-- Owned entrance marker keeps its dungeon purpose across guide and map requests.
local total = 0
local function client()
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
    function methods:CreateFontString() return create("FontString", nil, self) end
    function methods:GetStringHeight() return 18 end
    for _, name in ipairs({ "SetClampedToScreen", "SetMovable", "RegisterForDrag", "SetWidth", "SetText",
        "SetHeight", "SetJustifyH", "SetRotation", "StartMoving", "StopMovingOrSizing" }) do
        if not methods[name] then methods[name] = function() end end
    end
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
    addon.L = function(key) return key end
    addon.DungeonName = function() return "Dungeon" end
    local function marker()
        for _, frame in ipairs(frames) do if frame.icon then return frame end end
    end
    local function tick()
        for _, frame in ipairs(frames) do
            if frame.shown and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, .1) end
        end
    end
    return addon.Navigation, map, canvas, marker, tick, methods, function() return nativeWrites, manual end, addon
end
local function check(name, fn)
    fn(); total = total + 1; print("PASS " .. name)
end
local spot = { mapID = 1455, x = 32.8, y = 48.6 }
local other = { mapID = 1455, x = 80, y = 20 }
local function quest(place)
    return { id = 1, kind = "visit", place = place or spot }
end
local function dungeon()
    return { key = "example" }
end

check("entrance neutral entrance repaint keeps geometry and spares manual pins", function()
    local nav, _, _, findMarker, _, _, native = client()
    assert(nav.StartEntrance(dungeon(), spot))
    local marker = assert(findMarker())
    assert(marker.icon.atlas == "Dungeon", "entrance atlas")
    local anchorX, anchorY = marker.point[4], marker.point[5]
    assert(nav.Map(spot))
    assert(marker.icon.atlas == "Waypoint-MapPin-Untracked", "neutral repaint")
    assert(marker.point[4] == anchorX and marker.point[5] == anchorY, "geometry reused")
    assert(nav.StartEntrance(dungeon(), spot))
    assert(marker.icon.atlas == "Dungeon", "entrance repaint")
    assert(marker.point[4] == anchorX and marker.point[5] == anchorY, "geometry reused")
    assert(nav.Start(quest()))
    assert(marker.icon.atlas == "Waypoint-MapPin-Untracked", "quest remains neutral")
    assert(marker.width == 30, "constant marker size")
    local writes, manual = native()
    assert(writes == 0 and manual.uiMapID == 99, "manual pin untouched")
end)

for _, mode in ipairs({ "missing", "throws", "false", "mismatch" }) do
    check("entrance atlas fallback keeps the standard texture: " .. mode, function()
        local nav, _, _, findMarker, _, methods = client()
        if mode == "missing" then methods.SetAtlas = nil
        elseif mode == "throws" then methods.SetAtlas = function() error("unsupported atlas") end
        elseif mode == "false" then methods.SetAtlas = function(self) self.atlas = nil; return false end
        else methods.SetAtlas = function(self) self.atlas = "Something-Else"; return true end end
        assert(nav.StartEntrance(dungeon(), spot))
        local marker = assert(findMarker())
        assert(marker.shown, "marker stays visible")
        assert(marker.icon.texture == "Interface\\Icons\\INV_Misc_Map_01", "standard texture fallback")
    end)
end

for _, mode in ipairs({ "SetAtlas", "SetTexture", "GetAtlas" }) do
    check("replacement inside the old appearance " .. mode .. " keeps the newest owner", function()
        local nav, _, _, findMarker, _, methods = client()
        local armed, original = true, methods[mode]
        methods[mode] = function(self, first, ...)
            if armed and (mode ~= "SetTexture" or first == "Interface\\Icons\\INV_Misc_Map_01") then
                armed = false; assert(nav.Map(other))
            end
            return original(self, first, ...)
        end
        assert(nav.StartEntrance(dungeon(), spot))
        local marker = assert(findMarker())
        assert(marker.shown, "replacement stays visible")
        assert(marker.point[4] == 800 and marker.point[5] == -100, "replacement geometry wins")
        assert(marker.icon.atlas == "Waypoint-MapPin-Untracked", "stale entrance write repaired")
    end)
end

for _, mode in ipairs({ "restricted", "string", "number", "function", "boolean" }) do
    check("unsafe map role stays neutral: " .. mode, function()
        local nav, _, _, findMarker = client()
        local role = mode
        if mode == "restricted" then
            role = {}
            issecretvalue = function(value) return value == role end
        elseif mode == "string" then role = "dungeon"
        elseif mode == "number" then role = 7
        elseif mode == "function" then role = function() end
        else role = true end
        assert(nav.Map(spot, role))
        local marker = assert(findMarker())
        assert(marker.shown, "marker stays visible")
        assert(marker.icon.atlas == "Waypoint-MapPin-Untracked", "foreign role never claims entrance")
        assert(marker.width == 30, "constant marker size")
    end)
end

check("ordinary Start with a foreign role stays neutral", function()
    local nav, _, _, findMarker = client()
    assert(nav.Start(quest(), "dungeon"))
    local marker = assert(findMarker())
    assert(marker.shown and marker.icon.atlas == "Waypoint-MapPin-Untracked", "foreign role never claims entrance")
end)

for _, outer in ipairs({ "Map", "Start" }) do
    for _, nested in ipairs({ "Map", "Start" }) do
        check("stale " .. outer .. " cannot stop a newer " .. nested .. " from role cleanup", function()
            local nav, _, _, findMarker, _, _, _, addonRef = client()
            local token, fired, clean = {}, false, addonRef.Clean
            addonRef.Clean = function(value, kind)
                if not fired and value == token and kind == "table" then
                    fired = true
                    if nested == "Map" then assert(nav.Map(other))
                    else assert(nav.Start({ id = 9, kind = "visit", place = other })) end
                end
                return clean(value, kind)
            end
            if outer == "Map" then assert(nav.Map(spot, token) == false, "old map aborts")
            else assert(nav.Start({ kind = "entrance", dungeon = dungeon(), place = spot }, token) == false, "old guide aborts") end
            addonRef.Clean = clean
            assert(fired, "cleanup callback actually fired")
            local marker = assert(findMarker())
            assert(marker.shown, "replacement stays visible")
            assert(marker.point[4] == 800, "replacement geometry wins")
            assert(marker.icon.atlas == "Waypoint-MapPin-Untracked", "replacement stays neutral")
        end)
    end
end

check("ordinary requests stay neutral while entrance purpose survives the guide path", function()
    local nav, _, _, findMarker, _, _, native = client()
    local removals = 0
    TomTom = { AddWaypoint = function() error("foreign waypoint must never be claimed") end,
        RemoveWaypoint = function() removals = removals + 1 end }
    assert(nav.Map(spot))
    assert(findMarker().icon.atlas == "Waypoint-MapPin-Untracked", "plain map stays neutral")
    assert(nav.Start(quest()))
    assert(findMarker().icon.atlas == "Waypoint-MapPin-Untracked", "ordinary guide stays neutral")
    assert(nav.StartEntrance(dungeon(), spot))
    local marker = assert(findMarker())
    assert(marker.icon.atlas == "Dungeon", "entrance purpose reaches the map")
    assert(marker.width == 30, "constant marker size")
    nav.Stop()
    assert(not marker.shown, "stop hides the owned marker")
    assert(removals == 0, "foreign TomTom waypoints preserved")
    assert(native() == 0, "manual pin untouched")
end)

print("Entrance marker checks passed: " .. total .. " (native acceptance pending)")
