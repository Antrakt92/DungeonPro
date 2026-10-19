-- Contextual detail views separate work, source choices and actual quest prose.
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
assert(type(ui.SetDetailTab)=="function"and ui.detailTabButtons and ui.detailTabButtons.quest and ui.detailTabButtons.sources and ui.detailTabButtons.story,
 "quest details need three real contextual views")
local function tab(key)
 local b=ui.detailTabButtons[key];assert(b:IsShown()and b.enabled and b.scripts.OnClick)
 b.scripts.OnClick(b);assert(ui.detailTab==key)
end
assert(ui.detailTab=="quest"and visible("Item 3637")and not visible(prose))
local history=ui.detailHistory;local size=#history
tab("story");assert(visible(prose)and not visible("Item 3637")and #history==size)
assert(not ui.narrativeToggle or not ui.narrativeToggle:IsShown(),"full story does not require another read-more drawer")
tab("quest");assert(visible("Item 3637")and not visible(prose))
render(6981);assert(ui.detailTab=="quest")
assert(visible(a.L("ITEM_STARTER","Item 10441")),"starter identity stays on the work view")
assert(visible(a.L("ITEM_CARRIED",0)),"known carried zero is retained")
tab("sources");assert(visible("Mutanus the Devourer"),"verified item acquisition is directly visible in Sources")
assert(not ui.referenceToggle or not ui.referenceToggle:IsShown(),"Sources does not hide itself behind acquisition details")
tab("story");assert(visible(a.L("DETAIL_STORY_UNAVAILABLE")),"missing prose has an honest empty state")
assert(not visible("Mutanus the Devourer"),"source route is not fabricated story text")
ui.detailScroll.GetHeight=function()return 90 end
assert(ui:InspectQuest(1491,true));assert(ui.detailTab=="quest")
assert(ui:InspectQuest(6981,true,true));assert(ui.detailTab=="sources"and visible("Mutanus the Devourer")and routes==0)
ui.detailScroll:SetVerticalScroll(32);tab("quest");ui.detailScroll:SetVerticalScroll(16);tab("sources")
assert(ui.detailScroll:GetVerticalScroll()==32,"tab changes restore their own reading position")
ui:InspectQuest(1491,true);assert(ui.detailTab=="quest");ui:BackQuest()
assert(ui.quest==6981 and ui.detailTab=="sources"and ui.detailScroll:GetVerticalScroll()==32,
 "Back restores the matching tab and offset together")
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","itIT","koKR","zhCN","zhTW"})do
 a.db.locale=locale;ui:RefreshLanguagePreview();assert(ui.detailTab=="sources")
 for key,label in pairs({quest="TAB_QUEST",sources="TAB_SOURCES",story="TAB_STORY"})do
  local b=ui.detailTabButtons[key];assert(b.label.text==a.L(label)and b:GetWidth()>0)
 end
end
a.db.locale="enUS";render(98423);assert(visible(a.L("START_ITEM_LOCATION_UNKNOWN")))
ui.quest,ui.dungeon=2204,owners[2204]or owners[2201];ui:Refresh()
assert(ui.detailTab=="quest"and visible(a.L("SOURCE_SUMMON_ITEM","Item 7667",a.quests[2204].start.name)),
 "item-created giver instructions remain visible on Quest")
local character=a.char;a.char={};token={};ui:Refresh();assert(ui.detailTab=="quest");a.char=character
assert(routes==0,"tab selection never navigates or uses an item")
-- A real twelve-source starter is a short pointer on Quest, with every source retained on Sources.
render(7506)
local drops=assert(a.quests[7506].start.dropSources);assert(#drops==12)
assert(visible(a.L("ITEM_SOURCE_SUMMARY",12,a.L("TAB_SOURCES"))))
for _,drop in ipairs(drops)do assert(not visible(drop.name),"the work view must not repeat all twelve NPC sources")end
ui:SetDetailTab("sources")
for _,drop in ipairs(drops)do assert(visible(drop.name),"Sources keeps every exact recorded NPC source")end
-- An authored turn-in cost remains a source fact, distinct from reward money.
local payment=a.QuestPayment
a.QuestPayment=function(id)if id==2945 then return{amount=300,formatted="300 copper"}end end
assert(a.quests[2945].requiredMoney==300)
ui.quest,ui.dungeon=2945,owners[2945]or owners[166];ui:Refresh()
assert(visible(a.L("QUEST_PAYMENT","300 copper"))and not visible(a.L("QUEST_PAYMENT_NOTICE")))
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
 assert(#visited==before,"opening Sources never chooses a giver or object automatically")
 local headings=0;for _,field in ipairs(ui.details)do
  if field:IsShown()and field.text==a.L("START_ALTERNATIVES")then headings=headings+1 end
 end
 assert(headings==1,"all alternatives need one starting-sources heading, not separate preview and remainder headings")
 local choices={};for _,pool in ipairs({ui.giverButtons,ui.startButtons})do for _,row in ipairs(pool)do
  if row:IsShown()then choices[#choices+1]=row end
 end end
 assert(#choices==count,"every recorded manual source remains visible")
 local finishTop
 for _,field in ipairs(ui.details)do
  if field:IsShown()and field.text and field.text:find(a.L("DETAIL_TURNIN")..":",1,true)==1 then
   finishTop=-field.point[3];break
  end
 end
 assert(finishTop,"the actual alternative-source quest keeps its distinct turn-in identity")
 for _,row in ipairs(choices)do
  assert(-row.point[3]+row:GetHeight()<=finishTop,
   "all starting choices form one uninterrupted list before the turn-in caption")
 end
 for index,row in ipairs(choices)do
  assert(row.enabled and row.scripts.OnClick)
  row.scripts.OnClick(row)
  local call=assert(visited[before+index]);assert(call.point==alternatives[index],"manual visits retain exact source order and identity")
  if call.action then assert(call.action.id==id and call.action.kind=="visit")end
 end
 assert(ui.quest==id and ui.detailTab=="sources")
end
a.Navigation=navigation
-- Even an unchanged quest can complete a newer render inside the old scroll getter.
render(166)
local scroll=ui.detailScroll;local getter=scroll.GetVerticalScroll;local armed,fired=true,false
scroll.GetVerticalScroll=function(self)
 if armed then armed,fired=false,true;ui:RefreshDetail()end
 return getter(self)
end
local changed=ui:SetDetailTab("sources")
scroll.GetVerticalScroll=getter
assert(fired and not changed and ui.detailTab=="quest","a completed newer same-quest render retires the older tab request")
print("Detail tabs: PASS (actual work/source separation, full prose, honest empty,10locales, focus and tab-aware history)")
