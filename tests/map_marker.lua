-- Exercise owned map presentation independently of optional player waypoint APIs.
local total = 0
local function fixture()
    local frames, methods, addon = {}, {}, {}
    local function create(kind, _, parent)
        local frame = setmetatable({ kind = kind, parent = parent, scripts = {}, shown = true }, { __index = methods })
        frames[#frames + 1] = frame
        return frame
    end
    function methods:SetScript(event, callback) self.scripts[event] = callback end
    function methods:Show() if self.beforeShow then self.beforeShow() end; self.shown = true end
    function methods:Hide() if self.beforeHide then self.beforeHide() end; self.shown = false end
    function methods:IsShown() return self.shown end
    function methods:SetParent(parent) self.parent = parent end
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:SetScale(scale) self.scale = scale end
    function methods:GetWidth() if self.beforeWidth then self.beforeWidth() end; return self.width or 1000 end
    function methods:GetHeight() return self.height or 500 end
    function methods:ClearAllPoints() self.point = nil end
    function methods:SetPoint(...) if self.beforePoint then self.beforePoint() end; self.point = { ... } end
    function methods:EnableMouse(value) self.mouse = value end
    function methods:CreateTexture() return create("Texture", nil, self) end
    function methods:SetAllPoints(parent) self.anchor = parent end
    function methods:SetTexture(path) self.texture = path end
    function methods:SetAtlas(atlas) self.atlas = atlas end
    function methods:GetAtlas() return self.atlas end
    CreateFrame = create
    UIParent = create("Frame")
    local canvas, map = create("Frame"), create("Frame")
    map.mapID, map.zoom = 1455, 1
    function map:GetMapID() return self.mapID end
    function map:GetCanvas() return canvas end
    function map:GetCanvasScale() return self.zoom end
    WorldMapFrame = map
    local manual = { uiMapID = 99, position = { x = .2, y = .3 } }
    local nativeWrites = 0
    C_Map = {
        OpenWorldMap = function(mapID) map.mapID = mapID; map:Show() end,
        CanSetUserWaypointOnMap = function() return false end,
        GetUserWaypoint = function() return manual end,
        SetUserWaypoint = function() nativeWrites = nativeWrites + 1 end,
        ClearUserWaypoint = function() nativeWrites = nativeWrites + 1 end,
    }
    issecretvalue = function() return false end
    TomTom = nil
    assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
    assert(loadfile("UI/Navigation.lua"))("DungeonPro", addon)
    local function marker()
        for _, frame in ipairs(frames) do if frame.icon then return frame end end
    end
    local function tick()
        for _, frame in ipairs(frames) do
            if frame.shown and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, .1) end
        end
    end
    return addon.Navigation, map, canvas, marker, tick, methods, function() return nativeWrites, manual end
end
local function check(name, fn)
    fn(); total = total + 1; print("PASS " .. name)
end
local destination = { mapID = 1455, x = 32.8, y = 48.6 }
check("Map-only destination shows the Afadra marker without starting a guide or touching manual pins", function()
    local nav, map, canvas, getMarker, tick, _, native = fixture()
    assert(nav.Map(destination))
    local marker = assert(getMarker())
    assert(map.mapID == 1455 and marker.shown and marker.parent == canvas and marker.mouse == false)
    assert(math.abs(marker.point[4] - 328) < .001 and math.abs(marker.point[5] + 243) < .001)
    assert(marker.icon.atlas == "Waypoint-MapPin-Untracked" and marker.width == 30)
    local writes, manual = native(); assert(writes == 0 and manual.uiMapID == 99)
    tick(); nav.Stop(); assert(not marker.shown and native() == 0)
end)
check("Missing waypoint support retains the owned marker", function()
    local nav, _, _, getMarker = fixture()
    C_Map.CanSetUserWaypointOnMap, C_Map.SetUserWaypoint = nil, nil
    assert(nav.Map(destination) and getMarker().shown)
end)
check("Changing displayed map or hiding it hides only the owned marker and returning restores it", function()
    local nav, map, _, getMarker, tick, _, native = fixture()
    assert(nav.Map(destination)); local marker = getMarker()
    map.mapID = 1456; tick(); assert(not marker.shown)
    map.mapID = 1455; tick(); assert(marker.shown)
    map:Hide(); tick(); assert(not marker.shown)
    map:Show(); tick(); assert(marker.shown and native() == 0)
end)
check("Zoom and canvas resizing preserve normalized destination and constant icon size", function()
    local nav, map, canvas, getMarker, tick = fixture()
    assert(nav.Map(destination)); local marker = getMarker()
    map.zoom, canvas.width, canvas.height = 2, 1200, 600
    tick()
    assert(marker.scale == .5 and math.abs(marker.point[4] - 787.2) < .001 and math.abs(marker.point[5] + 583.2) < .001)
end)
check("Map-only unknown coordinates retire the old marker without a player pin mutation", function()
    local nav, _, _, getMarker, _, _, native = fixture()
    assert(nav.Map(destination)); local marker = getMarker()
    assert(nav.Map({ mapID = 1456 }) and not marker.shown and native() == 0)
end)
check("Invalidated source coordinates cannot leave a stale marker or ticker", function()
    local nav, _, _, getMarker, tick = fixture()
    local point = { mapID = 1455, x = 32.8, y = 48.6 }
    assert(nav.Map(point)); local marker = getMarker()
    point.x = -1; tick(); assert(not marker.shown)
    point.x = 32.8; tick(); assert(not marker.shown)
end)
check("A map switch inside canvas geometry cannot show a marker on the wrong map", function()
    local nav, map, canvas, getMarker = fixture()
    canvas.beforeWidth = function() map.mapID = 1456 end
    assert(nav.Map(destination)); assert(not getMarker() or not getMarker().shown)
end)
check("Existing marker hides when a geometry callback changes its displayed map or canvas", function()
    for _, mode in ipairs({ "map", "canvas" }) do
        local nav, map, canvas, getMarker, tick, methods = fixture()
        local selectedCanvas = canvas
        map.GetCanvas = function() return selectedCanvas end
        assert(nav.Map(destination)); local marker = getMarker()
        canvas.beforeWidth = function()
            if mode == "map" then map.mapID = 1456
            else selectedCanvas = setmetatable({ width = 1000, height = 500 }, { __index = methods }) end
        end
        tick(); assert(not marker.shown)
    end
end)
check("Missing restricted malformed or throwing zoom never becomes an assumed scale", function()
    for _, mode in ipairs({ "missing", "nil", "secret", "malformed", "zero", "infinite", "throwing" }) do
        local nav, map, _, getMarker, tick = fixture()
        assert(nav.Map(destination)); local marker = getMarker()
        if mode == "missing" then map.GetCanvasScale = nil
        else map.GetCanvasScale = function()
            if mode == "secret" then return 77 end
            if mode == "malformed" then return "not a zoom" end
            if mode == "zero" then return 0 end
            if mode == "infinite" then return math.huge end
            if mode == "throwing" then error("unavailable zoom") end
        end end
        issecretvalue = function(value) return value == 77 end
        tick(); assert(not marker.shown)
    end
end)
check("Transient map or canvas readback drift hides the marker then recovers on a stable tick", function()
    for _, mode in ipairs({ "map", "canvas" }) do
        local nav, map, canvas, getMarker, tick = fixture()
        assert(nav.Map(destination)); local marker = getMarker()
        local reads = 0
        if mode == "map" then
            map.GetMapID = function(self)
                reads = reads + 1
                return reads == 2 and 1456 or self.mapID
            end
        else
            map.GetCanvas = function()
                reads = reads + 1
                return reads == 2 and {} or canvas
            end
        end
        tick(); assert(not marker.shown)
        tick(); assert(marker.shown and math.abs(marker.point[4] - 328) < .001)
    end
end)
check("A newer map request inside the old anchor setter repairs the late old anchor", function()
    local nav, _, _, getMarker = fixture()
    assert(nav.Map(destination)); local marker = getMarker()
    local entered = false
    marker.beforePoint = function()
        if not entered then entered = true; assert(nav.Map({ mapID = 1455, x = 80, y = 20 })) end
    end
    assert(nav.Map({ mapID = 1455, x = 10, y = 90 }))
    assert(entered and marker.shown and marker.point[4] == 800 and marker.point[5] == -100)
end)
check("A late old Hide cannot hide a replacement marker", function()
    local nav, _, _, getMarker = fixture()
    assert(nav.Map(destination)); local marker, entered = getMarker(), false
    marker.beforeHide = function()
        if not entered then entered = true; assert(nav.Map({ mapID = 1455, x = 80, y = 20 })) end
    end
    nav.Stop()
    assert(entered and marker.shown and marker.point[4] == 800)
end)
check("Missing or rejected atlas retains a visible standard map texture", function()
    for _, mode in ipairs({ "missing", "rejected", "throwing" }) do
        local nav, _, _, getMarker, _, methods = fixture()
        if mode == "missing" then methods.SetAtlas = nil
        else methods.SetAtlas = function(self)
            self.texture, self.atlas = nil, nil
            if mode == "throwing" then error("unsupported atlas") end
        end end
        assert(nav.Map(destination))
        assert(getMarker().shown and getMarker().icon.texture == "Interface\\Icons\\INV_Misc_Map_01")
    end
end)
check("Transient texture allocation failure retries without poisoning the owned frame", function()
    local nav, _, _, getMarker, tick, methods = fixture()
    local original, calls = methods.CreateTexture, 0
    methods.CreateTexture = function(self)
        calls = calls + 1
        if calls == 1 then return nil end
        return original(self)
    end
    assert(nav.Map(destination)); tick()
    assert(calls == 2 and getMarker().shown and getMarker().icon)
end)
check("Persistent texture allocation failure has a bounded retry budget", function()
    local nav, _, _, _, tick, methods = fixture()
    local calls = 0
    methods.CreateTexture = function() calls = calls + 1 end
    assert(nav.Map(destination))
    for _ = 1, 20 do tick() end
    assert(calls == 3)
end)
print("Owned map marker checks passed: " .. total .. " (native acceptance pending)")
