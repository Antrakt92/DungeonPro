-- One selected detail stream retains practical work, complete sources and authentic prose.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
function f.methods:GetVerticalScroll()return self.verticalScroll or 0 end
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return"enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle();a.db.locale="enUS";ui.includeUnavailable=true
local owners={};for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=d end end
local token={}
a.Context=function()local own=token;return{level=60,faction="Alliance",class="MAGE",race=3,current=function()return token==own end,completed=function()return false end,active=function()return false end}end
local prose=string.rep("Actual cached quest prose. ",40)
a.Description=function(id)if id==166 then return prose end end
a.ItemName=function(id)return"Item "..id end;a.ItemIcon=function()return 134400 end;a.CarriedItemCount=function()return 0 end
local routes=0;a.Navigation={Start=function()routes=routes+1;return true end,Map=function()routes=routes+1;return true end}
local function visible(text)
 for _,v in ipairs(ui.details)do if v:IsShown()and v.text and v.text:find(text,1,true)then return true end end
 return false
end
local function render(id,inspectionDungeon)
 ui.dungeon,ui.quest=assert(owners[id]or inspectionDungeon),id;ui.questTreeRoot,ui.questTreeDungeon=nil,nil;ui:Refresh()
 assert(ui.quest==id and ui.renderedQuest==id)
end
render(166)
assert(type(ui.SetDetailTab)=="function")
local function tab(key)
 local offset=ui.detailScroll:GetVerticalScroll();assert(ui:SetDetailTab(key)and ui.detailTab=="quest")
 assert(ui.detailScroll:GetVerticalScroll()==offset,"compatibility alias keeps one reading position")
 for _,control in pairs(ui.detailTabButtons or{})do assert(not control:IsShown()and not control.enabled and control.scripts.OnClick==nil)end
end
assert(ui.detailTab=="quest"and visible("Item 3637")and visible(prose))
local history=ui.detailHistory;local size=#history
tab("story");assert(visible(prose)and visible("Item 3637")and #history==size)
assert(not ui.narrativeToggle or not ui.narrativeToggle:IsShown(),"authentic story does not need another drawer")
tab("quest");assert(visible("Item 3637")and visible(prose))
render(6981);assert(ui.detailTab=="quest")
assert(visible(a.L("ITEM_STARTER","Item 10441")),"starter identity stays on the work view")
assert(visible(a.L("ITEM_CARRIED",0)),"known carried zero is retained")
tab("sources");assert(visible("Mutanus the Devourer"),"verified item acquisition is directly visible in the stream")
assert(not ui.referenceToggle or not ui.referenceToggle:IsShown(),"source acquisition does not hide behind another view")
tab("story");assert(not visible(a.L("DETAIL_STORY_UNAVAILABLE")),"missing prose contributes no empty placeholder")
assert(visible("Mutanus the Devourer")and not visible(prose),"real source route remains practical information without borrowing another quest prose")
ui.detailScroll.GetHeight=function()return 90 end
assert(ui:InspectQuest(1491,true));assert(ui.detailTab=="quest")
assert(ui:InspectQuest(6981,true,true));assert(ui.detailTab=="quest"and visible("Mutanus the Devourer")and routes==0)
ui.detailScroll:SetVerticalScroll(32);tab("quest");ui.detailScroll:SetVerticalScroll(16);tab("sources")
assert(ui.detailScroll:GetVerticalScroll()==16,"aliases preserve the same stream reading position")
ui:InspectQuest(1491,true);assert(ui.detailTab=="quest");ui:BackQuest()
assert(ui.quest==6981 and ui.detailTab=="quest"and ui.detailScroll:GetVerticalScroll()==16,
 "Back restores the matching selected stream and offset")
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","itIT","koKR","zhCN","zhTW"})do
 a.db.locale=locale;ui:RefreshLanguagePreview();assert(ui.detailTab=="quest")
 for key in pairs({quest=true,sources=true,story=true})do tab(key)end
 assert(visible(a.L("ITEM_STARTER","Item 10441"))and visible("Mutanus the Devourer"),"localized stream keeps selected item and actual source")
end
a.db.locale="enUS";render(98423);assert(visible(a.L("START_ITEM_LOCATION_UNKNOWN")))
ui.quest,ui.dungeon=2204,owners[2204]or owners[2201];ui:Refresh()
assert(ui.detailTab=="quest"and visible(a.L("SOURCE_SUMMON_ITEM","Item 7667",a.quests[2204].start.name)),
 "item-created giver instructions remain visible on Quest")
local character=a.char;a.char={};token={};ui:Refresh();assert(ui.detailTab=="quest");a.char=character
assert(routes==0,"tab selection never navigates or uses an item")
-- A real twelve-source starter retains all exact sources once without a dead tab prompt.
render(7506)
local drops=assert(a.quests[7506].start.dropSources);assert(#drops==12)
assert(not visible(a.L("ITEM_SOURCE_SUMMARY",12,a.L("TAB_SOURCES"))),"no dead tab prompt replaces actual sources")
for _,drop in ipairs(drops)do assert(visible(drop.name),"one stream retains every exact NPC source")end
ui:SetDetailTab("sources")
for _,drop in ipairs(drops)do assert(visible(drop.name),"Sources keeps every exact recorded NPC source")end
-- An authored turn-in cost remains a source fact, distinct from reward money.
local payment=a.QuestPayment
a.QuestPayment=function(id)if id==2945 then return{amount=300,formatted="300 copper"}end end
assert(a.quests[2945].requiredMoney==300)
ui.quest,ui.dungeon=2945,owners[2945]or owners[166];ui:Refresh()
assert(visible(a.L("QUEST_PAYMENT","300 copper"))and visible(a.L("QUEST_PAYMENT_NOTICE")))
ui:SetDetailTab("sources")
assert(visible(a.L("QUEST_PAYMENT","300 copper"))and visible(a.L("QUEST_PAYMENT_NOTICE")),
 "Sources retains the cost and its non-availability warning without treating it as reward money")
a.QuestPayment=payment
-- A single Sources section keeps every manual alternative in its recorded order.
local navigation=a.Navigation;local visited={}
a.Navigation={Start=function(action)visited[#visited+1]={action=action,point=action.place};return true end,
 Map=function(point)visited[#visited+1]={point=point,mapOnly=true};return true end}
assert(not owners[2933],"Venom Bottles is inspected as a supporting definition, not added as a dungeon target")
for _,sample in ipairs({{2933,12},{7492,3},{8151,5}})do
 local id,count=sample[1],sample[2]
 render(id,owners[166]);local alternatives=assert(a.quests[id].startAlternatives)
 assert(#alternatives==count and ui.detailTab=="quest"and ui.giverAction==nil)
 local before=#visited
 ui:SetDetailTab("sources")
 assert(#visited==before,"a compatibility alias never chooses a giver or object")
 local headings=0;for _,field in ipairs(ui.details)do
  if field:IsShown()and field.text==a.L("START_ALTERNATIVES")then headings=headings+1 end
 end
 assert(headings==1,"all alternatives need one starting-sources heading, not separate preview and remainder headings")
 local choices={};for _,pool in ipairs({ui.giverButtons,ui.startButtons})do for _,row in ipairs(pool)do
  if row:IsShown()then choices[#choices+1]=row end
 end end
 assert(#choices==count,"every recorded manual source remains visible")
 local finish=assert(ui.detailContactRows and ui.detailContactRows[2],"actual finisher uses the compact header contact")
 local finishBinding=assert(finish.detailContactBinding)
 assert(finish:IsShown()and finishBinding.questID==id and finishBinding.field=="finish"and
  finishBinding.endpoint==a.quests[id].finish and finishBinding.current(),"the actual alternative-source quest keeps its own current turn-in identity")
 local finishTop=-assert(finish.point)[5]
 for _,row in ipairs(choices)do
  assert(finishTop+finish:GetHeight()<=-row.point[3],
   "all starting choices remain below the compact turn-in header")
 end
 for index,row in ipairs(choices)do
  assert(row.enabled and row.scripts.OnClick)
  row.scripts.OnClick(row)
  local call=assert(visited[before+index]);assert(call.point==alternatives[index],"manual visits retain exact source order and identity")
  if call.action then assert(call.action.id==id and call.action.kind=="visit")end
 end
 assert(ui.quest==id and ui.detailTab=="quest")
end
a.Navigation=navigation
-- Even an unchanged quest can complete a newer render inside the old scroll getter.
render(166)
local scroll=ui.detailScroll;local getter=scroll.GetVerticalScroll;local armed,fired=true,false
scroll.GetVerticalScroll=function(self)
 if armed then armed,fired=false,true;ui:RefreshDetail()end
 return getter(self)
end
local changed=ui:InspectQuest(1491,true)
scroll.GetVerticalScroll=getter
assert(fired and not changed and ui.quest==166 and ui.renderedQuest==166 and ui.detailTab=="quest","a newer same-quest render retires older inspection reading")
print("Single detail stream: PASS (complete practical sources, authentic prose,10locales, focus and history)")
