-- Recorded NPC goals add typed objective matches after existing source terms.
local a = {}
for _, path in ipairs({ 'Core/Namespace.lua', 'Core/Client.lua', 'Database/Catalog.lua',
    'Database/NameTranslations.lua', 'Database/SearchCaseFold.lua', 'Core/Search.lua' }) do
    assert(loadfile(path))('DungeonPro', a)
end
local passed, failures = 0, {}
local function setup()
    issecretvalue = function() return false end
    GetLocale = function() return 'enUS' end
    a.db, a.Language, a.nameTranslationFactories = { locale = 'ruRU' }, nil, nil
    a.nameTranslations = { ruRU = { quests = {}, dungeons = {}, objects = {}, npcs = {}, areas = {} } }
    a.sourceAreaNames = {}
    C_QuestLog = { RequestLoadQuestByID = function() error('goal search must not hydrate quests') end }
    C_Item = { RequestLoadItemDataByID = function() error('goal search must not hydrate items') end }
end
local function check(name, callback)
    setup()
    local ok, message = pcall(callback)
    if ok then passed = passed + 1; print('PASS ' .. name)
    else failures[#failures + 1] = name .. ': ' .. tostring(message); print('FAIL ' .. failures[#failures]) end
end
local function has(terms, text, kind)
    for _, term in ipairs(terms) do if term.text == text and (not kind or term.kind == kind) then return term end end
end
local function sourceQuest()
    return { start = { npcID = 1, name = 'Existing giver' },
        objectiveKills = { { npcID = 11519, name = 'Bazzalan' } } }
end

check('Actual Hidden Enemies exposes typed Bazzalan without inventing a quantity', function()
    local q = a.quests[5728]
    assert(q.objectiveKills[1].npcID == 11519 and q.objectiveKills[1].quantity == nil)
    local terms, current, raw = a.QuestSourceSearchTerms(q)
    assert(has(terms, 'Bazzalan', 'objective'), 'actual Bazzalan objective is missing')
    assert(has(terms, 'Jergosh the Invoker', 'objective') and current() and raw())
    assert(not has(terms, 'Bazzalan', 'npc') and not has(terms, 'Bazzalan', 'place'))
    assert(q.objectiveKills[1].quantity == nil)
end)

check('Reviewed objective aliases use exact NPC identity and remain separate from giver matches', function()
    a.nameTranslations.ruRU.npcs[11519] = { source = 'Bazzalan', name = 'Reviewed target label' }
    a.nameTranslations.ruRU.objects[11519] = { source = 'Bazzalan', name = 'Wrong object label' }
    local q = sourceQuest(); q.start = { npcID = 11519, name = 'Bazzalan' }
    local terms, current, raw = a.QuestSourceSearchTerms(q)
    assert(has(terms, 'Bazzalan', 'npc') and has(terms, 'Bazzalan', 'objective'))
    assert(has(terms, 'Reviewed target label', 'objective') and not has(terms, 'Wrong object label'))
    assert(terms[1].kind == 'npc' and current() and raw())
    q.objectiveKills[1].name = 'Other canonical target'
    terms = a.QuestSourceSearchTerms(q)
    assert(not has(terms, 'Reviewed target label', 'objective'), 'a mismatched canonical target cannot borrow an alias')
end)

check('Goal absence and every consumed list or identity binding expire retained proofs', function()
    local q = { start = { npcID = 1, name = 'Existing giver' } }
    local _, current, raw = a.QuestSourceSearchTerms(q); assert(current() and raw())
    q.objectiveKills = sourceQuest().objectiveKills; assert(not current() and not raw())
    for _, mutate in ipairs({
        function(v) v.objectiveKills = {} end,
        function(v) v.objectiveKills[1] = { npcID = 2, name = 'Replacement' } end,
        function(v) v.objectiveKills[1].npcID = 2 end,
        function(v) v.objectiveKills[1].name = 'Renamed' end,
        function(v) v.objectiveKills[1].objectID = 2 end,
        function(v) v.objectiveKills[2] = { npcID = 2, name = 'Added' } end,
    }) do
        q = sourceQuest(); _, current, raw = a.QuestSourceSearchTerms(q)
        assert(current() and raw()); mutate(q); assert(not current() and not raw())
    end
end)

check('Malformed goal arrays cannot add partial targets or replace existing source terms', function()
    local arrays = {
        { [2] = { npcID = 11519, name = 'Bazzalan' } },
        { { npcID = 11519, name = 'Bazzalan' }, extra = true },
        { { npcID = 11519, name = 'Bazzalan', objectID = 7 } },
        { { npcID = 11519, name = 'Bazzalan', itemID = 7 } },
        { { npcID = 11519, name = 'Bazzalan', dropNPCID = 7 } },
        { { npcID = 11519, name = 'Bazzalan' }, { npcID = 11519, name = 'Duplicate' } },
        { { npcID = 4294967296, name = 'Overflow' } },
    }
    local huge = {}; for index = 1, 101 do huge[index] = { npcID = index, name = 'Goal ' .. index } end
    arrays[#arrays + 1] = huge
    local overflowing = {}; for index = 1, 103 do overflowing[index] = { npcID = index, name = 'Overflow ' .. index } end
    arrays[#arrays + 1] = overflowing
    for _, goals in ipairs(arrays) do
        local q = sourceQuest(); q.objectiveKills = goals
        local terms, current, raw = a.QuestSourceSearchTerms(q)
        assert(has(terms, 'Existing giver', 'npc') and current() and raw())
        for _, term in ipairs(terms) do assert(term.kind ~= 'objective') end
    end
    local q = { start = { npcID = 1, name = 'Existing giver' },
        objectiveEvents = { { npcID = 11519, name = 'Bazzalan' } } }
    local terms = a.QuestSourceSearchTerms(q)
    assert(has(terms, 'Existing giver') and not has(terms, 'Bazzalan'), 'other goal roles remain outside kill-name search')
end)

check('Bounded invalid goal snapshots expire when the same array becomes valid', function()
    for _, mode in ipairs({ 'overflow', 'sparse', 'mixed' }) do
        local q = sourceQuest()
        if mode == 'overflow' then
            q.objectiveKills = {}
            for i = 1, 103 do q.objectiveKills[i] = { npcID = i, name = 'Goal ' .. i } end
        elseif mode == 'sparse' then q.objectiveKills = { [2] = q.objectiveKills[1] }
        else q.objectiveKills[1].objectID = 7 end
        local terms, current, raw = a.QuestSourceSearchTerms(q)
        assert(has(terms, 'Existing giver') and current() and raw())
        for _, term in ipairs(terms) do assert(term.kind ~= 'objective') end
        if mode == 'overflow' then for i = 101, 103 do q.objectiveKills[i] = nil end
        elseif mode == 'sparse' then q.objectiveKills[1], q.objectiveKills[2] = q.objectiveKills[2], nil
        else q.objectiveKills[1].objectID = nil end
        assert(not current() and not raw(), 'same-array repair must expire an earlier invalid snapshot')
        terms, current, raw = a.QuestSourceSearchTerms(q)
        assert(has(terms, mode == 'overflow' and 'Goal 1' or 'Bazzalan', 'objective') and current() and raw())
    end
end)

check('Counts and navigation-only fields are not read or promoted into search facts', function()
    local q = sourceQuest(); local goal = q.objectiveKills[1]
    setmetatable(goal, { __index = function(_, key)
        if key == 'quantity' or key == 'mapID' or key == 'x' or key == 'y' or key == 'source' then error('unconsumed field read: ' .. key) end
    end })
    local terms, current, raw = a.QuestSourceSearchTerms(q)
    assert(has(terms, 'Bazzalan', 'objective') and current() and raw())
    goal.quantity = 99; goal.mapID = 123; goal.x = .5; goal.y = .5
    assert(current() and raw(), 'unconsumed facts do not change name membership')
end)

check('Early cleaners and alias callbacks cannot silently rebind goal inputs', function()
    local q = sourceQuest(); local clean = a.Clean; local fired = false
    a.Clean = function(value, kind)
        if value == q and not fired then fired = true; q.objectiveKills[1].name = 'Changed during initial clean' end
        return clean(value, kind)
    end
    local terms, current = a.QuestSourceSearchTerms(q); a.Clean = clean
    assert(fired and #terms == 0 and not current())
    q = sourceQuest(); local checker = issecretvalue; fired = false; local arrayReads = 0
    issecretvalue = function(value)
        if value == q.objectiveKills then arrayReads = arrayReads + 1 end
        -- The first classification authorizes reading shape; this later one
        -- occurs after the goal fields have been captured.
        if value == q.objectiveKills and arrayReads == 2 and not fired then fired = true; q.objectiveKills[1].name = 'Changed during classification' end
        return false
    end
    terms, current = a.QuestSourceSearchTerms(q); issecretvalue = checker
    assert(fired and #terms == 0 and not current())
    q = sourceQuest(); local helper = a.SourceName; fired = false
    a.SourceName = function(place, ...)
        local name, valid, raw = helper(place, ...)
        if place == q.objectiveKills[1] then fired = true; place.npcID = 9 end
        return name, valid, raw
    end
    terms, current = a.QuestSourceSearchTerms(q); a.SourceName = helper
    assert(fired and #terms == 0 and not current())
end)

check('Staged classification rejects replaced slots and accepts coherent unread member changes', function()
    local q = sourceQuest(); local checker = issecretvalue; local fired = false
    issecretvalue = function(value)
        if value == q.objectiveKills and not fired then
            fired = true; q.objectiveKills = { { npcID = 7, name = 'Replaced list' } }
        end
        return false
    end
    local terms, current = a.QuestSourceSearchTerms(q)
    assert(fired and #terms == 0 and not current()); issecretvalue = checker
    q = sourceQuest(); fired = false
    issecretvalue = function(value)
        if value == q.objectiveKills and not fired then fired = true; q.objectiveKills[1].name = 'Fresh unread target' end
        return false
    end
    local raw
    terms, current, raw = a.QuestSourceSearchTerms(q)
    assert(fired and has(terms, 'Fresh unread target', 'objective') and not has(terms, 'Bazzalan'))
    assert(current() and raw(), 'no earlier member name was consumed before authorized capture')
    issecretvalue = checker
end)

check('Restricted roots arrays and members stop before unauthorized structural reads', function()
    for _, mode in ipairs({ 'root', 'array', 'member' }) do
        local q = sourceQuest()
        local blocked = mode == 'root' and q or mode == 'array' and q.objectiveKills or q.objectiveKills[1]
        local checker, minimum, get = issecretvalue, math.min, rawget
        local unsafe = false
        issecretvalue = function(value) return value == blocked end
        math.min = function(...)
            if mode ~= 'member' then unsafe = true end
            return minimum(...)
        end
        rawget = function(object, key)
            if mode == 'member' and object == blocked then unsafe = true end
            return get(object, key)
        end
        local terms, current = a.QuestSourceSearchTerms(q)
        issecretvalue, math.min, rawget = checker, minimum, get
        assert(not unsafe, mode .. ' entered structural/member reads before ordinary classification')
        assert(#terms == 0 and not current())
    end
end)

check('Every old source and area term keeps its order and full budget ahead of goals', function()
    local canonical = a.quests[2204].start.name
    a.nameTranslations.ruRU.objects[112877] = { source = canonical, name = 'Reviewed bowl alias' }
    a.sourceAreaNames.Ironforge = { name = 'Ironforge' }
    a.nameTranslations.ruRU.areas.Ironforge = { source = 'Ironforge', name = 'Reviewed area alias' }
    local q = { start = { objectID = 112877, name = canonical, zoneName = 'Ironforge' }, startAlternatives = {} }
    for i = 1, 100 do
        local p = { mapID = i, zoneName = 'Zone' .. i, reportedLocations = {} }
        for j = 1, (i <= 21 and 10 or 9) do p.reportedLocations[j] = { mapID = i, zoneName = i .. ':' .. j } end
        q.startAlternatives[i] = p
    end
    local baseline = a.QuestSourceSearchTerms(q); assert(#baseline == 1024 and has(baseline, 'Reviewed bowl alias'))
    q.objectiveKills = sourceQuest().objectiveKills
    local terms, current, raw = a.QuestSourceSearchTerms(q)
    assert(#terms == #baseline and current() and raw())
    for index, term in ipairs(baseline) do assert(terms[index].text == term.text and terms[index].kind == term.kind) end
    assert(not has(terms, 'Bazzalan'), 'new goals cannot evict an old reviewed source alias')
end)

check('Missing reviewed aliases and returned goal term fields remain owned', function()
    local q = sourceQuest(); local terms, current, raw = a.QuestSourceSearchTerms(q)
    assert(current() and raw())
    a.nameTranslations.ruRU.npcs[11519] = { source = 'Bazzalan', name = 'New reviewed alias' }
    assert(not current() and not raw())
    terms, current, raw = a.QuestSourceSearchTerms(q)
    local goal = assert(has(terms, 'New reviewed alias', 'objective'))
    goal.kind = 'npc'; assert(not current() and not raw())
end)

assert(#failures == 0, table.concat(failures, '\n'))
print('Objective target search: PASS ' .. passed .. ' groups; no native hydration or navigation')
