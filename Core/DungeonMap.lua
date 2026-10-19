local _, addon = ...

-- Native map identities and artwork are optional; none are inferred from catalogue art or entrances.
function addon.DungeonMapSnapshot(dungeon, requestedMapID, ownerCurrent)
    local clean, read, checker = addon.Clean, addon.Read, issecretvalue
    local api, localeGetter = addon.DungeonMapSnapshot, GetLocale
    local library, map, enum = C_EncounterJournal, C_Map, Enum
    local instanceInfo = EJ_GetInstanceInfo
    local catalogue, character, database, language = addon.dungeons, addon.char, addon.db, addon.Language
    local maximum = 9007199254740991
    -- Hold authored catalogue identities before even validation can call out.
    local sourceFields, sources, sourceCount = { "instanceID", "name", "key", "wing" }, {}, nil
    local captured = pcall(function()
        sourceCount = #catalogue
        if sourceCount < 1 or sourceCount > 100 then error("invalid catalogue") end
        for index = 1, sourceCount do
            local member, values = rawget(catalogue,index), {}
            for _, field in ipairs(sourceFields) do values[field] = rawget(member,field) end
            sources[index] = { member = member, values = values }
        end
    end)
    if not captured then return nil end
    local function readable(value)
        return type(checker) ~= "function" or read(checker,"boolean",value) == false
    end
    local function integer(value)
        value = clean(value,"number")
        return value and value > 0 and value <= maximum and value % 1 == 0 and value or nil
    end
    local function text(value)
        if not readable(value) then return nil, false end
        if value == nil then return nil, true end
        value = clean(value,"string")
        if not value or #value > 1024 or not value:find("%S") or value:find("%c") then return nil, false end
        return value, true
    end
    if not clean(dungeon,"table") or not clean(catalogue,"table") or not clean(library,"table") or
        not clean(map,"table") or not clean(enum,"table") or not clean(instanceInfo,"function") or
        not clean(localeGetter,"function") then return nil end
    if not readable(requestedMapID) then return nil end
    local requested = requestedMapID ~= nil and integer(requestedMapID) or nil
    if requestedMapID ~= nil and not requested then return nil end
    local owner = clean(ownerCurrent,"function")
    if ownerCurrent ~= nil and not owner then return nil end
    local join = rawget(library,"GetInstanceForGameMap")
    local types = rawget(enum,"UIMapType")
    if not clean(join,"function") or not clean(types,"table") then return nil end
    local dungeonType, microType = rawget(types,"Dungeon"), rawget(types,"Micro")
    local required = { "GetMapInfo", "MapHasArt", "GetMapArtID", "GetMapArtLayers", "GetMapArtLayerTextures" }
    local methods = {}
    for _, key in ipairs(required) do
        local value = rawget(map,key)
        if not clean(value,"function") then return nil end
        methods[key] = value
    end
    local groupGetter, membersGetter = rawget(map,"GetMapGroupID"), rawget(map,"GetMapGroupMembersInfo")
    if not readable(groupGetter) or not readable(membersGetter) then return nil end
    local groupsAvailable = clean(groupGetter,"function") and clean(membersGetter,"function")
    local validDungeonType = integer(dungeonType)
    local validMicroType = readable(microType) and (microType == nil or integer(microType))
    if not validDungeonType or not validMicroType or dungeonType == microType then return nil end
    local choice = type(database) == "table" and rawget(database,"locale")
    local selection = type(language) == "table" and rawget(language,"GetSelection")
    local session = type(language) == "table" and rawget(language,"session")
    local preview = type(session) == "table" and rawget(session,"preview")
    local entries = 0
    for key in next, catalogue do
        key = integer(key); entries = entries + 1
        if not key or key > sourceCount or entries > sourceCount then return nil end
    end
    if entries ~= sourceCount then return nil end
    local gameMap, selected, sharedCount = nil, 0, 0
    for _, source in ipairs(sources) do
        for _, field in ipairs(sourceFields) do if not readable(source.values[field]) then return nil end end
        local id = source.values.instanceID
        local valid = id ~= nil and integer(id) or nil
        if id ~= nil and not valid then return nil end
        if source.member == dungeon then selected = selected + 1; gameMap = valid end
    end
    if selected ~= 1 or not gameMap then return nil end
    for _, source in ipairs(sources) do if source.values.instanceID == gameMap then sharedCount = sharedCount + 1 end end
    local building = true
    local function sourceCurrent()
        local ok, same = pcall(function()
            if addon.DungeonMapSnapshot ~= api or addon.Clean ~= clean or addon.Read ~= read or issecretvalue ~= checker or
                C_EncounterJournal ~= library or C_Map ~= map or Enum ~= enum or EJ_GetInstanceInfo ~= instanceInfo or
                GetLocale ~= localeGetter or addon.dungeons ~= catalogue or addon.char ~= character or addon.db ~= database or
                addon.Language ~= language or rawget(library,"GetInstanceForGameMap") ~= join or
                rawget(enum,"UIMapType") ~= types or rawget(types,"Dungeon") ~= dungeonType or rawget(types,"Micro") ~= microType or
                rawget(map,"GetMapGroupID") ~= groupGetter or rawget(map,"GetMapGroupMembersInfo") ~= membersGetter or
                #catalogue ~= sourceCount then return false end
            for key, fn in pairs(methods) do if rawget(map,key) ~= fn then return false end end
            local count = 0
            for _ in next, catalogue do
                count = count + 1
                if count > sourceCount then return false end
            end
            if count ~= sourceCount then return false end
            for index, source in ipairs(sources) do
                if not rawequal(rawget(catalogue,index),source.member) then return false end
                for _, field in ipairs(sourceFields) do
                    if not rawequal(rawget(source.member,field),source.values[field]) then return false end
                end
            end
            return (type(database) ~= "table" or rawequal(rawget(database,"locale"),choice)) and
                (type(language) ~= "table" or (rawequal(rawget(language,"GetSelection"),selection) and
                    rawequal(rawget(language,"session"),session))) and
                (type(session) ~= "table" or rawequal(rawget(session,"preview"),preview))
        end)
        return ok and same == true
    end
    local function owned()
        if not sourceCurrent() then return false end
        if building and owner and read(owner,"boolean") ~= true then return false end
        return sourceCurrent()
    end
    local function call(fn,...)
        if not owned() then return nil end
        local result = { pcall(fn,...) }
        if result[1] ~= true or not owned() then return nil end
        return result
    end
    local function capture(object, fields, exact, held)
        if not clean(object,"table") then return nil end
        local values, count = {}, 0
        for _, key in ipairs(fields) do values[key] = rawget(object,key) end
        if exact then
            for _ in next, object do count = count + 1; if count > #fields then return nil end end
            if count ~= #fields then return nil end
        end
        held[#held + 1] = { object = object, fields = fields, values = values, count = exact and count or nil,
            metatable = getmetatable(object) }
        return values
    end
    local function array(object, limit, held)
        if not clean(object,"table") then return nil end
        local count = #object
        if count < 1 or count > limit then return nil end
        local keys = {}; for index = 1, count do keys[index] = index end
        local values = capture(object,keys,true,held)
        if not values then return nil end
        local actual = 0
        for key in next, object do
            key = integer(key); actual = actual + 1
            if not key or key > count or actual > count then return nil end
        end
        if actual ~= count then return nil end
        return values
    end
    local function unchanged(held)
        for _, snapshot in ipairs(held) do
            if getmetatable(snapshot.object) ~= snapshot.metatable then return false end
            for _, key in ipairs(snapshot.fields) do
                if not rawequal(rawget(snapshot.object,key),snapshot.values[key]) then return false end
            end
            if snapshot.count then
                local count = 0
                for _ in next, snapshot.object do count = count + 1; if count > snapshot.count then return false end end
                if count ~= snapshot.count then return false end
            end
        end
        return true
    end
    local function nativeSnapshot()
        local held, observed = {}, {}
        local localeResult = call(localeGetter)
        local locale = localeResult and clean(localeResult[2],"string")
        if not locale or #locale > 32 or not locale:find("%S") then return nil end
        observed.locale = locale
        local joined = call(join,gameMap)
        local journal = joined and integer(joined[2])
        if not journal then return nil end
        local info = call(instanceInfo,journal)
        local base = info and integer(info[8])
        local reverse = info and integer(info[11])
        if not base or reverse ~= gameMap then return nil end
        local function mapInfo(id)
            local result = call(methods.GetMapInfo,id)
            local values = result and capture(result[2],{"mapID","mapType","name"},false,held)
            if not values then return nil end
            local identity, kind = integer(values.mapID), integer(values.mapType)
            local name, named = text(values.name)
            if identity ~= id or not kind or not named then return nil end
            return { mapID = identity, mapType = kind, name = name }
        end
        local baseInfo = mapInfo(base)
        if not baseInfo or baseInfo.mapType ~= dungeonType then return nil end
        observed.baseInfo = baseInfo
        local hasBase = call(methods.MapHasArt,base)
        local artBase = call(methods.GetMapArtID,base)
        if not hasBase or clean(hasBase[2],"boolean") ~= true or not artBase then return nil end
        observed.baseArtID = integer(artBase[2])
        if not observed.baseArtID then return nil end
        local floors, members, groupID = {}, {}, nil
        if groupsAvailable then
            local group = call(groupGetter,base)
            if not group or not readable(group[2]) then return nil end
            if group[2] ~= nil then
                groupID = integer(group[2]); if not groupID then return nil end
                local result = call(membersGetter,groupID)
                local list = result and array(result[2],32,held)
                if not list then return nil end
                local seen, containsBase = {}, false
                for _, value in ipairs(list) do
                    local fields = capture(value,{"mapID","name","relativeHeightIndex"},false,held)
                    if not fields then return nil end
                    local id, height = integer(fields.mapID), clean(fields.relativeHeightIndex,"number")
                    local name, named = text(fields.name)
                    if not id or seen[id] or not height or math.abs(height) > maximum or not name or not named then return nil end
                    local detail = mapInfo(id)
                    if not detail or (detail.mapType ~= dungeonType and detail.mapType ~= microType) then return nil end
                    seen[id], containsBase = true, containsBase or id == base
                    floors[#floors + 1] = { mapID = id, name = name, relativeHeightIndex = height }
                    members[#members + 1] = detail
                end
                if not containsBase then return nil end
            end
        end
        observed.groupID, observed.members = groupID, members
        local selectedMap = requested or base
        local selectedInfo = baseInfo
        if selectedMap ~= base then
            selectedInfo = nil
            for _, member in ipairs(members) do if member.mapID == selectedMap then selectedInfo = member end end
            if not selectedInfo then return nil end
        end
        local artID = observed.baseArtID
        if selectedMap ~= base then
            local hasArt = call(methods.MapHasArt,selectedMap)
            local art = call(methods.GetMapArtID,selectedMap)
            if not hasArt or clean(hasArt[2],"boolean") ~= true or not art then return nil end
            artID = integer(art[2]); if not artID then return nil end
        end
        local result = call(methods.GetMapArtLayers,selectedMap)
        local layers = result and array(result[2],16,held)
        if not layers then return nil end
        local chosen, area, index, normalized = nil, nil, nil, {}
        for layerIndex, value in ipairs(layers) do
            local fields = capture(value,{"layerWidth","layerHeight","tileWidth","tileHeight"},false,held)
            if not fields then return nil end
            local width, height = integer(fields.layerWidth), integer(fields.layerHeight)
            local tileWidth, tileHeight = integer(fields.tileWidth), integer(fields.tileHeight)
            if not width or not height or not tileWidth or not tileHeight or width > maximum / height then return nil end
            local columns, rows = math.ceil(width/tileWidth), math.ceil(height/tileHeight)
            if columns > 256 or rows > 256 or columns * rows > 256 then return nil end
            local layer = { width = width, height = height, tileWidth = tileWidth, tileHeight = tileHeight,
                columns = columns, rows = rows }
            normalized[layerIndex] = layer
            local size = width * height
            if not area or size < area then chosen, area, index = layer, size, layerIndex end
        end
        observed.layers = normalized
        local tileResult = call(methods.GetMapArtLayerTextures,selectedMap,index)
        local tiles = tileResult and array(tileResult[2],256,held)
        if not tiles or #tiles ~= chosen.columns * chosen.rows then return nil end
        local textures = {}
        for tileIndex, value in ipairs(tiles) do
            local id = integer(value); if not id then return nil end
            textures[tileIndex] = id
        end
        if not owned() or not unchanged(held) then return nil end
        return { gameMapID = gameMap, journalID = journal, baseMapID = base, mapID = selectedMap,
            artID = artID, layerIndex = index, name = selectedInfo.name, width = chosen.width, height = chosen.height,
            tileWidth = chosen.tileWidth, tileHeight = chosen.tileHeight, columns = chosen.columns, rows = chosen.rows,
            textures = textures, floors = floors, shared = sharedCount > 1 }, observed
    end
    local function equal(left,right)
        if type(left) ~= type(right) then return false end
        if type(left) ~= "table" then return rawequal(left,right) end
        for key, value in pairs(left) do if not equal(value,rawget(right,key)) then return false end end
        for key in pairs(right) do if rawget(left,key) == nil then return false end end
        return true
    end
    local ok, model, observed = pcall(nativeSnapshot)
    if not ok or not model then return nil end
    local modelHeld = {}
    local function own(value)
        local keys = {}
        for key, child in pairs(value) do
            keys[#keys + 1] = key
            if type(child) == "table" and not own(child) then return false end
        end
        return capture(value,keys,true,modelHeld) ~= nil
    end
    if not own(model) then return nil end
    local function rawCurrent()
        local valid, same = pcall(function() return sourceCurrent() and unchanged(modelHeld) end)
        return valid and same == true
    end
    local function current()
        if not rawCurrent() then return false end
        local valid, candidate, data = pcall(nativeSnapshot)
        return valid and candidate ~= nil and equal(candidate,model) and equal(data,observed) and rawCurrent()
    end
    if not current() or not owned() or not rawCurrent() then return nil end
    building, owner = false, nil
    return model, current, rawCurrent
end
