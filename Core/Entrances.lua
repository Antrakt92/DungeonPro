local _, addon = ...
local E = {}
addon.Entrances = E
local cache

local function identity(value)
    value = addon.Clean(value, "number")
    if value and value > 0 and value <= 9007199254740991 and value % 1 == 0 then return value end
end

local function field(object, key, kind)
    return addon.Read(function() return object[key] end, kind)
end

local function current(c)
    return cache == c and addon.Entrances == E and addon.quests == c.quests and addon.dungeons == c.dungeons and
        C_EncounterJournal == c.library and issecretvalue == c.checker and
        field(c.library, "GetInstanceForGameMap", "function") == c.join and
        field(c.library, "GetDungeonEntrancesForMap", "function") == c.list
end

local function context()
    local library = addon.Clean(C_EncounterJournal, "table")
    local join = library and field(library, "GetInstanceForGameMap", "function")
    local list = library and field(library, "GetDungeonEntrancesForMap", "function")
    local quests, dungeons = addon.Clean(addon.quests, "table"), addon.Clean(addon.dungeons, "table")
    if not join or not list or not quests or not dungeons then return end
    if cache and current(cache) then return cache end
    cache = { library = library, join = join, list = list, quests = quests, dungeons = dungeons,
        checker = issecretvalue, indexes = {}, results = {}, journals = {} }
    return cache
end

local function mapsFor(c, dungeon)
    local maps, seen, visited = {}, {}, 0
    local function place(p)
        p = addon.Clean(p, "table")
        local id = p and identity(rawget(p, "mapID"))
        if id and not seen[id] and #maps < 64 then seen[id] = true; maps[#maps + 1] = id end
    end
    local function quest(q)
        q = addon.Clean(q, "table")
        if not q then return end
        place(rawget(q, "start")); place(rawget(q, "finish"))
        for _, key in ipairs({ "startAlternatives", "finishAlternatives" }) do
            local alternatives = addon.Clean(rawget(q, key), "table")
            for index = 1, math.min(alternatives and #alternatives or 0, 100) do place(rawget(alternatives, index)) end
        end
    end
    local members = addon.Clean(rawget(dungeon, "quests"), "table")
    for index = 1, math.min(members and #members or 0, 1000) do
        local id = identity(rawget(members, index))
        if id then quest(rawget(c.quests, id)) end
    end
    -- These are only candidate map identities. An exact native journal-ID match proves the destination.
    for _, q in pairs(c.quests) do
        visited = visited + 1
        if visited > 2000 then break end
        quest(q)
    end
    return maps
end

local function indexMap(c, mapID)
    local held = c.indexes[mapID]
    if held and (held.rows or held.attempts >= 2) then return held.rows end
    held = held or { attempts = 0 }; c.indexes[mapID] = held
    held.attempts = held.attempts + 1
    local rows = addon.Read(c.list, "table", mapID)
    if not current(c) or not rows then return end
    local result = {}
    for index = 1, math.min(#rows, 128) do
        local row = addon.Clean(rawget(rows, index), "table")
        local journal = row and identity(rawget(row, "journalInstanceID"))
        local poi = row and identity(rawget(row, "areaPoiID"))
        local name = row and addon.Clean(rawget(row, "name"), "string")
        local position = row and (addon.Clean(rawget(row, "position"), "table") or addon.Clean(rawget(row, "position"), "userdata"))
        local getter = position and field(position, "GetXY", "function")
        if journal and poi and name and #name > 0 and #name <= 500 and getter then
            local ok, x, y = pcall(getter, position)
            x, y = addon.Clean(x, "number"), addon.Clean(y, "number")
            if not current(c) then return end
            local positionNow = addon.Clean(rawget(row, "position"), "table") or addon.Clean(rawget(row, "position"), "userdata")
            if ok and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 and
                addon.Clean(rawget(rows, index), "table") == row and identity(rawget(row, "journalInstanceID")) == journal and
                identity(rawget(row, "areaPoiID")) == poi and addon.Clean(rawget(row, "name"), "string") == name and
                positionNow == position and field(position, "GetXY", "function") == getter then
                result[#result + 1] = { journal = journal, place = { mapID = mapID, x = x * 100, y = y * 100,
                    name = name, areaPoiID = poi } }
            end
        end
    end
    if not current(c) then return end
    -- Empty results remain unknown and get at most one later retry in this source/API context.
    if #result > 0 then held.rows = result end
    return result
end

local function nativeEntrance(dungeon)
    dungeon = addon.Clean(dungeon, "table")
    local c = dungeon and context()
    local gameMap = dungeon and identity(rawget(dungeon, "instanceID"))
    if not c or not current(c) or not gameMap or rawget(dungeon, "wing") ~= nil then return end
    local owned, shared = false, 0
    for index = 1, math.min(#c.dungeons, 100) do
        local d = addon.Clean(rawget(c.dungeons, index), "table")
        if d == dungeon then owned = true end
        if d and identity(rawget(d, "instanceID")) == gameMap then shared = shared + 1 end
    end
    if not owned or shared ~= 1 then return end
    local function valid()
        if not current(c) or identity(rawget(dungeon, "instanceID")) ~= gameMap or rawget(dungeon, "wing") ~= nil then return false end
        local found, count = false, 0
        for index = 1, math.min(#c.dungeons, 100) do
            local d = addon.Clean(rawget(c.dungeons, index), "table")
            if d == dungeon then found = true end
            if d and identity(rawget(d, "instanceID")) == gameMap then count = count + 1 end
        end
        return found and count == 1
    end
    local old = c.results[dungeon]
    if old and old.gameMap == gameMap and valid() then return old.place, valid end
    local joined = c.journals[dungeon]
    if not joined or joined.gameMap ~= gameMap then joined = { attempts = 0, gameMap = gameMap }; c.journals[dungeon] = joined end
    local journal = joined.value
    if not journal and joined.attempts < 2 then
        joined.attempts = joined.attempts + 1
        journal = identity(addon.Read(c.join, "number", gameMap))
        if valid() then joined.value = journal end
    end
    if not journal or not valid() then return end
    for _, mapID in ipairs(mapsFor(c, dungeon)) do
        local rows = indexMap(c, mapID)
        if not valid() then return end
        for _, row in ipairs(rows or {}) do
            if row.journal == journal then c.results[dungeon] = { place = row.place, gameMap = gameMap }; return row.place, valid end
        end
    end
end

local function recordedEntrance(dungeon)
    dungeon = addon.Clean(dungeon, "table")
    local dungeons = addon.Clean(addon.dungeons, "table")
    local entry = dungeon and addon.Clean(rawget(dungeon, "entrance"), "table")
    local gameMap = dungeon and identity(rawget(dungeon, "instanceID"))
    local sourceMap = entry and identity(rawget(entry, "gameMapID"))
    local mapID = entry and identity(rawget(entry, "mapID"))
    local x = entry and addon.Clean(rawget(entry, "x"), "number")
    local y = entry and addon.Clean(rawget(entry, "y"), "number")
    local source = entry and addon.Clean(rawget(entry, "source"), "string")
    local name = dungeon and addon.Clean(rawget(dungeon, "name"), "string")
    local key = dungeon and addon.Clean(rawget(dungeon, "key"), "string")
    local wing = dungeon and addon.Clean(rawget(dungeon, "wing"), "string")
    local scope = entry and addon.Clean(rawget(entry, "scope"), "string")
    local kind = entry and addon.Clean(rawget(entry, "kind"), "string")
    if not entry or not dungeons or not mapID or not x or not y or x < 0 or x > 100 or y < 0 or y > 100 or
        (rawget(dungeon, "instanceID") ~= nil and not gameMap) or sourceMap ~= gameMap or
        (rawget(entry, "gameMapID") ~= nil and not sourceMap) or not source or #source > 2048 or
        not name or #name == 0 or #name > 500 or not key or #key > 100 or
        (rawget(dungeon, "wing") ~= nil and wing ~= "lower" and wing ~= "upper") or
        (wing and scope ~= "shared") or (rawget(entry, "scope") ~= nil and scope ~= "shared") or
        (rawget(entry, "kind") ~= nil and kind ~= "approach") then return end
    local reviewed = (gameMap and source == "https://phylactery.io/instance/" .. gameMap) or
        source:match("^https://wowhandbook%.com/zones/dungeons/[a-z0-9%-]+/$") or
        source:match("^https://www%.warcrafttavern%.com/forever/guides/[a-z0-9%-]+/$") or
        source:match("^https://warcrafttavern%.com/forever/guides/[a-z0-9%-]+/$") or
        source:match("^https://www%.wowhead%.com/forever/guide/[a-z0-9%-]+$") or
        source:match("^https://www%.wowhead%.com/forever/zone=[1-9]%d*$") or
        source:match("^https://www%.wowhead%.com/forever/zone=[1-9]%d*/[a-z0-9%-]+$")
    if not reviewed then return end
    local point = { mapID = mapID, x = x, y = y, name = name, origin = "recorded", source = source, scope = scope, kind = kind }
    local function valid()
        local fieldsMatch = addon.Read(function()
            return rawget(dungeon, "instanceID") == gameMap and rawget(dungeon, "wing") == wing and
                rawget(entry, "gameMapID") == sourceMap and rawget(entry, "scope") == scope and rawget(entry, "kind") == kind
        end, "boolean")
        if fieldsMatch ~= true then return false end
        if addon.Entrances ~= E or addon.dungeons ~= dungeons or rawget(dungeon, "entrance") ~= entry or
            identity(rawget(dungeon, "instanceID")) ~= gameMap or addon.Clean(rawget(dungeon, "key"), "string") ~= key or
            addon.Clean(rawget(dungeon, "wing"), "string") ~= wing or
            addon.Clean(rawget(dungeon, "name"), "string") ~= name or
            identity(rawget(entry, "gameMapID")) ~= gameMap or identity(rawget(entry, "mapID")) ~= mapID or
            addon.Clean(rawget(entry, "x"), "number") ~= x or addon.Clean(rawget(entry, "y"), "number") ~= y or
            addon.Clean(rawget(entry, "source"), "string") ~= source or
            addon.Clean(rawget(entry, "scope"), "string") ~= scope or addon.Clean(rawget(entry, "kind"), "string") ~= kind or
            identity(point.mapID) ~= mapID or
            addon.Clean(point.x, "number") ~= x or addon.Clean(point.y, "number") ~= y then return false end
        local found, shared = false, 0
        for index = 1, math.min(#dungeons, 100) do
            local member = addon.Clean(rawget(dungeons, index), "table")
            if member == dungeon then found = true end
            if member and identity(rawget(member, "instanceID")) == gameMap then shared = shared + 1 end
        end
        return found and (shared == 1 or scope == "shared" or not gameMap) and addon.Entrances == E and addon.dungeons == dungeons
    end
    if valid() then return point, valid end
end

function E.Get(dungeon)
    local point, valid = nativeEntrance(dungeon)
    if point then return point, valid end
    return recordedEntrance(dungeon)
end
