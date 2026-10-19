local _, addon = ...
local N = {}
addon.Navigation = N
local target, frame, elapsed = nil, nil, 0
local tomtomOwner, tomtomUID, tomtomRemoval, nativePoint, pendingNativeCleanup
local navigationGeneration = {}
local presentation, contextElapsed = nil, 0
local presentationWrite, guideUpdate
local mapMarker, mapMarkerState, mapMarkerTicker
local markerGeneration, markerElapsed, markerWrites = {}, 0, setmetatable({}, { __mode = "k" })

local function actionTitle(action)
    if action.kind == "entrance" then
        return addon.Read(addon.DungeonName, "string", action.dungeon) or ""
    end
    return addon.Read(addon.QuestName, "string", action.id) or ""
end

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

local function mapIdentity(value)
    value = addon.Clean(value, "number")
    if value and value > 0 and value <= 9007199254740991 and value % 1 == 0 then return value end
end

function N.Valid(point)
    if type(point) ~= "table" then return false end
    local mapID = mapIdentity(point.mapID)
    local x, y = addon.Clean(point.x, "number"), addon.Clean(point.y, "number")
    return mapID ~= nil and x ~= nil and y ~= nil and x >= 0 and x <= 100 and y >= 0 and y <= 100
end

local function markerObject(value)
    return addon.Clean(value, "table") or addon.Clean(value, "userdata")
end

local function markerMethod(owner, key)
    return owner and addon.Read(function() return owner[key] end, "function")
end

local function markerWrite(owner, method, current, ...)
    if not current() then return false end
    local setter = markerMethod(owner, method)
    if not setter or not current() then return false end
    local writes = markerWrites[owner] or {}; markerWrites[owner] = writes
    local key = (method == "Show" or method == "Hide") and "visibility"
        or ((method == "SetPoint" or method == "ClearAllPoints") and "anchor" or method)
    local binding = { current = current, setter = setter, args = { ... }, count = select("#", ...) }
    writes[key] = binding
    local ok = pcall(setter, owner, ...)
    local fresh = current()
    if not fresh then
        local newer = writes[key]
        if newer and newer ~= binding and not newer.repairing then
            newer.repairing = true
            if newer.current() and writes[key] == newer then pcall(newer.setter, owner, unpack(newer.args, 1, newer.count)) end
            newer.repairing = nil
        end
    end
    return ok and fresh
end

local function clearMapMarker()
    local generation = {}; markerGeneration, mapMarkerState = generation, nil
    local function current() return markerGeneration == generation and mapMarkerState == nil end
    if mapMarker then markerWrite(mapMarker, "Hide", current) end
    if mapMarkerTicker and current() then markerWrite(mapMarkerTicker, "Hide", current) end
    return generation
end

local function refreshMapMarker()
    local state = mapMarkerState
    if not state then return end
    local function current()
        if markerGeneration ~= state.generation or mapMarkerState ~= state or addon.Navigation ~= N then return false end
        local mapID = mapIdentity(addon.Read(function() return state.point.mapID end, "number"))
        local x = addon.Read(function() return state.point.x end, "number")
        local y = addon.Read(function() return state.point.y end, "number")
        return markerGeneration == state.generation and mapMarkerState == state and addon.Navigation == N
            and mapID == state.mapID and x == state.x and y == state.y
    end
    if not current() then if mapMarkerState == state then clearMapMarker() end; return end
    local map = markerObject(WorldMapFrame)
    local shownGetter, mapGetter, canvasGetter = markerMethod(map, "IsShown"), markerMethod(map, "GetMapID"), markerMethod(map, "GetCanvas")
    local shown = shownGetter and addon.Read(shownGetter, "boolean", map)
    if shown == false then
        local function hidden()
            if not current() or WorldMapFrame ~= map or markerMethod(map, "IsShown") ~= shownGetter then return false end
            local visible = addon.Read(shownGetter, "boolean", map)
            return visible == false and current() and WorldMapFrame == map and markerMethod(map, "IsShown") == shownGetter
        end
        if mapMarker then
            local visible = addon.Read(markerMethod(mapMarker, "IsShown"), "boolean", mapMarker)
            if visible ~= false and hidden() then markerWrite(mapMarker, "Hide", hidden) end
        end
        if current() then state.geometry = nil end
        return
    end
    local mapID = mapGetter and mapIdentity(addon.Read(mapGetter, "number", map))
    local canvasOK, rawCanvas = pcall(function() return canvasGetter and canvasGetter(map) end)
    local canvas = canvasOK and markerObject(rawCanvas)
    local function owned()
        if not current() or WorldMapFrame ~= map or markerMethod(map, "IsShown") ~= shownGetter
            or markerMethod(map, "GetMapID") ~= mapGetter or markerMethod(map, "GetCanvas") ~= canvasGetter then return false end
        local displayed = mapGetter and mapIdentity(addon.Read(mapGetter, "number", map))
        local visible = shownGetter and addon.Read(shownGetter, "boolean", map)
        local canvasRead, latestCanvas = pcall(function() return canvasGetter and canvasGetter(map) end)
        return canvasRead and markerObject(latestCanvas) == canvas and displayed == mapID and visible == shown and current() and WorldMapFrame == map
            and markerMethod(map, "IsShown") == shownGetter and markerMethod(map, "GetMapID") == mapGetter
            and markerMethod(map, "GetCanvas") == canvasGetter and current()
    end
    if not owned() then
        if mapMarker then markerWrite(mapMarker, "Hide", current) end
        state.geometry = nil
        return
    end
    if not map or not canvas or shown ~= true or mapID ~= state.mapID then
        if mapMarker then markerWrite(mapMarker, "Hide", owned) end
        state.geometry = nil
        return
    end
    local width = addon.Read(markerMethod(canvas, "GetWidth"), "number", canvas)
    local height = addon.Read(markerMethod(canvas, "GetHeight"), "number", canvas)
    local scaleGetter = markerMethod(map, "GetCanvasScale")
    local zoom
    if scaleGetter then zoom = addon.Read(scaleGetter, "number", map) end
    if not width or not height or not zoom or width <= 0 or height <= 0 or zoom <= 0 or not owned() then
        if mapMarker then markerWrite(mapMarker, "Hide", current) end
        state.geometry = nil
        return
    end
    if not mapMarker then
        local ok, created = pcall(CreateFrame, "Frame", nil, canvas)
        if not owned() then return end
        mapMarker = ok and markerObject(created) or nil
        if not mapMarker then return end
        markerWrite(mapMarker, "Hide", owned)
        markerWrite(mapMarker, "EnableMouse", owned, false)
    end
    if not mapMarker.icon and (state.iconAttempts or 0) < 3 then
        state.iconAttempts = (state.iconAttempts or 0) + 1
        local createTexture = markerMethod(mapMarker, "CreateTexture")
        local made, icon = pcall(function() return createTexture and createTexture(mapMarker, nil, "OVERLAY") end)
        if not owned() then return end
        icon = made and markerObject(icon)
        if not icon then return end
        mapMarker.icon = icon
        markerWrite(icon, "SetAllPoints", owned, mapMarker)
        -- The waypoint atlas is shipped by the client's own map provider. The
        -- standard map icon remains visible when that optional atlas is unavailable.
        markerWrite(icon, "SetTexture", owned, "Interface\\Icons\\INV_Misc_Map_01")
        local atlas = markerMethod(icon, "SetAtlas")
        if atlas and owned() then
            local accepted, result = pcall(atlas, icon, "Waypoint-MapPin-Untracked")
            local actual = addon.Read(markerMethod(icon, "GetAtlas"), "string", icon)
            if not accepted or addon.Clean(result, "boolean") == false or actual ~= "Waypoint-MapPin-Untracked" then
                markerWrite(icon, "SetTexture", owned, "Interface\\Icons\\INV_Misc_Map_01")
            end
        end
    end
    if not mapMarker.icon or not owned() then return end
    local geometry = state.geometry
    if geometry and geometry.map == map and geometry.canvas == canvas and geometry.width == width
        and geometry.height == height and geometry.zoom == zoom then return end
    -- MapCanvas positions normalized points in its scrolling child, divided by
    -- the pin scale. Inverse canvas scale keeps this owned marker a constant size.
    local scale = 1 / zoom
    local anchorX = addon.Clean(width * (state.x / 100) / scale, "number")
    local anchorY = addon.Clean(-height * (state.y / 100) / scale, "number")
    if not addon.Clean(scale, "number") or not anchorX or not anchorY then
        markerWrite(mapMarker, "Hide", current); state.geometry = nil; return
    end
    if not markerWrite(mapMarker, "SetParent", owned, canvas)
        or not markerWrite(mapMarker, "SetSize", owned, 30, 30)
        or not markerWrite(mapMarker, "SetScale", owned, scale)
        or not markerWrite(mapMarker, "ClearAllPoints", owned)
        or not markerWrite(mapMarker, "SetPoint", owned, "CENTER", canvas, "TOPLEFT", anchorX, anchorY)
        or not markerWrite(mapMarker, "Show", owned) then return end
    state.geometry = { map = map, canvas = canvas, width = width, height = height, zoom = zoom }
end

function N.Map(point)
    local mapID = type(point) == "table" and mapIdentity(point.mapID)
    if not mapID then return false end
    local generation = clearMapMarker()
    local x = addon.Read(function() return point.x end, "number")
    local y = addon.Read(function() return point.y end, "number")
    local opened = false
    if C_Map and type(C_Map.OpenWorldMap) == "function" then opened = pcall(C_Map.OpenWorldMap, mapID)
    elseif type(OpenWorldMap) == "function" then opened = pcall(OpenWorldMap, mapID) end
    if not opened or markerGeneration ~= generation then return opened end
    local map = markerObject(WorldMapFrame)
    if x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 and map
        and markerMethod(map, "GetCanvas") and markerMethod(map, "GetMapID") and markerMethod(map, "IsShown") then
        mapMarkerState = { generation = generation, point = point, mapID = mapID, x = x, y = y }
        if not mapMarkerTicker then
            local ok, created = pcall(CreateFrame, "Frame", nil, UIParent)
            if markerGeneration ~= generation then return opened end
            mapMarkerTicker = ok and markerObject(created) or nil
            if mapMarkerTicker then
                mapMarkerTicker:SetScript("OnUpdate", function(_, delta)
                    delta = addon.Clean(delta, "number")
                    if not delta or delta < 0 then return end
                    markerElapsed = markerElapsed + delta
                    if markerElapsed < 0.1 then return end
                    markerElapsed = 0
                    refreshMapMarker()
                end)
            end
        end
        if mapMarkerTicker then
            markerWrite(mapMarkerTicker, "Show", function() return markerGeneration == generation and mapMarkerState ~= nil end)
        end
        refreshMapMarker()
    end
    return opened
end

function N.ProbeGeometry()
    local unknown = { status = "unknown", frames = {
        hud = { status = "unknown" }, planner = { status = "unknown" }, worldMap = { status = "unknown" } } }
    local clean, read, checker, localeGetter, probe = addon.Clean, addon.Read, issecretvalue, GetLocale, N.ProbeGeometry
    if type(clean) ~= "function" or type(read) ~= "function" then return unknown end
    local ok, result = pcall(function()
        local function readable(value)
            if type(checker) ~= "function" then return true end
            local checked, restricted = pcall(checker, value)
            return checked and restricted == false
        end
        local function same(value, saved)
            return readable(value) and rawequal(value, saved)
        end
        local function object(value)
            return clean(value, "table") or clean(value, "userdata")
        end
        local ui, mapRoot = addon.UI, WorldMapFrame
        if not readable(ui) or not readable(mapRoot) then return unknown end
        local card = clean(ui, "table")
        local cardFields, cardValues = { "frame", "quest", "dungeon", "engine", "rewardGeneration" }, {}
        if card then
            for _, key in ipairs(cardFields) do
                local value = rawget(card, key)
                if not readable(value) then return unknown end
                cardValues[key] = value
            end
        end
        local generation, action, hud = navigationGeneration, target, frame
        local localeFunction = clean(localeGetter, "function")
        local locale = localeFunction and clean(read(localeFunction, "string"), "string")
        if not locale then return unknown end
        local roles = { { key = "hud", owner = object(hud) },
            { key = "planner", owner = card and object(cardValues.frame) },
            { key = "worldMap", owner = object(mapRoot) } }
        -- The inherited GetMapID can fall back to player-location APIs.
        local mapOwner = type(roles[3].owner) == "table" and roles[3].owner or nil
        local rawMapID = mapOwner and rawget(mapOwner, "mapID")
        if not readable(rawMapID) then mapOwner = nil end
        local displayedMapID = mapOwner and clean(rawMapID, "number")
        if displayedMapID and (displayedMapID <= 0 or displayedMapID > 9007199254740991 or displayedMapID % 1 ~= 0) then displayedMapID = nil end
        if not displayedMapID then mapOwner = nil end
        local specs = { { "shown", "IsShown", "boolean" }, { "visible", "IsVisible", "boolean" },
            { "strata", "GetFrameStrata", "string" }, { "level", "GetFrameLevel", "number" },
            { "scale", "GetEffectiveScale", "number" }, { "left", "GetLeft", "number" },
            { "bottom", "GetBottom", "number" }, { "width", "GetWidth", "number" }, { "height", "GetHeight", "number" } }
        local strata = { BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true,
            FULLSCREEN = true, FULLSCREEN_DIALOG = true, TOOLTIP = true }
        local output = { status = "known", frames = {} }
        for _, role in ipairs(roles) do
            local values = { status = role.owner and "known" or "unknown" }
            output.frames[role.key], role.getters, role.rawMethods = values, {}, {}
            if role.owner then
                for _, spec in ipairs(specs) do
                    local getter = clean(role.owner[spec[2]], "function")
                    role.getters[spec[2]] = getter
                    if type(role.owner) == "table" then
                        local slot = rawget(role.owner, spec[2])
                        if not readable(slot) then return unknown end
                        role.rawMethods[spec[2]] = slot
                    end
                end
            end
        end
        for _, role in ipairs(roles) do
            local values = output.frames[role.key]
            if role.owner then
                for _, spec in ipairs(specs) do
                    local getter = role.getters[spec[2]]
                    local value = getter and clean(read(getter, spec[3], role.owner), spec[3])
                    if spec[1] == "strata" and value and not strata[value] then value = nil end
                    if spec[1] == "level" and value and (value < 0 or value % 1 ~= 0) then value = nil end
                    if spec[1] == "scale" and value and value <= 0 then value = nil end
                    if (spec[1] == "width" or spec[1] == "height") and value and value < 0 then value = nil end
                    values[spec[1]] = value
                end
            end
        end
        if output.frames.worldMap.shown == true then output.frames.worldMap.displayedMapID = displayedMapID end
        if addon.Clean ~= clean or addon.Read ~= read or issecretvalue ~= checker or GetLocale ~= localeGetter or
            addon.Navigation ~= N or navigationGeneration ~= generation or target ~= action or frame ~= hud or
            not same(addon.UI, ui) or not same(WorldMapFrame, mapRoot) then return unknown end
        if card then
            for _, key in ipairs(cardFields) do if not same(rawget(card, key), cardValues[key]) then return unknown end end
        end
        local language = clean(read(localeFunction, "string"), "string")
        for _, role in ipairs(roles) do
            if role.owner then
                for _, spec in ipairs(specs) do
                    if clean(role.owner[spec[2]], "function") ~= role.getters[spec[2]] then return unknown end
                end
            end
        end
        if language ~= locale or addon.Clean ~= clean or addon.Read ~= read or issecretvalue ~= checker or
            GetLocale ~= localeGetter or addon.Navigation ~= N or navigationGeneration ~= generation or
            target ~= action or frame ~= hud or not same(addon.UI, ui) or not same(WorldMapFrame, mapRoot) then return unknown end
        if card then
            for _, key in ipairs(cardFields) do if not same(rawget(card, key), cardValues[key]) then return unknown end end
        end
        -- Final proof covers static bindings only; inherited native dispatch and
        -- geometry sampled at different instants are not an atomic native snapshot.
        if not rawequal(rawget(addon, "Clean"), clean) or not rawequal(rawget(addon, "Read"), read) or
            not rawequal(rawget(_G, "issecretvalue"), checker) or not rawequal(rawget(_G, "GetLocale"), localeGetter) or
            not rawequal(rawget(addon, "Navigation"), N) or not rawequal(rawget(N, "ProbeGeometry"), probe) or
            not rawequal(rawget(addon, "UI"), ui) or not rawequal(rawget(_G, "WorldMapFrame"), mapRoot) or
            navigationGeneration ~= generation or target ~= action or frame ~= hud then return unknown end
        if card then
            for _, key in ipairs(cardFields) do
                if not rawequal(rawget(card, key), cardValues[key]) then return unknown end
            end
        end
        for _, role in ipairs(roles) do
            if type(role.owner) == "table" then
                for _, spec in ipairs(specs) do
                    if not rawequal(rawget(role.owner, spec[2]), role.rawMethods[spec[2]]) then return unknown end
                end
            end
        end
        if mapOwner and not rawequal(rawget(mapOwner, "mapID"), rawMapID) then return unknown end
        return output
    end)
    return ok and result or unknown
end

local function releaseNativePoint(pin, generation)
    if not pin or nativePoint or navigationGeneration ~= generation or not C_Map then return end
    local owner, checker = pin.owner, issecretvalue
    if C_Map ~= owner then return end
    local getter, clearer = addon.Clean(owner.GetUserWaypoint, "function"), addon.Clean(owner.ClearUserWaypoint, "function")
    if not getter or not clearer then return end
    if pin.cleanupGetter and (pin.cleanupGetter ~= getter or pin.cleanupClearer ~= clearer or pin.cleanupChecker ~= checker) then return end
    pin.cleanupGetter, pin.cleanupClearer, pin.cleanupChecker = getter, clearer, checker
    local function currentOwner()
        return navigationGeneration == generation and not nativePoint and C_Map == owner and issecretvalue == checker and
            rawequal(rawget(owner, "GetUserWaypoint"), getter) and rawequal(rawget(owner, "ClearUserWaypoint"), clearer)
    end
    local function readPoint()
        local ok, value = pcall(getter)
        if not ok then return "unknown" end
        if type(checker) == "function" then
            local checked, secret = pcall(checker, value)
            if not checked or secret ~= false then return "unknown" end
        end
        if value == nil then return "empty" end
        local point = addon.Clean(value, "table")
        local pos = point and addon.Clean(point.position, "table")
        local map = point and addon.Clean(point.uiMapID, "number")
        local x, y = pos and addon.Clean(pos.x, "number"), pos and addon.Clean(pos.y, "number")
        if not map or not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then return "unknown" end
        -- Native vector readback may round normalized coordinates to float precision.
        if map == pin.mapID and math.abs(x - pin.x) <= 0.0000001 and math.abs(y - pin.y) <= 0.0000001 then return "owned" end
        return "foreign"
    end
    local state = readPoint()
    if not currentOwner() then return end
    local attempts = pin.cleanupAttempts or 0
    if state == "owned" and attempts < 3 then
        pin.cleanupAttempts = attempts + 1
        pcall(clearer)
        if not currentOwner() then
            -- A nested cancellation may leave no guide to own a failed cleanup.
            -- Transfer only dormant authority; never clear again in this invocation.
            if navigationGeneration == generation or target or nativePoint or pendingNativeCleanup then return end
            generation = navigationGeneration
            if not currentOwner() then return end
        end
        -- Clearing has no success return contract; only fresh readback proves removal.
        state = readPoint()
    end
    if currentOwner() and (state == "owned" or state == "unknown") and (pin.cleanupAttempts or 0) < 3 then
        -- Dormant ownership is retried only by a later explicit Start/Stop, never a timer.
        pendingNativeCleanup = pin
    end
end

local visibilityWrite
local function setVisible(value, action, generation)
    if not frame then return true end
    local owner = frame
    local binding = { owner = owner, value = value }
    local function current()
        return frame == owner and navigationGeneration == generation and rawequal(target, action) and visibilityWrite == binding
    end
    binding.current = current
    visibilityWrite = binding
    local ok = pcall(value and owner.Show or owner.Hide, owner)
    local fresh = current()
    if not fresh then
        local newer = visibilityWrite
        if newer and newer ~= binding and not newer.repairing then
            newer.repairing = true
            local repairCurrent = newer.current()
            if repairCurrent and visibilityWrite == newer then
                pcall(newer.value and newer.owner.Show or newer.owner.Hide, newer.owner)
            end
            newer.repairing = nil
        end
    end
    return ok and fresh
end

function N.Stop()
    local generation = {}
    navigationGeneration = generation
    local owner, uid, remove, pin = tomtomOwner, tomtomUID, tomtomRemoval, nativePoint or pendingNativeCleanup
    -- Release ownership before third-party cleanup can invoke callbacks.
    tomtomOwner, tomtomUID, tomtomRemoval, nativePoint, pendingNativeCleanup, target = nil, nil, nil, nil, nil, nil
    presentation, contextElapsed = nil, 0
    clearMapMarker()
    if frame then setVisible(false, nil, generation) end
    if uid and owner and remove and owner.RemoveWaypoint == remove and
        not (rawequal(tomtomOwner, owner) and rawequal(tomtomUID, uid)) then
        pcall(remove, owner, uid)
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
    local kind, dungeon = action.kind, action.dungeon
    local dungeonGetter = addon.DungeonName
    local mapID, name = addon.Clean(place.mapID, "number"), addon.Clean(place.name, "string")
    local zone, npc = addon.Clean(place.zoneName, "string"), addon.Clean(place.npcID, "number")
    local x, y, objectID = addon.Clean(place.x, "number"), addon.Clean(place.y, "number"), addon.Clean(place.objectID, "number")
    local library, checker, localeGetter = C_Map, issecretvalue, GetLocale
    local mapGetter = library and addon.Clean(library.GetMapInfo, "function")
    local giverGetter, questGetter = addon.Clean(addon.GiverName, "function"), addon.Clean(addon.QuestName, "function")
    local sourceGetter, sourceProof = addon.SourceName, nil
    local database = addon.Clean(addon.db, "table")
    local choice = database and addon.Clean(database.locale, "string")
    local languages = addon.Clean(addon.Language, "table")
    local selectionGetter = languages and addon.Clean(languages.GetSelection, "function")
    local selection = addon.Read(selectionGetter, "string", languages)
    local locale = addon.Read(localeGetter, "string")
    local function current()
        if addon.SourceName ~= sourceGetter then return false end
        if GetLocale ~= localeGetter or issecretvalue ~= checker then return false end
        local liveLocale = addon.Read(localeGetter, "string")
        if liveLocale ~= locale or GetLocale ~= localeGetter or issecretvalue ~= checker then return false end
        return navigationGeneration == generation and rawequal(target, action) and addon.Clean(action.place, "table") == place and
            addon.Clean(action.id, "number") == id and action.kind == kind and action.dungeon == dungeon and
            addon.DungeonName == dungeonGetter and addon.SourceName == sourceGetter and addon.Language == languages and
            (not languages or addon.Clean(languages.GetSelection, "function") == selectionGetter) and
            addon.Read(selectionGetter, "string", languages) == selection and addon.Clean(place.mapID, "number") == mapID and
            addon.Clean(place.name, "string") == name and addon.Clean(place.zoneName, "string") == zone and
            addon.Clean(place.npcID, "number") == npc and addon.Clean(place.x, "number") == x and
            addon.Clean(place.y, "number") == y and addon.Clean(place.objectID, "number") == objectID and C_Map == library and issecretvalue == checker and
            GetLocale == localeGetter and (not library or addon.Clean(library.GetMapInfo, "function") == mapGetter) and
            addon.Clean(addon.GiverName, "function") == giverGetter and addon.Clean(addon.QuestName, "function") == questGetter and
            addon.Clean(addon.db, "table") == database and (not database or addon.Clean(database.locale, "string") == choice) and
            (not sourceProof or addon.Read(sourceProof, "boolean") == true) and addon.SourceName == sourceGetter and
            navigationGeneration == generation and rawequal(target, action) and rawequal(action.place, place) and
            rawequal(rawget(place, "mapID"), mapID) and rawequal(rawget(place, "x"), x) and rawequal(rawget(place, "y"), y)
    end
    if not current() then return nil end
    local title = actionTitle(action)
    if not current() then return nil end
    local giver
    if kind ~= "entrance" and type(sourceGetter) == "function" then
        local ok, localized, proof = pcall(sourceGetter, place, current)
        if not current() then return nil end
        proof = addon.Clean(proof, "function")
        if ok and proof and addon.Read(proof, "boolean") == true then
            sourceProof, giver = proof, addon.Clean(localized, "string")
        end
    end
    if not giver or #giver > 1024 or not giver:find("%S") then giver = kind ~= "entrance" and addon.Read(giverGetter, "string", place) or name end
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
    local shown, writeGeneration = presentation, {}
    presentationWrite = writeGeneration
    local function current()
        if navigationGeneration ~= generation or not rawequal(target, action) or
            presentation ~= shown or presentationWrite ~= writeGeneration then return false end
        if shown and not shown.current() then return false end
        return navigationGeneration == generation and rawequal(target, action) and
            presentation == shown and presentationWrite == writeGeneration
    end
    local function ownedWrite(object, key, value, apply)
        if not current() then return false end
        local binding = { current = current, value = value, apply = apply }
        object[key] = binding
        apply(object, value, current)
        if current() then return true end
        -- A setter wrapper may resume its old write after rendering a new guide.
        -- Restore only that newer owned value, once, without rerender/navigation.
        local newer = object[key]
        if newer ~= binding and newer and newer.current() and not newer.repairing then
            newer.repairing = true
            if object[key] == newer and newer.current() then pcall(newer.apply, object, newer.value, newer.current, true) end
            newer.repairing = nil
        end
        return false
    end
    local function text(region, value, isCurrent)
        if not isCurrent() then return end
        local getter = addon.Clean(region.GetText, "function")
        local actual = addon.Read(getter, "string", region)
        if not isCurrent() then return end
        if getter and actual == value and region.GetText == getter then return end
        region:SetText(value)
    end
    local layoutCacheable = true
    local function anchor(region, y, isCurrent, force)
        if not isCurrent() then return end
        local previous = region.guideAnchorPaint
        local setter, clearer = region.SetPoint, region.ClearAllPoints
        if not force and layoutCacheable and previous and previous.generation == generation and previous.value == y and
            previous.setter == setter and previous.clearer == clearer then return end
        region:ClearAllPoints()
        if not isCurrent() then return end
        region:SetPoint("TOPLEFT", 66, y)
        if isCurrent() then region.guideAnchorPaint = { value = y, generation = generation, setter = setter, clearer = clearer } end
    end
    local function resize(region, value, isCurrent, force)
        if not isCurrent() then return end
        local previous, setter = region.guideHeightPaint, region.SetHeight
        if not force and layoutCacheable and previous and previous.generation == generation and previous.value == value and previous.setter == setter then return end
        region:SetHeight(value)
        if isCurrent() then region.guideHeightPaint = { value = value, generation = generation, setter = setter } end
    end
    if not ownedWrite(frame.title, "guideText", shown and shown.title or "", text) or
        not ownedWrite(frame.note, "guideText", shown and shown.destination or "", text) or
        not ownedWrite(frame.label, "guideText", status, text) then return end
    if not shown then return end
    local function height(region, fallback)
        local font, widthGetter, scaleGetter = addon.Clean(region.GetFont, "function"),
            addon.Clean(region.GetWidth, "function"), addon.Clean(region.GetEffectiveScale, "function")
        local ok, path, size, flags = pcall(function() if font then return font(region) end end)
        path, size, flags = addon.Clean(path, "string"), addon.Clean(size, "number"), addon.Clean(flags, "string")
        local width, scale = addon.Read(widthGetter, "number", region), addon.Read(scaleGetter, "number", region)
        if not current() then return fallback end
        local cacheable = ok and path and size and size > 0 and flags and width and width > 0 and scale and scale > 0 and
            region.GetFont == font and region.GetWidth == widthGetter and region.GetEffectiveScale == scaleGetter
        layoutCacheable = layoutCacheable and cacheable and true or false
        local previous, getter = region.guideMeasurement, region.GetStringHeight
        local value = region.guideText and region.guideText.value
        if not cacheable then region.guideMeasurement = nil end
        if cacheable and previous and previous.generation == generation and previous.value == value and previous.path == path and previous.size == size and
            previous.flags == flags and previous.width == width and previous.scale == scale and previous.getter == getter and
            previous.font == font and previous.widthGetter == widthGetter and previous.scaleGetter == scaleGetter then return previous.height end
        local measured = addon.Read(getter, "number", region)
        if not current() then return fallback end
        if measured and measured > 0 and measured <= 4096 then
            if cacheable then region.guideMeasurement = { generation = generation, value = value, path = path, size = size, flags = flags,
                width = width, scale = scale, getter = getter, height = measured,
                font = font, widthGetter = widthGetter, scaleGetter = scaleGetter } end
            return measured
        end
        region.guideMeasurement = nil
        return fallback
    end
    local titleHeight = height(frame.title, 22)
    if not current() then return end
    local noteHeight = height(frame.note, 18)
    if not current() then return end
    local statusHeight = height(frame.label, 18)
    if not current() then return end
    if not ownedWrite(frame.note, "guideAnchor", -12 - titleHeight - 5, anchor) or
        not ownedWrite(frame.label, "guideAnchor", -12 - titleHeight - 5 - noteHeight - 5, anchor) then return end
    ownedWrite(frame, "guideHeight", math.max(82, 12 + titleHeight + 5 + noteHeight + 5 + statusHeight + 12), resize)
end

local function update(_, delta)
    delta = addon.Clean(delta, "number")
    if not delta or delta < 0 then return end
    elapsed, contextElapsed = elapsed + delta, contextElapsed + delta
    if elapsed < 0.1 then return end
    elapsed = 0
    local action, generation = target, navigationGeneration
    if not action then return end
    local tick = {}; guideUpdate = tick
    local function current()
        return navigationGeneration == generation and rawequal(target, action) and guideUpdate == tick
    end
    local north, west
    if action then north, west = N.Vector(action.place) end
    if not current() then return end
    local facing = addon.Read(GetPlayerFacing, "number")
    if not current() then return end
    if not north or not west or not facing then
        if markerWrite(frame.arrow, "Hide", current) then present(action, generation, addon.L("NO_POSITION")) end
        return
    end
    local distance = addon.Clean(math.sqrt(north * north + west * west), "number")
    if not distance then
        if markerWrite(frame.arrow, "Hide", current) then present(action, generation, addon.L("NO_POSITION")) end
        return
    end
    if not markerWrite(frame.arrow, "SetRotation", current, math.atan2(west, north) - facing) or
        not markerWrite(frame.arrow, "Show", current) then return end
    present(action, generation, addon.L("GUIDE_DISTANCE", math.floor(distance)))
end

function N.Start(action)
    if not action or not N.Valid(action.place) then return false end
    local generation = N.Stop()
    if not N.Valid(action.place) or target or navigationGeneration ~= generation then return false end
    target = action
    local function current()
        return navigationGeneration == generation and rawequal(target, action)
    end
    local p, owner = action.place, TomTom
    local title = actionTitle(action)
    if not current() then return false end
    if action.place ~= p or not N.Valid(p) then
        if current() then N.Stop() end
        return false
    end
    if not current() then return false end
    if owner and type(owner.AddWaypoint) == "function" then
        local add, exists, remove, checker = owner.AddWaypoint, addon.Clean(owner.WaypointExists, "function"),
            addon.Clean(owner.RemoveWaypoint, "function"), issecretvalue
        local mapID, pointX, pointY = addon.Clean(p.mapID, "number"), addon.Clean(p.x, "number"), addon.Clean(p.y, "number")
        local x, y = pointX and pointX / 100, pointY and pointY / 100
        local absent = mapID and x and y and N.Valid({ mapID = mapID, x = pointX, y = pointY }) and
            addon.Read(exists, "boolean", owner, mapID, x, y, title) == false
        if not current() then return false end
        if absent and remove and TomTom == owner and issecretvalue == checker and owner.AddWaypoint == add and
            owner.WaypointExists == exists and owner.RemoveWaypoint == remove and action.place == p and
            rawequal(rawget(p, "mapID"), mapID) and rawequal(rawget(p, "x"), pointX) and
            rawequal(rawget(p, "y"), pointY) and current() then
            -- TomTom returns an existing UID for duplicate coordinates/title. Only
            -- a new UID copies options, so the per-call token proves creation.
            local token = {}
            local ok, uid = pcall(add, owner, mapID, x, y,
                { title = title, persistent = false, minimap = true, world = true, dungeonProOwner = token })
            local valid = ok and addon.Clean(uid, "table")
            local marker = valid and addon.Clean(rawget(valid, "dungeonProOwner"), "table")
            local created = marker and rawequal(marker, token) and issecretvalue == checker and
                rawequal(rawget(valid, "dungeonProOwner"), token)
            if not current() then
                if created and not (rawequal(tomtomOwner, owner) and rawequal(tomtomUID, valid)) and
                    owner.RemoveWaypoint == remove then
                    pcall(remove, owner, valid)
                end
                return false
            end
            if created then tomtomOwner, tomtomUID, tomtomRemoval = owner, valid, remove end
        end
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
                    if owned and not capabilitiesCurrent() then
                        releaseNativePoint(pin, generation)
                        owned = false
                    end
                    if owned then nativePoint, pendingNativeCleanup = pin, nil end
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
        if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame.arrow = frame:CreateTexture(nil, "ARTWORK")
        frame.arrow:SetSize(42, 42); frame.arrow:SetPoint("TOPLEFT", 12, -16)
        frame.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
        local font = (addon.Clean(ChatFontNormal, "table") or addon.Clean(ChatFontNormal, "userdata")) and "ChatFontNormal" or "GameFontNormal"
        frame.title = frame:CreateFontString(nil, "OVERLAY", font)
        frame.title:SetPoint("TOPLEFT", 66, -12); frame.title:SetWidth(258); frame.title:SetJustifyH("LEFT")
        frame.note = frame:CreateFontString(nil, "OVERLAY", font)
        frame.note:SetWidth(258); frame.note:SetJustifyH("LEFT")
        frame.label = frame:CreateFontString(nil, "OVERLAY", font)
        frame.label:SetWidth(258); frame.label:SetJustifyH("LEFT")
        local theme = addon.Clean(addon.Theme, "table")
        if theme then
            if addon.Clean(theme.ApplyFont, "function") then
                pcall(theme.ApplyFont, frame.title, 16)
                pcall(theme.ApplyFont, frame.note, 14)
                pcall(theme.ApplyFont, frame.label, 14)
            end
            addon.Read(theme.StyleRow, "boolean", frame, { kind = "section" })
        end
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetSize(22, 22); close:SetPoint("TOPRIGHT"); close:SetScript("OnClick", N.Stop)
        if theme then addon.Read(theme.StyleCloseButton, "boolean", close) end
        frame:SetScript("OnUpdate", update)
    end
    if not current() then return false end
    local combatGetter = addon.Clean(InCombatLockdown, "function")
    local inCombat = addon.Read(combatGetter, "boolean")
    if not current() then return false end
    if inCombat == false and InCombatLockdown == combatGetter then
        local strataSetter = addon.Clean(frame.SetFrameStrata, "function")
        if not current() then return false end
        if strataSetter then pcall(strataSetter, frame, "DIALOG") end
        if not current() then return false end
        local ui = addon.Clean(addon.UI, "table")
        local planner = ui and (addon.Clean(ui.frame, "table") or addon.Clean(ui.frame, "userdata"))
        local highest = planner and addon.Clean(planner.GetHighestFrameLevel, "function")
        if not current() then return false end
        local level = highest and addon.Read(highest, "number", planner, true)
        if not current() then return false end
        -- Bound the local raise policy independently of the client's level limits.
        if level and level >= 0 and level <= 100000 and level % 1 == 0 then
            local setter = addon.Clean(frame.SetFrameLevel, "function")
            local outsideCombat = addon.Read(combatGetter, "boolean") == false
            if not current() then return false end
            if setter and outsideCombat and InCombatLockdown == combatGetter and addon.UI == ui and
                (addon.Clean(ui.frame, "table") or addon.Clean(ui.frame, "userdata")) == planner and
                addon.Clean(planner.GetHighestFrameLevel, "function") == highest and current() then
                pcall(setter, frame, level + 1)
            end
        end
        if not current() then return false end
    end
    if not setVisible(true, action, generation) then return false end
    if not current() then return false end
    elapsed = 0.1; update(frame, 0)
    if not current() then return false end
    N.Map(p)
    return current()
end

-- Entrances have dungeon identity; they are never represented as quest IDs.
function N.StartEntrance(dungeon, place)
    if type(dungeon) ~= "table" or type(dungeon.key) ~= "string" or dungeon.key == "" then return false end
    if not place and addon.Entrances and type(addon.Entrances.Get) == "function" then
        place = addon.Entrances.Get(dungeon)
    end
    if not N.Valid(place) then return false end
    return N.Start({ kind = "entrance", dungeon = dungeon, place = place })
end
