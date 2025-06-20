--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, HL          = ...
-- HeroDBC
local DBC                    = HeroDBC.DBC
-- HeroLib
local Cache, Utils           = HeroCache, HL.Utils
local Unit                   = HL.Unit
local Player, Pet, Target    = Unit.Player, Unit.Pet, Unit.Target
local Focus, MouseOver       = Unit.Focus, Unit.MouseOver
local Arena, Boss, Nameplate = Unit.Arena, Unit.Boss, Unit.Nameplate
local Party, Raid            = Unit.Party, Unit.Raid
local Spell                  = HL.Spell
local Item                   = HL.Item

-- C_Item locals
local IsItemInRange          = C_Item.IsItemInRange
-- Accepts: itemInfo, targetToken; Returns: result (bool)
local IsUsableItem           = C_Item.IsUsableItem
-- Accepts: itemInfo; Returns: usable (bool), noMana (bool)

-- C_Spell locals
local IsSpellInRange         = C_Spell.IsSpellInRange
-- Accepts: spellIdentifier, targetUnit; Returns: inRange (bool)

-- Base API locals
local InCombatLockdown       = InCombatLockdown
-- Accepts: nil; Returns: inLockdown (bool)
local IsActionInRange        = IsActionInRange
-- Accepts: actionSlot; Returns: inRange (bool)

-- Lua locals
local mathmax                = math.max
local mathrandom             = math.random
local pairs                  = pairs
local tablesort              = table.sort
local type                   = type
local unpack                 = unpack

-- File locals


-- IsInRangeTable generated manually by FilterItemRange
local RangeTableByType = {
  Melee = {
    Hostile = {
      RangeIndex = {},
      ItemRange = {}
    },
    Friendly = {
      RangeIndex = {},
      ItemRange = {}
    }
  },
  Ranged = {
    Hostile = {
      RangeIndex = {},
      ItemRange = {}
    },
    Friendly = {
      RangeIndex = {},
      ItemRange = {}
    }
  }
}
do
  local Types = { "Melee", "Ranged" }

  for _, Type in pairs(Types) do
    local ItemRange = DBC.ItemRange[Type]
    local Hostile, Friendly = RangeTableByType[Type].Hostile, RangeTableByType[Type].Friendly

    -- Map the range indices and sort them since the order is not guaranteed.
    Hostile.RangeIndex = { unpack(ItemRange.Hostile.RangeIndex) }
    tablesort(Hostile.RangeIndex, Utils.SortMixedASC)
    Friendly.RangeIndex = { unpack(ItemRange.Friendly.RangeIndex) }
    tablesort(Friendly.RangeIndex, Utils.SortMixedASC)

    -- Take randomly one item for each range.
    for k, v in pairs(ItemRange.Hostile.ItemRange) do
      Hostile.ItemRange[k] = v[mathrandom(1, #v)]
    end
    for k, v in pairs(ItemRange.Friendly.ItemRange) do
      Friendly.ItemRange[k] = v[mathrandom(1, #v)]
    end
  end
end

-- Debug function for manually fixing the DBC ItemRange table
function HL:CheckRangeTable()
  if not Target:Exists() or not Player:CanAttack(Target) or not Target:IsInRange(5) then
    HL.Print("You must have a hostile target (dummies are ok) selected and be within 5 yards of it to use this function.")
    return
  end
  local Types = { "Melee", "Ranged" }
  local OverallFailures = 0
  for _, Type in pairs(Types) do
    local DBCTable = DBC.ItemRange[Type]
    --local TableTypes = { "Hostile", "Friendly" }
    local TableTypes = { "Hostile" }
    for _, TableType in pairs(TableTypes) do
      for _,v in pairs(DBCTable[TableType].RangeIndex) do
        local Failures = 0
        for _,v2 in pairs(DBCTable[TableType].ItemRange[v]) do
          local MaxRange = 0
          local HasOnUseSpell = HL.Item(v2):OnUseSpell()
          local InRangeCheck = IsItemInRange(v2, Target:ID())
          if Type == "Melee" and not InRangeCheck then
            HL.Print("---------")
            HL.Print("Table Type: "..tostring(TableType).."-"..tostring(Type))
            HL.Print("Range Being Checked: "..tostring(v))
            HL.Print("Item with Bad Range Check: "..tostring(v2))
            HL.Print("IsItemInRange: "..tostring(InRangeCheck))
            Failures = Failures + 1
            OverallFailures = OverallFailures + 1
          end
          if Type == "Ranged" then
            MaxRange = HasOnUseSpell and HL.Item(v2):OnUseSpell().MaximumRange or 0
          end
          if (Type == "Ranged" and MaxRange ~= v) or not HasOnUseSpell or not InRangeCheck then
            HL.Print("---------")
            HL.Print("Table Type: "..tostring(TableType).."-"..tostring(Type))
            HL.Print("Range Being Checked: "..tostring(v))
            HL.Print("Item with Bad Range: "..tostring(v2))
            HL.Print("Actual Item Range: "..tostring(MaxRange))
            HL.Print("IsItemInRange: "..tostring(InRangeCheck))
            Failures = Failures + 1
            OverallFailures = OverallFailures + 1
          end
        end
        if Failures > 0 then
          HL.Print("----------------")
          HL.Print("Table Type: "..tostring(Type))
          HL.Print("Total Items in Range "..tostring(v)..": "..tostring(#DBCTable[TableType].ItemRange[v]))
          HL.Print("Total Failures: "..tostring(Failures))
        end
      end
    end
  end
  HL.Print("----------------")
  HL.Print("Overall Failures: "..tostring(OverallFailures))
end

--- ============================ CONTENT ============================
-- Get if the unit is in range, distance check through IsItemInRange.
-- Do keep in mind that if you're checking the range for a distance from the player (player-centered AoE like Fan of Knives),
-- you should use the radius - 1.5yds as distance (ex: instead of 10 you should use 8.5) because the player CombatReach is ignored (the distance is computed from the center to the edge, instead of edge to edge).
-- Supported hostile ranges (will take a lower one if you specify a different one): 5 - 6.5 - 7 - 8 - 10 - 15 - 20 - 25 - 30 - 35 - 38 - 40 - 45 - 50 - 55 - 60 - 70 - 80 - 90 - 100
function Unit:IsInRange(Distance)
  assert(type(Distance) == "number", "Distance must be a number.")
  assert(Distance >= 5 and Distance <= 100, "Distance must be between 5 and 100.")

  local GUID = self:GUID()
  if not GUID then return false end

  local UnitInfo = Cache.UnitInfo[GUID]
  if not UnitInfo then
    UnitInfo = {}
    Cache.UnitInfo[GUID] = UnitInfo
  end
  local UnitInfoIsInRange = UnitInfo.IsInRange
  if not UnitInfoIsInRange then
    UnitInfoIsInRange = {}
    UnitInfo.IsInRange = UnitInfoIsInRange
  end

  local Identifier = Distance -- Considering the Distance can change if it doesn't exist we use the one passed as argument for the cache
  local IsInRange = UnitInfoIsInRange[Identifier]
  if IsInRange == nil then
    -- For now, if we're in combat and trying to range check a friendly unit or enemy player, just return true to avoid icon shading.
    -- TODO: Come up with friendly tracking while in combat.
    if InCombatLockdown() and (self:IsAPlayer() or not Player:CanAttack(self)) then return true end
    -- Select the hostile or friendly range table
    local RangeTableByReaction = RangeTableByType.Ranged
    local RangeTable = Player:CanAttack(self) and RangeTableByReaction.Hostile or RangeTableByReaction.Friendly
    local ItemRange = RangeTable.ItemRange

    -- If the distance we want to check doesn't exists, we look for a fallback.
    if not ItemRange[Distance] then
      -- Iterate in reverse order the ranges in order to find the exact rannge or one that is lower than the one we look for (so we are guarantee it is in range)
      local RangeIndex = RangeTable.RangeIndex
      for i = #RangeIndex, 1, -1 do
        local Range = RangeIndex[i]
        if Range == Distance then break end
        if Range < Distance then
          Distance = Range
          break
        end
      end
    end

    IsInRange = IsItemInRange(ItemRange[Distance], self:ID())
    UnitInfoIsInRange[Identifier] = IsInRange
  end

  return IsInRange
end

-- Get if the unit is in range, distance check through IsItemInRange.
-- Melee ranges are different than Ranged one, we can only check the 5y Melee range through items at this moment.
-- If you have a spell that increase your melee range you should instead use Unit:IsSpellInRange().
-- Supported hostile ranges: 5
-- Supported friendly ranges: 5
function Unit:IsInMeleeRange(Distance)
  assert(type(Distance) == "number", "Distance must be a number.")
  assert(Distance >= 5 and Distance <= 100, "Distance must be between 5 and 100.")

  -- At this moment we cannot check multiple melee range (5, 8, 10), only the 5yds one from the item.
  -- So we use the ranged item while substracting 1.5y, which is the player hitbox radius.
  -- Make sure subtracting 1.5y won't put us under 5y.
  Distance = mathmax(Distance - 1.5, 5)
  if (Distance ~= 5) then
    return self:IsInRange(Distance)
  end

  local GUID = self:GUID()
  if not GUID then return false end

  -- Again, if in combat and target is friendly unit or enemy player, return true to avoid icon shading.
  -- TODO: Come up with friendly tracking while in combat.
  if InCombatLockdown() and (self:IsAPlayer() or not Player:CanAttack(self)) then return true end

  local RangeTableByReaction = RangeTableByType.Melee
  local RangeTable = Player:CanAttack(self) and RangeTableByReaction.Hostile or RangeTableByReaction.Friendly
  local ItemRange = RangeTable.ItemRange

  return IsItemInRange(ItemRange[Distance], self:ID())
end

-- Get if the unit is in range, distance check through IsSpellInRange (works only for targeted spells only)
function Unit:IsSpellInRange(ThisSpell)
  local GUID = self:GUID()
  if not GUID then return false end
  
  return IsSpellInRange(ThisSpell:ID(), self:ID())
end

-- Get if the unit is in range, distance check through IsItemInRange (works only for targeted items only)
function Unit:IsItemInRange(Item)
  local GUID = self:GUID()
  if not GUID then return false end

  -- If in combat and target is friendly or an enemy player, return false.
  if InCombatLockdown() and (self:IsAPlayer() or not Player:CanAttack(self)) then return false end
  return IsItemInRange(Item:ID(), self:ID())
end

-- Get if the unit is in range, distance check through IsActionInRange (works only for targeted actions only)
function Unit:IsActionInRange(ActionSlot)
  return IsActionInRange(ActionSlot, self:ID())
end

-- Find Range mixin, used by Unit:MinDistance() and Unit:MaxDistance()
local function FindRange(ThisUnit, Max)
  if InCombatLockdown() and (ThisUnit:IsAPlayer() or not Player:CanAttack(ThisUnit)) then return 0 end
  local RangeTableByReaction = RangeTableByType.Ranged
  local RangeTable = Player:CanAttack(ThisUnit) and RangeTableByReaction.Hostile or RangeTableByReaction.Friendly
  local RangeIndex = RangeTable.RangeIndex

  for i = #RangeIndex - (Max and 1 or 0), 1, -1 do
    if not ThisUnit:IsInRange(RangeIndex[i]) then
      return Max and RangeIndex[i + 1] or RangeIndex[i]
    end
  end
end

-- Get the minimum distance to the player, using Unit:IsInRange().
function Unit:MinDistance()
  return FindRange(self)
end

-- Get the maximum distance to the player, using Unit:IsInRange().
function Unit:MaxDistance()
  return FindRange(self, true)
end
