--- ============================ HEADER ============================
-- HeroLib
local HL      = HeroLib
local Unit    = HL.Unit
local Player  = Unit.Player
local Spell   = HL.Spell
-- Spells
local SpellProt = Spell.Paladin.Protection
local SpellRet  = Spell.Paladin.Retribution
-- Localize frequently used functions
local AddCoreOverride = HL.AddCoreOverride
-- Localize frequently used spells
local AvengingWrathBuffProt = SpellProt.AvengingWrathBuff
local SentinelBuff = SpellProt.SentinelBuff
local Sentinel = SpellProt.Sentinel
local AvengingWrath = SpellProt.AvengingWrath
local BastionofLightBuffProt = SpellProt.BastionofLightBuff
local AvengingWrathBuffRet = SpellRet.AvengingWrathBuff
local BastionofLightBuffRet = SpellRet.BastionofLightBuff
local RiteofAdjuration = SpellProt.RiteofAdjuration
local RiteofAdjurationBuff = SpellProt.RiteofAdjurationBuff
local RiteofSanctification = SpellProt.RiteofSanctification
local RiteofSanctificationBuff = SpellProt.RiteofSanctificationBuff
-- Lua

--- ============================ CONTENT ============================
-- Protection, ID: 66
local ProtPalBuffUp
ProtPalBuffUp = AddCoreOverride("Player.BuffUp",
  function(self, Spell, AnyCaster, BypassRecovery)
    local BaseCheck = ProtPalBuffUp(self, Spell, AnyCaster, BypassRecovery)
    if Spell == AvengingWrathBuffProt and Sentinel:IsAvailable() then
      return Player:BuffUp(SentinelBuff)
    else
      return BaseCheck
    end
  end
, 66)

local ProtPalBuffRemains
ProtPalBuffRemains = AddCoreOverride("Player.BuffRemains",
  function(self, Spell, AnyCaster, BypassRecovery)
    local BaseCheck = ProtPalBuffRemains(self, Spell, AnyCaster, BypassRecovery)
    if Spell == AvengingWrathBuffProt and Sentinel:IsAvailable() then
      return Player:BuffRemains(SentinelBuff)
    else
      return BaseCheck
    end
  end
, 66)

local ProtPalCDRemains
ProtPalCDRemains = AddCoreOverride("Spell.CooldownRemains",
  function(self, BypassRecovery)
    local BaseCheck = ProtPalCDRemains(self, BypassRecovery)
    if self == AvengingWrath and Sentinel:IsAvailable() then
      return Sentinel:CooldownRemains()
    else
      return BaseCheck
    end
  end
, 66)

local ProtPalIsAvail
ProtPalIsAvail = AddCoreOverride("Spell.IsAvailable",
  function(self, CheckPet)
    local BaseCheck = ProtPalIsAvail(self, CheckPet)
    if self == AvengingWrath and Sentinel:IsAvailable() then
      return Sentinel:IsAvailable()
    else
      return BaseCheck
    end
  end
, 66)

local ProtPalIsCastable
ProtPalIsCastable = AddCoreOverride("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = ProtPalIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == RiteofAdjuration then
      return BaseCheck and Player:BuffDown(RiteofAdjurationBuff)
    elseif self == RiteofSanctification then
      return BaseCheck and Player:BuffDown(RiteofSanctificationBuff)
    else
      return BaseCheck
    end
  end
, 66)

AddCoreOverride("Player.JudgmentPower",
  function(self)
    local JP = 1
    if Player:BuffUp(AvengingWrathBuffProt) or Player:BuffUp(SentinelBuff) then
      JP = JP + 1
    end
    if Player:BuffUp(BastionofLightBuffProt) then
      JP = JP + 2
    end
    return JP
  end
, 66)

-- Retribution, ID: 70
AddCoreOverride("Player.JudgmentPower",
  function(self)
    local JP = 1
    if Player:BuffUp(AvengingWrathBuffRet) then
      JP = JP + 1
    end
    if Player:BuffUp(BastionofLightBuffRet) then
      JP = JP + 2
    end
    return JP
  end
, 70)

-- Example (Arcane Mage)
-- HL.AddCoreOverride ("Spell.IsCastableP",
-- function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
--   if Range then
--     local RangeUnit = ThisUnit or Target;
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and RangeUnit:IsInRange( Range, AoESpell );
--   elseif self == SpellArcane.MarkofAluneth then
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and not Player:IsCasting(self);
--   else
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0;
--   end;
-- end
-- , 62);