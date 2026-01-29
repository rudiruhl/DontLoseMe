-- DontLoseMe - Core.lua
local ADDON, ns = ...

local defaults = {
  enabled = true,

  conditions = {
    always = true,
    party = false,
    raid = false,
    combat = false,
  },

  shape = "PLUS",
  size = 18,
  thickness = 2,

  -- Main color
  r = 1, g = 1, b = 1, a = 0.9,

  -- Position
  offsetX = 0,
  offsetY = 0,

  -- Outline
  outlineEnabled = false,
  outlineThickness = 2,
  or_ = 0, og = 0, ob = 0, oa = 1,
}

local function CopyDefaults(src, dst)
  if type(dst) ~= "table" then dst = {} end
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = CopyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

-- DB must exist immediately
DontLoseMeDB = CopyDefaults(defaults, DontLoseMeDB or {})

-- Migration from old single mode field
if DontLoseMeDB.mode and (not DontLoseMeDB.conditions or type(DontLoseMeDB.conditions) ~= "table") then
  DontLoseMeDB.conditions = {
    always = DontLoseMeDB.mode == "ALWAYS",
    party  = DontLoseMeDB.mode == "PARTY",
    raid   = DontLoseMeDB.mode == "RAID",
    combat = false,
  }
  DontLoseMeDB.mode = nil
end

-- Ensure conditions keys exist
do
  local c = DontLoseMeDB.conditions
  if type(c) ~= "table" then
    DontLoseMeDB.conditions = CopyDefaults(defaults.conditions, {})
    c = DontLoseMeDB.conditions
  end
  if c.always == nil then c.always = true end
  if c.party  == nil then c.party  = false end
  if c.raid   == nil then c.raid   = false end
  if c.combat == nil then c.combat = false end
end

-- -------------------------------------------------------------------
-- Crosshair frame
-- -------------------------------------------------------------------
local Root = CreateFrame("Frame", "DontLoseMeFrame", UIParent)
Root:SetFrameStrata("MEDIUM") -- not above dialogs/settings
Root:SetFrameLevel(10)
Root:EnableMouse(false)
Root:SetClampedToScreen(true)

-- Helper to create a bar texture
local function NewBar(layer)
  local t = Root:CreateTexture(nil, layer or "OVERLAY")
  t:SetColorTexture(1, 1, 1, 1)
  return t
end

-- Outline bars (BACKGROUND) - drawn behind the main bars
local o_plusH = NewBar("BACKGROUND")
local o_plusV = NewBar("BACKGROUND")
local o_xA    = NewBar("BACKGROUND")
local o_xB    = NewBar("BACKGROUND")
local o_ch1A  = NewBar("BACKGROUND")
local o_ch1B  = NewBar("BACKGROUND")
local o_ch2A  = NewBar("BACKGROUND")
local o_ch2B  = NewBar("BACKGROUND")

-- Main bars (OVERLAY)
local plusH = NewBar("OVERLAY")
local plusV = NewBar("OVERLAY")
local xA    = NewBar("OVERLAY")
local xB    = NewBar("OVERLAY")
local ch1A  = NewBar("OVERLAY")
local ch1B  = NewBar("OVERLAY")
local ch2A  = NewBar("OVERLAY")
local ch2B  = NewBar("OVERLAY")

local function HideAllShapes()
  -- Outline
  o_plusH:Hide(); o_plusV:Hide()
  o_xA:Hide(); o_xB:Hide()
  o_ch1A:Hide(); o_ch1B:Hide()
  o_ch2A:Hide(); o_ch2B:Hide()

  -- Main
  plusH:Hide(); plusV:Hide()
  xA:Hide(); xB:Hide()
  ch1A:Hide(); ch1B:Hide()
  ch2A:Hide(); ch2B:Hide()
end

local function ApplyColors(mainR, mainG, mainB, mainA, outR, outG, outB, outA)
  -- Main
  plusH:SetColorTexture(mainR, mainG, mainB, mainA)
  plusV:SetColorTexture(mainR, mainG, mainB, mainA)
  xA:SetColorTexture(mainR, mainG, mainB, mainA)
  xB:SetColorTexture(mainR, mainG, mainB, mainA)
  ch1A:SetColorTexture(mainR, mainG, mainB, mainA)
  ch1B:SetColorTexture(mainR, mainG, mainB, mainA)
  ch2A:SetColorTexture(mainR, mainG, mainB, mainA)
  ch2B:SetColorTexture(mainR, mainG, mainB, mainA)

  -- Outline
  o_plusH:SetColorTexture(outR, outG, outB, outA)
  o_plusV:SetColorTexture(outR, outG, outB, outA)
  o_xA:SetColorTexture(outR, outG, outB, outA)
  o_xB:SetColorTexture(outR, outG, outB, outA)
  o_ch1A:SetColorTexture(outR, outG, outB, outA)
  o_ch1B:SetColorTexture(outR, outG, outB, outA)
  o_ch2A:SetColorTexture(outR, outG, outB, outA)
  o_ch2B:SetColorTexture(outR, outG, outB, outA)
end

local function PlaceBar(tex, cx, cy, w, h, rot)
  tex:ClearAllPoints()
  tex:SetPoint("CENTER", Root, "CENTER", cx, cy)
  tex:SetSize(w, h)
  tex:SetRotation(rot or 0)
  tex:Show()
end

local function PlaceOutlined(outTex, mainTex, cx, cy, w, h, rot, outlineOn, outlineThickness)
  if outlineOn then
    PlaceBar(outTex, cx, cy, w + outlineThickness * 2, h + outlineThickness * 2, rot)
  else
    outTex:Hide()
  end
  PlaceBar(mainTex, cx, cy, w, h, rot)
end

local function PlaceV(outA, outB, texA, texB, y, armLen, thickness, leftRot, rightRot, outlineOn, outlineThickness)
  local dx = armLen * 0.35 -- horizontal offset

  PlaceOutlined(outA, texA, -dx, y, armLen, thickness, leftRot, outlineOn, outlineThickness)
  PlaceOutlined(outB, texB,  dx, y, armLen, thickness, rightRot, outlineOn, outlineThickness)
end

local function ApplyLayout()
  local db = DontLoseMeDB
  if not db then return end

  Root:ClearAllPoints()
  Root:SetPoint("CENTER", UIParent, "CENTER", db.offsetX or 0, db.offsetY or 0)

  local size = tonumber(db.size) or defaults.size
  local t = tonumber(db.thickness) or defaults.thickness
  local shape = db.shape or defaults.shape

  Root:SetSize(size, size)

  local r, g, b, a = db.r or 1, db.g or 1, db.b or 1, db.a or 1

  local outlineOn = db.outlineEnabled and true or false
  local oT = tonumber(db.outlineThickness) or defaults.outlineThickness
  if oT < 1 then oT = 1 end
  if oT > 10 then oT = 10 end

  local or_, og, ob, oa = db.or_ or defaults.or_, db.og or defaults.og, db.ob or defaults.ob, db.oa or defaults.oa
  ApplyColors(r, g, b, a, or_, og, ob, oa)

  HideAllShapes()

  if shape == "X" then
    PlaceOutlined(o_xA, xA, 0, 0, size, t, math.rad(45),  outlineOn, oT)
    PlaceOutlined(o_xB, xB, 0, 0, size, t, math.rad(-45), outlineOn, oT)

  elseif shape == "CHEVRON_DN" or shape == "CHEVRON_UP" then
    local angle = math.rad(35)
    local armLen = size
    local gap = math.max(2, t * 2)

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

    PlaceV(o_ch1A, o_ch1B, ch1A, ch1B, yTop, armLen, t, leftRot, rightRot, outlineOn, oT)
    PlaceV(o_ch2A, o_ch2B, ch2A, ch2B, yBot, armLen, t, leftRot, rightRot, outlineOn, oT)

  else
    -- PLUS default
    PlaceOutlined(o_plusH, plusH, 0, 0, size, t, 0, outlineOn, oT)
    PlaceOutlined(o_plusV, plusV, 0, 0, t, size, 0, outlineOn, oT)
  end
end

-- -------------------------------------------------------------------
-- Visibility logic based on conditions (multi-select)
-- -------------------------------------------------------------------
local function AnyContextSelected(c)
  return (c.always or c.party or c.raid) and true or false
end

local function ShouldShow()
  local db = DontLoseMeDB
  if not db or not db.enabled then return false end

  local c = db.conditions or defaults.conditions

  local inGroup = IsInGroup()
  local inRaid  = IsInRaid()
  local inParty = inGroup and not inRaid

  if not AnyContextSelected(c) then
    return false
  end

  local contextOK
  if c.always then
    contextOK = true
  else
    contextOK = (c.party and inParty) or (c.raid and inRaid)
  end

  if c.combat then
    contextOK = contextOK and InCombatLockdown()
  end

  return contextOK
end

local function RefreshVisibility()
  if ShouldShow() then
    Root:Show()
  else
    Root:Hide()
  end
end

function ns.RefreshAll()
  ApplyLayout()
  RefreshVisibility()
end

-- Refresh on relevant events
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")

ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" then
    ns.RefreshAll()
  elseif event == "GROUP_ROSTER_UPDATE" then
    RefreshVisibility()
  elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
    RefreshVisibility()
  end
end)
