-- Obsolete catalogue requests release heavy snapshots without replacing pooled bindings.
local fixture = assert(loadfile('tests/client_ui.lua'))('fixture')
local addon, ui = fixture.addon, fixture.addon.UI
issecretvalue = function() return false end
GetLocale = function() return 'enUS' end
C_Timer = { After = function() end }
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, 'ADDON_LOADED', 'DungeonPro')
ui:Toggle(); addon.db.locale = 'enUS'; ui.includeUnavailable = true; ui.range = false
local function query(text)
    ui.search = text; ui:RefreshDungeons()
    local count = 0
    for _, row in ipairs(ui.cards) do if row:IsShown() then count = count + 1 end end
    return count
end
query('The Barrens'); query('__warm_no_match__')
local hydration = 0
C_QuestLog.RequestLoadQuestByID = function() hydration = hydration + 1 end
C_Item = C_Item or {}
C_Item.RequestLoadItemDataByID = function() hydration = hydration + 1 end
local tokens = setmetatable({}, { __mode = 'v' })
local active
local provider = addon.QuestSourceSearchTerms
addon.QuestSourceSearchTerms = function(q)
    local terms, current, raw = provider(q)
    local token = active
    if not current or not raw then return terms, current, raw end
    if token == nil then return terms, current, raw end
    return terms, function() return token ~= nil and current() end,
        function() return token ~= nil and raw() end
end
local function tracked(label, text)
    active = {}; tokens[label] = active
    local count = query(text); active = nil
    collectgarbage('collect'); collectgarbage('collect')
    return count
end
assert(tracked('six', 'The Barrens') == 6)
assert(tracked('one', 'Tirion Fordring') == 1)
assert(tokens.six == nil and tokens.one ~= nil, 'obsolete six-card request retained')
assert(tracked('zero', '__no_catalogue_match__') == 0)
assert(tokens.one == nil and tokens.zero ~= nil, 'obsolete one-card request retained')
assert(ui.catalogLanguageView.current(), 'newest request lost ownership')
print('PASS weak sentinels 6 -> 1 -> 0; current request retained')

-- A late native setter must still repair through the SAME pooled binding registry.
query('The Barrens')
local row = ui.cards[1]
local bindings = row.title.catalogWrites
local original = row.title.SetText
local fired = false
row.title.SetText = function(self, text)
    if not fired then
        fired = true; query('Tirion Fordring')
    end
    return original(self, text)
end
row.title.text = '__force_native_write__'
query('The Barrens')
row.title.SetText = original
assert(fired and ui.search == 'Tirion Fordring')
assert(row.title.catalogWrites == bindings, 'binding table identity replaced')
assert(row.title.text == ui.catalogLanguageView.results[1].title, 'late text overwrote newest caption')
assert(ui.catalogLanguageView.current())
print('PASS late SetText repairs newest text without replacing bindings')

query('The Barrens')
local originalHide = row.Hide
fired = false
row.Hide = function(self)
    if not fired then fired = true; query('The Barrens') end
    return originalHide(self)
end
query('__no_catalogue_match__')
row.Hide = originalHide
assert(fired and ui.search == 'The Barrens' and row:IsShown(), 'late Hide concealed newest row')
assert(ui.catalogLanguageView.current())
print('PASS late Hide repairs newest visibility')

for _, key in ipairs({ 'Context', 'Clean', 'SearchFold' }) do
    local previous = addon[key]
    fired = false
    local newestRelease, newestGeneration
    addon[key] = function(...)
        if not fired then
            fired = true
            query('Tirion Fordring')
            newestRelease, newestGeneration = ui.catalogSearchRelease, ui.catalogGeneration
        end
        return previous(...)
    end
    query('The Barrens')
    addon[key] = previous
    assert(fired and newestRelease and ui.catalogSearchRelease == newestRelease,
        key .. ' older outer refresh clobbered newest release')
    assert(ui.catalogGeneration == newestGeneration and ui.search == 'Tirion Fordring')
    -- Restoring a provider intentionally invalidates its previous proof; refresh normally.
    query('Tirion Fordring'); assert(ui.catalogLanguageView.current())
    print('PASS early ' .. key .. ' reentry keeps newest release')
end

-- Hiding retains the reusable warm catalogue until a NEW query supersedes it.
query('The Barrens')
local generation, release = ui.catalogGeneration, ui.catalogSearchRelease
local title = ui.cards[1].title.text
local titleBindings = ui.cards[1].title.catalogWrites
ui.frame:Hide()
assert(ui.catalogGeneration == generation and ui.catalogSearchRelease == release)
assert(ui.catalogLanguageView.current(), 'hiding unnecessarily retired reusable request')
ui.frame:Show()
assert(ui.catalogGeneration ~= generation and ui.catalogSearchRelease ~= release,
    'normal OnShow refresh must publish a fresh request')
assert(ui.cards[1].title.catalogWrites == titleBindings and ui.cards[1].title.text == title)
assert(ui.catalogLanguageView.current(), 'warm hidden catalogue lost ownership')
local visible = 0
for _, card in ipairs(ui.cards) do if card:IsShown() then visible = visible + 1 end end
assert(visible == 6, 'hide/show changed catalogue result count')
assert(hydration == 0, 'catalogue search requested native quest/item hydration')
print('PASS warm hide/show reuses current catalogue and zero hydration')
