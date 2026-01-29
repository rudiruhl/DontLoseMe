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

  r = 1, g = 1, b = 1, a = 0.9,
  offsetX = 0,
  offsetY = 0,
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

if DontLoseMeDB.mode and (not DontLoseMeDB.conditions or type(DontLoseMeDB.conditions) ~= "table") then
  DontLoseMeDB.conditions = {
    always = DontLoseMeDB.mode == "ALWAYS",
    party  = DontLoseMeDB.mode == "PARTY",
    raid   = DontLoseMeDB.mode == "RAID",
    combat = false,
  }
  DontLoseMeDB.mode = nil
end

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

-- PLUS (+) pieces
local plusH = Root:CreateTexture(nil, "OVERLAY")
local plusV = Root:CreateTexture(nil, "OVERLAY")
plusH:SetColorTexture(1, 1, 1, 1)
plusV:SetColorTexture(1, 1, 1, 1)

-- X pieces (diagonals)
local xA = Root:CreateTexture(nil, "OVERLAY")
local xB = Root:CreateTexture(nil, "OVERLAY")
xA:SetColorTexture(1, 1, 1, 1)
xB:SetColorTexture(1, 1, 1, 1)

-- Double chevrons
local ch1A = Root:CreateTexture(nil, "OVERLAY")
local ch1B = Root:CreateTexture(nil, "OVERLAY")
local ch2A = Root:CreateTexture(nil, "OVERLAY")
local ch2B = Root:CreateTexture(nil, "OVERLAY")
ch1A:SetColorTexture(1,1,1,1)
ch1B:SetColorTexture(1,1,1,1)
ch2A:SetColorTexture(1,1,1,1)
ch2B:SetColorTexture(1,1,1,1)


local function HideAllShapes()
  plusH:Hide(); plusV:Hide()
  xA:Hide(); xB:Hide()
  ch1A:Hide(); ch1B:Hide();
  ch2A:Hide(); ch2B:Hide()
end

local function ApplyColor(r, g, b, a)
  plusH:SetColorTexture(r, g, b, a)
  plusV:SetColorTexture(r, g, b, a)
  xA:SetColorTexture(r, g, b, a)
  xB:SetColorTexture(r, g, b, a)

  ch1A:SetColorTexture(r, g, b, a)
  ch1B:SetColorTexture(r, g, b, a)
  ch2A:SetColorTexture(r, g, b, a)
  ch2B:SetColorTexture(r, g, b, a)
end

local function PlaceV(texA, texB, y, armLen, thickness, leftRot, rightRot)

  local dx = armLen * 0.35

  texA:ClearAllPoints()
  texA:SetPoint("CENTER", Root, "CENTER", -dx, y)
  texA:SetSize(armLen, thickness)
  texA:SetRotation(leftRot)
  texA:Show()

  texB:ClearAllPoints()
  texB:SetPoint("CENTER", Root, "CENTER", dx, y)
  texB:SetSize(armLen, thickness)
  texB:SetRotation(rightRot)
  texB:Show()  
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
  ApplyColor(r, g, b, a)

  HideAllShapes()

  if shape == "X" then
    xA:ClearAllPoints()
    xA:SetPoint("CENTER", Root, "CENTER", 0, 0)
    xA:SetSize(size, t)
    xA:SetRotation(math.rad(45))
    xA:Show()

    xB:ClearAllPoints()
    xB:SetPoint("CENTER", Root, "CENTER", 0, 0)
    xB:SetSize(size, t)
    xB:SetRotation(math.rad(-45))
    xB:Show()

  elseif shape == "CHEVRON_DN" or shape == "CHEVRON_UP" then
    -- Geometry
    local angle = math.rad(35)
    local armLen = size
    local gap = math.max(2, t*2)

    -- stacked offset
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

    PlaceV(ch1A, ch1B, yTop, armLen, t, leftRot, rightRot)
    PlaceV(ch2A, ch2B, yBot, armLen, t, leftRot, rightRot)
  else

    plusH:ClearAllPoints()
    plusH:SetPoint("CENTER", Root, "CENTER", 0, 0)
    plusH:SetSize(size, t)
    plusH:Show()

    plusV:ClearAllPoints()
    plusV:SetPoint("CENTER", Root, "CENTER", 0, 0)
    plusV:SetSize(t, size)
    plusV:Show()
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

  -- If none of Always/Party/Raid selected -> show nowhere (options auto-disables enabled anyway)
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

