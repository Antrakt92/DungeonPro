local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local secret, state = {}, {}
local generic = "Interface\\Icons\\INV_Misc_Map_01"
local function tuple(map, art)
    local values = {}; values[11], values[22] = art, map
    return unpack(values, 1, 22)
end
local function reset()
    state = { list = { -1, 101, 102, 101 }, calls = 0, infoCalls = 0,
        rows = { [101] = { 36, "native/deadmines" }, [102] = { 43, 5678 } } }
    issecretvalue = function(v) return v == secret end
    C_EncounterJournal, EJ_GetInstanceInfo = nil, nil
    GetLFDChoiceOrder = function(...)
        assert(select("#", ...) == 0); state.calls = state.calls + 1; return state.list
    end
    GetLFGDungeonInfo = function(id)
        state.infoCalls = state.infoCalls + 1
        local row = state.rows[id]; if row then return tuple(row[1], row[2]) end
    end
end
local function check(name, fn)
    reset(); local ok, err = pcall(fn)
    if not ok then error(name .. ": " .. tostring(err), 0) end
    total = total + 1; print("PASS " .. name)
end
check("Native enumeration maps gameMapID and background exact tuple positions", function()
    assert(addon.DungeonArt({ instanceID = 36 }) == "native/deadmines")
    assert(addon.DungeonArt({ instanceID = 43 }) == 5678)
    assert(state.calls == 1 and state.infoCalls == 2, "deduplicate and cache once")
end)
check("Encounter Journal remains first and avoids LFG scans", function()
    C_EncounterJournal = { GetInstanceForGameMap = function(id) assert(id == 36); return 99 end }
    EJ_GetInstanceInfo = function(id) assert(id == 99); return nil, nil, nil, nil, 111, 222 end
    assert(addon.DungeonArt({ instanceID = 36 }) == 222 and state.calls == 0)
end)
check("Unknown catalog map IDs never enumerate or guess", function()
    for _, id in ipairs({ false, secret, 0, -1, 1.5, 0/0, math.huge, "36" }) do
        assert(addon.DungeonArt({ instanceID = id }) == generic)
    end
    assert(addon.DungeonArt({}) == generic and state.calls == 0)
end)
check("Missing APIs recover when supplied without rescanning on each refresh", function()
    local enumerate = GetLFDChoiceOrder; GetLFDChoiceOrder = nil
    assert(addon.DungeonArt({ instanceID = 36 }) == generic)
    GetLFDChoiceOrder = enumerate
    assert(addon.DungeonArt({ instanceID = 36 }) == "native/deadmines")
    state.rows[101][2] = 999
    assert(addon.DungeonArt({ instanceID = 36 }) == "native/deadmines" and state.calls == 1)
    local old = GetLFGDungeonInfo; GetLFGDungeonInfo = function(id) return old(id) end
    assert(addon.DungeonArt({ instanceID = 36 }) == 999 and state.calls == 2)
end)
check("Distinct images for the same map are ambiguous while duplicates agree", function()
    state.rows[102] = { 36, "native/deadmines" }
    assert(addon.DungeonArt({ instanceID = 36 }) == "native/deadmines")
    local old = GetLFGDungeonInfo; GetLFGDungeonInfo = function(id) return old(id) end
    state.rows[102][2] = "native/other"
    assert(addon.DungeonArt({ instanceID = 36 }) == generic)
end)
check("Malformed sparse oversized and restricted lists fail closed boundedly", function()
    for _, list in ipairs({ false, secret, { [1] = 101, [3] = 102 }, { ["1"] = 101 },
        { 101, secret }, { 101, "102" }, { 101, 1.5 }, { 101, math.huge } }) do
        state.list = list
        GetLFDChoiceOrder = function() return state.list end
        assert(addon.DungeonArt({ instanceID = 36 }) == generic)
    end
    state.list = {}; for i = 1, 501 do state.list[i] = 101 end
    GetLFDChoiceOrder = function() return state.list end
    assert(addon.DungeonArt({ instanceID = 36 }) == generic and state.infoCalls == 0)
end)
check("Throwing native reads remain bounded unknown for the same API identity", function()
    GetLFGDungeonInfo = function() state.infoCalls = state.infoCalls + 1; error("unavailable") end
    for _ = 1, 5 do assert(addon.DungeonArt({ instanceID = 36 }) == generic) end
    assert(state.calls == 1 and state.infoCalls == 1)
end)
check("Secret malformed maps and art never authorize textures", function()
    for _, row in ipairs({ {secret, 123}, {36, secret}, {36, false}, {36, 0}, {36, -1},
        {36, 1.5}, {36, math.huge}, {36, ""}, {36, string.rep("a", 1025)}, {0, 123}, {36.5, 123} }) do
        state.rows = { [101] = row }; GetLFGDungeonInfo = function(id)
            local r = state.rows[id]; if r then return tuple(r[1], r[2]) end
        end
        assert(addon.DungeonArt({ instanceID = 36 }) == generic)
    end
end)
check("Reentrant native scan does not recurse or expose partially built art", function()
    local old = GetLFGDungeonInfo
    GetLFGDungeonInfo = function(id)
        assert(addon.DungeonArt({ instanceID = 36 }) == generic)
        return old(id)
    end
    assert(addon.DungeonArt({ instanceID = 36 }) == "native/deadmines" and state.calls == 1)
end)
check("Changed API identity during native read cannot publish old mapping", function()
    local old = GetLFGDungeonInfo
    GetLFGDungeonInfo = function(id)
        local row = state.rows[id]
        GetLFGDungeonInfo = function() return tuple(36, 999) end
        return row and tuple(row[1], row[2])
    end
    assert(addon.DungeonArt({ instanceID = 36 }) == generic)
    assert(addon.DungeonArt({ instanceID = 36 }) == 999)
end)
check("No match empty list and unavailable background use generic icon", function()
    assert(addon.DungeonArt({ instanceID = 999 }) == generic)
    GetLFDChoiceOrder = function() return {} end
    assert(addon.DungeonArt({ instanceID = 36 }) == generic)
    GetLFDChoiceOrder = function() return {101} end
    GetLFGDungeonInfo = function() return tuple(36, nil) end
    assert(addon.DungeonArt({ instanceID = 36 }) == generic)
end)
check("The five-hundredth entry is included and headers never reach info", function()
    state.list = {}; for i = 1, 499 do state.list[i] = -i end
    state.list[500] = 101
    assert(addon.DungeonArt({ instanceID = 36 }) == "native/deadmines" and state.infoCalls == 1)
end)
check("Missing info and enumeration failures cannot read other client state", function()
    local original = GetLFGDungeonInfo; GetLFGDungeonInfo = nil
    assert(addon.DungeonArt({ instanceID = 36 }) == generic and state.calls == 0)
    GetLFGDungeonInfo = original
    GetLFDChoiceOrder = function() state.calls = state.calls + 1; error("not available") end
    for _ = 1, 5 do assert(addon.DungeonArt({ instanceID = 36 }) == generic) end
    assert(state.calls == 1 and state.infoCalls == 0)
end)
check("Restricted checker failure never reaches native enumeration", function()
    issecretvalue = function() error("restricted") end
    assert(addon.DungeonArt({ instanceID = 36 }) == generic and state.calls == 0)
end)
check("A later agreeing image cannot resolve an earlier same-map ambiguity", function()
    GetLFDChoiceOrder = function() return { 101, 102, 103 } end
    GetLFGDungeonInfo = function(id)
        return tuple(36, id == 102 and "native/conflicting" or "native/deadmines")
    end
    assert(addon.DungeonArt({ instanceID = 36 }) == generic)
    assert(addon.DungeonArt({ instanceID = 36 }) == generic, "cached ambiguity must remain unknown")
end)
check("A later native failure discards every partial mapping and stays bounded for the same capabilities", function()
    GetLFDChoiceOrder = function() state.calls = state.calls + 1; return { 101, 102, 103 } end
    GetLFGDungeonInfo = function(id)
        state.infoCalls = state.infoCalls + 1
        if id == 103 then error("later native row unavailable") end
        return tuple(id == 101 and 36 or 43, id == 101 and "native/deadmines" or "native/caverns")
    end
    for _ = 1, 5 do
        assert(addon.DungeonArt({ instanceID = 36 }) == generic)
        assert(addon.DungeonArt({ instanceID = 43 }) == generic)
    end
    assert(state.calls == 1 and state.infoCalls == 3, "failed scan must neither expose partial maps nor retry per card")
end)
check("Replacing the enumerator during its read prevents old publication and recovers on the new identity", function()
    local replacement = function() state.calls = state.calls + 1; return { 102 } end
    GetLFDChoiceOrder = function()
        state.calls = state.calls + 1
        GetLFDChoiceOrder = replacement
        return { 101 }
    end
    GetLFGDungeonInfo = function(id) return tuple(36, id == 101 and "native/old" or "native/new") end
    assert(addon.DungeonArt({ instanceID = 36 }) == generic, "detached old enumeration must not publish")
    assert(addon.DungeonArt({ instanceID = 36 }) == "native/new" and state.calls == 2)
    assert(addon.DungeonArt({ instanceID = 36 }) == "native/new" and state.calls == 2)
end)
print("Dungeon art checks passed: " .. total)
