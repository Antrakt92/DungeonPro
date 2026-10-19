-- Data arrival may repaint details without rebuilding unchanged text-search membership.
local total, failures = 0, {}
local function check(name, callback)
    local ok, message = pcall(callback)
    if ok then total = total + 1; print('PASS ' .. name)
    else failures[#failures + 1] = name .. ': ' .. tostring(message); print('FAIL ' .. failures[#failures]) end
end
local function fixture()
    local f = assert(loadfile('tests/client_ui.lua'))('fixture')
    local a, ui, queue = f.addon, f.addon.UI, {}
    issecretvalue = function() return false end
    GetLocale = function() return 'enUS' end
    UnitGUID = function(unit) return unit == 'player' and 'Player-SearchData' or nil end
    C_Timer = { After = function(delay, fn) if delay == .1 then queue[#queue + 1] = fn end end }
    f.eventFrame.scripts.OnEvent(f.eventFrame, 'ADDON_LOADED', 'DungeonPro')
    ui:Toggle(); a.db.locale = 'enUS'; ui.range = false; ui.includeUnavailable = true
    local relation, relations, hydration = a.QuestSearchRelations, 0, 0
    a.QuestSearchRelations = function(...) relations = relations + 1; return relation(...) end
    C_QuestLog.RequestLoadQuestByID = function() hydration = hydration + 1 end
    local function event(name) f.eventFrame.scripts.OnEvent(f.eventFrame, name, 7001, true) end
    local function drain()
        local steps = 0
        while #queue > 0 do steps = steps + 1; assert(steps < 100); table.remove(queue, 1)() end
    end
    local function query(text)
        ui.search = text; ui:RefreshDungeons(); queue = {}; relations = 0
        assert(ui.catalogLanguageView and ui.catalogLanguageView.current())
        return ui.catalogGeneration
    end
    local function find(key)
        for _, row in ipairs(ui.cards) do
            if row:IsShown() and row.catalogResult.dungeon.key == key then return row.catalogResult, row end
        end
    end
    return { addon = a, ui = ui, event = event, drain = drain, query = query, find = find,
        relations = function() return relations end, hydration = function() return hydration end }
end
check('Actual related source result survives an item-only repaint without new projections', function()
    local f = fixture(); local ui = f.ui
    local generation = f.query('Gryphon Master Talonaxe')
    local result, row = f.find('zf'); assert(result and result.related)
    local quest, root, count, inspect = result.questID, result.relatedRootID, result.count, result.inspect
    local refresh = ui.RefreshDetail; local details = 0
    ui.RefreshDetail = function(...) details = details + 1; return refresh(...) end
    f.event('ITEM_DATA_LOAD_RESULT'); f.drain()
    assert(ui.catalogGeneration == generation, 'unchanged item data rebuilt the full text-search catalogue')
    local after, afterRow = f.find('zf')
    assert(afterRow == row and after.questID == quest and after.relatedRootID == root and after.count == count)
    assert(after.inspect == inspect and inspect:IsShown() and details == 1, 'data repaint must preserve explicit inspection and refresh details')
    assert(f.relations() == 0 and f.hydration() == 0, 'unchanged search cannot reproject graphs or hydrate quests')
end)
check('A previously missing native title becomes a match through the same getter', function()
    local f = fixture(); local label
    C_QuestLog.GetTitleForQuestID = function(id) if id == 166 then return label end end
    local generation = f.query('__New native quest label__'); assert(not f.find('dm'))
    label = '__New native quest label__'
    f.event('QUEST_DATA_LOAD_RESULT'); f.event('ITEM_DATA_LOAD_RESULT'); f.drain()
    local result = f.find('dm'); assert(result and result.questID == 166 and f.ui.catalogGeneration ~= generation)
    assert(f.hydration() == 0)
end)
check('A nonmatching localized dungeon label becomes a match through the same getter', function()
    local f = fixture(); local rfc
    for _, dungeon in ipairs(f.addon.dungeons) do if dungeon.key == 'rfc' then rfc = dungeon end end
    assert(rfc and rfc.instanceID)
    local label
    GetRealZoneText = function(id) if id == rfc.instanceID then return label end end
    local generation = f.query('__New native dungeon label__'); assert(not f.find('rfc'))
    label = '__New native dungeon label__'
    f.event('ITEM_DATA_LOAD_RESULT'); f.drain()
    local result = f.find('rfc'); assert(result and not result.questID and f.ui.catalogGeneration ~= generation)
end)
check('Earlier negative translated title mutations from a later getter cannot pass reuse', function()
    local f = fixture(); local a = f.addon
    a.db.locale = 'zhCN'; a.GetNameTranslations('zhCN', function() return true end)
    local entry = assert(a.nameTranslations.zhCN.quests[166]); local source = entry.source
    local previous = a.CachedQuestName; local armed, seen, fired = false, false, false
    a.CachedQuestName = function(id)
        if armed and id == 166 then seen = true
        elseif armed and seen and not fired then fired = true; entry.name = '__Later getter changed earlier title__' end
        return previous(id)
    end
    local generation = f.query('__Later getter changed earlier title__'); assert(not f.find('dm'))
    armed = true; f.event('ITEM_DATA_LOAD_RESULT'); f.drain(); armed = false
    assert(fired, 'late getter mutation was not exercised')
    local result = f.find('dm'); assert(result and result.questID == 166 and f.ui.catalogGeneration ~= generation)
    assert(entry.source == source and f.hydration() == 0)
end)
check('Source facts changing in a previously negative support quest rebuild membership', function()
    local f = fixture(); local a = f.addon
    local generation = f.query('__Recorded support source arrived__'); assert(not f.find('wc'))
    local point = assert(a.quests[870].start); point.name = '__Recorded support source arrived__'
    f.event('ITEM_DATA_LOAD_RESULT'); f.drain()
    local result = f.find('wc'); assert(result and result.related and result.questID == 870)
    assert(f.ui.catalogGeneration ~= generation and f.hydration() == 0)
end)
check('Full character invalidation wins over either ordering of item notifications', function()
    for _, first in ipairs({ 'ITEM_DATA_LOAD_RESULT', 'QUEST_LOG_UPDATE' }) do
        local f = fixture(); local generation = f.query('Gryphon Master Talonaxe')
        f.event(first); f.event(first == 'ITEM_DATA_LOAD_RESULT' and 'QUEST_LOG_UPDATE' or 'ITEM_DATA_LOAD_RESULT'); f.drain()
        assert(f.ui.catalogGeneration ~= generation and f.relations() > 0 and f.find('zf'))
    end
end)
check('A newer query from a name read owns the final results', function()
    local f = fixture(); local a, ui = f.addon, f.ui
    local previous = a.CachedQuestName; local armed, fired = false, false
    a.CachedQuestName = function(id)
        if armed and not fired then fired = true; ui.search = 'Betina Bigglezink'; ui:RefreshDungeons() end
        return previous(id)
    end
    f.query('Gryphon Master Talonaxe'); armed = true
    f.event('ITEM_DATA_LOAD_RESULT'); f.drain(); armed = false
    assert(fired and ui.search == 'Betina Bigglezink' and f.find('strat') and not f.find('zf'))
    assert(ui.catalogLanguageView.current() and f.hydration() == 0)
end)
check('A later dungeon getter cannot change an earlier negative translated area unnoticed',function()
    local f=fixture();local a=f.addon;a.db.locale='zhCN'
    local dictionary=assert(a.GetNameTranslations('zhCN',function()return true end))
    local first=a.dungeons[1];local entry=assert(dictionary.dungeons[first.key])
    local previous=a.DungeonName;local armed,seen,fired=false,false,false
    a.DungeonName=function(dungeon)
        if armed and dungeon==first then seen=true
        elseif armed and seen and not fired then fired=true;entry.name='__Earlier dungeon changed late__'end
        return previous(dungeon)
    end
    local generation=f.query('__Earlier dungeon changed late__');assert(not f.find(first.key))
    armed=true;f.event('ITEM_DATA_LOAD_RESULT');f.drain();armed=false
    local result=f.find(first.key)
    assert(fired and result and not result.questID and f.ui.catalogGeneration~=generation)
    assert(f.hydration()==0)
end)
check('Unchanged text results reuse membership in every selected language',function()
    local f=fixture()
    for _,locale in ipairs({'enUS','ruRU','deDE','frFR','esES','itIT','ptBR','koKR','zhCN','zhTW'})do
        f.addon.db.locale=locale
        local generation=f.query('Gryphon Master Talonaxe');local result=assert(f.find('zf'))
        local id,root,count=result.questID,result.relatedRootID,result.count
        f.event('ITEM_DATA_LOAD_RESULT');f.drain()
        result=assert(f.find('zf'))
        assert(f.ui.catalogGeneration==generation and f.relations()==0,locale..' should reuse proven membership')
        assert(result.questID==id and result.relatedRootID==root and result.count==count and f.hydration()==0)
    end
end)
check('An unavailable native scope conservatively rebuilds rather than claiming reusable membership',function()
    for _,scope in ipairs({'native','native-empty','native-unsupported','selected','player-false','player-throw','player-nil','player-empty','player-long'})do
        local f=fixture()
        if scope=='native'then GetLocale=function()return nil end
        elseif scope=='native-empty'then GetLocale=function()return ''end
        elseif scope=='native-unsupported'then GetLocale=function()return 'unsupported'end
        elseif scope=='selected'then f.addon.db.locale='unsupported'
        elseif scope=='player-false'then UnitGUID=function()return false end
        elseif scope=='player-throw'then UnitGUID=function()error('unavailable player')end
        elseif scope=='player-nil'then UnitGUID=function()return nil end
        elseif scope=='player-empty'then UnitGUID=function()return '  'end
        else UnitGUID=function()return string.rep('x',257)end end
        local generation=f.query('Gryphon Master Talonaxe');assert(f.find('zf'))
        f.event('ITEM_DATA_LOAD_RESULT');f.drain()
        assert(f.ui.catalogGeneration~=generation and f.relations()>0 and f.find('zf'))
        assert(f.hydration()==0)
    end
end)
check('Scope getters that reenter an initial or reusable request preserve the newer query',function()
    for _,reuse in ipairs({false,true})do
        local f=fixture();local a,ui=f.addon,f.ui
        local previous=GetLocale;local armed,fired=false,false
        GetLocale=function()
            if armed and not fired then fired=true;ui.search='Betina Bigglezink';ui:RefreshDungeons()end
            return previous()
        end
        if reuse then f.query('Gryphon Master Talonaxe');armed=true;f.event('ITEM_DATA_LOAD_RESULT');f.drain()
        else armed=true;ui.search='Gryphon Master Talonaxe';ui:RefreshDungeons()end
        armed=false
        assert(fired and ui.search=='Betina Bigglezink'and f.find('strat')and not f.find('zf'))
        assert(ui.catalogLanguageView.current()and f.hydration()==0)
    end
end)
check('Unreadable source or relation projections rebuild when their same provider becomes readable',function()
    for _,key in ipairs({'QuestSourceSearchTerms','QuestSearchRelations'})do
        local f=fixture();local a=f.addon;local previous=a[key];local ready=false
        a[key]=function(...)if ready then return previous(...)end end
        local generation=f.query('Gryphon Master Talonaxe');assert(not f.find('zf'))
        ready=true;f.event('ITEM_DATA_LOAD_RESULT');f.drain()
        assert(f.ui.catalogGeneration~=generation and f.find('zf')and f.hydration()==0,key..' missing proof cannot authorize reuse')
    end
end)
check('A final membership getter selection change repaints the latest catalogue selection',function()
    local f=fixture();local a,ui=f.addon,f.ui;local other
    for _,dungeon in ipairs(a.dungeons)do if dungeon.key=='zf'then other=dungeon end end
    -- Warm both visible quest lists: changing selection may legitimately request row previews.
    local selected=ui.dungeon;ui.dungeon=other;ui:Refresh();ui.dungeon=selected;ui:Refresh()
    local hydration=f.hydration()
    local previous=a.CachedQuestName;local armed,fired,reads=false,false,0
    a.CachedQuestName=function(id)
        if armed and id==166 then
            reads=reads+1
            if reads==2 then fired=true;ui.dungeon=other end
        end
        return previous(id)
    end
    local generation=f.query('Gryphon Master Talonaxe');assert(ui.dungeon~=other)
    armed=true;f.event('ITEM_DATA_LOAD_RESULT');f.drain();armed=false
    assert(fired and reads>=2,'the final dynamic membership pass must actually change selection')
    assert(ui.dungeon==other and ui.catalogLanguageView.selectedDungeon==other and ui.catalogGeneration~=generation,
        'same-view selection supersession cannot leave the former selected-card paint')
    assert(f.find('zf')and f.hydration()==hydration,'catalogue membership itself adds no hydration')
end)
check('A later getter cannot change an earlier native wing label template unnoticed',function()
    local f=fixture();local a=f.addon;local lower
    for _,dungeon in ipairs(a.dungeons)do if dungeon.wing=='lower'then lower=dungeon end end
    assert(lower)
    GetRealZoneText=function()return 'Native complex base'end
    local previous=a.DungeonName;local armed,reads,fired=false,0,false
    a.DungeonName=function(dungeon)
        if armed and dungeon==lower then reads=reads+1
        elseif armed and reads==2 and not fired then
            fired=true;a.locales.enUS.DUNGEON_WING_lower='%s __Later wing template__'
        end
        return previous(dungeon)
    end
    local generation=f.query('__Later wing template__');assert(not f.find(lower.key))
    armed=true;f.event('ITEM_DATA_LOAD_RESULT');f.drain();armed=false
    local result=f.find(lower.key)
    assert(fired and result and not result.questID and f.ui.catalogGeneration~=generation,
        'the native wing template is part of the consulted dungeon label')
    assert(f.hydration()==0)
end)
check('Restoring a harmless localizer preserves a retained non-wing source inspection',function()
    local f=fixture();local a,ui=f.addon,f.ui;local nonwing={}
    for _,dungeon in ipairs(a.dungeons)do
        if dungeon.key=='dm'or dungeon.key=='rfc'or dungeon.key=='wc'then nonwing[#nonwing+1]=dungeon;assert(not dungeon.wing)end
    end
    assert(#nonwing==3);a.dungeons=nonwing
    local localize=a.L;a.L=function(...)return localize(...)end
    f.query('Gryan Stoutmantle');local result=assert(f.find('dm'))
    local questID=result.questID;local click=assert(result.inspect.scripts.OnClick)
    a.L=localize
    assert(f.hydration()==0,'search itself never requests quest hydration')
    assert(ui.quest~=questID);click()
    assert(ui.quest==questID,'non-wing route ownership does not depend on an unused localizer identity')
end)
assert(#failures == 0, table.concat(failures, '\n'))
print('Search data refresh: PASS ' .. total .. ' groups; no native latency or FPS proof')
