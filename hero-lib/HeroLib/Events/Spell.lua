--- ============================ HEADER ============================
---
--- hero-lib/HeroLib/Events/Spell.lua
---
--- This file is responsible for high-fidelity spell event tracking. It enhances
--- the base combat log events by incorporating network latency compensation,
--- spell queue window adjustments, and failure tracking (e.g., interrupts,
--- out of range) to provide the rotation logic with the most accurate
--- possible state of the player's abilities.
---
--- ============================ HEADER ============================

--- ======= LOCALIZE =======
-- Addon
local _, HL                  = ...
-- HeroLib
local Unit                   = HL.Unit
local Player                 = Unit.Player
local Spell                  = HL.Spell
local MultiSpell             = HL.MultiSpell
local Item                   = HL.Item

-- Lua locals
local pairs                  = pairs
local ipairs                 = ipairs
local tableinsert            = table.insert
local GetTime                = GetTime
local mathmax                = math.max
local CreateFrame            = CreateFrame

-- File Locals
local PlayerSpecs            = {}
local ListenedSpells         = {}
local ListenedItemSpells     = {}
local ListenedSpecItemSpells = {}
local MultiSpells            = {}
local Custom = {
  Whitelist = {},
  Blacklist = {}
}

---
--- Advanced spell tracking variables for optimal rotation accuracy.
---
local SpellQueueWindow       = 0.4  -- WoW's default spell queue window (400ms).
local LastGCDEnd             = 0    -- Tracks the timestamp of the last detected GCD completion.
local FailedCasts            = {}   -- Tracks recently failed spells to prevent erroneous rotation suggestions.

--- ============================ CONTENT ============================

---
--- Enhanced SPELL_CAST_SUCCESS listener for the player.
--- This listener adjusts the timestamp of successful casts by compensating for
--- network latency and the spell queue window, resulting in a much more
--- accurate `LastCastTime` for the rotation logic.
---
do
  local ListenedSpell
  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, _, _, _, _, SpellID)
      -- Clear any failed cast tracking for this spell since it succeeded.
      FailedCasts[SpellID] = nil
      
      -- Calculate lag-compensated timing for maximum accuracy.
      local CurrentTime = GetTime()
      local LagCompensation = HL.Latency() * 0.5  -- Use half latency as a common practice to average out timing discrepancies.
      local AdjustedCastTime = CurrentTime - LagCompensation
      local SpellQueueAdjustment = 0
      
      -- If the cast happened within the spell queue window after a GCD, adjust its timestamp
      -- to reflect when the player actually pressed the key.
      if LastGCDEnd > 0 and (CurrentTime - LastGCDEnd) <= SpellQueueWindow then
        SpellQueueAdjustment = mathmax(0, SpellQueueWindow - (CurrentTime - LastGCDEnd))
        AdjustedCastTime = AdjustedCastTime - SpellQueueAdjustment
      end
      
      for i = 1, #PlayerSpecs do
        ListenedSpell = ListenedSpells[PlayerSpecs[i]][SpellID]
        if ListenedSpell then
          ListenedSpell.LastCastTime = AdjustedCastTime
          ListenedSpell.LastHitTime = AdjustedCastTime + ListenedSpell:TravelTime()
          -- Track the raw time of the successful cast for other predictive measures.
          ListenedSpell.LastSuccessfulCast = CurrentTime
        end
      end
      ListenedSpell = ListenedItemSpells[SpellID]
      if ListenedSpell then
        ListenedSpell.LastCastTime = AdjustedCastTime
        ListenedSpell.LastSuccessfulCast = CurrentTime
      end
      ListenedSpell = ListenedSpecItemSpells[SpellID]
      if ListenedSpell then
        ListenedSpell.LastCastTime = AdjustedCastTime
        ListenedSpell.LastSuccessfulCast = CurrentTime
      end
    end,
    "SPELL_CAST_SUCCESS"
  )
end

---
--- Critical: Tracks SPELL_CAST_FAILED events.
--- This is crucial for rotation accuracy. Without this, the addon might
--- assume a spell was cast successfully when it failed (e.g., out of range,
--- silenced), leading to incorrect follow-up recommendations.
---
do
  local ListenedSpell
  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, _, _, _, _, SpellID, _, _, FailedType)
      local CurrentTime = GetTime()
      
      -- Mark the spell as recently failed.
      FailedCasts[SpellID] = {
        Time = CurrentTime,
        Reason = FailedType,
        Count = (FailedCasts[SpellID] and FailedCasts[SpellID].Count or 0) + 1
      }
      
      -- Store the failure information on the spell object itself.
      for i = 1, #PlayerSpecs do
        ListenedSpell = ListenedSpells[PlayerSpecs[i]][SpellID]
        if ListenedSpell then
          ListenedSpell.LastFailedCast = CurrentTime
          ListenedSpell.LastFailureReason = FailedType
        end
      end
    end,
    "SPELL_CAST_FAILED"
  )
end

---
--- Enhanced SPELL_CAST_SUCCESS listener for the player's pet.
--- Provides network latency compensation for pet abilities, which is vital
--- for pet-heavy classes like Beast Mastery Hunter or Demonology Warlock.
---
do
  local ListenedSpell
  HL:RegisterForPetCombatEvent(
    function(_, _, _, _, _, _, _, _, _, _, _, SpellID)
      local CurrentTime = GetTime()
      local LagCompensation = HL.Latency() * 0.5
      local AdjustedCastTime = CurrentTime - LagCompensation
      
      for i = 1, #PlayerSpecs do
        ListenedSpell = ListenedSpells[PlayerSpecs[i]][SpellID]
        if ListenedSpell then
          ListenedSpell.LastCastTime = AdjustedCastTime
          ListenedSpell.LastHitTime = AdjustedCastTime + ListenedSpell:TravelTime()
        end
      end
    end,
    "SPELL_CAST_SUCCESS"
  )
end

---
--- Enhanced SPELL_AURA_APPLIED listener.
--- Applies a light latency compensation to aura application times for more
--- precise buff/debuff tracking.
---
do
  local ListenedSpell
  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, _, _, _, _, SpellID)
      local CurrentTime = GetTime()
      local LagCompensation = HL.Latency() * 0.3  -- Lighter compensation for aura events.
      
      for i = 1, #PlayerSpecs do
        ListenedSpell = ListenedSpells[PlayerSpecs[i]][SpellID]
        if ListenedSpell then
          ListenedSpell.LastAppliedOnPlayerTime = CurrentTime - LagCompensation
          -- Track aura application success for better buff prediction.
          ListenedSpell.LastAuraSuccess = CurrentTime
        end
      end
    end,
    "SPELL_AURA_APPLIED"
  )
end

---
--- Enhanced SPELL_AURA_REMOVED listener.
--- Applies latency compensation for more accurate tracking of when buffs
--- or debuffs fall off the player.
---
do
  local ListenedSpell
  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, _, _, _, _, SpellID)
      local CurrentTime = GetTime()
      local LagCompensation = HL.Latency() * 0.3
      
      for i = 1, #PlayerSpecs do
        ListenedSpell = ListenedSpells[PlayerSpecs[i]][SpellID]
        if ListenedSpell then
          ListenedSpell.LastRemovedFromPlayerTime = CurrentTime - LagCompensation
        end
      end
    end,
    "SPELL_AURA_REMOVED"
  )
end

---
--- Tracks SPELL_INTERRUPT events.
--- Provides the rotation with intelligence that a spell was interrupted,
--- allowing it to adjust recommendations for a locked-out spell school.
---
do
  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, _, _, _, _, SpellID)
      local CurrentTime = GetTime()
      
      -- Mark as interrupted and reset its LastCastTime.
      for i = 1, #PlayerSpecs do
        local ListenedSpell = ListenedSpells[PlayerSpecs[i]][SpellID]
        if ListenedSpell then
          ListenedSpell.LastInterruptTime = CurrentTime
          if ListenedSpell.LastCastTime and (CurrentTime - ListenedSpell.LastCastTime) < 10 then
            ListenedSpell.LastCastTime = 0
          end
        end
      end
    end,
    "SPELL_INTERRUPT"
  )
end

---
--- High-frequency GCD End Tracking.
--- Uses a lightweight OnUpdate frame to detect the end of the Global Cooldown,
--- which is essential for accurate spell queue window calculations.
---
do
  local function UpdateGCDTracking()
    local GCDRemains = Player:GCDRemains()
    if GCDRemains <= 0.05 and LastGCDEnd ~= GetTime() then  -- 50ms threshold for precision.
      LastGCDEnd = GetTime()
    end
  end
  
  local GCDFrame = CreateFrame("Frame")
  local LastUpdate = 0
  GCDFrame:SetScript("OnUpdate", function()
    local CurrentTime = GetTime()
    if CurrentTime - LastUpdate >= 0.05 then  -- Update every 50ms.
      UpdateGCDTracking()
      LastUpdate = CurrentTime
    end
  end)
end

-- Registers spells from usable items to be tracked.
function Player:RegisterListenedItemSpells()
  ListenedItemSpells = {}
  local UsableItems = self:GetOnUseItems()
  for _, Item in ipairs(UsableItems) do
    local Spell = Item:OnUseSpell()
    if Spell then
      -- HL.Print("Listening to spell " .. Spell:ID() .. " for item " .. TrinketItem:Name() )
      ListenedItemSpells[Spell:ID()] = Spell
    end
  end
end

-- Registers spells for the player's current class and spec to be tracked.
function Player:RegisterListenedSpells(SpecID)
  PlayerSpecs = {}
  ListenedSpells = {}
  ListenedSpecItemSpells = {}
  local PlayerClass = HL.SpecID_ClassesSpecs[SpecID][1]
  -- Fetch registered spells during the init
  for Spec, Spells in pairs(HL.Spell[PlayerClass]) do
    tableinsert(PlayerSpecs, Spec)
    ListenedSpells[Spec] = {}
    for _, Spell in pairs(Spells) do
      if Spell:ID() then
        ListenedSpells[Spec][Spell:ID()] = Spell
      end
    end
  end
  -- Add Spells based on the Whitelist
  for SpellID, Spell in pairs(Custom.Whitelist) do
    for i = 1, #PlayerSpecs do
      ListenedSpells[PlayerSpecs[i]][SpellID] = Spell
    end
  end
  -- Remove Spells based on the Blacklist
  for i = 1, #Custom.Blacklist do
    local SpellID = Custom.Blacklist[i]
    for k = 1, #PlayerSpecs do
      local Spec = PlayerSpecs[k]
      if ListenedSpells[Spec][SpellID] then
        ListenedSpells[Spec][SpellID] = nil
      end
    end
  end
  -- Re-scan equipped Item spells after module initialization
  if HL.Item[PlayerClass] then
    for Spec, Items in pairs(HL.Item[PlayerClass]) do
      for _, Item in pairs(Items) do
        local Spell = Item:OnUseSpell()
        if Spell then
          -- HL.Print("Listening to spell " .. Spell:ID() .. " for spec item " .. Item:Name() )
          ListenedSpecItemSpells[Spell:ID()] = Spell
        end
      end
    end
  end
end

---
--- Checks if the spell has failed within a given time window.
--- This prevents the rotation from immediately retrying a failing spell.
--- @param TimeWindow number: The lookback duration in seconds (default: 2.0).
--- @return boolean: True if the spell has failed recently.
---
function Spell:RecentlyFailed(TimeWindow)
  TimeWindow = TimeWindow or 2.0  -- Default 2 second window
  local SpellID = self:ID()
  local FailInfo = FailedCasts[SpellID]
  if not FailInfo then return false end
  
  return (GetTime() - FailInfo.Time) < TimeWindow
end

---
--- Returns the reason for the last recorded spell failure.
--- @return string or nil: The failure reason (e.g., "Interrupted", "Out of range").
---
function Spell:LastFailureReason()
  local SpellID = self:ID()
  local FailInfo = FailedCasts[SpellID]
  return FailInfo and FailInfo.Reason or nil
end

---
--- Returns a high-fidelity time since the last *successful* cast.
--- This is critical for accurate rotation logic, as it ignores failed casts.
--- @return number: Time since last successful cast, or 999 if never cast.
---
function Spell:TimeSinceLastCast()
  if self.LastCastTime and self.LastCastTime > 0 then
    -- If spell recently failed, consider its cast time to be infinite to prevent misuse.
    if self:RecentlyFailed(1.0) then
      return 999
    end
    
    return GetTime() - self.LastCastTime
  end
  return 999
end

---
--- A predictive function to check if a spell will be ready within the player's latency.
--- This allows for more aggressive and responsive spell queueing.
--- @param TimeWindow number: Additional time buffer (default: 0.1s).
--- @return boolean: True if the spell is ready or will be ready within the latency window.
---
function Spell:IsReadyNetworkCompensated(TimeWindow)
  TimeWindow = TimeWindow or 0.1  -- 100ms default compensation window
  
  -- If spell recently failed, it's definitely not ready.
  if self:RecentlyFailed(0.5) then
    return false
  end
  
  -- Use base IsReady but account for network lag in timing decisions.
  local BaseReady = self:IsReady()
  if not BaseReady then
    -- Check if it might be ready when accounting for lag.
    local CDRemains = self:CooldownRemains()
    if CDRemains > 0 and CDRemains <= (HL.Latency() + TimeWindow) then
      return true  -- Ready within network lag tolerance.
    end
  end
  
  return BaseReady
end

-- Add a spell to the tracking whitelist.
function Spell:AddToListenedSpells()
  Custom.Whitelist[self.SpellID] = self
end

-- Add a spell to the tracking blacklist.
function Spell:RemoveFromListenedSpells()
  tableinsert(Custom.Blacklist, self.SpellID)
end

-- Add a MultiSpell to the tracking list.
function MultiSpell:AddToMultiSpells()
  tableinsert(MultiSpells, self)
end

HL:RegisterForEvent(
  function(Event, Arg1)
    for _, ThisMultiSpell in pairs(MultiSpells) do
      ThisMultiSpell:Update()
    end
  end,
  "PLAYER_LOGIN", "SPELLS_CHANGED"
)

---
--- Periodic cleanup for the FailedCasts table.
--- This acts as a garbage collector to prevent memory bloat from storing
--- cast failure data indefinitely over long gameplay sessions.
---
do
  local CleanupFrame = CreateFrame("Frame")
  local LastCleanup = 0
  CleanupFrame:SetScript("OnUpdate", function()
    local CurrentTime = GetTime()
    if CurrentTime - LastCleanup >= 30 then  -- Cleanup every 30 seconds.
      for SpellID, FailInfo in pairs(FailedCasts) do
        if CurrentTime - FailInfo.Time > 10 then  -- Remove failures older than 10 seconds.
          FailedCasts[SpellID] = nil
        end
      end
      LastCleanup = CurrentTime
    end
  end)
end
