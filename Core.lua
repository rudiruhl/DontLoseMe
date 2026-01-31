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
-- Database handling (PER CHARACTER)
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

-- IMPORTANT: Initialize per-character DB
-- DontLoseMeDB will now be a table with character-specific entries
local function InitDB()
  -- Create global table structure if it doesn't exist
  if type(DontLoseMeDB) ~= "table" then
    DontLoseMeDB = {}
  end
  
  -- Get character-specific key
  local realm = GetRealmName()
  local name = UnitName("player")
  local charKey = name .. "-" .. realm
  
  -- Initialize this character's settings if they don't exist
  if type(DontLoseMeDB[charKey]) ~= "table" then
    DontLoseMeDB[charKey] = CopyDefaults(defaults, {})
  else
    -- Apply defaults for any missing keys
    DontLoseMeDB[charKey] = CopyDefaults(defaults, DontLoseMeDB[charKey])
  end
  
  -- Create easy accessor
  ns.db = DontLoseMeDB[charKey]
  
  return ns.db
end

-- Will be called on PLAYER_LOGIN
local function PerformMigrations()
  local db = ns.db
  
  -- Migration: old single-mode -> conditions table
  if db.mode and (not db.conditions or type(db.conditions) ~= "table") then
    db.conditions = {
      always = db.mode == "ALWAYS",
      party  = db.mode == "PARTY",
      raid   = db.mode == "RAID",
      combat = false,
    }
    db.mode = nil
  end

  -- Migration: old outline keys (or_/og/ob/oa) -> outlineR/G/B/A
  if db.or_ ~= nil or db.og ~= nil or db.ob ~= nil or db.oa ~= nil then
    if db.outlineR == nil and db.or_ ~= nil then db.outlineR = db.or_ end
    if db.outlineG == nil and db.og ~= nil then db.outlineG = db.og end
    if db.outlineB == nil and db.ob ~= nil then db.outlineB = db.ob end
    if db.outlineA == nil and db.oa ~= nil then db.outlineA = db.oa end
    db.or_, db.og, db.ob, db.oa = nil, nil, nil, nil
  end

  -- Ensure all condition fields exist
  do
    local c = db.conditions
    if type(c) ~= "table" then
      db.conditions = CopyDefaults(defaults.conditions, {})
      c = db.conditions
    end
    if c.always == nil then c.always = true end
    if c.party  == nil then c.party  = false end
    if c.raid   == nil then c.raid   = false end
    if c.combat == nil then c.combat = false end
  end
  
  -- FIX: Ensure outlineEnabled is properly set as boolean
  if db.outlineEnabled == nil then
    db.outlineEnabled = defaults.outlineEnabled
  else
    -- Convert to proper boolean if it's stored as number or anything else
    db.outlineEnabled = db.outlineEnabled and true or false
  end
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
  local db = ns.db
  if not db then return end

  Root:ClearAllPoints()
  Root:SetPoint("CENTER", UIParent, "CENTER", db.offsetX or 0, db.offsetY or 0)

  local size  = tonumber(db.size) or defaults.size
  local thick = tonumber(db.thickness) or defaults.thickness
  local shape = db.shape or defaults.shape

  -- Main color
  local r, g, b, a = db.r or 1, db.g or 1, db.b or 1, db.a or 1

  -- Outline settings - FIX: properly read boolean value
  local outlineOn = (db.outlineEnabled == true)
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
    local gap = math.max(6, size * 0.6)  -- Scale gap with size to prevent crossing

    local yTop = gap
    local yBot = -gap

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
  local db = ns.db
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
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")

local isInitialized = false

ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    -- Initialize per-character database
    InitDB()
    
  elseif event == "PLAYER_LOGIN" then
    -- Perform migrations after DB is fully loaded
    PerformMigrations()
    isInitialized = true
    ns.RefreshAll()
    
  elseif event == "PLAYER_ENTERING_WORLD" then
    if isInitialized then
      ns.RefreshAll()
    end
    
  elseif event == "GROUP_ROSTER_UPDATE" then
    if isInitialized then
      RefreshVisibility()
    end
    
  elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
    if isInitialized then
      RefreshVisibility()
    end
  end
end)