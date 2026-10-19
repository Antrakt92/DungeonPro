-- Reuse preflights batch pure reads without skipping final membership ownership.
local failures, passed = {}, 0
local function check(name, callback)
    local ok, message = pcall(callback)
    if ok then passed = passed + 1; print('PASS ' .. name)
    else failures[#failures + 1] = name .. ': ' .. tostring(message); print('FAIL ' .. failures[#failures]) end
end
local function fixture()
    local f = assert(loadfile('tests/client_ui.lua'))('fixture')
    local a, ui, queue = f.addon, f.addon.UI, {}
    issecretvalue = function() return false end
    GetLocale = function() return 'enUS' end
    UnitGUID = function() return 'Player-BatchProof' end
    C_Timer = { After = function(delay, callback) if delay == .1 then queue[#queue + 1] = callback end end }
    f.eventFrame.scripts.OnEvent(f.eventFrame, 'ADDON_LOADED', 'DungeonPro')
    ui:Toggle(); a.db.locale = 'enUS'; ui.range = false; ui.includeUnavailable = true
    local hydration = 0
    C_QuestLog.RequestLoadQuestByID = function() hydration = hydration + 1 end
    local function query(text)
        ui.search = text; ui:RefreshDungeons(); queue = {}
        assert(ui.catalogLanguageView and ui.catalogLanguageView.current())
        hydration = 0 -- Observe the following data arrival, after explicit setup/warming.
        return ui.catalogGeneration
    end
    local function event()
        f.eventFrame.scripts.OnEvent(f.eventFrame, 'ITEM_DATA_LOAD_RESULT', 7001, true)
        local steps = 0
        while #queue > 0 do steps = steps + 1; assert(steps < 100); table.remove(queue, 1)() end
        assert(hydration == 0, 'catalogue preflight cannot hydrate quests')
    end
    local function find(key)
        for _, row in ipairs(ui.cards) do
            if row:IsShown() and row.catalogResult.dungeon.key == key then return row.catalogResult end
        end
    end
    return a, ui, query, event, find
end

check('Repeated unmatched item events avoid redundant complete source preflights', function()
    local a, ui, query, event = fixture()
    local provider, active, counts = a.QuestSourceSearchTerms, false, {}
    a.QuestSourceSearchTerms = function(q)
        local terms, current, raw = provider(q)
        if not current or not raw then return terms, current, raw end
        return terms, function()
            if active then counts[q.id] = (counts[q.id] or 0) + 1 end
            return current()
        end, raw
    end
    local generation = query('__No batch proof result__')
    active = true
    for index = 1, 3 do event() end
    active = false
    assert(ui.catalogGeneration == generation and #ui.catalogLanguageView.results == 0)
    local distinct, maximum = 0, 0
    for _, count in pairs(counts) do distinct = distinct + 1; maximum = math.max(maximum, count) end
    assert(distinct > 500, 'actual catalogue source preflight was not exercised')
    assert(maximum <= 6, 'three unchanged events repeated full source preflights: ' .. maximum)
    print('  actual sources', distinct, 'maximum calls per source', maximum)
end)

check('Initial and final status callbacks cannot conceal a newer query', function()
    for _, index in ipairs({ 1, 6 }) do
        local a, ui, query, event, find = fixture()
        query('The Barrens'); assert(#ui.catalogLanguageView.results == 6)
        local result = ui.catalogLanguageView.results[index]
        local previous, fired = result.statusCurrent, false
        result.statusCurrent = function()
            local valid = previous()
            if not fired then fired = true; query('Betina Bigglezink') end
            return valid
        end
        event()
        assert(fired and ui.search == 'Betina Bigglezink' and find('strat'))
        assert(ui.catalogLanguageView.current())
    end
end)

check('A late language read cannot conceal an earlier negative title or source', function()
    for _, mode in ipairs({ 'title', 'source', 'graph' }) do
        local a, ui, query, event, find = fixture()
        a.db.locale = 'zhCN'; a.GetNameTranslations('zhCN', function() return true end)
        local keyGetter, armed, fired, reads = ui.CatalogLanguageKey, false, false, 0
        local needle = mode == 'graph' and 'Tirion Fordring' or ('__Batch late ' .. mode .. '__')
        ui.CatalogLanguageKey = function(self)
            local value = keyGetter(self)
            if armed then reads = reads + 1 end
            if armed and reads == 2 and not fired then
                fired = true
                if mode == 'title' then a.nameTranslations.zhCN.quests[166].name = needle
                elseif mode == 'source' then a.quests[870].start.name = needle
                else
                    -- Existing support definition is unrelated until the recorded edge changes.
                    a.quests[914].requires = { { ids = { 5742 } } }
                end
            end
            return value
        end
        local generation = query(needle); assert(not find(mode == 'title' and 'dm' or 'wc'))
        armed = true; event(); armed = false
        assert(fired and ui.catalogGeneration ~= generation)
        assert(find(mode == 'title' and 'dm' or 'wc'), 'late negative ' .. mode .. ' change was lost')
    end
end)

check('Source helper replacement during detached status reads rebuilds safely', function()
    local a, ui, query, event = fixture()
    local generation = query('The Barrens')
    local result = ui.catalogLanguageView.results[1]
    local previous, provider, fired = result.statusCurrent, a.QuestSourceSearchTerms, false
    result.statusCurrent = function()
        local valid = previous()
        if not fired then fired = true; a.QuestSourceSearchTerms = function(...) return provider(...) end end
        return valid
    end
    event()
    assert(fired and ui.catalogGeneration ~= generation and ui.catalogLanguageView.current())
end)

check('Selection changed during initial or final preflight cannot retain obsolete paint', function()
  for _, mode in ipairs({ 'initial', 'final' }) do
    local a, ui, query, event, find = fixture()
    local other
    for _, dungeon in ipairs(a.dungeons) do if dungeon.key == 'zf' then other = dungeon end end
    local selected = ui.dungeon
    -- Warm ordinary quest-row metadata before observing hydration-free catalogue work.
    ui.dungeon = other; ui:Refresh(); ui.dungeon = selected; ui:Refresh()
    local getter, armed, fired = a.CachedQuestName, false, false
    local provider = a.QuestSourceSearchTerms
    a.QuestSourceSearchTerms = function(q)
        local terms, current, raw = provider(q)
        if not current or not raw then return terms, current, raw end
        return terms, function()
            local valid = current()
            if mode == 'initial' and armed and not fired then fired = true; ui.dungeon = other end
            return valid
        end, raw
    end
    a.CachedQuestName = function(id)
        if mode == 'final' and armed and not fired then fired = true; ui.dungeon = other end
        return getter(id)
    end
    query('Gryphon Master Talonaxe'); armed = true; event(); armed = false
    assert(fired and ui.dungeon == other and find('zf'))
    assert(ui.catalogLanguageView.selectedDungeon == other and ui.catalogLanguageView.current())
  end
end)

check('Owned preflight callbacks retire the old view and final tails invoke none', function()
    local _, ui, query, _, find = fixture()
    local keyGetter, armed, fired, reads = ui.CatalogLanguageKey, false, false, 0
    ui.CatalogLanguageKey = function(self)
        local value = keyGetter(self)
        reads = reads + 1
        if reads == 2 then armed = true end
        return value
    end
    query('The Barrens'); reads, armed = 0, false
    local before = ui.catalogLanguageView
    local beforeOwned = before.owned
    before.owned = function(...)
        local valid = beforeOwned(...)
        if armed and not fired then fired = true; query('Betina Bigglezink') end
        return valid
    end
    local reused, reason = ui:RefreshCatalogData()
    assert(fired and ui.search == 'Betina Bigglezink' and find('strat'))
    assert(reused ~= true and reason == 'superseded', 'owned preflight authorized a retired view')

    local a
    a, ui, query = fixture()
    query('The Barrens')
    local view = ui.catalogLanguageView
    local owned, membership = view.owned, view.membershipCurrent
    armed, fired = false, false
    view.membershipCurrent = function(...)
        local valid = membership(...); armed = true; return valid
    end
    view.owned = function(...)
        local valid = owned(...)
        if armed and not fired then
            fired = true
            a.quests[870].start.name = '__Mutation after completed proof__'
        end
        return valid
    end
    reused = ui:RefreshCatalogData()
    assert(armed, 'membership proof must complete before reporting reusable results')
    assert(not fired, 'final tail invoked an owner callback after completing membership proof')
    assert(reused == true and ui.catalogLanguageView == view and ui.search == 'The Barrens')
end)

assert(#failures == 0, table.concat(failures, '\n'))
print('Catalogue data batch: PASS ' .. passed .. ' groups; invocation bounds only, no native timing claim')
