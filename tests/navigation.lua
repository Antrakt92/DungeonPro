local frames, methods = {}, {}
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetText(value) self.text = value end
function methods:SetHeight(value) self.height = value end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetPoint(...) self.point={...} end
function methods:ClearAllPoints() end
function methods:SetJustifyH() end
function methods:GetStringHeight() return self.measured or 18 end
function methods:SetRotation(value) assert(value == value and value ~= math.huge and value ~= -math.huge) end
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
    TomTom = { AddWaypoint = function() error("TomTom unavailable") end }
    assert(nav.Start(action) and nativeCalls == 1)
    nav.Stop(); assert(clears == 1)
end)
check("Missing or malformed TomTom identity falls back without removing foreign waypoints", function()
    for _, uid in ipairs({ false, true, "", 0, math.huge }) do
        local removed = 0
        TomTom = { AddWaypoint = function() return uid end, RemoveWaypoint = function() removed = removed + 1 end }
        assert(nav.Start(action)); nav.Stop(); assert(removed == 0)
    end
    assert(nativeCalls == 5)
end)
check("Valid TomTom identity uses only its original owner for cleanup", function()
    local uid, removed, foreign = {}, 0, 0
    TomTom = { AddWaypoint = function() return uid end,
        RemoveWaypoint = function(_, removedUID) assert(removedUID == uid); removed = removed + 1 end }
    assert(nav.Start(action) and nativeCalls == 0)
    TomTom = { RemoveWaypoint = function() foreign = foreign + 1 end }
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
    TomTom = { AddWaypoint = function() return 123 end, RemoveWaypoint = function()
        removed = removed + 1
        if removed == 1 then nav.Stop() end
    end }
    assert(nav.Start(action)); nav.Stop()
    assert(removed == 1)
end)
check("A replacement guide started by cleanup retains its owner and stays visible", function()
    local nextUID, removed = 0, {}
    TomTom = { AddWaypoint = function() nextUID = nextUID + 1; return nextUID end,
        RemoveWaypoint = function(_, uid)
            removed[#removed + 1] = uid
            if uid == 1 then assert(nav.Start({ id = 2, kind = "visit", place = point })) end
        end }
    assert(nav.Start(action)); nav.Stop()
    local shown = false
    for _, frame in ipairs(frames) do if frame.shown and frame.scripts.OnUpdate then shown = true end end
    assert(shown and #removed == 1)
    nav.QuestChanged(2)
    assert(#removed == 2 and removed[2] == 2)
end)
check("An older Start cannot overwrite a replacement requested during cleanup", function()
    local nextUID, removed = 0, {}
    TomTom = { AddWaypoint = function() nextUID = nextUID + 1; return nextUID end,
        RemoveWaypoint = function(_, uid)
            removed[#removed + 1] = uid
            if uid == 1 then assert(nav.Start({ id = 3, kind = "visit", place = point })) end
        end }
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
    local original = { AddWaypoint = function() TomTom = foreign; return 901 end,
        RemoveWaypoint = function(_, uid) assert(uid == 901); ownRemoved = ownRemoved + 1 end }
    TomTom = original
    assert(nav.Start(action) and nativeCalls == 0); nav.Stop()
    assert(ownRemoved == 1 and foreignRemoved == 0)
end)
check("A guide superseded during AddWaypoint releases only its stale returned identity", function()
    local calls, removed = 0, {}
    TomTom = { AddWaypoint = function()
        calls = calls + 1; local uid = calls
        if uid == 1 then assert(nav.Start({ id = 2, kind = "visit", place = point })) end
        return uid
    end, RemoveWaypoint = function(_, uid) removed[#removed + 1] = uid end }
    assert(not nav.Start(action) and nativeCalls == 0)
    assert(#removed == 1 and removed[1] == 1)
    nav.QuestChanged(1); assert(#removed == 1)
    nav.QuestChanged(2); assert(#removed == 2 and removed[2] == 2)
end)
check("A replacement using the same TomTom identity is not removed as stale", function()
    local calls, removed = 0, 0
    local uid = {}
    TomTom = { AddWaypoint = function()
        calls = calls + 1
        if calls == 1 then assert(nav.Start({ id = 2, kind = "visit", place = point })) end
        return uid
    end, RemoveWaypoint = function(_, identity) assert(rawequal(identity, uid)); removed = removed + 1 end }
    assert(not nav.Start(action) and calls == 2 and removed == 0)
    nav.QuestChanged(2); assert(removed == 1)
end)
check("Same action reused by a callback still creates a distinct navigation generation", function()
    local calls, removed = 0, {}
    TomTom = { AddWaypoint = function()
        calls = calls + 1; local uid = calls
        if uid == 1 then assert(nav.Start(action)) end
        return uid
    end, RemoveWaypoint = function(_, uid) removed[#removed + 1] = uid end }
    assert(not nav.Start(action) and calls == 2 and #removed == 1 and removed[1] == 1)
    nav.QuestChanged(1); assert(#removed == 2 and removed[2] == 2)
end)
check("Stale waypoint cleanup may start another guide without corrupting its ownership", function()
    local calls, removed = 0, {}
    TomTom = { AddWaypoint = function()
        calls = calls + 1; local uid = calls
        if uid == 1 then assert(nav.Start({ id = 2, kind = "visit", place = point })) end
        return uid
    end, RemoveWaypoint = function(_, uid)
        removed[#removed + 1] = uid
        if uid == 1 then assert(nav.Start({ id = 3, kind = "visit", place = point })) end
    end }
    assert(not nav.Start(action) and calls == 3)
    assert(#removed == 2 and removed[1] == 1 and removed[2] == 2)
    nav.QuestChanged(2); assert(#removed == 2)
    nav.QuestChanged(3); assert(#removed == 3 and removed[3] == 3)
end)
check("Stopping during AddWaypoint does not resurrect the old frame or claim its returned identity", function()
    local removed = 0
    TomTom = { AddWaypoint = function() nav.Stop(); return 901 end,
        RemoveWaypoint = function(_, uid) assert(uid == 901); removed = removed + 1 end }
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
    TomTom = { AddWaypoint = function() added = added + 1; return "owned" end,
        RemoveWaypoint = function() nextPoint.mapID = 1.5 end }
    assert(nav.Start(action) and added == 1)
    assert(not nav.Start({ id = 2, kind = "visit", place = nextPoint }))
    assert(added == 1 and nativeCalls == 0)
end)
print("Navigation modeled checks passed: " .. total .. " (no native map validation)")
