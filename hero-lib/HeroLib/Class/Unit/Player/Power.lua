---
--- hero-lib/HeroLib/Class/Unit/Player/Power.lua
---
--- Provides a comprehensive API for tracking the player's power and resource
--- mechanics, including current/max values, regeneration rates, and predictive
--- calculations for all classes and specs. It is designed to be a single
--- source of truth for all resource-related queries, ensuring that rotation
--- logic has access to accurate, low-latency data.
---

--- ======================= LOCALIZATION =======================
--- Lua & WoW APIs are localized for performance.
local _, HL                  = ...
-- HeroLib
local Unit                   = HL.Unit
local Player                 = Unit.Player
local Spell                  = HL.Spell

-- Base API locals
local Enum                   = Enum
local GetPowerRegen          = GetPowerRegen         -- Accepts: nil; Returns: base (number), casting (number)
local UnitPower              = UnitPower             -- Accepts: unit, powerType; Returns: number
local UnitPowerMax           = UnitPowerMax          -- Accepts: unit, powerType; Returns: number
local GetUnitChargedPowerPoints = GetUnitChargedPowerPoints -- Accepts: unit; Returns: table

-- Lua locals
local GetTime                = GetTime
local pairs                  = pairs
local tablesort              = table.sort

--- ============================ CONTENT ============================
--------------------------
--- 0 | Mana Functions ---
--------------------------
do
  local ManaPowerType = Enum.PowerType.Mana

  --- Returns the player's maximum mana.
  -- @return number: Maximum mana.
  function Player:ManaMax()
    return UnitPowerMax(self.UnitID, ManaPowerType)
  end

  --- Returns the player's current mana.
  -- @return number: Current mana.
  function Player:Mana()
    return UnitPower(self.UnitID, ManaPowerType)
  end

  --- Returns the player's current mana as a percentage of maximum.
  -- @return number: Mana percentage.
  function Player:ManaPercentage()
    return (self:Mana() / self:ManaMax()) * 100
  end

  --- Returns the player's mana deficit (how much is missing).
  -- @return number: Mana deficit.
  function Player:ManaDeficit()
    return self:ManaMax() - self:Mana()
  end

  --- Returns the player's mana deficit as a percentage.
  -- @return number: Mana deficit percentage.
  function Player:ManaDeficitPercentage()
    return (self:ManaDeficit() / self:ManaMax()) * 100
  end

  --- Returns mana regeneration per second, based on casting state.
  -- @return number: Current mana regeneration per second.
  function Player:ManaRegen()
    local baseRegen, castingRegen = GetPowerRegen()
    return self:IsCasting() and castingRegen or baseRegen
  end

  --- Returns base mana regeneration (out of combat or not casting).
  -- @return number: Base mana regeneration per second.
  function Player:ManaRegenBase()
    local baseRegen = GetPowerRegen()
    return baseRegen
  end

  --- Returns mana regeneration while casting.
  -- @return number: Casting mana regeneration per second.
  function Player:ManaRegenCasting()
    local _, castingRegen = GetPowerRegen()
    return castingRegen
  end

  --- Calculates total mana regenerated over a given cast time.
  -- @param CastTime number: The duration of the cast.
  -- @return number: Total mana regenerated, or -1 if casting regen is zero.
  function Player:ManaCastRegen(CastTime)
    local _, castingRegen = GetPowerRegen()
    if castingRegen == 0 then return -1 end
    return castingRegen * CastTime
  end

  --- Calculates mana regenerated during the remainder of a cast or GCD.
  -- @param Offset? number: An optional time offset to add.
  -- @return number: Mana regenerated, or -1 if casting regen is zero.
  function Player:ManaRemainingCastRegen(Offset)
    local _, castingRegen = GetPowerRegen()
    if castingRegen == 0 then return -1 end
    -- If we are casting, we check what we will regen until the end of the cast
    if self:IsCasting() then
      return castingRegen * (self:CastRemains() + (Offset or 0))
      -- Else we'll use the remaining GCD as "CastTime"
    else
      return castingRegen * (self:GCDRemains() + (Offset or 0))
    end
  end

  --- Calculates the time in seconds until the player reaches maximum mana.
  -- @return number: Time to max mana in seconds, or -1 if regen is zero.
  function Player:ManaTimeToMax()
    local regen = self:ManaRegen()
    if regen == 0 then return -1 end
    return self:ManaDeficit() / regen
  end

  --- Calculates the time in seconds until the player reaches a specific mana amount.
  -- @param Amount number: The target mana amount.
  -- @return number: Time to reach the target amount, or 0 if already above it.
  function Player:ManaTimeToX(Amount)
    local regen = self:ManaRegen()
    if regen == 0 then return -1 end
    return Amount > self:Mana() and (Amount - self:Mana()) / regen or 0
  end

  --- Predicts mana at the end of the current cast or GCD.
  -- @return number: Predicted mana value, capped at maximum mana.
  function Player:ManaP()
    local FutureMana = Player:Mana() - Player:CastCost()
    -- Add the mana that we will regen during the remaining of the cast
    if Player:Mana() ~= Player:ManaMax() then FutureMana = FutureMana + Player:ManaRemainingCastRegen() end
    -- Cap the max
    if FutureMana > Player:ManaMax() then FutureMana = Player:ManaMax() end
    return FutureMana
  end

  --- Predicts mana percentage at the end of the current cast or GCD.
  -- @return number: Predicted mana percentage.
  function Player:ManaPercentageP()
    return (self:ManaP() / self:ManaMax()) * 100
  end

  --- Predicts mana deficit at the end of the current cast or GCD.
  -- @return number: Predicted mana deficit.
  function Player:ManaDeficitP()
    return self:ManaMax() - self:ManaP()
  end

  --- Predicts mana deficit percentage at the end of the current cast or GCD.
  -- @return number: Predicted mana deficit percentage.
  function Player:ManaDeficitPercentageP()
    return (self:ManaDeficitP() / self:ManaMax()) * 100
  end
end

--------------------------
--- 1 | Rage Functions ---
--------------------------
do
  local RagePowerType = Enum.PowerType.Rage

  --- Returns the player's maximum Rage.
  -- @return number: Maximum Rage.
  function Player:RageMax()
    return UnitPowerMax(self.UnitID, RagePowerType)
  end

  --- Returns the player's current Rage.
  -- @return number: Current Rage.
  function Player:Rage()
    return UnitPower(self.UnitID, RagePowerType)
  end

  --- Returns the player's current Rage as a percentage.
  -- @return number: Rage percentage.
  function Player:RagePercentage()
    return (self:Rage() / self:RageMax()) * 100
  end

  --- Returns the player's Rage deficit.
  -- @return number: Rage deficit.
  function Player:RageDeficit()
    return self:RageMax() - self:Rage()
  end

  --- Returns the player's Rage deficit as a percentage.
  -- @return number: Rage deficit percentage.
  function Player:RageDeficitPercentage()
    return (self:RageDeficit() / self:RageMax()) * 100
  end
end

---------------------------
--- 2 | Focus Functions ---
---------------------------
do
  local FocusPowerType = Enum.PowerType.Focus

  --- Returns the player's maximum Focus.
  -- @return number: Maximum Focus.
  function Player:FocusMax()
    return UnitPowerMax(self.UnitID, FocusPowerType)
  end

  --- Returns the player's current Focus.
  -- @return number: Current Focus.
  function Player:Focus()
    return UnitPower(self.UnitID, FocusPowerType)
  end

  --- Returns Focus regeneration per second, scaled by Haste.
  -- @return number: Current Focus regeneration per second.
  function Player:FocusRegen()
    -- Focus base regen is 10 per second for hunters, modified by haste
    local haste = 1 + (Player:HastePct() / 100)
    return 10 * haste
  end

  --- Returns the player's current Focus as a percentage.
  -- @return number: Focus percentage.
  function Player:FocusPercentage()
    return (self:Focus() / self:FocusMax()) * 100
  end

  --- Returns the player's Focus deficit.
  -- @return number: Focus deficit.
  function Player:FocusDeficit()
    return self:FocusMax() - self:Focus()
  end

  --- Returns the player's Focus deficit as a percentage.
  -- @return number: Focus deficit percentage.
  function Player:FocusDeficitPercentage()
    return (self:FocusDeficit() / self:FocusMax()) * 100
  end

  --- Returns the player's Focus regeneration as a percentage of max Focus.
  -- @return number: Focus regeneration percentage per second.
  function Player:FocusRegenPercentage()
    return (self:FocusRegen() / self:FocusMax()) * 100
  end

  --- Calculates time in seconds until the player reaches maximum Focus.
  -- @return number: Time to max Focus in seconds, or -1 if regen is zero.
  function Player:FocusTimeToMax()
    if self:FocusRegen() == 0 then return -1 end
    return self:FocusDeficit() / self:FocusRegen()
  end

  --- Calculates time in seconds until the player reaches a specific Focus amount.
  -- @param Amount number: The target Focus amount.
  -- @return number: Time to reach target Focus, or 0 if already above it.
  function Player:FocusTimeToX(Amount)
    if self:FocusRegen() == 0 then return -1 end
    return Amount > self:Focus() and (Amount - self:Focus()) / self:FocusRegen() or 0
  end

  --- Calculates time in seconds until the player reaches a specific Focus percentage.
  -- @param Amount number: The target Focus percentage.
  -- @return number: Time to reach target Focus percentage.
  function Player:FocusTimeToXPercentage(Amount)
    if self:FocusRegen() == 0 then return -1 end
    return Amount > self:FocusPercentage() and (Amount - self:FocusPercentage()) / self:FocusRegenPercentage() or 0
  end

  --- Calculates total Focus regenerated over a given cast time.
  -- @param CastTime number: The duration of the cast.
  -- @return number: Total Focus regenerated, or -1 if regen is zero.
  function Player:FocusCastRegen(CastTime)
    if self:FocusRegen() == 0 then return -1 end
    return self:FocusRegen() * CastTime
  end

  --- Calculates Focus regenerated during the remainder of a cast or GCD.
  -- @param Offset? number: An optional time offset to add.
  -- @return number: Focus regenerated, or -1 if regen is zero.
  function Player:FocusRemainingCastRegen(Offset)
    if self:FocusRegen() == 0 then return -1 end
    -- If we are casting, we check what we will regen until the end of the cast
    if self:IsCasting() then
      return self:FocusRegen() * (self:CastRemains() + (Offset or 0))
      -- Else we'll use the remaining GCD as "CastTime"
    else
      return self:FocusRegen() * (self:GCDRemains() + (Offset or 0))
    end
  end

  --- Returns the Focus cost of the spell currently being cast.
  -- @return number: The Focus cost, or 0 if not casting.
  function Player:FocusLossOnCastEnd()
    return self:IsCasting() and Spell(self:CastSpellID()):Cost() or 0
  end

  --- Predicts Focus at the end of the current cast or GCD.
  -- @param Offset? number: An optional time offset to add.
  -- @return number: Predicted Focus, or -1 if regen is zero.
  function Player:FocusPredicted(Offset)
    if self:FocusRegen() == 0 then return -1 end
    return math.min(Player:FocusMax(), self:Focus() + self:FocusRemainingCastRegen(Offset) - self:FocusLossOnCastEnd())
  end

  --- Predicts Focus deficit at the end of the current cast or GCD.
  -- @param Offset? number: An optional time offset to add.
  -- @return number: Predicted Focus deficit, or -1 if regen is zero.
  function Player:FocusDeficitPredicted(Offset)
    if self:FocusRegen() == 0 then return -1 end
    return Player:FocusMax() - self:FocusPredicted(Offset);
  end

  --- Predicts time to maximum Focus from the end of a cast or GCD.
  -- @return number: Predicted time to max Focus, or -1 if regen is zero.
  function Player:FocusTimeToMaxPredicted()
    if self:FocusRegen() == 0 then return -1 end
    local FocusDeficitPredicted = self:FocusDeficitPredicted()
    if FocusDeficitPredicted <= 0 then
      return 0
    end
    return FocusDeficitPredicted / self:FocusRegen()
  end
end

----------------------------
--- 3 | Energy Functions ---
----------------------------
do
  local EnergyPowerType = Enum.PowerType.Energy

  --- Returns maximum Energy, with an optional offset.
  -- @param MaxOffset? number: Value to add to maximum Energy.
  -- @return number: Maximum Energy.
  function Player:EnergyMax(MaxOffset)
    return math.max(0, UnitPowerMax(self.UnitID, EnergyPowerType) + (MaxOffset or 0))
  end

  --- Returns current Energy.
  -- @return number: Current Energy.
  function Player:Energy()
    return UnitPower(self.UnitID, EnergyPowerType)
  end

  --- Returns Energy regeneration per second, scaled by Haste.
  -- @return number: Current Energy regeneration per second.
  function Player:EnergyRegen()
    -- Energy base regen is 10 per second for rogues/druids, modified by haste
    local haste = 1 + (Player:HastePct() / 100)
    return 10 * haste
  end

  --- Returns current Energy as a percentage.
  -- @param MaxOffset? number: Optional maximum Energy offset.
  -- @return number: Energy percentage.
  function Player:EnergyPercentage(MaxOffset)
    return math.min(100, (self:Energy() / self:EnergyMax(MaxOffset)) * 100)
  end

  --- Returns Energy deficit.
  -- @param MaxOffset? number: Optional maximum Energy offset.
  -- @return number: Energy deficit.
  function Player:EnergyDeficit(MaxOffset)
    return math.max(0, self:EnergyMax(MaxOffset) - self:Energy())
  end

  --- Returns Energy deficit as a percentage.
  -- @param MaxOffset? number: Optional maximum Energy offset.
  -- @return number: Energy deficit percentage.
  function Player:EnergyDeficitPercentage(MaxOffset)
    return (self:EnergyDeficit(MaxOffset) / self:EnergyMax(MaxOffset)) * 100
  end

  --- Returns Energy regeneration as a percentage of max Energy.
  -- @param MaxOffset? number: Optional maximum Energy offset.
  -- @return number: Energy regeneration percentage per second.
  function Player:EnergyRegenPercentage(MaxOffset)
    return (self:EnergyRegen() / self:EnergyMax(MaxOffset)) * 100
  end

  --- Calculates time in seconds until the player reaches maximum Energy.
  -- @param MaxOffset? number: Optional maximum Energy offset.
  -- @return number: Time to max Energy in seconds, or -1 if regen is zero.
  function Player:EnergyTimeToMax(MaxOffset)
    if self:EnergyRegen() == 0 then return -1 end
    return self:EnergyDeficit(MaxOffset) / self:EnergyRegen()
  end

  --- Calculates time in seconds until the player reaches a specific Energy amount.
  -- @param Amount number: The target Energy amount.
  -- @param Offset? number: Optional regen multiplier adjustment.
  -- @return number: Time to reach target Energy, or 0 if already above it.
  function Player:EnergyTimeToX(Amount, Offset)
    if self:EnergyRegen() == 0 then return -1 end
    return Amount > self:Energy() and (Amount - self:Energy()) / (self:EnergyRegen() * (1 - (Offset or 0))) or 0
  end

  --- Calculates time in seconds until the player reaches a specific Energy percentage.
  -- @param Amount number: The target Energy percentage.
  -- @return number: Time to reach target Energy percentage.
  function Player:EnergyTimeToXPercentage(Amount)
    if self:EnergyRegen() == 0 then return -1 end
    return Amount > self:EnergyPercentage() and (Amount - self:EnergyPercentage()) / self:EnergyRegenPercentage() or 0
  end

  --- Calculates Energy regenerated during the remainder of a cast or GCD.
  -- @param Offset? number: An optional time offset to add.
  -- @return number: Energy regenerated, or -1 if regen is zero.
  function Player:EnergyRemainingCastRegen(Offset)
    if self:EnergyRegen() == 0 then return -1 end
    -- If we are casting, we check what we will regen until the end of the cast
    if self:IsCasting() or self:IsChanneling() then
      return self:EnergyRegen() * (self:CastRemains() + (Offset or 0))
      -- Else we'll use the remaining GCD as "CastTime"
    else
      return self:EnergyRegen() * (self:GCDRemains() + (Offset or 0))
    end
  end

  --- Predicts Energy at the end of the current cast or GCD.
  -- @param Offset? number: An optional time offset to add.
  -- @param MaxOffset? number: Optional maximum Energy offset.
  -- @return number: Predicted Energy, or -1 if regen is zero.
  function Player:EnergyPredicted(Offset, MaxOffset)
    if self:EnergyRegen() == 0 then return -1 end
    return math.min(Player:EnergyMax(MaxOffset), self:Energy() + self:EnergyRemainingCastRegen(Offset))
  end

  --- Predicts Energy deficit at the end of the current cast or GCD.
  -- @param Offset? number: An optional time offset to add.
  -- @param MaxOffset? number: Optional maximum Energy offset.
  -- @return number: Predicted Energy deficit, or -1 if regen is zero.
  function Player:EnergyDeficitPredicted(Offset, MaxOffset)
    if self:EnergyRegen() == 0 then return -1 end
    return math.max(0, self:EnergyDeficit(MaxOffset) - self:EnergyRemainingCastRegen(Offset))
  end

  --- Predicts time to maximum Energy from the end of a cast or GCD.
  -- @param Offset? number: An optional time offset to add.
  -- @param MaxOffset? number: Optional maximum Energy offset.
  -- @return number: Predicted time to max Energy, or -1 if regen is zero.
  function Player:EnergyTimeToMaxPredicted(Offset, MaxOffset)
    if self:EnergyRegen() == 0 then return -1 end
    local EnergyDeficitPredicted = self:EnergyDeficitPredicted(Offset, MaxOffset)
    if EnergyDeficitPredicted <= 0 then
      return 0
    end
    return EnergyDeficitPredicted / self:EnergyRegen()
  end
end

----------------------------------
--- 4 | Combo Points Functions ---
----------------------------------
do
  local ComboPointsPowerType = Enum.PowerType.ComboPoints

  --- Returns maximum Combo Points.
  -- @return number: Maximum Combo Points.
  function Player:ComboPointsMax()
    return UnitPowerMax(self.UnitID, ComboPointsPowerType)
  end

  --- Returns total Combo Points, including base and charged points.
  -- @return number: Total Combo Points.
  function Player:ComboPoints()
    local baseCP = UnitPower(self.UnitID, ComboPointsPowerType)
    local chargedCP = self:ChargedComboPoints()
    return baseCP + chargedCP
  end

  --- Returns the number of charged Combo Points.
  -- @return number: Charged Combo Points.
  function Player:ChargedComboPoints()
    local chargedCps = GetUnitChargedPowerPoints(self.UnitID)
    return (chargedCps and #chargedCps) or 0
  end

  --- Returns only the base Combo Points (excluding charged).
  -- @return number: Base Combo Points.
  function Player:ComboPointsBase()
    return UnitPower(self.UnitID, ComboPointsPowerType)
  end

  --- Returns Combo Points deficit.
  -- @return number: Combo Points deficit.
  function Player:ComboPointsDeficit()
    return self:ComboPointsMax() - self:ComboPoints()
  end
end

---------------------------------
--- 5 | Runic Power Functions ---
---------------------------------
do
  local RunicPowerPowerType = Enum.PowerType.RunicPower

  --- Returns maximum Runic Power.
  -- @return number: Maximum Runic Power.
  function Player:RunicPowerMax()
    return UnitPowerMax(self.UnitID, RunicPowerPowerType)
  end

  --- Returns current Runic Power.
  -- @return number: Current Runic Power.
  function Player:RunicPower()
    return UnitPower(self.UnitID, RunicPowerPowerType)
  end

  --- Returns current Runic Power as a percentage.
  -- @return number: Runic Power percentage.
  function Player:RunicPowerPercentage()
    return (self:RunicPower() / self:RunicPowerMax()) * 100
  end

  --- Returns Runic Power deficit.
  -- @return number: Runic Power deficit.
  function Player:RunicPowerDeficit()
    return self:RunicPowerMax() - self:RunicPower()
  end

  --- Returns Runic Power deficit as a percentage.
  -- @return number: Runic Power deficit percentage.
  function Player:RunicPowerDeficitPercentage()
    return (self:RunicPowerDeficit() / self:RunicPowerMax()) * 100
  end
end

---------------------------
--- 6 | Runes Functions ---
---------------------------
do
  local GetRuneCooldown = GetRuneCooldown

  -- Computes the remaining cooldown for a single rune slot.
  local function ComputeRuneCooldown(Slot, BypassRecovery)
    local CDTime, CDValue = GetRuneCooldown(Slot)
    if CDTime == 0 or CDTime == nil then return 0 end
    local CD = CDTime + CDValue - GetTime() - HL.RecoveryOffset(BypassRecovery)
    return CD > 0 and CD or 0
  end

  --- Returns the number of fully recharged Runes.
  -- @return number: Count of available runes.
  function Player:Rune()
    local Count = 0
    for i = 1, 6 do
      if ComputeRuneCooldown(i) == 0 then
        Count = Count + 1
      end
    end
    return Count
  end

  --- Calculates time until X number of Runes are available.
  -- @param Value number: The target number of runes (1-6).
  -- @return number: Time in seconds until the target number of runes are ready.
  function Player:RuneTimeToX(Value)
    if type(Value) ~= "number" then error("Value must be a number.") end
    if Value < 1 or Value > 6 then error("Value must be a number between 1 and 6.") end
    local Runes = {}
    for i = 1, 6 do
      Runes[i] = ComputeRuneCooldown(i)
    end
    tablesort(Runes, function(a, b) return a < b end)
    local Count = 1
    for _, CD in pairs(Runes) do
      if Count == Value then
        return CD
      end
      Count = Count + 1
    end
  end
end

------------------------
--- 7 | Soul Shards  ---
------------------------
do
  local SoulShardsPowerType = Enum.PowerType.SoulShards

  --- Returns maximum Soul Shards.
  -- @return number: Maximum Soul Shards.
  function Player:SoulShardsMax()
    return UnitPowerMax(self.UnitID, SoulShardsPowerType)
  end

  --- Returns current Soul Shards.
  -- @return number: Current Soul Shards.
  function Player:SoulShards()
    return UnitPower(self.UnitID, SoulShardsPowerType)
  end

  --- Returns predicted Soul Shards (can be customized in spec overrides).
  -- @return number: Predicted Soul Shards.
  function Player:SoulShardsP()
    return UnitPower(self.UnitID, SoulShardsPowerType)
  end

  --- Returns Soul Shards deficit.
  -- @return number: Soul Shards deficit.
  function Player:SoulShardsDeficit()
    return self:SoulShardsMax() - self:SoulShards()
  end
end

------------------------
--- 8 | Astral Power ---
------------------------
do
  local LunarPowerPowerType = Enum.PowerType.LunarPower

  --- Returns maximum Astral Power.
  -- @return number: Maximum Astral Power.
  function Player:AstralPowerMax()
    return UnitPowerMax(self.UnitID, LunarPowerPowerType)
  end

  --- Returns current Astral Power.
  -- @param OverrideFutureAstralPower? number: An optional override value.
  -- @return number: Current Astral Power.
  function Player:AstralPower(OverrideFutureAstralPower)
    return OverrideFutureAstralPower or UnitPower(self.UnitID, LunarPowerPowerType)
  end

  --- Returns current Astral Power as a percentage.
  -- @param OverrideFutureAstralPower? number: An optional override value.
  -- @return number: Astral Power percentage.
  function Player:AstralPowerPercentage(OverrideFutureAstralPower)
    return (self:AstralPower(OverrideFutureAstralPower) / self:AstralPowerMax()) * 100
  end

  --- Returns Astral Power deficit.
  -- @param OverrideFutureAstralPower? number: An optional override value.
  -- @return number: Astral Power deficit.
  function Player:AstralPowerDeficit(OverrideFutureAstralPower)
    local AstralPower = self:AstralPower(OverrideFutureAstralPower)
    return self:AstralPowerMax() - AstralPower
  end

  --- Returns Astral Power deficit as a percentage.
  -- @param OverrideFutureAstralPower? number: An optional override value.
  -- @return number: Astral Power deficit percentage.
  function Player:AstralPowerDeficitPercentage(OverrideFutureAstralPower)
    return (self:AstralPowerDeficit(OverrideFutureAstralPower) / self:AstralPowerMax()) * 100
  end
end

--------------------------------
--- 9 | Holy Power Functions ---
--------------------------------
do
  local HolyPowerPowerType = Enum.PowerType.HolyPower

  --- Returns maximum Holy Power.
  -- @return number: Maximum Holy Power.
  function Player:HolyPowerMax()
    return UnitPowerMax(self.UnitID, HolyPowerPowerType)
  end

  --- Returns current Holy Power.
  -- @return number: Current Holy Power.
  function Player:HolyPower()
    return UnitPower(self.UnitID, HolyPowerPowerType)
  end

  --- Returns current Holy Power as a percentage.
  -- @return number: Holy Power percentage.
  function Player:HolyPowerPercentage()
    return (self:HolyPower() / self:HolyPowerMax()) * 100
  end

  --- Returns Holy Power deficit.
  -- @return number: Holy Power deficit.
  function Player:HolyPowerDeficit()
    return self:HolyPowerMax() - self:HolyPower()
  end

  --- Returns Holy Power deficit as a percentage.
  -- @return number: Holy Power deficit percentage.
  function Player:HolyPowerDeficitPercentage()
    return (self:HolyPowerDeficit() / self:HolyPowerMax()) * 100
  end
end

------------------------------
-- 11 | Maelstrom Functions --
------------------------------
--- Returns maximum Maelstrom.
-- @return number: Maximum Maelstrom.
function Player:MaelstromMax()
  return UnitPowerMax(self.UnitID, Enum.PowerType.Maelstrom)
end

--- Returns current Maelstrom.
-- @return number: Current Maelstrom.
function Player:Maelstrom()
  return UnitPower(self.UnitID, Enum.PowerType.Maelstrom)
end

--- Returns current Maelstrom as a percentage.
-- @return number: Maelstrom percentage.
function Player:MaelstromPercentage()
  return (self:Maelstrom() / self:MaelstromMax()) * 100
end

--- Returns Maelstrom deficit.
-- @return number: Maelstrom deficit.
function Player:MaelstromDeficit()
  return self:MaelstromMax() - self:Maelstrom()
end

--- Returns Maelstrom deficit as a percentage.
-- @return number: Maelstrom deficit percentage.
function Player:MaelstromDeficitPercentage()
  return (self:MaelstromDeficit() / self:MaelstromMax()) * 100
end

--------------------------------------
--- 12 | Chi Functions (& Stagger) ---
--------------------------------------
do
  local ChiPowerType = Enum.PowerType.Chi
  local UnitStagger = UnitStagger

  --- Returns maximum Chi.
  -- @return number: Maximum Chi.
  function Player:ChiMax()
    return UnitPowerMax(self.UnitID, ChiPowerType)
  end

  --- Returns current Chi.
  -- @return number: Current Chi.
  function Player:Chi()
    return UnitPower(self.UnitID, ChiPowerType)
  end

  --- Returns current Chi as a percentage.
  -- @return number: Chi percentage.
  function Player:ChiPercentage()
    return (self:Chi() / self:ChiMax()) * 100
  end

  --- Returns Chi deficit.
  -- @return number: Chi deficit.
  function Player:ChiDeficit()
    return self:ChiMax() - self:Chi()
  end

  --- Returns Chi deficit as a percentage.
  -- @return number: Chi deficit percentage.
  function Player:ChiDeficitPercentage()
    return (self:ChiDeficit() / self:ChiMax()) * 100
  end

  --- Returns maximum Stagger amount (equal to player's max health).
  -- @return number: Maximum Stagger amount.
  function Player:StaggerMax()
    return self:MaxHealth()
  end

  --- Returns the current amount of damage delayed by Stagger.
  -- @return number: Current Stagger amount.
  function Player:Stagger()
    return UnitStagger(self.UnitID)
  end

  --- Returns the current Stagger amount as a percentage of max health.
  -- @return number: Stagger percentage.
  function Player:StaggerPercentage()
    return (self:Stagger() / self:StaggerMax()) * 100
  end
end

------------------------------
-- 13 | Insanity Functions ---
------------------------------
do
  local InsanityPowerType = Enum.PowerType.Insanity

  --- Returns maximum Insanity.
  -- @return number: Maximum Insanity.
  function Player:InsanityMax()
    return UnitPowerMax(self.UnitID, InsanityPowerType)
  end

  --- Returns current Insanity.
  -- @return number: Current Insanity.
  function Player:Insanity()
    return UnitPower(self.UnitID, InsanityPowerType)
  end

  --- Returns current Insanity as a percentage.
  -- @return number: Insanity percentage.
  function Player:InsanityPercentage()
    return (self:Insanity() / self:InsanityMax()) * 100
  end

  --- Returns Insanity deficit.
  -- @return number: Insanity deficit.
  function Player:InsanityDeficit()
    return self:InsanityMax() - self:Insanity()
  end

  --- Returns Insanity deficit as a percentage.
  -- @return number: Insanity deficit percentage.
  function Player:InsanityDeficitPercentage()
    return (self:InsanityDeficit() / self:InsanityMax()) * 100
  end

  --- TODO: Implement Insanity Drain calculation.
  function Player:InsanityDrain()
    return 1
  end
end

-----------------------------------
-- 16 | Arcane Charges Functions --
-----------------------------------
do
  local ArcaneChargesPowerType = Enum.PowerType.ArcaneCharges

  --- Returns maximum Arcane Charges.
  -- @return number: Maximum Arcane Charges.
  function Player:ArcaneChargesMax()
    return UnitPowerMax(self.UnitID, ArcaneChargesPowerType)
  end

  --- Returns current Arcane Charges.
  -- @return number: Current Arcane Charges.
  function Player:ArcaneCharges()
    return UnitPower(self.UnitID, ArcaneChargesPowerType)
  end

  --- Returns current Arcane Charges as a percentage.
  -- @return number: Arcane Charges percentage.
  function Player:ArcaneChargesPercentage()
    return (self:ArcaneCharges() / self:ArcaneChargesMax()) * 100
  end

  --- Returns Arcane Charges deficit.
  -- @return number: Arcane Charges deficit.
  function Player:ArcaneChargesDeficit()
    return self:ArcaneChargesMax() - self:ArcaneCharges()
  end

  --- Returns Arcane Charges deficit as a percentage.
  -- @return number: Arcane Charges deficit percentage.
  function Player:ArcaneChargesDeficitPercentage()
    return (self:ArcaneChargesDeficit() / self:ArcaneChargesMax()) * 100
  end
end

---------------------------
--- 17 | Fury Functions ---
---------------------------
do
  local FuryPowerType = Enum.PowerType.Fury

  --- Returns maximum Fury.
  -- @return number: Maximum Fury.
  function Player:FuryMax()
    return UnitPowerMax(self.UnitID, FuryPowerType)
  end

  --- Returns current Fury.
  -- @return number: Current Fury.
  function Player:Fury()
    return UnitPower(self.UnitID, FuryPowerType)
  end

  --- Returns current Fury as a percentage.
  -- @return number: Fury percentage.
  function Player:FuryPercentage()
    return (self:Fury() / self:FuryMax()) * 100
  end

  --- Returns Fury deficit.
  -- @return number: Fury deficit.
  function Player:FuryDeficit()
    return self:FuryMax() - self:Fury()
  end

  --- Returns Fury deficit as a percentage.
  -- @return number: Fury deficit percentage.
  function Player:FuryDeficitPercentage()
    return (self:FuryDeficit() / self:FuryMax()) * 100
  end
end

---------------------------
--- 18 | Pain Functions ---
---------------------------
do
  local PainPowerType = Enum.PowerType.Pain

  --- Returns maximum Pain.
  -- @return number: Maximum Pain.
  function Player:PainMax()
    return UnitPowerMax(self.UnitID, PainPowerType)
  end

  --- Returns current Pain.
  -- @return number: Current Pain.
  function Player:Pain()
    return UnitPower(self.UnitID, PainPowerType)
  end

  --- Returns current Pain as a percentage.
  -- @return number: Pain percentage.
  function Player:PainPercentage()
    return (self:Pain() / self:PainMax()) * 100
  end

  --- Returns Pain deficit.
  -- @return number: Pain deficit.
  function Player:PainDeficit()
    return self:PainMax() - self:Pain()
  end

  --- Returns Pain deficit as a percentage.
  -- @return number: Pain deficit percentage.
  function Player:PainDeficitPercentage()
    return (self:PainDeficit() / self:PainMax()) * 100
  end
end

------------------------------
--- 19 | Essence Functions ---
------------------------------
do
  local EssencePowerType = Enum.PowerType.Essence

  --- Returns maximum Essence.
  -- @return number: Maximum Essence.
  function Player:EssenceMax()
    return UnitPowerMax(self.UnitID, EssencePowerType)
  end

  --- Returns current Essence.
  -- @return number: Current Essence.
  function Player:Essence()
    return UnitPower(self.UnitID, EssencePowerType)
  end

  --- Returns Essence deficit.
  -- @return number: Essence deficit.
  function Player:EssenceDeficit()
    return self:EssenceMax() - self:Essence()
  end

  --[[ Essence regeneration logic has been moved to Evoker-specific files
       (Events.lua/Overrides.lua) as it is a class-specific mechanic.
  -- essence.time_to_max
  function Player:EssenceTimeToMax()
    local Deficit = Player:EssenceDeficit()
    if Deficit == 0 then return 0; end
    local Regen = GetPowerRegenForPowerType(EssencePowerType)
    local TimeToOneEssence = 5 / (5 / (1 / Regen))
    local LastUpdate = Cache.Persistent.Player.LastPowerUpdate
    return Deficit * TimeToOneEssence - (GetTime() - LastUpdate)
  end

  -- essence.time_to_x
  function Player:EssenceTimeToX(Amount)
    local Essence = Player:Essence()
    if Essence >= Amount then return 0; end
    local Regen = GetPowerRegenForPowerType(EssencePowerType)
    local TimeToOneEssence = 5 / (5 / (1 / Regen))
    local LastUpdate = Cache.Persistent.Player.LastPowerUpdate
    return ((Amount - Essence) * TimeToOneEssence) - (GetTime() - LastUpdate)
  end
  ]]
end

---------------------------------------------------------------------
--- Predicted Resource Map
--- Maps power types to their predicted value functions. This is used
--- by spell usability checks to determine if a spell can be cast.
---------------------------------------------------------------------
do
  Player.PredictedResourceMap = {
    -- Health (but might be percentage only?), cf. https://github.com/herotc/hero-lib/issues/35
    [-2] = function() return Player:Health() end,
    -- Mana
    [0] = function() return Player:ManaP() end,
    -- Rage
    [1] = function() return Player:Rage() end,
    -- Focus
    [2] = function() return Player:FocusPredicted() end,
    -- Energy
    [3] = function() return Player:EnergyPredicted() end,
    -- ComboPoints
    [4] = function() return Player:ComboPoints() end,
    -- Runic Power
    [5] = function() return Player:RunicPower() end,
    -- Runes
    [6] = function() return Player:Rune() end,
    -- Soul Shards
    [7] = function() return Player:SoulShardsP() end,
    -- Astral Power
    [8] = function() return Player:AstralPower() end,
    -- Holy Power
    [9] = function() return Player:HolyPower() end,
    -- Maelstrom
    [11] = function() return Player:Maelstrom() end,
    -- Chi
    [12] = function() return Player:Chi() end,
    -- Insanity
    [13] = function() return Player:Insanity() end,
    -- Arcane Charges
    [16] = function() return Player:ArcaneCharges() end,
    -- Fury
    [17] = function() return Player:Fury() end,
    -- Pain
    [18] = function() return Player:Pain() end,
    -- Essence
    [19] = function() return Player:Essence() end,
  }
end

---------------------------------------------------------------------
--- Time To X Resource Map
--- Maps power types to their "Time To X" functions, for calculating
--- time until a certain resource amount is reached.
---------------------------------------------------------------------
do
  Player.TimeToXResourceMap = {
    -- Mana
    [0] = function(Value) return Player:ManaTimeToX(Value) end,
    -- Rage
    [1] = function() return nil end,
    -- Focus
    [2] = function(Value) return Player:FocusTimeToX(Value) end,
    -- Energy
    [3] = function(Value) return Player:EnergyTimeToX(Value) end,
    -- ComboPoints
    [4] = function() return nil end,
    -- Runic Power
    [5] = function() return nil end,
    -- Runes
    [6] = function(Value) return Player:RuneTimeToX(Value) end,
    -- Soul Shards
    [7] = function() return nil end,
    -- Astral Power
    [8] = function() return nil end,
    -- Holy Power
    [9] = function() return nil end,
    -- Maelstrom
    [11] = function() return nil end,
    -- Chi
    [12] = function() return nil end,
    -- Insanity
    [13] = function() return nil end,
    -- Arcane Charges
    [16] = function() return nil end,
    -- Fury
    [17] = function() return nil end,
    -- Pain
    [18] = function() return nil end,
    -- Essence (TODO: Add EssenceTimeToX())
    [19] = function() return nil end,
  }
end
