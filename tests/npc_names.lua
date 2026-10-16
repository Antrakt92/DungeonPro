local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local secret, state, place = {}, {}, {}
local function reset()
    state = { guid = "Actual-native-GUID", id = 234, locale = "ruRU", name = "Локальное имя", names = 0, ids = 0 }
    place = { npcID = 234, name = "Source name", mapID = 1436, x = 56.3, y = 47.5 }
    issecretvalue = function(value) return value == secret end
    UnitGUID = function(unit, ...)
        assert(unit == "npc" and select("#", ...) == 0, "only the actual npc token may be inspected")
        return state.guid
    end
    GetLocale = function(...) assert(select("#", ...) == 0); return state.locale end
    C_CreatureInfo = { GetCreatureID = function(guid, ...)
        assert(guid == state.guid and select("#", ...) == 0, "must pass the actual clean GUID")
        state.ids = state.ids + 1
        return state.id
    end }
    UnitName = function(unit, ...)
        assert(unit == "npc" and select("#", ...) == 0)
        state.names = state.names + 1
        return state.name, "Ignored realm field"
    end
end
local function check(label, fn)
    reset()
    local ok, message = pcall(fn)
    assert(ok, label .. ": " .. tostring(message))
    total = total + 1; print("PASS " .. label)
end
check("Actual matching NPC returns fresh native first name without modifying source facts", function()
    assert(addon.GiverName(place) == "Локальное имя" and state.names == 1 and state.ids == 2)
    assert(place.name == "Source name" and place.npcID == 234 and place.mapID == 1436 and place.x == 56.3)
    state.name, state.locale = "Updated client name", "enUS"
    assert(addon.GiverName(place) == state.name and state.names == 2)
    state.guid = nil
    assert(addon.GiverName(place) == nil and state.names == 2, "no visited-name cache may survive missing live identity")
    assert(addon.char == nil and addon.db == nil, "native names must not create saved data")
end)
check("Missing source name stays supported and inherited identities cannot authorize reads", function()
    place.name = nil
    assert(addon.GiverName(place) == state.name)
    local inherited = setmetatable({}, { __index = function() error("source getters must not execute") end })
    assert(addon.GiverName(inherited) == nil and state.names == 1)
end)
check("Invalid source places and NPC IDs fail before any native name read", function()
    for _, bad in ipairs({ false, 234, "234", secret }) do assert(addon.GiverName(bad) == nil) end
    assert(addon.GiverName(nil) == nil)
    for _, bad in ipairs({ false, 0, -1, 1.5, "234", math.huge, 0 / 0, secret }) do
        place.npcID = bad; assert(addon.GiverName(place) == nil)
    end
    place.npcID = nil
    place.itemID, place.objectID, place.dropNPCID, place.displayID = 234, 234, 234, 234
    assert(addon.GiverName(place) == nil and state.names == 0 and state.ids == 0)
end)
check("Malformed present source names cannot hide a mutation behind a nil snapshot", function()
    for _, bad in ipairs({ false, 234, {}, secret, "", " \t\n", string.rep("x", 1025) }) do
        place.name = bad; assert(addon.GiverName(place) == nil)
    end
    assert(state.names == 0)
end)
check("Different or noncreature identity never reads the unit name", function()
    for _, bad in ipairs({ 235, 0, -1, 1.5, "234", math.huge, secret }) do
        state.id = bad; assert(addon.GiverName(place) == nil)
    end
    state.guid, state.id = "Player-actual-guid", nil
    assert(addon.GiverName(place) == nil and state.names == 0)
end)
check("GUID and locale must be clean nonblank bounded strings before name reads", function()
    for _, field in ipairs({ "guid", "locale" }) do
        for _, bad in ipairs({ false, 1, {}, secret, "", " \t", string.rep("x", field == "guid" and 257 or 33) }) do
            reset(); state[field] = bad; assert(addon.GiverName(place) == nil and state.names == 0)
        end
        reset(); state[field] = nil; assert(addon.GiverName(place) == nil and state.names == 0)
    end
end)
check("Exact documented adapter bounds remain accepted without guessed GUID parsing", function()
    state.guid, state.locale, state.name = string.rep("g", 256), string.rep("l", 32), string.rep("n", 1024)
    assert(addon.GiverName(place) == state.name)
end)
check("Native name absence restrictions and malformed values return nil", function()
    for _, bad in ipairs({ false, 1, {}, secret, "", " \t\n", string.rep("x", 1025) }) do
        state.name = bad; assert(addon.GiverName(place) == nil)
    end
    state.name = nil; assert(addon.GiverName(place) == nil)
end)
check("Missing nonfunction or throwing native APIs fail closed", function()
    for _, key in ipairs({ "UnitGUID", "GetLocale", "UnitName" }) do
        for _, replacement in ipairs({ false, true, function() error("not loaded") end }) do
            reset(); _G[key] = replacement; assert(addon.GiverName(place) == nil)
        end
        reset(); _G[key] = nil; assert(addon.GiverName(place) == nil)
    end
    for _, replacement in ipairs({ false, true, {}, { GetCreatureID = true },
        { GetCreatureID = function() error("not available") end } }) do
        reset(); C_CreatureInfo = replacement; assert(addon.GiverName(place) == nil and state.names == 0)
    end
    reset(); C_CreatureInfo = nil; assert(addon.GiverName(place) == nil and state.names == 0)
end)
check("Reentrant identity locale or source changes reject the name just read", function()
    for _, field in ipairs({ "guid", "id", "locale", "npcID", "sourceName" }) do
        reset()
        UnitName = function(unit)
            assert(unit == "npc")
            if field == "npcID" then place.npcID = 235
            elseif field == "sourceName" then place.name = "Changed source"
            elseif field == "id" then state.id = 235
            else state[field] = "Changed context" end
            return "Must be discarded"
        end
        assert(addon.GiverName(place) == nil, field)
    end
end)
check("Unavailable or throwing final identity rechecks cannot return a stale name", function()
    local readName = UnitName
    UnitName = function(unit)
        local name = readName(unit)
        C_CreatureInfo.GetCreatureID = function() error("identity disappeared") end
        return name
    end
    assert(addon.GiverName(place) == nil)
    reset(); UnitName = function() state.guid = nil; return "Stale" end
    assert(addon.GiverName(place) == nil)
end)
check("Secret-checker failure and restricted source mutation stay unknown", function()
    issecretvalue = function() error("restricted context") end
    assert(addon.GiverName(place) == nil and state.names == 0)
    reset(); UnitName = function() place.name = secret; return "Discard" end
    assert(addon.GiverName(place) == nil)
end)
print("Live NPC-name modeled checks passed: " .. total .. " (no native client acceptance)")
