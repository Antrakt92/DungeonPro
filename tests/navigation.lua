local frames, methods = {}, {}
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetText(value) self.text = value end
function methods:SetRotation(value) assert(value == value and value ~= math.huge and value ~= -math.huge) end
for _, name in ipairs({ "SetSize", "SetPoint", "SetMovable", "EnableMouse", "RegisterForDrag", "SetTexture",
    "SetWidth", "StartMoving", "StopMovingOrSizing" }) do methods[name] = function() end end
local function object()
    local result = setmetatable({ scripts = {} }, { __index = methods })
    frames[#frames + 1] = result; return result
end
function methods:CreateTexture() return object() end
function methods:CreateFontString() return object() end
CreateFrame = object
UIParent = object()
local addon = {}
assert(loadfile("Core/Namespace.lua"))("DungeonPrep", addon)
addon.L = function(key) return key end
addon.QuestName = function() return "Quest" end
assert(loadfile("UI/Navigation.lua"))("DungeonPrep", addon)
local nav, total, nativeCalls, clears, current = addon.Navigation, 0
local point = { mapID = 1, x = 60, y = 70 }
local action = { id = 1, kind = "visit", place = point }
local function reset()
    nav.Stop()
    nativeCalls, clears, current = 0, 0, nil
    TomTom, C_SuperTrack, issecretvalue = nil, nil, nil
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
check("Rejected native waypoint never claims an existing matching player pin", function()
    local tracked = 0
    current = { uiMapID = 1, position = { x = point.x / 100, y = point.y / 100 } }
    local playerPin = current
    C_Map.SetUserWaypoint = function() nativeCalls = nativeCalls + 1; return false end
    C_SuperTrack = { SetSuperTrackedUserWaypoint = function() tracked = tracked + 1 end }
    assert(nav.Start(action) and nativeCalls == 1)
    nav.Stop()
    assert(clears == 0 and current == playerPin and tracked == 0)
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
print("Navigation modeled checks passed: " .. total .. " (no native map validation)")
