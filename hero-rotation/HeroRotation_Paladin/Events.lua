--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
-- HeroRotation
local HR = HeroRotation
-- Lua
local select = select
-- File Locals
HR.Commons = HR.Commons or {}
HR.Commons.Paladin = HR.Commons.Paladin or {}
local Paladin = HR.Commons.Paladin
-- Spell IDs
local HolyCrusaderStrikeSpellID = 385127
local DivineHammerSpellID = 198034
-- Initialize
Paladin.HPGCount = 0
Paladin.DivineHammerActive = false

--- ============================ CONTENT ============================
--- ===== HPGTo2Dawn Tracker =====
local Spec = Cache.Persistent.Player.Spec[1]
Paladin.HPGCount = 0
HL:RegisterForSelfCombatEvent(
  function (...)
    if Spec == 66 then
      Paladin.HPGCount = Paladin.HPGCount + 1
    end
  end
, "SPELL_ENERGIZE")

HL:RegisterForSelfCombatEvent(
  function (...)
    local SpellID = select(12, ...)
    if SpellID == HolyCrusaderStrikeSpellID then
      Paladin.HPGCount = 0
    elseif SpellID == DivineHammerSpellID then -- Divine Hammer
      Paladin.DivineHammerActive = true
    end
  end
, "SPELL_AURA_APPLIED", "SPELL_AURA_APPLIED_DOSE")

HL:RegisterForSelfCombatEvent(
  function (...)
    local SpellID = select(12, ...)
    if SpellID == DivineHammerSpellID then -- Divine Hammer
      Paladin.DivineHammerActive = false
    end
  end
  , "SPELL_AURA_REMOVED"
)

--- ======= NON-COMBATLOG =======

--- ======= COMBATLOG =======
  --- Combat Log Arguments
    ------- Base -------
      --     1        2         3           4           5           6              7             8         9        10           11
      -- TimeStamp, Event, HideCaster, SourceGUID, SourceName, SourceFlags, SourceRaidFlags, DestGUID, DestName, DestFlags, DestRaidFlags

    ------- Prefixes -------
      --- SWING
      -- N/A

      --- SPELL & SPELL_PACIODIC
      --    12        13          14
      -- SpellID, SpellName, SpellSchool

    ------- Suffixes -------
      --- _CAST_START & _CAST_SUCCESS & _SUMMON & _RESURRECT
      -- N/A

      --- _CAST_FAILED
      --     15
      -- FailedType

      --- _AURA_APPLIED & _AURA_REMOVED & _AURA_REFRESH
      --    15
      -- AuraType

      --- _AURA_APPLIED_DOSE
      --    15       16
      -- AuraType, Charges

      --- _INTERRUPT
      --      15            16             17
      -- ExtraSpellID, ExtraSpellName, ExtraSchool

      --- _HEAL
      --   15         16         17        18
      -- Amount, Overhealing, Absorbed, Critical

      --- _DAMAGE
      --   15       16       17       18        19       20        21        22        23
      -- Amount, Overkill, School, Resisted, Blocked, Absorbed, Critical, Glancing, Crushing

      --- _MISSED
      --    15        16           17
      -- MissType, IsOffHand, AmountMissed

    ------- Special -------
      --- UNIT_DIED, UNIT_DESTROYED
      -- N/A

  --- End Combat Log Arguments
