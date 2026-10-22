-- Selected world-area captions own their visible controls independently of source names.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
-- Match native default visibility for newly created contact text regions.
local createFontString=f.methods.CreateFontString
function f.methods:CreateFontString(...)local value=createFontString(self,...);value.shown=true;return value end
issecretvalue=function()return false end;GetLocale=function()return"enUS"end;C_Timer={After=function()end}
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle()
a.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
a.DialogueRewards,a.QuestRewards,a.CachedQuestRewards=function()end,function()end,function()end
local dungeon;for _,d in ipairs(a.dungeons)do if d.key=="ulda"then dungeon=d end end
assert(dungeon)
local q=assert(a.quests[2933]);local point=assert(q.startAlternatives[1])
local area,source,map,x,y=point.zoneName,point.name,point.mapID,point.x,point.y
assert(area=="The Hinterlands"and point.objectID==142702 and map==1425 and x==23.6 and y==58.7)
C_Map.GetMapInfo=function(id)return{name=id==1455 and"Ironforge"or"The Hinterlands"}end
local provider=assert(a.SourceAreaName);local nativeNavigation=a.Navigation
local routes={}
a.Navigation={Start=function(action)routes[#routes+1]=action;return true end,Map=function()error("actual bottle has a precise recorded point")end}
local function render(id,tab)
 ui.dungeon,ui.quest,ui.includeUnavailable,ui.range=dungeon,id or 2933,true,false
 ui.questTreeRoot,ui.questTreeDungeon=nil,nil;ui:Refresh()
 assert(ui.quest==(id or 2933)and ui.renderedQuest==ui.quest)
 if ui.detailTab~=(tab or"sources")then assert(ui:SetDetailTab(tab or"sources"))end
end
local function first()
 local row=assert(ui.giverButtons[1]);assert(row.shown and row.enabled and row.scripts.OnClick);return row
end
-- Visible body text or source-owned compact contact tooltip metadata.
local function represented(text)
 for _,field in ipairs(ui.details)do if field.shown and field.text and field.text:find(text,1,true)then return field end end
 for index,row in ipairs(ui.detailContactRows or{})do
  local binding=row.detailContactBinding
  if row:IsShown()and binding and binding.questID==ui.quest and binding.field==(index==1 and "start"or"finish")and
   binding.endpoint==a.quests[ui.quest][binding.field]and binding.current()then
   for _,field in ipairs({row.title,row.note})do
    if not field:IsShown()and field.text and field.text:find(text,1,true)then return field end
   end
  end
 end
end
local function exact(row)
 local n=#routes;row.scripts.OnClick(row,"LeftButton",false)
 local action=assert(routes[#routes]);assert(#routes==n+1 and action.id==2933 and action.kind=="visit"and action.place==point)
 assert(point.objectID==142702 and point.mapID==map and point.x==x and point.y==y and point.zoneName==area)
end
for _,case in ipairs({{"ruRU","Внутренние земли"},{"zhCN","辛特兰"}})do
 a.db.locale=case[1];render()
 local expectedName=a.SourceName(point)or source
 assert(first().title.text==expectedName,"object-name translation remains a separate typed lookup")
 assert(first().note.text:find(case[2],1,true)and not first().note.text:find(area,1,true),"actual2933 world area follows selected language instead of native English")
 assert(first().note.text:find("23.6, 58.7",1,true)and #routes==0,"area presentation never changes coordinates or starts navigation")
end
a.db.locale="ruRU";render(2204,"quest")
assert(represented("Стальгорн")and not represented("Ironforge"),"actual2204 turn-in uses the reviewed world-area caption")
assert(a.quests[2204].finish.mapID==1455 and a.quests[2204].finish.x==36 and a.quests[2204].finish.y==3.4)
local root=a.nameTranslations;local ru=assert(root.ruRU);local zh=assert(root.zhCN)
local areas=assert(ru.areas);local entry=assert(areas[area]);local registry=assert(a.sourceAreaNames)
local definition=assert(registry[area]);local translated=entry.name
assert(entry.source==area and translated=="Внутренние земли"and definition.name==area)
-- The area resolver performs no native hydration of names or quests.
local request,item,npc=C_QuestLog.RequestLoadQuestByID,a.ItemName,a.GiverName;local hydration=0
C_QuestLog.RequestLoadQuestByID=function()hydration=hydration+1;error("area captions do not request quest hydration")end
a.ItemName=function()hydration=hydration+1;error("area captions do not query items")end
a.GiverName=function()hydration=hydration+1;error("area captions do not query NPCs")end
assert(a.SourceAreaName(area)==translated and hydration==0)
assert(a.SourceAreaName("Blackrock Spire")==nil,"ambiguous broad area remains unreviewed")
assert(a.SourceAreaName("Westfall")=="Западный Край","explicit reviewed case choice supplies the observed Russian spelling")
a.db.locale="itIT";assert(a.SourceAreaName(area)==nil,"missing reviewed Italian world-area data keeps fallback semantics")
C_QuestLog.RequestLoadQuestByID,a.ItemName,a.GiverName=request,item,npc
local function reset()
 a.SourceAreaName=provider;a.nameTranslations=root;root.ruRU=ru;root.zhCN=zh;ru.areas=areas;areas[area]=entry
 entry.source,entry.name=area,translated;a.sourceAreaNames=registry;registry[area]=definition;definition.name=area
 point.zoneName=area;a.db.locale="ruRU";ui.frame:Show()
end
for _,mode in ipairs({"helper","entry-name","entry-source","entry","areas","dictionary","root","registry","registry-entry","registry-name","locale","source","missing-entry-added"})do
 reset()
 if mode=="missing-entry-added"then areas[area]=nil end
 render();local row=first();local click=row.scripts.OnClick;local before=#routes
 local selected,engine,plan=ui.quest,ui.engine,ui.currentPlan
 if mode=="helper"then a.SourceAreaName=function(...)return provider(...)end
 elseif mode=="entry-name"then entry.name="Изменённая область"
 elseif mode=="entry-source"then entry.source="Different canonical area"
 elseif mode=="entry"then areas[area]={source=area,name=translated}
 elseif mode=="areas"then local copy={};for k,v in pairs(areas)do copy[k]=v end;ru.areas=copy
 elseif mode=="dictionary"then local copy={};for k,v in pairs(ru)do copy[k]=v end;root.ruRU=copy
 elseif mode=="root"then local copy={};for k,v in pairs(root)do copy[k]=v end;a.nameTranslations=copy
 elseif mode=="registry"then local copy={};for k,v in pairs(registry)do copy[k]=v end;a.sourceAreaNames=copy
 elseif mode=="registry-entry"then registry[area]={name=area}
 elseif mode=="registry-name"then definition.name="Different canonical area"
 elseif mode=="locale"then a.db.locale="zhCN"
 elseif mode=="source"then point.zoneName="Changed source area"
 else areas[area]=entry end
 click(row,"LeftButton",false)
 assert(#routes==before and ui.quest==selected and ui.engine==engine and ui.currentPlan==plan,mode..": retired area label dispatched or replaced the inspected plan")
end
reset();render();exact(first())

-- Resolver and retained proof reentry must retire their previous card's caption and action.
reset();render();local fired=false
a.SourceAreaName=function(name,current)
 local text,proof,raw=provider(name,current)
 if not fired and name==area then fired=true;ui:InspectQuest(2204,true,true);return"Retired world-area caption",proof,raw end
 return text,proof,raw
end
local before=#routes;ui:RefreshDetail()
assert(fired and ui.quest==2204 and ui.renderedQuest==2204 and not represented("Retired world-area caption")and #routes==before)
reset();local armedProof,proofFired=false,false
a.SourceAreaName=function(name,current)
 local text,proof,raw=provider(name,current)
 if name==area and proof then return text,function()
  if armedProof then armedProof,proofFired=false,true;ui:InspectQuest(2204,true,true)end
  return proof()
 end,raw end
 return text,proof,raw
end
render();local row=first();local old=row.scripts.OnClick;before=#routes;armedProof=true;old(row,"LeftButton",false)
assert(proofFired and ui.quest==2204 and #routes==before,"area proof callback replaced the UI owner before a stale route dispatched")

for _,mode in ipairs({"same-card-locale","new-card"})do
 reset();render();row=first();local native=row.note.SetText;local armed,seen=true,false
 row.note.SetText=function(self,text)
  if armed and text:find(translated,1,true)then
   armed,seen=false,true
   if mode=="same-card-locale"then a.db.locale="zhCN";ui:RefreshDetail()else ui:InspectQuest(2204,true,true)end
  end
  return native(self,text)
 end
 before=#routes;ui:RefreshDetail();row.note.SetText=native
 assert(seen and #routes==before,"world-area native note reentry actually fired without routing")
 if mode=="same-card-locale"then
  assert(ui.quest==2933 and first().note.text:find("辛特兰",1,true)and not first().note.text:find(translated,1,true))
 else assert(ui.quest==2204 and not row.shown and not row.scripts.OnClick)end
end

-- Controlled listed-quest composition reuses the same actual bottle/point for route hints and the live guide.
-- It changes no recorded position and is never added to the catalogue.
reset();local primary=a.quests[2204]
local savedStart,savedAlternatives=primary.start,primary.startAlternatives;primary.start,primary.startAlternatives=point,nil
local tip={}
function tip:SetOwner(owner)self.owner=owner end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetText(text)self.title=text end
function tip:AddLine(text)self.body=text end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip;render(2204,"quest")
local middle;for _,candidate in ipairs(ui.rows)do if candidate.shown and candidate.questID==2204 then middle=candidate;break end end
assert(middle and middle.navigationBinding.action)
local selected,engine,plan=ui.quest,ui.engine,ui.currentPlan;before=#routes
middle.navigationControl.scripts.OnEnter()
assert(tip.shown and tip.body:find(translated,1,true)and not tip.body:find(area,1,true),"middle route hint uses selected reviewed world area")
local contact=assert(ui.detailContactRows[1]);local binding=assert(contact.detailContactBinding)
assert(contact:IsShown()and binding.current()and binding.questID==2204 and binding.field=="start"and binding.endpoint==point and
 binding.action.kind=="visit"and binding.action.place==point,"actual current contact retains its exact typed object route")
assert(not contact.detailPurpose:IsShown()and contact.detailPurpose.text==a.L("DETAIL_GIVER")and
 contact.title.text==(a.SourceName(point)or source)and contact.note.text==translated,"contact purpose, actor and translated area remain available independently")
assert(not ui.giver:IsShown()and not ui.giver.enabled and ui.giver.scripts.OnClick==nil,"retired giver has no duplicate contact capability")
assert(#routes==before and ui.quest==selected and ui.engine==engine and ui.currentPlan==plan,"hints never start navigation or rebuild the inspected plan")
local savedNavigation = a.Navigation; a.Navigation = nativeNavigation
assert(nativeNavigation.Start({id=2204,kind="visit",place=point}),"guide starts only through an explicit manual request")
a.Navigation = savedNavigation
local guide;for _,object in ipairs(f.objects)do if object.title and object.note and object.label and object.scripts.OnUpdate then guide=object end end
assert(guide and guide.shown and guide.note.text:find(translated,1,true)and not guide.note.text:find(area,1,true),"guide prefers selected area over the native English map name")
assert(guide.note.text:find(a.SourceName(point),1,true),"guide retains the independent typed object label")
entry.name="Изменённая область";guide.scripts.OnUpdate(guide,.11)
assert(guide.note.text:find(entry.name,1,true)and not guide.note.text:find(translated,1,true),"guide retires an area-only dictionary edit before its periodic context refresh")
entry.name=translated;areas[area]=nil;guide.scripts.OnUpdate(guide,.11)
assert(guide.note.text:find(area,1,true),"valid missing reviewed area keeps the native/canonical fallback")
areas[area]=entry;guide.scripts.OnUpdate(guide,.11)
assert(guide.note.text:find(translated,1,true)and not guide.note.text:find(area,1,true),"retained absence proof notices a newly available area label")
a.db.locale="zhCN";guide.scripts.OnUpdate(guide,.11)
assert(guide.note.text:find("辛特兰",1,true)and guide.note.text:find(a.SourceName(point)or source,1,true),"guide updates selected area and independent object label together")
assert(#routes==before and ui.quest==selected and ui.engine==engine and ui.currentPlan==plan,"area-only guide refresh does not issue another navigation request or rebuild the plan")
nativeNavigation.Stop();primary.start,primary.startAlternatives=savedStart,savedAlternatives
assert(point.name==source and point.zoneName==area and point.objectID==142702 and point.mapID==map and point.x==x and point.y==y)
print("World-area caller retirement UI: PASS (actual world captions, thirteen invalidations, fired helper/proof/native reentry, hints and explicit guide; modeled only)")
