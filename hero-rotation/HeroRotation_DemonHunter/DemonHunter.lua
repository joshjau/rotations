--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
local MergeTableByKey = HL.Utils.MergeTableByKey
-- HeroRotation
local HR         = HeroRotation

--- ============================ CONTENT ============================

-- Spell
if not Spell.DemonHunter then Spell.DemonHunter = {} end
Spell.DemonHunter.Commons = {
  -- Racials
  ArcaneTorrent                         = Spell(50613),
  -- Abilities
  Glide                                 = Spell(131347),
  -- Talents
  AuraofPain                            = Spell(207347),
  ChaosNova                             = Spell(179057),
  CollectiveAnguish                     = Spell(390152),
  Demonic                               = Spell(213410),
  SigilofSpite                          = Spell(390163),
  Felblade                              = Spell(232893),
  FirstoftheIllidari                    = Spell(235893),
  FlamesofFury                          = Spell(389694),
  FoddertotheFlame                      = Spell(391429),
  QuickenedSigils                       = Spell(209281),
  SoulSigils                            = Spell(395446),
  StudentofSuffering                    = Spell(452412),
  TheHunt                               = Spell(370965),
  UnhinderedAssault                     = Spell(444931),
  VengefulRetreat                       = Spell(198793),
  -- Sigils
  SigilofChains                         = MultiSpell(202138, 389807),
  SigilofFlame                          = MultiSpell(204596, 389810), -- 204596: Base ID, 389810: Precise
  SigilofMisery                         = MultiSpell(207684, 389813), -- 207684: Base ID, 389813: Precise
  SigilofSilence                        = MultiSpell(202137, 389809),
  -- Utility
  Disrupt                               = Spell(183752),
  -- Buffs
  ExplosiveAdrenalineBuff               = Spell(1218713), -- Improvised Seaforium Pacemaker buff
  InnerResilienceBuff                   = Spell(450706),  -- Tome of Light's Devotion buff
  JunkmaestrosBuff                      = Spell(1219661), -- Junkmaestro's Mega Magnet buff
  -- Debuffs
  SigilofFlameDebuff                    = Spell(204598),
  SigilofMiseryDebuff                   = Spell(207685),
  -- Other
  Pool                                  = Spell(999910)
}

Spell.DemonHunter.AldrachiReaver = {
  -- Talents
  ArtoftheGlaive                        = Spell(442290),
  FuryoftheAldrachi                     = Spell(442718),
  KeenEngagement                        = Spell(442497),
  ReaversGlaive                         = Spell(442294),
  -- Buffs
  ArtoftheGlaiveBuff                    = Spell(444661),
  GlaiveFlurryBuff                      = Spell(442435),
  ThrilloftheFightAtkBuff               = Spell(442695),
  ThrilloftheFightHavocDmgBuff          = Spell(442688),
  ThrilloftheFightVengDmgBuff           = Spell(1227062),
  WarbladesHungerBuff                   = Spell(442503),
  -- Debuffs
  ReaversMarkDebuff                     = Spell(442624),
  RendingStrikeBuff                     = Spell(442442),
}

Spell.DemonHunter.FelScarred = {
  -- Abilities
  AbyssalGaze                           = Spell(452497),
  ConsumingFire                         = Spell(452487),
  FelDesolation                         = Spell(452486),
  Flamebound                            = Spell(452413),
  SigilofDoom                           = Spell(452490),
  SoulSunder                            = Spell(452436),
  SpiritBurst                           = Spell(452437),
  -- Talents
  Demonsurge                            = Spell(454402),
  -- Buffs
  ConsumingFireBuff                     = Spell(427912),
  DemonsurgeBuff                        = Spell(452416),
  StudentofSufferingBuff                = Spell(453239),
  -- Debuffs
  SigilofDoomDebuff                     = Spell(462030),
}

Spell.DemonHunter.Havoc = MergeTableByKey(Spell.DemonHunter.Commons, {
  -- Abilities
  Annihilation                          = Spell(201427),
  BladeDance                            = Spell(188499),
  Blur                                  = Spell(198589),
  ChaosStrike                           = Spell(162794),
  DeathSweep                            = Spell(210152),
  DemonsBite                            = Spell(162243),
  FelRush                               = Spell(195072),
  ImmolationAura                        = MultiSpell(258920, 427917), -- 2nd ID is only used with A Fire Inside when one buff is already active.
  Metamorphosis                         = Spell(191427),
  ThrowGlaive                           = Spell(185123),
  -- Talents
  AFireInside                           = Spell(427775),
  AnyMeansNecessary                     = Spell(388114),
  BlindFury                             = Spell(203550),
  BurningWound                          = Spell(391189),
  ChaosTheory                           = Spell(389687),
  ChaoticTransformation                 = Spell(388112),
  CycleofHatred                         = Spell(258887),
  DemonBlades                           = Spell(203555),
  EssenceBreak                          = Spell(258860),
  EyeBeam                               = Spell(198013),
  FelBarrage                            = Spell(258925),
  FelEruption                           = Spell(211881),
  FirstBlood                            = Spell(206416),
  FuriousGaze                           = Spell(343311),
  FuriousThrows                         = Spell(393029),
  GlaiveTempest                         = Spell(342817),
  Inertia                               = Spell(427640),
  Initiative                            = Spell(388108),
  InnerDemon                            = Spell(389693),
  IsolatedPrey                          = Spell(388113),
  LooksCanKill                          = Spell(320415),
  Momentum                              = Spell(206476),
  Ragefire                              = Spell(388107),
  RestlessHunter                        = Spell(390142),
  ScreamingBrutality                    = Spell(1220506),
  SerratedGlaive                        = Spell(390154),
  ShatteredDestiny                      = Spell(388116),
  Soulrend                              = Spell(388106),
  Soulscar                              = Spell(388106),
  TacticalRetreat                       = Spell(389688),
  TrailofRuin                           = Spell(258881),
  UnboundChaos                          = Spell(347461),
  -- Buffs
  ChaosTheoryBuff                       = Spell(390195),
  CycleofHatredBuff                     = Spell(1214887),
  ExergyBuff                            = Spell(208628),
  FelBarrageBuff                        = Spell(258925),
  FuriousGazeBuff                       = Spell(343312),
  ImmolationAuraBuff                    = Spell(999999), -- Dummy, handled in Overrides
  ImmolationAuraBuff1                   = Spell(258920),
  ImmolationAuraBuff2                   = Spell(427912),
  ImmolationAuraBuff3                   = Spell(427913),
  ImmolationAuraBuff4                   = Spell(427914),
  ImmolationAuraBuff5                   = Spell(427915),
  InertiaBuff                           = Spell(427641),
  InitiativeBuff                        = Spell(391215),
  InnerDemonBuff                        = Spell(390145),
  MetamorphosisBuff                     = Spell(162264),
  MomentumBuff                          = Spell(208628),
  NecessarySacrificeBuff                = Spell(1217055), -- TWW S2 4pc Buff
  TacticalRetreatBuff                   = Spell(389890),
  UnboundChaosBuff                      = Spell(347462),
  WinningStreakBuff                     = Spell(1220706), -- TWW S2 2pc Buff
  -- Debuffs
  BurningWoundDebuff                    = Spell(391191),
  EssenceBreakDebuff                    = Spell(320338),
  SerratedGlaiveDebuff                  = Spell(390155),
})
Spell.DemonHunter.Havoc = MergeTableByKey(Spell.DemonHunter.Havoc, Spell.DemonHunter.AldrachiReaver)
Spell.DemonHunter.Havoc = MergeTableByKey(Spell.DemonHunter.Havoc, Spell.DemonHunter.FelScarred)

Spell.DemonHunter.Vengeance = MergeTableByKey(Spell.DemonHunter.Commons, {
  -- Abilities
  ImmolationAura                        = Spell(258920),
  InfernalStrike                        = Spell(189110),
  Shear                                 = Spell(203782),
  SoulCleave                            = Spell(228477),
  ThrowGlaive                           = Spell(204157),
  -- Defensive
  DemonSpikes                           = Spell(203720),
  -- Talents
  AscendingFlame                        = Spell(428603),
  BulkExtraction                        = Spell(320341),
  CycleofBinding                        = Spell(389718),
  DarkglareBoon                         = Spell(389708),
  DowninFlames                          = Spell(389732),
  Fallout                               = Spell(227174),
  FelDevastation                        = Spell(212084),
  FieryBrand                            = Spell(204021),
  FieryDemise                           = Spell(389220),
  Fracture                              = Spell(263642),
  IlluminatedSigils                     = Spell(428557),
  SoulCarver                            = Spell(207407),
  SpiritBomb                            = Spell(247454),
  VolatileFlameblood                    = Spell(390808),
  -- Sigils
  -- Utility
  Metamorphosis                         = Spell(187827),
  -- Buffs
  DemonSpikesBuff                       = Spell(203819),
  ImmolationAuraBuff                    = Spell(258920),
  MetamorphosisBuff                     = Spell(187827),
  SoulFurnaceBuff                       = Spell(391166),
  SoulFurnaceDmgBuff                    = Spell(391172),
  -- Debuffs
  FieryBrandDebuff                      = Spell(207771),
})
Spell.DemonHunter.Vengeance = MergeTableByKey(Spell.DemonHunter.Vengeance, Spell.DemonHunter.AldrachiReaver)
Spell.DemonHunter.Vengeance = MergeTableByKey(Spell.DemonHunter.Vengeance, Spell.DemonHunter.FelScarred)

-- Items
if not Item.DemonHunter then Item.DemonHunter = {} end
Item.DemonHunter.Commons = {
  -- TWW Trinkets
  Blastmaster3000                       = Item(234717, {13, 14}),
  GeargrindersSpareKeys                 = Item(230197, {13, 14}),
  HouseofCards                          = Item(230027, {13, 14}),
  ImprovisedSeaforiumPacemaker          = Item(232541, {13, 14}),
  JunkmaestrosMegaMagnet                = Item(230189, {13, 14}),
  MadQueensMandate                      = Item(212454, {13, 14}),
  MisterLockNStalk                      = Item(230193, {13, 14}),
  RatfangToxin                          = Item(235359, {13, 14}),
  RavenousHoneyBuzzer                   = Item(219298, {13, 14}),
  SignetofthePriory                     = Item(219308, {13, 14}),
  TomeofLightsDevotion                  = Item(219309, {13, 14}),
  TreacherousTransmitter                = Item(221023, {13, 14}),
  -- TWW S2 Old Trinkets
  GrimCodex                             = Item(178811, {13, 14}),
  SkardynsGrace                         = Item(133282, {13, 14}),
}

Item.DemonHunter.Vengeance = MergeTableByKey(Item.DemonHunter.Commons, {
})

Item.DemonHunter.Havoc = MergeTableByKey(Item.DemonHunter.Commons, {
})
