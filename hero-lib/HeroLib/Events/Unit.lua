--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local _, HL = ...
-- HeroLib
local Unit          = HL.Unit
local Target        = Unit.Target

-- Lua locals
local pairs         = pairs

-- File Locals


--- ============================ CONTENT ============================
-- Manages nameplate units for multi-target detection and cleave optimization.
do
  local NameplateUnits = Unit.Nameplate

  HL:RegisterForEvent(function(Event, UnitID) NameplateUnits[UnitID]:Cache() end, "NAME_PLATE_UNIT_ADDED")
  HL:RegisterForEvent(function(Event, UnitID) NameplateUnits[UnitID]:Init() end, "NAME_PLATE_UNIT_REMOVED")
end

-- Updates the primary target, crucial for single-target spell casting.
HL:RegisterForEvent(function() Target:Cache() end, "PLAYER_TARGET_CHANGED", "PLAYER_SOFT_ENEMY_CHANGED")

-- Updates the focus target for secondary target tracking and control.
do
  local Focus = Unit.Focus

  HL:RegisterForEvent(function() Focus:Cache() end, "PLAYER_FOCUS_CHANGED")
end

-- Keeps arena opponent data fresh for accurate PvP burst windows.
do
  local ArenaUnits = Unit.Arena

  HL:RegisterForEvent(
    function(Event, UnitID)
      local ArenaUnit = ArenaUnits[UnitID]
      if ArenaUnit then ArenaUnit:Cache() end
    end,
    "ARENA_OPPONENT_UPDATE"
  )
end

-- Updates boss units, vital for raid mechanics and phase transitions.
do
  local BossUnits = Unit.Boss

  HL:RegisterForEvent(
    function()
      for _, BossUnit in pairs(BossUnits) do BossUnit:Cache() end
    end,
    "INSTANCE_ENCOUNTER_ENGAGE_UNIT"
  )
end

-- Updates friendly party and raid frames for group-based logic.
HL:RegisterForEvent(
  function()
    for _, PartyUnit in pairs(Unit.Party) do PartyUnit:Cache() end
    for _, RaidUnit in pairs(Unit.Raid) do RaidUnit:Cache() end
  end,
  "GROUP_ROSTER_UPDATE"
)

-- Updates unit health, essential for execute abilities and health-based logic.
HL:RegisterForEvent(
  function(Event, UnitID)
    if UnitID == Target:ID() then
      Target:Cache()
    else
      local FoundUnit = Unit.Nameplate[UnitID] or Unit.Boss[UnitID]
      if FoundUnit then FoundUnit:Cache() end
    end
  end,
  "UNIT_HEALTH"
)

-- Updates unit power (mana, rage, etc.), informing resource-sensitive abilities.
HL:RegisterForEvent(
  function(Event, UnitID, PowerType)
    if UnitID == Target:ID() then
      Target:Cache()
    else
      local FoundUnit = Unit.Nameplate[UnitID] or Unit.Boss[UnitID] or Unit.Arena[UnitID]
      if FoundUnit then FoundUnit:Cache() end
    end
  end,
  "UNIT_POWER_UPDATE"
)

-- Updates unit auras, critical for tracking buffs/debuffs for rotation decisions.
HL:RegisterForEvent(
  function(Event, UnitID, UpdateInfo)
    -- Optimize by only processing events with meaningful aura changes.
    if UpdateInfo and (UpdateInfo.addedAuras or UpdateInfo.updatedAuraInstanceIDs or UpdateInfo.removedAuraInstanceIDs) then
      if UnitID == Target:ID() then
        Target:Cache()
      else
        local FoundUnit = Unit.Nameplate[UnitID] or Unit.Boss[UnitID] or Unit.Arena[UnitID]
        if FoundUnit then FoundUnit:Cache() end
      end
    end
  end,
  "UNIT_AURA"
)

-- Handles changes in unit state like faction, flags, and targetability.
do
  local Focus = Unit.Focus
  local BossUnits, PartyUnits, RaidUnits, NameplateUnits = Unit.Boss, Unit.Party, Unit.Raid, Unit.Nameplate

  HL:RegisterForEvent(
    function(Event, UnitID)
      if UnitID == Target:ID() then
        Target:Cache()
      elseif UnitID == Focus:ID() then
        Focus:Cache()
      else
        local FoundUnit = PartyUnits[UnitID] or RaidUnits[UnitID] or BossUnits[UnitID] or NameplateUnits[UnitID]
        if FoundUnit then FoundUnit:Cache() end
      end
    end,
    "UNIT_TARGETABLE_CHANGED", "UNIT_FACTION", "UNIT_FLAGS"
  )
end
