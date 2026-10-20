-- Unknown starting methods remain distinct from unknown NPC positions or item acquisition.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
C_Timer={After=function()end};issecretvalue=function()return false end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle();ui.includeUnavailable=true
local context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
a.Context=context
local starts,maps=0,0
a.Navigation={Start=function()starts=starts+1;return true end,Map=function()maps=maps+1;return true end}
a.DialogueRewards,a.QuestRewards,a.CachedQuestRewards=function()end,function()end,function()end
local owners={}
for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=owners[id]or d end end
local tip={}
function tip:SetOwner(owner)self.owner=owner end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetText(text)self.title=text end
function tip:AddLine(text)self.body=text end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip
local function render(id,inspection)
 ui.dungeon,ui.quest=assert(inspection or owners[id]),id;ui:Refresh()
 assert(ui.quest==id and ui.renderedQuest==id,"own actual quest remains inspected")
end
local function fields(text)
 local count,found=0,nil
 for _,field in ipairs(ui.details)do if field:IsShown()and field.text==text then count,found=count+1,field end end
 return count,found
end
local function row(id)
 for _,r in ipairs(ui.rows)do if r:IsShown()and r.questID==id then return r end end
 error("actual quest row not found "..id)
end
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","koKR","zhCN","zhTW","itIT"})do
 a.db.locale=locale
 for _,id in ipairs({96987,95809,95795,92415,95250,95775,95776,95787,95788})do
  local q=assert(a.quests[id]);assert(q.start==nil and q.startAlternatives==nil and q.requirementsKnown==false,"actual source method is absent rather than automatic")
  render(id)
  local count,warning=fields(a.L("QUEST_START_UNKNOWN"))
  assert(a.L("QUEST_START_UNKNOWN")~="QUEST_START_UNKNOWN"and count==1 and warning.detailStyle=="warning","one explicit localized warning describes the unknown starting method")
  assert(fields(a.L("SOURCE_DETAILS"))==1,"unknown starting method has a neutral source heading")
  assert(fields(a.L("GIVER_LOCATION_UNKNOWN"))==0 and fields(a.L("START_ITEM_LOCATION_UNKNOWN"))==0,"unknown source method does not imply an NPC or item source")
  assert(ui.giverUnavailableKey=="QUEST_START_UNKNOWN"and not ui.giver.enabled and not ui:NavigationDestination(false),"detail does not invent a visit route")
  ui.giver.scripts.OnEnter()
  assert(tip.title==a.L("SOURCE_DETAILS")and tip.body==a.L("QUEST_START_UNKNOWN"),"detail hint also names the unknown starting method without a visit promise")
  local r=row(id);local control=assert(r.navigationControl)
  assert(not control.enabled and not r.navigationBinding.action and not r.navigationBinding.inspect,"missing method remains disabled rather than automatic source inspection or travel")
  control.scripts.OnEnter()
  assert(tip.title==a.L("SOURCE_DETAILS")and tip.body==a.L("QUEST_START_UNKNOWN"),"disabled row hint explains the missing starting method under a neutral source title")
  if control.scripts.OnClick then control.scripts.OnClick()end
  assert(ui.quest==id and starts==0 and maps==0,"disabled missing-source click cannot dispatch or change selection")
  local state=ui.engine:State(id)
  local restricted=q.factions and q.factions[1]=="Horde"
  assert(state.status==(restricted and "UNAVAILABLE"or"UNKNOWN")and state.reason==(restricted and"faction"or"requirements"),"copy preserves existing audience restriction or unverified requirements without promoting readiness")
  local actions=ui.engine:Next(id);assert(#actions==0,"unknown source is not an inferred automatic pickup")
  if q.finish then
   assert(({[95809]=1480,[95795]=956,[92415]=14450})[id]==q.finish.npcID,"known finish identity remains its own recorded endpoint")
   local shown=false
   for _,field in ipairs(ui.details)do if field:IsShown()and field.text:find(a.L("DETAIL_TURNIN"),1,true)and field.text:find(q.finish.name,1,true)then shown=true end end
   assert(shown,"recorded turn-in is displayed separately from the unknown starting method")
  end
 end
 -- Nalpak still has no verified local source area or actionable position.
 render(1486)
 assert(fields(a.L("GIVER_LOCATION_UNKNOWN"))==1 and fields(a.L("QUEST_START_UNKNOWN"))==0,"typed unknown NPC retains its precise existing warning")
  render(98423)
  assert(fields(a.L("START_ITEM_LOCATION_UNKNOWN"))==1 and fields(a.L("QUEST_START_UNKNOWN"))==0,"item starter retains its own unknown-acquisition warning")
 end
 -- Empty alternative lists count as absent: same unknown-start card, no invented choices.
 for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","koKR","zhCN","zhTW","itIT"})do
  a.db.locale=locale
  local qUnknown=assert(a.quests[96987])
  assert(qUnknown.start==nil and qUnknown.startAlternatives==nil)
  qUnknown.startAlternatives={}
  render(96987)
  assert(fields(a.L("QUEST_START_UNKNOWN"))==1,"empty alternatives keep one unknown-start warning")
  assert(fields(a.L("GIVER_CHOICES_REQUIRED"))==0 and fields(a.L("GIVER_LOCATION_UNKNOWN"))==0 and fields(a.L("START_ITEM_LOCATION_UNKNOWN"))==0,"empty alternatives invent no giver choice or location warning")
  assert(fields(a.L("SOURCE_DETAILS"))==1,"empty alternatives keep neutral source heading")
  assert(ui.giverUnavailableKey=="QUEST_START_UNKNOWN" and not ui.giver.enabled and not ui:NavigationDestination(false),"empty alternatives dispatch no visit route")
  qUnknown.startAlternatives=nil
  local qItem=assert(a.quests[98423])
  assert(qItem.startAlternatives==nil)
  qItem.startAlternatives={}
  render(98423)
  assert(fields(a.L("START_ITEM_LOCATION_UNKNOWN"))==1,"empty alternatives keep item-starter unknown-acquisition warning")
  assert(fields(a.L("QUEST_START_UNKNOWN"))==0 and fields(a.L("GIVER_CHOICES_REQUIRED"))==0,"item starter with empty alternatives claims no unknown method or giver choice")
  assert(ui.giverUnavailableKey=="START_ITEM_LOCATION_UNKNOWN","item starter with empty alternatives keeps its own unavailable key")
  qItem.startAlternatives=nil
  qUnknown.startAlternatives={}
  render(96987)
  assert(ui:SetDetailTab("sources"))
  assert(fields(a.L("QUEST_START_UNKNOWN"))==1 and fields(a.L("START_ALTERNATIVES"))==0 and fields(a.L("GIVER_CHOICES_REQUIRED"))==0,"sources tab shows unknown start without an empty choice block")
  local buttonsShown=false
  for _,pool in ipairs({ui.giverButtons,ui.startButtons})do for _,button in ipairs(pool)do if button:IsShown()then buttonsShown=true end end end
  assert(not buttonsShown,"absent alternatives create no source buttons")
  assert(ui:SetDetailTab("quest"))
  qUnknown.startAlternatives=nil
 end
 -- Stale empty-alternative warning cannot overwrite a newer card.
 local qStale=assert(a.quests[96987])
 qStale.startAlternatives={}
 render(96987)
 local _,staleWarning=fields(a.L("QUEST_START_UNKNOWN"));local staleSetter=staleWarning.SetText
 local armedStale,firedStale=true,false
 staleWarning.SetText=function(self,text,...)
  if armedStale and text==a.L("QUEST_START_UNKNOWN")then armedStale,firedStale=false,true;render(98423)end
  return staleSetter(self,text,...)
 end
 ui.quest=96987;ui:Refresh();staleWarning.SetText=staleSetter
 qStale.startAlternatives=nil
 assert(firedStale and ui.quest==98423 and ui.renderedQuest==98423 and fields(a.L("QUEST_START_UNKNOWN"))==0,"retired empty-alternative warning cannot overwrite a newer card")
a.db.locale="enUS"
-- The native warning setter completes another card before the retired text write resumes.
render(96987)
local _,warning=fields(a.L("QUEST_START_UNKNOWN"));local setter=warning.SetText
local armed,fired=true,false
warning.SetText=function(self,text,...)
 if armed and text==a.L("QUEST_START_UNKNOWN")then armed,fired=false,true;render(98423)end
 return setter(self,text,...)
end
ui.quest=96987;ui:Refresh();warning.SetText=setter
assert(fired and ui.quest==98423 and ui.renderedQuest==98423 and fields(a.L("QUEST_START_UNKNOWN"))==0,"retired method warning cannot overwrite a newer item-source card")
local localize=a.L;armed,fired=true,false
local quest=a.quests[96987]
a.L=function(key,...)
 local text=localize(key,...)
 if armed and key=="QUEST_START_UNKNOWN"then
  armed,fired=false,true;quest.start={npcID=1480,name="Recorded NPC"}
 end
 return text
end
ui.dungeon,ui.quest=assert(owners[96987]),96987;ui:Refresh();a.L=localize
assert(fired and fields(a.L("QUEST_START_UNKNOWN"))==0,"newly supplied typed source expires an absent-source warning during localization")
quest.start=nil
assert(starts==0 and maps==0)
print("Unknown quest start method: PASS (actual TOC;10 locales, modeled UI only)")
