-- Numeric search labels use the selected language without losing exact identity.
local fixture=assert(loadfile("tests/client_ui.lua"))("fixture")
local addon,ui=fixture.addon,fixture.addon.UI
C_Timer={After=function()end}
GetLocale=function()return "enUS"end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();ui.dungeon,ui.quest=nil,nil;ui.includeUnavailable=true;ui.range=false
local requests=0
C_QuestLog.RequestLoadQuestByID=function()requests=requests+1 end
local cached=addon.CachedQuestName
local reads=0
addon.CachedQuestName=function(id)reads=reads+1;return cached(id)end
local function cards(id,expected)
    local result={}
    for _,card in ipairs(ui.cards)do if card:IsShown()then
        assert(card.matchQuestID==id,"only direct numeric matches remain visible")
        assert(card.note.text:find(expected.." (#"..id..")",1,true),"translated title retains exact ID cue")
        result[#result+1]=card
    end end
    assert(#result==3,"one shared quest retains all three actual parent dungeons")
    return result
end
local locales={"zhCN","enUS","ruRU","deDE","frFR","esES","itIT","ptBR","koKR","zhTW"}
for _,locale in ipairs(locales)do
    addon.db.locale=locale;ui.search=" 1654 ";reads=0
    ui:RefreshDungeons()
    local expected=cached(1654)or addon.quests[1654].name
    local initial=cards(1654,expected);local notes={}
    assert(reads==1,"initial ID search memoizes one pure title read across three parents")
    for index,card in ipairs(initial)do notes[index]=card.note.text end
    ui:Refresh(false,true)
    local after=cards(1654,expected)
    for index,card in ipairs(after)do assert(card.note.text==notes[index],"ordinary data refresh does not change a stable ID label")end
    assert(ui.search==" 1654 "and ui.includeUnavailable and not ui.range and not ui.quest and not ui.dungeon)
end
addon.db.locale="enUS";ui.search="1654";ui:RefreshDungeons()
ui.language.scripts.OnEnter()
local session=assert(addon.Language.session);local chinese
for _,row in ipairs(session.rows)do if row.languageCode=="zhCN"or row.text=="简体中文"then chinese=row end end
assert(chinese);chinese.scripts.OnEnter()
cards(1654,cached(1654));assert(addon.db.locale=="enUS","preview keeps committed preference")
addon.Language:Cancel(ui);cards(1654,cached(1654)or addon.quests[1654].name)
-- Missing/invalid optional cache titles retain the source-language label and ID.
for _,value in ipairs({false,"",string.rep("x",1025)})do
    addon.CachedQuestName=function()return value end
    addon.db.locale="zhCN";ui:RefreshDungeons();cards(1654,addon.quests[1654].name)
    ui:Refresh(false,true);cards(1654,addon.quests[1654].name)
end
addon.CachedQuestName=cached
addon.db.locale="zhCN";ui.search=cached(1654);ui:RefreshDungeons()
local found=false
for _,card in ipairs(ui.cards)do if card:IsShown()and card.matchQuestID==1654 then
    found=true;assert(not card.note.text:find("(#1654)",1,true),"ordinary text matches do not acquire numeric cues")
end end
assert(found and requests==0,"numeric/localized text search never hydrates quest data")
local armed=true
addon.CachedQuestName=function(id)
    if armed then armed=false;ui.search="6981";ui:RefreshDungeons()end
    return cached(id)
end
ui.search="1654";ui:RefreshDungeons()
assert(not armed and ui.search=="6981","new title read actually starts the newer search")
local found=false
for _,card in ipairs(ui.cards)do if card:IsShown()then
    found=true;assert(card.matchQuestID==6981 and not card.note.text:find("(#1654)",1,true),
        "expired numeric title cannot publish over a newer query")
end end
assert(found)
armed=true
addon.CachedQuestName=function()
    if armed then armed=false;addon.CachedQuestName=cached end
    return "STALE TITLE"
end
ui.search="1654";ui:RefreshDungeons()
assert(not armed,"replacement cache getter actually ran")
for _,card in ipairs(ui.cards)do if card:IsShown()then
    assert(not card.note.text:find("STALE TITLE",1,true),"replaced title provider cannot publish a detached label")
end end
ui:RefreshDungeons();cards(1654,cached(1654))
assert(requests==0)
-- Shared-quest and shared-member numeric IDs resolve across all wings with a single title read.
do
    local counted = addon.CachedQuestName
    for _, sample in ipairs({ { " 96800 ", 96800, 4 }, { " 1050 ", 1050, 4 } }) do
        local query, id, want = sample[1], sample[2], sample[3]
        local n = 0
        addon.CachedQuestName = function(questID) n = n + 1; return counted(questID) end
        addon.db.locale = "enUS"; ui.search = query; ui:RefreshDungeons()
        local shown = 0
        for _, card in ipairs(ui.cards) do
            if card:IsShown() then
                shown = shown + 1
                assert(card.matchQuestID == id, "shared numeric match keeps exact quest identity")
            end
        end
        assert(shown == want and n == 1, "shared/member numeric search shows all wing cards after one title read")
    end
    addon.CachedQuestName = counted
end
print("Quest ID search localization: PASS (ten locales, shared parents, refresh, preview, fallback)")
