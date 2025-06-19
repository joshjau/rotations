--- ============================ HEADER ============================
--- HeroCache - High-Performance Caching System for DPS Rotations
--- Provides multi-level nested caching with dynamic code generation
--- for optimal performance in real-time combat calculations
--- ============================ HEADER ============================

--- ======= LOCALIZE =======
-- Addon namespace
local _, Cache = ...
-- Core Lua functions (localized for performance)
local wipe = wipe
local select = select
local setmetatable = setmetatable
local loadstring = loadstring
local type = type
local pcall = pcall
local assert = assert
local setfenv = setfenv
-- String/Table manipulation functions
local stringformat = string.format
local tableconcat = table.concat

-- Initialize saved variables database
if not HeroCacheDB then
  _G.HeroCacheDB = {}
  HeroCacheDB.Enabled = true -- Cache enabled by default for performance
end
-- Cache the enabled state locally to avoid repeated global lookups in hot paths
local CacheEnabled = HeroCacheDB.Enabled

--- ======= GLOBALIZE =======
-- Export Cache as global HeroCache
HeroCache = Cache


--- ============================ CONTENT ============================
--- ======= CACHE STRUCTURE =======
-- Cache tables organized by data type and persistence level

-- Temporary caches (reset each combat/frame cycle)
Cache.APLVar = {}       -- Action Priority List variables (rotation state)
Cache.Enemies = {       -- Enemy unit data organized by interaction type
  ItemAction = {},      -- Item usage on enemies
  Melee = {},          -- Melee range enemies
  Ranged = {},         -- Ranged enemies
  Spell = {},          -- Spell casting enemies
  SpellAction = {}     -- Spell targets
}
Cache.GUIDInfo = {}     -- Unit GUID metadata
Cache.MiscInfo = {}     -- Miscellaneous temporary data
Cache.SpellInfo = {}    -- Spell metadata (cooldowns, costs, etc.)
Cache.ItemInfo = {}     -- Item metadata
Cache.UnitInfo = {}     -- Unit information cache

-- Persistent caches (survives reload/logout)
Cache.Persistent = {
  Equipment = {},       -- Player equipment data
  TierSets = {},       -- Tier set bonuses
  Player = {           -- Player-specific persistent data
    Class = { UnitClass("player") }, -- Class info
    Spec = {},         -- Specialization data
    HeroTrees = {},    -- Hero talent trees
    ActiveHeroTree = {}, -- Currently active hero tree
    ActiveHeroTreeID = {}, -- Active hero tree ID
  },
  BookIndex = { Pet = {}, Player = {} }, -- Spell book indices
  SpellLearned = { Pet = {}, Player = {} }, -- Known spells tracking
  Texture = { Spell = {}, Item = {}, Custom = {} }, -- Icon textures
  ElvUIPaging = { PagingString, PagingStrings = {}, PagingBars = {} }, -- ElvUI integration
  Talents = { Rank } -- Talent rank data
}

--- ======= CACHE MANAGEMENT =======
-- Reset flag to prevent multiple resets per cycle
Cache.HasBeenReset = false

-- Clears all temporary caches (preserves persistent data)
-- Called at the start of each combat cycle for fresh state
function Cache.Reset()
  if not Cache.HasBeenReset then
    -- Clear all temporary cache tables
    wipe(Cache.APLVar)
    wipe(Cache.Enemies.ItemAction)
    wipe(Cache.Enemies.Melee)
    wipe(Cache.Enemies.Ranged)
    wipe(Cache.Enemies.Spell)
    wipe(Cache.Enemies.SpellAction)
    wipe(Cache.GUIDInfo)
    wipe(Cache.MiscInfo)
    wipe(Cache.SpellInfo)
    wipe(Cache.ItemInfo)
    wipe(Cache.UnitInfo)

    Cache.HasBeenReset = true
  end
end

-- Updates the locally cached enabled state when settings change
-- Call this after modifying HeroCacheDB.Enabled
function Cache.UpdateEnabledState()
  CacheEnabled = HeroCacheDB.Enabled
end

--- ======= DYNAMIC CACHE SYSTEM =======
-- Advanced caching system that generates optimized functions at runtime
-- for multi-level nested table access with automatic table creation

local MakeCache
do
  -- Generates argument names for dynamic functions (a1, a2, a3, ...)
  local function makeArgs(n)
    local args = {}
    for i = 1, n do
      args[i] = stringformat("a%d", i)
    end
    return args
  end

  -- Creates nested table initialization code for deep cache paths
  -- Generates: [a1] = { [a2] = { [a3] = val } }
  local function makeInitString(args, start)
    local n = #args
    local t = {}
    -- Opening brackets and table assignments
    for i = start, n - 1 do
      t[#t + 1] = '[' .. args[i] .. '] = { '
    end
    -- Final value assignment
    t[#t + 1] = '[' .. args[n] .. '] = val'
    -- Closing brackets
    for i = start, n - 1 do
      t[#t + 1] = ' }'
    end
    return tableconcat(t)
  end

  -- Generates optimized getter functions for N-level cache access
  -- Returns nil if any level in the path doesn't exist
  local function makeGetter(n)
    -- Simple case: cache[arg]
    if n == 1 then
      return "return function(arg) return cache[arg] end"
    end

    -- Complex case: cache[a1][a2][a3]...
    local args = makeArgs(n)
    local checks = {}
    -- Generate null checks for each level: if not c1 then return nil end
    for i = 1, n - 1 do
      checks[i] = stringformat("local c%d = c%d[%s] if not c%d then return nil end",
        i, i - 1, args[i], i)
    end

    return stringformat([=[
return function(%s)
  local c0 = cache
  %s
  return c%d[%s]
end]=],
      tableconcat(args, ','),      -- Function parameters
      tableconcat(checks, '\n  '), -- Null checks
      n - 1, args[#args])          -- Final table access
  end

  -- Generates optimized setter functions for N-level cache access
  -- Automatically creates intermediate tables as needed
  local function makeSetter(n)
    -- Simple case: cache[arg] = val
    if n == 1 then
      return "return function(val, arg) cache[arg] = val return val end"
    end

    -- Complex case: cache[a1][a2][a3] = val (with auto-creation)
    local args = makeArgs(n)
    local initializers = {}
    -- Generate table creation code for each level
    for i = 1, n - 1 do
      initializers[i] = stringformat("local c%d = c%d[%s] if not c%d then c%d[%s] = { %s } return val end",
        i, i - 1, args[i], i, i - 1, args[i], makeInitString(args, i + 1))
    end

    return stringformat([=[
return function(val, %s)
  local c0 = cache
  %s
  c%d[%s] = val
  return val
end]=],
      tableconcat(args, ','),           -- Function parameters
      tableconcat(initializers, '\n  '), -- Table creation
      n - 1, args[#args])               -- Final assignment
  end

  -- Generates lazy-loading getter/setter functions
  -- If value doesn't exist, calls provided function to generate it
  local function makeGetSetter(n)
    local args = makeArgs(n)
    local initializers = {}
    -- Generate lazy initialization code
    for i = 1, n - 1 do
      initializers[i] = stringformat("local c%d = c%d[%s] if not c%d then local val = func() c%d[%s] = { %s } return val end",
        i, i - 1, args[i], i, i - 1, args[i], makeInitString(args, i + 1))
    end

    return stringformat([=[
return function(func, %s)
  local c0 = cache
  %s
  local val = c%d[%s]
  if val == nil then
    val = func()
    c%d[%s] = val
  end
  return val
end]=],
      tableconcat(args, ','),           -- Function parameters
      tableconcat(initializers, '\n  '), -- Lazy initialization
      n - 1, args[#args], n - 1, args[#args]) -- Get and set
  end

  -- Creates a metatable-based function cache with lazy loading
  -- Functions are compiled on first access and cached for reuse
  local function initGlobal(func)
    return setmetatable({}, {
      __index = function(tbl, key)
        tbl[key] = loadstring(func(key))() -- Compile and cache function
        return tbl[key]
      end
    })
  end

  -- Function generators for different access patterns
  local cacheGetters = initGlobal(makeGetter)       -- Read-only access
  local cacheSetters = initGlobal(makeSetter)       -- Write access with auto-creation
  local cacheGetSetters = initGlobal(makeGetSetter) -- Lazy-loading access

  --[[
    Creates a high-performance cache implementation with three access methods:
    
    Get(...) - Retrieves cached value or nil
      Example: cache.Get("SpellInfo", 123, "PowerCost")
      
    Set(val, ...) - Sets value at path, creates tables as needed
      Example: cache.Set(50, "SpellInfo", 123, "PowerCost")
      
    GetSet(func, ...) - Lazy evaluation: gets existing value or calls func to create it
      Example: cache.GetSet(function() return GetSpellPowerCost(123) end, "SpellInfo", 123, "PowerCost")
      
    The system dynamically generates optimized functions for each depth level,
    providing maximum performance for frequently accessed cache paths.
  ]]
  MakeCache = function(cache)
    -- Initialize function maps for different argument counts
    local function init(proto)
      local function makeFunc(n)
        local func = proto[n]()
        setfenv(func, { ['cache'] = cache }) -- Bind cache to function scope
        return func
      end

      local map = {}
      -- Pre-populate first 7 entries for optimal Lua VM performance
      -- (uses array part of table instead of hash part)
      for i = 1, 7 do
        map[i] = makeFunc(i)
      end
      return setmetatable(map, {
        __index = function(tbl, key)
          tbl[key] = makeFunc(key) -- Generate function on demand
          return tbl[key]
        end
      })
    end

    -- Create function maps for each access pattern
    local getters = init(cacheGetters)
    local setters = init(cacheSetters)
    local getsetters = init(cacheGetSetters)
    
    return {
      -- Direct read access
      Get = function(...)
        return getters[select('#', ...)](...)
      end,
      -- Write access with validation
      Set = function(...)
        local n = select('#', ...)
        assert(n > 1, "setter expects at least 2 parameters")
        return setters[n - 1](select(n, ...), ...)
      end,
      -- Lazy evaluation access
      GetSet = function(...)
        local n = select('#', ...)
        local last = select(n, ...)
        if n > 1 and type(last) == 'function' then
          return getsetters[n - 1](last, ...)
        else
          return getters[n](...)
        end
      end,
    }
  end
end

-- Create the main cache implementation instance
local CacheImpl = MakeCache(Cache)

--- ======= PUBLIC API =======
-- High-level cache access functions used throughout the rotation system

-- Retrieves cached values with optional lazy loading
-- If caching is disabled, calls the fallback function directly
-- 
-- Usage patterns:
--   Cache.Get("SpellInfo", 53, "CostTable") -- Direct access
--   Cache.Get("SpellInfo", 53, "CostTable", function() return GetSpellPowerCost(53) end) -- With fallback
function Cache.Get(...)
  if CacheEnabled then
    return CacheImpl.GetSet(...)
  else
    -- Cache disabled: execute fallback function if provided
    local argc = select('#', ...)
    local last = select(argc, ...)
    if type(last) == 'function' then
      return last()
    else
      return nil
    end
  end
end

-- Stores values in cache and returns the value
-- If caching is disabled, returns the value without storing
-- 
-- Usage: Cache.Set("SpellInfo", 53, "CostTable", GetSpellPowerCost(53))
function Cache.Set(...)
  local argc = select('#', ...)
  return CacheEnabled and CacheImpl.Set(...) or select(argc, ...)
end
