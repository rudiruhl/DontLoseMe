-- DontLoseMe - Options.lua

local ADDON, ns = ...

DontLoseMe = DontLoseMe or {}
DontLoseMe.CATEGORY_ID = nil

local FALLBACKS = {
  enabled = true,
  conditions = { always = true, party = false, raid = false, combat = false },
  shape = "PLUS",
  size = 18,
  thickness = 2,
  offsetX = 0,
  offsetY = 0,
  r = 1, g = 1, b = 1, a = 0.9,
}

local function DB()
  if not DontLoseMeDB then DontLoseMeDB = {} end
  return DontLoseMeDB
end

local function Conditions()
  local db = DB()
  if type(db.conditions) ~= "table" then
    db.conditions = { always = true, party = false, raid = false, combat = false }
  end
  if db.conditions.always == nil then db.conditions.always = true end
  if db.conditions.party  == nil then db.conditions.party  = false end
  if db.conditions.raid   == nil then db.conditions.raid   = false end
  if db.conditions.combat == nil then db.conditions.combat = false end
  return db.conditions
end

local function Clamp(v, minv, maxv)
  v = tonumber(v) or minv
  if v < minv then return minv end
  if v > maxv then return maxv end
  return v
end

-- -------------------------------------------------------------------
-- UI helpers
-- -------------------------------------------------------------------
local function MakeLabel(parent, text, point, rel, relPoint, x, y, template)
  local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
  fs:SetText(text)
  if rel then
    fs:SetPoint(point, rel, relPoint, x, y)
  else
    fs:SetPoint(point, x, y)
  end
  return fs
end

local function MakeCheckbox(parent, label, tooltip, get, set)
  local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  cb.Text:SetText(label)
  cb.tooltipText = tooltip
  cb:SetScript("OnClick", function(self)
    set(self:GetChecked() and true or false)
    ns.RefreshAll()
  end)
  cb.Refresh = function()
    cb:SetChecked(get() and true or false)
  end
  return cb
end

local function MakeSlider(parent, label, minv, maxv, step, get, set)
  local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  s:SetMinMaxValues(minv, maxv)
  s:SetValueStep(step)
  s:SetObeyStepOnDrag(true)
  s.Text:SetText(label)
  s.Low:SetText(tostring(minv))
  s.High:SetText(tostring(maxv))

  s:SetScript("OnValueChanged", function(self, value)
    value = Clamp(value, minv, maxv)
    set(value)
    ns.RefreshAll()
  end)

  s.Refresh = function()
    s:SetValue(get())
  end
  return s
end

local function MakeNumberBox(parent, label, minv, maxv, getFunc, setFunc)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetAutoFocus(false)
  eb:SetSize(60, 20)
  eb:SetNumeric(true)

  MakeLabel(parent, label, "RIGHT", eb, "LEFT", -4, 0)

  local function Apply()
    local value = tonumber(eb:GetText())
    if not value then
      eb:SetText(tostring(getFunc()))
      return
    end
    value = Clamp(value, minv, maxv)
    setFunc(value)
    eb:SetText(tostring(value))
    ns.RefreshAll()
  end

  eb:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    Apply()
  end)

  eb:SetScript("OnEditFocusLost", function()
    Apply()
  end)

  eb.Refresh = function()
    eb:SetText(tostring(getFunc()))
  end

  return eb
end



local function MakeDropdown(parent, items, get, set)
  local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(dd, 180)

  local function Initialize()
    local current = get()
    for _, it in ipairs(items) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = it.text
      info.value = it.value
      info.checked = (it.value == current)
      info.func = function()
        set(it.value)
        UIDropDownMenu_SetSelectedValue(dd, it.value)
        ns.RefreshAll()
      end
      UIDropDownMenu_AddButton(info)
    end
  end

  UIDropDownMenu_Initialize(dd, Initialize)

  dd.Refresh = function()
    UIDropDownMenu_SetSelectedValue(dd, get())
  end

  return dd
end

-- -------------------------------------------------------------------
-- Panel
-- -------------------------------------------------------------------
local panel = CreateFrame("Frame", "DontLoseMeOptionsPanel", UIParent)
panel.name = "DontLoseMe"

local LEFT = 24
local TOP = -18

local header = MakeLabel(panel, "DontLoseMe", "TOPLEFT", nil, nil, LEFT, TOP, "GameFontNormalLarge")
local sub = MakeLabel(panel, "Don’t lose your character in combat — configurable crosshair overlay.", "TOPLEFT", header, "BOTTOMLEFT", 0, -8, "GameFontHighlightSmall")

-- Enable checkbox
local enabled = MakeCheckbox(
  panel,
  "Enable crosshair",
  "If no conditions are selected, this will turn off automatically.",
  function()
    return (DontLoseMeDB and DontLoseMeDB.enabled) ~= false
  end,
  function(v)
    DB().enabled = v and true or false
  end
)
enabled:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", -2, -12)

-- Conditions header
local conditionsHeader = MakeLabel(panel, "Conditions", "TOPLEFT", enabled, "BOTTOMLEFT", 2, -14, "GameFontNormal")

-- We create these first; callbacks will use them
local condAlways, condParty, condRaid, condCombat

-- Shape + sliders references (needed for grey-out function)
local shapeLabel, shape
local size, thickness, offsetX, offsetY
local sizeBox, offsetXBox, offsetYBox, thicknessBox
local colorBtn, swatch

local function UpdateSwatch()
  local db = DB()
  swatch:SetColorTexture(db.r or 1, db.g or 1, db.b or 1, db.a or 1)
end

local function UpdateControlState()
  local enabledState = (DontLoseMeDB and DontLoseMeDB.enabled) ~= false

  if enabledState then
    UIDropDownMenu_EnableDropDown(shape)
    size:Enable()
    sizeBox:Enable()
    thickness:Enable()
    thicknessBox:Enable()
    offsetX:Enable()
    offsetXBox:Enable()
    offsetY:Enable()
    offsetYBox:Enable()
    colorBtn:Enable()
    swatch:SetAlpha(1)
  else
    UIDropDownMenu_DisableDropDown(shape)
    size:Disable()
    sizeBox:Disable()
    thickness:Disable()
    thicknessBox:Disable()
    offsetX:Disable()
    offsetXBox:Disable()
    offsetY:Disable()
    offsetYBox:Disable()
    colorBtn:Disable()
    swatch:SetAlpha(0.3)
  end

  -- Optional: dim section label
  if enabledState then
    shapeLabel:SetTextColor(1, 0.82, 0)
  else
    shapeLabel:SetTextColor(0.5, 0.5, 0.5)
  end
end

local function ApplyConditionRules(changedKey)
  local db = DB()
  local c = Conditions()

  -- If Always ticked -> clear others (party/raid/combat)
  if changedKey == "always" and c.always then
    c.party = false
    c.raid = false
    c.combat = false
  end

  -- If any other ticked -> untick Always
  if changedKey ~= "always" and c[changedKey] then
    c.always = false
  end

  -- Auto enable/disable: any condition ticked => enabled on, none => enabled off
  local any = (c.always or c.party or c.raid or c.combat) and true or false
  db.enabled = any and true or false

  -- Refresh UI to reflect rules
  if condAlways then condAlways:Refresh() end
  if condParty  then condParty:Refresh()  end
  if condRaid   then condRaid:Refresh()   end
  if condCombat then condCombat:Refresh() end
  enabled:Refresh()

  if shape then shape:Refresh() end
  UpdateControlState()

  ns.RefreshAll()
end

local function MakeCondCheckbox(text, key, anchorTo, x, y)
  local cb = MakeCheckbox(
    panel,
    text,
    nil,
    function()
      local c = (DontLoseMeDB and DontLoseMeDB.conditions) or FALLBACKS.conditions
      return c[key] and true or false
    end,
    function(v)
      local c = Conditions()
      c[key] = v and true or false
      ApplyConditionRules(key)
    end
  )
  cb:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x or 0, y or -6)
  return cb
end

condAlways = MakeCondCheckbox("Always", "always", conditionsHeader, -2, -8)
condParty  = MakeCondCheckbox("In Party", "party",  condAlways, 0, -6)
condRaid   = MakeCondCheckbox("In Raid",  "raid",   condParty, 0, -6)
condCombat = MakeCondCheckbox("Only in combat", "combat", condRaid, 0, -6)

-- Shape
shapeLabel = MakeLabel(panel, "Shape", "TOPLEFT", condCombat, "BOTTOMLEFT", 2, -14, "GameFontNormal")
shape = MakeDropdown(
  panel,
  {
    { text = "Plus (+)", value = "PLUS" },
    { text = "X (diagonal)", value = "X" },
    { text = "Chevrons (Down)", value = "CHEVRON_DN" },
    { text = "Chevrons (Up)", value = "CHEVRON_UP" },
  },
  function() return (DontLoseMeDB and DontLoseMeDB.shape) or FALLBACKS.shape end,
  function(v) DB().shape = v end
)
shape:SetPoint("TOPLEFT", shapeLabel, "BOTTOMLEFT", -16, -6)

-- Sliders
size = MakeSlider(
  panel, "Size", 6, 80, 1,
  function() return (DontLoseMeDB and DontLoseMeDB.size) or FALLBACKS.size end,
  function(v) DB().size = v end
)
size:SetPoint("TOPLEFT", shape, "BOTTOMLEFT", 36, -34)

sizeBox = MakeNumberBox(
  panel, "px", 6, 80,
  function() return DB().size end,
  function(v) DB().size = v end
)

sizeBox:SetPoint("LEFT", size, "RIGHT", 18, 0)

-- update box if slider changes
size:HookScript("OnValueChanged", function()
  if sizeBox and sizeBox.Refresh then sizeBox:Refresh() end
end)

thickness = MakeSlider(
  panel, "Thickness", 1, 10, 1,
  function() return (DontLoseMeDB and DontLoseMeDB.thickness) or FALLBACKS.thickness end,
  function(v) DB().thickness = v end
)
thickness:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -42)

thicknessBox = MakeNumberBox(
  panel, "px", 1, 10,
  function() return DB().thickness end,
  function(v) DB().thickness = v end
)
thicknessBox:SetPoint("LEFT", thickness, "RIGHT", 18, 0)

offsetX = MakeSlider(
  panel, "Offset X", -300, 300, 1,
  function() return (DontLoseMeDB and DontLoseMeDB.offsetX) or FALLBACKS.offsetX end,
  function(v) DB().offsetX = v end
)
offsetX:SetPoint("TOPLEFT", thickness, "BOTTOMLEFT", 0, -42)

offsetXBox = MakeNumberBox(
  panel, "", -300, 300,
  function() return DB().offsetX end,
  function(v) DB().offsetX = v end
)
offsetXBox:SetPoint("LEFT", offsetX, "RIGHT", 18, 0)

offsetX:HookScript("OnValueChanged", function()
  if offsetXBox and offsetXBox.Refresh then offsetXBox:Refresh() end
end)


offsetY = MakeSlider(
  panel, "Offset Y", -300, 300, 1,
  function() return (DontLoseMeDB and DontLoseMeDB.offsetY) or FALLBACKS.offsetY end,
  function(v) DB().offsetY = v end
)
offsetY:SetPoint("TOPLEFT", offsetX, "BOTTOMLEFT", 0, -42)

offsetYBox = MakeNumberBox(
  panel, "", -300, 300,
  function() return DB().offsetY end,
  function(v) DB().offsetY = v end
)
offsetYBox:SetPoint("LEFT", offsetY, "RIGHT", 18, 0)

offsetY:HookScript("OnValueChanged", function()
  if offsetYBox and offsetYBox.Refresh then offsetYBox:Refresh() end
end)


-- Color button + swatch
colorBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
colorBtn:SetSize(160, 24)
colorBtn:SetPoint("TOPLEFT", offsetY, "BOTTOMLEFT", -2, -18)
colorBtn:SetText("Set Color...")

swatch = panel:CreateTexture(nil, "ARTWORK")
swatch:SetSize(18, 18)
swatch:SetPoint("LEFT", colorBtn, "RIGHT", 12, 0)

-- Modern color picker (Retail)
colorBtn:SetScript("OnClick", function()
  local db = DB()

  local info = {}
  info.r = db.r or FALLBACKS.r
  info.g = db.g or FALLBACKS.g
  info.b = db.b or FALLBACKS.b

  info.hasOpacity = true
  info.opacity = 1 - (db.a or FALLBACKS.a)
  info.previousValues = { info.r, info.g, info.b, info.opacity }

  info.swatchFunc = function()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    local opacity = (OpacitySliderFrame and OpacitySliderFrame:GetValue()) or info.opacity or 0
    local a = 1 - opacity
    db.r, db.g, db.b, db.a = r, g, b, a
    UpdateSwatch()
    ns.RefreshAll()
  end
  info.opacityFunc = info.swatchFunc

  info.cancelFunc = function(prev)
    if type(prev) == "table" then
      local r, g, b, opacity = prev[1], prev[2], prev[3], prev[4]
      db.r, db.g, db.b = r or FALLBACKS.r, g or FALLBACKS.g, b or FALLBACKS.b
      db.a = 1 - (opacity or (1 - FALLBACKS.a))
      UpdateSwatch()
      ns.RefreshAll()
    end
  end

  if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
    ColorPickerFrame:SetupColorPickerAndShow(info)
  else
    ColorPickerFrame.func = info.swatchFunc
    ColorPickerFrame.opacityFunc = info.opacityFunc
    ColorPickerFrame.cancelFunc = info.cancelFunc
    ColorPickerFrame.hasOpacity = info.hasOpacity
    ColorPickerFrame.opacity = info.opacity
    ColorPickerFrame.previousValues = info.previousValues
    ColorPickerFrame:Show()
  end
end)

panel:SetScript("OnShow", function()
  -- Apply init rules once (ensures enabled is consistent with conditions)
  ApplyConditionRules("init")

  enabled:Refresh()
  condAlways:Refresh()
  condParty:Refresh()
  condRaid:Refresh()
  condCombat:Refresh()

  shape:Refresh()
  size:Refresh()
  sizeBox:Refresh()
  thickness:Refresh()
  thicknessBox:Refresh()
  offsetX:Refresh()
  offsetXBox:Refresh()
  offsetY:Refresh()
  offsetYBox:Refresh()

  UpdateSwatch()
  UpdateControlState()
end)

-- -------------------------------------------------------------------
-- Register 
-- -------------------------------------------------------------------
local function RegisterSettingsCategory()
  if not Settings or not Settings.RegisterCanvasLayoutCategory then return end
  local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
  Settings.RegisterAddOnCategory(category)
  DontLoseMe.CATEGORY_ID = category:GetID()
end

RegisterSettingsCategory()

-- Slash commands
SLASH_DONTLOSEME1 = "/dontloseme"
SLASH_DONTLOSEME2 = "/dlm"

SlashCmdList["DONTLOSEME"] = function()
  if Settings and Settings.OpenToCategory and DontLoseMe.CATEGORY_ID then
    Settings.OpenToCategory(DontLoseMe.CATEGORY_ID)
  else
    print("DontLoseMe: Settings not ready yet.")
  end
end
