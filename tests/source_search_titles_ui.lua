-- Source matches keep selected-language quest captions and exact identities.
local fixture=assert(loadfile("tests/client_ui.lua"))("fixture")
local addon,ui=fixture.addon,fixture.addon.UI
C_Timer={After=function()end};GetLocale=function()return "enUS"end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();ui.includeUnavailable=true;ui.range=false
local loads=0
C_QuestLog.RequestLoadQuestByID=function()loads=loads+1 end
local function find(key,id)
    for _,card in ipairs(ui.cards)do
        if card:IsShown()and card.entranceDungeon.key==key and card.matchQuestID==id then return card end
    end
    error("missing exact source match "..key.."/"..id)
end
local function query(value,locale)
    addon.db.locale=locale;ui.search=value;ui:RefreshDungeons()
end
local getter=addon.CachedQuestName
local roots={};for _,d in ipairs(addon.dungeons)do roots[d]=#d.quests end
query("贝蒂娜·比格辛克","zhCN")
assert(getter(5213)=="活跃的探子","actual reviewed Chinese quest-name control")
assert(find("strat",5213).note.text:find("任务：活跃的探子",1,true),
    "NPC match must display the reviewed selected-language quest title")
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","itIT","ptBR","koKR","zhCN","zhTW"})do
    query("Betina Bigglezink",locale)
    local name=getter(5213)or addon.quests[5213].name
    assert(find("strat",5213).note.text:find(addon.L("SEARCH_QUEST_MATCH",name),1,true),
        "root source caption follows selected language: "..locale)
end
print("PASS actual root source-match captions in all ten languages")
query("The Active Agent","zhCN")
assert(find("strat",5213).note.text:find("任务：活跃的探子",1,true),
    "canonical title queries still display the selected-language quest caption")
query("Betina Bigglezink","zhCN")
assert(find("scholo",5531).note.text:find(addon.L("SEARCH_QUEST_MATCH",getter(5531)),1,true),
    "canonical name-match priority does not leak the source-language title")
print("PASS canonical quest queries retain localized result captions")

query("Tonga Runetotem","zhCN")
assert(getter(870)=="遗忘之池","actual reviewed supporting quest-name control")
assert(find("wc",870).note.text:find(addon.L("SEARCH_RELATED_STEP","遗忘之池"),1,true),
    "related source match also displays the selected-language quest title")
print("PASS actual related source-match caption keeps recorded root context")
for _,value in ipairs({false,"",string.rep("x",1025)})do
    addon.CachedQuestName=function()return value end
    query("Betina Bigglezink","zhCN")
    assert(find("strat",5213).note.text:find(addon.L("SEARCH_QUEST_MATCH",addon.quests[5213].name),1,true),
        "unusable optional title preserves the canonical quest caption")
end
addon.CachedQuestName=function()return nil end
query("Betina Bigglezink","zhCN")
assert(find("strat",5213).note.text:find(addon.quests[5213].name,1,true))
addon.CachedQuestName=getter
print("PASS unavailable and malformed optional titles retain canonical identity")
query("Betina Bigglezink","zhCN")
assert(addon.Language:Open(ui)~=false)
local session=assert(addon.Language.session)
assert(addon.Language:Preview(session,"ruRU")~=false)
assert(find("strat",5213).note.text:find(addon.L("SEARCH_QUEST_MATCH",getter(5213)),1,true))
addon.Language:Cancel(ui)
assert(addon.db.locale=="zhCN"and find("strat",5213).note.text:find("活跃的探子",1,true))
print("PASS normal hover preview and cancellation restore source captions")
-- Retained source inspection owns the exact title entry used for its caption.
local dictionary=assert(addon.GetNameTranslations("zhCN",function()return true end))
local entries=dictionary.quests;local entry=assert(entries[5213]);local originalName,originalSource=entry.name,entry.source
for _,mode in ipairs({"name","source","entry","group","absent"})do
    ui.search="";ui.quest=166;for _,d in ipairs(addon.dungeons)do if d.key=="dm"then ui.dungeon=d end end
    ui:Refresh();query("Betina Bigglezink","zhCN")
    local result=find("strat",5213).catalogResult;local click=assert(result.inspect.scripts.OnClick)
    if mode=="name"then entry.name="Different reviewed title"
    elseif mode=="source"then entry.source="Different canonical identity"
    elseif mode=="entry"then entries[5213]={source=originalSource,name=originalName}
    elseif mode=="group"then dictionary.quests={}
    else entries[5213]=nil end
    click();assert(ui.quest==166,"retained caption inspection must expire after "..mode)
    dictionary.quests=entries;entries[5213]=entry;entry.name,entry.source=originalName,originalSource
end
print("PASS retained root caption title-entry ownership")
-- An earlier matching localized memo cannot authorize a freshly nonmatching title.
local titleReads=0
addon.CachedQuestName=function(id)
    if id==5213 then
        titleReads=titleReads+1
        if titleReads==1 then entry.name="Different fresh translated title";return "Obsolete transient quest label"end
    end
    return getter(id)
end
query("Obsolete transient quest label","zhCN")
assert(titleReads==2,"the matching title is freshly read once under its own snapshot")
for _,card in ipairs(ui.cards)do if card:IsShown()then assert(card.matchQuestID~=5213,"obsolete localized title cannot retain query membership")end end
addon.CachedQuestName=getter;entry.name=originalName
print("PASS changed localized title is revalidated against its query")
local armed=true
addon.CachedQuestName=function(id)
    if armed then armed=false;ui.search="6981";ui:RefreshDungeons()end
    return getter(id)
end
ui.search="Betina Bigglezink";ui:RefreshDungeons()
assert(not armed and ui.search=="6981","title lookup actually reenters a newer query")
for _,card in ipairs(ui.cards)do if card:IsShown()then
    assert(card.matchQuestID==6981 and not card.note.text:find("活跃的探子",1,true),
        "retired title lookup cannot overwrite the newer result")
end end
addon.CachedQuestName=getter
for dungeon,count in pairs(roots)do assert(#dungeon.quests==count,"search does not add targets")end
assert(loads==0,"source-title captions never request native hydration")
print("PASS title-read reentry, exact root counts and no native hydration")
