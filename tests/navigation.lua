local frames, methods = {}, {}
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:SetClampedToScreen(value) assert(type(value)=="boolean");self.clamped=value end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetText(value) self.text = value end
function methods:SetHeight(value) self.height = value end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetPoint(...) self.point={...} end
function methods:ClearAllPoints() end
function methods:SetJustifyH() end
function methods:GetStringHeight() return self.measured or 18 end
function methods:SetRotation(value) assert(value == value and value ~= math.huge and value ~= -math.huge); self.rotation=value end
for _, name in ipairs({ "SetMovable", "EnableMouse", "RegisterForDrag", "SetTexture",
    "SetWidth", "StartMoving", "StopMovingOrSizing" }) do methods[name] = function() end end
local function object()
    local result = setmetatable({ scripts = {} }, { __index = methods })
    frames[#frames + 1] = result; return result
end
function methods:CreateTexture() return object() end
function methods:CreateFontString(_,_,font) local result=object();result.template=font;return result end
CreateFrame = object
UIParent = object()
local addon = {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
addon.L = function(key,value) return key == "GUIDE_DISTANCE" and (value .. " yd") or key end
addon.QuestName = function() return "Quest" end
assert(loadfile("UI/Navigation.lua"))("DungeonPro", addon)
local nav, total, nativeCalls, clears, current = addon.Navigation, 0
local point = { mapID = 1, x = 60, y = 70 }
local action = { id = 1, kind = "visit", place = point }
local function reset()
    nav.Stop()
    nativeCalls, clears, current = 0, 0, nil
    TomTom, C_SuperTrack, issecretvalue = nil, nil, nil
    InCombatLockdown = nil
    addon.GiverName, addon.db = nil, nil
    addon.Theme = { StyleRow = function(row, options) assert(options.kind == "section"); row.skinned = true; return true end }
    GetLocale = function() return "enUS" end
    GetPlayerFacing = function() return 0 end
    CreateVector2D = function(x, y) return { x = x, y = y } end
    UiMapPoint = { CreateFromCoordinates = function(mapID, x, y) return { uiMapID = mapID, position = { x = x, y = y } } end }
    C_Map = {
        GetBestMapForUnit = function() return 1 end,
        GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.5 end } end,
        GetWorldPosFromMapPos = function(_, p) return 1, { x = p.y * 1000, y = p.x * 1000 } end,
        CanSetUserWaypointOnMap = function() return true end,
        SetUserWaypoint = function(p) nativeCalls = nativeCalls + 1; current = p; return true end,
        GetUserWaypoint = function() return current end,
        ClearUserWaypoint = function() clears = clears + 1; current = nil end,
        OpenWorldMap = function() end,
    }
end
-- Native-shaped TomTom test adapter: new UID tables copy options; duplicate
-- results retain the original creation token. Assertions may still use serials.
local function tomtom(spec)
    local add, remove, identities = spec.AddWaypoint, spec.RemoveWaypoint, {}
    if not add then return spec end
    spec.WaypointExists = function() return false end
    spec.AddWaypoint = function(self, map, x, y, options)
        local value = add(self, map, x, y, options)
        if type(value) == "boolean" or value == nil or value == "" or
            (type(value) == "number" and (value <= 0 or value ~= value or value == math.huge)) then return value end
        local uid = identities[value]
        if not uid then
            uid = { map, x, y, title = options.title, dungeonProOwner = options.dungeonProOwner }
            identities[value] = uid
        end
        return uid
    end
    spec.RemoveWaypoint = function(self, uid)
        for value, identity in pairs(identities) do
            if identity == uid then if remove then return remove(self, value) end; return end
        end
        error("Removing an unowned test UID")
    end
    return spec
end
local function check(name, fn)
    reset()
    local ok, err = pcall(fn); assert(ok, name .. ": " .. tostring(err))
    total = total + 1; print("PASS " .. name)
end
local function noPosition()
    for _, frame in ipairs(frames) do
        if frame.shown and frame.scripts.OnUpdate then
            assert(frame.label.text == "NO_POSITION" and not frame.arrow.shown); return
        end
    end
    error("No visible navigation frame")
end
check("Throwing native point constructor cannot crash guide", function()
    UiMapPoint.CreateFromCoordinates = function() error("not ready") end
    assert(nav.Start(action) and nativeCalls == 0)
end)
check("Malformed native point constructor result never reaches the setter", function()
    UiMapPoint.CreateFromCoordinates = function() return false end
    assert(nav.Start(action) and nativeCalls == 0)
    nav.Stop(); assert(clears == 0)
end)
check("Throwing vector constructor becomes position unknown", function()
    CreateVector2D = function() error("vector unavailable") end
    assert(nav.Start(action)); noPosition()
end)
check("Unreadable world values and failed native setters do not claim ownership", function()
    issecretvalue = function(value) return type(value) == "number" and value == 777 end
    C_Map.GetWorldPosFromMapPos = function() return 1, { x = 777, y = 0 } end
    C_Map.SetUserWaypoint = function() error("restricted") end
    assert(nav.Start(action)); noPosition()
    nav.Stop(); assert(clears == 0)
end)
check("Throwing TomTom falls back to owned native waypoint", function()
    TomTom = tomtom({ AddWaypoint = function() error("TomTom unavailable") end })
    assert(nav.Start(action) and nativeCalls == 1)
    nav.Stop(); assert(clears == 1)
end)
check("Missing or malformed TomTom identity falls back without removing foreign waypoints", function()
    for _, uid in ipairs({ false, true, "", 0, math.huge }) do
        local removed = 0
        TomTom = tomtom({ AddWaypoint = function() return uid end, RemoveWaypoint = function() removed = removed + 1 end })
        assert(nav.Start(action)); nav.Stop(); assert(removed == 0)
    end
    assert(nativeCalls == 5)
end)
check("Valid TomTom identity uses only its original owner for cleanup", function()
    local uid, removed, foreign = {}, 0, 0
    TomTom = tomtom({ AddWaypoint = function() return uid end,
        RemoveWaypoint = function(_, removedUID) assert(removedUID == uid); removed = removed + 1 end })
    assert(nav.Start(action) and nativeCalls == 0)
    TomTom = tomtom({ RemoveWaypoint = function() foreign = foreign + 1 end })
    nav.Stop(); nav.Stop(); assert(removed == 1 and foreign == 0)
end)
check("Cleanup preserves a native waypoint moved by the player", function()
    assert(nav.Start(action) and nativeCalls == 1)
    current = { uiMapID = 1, position = { x = 0.2, y = 0.3 } }
    nav.Stop(); assert(clears == 0)
end)
check("Starting a guide preserves an existing manual native waypoint", function()
    current = { uiMapID = 2, position = { x = 0.25, y = 0.35 } }
    local manual = current
    assert(nav.Start(action))
    assert(current == manual and nativeCalls == 0)
    nav.Stop(); assert(current == manual and clears == 0)
end)
check("Replacing a guide preserves a native waypoint moved by the player", function()
    assert(nav.Start(action) and nativeCalls == 1)
    current = { uiMapID = 2, position = { x = 0.25, y = 0.35 } }
    local manual = current
    assert(nav.Start({ id = 2, kind = "visit", place = point }))
    assert(current == manual and nativeCalls == 1 and clears == 0)
    nav.Stop(); assert(current == manual and clears == 0)
end)
check("Unknown native waypoint ownership keeps the internal guide without setting a pin", function()
    local secret = {}
    for _, getter in ipairs({ false, function() error("unavailable") end, function() return secret end }) do
        C_Map.GetUserWaypoint = getter
        issecretvalue = function(value) return value == secret end
        assert(nav.Start(action) and nativeCalls == 0)
        nav.Stop(); assert(clears == 0)
    end
end)
check("Quest cancellation preserves a nearby but different player waypoint", function()
    assert(nav.Start(action))
    current = { uiMapID = 1, position = { x = point.x / 100 + 0.000005, y = point.y / 100 } }
    local playerPin = current
    nav.QuestChanged(999); assert(clears == 0)
    nav.QuestChanged(action.id)
    assert(clears == 0 and current == playerPin)
end)
check("Reentrant cleanup cannot remove the same TomTom waypoint twice", function()
    local removed = 0
    TomTom = tomtom({ AddWaypoint = function() return 123 end, RemoveWaypoint = function()
        removed = removed + 1
        if removed == 1 then nav.Stop() end
    end })
    assert(nav.Start(action)); nav.Stop()
    assert(removed == 1)
end)
check("A replacement guide started by cleanup retains its owner and stays visible", function()
    local nextUID, removed = 0, {}
    TomTom = tomtom({ AddWaypoint = function() nextUID = nextUID + 1; return nextUID end,
        RemoveWaypoint = function(_, uid)
            removed[#removed + 1] = uid
            if uid == 1 then assert(nav.Start({ id = 2, kind = "visit", place = point })) end
        end })
    assert(nav.Start(action)); nav.Stop()
    local shown = false
    for _, frame in ipairs(frames) do if frame.shown and frame.scripts.OnUpdate then shown = true end end
    assert(shown and #removed == 1)
    nav.QuestChanged(2)
    assert(#removed == 2 and removed[2] == 2)
end)
check("An older Start cannot overwrite a replacement requested during cleanup", function()
    local nextUID, removed = 0, {}
    TomTom = tomtom({ AddWaypoint = function() nextUID = nextUID + 1; return nextUID end,
        RemoveWaypoint = function(_, uid)
            removed[#removed + 1] = uid
            if uid == 1 then assert(nav.Start({ id = 3, kind = "visit", place = point })) end
        end })
    assert(nav.Start(action))
    assert(not nav.Start({ id = 2, kind = "visit", place = point }))
    assert(nextUID == 2)
    nav.QuestChanged(2); assert(#removed == 1)
    nav.QuestChanged(3); assert(#removed == 2 and removed[2] == 2)
end)
check("Existing matching player waypoint is never claimed or supertracked", function()
    local tracked = 0
    current = { uiMapID = 1, position = { x = point.x / 100, y = point.y / 100 } }
    local playerPin = current
    C_Map.SetUserWaypoint = function() nativeCalls = nativeCalls + 1; return false end
    C_SuperTrack = { SetSuperTrackedUserWaypoint = function() tracked = tracked + 1 end }
    assert(nav.Start(action) and nativeCalls == 0)
    nav.Stop()
    assert(clears == 0 and current == playerPin and tracked == 0)
end)
check("Rejected native waypoint setter never claims ownership", function()
    local tracked = 0
    C_Map.SetUserWaypoint = function() nativeCalls = nativeCalls + 1; return false end
    C_SuperTrack = { SetSuperTrackedUserWaypoint = function() tracked = tracked + 1 end }
    assert(nav.Start(action) and nativeCalls == 1)
    nav.Stop(); assert(clears == 0 and tracked == 0)
end)
check("A replacement guide started by waypoint inspection keeps its ownership", function()
    local inspecting = false
    C_Map.GetUserWaypoint = function()
        if not inspecting then
            inspecting = true
            assert(nav.Start({ id = 2, kind = "visit", place = point }))
        end
        return current
    end
    assert(not nav.Start(action) and nativeCalls == 1)
    nav.QuestChanged(1); assert(clears == 0)
    nav.QuestChanged(2); assert(clears == 1)
end)
check("Malformed world vectors and field access failures become position unknown", function()
    for _, value in ipairs({ false, true, 1, "bad", {}, setmetatable({}, { __index = function() error("unreadable") end }) }) do
        C_Map.GetWorldPosFromMapPos = function() return 1, value end
        assert(nav.Start(action)); noPosition()
    end
end)
check("Native vector userdata is accepted and failing userdata indexing is rejected", function()
    local vector = newproxy(true)
    getmetatable(vector).__index = { x = 100, y = 200 }
    C_Map.GetWorldPosFromMapPos = function() return 1, vector end
    local north, west = nav.Vector(point)
    assert(north == 0 and west == 0)
    getmetatable(vector).__index = function() error("unreadable vector") end
    assert(nav.Start(action)); noPosition()
end)
check("Nonfinite or overflowing world coordinates cannot reach HUD arithmetic", function()
    for _, value in ipairs({ math.huge, -math.huge, 0 / 0 }) do
        C_Map.GetWorldPosFromMapPos = function() return 1, { x = value, y = 0 } end
        assert(nav.Start(action)); noPosition()
    end
    local calls = 0
    C_Map.GetWorldPosFromMapPos = function()
        calls = calls + 1; return 1, { x = calls % 2 == 1 and -1e308 or 1e308, y = 0 }
    end
    assert(nav.Start(action)); noPosition()
    C_Map.GetWorldPosFromMapPos = function(_, p) return 1, { x = p.x * 1e200, y = p.y * 1e200 } end
    assert(nav.Start(action)); noPosition()
end)
check("Invalid destinations preserve existing guide ownership", function()
    assert(nav.Start(action))
    assert(not nav.Start({ id = 2, place = { mapID = 1, x = math.huge, y = 10 } }))
    assert(nativeCalls == 1 and clears == 0)
    nav.Stop(); assert(clears == 1)
end)
check("TomTom replacement during AddWaypoint cleans only the actual creator", function()
    local ownRemoved, foreignRemoved = 0, 0
    local foreign = { RemoveWaypoint = function() foreignRemoved = foreignRemoved + 1 end }
    local original = tomtom({ AddWaypoint = function() TomTom = foreign; return 901 end,
        RemoveWaypoint = function(_, uid) assert(uid == 901); ownRemoved = ownRemoved + 1 end })
    TomTom = original
    assert(nav.Start(action) and nativeCalls == 0); nav.Stop()
    assert(ownRemoved == 1 and foreignRemoved == 0)
end)
check("A guide superseded during AddWaypoint releases only its stale returned identity", function()
    local calls, removed = 0, {}
    TomTom = tomtom({ AddWaypoint = function()
        calls = calls + 1; local uid = calls
        if uid == 1 then assert(nav.Start({ id = 2, kind = "visit", place = point })) end
        return uid
    end, RemoveWaypoint = function(_, uid) removed[#removed + 1] = uid end })
    assert(not nav.Start(action) and nativeCalls == 0)
    assert(#removed == 1 and removed[1] == 1)
    nav.QuestChanged(1); assert(#removed == 1)
    nav.QuestChanged(2); assert(#removed == 2 and removed[2] == 2)
end)
check("A replacement using the same TomTom identity is not removed as stale", function()
    local calls, removed = 0, 0
    local uid = {}
    TomTom = tomtom({ AddWaypoint = function()
        calls = calls + 1
        if calls == 1 then assert(nav.Start({ id = 2, kind = "visit", place = point })) end
        return uid
    end, RemoveWaypoint = function(_, identity) assert(rawequal(identity, uid)); removed = removed + 1 end })
    assert(not nav.Start(action) and calls == 2 and removed == 0)
    nav.QuestChanged(2); assert(removed == 1)
end)
check("Same action reused by a callback still creates a distinct navigation generation", function()
    local calls, removed = 0, {}
    TomTom = tomtom({ AddWaypoint = function()
        calls = calls + 1; local uid = calls
        if uid == 1 then assert(nav.Start(action)) end
        return uid
    end, RemoveWaypoint = function(_, uid) removed[#removed + 1] = uid end })
    assert(not nav.Start(action) and calls == 2 and #removed == 1 and removed[1] == 1)
    nav.QuestChanged(1); assert(#removed == 2 and removed[2] == 2)
end)
check("Stale waypoint cleanup may start another guide without corrupting its ownership", function()
    local calls, removed = 0, {}
    TomTom = tomtom({ AddWaypoint = function()
        calls = calls + 1; local uid = calls
        if uid == 1 then assert(nav.Start({ id = 2, kind = "visit", place = point })) end
        return uid
    end, RemoveWaypoint = function(_, uid)
        removed[#removed + 1] = uid
        if uid == 1 then assert(nav.Start({ id = 3, kind = "visit", place = point })) end
    end })
    assert(not nav.Start(action) and calls == 3)
    assert(#removed == 2 and removed[1] == 1 and removed[2] == 2)
    nav.QuestChanged(2); assert(#removed == 2)
    nav.QuestChanged(3); assert(#removed == 3 and removed[3] == 3)
end)
check("Stopping during AddWaypoint does not resurrect the old frame or claim its returned identity", function()
    local removed = 0
    TomTom = tomtom({ AddWaypoint = function() nav.Stop(); return 901 end,
        RemoveWaypoint = function(_, uid) assert(uid == 901); removed = removed + 1 end })
    assert(not nav.Start(action) and removed == 1 and nativeCalls == 0)
    for _, item in ipairs(frames) do if item.scripts.OnUpdate then assert(not item.shown) end end
    nav.Stop(); assert(removed == 1)
end)
check("Stop cannot clear a replacement native point created during its ownership inspection", function()
    assert(nav.Start(action) and nativeCalls == 1)
    local inspecting = false
    C_Map.GetUserWaypoint = function()
        if not inspecting then
            inspecting = true; current = nil
            assert(nav.Start({ id = 2, kind = "visit", place = point }))
        end
        return current
    end
    nav.Stop()
    assert(nativeCalls == 2 and clears == 0 and current ~= nil)
    local shown = false
    for _, item in ipairs(frames) do if item.shown and item.scripts.OnUpdate then shown = true end end
    assert(shown)
    nav.QuestChanged(2); assert(clears == 1 and current == nil)
end)
check("CanSet cancellation prevents native point creation and guide resurrection", function()
    C_Map.CanSetUserWaypointOnMap = function() nav.Stop(); return true end
    assert(not nav.Start(action) and nativeCalls == 0)
    for _, item in ipairs(frames) do if item.scripts.OnUpdate then assert(not item.shown) end end
end)
check("Native constructor supersession cannot overwrite a newer guide point", function()
    local original, entered = UiMapPoint.CreateFromCoordinates, false
    UiMapPoint.CreateFromCoordinates = function(mapID, x, y)
        if not entered then entered = true; assert(nav.Start({ id = 2, place = { mapID = 2, x = 30, y = 40 } })) end
        return original(mapID, x, y)
    end
    assert(not nav.Start(action) and nativeCalls == 1 and current.uiMapID == 2)
    nav.QuestChanged(1); assert(clears == 0)
    nav.QuestChanged(2); assert(clears == 1)
end)
check("A manual waypoint appearing during construction is never overwritten or owned", function()
    local original = UiMapPoint.CreateFromCoordinates
    local manual = { uiMapID = 2, position = { x = 0.15, y = 0.25 } }
    UiMapPoint.CreateFromCoordinates = function(mapID, x, y)
        current = manual; return original(mapID, x, y)
    end
    assert(nav.Start(action) and nativeCalls == 0 and current == manual)
    nav.Stop(); assert(clears == 0 and current == manual)
end)
check("Cancellation during a successful setter cleans only its exact stale point", function()
    C_Map.SetUserWaypoint = function(p)
        nativeCalls = nativeCalls + 1; current = p; nav.Stop(); return true
    end
    assert(not nav.Start(action) and nativeCalls == 1 and current == nil and clears == 1)
    for _, item in ipairs(frames) do if item.scripts.OnUpdate then assert(not item.shown) end end
    nav.Stop(); assert(clears == 1)
end)
check("Supersession inside the setter preserves a newer owned matching native point", function()
    local entered = false
    C_Map.SetUserWaypoint = function(p)
        nativeCalls = nativeCalls + 1; current = p
        if not entered then
            entered = true; current = nil
            assert(nav.Start({ id = 2, place = point }))
        end
        return true
    end
    assert(not nav.Start(action) and nativeCalls == 2 and current ~= nil and clears == 0)
    nav.QuestChanged(2); assert(clears == 1 and current == nil)
end)
check("Stale native setter cleanup preserves a different player pin", function()
    local manual = { uiMapID = 2, position = { x = 0.15, y = 0.25 } }
    C_Map.SetUserWaypoint = function()
        nativeCalls = nativeCalls + 1; nav.Stop(); current = manual; return true
    end
    assert(not nav.Start(action) and current == manual and clears == 0)
    nav.Stop(); assert(current == manual and clears == 0)
end)
check("Supertracking supersession stops the old map and frame path", function()
    local entered, maps = false, {}
    C_SuperTrack = { SetSuperTrackedUserWaypoint = function()
        if not entered then entered = true; assert(nav.Start({ id = 2, place = { mapID = 2, x = 30, y = 40 } })) end
    end }
    C_Map.OpenWorldMap = function(mapID) maps[#maps + 1] = mapID end
    assert(not nav.Start(action) and current.uiMapID == 2 and #maps == 1 and maps[1] == 2)
    nav.QuestChanged(2); assert(current == nil)
end)
check("Map-open cancellation and player-facing cancellation return without stale HUD writes", function()
    C_Map.OpenWorldMap = function() nav.Stop() end
    assert(not nav.Start(action))
    for _, item in ipairs(frames) do if item.scripts.OnUpdate then assert(not item.shown) end end
    C_Map.OpenWorldMap = function() error("cancelled request must not open map") end
    GetPlayerFacing = function() nav.Stop(); return 0 end
    local ok, started = pcall(nav.Start, action)
    assert(ok and started == false)
    for _, item in ipairs(frames) do if item.scripts.OnUpdate then assert(not item.shown) end end
end)
check("Stale native cleanup inspection cannot clear a guide created by its callback", function()
    local reads, replacing = 0, false
    C_Map.GetUserWaypoint = function()
        reads = reads + 1
        if reads == 3 and not replacing then
            replacing = true; current = nil
            assert(nav.Start({ id = 2, place = point }))
        end
        return current
    end
    C_Map.SetUserWaypoint = function(p)
        nativeCalls = nativeCalls + 1; current = p
        if not replacing then nav.Stop() end
        return true
    end
    assert(not nav.Start(action) and replacing and nativeCalls == 2 and current ~= nil and clears == 0)
    nav.QuestChanged(2); assert(clears == 1 and current == nil)
end)
check("A title refresh starting another guide cannot overwrite the newer HUD label", function()
    local questName, entered = addon.QuestName, false
    addon.QuestName = function(id)
        if id == 1 and not entered then entered = true; assert(nav.Start({ id = 2, place = point })) end
        return "Quest " .. id
    end
    assert(not nav.Start(action))
    local shown = false
    for _, item in ipairs(frames) do if item.shown and item.scripts.OnUpdate then
        assert(item.title.text == "Quest 2"); shown = true
    end end
    assert(shown)
    addon.QuestName = questName
end)
check("Cleanup cannot clear a different map namespace installed during ownership inspection", function()
    assert(nav.Start(action))
    local owned = current
    local manual = { uiMapID = 2, position = { x = 0.2, y = 0.3 } }
    C_Map.GetUserWaypoint = function()
        current = manual
        C_Map = { GetUserWaypoint = function() return manual end,
            ClearUserWaypoint = function() clears = clears + 1; current = nil end }
        return owned
    end
    nav.Stop()
    assert(clears == 0 and current == manual, "old ownership result must not authorize a new namespace clear")
end)
check("Cleanup cannot use a replaced getter or clearer after reading an old owned point", function()
    for _, changed in ipairs({ "getter", "clearer" }) do
        reset(); assert(nav.Start(action))
        local owned = current
        local manual = { uiMapID = 2, position = { x = 0.2, y = 0.3 } }
        C_Map.GetUserWaypoint = function()
            current = manual
            if changed == "getter" then C_Map.GetUserWaypoint = function() return manual end
            else C_Map.ClearUserWaypoint = function() clears = clears + 1; current = nil end end
            return owned
        end
        nav.Stop()
        assert(clears == 0 and current == manual, changed .. " drift must preserve replacement point")
    end
end)
check("A map capability change during the final empty check cannot overwrite a manual pin", function()
    local reads, map = 0, C_Map
    local manual = { uiMapID = 2, position = { x = 0.2, y = 0.3 } }
    map.GetUserWaypoint = function()
        reads = reads + 1
        if reads == 2 then
            local replacement = {}; for key, value in pairs(map) do replacement[key] = value end
            replacement.GetUserWaypoint = function() return manual end
            C_Map, current = replacement, manual
        end
        return nil
    end
    assert(nav.Start(action))
    assert(nativeCalls == 0 and current == manual, "a stale empty result cannot authorize a new native setter")
    nav.Stop(); assert(clears == 0 and current == manual)
end)
check("Changing the final getter or setter in place preserves a newly installed manual point", function()
    for _, field in ipairs({ "GetUserWaypoint", "SetUserWaypoint" }) do
        reset()
        local reads = 0
        local manual = { uiMapID = 2, position = { x = 0.2, y = 0.3 } }
        C_Map.GetUserWaypoint = function()
            reads = reads + 1
            if reads == 2 then
                current = manual
                if field == "GetUserWaypoint" then C_Map.GetUserWaypoint = function() return manual end
                else C_Map.SetUserWaypoint = function(p) nativeCalls = nativeCalls + 1; current = p; return true end end
            end
            return nil
        end
        assert(nav.Start(action) and nativeCalls == 0 and current == manual)
        nav.Stop(); assert(clears == 0 and current == manual)
    end
end)
check("Restricted destination changes during native reads never reach coordinate arithmetic", function()
    local restricted, reads = {}, 0
    local destination = { mapID = 1, x = 60, y = 70 }
    issecretvalue = function(value) return value == restricted end
    C_Map.GetUserWaypoint = function()
        reads = reads + 1
        if reads == 2 then destination.x = restricted end
        return nil
    end
    assert(nav.Start({ id = 2, place = destination }) and nativeCalls == 0)
    noPosition(); nav.Stop(); assert(clears == 0)
end)
local function hud()
    for _,item in ipairs(frames) do if item.shown and item.scripts.OnUpdate then return item end end
    error("No current guide")
end
check("Guide context shows the exact giver and zone even when bearing is unavailable", function()
    local p={mapID=1,x=60,y=70,npcID=99,name="Recorded giver",zoneName="Recorded zone"}
    addon.GiverName=function(place) assert(place==p);return "Live giver" end
    C_Map.GetMapInfo=function(id) assert(id==1);return {name="Client zone"} end
    GetPlayerFacing=function() return nil end
    assert(nav.Start({id=1,place=p}))
    local card=hud()
    assert(card.skinned and card.title.text=="Quest" and card.note.text=="Live giver · Client zone")
    assert(card.label.text=="NO_POSITION" and not card.arrow.shown)
    assert(card.scripts.OnDragStart==card.StartMoving and card.scripts.OnDragStop==card.StopMovingOrSizing)
end)
check("Guide presentation refreshes context sparingly and never retains changed source names", function()
    local p={mapID=1,x=60,y=70,name="Source giver",zoneName="Source zone"}
    local names,maps=0,0
    addon.GiverName=function() names=names+1;return nil end
    C_Map.GetMapInfo=function() maps=maps+1;return nil end
    assert(nav.Start({id=1,place=p}));local card=hud()
    assert(card.note.text=="Source giver · Source zone" and names==1 and maps==1)
    for tick=1,4 do card.scripts.OnUpdate(card,0.1) end
    assert(names==1 and maps==1)
    p.name="Changed giver";card.scripts.OnUpdate(card,0.1)
    assert(card.note.text=="Changed giver · Source zone" and names==2)
    GetLocale=function() return "ruRU" end
    card.scripts.OnUpdate(card,1.1);assert(names==3)
end)
check("Guide wraps long text grows its themed surface and shrinks cleanly on replacement", function()
    local styles=0
    addon.Theme={StyleRow=function(card,options) assert(options.kind=="section");styles=styles+1;return true end}
    assert(nav.Start({id=1,place={mapID=1,x=60,y=70,name="A long giver",zoneName="A long zone"}}))
    local card=hud()
    card.title.measured,card.note.measured,card.label.measured=90,60,36
    card.scripts.OnUpdate(card,0.1)
    assert(card.height==220 and card.note.point[3]==-107 and card.label.point[3]==-172)
    card.title.measured,card.note.measured,card.label.measured=nil,nil,nil
    assert(nav.Start(action));assert(hud()==card and card.note.text=="" and card.height==88)
    assert(styles==0,"reused HUD retains its original skin without repeated theme allocation")
end)
check("Guide context getters cannot publish a mutated destination or cancel a newer guide", function()
    local p={mapID=1,x=60,y=70,name="Old giver",zoneName="Old zone"}
    local a={id=1,place=p};local armed=true
    addon.GiverName=function()
        if armed then armed=false;a.place={mapID=1,x=60,y=70,name="New giver",zoneName="New zone"} end
        return "Obsolete giver"
    end
    assert(nav.Start(a));local card=hud();assert(card.note.text=="")
    addon.GiverName=nil;card.scripts.OnUpdate(card,0.1)
    assert(card.note.text=="New giver · New zone")
    armed=true
    addon.GiverName=function()
        if armed then armed=false;nav.Stop() end
        return "Detached giver"
    end
    assert(not nav.Start(a) and not card.shown)
end)
check("Guide rejects source identity and locale mutation inside a contextual name read", function()
    for _,field in ipairs({"name","mapID","x","npcID","locale"}) do
        local p={mapID=1,x=60,y=70,npcID=99,name="Recorded",zoneName="Zone"}
        local locale="enUS";GetLocale=function() return locale end
        local armed=true
        addon.GiverName=function()
            if armed then
                armed=false
                if field=="locale" then locale="ruRU"
                elseif field=="name" then p.name="Changed"
                else p[field]=2 end
            end
            return "Detached native giver"
        end
        assert(nav.Start({id=1,place=p}));assert(hud().note.text=="",field)
        addon.GiverName=nil;hud().scripts.OnUpdate(hud(),0.1)
        assert(hud().note.text==(field=="name" and "Changed · Zone" or "Recorded · Zone"),field)
        nav.Stop()
    end
end)
check("Guide ignores malformed native names and unclean geometry while retaining close ownership", function()
    local restricted={};issecretvalue=function(value) return value==restricted end
    addon.GiverName=function() return restricted end
    C_Map.GetMapInfo=function() return {name=restricted} end
    assert(nav.Start({id=1,place={mapID=1,x=60,y=70,name="Source",zoneName="Zone"}}))
    local card=hud();assert(card.note.text=="Source · Zone")
    for _,value in ipairs({restricted,math.huge,-1,0}) do
        card.title.measured=value;card.scripts.OnUpdate(card,0.1)
        assert(card.height==92)
    end
    card.title.measured=nil
    local found=false
    for _,part in ipairs(frames) do
        if part.scripts.OnClick==nav.Stop then part.scripts.OnClick(part,"LeftButton",false);found=true;break end
    end
    assert(found and not card.shown and current==nil)
end)
check("A saved guide tick after Stop stays quiet and cannot rewrite hidden presentation",function()
    assert(nav.Start(action));local card=hud()
    local tick,title,note,status,height=card.scripts.OnUpdate,card.title.text,card.note.text,card.label.text,card.height
    nav.Stop()
    local calls=0
    addon.QuestName=function()calls=calls+1;error("stopped context must not read titles")end
    tick(card,0.2)
    assert(not card.shown and calls==0 and card.title.text==title and card.note.text==note and card.label.text==status and card.height==height)
    addon.QuestName=function()return "Quest"end
end)
check("Bearing rejects destination changes during native player-map reads", function()
    for _, stage in ipairs({ "GetBestMapForUnit", "GetPlayerMapPosition", "GetWorldPosFromMapPos" }) do
        reset()
        local p={mapID=1,x=60,y=70}
        local getter=C_Map[stage]
        C_Map[stage]=function(...)
            local a,b=getter(...)
            p.x=80
            return a,b
        end
        local north,west=nav.Vector(p)
        assert(north==nil and west==nil, stage .. " cannot mix a changed destination into an old read")
    end
end)
check("Bearing rejects replaced native namespaces getters and constructors", function()
    for _, field in ipairs({ "namespace", "GetPlayerMapPosition", "GetWorldPosFromMapPos", "constructor", "checker" }) do
        reset()
        local map=C_Map;local best=map.GetBestMapForUnit
        map.GetBestMapForUnit=function(...)
            if field=="namespace" then
                local replacement={};for key,value in pairs(map)do replacement[key]=value end;C_Map=replacement
            elseif field=="constructor" then CreateVector2D=function(x,y)return {x=x,y=y}end
            elseif field=="checker" then issecretvalue=function()return false end
            else
                local old=map[field];map[field]=function(...)return old(...)end
            end
            return best(...)
        end
        local north,west=nav.Vector({mapID=1,x=60,y=70})
        assert(north==nil and west==nil, field .. " identity drift must discard bearing")
    end
end)
check("Bearing cannot retain a same-action destination detached during vector construction", function()
    local p={mapID=1,x=60,y=70};local a={id=1,place=p}
    assert(nav.Start(a));local card=hud()
    local old=CreateVector2D;local armed=true
    CreateVector2D=function(x,y)
        if armed then armed=false;a.place={mapID=1,x=30,y=20}end
        return old(x,y)
    end
    card.scripts.OnUpdate(card,0.2)
    assert(card.label.text=="NO_POSITION" and not card.arrow.shown,
        "same-action place replacement must not display the old bearing")
    card.scripts.OnUpdate(card,0.2)
    assert(card.arrow.shown,"the next detached read recovers for the new destination")
end)
check("Bearing discards drift during both constructors positions and world-field reads", function()
    for _,stage in ipairs({"position", "constructor1", "constructor2", "conversion2", "fields"}) do
        reset()
        local p={mapID=1,x=60,y=70};local restricted={}
        issecretvalue=function(value)return value==restricted end
        if stage=="position" then
            C_Map.GetPlayerMapPosition=function()
                return {GetXY=function()p.mapID=2;return .5,.5 end}
            end
        elseif stage:find("constructor",1,true) then
            local old,count=CreateVector2D,0
            CreateVector2D=function(x,y)
                count=count+1
                if count==(stage=="constructor1" and 1 or 2) then p.y=restricted end
                return old(x,y)
            end
        else
            local old,count=C_Map.GetWorldPosFromMapPos,0
            C_Map.GetWorldPosFromMapPos=function(...)
                count=count+1;local map,world=old(...)
                if count==2 then
                    if stage=="conversion2" then C_Map.GetBestMapForUnit=function()return 1 end
                    else
                        world=setmetatable({y=world.y},{__index=function(_,key)
                            if key=="x" then p.x=80;return 700 end
                        end})
                    end
                end
                return map,world
            end
        end
        local ok,north,west=pcall(nav.Vector,p)
        assert(ok and north==nil and west==nil,stage)
    end
end)
check("Stable bearing retains exact orientation and direct-call behavior",function()
    local north,west=nav.Vector({mapID=1,x=60,y=70})
    assert(north==200 and west==100)
    assert(nav.Start(action))
    north,west=nav.Vector({mapID=1,x=30,y=20})
    assert(north==-300 and west==-200,"an independent direct point is not bound to the guide's destination")
end)
check("Unreadable player-position methods quietly discard the bearing",function()
    C_Map.GetPlayerMapPosition=function()
        return setmetatable({},{__index=function()error("unavailable method")end})
    end
    assert(nav.Vector(point)==nil)
    for _,value in ipairs({true,12,"invalid"})do
        C_Map=value
        assert(nav.Vector(point)==nil)
    end
end)
check("Guide uses the shared readable family and real font height with a safe native-template fallback",function()
    local theme,chat=addon.Theme,ChatFontNormal
    nav.Stop();ChatFontNormal={untouched=true}
    methods.SetFontObject=function(self,font)self.family=font end
    methods.SetFontHeight=function(self,height)self.fontHeight=height end
    methods.SetShadowOffset=function(self,x,y)self.shadow={x,y}end
    methods.SetTextHeight=function()error("guide must not scale rasterized text")end
    assert(loadfile("UI/Theme.lua"))("DungeonPro",addon)
    assert(loadfile("UI/Navigation.lua"))("DungeonPro",addon)
    local fresh=addon.Navigation;assert(fresh.Start(action));local card=hud()
    assert(card.title.family==ChatFontNormal and card.title.fontHeight==16 and card.note.fontHeight==14 and card.label.fontHeight==14)
    assert(card.title.shadow[1]==0 and card.title.shadow[2]==0 and ChatFontNormal.untouched and not ChatFontNormal.fontHeight)
    fresh.Stop();addon.Theme=nil
    assert(loadfile("UI/Navigation.lua"))("DungeonPro",addon)
    fresh=addon.Navigation;assert(fresh.Start(action));card=hud()
    assert(card.title.template=="ChatFontNormal" and card.note.template=="ChatFontNormal")
    fresh.Stop();addon.Navigation=nav;addon.Theme,ChatFontNormal=theme,chat
    methods.SetFontObject,methods.SetFontHeight,methods.SetShadowOffset,methods.SetTextHeight=nil,nil,nil,nil
end)
check("Presentation text setters preserve a replacement guide before and after their original write",function()
    local questName=addon.QuestName
    addon.QuestName=function(id)return "Quest "..id end
    addon.GiverName=function(place)return place.name end
    for _,part in ipairs({"title","note","label"})do
        for _,phase in ipairs({"before","after"})do
            local first={id=101,place={mapID=1,x=60,y=70,name="Old giver"}}
            local nextAction={id=202,place={mapID=1,x=30,y=20,name="New giver"}}
            assert(nav.Start(first));local card=hud()
            local region,armed,snapshot=card[part],true
            local original=region.SetText
            region.SetText=function(self,value)
                local function replace()
                    if armed then
                        armed=false;assert(nav.Start(nextAction))
                        snapshot={card.title.text,card.note.text,card.label.text,card.height}
                    end
                end
                if phase=="before"then replace()end
                original(self,value)
                if phase=="after"then replace()end
            end
            card.scripts.OnUpdate(card,0.2)
            region.SetText=nil
            assert(snapshot and card.title.text==snapshot[1] and card.note.text==snapshot[2] and
                card.label.text==snapshot[3] and card.height==snapshot[4],part.." "..phase)
            assert(card.title.text=="Quest 202" and card.note.text:find("New giver",1,true))
        end
    end
    addon.QuestName=questName
end)
check("Presentation geometry setters cannot resume over a replacement guide layout",function()
    for _,part in ipairs({"note","label","frame"})do
        local setters=part=="frame"and {"SetHeight"}or {"ClearAllPoints","SetPoint"}
        for _,setter in ipairs(setters)do
            for _,phase in ipairs({"before","after"})do
                assert(nav.Start(action));local card=hud()
                local region=part=="frame"and card or card[part]
                local original,armed,snapshot=region[setter],true
                region[setter]=function(self,...)
                    local function replace()
                        if armed then
                            armed=false;card.title.measured=80;card.note.measured=50;card.label.measured=30
                            assert(nav.Start({id=202,place={mapID=1,x=30,y=20,name="New giver"}}))
                            snapshot={card.note.point[3],card.label.point[3],card.height}
                        end
                    end
                    if phase=="before"then replace()end
                    original(self,...)
                    if phase=="after"then replace()end
                end
                card.scripts.OnUpdate(card,0.2)
                region[setter]=nil
                assert(snapshot and card.note.point[3]==snapshot[1] and card.label.point[3]==snapshot[2] and
                    card.height==snapshot[3],part.." "..setter.." "..phase)
                card.title.measured,card.note.measured,card.label.measured=nil,nil,nil
            end
        end
    end
end)
check("Presentation cancellation during text or measurement cannot publish later fields",function()
    for _,stage in ipairs({"text","measurement"})do
        assert(nav.Start(action));local card=hud()
        local setter=stage=="text"and "SetText"or "GetStringHeight"
        local original,armed,writes=card.title[setter],true,0
        local noteSetter=card.note.SetText
        card.note.SetText=function(self,value)writes=writes+1;noteSetter(self,value)end
        card.title[setter]=function(self,...)
            local result=original(self,...)
            if armed then armed=false;nav.Stop()end
            return result
        end
        card.scripts.OnUpdate(card,0.2)
        card.title[setter],card.note.SetText=nil,nil
        assert(not card.shown and writes==(stage=="text"and 0 or 1),stage)
        local title,note,status=card.title.text,card.note.text,card.label.text
        card.scripts.OnUpdate(card,0.2)
        assert(not card.shown and title==card.title.text and note==card.note.text and status==card.label.text)
    end
end)
check("A nested tick of the same guide owns its newer status and measurement",function()
    assert(nav.Start(action));local card=hud()
    local original,armed,snapshot=card.title.SetText,true
    card.title.SetText=function(self,value)
        if armed then
            armed=false;card.title.measured=75
            GetPlayerFacing=function()return nil end
            card.scripts.OnUpdate(card,0.2)
            snapshot={card.label.text,card.height}
        end
        original(self,value)
    end
    card.scripts.OnUpdate(card,0.2)
    card.title.SetText=nil;card.title.measured=nil
    assert(snapshot and snapshot[1]=="NO_POSITION" and card.label.text==snapshot[1] and card.height==snapshot[2])
end)
check("Map identities must be exact positive integers before native or guide dispatch", function()
    local opened = {}
    C_Map.OpenWorldMap = function(id) opened[#opened + 1] = id end
    for _, id in ipairs({ 1.5, 0, -1, 9007199254740992, math.huge, -math.huge, 0 / 0 }) do
        local invalid = { mapID = id, x = 20, y = 30 }
        assert(not nav.Valid(invalid) and not nav.Map(invalid) and not nav.Start({ id = 1, place = invalid }))
    end
    assert(#opened == 0 and nativeCalls == 0)
    for _, xy in ipairs({ 0, 100 }) do
        assert(nav.Valid({ mapID = 1, x = xy, y = xy }))
    end
    assert(nav.Map({ mapID = 1 }) and opened[1] == 1)
end)
check("Map dispatch uses the validated map identity snapshot", function()
    local reads, opened = 0
    local changing = setmetatable({}, { __index = function(_, key)
        if key == "mapID" then reads = reads + 1; return reads == 1 and 1 or 1.5 end
    end })
    C_Map.OpenWorldMap = function(id) opened = id end
    assert(nav.Map(changing) and opened == 1 and reads == 1)
end)
check("Old waypoint cleanup cannot authorize a newly invalid destination", function()
    local nextPoint, added = { mapID = 1, x = 20, y = 30 }, 0
    TomTom = tomtom({ AddWaypoint = function() added = added + 1; return "owned" end,
        RemoveWaypoint = function() nextPoint.mapID = 1.5 end })
    assert(nav.Start(action) and added == 1)
    assert(not nav.Start({ id = 2, kind = "visit", place = nextPoint }))
    assert(added == 1 and nativeCalls == 0)
end)
check("Show cancellation cannot resurrect a stopped navigation HUD", function()
    assert(nav.Start(action))
    local card = hud()
    nav.Stop()
    local original, armed = card.Show, true
    card.Show = function(self)
        if armed then armed = false; nav.Stop() end
        return original(self)
    end
    local before = clears
    local started = nav.Start(action)
    card.Show = original
    assert(not started and not card.shown)
    assert(current == nil and clears == before + 1)
end)
check("Old Show cannot overwrite a replacement guide", function()
    assert(nav.Start(action))
    local card = hud()
    nav.Stop()
    local original, armed = card.Show, true
    card.Show = function(self)
        if armed then armed = false; assert(nav.Start({ id = 2, place = point })) end
        return original(self)
    end
    assert(not nav.Start(action))
    card.Show = original
    assert(card.shown)
    local before = clears
    nav.QuestChanged(1)
    assert(clears == before and card.shown)
    nav.QuestChanged(2)
    assert(not card.shown)
end)
check("Old Hide cannot suppress a replacement started by its wrapper", function()
    assert(nav.Start(action))
    local card = hud()
    local original, armed = card.Hide, true
    card.Hide = function(self)
        if armed then armed = false; assert(nav.Start({ id = 2, place = point })) end
        return original(self)
    end
    nav.Stop()
    card.Hide = original
    assert(card.shown)
    nav.QuestChanged(1)
    assert(card.shown)
    nav.QuestChanged(2)
    assert(not card.shown)
end)
check("A replacement guide borrowing the old TomTom identity keeps its HUD without adopting cleanup", function()
    local removed = 0
    TomTom = tomtom({ AddWaypoint = function() return "same" end,
        RemoveWaypoint = function() removed = removed + 1 end })
    assert(nav.Start(action))
    local card = hud()
    local original, armed = card.Hide, true
    card.Hide = function(self)
        if armed then armed = false; assert(nav.Start({ id = 2, place = point })) end
        return original(self)
    end
    nav.Stop()
    card.Hide = original
    assert(card.shown and removed == 1)
    nav.QuestChanged(2)
    assert(removed == 1 and not card.shown)
end)
check("Hide replacement releases only the old distinct TomTom identity", function()
    local nextUID, removed = 0, {}
    TomTom = tomtom({ AddWaypoint = function() nextUID = nextUID + 1; return nextUID end,
        RemoveWaypoint = function(_, uid) removed[#removed + 1] = uid end })
    assert(nav.Start(action))
    local card = hud()
    local original, armed = card.Hide, true
    card.Hide = function(self)
        if armed then armed = false; assert(nav.Start({ id = 2, place = point })) end
        return original(self)
    end
    nav.Stop()
    card.Hide = original
    assert(card.shown and #removed == 1 and removed[1] == 1)
    nav.QuestChanged(1)
    assert(#removed == 1 and card.shown)
    nav.QuestChanged(2)
    assert(#removed == 2 and removed[2] == 2 and not card.shown)
end)
check("Movable HUD requests screen clamping and retains it when the same guide frame is reused",function()
    assert(nav.Start(action))
    local card=hud()
    assert(card.clamped==true,"movable guide must request native screen clamping")
    assert(card.scripts.OnDragStart==card.StartMoving and card.scripts.OnDragStop==card.StopMovingOrSizing)
    nav.Stop();assert(not card.shown)
    assert(nav.Start(action) and hud()==card and card.clamped==true)
end)
check("Absent optional HUD clamp capability preserves existing guide and close behavior",function()
    local first=#frames
    local setter=methods.SetClampedToScreen
    methods.SetClampedToScreen=nil
    local fresh={};assert(loadfile("Core/Namespace.lua"))("DungeonPro",fresh)
    fresh.L,fresh.QuestName,fresh.Theme=addon.L,addon.QuestName,addon.Theme
    assert(loadfile("UI/Navigation.lua"))("DungeonPro",fresh)
    assert(fresh.Navigation.Start(action))
    local card
    for index=first+1,#frames do if frames[index].scripts.OnUpdate then card=frames[index];break end end
    assert(card and card.shown and card.clamped==nil)
    local close
    for index=first+1,#frames do if frames[index].scripts.OnClick==fresh.Navigation.Stop then close=frames[index]end end
    assert(close);close.scripts.OnClick();assert(not card.shown)
    methods.SetClampedToScreen=setter
end)
local function geometryFixture()
    nav.Start(action)
    local hud
    for _, candidate in ipairs(frames) do if candidate.scripts.OnUpdate then hud=candidate;break end end
    local oldUI,oldWorld=addon.UI,WorldMapFrame
    local planner,world=object(),object()
    addon.UI={frame=planner,quest=1,dungeon={},engine={},rewardGeneration={}}
    WorldMapFrame=world
    local owners={hud,planner,world};local saved,calls={},{}
    for _,owner in ipairs(owners)do
        saved[owner]={};calls[owner]={}
        for name,value in pairs({IsShown=true,IsVisible=false,GetFrameStrata="DIALOG",GetFrameLevel=5,
            GetEffectiveScale=0.75,GetLeft=12,GetBottom=24,GetWidth=354,GetHeight=104})do
            saved[owner][name]=rawget(owner,name)
            local key,result=name,value
            owner[key]=function(self,...)
                assert(select("#",...)==0)
                calls[self][key]=(calls[self][key]or 0)+1
                return result
            end
        end
    end
    return {hud=hud,planner=planner,world=world,calls=calls,finish=function()
        for _,owner in ipairs(owners)do
            for _,name in ipairs({"IsShown","IsVisible","GetFrameStrata","GetFrameLevel","GetEffectiveScale","GetLeft","GetBottom","GetWidth","GetHeight"})do
                owner[name]=saved[owner][name]
            end
        end
        addon.UI,WorldMapFrame=oldUI,oldWorld
    end}
end
check("Geometry probe reads only three fixed existing frame roles once without actions or saved data",function()
    local f=geometryFixture();local char,db={},{};addon.char,addon.db=char,db
    local before=#frames;local mapCalls=0;C_Map.OpenWorldMap=function()mapCalls=mapCalls+1 end
    local result=nav.ProbeGeometry()
    assert(result.status=="known"and #frames==before and mapCalls==0 and next(char)==nil and next(db)==nil)
    local count=0
    for _,role in ipairs({"hud","planner","worldMap"})do
        local value=result.frames[role]
        assert(value.status=="known"and value.shown==true and value.visible==false and value.strata=="DIALOG"and
            value.level==5 and value.scale==0.75 and value.left==12 and value.bottom==24 and value.width==354 and value.height==104)
    end
    for _,calls in pairs(f.calls)do for _,value in pairs(calls)do assert(value==1);count=count+value end end
    assert(count==27);f.finish();addon.char=nil
end)
check("Geometry probe keeps missing roots and unavailable individual getters unknown",function()
    local f=geometryFixture();WorldMapFrame=nil;f.planner.GetWidth=false;f.planner.GetLeft=function()error("unavailable")end
    local result=nav.ProbeGeometry()
    assert(result.status=="known"and result.frames.worldMap.status=="unknown"and result.frames.planner.width==nil and
        result.frames.planner.left==nil and result.frames.planner.height==104)
    f.finish()
end)
check("Geometry probe omits restricted nonfinite and invalid primitive geometry",function()
    local f=geometryFixture();local restricted={}
    issecretvalue=function(value)return value==restricted end
    f.hud.GetLeft=function()return restricted end
    f.hud.GetBottom=function()return 0/0 end
    f.hud.GetWidth=function()return math.huge end
    f.hud.GetHeight=function()return -1 end
    f.hud.GetFrameLevel=function()return 1.5 end
    f.hud.GetEffectiveScale=function()return 0 end
    f.hud.GetFrameStrata=function()return "private arbitrary text"end
    local result=nav.ProbeGeometry();local value=result.frames.hud
    assert(result.status=="known"and value.shown==true and value.left==nil and value.bottom==nil and value.width==nil and
        value.height==nil and value.level==nil and value.scale==nil and value.strata==nil)
    f.finish()
end)
check("Geometry probe rejects root card navigation locale helper and getter replacements as a whole",function()
    for _,kind in ipairs({"ui","world","card","navigation","locale","checker","clean","read","getter"})do
        local f=geometryFixture();local clean,read,checker,locale=addon.Clean,addon.Read,issecretvalue,GetLocale
        local ui,world=addon.UI,WorldMapFrame;local armed=true
        f.world.GetHeight=function()
            if armed then
                armed=false
                if kind=="ui"then addon.UI={}
                elseif kind=="world"then WorldMapFrame={}
                elseif kind=="card"then ui.rewardGeneration={}
                elseif kind=="navigation"then nav.Stop()
                elseif kind=="locale"then GetLocale=function()return "ruRU"end
                elseif kind=="checker"then issecretvalue=function()return false end
                elseif kind=="clean"then addon.Clean=function(...)return clean(...)end
                elseif kind=="read"then addon.Read=function(...)return read(...)end
                else f.hud.GetLeft=function()return 999 end end
            end
            return 104
        end
        local result=nav.ProbeGeometry()
        assert(not armed and result.status=="unknown"and result.frames.hud.left==nil and result.frames.planner.width==nil)
        addon.Clean,addon.Read,issecretvalue,GetLocale=clean,read,checker,locale
        addon.UI,WorldMapFrame=ui,world;f.finish()
    end
end)

check("Geometry probe pins later getters before reading and checks locale callbacks before final getter ownership",function()
    for _,kind in ipairs({"earlierGeometry","locale"})do
        local f=geometryFixture();local locale=GetLocale
        if kind=="earlierGeometry"then
            f.hud.GetLeft=function()f.world.GetHeight=function()return 999 end;return 12 end
        else
            local calls=0
            GetLocale=function()
                calls=calls+1
                if calls==2 then f.hud.GetLeft=function()return 999 end end
                return "enUS"
            end
        end
        local result=nav.ProbeGeometry()
        assert(result.status=="unknown"and result.frames.worldMap.height==nil)
        GetLocale=locale;f.finish()
    end
end)

check("Geometry probe rejects an earlier getter replaced by a later final checker callback",function()
    local f=geometryFixture();local sampled,calls=false,0
    local watched=function()sampled=true;return 104 end
    f.world.GetHeight=watched
    issecretvalue=function(value)
        if sampled and value==watched then
            calls=calls+1
            if calls==1 then f.hud.GetLeft=function()return 999 end end
        end
        return false
    end
    local result=nav.ProbeGeometry()
    assert(calls>=1 and result.status=="unknown"and result.frames.hud.left==nil)
    f.finish()
end)

check("Guide close styling is optional and preserves its exact Stop handler and owned HUD",function()
    for _,mode in ipairs({"style","false","throw","missing"})do
        local fresh={};assert(loadfile("Core/Namespace.lua"))("DungeonPro",fresh)
        fresh.L,fresh.QuestName=addon.L,addon.QuestName
        local calls,close=0,nil;fresh.Theme={}
        if mode~="missing"then fresh.Theme.StyleCloseButton=function(button)
            calls=calls+1;close=button
            assert(button.width==22 and button.height==22 and button.point[1]=="TOPRIGHT"and button.scripts.OnClick==fresh.Navigation.Stop)
            if mode=="throw"then error("optional style unavailable")end
            return mode=="style"
        end end
        local first=#frames;assert(loadfile("UI/Navigation.lua"))("DungeonPro",fresh)
        assert(fresh.Navigation.Start(action))
        local card
        for index=first+1,#frames do
            if frames[index].scripts.OnUpdate then card=frames[index]end
            if frames[index].scripts.OnClick==fresh.Navigation.Stop then close=frames[index]end
        end
        assert(card and card.shown and close and calls==(mode=="missing"and 0 or 1))
        assert(close.scripts.OnClick==fresh.Navigation.Stop)
        close.scripts.OnClick();assert(not card.shown)
    end
end)

local function layerFixture()
    local ui,combat,strataSetter,levelSetter=addon.UI,InCombatLockdown,methods.SetFrameStrata,methods.SetFrameLevel
    local f={level=40,strataCalls=0,levelCalls=0,reads=0}
    f.planner={GetHighestFrameLevel=function(_,allChildren)assert(allChildren==true);f.reads=f.reads+1;return f.level end}
    addon.UI={frame=f.planner};InCombatLockdown=function()return false end
    methods.SetFrameStrata=function(self,value)f.strataCalls=f.strataCalls+1;assert(value=="DIALOG");if f.strataThrows then error("restricted")end;self.layerStrata=value end
    methods.SetFrameLevel=function(self,value)f.levelCalls=f.levelCalls+1;if f.levelThrows then error("restricted")end;self.layerLevel=value end
    f.finish=function()addon.UI,InCombatLockdown,methods.SetFrameStrata,methods.SetFrameLevel=ui,combat,strataSetter,levelSetter end
    return f
end
check("Guide explicitly layers above the current owned planner subtree on every start",function()
    local f=layerFixture();assert(nav.Start(action));local card=hud()
    assert(card.layerStrata=="DIALOG"and card.layerLevel==41 and f.strataCalls==1 and f.levelCalls==1 and f.reads==1)
    addon.UI.frame={GetHighestFrameLevel=function(_,allChildren)assert(allChildren==true);return 83 end}
    assert(nav.Start(action)and hud()==card and card.layerLevel==84 and f.strataCalls==2 and f.levelCalls==2)
    nav.Stop();f.finish()
end)
check("Unknown and out-of-policy planner levels never drive a numeric raise",function()
    for _,kind in ipairs({"missing","restricted","negative","fractional","nan","infinite","aboveCap","throw","frameReplacement","getterReplacement"})do
        local f=layerFixture();local token={}
        if kind=="missing"then f.planner.GetHighestFrameLevel=nil
        elseif kind=="restricted"then f.level=token;issecretvalue=function(v)return v==token end
        elseif kind=="negative"then f.level=-1
        elseif kind=="fractional"then f.level=1.5
        elseif kind=="nan"then f.level=0/0
        elseif kind=="infinite"then f.level=math.huge
        elseif kind=="aboveCap"then f.level=100001
        elseif kind=="throw"then f.planner.GetHighestFrameLevel=function()error("unavailable")end
        elseif kind=="frameReplacement"then f.planner.GetHighestFrameLevel=function()addon.UI.frame={};return 40 end
        else f.planner.GetHighestFrameLevel=function()f.planner.GetHighestFrameLevel=function()return 40 end;return 40 end end
        assert(nav.Start(action)and hud().layerStrata=="DIALOG"and f.levelCalls==0)
        nav.Stop();issecretvalue=nil;f.finish()
    end
    for _,level in ipairs({0,100000})do
        local f=layerFixture();f.level=level;assert(nav.Start(action)and hud().layerLevel==level+1);nav.Stop();f.finish()
    end
end)
check("Guide layer mutations require clean out-of-combat state and recheck it after planner reads",function()
    for _,kind in ipairs({"combat","missing","throw","restricted","entered","getterChanged"})do
        local f=layerFixture();local token={}
        if kind=="combat"then InCombatLockdown=function()return true end
        elseif kind=="missing"then InCombatLockdown=nil
        elseif kind=="throw"then InCombatLockdown=function()error("unavailable")end
        elseif kind=="restricted"then InCombatLockdown=function()return token end;issecretvalue=function(v)return v==token end
        else f.planner.GetHighestFrameLevel=function()
            if kind=="entered"then InCombatLockdown=function()return true end
            else InCombatLockdown=function()return false end end
            return 40
        end end
        assert(nav.Start(action)and f.levelCalls==0)
        assert(f.strataCalls==((kind=="entered"or kind=="getterChanged")and 1 or 0))
        nav.Stop();issecretvalue=nil;f.finish()
    end
end)
check("Failed optional layer setters retain the existing live guide",function()
    local f=layerFixture();f.strataThrows,f.levelThrows=true,true
    assert(nav.Start(action)and hud().shown and f.strataCalls==1 and f.levelCalls==1)
    nav.Stop();f.finish()
end)
check("Planner-layer callbacks cannot resurrect a canceled guide or suppress its replacement",function()
    local f=layerFixture();f.planner.GetHighestFrameLevel=function()nav.Stop();return 40 end
    assert(nav.Start(action)==false)
    for _,frame in ipairs(frames)do if frame.scripts.OnUpdate then assert(not frame.shown)end end
    f.finish()
    f=layerFixture();local armed=true;local newer={id=2,kind="visit",place={mapID=1,x=30,y=40}}
    f.planner.GetHighestFrameLevel=function()
        if armed then armed=false;assert(nav.Start(newer))end
        return 40
    end
    assert(nav.Start(action)==false and not armed and hud().shown)
    nav.QuestChanged(1);assert(hud().shown)
    nav.QuestChanged(2);for _,frame in ipairs(frames)do if frame.scripts.OnUpdate then assert(not frame.shown)end end
    f.finish()
end)

check("Geometry probe samples only the shown world map raw ID without player fallback or extra getters",function()
    local f=geometryFixture();local mapUtil,unit=MapUtil,UnitGUID
    local effects=0;local function forbidden()effects=effects+1;error("no player or map fallback reads")end
    f.world.mapID=1436;f.hud.mapID=999;f.planner.mapID=998
    f.world.GetMapID=forbidden;MapUtil={GetDisplayableMapForPlayer=forbidden};UnitGUID=forbidden
    C_Map.GetBestMapForUnit=forbidden
    local result=nav.ProbeGeometry()
    assert(result.status=="known"and result.frames.worldMap.displayedMapID==1436)
    assert(result.frames.hud.displayedMapID==nil and result.frames.planner.displayedMapID==nil and effects==0)
    local calls=0;for _,getters in pairs(f.calls)do for _,count in pairs(getters)do assert(count==1);calls=calls+count end end
    assert(calls==27)
    MapUtil,UnitGUID=mapUtil,unit;f.finish()
end)
check("Displayed map ID remains optional for hidden missing userdata restricted and invalid state",function()
    for _,kind in ipairs({"missing","hidden","unknownShown","userdata","zero","negative","fraction","infinite","nan","large","string","restricted","maximum"})do
        local f=geometryFixture();local restricted={};f.world.mapID=1436
        if kind=="missing"then f.world.mapID=nil
        elseif kind=="hidden"then f.world.IsShown=function()return false end
        elseif kind=="unknownShown"then f.world.IsShown=function()return nil end
        elseif kind=="userdata"then local proxy=newproxy(true);getmetatable(proxy).__index=f.world;WorldMapFrame=proxy
        elseif kind=="zero"then f.world.mapID=0
        elseif kind=="negative"then f.world.mapID=-1
        elseif kind=="fraction"then f.world.mapID=1.5
        elseif kind=="infinite"then f.world.mapID=math.huge
        elseif kind=="nan"then f.world.mapID=0/0
        elseif kind=="large"then f.world.mapID=9007199254740992
        elseif kind=="string"then f.world.mapID="1436"
        elseif kind=="restricted"then f.world.mapID=restricted;issecretvalue=function(v)return v==restricted end
        else f.world.mapID=9007199254740991 end
        local result=nav.ProbeGeometry()
        assert(result.status=="known",kind)
        assert(result.frames.worldMap.displayedMapID==(kind=="maximum"and 9007199254740991 or nil),kind)
        f.finish()
    end
end)
check("Displayed map ID binding expires after geometry or final-checker replacement",function()
    for _,kind in ipairs({"geometry","checker"})do
        local f=geometryFixture();f.world.mapID=1436;local sampled=false
        local watched=function()sampled=true;if kind=="geometry"then f.world.mapID=1453 end;return 104 end
        f.world.GetHeight=watched
        if kind=="checker"then issecretvalue=function(v)if sampled and v==watched then f.world.mapID=1453 end;return false end end
        local result=nav.ProbeGeometry()
        assert(result.status=="unknown"and result.frames.worldMap.displayedMapID==nil,kind)
        f.finish()
    end
end)

check("Entrance navigation uses dungeon title and survives unrelated quest changes", function()
    local d = {key = "deadmines", name = "Deadmines"}
    local previous = addon.DungeonName
    addon.DungeonName = function(value) assert(value == d); return "Deadmines" end
    local calls = 0
    local oldQuestName = addon.QuestName
    addon.QuestName = function() calls = calls + 1; error("entrance has no quest") end
    local title
    TomTom = tomtom({ AddWaypoint = function(_, _, _, _, options) title = options.title; return "entry" end })
    assert(nav.StartEntrance(d, point) and title == "Deadmines")
    local hud
    for _, f in ipairs(frames) do if f.shown and f.scripts.OnUpdate then hud = f end end
    assert(hud and hud.title.text == "Deadmines" and calls == 0)
    nav.QuestChanged(1); assert(hud.shown)
    nav.Stop(); assert(not hud.shown)
    addon.QuestName, addon.DungeonName = oldQuestName, previous
end)
check("Missing or invalid entrance does not cancel an existing quest guide", function()
    assert(nav.Start(action))
    local calls = nativeCalls
    assert(not nav.StartEntrance({key = "unknown"}, {mapID = 1, x = -1, y = 50}))
    assert(not nav.StartEntrance({}, point))
    assert(nativeCalls == calls)
    nav.QuestChanged(1)
    for _, f in ipairs(frames) do if f.scripts.OnUpdate then assert(not f.shown) end end
end)

check("Entrance title callbacks cannot dispatch an obsolete guide after cancellation", function()
    local old = addon.DungeonName
    local calls = 0
    TomTom = tomtom({AddWaypoint = function() calls = calls + 1; return "old" end})
    addon.DungeonName = function() nav.Stop(); return "Old entrance" end
    assert(not nav.StartEntrance({key = "old"}, point) and calls == 0 and nativeCalls == 0)
    addon.DungeonName = old
end)
check("Entrance resolver supplies coordinates without a fabricated quest identity", function()
    local previous, getter = addon.Entrances, addon.DungeonName
    local dungeon = {key = "resolved"}
    addon.DungeonName = function(value) assert(value == dungeon); return "Resolved dungeon" end
    addon.Entrances = {Get = function(value) assert(value == dungeon); return point end}
    assert(nav.StartEntrance(dungeon) and nativeCalls == 1)
    addon.Entrances, addon.DungeonName = previous, getter
end)

check("Entrance title callback cannot send a destination it invalidated to TomTom", function()
    local previous = addon.DungeonName
    local mutable = {mapID = 1, x = 50, y = 60}
    local calls = 0
    addon.DungeonName = function() mutable.x = "invalid"; return "Entrance" end
    TomTom = tomtom({AddWaypoint = function() calls = calls + 1; return "invalid" end})
    assert(not nav.StartEntrance({key = "changed"}, mutable) and calls == 0)
    addon.DungeonName = previous
end)

check("A successful native setter cannot orphan its pin after changing the source coordinates", function()
    for _, field in ipairs({ "mapID", "x", "y" }) do
        reset()
        local mutable = { mapID = 1, x = 60, y = 70 }
        C_Map.SetUserWaypoint = function(p)
            nativeCalls = nativeCalls + 1; current = p
            mutable[field] = mutable[field] + 1
            return true
        end
        assert(nav.Start({ id = 99, kind = "visit", place = mutable }))
        assert(nativeCalls == 1 and clears == 1 and current == nil)
        nav.Stop(); assert(clears == 1)
    end
end)
check("Rejected native ownership cleanup preserves a newer manual pin or guide", function()
    for _, replacement in ipairs({ "manual", "guide" }) do
        reset()
        local mutable = { mapID = 1, x = 60, y = 70 }
        local manual = { uiMapID = 2, position = { x = .1, y = .2 } }
        C_Map.SetUserWaypoint = function(p)
            nativeCalls = nativeCalls + 1; current = p; mutable.x = 61
            if replacement == "manual" then current = manual end
            return true
        end
        local getter, entered = C_Map.GetUserWaypoint, false
        if replacement == "guide" then
            C_Map.GetUserWaypoint = function()
                if nativeCalls == 1 and not entered then
                    entered = true; current = nil
                    assert(nav.Start({ id = 100, kind = "visit", place = point }))
                end
                return getter()
            end
        end
        local started = nav.Start({ id = 99, kind = "visit", place = mutable })
        if replacement == "manual" then
            assert(started and current == manual and clears == 0)
            nav.Stop(); assert(current == manual and clears == 0)
        else
            assert(not started and entered and nativeCalls == 2 and clears == 0 and current)
            nav.QuestChanged(99); assert(clears == 0 and current)
            nav.QuestChanged(100); assert(clears == 1 and current == nil)
        end
    end
end)
check("Float32 native coordinate readback still identifies the old owned route pin during replacement", function()
    C_Map.SetUserWaypoint = function(p)
        nativeCalls = nativeCalls + 1
        if nativeCalls == 1 then
            current = { uiMapID = p.uiMapID, position = { x = .2750000059604645, y = .47999998927116394 } }
        else current = p end
        return true
    end
    local first = { mapID = 1, x = 27.5, y = 48 }
    local second = { mapID = 2, x = 25, y = 35 }
    assert(nav.Start({ id = 201, kind = "visit", place = first }) and nativeCalls == 1 and current.uiMapID == 1)
    assert(nav.Start({ id = 202, kind = "visit", place = second }))
    assert(nativeCalls == 2 and clears == 1 and current.uiMapID == 2 and current.position.x == .25 and current.position.y == .35,
        "float32 readback must not orphan a successful old pin and block its replacement")
    nav.Stop(); assert(clears == 2 and current == nil)
    nav.Stop(); assert(clears == 2)
end)
check("Nearby manual pins outside native float precision remain untouched", function()
    for _, point in ipairs({{uiMapID=1,position={x=.275001,y=.48}},
        {uiMapID=1,position={x=.275,y=.480001}}, {uiMapID=2,position={x=.275,y=.48}}})do
        reset()
        assert(nav.Start({ id = 201, kind = "visit", place = {mapID=1,x=27.5,y=48} }))
        current=point
        assert(nav.Start({id=202,kind="visit",place={mapID=2,x=25,y=35}}))
        nav.Stop();assert(nativeCalls==1 and clears==0 and current==point,
            "coordinate tolerance must not clear a distinct manual location or map")
    end
end)
check("Explicitly false or throwing native setters never gain ownership from a matching readback", function()
    for _, failure in ipairs({ "false", "throw" }) do
        reset()
        C_Map.SetUserWaypoint = function(p)
            nativeCalls = nativeCalls + 1; current = p
            if failure == "throw" then error("setter failed") end
            return false
        end
        assert(nav.Start(action) and nativeCalls == 1 and current)
        nav.Stop(); assert(clears == 0 and current, "a failure signal must not authorize native pin cleanup")
    end
end)
check("Repeated same-map and cross-map routes release rounded owned pins and Stop clears the final pin", function()
    C_Map.SetUserWaypoint = function(p)
        nativeCalls=nativeCalls+1
        current={uiMapID=p.uiMapID,position={x=p.position.x+.00000000596,y=p.position.y-.00000001073}}
        return true
    end
    local places={{mapID=1,x=27.5,y=48},{mapID=1,x=31.2,y=52.7},{mapID=2,x=25,y=35},{mapID=1,x=60,y=70}}
    for index,place in ipairs(places)do
        assert(nav.Start({id=210+index,kind="visit",place=place}))
        assert(nativeCalls==index and clears==index-1 and current.uiMapID==place.mapID)
    end
    nav.Stop();assert(clears==#places and current==nil)
    nav.Stop();assert(clears==#places)
end)
check("Late arrow setters cannot overwrite a replacement guide bearing or visibility",function()
    for _,method in ipairs({"SetRotation","Show","Hide"})do
        assert(nav.Start(action));local card=hud();local arrow=card.arrow
        local setter,armed,snapshot=arrow[method],true
        arrow[method]=function(self,...)
            if armed then
                armed=false
                GetPlayerFacing=function()return method=="Show"and nil or 1 end
                assert(nav.Start({id=888,place={mapID=1,x=20,y=30}}))
                snapshot={rotation=arrow.rotation,shown=arrow.shown}
            end
            return setter(self,...)
        end
        if method=="Hide"then GetPlayerFacing=function()return nil end end
        card.scripts.OnUpdate(card,.2)
        arrow[method]=nil
        assert(snapshot and arrow.rotation==snapshot.rotation and arrow.shown==snapshot.shown,method)
        nav.Stop();GetPlayerFacing=function()return 0 end
    end
end)
check("A nested update of the same guide retains its newer arrow bearing",function()
    assert(nav.Start(action));local card=hud();local arrow=card.arrow
    local setter,armed,snapshot=arrow.SetRotation,true
    arrow.SetRotation=function(self,...)
        if armed then
            armed=false;GetPlayerFacing=function()return 1 end
            card.scripts.OnUpdate(card,.2);snapshot=arrow.rotation
        end
        return setter(self,...)
    end
    card.scripts.OnUpdate(card,.2);arrow.SetRotation=nil
    assert(snapshot and arrow.rotation==snapshot)
end)
check("Invalid elapsed values cannot poison navigation ticking or query positions",function()
    assert(nav.Start(action));local card=hud();local reads=0
    local getter=C_Map.GetBestMapForUnit
    C_Map.GetBestMapForUnit=function(...)reads=reads+1;return getter(...)end
    local secret={};issecretvalue=function(value)return value==secret end
    for _,delta in ipairs({"bad",-1,0/0,math.huge,secret})do card.scripts.OnUpdate(card,delta)end
    assert(reads==0)
    card.scripts.OnUpdate(card,.2);assert(reads==1 and card.arrow.shown)
end)
check("Stationary guide skips repeated text measurement and layout while live bearing remains current",function()
    local oldText,oldFont,oldWidth,oldScale=methods.GetText,methods.GetFont,methods.GetWidth,methods.GetEffectiveScale
    methods.GetText=function(self)return self.text end
    methods.GetFont=function(self)return "Fonts\\ARIALN.TTF",self.fontSize or 14,""end
    methods.GetWidth=function(self)return self.width or 258 end
    methods.GetEffectiveScale=function(self)return self.scale or 1 end
    assert(nav.Start(action));local card=hud()
    local writes,measures,anchors,rotations,positions=0,0,0,0,0
    local saved={}
    for _,region in ipairs({card.title,card.note,card.label})do
        saved[region]={SetText=region.SetText,GetStringHeight=region.GetStringHeight,SetPoint=region.SetPoint}
        region.SetText=function(self,...)writes=writes+1;return saved[self].SetText(self,...)end
        region.GetStringHeight=function(self,...)measures=measures+1;return saved[self].GetStringHeight(self,...)end
        region.SetPoint=function(self,...)anchors=anchors+1;return saved[self].SetPoint(self,...)end
    end
    local rotate,locate=card.arrow.SetRotation,C_Map.GetPlayerMapPosition
    card.arrow.SetRotation=function(self,...)rotations=rotations+1;return rotate(self,...)end
    C_Map.GetPlayerMapPosition=function(...)positions=positions+1;return locate(...)end
    -- Establish signatures for the instrumented measurement methods themselves.
    card.scripts.OnUpdate(card,.1);writes,measures,anchors,rotations,positions=0,0,0,0,0
    for _=1,600 do card.scripts.OnUpdate(card,.1)end
    assert(writes==0 and measures==0 and anchors==0,"unchanged values do not require another native text/layout write")
    assert(rotations==600 and positions==600,"bearing keeps its live position and facing cadence")
    C_Map.GetPlayerMapPosition=function()return {GetXY=function()return .4,.3 end}end
    card.scripts.OnUpdate(card,.1);assert(writes==1 and measures==1,"changed distance is repainted and measured")
    card.title.fontSize,card.title.measured,card.title.text=18,36,""
    card.scripts.OnUpdate(card,.1)
    assert(card.title.text=="Quest"and measures==2 and anchors>=2,"font resets restore title and invalidate layout")
    card.note.scale=2;card.scripts.OnUpdate(card,.1);assert(measures==3,"scale change invalidates measurement")
    card.title.width=200;card.scripts.OnUpdate(card,.1);assert(measures==4,"width change invalidates wrapping")
    local originalPoint,armed,snapshot=card.note.SetPoint,true
    card.note.SetPoint=function(self,...)
        if armed then
            armed=false;card.title.measured=80
            assert(nav.Start({id=902,place={mapID=1,x=20,y=30}}));snapshot=card.note.point[3]
        end
        return originalPoint(self,...)
    end
    card.title.fontSize,card.title.measured=22,54
    card.scripts.OnUpdate(card,.1)
    assert(snapshot and card.note.point[3]==snapshot and snapshot==-97,"cached geometry repairs a newer guide after a late old anchor write")
    for region,values in pairs(saved)do region.SetText,region.GetStringHeight,region.SetPoint=nil,nil,nil end
    card.arrow.SetRotation=nil;card.title.fontSize,card.title.measured,card.note.scale,card.title.width=nil,nil,nil,nil
    methods.GetText,methods.GetFont,methods.GetWidth,methods.GetEffectiveScale=oldText,oldFont,oldWidth,oldScale
end)
check("Transient native clear failure retries only on the next explicit stop", function()
    local original, attempts = C_Map.ClearUserWaypoint, 0
    C_Map.ClearUserWaypoint = function()
        attempts = attempts + 1
        if attempts == 1 then error("temporary cleanup failure") end
        return original()
    end
    assert(nav.Start(action)); nav.Stop()
    assert(current and attempts == 1)
    nav.Stop(); assert(current == nil and attempts == 2)
    nav.Stop(); assert(attempts == 2)
end)
check("Native clear readback wins over false nil and throwing return paths", function()
    for _, mode in ipairs({ "false", "nil", "throw", "noop" }) do
        reset()
        local attempts = 0
        C_Map.ClearUserWaypoint = function()
            attempts = attempts + 1
            if mode == "noop" and attempts == 1 then return end
            current = nil
            if mode == "throw" then error("already cleared") end
            if mode == "false" then return false end
        end
        assert(nav.Start(action)); nav.Stop()
        if mode == "noop" then assert(current and attempts == 1); nav.Stop() end
        assert(current == nil and attempts == (mode == "noop" and 2 or 1))
        local previous = attempts; nav.Stop(); assert(attempts == previous)
    end
end)
check("Persistent native cleanup failure has three actual clear attempts and no tick retries", function()
    local attempts = 0
    C_Map.ClearUserWaypoint = function() attempts = attempts + 1; error("not ready") end
    assert(nav.Start(action)); nav.Stop()
    for _, card in ipairs(frames) do
        if card.scripts.OnUpdate then card.scripts.OnUpdate(card, .1) end
    end
    assert(attempts == 1)
    for _ = 1, 12 do nav.Stop() end
    assert(current and attempts == 3)
end)
check("Temporarily unreadable native cleanup retains dormant identity without clearing unknown points", function()
    for _, phase in ipairs({ "before", "after" }) do
        reset()
        local attempts, unreadable = 0, false
        C_Map.GetUserWaypoint = function() if unreadable then error("read not ready") end; return current end
        C_Map.ClearUserWaypoint = function()
            attempts = attempts + 1
            if attempts == 1 then unreadable = true; return false end
            current = nil
        end
        assert(nav.Start(action))
        if phase == "before" then unreadable = true end
        nav.Stop(); assert(current and attempts == (phase == "before" and 0 or 1))
        nav.Stop(); assert(attempts == (phase == "before" and 0 or 1))
        unreadable = false; nav.Stop()
        if current then unreadable = false; nav.Stop() end
        assert(current == nil and attempts == 2)
    end
end)
check("Pending native cleanup preserves manual replacements and retires changed API authority", function()
    for _, mode in ipairs({ "manual", "getter", "clearer", "owner" }) do
        reset()
        local attempts = 0
        C_Map.ClearUserWaypoint = function() attempts = attempts + 1; return false end
        assert(nav.Start(action)); nav.Stop(); assert(attempts == 1)
        local manual = { uiMapID = 2, position = { x = .12, y = .34 } }
        if mode == "manual" then current = manual
        elseif mode == "getter" then C_Map.GetUserWaypoint = function() return current end
        elseif mode == "clearer" then C_Map.ClearUserWaypoint = function() error("foreign clearer") end
        else local newer = {}; for k, v in pairs(C_Map) do newer[k] = v end; C_Map = newer end
        nav.Stop(); nav.Stop(); assert(attempts == 1)
        if mode == "manual" then assert(current == manual) end
    end
end)
check("Replacing a guide retries the old pin once and preserves the newer cleanup owner", function()
    local original, attempts = C_Map.ClearUserWaypoint, 0
    C_Map.ClearUserWaypoint = function()
        attempts = attempts + 1
        if attempts == 1 then error("temporary") end
        return original()
    end
    assert(nav.Start(action)); nav.Stop(); assert(current and attempts == 1)
    assert(nav.Start({ id = 2, place = { mapID = 2, x = 20, y = 30 } }))
    assert(current and current.uiMapID == 2 and nativeCalls == 2 and attempts == 2)
    nav.Stop(); assert(current == nil and attempts == 3)
end)
check("A reentrant native clear cannot republish stale pending ownership over a newer guide", function()
    local original, attempts = C_Map.ClearUserWaypoint, 0
    C_Map.ClearUserWaypoint = function()
        attempts = attempts + 1
        if attempts == 1 then
            current = nil
            assert(nav.Start({ id = 2, place = { mapID = 2, x = 20, y = 30 } }))
            error("old clear completed late")
        end
        return original()
    end
    assert(nav.Start(action)); nav.Stop()
    assert(current and current.uiMapID == 2 and attempts == 1)
    nav.QuestChanged(1); assert(current and current.uiMapID == 2)
    nav.QuestChanged(2); assert(current == nil and attempts == 2)
    nav.Stop(); assert(attempts == 2)
end)
check("Nested cancellation retains only dormant old pin ownership without taking over another guide", function()
    for _, mode in ipairs({ "empty", "manual", "guide" }) do
        reset()
        local original, attempts = C_Map.ClearUserWaypoint, 0
        local manual = { uiMapID = 2, position = { x = .15, y = .25 } }
        C_Map.ClearUserWaypoint = function()
            attempts = attempts + 1
            if attempts == 1 then
                nav.Stop()
                if mode == "manual" then current = manual end
                if mode == "guide" then assert(nav.Start({ id = 2, place = { mapID = 2, x = 20, y = 30 } })) end
                error("transient clear after nested cancellation")
            end
            return original()
        end
        assert(nav.Start(action)); nav.Stop()
        assert(current and attempts == 1, "nested Stop must not retry recursively")
        nav.Stop()
        if mode == "empty" then assert(current == nil and attempts == 2)
        else assert(current and attempts == 1); if mode == "manual" then assert(current == manual) end end
    end
end)
check("Context map bound rejects 2^53 without native reads and keeps recorded zone", function()
    local HUGE = 9007199254740992
    local p = { mapID = 1, x = 60, y = 70, name = "Recorded giver", zoneName = "Recorded zone" }
    local calls = 0
    C_Map.GetMapInfo = function() calls = calls + 1; return { name = "Client zone" } end
    assert(nav.Start({ id = 1, place = p }))
    local card = hud()
    assert(calls == 1 and card.note.text == "Recorded giver · Client zone")
    calls = 0
    p.mapID = HUGE
    card.scripts.OnUpdate(card, 1.1)
    assert(calls == 0, "huge mapID must not query native info")
    assert(card.note.text == "Recorded giver · Recorded zone")
end)
check("Context map bound keeps 2^53-1 with exactly one native read", function()
    local MAXSAFE = 9007199254740991
    local p = { mapID = MAXSAFE, x = 60, y = 70, name = "Recorded giver", zoneName = "Recorded zone" }
    local calls, seen = 0, nil
    C_Map.GetMapInfo = function(id) calls = calls + 1; seen = id; return { name = "Client zone" } end
    assert(nav.Start({ id = 1, place = p }))
    assert(calls == 1 and seen == MAXSAFE, "boundary mapID needs exactly one native read")
    assert(hud().note.text == "Recorded giver · Client zone")
end)
check("Context map bound rejects zero and fractional without native reads", function()
    for _, bad in ipairs({ 0, 1.5 }) do
        reset()
        local p = { mapID = 1, x = 60, y = 70, name = "Recorded giver", zoneName = "Recorded zone" }
        local calls = 0
        C_Map.GetMapInfo = function() calls = calls + 1; return { name = "Client zone" } end
        assert(nav.Start({ id = 1, place = p }))
        assert(calls == 1)
        calls = 0
        p.mapID = bad
        local card = hud()
        card.scripts.OnUpdate(card, 1.1)
        assert(calls == 0, "mapID " .. tostring(bad) .. " must not query native info")
        assert(card.note.text == "Recorded giver · Recorded zone", "mapID " .. tostring(bad))
    end
end)
check("Hostile non-table namespaces never throw and never claim native ownership", function()
    for _, hostile in ipairs({ 42, true, "hostile", function() end }) do
        reset()
        TomTom, C_Map, UiMapPoint, C_SuperTrack = hostile, hostile, hostile, hostile
        local ok, started = pcall(nav.Start, action)
        assert(ok and started, "hostile namespace must not throw or cancel the guide")
        nav.Stop(); assert(clears == 0 and nativeCalls == 0)
    end
end)
check("Hostile map namespace keeps a TomTom-owned guide without native claims", function()
    TomTom = tomtom({ AddWaypoint = function(self, map, x, y, options)
        return { dungeonProOwner = options.dungeonProOwner }
    end })
    C_Map, UiMapPoint = 42, 42
    local ok, started = pcall(nav.Start, action)
    assert(ok and started and nativeCalls == 0)
    nav.Stop()
end)
check("Hostile __eq metamethods never decide TomTom ownership", function()
    reset()
    local mt = { __eq = function() error("hostile __eq") end }
    local owner = tomtom({ AddWaypoint = function() return "serial" end })
    owner.WaypointExists = function()
        TomTom = setmetatable({}, mt)
        return false
    end
    setmetatable(owner, mt)
    TomTom = owner
    local ok, started = pcall(nav.Start, action)
    assert(ok, "hostile __eq threw during Start")
    assert(started, "guide must start via native fallback")
    nav.Stop()
end)
check("Non-table navigation actions fail closed without throwing", function()
    for _, bad in ipairs({ 5, "visit", true }) do
        local ok, started = pcall(nav.Start, bad)
        assert(ok and started == false, "Start must fail closed for " .. tostring(bad))
    end
    local ok, started = pcall(nav.Start, nil)
    assert(ok and started == false)
    assert(nativeCalls == 0)
end)
check("Throwing guide painters cannot escape the tick", function()
    local cases = {
        { region = "title", setter = "SetText" },
        { region = "note", setter = "SetText" },
        { region = "label", setter = "SetText" },
        { region = "note", setter = "ClearAllPoints" },
        { region = "note", setter = "SetPoint" },
        { region = "label", setter = "SetPoint" },
        { region = "frame", setter = "SetHeight" },
    }
    for _, case in ipairs(cases) do
        reset()
        assert(nav.Start(action))
        local card = hud()
        local region = case.region == "frame" and card or card[case.region]
        region[case.setter] = function() error("painter unavailable") end
        local ok = pcall(card.scripts.OnUpdate, card, 0.2)
        region[case.setter] = nil
        assert(ok, case.region .. "." .. case.setter .. " must not escape the guide tick")
        card.scripts.OnUpdate(card, 0.2)
        assert(card.shown and card.title.text == "Quest", case.region .. "." .. case.setter .. " recovers")
        nav.Stop()
    end
end)
check("Quest detail dispatch rejects non-table actions without throwing", function()
    assert(loadfile("UI/QuestNavigation.lua"))("DungeonPro", addon)
    local ui = addon.QuestNavigation
    local saved = ui.frame
    ui.frame = object()
    local ok, result = pcall(ui.DispatchDetail, ui, 5)
    ui.frame = saved
    assert(ok and result == false, "DispatchDetail must fail closed for a non-table action")
end)
print("Navigation modeled checks passed: " .. total .. " (no native map validation)")
