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
check("Reviewed new dungeon game-map identities reach the native join before portal lookup", function()
    for key, expected in pairs({ thanes = 3065, lordaeron = 2999, excavation = 2998, dalaran = 2959 }) do
        local e = reset(); assert(loadfile("Database/Catalog.lua"))("DungeonPro", addon)
        local selected
        for _, d in ipairs(addon.dungeons) do if d.key == key then selected = d end end
        assert(selected and selected.instanceID == expected, key .. ": exact game-map identity is present")
        local seen
        C_EncounterJournal.GetInstanceForGameMap = function(id) seen = id; assert(id == expected); return 77 end
        -- Modeled portal data exercises the join; these coordinates are not real destinations.
        rows = { [1455] = { row(77, .25, .5) } }
        local place, current = e.Get(selected)
        assert(seen == expected and place and current() and place.mapID == 1455 and place.x == 25 and place.y == 50)
        addon.dungeons = {}
        assert(not current(), "replaced catalogue expires the new dungeon destination")
    end
end)
check("Recorded portal works with absent services and the human-observed nil journal", function()
    for _, unavailable in ipairs({ "missing", "nil-journal", "empty-portals" }) do
        local e = reset()
        dungeon.entrance = { gameMapID = 36, mapID = 1455, x = 27.5, y = 48, source = "https://phylactery.io/instance/36" }
        if unavailable == "missing" then C_EncounterJournal = nil
        elseif unavailable == "nil-journal" then C_EncounterJournal.GetInstanceForGameMap = function() return nil end
        else rows = {} end
        local point, current = e.Get(dungeon)
        assert(point and current() and point.origin == "recorded" and point.mapID == 1455 and point.x == 27.5 and point.y == 48)
        dungeon.entrance.x = 28
        assert(not current(), "changed recorded source expires the destination")
    end
end)
check("An exact native portal takes priority over a recorded fallback", function()
    local e = reset()
    dungeon.entrance = { gameMapID = 36, mapID = 1455, x = 27.5, y = 48, source = "https://phylactery.io/instance/36" }
    local point = assert(e.Get(dungeon))
    assert(point.mapID == 1436 and point.x == 42 and point.y == 75 and point.origin ~= "recorded")
end)
check("Recorded portals reject malformed coordinates source identities and shared wings", function()
    for _, value in ipairs({ secret, false, "27.5", -1, 101, math.huge }) do
        local e = reset(); C_EncounterJournal = nil
        dungeon.entrance = { gameMapID = 36, mapID = 1455, x = value, y = 48, source = "https://phylactery.io/instance/36" }
        assert(e.Get(dungeon) == nil)
    end
    for _, fieldName in ipairs({ "source", "gameMapID", "mapID" }) do
        local e = reset(); C_EncounterJournal = nil
        dungeon.entrance = { gameMapID = 36, mapID = 1455, x = 27.5, y = 48, source = "https://phylactery.io/instance/36" }
        dungeon.entrance[fieldName] = fieldName == "source" and "https://phylactery.io/instance/3065" or 0
        assert(e.Get(dungeon) == nil)
    end
    local e = reset(); C_EncounterJournal = nil
    dungeon.entrance = { gameMapID = 36, mapID = 1455, x = 27.5, y = 48, source = "https://phylactery.io/instance/36" }
    local _, current = e.Get(dungeon)
    addon.dungeons[2] = { instanceID = 36 }
    assert(not current() and e.Get(dungeon) == nil)
    addon.dungeons[2] = nil; dungeon.wing = "lower"
    assert(e.Get(dungeon) == nil)
end)
check("Actual Thanes recorded entrance survives the missing native join without becoming a quest giver", function()
    local e = reset(); assert(loadfile("Database/Catalog.lua"))("DungeonPro", addon)
    C_EncounterJournal.GetInstanceForGameMap = function() return nil end
    rows = {}
    local thanes
    for _, d in ipairs(addon.dungeons) do if d.key == "thanes" then thanes = d end end
    local point, current = e.Get(thanes)
    assert(point and current() and point.origin == "recorded" and point.source == "https://phylactery.io/instance/3065")
    assert(point.mapID == 1455 and point.x == 27.5 and point.y == 48)
    local giver = addon.quests[96394].start
    assert(point ~= giver and (point.x ~= giver.x or point.y ~= giver.y))
    thanes.entrance = {}; assert(not current())
end)
local reviewedSources = {
    "https://wowhandbook.com/zones/dungeons/blackrock-spire/",
    "https://www.warcrafttavern.com/forever/guides/dungeon-entrances/",
    "https://warcrafttavern.com/forever/guides/dungeon-entrances/",
    "https://www.wowhead.com/forever/zone=718",
    "https://www.wowhead.com/forever/zone=718/wailing-caverns",
    "https://www.wowhead.com/forever/guide/dungeons-overview-locations-details",
}
local function recordedFixture(source, known)
    local e = reset(); C_EncounterJournal = nil
    if not known then dungeon.instanceID = nil end
    dungeon.entrance = { mapID = 1428, x = 33, y = 25.2, source = source }
    if known then dungeon.entrance.gameMapID = dungeon.instanceID end
    return e, dungeon.entrance
end
check("Reviewed source families preserve typed known identities and do not guess unknown GameMaps", function()
    for _, source in ipairs(reviewedSources) do
        for _, known in ipairs({ true, false }) do
            local e, entry = recordedFixture(source, known)
            local point, current = e.Get(dungeon)
            assert(point and current() and point.origin == "recorded" and point.source == source)
            assert(point.mapID == 1428 and point.x == 33 and point.y == 25.2)
            assert((known and dungeon.instanceID == 36 and entry.gameMapID == 36) or
                (not known and dungeon.instanceID == nil and entry.gameMapID == nil))
            assert(joins == 0 and #calls == 0, "recorded fallback starts no unavailable native reads")
        end
    end
end)
check("Known GameMap bindings cannot be omitted changed or supplied by a different source identity", function()
    for _, source in ipairs(reviewedSources) do
        for _, value in ipairs({ false, true, 0, 37, "36", secret }) do
            local e, entry = recordedFixture(source, true)
            entry.gameMapID = value
            assert(e.Get(dungeon) == nil)
        end
        local e, entry = recordedFixture(source, true)
        entry.gameMapID = nil
        assert(e.Get(dungeon) == nil)
    end
    local e, entry = recordedFixture("https://phylactery.io/instance/36", false)
    assert(e.Get(dungeon) == nil)
    entry.gameMapID = 36
    assert(e.Get(dungeon) == nil, "a source URL cannot invent the dungeon GameMap")
end)
check("Explicit shared recorded approach supports both wings without changing native ambiguity", function()
    local e, entry = recordedFixture(reviewedSources[1], true)
    dungeon.instanceID, dungeon.wing, entry.gameMapID = 229, "lower", 229
    local upper = { key = "upper", name = "Upper wing", instanceID = 229, wing = "upper", quests = {},
        entrance = { gameMapID = 229, mapID = 1428, x = 33, y = 25.2, source = reviewedSources[1] } }
    addon.dungeons[2] = upper
    assert(e.Get(dungeon) == nil and e.Get(upper) == nil)
    entry.scope, entry.kind = "shared", "approach"
    upper.entrance.scope, upper.entrance.kind = "shared", "approach"
    local point, current = e.Get(dungeon)
    local other, otherCurrent = e.Get(upper)
    assert(point and other and current() and otherCurrent())
    assert(point.scope == "shared" and point.kind == "approach" and point.origin == "recorded")
    assert(other.scope == "shared" and other.kind == "approach" and other.origin == "recorded")
    assert(joins == 0 and #calls == 0 and point.x == other.x and point.y == other.y)
    entry.scope = nil
    assert(not current() and e.Get(dungeon) == nil and otherCurrent())
end)
check("Unknown-instance approach keeps its outer-route kind and never becomes a native portal", function()
    local e, entry = recordedFixture(reviewedSources[6], false)
    entry.kind = "approach"
    local point, current = e.Get(dungeon)
    assert(point and current() and point.kind == "approach" and point.origin == "recorded")
    assert(point.gameMapID == nil and point.journalInstanceID == nil and joins == 0)
    entry.kind = "portal"
    assert(not current() and e.Get(dungeon) == nil)
end)
check("Runtime provenance guards match canonical client domains paths and positive zone IDs", function()
    for _, source in ipairs({
        "https://wowhandbook.com.evil.invalid/zones/dungeons/blackrock-spire/",
        "http://wowhandbook.com/zones/dungeons/blackrock-spire/",
        "https://wowhandbook.com/zones/dungeons/blackrock-spire/?x=33",
        "https://wowhandbook.com/zones/dungeons/blackrock-spire/#entry",
        "https://www.warcrafttavern.com/wow-classic/guides/dungeon-entrances/",
        "https://www.wowhead.com/classic/zone=718/wailing-caverns",
        "https://www.wowhead.com/forever/npc=718",
        "https://www.wowhead.com/forever/zone=0",
        "https://www.wowhead.com/forever/zone=000718",
        "https://www.wowhead.com/forever/zone=718?x=33",
        "https://www.wowhead.com/forever/guide/dungeons-overview-locations-details/",
        " https://www.wowhead.com/forever/zone=718",
    }) do
        local e = recordedFixture(source, true)
        assert(e.Get(dungeon) == nil, source)
    end
end)
check("Absent optional identity and route fields cannot drift to invalid present aliases", function()
    for _, fieldName in ipairs({ "instanceID", "wing", "gameMapID", "scope", "kind" }) do
        for _, value in ipairs({ false, true, 0, "unsupported", secret }) do
            local e, entry = recordedFixture(reviewedSources[1], false)
            local point, current = e.Get(dungeon)
            assert(point and current())
            local owner = (fieldName == "instanceID" or fieldName == "wing") and dungeon or entry
            owner[fieldName] = value
            assert(not current(), "absent->invalid drift: " .. fieldName)
            assert(e.Get(dungeon) == nil, "fresh read rejects invalid " .. fieldName)
        end
    end
end)
check("Recorded point owner source and output changes expire both known and unknown contexts", function()
    for _, known in ipairs({ true, false }) do
        for _, fieldName in ipairs({ "source", "mapID", "x", "y" }) do
            local e, entry = recordedFixture(reviewedSources[1], known)
            local point, current = e.Get(dungeon)
            assert(point and current())
            if fieldName == "source" then entry.source = reviewedSources[2]
            else point[fieldName] = secret end
            assert(not current(), "detached source/output: " .. fieldName)
        end
        local e = recordedFixture(reviewedSources[1], known)
        local _, current = e.Get(dungeon)
        addon.dungeons = { dungeon }
        assert(not current(), "replacement catalogue must expire a retained route")
    end
end)
check("Every sourced current catalogue entrance is usable without optional native services", function()
    local e = reset(); assert(loadfile("Database/Catalog.lua"))("DungeonPro", addon)
    C_EncounterJournal = nil
    local present = false
    for _, selected in ipairs(addon.dungeons) do
        local point, current = e.Get(selected)
        if selected.entrance then
            local entry = selected.entrance
            present = true
            assert(point and current(), selected.key .. ": sourced route is usable")
            assert(point.mapID == entry.mapID and point.x == entry.x and point.y == entry.y and point.source == entry.source)
            assert(point.origin == "recorded" and point.kind == entry.kind and point.scope == entry.scope)
        else assert(point == nil, selected.key .. ": no fabricated route for absent evidence") end
    end
    assert(present, "current catalogue includes reviewed source routes")
end)
issecretvalue = nil
print("Entrance modeled checks passed: " .. total .. " (native coverage unverified)")
