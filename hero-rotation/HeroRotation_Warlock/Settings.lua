--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroRotation
local HR = HeroRotation
-- HeroLib
local HL = HeroLib
-- File Locals
local GUI = HL.GUI
local CreateChildPanel = GUI.CreateChildPanel
local CreatePanelOption = GUI.CreatePanelOption
local CreateARPanelOption = HR.GUI.CreateARPanelOption
local CreateARPanelOptions = HR.GUI.CreateARPanelOptions

--- ============================ CONTENT ============================
-- All settings here should be moved into the GUI someday.
HR.GUISettings.APL.Warlock = {
  Commons = {
    HidePetSummon = false,
    Enabled = {
      Potions = true,
      Trinkets = true,
      Items = true,
    },
  },
  CommonsDS = {
    DisplayStyle = {
      -- Common
      Interrupts = "Cooldown",
      Items = "Suggested",
      Potions = "Suggested",
      Trinkets = "Suggested",
      -- Class Specific
      Malevolence = "Suggested",
      SoulRot = "Suggested",
    },
  },
  CommonsOGCD = {
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      Racials = true,
    }
  },
  Affliction = {
    UseCleaveAPL = false,
    PotionType = {
      Selected = "Tempered",
    },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      GrimoireOfSacrifice = true,
      Haunt = false,
      InquisitorsGaze = false,
      PhantomSingularity = true,
      SoulTap = true,
      SummonDarkglare = true,
      SummonPet = false,
      VileTaint = false,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
    }
  },
  Demonology = {
    SummonPetFontSize = 26,
    UnendingResolveHP = 20,
    ForceTyrantVilefiendSync = false,
    PotionType = {
      Selected = "Tempered",
    },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      DemonicStrength = false,
      GrimoireFelguard = false,
      Guillotine = false,
      Implosion = false,
      NetherPortal = true,
      PowerSiphon = true,
      SummonDemonicTyrant = false,
      SummonPet = false,
      SummonVilefiend = false,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      UnendingResolve = true,
      AxeToss = true,
    }
  },
  Destruction = {
    PotionType = {
      Selected = "Tempered",
    },
    --UnendingResolveHP = 20,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      Cataclysm = false,
      ChannelDemonfire = false,
      DimensionalRift = false,
      GrimoireOfSacrifice = true,
      InquisitorsGaze = false,
      RainOfFire = false,
      SoulFire = false,
      SummonInfernal = true,
      SummonPet = false,
      SummonSoulkeeper = false,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
    }
  }
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Warlock = CreateChildPanel(ARPanel, "Warlock")
local CP_WarlockDS = CreateChildPanel(CP_Warlock, "Class DisplayStyles")
local CP_WarlockOGCD = CreateChildPanel(CP_Warlock, "Class OffGCDs")
local CP_Demonology = CreateChildPanel(CP_Warlock, "Demonology")
local CP_Affliction = CreateChildPanel(CP_Warlock, "Affliction")
local CP_Destruction = CreateChildPanel(CP_Warlock, "Destruction")

-- Warlock
CreateARPanelOptions(CP_Warlock, "APL.Warlock.Commons")
CreateARPanelOptions(CP_WarlockDS, "APL.Warlock.CommonsDS")
CreateARPanelOptions(CP_WarlockOGCD, "APL.Warlock.CommonsOGCD")

-- Affliction
CreatePanelOption("CheckButton", CP_Affliction, "APL.Warlock.Affliction.UseCleaveAPL", "Force Cleave APL", "Force Cleave abilities, as per the Cleave APL option in Simulationcraft.")
CreateARPanelOptions(CP_Affliction, "APL.Warlock.Affliction")

-- Demonology
CreatePanelOption("Slider", CP_Demonology, "APL.Warlock.Demonology.UnendingResolveHP", {0, 100, 1}, "Unending Resolve HP", "Set the Unending Resolve HP threshold.")
CreatePanelOption("Slider", CP_Demonology, "APL.Warlock.Demonology.SummonPetFontSize", {1, 100, 1}, "Summon Pet Font Size", "Select the font size to use for the overlay on your Summon Felguard pet suggestion. This value scales with the addon's 'UI' scale.")
CreatePanelOption("CheckButton", CP_Demonology, "APL.Warlock.Demonology.ForceTyrantVilefiendSync", "Force Tyrant/Vilefiend Sync", "Enable this option to force Summon Demonic Tyrant and Vilefiend to be in sync with each other. Summon Demonic Tyrant will not be suggested if Vilefiend (or its variants) are not active.")
CreateARPanelOptions(CP_Demonology, "APL.Warlock.Demonology")

-- Destruction
CreateARPanelOptions(CP_Destruction, "APL.Warlock.Destruction")
