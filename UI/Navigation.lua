local _, addon = ...
local N = {}
addon.Navigation = N
local target, frame, elapsed = nil, nil, 0
local tomtomOwner, tomtomUID, nativePoint

function N.Valid(point)
    return type(point) == "table" and addon.Clean(point.mapID, "number") and
        addon.Clean(point.x, "number") and addon.Clean(point.y, "number") and
        point.mapID > 0 and point.x >= 0 and point.x <= 100 and point.y >= 0 and point.y <= 100
end

function N.Map(point)
    if type(point) ~= "table" or not addon.Clean(point.mapID, "number") or point.mapID <= 0 then return false end
    if C_Map and type(C_Map.OpenWorldMap) == "function" then
        return pcall(C_Map.OpenWorldMap, point.mapID)
    end
    if type(OpenWorldMap) == "function" then return pcall(OpenWorldMap, point.mapID) end
    return false
end

function N.Stop()
    if tomtomUID and tomtomOwner and type(tomtomOwner.RemoveWaypoint) == "function" then
        pcall(tomtomOwner.RemoveWaypoint, tomtomOwner, tomtomUID)
    end
    tomtomOwner, tomtomUID = nil, nil
    if nativePoint and C_Map then
        local current = addon.Read(C_Map.GetUserWaypoint, "table")
        local pos = current and addon.Clean(current.position, "table")
        local map = current and addon.Clean(current.uiMapID, "number")
        local x, y = pos and addon.Clean(pos.x, "number"), pos and addon.Clean(pos.y, "number")
        if map == nativePoint.mapID and x and y and math.abs(x - nativePoint.x) < 0.00001 and math.abs(y - nativePoint.y) < 0.00001 then
            if type(C_Map.ClearUserWaypoint) == "function" then pcall(C_Map.ClearUserWaypoint) end
        end
    end
    nativePoint = nil
    target = nil
    if frame then frame:Hide() end
end

function N.QuestChanged(id)
    id = addon.Clean(id, "number")
    if id and target and id == target.id then N.Stop() end
end

-- This is a bearing to a coordinate, not a terrain or transport route.
function N.Vector(point)
    if not N.Valid(point) or not C_Map or not CreateVector2D then return nil end
    local mapID = addon.Read(C_Map.GetBestMapForUnit, "number", "player")
    local position = mapID and addon.Read(C_Map.GetPlayerMapPosition, "table", mapID, "player")
    if not position then return nil end
    local ok, x, y = pcall(function() return position:GetXY() end)
    x, y = addon.Clean(x, "number"), addon.Clean(y, "number")
    if not ok or not x or not y or (x == 0 and y == 0) then return nil end
    local convert = C_Map.GetWorldPosFromMapPos
    if type(convert) ~= "function" then return nil end
    local aOK, aMap, a = pcall(function() return convert(mapID, CreateVector2D(x, y)) end)
    local bOK, bMap, b = pcall(function() return convert(point.mapID, CreateVector2D(point.x / 100, point.y / 100)) end)
    aMap, bMap = addon.Clean(aMap, "number"), addon.Clean(bMap, "number")
    a, b = addon.Clean(a, "table") or addon.Clean(a, "userdata"), addon.Clean(b, "table") or addon.Clean(b, "userdata")
    if not aOK or not bOK or not aMap or aMap ~= bMap or not a or not b then return nil end
    local aFields, ax, ay = pcall(function() return a.x, a.y end)
    local bFields, bx, by = pcall(function() return b.x, b.y end)
    ax, ay, bx, by = addon.Clean(ax, "number"), addon.Clean(ay, "number"), addon.Clean(bx, "number"), addon.Clean(by, "number")
    if not aFields or not bFields or not ax or not ay or not bx or not by then return nil end
    -- WoW world X points north and world Y points west.
    return addon.Clean(bx - ax, "number"), addon.Clean(by - ay, "number")
end

local function update(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.1 then return end
    elapsed = 0
    local north, west
    if target then north, west = N.Vector(target.place) end
    local facing = addon.Read(GetPlayerFacing, "number")
    if not north or not west or not facing then
        frame.label:SetText(addon.L("NO_POSITION")); frame.arrow:Hide(); return
    end
    local distance = addon.Clean(math.sqrt(north * north + west * west), "number")
    if not distance then frame.label:SetText(addon.L("NO_POSITION")); frame.arrow:Hide(); return end
    local bearing = math.atan2(west, north)
    frame.arrow:SetRotation(bearing - facing)
    frame.arrow:Show()
    frame.label:SetText(addon.QuestName(target.id) .. "\n" .. math.floor(distance) .. " yd")
end

function N.Start(action)
    if not action or not N.Valid(action.place) then return false end
    N.Stop()
    target = action
    local p = action.place
    if TomTom and type(TomTom.AddWaypoint) == "function" then
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, p.mapID, p.x / 100, p.y / 100,
            { title = addon.QuestName(action.id), persistent = false, minimap = true, world = true })
        local valid = addon.Clean(uid, "table") or addon.Clean(uid, "string") or addon.Clean(uid, "number")
        if type(valid) == "string" and valid == "" then valid = nil end
        if type(valid) == "number" and valid <= 0 then valid = nil end
        if ok and valid then tomtomOwner, tomtomUID = TomTom, valid end
    end
    if not tomtomUID and C_Map and type(C_Map.SetUserWaypoint) == "function" and UiMapPoint and
        type(UiMapPoint.CreateFromCoordinates) == "function" then
        local allowed = not C_Map.CanSetUserWaypointOnMap or addon.Read(C_Map.CanSetUserWaypointOnMap, "boolean", p.mapID) == true
        if allowed then
            local ok, wasSet = pcall(function()
                local value = UiMapPoint.CreateFromCoordinates(p.mapID, p.x / 100, p.y / 100)
                if not (addon.Clean(value, "table") or addon.Clean(value, "userdata")) then error("Invalid map point") end
                return C_Map.SetUserWaypoint(value)
            end)
            local owned = ok and addon.Clean(wasSet, "boolean") == true
            if owned then nativePoint = { mapID = p.mapID, x = p.x / 100, y = p.y / 100 } end
            if owned and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
            end
        end
    end
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        frame:SetSize(320, 115); frame:SetPoint("TOP", 0, -90)
        frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame.arrow = frame:CreateTexture(nil, "ARTWORK")
        frame.arrow:SetSize(42, 42); frame.arrow:SetPoint("TOP")
        frame.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
        frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.label:SetPoint("TOP", 0, -46); frame.label:SetWidth(310)
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetSize(22, 22); close:SetPoint("TOPRIGHT"); close:SetScript("OnClick", N.Stop)
        frame:SetScript("OnUpdate", update)
    end
    frame:Show(); elapsed = 0.1; update(frame, 0)
    N.Map(p)
    return true
end
