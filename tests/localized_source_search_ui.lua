-- Search the selected-language label of an actual summoned object without inventing a route.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
issecretvalue=function()return false end;GetLocale=function()return"enUS"end;C_Timer={After=function()end}
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle()
a.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
a.DialogueRewards,a.QuestRewards,a.CachedQuestRewards=function()end,function()end,function()end
local dungeon
for _,d in ipairs(a.dungeons)do if d.key=="ulda"then dungeon=d end end
assert(dungeon)
ui.dungeon,ui.quest,ui.includeUnavailable,ui.range,ui.search=dungeon,2933,true,false,""
ui:Refresh()
local selected,engine,plan=ui.quest,ui.engine,ui.currentPlan
local start=assert(a.quests[2204].start);local finish=assert(a.quests[2201].finish)
assert(start.objectID==112877 and finish.objectID==112877 and start.summonItem and not start.mapID)
local canonical=start.name
assert(canonical==finish.name)
local resolver=assert(a.SourceName)
local ru=assert(a.GetNameTranslations("ruRU",function()return true end))
local zh=assert(a.GetNameTranslations("zhCN",function()return true end))
local ruEntry,zhEntry=assert(ru.objects[112877]),assert(zh.objects[112877])
local russian,chinese=ruEntry.name,zhEntry.name
assert(russian~=canonical and chinese~=canonical and ruEntry.source==canonical and zhEntry.source==canonical)
local reads={quest=0,item=0,npc=0}
local request,itemName,giverName=C_QuestLog.RequestLoadQuestByID,a.ItemName,a.GiverName
C_QuestLog.RequestLoadQuestByID=function(...)reads.quest=reads.quest+1;return request(...)end
a.ItemName=function(...)reads.item=reads.item+1;return itemName(...)end
a.GiverName=function(...)reads.npc=reads.npc+1;return giverName(...)end
local function retained()
 assert(ui.quest==selected and ui.engine==engine and ui.currentPlan==plan,"catalogue search does not replace the inspected quest or its plan")
end
local function results(query)
 local before={quest=reads.quest,item=reads.item,npc=reads.npc}
 ui.search=query;ui:RefreshDungeons()
 local cards={};for _,card in ipairs(ui.cards)do if card:IsShown()then cards[#cards+1]=card end end
 assert(reads.quest==before.quest and reads.item==before.item and reads.npc==before.npc,"source search does not hydrate native quest/item/NPC names")
 retained();return cards
end
local function uldaman(query)
 local cards=results(query)
 assert(#cards==1,"actual localized object query finds one dungeon: "..query.." (got "..#cards..")")
 local card=cards[1]
 assert(card.dungeon==dungeon or card.catalogResult and card.catalogResult.dungeon==dungeon or card.title.text==a.DungeonName(dungeon))
 assert(card.matchQuestID==2201 or card.matchQuestID==2204,"summoned object matches an existing listed quest, never a fabricated source target")
 assert(card.note.text:find(query,1,true),"matched source label remains visible in its catalogue cue")
 return card
end
for _,locale in ipairs({"ruRU","zhCN"})do
 a.db.locale=locale;local translated=locale=="ruRU"and russian or chinese
 uldaman(translated);uldaman(canonical)
end
assert(start.name==canonical and finish.name==canonical and not start.mapID and not finish.mapID,"search retains source bytes and mapless summoned-object semantics")

-- A preview changes the search language temporarily and cancellation restores the committed result.
a.db.locale="enUS";assert(#results(russian)==0,"unselected locale labels do not leak into English source search")
ui.language.scripts.OnEnter();local session=assert(a.Language.session)
session.rows[3].scripts.OnEnter()
assert(a.db.locale=="enUS"and a.Language:GetSelection()=="ruRU")
-- Language preview may refresh the active pane; retain its new engine as the current search owner.
selected,engine,plan=ui.quest,ui.engine,ui.currentPlan
assert(selected==2933);uldaman(russian)
a.Language:Cancel(ui)
selected,engine,plan=ui.quest,ui.engine,ui.currentPlan
assert(a.db.locale=="enUS"and selected==2933 and a.Language:GetSelection()==nil)
assert(#results(russian)==0,"preview cancel retires the temporary localized result")

local function inspectClick()
 for _,control in ipairs(ui.catalogInspectButtons)do if control:IsShown()then return assert(control.scripts.OnClick)end end
 error("matching actual quest has an explicit inspect control")
end
local rawName,sourceName,startID,finishID=ruEntry.name,start.name,start.objectID,finish.objectID
local root=a.nameTranslations
for _,mode in ipairs({"helper","entry-name","entry","dictionary","root","locale","source-name","source-id","missing-entry-added"})do
 a.SourceName=resolver;a.nameTranslations=root;root.ruRU=ru;ru.objects[112877]=ruEntry
 ruEntry.name=rawName;start.name,finish.name=sourceName,sourceName;start.objectID,finish.objectID=startID,finishID
 a.db.locale="ruRU"
 local query=russian
 if mode=="missing-entry-added"then ru.objects[112877]=nil;query=canonical end
 uldaman(query);local click=inspectClick()
 if mode=="helper"then a.SourceName=function(...)return resolver(...)end
 elseif mode=="entry-name"then ruEntry.name="Новая подпись чаши"
 elseif mode=="entry"then ru.objects[112877]={source=canonical,name=russian}
 elseif mode=="dictionary"then root.ruRU={quests=ru.quests,dungeons=ru.dungeons,objects=ru.objects,npcs=ru.npcs}
 elseif mode=="root"then a.nameTranslations={ruRU=ru,zhCN=zh}
 elseif mode=="locale"then a.db.locale="zhCN"
 elseif mode=="source-name"then start.name,finish.name="Changed source identity","Changed source identity"
 elseif mode=="source-id"then start.objectID,finish.objectID=112878,112878
 else ru.objects[112877]=ruEntry end
 click()
 retained()
end
a.SourceName=resolver;a.nameTranslations=root;root.ruRU=ru;ru.objects[112877]=ruEntry;ruEntry.name=rawName
start.name,finish.name=sourceName,sourceName;start.objectID,finish.objectID=startID,finishID;a.db.locale="ruRU"

-- A helper can replace the entire catalogue query while a translated source is being scanned.
local fired=false
a.SourceName=function(place,current)
 local name,proof,unchanged=resolver(place,current)
 if not fired and place.objectID==112877 then
  fired=true;ui.search="Ragefire Chasm";ui:RefreshDungeons()
 end
 return name,proof,unchanged
end
results(russian)
assert(fired and ui.search=="Ragefire Chasm","localized-source helper reentry actually changed the query")
local cards={};for _,card in ipairs(ui.cards)do if card:IsShown()then cards[#cards+1]=card end end
assert(#cards==1 and cards[1].title.text==a.DungeonName(a.dungeons[1]),"older localized scan must preserve the newer catalogue result")
a.SourceName=resolver

-- Native old-note writes must restore the newest result instead of its translated source cue.
local card=uldaman(russian);local native=card.note.SetText;local entered=false
native(card.note,"Earlier catalogue cue")
card.note.SetText=function(self,text)
 if not entered and text:find(russian,1,true)then entered=true;ui.search="Ragefire Chasm";ui:RefreshDungeons()end
 return native(self,text)
end
results(russian);card.note.SetText=native
assert(entered and ui.search=="Ragefire Chasm","localized note publication reentry fired")
cards={};for _,row in ipairs(ui.cards)do if row:IsShown()then cards[#cards+1]=row end end
assert(#cards==1 and not cards[1].note.text:find(russian,1,true))
retained()
assert(start.name==canonical and finish.name==canonical and not start.mapID and not finish.mapID)
print("Localized source search UI: PASS (actual reviewed Russian/Chinese object queries, canonical fallback, preview/cancel, stale bindings and fired reentry; no native-client proof)")
