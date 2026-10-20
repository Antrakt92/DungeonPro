-- Known source identity/area remains distinct from an unknown exact position.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
C_Timer={After=function()end};issecretvalue=function()return false end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle();ui.includeUnavailable=true
a.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
a.DialogueRewards,a.QuestRewards,a.CachedQuestRewards=function()end,function()end,function()end
local owners={}
for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=d end end
local function render(id,context)
 ui.dungeon=assert(context or owners[id]);ui.quest=id;ui:Refresh()
 assert(ui.renderedQuest==id,"actual inspected source remains current")
end
local function count(key)
 local n=0
 for _,field in ipairs(ui.details)do if field:IsShown()and field.text==a.L(key)then n=n+1 end end
 return n
end
local function named(name)
 for _,field in ipairs(ui.details)do if field:IsShown()and field.text and field.text:find(name,1,true)then return true end end
 for _,button in ipairs(ui.containerButtons or {})do if button:IsShown()then
  for _,field in ipairs({button.title,button.note})do if field.text and field.text:find(name,1,true)then return true end end
 end end
 for _,row in ipairs(ui.detailContactRows or {})do if row:IsShown()then
  for _,field in ipairs({row.title,row.note})do if field.text and field.text:find(name,1,true)then return true end end
 end end
 return false
end
local function sources(id,context)
 render(id,context);assert(ui:SetDetailTab("sources")and ui.detailTab=="quest")
end
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","koKR","zhCN","zhTW","itIT"})do
 a.db.locale=locale
 for _,id in ipairs({96395,5724})do
  render(id)
  assert(count("SOURCE_POSITION_UNKNOWN")==1 and count("GIVER_LOCATION_UNKNOWN")==0,"known area warns about exact position, not wholly unknown location")
  assert(ui.giverUnavailableKey=="SOURCE_POSITION_UNKNOWN"and not ui.giver.enabled,"known area does not invent a usable map route")
  local area=false
  local expectedArea=id==5724 and locale~="enUS"and a.DungeonName(owners[id])or a.quests[id].start.zoneName
  for _,field in ipairs(ui.details)do if field:IsShown()then
   if field.text:find(expectedArea,1,true)then area=true end
   if field.text==a.L("SOURCE_POSITION_UNKNOWN")then assert(field.detailStyle=="warning","unknown exact position uses the explicit warning style")end
  end end
  local contact=ui.detailContactRows and ui.detailContactRows[1]
  if contact and contact:IsShown()then
   assert(contact.detailContactBinding.endpoint==a.quests[id].start and contact.detailContactBinding.current(),"known source area belongs to the exact selected pickup")
   if contact.note.text:find(expectedArea,1,true)then area=true end
  end
  assert(area,"recorded known area remains visible")
  local matched=false
  for _,row in ipairs(ui.rows)do if row:IsShown()and row.questID==id then
   matched=true;assert(row.navigationBinding.reason=="SOURCE_POSITION_UNKNOWN"and not row.navigationControl.enabled,"row source hint shares the precise-position distinction without a map route")
  end end
  assert(matched,"actual known-area quest remains listed in All mode")
 end
 -- The reviewed WC source proves only the continent; it must never become a point route.
 local wc=assert(a.quests[1486]);local originalStart,originalFinish=wc.start,wc.finish
 local originalMap,originalRoute=a.Navigation.Map,a.Navigation.Start
 local mapCalls,routeCalls=0,0
 a.Navigation.Map=function(point,purpose,id,current)
  mapCalls=mapCalls+1
  assert(point==originalStart and point.mapID==1414 and point.x==nil and point.y==nil and point.reportedLocations==nil,
   "actual WC endpoint remains a continent-only map without projected points")
  assert(id==1486 and purpose=="quest-start"and current(),"manual map request owns its exact selected quest")
  return true
 end
 a.Navigation.Start=function()routeCalls=routeCalls+1;error("map-only continent cannot start a point route")end
 local ok,failure=pcall(function()
  render(1486)
  assert(originalStart.npcID==5767 and originalStart.mapID==1414 and originalStart.x==nil and originalStart.y==nil and originalStart.reportedLocations==nil)
  assert(count("GIVER_LOCATION_UNKNOWN")==0 and count("SOURCE_POSITION_UNKNOWN")==0 and ui.giverUnavailableKey=="GIVER_COORDINATES_UNKNOWN",
   "known continent permits map inspection while exact coordinates remain unknown")
  local contact=assert(ui.detailContactRows[1]);local binding=assert(contact.detailContactBinding)
  assert(contact:IsShown()and contact.enabled and binding.endpoint==originalStart and binding.questID==1486 and binding.field=="start"and
   binding.mapOnly and binding.reason==nil and binding.current()and contact.note.text:find(originalStart.zoneName,1,true))
  assert(mapCalls==0 and routeCalls==0,"rendering a map-only source never navigates automatically")
  contact.scripts.OnClick();assert(mapCalls==1 and routeCalls==0,"explicit contact click opens only the known continent map")
  -- Isolate the wholly unknown-location behavior from the now-known factual WC map.
  wc.start={npcID=originalStart.npcID,name=originalStart.name,creatureDisplayID=originalStart.creatureDisplayID,portraitSource=originalStart.portraitSource}
  wc.finish=wc.start
  render(1486)
  assert(count("GIVER_LOCATION_UNKNOWN")==1 and count("SOURCE_POSITION_UNKNOWN")==0,"wholly unknown NPC location retains its full warning")
  local unknown=assert(ui.detailContactRows[1]);local unavailable=assert(unknown.detailContactBinding)
  assert(unknown:IsShown()and not unknown.enabled and unknown.scripts.OnClick==nil and unavailable.endpoint==wc.start and
   unavailable.questID==1486 and unavailable.reason=="SOURCE_POSITION_UNKNOWN"and unavailable.action==nil and unavailable.current(),
   "detached source without any area remains visible but has no navigation capability")
  assert(mapCalls==1 and routeCalls==0,"unknown source cannot add a map or point route")
 end)
 wc.start,wc.finish=originalStart,originalFinish;a.Navigation.Map,a.Navigation.Start=originalMap,originalRoute
 assert(ok,failure)
 assert(wc.start==originalStart and wc.finish==originalFinish,"each locale restores both exact factual endpoint objects")
 for _,id in ipairs({95189,95204})do
  render(id)
  assert(named(a.quests[id].start.containerSource.name)and count("SOURCE_POSITION_UNKNOWN")==0 and count("START_ITEM_LOCATION_UNKNOWN")==0,
   "the complete container row owns its warning without duplicate unknown-source prose")
  local containers=0
  for _,button in ipairs(ui.containerButtons)do if button:IsShown()then
   containers=containers+1
   assert(button.title.text==a.quests[id].start.containerSource.name and not button.enabled and not button.scripts.OnClick,
    "the current own container appears once and never invents a route")
   assert(button.note.text=="|cffff594d"..a.L("SOURCE_POSITION_UNKNOWN").."|r",
    "one explicit warning remains visibly styled beside its own container")
  end end
  assert(containers==1,"the stream has exactly one full container row")
  assert(ui:SetDetailTab("sources"))
  local shown=0
  for _,button in ipairs(ui.containerButtons)do if button:IsShown()then
   shown=shown+1
   assert(button.title.text==a.quests[id].start.containerSource.name and not button.enabled,"known container identity remains, without a guessed route")
   assert(button.note.text=="|cffff594d"..a.L("SOURCE_POSITION_UNKNOWN").."|r","unknown container point is one explicit warning")
  end end
  assert(shown==1 and count("START_ITEM_LOCATION_UNKNOWN")==0 and count("SOURCE_POSITION_UNKNOWN")==0,"container warning is not repeated as separate source-unknown prose")
 end
 -- Standalone journal is inspected without adding it to a dungeon target list.
 assert(not owners[1100]);render(1100,assert(owners[1491]))
 assert(named(a.quests[1100].start.containerSource.name)and count("SOURCE_POSITION_UNKNOWN")==0,
  "Quest retains a known exact container without a false warning")
 assert(ui:SetDetailTab("sources"))
 local knownContainers=0
 for _,button in ipairs(ui.containerButtons)do if button:IsShown()then
  knownContainers=knownContainers+1
  assert(button.enabled and not button.note.text:find(a.L("SOURCE_POSITION_UNKNOWN"),1,true),"known exact container location has no false warning")
 end end
 assert(knownContainers==1,"actual known container remains displayed")
 render(98423)
 assert(count("START_ITEM_LOCATION_UNKNOWN")==1 and count("SOURCE_POSITION_UNKNOWN")==0,"unknown item acquisition retains exactly one warning")
end
a.db.locale="enUS"
-- A named area remains useful even when its exact container position is unknown.
local namedContainer=a.quests[95189].start.containerSource
local originalZone=namedContainer.zoneName
namedContainer.zoneName="Known container area";render(95189)
assert(named(namedContainer.name)and named("Known container area")and count("SOURCE_POSITION_UNKNOWN")==0,
 "the stream preserves named container area and no duplicated standalone position warning")
assert(ui:SetDetailTab("sources"))
local namedButton=assert(ui.containerButtons[1])
assert(namedButton:IsShown()and not namedButton.enabled and not namedButton.scripts.OnClick,"named container without a map does not invent navigation")
assert(namedButton.note.text=="Known container area — |cffff594d"..a.L("SOURCE_POSITION_UNKNOWN").."|r","known container area is retained beside one exact-position warning")
assert(count("START_ITEM_LOCATION_UNKNOWN")==0 and count("SOURCE_POSITION_UNKNOWN")==0,"named-container warning is not duplicated as unknown-source prose")
namedContainer.zoneName=originalZone;sources(95189)
assert(ui.containerButtons[1].note.text=="|cffff594d"..a.L("SOURCE_POSITION_UNKNOWN").."|r","restoring the actual mapless container restores its area-free warning")
local localize,armed,fired=a.L,true,false
a.L=function(key,...)
 local value=localize(key,...)
 if armed and key=="SOURCE_POSITION_UNKNOWN"then
  armed,fired=false,true;render(6981)
  return "Retired source-position warning"
 end
 return value
end
ui.dungeon,ui.quest=assert(owners[96395]),96395;ui:Refresh()
a.L=localize
assert(fired and ui.quest==6981 and ui.renderedQuest==6981,"warning localization callback actually completed a newer source card")
for _,field in ipairs(ui.details)do assert(not field:IsShown()or field.text~="Retired source-position warning","retired warning cannot overwrite newer source content")end
-- A retired native note setter must not overwrite a newly rendered exact container point.
sources(1100,assert(owners[1491]));local button=assert(ui.containerButtons[1]);local expected=button.note.text
sources(95189);assert(button==ui.containerButtons[1])
local setter=button.note.SetText;armed,fired=true,false
button.note.SetText=function(self,text,...)
 if armed and text:find(a.L("SOURCE_POSITION_UNKNOWN"),1,true)then
  armed,fired=false,true;sources(1100,assert(owners[1491]))
 end
 return setter(self,text,...)
end
ui.dungeon,ui.quest=assert(owners[95189]),95189;ui:Refresh();ui:SetDetailTab("sources");button.note.SetText=setter
assert(fired and ui.quest==1100 and ui.renderedQuest==1100 and button:IsShown(),"native warning setter actually completed a newer known-container card")
assert(button.note.text==expected and not button.note.text:find(a.L("SOURCE_POSITION_UNKNOWN"),1,true),"retired native warning tail restores the newest owned exact-point note")
print("Source location warnings: PASS (actual TOC;10locales, knownarea/unknownNPC/container distinctions; modeled rendering)")
