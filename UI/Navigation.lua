local _, addon = ...
local N = {}
addon.Navigation = N
local target, frame, elapsed = nil, nil, 0
local tomtomOwner, tomtomUID, nativePoint
local navigationGeneration = {}
local presentation, contextElapsed = nil, 0

local function nativeWaypointEmpty(getter)
    if type(getter) ~= "function" then return false end
    local ok, point = pcall(getter)
    if not ok then return false end
    if type(issecretvalue) == "function" then
        local checked, secret = pcall(issecretvalue, point)
        if not checked or secret ~= false then return false end
    end
    return point == nil
end

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

local function releaseNativePoint(pin, generation)
    if not pin or nativePoint or navigationGeneration ~= generation or not C_Map then return end
    local owner, checker = pin.owner, issecretvalue
    if C_Map ~= owner then return end
    local getter, clearer = addon.Clean(owner.GetUserWaypoint, "function"), addon.Clean(owner.ClearUserWaypoint, "function")
    if not getter or not clearer then return end
    local current = addon.Read(getter, "table")
    local pos = current and addon.Clean(current.position, "table")
    local map = current and addon.Clean(current.uiMapID, "number")
    local x, y = pos and addon.Clean(pos.x, "number"), pos and addon.Clean(pos.y, "number")
    if navigationGeneration == generation and not nativePoint and C_Map == owner and issecretvalue == checker and
        addon.Clean(owner.GetUserWaypoint, "function") == getter and addon.Clean(owner.ClearUserWaypoint, "function") == clearer and
        map == pin.mapID and x == pin.x and y == pin.y then
        pcall(clearer)
    end
end

function N.Stop()
    local generation = {}
    navigationGeneration = generation
    local owner, uid, pin = tomtomOwner, tomtomUID, nativePoint
    -- Release ownership before third-party cleanup can invoke callbacks.
    tomtomOwner, tomtomUID, nativePoint, target = nil, nil, nil, nil
    presentation, contextElapsed = nil, 0
    if frame then frame:Hide() end
    if uid and owner and type(owner.RemoveWaypoint) == "function" then
        pcall(owner.RemoveWaypoint, owner, uid)
    end
    releaseNativePoint(pin, generation)
    return generation
end

function N.QuestChanged(id)
    id = addon.Clean(id, "number")
    if id and target and id == target.id then N.Stop() end
end

-- This is a bearing to a coordinate, not a terrain or transport route.
function N.Vector(point)
    if not N.Valid(point) then return nil end
    local destination, px, py = addon.Clean(point.mapID, "number"), addon.Clean(point.x, "number"), addon.Clean(point.y, "number")
    local library, checker = addon.Clean(C_Map, "table"), issecretvalue
    local best = library and addon.Clean(library.GetBestMapForUnit, "function")
    local locate = library and addon.Clean(library.GetPlayerMapPosition, "function")
    local convert = library and addon.Clean(library.GetWorldPosFromMapPos, "function")
    local create = addon.Clean(CreateVector2D, "function")
    local action, generation = target, navigationGeneration
    local owned = action and rawequal(action.place, point)
    local function current()
        return issecretvalue == checker and C_Map == library and CreateVector2D == create and
            addon.Clean(library.GetBestMapForUnit, "function") == best and
            addon.Clean(library.GetPlayerMapPosition, "function") == locate and
            addon.Clean(library.GetWorldPosFromMapPos, "function") == convert and
            addon.Clean(point.mapID, "number") == destination and addon.Clean(point.x, "number") == px and
            addon.Clean(point.y, "number") == py and
            (not owned or (navigationGeneration == generation and rawequal(target, action) and rawequal(action.place, point)))
    end
    if not destination or not px or not py or destination <= 0 or px < 0 or px > 100 or py < 0 or py > 100 or
        not library or not best or not locate or not convert or not create or not current() then return nil end
    local mapID = addon.Read(best, "number", "player")
    if not current() or not mapID then return nil end
    local position = addon.Read(locate, "table", mapID, "player")
    if not current() or not position then return nil end
    local function positionGetter() return addon.Read(function() return position.GetXY end, "function") end
    local xy = positionGetter()
    if not current() or not xy then return nil end
    local ok, x, y = pcall(xy, position)
    x, y = addon.Clean(x, "number"), addon.Clean(y, "number")
    if not current() or positionGetter() ~= xy or not ok or not x or not y or (x == 0 and y == 0) then return nil end
    local sourceOK, source = pcall(create, x, y)
    if not current() or not sourceOK then return nil end
    local aOK, aMap, a = pcall(convert, mapID, source)
    if not current() then return nil end
    local destinationOK, destinationPoint = pcall(create, px / 100, py / 100)
    if not current() or not destinationOK then return nil end
    local bOK, bMap, b = pcall(convert, destination, destinationPoint)
    if not current() then return nil end
    aMap, bMap = addon.Clean(aMap, "number"), addon.Clean(bMap, "number")
    a, b = addon.Clean(a, "table") or addon.Clean(a, "userdata"), addon.Clean(b, "table") or addon.Clean(b, "userdata")
    if not aOK or not bOK or not aMap or aMap ~= bMap or not a or not b then return nil end
    local aFields, ax, ay = pcall(function() return a.x, a.y end)
    local bFields, bx, by = pcall(function() return b.x, b.y end)
    ax, ay, bx, by = addon.Clean(ax, "number"), addon.Clean(ay, "number"), addon.Clean(bx, "number"), addon.Clean(by, "number")
    if not current() or not aFields or not bFields or not ax or not ay or not bx or not by then return nil end
    -- WoW world X points north and world Y points west.
    local north, west = addon.Clean(bx - ax, "number"), addon.Clean(by - ay, "number")
    if current() then return north, west end
end

local function context(action, generation)
    local place, id = action.place, addon.Clean(action.id, "number")
    local mapID, name = addon.Clean(place.mapID, "number"), addon.Clean(place.name, "string")
    local zone, npc = addon.Clean(place.zoneName, "string"), addon.Clean(place.npcID, "number")
    local x, y, objectID = addon.Clean(place.x, "number"), addon.Clean(place.y, "number"), addon.Clean(place.objectID, "number")
    local library, checker, localeGetter = C_Map, issecretvalue, GetLocale
    local mapGetter = library and addon.Clean(library.GetMapInfo, "function")
    local giverGetter, questGetter = addon.Clean(addon.GiverName, "function"), addon.Clean(addon.QuestName, "function")
    local database = addon.Clean(addon.db, "table")
    local choice = database and addon.Clean(database.locale, "string")
    local locale = addon.Read(localeGetter, "string")
    local function current()
        if GetLocale ~= localeGetter or issecretvalue ~= checker then return false end
        local liveLocale = addon.Read(localeGetter, "string")
        if liveLocale ~= locale or GetLocale ~= localeGetter or issecretvalue ~= checker then return false end
        return navigationGeneration == generation and rawequal(target, action) and addon.Clean(action.place, "table") == place and
            addon.Clean(action.id, "number") == id and addon.Clean(place.mapID, "number") == mapID and
            addon.Clean(place.name, "string") == name and addon.Clean(place.zoneName, "string") == zone and
            addon.Clean(place.npcID, "number") == npc and addon.Clean(place.x, "number") == x and
            addon.Clean(place.y, "number") == y and addon.Clean(place.objectID, "number") == objectID and C_Map == library and issecretvalue == checker and
            GetLocale == localeGetter and (not library or addon.Clean(library.GetMapInfo, "function") == mapGetter) and
            addon.Clean(addon.GiverName, "function") == giverGetter and addon.Clean(addon.QuestName, "function") == questGetter and
            addon.Clean(addon.db, "table") == database and (not database or addon.Clean(database.locale, "string") == choice)
    end
    if not current() then return nil end
    local title = addon.Read(questGetter, "string", id)
    if not current() then return nil end
    local giver = addon.Read(giverGetter, "string", place)
    if not current() then return nil end
    local info = addon.Read(mapGetter, "table", mapID)
    if not current() then return nil end
    local region = info and addon.Clean(info.name, "string") or zone
    local function text(value)
        return value and #value <= 1024 and value:find("%S") and value or nil
    end
    giver, region = text(giver) or text(name), text(region) or text(zone)
    return { title = text(title) or "", destination = giver and region and (giver .. " · " .. region) or giver or region or "",
        current = current, locale = locale, localeGetter = localeGetter }
end

local function present(action, generation, status)
    if not presentation or not presentation.current() or contextElapsed >= 1 then
        local refreshed = context(action, generation)
        if navigationGeneration ~= generation or not rawequal(target, action) then return end
        presentation = refreshed
        contextElapsed = 0
    end
    if navigationGeneration ~= generation or not rawequal(target, action) then return end
    local shown = presentation
    if not shown then
        frame.title:SetText(""); frame.note:SetText(""); frame.label:SetText(status); return
    end
    frame.title:SetText(shown.title); frame.note:SetText(shown.destination); frame.label:SetText(status)
    local function height(region, fallback)
        local measured = addon.Read(region.GetStringHeight, "number", region)
        return measured and measured > 0 and measured <= 4096 and measured or fallback
    end
    local titleHeight, noteHeight, statusHeight = height(frame.title, 22), height(frame.note, 18), height(frame.label, 18)
    if not shown.current() or presentation ~= shown then return end
    frame.note:ClearAllPoints(); frame.note:SetPoint("TOPLEFT", 66, -12 - titleHeight - 5)
    frame.label:ClearAllPoints(); frame.label:SetPoint("TOPLEFT", 66, -12 - titleHeight - 5 - noteHeight - 5)
    frame:SetHeight(math.max(82, 12 + titleHeight + 5 + noteHeight + 5 + statusHeight + 12))
end

local function update(_, delta)
    elapsed, contextElapsed = elapsed + delta, contextElapsed + delta
    if elapsed < 0.1 then return end
    elapsed = 0
    local action, generation = target, navigationGeneration
    if not action then return end
    local north, west
    if action then north, west = N.Vector(action.place) end
    if navigationGeneration ~= generation or not rawequal(target, action) then return end
    local facing = addon.Read(GetPlayerFacing, "number")
    if navigationGeneration ~= generation or not rawequal(target, action) then return end
    if not north or not west or not facing then
        frame.arrow:Hide(); present(action, generation, addon.L("NO_POSITION")); return
    end
    local distance = addon.Clean(math.sqrt(north * north + west * west), "number")
    if not distance then frame.arrow:Hide(); present(action, generation, addon.L("NO_POSITION")); return end
    frame.arrow:SetRotation(math.atan2(west, north) - facing)
    frame.arrow:Show()
    present(action, generation, addon.L("GUIDE_DISTANCE", math.floor(distance)))
end

function N.Start(action)
    if not action or not N.Valid(action.place) then return false end
    local generation = N.Stop()
    if target or navigationGeneration ~= generation then return false end
    target = action
    local function current()
        return navigationGeneration == generation and rawequal(target, action)
    end
    local p, owner = action.place, TomTom
    if owner and type(owner.AddWaypoint) == "function" then
        local ok, uid = pcall(owner.AddWaypoint, owner, p.mapID, p.x / 100, p.y / 100,
            { title = addon.QuestName(action.id), persistent = false, minimap = true, world = true })
        local valid = addon.Clean(uid, "table") or addon.Clean(uid, "string") or addon.Clean(uid, "number")
        if type(valid) == "string" and valid == "" then valid = nil end
        if type(valid) == "number" and valid <= 0 then valid = nil end
        if not current() then
            -- A superseded request must not overwrite or remove a replacement's UID.
            if ok and valid and not (rawequal(tomtomOwner, owner) and rawequal(tomtomUID, valid)) and
                type(owner.RemoveWaypoint) == "function" then
                pcall(owner.RemoveWaypoint, owner, valid)
            end
            return false
        end
        if ok and valid then tomtomOwner, tomtomUID = owner, valid end
    end
    if not tomtomUID and N.Valid(p) and C_Map and type(C_Map.SetUserWaypoint) == "function" and UiMapPoint and
        type(UiMapPoint.CreateFromCoordinates) == "function" then
        local mapOwner, factory, checker = C_Map, UiMapPoint, issecretvalue
        local getter, setter, canSet, create = C_Map.GetUserWaypoint, C_Map.SetUserWaypoint,
            C_Map.CanSetUserWaypointOnMap, UiMapPoint.CreateFromCoordinates
        local mapID, pointX, pointY = addon.Clean(p.mapID, "number"), addon.Clean(p.x, "number"), addon.Clean(p.y, "number")
        local x, y = pointX and pointX / 100, pointY and pointY / 100
        local function capabilitiesCurrent()
            return mapID and x and y and C_Map == mapOwner and UiMapPoint == factory and issecretvalue == checker and
                mapOwner.GetUserWaypoint == getter and mapOwner.SetUserWaypoint == setter and
                mapOwner.CanSetUserWaypointOnMap == canSet and factory.CreateFromCoordinates == create and
                addon.Clean(p.mapID, "number") == mapID and addon.Clean(p.x, "number") == pointX and
                addon.Clean(p.y, "number") == pointY
        end
        -- A guide can use its own arrow without replacing the player's map pin.
        local empty = nativeWaypointEmpty(getter)
        if not current() then return false end
        local allowed = capabilitiesCurrent() and empty and (not canSet or
            addon.Read(canSet, "boolean", mapID) == true)
        if not current() then return false end
        if allowed and capabilitiesCurrent() then
            local ok, value = pcall(create, mapID, x, y)
            if not current() then return false end
            value = ok and (addon.Clean(value, "table") or addon.Clean(value, "userdata"))
            if value and capabilitiesCurrent() then
                -- A callback may have created a manual pin since the first check.
                empty = nativeWaypointEmpty(getter)
                if not current() then return false end
                if empty and capabilitiesCurrent() then
                    local setOK, wasSet = pcall(setter, value)
                    local owned = setOK and addon.Clean(wasSet, "boolean") == true
                    local pin = { mapID = mapID, x = x, y = y, owner = mapOwner }
                    if not current() then
                        if owned then releaseNativePoint(pin, navigationGeneration) end
                        return false
                    end
                    owned = owned and capabilitiesCurrent()
                    if owned then nativePoint = pin end
                    if owned and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
                        if not current() then return false end
                    end
                end
            end
        end
    end
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        frame:SetSize(354, 104); frame:SetPoint("TOP", 0, -90)
        frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame.arrow = frame:CreateTexture(nil, "ARTWORK")
        frame.arrow:SetSize(42, 42); frame.arrow:SetPoint("TOPLEFT", 12, -16)
        frame.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        frame.title:SetPoint("TOPLEFT", 66, -12); frame.title:SetWidth(258); frame.title:SetJustifyH("LEFT")
        frame.note = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.note:SetWidth(258); frame.note:SetJustifyH("LEFT")
        frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.label:SetWidth(258); frame.label:SetJustifyH("LEFT")
        local theme = addon.Clean(addon.Theme, "table")
        if theme then addon.Read(theme.StyleRow, "boolean", frame, { kind = "section" }) end
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetSize(22, 22); close:SetPoint("TOPRIGHT"); close:SetScript("OnClick", N.Stop)
        frame:SetScript("OnUpdate", update)
    end
    if not current() then return false end
    frame:Show()
    if not current() then return false end
    elapsed = 0.1; update(frame, 0)
    if not current() then return false end
    N.Map(p)
    return current()
end
