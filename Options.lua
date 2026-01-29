-- DontLoseMe - Options.lua

local ADDON, ns = ...

DontLoseMe = DontLoseMe or {}
DontLoseMe.CATEGORY_ID = nil

-- -------------------------------------------------------------------
-- Database accessors + helpers
-- -------------------------------------------------------------------
local FALLBACKS = {
  enabled = true,
  conditions = { always = true, party = false, raid = false, combat = false },
  shape = "PLUS",
  size = 18,
  thickness = 2,
  offsetX = 0,
  offsetY = 0,
  r = 1, g = 1, b = 1, a = 0.9,
  outlineEnabled = false,
  outlineThickness = 2,
  outlineR = 0, outlineG = 0, outlineB = 0, outlineA = 1,
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

-- UI-only saved state (collapse, layout)
local function EnsureUIState()
  local db = DB()
  if type(db.ui) ~= "table" then
    db.ui = {}
  end
  if db.ui.conditionsCollapsed == nil then
    db.ui.conditionsCollapsed = false
  end
end

local function EnsureOutline()
  local db = DB()
  if db.outlineEnabled == nil then db.outlineEnabled = FALLBACKS.outlineEnabled end
  if db.outlineThickness == nil then db.outlineThickness = FALLBACKS.outlineThickness end
  if db.outlineR == nil then db.outlineR = FALLBACKS.outlineR end
  if db.og == nil then db.og = FALLBACKS.og end
  if db.ob == nil then db.ob = FALLBACKS.ob end
  if db.oa == nil then db.oa = FALLBACKS.oa end
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

-- Label
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

-- Checkbox
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

-- Shape preview
local function CreateShapeTextures(parent)
  local t = {}

  -- main
  t.plusH = parent:CreateTexture(nil, "ARTWORK"); t.plusH:SetColorTexture(1,1,1,1)
  t.plusV = parent:CreateTexture(nil, "ARTWORK"); t.plusV:SetColorTexture(1,1,1,1)

  t.xA = parent:CreateTexture(nil, "ARTWORK"); t.xA:SetColorTexture(1,1,1,1)
  t.xB = parent:CreateTexture(nil, "ARTWORK"); t.xB:SetColorTexture(1,1,1,1)

  t.ch1A = parent:CreateTexture(nil, "ARTWORK"); t.ch1A:SetColorTexture(1,1,1,1)
  t.ch1B = parent:CreateTexture(nil, "ARTWORK"); t.ch1B:SetColorTexture(1,1,1,1)
  t.ch2A = parent:CreateTexture(nil, "ARTWORK"); t.ch2A:SetColorTexture(1,1,1,1)
  t.ch2B = parent:CreateTexture(nil, "ARTWORK"); t.ch2B:SetColorTexture(1,1,1,1)

  -- outline (drawn behind)
  t.o_plusH = parent:CreateTexture(nil, "BACKGROUND"); t.o_plusH:SetColorTexture(0,0,0,1)
  t.o_plusV = parent:CreateTexture(nil, "BACKGROUND"); t.o_plusV:SetColorTexture(0,0,0,1)

  t.o_xA = parent:CreateTexture(nil, "BACKGROUND"); t.o_xA:SetColorTexture(0,0,0,1)
  t.o_xB = parent:CreateTexture(nil, "BACKGROUND"); t.o_xB:SetColorTexture(0,0,0,1)

  t.o_ch1A = parent:CreateTexture(nil, "BACKGROUND"); t.o_ch1A:SetColorTexture(0,0,0,1)
  t.o_ch1B = parent:CreateTexture(nil, "BACKGROUND"); t.o_ch1B:SetColorTexture(0,0,0,1)
  t.o_ch2A = parent:CreateTexture(nil, "BACKGROUND"); t.o_ch2A:SetColorTexture(0,0,0,1)
  t.o_ch2B = parent:CreateTexture(nil, "BACKGROUND"); t.o_ch2B:SetColorTexture(0,0,0,1)

  return t
end

local function HideAll(t)
  for _, tex in pairs(t) do tex:Hide() end
end

local previewRoot = CreateFrame("Frame", nil, preview)
previewRoot:SetPoint("CENTER", preview, "CENTER", 0, 0)
previewRoot:SetSize(1, 1)

local PT = CreateShapeTextures(previewRoot)

local function PlaceBar(tex, cx, cy, w, h, rot)
  tex:ClearAllPoints()
  tex:SetPoint("CENTER", previewRoot, "CENTER", cx, cy)
  tex:SetSize(w, h)
  tex:SetRotation(rot or 0)
  tex:Show()
end

local function RenderShape(t, db)
  HideAll(t)

  local size = Clamp(db.size or FALLBACKS.size, 6, 80)
  local thick = Clamp(db.thickness or FALLBACKS.thickness, 1, 10)
  local r,g,b,a = db.r or 1, db.g or 1, db.b or 1, db.a or 1

  local outlineOn = db.outlineEnabled and true or false
  local oT = Clamp(db.outlineThickness or FALLBACKS.outlineThickness, 1, 10)
  local or_,og,ob,oa = db.or_ or 0, db.og or 0, db.ob or 0, db.oa or 1

  local shape = db.shape or FALLBACKS.shape

  local function setMain(tex) tex:SetColorTexture(r,g,b,a) end
  local function setOut(tex)  tex:SetColorTexture(or_,og,ob,oa) end

  -- helper: outline version of same bar (bigger behind)
  local function PlaceOutlined(outTex, mainTex, cx, cy, w, h, rot)
    if outlineOn then
      setOut(outTex)
      PlaceBar(outTex, cx, cy, w + oT*2, h + oT*2, rot)
    end
    setMain(mainTex)
    PlaceBar(mainTex, cx, cy, w, h, rot)
  end

  if shape == "PLUS" then
    PlaceOutlined(t.o_plusH, t.plusH, 0, 0, size, thick, 0)
    PlaceOutlined(t.o_plusV, t.plusV, 0, 0, thick, size, 0)

  elseif shape == "X" then
    PlaceOutlined(t.o_xA, t.xA, 0, 0, size, thick, math.rad(45))
    PlaceOutlined(t.o_xB, t.xB, 0, 0, size, thick, math.rad(-45))

  elseif shape == "CHEVRON_DD" or shape == "CHEVRON_DU" then
    local angle = math.rad(35)
    local armLen = size
    local dx = armLen * 0.25
    local gap = math.max(2, thick * 2)
    local yTop = gap * 0.6
    local yBot = -gap * 0.6

    local leftRot, rightRot
    if shape == "CHEVRON_DD" then
      leftRot, rightRot = angle, -angle
    else
      leftRot, rightRot = -angle, angle
    end

    -- top V
    PlaceOutlined(t.o_ch1A, t.ch1A, -dx, yTop, armLen, thick, leftRot)
    PlaceOutlined(t.o_ch1B, t.ch1B,  dx, yTop, armLen, thick, rightRot)
    -- bottom V
    PlaceOutlined(t.o_ch2A, t.ch2A, -dx, yBot, armLen, thick, leftRot)
    PlaceOutlined(t.o_ch2B, t.ch2B,  dx, yBot, armLen, thick, rightRot)
  end
end

-- Slider
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

-- Number box
local function MakeNumberBox(parent, label, minv, maxv, getFunc, setFunc)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetAutoFocus(false)
  eb:SetSize(60, 20)
  eb:SetNumeric(true)
  eb:SetJustifyH("CENTER")

  local lbl
  if label and label ~= "" then
    lbl = MakeLabel(parent, label, "LEFT", eb, "RIGHT", 4, 0)
  end

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

  eb:SetScript("OnEditFocusLost", Apply)

  eb.Refresh = function()
    eb:SetText(tostring(getFunc()))
  end

  return eb, lbl
end

-- Dropdown
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
-- Panel + Scroll Container
-- -------------------------------------------------------------------
local panel = CreateFrame("Frame", "DontLoseMeOptionsPanel", UIParent)
panel.name = "DontLoseMe"

-- Scroll container
local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 0) -- space for scrollbar

-- Content frame (everything is parented here)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(1, 1)
scroll:SetScrollChild(content)

local LEFT = 24
local TOP = -18

local header = MakeLabel(content, "DontLoseMe", "TOPLEFT", nil, nil, LEFT, TOP, "GameFontNormalLarge")
local sub = MakeLabel(content, "Don’t lose your character in combat — configurable crosshair overlay.", "TOPLEFT", header, "BOTTOMLEFT", 0, -8, "GameFontHighlightSmall")

-- Enable checkbox
local enabled = MakeCheckbox(
  content,
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

-- -------------------------------------------------------------------
-- References
-- -------------------------------------------------------------------
local condAlways, condParty, condRaid, condCombat
local UpdateScrollHeight
local shapeLabel, shape
local preview
local size, thickness, offsetX, offsetY
local sizeBox, offsetXBox, offsetYBox, thicknessBox
local sizeBoxLbl, offsetXBoxLbl, offsetYBoxLbl, thicknessBoxLbl
local colorBtn, swatch
local outlineEnabled

-- Collapsible conditions widgets
local conditionsBtn, conditionsHeader, conditionsGroup, conditionsArrow, conditionsSpacer
local function RefreshConditionsCollapse() end

local function UpdateSwatch()
  local db = DB()
  if swatch then
    swatch:SetColorTexture(db.r or 1, db.g or 1, db.b or 1, db.a or 1)
  end
end

local function UpdateControlState()
  local enabledState = (DontLoseMeDB and DontLoseMeDB.enabled) ~= false

  if shape then
    if enabledState then UIDropDownMenu_EnableDropDown(shape) else UIDropDownMenu_DisableDropDown(shape) end
  end

  local function SetEnabled(widget)
    if not widget then return end
    if enabledState then widget:Enable() else widget:Disable() end
  end
  SetEnabled(size); SetEnabled(sizeBox)
  SetEnabled(thickness); SetEnabled(thicknessBox)
  SetEnabled(offsetX); SetEnabled(offsetXBox)
  SetEnabled(offsetY); SetEnabled(offsetYBox)
  SetEnabled(colorBtn)

  if swatch then swatch:SetAlpha(enabledState and 1 or 0.3) end

  if shapeLabel then
    if enabledState then
      shapeLabel:SetTextColor(1, 0.82, 0)
    else
      shapeLabel:SetTextColor(0.5, 0.5, 0.5)
    end
  end

  local a = enabledState and 1 or 0.4
  if sizeBoxLbl then sizeBoxLbl:SetAlpha(a) end
  if thicknessBoxLbl then thicknessBoxLbl:SetAlpha(a) end
  if offsetXBoxLbl then offsetXBoxLbl:SetAlpha(a) end
  if offsetYBoxLbl then offsetYBoxLbl:SetAlpha(a) end

  local outlineOn = DB().outlineEnabled and true or false
  if outlineThickness then if outlineOn then outlineThickness:Enable() else outlineThickness:Disable() end end
  if outlineThicknessBox then if outlineOn then outlineThicknessBox:Enable() else outlineThicknessBox:Disable() end end
  if outlineColorBtn then if outlineOn then outlineColorBtn:Enable() else outlineColorBtn:Disable() end end
  if outlineSwatch then outlineSwatch:SetAlpha(outlineOn and 1 or 0.3) end

end

local function ApplyConditionRules(changedKey)
  local db = DB()
  local c = Conditions()

  if changedKey == "always" and c.always then
    c.party = false
    c.raid = false
    c.combat = false
  end

  if changedKey ~= "always" and c[changedKey] then
    c.always = false
  end

  local any = (c.always or c.party or c.raid or c.combat) and true or false
  db.enabled = any and true or false

  if condAlways then condAlways:Refresh() end
  if condParty  then condParty:Refresh()  end
  if condRaid   then condRaid:Refresh()   end
  if condCombat then condCombat:Refresh() end
  enabled:Refresh()

  if shape then shape:Refresh() end
  UpdateControlState()

  ns.RefreshAll()
end

-------------------------------------------------------------------
-- Conditions (collapsible)
-- -------------------------------------------------------------------

-- Clickable header button
conditionsBtn = CreateFrame("Button", nil, content)
conditionsBtn:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -12)
conditionsBtn:SetSize(260, 20)

conditionsHeader = MakeLabel(conditionsBtn, "Conditions", "LEFT", conditionsBtn, "LEFT", 28, 0, "GameFontNormal")

conditionsArrow = conditionsBtn:CreateTexture(nil, "ARTWORK")
conditionsArrow:SetSize(24, 24)
conditionsArrow:SetPoint("LEFT", conditionsBtn, "LEFT", 4, 0)
conditionsArrow:SetTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up")

-- This frame is ONLY used as a layout anchor for what comes next.
conditionsSpacer = CreateFrame("Frame", nil, content)
conditionsSpacer:SetPoint("TOPLEFT", conditionsBtn, "BOTTOMLEFT", 0, -4)
conditionsSpacer:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
conditionsSpacer:SetHeight(10)

-- The actual container that holds the checkboxes.
conditionsGroup = CreateFrame("Frame", nil, content)
conditionsGroup:SetPoint("TOPLEFT", conditionsSpacer, "TOPLEFT", 0, 0)
conditionsGroup:SetSize(1, 1)

-- Create condition checkboxes INSIDE conditionsGroup
local function MakeCondCheckbox(text, key, anchorTo, x, y)
  local cb = MakeCheckbox(
    conditionsGroup,
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

-- First checkbox anchors to the group's TOPLEFT (not to the header!)
condAlways = MakeCondCheckbox("Always", "always", conditionsGroup, 20, 0)
condParty  = MakeCondCheckbox("In Party", "party",  condAlways, 0, -6)
condRaid   = MakeCondCheckbox("In Raid",  "raid",   condParty, 0, -6)
condCombat = MakeCondCheckbox("Only in combat", "combat", condRaid, 0, -6)

-- Collapse/expand refresh
local function RefreshConditionsCollapse()
  EnsureUIState()
  local collapsed = DB().ui.conditionsCollapsed and true or false

  if collapsed then
    conditionsGroup:Hide()
    conditionsSpacer:SetHeight(10)
    conditionsArrow:SetRotation(0) -- right
  else
    conditionsGroup:Show()
    conditionsArrow:SetRotation(math.rad(90)) -- down

    -- Compute required height for spacer so content below moves down
    local bottom = condCombat and condCombat:GetBottom()
    local top = conditionsGroup:GetTop()
    if bottom and top then
      local h = (top - bottom) + 12
      if h < 1 then h = 1 end
      conditionsSpacer:SetHeight(h)
    else
      conditionsSpacer:SetHeight(90)
    end
  end
end

conditionsBtn:SetScript("OnClick", function()
  EnsureUIState()
  DB().ui.conditionsCollapsed = not DB().ui.conditionsCollapsed
  RefreshConditionsCollapse()
  UpdateScrollHeight()
end)

-- Call once so initial state is correct (will be called again in OnShow too)
RefreshConditionsCollapse()

-- -------------------------------------------------------------------
-- Shape dropdown
-- -------------------------------------------------------------------
shapeLabel = MakeLabel(content, "Shape", "TOPLEFT", conditionsSpacer, "BOTTOMLEFT", 2, -14, "GameFontNormal")
shape = MakeDropdown(
  content,
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

-- Preview box (right side)
preview = CreateFrame("Frame", nil, content, "BackdropTemplate")
preview:SetSize(300, 300)
preview:SetPoint("TOPLEFT", shape, "BOTTOMRIGHT", 260, -10)
preview:SetBackdrop({
  bgFile = "Interface/ChatFrame/ChatFrameBackground",
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
preview:SetBackdropColor(0, 0, 0, 0.35)

local previewTitle = MakeLabel(content, "Preview", "BOTTOMLEFT", preview, "TOPLEFT", 6, 6, "GameFontNormal")


-- Layout constants
local SLIDER_GAP  = 34
local BOX_GAP     = 6
local SECTION_GAP = 50
local BUTTON_GAP  = 28

-- Size
size = MakeSlider(
  content, "Size", 6, 80, 1,
  function() return (DontLoseMeDB and DontLoseMeDB.size) or FALLBACKS.size end,
  function(v) DB().size = v end
)
size:SetPoint("TOPLEFT", shape, "BOTTOMLEFT", 16, -SLIDER_GAP)

sizeBox, sizeBoxLbl = MakeNumberBox(
  content, "px", 6, 80,
  function() return DB().size end,
  function(v) DB().size = v end
)
sizeBox:ClearAllPoints()
sizeBox:SetPoint("TOP", size, "BOTTOM", 0, -BOX_GAP)
size:HookScript("OnValueChanged", function()
  if sizeBox and sizeBox.Refresh then sizeBox:Refresh() end
end)

-- Thickness
thickness = MakeSlider(
  content, "Thickness", 1, 10, 1,
  function() return (DontLoseMeDB and DontLoseMeDB.thickness) or FALLBACKS.thickness end,
  function(v) DB().thickness = v end
)
thickness:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -SECTION_GAP)

thicknessBox, thicknessBoxLbl = MakeNumberBox(
  content, "px", 1, 10,
  function() return DB().thickness end,
  function(v) DB().thickness = v end
)
thicknessBox:ClearAllPoints()
thicknessBox:SetPoint("TOP", thickness, "BOTTOM", 0, -BOX_GAP)
thickness:HookScript("OnValueChanged", function()
  if thicknessBox and thicknessBox.Refresh then thicknessBox:Refresh() end
end)

-- Offset X
offsetX = MakeSlider(
  content, "Offset X", -300, 300, 1,
  function() return (DontLoseMeDB and DontLoseMeDB.offsetX) or FALLBACKS.offsetX end,
  function(v) DB().offsetX = v end
)
offsetX:SetPoint("TOPLEFT", thickness, "BOTTOMLEFT", 0, -SECTION_GAP)

offsetXBox, offsetXBoxLbl = MakeNumberBox(
  content, "px", -300, 300,
  function() return DB().offsetX end,
  function(v) DB().offsetX = v end
)
offsetXBox:ClearAllPoints()
offsetXBox:SetPoint("TOP", offsetX, "BOTTOM", 0, -BOX_GAP)
offsetX:HookScript("OnValueChanged", function()
  if offsetXBox and offsetXBox.Refresh then offsetXBox:Refresh() end
end)

-- Offset Y
offsetY = MakeSlider(
  content, "Offset Y", -300, 300, 1,
  function() return (DontLoseMeDB and DontLoseMeDB.offsetY) or FALLBACKS.offsetY end,
  function(v) DB().offsetY = v end
)
offsetY:SetPoint("TOPLEFT", offsetX, "BOTTOMLEFT", 0, -SECTION_GAP)

offsetYBox, offsetYBoxLbl = MakeNumberBox(
  content, "px", -300, 300,
  function() return DB().offsetY end,
  function(v) DB().offsetY = v end
)
offsetYBox:ClearAllPoints()
offsetYBox:SetPoint("TOP", offsetY, "BOTTOM", 0, -BOX_GAP)
offsetY:HookScript("OnValueChanged", function()
  if offsetYBox and offsetYBox.Refresh then offsetYBox:Refresh() end
end)

-- Color button + swatch
colorBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
colorBtn:SetSize(160, 24)
colorBtn:SetPoint("TOPLEFT", offsetY, "BOTTOMLEFT", 0, -(BOX_GAP + BUTTON_GAP))
colorBtn:SetText("Set Color...")

swatch = content:CreateTexture(nil, "ARTWORK")
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

outlineEnabled = MakeCheckbox(
  content,
  "Enable outline",
  "Draw a separate outline behind the shape.",
  function() return DB().outlineEnabled and true or false end,
  function(v) DB().outlineEnabled = v and true or false end
)
outlineEnabled:SetPoint("TOPLEFT", colorBtn, "BOTTOMLEFT", 0, -14)

outlineThickness = MakeSlider(
  content, "Outline Thickness", 1, 10, 1,
  function() return DB().outlineThickness or FALLBACKS.outlineThickness end,
  function(v) DB().outlineThickness = v end
)
outlineThickness:SetPoint("TOPLEFT", outlineEnabled, "BOTTOMLEFT", 2, -22)

outlineThicknessBox, outlineThicknessLbl = MakeNumberBox(
  content, "px", 1, 10,
  function() return DB().outlineThickness or FALLBACKS.outlineThickness end,
  function(v) DB().outlineThickness = v end
)
outlineThicknessBox:SetPoint("TOP", outlineThickness, "BOTTOM", 0, -BOX_GAP)

outlineThickness:HookScript("OnValueChanged", function()
  if outlineThicknessBox and outlineThicknessBox.Refresh then outlineThicknessBox:Refresh() end
end)

local outlineColorBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
outlineColorBtn:SetSize(160, 24)
outlineColorBtn:SetPoint("TOPLEFT", outlineThickness, "BOTTOMLEFT", 0, -(BOX_GAP + 18))
outlineColorBtn:SetText("Set Outline Color...")

local outlineSwatch = content:CreateTexture(nil, "ARTWORK")
outlineSwatch:SetSize(18, 18)
outlineSwatch:SetPoint("LEFT", outlineColorBtn, "RIGHT", 12, 0)

local function UpdateOutlineSwatch()
  local db = DB()
  outlineSwatch:SetColorTexture(db.or_ or 0, db.og or 0, db.ob or 0, db.oa or 1)
end

outlineColorBtn:SetScript("OnClick", function()
  local db = DB()
  local info = {
    r = db.or_ or FALLBACKS.or_, g = db.og or FALLBACKS.og, b = db.ob or FALLBACKS.ob,
    hasOpacity = true,
    opacity = 1 - (db.oa or FALLBACKS.oa),
    previousValues = { db.or_ or FALLBACKS.or_, db.og or FALLBACKS.og, db.ob or FALLBACKS.ob, 1 - (db.oa or FALLBACKS.oa) },
  }

  info.swatchFunc = function()
    local r,g,b = ColorPickerFrame:GetColorRGB()
    local opacity = (OpacitySliderFrame and OpacitySliderFrame:GetValue()) or info.opacity or 0
    db.or_, db.og, db.ob, db.oa = r, g, b, (1 - opacity)
    UpdateOutlineSwatch()
    ns.RefreshAll()
    RenderShape(PT, db)
  end
  info.opacityFunc = info.swatchFunc

  info.cancelFunc = function(prev)
    if type(prev) == "table" then
      db.or_, db.og, db.ob = prev[1], prev[2], prev[3]
      db.oa = 1 - (prev[4] or 0)
      UpdateOutlineSwatch()
      ns.RefreshAll()
      RenderShape(PT, db)
    end
  end

  ColorPickerFrame:SetupColorPickerAndShow(info)
end)


-- Set content size so scrollbar knows how far it can scroll
UpdateScrollHeight = function()
  content:SetWidth(panel:GetWidth() > 0 and panel:GetWidth() or 500)

  local bottom = colorBtn and colorBtn:GetBottom()
  local top = header and header:GetTop()
  if bottom and top then
    local h = (top - bottom) + 40
    if h < 1 then h = 1 end
    content:SetHeight(h)
  else
    content:SetHeight(800)
  end
end


-- -------------------------------------------------------------------
-- OnShow: ensure UI state + collapse refresh
-- -------------------------------------------------------------------
panel:SetScript("OnShow", function()
  EnsureUIState()
  EnsureOutline()
  UpdateScrollHeight()
  RefreshConditionsCollapse()
  RenderShape(PT, DB())

  ApplyConditionRules("init")

  enabled:Refresh()
  if condAlways then condAlways:Refresh() end
  if condParty  then condParty:Refresh()  end
  if condRaid   then condRaid:Refresh()   end
  if condCombat then condCombat:Refresh() end

  if shape then shape:Refresh() end

  if size then size:Refresh() end
  if sizeBox then sizeBox:Refresh() end
  if thickness then thickness:Refresh() end
  if thicknessBox then thicknessBox:Refresh() end
  if offsetX then offsetX:Refresh() end
  if offsetXBox then offsetXBox:Refresh() end
  if offsetY then offsetY:Refresh() end
  if offsetYBox then offsetYBox:Refresh() end

  UpdateSwatch()
  UpdateControlState()
  UpdateScrollHeight()
end)

panel:SetScript("OnSizeChanged", function()
  UpdateScrollHeight()
end)

-- -------------------------------------------------------------------
-- Register in Settings
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
