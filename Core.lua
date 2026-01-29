-- DontLoseMe - Core.lua
local ADDON, ns = ...

-- -------------------------------------------------------------------
-- Default settings
-- -------------------------------------------------------------------
local defaults = {
  enabled = true,

  conditions = {
    always = true,
    party  = false,
    raid   = false,
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
  outlineR = 0, outlineG = 0, outlineB = 0, outlineA = 1,
}

-- -------------------------------------------------------------------
-- Database handling
-- -------------------------------------------------------------------
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

-- Migration: old single-mode -> conditions table
if DontLoseMeDB.mode and (not DontLoseMeDB.conditions or type(DontLoseMeDB.conditions) ~= "table") then
  DontLoseMeDB.conditions = {
    always = DontLoseMeDB.mode == "ALWAYS",
    party  = DontLoseMeDB.mode == "PARTY",
    raid   = DontLoseMeDB.mode == "RAID",
    combat = false,
  }
  DontLoseMeDB.mode = nil
end

-- Migration: old outline keys (or_/og/ob/oa) -> outlineR/G/B/A
if DontLoseMeDB.or_ ~= nil or DontLoseMeDB.og ~= nil or DontLoseMeDB.ob ~= nil or DontLoseMeDB.oa ~= nil then
  if DontLoseMeDB.outlineR == nil and DontLoseMeDB.or_ ~= nil then DontLoseMeDB.outlineR = DontLoseMeDB.or_ end
  if DontLoseMeDB.outlineG == nil and DontLoseMeDB.og ~= nil then DontLoseMeDB.outlineG = DontLoseMeDB.og end
  if DontLoseMeDB.outlineB == nil and DontLoseMeDB.ob ~= nil then DontLoseMeDB.outlineB = DontLoseMeDB.ob end
  if DontLoseMeDB.outlineA == nil and DontLoseMeDB.oa ~= nil then DontLoseMeDB.outlineA = DontLoseMeDB.oa end
  DontLoseMeDB.or_, DontLoseMeDB.og, DontLoseMeDB.ob, DontLoseMeDB.oa = nil, nil, nil, nil
end

-- Ensure all condition fields exist
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

-- -------------------------------------------------------------------
-- Shape textures
-- -------------------------------------------------------------------
local function NewBar(layer)
  local t = Root:CreateTexture(nil, layer or "OVERLAY")
  t:SetColorTexture(1, 1, 1, 1)
  return t
end

-- Store all bars in one table so we can hide/apply colors easily
local T = {
  -- Outline (BACKGROUND)
  o_plusH = NewBar("BACKGROUND"),
  o_plusV = NewBar("BACKGROUND"),
  o_xA    = NewBar("BACKGROUND"),
  o_xB    = NewBar("BACKGROUND"),
  o_ch1A  = NewBar("BACKGROUND"),
  o_ch1B  = NewBar("BACKGROUND"),
  o_ch2A  = NewBar("BACKGROUND"),
  o_ch2B  = NewBar("BACKGROUND"),

  -- Main (OVERLAY)
  plusH = NewBar("OVERLAY"),
  plusV = NewBar("OVERLAY"),
  xA    = NewBar("OVERLAY"),
  xB    = NewBar("OVERLAY"),
  ch1A  = NewBar("OVERLAY"),
  ch1B  = NewBar("OVERLAY"),
  ch2A  = NewBar("OVERLAY"),
  ch2B  = NewBar("OVERLAY"),
}

local function HideAllShapes()
  for _, tex in pairs(T) do
    tex:Hide()
  end
end

local function ApplyColors(mainR, mainG, mainB, mainA, outR, outG, outB, outA)
  -- Main
  T.plusH:SetColorTexture(mainR, mainG, mainB, mainA)
  T.plusV:SetColorTexture(mainR, mainG, mainB, mainA)
  T.xA:SetColorTexture(mainR, mainG, mainB, mainA)
  T.xB:SetColorTexture(mainR, mainG, mainB, mainA)
  T.ch1A:SetColorTexture(mainR, mainG, mainB, mainA)
  T.ch1B:SetColorTexture(mainR, mainG, mainB, mainA)
  T.ch2A:SetColorTexture(mainR, mainG, mainB, mainA)
  T.ch2B:SetColorTexture(mainR, mainG, mainB, mainA)

  -- Outline
  T.o_plusH:SetColorTexture(outR, outG, outB, outA)
  T.o_plusV:SetColorTexture(outR, outG, outB, outA)
  T.o_xA:SetColorTexture(outR, outG, outB, outA)
  T.o_xB:SetColorTexture(outR, outG, outB, outA)
  T.o_ch1A:SetColorTexture(outR, outG, outB, outA)
  T.o_ch1B:SetColorTexture(outR, outG, outB, outA)
  T.o_ch2A:SetColorTexture(outR, outG, outB, outA)
  T.o_ch2B:SetColorTexture(outR, outG, outB, outA)
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
  local dx = armLen * 0.35
  PlaceOutlined(outA, texA, -dx, y, armLen, thickness, leftRot,  outlineOn, outlineThickness)
  PlaceOutlined(outB, texB,  dx, y, armLen, thickness, rightRot, outlineOn, outlineThickness)
end

-- -------------------------------------------------------------------
-- Layout
-- -------------------------------------------------------------------
local function ApplyLayout()
  local db = DontLoseMeDB
  if not db then return end

  Root:ClearAllPoints()
  Root:SetPoint("CENTER", UIParent, "CENTER", db.offsetX or 0, db.offsetY or 0)

  local size  = tonumber(db.size) or defaults.size
  local thick = tonumber(db.thickness) or defaults.thickness
  local shape = db.shape or defaults.shape

  -- Main color
  local r, g, b, a = db.r or 1, db.g or 1, db.b or 1, db.a or 1

  -- Outline settings
  local outlineOn = db.outlineEnabled and true or false
  local oT = tonumber(db.outlineThickness) or defaults.outlineThickness
  if oT < 1 then oT = 1 end
  if oT > 10 then oT = 10 end

  local outR = db.outlineR
  local outG = db.outlineG
  local outB = db.outlineB
  local outA = db.outlineA
  if outR == nil then outR = defaults.outlineR end
  if outG == nil then outG = defaults.outlineG end
  if outB == nil then outB = defaults.outlineB end
  if outA == nil then outA = defaults.outlineA end

  Root:SetSize(size, size)
  ApplyColors(r, g, b, a, outR, outG, outB, outA)

  HideAllShapes()

  if shape == "X" then
    PlaceOutlined(T.o_xA, T.xA, 0, 0, size, thick, math.rad(45),  outlineOn, oT)
    PlaceOutlined(T.o_xB, T.xB, 0, 0, size, thick, math.rad(-45), outlineOn, oT)

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

    PlaceV(T.o_ch1A, T.o_ch1B, T.ch1A, T.ch1B, yTop, armLen, thick, leftRot, rightRot, outlineOn, oT)
    PlaceV(T.o_ch2A, T.o_ch2B, T.ch2A, T.ch2B, yBot, armLen, thick, leftRot, rightRot, outlineOn, oT)

  else
    -- PLUS default
    PlaceOutlined(T.o_plusH, T.plusH, 0, 0, size, thick, 0, outlineOn, oT)
    PlaceOutlined(T.o_plusV, T.plusV, 0, 0, thick, size, 0, outlineOn, oT)
  end
end

-- -------------------------------------------------------------------
-- Visibility handling
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

-- -------------------------------------------------------------------
-- Event handling
-- -------------------------------------------------------------------
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