-- Reviewed dungeon area captions follow the selected language without changing destinations.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
C_Timer={After=function()end};issecretvalue=function()return false end;GetLocale=function()return"enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle();ui.includeUnavailable=true
a.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
a.DialogueRewards,a.QuestRewards,a.CachedQuestRewards=function()end,function()end,function()end
local visits,maps=0,0
a.Navigation={Start=function()visits=visits+1;return true end,Map=function()maps=maps+1;return true end}
local owners,dungeons={},{}
for _,d in ipairs(a.dungeons)do dungeons[d.name]=d;for _,id in ipairs(d.quests)do owners[id]=owners[id]or d end end
local function render(id,inspection)
 ui.dungeon,ui.quest=assert(inspection or owners[id]),id;ui:Refresh()
 if ui.detailTab~="quest"then assert(ui:SetDetailTab("quest"))end
 assert(ui.quest==id and ui.renderedQuest==id,"actual source identity remains inspected")
end
local function field(text)
 for _,value in ipairs(ui.details)do if value:IsShown()and value.text:find(text,1,true)then return value end end
end
local function label(locale,canonical)
 if locale=="enUS"then return canonical end
 local dictionary=assert(a.GetNameTranslations(locale,function()return true end))
 return assert(dictionary.dungeons[assert(dungeons[canonical]).key]).name
end
local tip={}
function tip:SetOwner(owner)self.owner=owner end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetText(text)self.title=text end
function tip:AddLine(text)self.body=text end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","koKR","zhCN","zhTW","itIT"})do
 a.db.locale=locale
 for _,sample in ipairs({{7046,"start","Maraudon"},{7044,"finish","Maraudon"},{2951,"start","Gnomeregan"},{2945,"finish","Gnomeregan"},{2278,"start","Uldaman"},{2398,"finish","Uldaman"}})do
  local id,role,canonical=unpack(sample);local q=assert(a.quests[id]);assert(q[role].zoneName==canonical)
  render(id,owners[id]or dungeons[canonical])
  assert(field(q[role].name.." — "..label(locale,canonical)),"actual recorded area uses its reviewed selected-language label: "..locale.."/"..id)
 end
 -- Broad Spire has no exact unique canonical dictionary identity; no wing is inferred.
 render(5160)
 assert(field(a.quests[5160].start.name.." — Blackrock Spire"),"generic source area stays original instead of guessing a wing")
end
-- Controlled renderer variants retain the actual Maraudon NPC, without publishing a new source fact.
a.db.locale="zhCN"
local q=a.quests[7046];local start,alternatives=q.start,q.startAlternatives
q.start=nil;q.startAlternatives={start};render(7046);assert(ui:SetDetailTab("sources"))
assert(ui.giverButtons[1]:IsShown()and ui.giverButtons[1].note.text:find(label("zhCN","Maraudon"),1,true),"alternative source captions use the same reviewed area name")
q.start,q.startAlternatives=start,alternatives
-- A formatter-only mapped fixture opposes the canonical source label to the native map name.
-- Existing world-map coordinates are copied unchanged solely to exercise reported/hint rendering.
local world=a.quests[7494].startAlternatives[1]
local point={npcID=start.npcID,name=start.name,zoneName=start.zoneName,mapID=world.mapID,x=world.x,y=world.y,
 reportedLocations={{mapID=world.mapID,x=world.x,y=world.y,zoneName=start.zoneName},{mapID=world.mapID,x=world.x,y=world.y+0.1,zoneName=start.zoneName}}}
q.start=point
local mapRoot=C_Map;C_Map={GetMapInfo=function()return{name="Opposite native label"}end}
render(7046);ui.reportedExpanded["start"]=true;assert(ui:SetDetailTab("sources"));ui:RefreshDetail()
local reported=0
for _,button in ipairs(ui.reportedRows)do if button:IsShown()then
 reported=reported+1;assert(button.title.text:find(label("zhCN","Maraudon"),1,true)and not button.title.text:find("Opposite native label",1,true),"reported source area prefers selected dictionary over native map language")
end end
assert(reported==2,"controlled reported fixture actually exercised both point rows")
local sourceRow
for _,row in ipairs(ui.rows)do if row:IsShown()and row.questID==7046 then sourceRow=row end end
assert(sourceRow);sourceRow.navigationControl.scripts.OnEnter()
assert(tip.body:find(label("zhCN","Maraudon"),1,true)and not tip.body:find("Opposite native label",1,true),"row hint uses the same reviewed canonical area")
assert(ui:SetDetailTab("quest"));ui.giver.scripts.OnEnter();assert(tip.body:find(label("zhCN","Maraudon"),1,true),"detail route hint shares the selected source-area name")
q.start=start;C_Map=mapRoot
-- World locations outside the dungeon dictionary keep native/raw fallback labels.
render(1491);sourceRow=nil
for _,row in ipairs(ui.rows)do if row:IsShown()and row.questID==1491 then sourceRow=row end end
assert(sourceRow and sourceRow.navigationBinding.action);sourceRow.navigationControl.scripts.OnEnter()
assert(tip.body:find(a.quests[1491].start.zoneName,1,true),"outside-catalogue world area retains its existing raw fallback in the source hint")
-- Resolver callbacks that replace source, locale, or helper cannot publish retired captions.
local provider=a.SourceAreaName
for _,mode in ipairs({"card","source","locale","method"})do
 a.db.locale="zhCN";local armed,fired=true,false
 a.SourceAreaName=function(name,current)
  local value=provider(name,current)
  if armed and name=="Maraudon"then
   armed,fired=false,true
   if mode=="card"then render(98423)
   elseif mode=="source"then start.zoneName="Gnomeregan";render(7046)
   elseif mode=="locale"then a.db.locale="ruRU";render(7046)
   else a.SourceAreaName=provider;render(98423)end
   return"Retired area label"
  end
  return value
 end
 ui.dungeon,ui.quest=assert(owners[7046]),7046;ui:Refresh();a.SourceAreaName=provider
 assert(fired and not field("Retired area label"),"source-area callback actually expired its old result: "..mode)
 assert(ui.renderedQuest==((mode=="locale"or mode=="source")and 7046 or 98423),"new source context wins resolver reentry: "..mode)
 start.zoneName="Maraudon"
end
-- A retired native text tail cannot restore the old language after a new locale render.
a.db.locale="zhCN";render(7046)
local chinese=label("zhCN","Maraudon");local line=assert(field(start.name.." — "..chinese))
local setter=line.SetText;local armed,fired=true,false
line.SetText=function(self,text,...)
 if armed and text:find(chinese,1,true)then armed,fired=false,true;a.db.locale="ruRU";render(7046)end
 return setter(self,text,...)
end
ui:RefreshDetail();line.SetText=setter
assert(fired and a.db.locale=="ruRU"and field(start.name.." — "..label("ruRU","Maraudon")),"new locale caption survives the retired native label write")
assert(not field(start.name.." — "..chinese),"retired native text does not revive the old source-area language")
assert(visits==0 and maps==0,"area translation never routes automatically")
print("Source area names UI: PASS (actual sources, controlled renderer fixtures; modeled UI only)")
