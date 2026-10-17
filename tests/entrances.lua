local addon, total, secret = {}, 0, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
local calls, joins, dungeon, rows
local function row(journal, x, y)
    return { journalInstanceID = journal, areaPoiID = 100, name = "Dungeon portal",
        position = { GetXY = function() return x, y end } }
end
local function reset()
    calls, joins = {}, 0
    issecretvalue = function(value) return value == secret end
    dungeon = { key = "dm", name = "Deadmines", instanceID = 36, quests = { 166 } }
    addon.dungeons = { dungeon }
    addon.quests = { [166] = { start = { mapID = 1436, x = 56.3, y = 47.5 } }, [65] = { finish = { mapID = 1453 } } }
    rows = { [1436] = { row(77, .42, .75) } }
    C_EncounterJournal = {
        GetInstanceForGameMap = function(id) assert(id == dungeon.instanceID); joins = joins + 1; return 77 end,
        GetDungeonEntrancesForMap = function(mapID) calls[#calls + 1] = mapID; return rows[mapID] or {} end }
    assert(loadfile("Core/Entrances.lua"))("DungeonPro", addon)
    return addon.Entrances
end
local function check(name, fn)
    local ok, err = pcall(fn); assert(ok, name .. ": " .. tostring(err)); total = total + 1; print("PASS " .. name)
end
check("Exact game-map to journal join uses native entrance fractions and own candidate map first", function()
    local e = reset(); local p, current = e.Get(dungeon)
    assert(p.mapID == 1436 and p.x == 42 and p.y == 75 and p.name == "Dungeon portal" and p.areaPoiID == 100)
    assert(current() and joins == 1 and #calls == 1 and calls[1] == 1436)
    for i = 1, 20 do assert(e.Get(dungeon) == p) end
    assert(joins == 1 and #calls == 1)
end)
check("Same name and game-map numeric coincidence never substitute for exact journal identity", function()
    local e = reset(); rows[1436][1].journalInstanceID = 36
    assert(e.Get(dungeon) == nil)
    assert(#calls == 2 and calls[2] == 1453)
end)
check("Missing optional capabilities and unknown journal IDs are bounded unknown", function()
    local e = reset(); C_EncounterJournal = nil; assert(e.Get(dungeon) == nil and joins == 0)
    e = reset(); C_EncounterJournal.GetInstanceForGameMap = function() joins = joins + 1; return nil end
    for i = 1, 30 do assert(e.Get(dungeon) == nil) end
    assert(joins == 2 and #calls == 0)
end)
check("No instance identity and shared or wing-specific game maps are not guessed", function()
    local e = reset(); dungeon.instanceID = nil; assert(e.Get(dungeon) == nil)
    dungeon.instanceID = 229; dungeon.wing = "lower"; assert(e.Get(dungeon) == nil)
    dungeon.wing = nil; addon.dungeons[2] = { instanceID = 229 }; assert(e.Get(dungeon) == nil)
    assert(joins == 0 and #calls == 0)
end)
check("Native point units are strict fractions and restricted invalid rows remain unknown", function()
    for _, value in ipairs({ -1, 1.01, math.huge, secret, "0.4", false }) do
        local e = reset(); rows[1436] = { row(77, value, .5) }; assert(e.Get(dungeon) == nil)
    end
    local e = reset(); rows[1436] = { row(77, 0, 1) }; local p = assert(e.Get(dungeon)); assert(p.x == 0 and p.y == 100)
end)
check("Empty and throwing map indexes retry at most once without per-refresh scans", function()
    local e = reset(); rows = {}
    C_EncounterJournal.GetDungeonEntrancesForMap = function(id) calls[#calls + 1] = id; error("unavailable") end
    for i = 1, 20 do assert(e.Get(dungeon) == nil) end
    assert(#calls == 4 and joins == 1)
end)
check("A later unknown-map retry can recover a native entry", function()
    local e = reset(); rows = {}; assert(e.Get(dungeon) == nil)
    rows[1436] = { row(77, .1, .2) }; local p = assert(e.Get(dungeon)); assert(p.x == 10 and p.y == 20)
end)
check("Replaced library getters invalidate cached native data and current predicates", function()
    local e = reset(); local p, current = e.Get(dungeon); assert(p and current())
    C_EncounterJournal.GetDungeonEntrancesForMap = function() return {} end
    assert(not current() and e.Get(dungeon) == nil)
end)
check("Getter reentry cannot publish an obsolete library or source owner", function()
    local e = reset(); rows[1436][1].position.GetXY = function() addon.dungeons = {}; return .1, .2 end
    assert(e.Get(dungeon) == nil)
    e = reset(); C_EncounterJournal.GetInstanceForGameMap = function() addon.Entrances = {}; return 77 end
    assert(e.Get(dungeon) == nil and #calls == 0)
end)
check("Point getter mutation of typed identity cannot publish mismatched coordinates", function()
    local e = reset(); local r = rows[1436][1]
    r.position.GetXY = function() r.journalInstanceID = 90; return .1, .2 end
    assert(e.Get(dungeon) == nil)
end)
check("All native callback phases reject an in-place selected dungeon identity change", function()
    for _, phase in ipairs({ "join", "list", "position" }) do
        local e = reset()
        if phase == "join" then
            C_EncounterJournal.GetInstanceForGameMap = function() dungeon.instanceID = 48; return 77 end
        elseif phase == "list" then
            C_EncounterJournal.GetDungeonEntrancesForMap = function() dungeon.instanceID = 48; return rows[1436] end
        else
            rows[1436][1].position.GetXY = function() dungeon.instanceID = 48; return .42, .75 end
        end
        assert(e.Get(dungeon) == nil, phase)
    end
end)
check("In-place game-map replacement never reuses the previous destination", function()
    local e = reset(); local p, current = e.Get(dungeon); assert(p)
    dungeon.instanceID = 48; rows[1436] = { row(88, .1, .2) }
    C_EncounterJournal.GetInstanceForGameMap = function(id) assert(id == 48); return 88 end
    assert(not current()); local nextPlace = assert(e.Get(dungeon)); assert(nextPlace ~= p and nextPlace.x == 10)
    addon.dungeons[1] = {}; local _, latest = e.Get(dungeon); assert(not latest)
end)
check("Candidate map calls and returned rows have fixed upper bounds", function()
    local e = reset(); addon.quests = {}; dungeon.quests = {}
    for i = 1, 100 do addon.quests[i] = { start = { mapID = 1000 + i } } end
    rows = {}; assert(e.Get(dungeon) == nil and #calls == 64)
    for i = 1, 3 do assert(e.Get(dungeon) == nil) end
    assert(#calls == 128)
end)
check("Actual catalogue map candidates remain separate from native acceptance", function()
    local e = reset(); assert(loadfile("Database/Catalog.lua"))("DungeonPro", addon)
    local dm
    for _, d in ipairs(addon.dungeons) do if d.key == "dm" then dm = d end end
    C_EncounterJournal.GetInstanceForGameMap = function(id) assert(id == 36); return 77 end
    local p = assert(e.Get(dm)); assert(p.mapID == 1436 and p.x == 42 and p.y == 75)
end)
issecretvalue = nil
print("Entrance modeled checks passed: " .. total .. " (native coverage unverified)")
