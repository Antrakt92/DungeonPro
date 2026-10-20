-- Typed source labels must preserve the owner of their visible manual action.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
C_Timer={After=function()end};issecretvalue=function()return false end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle()
a.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
a.DialogueRewards,a.QuestRewards,a.CachedQuestRewards=function()end,function()end,function()end
C_Map.GetMapInfo=function()return nil end
local dungeon
for _,d in ipairs(a.dungeons)do if d.key=="ulda"then dungeon=d end end
assert(dungeon,"actual Uldaman catalogue is available")
local point=assert(a.quests[2933].startAlternatives[1])
assert(point.objectID==142702 and point.npcID==nil and point.itemID==nil)
local originalName,objectID,x,y,map=point.name,point.objectID,point.x,point.y,point.mapID
local originalResolver=assert(a.SourceName,"typed source-name resolver is available")
local routes={}
a.Navigation={Start=function(action)routes[#routes+1]=action;return true end,Map=function()error("precise object source is not map-only")end}
local function dictionaries()
 local root={}
 for _,locale in ipairs({"ruRU","zhCN"})do
  root[locale]={quests={},dungeons={},objects={[objectID]={source=originalName,name=locale=="ruRU"and"Проверенная бутылка"or"已核实的瓶子"}}}
 end
 a.nameTranslations=root
 a.nameTranslationFactories={root=root,loaders={}}
 return root
end
local function reset()
 point.name,point.objectID,point.npcID,point.itemID=originalName,objectID,nil,nil
 point.x,point.y,point.mapID=x,y,map
 a.SourceName=originalResolver
 a.db.locale="ruRU";ui.frame:Show();dictionaries()
end
local function render(id)
 ui.dungeon,ui.quest=dungeon,id or 2933;ui.questTreeRoot,ui.questTreeDungeon=nil,nil
 ui.includeUnavailable=true;ui.range=false;ui:Refresh()
 assert(ui.quest==(id or 2933))
 if ui.detailTab~="sources"then assert(ui:SetDetailTab("sources"))end
end
local function first()
 local row=assert(ui.giverButtons[1]);assert(row.shown and row.enabled and row.scripts.OnClick)
 return row
end
local function exactRoute(row)
 local count=#routes;row.scripts.OnClick(row,"LeftButton",false)
 local action=assert(routes[#routes])
 assert(#routes==count+1 and action.id==2933 and action.kind=="visit"and action.place==point)
 assert(point.objectID==objectID and point.npcID==nil and point.itemID==nil and point.mapID==map and point.x==x and point.y==y)
end
reset();render()
assert(first().title.text=="Проверенная бутылка","actual typed bottle uses the selected reviewed source label")
exactRoute(first())
assert(point.name==originalName,"localized presentation does not rewrite recorded source bytes")

-- A click bound to an older visible label cannot outlive its reviewed-name proof.
for _,mode in ipairs({"entry-name","entry-source","entry","kind-table","dictionary","root","locale","resolver","source-name","source-id","source-role"})do
 reset();render();local row=first();local click=row.scripts.OnClick;local before=#routes
 local root=a.nameTranslations;local entry=root.ruRU.objects[objectID]
 if mode=="entry-name"then entry.name="New reviewed label"
 elseif mode=="entry-source"then entry.source="Different source identity"
 elseif mode=="entry"then root.ruRU.objects[objectID]={source=originalName,name=entry.name}
 elseif mode=="kind-table"then root.ruRU.objects={[objectID]=entry}
 elseif mode=="dictionary"then root.ruRU={quests={},dungeons={},objects={[objectID]=entry}}
 elseif mode=="root"then a.nameTranslations={ruRU=root.ruRU}
 elseif mode=="locale"then a.db.locale="zhCN"
 elseif mode=="resolver"then a.SourceName=function(...)return originalResolver(...)end
 elseif mode=="source-name"then point.name="Changed recorded source"
 elseif mode=="source-id"then point.objectID=142703
 else point.npcID=objectID end
 click(row,"LeftButton",false)
 assert(#routes==before,mode..": stale translated source row dispatched a visit")
end

-- The helper itself may synchronously replace the inspected card before returning.
reset();render();local fired=false
a.SourceName=function(place,current)
 local name,proof,rawProof=originalResolver(place,current)
 if not fired and place==point then
  fired=true;ui:InspectQuest(739,true,true)
  return"Retired translated bottle",proof,rawProof
 end
 return name,proof,rawProof
end
ui:RefreshDetail()
assert(fired and ui.quest==739 and ui.renderedQuest==739,"source-name helper actually replaced the selected card")
for _,row in ipairs(ui.giverButtons)do assert(not row.shown,"old alternative cannot survive replacement by a single typed giver")end
for _,field in ipairs(ui.details)do assert(not(field.shown and field.text:find("Retired translated bottle",1,true)))end
local replacement=assert(ui.detailContactRows[1]);local binding=assert(replacement.detailContactBinding)
assert(replacement:IsShown()and replacement.enabled and replacement.scripts.OnClick and binding.current()and
 binding.questID==739 and binding.field=="start"and binding.endpoint==a.quests[739].start and
 binding.endpoint.objectID==2875 and binding.action.id==739 and binding.action.kind=="visit"and binding.action.place==binding.endpoint,
 "replacement contact owns its distinct current typed object source and manual action")

-- A retained name proof is callback-capable; a click must recheck its UI owner afterward.
reset();local armedProof,proofFired=false,false
a.SourceName=function(place,current)
 local name,proof,rawProof=originalResolver(place,current)
 if place==point and proof then return name,function()
  if armedProof then armedProof,proofFired=false,true;ui:InspectQuest(739,true,true)end
  return proof()
 end,rawProof end
 return name,proof,rawProof
end
render();local oldRow=first();local oldClick=oldRow.scripts.OnClick;local routeCount=#routes
armedProof=true;oldClick(oldRow,"LeftButton",false)
assert(proofFired and ui.quest==739 and #routes==routeCount,"retained name proof replaced the UI owner before an old click dispatched")

-- A late native SetText tail must preserve the newer locale or selected quest.
for _,mode in ipairs({"same-card-locale","new-card"})do
 reset();render();local row=first();local native=row.title.SetText;local armed,seen=true,false
 row.title.SetText=function(self,text)
  if armed and text=="Проверенная бутылка"then
   armed,seen=false,true
   if mode=="same-card-locale"then a.db.locale="zhCN";ui:RefreshDetail()
   else ui:InspectQuest(739,true,true)end
  end
  return native(self,text)
 end
 ui:RefreshDetail();row.title.SetText=native
 assert(seen,mode..": translated native label publication did not fire")
 if mode=="same-card-locale"then
  assert(ui.quest==2933 and first().title.text=="已核实的瓶子","late old text replaced the newest selected-locale label")
  exactRoute(first())
 else
  assert(ui.quest==739 and not row.shown and not row.scripts.OnClick,"late old source row survived replacement quest")
  local row=assert(ui.detailContactRows[1]);local binding=assert(row.detailContactBinding)
  assert(row:IsShown()and row.enabled and row.scripts.OnClick and binding.current()and binding.questID==739 and binding.field=="start"and
   binding.endpoint==a.quests[739].start and binding.endpoint.objectID==2875 and binding.action.id==739 and
   binding.action.kind=="visit"and binding.action.place==binding.endpoint)
 end
end
-- Optional resolver omission keeps the recorded name and the same typed route.
reset();a.SourceName=nil;render()
assert(first().title.text==originalName,"missing optional translation helper retains the recorded label")
exactRoute(first())
reset();render()
print("Source-name caller retirement checks passed: actual typed object, eleven invalidations, fired helper and native publication reentry")
