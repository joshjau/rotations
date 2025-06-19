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
HR.GUISettings.APL.Hunter = {
  Commons = {
    Enabled = {
      Potions = true,
      Trinkets = true,
      Items = true,
    },
    ExhilarationHP = 20,
    MendPetHP = 40,
    SummonPetSlot = 1,
  },
  CommonsDS = {
    DisplayStyle = {
      -- Common
      Interrupts = "Cooldown",
      Items = "Suggested",
      Potions = "Suggested",
      Trinkets = "Suggested",
      -- Class Specific
      FuryOfTheEagle = "Suggested",
    },
  },
  CommonsOGCD = {
    GCDasOffGCD = {
      Exhilaration = true,
      ExplosiveShot = false,
      Flare = false,
      FreezingTrap = false,
      HuntersMark = false,
      MendPet = false,
      RevivePet = false,
      Stampede = false,
      SteelTrap = false,
      SummonPet = false,
      TarTrap = false,
    },
    OffGCDasOffGCD = {
      CounterShot = true,
      Racials = true,
    }
  },
  BeastMastery = {
    PotionType = {
      Selected = "Tempered",
    },
    GCDasOffGCD = {
      AMurderOfCrows = false,
      BestialWrath = false,
      Bloodshed = false,
      CallOfTheWild = false,
      DireBeast = false,
      WailingArrow = false,
    },
  },
  Marksmanship = {
    MaxPrioDamage = true,
    PotionType = {
      Selected = "Tempered",
    },
    GCDasOffGCD = {
      RapidFire = false,
      Volley = false,
      WailingArrow = false,
    },
    OffGCDasOffGCD = {
      Salvo = true,
      Trueshot = true,
    }
  },
  Survival = {
    AspectOfTheEagle = true,
    PotionType = {
      Selected = "Tempered",
    },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      Butchery = false,
      CoordinatedAssault = true,
      Harpoon = true,
      Spearhead = false,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      AspectOfTheEagle = true,
    }
  }
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Hunter = CreateChildPanel(ARPanel, "Hunter")
local CP_HunterDS = CreateChildPanel(CP_Hunter, "Class DisplayStyles")
local CP_HunterOGCD = CreateChildPanel(CP_Hunter, "Class OffGCDs")
local CP_BeastMastery = CreateChildPanel(CP_Hunter, "BeastMastery")
local CP_Marksmanship = CreateChildPanel(CP_Hunter, "Marksmanship")
local CP_Survival = CreateChildPanel(CP_Hunter, "Survival")

-- Hunter
CreateARPanelOptions(CP_Hunter, "APL.Hunter.Commons")
CreatePanelOption("Slider", CP_Hunter, "APL.Hunter.Commons.ExhilarationHP", {0, 100, 1}, "Exhilaration HP", "Set the Exhilaration HP threshold. Set to 0 to disable.")
CreatePanelOption("Slider", CP_Hunter, "APL.Hunter.Commons.MendPetHP", {0, 100, 1}, "Mend Pet High HP", "Set the Mend Pet HP threshold. Set to 0 to disable.")
CreatePanelOption("Slider", CP_Hunter, "APL.Hunter.Commons.SummonPetSlot", {1, 5, 1}, "Summon Pet Slot", "Which pet stable slot to suggest when summoning a pet.")
CreateARPanelOptions(CP_HunterDS, "APL.Hunter.CommonsDS")
CreateARPanelOptions(CP_HunterOGCD, "APL.Hunter.CommonsOGCD")

-- Beast Mastery
CreateARPanelOptions(CP_BeastMastery, "APL.Hunter.BeastMastery")

-- Marksmanship
CreatePanelOption("CheckButton", CP_Marksmanship, "APL.Hunter.Marksmanship.MaxPrioDamage", "Prioritize Current Target", "Enable this setting to prioritize the current target when choosing a target for some abilities.")
CreateARPanelOptions(CP_Marksmanship, "APL.Hunter.Marksmanship")

-- Survival
CreatePanelOption("CheckButton", CP_Survival, "APL.Hunter.Survival.AspectOfTheEagle", "Show Aspect of the Eagle", "Show Aspect of the Eagle when out of Melee Range.")
CreateARPanelOptions(CP_Survival, "APL.Hunter.Survival")