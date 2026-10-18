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
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","koKR","zhCN","zhTW","itIT"})do
 a.db.locale=locale
 for _,id in ipairs({96395,5724})do
  render(id)
  assert(count("SOURCE_POSITION_UNKNOWN")==1 and count("GIVER_LOCATION_UNKNOWN")==0,"known area warns about exact position, not wholly unknown location")
  assert(ui.giverUnavailableKey=="SOURCE_POSITION_UNKNOWN"and not ui.giver.enabled,"known area does not invent a usable map route")
  local area=false
  for _,field in ipairs(ui.details)do if field:IsShown()then
   if field.text:find(a.quests[id].start.zoneName,1,true)then area=true end
   if field.text==a.L("SOURCE_POSITION_UNKNOWN")then assert(field.detailStyle=="warning","unknown exact position uses the explicit warning style")end
  end end
  assert(area,"recorded known area remains visible")
  local matched=false
  for _,row in ipairs(ui.rows)do if row:IsShown()and row.questID==id then
   matched=true;assert(row.navigationBinding.reason=="SOURCE_POSITION_UNKNOWN"and not row.navigationControl.enabled,"row source hint shares the precise-position distinction without a map route")
  end end
  assert(matched,"actual known-area quest remains listed in All mode")
 end
 render(1486)
 assert(count("GIVER_LOCATION_UNKNOWN")==1 and count("SOURCE_POSITION_UNKNOWN")==0,"wholly unknown NPC location retains its full warning")
 for _,id in ipairs({95189,95204})do
  render(id)
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
local namedButton=assert(ui.containerButtons[1])
assert(namedButton:IsShown()and not namedButton.enabled and not namedButton.scripts.OnClick,"named container without a map does not invent navigation")
assert(namedButton.note.text=="Known container area — |cffff594d"..a.L("SOURCE_POSITION_UNKNOWN").."|r","known container area is retained beside one exact-position warning")
assert(count("START_ITEM_LOCATION_UNKNOWN")==0 and count("SOURCE_POSITION_UNKNOWN")==0,"named-container warning is not duplicated as unknown-source prose")
namedContainer.zoneName=originalZone;render(95189)
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
render(1100,assert(owners[1491]));local button=assert(ui.containerButtons[1]);local expected=button.note.text
render(95189);assert(button==ui.containerButtons[1])
local setter=button.note.SetText;armed,fired=true,false
button.note.SetText=function(self,text,...)
 if armed and text:find(a.L("SOURCE_POSITION_UNKNOWN"),1,true)then
  armed,fired=false,true;render(1100,assert(owners[1491]))
 end
 return setter(self,text,...)
end
ui.dungeon,ui.quest=assert(owners[95189]),95189;ui:Refresh();button.note.SetText=setter
assert(fired and ui.quest==1100 and ui.renderedQuest==1100 and button:IsShown(),"native warning setter actually completed a newer known-container card")
assert(button.note.text==expected and not button.note.text:find(a.L("SOURCE_POSITION_UNKNOWN"),1,true),"retired native warning tail restores the newest owned exact-point note")
print("Source location warnings: PASS (actual TOC;10locales, knownarea/unknownNPC/container distinctions; modeled rendering)")
