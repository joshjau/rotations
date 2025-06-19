--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local _, HL   = ...
-- HeroLib
local Unit            = HL.Unit
local Player          = Unit.Player

-- Base API locals
local GetInstanceInfo = GetInstanceInfo
-- Accepts: nil
-- Returns: name (string), instanceType (string), difficultyID (number), difficultyName (string), maxPlayers (number)
-- dynamicDifficulty (number), isDynamic (bool), instanceID (number), instanceGroupSize (number), LfgDungeonID (number)
local GetNetStats     = GetNetStats
-- Accepts: nil; Returns: bandwidthIn (number), bandwidthOut (number), latencyHome (number), latencyWorld (number)
-- Note: Latency values are updated every 30 seconds

-- Lua locals
local CreateFrame     = CreateFrame
local GetTime         = GetTime
local UIParent        = UIParent
local mathmax         = math.max
local select          = select
local C_Timer         = C_Timer


--- ============================ CONTENT ============================
-- Get the Instance Informations
-- TODO: Cache it in Persistent Cache and update it only when it changes
-- @returns name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, LfgDungeonID
-- name - Localized name of the instance, or continent name if not in an instance (string)
-- instanceType - Instance category: "none", "scenario", "party", "raid", "arena", "pvp" (string)
-- difficultyID - DifficultyID of the instance (0 if not in instance) (number)
-- difficultyName - Localized difficulty name ("10 Player", "25 Player (Heroic)", etc.) (string)
-- maxPlayers - Maximum number of players permitted in the instance (number)
-- dynamicDifficulty - Dynamic difficulty (deprecated, always returns 0) (number)
-- isDynamic - Whether instance difficulty can be changed while zoned in (boolean)
-- instanceID - InstanceID for the instance or continent (number)
-- instanceGroupSize - Number of players in your instance group (number)
-- LfgDungeonID - LfgDungeonID if in dungeon finder group, nil otherwise (number)
function HL.GetInstanceInfo(Index)
  if Index then
    local Result = select(Index, GetInstanceInfo())
    return Result
  end
  return GetInstanceInfo()
end

-- Get the Instance Difficulty Infos
-- @returns difficultyID - Difficulty setting of the instance (number)
-- Classic Difficulties:
-- 0 - None (not in an Instance)
-- 1 - 5-player Normal Instance
-- 2 - 5-player Heroic Instance
-- 3 - 10-player Raid Instance
-- 4 - 25-player Raid Instance
-- 5 - 10-player Heroic Raid Instance
-- 6 - 25-player Heroic Raid Instance
-- 7 - 25-player Raid Finder Instance
-- 8 - Challenge Mode Instance (MoP)
-- 9 - 40-player Raid Instance
-- 11 - Heroic Scenario Instance
-- 12 - Normal Scenario Instance
-- Modern Difficulties:
-- 14 - 10-30-player Normal Raid Instance (Flexible Normal)
-- 15 - 10-30-player Heroic Raid Instance (Flexible Heroic)
-- 16 - 20-player Mythic Raid Instance
-- 17 - 10-30-player Raid Finder Instance (Flexible LFR)
-- 18 - 40-player Event raid (e.g., MC Anniversary)
-- 19 - 5-player Event instance (e.g., UBRS)
-- 20 - 25-player Event scenario
-- 23 - Mythic 5-player Instance (Mythic+)
-- 24 - Timewalker 5-player Instance
-- 33 - Timewalker Raid Instance
-- 151 - 5-player Follower Dungeon
function HL.GetInstanceDifficulty()
  return HL.GetInstanceInfo(3)
end

-- Get the time since combat has started.
function HL.CombatTime()
  return HL.CombatStarted ~= 0 and GetTime() - HL.CombatStarted or 0
end

do
  -- Advanced Latency Tracking System
  -- Tracks both home and world latency separately with rolling average smoothing
  -- Benefits:
  -- 1. Rolling average prevents rotation jitter from latency spikes
  -- 2. Separate home/world tracking useful for Oceanic players on US realms
  -- 3. 1-second updates provide real-time responsiveness (vs WoW's 30s updates)
  -- 4. Smoothed world latency used for combat timing, raw values for diagnostics
  local LatencySamples = {}
  local LatencyIndex = 1
  local LatencyCount = 0
  local LATENCY_WINDOW = 5 -- Rolling average window
  local Latency = 0 -- Smoothed world latency average
  local LastHomeLatency = 0 -- Raw home latency
  local LastWorldLatency = 0 -- Raw world latency
  
  local function UpdateLatency()
    local _, _, lagHome, lagWorld = GetNetStats()
    LastHomeLatency = lagHome / 1000 -- Convert from ms to seconds
    LastWorldLatency = lagWorld / 1000 -- Convert from ms to seconds
    
    -- Update rolling average for world latency (used for combat timing)
    local current = LastWorldLatency
    LatencySamples[LatencyIndex] = current
    LatencyIndex = (LatencyIndex % LATENCY_WINDOW) + 1
    
    if LatencyCount < LATENCY_WINDOW then
      LatencyCount = LatencyCount + 1
    end
    
    -- Calculate smoothed average
    local sum = 0
    for i = 1, LatencyCount do 
      sum = sum + LatencySamples[i] 
    end
    Latency = sum / LatencyCount
  end
  
  -- Initialize with current latency
  UpdateLatency()
  local initial = LastWorldLatency
  for i = 1, LATENCY_WINDOW do
    LatencySamples[i] = initial
  end
  LatencyCount = LATENCY_WINDOW
  Latency = initial
  
  -- Update every second for responsive latency tracking
  local LatencyFrame = CreateFrame("Frame", "HeroLib_LatencyFrame", UIParent)
  local LatencyFrameNextUpdate = 0
  local LatencyFrameUpdateFrequency = 1 -- 1 second for real-time responsiveness
  LatencyFrame:SetScript(
    "OnUpdate",
    function ()
      if GetTime() <= LatencyFrameNextUpdate then return end
      LatencyFrameNextUpdate = GetTime() + LatencyFrameUpdateFrequency
      UpdateLatency()
    end
  )
  
  -- Main latency function - returns smoothed world latency combined with home latency for optimal combat timing
  -- Uses world latency (affects combat data) but ensures we don't underestimate total lag
  function HL.Latency()
    -- Use the higher of smoothed world latency or raw home latency
    -- This accounts for cases where home connection issues might affect overall responsiveness
    return mathmax(Latency, LastHomeLatency)
  end

  -- Get the recovery timer based the remaining time of the GCD or the current cast (whichever is higher) in order to improve prediction.
  function HL.RecoveryTimer()
    local CastRemains = Player:CastRemains()
    local GCDRemains = Player:GCDRemains()
    return mathmax(GCDRemains, CastRemains)
  end

  -- Compute the Recovery Offset with Lag Compensation.
  -- Bypass is there in case we want to ignore it (instead of handling this bypass condition in every method the offset is called)
  function HL.RecoveryOffset(Bypass)
    if (Bypass) then return 0 end

    return HL.Latency() + HL.RecoveryTimer()
  end
end
