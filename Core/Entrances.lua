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

function E.Get(dungeon)
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
