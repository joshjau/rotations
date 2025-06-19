--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL          = HeroLib
local Cache       = HeroCache
local Unit        = HL.Unit
local Player      = Unit.Player
local Target      = Unit.Target
local Boss        = Unit.Boss
local Pet         = Unit.Pet
local Spell       = HL.Spell
local Item        = HL.Item
-- HeroRotation
local HR          = HeroRotation
local Cast        = HR.Cast
local CDsON       = HR.CDsON
local AoEON       = HR.AoEON
-- Num/Bool Helper Functions
local num         = HR.Commons.Everyone.num
local bool        = HR.Commons.Everyone.bool
-- lua
local mathmax     = math.max
local tableinsert = table.insert
local GetTime     = GetTime
-- WoW API
local Delay       = C_Timer.After

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DeathKnight.Unholy
local I = Item.DeathKnight.Unholy

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.TreacherousTransmitter:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  CommonsDS = HR.GUISettings.APL.DeathKnight.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.DeathKnight.CommonsOGCD,
  Unholy = HR.GUISettings.APL.DeathKnight.Unholy
}

--- ===== Rotation Variables =====
local VarSTPlanning
local VarAddsRemain
local VarApocTiming
local VarPopWounds
local VarPoolingRunicPower
local VarSpendRP
local VarSanCoilMult
local VarEpidemicTargets
local VarAbomActive, VarAbomRemains
local VarApocGhoulActive, VarApocGhoulRemains
local VarArmyGhoulActive, VarArmyGhoulRemains
local VarGargActive, VarGargRemains
local WoundSpender = (S.ClawingShadows:IsAvailable()) and S.ClawingShadows or S.ScourgeStrike
local AnyDnD = (S.Defile:IsAvailable()) and S.Defile or S.DeathAndDecay
local FesterStacks, FesterTargets
local FesteringAction, FesteringRange
local FesterMaxStacks = 6
local EnemiesMelee, EnemiesMeleeCount, ActiveEnemies
local Enemies10ySplash, Enemies10ySplashCount
local EnemiesWithoutVP
local BossFightRemains = 11111
local FightRemains = 11111
local Ghoul = HR.Commons.DeathKnight.GhoulTable

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Level, VarTrinket2Level
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Ex, VarTrinket2Ex
local VarTrinket1Buffs, VarTrinket2Buffs
local VarTrinket1Duration, VarTrinket2Duration
local VarTrinket1HighValue, VarTrinket2HighValue
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinketPriority, VarDamageTrinketPriority
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.Level == 0 or T2.Level == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
    VarTrinketFailures = VarTrinketFailures + 1
    Delay(5, function()
        SetTrinketVariables()
      end
    )
    return
  end

  Trinket1 = T1.Object
  Trinket2 = T2.Object

  VarTrinket1ID = T1.ID
  VarTrinket2ID = T2.ID

  VarTrinket1Level = T1.Level
  VarTrinket2Level = T2.Level

  VarTrinket1Spell = T1.Spell
  VarTrinket1Range = T1.Range
  VarTrinket1CastTime = T1.CastTime
  VarTrinket2Spell = T2.Spell
  VarTrinket2Range = T2.Range
  VarTrinket2CastTime = T2.CastTime

  VarTrinket1CD = T1.Cooldown
  VarTrinket2CD = T2.Cooldown

  VarTrinket1Ex = T1.Excluded
  VarTrinket2Ex = T2.Excluded

  VarTrinket1Buffs = Trinket1:HasUseBuff() or VarTrinket1ID == I.TreacherousTransmitter:ID()
  VarTrinket2Buffs = Trinket2:HasUseBuff() or VarTrinket2ID == I.TreacherousTransmitter:ID()

  VarTrinket1Duration = 0
  VarTrinket2Duration = 0
  if VarTrinket1ID == I.TreacherousTransmitter:ID() then
    VarTrinket1Duration = 15
  elseif VarTrinket1ID == I.FunhouseLens:ID() then
    VarTrinket1Duration = 15
  elseif VarTrinket1ID == I.SignetofthePriory:ID() then
    VarTrinket1Duration = 20
  else
    VarTrinket1Duration = Trinket1:BuffDuration()
  end
  if VarTrinket2ID == I.TreacherousTransmitter:ID() then
    VarTrinket2Duration = 15
  elseif VarTrinket2ID == I.FunhouseLens:ID() then
    VarTrinket2Duration = 15
  elseif VarTrinket2ID == I.SignetofthePriory:ID() then
    VarTrinket2Duration = 20
  else
    VarTrinket2Duration = Trinket2:BuffDuration()
  end

  VarTrinket1HighValue = VarTrinket1ID == I.TreacherousTransmitter:ID() and 2 or 1
  VarTrinket2HighValue = VarTrinket2ID == I.TreacherousTransmitter:ID() and 2 or 1

  VarTrinket1Sync = 0.5
  if VarTrinket1Buffs and (S.Apocalypse:IsAvailable() and VarTrinket1CD % 30 == 0 or S.DarkTransformation:IsAvailable() and VarTrinket1CD % 45 == 0) or VarTrinket1ID == I.TreacherousTransmitter:ID() then
    VarTrinket1Sync = 1
  end

  VarTrinket2Sync = 0.5
  if VarTrinket2Buffs and (S.Apocalypse:IsAvailable() and VarTrinket2CD % 30 == 0 or S.DarkTransformation:IsAvailable() and VarTrinket2CD % 45 == 0) or VarTrinket2ID == I.TreacherousTransmitter:ID() then
    VarTrinket2Sync = 1
  end

  VarTrinketPriority = 1
  -- Note: Using the below buff durations to avoid potential divide by zero errors.
  local T1BuffDuration = (VarTrinket1Duration > 0) and VarTrinket1Duration or 1
  local T2BuffDuration = (VarTrinket2Duration > 0) and VarTrinket2Duration or 1
  if not VarTrinket1Buffs and VarTrinket2Buffs and (Trinket2:HasCooldown() or not Trinket1:HasCooldown()) or VarTrinket2Buffs and ((VarTrinket2CD / T2BuffDuration) * (VarTrinket2Sync) * (VarTrinket2HighValue) * (1 + ((VarTrinket2Level - VarTrinket1Level) / 100))) > ((VarTrinket1CD / T1BuffDuration) * (VarTrinket1Sync) * (VarTrinket1HighValue) * (1 + ((VarTrinket1Level - VarTrinket2Level) / 100))) then
    VarTrinketPriority = 2
  end

  VarDamageTrinketPriority = 1
  if not VarTrinket1Buffs and not VarTrinket2Buffs and VarTrinket2Level >= VarTrinket1Level then
    VarDamageTrinketPriority = 2
  end
end
SetTrinketVariables()

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  {S.Asphyxiate, "Cast Asphyxiate (Interrupt)", function () return true; end},
}

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  AnyDnD = (S.Defile:IsAvailable()) and S.Defile or S.DeathAndDecay
  VarTrinketFailures = 0
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

--- ===== Helper Functions =====
local function DeathStrikeHeal()
  return (Settings.General.SoloMode and (Player:HealthPercentage() < Settings.Commons.UseDeathStrikeHP or Player:HealthPercentage() < Settings.Commons.UseDarkSuccorHP and Player:BuffUp(S.DeathStrikeBuff)))
end

local function UnitsWithoutVP(enemies)
  local WithoutVPCount = 0
  for _, CycleUnit in pairs(enemies) do
    if CycleUnit:DebuffDown(S.VirulentPlagueDebuff) then
      WithoutVPCount = WithoutVPCount + 1
    end
  end
  return WithoutVPCount
end

local function AddsFightRemains(enemies)
  local NonBossEnemies = {}
  for k in pairs(enemies) do
    if not Unit:IsInBossList(enemies[k]["UnitNPCID"]) then
      tableinsert(NonBossEnemies, enemies[k])
    end
  end
  return HL.FightRemains(NonBossEnemies)
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterDCAoE(TargetUnit)
  -- target_if=min:debuff.rotten_touch.remains*(buff.sudden_doom.react&talent.rotten_touch)
  return TargetUnit:DebuffRemains(S.RottenTouchDebuff) * num(Player:BuffUp(S.SuddenDoomBuff) and S.RottenTouch:IsAvailable())
end

local function EvaluateTargetIfFilterFWStack(TargetUnit)
  -- target_if=min:debuff.festering_wound.stack
  return TargetUnit:DebuffStack(S.FesteringWoundDebuff)
end

local function EvaluateTargetIfFilterTrollbaneSlow(TargetUnit)
  -- target_if=min:debuff.chains_of_ice_trollbane_slow.remains
  return TargetUnit:DebuffRemains(S.TrollbaneSlowDebuff)
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfFesteringStrikeAoE(TargetUnit)
  -- if=debuff.festering_wound.stack<2
  return TargetUnit:DebuffStack(S.FesteringWoundDebuff) < 2
end

local function EvaluateTargetIfFesteringStrikeAoEBurst(TargetUnit)
  -- if=debuff.festering_wound.stack<=2
  return TargetUnit:DebuffStack(S.FesteringWoundDebuff) <= 2
end

local function EvaluateTargetIfFesteringStrikeAoESetup(TargetUnit)
  -- if=talent.vile_contagion&cooldown.vile_contagion.remains<5&!debuff.festering_wound.at_max_stacks
  return TargetUnit:DebuffStack(S.FesteringWoundDebuff) < FesterMaxStacks
end

local function EvaluateTargetIfFesteringStrikeAoESetup2(TargetUnit)
  -- if=!talent.vile_contagion
  return not S.VileContagion:IsAvailable()
end

local function EvaluateTargetIfFesteringStrikeAoESetup3(TargetUnit)
  -- if=cooldown.vile_contagion.remains<5|death_knight.fwounded_targets=active_enemies&debuff.festering_wound.stack<=4
  return S.VileContagion:CooldownRemains() < 5 or FesterTargets == ActiveEnemies and TargetUnit:DebuffStack(S.FesteringWoundDebuff) <= 4
end

local function EvaluateTargetIfFesteringStrikeAoESetup4(TargetUnit)
  -- if=cooldown.apocalypse.remains<gcd&debuff.festering_wound.stack=0|death_knight.fwounded_targets<active_enemies
  return S.Apocalypse:CooldownRemains() < Player:GCD() and TargetUnit:DebuffDown(S.FesteringWoundDebuff) or FesterTargets < ActiveEnemies
end

local function EvaluateTargetIfFesteringStrikeCleave(TargetUnit)
  -- if=!buff.vampiric_strike.react&!variable.pop_wounds&debuff.festering_wound.stack<2|buff.festering_scythe.react
  return not S.VampiricStrikeAction:IsReady() and not VarPopWounds and TargetUnit:DebuffStack(S.FesteringWoundDebuff) < 2 or Player:BuffUp(S.FesteringScytheBuff)
end

local function EvaluateTargetIfFesteringStrikeCleave2(TargetUnit)
  -- if=!buff.vampiric_strike.react&cooldown.apocalypse.remains<variable.apoc_timing&debuff.festering_wound.stack<1
  return not S.VampiricStrikeAction:IsReady() and S.Apocalypse:CooldownRemains() < VarApocTiming and TargetUnit:DebuffDown(S.FesteringWoundDebuff)
end

local function EvaluateTargetIfFWStackMinCheck(TargetUnit)
  -- Check to make sure the target has FW stacks in order to use Apocalypse.
  return TargetUnit:DebuffUp(S.FesteringWoundDebuff)
end

local function EvaluateTargetIfUnholyAssaultCDsAoE(TargetUnit)
  -- if=variable.adds_remain&(debuff.festering_wound.stack>=2&cooldown.vile_contagion.remains<3|!talent.vile_contagion)
  return VarAddsRemain and (TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 2 and S.VileContagion:CooldownRemains() < 3 or not S.VileContagion:IsAvailable())
end

local function EvaluateTargetIfUnholyAssaultCDsAoESan(TargetUnit)
  -- if=variable.adds_remain&(debuff.festering_wound.stack>=2&cooldown.vile_contagion.remains<6|!talent.vile_contagion)
  return VarAddsRemain and (TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 2 and S.VileContagion:CooldownRemains() < 6 or not S.VileContagion:IsAvailable())
end

local function EvaluateTargetIfVileContagionCDsAoE(TargetUnit)
  -- if=debuff.festering_wound.stack>=4&variable.adds_remain
  return TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 4 and VarAddsRemain
end

local function EvaluateTargetIfVileContagionCDsShared(TargetUnit)
  -- if=variable.adds_remain&(debuff.festering_wound.stack=6&(defile.ticking|death_and_decay.ticking|cooldown.any_dnd.remains<3)|raid_event.adds.exists&raid_event.adds.remains<=11&raid_event.adds.remains>5|buff.death_and_decay.up&debuff.festering_wound.stack>=4|cooldown.any_dnd.remains<3&debuff.festering_wound.stack>=4)
  -- Note: Variable checked before CastTargetIf.
  return TargetUnit:DebuffStack(S.FesteringWoundDebuff) == 6 and (Player:DnDTicking() or AnyDnD:CooldownRemains() < 3) or Player:BuffUp(S.DeathAndDecayBuff) and TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 4 or AnyDnD:CooldownRemains() < 3 and TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 4
end

local function EvaluateTargetIfWoundSpenderAoE(TargetUnit)
  -- if=debuff.festering_wound.stack>=1&buff.death_and_decay.up&talent.bursting_sores&cooldown.apocalypse.remains>variable.apoc_timing
  -- Note: Talent and CDs checked before CastTargetIf.
  return TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 1
end

local function EvaluateTargetIfWoundSpenderAoE2(TargetUnit)
  -- if=debuff.chains_of_ice_trollbane_slow.up&debuff.chains_of_ice_trollbane_slow.remains<gcd
  return TargetUnit:DebuffUp(S.TrollbaneSlowDebuff) and TargetUnit:DebuffRemains(S.TrollbaneSlowDebuff) < Player:GCD()
end

local function EvaluateTargetIfWoundSpenderAoE3(TargetUnit)
  -- if=debuff.festering_wound.stack>=1&cooldown.apocalypse.remains>gcd|buff.vampiric_strike.react&dot.virulent_plague.ticking
  return TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 1 and S.Apocalypse:CooldownRemains() > Player:GCD() or S.VampiricStrikeAction:IsLearned() and TargetUnit:DebuffUp(S.VirulentPlagueDebuff)
end

local function EvaluateTargetIfWoundSpenderAoEBurst(TargetUnit)
  -- if=debuff.festering_wound.stack>=1|buff.vampiric_strike.react|buff.death_and_decay.up
  return TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 1 or S.VampiricStrikeAction:IsLearned() or Player:BuffUp(S.DeathAndDecayBuff)
end

local function EvaluateTargetIfWoundSpenderAoEBurst2(TargetUnit)
  -- if=debuff.chains_of_ice_trollbane_slow.up
  return TargetUnit:DebuffUp(S.TrollbaneSlowDebuff)
end

local function EvaluateTargetIfWoundSpenderAoESetup(TargetUnit)
  -- if=debuff.chains_of_ice_trollbane_slow.up&debuff.chains_of_ice_trollbane_slow.remains<gcd
  return TargetUnit:DebuffUp(S.TrollbaneSlowDebuff) and TargetUnit:DebuffRemains(S.TrollbaneSlowDebuff) < Player:GCD()
end

--- ===== CastCycle Functions =====
local function EvaluateCycleOutbreakCDs(TargetUnit)
  -- target_if=target.time_to_die>dot.virulent_plague.remains&dot.virulent_plague.ticks_remain<5,if=(dot.virulent_plague.refreshable|talent.superstrain&(dot.frost_fever.refreshable|dot.blood_plague.refreshable))&(!talent.unholy_blight|talent.plaguebringer)&(!talent.raise_abomination|talent.raise_abomination&cooldown.raise_abomination.remains>dot.virulent_plague.ticks_remain*3)
  return (TargetUnit:TimeToDie() > TargetUnit:DebuffRemains(S.VirulentPlagueDebuff) and TargetUnit:DebuffTicksRemain(S.VirulentPlagueDebuff) < 5) and ((TargetUnit:DebuffRefreshable(S.VirulentPlagueDebuff) or S.Superstrain:IsAvailable() and (TargetUnit:DebuffRefreshable(S.FrostFeverDebuff) or TargetUnit:DebuffRefreshable(S.BloodPlagueDebuff))) and (not S.UnholyBlight:IsAvailable() or S.Plaguebringer:IsAvailable()) and (not S.RaiseAbomination:IsAvailable() or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownRemains() > TargetUnit:DebuffTicksRemain(S.VirulentPlagueDebuff) * 3))
end

local function EvaluateCycleOutbreakCDsCleaveSan(TargetUnit)
  -- target_if=target.time_to_die>dot.virulent_plague.remains&dot.virulent_plague.ticks_remain<5,if=(dot.virulent_plague.refreshable|talent.morbidity&buff.infliction_of_sorrow.up&talent.superstrain&dot.frost_fever.refreshable&dot.blood_plague.refreshable)&(!talent.unholy_blight|talent.unholy_blight&cooldown.dark_transformation.remains>6)&(!talent.raise_abomination|talent.raise_abomination&cooldown.raise_abomination.remains>6)
  return (TargetUnit:TimeToDie() > TargetUnit:DebuffRemains(S.VirulentPlagueDebuff) and TargetUnit:DebuffTicksRemain(S.VirulentPlagueDebuff) < 5) and ((TargetUnit:DebuffRefreshable(S.VirulentPlagueDebuff) or S.Morbidity:IsAvailable() and Player:BuffUp(S.InflictionofSorrowBuff) and S.Superstrain:IsAvailable() and TargetUnit:DebuffRefreshable(S.FrostFeverDebuff) and TargetUnit:DebuffRefreshable(S.BloodPlagueDebuff)) and (not S.UnholyBlight:IsAvailable() or S.UnholyBlight:IsAvailable() and S.DarkTransformation:CooldownRemains() > 6) and (not S.RaiseAbomination:IsAvailable() or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownRemains() > 6))
end

local function EvaluateCycleOutbreakCDsSan(TargetUnit)
  -- target_if=target.time_to_die>dot.virulent_plague.remains&dot.virulent_plague.ticks_remain<5,if=(dot.virulent_plague.refreshable|talent.morbidity&buff.infliction_of_sorrow.up&talent.superstrain&dot.frost_fever.refreshable&dot.blood_plague.refreshable)&(!talent.unholy_blight|talent.unholy_blight&cooldown.dark_transformation.remains)&(!talent.raise_abomination|talent.raise_abomination&cooldown.raise_abomination.remains)
  return (TargetUnit:TimeToDie() > TargetUnit:DebuffRemains(S.VirulentPlagueDebuff) and TargetUnit:DebuffTicksRemain(S.VirulentPlagueDebuff) < 5) and ((TargetUnit:DebuffRefreshable(S.VirulentPlagueDebuff) or S.Morbidity:IsAvailable() and Player:BuffUp(S.InflictionofSorrowBuff) and S.Superstrain:IsAvailable() and TargetUnit:DebuffRefreshable(S.FrostFeverDebuff) and TargetUnit:DebuffRefreshable(S.BloodPlagueDebuff)) and (not S.UnholyBlight:IsAvailable() or S.UnholyBlight:IsAvailable() and S.DarkTransformation:CooldownDown()) and (not S.RaiseAbomination:IsAvailable() or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownDown()))
end

local function EvaluateCycleTrollbaneSlow(TargetUnit)
  -- target_if=debuff.chains_of_ice_trollbane_slow.up
  return TargetUnit:DebuffUp(S.TrollbaneSlowDebuff)
end

local function EvaluateCycleUnholyAssaultCDsAoESan(TargetUnit)
  -- target_if=debuff.festering_wound.stack<3,if=variable.adds_remain&talent.vile_contagion&debuff.festering_wound.stack<=2&cooldown.vile_contagion.remains<6
  return TargetUnit:DebuffStack(S.FesteringWoundDebuff) <= 2
end

--- ===== Rotation Functions =====
local function Precombat()
  -- snapshot_stats
  -- raise_dead
  if S.RaiseDead:IsCastable() then
    if Settings.Unholy.RaiseDeadCastLeft then
      if HR.CastLeft(S.RaiseDead) then return "raise_dead precombat 2 left"; end
    else
      if Cast(S.RaiseDead, nil, Settings.CommonsDS.DisplayStyle.RaiseDead) then return "raise_dead precombat 2 displaystyle"; end
    end
  end
  -- army_of_the_dead,precombat_time=2
  if S.ArmyoftheDead:IsReady() and not Settings.Commons.DisableAotD then
    if Cast(S.ArmyoftheDead, nil, Settings.Unholy.DisplayStyle.ArmyOfTheDead) then return "army_of_the_dead precombat 4"; end
  end
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff|trinket.1.is.treacherous_transmitter
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff|trinket.2.is.treacherous_transmitter
  -- variable,name=trinket_1_duration,op=setif,value=trinket.1.is.treacherous_transmitter*15+trinket.1.is.funhouse_lens*15+trinket.1.is.signet_of_the_priory*20,value_else=trinket.1.proc.any_dps.duration,condition=trinket.1.is.treacherous_transmitter|trinket.1.is.funhouse_lens|trinket.1.is.signet_of_the_priory
  -- variable,name=trinket_2_duration,op=setif,value=trinket.2.is.treacherous_transmitter*15+trinket.2.is.funhouse_lens*15+trinket.2.is.signet_of_the_priory*20,value_else=trinket.2.proc.any_dps.duration,condition=trinket.2.is.treacherous_transmitter|trinket.2.is.funhouse_lens|trinket.2.is.signet_of_the_priory
  -- variable,name=trinket_1_high_value,op=setif,value=2,value_else=1,condition=trinket.1.is.treacherous_transmitter
  -- variable,name=trinket_2_high_value,op=setif,value=2,value_else=1,condition=trinket.2.is.treacherous_transmitter
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(talent.apocalypse&trinket.1.cooldown.duration%%cooldown.apocalypse.duration=0|talent.dark_transformation&trinket.1.cooldown.duration%%cooldown.dark_transformation.duration=0)|trinket.1.is.treacherous_transmitter
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(talent.apocalypse&trinket.2.cooldown.duration%%cooldown.apocalypse.duration=0|talent.dark_transformation&trinket.2.cooldown.duration%%cooldown.dark_transformation.duration=0)|trinket.2.is.treacherous_transmitter
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs&(trinket.2.has_cooldown|!trinket.1.has_cooldown)|variable.trinket_2_buffs&((trinket.2.cooldown.duration%variable.trinket_2_duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync)*(variable.trinket_2_high_value)*(1+((trinket.2.ilvl-trinket.1.ilvl)%100)))>((trinket.1.cooldown.duration%variable.trinket_1_duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync)*(variable.trinket_1_high_value)*(1+((trinket.1.ilvl-trinket.2.ilvl)%100)))
  -- variable,name=damage_trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&!variable.trinket_2_buffs&trinket.2.ilvl>=trinket.1.ilvl
  -- Note: Moved the above variable definitions to initial profile load, SPELLS_CHANGED, and PLAYER_EQUIPMENT_CHANGED.
  -- Manually added: outbreak
  if S.Outbreak:IsReady() then
    if Cast(S.Outbreak, nil, nil, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak precombat 6"; end
  end
  -- Manually added: festering_strike if in melee range
  if FesteringAction:IsReady() then
    if Cast(FesteringAction, nil, nil, not Target:IsInMeleeRange(FesteringRange)) then return "festering_strike precombat 8"; end
  end
end

local function AoE()
  -- festering_strike,if=buff.festering_scythe.react
  if S.FesteringScytheAction:IsReady() then
    if Cast(S.FesteringScytheAction, nil, nil, not Target:IsInMeleeRange(14)) then return "festering_scythe aoe 2"; end
  end
  -- death_coil,target_if=min:debuff.rotten_touch.remains*(buff.sudden_doom.react&talent.rotten_touch),if=rune<4&active_enemies<variable.epidemic_targets&buff.gift_of_the_sanlayn.up&gcd<=1.0&(!raid_event.adds.exists&fight_remains>buff.dark_transformation.remains*2|raid_event.adds.exists&raid_event.adds.remains>buff.dark_transformation.remains*2)
  if S.DeathCoil:IsReady() and (Player:Rune() < 4 and ActiveEnemies < VarEpidemicTargets and Player:BuffUp(S.GiftoftheSanlaynBuff)) then
    if Everyone.CastTargetIf(S.DeathCoil, EnemiesMelee, "min", EvaluateTargetIfFilterDCAoE, nil, not Target:IsInRange(40), Settings.Unholy.GCDasOffGCD.DeathCoil) then return "death_coil aoe 4"; end
  end
  -- epidemic,if=rune<4&active_enemies>variable.epidemic_targets&buff.gift_of_the_sanlayn.up&gcd<=1.0&(!raid_event.adds.exists&fight_remains>buff.dark_transformation.remains*2|raid_event.adds.exists&raid_event.adds.remains>buff.dark_transformation.remains*2)
  if S.Epidemic:IsReady() and (Player:Rune() < 4 and ActiveEnemies > VarEpidemicTargets and Player:BuffUp(S.GiftoftheSanlaynBuff)) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic aoe 6"; end
  end
  -- wound_spender,target_if=max:debuff.festering_wound.stack,if=debuff.festering_wound.stack>=1&buff.death_and_decay.up&talent.bursting_sores&cooldown.apocalypse.remains>variable.apoc_timing
  if WoundSpender:IsReady() and (Player:BuffUp(S.DeathAndDecayBuff) and S.BurstingSores:IsAvailable() and S.Apocalypse:CooldownRemains() > VarApocTiming) then
    if Everyone.CastTargetIf(WoundSpender, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfWoundSpenderAoE, not Target:IsInMeleeRange(5)) then return "wound_spender aoe 8"; end
  end
  -- death_coil,target_if=min:debuff.rotten_touch.remains*(buff.sudden_doom.react&talent.rotten_touch),if=!variable.pooling_runic_power&active_enemies<variable.epidemic_targets
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower and ActiveEnemies < VarEpidemicTargets) then
    if Everyone.CastTargetIf(S.DeathCoil, EnemiesMelee, "min", EvaluateTargetIfFilterDCAoE, nil, not Target:IsInRange(40), Settings.Unholy.GCDasOffGCD.DeathCoil) then return "death_coil aoe 10"; end
  end
  -- epidemic,if=!variable.pooling_runic_power
  if S.Epidemic:IsReady() and (not VarPoolingRunicPower) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic aoe 12"; end
  end
  -- wound_spender,target_if=debuff.chains_of_ice_trollbane_slow.up
  if WoundSpender:IsReady() then
    if Everyone.CastCycle(WoundSpender, EnemiesMelee, EvaluateCycleTrollbaneSlow, not Target:IsInMeleeRange(5)) then return "wound_spender aoe 14"; end
  end
  -- festering_strike,target_if=max:debuff.festering_wound.stack,if=cooldown.apocalypse.remains<variable.apoc_timing|buff.festering_scythe.react
  if FesteringAction:IsReady() and (S.Apocalypse:CooldownRemains() < VarApocTiming or Player:BuffUp(S.FesteringScytheBuff)) then
    if Everyone.CastTargetIf(FesteringAction, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, nil, not Target:IsInMeleeRange(FesteringRange)) then return "festering_strike aoe 16"; end
  end
  -- festering_strike,target_if=min:debuff.festering_wound.stack,if=debuff.festering_wound.stack<2
  if FesteringAction:IsReady() then
    if Everyone.CastTargetIf(FesteringAction, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFesteringStrikeAoE, not Target:IsInMeleeRange(FesteringRange)) then return "festering_strike aoe 18"; end
  end
  -- wound_spender,target_if=max:debuff.festering_wound.stack,if=debuff.festering_wound.stack>=1&cooldown.apocalypse.remains>gcd|buff.vampiric_strike.react&dot.virulent_plague.ticking
  if WoundSpender:IsReady() then
    if Everyone.CastTargetIf(WoundSpender, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfWoundSpenderAoE3, not Target:IsInMeleeRange(5)) then return "wound_spender aoe 20"; end
  end
end

local function AoEBurst()
  -- festering_strike,if=buff.festering_scythe.react
  if S.FesteringScytheAction:IsReady() then
    if Cast(S.FesteringScytheAction, nil, nil, not Target:IsInMeleeRange(14)) then return "festering_scythe aoe_burst 2"; end
  end
  -- death_coil,target_if=min:debuff.rotten_touch.remains*(buff.sudden_doom.react&talent.rotten_touch),if=!buff.vampiric_strike.react&active_enemies<variable.epidemic_targets&(!talent.bursting_sores|talent.bursting_sores&buff.sudden_doom.react&death_knight.fwounded_targets<active_enemies*0.4|buff.sudden_doom.react&(talent.doomed_bidding&talent.menacing_magus|talent.rotten_touch|debuff.death_rot.remains<gcd)|rune<2)|(rune<4|active_enemies<4|raid_event.pull.has_boss)&active_enemies<variable.epidemic_targets&buff.gift_of_the_sanlayn.up&gcd<=1.0&(!raid_event.adds.exists&fight_remains>buff.dark_transformation.remains*2|raid_event.adds.exists&raid_event.adds.remains>buff.dark_transformation.remains*2)
  if S.DeathCoil:IsReady() and (not S.VampiricStrikeAction:IsLearned() and EnemiesMeleeCount < VarEpidemicTargets and (not S.BurstingSores:IsAvailable() or S.BurstingSores:IsAvailable() and Player:BuffUp(S.SuddenDoomBuff) and FesterTargets < EnemiesMeleeCount * 0.4 or Player:BuffUp(S.SuddenDoomBuff) and (S.DoomedBidding:IsAvailable() and S.MenacingMagus:IsAvailable() or S.RottenTouch:IsAvailable() or Target:DebuffRemains(S.DeathRotDebuff) < Player:GCD()) or Player:Rune() < 2) or (Player:Rune() < 4 or ActiveEnemies < 4 or HL.AnyBossExists()) and ActiveEnemies < VarEpidemicTargets and Player:BuffUp(S.GiftoftheSanlaynBuff)) then
    if Everyone.CastTargetIf(S.DeathCoil, EnemiesMelee, "min", EvaluateTargetIfFilterDCAoE, nil, not Target:IsInRange(40), Settings.Unholy.GCDasOffGCD.DeathCoil) then return "death_coil aoe_burst 4"; end
  end
  -- epidemic,if=!buff.vampiric_strike.react&(!talent.bursting_sores|talent.bursting_sores&buff.sudden_doom.react&death_knight.fwounded_targets<active_enemies*0.4|buff.sudden_doom.react&(buff.a_feast_of_souls.up|debuff.death_rot.remains<gcd|debuff.death_rot.stack<10)|rune<2)|(rune<4|raid_event.pull.has_boss)&active_enemies>=variable.epidemic_targets&buff.gift_of_the_sanlayn.up&gcd<=1.0&(!raid_event.adds.exists&fight_remains>buff.dark_transformation.remains*2|raid_event.adds.exists&raid_event.adds.remains>buff.dark_transformation.remains*2)
  if S.Epidemic:IsReady() and (not S.VampiricStrikeAction:IsLearned() and (not S.BurstingSores:IsAvailable() or S.BurstingSores:IsAvailable() and Player:BuffUp(S.SuddenDoomBuff) and FesterTargets < ActiveEnemies * 0.4 or Player:BuffUp(S.SuddenDoomBuff) and (Player:BuffUp(S.AFeastofSoulsBuff) or Target:DebuffRemains(S.DeathRotDebuff) < Player:GCD() or Target:DebuffStack(S.DeathRotDebuff) < 10) or Player:Rune() < 2) or (Player:Rune() < 4 or HL.AnyBossExists()) and ActiveEnemies >= VarEpidemicTargets and Player:BuffUp(S.GiftoftheSanlaynBuff)) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic aoe_burst 6"; end
  end
  -- wound_spender,target_if=debuff.chains_of_ice_trollbane_slow.up
  if WoundSpender:IsReady() then
    if Everyone.CastCycle(WoundSpender, EnemiesMelee, EvaluateCycleTrollbaneSlow, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender aoe_burst 8"; end
  end
  -- wound_spender,target_if=max:debuff.festering_wound.stack,if=debuff.festering_wound.stack>=1|buff.vampiric_strike.react|buff.death_and_decay.up
  if WoundSpender:IsReady() then
    if Everyone.CastTargetIf(WoundSpender, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfWoundSpenderAoEBurst, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender aoe_burst 10"; end
  end
  -- death_coil,target_if=min:debuff.rotten_touch.remains*(buff.sudden_doom.react&talent.rotten_touch),if=active_enemies<variable.epidemic_targets
  if S.DeathCoil:IsReady() and (ActiveEnemies < VarEpidemicTargets) then
    if Everyone.CastTargetIf(S.DeathCoil, EnemiesMelee, "min", EvaluateTargetIfFilterDCAoE, nil, not Target:IsInRange(40), Settings.Unholy.GCDasOffGCD.DeathCoil) then return "death_coil aoe_burst 12"; end
  end
  -- epidemic,if=variable.epidemic_targets<=active_enemies
  if S.Epidemic:IsReady() and (VarEpidemicTargets <= ActiveEnemies) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic aoe_burst 14"; end
  end
  -- festering_strike,target_if=min:debuff.festering_wound.stack,if=debuff.festering_wound.stack<=2
  if FesteringAction:IsReady() then
    if Everyone.CastTargetIf(FesteringAction, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFesteringStrikeAoEBurst, not Target:IsInMeleeRange(FesteringRange)) then return "festering_strike aoe_burst 16"; end
  end
  -- wound_spender,target_if=max:debuff.festering_wound.stack
  if WoundSpender:IsReady() then
    if Everyone.CastTargetIf(WoundSpender, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender aoe_burst 18"; end
  end
end

local function AoESetup()
  -- festering_strike,if=buff.festering_scythe.react
  if S.FesteringScytheAction:IsReady() then
    if Cast(S.FesteringScytheAction, nil, nil, not Target:IsInMeleeRange(14)) then return "festering_scythe aoe_setup 2"; end
  end
  -- festering_strike,target_if=max:debuff.festering_wound.stack,if=talent.vile_contagion&cooldown.vile_contagion.remains<5&!debuff.festering_wound.at_max_stacks
  if FesteringAction:IsReady() and (S.VileContagion:IsAvailable() and S.VileContagion:CooldownRemains() < 5) then
    if Everyone.CastTargetIf(FesteringAction, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFesteringStrikeAoESetup, not Target:IsInMeleeRange(FesteringRange)) then return "festering_strike aoe_setup 4"; end
  end
  -- festering_strike,target_if=min:debuff.festering_wound.stack,if=death_knight.fwounded_targets=0&cooldown.apocalypse.remains<gcd&(cooldown.dark_transformation.remains&cooldown.unholy_assault.remains|cooldown.unholy_assault.remains|!talent.unholy_assault&!talent.pestilence|talent.pestilence&!death_and_decay.ticking&cooldown.dark_transformation.remains&rune<=4)
  if FesteringAction:IsReady() and (FesterTargets == 0 and S.Apocalypse:CooldownRemains() < Player:GCD() and (S.DarkTransformation:CooldownDown() and S.UnholyAssault:CooldownDown() or S.UnholyAssault:CooldownDown() or not S.UnholyAssault:IsAvailable()  and not S.Pestilence:IsAvailable() or S.Pestilence:IsAvailable() and not Player:DnDTicking() and S.DarkTransformation:CooldownDown() and Player:Rune() <= 4)) then
    if Everyone.CastTargetIf(FesteringAction, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, nil, not Target:IsInMeleeRange(FesteringRange)) then return "festering_strike aoe_setup 6"; end
  end
  -- wound_spender,target_if=debuff.chains_of_ice_trollbane_slow.up
  if WoundSpender:IsReady() then
    if Everyone.CastCycle(WoundSpender, EnemiesMelee, EvaluateCycleTrollbaneSlow, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender aoe_setup 8"; end
  end
  -- death_coil,target_if=min:debuff.rotten_touch.remains*(buff.sudden_doom.react&talent.rotten_touch),if=!variable.pooling_runic_power&active_enemies<variable.epidemic_targets&rune<4
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower and ActiveEnemies < VarEpidemicTargets and Player:Rune() < 4) then
    if Everyone.CastTargetIf(S.DeathCoil, EnemiesMelee, "min", EvaluateTargetIfFilterDCAoE, nil, not Target:IsInRange(40), Settings.Unholy.GCDasOffGCD.DeathCoil) then return "death_coil aoe_setup 10"; end
  end
  -- epidemic,if=!variable.pooling_runic_power&variable.epidemic_targets<=active_enemies&rune<4
  if S.Epidemic:IsReady() and (not VarPoolingRunicPower and VarEpidemicTargets <= ActiveEnemies and Player:Rune() < 4) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic aoe_setup 12"; end
  end
  -- any_dnd,if=!buff.death_and_decay.up&(!talent.bursting_sores&!talent.vile_contagion|death_knight.fwounded_targets=active_enemies|death_knight.fwounded_targets>=8|raid_event.adds.exists&raid_event.adds.remains<=11&raid_event.adds.remains>5|!buff.death_and_decay.up&talent.defile)
  if AnyDnD:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) and (not S.BurstingSores:IsAvailable() and not S.VileContagion:IsAvailable() or FesterTargets == ActiveEnemies or FesterTargets >= 8 or Player:BuffDown(S.DeathAndDecayBuff) and S.Defile:IsAvailable())) then
    if Cast(AnyDnD, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "any_dnd aoe_setup 14"; end
  end
  -- death_coil,target_if=min:debuff.rotten_touch.remains*(buff.sudden_doom.react&talent.rotten_touch),if=!variable.pooling_runic_power&active_enemies<variable.epidemic_targets&(buff.sudden_doom.react|death_knight.fwounded_targets=active_enemies|death_knight.fwounded_targets>=8)
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower and ActiveEnemies < VarEpidemicTargets and (Player:BuffUp(S.SuddenDoomBuff) or FesterTargets == ActiveEnemies or FesterTargets >= 8)) then
    if Everyone.CastTargetIf(S.DeathCoil, EnemiesMelee, "min", EvaluateTargetIfFilterDCAoE, nil, not Target:IsInRange(40), Settings.Unholy.GCDasOffGCD.DeathCoil) then return "death_coil aoe_setup 16"; end
  end
  -- epidemic,if=!variable.pooling_runic_power&variable.epidemic_targets<=active_enemies&(buff.sudden_doom.react|death_knight.fwounded_targets=active_enemies|death_knight.fwounded_targets>=8)
  if S.Epidemic:IsReady() and (not VarPoolingRunicPower and VarEpidemicTargets <= ActiveEnemies and (Player:BuffUp(S.SuddenDoomBuff) or FesterTargets == ActiveEnemies or FesterTargets >= 8)) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic aoe_setup 18"; end
  end
  -- death_coil,target_if=min:debuff.rotten_touch.remains*(buff.sudden_doom.react&talent.rotten_touch),if=!variable.pooling_runic_power&active_enemies<variable.epidemic_targets
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower and ActiveEnemies < VarEpidemicTargets) then
    if Everyone.CastTargetIf(S.DeathCoil, EnemiesMelee, "min", EvaluateTargetIfFilterDCAoE, nil, not Target:IsInRange(40), Settings.Unholy.GCDasOffGCD.DeathCoil) then return "death_coil aoe_setup 20"; end
  end
  -- epidemic,if=!variable.pooling_runic_power
  if S.Epidemic:IsReady() and (not VarPoolingRunicPower) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic aoe_setup 22"; end
  end
  -- festering_strike,target_if=min:debuff.festering_wound.stack,if=death_knight.fwounded_targets<8&!death_knight.fwounded_targets=active_enemies
  if FesteringAction:IsReady() and (FesterTargets < 8 and FesterTargets ~= ActiveEnemies) then
    if Everyone.CastTargetIf(FesteringAction, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, nil, not Target:IsInMeleeRange(FesteringRange)) then return "festering_strike aoe_setup 24"; end
  end
  -- wound_spender,target_if=max:debuff.festering_wound.stack,if=buff.vampiric_strike.react
  if WoundSpender:IsReady() and (S.VampiricStrikeAction:IsLearned()) then
    if Everyone.CastTargetIf(WoundSpender, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, nil, not Target:IsInMeleeRange(5)) then return "wound_spender aoe_setup 26"; end
  end
end

local function CDs()
  -- dark_transformation,if=variable.st_planning&(cooldown.apocalypse.remains<8|!talent.apocalypse|active_enemies>=1)|fight_remains<20
  if S.DarkTransformation:IsCastable() and (VarSTPlanning and (S.Apocalypse:CooldownRemains() < 8 or not S.Apocalypse:IsAvailable() or ActiveEnemies >= 1) or BossFightRemains < 20) then
    if Cast(S.DarkTransformation, Settings.Unholy.GCDasOffGCD.DarkTransformation) then return "dark_transformation cds 2"; end
  end
  -- unholy_assault,if=variable.st_planning&(cooldown.apocalypse.remains<gcd*2|!talent.apocalypse|active_enemies>=2&buff.dark_transformation.up)|fight_remains<20
  if S.UnholyAssault:IsCastable() and (VarSTPlanning and (S.Apocalypse:CooldownRemains() < Player:GCD() * 2 or not S.Apocalypse:IsAvailable() or ActiveEnemies >= 2 and Pet:BuffUp(S.DarkTransformation)) or BossFightRemains < 20) then
    if Cast(S.UnholyAssault, Settings.Unholy.GCDasOffGCD.UnholyAssault, nil, not Target:IsInMeleeRange(5)) then return "unholy_assault cds 4"; end
  end
  -- apocalypse,if=variable.st_planning|fight_remains<20
  if S.Apocalypse:IsReady() and (VarSTPlanning or BossFightRemains < 20) then
    if Cast(S.Apocalypse, Settings.Unholy.GCDasOffGCD.Apocalypse, nil, not Target:IsInMeleeRange(5)) then return "apocalypse cds 6"; end
  end
  -- outbreak,target_if=target.time_to_die>dot.virulent_plague.remains&dot.virulent_plague.ticks_remain<5,if=(dot.virulent_plague.refreshable|talent.superstrain&(dot.frost_fever.refreshable|dot.blood_plague.refreshable))&(!talent.unholy_blight|talent.plaguebringer)&(!talent.raise_abomination|talent.raise_abomination&cooldown.raise_abomination.remains>dot.virulent_plague.ticks_remain*3)
  if S.Outbreak:IsReady() then
    if Everyone.CastCycle(S.Outbreak, Enemies10ySplash, EvaluateCycleOutbreakCDs, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak cds 8"; end
  end
  -- abomination_limb,if=variable.st_planning&!buff.sudden_doom.react&(buff.festermight.up&buff.festermight.stack>8|!talent.festermight)&(pet.apoc_ghoul.remains<5|!talent.apocalypse)&debuff.festering_wound.stack<=2|fight_remains<12
  if S.AbominationLimb:IsCastable() and (VarSTPlanning and Player:BuffDown(S.SuddenDoomBuff) and (Player:BuffUp(S.FestermightBuff) and Player:BuffStack(S.FestermightBuff) > 8 or not S.Festermight:IsAvailable()) and (VarApocGhoulRemains < 5 or not S.Apocalypse:IsAvailable()) and FesterStacks <= 2 or BossFightRemains < 12) then
    if Cast(S.AbominationLimb, nil, Settings.CommonsDS.DisplayStyle.AbominationLimb, not Target:IsInRange(20)) then return "abomination_limb cds 10"; end
  end
end

local function CDsAoE()
  -- vile_contagion,target_if=max:debuff.festering_wound.stack,if=debuff.festering_wound.stack>=4&variable.adds_remain
  if S.VileContagion:IsReady() then
    if Everyone.CastTargetIf(S.VileContagion, Enemies10ySplash, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfVileContagionCDsAoE, not Target:IsSpellInRange(S.VileContagion), Settings.Unholy.GCDasOffGCD.VileContagion) then return "vile_contagion cds_aoe 2"; end
  end
  -- unholy_assault,target_if=max:debuff.festering_wound.stack,if=variable.adds_remain&(debuff.festering_wound.stack>=2&cooldown.vile_contagion.remains<3|!talent.vile_contagion)
  if S.UnholyAssault:IsCastable() then
    if Everyone.CastTargetIf(S.UnholyAssault, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfUnholyAssaultCDsAoE, not Target:IsInMeleeRange(5), Settings.Unholy.GCDasOffGCD.UnholyAssault) then return "unholy_assault cds_aoe 4"; end
  end
  -- dark_transformation,if=variable.adds_remain&(cooldown.vile_contagion.remains>5|!talent.vile_contagion|death_and_decay.ticking|cooldown.death_and_decay.remains<3)
  if S.DarkTransformation:IsCastable() and (VarAddsRemain and (S.VileContagion:CooldownRemains() > 5 or not S.VileContagion:IsAvailable() or Player:DnDTicking() or AnyDnD:CooldownRemains() < 3)) then
    if Cast(S.DarkTransformation, Settings.Unholy.GCDasOffGCD.DarkTransformation) then return "dark_transformation cds_aoe 6"; end
  end
  -- outbreak,if=dot.virulent_plague.ticks_remain<5&dot.virulent_plague.refreshable&(!talent.unholy_blight|talent.unholy_blight&cooldown.dark_transformation.remains)&(!talent.raise_abomination|talent.raise_abomination&cooldown.raise_abomination.remains)
  if S.Outbreak:IsReady() and (Target:DebuffTicksRemain(S.VirulentPlagueDebuff) < 5 and Target:DebuffRefreshable(S.VirulentPlagueDebuff) and (not S.UnholyBlight:IsAvailable() or S.UnholyBlight:IsAvailable() and S.DarkTransformation:CooldownDown()) and (not S.RaiseAbomination:IsAvailable() or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownDown())) then
    if Cast(S.Outbreak, nil, nil, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak cds_aoe 8"; end
  end
  -- apocalypse,target_if=max:debuff.festering_wound.stack,if=variable.adds_remain&rune<=3
  if S.Apocalypse:IsReady() and (VarAddsRemain and Player:Rune() <= 3) then
    if Everyone.CastTargetIf(S.Apocalypse, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, nil, not Target:IsInMeleeRange(5), Settings.Unholy.GCDasOffGCD.Apocalypse) then return "apocalypse cds_aoe 10"; end
  end
  -- abomination_limb,if=variable.adds_remain
  if S.AbominationLimb:IsCastable() and (VarAddsRemain) then
    if Cast(S.AbominationLimb, nil, Settings.CommonsDS.DisplayStyle.AbominationLimb, not Target:IsInRange(20)) then return "abomination_limb cds_aoe 12"; end
  end
end

local function CDsAoESan()
  -- vile_contagion,target_if=max:debuff.festering_wound.stack,if=debuff.festering_wound.stack>=4&variable.adds_remain
  if S.VileContagion:IsReady() then
    if Everyone.CastTargetIf(S.VileContagion, Enemies10ySplash, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfVileContagionCDsAoE, not Target:IsSpellInRange(S.VileContagion), Settings.Unholy.GCDasOffGCD.VileContagion) then return "vile_contagion cds_aoe_san 2"; end
  end
  -- dark_transformation,if=variable.adds_remain&(buff.death_and_decay.up|active_enemies<=3)
  if S.DarkTransformation:IsCastable() and (VarAddsRemain and (Player:BuffUp(S.DeathAndDecayBuff) or ActiveEnemies <= 3)) then
    if Cast(S.DarkTransformation, Settings.Unholy.GCDasOffGCD.DarkTransformation) then return "dark_transformation cds_aoe_san 4"; end
  end
  -- unholy_assault,target_if=debuff.festering_wound.stack<3,if=variable.adds_remain&talent.vile_contagion&debuff.festering_wound.stack<=2&cooldown.vile_contagion.remains<6
  if S.UnholyAssault:IsCastable() and (VarAddsRemain and S.VileContagion:IsAvailable() and S.VileContagion:CooldownRemains() < 6) then
    if Everyone.CastCycle(S.UnholyAssault, EnemiesMelee, EvaluateCycleUnholyAssaultCDsAoESan, not Target:IsSpellInRange(S.UnholyAssault)) then return "unholy_assault cds_aoe_san 6"; end
  end
  -- unholy_assault,target_if=min:debuff.festering_wound.stack,if=variable.adds_remain&!talent.vile_contagion&buff.dark_transformation.up&buff.dark_transformation.remains<12
  if S.UnholyAssault:IsCastable() and (VarAddsRemain and not S.VileContagion:IsAvailable() and Pet:BuffUp(S.DarkTransformation) and Pet:BuffRemains(S.DarkTransformation) < 12) then
    if Everyone.CastTargetIf(S.UnholyAssault, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, nil, not Target:IsInMeleeRange(5), Settings.Unholy.GCDasOffGCD.UnholyAssault) then return "unholy_assault cds_aoe_san 8"; end
  end
  -- outbreak,if=(dot.virulent_plague.ticks_remain<5|set_bonus.tww2_4pc&talent.superstrain&dot.frost_fever.ticks_remain<5&!pet.abomination.active)&(talent.unholy_blight&!cooldown.dark_transformation.ready|!talent.unholy_blight)&(dot.virulent_plague.refreshable|talent.morbidity&!buff.gift_of_the_sanlayn.up&talent.superstrain&dot.frost_fever.refreshable&dot.blood_plague.refreshable)&(!dot.virulent_plague.ticking&variable.epidemic_targets<active_enemies|(!talent.unholy_blight|talent.unholy_blight&cooldown.dark_transformation.remains>5)&(!talent.raise_abomination|talent.raise_abomination&cooldown.raise_abomination.remains>5))
  if S.Outbreak:IsReady() and ((Target:DebuffTicksRemain(S.VirulentPlagueDebuff) < 5 or Player:HasTier("TWW2", 4) and S.Superstrain:IsAvailable() and Target:DebuffTicksRemain(S.FrostFeverDebuff) < 5 and not VarAbomActive) and (S.UnholyBlight:IsAvailable() and S.DarkTransformation:CooldownDown() or not S.UnholyBlight:IsAvailable()) and (Target:DebuffRefreshable(S.VirulentPlagueDebuff) or S.Morbidity:IsAvailable() and Player:BuffDown(S.GiftoftheSanlaynBuff) and S.Superstrain:IsAvailable() and Target:DebuffRefreshable(S.FrostFeverDebuff) and Target:DebuffRefreshable(S.BloodPlagueDebuff)) and (Target:DebuffDown(S.VirulentPlagueDebuff) and VarEpidemicTargets < ActiveEnemies or (not S.UnholyBlight:IsAvailable() or S.UnholyBlight:IsAvailable() and S.DarkTransformation:CooldownRemains() > 5) and (not S.RaiseAbomination:IsAvailable() or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownRemains() > 5))) then
    if Cast(S.Outbreak, nil, nil, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak cds_aoe_san 10"; end
  end
  -- apocalypse,target_if=min:debuff.festering_wound.stack,if=variable.adds_remain&rune<=3
  if S.Apocalypse:IsReady() and (VarAddsRemain and Player:Rune() <= 3) then
    if Everyone.CastTargetIf(S.Apocalypse, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFWStackMinCheck, not Target:IsInMeleeRange(5), Settings.Unholy.GCDasOffGCD.Apocalypse) then return "apocalypse cds_aoe_san 12"; end
  end
  -- abomination_limb,if=variable.adds_remain
  if S.AbominationLimb:IsCastable() and (VarAddsRemain) then
    if Cast(S.AbominationLimb, nil, Settings.CommonsDS.DisplayStyle.AbominationLimb, not Target:IsInRange(20)) then return "abomination_limb cds_aoe_san 14"; end
  end
end

local function CDsCleaveSan()
  -- dark_transformation,if=buff.death_and_decay.up&(talent.apocalypse&pet.apoc_ghoul.active|!talent.apocalypse)|fight_remains<20|raid_event.adds.exists&raid_event.adds.remains<20
  if S.DarkTransformation:IsCastable() and (Player:BuffUp(S.DeathAndDecayBuff) and (S.Apocalypse:IsAvailable() and VarApocGhoulActive or not S.Apocalypse:IsAvailable()) or BossFightRemains < 20) then
    if Cast(S.DarkTransformation, Settings.Unholy.GCDasOffGCD.DarkTransformation) then return "dark_transformation cds_cleave_san 2"; end
  end
  -- unholy_assault,if=buff.dark_transformation.up&buff.dark_transformation.remains<12|fight_remains<20|raid_event.adds.exists&raid_event.adds.remains<20
  if S.UnholyAssault:IsCastable() and (Pet:BuffUp(S.DarkTransformation) and Pet:BuffRemains(S.DarkTransformation) < 12 or BossFightRemains < 20) then
    if Cast(S.UnholyAssault, Settings.Unholy.GCDasOffGCD.UnholyAssault, nil, not Target:IsInMeleeRange(5)) then return "unholy_assault cds_cleave_san 4"; end
  end
  -- apocalypse,target_if=max:debuff.festering_wound.stack
  if S.Apocalypse:IsReady() then
    if Everyone.CastTargetIf(S.Apocalypse, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, nil, not Target:IsInMeleeRange(5), Settings.Unholy.GCDasOffGCD.Apocalypse) then return "apocalypse cds_cleave_san 6"; end
  end
  -- outbreak,target_if=target.time_to_die>dot.virulent_plague.remains&dot.virulent_plague.ticks_remain<5,if=(dot.virulent_plague.refreshable|talent.morbidity&buff.infliction_of_sorrow.up&talent.superstrain&dot.frost_fever.refreshable&dot.blood_plague.refreshable)&(!talent.unholy_blight|talent.unholy_blight&cooldown.dark_transformation.remains>6)&(!talent.raise_abomination|talent.raise_abomination&cooldown.raise_abomination.remains>6)
  if S.Outbreak:IsReady() then
    if Everyone.CastCycle(S.Outbreak, EnemiesMelee, EvaluateCycleOutbreakCDsCleaveSan, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak cds_cleave_san 8"; end
  end
  -- abomination_limb,if=!buff.gift_of_the_sanlayn.up&!buff.sudden_doom.react&buff.festermight.up&debuff.festering_wound.stack<=2|!buff.gift_of_the_sanlayn.up&fight_remains<12
  if S.AbominationLimb:IsCastable() and (Player:BuffDown(S.GiftoftheSanlaynBuff) and Player:BuffDown(S.SuddenDoomBuff) and Player:BuffUp(S.FestermightBuff) and FesterStacks <= 2 or Player:BuffUp(S.GiftoftheSanlaynBuff) and BossFightRemains < 12) then
    if Cast(S.AbominationLimb, nil, Settings.CommonsDS.DisplayStyle.AbominationLimb, not Target:IsInRange(20)) then return "abomination_limb cds_cleave_san 10"; end
  end
end

local function CDsSan()
  -- dark_transformation,if=active_enemies>=1&variable.st_planning&(talent.apocalypse&pet.apoc_ghoul.active|!talent.apocalypse)|fight_remains<20
  if S.DarkTransformation:IsCastable() and (ActiveEnemies >= 1 and VarSTPlanning and (S.Apocalypse:IsAvailable() and VarApocGhoulActive or not S.Apocalypse:IsAvailable()) or BossFightRemains < 20) then
    if Cast(S.DarkTransformation, Settings.Unholy.GCDasOffGCD.DarkTransformation) then return "dark_transformation cds_san 2"; end
  end
  -- unholy_assault,if=variable.st_planning&(buff.dark_transformation.up&buff.dark_transformation.remains<12)|fight_remains<20
  if S.UnholyAssault:IsCastable() and (VarSTPlanning and (Pet:BuffUp(S.DarkTransformation) and Pet:BuffRemains(S.DarkTransformation) < 12) or BossFightRemains < 20) then
    if Cast(S.UnholyAssault, Settings.Unholy.GCDasOffGCD.UnholyAssault, nil, not Target:IsInMeleeRange(5)) then return "unholy_assault cds_san 4"; end
  end
  -- apocalypse,if=variable.st_planning|fight_remains<20
  if S.Apocalypse:IsReady() and (VarSTPlanning or BossFightRemains < 20) then
    if Cast(S.Apocalypse, Settings.Unholy.GCDasOffGCD.Apocalypse, nil, not Target:IsInMeleeRange(5)) then return "apocalypse cds_san 6"; end
  end
  -- outbreak,target_if=target.time_to_die>dot.virulent_plague.remains&dot.virulent_plague.ticks_remain<5,if=(dot.virulent_plague.refreshable|talent.morbidity&buff.infliction_of_sorrow.up&talent.superstrain&dot.frost_fever.refreshable&dot.blood_plague.refreshable)&(!talent.unholy_blight|talent.unholy_blight&cooldown.dark_transformation.remains>6)&(!talent.raise_abomination|talent.raise_abomination&cooldown.raise_abomination.remains>6)
  -- Note: Eval condition is not a typo. It uses the same condition as the one in CDsCleaveSan.
  if S.Outbreak:IsReady() then
    if Everyone.CastCycle(S.Outbreak, EnemiesMelee, EvaluateCycleOutbreakCDsCleaveSan, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak cds_san 8"; end
  end
  -- abomination_limb,if=active_enemies>=1&variable.st_planning&!buff.gift_of_the_sanlayn.up&!buff.sudden_doom.react&buff.festermight.up&debuff.festering_wound.stack<=2|!buff.gift_of_the_sanlayn.up&fight_remains<12
  if S.AbominationLimb:IsCastable() and (ActiveEnemies >= 1 and VarSTPlanning and Player:BuffDown(S.GiftoftheSanlaynBuff) and Player:BuffDown(S.SuddenDoomBuff) and Player:BuffUp(S.FestermightBuff) and FesterStacks <= 2 or Player:BuffDown(S.GiftoftheSanlaynBuff) and BossFightRemains < 12) then
    if Cast(S.AbominationLimb, nil, Settings.CommonsDS.DisplayStyle.AbominationLimb, not Target:IsInRange(20)) then return "abomination_limb cds_san 10"; end
  end
end

local function CDsShared()
  -- potion,if=(variable.st_planning|variable.adds_remain)&(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(buff.dark_transformation.up&30>=buff.dark_transformation.remains|!talent.vampiric_strike&pet.army_ghoul.active&pet.army_ghoul.remains<=30|!talent.vampiric_strike&pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=30|!talent.vampiric_strike&pet.abomination.active&pet.abomination.remains<=30)|fight_remains<=30
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected then
      if PotionSelected:IsReady() and ((VarSTPlanning or VarAddsRemain) and (not S.SummonGargoyle:IsAvailable() or S.SummonGargoyle:CooldownRemains() > 60) and (Pet:BuffUp(S.DarkTransformation) and 30 >= Pet:BuffRemains(S.DarkTransformation) or not S.VampiricStrike:IsAvailable() and VarArmyGhoulActive and VarArmyGhoulRemains <= 30 or not S.VampiricStrike:IsAvailable() and VarApocGhoulActive and VarApocGhoulRemains <= 30 or not S.VampiricStrike:IsAvailable() and VarAbomActive and VarAbomRemains <= 30) or BossFightRemains <= 30) then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cds_shared 2"; end
      end
    end
  end
  -- invoke_external_buff,name=power_infusion,if=active_enemies>=1&(variable.st_planning|variable.adds_remain)&(pet.gargoyle.active&pet.gargoyle.remains<=22|!talent.summon_gargoyle&talent.army_of_the_dead&(talent.raise_abomination&pet.abomination.active&pet.abomination.remains<18|!talent.raise_abomination&pet.army_ghoul.active&pet.army_ghoul.remains<=18)|!talent.summon_gargoyle&!talent.army_of_the_dead&buff.dark_transformation.up|!talent.summon_gargoyle&buff.dark_transformation.up|!pet.gargoyle.active&cooldown.summon_gargoyle.remains+10>cooldown.invoke_external_buff_power_infusion.duration|active_enemies>=3&(buff.dark_transformation.up|death_and_decay.ticking))
  -- Note: Not handling external buffs.
  -- army_of_the_dead,if=(variable.st_planning|variable.adds_remain)&(talent.commander_of_the_dead&cooldown.dark_transformation.remains<5|!talent.commander_of_the_dead&active_enemies>=1)|fight_remains<35
  if S.ArmyoftheDead:IsReady() and not Settings.Commons.DisableAotD and ((VarSTPlanning or VarAddsRemain) and (S.CommanderoftheDead:IsAvailable() and S.DarkTransformation:CooldownRemains() < 5 or not S.CommanderoftheDead:IsAvailable() and ActiveEnemies >= 1) or BossFightRemains < 35) then
    if Cast(S.ArmyoftheDead, nil, Settings.Unholy.DisplayStyle.ArmyOfTheDead) then return "army_of_the_dead cds_shared 4"; end
  end
  -- raise_abomination,if=(variable.st_planning|variable.adds_remain)&(!talent.vampiric_strike|(pet.apoc_ghoul.active|!talent.apocalypse))|fight_remains<30
  if S.RaiseAbomination:IsCastable() and ((VarSTPlanning or VarAddsRemain) and (not S.VampiricStrike:IsAvailable() or (VarApocGhoulActive or not S.Apocalypse:IsAvailable())) or BossFightRemains < 30) then
    if Cast(S.RaiseAbomination, Settings.Unholy.GCDasOffGCD.RaiseAbomination) then return "raise_abomination cds_shared 6"; end
  end
  -- summon_gargoyle,use_off_gcd=1,if=(variable.st_planning|variable.adds_remain)&(buff.commander_of_the_dead.up|!talent.commander_of_the_dead&active_enemies>=1)|fight_remains<25
  if S.SummonGargoyle:IsReady() and ((VarSTPlanning or VarAddsRemain) and (Player:BuffUp(S.CommanderoftheDeadBuff) or not S.CommanderoftheDead:IsAvailable() and ActiveEnemies >= 1) or BossFightRemains < 25) then
    if Cast(S.SummonGargoyle, Settings.Unholy.GCDasOffGCD.SummonGargoyle) then return "summon_gargoyle cds_shared 8"; end
  end
  -- antimagic_shell,if=death_knight.ams_absorb_percent>0&runic_power<30&rune<2
  if S.AntiMagicShell:IsCastable() and Settings.Commons.UseAMSAMZOffensively and (Settings.Unholy.AMSAbsorbPercent > 0 and Player:RunicPower() < 30 and Player:Rune() < 2) then
    if Cast(S.AntiMagicShell, Settings.CommonsOGCD.GCDasOffGCD.AntiMagicShell) then return "antimagic_shell cds_shared 10"; end
  end
end

local function Cleave()
  -- any_dnd,if=!death_and_decay.ticking&variable.adds_remain&(cooldown.apocalypse.remains|!talent.apocalypse)
  if AnyDnD:IsReady() and (not Player:DnDTicking() and VarAddsRemain and (S.Apocalypse:CooldownDown() or not S.Apocalypse:IsAvailable())) then
    if Cast(AnyDnD, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "any_dnd cleave 2"; end
  end
  -- death_coil,if=!variable.pooling_runic_power&talent.improved_death_coil
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower and S.ImprovedDeathCoil:IsAvailable()) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil cleave 4"; end
  end
  -- wound_spender,if=buff.vampiric_strike.react
  if WoundSpender:IsReady() and (S.VampiricStrikeAction:IsLearned()) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender cleave 6"; end
  end
  -- death_coil,if=!variable.pooling_runic_power&!talent.improved_death_coil
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower and not S.ImprovedDeathCoil:IsAvailable()) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil cleave 8"; end
  end
  -- festering_strike,target_if=min:debuff.festering_wound.stack,if=!buff.vampiric_strike.react&!variable.pop_wounds&debuff.festering_wound.stack<2|buff.festering_scythe.react
  if FesteringAction:IsReady() then
    if Everyone.CastTargetIf(FesteringAction, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFesteringStrikeCleave, not Target:IsInMeleeRange(FesteringRange)) then return "festering_strike cleave 10"; end
  end
  -- festering_strike,target_if=max:debuff.festering_wound.stack,if=!buff.vampiric_strike.react&cooldown.apocalypse.remains<variable.apoc_timing&debuff.festering_wound.stack<1
  if FesteringAction:IsReady() then
    if Everyone.CastTargetIf(FesteringAction, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFesteringStrikeCleave2, not Target:IsInMeleeRange(FesteringRange)) then return "festering_strike cleave 12"; end
  end
  -- wound_spender,if=variable.pop_wounds
  if WoundSpender:IsReady() and (VarPopWounds) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender cleave 14"; end
  end
end

local function Racials()
  -- arcane_torrent,if=runic_power<20&rune<2
  if S.ArcaneTorrent:IsCastable() and (Player:RunicPower() < 20 and Player:Rune() < 2) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent racials 2"; end
  end
  -- blood_fury,if=(buff.blood_fury.duration+3>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(pet.army_ghoul.active&pet.army_ghoul.remains<=buff.blood_fury.duration+3|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=buff.blood_fury.duration+3|active_enemies>=2&death_and_decay.ticking)|fight_remains<=buff.blood_fury.duration+3
  if S.BloodFury:IsCastable() and ((S.BloodFury:BaseDuration() + 3 >= VarGargRemains and VarGargActive) or (not S.SummonGargoyle:IsAvailable() or S.SummonGargoyle:CooldownRemains() > 60) and (VarArmyGhoulActive and VarArmyGhoulRemains <= S.BloodFury:BaseDuration() + 3 or VarApocGhoulActive and VarApocGhoulRemains <= S.BloodFury:BaseDuration() + 3 or ActiveEnemies >= 2 and Player:DnDTicking()) or BossFightRemains <= S.BloodFury:BaseDuration() + 3) then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury racials 4"; end
  end
  -- berserking,if=(buff.berserking.duration+3>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(pet.army_ghoul.active&pet.army_ghoul.remains<=buff.berserking.duration+3|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=buff.berserking.duration+3|active_enemies>=2&death_and_decay.ticking)|fight_remains<=buff.berserking.duration+3
  if S.Berserking:IsCastable() and ((S.Berserking:BaseDuration() + 3 >= VarGargRemains and VarGargActive) or (not S.SummonGargoyle:IsAvailable() or S.SummonGargoyle:CooldownRemains() > 60) and (VarArmyGhoulActive and VarArmyGhoulRemains <= S.Berserking:BaseDuration() + 3 or VarApocGhoulActive and VarApocGhoulRemains <= S.Berserking:BaseDuration() + 3 or ActiveEnemies >= 2 and Player:DnDTicking()) or BossFightRemains <= S.Berserking:BaseDuration() + 3) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking racials 6"; end
  end
  -- lights_judgment,if=buff.unholy_strength.up&(!talent.festermight|buff.festermight.remains<target.time_to_die|buff.unholy_strength.remains<target.time_to_die)
  if S.LightsJudgment:IsCastable() and (Player:BuffUp(S.UnholyStrengthBuff) and (not S.Festermight:IsAvailable() or Player:BuffRemains(S.FestermightBuff) < Target:TimeToDie() or Player:BuffRemains(S.UnholyStrengthBuff) < Target:TimeToDie())) then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment racials 8"; end
  end
  -- ancestral_call,if=(18>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(pet.army_ghoul.active&pet.army_ghoul.remains<=18|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=18|active_enemies>=2&death_and_decay.ticking)|fight_remains<=18
  if S.AncestralCall:IsCastable() and ((18 >= VarGargRemains and VarGargActive) or (not S.SummonGargoyle:IsAvailable() or S.SummonGargoyle:CooldownRemains() > 60) and (VarArmyGhoulActive and VarArmyGhoulRemains <= 18 or VarApocGhoulActive and VarApocGhoulRemains <= 18 or ActiveEnemies >= 2 and Player:DnDTicking()) or BossFightRemains <= 18) then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call racials 10"; end
  end
  -- arcane_pulse,if=active_enemies>=2|(rune.deficit>=5&runic_power.deficit>=60)
  if S.ArcanePulse:IsCastable() and (ActiveEnemies >= 2 or (Player:Rune() <= 1 and Player:RunicPowerDeficit() >= 60)) then
    if Cast(S.ArcanePulse, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_pulse racials 12"; end
  end
  -- fireblood,if=(buff.fireblood.duration+3>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(pet.army_ghoul.active&pet.army_ghoul.remains<=buff.fireblood.duration+3|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=buff.fireblood.duration+3|active_enemies>=2&death_and_decay.ticking)|fight_remains<=buff.fireblood.duration+3
  if S.Fireblood:IsCastable() and ((S.Fireblood:BaseDuration() + 3 >= VarGargRemains and VarGargActive) or (not S.SummonGargoyle:IsAvailable() or S.SummonGargoyle:CooldownRemains() > 60) and (VarArmyGhoulActive and VarArmyGhoulRemains <= S.Fireblood:BaseDuration() + 3 or VarApocGhoulActive and VarApocGhoulRemains <= S.Fireblood:BaseDuration() + 3 or ActiveEnemies >= 2 and Player:DnDTicking()) or BossFightRemains <= S.Fireblood:BaseDuration() + 3) then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood racials 14"; end
  end
  -- bag_of_tricks,if=active_enemies=1&(buff.unholy_strength.up|fight_remains<5)
  if S.BagofTricks:IsCastable() and (ActiveEnemies == 1 and (Player:BuffUp(S.UnholyStrengthBuff) or BossFightRemains < 5)) then
    if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks racials 16"; end
  end
end

local function SanFishing()
  -- antimagic_shell,if=death_knight.ams_absorb_percent>0&runic_power<40
  if S.AntiMagicShell:IsCastable() and Settings.Commons.UseAMSAMZOffensively and (Settings.Unholy.AMSAbsorbPercent > 0 and Player:RunicPower() < 40) then
    if Cast(S.AntiMagicShell, Settings.CommonsOGCD.GCDasOffGCD.AntiMagicShell) then return "antimagic_shell san_fishing 2"; end
  end
  -- wound_spender,if=buff.infliction_of_sorrow.up
  if WoundSpender:IsReady() and (Player:BuffUp(S.InflictionofSorrowBuff)) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender san_fishing 4"; end
  end
  -- any_dnd,if=!buff.death_and_decay.up&!buff.vampiric_strike.react
  if AnyDnD:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) and not S.VampiricStrikeAction:IsLearned()) then
    if Cast(AnyDnD, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "any_dnd san_fishing 6"; end
  end
  -- death_coil,if=buff.sudden_doom.react&talent.doomed_bidding|set_bonus.tww2_4pc&buff.essence_of_the_blood_queen.at_max_stacks&talent.frenzied_bloodthirst&!buff.vampiric_strike.react
  if S.DeathCoil:IsReady() and (Player:BuffUp(S.SuddenDoomBuff) and S.DoomedBidding:IsAvailable() or Player:HasTier("TWW2", 4) and Player:BuffStack(S.EssenceoftheBloodQueenBuff) >= 5 and S.FrenziedBloodthirst:IsAvailable() and not S.VampiricStrikeAction:IsLearned()) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil san_fishing 8"; end
  end
  -- soul_reaper,if=target.health.pct<=35&fight_remains>5
  if S.SoulReaper:IsReady() and (Target:HealthPercentage() <= 35 and FightRemains > 5) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper san_fishing 10"; end
  end
  -- death_coil,if=!buff.vampiric_strike.react
  if S.DeathCoil:IsReady() and (not S.VampiricStrikeAction:IsLearned()) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil san_fishing 12"; end
  end
  -- wound_spender,if=(debuff.festering_wound.stack>=3-pet.abomination.active&cooldown.apocalypse.remains>variable.apoc_timing)|buff.vampiric_strike.react
  if WoundSpender:IsReady() and ((FesterStacks >= 3 - num(VarAbomActive) and S.Apocalypse:CooldownRemains() > VarApocTiming) or S.VampiricStrikeAction:IsLearned()) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender san_fishing 14"; end
  end
  -- festering_strike,if=debuff.festering_wound.stack<3-pet.abomination.active
  if FesteringAction:IsReady() and (FesterStacks < 3 - num(VarAbomActive)) then
    if Cast(FesteringAction, nil, nil, not Target:IsInMeleeRange(FesteringRange)) then return "festering_strike san_fishing 16"; end
  end
end

local function SanST()
  -- any_dnd,if=variable.st_planning&!buff.death_and_decay.up&talent.unholy_ground&(cooldown.dark_transformation.remains<5|talent.defile&buff.gift_of_the_sanlayn.up)
  if AnyDnD:IsReady() and (VarSTPlanning and Player:BuffDown(S.DeathAndDecayBuff) and S.UnholyGround:IsAvailable() and (S.DarkTransformation:CooldownRemains() < 5 or S.Defile:IsAvailable() and Player:BuffUp(S.GiftoftheSanlaynBuff))) then
    if Cast(AnyDnD, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "any_dnd san_st 2"; end
  end
  -- wound_spender,if=buff.infliction_of_sorrow.up
  if WoundSpender:IsReady() and (Player:BuffUp(S.InflictionofSorrowBuff)) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender san_st 4"; end
  end
  -- festering_strike,if=buff.festering_scythe.react&(!raid_event.adds.exists|!raid_event.adds.in|raid_event.adds.in>11|raid_event.pull.has_boss&raid_event.adds.in>11)
  if S.FesteringScytheAction:IsReady() then
    if Cast(S.FesteringScytheAction, nil, nil, not Target:IsInMeleeRange(14)) then return "festering_scythe san_st 6"; end
  end
  -- death_coil,if=buff.sudden_doom.react&buff.gift_of_the_sanlayn.remains&(talent.doomed_bidding|talent.rotten_touch)|rune<3&!buff.runic_corruption.up|set_bonus.tww2_4pc&runic_power>80|buff.gift_of_the_sanlayn.up&buff.essence_of_the_blood_queen.at_max_stacks&talent.frenzied_bloodthirst&set_bonus.tww2_4pc&buff.winning_streak_unholy.at_max_stacks&rune<=3&buff.essence_of_the_blood_queen.remains>3
  if S.DeathCoil:IsReady() and (Player:BuffUp(S.SuddenDoomBuff) and Player:BuffUp(S.GiftoftheSanlaynBuff) and (S.DoomedBidding:IsAvailable() or S.RottenTouch:IsAvailable()) or Player:Rune() < 3 and Player:BuffDown(S.RunicCorruptionBuff) or Player:HasTier("TWW2", 4) and Player:RunicPower() > 80 or Player:BuffUp(S.GiftoftheSanlaynBuff) and Player:BuffStack(S.EssenceoftheBloodQueenBuff) >= 5 and S.FrenziedBloodthirst:IsAvailable() and Player:HasTier("TWW2", 4) and Player:BuffStack(S.WinningStreakBuff) >= 6 and Player:Rune() <= 3 and Player:BuffRemains(S.EssenceoftheBloodQueenBuff) > 3) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil san_st 8"; end
  end
  -- wound_spender,if=buff.vampiric_strike.react&debuff.festering_wound.stack>=1|buff.gift_of_the_sanlayn.up|talent.gift_of_the_sanlayn&buff.dark_transformation.up&buff.dark_transformation.remains<gcd
  if WoundSpender:IsReady() and (S.VampiricStrikeAction:IsLearned() and FesterStacks >= 1 or Player:BuffUp(S.GiftoftheSanlaynBuff) or S.GiftoftheSanlayn:IsAvailable() and Pet:BuffUp(S.DarkTransformation) and Pet:BuffRemains(S.DarkTransformation) < Player:GCD()) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender san_st 10"; end
  end
  -- soul_reaper,if=target.health.pct<=35&!buff.gift_of_the_sanlayn.up&fight_remains>5
  if S.SoulReaper:IsReady() and (Target:HealthPercentage() <= 35 and Player:BuffDown(S.GiftoftheSanlaynBuff) and FightRemains > 5) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper san_st 12"; end
  end
  -- festering_strike,if=(debuff.festering_wound.stack=0&cooldown.apocalypse.remains<variable.apoc_timing)|!buff.dark_transformation.up&cooldown.dark_transformation.remains<10&debuff.festering_wound.stack<=3&(rune>4|runic_power<80)|(talent.gift_of_the_sanlayn&!buff.gift_of_the_sanlayn.up|!talent.gift_of_the_sanlayn)&debuff.festering_wound.stack<=1
  if FesteringAction:IsReady() and ((FesterStacks == 0 and S.Apocalypse:CooldownRemains() < VarApocTiming) or Pet:BuffDown(S.DarkTransformation) and S.DarkTransformation:CooldownRemains() < 10 and FesterStacks <= 3 and (Player:Rune() > 4 or Player:RunicPower() < 80) or (S.GiftoftheSanlayn:IsAvailable() and Player:BuffDown(S.GiftoftheSanlaynBuff) or not S.GiftoftheSanlayn:IsAvailable()) and FesterStacks <= 1) then
    if Cast(FesteringAction, nil, nil, not Target:IsInMeleeRange(FesteringRange)) then return "festering_strike san_st 14"; end
  end
  -- wound_spender,if=(!talent.apocalypse|cooldown.apocalypse.remains>variable.apoc_timing)&(cooldown.dark_transformation.remains>5&debuff.festering_wound.stack>=3-pet.abomination.active|buff.vampiric_strike.react)
  if WoundSpender:IsReady() and ((not S.Apocalypse:IsAvailable() or S.Apocalypse:CooldownRemains() > VarApocTiming) and (S.DarkTransformation:CooldownRemains() > 5 and FesterStacks >= 3 - num(VarAbomActive) or S.VampiricStrikeAction:IsLearned())) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender san_st 16"; end
  end
  -- death_coil,if=!variable.pooling_runic_power&debuff.death_rot.remains<gcd|(buff.sudden_doom.react&debuff.festering_wound.stack>=1|rune<2)
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower and Target:DebuffRemains(S.DeathRotDebuff) < Player:GCD() or (Player:BuffUp(S.SuddenDoomBuff) and FesterStacks >= 1 or Player:Rune() < 2)) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil san_st 18"; end
  end
  -- wound_spender,if=debuff.festering_wound.stack>4
  if WoundSpender:IsReady() and (FesterStacks > 4) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender san_st 20"; end
  end
  -- death_coil,if=!variable.pooling_runic_power
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil san_st 22"; end
  end
  -- wound_spender,if=(!talent.apocalypse|cooldown.apocalypse.remains>variable.apoc_timing)&rune>=4
  if WoundSpender:IsReady() and ((not S.Apocalypse:IsAvailable() or S.Apocalypse:CooldownRemains() > VarApocTiming) and Player:Rune() >= 4) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender san_st 24"; end
  end
end

local function SanTrinkets()
  if Settings.Commons.Enabled.Trinkets then
    -- do_treacherous_transmitter_task,use_off_gcd=1,if=buff.errant_manaforge_emission.up&buff.dark_transformation.up&buff.errant_manaforge_emission.remains<2|buff.cryptic_instructions.up&buff.dark_transformation.up&buff.cryptic_instructions.remains<2|buff.realigning_nexus_convergence_divergence.up&buff.dark_transformation.up&buff.realigning_nexus_convergence_divergence.remains<2
    -- TODO: Handle the above.
    -- use_item,name=treacherous_transmitter,if=(variable.adds_remain|variable.st_planning)&cooldown.dark_transformation.remains<10
    if I.TreacherousTransmitter:IsEquippedAndReady() and ((VarAddsRemain or VarSTPlanning) and S.DarkTransformation:CooldownRemains() < 10) then
      if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter san_trinkets 2"; end
    end
    -- use_item,slot=trinket1,if=variable.trinket_1_buffs&(buff.dark_transformation.up&buff.dark_transformation.remains<variable.trinket_1_duration*0.73&(variable.trinket_priority=1|trinket.2.cooldown.remains|!trinket.2.has_cooldown))|variable.trinket_1_duration>=fight_remains
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (VarTrinket1Buffs and (Pet:BuffUp(S.DarkTransformation) and Pet:BuffRemains(S.DarkTransformation) < VarTrinket1Duration * 0.73 and (VarTrinketPriority == 1 or Trinket2:CooldownDown() or not Trinket2:HasCooldown())) or VarTrinket1Duration >= BossFightRemains) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Trinket1 use_item for " .. Trinket1:Name() .. " san_trinkets 4"; end
    end
    -- use_item,slot=trinket2,if=variable.trinket_2_buffs&(buff.dark_transformation.up&buff.dark_transformation.remains<variable.trinket_2_duration*0.73&(variable.trinket_priority=2|trinket.1.cooldown.remains|!trinket.1.has_cooldown))|variable.trinket_2_duration>=fight_remains
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (VarTrinket2Buffs and (Pet:BuffUp(S.DarkTransformation) and Pet:BuffRemains(S.DarkTransformation) < VarTrinket2Duration * 0.73 and (VarTrinketPriority == 2 or Trinket1:CooldownDown() or not Trinket1:HasCooldown())) or VarTrinket2Duration >= BossFightRemains) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Trinket2 use_item for " .. Trinket2:Name() .. " san_trinkets 6"; end
    end
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&(trinket.1.cast_time>0&!buff.gift_of_the_sanlayn.up|!trinket.1.cast_time>0)&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains|!trinket.2.has_cooldown|!talent.summon_gargoyle&!talent.army_of_the_dead&!talent.raise_abomination|!talent.summon_gargoyle&talent.army_of_the_dead&(!talent.raise_abomination&cooldown.army_of_the_dead.remains>20|talent.raise_abomination&cooldown.raise_abomination.remains>20)|!talent.summon_gargoyle&!talent.army_of_the_dead&!talent.raise_abomination&cooldown.dark_transformation.remains>20|talent.summon_gargoyle&cooldown.summon_gargoyle.remains>20&!pet.gargoyle.active)|fight_remains<15
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1Buffs and (VarTrinket1CastTime > 0 and Player:BuffDown(S.GiftoftheSanlaynBuff) or VarTrinket1CastTime == 0) and (VarDamageTrinketPriority == 1 or Trinket2:CooldownDown() or not Trinket2:HasCooldown() or not S.SummonGargoyle:IsAvailable() and not S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() or not S.SummonGargoyle:IsAvailable() and S.ArmyoftheDead:IsAvailable() and (not S.RaiseAbomination:IsAvailable() and S.ArmyoftheDead:CooldownRemains() > 20 or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownRemains() > 20) or not S.SummonGargoyle:IsAvailable() and not S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() and S.DarkTransformation:CooldownRemains() > 20 or S.SummonGargoyle:IsAvailable() and S.SummonGargoyle:CooldownRemains() > 20 and not VarGargActive) or BossFightRemains < 15) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Trinket1 use_item for " .. Trinket1:Name() .. " san_trinkets 8"; end
    end
    -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&(trinket.2.cast_time>0&!buff.gift_of_the_sanlayn.up|!trinket.2.cast_time>0)&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains|!trinket.1.has_cooldown|!talent.summon_gargoyle&!talent.army_of_the_dead&!talent.raise_abomination|!talent.summon_gargoyle&talent.army_of_the_dead&(!talent.raise_abomination&cooldown.army_of_the_dead.remains>20|talent.raise_abomination&cooldown.raise_abomination.remains>20)|!talent.summon_gargoyle&!talent.army_of_the_dead&!talent.raise_abomination&cooldown.dark_transformation.remains>20|talent.summon_gargoyle&cooldown.summon_gargoyle.remains>20&!pet.gargoyle.active)|fight_remains<15
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2Buffs and (VarTrinket2CastTime > 0 and Player:BuffDown(S.GiftoftheSanlaynBuff) or VarTrinket2CastTime == 0) and (VarDamageTrinketPriority == 2 or Trinket1:CooldownDown() or not Trinket1:HasCooldown() or not S.SummonGargoyle:IsAvailable() and not S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() or not S.SummonGargoyle:IsAvailable() and S.ArmyoftheDead:IsAvailable() and (not S.RaiseAbomination:IsAvailable() and S.ArmyoftheDead:CooldownRemains() > 20 or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownRemains() > 20) or not S.SummonGargoyle:IsAvailable() and not S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() and S.DarkTransformation:CooldownRemains() > 20 or S.SummonGargoyle:IsAvailable() and S.SummonGargoyle:CooldownRemains() > 20 and not VarGargActive) or BossFightRemains < 15) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Trinket2 use_item for " .. Trinket2:Name() .. " san_trinkets 10"; end
    end
  end
  if Settings.Commons.Enabled.Items then
    -- use_item,slot=main_hand,if=(!variable.trinket_1_buffs&!variable.trinket_2_buffs|trinket.1.cooldown.remains>20&!variable.trinket_2_buffs|trinket.2.cooldown.remains>20&!variable.trinket_1_buffs|trinket.1.cooldown.remains>20&trinket.2.cooldown.remains>20)&(buff.dark_transformation.up&buff.dark_transformation.remains>10)&(!talent.raise_abomination&!talent.army_of_the_dead|!talent.raise_abomination&talent.army_of_the_dead&pet.army_ghoul.active|talent.raise_abomination&pet.abomination.active|(variable.trinket_1_buffs|variable.trinket_2_buffs|fight_remains<15))
    local ItemToUse, _, ItemRange = Player:GetUseableItems(OnUseExcludes, 16, true)
    if ItemToUse and ((not VarTrinket1Buffs and not VarTrinket2Buffs or Trinket1:CooldownRemains() > 20 and not VarTrinket2Buffs or Trinket2:CooldownRemains() > 20 and not VarTrinket1Buffs or Trinket1:CooldownRemains() > 20 and Trinket2:CooldownRemains() > 20) and (Pet:BuffUp(S.DarkTransformation) and Pet:BuffRemains(S.DarkTransformation) > 10) and (not S.RaiseAbomination:IsAvailable() and not S.ArmyoftheDead:IsAvailable() or not S.RaiseAbomination:IsAvailable() and S.ArmyoftheDead:IsAvailable() and VarArmyGhoulActive or S.RaiseAbomination:IsAvailable() and VarAbomActive or (VarTrinket1Buffs or VarTrinket2Buffs or BossFightRemains < 15))) then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Main Hand use_item for " .. ItemToUse:Name() .. " san_trinkets 12"; end
    end
    -- Note: Generic use_items for non-trinkets.
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
    if ItemToUse and ((not VarTrinket1Buffs or Trinket1:CooldownDown()) and (not VarTrinket2Buffs or Trinket2:CooldownDown())) then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Generic use_item for " .. ItemToUse:Name() .. " san_trinkets 14"; end
    end
  end
end

local function ST()
  -- soul_reaper,if=target.health.pct<=35&fight_remains>5
  if S.SoulReaper:IsReady() and (Target:HealthPercentage() <= 35 and FightRemains > 5) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper st 2"; end
  end
  -- wound_spender,if=debuff.chains_of_ice_trollbane_slow.up
  if WoundSpender:IsReady() and (Target:DebuffUp(S.TrollbaneSlowDebuff)) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender st 4"; end
  end
  -- any_dnd,if=talent.unholy_ground&!buff.death_and_decay.up&(pet.apoc_ghoul.active|pet.abomination.active|pet.gargoyle.active)
  if AnyDnD:IsReady() and (S.UnholyGround:IsAvailable() and Player:BuffDown(S.DeathAndDecayBuff) and (VarApocGhoulActive or VarAbomActive or VarGargActive)) then
    if Cast(AnyDnD, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "any_dnd st 6"; end
  end
  -- death_coil,if=!variable.pooling_runic_power&variable.spend_rp|fight_remains<10
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower and VarSpendRP or BossFightRemains < 10) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil st 8"; end
  end
  -- festering_strike,if=debuff.festering_wound.stack<4&(!variable.pop_wounds|buff.festering_scythe.react)
  if FesteringAction:IsReady() and (FesterStacks < 4 and (not VarPopWounds or Player:BuffUp(S.FesteringScytheBuff))) then
    if Cast(FesteringAction, nil, nil, not Target:IsInMeleeRange(FesteringRange)) then return "festering_strike st 10"; end
  end
  -- wound_spender,if=variable.pop_wounds
  if WoundSpender:IsReady() and (VarPopWounds) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender st 12"; end
  end
  -- death_coil,if=!variable.pooling_runic_power
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil st 14"; end
  end
  -- wound_spender,if=!variable.pop_wounds&debuff.festering_wound.stack>=4
  if WoundSpender:IsReady() and (not VarPopWounds and FesterStacks >= 4) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender st 16"; end
  end
end

local function Trinkets()
  if Settings.Commons.Enabled.Trinkets then
    -- do_treacherous_transmitter_task,use_off_gcd=1,if=buff.errant_manaforge_emission.up&(pet.apoc_ghoul.active|!talent.apocalypse&buff.dark_transformation.up)|buff.cryptic_instructions.up&(pet.apoc_ghoul.active|!talent.apocalypse&buff.dark_transformation.up)|buff.realigning_nexus_convergence_divergence.up&(pet.apoc_ghoul.active|!talent.apocalypse&buff.dark_transformation.up)
    -- TODO: Handle the above.
    -- use_item,name=treacherous_transmitter,if=(variable.adds_remain|variable.st_planning)&cooldown.dark_transformation.remains<10
    if I.TreacherousTransmitter:IsEquippedAndReady() and ((VarAddsRemain or VarSTPlanning) and S.DarkTransformation:CooldownRemains() < 10) then
      if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter trinkets 2"; end
    end
    -- use_item,slot=trinket1,if=variable.trinket_1_buffs&(variable.trinket_priority=1|!trinket.2.has_cooldown|trinket.2.cooldown.remains>20&(!talent.apocalypse&buff.dark_transformation.up|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=variable.trinket_1_duration&pet.apoc_ghoul.remains>5))&(talent.army_of_the_dead&!talent.raise_abomination&pet.army_ghoul.active&pet.army_ghoul.remains<=variable.trinket_1_duration&pet.army_ghoul.remains>10|talent.raise_abomination&pet.abomination.active&pet.abomination.remains<=variable.trinket_1_duration&pet.abomination.remains>10|talent.apocalypse&pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=variable.trinket_1_duration+3&pet.apoc_ghoul.remains>5|!talent.raise_abomination&!talent.apocalypse&buff.dark_transformation.up|trinket.2.cooldown.remains)|fight_remains<=variable.trinket_1_duration
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (VarTrinket1Buffs and (VarTrinketPriority == 1 or not Trinket2:HasCooldown() or Trinket2:CooldownRemains() > 20 and (not S.Apocalypse:IsAvailable() and Pet:BuffUp(S.DarkTransformation) or VarApocGhoulActive and VarApocGhoulRemains <= VarTrinket1Duration and VarApocGhoulRemains > 5)) and (S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() and VarArmyGhoulActive and VarArmyGhoulRemains <= VarTrinket1Duration and VarArmyGhoulRemains > 10 or S.RaiseAbomination:IsAvailable() and VarAbomActive and VarAbomRemains <= VarTrinket1Duration and VarAbomRemains > 10 or S.Apocalypse:IsAvailable() and VarApocGhoulActive and VarApocGhoulRemains <= VarTrinket1Duration + 3 and VarApocGhoulRemains > 5 or not S.RaiseAbomination:IsAvailable() and not S.Apocalypse:IsAvailable() and Pet:BuffUp(S.DarkTransformation) or Trinket2:CooldownDown()) or BossFightRemains <= VarTrinket1Duration) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for " .. Trinket1:Name() .. " trinkets 4"; end
    end
    -- use_item,slot=trinket2,if=variable.trinket_2_buffs&(variable.trinket_priority=2|!trinket.1.has_cooldown|trinket.1.cooldown.remains>20&(!talent.apocalypse&buff.dark_transformation.up|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=variable.trinket_2_duration&pet.apoc_ghoul.remains>5))&(talent.army_of_the_dead&!talent.raise_abomination&pet.army_ghoul.active&pet.army_ghoul.remains<=variable.trinket_2_duration&pet.army_ghoul.remains>10|talent.raise_abomination&pet.abomination.active&pet.abomination.remains<=variable.trinket_2_duration&pet.abomination.remains>10|talent.apocalypse&pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=variable.trinket_2_duration+3&pet.apoc_ghoul.remains>5|!talent.raise_abomination&!talent.apocalypse&buff.dark_transformation.up|trinket.1.cooldown.remains)|fight_remains<=variable.trinket_2_duration
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (VarTrinket2Buffs and (VarTrinketPriority == 2 or not Trinket1:HasCooldown() or Trinket1:CooldownRemains() > 20 and (not S.Apocalypse:IsAvailable() and Pet:BuffUp(S.DarkTransformation) or VarApocGhoulActive and VarApocGhoulRemains <= VarTrinket2Duration and VarApocGhoulRemains > 5)) and (S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() and VarArmyGhoulActive and VarArmyGhoulRemains <= VarTrinket2Duration and VarArmyGhoulRemains > 10 or S.RaiseAbomination:IsAvailable() and VarAbomActive and VarAbomRemains <= VarTrinket2Duration and VarAbomRemains > 10 or S.Apocalypse:IsAvailable() and VarApocGhoulActive and VarApocGhoulRemains <= VarTrinket2Duration + 3 and VarApocGhoulRemains > 5 or not S.RaiseAbomination:IsAvailable() and not S.Apocalypse:IsAvailable() and Pet:BuffUp(S.DarkTransformation) or Trinket1:CooldownDown()) or BossFightRemains <= VarTrinket2Duration) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for " .. Trinket2:Name() .. " san_trinkets 6"; end
    end
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains|!trinket.2.has_cooldown|!talent.summon_gargoyle&!talent.army_of_the_dead&!talent.raise_abomination|!talent.summon_gargoyle&talent.army_of_the_dead&(!talent.raise_abomination&cooldown.army_of_the_dead.remains>20|talent.raise_abomination&cooldown.raise_abomination.remains>20)|!talent.summon_gargoyle&!talent.army_of_the_dead&!talent.raise_abomination&cooldown.dark_transformation.remains>20|talent.summon_gargoyle&cooldown.summon_gargoyle.remains>20&!pet.gargoyle.active)|fight_remains<15
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1Buffs and (VarDamageTrinketPriority == 1 or Trinket2:CooldownDown() or not Trinket2:HasCooldown() or not S.SummonGargoyle:IsAvailable() and not S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() or not S.SummonGargoyle:IsAvailable() and S.ArmyoftheDead:IsAvailable() and (not S.RaiseAbomination:IsAvailable() and S.ArmyoftheDead:CooldownRemains() > 20 or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownRemains() > 20) or not S.SummonGargoyle:IsAvailable() and not S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() and S.DarkTransformation:CooldownRemains() > 20 or S.SummonGargoyle:IsAvailable() and S.SummonGargoyle:CooldownRemains() > 20 and not VarGargActive) or BossFightRemains < 15) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for " .. Trinket1:Name() .. " trinkets 8"; end
    end
    -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains|!trinket.1.has_cooldown|!talent.summon_gargoyle&!talent.army_of_the_dead&!talent.raise_abomination|!talent.summon_gargoyle&talent.army_of_the_dead&(!talent.raise_abomination&cooldown.army_of_the_dead.remains>20|talent.raise_abomination&cooldown.raise_abomination.remains>20)|!talent.summon_gargoyle&!talent.army_of_the_dead&!talent.raise_abomination&cooldown.dark_transformation.remains>20|talent.summon_gargoyle&cooldown.summon_gargoyle.remains>20&!pet.gargoyle.active)|fight_remains<15
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2Buffs and (VarDamageTrinketPriority == 2 or Trinket1:CooldownDown() or not Trinket1:HasCooldown() or not S.SummonGargoyle:IsAvailable() and not S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() or not S.SummonGargoyle:IsAvailable() and S.ArmyoftheDead:IsAvailable() and (not S.RaiseAbomination:IsAvailable() and S.ArmyoftheDead:CooldownRemains() > 20 or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownRemains() > 20) or not S.SummonGargoyle:IsAvailable() and not S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() and S.DarkTransformation:CooldownRemains() > 20 or S.SummonGargoyle:IsAvailable() and S.SummonGargoyle:CooldownRemains() > 20 and not VarGargActive) or BossFightRemains < 15) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for " .. Trinket2:Name() .. " san_trinkets 10"; end
    end
  end
  if Settings.Commons.Enabled.Items then
    -- use_item,slot=main_hand,if=(!variable.trinket_1_buffs&!variable.trinket_2_buffs|trinket.1.cooldown.remains&!variable.trinket_2_buffs|trinket.2.cooldown.remains&!variable.trinket_1_buffs|trinket.1.cooldown.remains&trinket.2.cooldown.remains)&(pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=18|!talent.apocalypse&buff.dark_transformation.up)&((trinket.1.cooldown.duration=90|trinket.2.cooldown.duration=90)|!talent.raise_abomination&!talent.army_of_the_dead|!talent.raise_abomination&talent.army_of_the_dead&pet.army_ghoul.active|talent.raise_abomination&pet.abomination.active)
    local ItemToUse, _, ItemRange = Player:GetUseableItems(OnUseExcludes, 16, true)
    if ItemToUse and ((not VarTrinket1Buffs and not VarTrinket2Buffs or Trinket1:CooldownDown() and not VarTrinket2Buffs or Trinket2:CooldownDown() and not VarTrinket1Buffs or Trinket1:CooldownDown() and Trinket2:CooldownDown()) and (VarApocGhoulActive and VarApocGhoulRemains <= 18 or not S.Apocalypse:IsAvailable() and Pet:BuffUp(S.DarkTransformation)) and ((VarTrinket1CD == 90 or VarTrinket2CD == 90) or not S.RaiseAbomination:IsAvailable() and not S.ArmyoftheDead:IsAvailable() or not S.RaiseAbomination:IsAvailable() and S.ArmyoftheDead:IsAvailable() and VarArmyGhoulActive or S.RaiseAbomination:IsAvailable() and VarAbomActive)) then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Main Hand use_item for " .. ItemToUse:Name() .. " trinkets 12"; end
    end
    -- Note: Generic use_items for non-trinkets.
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
    if ItemToUse and ((not VarTrinket1Buffs or Trinket1:CooldownDown()) and (not VarTrinket2Buffs or Trinket2:CooldownDown())) then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Generic use_item for " .. ItemToUse:Name() .. " trinkets 14"; end
    end
  end
end

local function Variables()
  -- variable,name=st_planning,op=setif,value=1,value_else=0,condition=active_enemies=1&(!raid_event.adds.exists|!raid_event.adds.in|raid_event.adds.in>15|raid_event.pull.has_boss&raid_event.adds.in>15)
  VarSTPlanning = ActiveEnemies == 1
  -- variable,name=adds_remain,op=setif,value=1,value_else=0,condition=active_enemies>=2&(!raid_event.adds.exists&fight_remains>6|raid_event.adds.exists&raid_event.adds.remains>6)
  VarAddsRemain = ActiveEnemies >= 2 and FightRemains > 6
  -- variable,name=apoc_timing,op=setif,value=3,value_else=0,condition=cooldown.apocalypse.remains<5&debuff.festering_wound.stack<1&cooldown.unholy_assault.remains>5
  VarApocTiming = (S.Apocalypse:CooldownRemains() < 5 and FesterStacks < 1 and S.UnholyAssault:CooldownRemains() > 5) and 3 or 0
  -- variable,name=pop_wounds,op=setif,value=1,value_else=0,condition=(cooldown.apocalypse.remains>variable.apoc_timing|!talent.apocalypse)&(debuff.festering_wound.stack>=1&cooldown.unholy_assault.remains<20&talent.unholy_assault&variable.st_planning|debuff.rotten_touch.up&debuff.festering_wound.stack>=1|debuff.festering_wound.stack>=4-pet.abomination.active)|fight_remains<5&debuff.festering_wound.stack>=1
  VarPopWounds = (S.Apocalypse:CooldownRemains() > VarApocTiming or not S.Apocalypse:IsAvailable()) and (FesterStacks >= 1 and S.UnholyAssault:CooldownRemains() < 20 and S.UnholyAssault:IsAvailable() and VarSTPlanning or Target:DebuffUp(S.RottenTouchDebuff) and FesterStacks >= 1 or FesterStacks >= 4 - num(VarAbomActive)) or BossFightRemains < 5 and FesterStacks >= 1
  -- variable,name=pooling_runic_power,op=setif,value=1,value_else=0,condition=talent.vile_contagion&cooldown.vile_contagion.remains<5&runic_power<30
  VarPoolingRunicPower = S.VileContagion:IsAvailable() and S.VileContagion:CooldownRemains() < 5 and Player:RunicPower() < 30
  -- variable,name=spend_rp,op=setif,value=1,value_else=0,condition=(!talent.rotten_touch|talent.rotten_touch&!debuff.rotten_touch.up|runic_power.deficit<20)&((talent.improved_death_coil&(active_enemies=2|talent.coil_of_devastation)|rune<3|pet.gargoyle.active|buff.sudden_doom.react|!variable.pop_wounds&debuff.festering_wound.stack>=4))
  VarSpendRP = (not S.RottenTouch:IsAvailable() or S.RottenTouch:IsAvailable() and Target:DebuffDown(S.RottenTouchDebuff) or Player:RunicPowerDeficit() < 20) and (S.ImprovedDeathCoil:IsAvailable() and (ActiveEnemies == 2 or S.CoilofDevastation:IsAvailable()) or Player:Rune() < 3 or VarGargActive or Player:BuffUp(S.SuddenDoomBuff) or not VarPopWounds and FesterStacks >= 4)
  -- variable,name=san_coil_mult,op=setif,value=2,value_else=1,condition=buff.essence_of_the_blood_queen.stack>=4
  VarSanCoilMult = (Player:BuffStack(S.EssenceoftheBloodQueenBuff) >= 4) and 2 or 1
  -- variable,name=epidemic_targets,value=3+talent.improved_death_coil+(talent.frenzied_bloodthirst*variable.san_coil_mult)+(talent.hungering_thirst&talent.harbinger_of_doom&buff.sudden_doom.up)
  VarEpidemicTargets = 3 + num(S.ImprovedDeathCoil:IsAvailable()) + num(S.FrenziedBloodthirst:IsAvailable() and VarSanCoilMult) + num(S.HungeringThirst:IsAvailable() and S.HarbingerofDoom:IsAvailable() and Player:BuffUp(S.SuddenDoomBuff))
end

--- ===== APL Main =====
local function APL()
  EnemiesMelee = Player:GetEnemiesInMeleeRange(5)
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    EnemiesMeleeCount = #EnemiesMelee
    Enemies10ySplashCount = Target:GetEnemiesInSplashRangeCount(10)
  else
    EnemiesMeleeCount = 1
    Enemies10ySplashCount = 1
  end
  ActiveEnemies = mathmax(EnemiesMeleeCount, Enemies10ySplashCount)

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(EnemiesMelee, false)
    end

    -- Check which enemies don't have Virulent Plague
    EnemiesWithoutVP = UnitsWithoutVP(Enemies10ySplash)

    -- Is Abomination active?
    VarAbomActive = Ghoul:AbomActive()
    VarAbomRemains = Ghoul:AbomRemains()
    -- Is Apocalypse Ghoul active?
    VarApocGhoulActive = S.Apocalypse:TimeSinceLastCast() <= 15
    VarApocGhoulRemains = (VarApocGhoulActive) and 15 - S.Apocalypse:TimeSinceLastCast() or 0
    -- Is Army active?
    VarArmyGhoulActive = S.ArmyoftheDead:TimeSinceLastCast() <= 30
    VarArmyGhoulRemains = (VarArmyGhoulActive) and 30 - S.ArmyoftheDead:TimeSinceLastCast() or 0
    -- Is Gargoyle active?
    VarGargActive = Ghoul:GargActive()
    VarGargRemains = Ghoul:GargRemains()

    -- Check our stacks of Festering Wounds
    FesterStacks = Target:DebuffStack(S.FesteringWoundDebuff)
    FesterTargets = S.FesteringWoundDebuff:AuraActiveCount()

    -- Use the right version of Festering Strike/Scythe
    if S.FesteringScytheAction:IsLearned() then
      FesteringAction = S.FesteringScytheAction
      FesteringRange = 14
    else
      FesteringAction = S.FesteringStrike
      FesteringRange = 5
    end
    -- Use the right WoundSpender
    WoundSpender = (S.VampiricStrikeAction:IsLearned()) and S.VampiricStrikeAction or ((S.ClawingShadows:IsAvailable()) and S.ClawingShadows or S.ScourgeStrike)
  end

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- use DeathStrike on low HP or with proc in Solo Mode
    if S.DeathStrike:IsReady() and DeathStrikeHeal() then
      if Cast(S.DeathStrike) then return "death_strike low hp or proc"; end
    end
    -- auto_attack
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(S.MindFreeze, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Things to do if more than 10y away from our target (10y instead of melee range to avoid the rotation getting twitchy when near max melee range).
    if not Target:IsInRange(10) then
      -- Manually added: Outbreak if targets are missing VP and out of range
      if S.Outbreak:IsReady() and (EnemiesWithoutVP > 0) then
        if Cast(S.Outbreak, nil, nil, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak out_of_range"; end
      end
      -- Manually added: epidemic,if=!variable.pooling_runic_power&active_enemies=0
      if S.Epidemic:IsReady() and AoEON() and S.VirulentPlagueDebuff:AuraActiveCount() > 1 and not VarPoolingRunicPower then
        if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic out_of_range"; end
      end
      -- Manually added: death_coil,if=!variable.pooling_runic_power&active_enemies=0
      if S.DeathCoil:IsReady() and S.VirulentPlagueDebuff:AuraActiveCount() < 2 and not VarPoolingRunicPower then
        if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil out_of_range"; end
      end
    end
    -- call_action_list,name=variables
    Variables()
    -- call_action_list,name=san_trinkets,if=talent.vampiric_strike
    if (Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items) and S.VampiricStrike:IsAvailable() then
      local ShouldReturn = SanTrinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=trinkets,if=!talent.vampiric_strike
    if (Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items) and not S.VampiricStrike:IsAvailable() then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=racials
    if (CDsON()) then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cds_shared
    if CDsON() then
      local ShouldReturn = CDsShared(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cds_aoe_san,if=talent.vampiric_strike&active_enemies>=3
    if CDsON() and AoEON() and S.VampiricStrike:IsAvailable() and ActiveEnemies >= 3 then
      local ShouldReturn = CDsAoESan(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cds_aoe,if=!talent.vampiric_strike&active_enemies>=2
    if CDsON() and AoEON() and not S.VampiricStrike:IsAvailable() and ActiveEnemies >= 2 then
      local ShouldReturn = CDsAoE(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cds_cleave_san,if=talent.vampiric_strike&active_enemies=2
    if CDsON() and S.VampiricStrike:IsAvailable() and ActiveEnemies == 2 then
      local ShouldReturn = CDsCleaveSan(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cds_san,if=talent.vampiric_strike&active_enemies=1
    if CDsON() and S.VampiricStrike:IsAvailable() and ActiveEnemies == 1 then
      local ShouldReturn = CDsSan(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cds,if=!talent.vampiric_strike&active_enemies=1
    if CDsON() and not S.VampiricStrike:IsAvailable() and ActiveEnemies == 1 then
      local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies=2
    if AoEON() and ActiveEnemies == 2 then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe_setup,if=active_enemies>=3&cooldown.any_dnd.remains<10&!death_and_decay.ticking
    if AoEON() and ActiveEnemies >= 3 and AnyDnD:CooldownRemains() < 10 and not Player:DnDTicking() then
      local ShouldReturn = AoESetup(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe_burst,if=active_enemies>=3&(death_and_decay.ticking|buff.death_and_decay.up&(death_knight.fwounded_targets>=(active_enemies*0.5)|talent.vampiric_strike&active_enemies<16))
    if AoEON() and ActiveEnemies >= 3 and (Player:DnDTicking() or Player:BuffUp(S.DeathAndDecayBuff) and (FesterTargets >= (ActiveEnemies * 0.5) or S.VampiricStrike:IsAvailable() and ActiveEnemies < 16)) then
      local ShouldReturn = AoEBurst(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>=3&!buff.death_and_decay.up
    if AoEON() and ActiveEnemies >= 3 and Player:BuffDown(S.DeathAndDecayBuff) then
      local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=san_fishing,if=active_enemies=1&talent.gift_of_the_sanlayn&!cooldown.dark_transformation.ready&!buff.gift_of_the_sanlayn.up&buff.essence_of_the_blood_queen.remains<cooldown.dark_transformation.remains+3
    if (ActiveEnemies == 1 or not AoEON()) and S.GiftoftheSanlayn:IsAvailable() and S.DarkTransformation:CooldownDown() and Player:BuffDown(S.GiftoftheSanlaynBuff) and Player:BuffRemains(S.EssenceoftheBloodQueenBuff) < S.DarkTransformation:CooldownRemains() + 3 then
      local ShouldReturn = SanFishing(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for SanFishing()"; end
    end
    -- call_action_list,name=san_st,if=active_enemies=1&talent.vampiric_strike
    if ActiveEnemies == 1 and S.VampiricStrike:IsAvailable() then
      local ShouldReturn = SanST(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies=1&!talent.vampiric_strike
    if ActiveEnemies == 1 and not S.VampiricStrike:IsAvailable() then
      local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
    end
    -- Add pool resources icon if nothing else to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "pool_resources"; end
  end
end

local function Init()
  S.VirulentPlagueDebuff:RegisterAuraTracking()
  S.FesteringWoundDebuff:RegisterAuraTracking()

  HR.Print("Unholy DK rotation has been updated for patch 11.1.5.")
end

HR.SetAPL(252, APL, Init)
