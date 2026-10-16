local addon = {}
assert(loadfile("Core/Namespace.lua"))("DungeonPrep", addon)
assert(loadfile("Core/Planner.lua"))("DungeonPrep", addon)
assert(loadfile("Database/Catalog.lua"))("DungeonPrep", addon)
local P, passed = addon.Planner, 0
local function check(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name .. ": " .. tostring(err), 0) end
    passed = passed + 1
    print("PASS " .. name)
end
local function eq(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function ctx(done, active)
    done, active = done or {}, active or {}
    return { level = 20, faction = "Alliance", class = "MAGE", race = 3,
        completed = function(id) return done[id] or false end,
        active = function(id) return active[id] or false end, ready = function() return false end }
end
local function q(id, parents, extra)
    local result = { id = id, minLevel = 1, requirementsKnown = true, requires = parents }
    for k, v in pairs(extra or {}) do result[k] = v end
    return result
end
check("VanCleef resolves to the actual beginning, not the locked penultimate quest", function()
    local engine = P.New(addon.quests, ctx())
    eq(engine:State(166).status, "LOCKED")
    local actions, unknown = engine:Next(166)
    eq(#actions, 1); eq(actions[1].id, 65); eq(actions[1].kind, "pickup"); eq(unknown, false)
end)
check("Chain resumes after completed steps", function()
    local actions = P.New(addon.quests, ctx({ [65] = true, [132] = true })):Next(166)
    eq(actions[1].id, 135)
end)
check("Active prerequisite must be finished before the child can be picked up", function()
    local engine = P.New(addon.quests, ctx({}, { [65] = true }))
    local actions = engine:Next(166)
    eq(actions[1].id, 65); eq(actions[1].kind, "complete")
end)
check("Ready prerequisite directs to turn-in", function()
    local c = ctx({}, { [65] = true }); c.ready = function() return true end
    local actions = P.New(addon.quests, c):Next(166)
    eq(actions[1].kind, "turnin")
end)
check("Missing requirements evidence is never available", function()
    eq(P.New(addon.quests, ctx()):State(92753).status, "UNKNOWN")
end)
check("Story order is not silently treated as prerequisite evidence", function()
    local engine = P.New(addon.quests, ctx({ [92752] = true }))
    local actions, unknown = engine:Next(92753)
    eq(#actions, 0); eq(unknown, true)
end)
check("Quest already in log overrides incomplete catalogue requirements", function()
    eq(P.New(addon.quests, ctx({}, { [92753] = true })):State(92753).status, "ACTIVE")
end)
check("Faction restrictions remove quests from the dungeon totals", function()
    local d = { quests = { 5728 }, coverage = "reviewed" }
    eq(#P.New(addon.quests, ctx()):Dungeon(d).rows, 0)
end)
check("Forever race IDs are not truncated to a classic eight-bit mask", function()
    local c = ctx(); c.race = 95
    eq(P.Eligible(addon.quests[96393], c), true)
    c.race = 1; eq(P.Eligible(addon.quests[96393], c), false)
end)
check("OR branches choose an actionable alternative", function()
    local quests = { [1] = q(1, nil, { minLevel = 60 }), [2] = q(2), [3] = q(3, { { ids = { 1, 2 } } }) }
    local actions, unknown = P.New(quests, ctx()):Next(3)
    eq(actions[1].id, 2); eq(unknown, false)
end)
check("AND groups collect both branches and deduplicate common ancestors", function()
    local quests = { [1] = q(1), [2] = q(2, { { ids = { 1 } } }), [3] = q(3, { { ids = { 1 } } }),
        [4] = q(4, { { ids = { 2 } }, { ids = { 3 } } }) }
    local actions = P.New(quests, ctx()):Next(4)
    eq(#actions, 1); eq(actions[1].id, 1)
end)
check("Accept-only prerequisites are distinct from completed prerequisites", function()
    local quests = { [1] = q(1), [2] = q(2, { { ids = { 1 }, mode = "active" } }) }
    eq(P.New(quests, ctx({}, { [1] = true })):State(2).status, "AVAILABLE")
end)
check("Missing parent fails closed", function()
    local e = P.New({ [2] = q(2, { { ids = { 999 } } }) }, ctx())
    eq(e:State(2).status, "UNKNOWN")
    local actions, unknown = e:Next(2); eq(#actions, 0); eq(unknown, true)
end)
check("Cycles terminate without availability", function()
    local e = P.New({ [1] = q(1, { { ids = { 2 } } }), [2] = q(2, { { ids = { 1 } } }) }, ctx())
    eq(e:State(1).status, "UNKNOWN")
end)
check("Unknown character API results do not become false history", function()
    local c = ctx(); c.completed = function() return nil end
    eq(P.New(addon.quests, c):State(65).status, "UNKNOWN")
end)
check("Partial dungeon coverage never grants ready", function()
    local c = ctx({ [65] = true })
    eq(P.New(addon.quests, c):Dungeon({ quests = { 65 }, coverage = "partial" }).ready, false)
end)
check("Prepared means held quests, not necessarily completed quests", function()
    local c = ctx({}, { [65] = true })
    eq(P.New(addon.quests, c):Dungeon({ quests = { 65 }, coverage = "reviewed" }).ready, true)
end)
check("Inside-only pickups do not require leaving the dungeon to prepare", function()
    local e = P.New({ [1] = q(1, nil, { startsInside = true }) }, ctx())
    local d = e:Dungeon({ quests = { 1 }, coverage = "reviewed" })
    eq(d.ready, true); eq(d.actions[1].kind, "inside")
end)
check("Future schema is preserved", function()
    GetLocale = function() return "enUS" end
    assert(loadfile("Core/Client.lua"))("DungeonPrep", addon)
    DungeonPrepDB = { schema = 99, sentinel = {} }
    local previous = DungeonPrepDB
    eq(addon.RestoreDB(), false); eq(DungeonPrepDB, previous); eq(DungeonPrepDB.schema, 99)
end)
check("Class API exceptions become unknown restrictions", function()
    UnitClass = function() error("blocked") end
    UnitRace = function() return "Dwarf", "Dwarf", 3 end
    UnitLevel = function() return 20 end
    UnitFactionGroup = function() return "Alliance" end
    local c = addon.Context()
    eq(c.class, nil); eq(c.race, 3)
end)
check("Secret and nonfinite values cannot authorize decisions", function()
    local secret = {}; issecretvalue = function(v) return v == secret end
    eq(addon.Clean(secret, "table"), nil); eq(addon.Clean(0 / 0, "number"), nil)
    eq(addon.Clean(math.huge, "number"), nil); eq(addon.Clean(false, "boolean"), false)
end)
print("Planner checks passed: " .. passed)
