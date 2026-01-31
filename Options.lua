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

-- FIX: Use per-character database
local function DB()
  -- ns.db is set by Core.lua after ADDON_LOADED
  if not ns.db then
    -- Fallback during early initialization
    local realm = GetRealmName()
    local name = UnitName("player")
    local charKey = name .. "-" .. realm
    
    if not DontLoseMeDB then DontLoseMeDB = {} end
    if not DontLoseMeDB[charKey] then DontLoseMeDB[charKey] = {} end
    
    ns.db = DontLoseMeDB[charKey]
  end
  return ns.db
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

-- UI-only saved state (collapse)
local function EnsureUIState()
  local db = DB()
  if type(db.ui) ~= "table" then db.ui = {} end
  if db.ui.conditionsCollapsed == nil then
    db.ui.conditionsCollapsed = false -- default: expanded
  end
end

local function EnsureOutline()
  local db = DB()
  -- FIX: Ensure proper boolean type for outlineEnabled
  if db.outlineEnabled == nil then 
    db.outlineEnabled = FALLBACKS.outlineEnabled
  else
    db.outlineEnabled = db.outlineEnabled and true or false
  end
  
  if db.outlineThickness == nil then db.outlineThickness = FALLBACKS.outlineThickness end
  if db.outlineR == nil then db.outlineR = FALLBACKS.outlineR end
  if db.outlineG == nil then db.outlineG = FALLBACKS.outlineG end
  if db.outlineB == nil then db.outlineB = FALLBACKS.outlineB end
  if db.outlineA == nil then db.outlineA = FALLBACKS.outlineA end
end

-- -------------------------------------------------------------------
-- Utility
-- -------------------------------------------------------------------
local function Clamp(v, minv, maxv)
  v = tonumber(v) or minv
  if v < minv then return minv end
  if v > maxv then return maxv end
  return v
end

-- Forward declarations (needed because helpers call these)
local RefreshPreview
local UpdateControlState

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
    local checked = self:GetChecked() and true or false
    set(checked)
    ns.RefreshAll()
    if RefreshPreview then RefreshPreview() end
    if UpdateControlState then UpdateControlState() end
  end)
  cb.Refresh = function()
    local value = get()
    cb:SetChecked(value and true or false)
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
    if RefreshPreview then RefreshPreview() end
  end)

  s.Refresh = function()
    s:SetValue(get())
  end
  return s
end

-- Number box: keeps slider + preview in sync when user types
local function MakeNumberBox(parent, label, minv, maxv, getFunc, setFunc, linkedSlider)
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

    -- keep slider in sync (prevents preview desync)
    if linkedSlider and linkedSlider.SetValue then
      if linkedSlider:GetValue() ~= value then
        linkedSlider:SetValue(value)
      end
    end

    ns.RefreshAll()
    if RefreshPreview then RefreshPreview() end
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
        if RefreshPreview then RefreshPreview() end
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
-- Preview renderer helpers
-- -------------------------------------------------------------------
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

  -- outline (behind)
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

local function PlaceBarP(tex, parent, cx, cy, w, h, rot)
  tex:ClearAllPoints()
  tex:SetPoint("CENTER", parent, "CENTER", cx, cy)
  tex:SetSize(w, h)
  tex:SetRotation(rot or 0)
  tex:Show()
end

local function PlaceOutlinedP(outTex, mainTex, parent, cx, cy, w, h, rot, outlineOn, oThick)
  if outlineOn then
    PlaceBarP(outTex, parent, cx, cy, w + oThick * 2, h + oThick * 2, rot)
  else
    outTex:Hide()
  end
  PlaceBarP(mainTex, parent, cx, cy, w, h, rot)
end

local function PlaceVP(outA, outB, texA, texB, parent, y, armLen, thick, leftRot, rightRot, outlineOn, oThick)
  local dx = armLen * 0.35
  PlaceOutlinedP(outA, texA, parent, -dx, y, armLen, thick, leftRot,  outlineOn, oThick)
  PlaceOutlinedP(outB, texB, parent,  dx, y, armLen, thick, rightRot, outlineOn, oThick)
end

local function ApplyColorsP(t, r, g, b, a, outR, outG, outB, outA)
  t.plusH:SetColorTexture(r, g, b, a)
  t.plusV:SetColorTexture(r, g, b, a)
  t.xA:SetColorTexture(r, g, b, a)
  t.xB:SetColorTexture(r, g, b, a)
  t.ch1A:SetColorTexture(r, g, b, a)
  t.ch1B:SetColorTexture(r, g, b, a)
  t.ch2A:SetColorTexture(r, g, b, a)
  t.ch2B:SetColorTexture(r, g, b, a)

  t.o_plusH:SetColorTexture(outR, outG, outB, outA)
  t.o_plusV:SetColorTexture(outR, outG, outB, outA)
  t.o_xA:SetColorTexture(outR, outG, outB, outA)
  t.o_xB:SetColorTexture(outR, outG, outB, outA)
  t.o_ch1A:SetColorTexture(outR, outG, outB, outA)
  t.o_ch1B:SetColorTexture(outR, outG, outB, outA)
  t.o_ch2A:SetColorTexture(outR, outG, outB, outA)
  t.o_ch2B:SetColorTexture(outR, outG, outB, outA)
end

local function RenderPreview(parent, t)
  local db = DB()
  local size  = tonumber(db.size) or FALLBACKS.size
  local thick = tonumber(db.thickness) or FALLBACKS.thickness
  local shape = db.shape or FALLBACKS.shape

  local r = db.r or FALLBACKS.r
  local g = db.g or FALLBACKS.g
  local b = db.b or FALLBACKS.b
  local a = db.a or FALLBACKS.a

  -- FIX: Properly read boolean value for outline
  local outlineOn = (db.outlineEnabled == true)
  local oT = tonumber(db.outlineThickness) or FALLBACKS.outlineThickness
  if oT < 1 then oT = 1 end
  if oT > 10 then oT = 10 end

  local outR = db.outlineR or FALLBACKS.outlineR
  local outG = db.outlineG or FALLBACKS.outlineG
  local outB = db.outlineB or FALLBACKS.outlineB
  local outA = db.outlineA or FALLBACKS.outlineA

  ApplyColorsP(t, r, g, b, a, outR, outG, outB, outA)
  HideAll(t)

  if shape == "X" then
    PlaceOutlinedP(t.o_xA, t.xA, parent, 0, 0, size, thick, math.rad(45),  outlineOn, oT)
    PlaceOutlinedP(t.o_xB, t.xB, parent, 0, 0, size, thick, math.rad(-45), outlineOn, oT)

  elseif shape == "CHEVRON_DN" or shape == "CHEVRON_UP" then
    local angle = math.rad(35)
    local armLen = size
    local gap = math.max(2, thick * 2)
    local yTop = gap * 0.6
    local yBot = -gap * 0.6

    local leftRot, rightRot
    if shape == "CHEVRON_DN" then
      leftRot  = -angle
      rightRot = angle
    else
      leftRot  = angle
      rightRot = -angle
    end

    PlaceVP(t.o_ch1A, t.o_ch1B, t.ch1A, t.ch1B, parent, yTop, armLen, thick, leftRot, rightRot, outlineOn, oT)
    PlaceVP(t.o_ch2A, t.o_ch2B, t.ch2A, t.ch2B, parent, yBot, armLen, thick, leftRot, rightRot, outlineOn, oT)

  else
    PlaceOutlinedP(t.o_plusH, t.plusH, parent, 0, 0, size, thick, 0, outlineOn, oT)
    PlaceOutlinedP(t.o_plusV, t.plusV, parent, 0, 0, thick, size, 0, outlineOn, oT)
  end
end

-- -------------------------------------------------------------------
-- Panel + Scroll Container
-- -------------------------------------------------------------------
local panel = CreateFrame("Frame", "DontLoseMeOptions", UIParent)
panel.name = "DontLoseMe"
panel:Hide()

local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 10, -10)
scroll:SetPoint("BOTTOMRIGHT", -30, 10)

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(1, 1)
scroll:SetScrollChild(content)

local SLIDER_W = 240
local SECTION_GAP = 40
local BOX_GAP = 6
local CONTROL_GAP = 16
local CHECKBOX_GAP = 8

-- -------------------------------------------------------------------
-- Header
-- -------------------------------------------------------------------
local header = MakeLabel(content, "DontLoseMe - Crosshair Settings", "TOPLEFT", 10, -10, "GameFontNormalLarge")

-- -------------------------------------------------------------------
-- Preview area
-- -------------------------------------------------------------------
local previewFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
previewFrame:SetSize(150, 150)
previewFrame:SetPoint("TOPRIGHT", content, "TOPRIGHT", -20, -10)
previewFrame:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = false, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 }
})

local previewLabel = MakeLabel(previewFrame, "Preview", "BOTTOM", 0, -20, "GameFontNormalSmall")

local previewTextures = CreateShapeTextures(previewFrame)

RefreshPreview = function()
  RenderPreview(previewFrame, previewTextures)
end

-- -------------------------------------------------------------------
-- Enable checkbox
-- -------------------------------------------------------------------
local enabled = MakeCheckbox(
  content,
  "Enable crosshair",
  "Enable or disable the addon.",
  function() return DB().enabled end,
  function(v) DB().enabled = v end
)
enabled:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -CONTROL_GAP)

-- -------------------------------------------------------------------
-- Conditions (collapsible)
-- -------------------------------------------------------------------
local condHeader = CreateFrame("Button", nil, content)
condHeader:SetSize(200, 24)
condHeader:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -CONTROL_GAP)
condHeader:SetNormalFontObject("GameFontNormal")
condHeader:SetHighlightFontObject("GameFontHighlight")

local condArrow = condHeader:CreateTexture(nil, "ARTWORK")
condArrow:SetSize(16, 16)
condArrow:SetPoint("LEFT")
condArrow:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")

local condText = condHeader:CreateFontString(nil, "ARTWORK", "GameFontNormal")
condText:SetPoint("LEFT", condArrow, "RIGHT", 4, 0)
condText:SetText("Show Conditions")

-- Spacer frame to manage vertical space when collapsed/expanded
local condSpacer = CreateFrame("Frame", nil, content)
condSpacer:SetPoint("TOPLEFT", condHeader, "BOTTOMLEFT", 0, 0)
condSpacer:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
condSpacer:SetHeight(1)

local condAlways, condParty, condRaid, condCombat

local function RefreshConditionsCollapse()
  local db = DB()
  local collapsed = db.ui and db.ui.conditionsCollapsed
  if collapsed then
    condArrow:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
    if condAlways then condAlways:Hide() end
    if condParty  then condParty:Hide() end
    if condRaid   then condRaid:Hide() end
    if condCombat then condCombat:Hide() end
    -- Collapsed: minimal height so shape appears with proper spacing
    condSpacer:SetHeight(CONTROL_GAP)
  else
    condArrow:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
    if condAlways then condAlways:Show() end
    if condParty  then condParty:Show() end
    if condRaid   then condRaid:Show() end
    if condCombat then condCombat:Show() end
    -- Expanded: height to bottom of last checkbox plus gap before next section
    -- Checkboxes: 8+24+8+24+8+24+8+24 = 128, plus CONTROL_GAP for spacing after
    condSpacer:SetHeight(128 + CONTROL_GAP)
  end
end

condHeader:SetScript("OnClick", function()
  local db = DB()
  if not db.ui then db.ui = {} end
  db.ui.conditionsCollapsed = not db.ui.conditionsCollapsed
  RefreshConditionsCollapse()
end)

condAlways = MakeCheckbox(
  content,
  "Always",
  "Show crosshair at all times.",
  function() return Conditions().always end,
  function(v) Conditions().always = v end
)
condAlways:SetPoint("TOPLEFT", condHeader, "BOTTOMLEFT", 20, -CHECKBOX_GAP)

condParty = MakeCheckbox(
  content,
  "In Party",
  "Show only when in a party (not raid).",
  function() return Conditions().party end,
  function(v) Conditions().party = v end
)
condParty:SetPoint("TOPLEFT", condAlways, "BOTTOMLEFT", 0, -CHECKBOX_GAP)

condRaid = MakeCheckbox(
  content,
  "In Raid",
  "Show only when in a raid.",
  function() return Conditions().raid end,
  function(v) Conditions().raid = v end
)
condRaid:SetPoint("TOPLEFT", condParty, "BOTTOMLEFT", 0, -CHECKBOX_GAP)

condCombat = MakeCheckbox(
  content,
  "In Combat",
  "Show only when in combat (works with above).",
  function() return Conditions().combat end,
  function(v) Conditions().combat = v end
)
condCombat:SetPoint("TOPLEFT", condRaid, "BOTTOMLEFT", 0, -CHECKBOX_GAP)

-- -------------------------------------------------------------------
-- Shape
-- -------------------------------------------------------------------
local shape = MakeDropdown(
  content,
  {
    { text = "Plus (+)", value = "PLUS" },
    { text = "Cross (X)", value = "X" },
    { text = "Chevron Down (V)", value = "CHEVRON_DN" },
    { text = "Chevron Up (^)", value = "CHEVRON_UP" },
  },
  function() return DB().shape or FALLBACKS.shape end,
  function(v) DB().shape = v end
)
shape:SetPoint("TOPLEFT", condSpacer, "BOTTOMLEFT", 0, -CONTROL_GAP)
MakeLabel(content, "Shape", "BOTTOMLEFT", shape, "TOPLEFT", 18, 2)

-- -------------------------------------------------------------------
-- Sliders + Number boxes
-- -------------------------------------------------------------------
local size, sizeBox, sizeBoxLbl
local thickness, thicknessBox, thicknessBoxLbl
local offsetX, offsetXBox, offsetXBoxLbl
local offsetY, offsetYBox, offsetYBoxLbl

size = MakeSlider(content, "Shape Size", 8, 60, 1,
  function() return (DontLoseMeDB and DB().size) or FALLBACKS.size end,
  function(v) DB().size = v end
)
size:SetPoint("TOPLEFT", shape, "BOTTOMLEFT", 0, -CONTROL_GAP)
size:SetWidth(SLIDER_W)

sizeBox, sizeBoxLbl = MakeNumberBox(content, "px", 8, 60,
  function() return DB().size end,
  function(v) DB().size = v end,
  size
)
sizeBox:SetPoint("TOP", size, "BOTTOM", 0, -BOX_GAP)

thickness = MakeSlider(content, "Shape Thickness", 1, 10, 1,
  function() return (DontLoseMeDB and DB().thickness) or FALLBACKS.thickness end,
  function(v) DB().thickness = v end
)
thickness:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -SECTION_GAP)
thickness:SetWidth(SLIDER_W)

thicknessBox, thicknessBoxLbl = MakeNumberBox(content, "px", 1, 10,
  function() return DB().thickness end,
  function(v) DB().thickness = v end,
  thickness
)
thicknessBox:SetPoint("TOP", thickness, "BOTTOM", 0, -BOX_GAP)

offsetX = MakeSlider(content, "Shape Offset X", -300, 300, 1,
  function() return (DontLoseMeDB and DB().offsetX) or FALLBACKS.offsetX end,
  function(v) DB().offsetX = v end
)
offsetX:SetPoint("TOPLEFT", thickness, "BOTTOMLEFT", 0, -SECTION_GAP)
offsetX:SetWidth(SLIDER_W)

offsetXBox, offsetXBoxLbl = MakeNumberBox(content, "px", -300, 300,
  function() return DB().offsetX end,
  function(v) DB().offsetX = v end,
  offsetX
)
offsetXBox:SetPoint("TOP", offsetX, "BOTTOM", 0, -BOX_GAP)

offsetY = MakeSlider(content, "Shape Offset Y", -300, 300, 1,
  function() return (DontLoseMeDB and DB().offsetY) or FALLBACKS.offsetY end,
  function(v) DB().offsetY = v end
)
offsetY:SetPoint("TOPLEFT", offsetX, "BOTTOMLEFT", 0, -SECTION_GAP)
offsetY:SetWidth(SLIDER_W)

offsetYBox, offsetYBoxLbl = MakeNumberBox(content, "px", -300, 300,
  function() return DB().offsetY end,
  function(v) DB().offsetY = v end,
  offsetY
)
offsetYBox:SetPoint("TOP", offsetY, "BOTTOM", 0, -BOX_GAP)

-- -------------------------------------------------------------------
-- Color pickers
-- -------------------------------------------------------------------
local colorBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
colorBtn:SetSize(160, 24)
colorBtn:SetPoint("TOPLEFT", offsetY, "BOTTOMLEFT", 0, -(BOX_GAP + CONTROL_GAP))
colorBtn:SetText("Set Color...")

local swatch = content:CreateTexture(nil, "ARTWORK")
swatch:SetSize(18, 18)
swatch:SetPoint("LEFT", colorBtn, "RIGHT", 12, 0)

local function UpdateSwatch()
  local db = DB()
  swatch:SetColorTexture(
    db.r or FALLBACKS.r,
    db.g or FALLBACKS.g,
    db.b or FALLBACKS.b,
    db.a or FALLBACKS.a
  )
end

colorBtn:SetScript("OnClick", function()
  local db = DB()

  local info = {
    r = db.r or FALLBACKS.r,
    g = db.g or FALLBACKS.g,
    b = db.b or FALLBACKS.b,
    hasOpacity = true,
    opacity = 1 - (db.a or FALLBACKS.a),
    previousValues = { db.r or FALLBACKS.r, db.g or FALLBACKS.g, db.b or FALLBACKS.b, 1 - (db.a or FALLBACKS.a) },
  }

  info.swatchFunc = function()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    local opacity = (OpacitySliderFrame and OpacitySliderFrame:GetValue()) or info.opacity or 0
    db.r, db.g, db.b, db.a = r, g, b, (1 - opacity)
    UpdateSwatch()
    ns.RefreshAll()
    RefreshPreview()
  end
  info.opacityFunc = info.swatchFunc

  info.cancelFunc = function(prev)
    if type(prev) == "table" then
      db.r, db.g, db.b = prev[1], prev[2], prev[3]
      db.a = 1 - (prev[4] or 0)
      UpdateSwatch()
      ns.RefreshAll()
      RefreshPreview()
    end
  end

  ColorPickerFrame:SetupColorPickerAndShow(info)
end)

-- -------------------------------------------------------------------
-- Outline controls
-- -------------------------------------------------------------------
local outlineEnabled, outlineThickness, outlineThicknessBox, outlineThicknessLbl
local outlineColorBtn, outlineSwatch

local function UpdateOutlineSwatch()
  local db = DB()
  outlineSwatch:SetColorTexture(
    db.outlineR or FALLBACKS.outlineR,
    db.outlineG or FALLBACKS.outlineG,
    db.outlineB or FALLBACKS.outlineB,
    db.outlineA or FALLBACKS.outlineA
  )
end

UpdateControlState = function()
  local db = DB()
  -- FIX: Properly check boolean value
  local enabled = (db.outlineEnabled == true)
  
  if outlineThickness then
    if enabled then
      outlineThickness:Enable()
      outlineThickness:SetAlpha(1)
    else
      outlineThickness:Disable()
      outlineThickness:SetAlpha(0.5)
    end
  end
  
  if outlineThicknessBox then
    if enabled then
      outlineThicknessBox:Enable()
      outlineThicknessBox:SetAlpha(1)
    else
      outlineThicknessBox:Disable()
      outlineThicknessBox:SetAlpha(0.5)
    end
  end
  
  if outlineThicknessLbl then
    outlineThicknessLbl:SetAlpha(enabled and 1 or 0.5)
  end
  
  if outlineColorBtn then
    if enabled then
      outlineColorBtn:Enable()
      outlineColorBtn:SetAlpha(1)
    else
      outlineColorBtn:Disable()
      outlineColorBtn:SetAlpha(0.5)
    end
  end
  
  if outlineSwatch then
    outlineSwatch:SetAlpha(enabled and 1 or 0.5)
  end
end

outlineEnabled = MakeCheckbox(
  content,
  "Enable outline",
  "Draw a separate outline behind the shape.",
  function()
    local db = DB()
    -- FIX: Return proper boolean
    return db.outlineEnabled == true
  end,
  function(v)
    local db = DB()
    -- FIX: Store as proper boolean
    db.outlineEnabled = v and true or false
    UpdateOutlineSwatch()
    UpdateControlState()
    ns.RefreshAll()
    RefreshPreview()
  end
)
outlineEnabled:SetPoint("TOPLEFT", colorBtn, "BOTTOMLEFT", 0, -CONTROL_GAP)

outlineThickness = MakeSlider(content, "Outline Thickness", 1, 10, 1,
  function() return DB().outlineThickness or FALLBACKS.outlineThickness end,
  function(v) DB().outlineThickness = v end
)
outlineThickness:SetPoint("TOPLEFT", outlineEnabled, "BOTTOMLEFT", 0, -CHECKBOX_GAP)
outlineThickness:SetWidth(SLIDER_W)

outlineThicknessBox, outlineThicknessLbl = MakeNumberBox(content, "px", 1, 10,
  function() return DB().outlineThickness or FALLBACKS.outlineThickness end,
  function(v) DB().outlineThickness = v end,
  outlineThickness
)
outlineThicknessBox:SetPoint("TOP", outlineThickness, "BOTTOM", 0, -BOX_GAP)

outlineColorBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
outlineColorBtn:SetSize(160, 24)
outlineColorBtn:SetText("Set Outline Color...")
outlineColorBtn:ClearAllPoints()
-- Anchor to the slider with consistent spacing
outlineColorBtn:SetPoint("TOPLEFT", outlineThickness, "BOTTOMLEFT", 0, -(BOX_GAP + CONTROL_GAP))

outlineSwatch = content:CreateTexture(nil, "ARTWORK")
outlineSwatch:SetSize(18, 18)
outlineSwatch:SetPoint("LEFT", outlineColorBtn, "RIGHT", 12, 0)

outlineColorBtn:SetScript("OnClick", function()
  local db = DB()

  local info = {
    r = db.outlineR or FALLBACKS.outlineR,
    g = db.outlineG or FALLBACKS.outlineG,
    b = db.outlineB or FALLBACKS.outlineB,
    hasOpacity = true,
    opacity = 1 - (db.outlineA or FALLBACKS.outlineA),
    previousValues = {
      db.outlineR or FALLBACKS.outlineR,
      db.outlineG or FALLBACKS.outlineG,
      db.outlineB or FALLBACKS.outlineB,
      1 - (db.outlineA or FALLBACKS.outlineA),
    },
  }

  info.swatchFunc = function()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    local opacity = (OpacitySliderFrame and OpacitySliderFrame:GetValue()) or info.opacity or 0

    db.outlineR = r
    db.outlineG = g
    db.outlineB = b
    db.outlineA = 1 - opacity

    UpdateOutlineSwatch()
    ns.RefreshAll()
    RefreshPreview()
  end
  info.opacityFunc = info.swatchFunc

  info.cancelFunc = function(prev)
    if type(prev) == "table" then
      db.outlineR = prev[1]
      db.outlineG = prev[2]
      db.outlineB = prev[3]
      db.outlineA = 1 - (prev[4] or 0)

      UpdateOutlineSwatch()
      ns.RefreshAll()
      RefreshPreview()
    end
  end

  ColorPickerFrame:SetupColorPickerAndShow(info)
end)

-- -------------------------------------------------------------------
-- Scroll height calculation
-- -------------------------------------------------------------------
local UpdateScrollHeight = function()
  local last = outlineColorBtn or colorBtn
  local bottom = last and last:GetBottom()
  local top = header and header:GetTop()

  if bottom and top then
    local h = (top - bottom) + 60
    if h < 1 then h = 1 end
    content:SetHeight(h)
  else
    content:SetHeight(900)
  end
end

-- -------------------------------------------------------------------
-- OnShow / resizing
-- -------------------------------------------------------------------
panel:SetScript("OnShow", function()
  EnsureUIState()
  EnsureOutline()

  RefreshConditionsCollapse()

  if enabled then enabled:Refresh() end
  if condAlways then condAlways:Refresh() end
  if condParty  then condParty:Refresh() end
  if condRaid   then condRaid:Refresh() end
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

  if outlineThickness then outlineThickness:Refresh() end
  if outlineThicknessBox then outlineThicknessBox:Refresh() end
  if outlineEnabled then outlineEnabled:Refresh() end

  UpdateSwatch()
  UpdateOutlineSwatch()
  UpdateControlState()
  UpdateScrollHeight()
  RefreshPreview()
end)

panel:SetScript("OnSizeChanged", function()
  if UpdateScrollHeight then UpdateScrollHeight() end
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