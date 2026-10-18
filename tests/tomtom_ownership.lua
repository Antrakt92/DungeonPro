-- TomTom 4.3.12 public API: duplicate AddWaypoint returns the existing UID;
-- only a new UID copies options. DefaultCallbacks runs before duplicate lookup.
local load = loadfile
if arg and arg[1] then loadfile = function(path) return load(path == "UI/Navigation.lua" and arg[1] or path) end end
local f = assert(loadfile("tests/client_ui.lua"))("fixture")
loadfile = load
local a, total = f.addon, 0
GetLocale = function() return "enUS" end
f.eventFrame.scripts.OnEvent(f.eventFrame, "ADDON_LOADED", "DungeonPro")
local nav, place = a.Navigation, a.quests[65].start
local action = { id = 65, kind = "visit", place = place }
local active, sets, clears, removes, added
local function reset()
    nav.Stop(); TomTom = nil; issecretvalue = nil
    active, sets, clears, removes, added = nil, 0, 0, {}, 0
    UiMapPoint.CreateFromCoordinates = function(mapID, x, y) return { uiMapID = mapID, position = { x = x, y = y } } end
    C_Map.GetUserWaypoint = function() return active end
    C_Map.SetUserWaypoint = function(point) sets = sets + 1; active = point; return true end
    C_Map.ClearUserWaypoint = function() clears = clears + 1; active = nil end
end
local function backend()
    local owner = {}
    owner.WaypointExists = function() return false end
    owner.AddWaypoint = function(_, map, x, y, opts)
        added = added + 1
        local uid = { map, x, y }
        for key, value in pairs(opts) do uid[key] = value end
        return uid
    end
    owner.RemoveWaypoint = function(_, uid) removes[#removes + 1] = uid end
    TomTom = owner; return owner
end
local function test(name, fn)
    reset(); local ok, err = pcall(fn); assert(ok, name .. ": " .. tostring(err))
    total = total + 1; print("PASS " .. name)
end
test("An existing persistent TomTom waypoint is borrowed without any Add or removal", function()
    local owner = backend(); local player = { persistent = true }
    owner.WaypointExists = function(_, map, x, y, title)
        assert(map == place.mapID and x == place.x / 100 and y == place.y / 100 and title == a.QuestName(65)); return true
    end
    owner.AddWaypoint = function() added = added + 1; return player end
    assert(nav.Start(action)); nav.Stop()
    assert(added == 0 and #removes == 0 and player.persistent)
end)
test("A pin created inside default callback setup is never adopted as new", function()
    local owner = backend(); local player, fired
    owner.AddWaypoint = function(_, map, x, y, opts)
        fired = true; player = { map, x, y, title = opts.title, persistent = true }
        return player -- public duplicate return does not copy the caller's options
    end
    assert(nav.Start(action)); nav.Stop()
    assert(fired and player.persistent and #removes == 0 and sets == 1 and clears == 1)
end)
test("New UID copied options authorize exactly one matching cleanup", function()
    backend(); assert(nav.Start(action) and added == 1 and sets == 0)
    nav.Stop(); nav.Stop(); assert(#removes == 1 and type(removes[1].dungeonProOwner) == "table")
end)
for _, mode in ipairs({ "missing", "throwing", "nil", "true", "number" }) do
    test("Unreadable TomTom absence proof falls back safely: " .. mode, function()
        local owner = backend()
        if mode == "missing" then owner.WaypointExists = nil
        elseif mode == "throwing" then owner.WaypointExists = function() error("unavailable") end
        elseif mode == "nil" then owner.WaypointExists = function() return nil end
        elseif mode == "true" then owner.WaypointExists = function() return true end
        else owner.WaypointExists = function() return 0 end end
        assert(nav.Start(action)); nav.Stop(); assert(added == 0 and #removes == 0 and sets == 1 and clears == 1)
    end)
end
for _, value in ipairs({ 42, "uid", true, {}, { dungeonProOwner = {} } }) do
    test("Unproven returned UID is never removed: " .. type(value), function()
        local owner = backend(); owner.AddWaypoint = function() return value end
        assert(nav.Start(action)); nav.Stop(); assert(#removes == 0 and sets == 1)
    end)
end
test("Restricted option marker never grants ownership", function()
    local owner = backend(); local marker = {}
    owner.AddWaypoint = function() return { dungeonProOwner = marker } end
    issecretvalue = function(value) return rawequal(value, marker) end
    assert(nav.Start(action)); nav.Stop(); assert(#removes == 0 and sets == 1)
end)
test("A marker changed by its readability check is never adopted", function()
    local owner = backend(); local add = owner.AddWaypoint; local uid, token, fired
    owner.AddWaypoint = function(self, ...)
        uid = add(self, ...); token = uid.dungeonProOwner; return uid
    end
    issecretvalue = function(value)
        if token and rawequal(value, token) then fired = true; uid.dungeonProOwner = {} end
        return false
    end
    assert(nav.Start(action)); nav.Stop(); assert(fired and #removes == 0 and sets == 1)
end)
for _, mode in ipairs({ "add", "exists", "remove", "coordinates", "cancel" }) do
    test("Preflight reentry invalidates dispatch: " .. mode, function()
        local owner = backend(); local fired, oldX = false, place.x
        owner.WaypointExists = function()
            fired = true
            if mode == "add" then owner.AddWaypoint = function() error("replaced") end
            elseif mode == "exists" then owner.WaypointExists = function() return false end
            elseif mode == "remove" then owner.RemoveWaypoint = function() error("replaced") end
            elseif mode == "coordinates" then place.x = oldX + 1
            else nav.Stop() end
            return false
        end
        local result = nav.Start(action); place.x = oldX
        if mode == "cancel" then assert(not result) else assert(result) end
        nav.Stop(); assert(fired and added == 0 and #removes == 0)
    end)
end
test("Superseded Add releases only its newly created UID", function()
    local owner = backend(); local add = owner.AddWaypoint; local fired, oldUID
    owner.AddWaypoint = function(self, ...)
        local uid = add(self, ...)
        if not fired then fired = true; oldUID = uid; assert(nav.Start({ id = 132, kind = "visit", place = place })) end
        return uid
    end
    assert(not nav.Start(action)); assert(fired and #removes == 1 and removes[1] == oldUID)
    nav.QuestChanged(65); assert(#removes == 1)
    nav.QuestChanged(132); assert(#removes == 2 and removes[2] ~= oldUID)
end)
test("Superseded duplicate return never removes a player UID", function()
    local owner = backend(); local add = owner.AddWaypoint; local fired; local player = { persistent = true }
    owner.AddWaypoint = function(self, ...)
        if not fired then fired = true; assert(nav.Start({ id = 132, place = place })); return player end
        return add(self, ...)
    end
    assert(not nav.Start(action) and fired and #removes == 0)
    nav.Stop(); assert(#removes == 1 and removes[1] ~= player and player.persistent)
end)
test("Changed removal binding cannot borrow the old lease", function()
    local owner = backend(); assert(nav.Start(action)); local foreign = 0
    owner.RemoveWaypoint = function() foreign = foreign + 1 end
    nav.Stop(); assert(#removes == 0 and foreign == 0)
end)
test("Cancellation while creating a new UID releases only that owned result", function()
    local owner = backend(); local add = owner.AddWaypoint; local fired
    owner.AddWaypoint = function(self, ...) local uid = add(self, ...); fired = true; nav.Stop(); return uid end
    assert(not nav.Start(action) and fired and #removes == 1 and sets == 0)
    nav.Stop(); assert(#removes == 1)
end)
print("TomTom ownership: " .. total .. " checks passed (modeled public API; no native acceptance)")
