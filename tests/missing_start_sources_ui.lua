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
 -- DP-5 DETAIL-INVALID-ITEM: raw invalid/mixed item starter reads as unknown, never a giver visit.
 local qInvalid=assert(a.quests[98423])
 local savedInvalidStart=qInvalid.start
 for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","koKR","zhCN","zhTW","itIT"})do
  a.db.locale=locale
  assert(ui:SetDetailTab("quest"))
  qInvalid.start={itemID=0}
  render(98423)
  assert(fields(a.L("QUEST_START_UNKNOWN"))==1,"invalid item starter keeps one unknown-start warning")
  assert(fields(a.L("GIVER_LOCATION_UNKNOWN"))==0 and fields(a.L("GIVER_COORDINATES_UNKNOWN"))==0 and fields(a.L("SOURCE_POSITION_UNKNOWN"))==0 and fields(a.L("START_ITEM_LOCATION_UNKNOWN"))==0,"invalid item starter invents no giver or item-acquisition warning")
  assert(fields(a.L("SOURCE_DETAILS"))==1,"invalid item starter keeps neutral source heading")
  assert(ui.giverUnavailableKey=="QUEST_START_UNKNOWN" and not ui.giver.enabled and not ui:NavigationDestination(false),"invalid item starter dispatches no visit route")
  assert(ui:SetDetailTab("sources"))
  assert(fields(a.L("QUEST_START_UNKNOWN"))==1,"sources tab shows unknown start for invalid item starter")
  assert(fields(a.L("GIVER_LOCATION_UNKNOWN"))==0 and fields(a.L("START_ITEM_LOCATION_UNKNOWN"))==0,"sources tab invents no giver visit for invalid item starter")
  assert(not ui.giver.enabled and not ui:NavigationDestination(false),"sources tab dispatches no visit route for invalid item starter")
  assert(ui:SetDetailTab("quest"))
  qInvalid.start={itemID=801,npcID=5,name="Recorded NPC"}
  render(98423)
  assert(fields(a.L("QUEST_START_UNKNOWN"))==1,"mixed item starter keeps one unknown-start warning")
  assert(fields(a.L("GIVER_LOCATION_UNKNOWN"))==0 and fields(a.L("GIVER_COORDINATES_UNKNOWN"))==0 and fields(a.L("SOURCE_POSITION_UNKNOWN"))==0 and fields(a.L("START_ITEM_LOCATION_UNKNOWN"))==0,"mixed item starter invents no giver or item-acquisition warning")
  assert(fields(a.L("SOURCE_DETAILS"))==1,"mixed item starter keeps neutral source heading")
  assert(ui.giverUnavailableKey=="QUEST_START_UNKNOWN" and not ui.giver.enabled and not ui:NavigationDestination(false),"mixed item starter dispatches no visit route")
  assert(ui:SetDetailTab("sources"))
  assert(fields(a.L("QUEST_START_UNKNOWN"))==1,"sources tab shows unknown start for mixed item starter")
  assert(not ui.giver.enabled and not ui:NavigationDestination(false),"sources tab dispatches no visit route for mixed item starter")
  assert(ui:SetDetailTab("quest"))
 end
 qInvalid.start=savedInvalidStart
 render(98423)
 assert(fields(a.L("START_ITEM_LOCATION_UNKNOWN"))==1 and fields(a.L("QUEST_START_UNKNOWN"))==0,"valid item starter retains its own unknown-acquisition warning")
 assert(ui.giverUnavailableKey=="START_ITEM_LOCATION_UNKNOWN","valid item starter keeps its own unavailable key")
 render(1486)
 assert(fields(a.L("GIVER_LOCATION_UNKNOWN"))==1 and fields(a.L("QUEST_START_UNKNOWN"))==0,"mapless giver retains its precise existing warning")
 a.db.locale="enUS"
 assert(ui:SetDetailTab("quest"))
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
-- DP-5 DETAIL-GIVER-NAV-UNAVAILABLE: detail mirrors the row when the navigation method is absent.
a.db.locale="enUS"
assert(ui:SetDetailTab("quest"))
local savedNavigation=a.Navigation
local detailStarts,detailMaps=0,0
local function fullNavigation()
 return {Start=function(action) detailStarts=detailStarts+1; return true end, Map=function(point) detailMaps=detailMaps+1; return true end}
end
local function resetTip() tip.shown=false; tip.owner=nil; tip.title=nil; tip.body=nil end
-- (1) pure-visit without Navigation: row and detail disabled, no visit route.
a.Navigation=nil; ui.frame:Show()
render(166)
do
 local keptQuest=ui.quest
 assert(keptQuest==166,"pure visit keeps selection without navigation")
 local r=row(166); local control=assert(r.navigationControl)
 assert(control.enabled==false,"pure-visit row stays disabled without Navigation")
 assert(r.navigationBinding.reason=="NAVIGATION_UNAVAILABLE" and r.navigationBinding.action==nil,"pure-visit row keeps unavailable reason without route")
 resetTip(); control.scripts.OnEnter()
 assert(tip.shown and tip.owner==control and tip.body==a.L("NAVIGATION_UNAVAILABLE"),"pure-visit row hint names unavailable navigation")
 assert(tip.title==a.L("DETAIL_GIVER"),"pure-visit row hint keeps giver title without route")
 local routedBefore, mappedBefore=starts, maps
 control.scripts.OnClick()
 assert(starts==routedBefore and maps==mappedBefore and ui.quest==keptQuest,"disabled pure-visit row click dispatches no route")
 assert(ui.giverUnavailableKey=="NAVIGATION_UNAVAILABLE" and not ui.giver.enabled,"pure-visit detail stays disabled without Navigation")
 assert(ui.giver.footerLabelKey=="SOURCE_DETAILS","unavailable detail keeps neutral source title instead of a visit promise")
 assert(ui:NavigationDestination(false)==nil,"unavailable detail invents no visit destination")
 resetTip(); ui.giver.scripts.OnEnter()
 assert(tip.shown and tip.owner==ui.giver and tip.title==a.L("SOURCE_DETAILS") and tip.body==a.L("NAVIGATION_UNAVAILABLE"),"unavailable detail hint stays neutral without a visit promise")
 local detailBeforeStarts, detailBeforeMaps=detailStarts, detailMaps
 ui.giver.scripts.OnClick()
 assert(detailStarts==detailBeforeStarts and detailMaps==detailBeforeMaps and starts==routedBefore and maps==mappedBefore,"disabled pure-visit detail click is a no-op")
 assert(ui.quest==keptQuest,"disabled detail click keeps selection")
end
-- (2) map-only without x/y without Navigation.Map: same, GIVER_MAP never enables.
do
 local q=assert(a.quests[166]); local savedStart=q.start
 q.start={npcID=1234,name="Map-only giver",mapID=1436}
 a.Navigation={Start=function(action) detailStarts=detailStarts+1; return true end}
 ui.frame:Show(); render(166)
 local keptQuest=ui.quest
 local r=row(166); local control=assert(r.navigationControl)
 assert(control.enabled==false,"map-only row stays disabled without Navigation.Map")
 assert(r.navigationBinding.reason=="NAVIGATION_UNAVAILABLE" and r.navigationBinding.action==nil,"map-only row keeps unavailable reason without map route")
 assert(ui.giverUnavailableKey=="NAVIGATION_UNAVAILABLE" and not ui.giver.enabled,"map-only detail stays disabled without Navigation.Map")
 assert(ui.giver.footerLabelKey=="SOURCE_DETAILS" and ui.giver.footerLabelKey~="GIVER_MAP","map-only detail never enables GIVER_MAP without a map method")
 assert(ui:NavigationDestination(false)==nil,"map-only detail invents no destination without Navigation.Map")
 resetTip(); ui.giver.scripts.OnEnter()
 assert(tip.title==a.L("SOURCE_DETAILS") and tip.body==a.L("NAVIGATION_UNAVAILABLE"),"map-only detail hint stays neutral without a map promise")
 local beforeStarts, beforeMaps=detailStarts, detailMaps
 control.scripts.OnClick(); ui.giver.scripts.OnClick()
 assert(detailStarts==beforeStarts and detailMaps==beforeMaps and ui.quest==keptQuest,"map-only clicks dispatch no route and keep selection")
 q.start=savedStart
end
-- Inspect branch stays enabled without Navigation (quest_row_sources_ui.lua:65-68 protection).
do
 a.Navigation=nil
 ui.dungeon=assert(owners[6981]); ui.quest=1491; ui.includeUnavailable=true; ui.frame:Show(); ui:Refresh()
 local npc=row(6981); local control=assert(npc.navigationControl)
 assert(control.enabled,"source inspection does not require a navigation capability")
 local beforeStarts, beforeMaps=detailStarts, detailMaps
 control.scripts.OnClick()
 assert(ui.quest==6981 and ui.renderedQuest==6981,"source click still inspects its own quest without navigation")
 assert(detailStarts==beforeStarts and detailMaps==beforeMaps,"source inspection dispatches no navigation route")
end
-- (3) Navigation returns: fresh controls enable, stale DispatchDetail/hover rejected.
do
 a.Navigation=fullNavigation()
 ui.dungeon=assert(owners[166]); ui.quest=166; ui.frame:Show(); ui:Refresh()
 assert(ui.giver.enabled and ui.giver.footerLabelKey=="VISIT_GIVER","returned Navigation re-enables the pure-visit detail")
 assert(ui:NavigationDestination(false)~=nil,"returned Navigation restores the visit destination")
 local freshBinding=assert(ui.giverBinding); local freshAction=assert(ui.giverAction); local freshCoords=ui.giverHasCoordinates
 assert(freshBinding.current()==true,"fresh detail binding stays current")
 local staleAction, staleCurrent=freshAction, freshBinding.current
 local staleBinding=freshBinding
 a.Navigation=nil; ui:Refresh()
 assert(not ui.giver.enabled and ui.giverUnavailableKey=="NAVIGATION_UNAVAILABLE","removed Navigation disables the detail again")
 assert(staleCurrent()==false,"removed Navigation retires the previous detail binding")
 a.Navigation=fullNavigation(); ui:Refresh()
 assert(ui.giver.enabled and ui.giver.footerLabelKey=="VISIT_GIVER","second Navigation return re-enables the detail")
 local renewedBinding=assert(ui.giverBinding)
 assert(renewedBinding~=staleBinding and renewedBinding.current()==true,"fresh return owns a new current binding")
 assert(staleCurrent()==false,"old detail binding stays retired after the return")
 local beforeStarts, beforeMaps=detailStarts, detailMaps
 assert(ui:DispatchDetail(staleAction, not freshCoords, true, staleCurrent)==false,"stale DispatchDetail with a retired owner is rejected")
 assert(detailStarts==beforeStarts and detailMaps==beforeMaps,"stale detail dispatch routes nothing")
 resetTip(); ui.giver.scripts.OnEnter()
 assert(tip.shown and tip.title==a.L("VISIT_GIVER") and tip.body~=a.L("NAVIGATION_UNAVAILABLE"),"fresh hover shows the restored visit destination instead of the retired hint")
 ui.giver.scripts.OnClick()
 assert((detailStarts+detailMaps)==(beforeStarts+beforeMaps+1),"fresh detail click routes once through the returned method")
 assert(ui.quest==166,"fresh detail navigation keeps selection")
end
a.Navigation=savedNavigation
a.quests[166].start=a.quests[166].start
render(98423)
a.db.locale="enUS"
assert(ui:SetDetailTab("quest"))
assert(starts==0 and maps==0)
-- DP-5 DETAIL-GIVER-MAP-BOUND: non-integer/overflow mapID invents no visit; row and detail agree.
do
 local q=assert(a.quests[166]); local savedStart=q.start; local savedNav=a.Navigation
 local routed=0
 a.Navigation={Start=function() routed=routed+1; return true end, Map=function() routed=routed+1; return true end}
 ui.frame:Show()
 local function checkInvalid(label, start)
  q.start=start; routed=0; render(166)
  local keptQuest=ui.quest
  assert(keptQuest==166,label.." keeps selection on invalid map")
  local r=row(166); local control=assert(r.navigationControl)
  assert(control.enabled==false,label.." row stays disabled on invalid map")
  assert(r.navigationBinding.action==nil,label.." row invents no action on invalid map")
  assert(r.navigationBinding.reason=="GIVER_LOCATION_UNKNOWN" or r.navigationBinding.reason=="SOURCE_POSITION_UNKNOWN",label.." row keeps unknown-location reason on invalid map")
  assert(ui.giverUnavailableKey=="GIVER_LOCATION_UNKNOWN" or ui.giverUnavailableKey=="SOURCE_POSITION_UNKNOWN",label.." detail keeps unknown-location key on invalid map")
  assert(not ui.giver.enabled,label.." detail stays disabled on invalid map")
  assert(ui:NavigationDestination(false)==nil,label.." invalid map invents no visit destination")
  local before=routed
  control.scripts.OnClick(); ui.giver.scripts.OnClick()
  assert(routed==before,label.." invalid map clicks dispatch no route")
  assert(ui.quest==keptQuest,label.." invalid map clicks keep selection")
 end
 checkInvalid("overflow 2^53",{npcID=1,mapID=9007199254740992,x=10,y=20})
 checkInvalid("fractional 1436.5",{npcID=1,mapID=1436.5,x=10,y=20})
 -- Boundary 2^53-1 stays a valid visit: enabled, one Start, stale binding retires.
 q.start={npcID=1,mapID=9007199254740991,x=10,y=20}; routed=0; render(166)
 assert(ui.giver.enabled,"boundary map enables the detail")
 assert(ui.giver.footerLabelKey=="VISIT_GIVER","boundary map keeps visit title")
 assert(ui:NavigationDestination(false)~=nil,"boundary map restores the visit destination")
 local r=row(166); local control=assert(r.navigationControl)
 assert(control.enabled and r.navigationBinding.action~=nil,"boundary map enables the row with an action")
 local freshBinding=assert(ui.giverBinding); local freshCurrent=assert(freshBinding.current)
 assert(freshCurrent()==true,"boundary detail binding stays current")
 local before=routed
 ui.giver.scripts.OnClick()
 assert(routed==before+1,"boundary detail click routes once through Start")
 assert(ui.quest==166,"boundary detail navigation keeps selection")
 -- Stale boundary binding cannot dispatch after the map turns invalid.
 local staleAction, staleCurrent=freshBinding.action, freshBinding.current
 q.start={npcID=1,mapID=9007199254740992,x=10,y=20}; render(166)
 assert(not ui.giver.enabled,"overflow map disables the detail again")
 assert(ui:NavigationDestination(false)==nil,"overflow map retires the visit destination")
 assert(staleCurrent()==false,"overflow map retires the previous detail binding")
 local beforeStale=routed
 assert(ui:DispatchDetail(staleAction,false,true,staleCurrent)==false,"stale boundary dispatch with a retired owner is rejected")
 assert(routed==beforeStale,"stale boundary dispatch routes nothing")
 -- Valid maps still enable after the bound checks.
 q.start=savedStart; routed=0; render(166)
 assert(ui.giver.enabled and ui.giver.footerLabelKey=="VISIT_GIVER","restored 1436 re-enables the visit detail")
 q.start={npcID=1,mapID=1453,x=10,y=20}; render(166)
 assert(ui.giver.enabled and ui.giver.footerLabelKey=="VISIT_GIVER","valid 1453 stays enabled")
 q.start=savedStart; a.Navigation=savedNav; render(166)
end
-- DP-5 DETAIL-ALTERNATIVE-MAP-BOUND: overflow/fractional alternative invents no visit; boundary stays usable.
do
 local q=assert(a.quests[166]); local savedStart=q.start; local savedAlternatives=q.startAlternatives; local savedNav=a.Navigation
 local routed=0; local hugeMaps=0
 a.Navigation={Start=function() routed=routed+1; return true end, Map=function() routed=routed+1; return true end}
 local mapRoot=C_Map; local mapInfo=assert(mapRoot.GetMapInfo)
 C_Map.GetMapInfo=function(mapID, ...) if type(mapID)=="number" and mapID>9007199254740991 then hugeMaps=hugeMaps+1 end; return mapInfo(mapID, ...) end
 ui.frame:Show(); assert(ui:SetDetailTab("sources"))
 local function renderAlternatives(alts)
  q.start=nil; q.startAlternatives=alts; routed=0; hugeMaps=0; render(166)
  assert(ui.detailTab=="sources","alternative check stays on the sources tab")
  assert(ui.quest==166 and ui.renderedQuest==166,"alternative check keeps selection")
 end
 local function checkInvalidAlternative(label, mapID)
  renderAlternatives({{npcID=1, name="Alt source", zoneName="Westfall", mapID=mapID, x=10, y=20}})
  local keptQuest=ui.quest
  local btn=assert(ui.giverButtons[1],label.." alternative row exists")
  assert(btn:IsShown(),label.." alternative row is shown")
  assert(btn.enabled==false,label.." alternative row stays disabled on invalid map")
  assert(btn.scripts.OnClick==nil,label.." alternative row invents no click on invalid map")
  assert(btn.note.text:find(a.L("SOURCE_POSITION_UNKNOWN"),1,true)~=nil,label.." alternative row keeps unknown-position warning on invalid map")
  assert(hugeMaps==0,label.." invalid alternative map never queries native info")
  local before=routed
  if btn.scripts.OnClick then btn.scripts.OnClick() end
  assert(routed==before,label.." invalid alternative click dispatches no route")
  assert(ui.quest==keptQuest and ui.renderedQuest==keptQuest,label.." invalid alternative click keeps selection")
 end
 checkInvalidAlternative("overflow 2^53",9007199254740992)
 checkInvalidAlternative("fractional 1436.5",1436.5)
 -- Boundary 2^53-1 stays usable: enabled, one Start route, stale click retires.
 renderAlternatives({{npcID=1, name="Alt source", zoneName="Westfall", mapID=9007199254740991, x=10, y=20}})
 do
  local btn=assert(ui.giverButtons[1],"boundary alternative row exists")
  assert(btn:IsShown() and btn.enabled==true,"boundary alternative row stays enabled")
  assert(btn.scripts.OnClick~=nil,"boundary alternative row keeps its click")
  assert(btn.note.text:find("(10.0, 20.0)",1,true)~=nil and btn.note.text:find("|cffff594d",1,true)==nil,"boundary alternative row keeps ordinary coordinates without a warning")
  assert(hugeMaps==0,"boundary alternative needs no huge native query")
  local savedDispatch=ui.DispatchDetail
  local capAction, capMapOnly, capOwner=nil, nil, nil
  ui.DispatchDetail=function(self, action, mapOnly, giver, ownerCurrent)
   capAction, capMapOnly, capOwner=action, mapOnly, ownerCurrent
   return savedDispatch(self, action, mapOnly, giver, ownerCurrent)
  end
  local before=routed
  btn.scripts.OnClick()
  assert(routed==before+1,"boundary alternative click routes once through Start")
  assert(capMapOnly==false,"boundary alternative with coordinates routes through Start")
  assert(ui.quest==166 and ui.renderedQuest==166,"boundary alternative navigation keeps selection")
  assert(capAction~=nil and capOwner~=nil and capOwner()==true,"boundary alternative binding stays current")
  local staleAction, staleMapOnly, staleOwner, staleClick=capAction, capMapOnly, capOwner, btn.scripts.OnClick
  ui.DispatchDetail=savedDispatch
  renderAlternatives({{npcID=1, name="Alt source", zoneName="Westfall", mapID=9007199254740992, x=10, y=20}})
  local retired=assert(ui.giverButtons[1],"overflow alternative row exists after boundary")
  assert(retired.enabled==false and retired.scripts.OnClick==nil,"overflow alternative disables the row again")
  assert(staleOwner()==false,"overflow alternative retires the previous boundary binding")
  local beforeStale=routed
  staleClick()
  assert(routed==beforeStale,"stale boundary click routes nothing")
  assert(ui.quest==166 and ui.renderedQuest==166,"stale boundary click keeps selection")
  assert(ui:DispatchDetail(staleAction, staleMapOnly, nil, staleOwner)==false,"stale boundary dispatch with a retired owner is rejected")
  assert(routed==beforeStale,"stale boundary dispatch routes nothing")
 end
 C_Map.GetMapInfo=mapInfo
 q.start=savedStart; q.startAlternatives=savedAlternatives; a.Navigation=savedNav
 assert(ui:SetDetailTab("quest")); render(166)
end
print("Unknown quest start method: PASS (actual TOC;10 locales, modeled UI only)")
print("DP-5 DETAIL-GIVER-NAV-UNAVAILABLE: PASS (pure-visit, map-only, stale return; modeled UI only)")
print("DP-5 DETAIL-GIVER-MAP-BOUND: PASS (overflow, fractional, boundary; modeled UI only)")
print("DP-5 DETAIL-ALTERNATIVE-MAP-BOUND: PASS (overflow, fractional, boundary; modeled UI only)")
