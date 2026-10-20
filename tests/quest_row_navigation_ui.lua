-- Direct middle-list navigation preserves selected quest and hierarchy ownership.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui = fixture.addon, fixture.addon.UI
fixture.methods.SetMotionScriptsWhileDisabled = function(self, value) self.disabledMotion = value end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
ui:Toggle(); addon.db.locale = "enUS"
local context = { level=20, faction="Alliance", class="MAGE", completed=function()return false end, active=function()return false end }
addon.Context = function()return context end
local ids = {990101,990102,990103,990104,990105,990106}
for _, id in ipairs(ids)do addon.quests[id]={id=id,name="Own quest "..id,minLevel=1,requirementsKnown=true} end
addon.quests[990101].minLevel=80
addon.quests[990101].start={npcID=1,name="Own distant giver",mapID=1453,x=10,y=20}
addon.quests[990102].start={npcID=2,name="Own map giver",mapID=1455}
addon.quests[990103].start={npcID=3,name="Unknown giver"}
addon.quests[990104].start={itemID=801,name="Own starter"}
addon.quests[990105].startAlternatives={{npcID=5,name="Alternative giver",mapID=1453,x=40,y=50}}
addon.quests[990106].start={npcID=6,name="Root giver",mapID=1453,x=60,y=70}
addon.quests[990106].requires={{ids={990101}}}
local dungeon={key="direct-navigation",name="Own dungeon",minLevel=1,maxLevel=80,quests=ids}
addon.dungeons={dungeon}; ui.dungeon=dungeon;ui.quest=990104;ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.includeUnavailable=true
local routed,mapped,entrances,entranceReads={},{},0,0
addon.Navigation={Start=function(action)routed[#routed+1]=action;return true end,
    Map=function(point)mapped[#mapped+1]=point;return true,false end,
    StartEntrance=function(d,point)assert(d==dungeon and point.mapID==1453);entrances=entrances+1;return true end}
local entranceKnown=true
addon.Entrances={Get=function(d)
    entranceReads=entranceReads+1
    if not entranceKnown then return nil end
    return {mapID=1453,x=30,y=40,name="Entrance"},function()return entranceKnown end
end}
addon.CachedQuestRewards=function()return{source="cache",items={{id=801,name="Reward",count=1,texture=134400}},choices={}}end
ui.search="";ui.range=false;ui:Refresh()
local function row(id)
    for _,r in ipairs(ui.rows)do if r:IsShown()and r.questID==id then return r end end
    error("missing quest row "..id)
end
local selected,tree,history=ui.quest,ui.questTreeRoot,ui.detailHistory
local first=row(990101)
assert(first.navigationControl and first.navigationControl:IsShown(),"middle quest has a direct giver control")
assert(first.navigationControl.width==24 and first.navigationControl.height==24 and first.navigationReserve==32)
assert(first.navigationControl.point[4]==-4 and first.navigationControl.disabledMotion)
assert(first.navigationControl.enabled,"level-gated quests can visit their recorded giver")
first.navigationControl.scripts.OnClick()
assert(#routed==1 and routed[1].id==990101 and routed[1].kind=="visit" and routed[1].place==addon.quests[990101].start)
assert(ui.quest==selected and ui.questTreeRoot==tree and ui.detailHistory==history,"navigation never selects or expands a row")
row(990102).navigationControl.scripts.OnClick()
assert(#mapped==1 and mapped[1]==addon.quests[990102].start,"map-only giver uses its own known area")
local tip={}
function tip:SetOwner(owner)self.owner=owner end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetText(text)self.title=text end
function tip:AddLine(text)self.body=text end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip
for _,case in ipairs({{990103,"GIVER_LOCATION_UNKNOWN"},{990104,"START_ITEM_NAVIGATION"},{990105,"SOURCE_DETAILS_HINT"}})do
    local button=row(case[1]).navigationControl
    assert(button:IsShown()and button.enabled==(case[1]~=990103))
    button.scripts.OnEnter();assert(tip.shown and tip.owner==button and tip.body==addon.L(case[2]))
    assert(tip.title==addon.L(case[1]==990103 and "DETAIL_GIVER"or"SOURCE_DETAILS"),"source inspection is not labelled as map navigation")
    button.scripts.OnClick();assert(#routed==1 and #mapped==1)
    if case[1]~=990103 then assert(ui.quest==case[1]and ui.renderedQuest==case[1],"manual sources open their own details")end
end
assert(ui:InspectQuest(selected,true));first=row(990101)
local mapReads=0
C_Map={GetMapInfo=function(id)mapReads=mapReads+1;assert(id==1453);return{name="Stormwind City"}end}
first.navigationControl.scripts.OnEnter()
assert(mapReads==1 and tip.body:find("Stormwind City",1,true) and tip.body:find("10.0, 20.0",1,true),"hover hydrates the native destination area")
local oldLeave=first.navigationControl.scripts.OnLeave
row(990103).navigationControl.scripts.OnEnter();oldLeave()
assert(tip.owner==row(990103).navigationControl and tip.shown,"old row leave preserves another navigation hint")
tip.owner={};row(990103).navigationControl.scripts.OnLeave();assert(tip.shown,"borrowed tooltip remains untouched")
local created=fixture.objects
local reward
for _,object in ipairs(created)do if object.parent==first and object.icon and object.icon.texture==134400 then reward=object end end
-- The fixture does not expose native parents, so also use the visible reward's anchored row.
if not reward then for _,object in ipairs(created)do if object.icon and object.icon.texture==134400 and object.point and object.point[2]==first then reward=object end end end
assert(reward and reward.point[4]==-38,"reward preview shifts left of the direct navigation slot")
assert(first.title.point[2]+first.title.width+(first.factionReserve or 0)<=first:GetWidth()-32-26,
    "title and audience reserve both navigation and cached reward slots before wrapping")
assert(ui.questEntrance:IsShown()and ui.questEntrance.enabled and entranceReads==1,"heading reuses selected card entrance evidence")
assert(ui.heading.point[2]+ui.heading.width<ui.questEntrance.point[2]and ui.questEntrance.point[2]+ui.questEntrance.width<ui.characterButton.point[2])
ui.questEntrance.scripts.OnClick();assert(entrances==1 and ui.quest==selected)
local reads=entranceReads
assert(addon.Language:Open(ui));local session=addon.Language.session
for _,locale in ipairs({"ruRU","koKR","enUS"})do addon.Language:Preview(session,locale);assert(entranceReads==reads)end
addon.Language:Cancel(ui);assert(entranceReads==reads,"language refresh does not request entrance data again")
ui.search="no dungeon matches this";ui:Refresh()
assert(ui.questEntrance.enabled,"filtered-out selected dungeon retains its independently owned entrance")
local fallbackReads=entranceReads;ui:RefreshQuests();assert(entranceReads==fallbackReads)
ui.questEntrance.scripts.OnClick();assert(entrances==2)
entranceKnown=false;ui:RefreshQuests();assert(not ui.questEntrance.enabled)
local negativeReads=entranceReads;ui:RefreshQuests();assert(entranceReads==negativeReads,"warm missing entrance cache stays bounded")
entranceKnown=true;ui:RefreshDungeons();ui:RefreshQuests()
assert(ui.questEntrance.enabled and entranceReads==negativeReads+1,"new catalogue evidence refreshes an unavailable entrance")
local staleEntrance=ui.questEntrance.scripts.OnClick
local getEntrance=addon.Entrances.Get
addon.Entrances.Get=function(...)return getEntrance(...)end
staleEntrance();assert(entrances==2,"provider replacement expires old heading input")
ui:RefreshQuests();assert(ui.questEntrance.enabled)
local stale=row(990101).navigationControl.scripts.OnClick
addon.quests[990101].start.x=11;stale();assert(#routed==1,"changed source rejects an old route before redraw")
ui.search="";ui:Refresh();stale=row(990101).navigationControl.scripts.OnClick
local nav=addon.Navigation;addon.Navigation={Start=nav.Start,Map=nav.Map,StartEntrance=nav.StartEntrance};stale();assert(#routed==1)
ui:Refresh();stale=row(990101).navigationControl.scripts.OnClick
local char=addon.char;addon.char={};stale();assert(#routed==1);addon.char=char
ui:Refresh();stale=row(990101).navigationControl.scripts.OnClick
ui.questTreeRoot=990106;ui.questTreeDungeon=dungeon;ui:RefreshQuests();stale();assert(#routed==1,"recycled list rejects its previous callback")
local step=row(990101);step.navigationControl.scripts.OnClick()
assert(#routed==2 and routed[2].id==990101 and ui.quest==selected and ui.questTreeRoot==990106,"chain step visits its own giver without selecting it")
ui.frame:Hide();step.navigationControl.scripts.OnClick();assert(#routed==2)
-- DP-5 ROW-STARTER-REASON: invalid or mixed item starter stays unknown, never invents a giver.
ui.frame:Show();ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.search="";ui.quest=990104;ui:Refresh()
local validStarter={itemID=801,name="Own starter"}
local function checkUnknownStarter(label,start)
 addon.quests[990104].start=start;ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
 local target=row(990104);local button=target.navigationControl;local binding=target.navigationBinding
 assert(binding.reason=="QUEST_START_UNKNOWN",label.." keeps unknown start reason")
 assert(binding.inspect==nil and binding.action==nil,label.." has no inspection or route")
 assert(button:IsShown() and not button.enabled,label.." stays disabled")
 button.scripts.OnEnter()
 assert(tip.shown and tip.owner==button and tip.title==addon.L("SOURCE_DETAILS") and tip.body==addon.L("QUEST_START_UNKNOWN"),label.." explains unknown start under neutral source title")
 local routedBefore,mappedBefore,keptQuest=#routed,#mapped,ui.quest
 button.scripts.OnClick()
 assert(#routed==routedBefore and #mapped==mappedBefore and ui.quest==keptQuest,label.." click dispatches no route and keeps selection")
end
checkUnknownStarter("zero itemID",{itemID=0,name="Own starter"})
checkUnknownStarter("overflow itemID",{itemID=4294967296,name="Own starter"})
checkUnknownStarter("fractional itemID",{itemID=1.5,name="Own starter"})
checkUnknownStarter("non-numeric itemID",{itemID="801",name="Own starter"})
addon.quests[990104].start=validStarter;ui:Refresh()
local restored=row(990104);local restoredButton=restored.navigationControl
assert(restored.navigationBinding.reason=="START_ITEM_NAVIGATION" and restored.navigationBinding.inspect==true,"valid starter restores item navigation")
assert(restoredButton.enabled,"valid starter restores enabled control")
restoredButton.scripts.OnEnter();assert(tip.title==addon.L("SOURCE_DETAILS") and tip.body==addon.L("START_ITEM_NAVIGATION"),"valid starter hint returns")
checkUnknownStarter("mixed item+npc",{itemID=801,npcID=5,name="Mixed starter"})
checkUnknownStarter("mixed item+object",{itemID=801,objectID=7,name="Mixed starter"})
addon.quests[990104].start={itemID=801,npcID=5,name="Mixed starter"};ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
row(990104).navigationControl.scripts.OnEnter()
assert(tip.body==addon.L("QUEST_START_UNKNOWN"),"mixed starter hint starts unknown")
assert(ui:InspectQuest(990101,true),"card change keeps ownership")
ui:Refresh();row(990104).navigationControl.scripts.OnEnter()
assert(tip.body==addon.L("QUEST_START_UNKNOWN"),"card change does not restore old item hint")
if type(ui.SetDetailTab)=="function" then ui:SetDetailTab("sources");ui:SetDetailTab("quest") end
row(990104).navigationControl.scripts.OnEnter()
assert(tip.body==addon.L("QUEST_START_UNKNOWN"),"tab change does not restore old item hint")
assert(addon.Language:Open(ui));local starterSession=addon.Language.session
for _,locale in ipairs({"ruRU","enUS"})do addon.Language:Preview(starterSession,locale);row(990104).navigationControl.scripts.OnEnter();assert(tip.body==addon.L("QUEST_START_UNKNOWN"),"language change does not restore old item hint")end
addon.Language:Cancel(ui)
addon.quests[990104].start=validStarter;ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
-- DP-5 ROW-EMPTY-ALTERNATIVES: nil start + empty alternatives stays unknown, never invents a giver.
addon.quests[990104].start=nil;addon.quests[990104].startAlternatives={}
ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
do
 local target=row(990104);local button=target.navigationControl;local binding=target.navigationBinding
 assert(binding.reason=="QUEST_START_UNKNOWN","empty alternatives keeps unknown start reason")
 assert(binding.inspect==nil and binding.action==nil,"empty alternatives has no inspection or route")
 assert(button:IsShown() and not button.enabled,"empty alternatives stays disabled")
 button.scripts.OnEnter()
 assert(tip.shown and tip.owner==button and tip.title==addon.L("SOURCE_DETAILS") and tip.body==addon.L("QUEST_START_UNKNOWN"),"empty alternatives explains unknown start under neutral source title")
 local routedBefore,mappedBefore,keptQuest=#routed,#mapped,ui.quest
 button.scripts.OnClick()
 assert(#routed==routedBefore and #mapped==mappedBefore and ui.quest==keptQuest,"empty alternatives click dispatches no route and keeps selection")
end
addon.quests[990104].start=validStarter;addon.quests[990104].startAlternatives=nil
ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
for _,case in ipairs({{990103,"GIVER_LOCATION_UNKNOWN","DETAIL_GIVER",false},{990104,"START_ITEM_NAVIGATION","SOURCE_DETAILS",true},{990105,"SOURCE_DETAILS_HINT","SOURCE_DETAILS",true}})do
 local button=row(case[1]).navigationControl
 assert(button:IsShown() and button.enabled==case[4],"existing case "..case[1].." keeps enabled state")
 button.scripts.OnEnter()
 assert(tip.title==addon.L(case[3]) and tip.body==addon.L(case[2]),"existing case "..case[1].." keeps hint")
end
assert(row(990101).navigationControl.enabled and row(990102).navigationControl.enabled,"existing visit and map-only rows stay enabled")
-- DP-5 ROW-LARGE-ALTERNATIVES: nil start + 101 alternatives stays inspect, never invents a giver.
addon.quests[990105].start=nil
local large101={}
for i=1,101 do large101[i]={npcID=2000+i,name="Large giver "..i,mapID=1453,x=40,y=50} end
addon.quests[990105].startAlternatives=large101
ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
do
 local target=row(990105);local button=target.navigationControl;local binding=target.navigationBinding
 assert(binding.reason=="SOURCE_DETAILS_HINT","101 alternatives keeps details hint reason")
 assert(binding.inspect==true and binding.action==nil,"101 alternatives has inspection without route")
 assert(button:IsShown() and button.enabled,"101 alternatives stays enabled")
 button.scripts.OnEnter()
 assert(tip.shown and tip.owner==button and tip.title==addon.L("SOURCE_DETAILS") and tip.body==addon.L("SOURCE_DETAILS_HINT"),"101 alternatives explains choices under source title")
 local routedBefore,mappedBefore=#routed,#mapped
 button.scripts.OnClick()
 assert(#routed==routedBefore and #mapped==mappedBefore,"101 alternatives click dispatches no route and no map")
 assert(ui.quest==990105 and ui.renderedQuest==990105,"101 alternatives click inspects its own details")
end
-- Boundary 100 stays inspect (regression guard).
local large100={}
for i=1,100 do large100[i]={npcID=2000+i,name="Large giver "..i,mapID=1453,x=40,y=50} end
addon.quests[990105].start=nil;addon.quests[990105].startAlternatives=large100
ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
do
 local target=row(990105);local button=target.navigationControl;local binding=target.navigationBinding
 assert(binding.reason=="SOURCE_DETAILS_HINT","100 alternatives keeps details hint reason")
 assert(binding.inspect==true and binding.action==nil,"100 alternatives has inspection without route")
 assert(button:IsShown() and button.enabled,"100 alternatives stays enabled")
 button.scripts.OnEnter()
 assert(tip.shown and tip.owner==button and tip.title==addon.L("SOURCE_DETAILS") and tip.body==addon.L("SOURCE_DETAILS_HINT"),"100 alternatives explains choices under source title")
 local routedBefore,mappedBefore=#routed,#mapped
 button.scripts.OnClick()
 assert(#routed==routedBefore and #mapped==mappedBefore,"100 alternatives click dispatches no route and no map")
 assert(ui.quest==990105 and ui.renderedQuest==990105,"100 alternatives click inspects its own details")
end
-- Mutation 101->2 + locale change expires the old click/hint.
addon.quests[990105].start=nil;addon.quests[990105].startAlternatives=large101
ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
local staleTarget=row(990105);staleTarget.navigationControl.scripts.OnEnter()
assert(tip.body==addon.L("SOURCE_DETAILS_HINT"),"large hint starts inspect")
local staleClick=staleTarget.navigationControl.scripts.OnClick
local staleEnter=staleTarget.navigationControl.scripts.OnEnter
local staleBinding=staleTarget.navigationBinding
assert(staleBinding.inspect==true and staleBinding.reason=="SOURCE_DETAILS_HINT","stale large binding starts inspect")
addon.quests[990105].startAlternatives={{npcID=5,name="Alternative giver",mapID=1453,x=40,y=50},{npcID=6,name="Second giver",mapID=1453,x=41,y=51}}
assert(addon.Language:Open(ui));local largeSession=addon.Language.session
addon.Language:Preview(largeSession,"ruRU")
ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
addon.Language:Cancel(ui)
ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
do
 local routedBefore,mappedBefore=#routed,#mapped
 staleClick()
 assert(#routed==routedBefore and #mapped==mappedBefore,"truncated alternatives reject the old large click")
 assert(ui.quest==990104,"truncated alternatives keep selection after stale click")
 tip.shown=false;tip.owner=nil;tip.title=nil;tip.body=nil
 staleEnter()
 assert(tip.shown~=true and tip.owner==nil,"truncated alternatives reject the old large hint")
 local fresh=row(990105);local button=fresh.navigationControl;local binding=fresh.navigationBinding
 assert(binding.inspect==true and binding.reason=="SOURCE_DETAILS_HINT","truncated alternatives keep inspect")
 assert(button.enabled,"truncated alternatives stay enabled")
 button.scripts.OnEnter()
 assert(tip.shown and tip.owner==button and tip.body==addon.L("SOURCE_DETAILS_HINT"),"truncated alternatives refresh the hint")
end
-- DP-5 NAV-DESTINATION-METHOD-GUARD: destination mirrors the row method guard, no new keys.
do
 local savedNavigation=addon.Navigation
 local function refreshDetail(id)
  ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.dungeon=dungeon;ui.quest=id;ui.frame:Show();ui:Refresh()
 end
 local function refreshRows()
  ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.dungeon=dungeon;ui.quest=990104;ui.frame:Show();ui:Refresh()
 end
 -- (1) positive: full Navigation + valid giver answers both requests and dispatches.
 addon.Navigation={Start=function(action)routed[#routed+1]=action;return true end,Map=function(point)mapped[#mapped+1]=point;return true end,StartEntrance=savedNavigation.StartEntrance}
 refreshDetail(990101)
 local coordAction=assert(ui.giverAction,"positive coordinate giver owns an action")
 local destTrue,giverTrue=ui:NavigationDestination(true)
 assert(destTrue==coordAction and giverTrue==true,"positive coordinate destination needs Start")
 local destFalse,giverFalse=ui:NavigationDestination(false)
 assert(destFalse==coordAction and giverFalse==true,"positive coordinate destination answers map request through Start")
 local routedBefore=#routed
 assert(ui:DispatchDetail(coordAction,false,true)~=false,"positive coordinate dispatch succeeds")
 assert(#routed==routedBefore+1,"positive coordinate dispatch routes once")
 refreshDetail(990102)
 local mapAction=assert(ui.giverAction,"positive map-only giver owns an action")
 local mapDest,mapGiver=ui:NavigationDestination(false)
 assert(mapDest==mapAction and mapGiver==true,"positive map-only destination needs Map")
 assert(ui:NavigationDestination(true)==nil,"positive map-only has no coordinate destination")
 local mappedBefore=#mapped
 assert(ui:DispatchDetail(mapAction,true,true)~=false,"positive map-only dispatch succeeds")
 assert(#mapped==mappedBefore+1,"positive map-only dispatch routes once")
 -- (2) Navigation=nil/{} keeps the stale coordinate destination empty and dispatches nothing.
 refreshDetail(990101)
 local staleAction=assert(ui.giverAction,"stale coordinate giver owns an action before Navigation loss")
 for _,nav in ipairs({nil,{}})do
  addon.Navigation=nav
  assert(ui:NavigationDestination(true)==nil,"missing Navigation invents no stale coordinate destination")
  assert(ui:NavigationDestination(false)==nil,"missing Navigation invents no stale map destination for a coordinate giver")
  assert(ui:DispatchDetail(staleAction,false,true)==false,"missing Navigation dispatches no stale coordinate route")
  refreshRows()
  local staleRow=row(990101)
  assert(staleRow.navigationBinding.reason=="NAVIGATION_UNAVAILABLE" and staleRow.navigationBinding.action==nil,"missing Navigation keeps row unavailable without route")
  assert(not staleRow.navigationControl.enabled,"missing Navigation disables coordinate row")
  -- Re-arm the same stale detail for the next Navigation shape without a refresh.
  addon.Navigation={Start=function(action)routed[#routed+1]=action;return true end,Map=function(point)mapped[#mapped+1]=point;return true end,StartEntrance=savedNavigation.StartEntrance}
  refreshDetail(990101)
  staleAction=assert(ui.giverAction,"stale coordinate giver re-armed before next Navigation shape")
 end
 -- (3) split providers: coordinate needs Start, map-only needs Map.
 refreshDetail(990101)
 staleAction=assert(ui.giverAction,"split coordinate giver owns an action before Map-only provider")
 addon.Navigation={Map=function(point)mapped[#mapped+1]=point;return true end}
 assert(ui:NavigationDestination(true)==nil,"Map-only provider cannot serve a coordinate destination")
 assert(ui:DispatchDetail(staleAction,false,true)==false,"Map-only provider dispatches no coordinate route")
 refreshDetail(990102)
 local staleMap=assert(ui.giverAction,"split map-only giver owns an action before Start-only provider")
 addon.Navigation={Start=function(action)routed[#routed+1]=action;return true end}
 assert(ui:NavigationDestination(false)==nil,"Start-only provider cannot serve a map-only destination")
 assert(ui:NavigationDestination(true)==nil,"Start-only provider has no coordinate destination for a map-only giver")
 assert(ui:DispatchDetail(staleMap,true,true)==false,"Start-only provider dispatches no map-only route")
 addon.Navigation=savedNavigation
 refreshRows()
 assert(row(990101).navigationControl.enabled and row(990102).navigationControl.enabled,"restored Navigation re-enables visit rows")
end
-- DP-5 ENTRANCE-MAP-BOUND: GetEntranceBinding rejects mapID > 2^53-1 like row/detail/provider.
do
 local savedGet=addon.Entrances.Get
 local savedStart=addon.Navigation.StartEntrance
 local hugeCalls=0
 addon.Navigation.StartEntrance=function(d,point)hugeCalls=hugeCalls+1;return true end
 local function alwaysTrue()return true end
 local HUGE=9007199254740992
 local MAXSAFE=9007199254740991
 local function serve(mapID)
  addon.Entrances.Get=function(d)
   assert(d==dungeon)
   return {mapID=mapID,x=27.5,y=48},function()return true end
  end
 end
 -- (1) huge-ID provider point stays unbound, disabled, and never navigates.
 serve(HUGE)
 assert(ui:GetEntranceBinding(dungeon,alwaysTrue)==nil,"huge mapID must not bind")
 ui:RefreshQuests()
 assert(not ui.questEntrance.enabled,"huge mapID disables the entrance")
 assert(addon.L("DUNGEON_ENTRANCE_UNKNOWN")~=nil,"unknown entrance label stays available")
 local beforeHuge=hugeCalls
 ui.questEntrance.scripts.OnClick()
 assert(hugeCalls==beforeHuge,"huge mapID never reaches native navigation")
 -- (2) boundary: 2^53-1 valid, 2^53/0/-1/fractional invalid.
 for _,bad in ipairs({HUGE,0,-1,1453.5})do
  serve(bad)
  assert(ui:GetEntranceBinding(dungeon,alwaysTrue)==nil,"bad mapID "..tostring(bad).." must not bind")
 end
 serve(MAXSAFE)
 local edge=assert(ui:GetEntranceBinding(dungeon,alwaysTrue),"2^53-1 stays valid when provided")
 assert(edge.point.mapID==MAXSAFE and edge.current()==true,"2^53-1 keeps a live predicate")
 -- (3) ordinary 1453 path intact: live binding, enabled control, native dispatch once.
 addon.Navigation.StartEntrance=savedStart
 addon.Entrances.Get=savedGet
 ui:RefreshQuests()
 local live=assert(ui:GetEntranceBinding(dungeon,alwaysTrue),"ordinary 1453 stays bound")
 assert(live.point.mapID==1453 and live.current()==true,"ordinary 1453 keeps a live predicate")
 assert(ui.questEntrance.enabled,"ordinary 1453 stays enabled")
 local before=entrances
 ui.questEntrance.scripts.OnClick()
 assert(entrances==before+1,"ordinary 1453 still dispatches once")
end
-- DP-5 ROW-SUMMON-OBJECT-BOUND: HasSummonSource rejects objectID > 2^32-1 like SummonSource.
do
 local HUGE=4294967296
 local MAXU32=4294967295
 local savedStart=addon.quests[990101].start
 local function summonEndpoint(objectID)
  return {objectID=objectID,name="Scrying Bowl",summonItem={itemID=7667,name="Summon tool"}}
 end
 -- (1) huge objectID + valid mapped start must not suppress the route as an unknown summon.
 addon.quests[990101].start={objectID=HUGE,name="Huge object",mapID=1453,x=10,y=20,summonItem={itemID=7667,name="Summon tool"}}
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
 do
  local target=row(990101);local button=target.navigationControl;local binding=target.navigationBinding
  assert(binding.reason~="GIVER_LOCATION_UNKNOWN","huge objectID must not suppress a mapped start as unknown summon")
  assert(binding.action~=nil and binding.action.kind=="visit" and binding.inspect==nil,"huge objectID keeps the mapped visit action without inspection")
  assert(button:IsShown() and button.enabled,"huge objectID keeps the mapped row enabled")
  local routedBefore=#routed
  button.scripts.OnClick()
  assert(#routed==routedBefore+1 and routed[#routed].id==990101,"huge objectID routes Start once")
 end
 -- (2) boundary: 2^32-1 stays a summon like 112877; huge/0/-1/fractional are not summons.
 assert(ui:HasSummonSource(summonEndpoint(MAXU32))==true,"2^32-1 stays a declared summon")
 assert(ui:SummonSource(summonEndpoint(MAXU32))~=nil,"2^32-1 keeps the informational summon relation")
 assert(ui:HasSummonSource(summonEndpoint(112877))==true,"ordinary 112877 stays a declared summon")
 assert(ui:SummonSource(summonEndpoint(112877))~=nil,"ordinary 112877 keeps the informational summon relation")
 for _,bad in ipairs({HUGE,0,-1,1.5})do
  assert(ui:HasSummonSource(summonEndpoint(bad))==false,"bad objectID "..tostring(bad).." is not a declared summon")
  assert(ui:SummonSource(summonEndpoint(bad))==nil,"bad objectID "..tostring(bad).." keeps no summon relation")
 end
 -- (3) ordinary mapless 112877 summon stays inspect-only without Start/Map.
 addon.quests[990101].start={objectID=112877,name="Scrying Bowl",summonItem={itemID=7667,name="Summon tool"}}
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
 do
  local target=row(990101);local button=target.navigationControl;local binding=target.navigationBinding
  assert(binding.reason=="SOURCE_DETAILS_HINT","ordinary summon keeps details hint reason")
  assert(binding.inspect==true and binding.action==nil,"ordinary summon has inspection without route")
  assert(button:IsShown() and button.enabled,"ordinary summon stays enabled")
  button.scripts.OnEnter()
  assert(tip.shown and tip.owner==button and tip.title==addon.L("SOURCE_DETAILS") and tip.body==addon.L("SOURCE_DETAILS_HINT"),"ordinary summon explains inspection without navigation")
  local routedBefore,mappedBefore=#routed,#mapped
  button.scripts.OnClick()
  assert(#routed==routedBefore and #mapped==mappedBefore,"ordinary summon click dispatches no Start or Map")
  assert(ui.quest==990101 and ui.renderedQuest==990101,"ordinary summon click inspects its own details")
 end
 addon.quests[990101].start=savedStart
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
end
print("Middle quest navigation checks passed (modeled, no native input or layout proof)")
