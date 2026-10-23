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
  -- (1) huge objectID + valid mapped start stays an honest unknown summon without a guessed route.
  addon.quests[990101].start={objectID=HUGE,name="Huge object",mapID=1453,x=10,y=20,summonItem={itemID=7667,name="Summon tool"}}
  ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
  do
   local target=row(990101);local button=target.navigationControl;local binding=target.navigationBinding
   assert(binding.reason=="QUEST_START_UNKNOWN","huge objectID keeps an honest unknown start instead of an invented giver")
   assert(binding.action==nil and binding.inspect==nil,"huge objectID offers no summon inspection and no guessed route")
   assert(button:IsShown() and not button.enabled,"huge objectID keeps the mapped row disabled")
   local routedBefore=#routed
   button.scripts.OnClick()
   assert(#routed==routedBefore and ui.quest==990104,"huge objectID dispatches no guessed fixed point")
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
-- DP-5 ROW-SUMMON-DECLARATION-EXCLUSIVITY: mixed endpoints declare no summon and keep the honest branch.
do
 local savedStart=addon.quests[990101].start
 local function refreshRows()
  ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
 end
 -- (1) objectID+npcID+summonItem declares no summon.
 local defectEp={objectID=1,npcID=2,name="Mixed object",summonItem={itemID=3,name="Summon tool"}}
 assert(ui:HasSummonSource(defectEp)==false,"mixed object+npc declares no summon")
 assert(ui:SummonSource(defectEp)==nil,"mixed object+npc keeps no summon relation")
 local mappedMixed={objectID=1,npcID=2,name="Mixed object giver",mapID=1453,x=10,y=20,summonItem={itemID=3,name="Summon tool"}}
 assert(ui:HasSummonSource(mappedMixed)==false,"mapped mixed object+npc declares no summon")
 assert(ui:SummonSource(mappedMixed)==nil,"mapped mixed object+npc keeps no summon relation")
 addon.quests[990101].start=mappedMixed;refreshRows()
 do
  local target=row(990101);local button=target.navigationControl;local binding=target.navigationBinding
  assert(binding.inspect==nil,"mapped mixed object+npc claims no summon inspection")
  assert(binding.action==nil and binding.reason=="QUEST_START_UNKNOWN","mapped mixed object+npc stays an honest unknown start without a guessed route")
  assert(button:IsShown() and not button.enabled,"mapped mixed object+npc keeps the mapped row disabled")
  local routedBefore=#routed
  button.scripts.OnClick()
  assert(#routed==routedBefore and ui.quest==990104,"mapped mixed object+npc dispatches no guessed fixed point")
 end
 -- (2) objectID+mapID+summonItem (and reportedLocations) declare no summon.
 local mixedMap={objectID=1,name="Mixed map object",mapID=1453,summonItem={itemID=3,name="Summon tool"}}
 assert(ui:HasSummonSource(mixedMap)==false,"mixed object+map declares no summon")
 assert(ui:SummonSource(mixedMap)==nil,"mixed object+map keeps no summon relation")
 local mixedReported={objectID=1,name="Mixed reported object",summonItem={itemID=3,name="Summon tool"},reportedLocations={{mapID=1453,x=10,y=20}}}
 assert(ui:HasSummonSource(mixedReported)==false,"mixed object+reportedLocations declares no summon")
 assert(ui:SummonSource(mixedReported)==nil,"mixed object+reportedLocations keeps no summon relation")
 addon.quests[990101].start=mixedMap;refreshRows()
 do
  local target=row(990101);local button=target.navigationControl;local binding=target.navigationBinding
  assert(binding.inspect==nil,"mixed object+map claims no summon inspection")
  assert(binding.action==nil and binding.reason=="QUEST_START_UNKNOWN","mixed object+map stays an honest unknown start without a guessed route")
  assert(button:IsShown() and not button.enabled,"mixed object+map keeps the mapped row disabled")
 end
 -- (3) valid objectID-only + summonItem behavior unchanged.
 local validSummon={objectID=112877,name="Scrying Bowl",summonItem={itemID=7667,name="Summon tool"}}
 assert(ui:HasSummonSource(validSummon)==true,"valid object-only stays a declared summon")
 assert(ui:SummonSource(validSummon)~=nil,"valid object-only keeps the informational summon relation")
 addon.quests[990101].start=validSummon;refreshRows()
 do
  local target=row(990101);local button=target.navigationControl;local binding=target.navigationBinding
  assert(binding.reason=="SOURCE_DETAILS_HINT","valid summon keeps details hint reason")
  assert(binding.inspect==true and binding.action==nil,"valid summon has inspection without route")
  assert(button:IsShown() and button.enabled,"valid summon stays enabled")
 end
 addon.quests[990101].start=savedStart;refreshRows()
end
-- U5/U6 SHARED-EMPTINESS: one helper answers nil/empty/malformed inputs directly.
do
 assert(ui:IsEmptyAlternatives(nil)==true,"nil alternatives count as absent")
 assert(ui:IsEmptyAlternatives({})==true,"empty alternatives count as absent")
 assert(ui:IsEmptyAlternatives({{npcID=5}})==false,"non-empty alternatives stay present")
 assert(ui:IsEmptyAlternatives(5)==true,"non-table alternatives count as absent without a crash")
 assert(ui:IsEmptyAlternatives("cord")==true,"string alternatives count as absent without a crash")
 assert(ui:PickupStartKind(nil,nil)==nil,"missing start classifies as ordinary")
 assert(ui:PickupStartKind({itemID=801},5)==nil,"malformed alternatives keep item starters unshaped")
 assert(ui:PickupStartKind({itemID=801,name="Own starter"})=="item","item-only starter classifies once")
 assert(ui:PickupStartKind({objectID=112877,name="Scrying Bowl",summonItem={itemID=7667,name="Summon tool"}})=="uncertain","summon pickup classifies once")
end
-- F-C NAMELESS-SUMMON-TOOL: a summon tool without a nonblank, length-bounded
-- name never classifies as uncertain, matching SummonSource strictness.
do
 assert(ui:PickupStartKind({objectID=112877,summonItem={itemID=7667}})==nil,"nameless summon tool classifies as ordinary, never uncertain")
 assert(ui:PickupStartKind({objectID=112877,summonItem={itemID=7667,name=""}})==nil,"blank summon tool name classifies as ordinary")
 assert(ui:PickupStartKind({objectID=112877,summonItem={itemID=7667,name="   "}})==nil,"whitespace-only summon tool name classifies as ordinary")
 assert(ui:PickupStartKind({objectID=112877,summonItem={itemID=7667,name=5}})==nil,"non-string summon tool name classifies as ordinary")
 assert(ui:PickupStartKind({objectID=112877,summonItem={itemID=7667,name=("n"):rep(501)}})==nil,"overlong summon tool name classifies as ordinary")
 assert(ui:PickupStartKind({objectID=112877,summonItem={itemID=7667,name=("n"):rep(500)}})=="uncertain","500-char summon tool name keeps the uncertain pickup")
end
-- U1/U2/U4 LIST-KIND-AGREEMENT + U3 ROW-NOTE-LOCALE: preparation grouping and
-- row notes share the overview shape authority and reviewed locale names.
do
 addon.quests[991201]={id=991201,name="List summon pickup",minLevel=1,requirementsKnown=true,
  start={objectID=112877,name="Scrying Bowl",summonItem={itemID=7667,name="Summon tool"}}}
 addon.quests[991202]={id=991202,name="List item starter",minLevel=1,requirementsKnown=true,
  start={itemID=7666,name="Shattered Necklace",
   dropSources={{npcID=4852,name="Stonevault Oracle",locationName="Uldaman",zoneName="Uldaman"}}}}
 addon.quests[991203]={id=991203,name="List start-less",minLevel=1,requirementsKnown=true}
 addon.quests[991204]={id=991204,name="List ordinary giver",minLevel=1,requirementsKnown=true,
  start={npcID=991204,name="Ordinary giver",mapID=1453,x=10,y=20}}
 addon.quests[991205]={id=991205,name="List bottle object",minLevel=1,requirementsKnown=true,
  start={objectID=142702,name="Venom Bottle",mapID=1425,x=23.6,y=58.7}}
 local kindDungeon={key="pickup-kind-list",name="Pickup kind list",minLevel=1,maxLevel=80,
  quests={991201,991202,991203,991204,991205}}
 local savedDungeon,savedQuest,savedPrep,savedRoot,savedRootDungeon,savedLocale,savedSource=
  ui.dungeon,ui.quest,ui.preparation,ui.questTreeRoot,ui.questTreeDungeon,addon.db.locale,addon.SourceName
 local function preparationHeadings()
  ui.dungeon,ui.quest,ui.preparation=kindDungeon,nil,true
  ui.questTreeRoot,ui.questTreeDungeon,ui.search,ui.includeUnavailable=nil,nil,"",true
  ui.frame:Show();ui:RefreshQuests();ui:RefreshDetail()
  local group,found=nil,{}
  for _,r in ipairs(ui.rows)do
   if r:IsShown()then
    if r.heading then group=r.heading
    elseif r.questID then found[r.questID]=group end
   end
  end
  return found
 end
 local function prepNote(id)
  for _,r in ipairs(ui.rows)do if r:IsShown()and not r.heading and r.questID==id then return r.note.text end end
  error("missing preparation row "..id)
 end
 local groups=preparationHeadings()
 assert(groups[991201]=="PREP_uncertain","2204-modeled summon pickup lists under uncertain, not outside")
 assert(groups[991202]=="PREP_item","2198-modeled item starter lists under item, not outside")
 assert(groups[991203]=="PREP_uncertain","start-less pickup lists under uncertain, not outside")
 assert(groups[991204]=="PREP_outside","ordinary giver pickup stays outside")
 assert(groups[991205]=="PREP_outside","ordinary object pickup stays outside")
 addon.SourceName=function(point,owner)
  if owner and not owner()then return nil end
  if point.objectID==142702 and addon.db.locale=="ruRU" then
   local raw=point.name
   local function current()return addon.db.locale=="ruRU" and point.name==raw and point.objectID==142702 end
   return "Reviewed bottle label",current,current
  end
  return savedSource(point,owner)
 end
 addon.db.locale="ruRU"
 preparationHeadings()
 local bottleNote=prepNote(991205)
 assert(bottleNote:find("Reviewed bottle label",1,true),"row note carries the reviewed locale giver name")
 assert(not bottleNote:find("Venom Bottle",1,true),"row note replaces the source-language giver name")
 addon.SourceName=savedSource;addon.db.locale=savedLocale
 preparationHeadings()
 assert(prepNote(991205):find("Venom Bottle",1,true),"restored resolver keeps the source-language note")
 ui.dungeon,ui.quest,ui.preparation=savedDungeon,savedQuest,savedPrep
 ui.questTreeRoot,ui.questTreeDungeon=savedRoot,savedRootDungeon
 for _,id in ipairs({991201,991202,991203,991204,991205})do addon.quests[id]=nil end
 ui:Refresh()
end
-- F-A ROW-ITEM-ALTERNATIVES-AGREEMENT: an item start with well-formed
-- alternatives is not an item-only pickup (the shared classifier returns nil
-- for it), so the row must not claim START_ITEM_NAVIGATION while list and
-- overview say outside and detail keeps GIVER_CHOICES_REQUIRED. With known
-- choices the row stays inspectable (SOURCE_DETAILS_HINT, mirroring the
-- start-less + alternatives branch) instead of dead-ending the user with a
-- disabled QUEST_START_UNKNOWN despite recorded alternatives.
do
 addon.quests[990104].start={itemID=50033}
 addon.quests[990104].startAlternatives={{npcID=5678}}
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
 assert(ui:PickupStartKind(addon.quests[990104].start,addon.quests[990104].startAlternatives)==nil,"item + choices classifies as ordinary, never item")
 assert(not ui:IsEmptyAlternatives(addon.quests[990104].startAlternatives),"non-empty alternatives stay present")
 do
  local target=row(990104);local button=target.navigationControl;local binding=target.navigationBinding
  assert(binding.reason=="SOURCE_DETAILS_HINT","item + choices keeps details hint, never item navigation")
  assert(binding.inspect==true and binding.action==nil,"item + choices has inspection without route")
  assert(button:IsShown() and button.enabled,"item + choices stays enabled")
  button.scripts.OnEnter()
  assert(tip.shown and tip.owner==button and tip.title==addon.L("SOURCE_DETAILS") and tip.body==addon.L("SOURCE_DETAILS_HINT"),"item + choices explains choices under source title")
  local routedBefore,mappedBefore=#routed,#mapped
  button.scripts.OnClick()
  assert(#routed==routedBefore and #mapped==mappedBefore,"item + choices click dispatches no route and no map")
  assert(ui.quest==990104 and ui.renderedQuest==990104,"item + choices click inspects its own details")
 end
 addon.quests[990104].start={itemID=801,name="Own starter"};addon.quests[990104].startAlternatives=nil
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
 do
  local binding=row(990104).navigationBinding
  assert(binding.reason=="START_ITEM_NAVIGATION" and binding.inspect==true,"restored lone item starter keeps item navigation")
 end
end
-- F-D LIST-CLASSIFY-FALLBACK: with the shared classifier absent, list grouping
-- degrades to its documented place verdict (a placed pickup lists outside,
-- never item); restoring the helper recovers PREP_item.
do
 addon.quests[991301]={id=991301,name="Fallback item starter",minLevel=1,requirementsKnown=true,
  start={itemID=7666,name="Shattered Necklace"}}
 local fallbackDungeon={key="classify-fallback",name="Classify fallback fixture",minLevel=1,maxLevel=80,quests={991301}}
 local savedDungeon,savedQuest,savedPrep,savedRoot,savedRootDungeon=
  ui.dungeon,ui.quest,ui.preparation,ui.questTreeRoot,ui.questTreeDungeon
 local function fallbackHeadings()
  ui.dungeon,ui.quest,ui.preparation=fallbackDungeon,nil,true
  ui.questTreeRoot,ui.questTreeDungeon,ui.search,ui.includeUnavailable=nil,nil,"",true
  ui.frame:Show();ui:RefreshQuests();ui:RefreshDetail()
  local group,found=nil,{}
  for _,r in ipairs(ui.rows)do
   if r:IsShown()then
    if r.heading then group=r.heading
    elseif r.questID then found[r.questID]=group end
   end
  end
  return found
 end
 assert(fallbackHeadings()[991301]=="PREP_item","shared classifier present lists the item starter under item")
 local savedClassifier=addon.QuestNavigation.PickupStartKind
 addon.QuestNavigation.PickupStartKind=nil
 assert(fallbackHeadings()[991301]=="PREP_outside","missing classifier falls back to outside for a placed pickup, never item")
 addon.QuestNavigation.PickupStartKind=savedClassifier
 assert(fallbackHeadings()[991301]=="PREP_item","restored classifier recovers the item group")
 ui.dungeon,ui.quest,ui.preparation=savedDungeon,savedQuest,savedPrep
 ui.questTreeRoot,ui.questTreeDungeon=savedRoot,savedRootDungeon
 addon.quests[991301]=nil
 ui:Refresh()
end
-- LOW-2: malformed requires fail closed without throwing or writing choices.
do
 local savedChoices, savedQuests = addon.char.choices, addon.quests
 addon.char.choices = {}
 addon.quests[990201] = { id = 990201, name = "Malformed group", requires = { "bad" } }
 addon.quests[990202] = { id = 990202, name = "Numeric group", requires = { 5 } }
 addon.quests[990203] = { id = 990203, name = "String ids", requires = { { ids = "bad" } } }
 addon.quests[990204] = { id = 990204, name = "Numeric ids", requires = { { ids = 5 } } }
 addon.quests[990205] = { id = 990205, name = "Thin group", requires = { { ids = { 990101 } } } }
 for _, id in ipairs({ 990101, 990201, 990202, 990203, 990204, 990205 }) do
  local ok, result = pcall(function() return ui:ChooseBranch(id, 1, nil) end)
  assert(ok and result == false, "malformed requires must fail closed without throwing for " .. id)
 end
 local ok, result = pcall(function() return ui:ChooseBranch(990203, 1, 990101) end)
 assert(ok and result == false, "malformed ids must reject parent membership without throwing")
 local savedCatalogue = addon.quests
 addon.quests = nil
 ok, result = pcall(function() return ui:ChooseBranch(990101, 1, nil) end)
 assert(ok and result == false, "missing catalogue must fail closed without throwing")
 addon.quests = savedCatalogue
 assert(next(addon.char.choices) == nil, "failed branch choices must not leak")
 for _, id in ipairs({ 990201, 990202, 990203, 990204, 990205 }) do addon.quests[id] = nil end
 addon.char.choices = savedChoices
end
-- NEW-6: malformed dungeon quest list fails closed without throwing.
do
 local savedTargets = dungeon.quests
 local function refreshRows()
  ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.includeUnavailable=true;ui.frame:Show();ui:Refresh()
 end
 dungeon.quests = "bad"
 local ok, err = pcall(function() refreshRows() end)
 assert(ok, "bad dungeon quests threw in Refresh: "..tostring(err))
 assert(ui.currentPlan == nil, "corrupt dungeon must not publish a quest plan")
 local enginePlan = ui.engine:Dungeon(ui.dungeon, { includeUnavailable = true })
 assert(#enginePlan.rows == 0 and #enginePlan.actions == 0 and enginePlan.unknown == true and enginePlan.ready == false,
  "corrupt dungeon must plan fail-closed")
 dungeon.quests = savedTargets
 refreshRows()
 assert(row(990101).navigationControl.enabled, "valid dungeon restores navigation rows")
end
-- A6 CATALOGUE-GUARDS: nil/malformed catalogue sources fail closed without throwing.
do
 local savedDungeons, savedQuests, savedDB, savedChar = addon.dungeons, addon.quests, addon.db, addon.char
 local function refreshCatalogue()
  ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.includeUnavailable=true;ui.frame:Show();ui:RefreshDungeons()
 end
 local function shownCards()
  local count=0
  for _,card in ipairs(ui.cards)do if card:IsShown()then count=count+1 end end
  return count
 end
 refreshCatalogue()
 assert(shownCards()>0,"valid catalogue publishes dungeon cards")
 local cases={
  {"nil dungeons",function()addon.dungeons=nil end},
  {"non-table dungeons",function()addon.dungeons="bad" end},
  {"nil quests",function()addon.quests=nil end},
  {"non-table quests",function()addon.quests=7 end},
  {"nil db",function()addon.db=nil end},
  {"non-table db",function()addon.db="bad" end},
  {"nil char",function()addon.char=nil end},
 }
 for _,case in ipairs(cases)do
  case[2]()
  local ok,err=pcall(refreshCatalogue)
  addon.dungeons,addon.quests,addon.db,addon.char=savedDungeons,savedQuests,savedDB,savedChar
  assert(ok,case[1].." threw in RefreshDungeons: "..tostring(err))
 end
 for _,card in ipairs(ui.cards)do card:Hide() end
 ui.catalogNotice:Hide()
 addon.dungeons=nil;addon.quests=nil;addon.db=nil
 local ok,err=pcall(refreshCatalogue)
 addon.dungeons,addon.quests,addon.db,addon.char=savedDungeons,savedQuests,savedDB,savedChar
 assert(ok,"combined corrupt catalogue threw: "..tostring(err))
 assert(shownCards()==0,"combined corrupt catalogue must publish no rows")
 refreshCatalogue()
 assert(shownCards()>0,"valid catalogue restores dungeon cards")
end
-- A7 REFRESH-QUESTS-CHAR-GUARD: nil/non-table character fails closed without throwing.
do
 local savedChar=addon.char
 local function refreshQuests()
  ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.includeUnavailable=true;ui.frame:Show();ui:RefreshQuests()
 end
 refreshQuests()
 for _,bad in ipairs({nil,"bad",7})do
  addon.char=bad
  local ok,err=pcall(refreshQuests)
  addon.char=savedChar
  assert(ok,"bad character "..tostring(bad).." threw in RefreshQuests: "..tostring(err))
 end
 refreshQuests()
 assert(row(990101).navigationControl.enabled,"valid character restores navigation rows")
end
-- A7 CHOOSE-BRANCH-CHAR-GUARD: nil/non-table character fails closed without throwing or writing choices.
do
 local savedChar=addon.char
 addon.quests[990301]={id=990301,name="Branch A",minLevel=1,requirementsKnown=true}
 addon.quests[990302]={id=990302,name="Branch B",minLevel=1,requirementsKnown=true}
 addon.quests[990303]={id=990303,name="Branch root",minLevel=1,requirementsKnown=true,requires={{ids={990301,990302}}}}
 addon.char={choices={}}
 for _,bad in ipairs({nil,"bad",7})do
  addon.char=bad
  local ok,result=pcall(function()return ui:ChooseBranch(990303,1,nil)end)
  assert(ok and result==false,"bad character "..tostring(bad).." must fail closed without throwing (clear)")
  ok,result=pcall(function()return ui:ChooseBranch(990303,1,990301)end)
  assert(ok and result==false,"bad character "..tostring(bad).." must fail closed without throwing (parent)")
 end
 addon.char=savedChar
 assert(addon.char.choices==nil or next(addon.char.choices)==nil,"failed branch choices must not leak")
 for _,id in ipairs({990301,990302,990303})do addon.quests[id]=nil end
end
-- A7 DETAIL-REWARD-ICON-BOUNDS: itemID capped at 2^32-1, numeric texture at 2^53-1.
do
 local savedDialogue, savedLog, savedCache=addon.DialogueRewards, addon.QuestRewards, addon.CachedQuestRewards
 local savedDungeons=addon.dungeons
 addon.quests[990401]={id=990401,name="Reward bound quest",minLevel=1,requirementsKnown=true}
 local boundDungeon={key="reward-bound",name="Reward bound dungeon",minLevel=1,maxLevel=80,quests={990401}}
 addon.dungeons={boundDungeon}
 ui.dungeon,ui.quest,ui.questTreeRoot,ui.questTreeDungeon=boundDungeon,990401,nil,nil
 ui.search="";ui.includeUnavailable=true;ui.frame:Show()
 local function visibleRewardCount()
  local n=0
  for _,b in ipairs(ui.rewardButtons or {})do if b:IsShown()then n=n+1 end end
  return n
 end
 local function renderWith(item)
  addon.DialogueRewards=function(id)if id==990401 then return {source="dialogue",items={item},choices={}} end end
  addon.QuestRewards=function()return nil end
  addon.CachedQuestRewards=function()return nil end
  ui:Refresh()
  return visibleRewardCount()
 end
 assert(renderWith({id=4294967296,name="Huge item",count=1,texture=134400})==0,"itemID 2^32 must not paint a detail icon")
 assert(renderWith({id=0,name="Zero item",count=1,texture=134400})==0,"itemID 0 must not paint a detail icon")
 assert(renderWith({id=4294967295,name="Max item",count=1,texture=134400})==1,"itemID 2^32-1 keeps its detail icon")
 assert(renderWith({id=801,name="Huge texture",count=1,texture=9007199254740992})==0,"numeric texture 2^53 must not paint a detail icon")
 assert(renderWith({id=801,name="Zero texture",count=1,texture=0})==0,"numeric texture 0 must not paint a detail icon")
 assert(renderWith({id=801,name="Max texture",count=1,texture=9007199254740991})==1,"numeric texture 2^53-1 keeps its detail icon")
 addon.DialogueRewards,addon.QuestRewards,addon.CachedQuestRewards=savedDialogue,savedLog,savedCache
 addon.dungeons=savedDungeons
 addon.quests[990401]=nil
 ui.dungeon,ui.quest=dungeon,990104
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.frame:Show();ui:Refresh()
end
-- A8 DUNGEON-ENTRY-GUARDS: non-table catalogue entries fail closed without throwing.
do
 local savedDungeons=addon.dungeons
 local function refreshCatalogue()
  ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.includeUnavailable=true;ui.frame:Show();ui:RefreshDungeons()
 end
 local function shownCards()
  local count=0
  for _,card in ipairs(ui.cards)do if card:IsShown()then count=count+1 end end
  return count
 end
 addon.dungeons={dungeon}
 refreshCatalogue()
 assert(shownCards()>0,"valid catalogue publishes dungeon cards")
 for _,bad in ipairs({"bad",7,false})do
  addon.dungeons={dungeon,bad}
  local ok,err=pcall(refreshCatalogue)
  addon.dungeons=savedDungeons
  assert(ok,"non-table dungeon entry "..tostring(bad).." threw in RefreshDungeons: "..tostring(err))
 end
 addon.dungeons={dungeon,"bad",7,false}
 refreshCatalogue()
 assert(shownCards()>0,"valid entries still publish with malformed neighbours")
 addon.dungeons={"bad"}
 local ok,err=pcall(refreshCatalogue)
 assert(ok,"all-malformed catalogue threw: "..tostring(err))
 addon.dungeons=savedDungeons
 refreshCatalogue()
 assert(shownCards()>0,"valid catalogue restores dungeon cards")
end
-- A8 SEARCH-NAME-GUARD: non-string dungeon names fail closed without throwing.
do
 local savedName=dungeon.name
 local function refreshCatalogue()
  ui.search="own";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.includeUnavailable=true;ui.frame:Show();ui:RefreshDungeons()
 end
 for _,bad in ipairs({7,false})do
  dungeon.name=bad
  local ok,err=pcall(refreshCatalogue)
  dungeon.name=savedName
  assert(ok,"non-string dungeon name "..tostring(bad).." threw in RefreshDungeons: "..tostring(err))
 end
 dungeon.name=savedName
 ui.search="";ui.frame:Show();ui:RefreshDungeons()
end
-- A8 QUEST-ROW-DUNGEON-GUARD: non-table dungeon selection fails closed without throwing.
do
 local savedDungeon=ui.dungeon
 local function refreshQuests()
  ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.includeUnavailable=true;ui.frame:Show();ui:RefreshQuests()
 end
 for _,bad in ipairs({"bad",7,false})do
  ui.dungeon=bad
  local ok,err=pcall(refreshQuests)
  ui.dungeon=savedDungeon
  assert(ok,"non-table dungeon "..tostring(bad).." threw in RefreshQuests: "..tostring(err))
  assert(ui.currentPlan==nil,"non-table dungeon must not publish a quest plan")
 end
 ui.dungeon=nil
 local ok,err=pcall(refreshQuests)
 ui.dungeon=savedDungeon
 assert(ok,"nil dungeon threw in RefreshQuests: "..tostring(err))
 -- A quests-less dungeon table fails closed instead of throwing on length.
 local savedTargets=dungeon.quests
 dungeon.quests=nil
 ok,err=pcall(refreshQuests)
 dungeon.quests=savedTargets
 assert(ok,"quests-less dungeon threw in RefreshQuests: "..tostring(err))
 refreshQuests()
 assert(row(990101).navigationControl.enabled,"valid dungeon restores navigation rows")
end
-- A8 DROP-DUNGEON-KEY-GUARD: non-table catalogue entries fail closed in detail drop lookup.
do
 local savedDungeons=addon.dungeons
 addon.quests[990501]={id=990501,name="Drop quest",minLevel=1,requirementsKnown=true,start={itemID=801,name="Drop starter",dropNPCID=9,dropName="Dropper"}}
 local dropDungeon={key="drop-dungeon",name="Drop dungeon",minLevel=1,maxLevel=80,quests={990501}}
 addon.dungeons={dropDungeon}
 ui.dungeon,ui.quest,ui.questTreeRoot,ui.questTreeDungeon=dropDungeon,990501,nil,nil
 ui.search="";ui.includeUnavailable=true;ui.frame:Show();ui:Refresh()
 addon.dungeons={dropDungeon,7,"bad"}
 local ok,err=pcall(function()ui:RefreshDetail()end)
 addon.dungeons=savedDungeons
 addon.quests[990501]=nil
 assert(ok,"non-table dungeon entries threw in detail drop lookup: "..tostring(err))
 ui.dungeon,ui.quest=dungeon,990104
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.frame:Show();ui:Refresh()
end
-- A8 FILTER-CHAR-GUARDS: nil/non-table character fails closed in LoadFilters/SaveFilters.
do
 local savedChar=addon.char
 local function checkBad(bad,label)
  addon.char=bad
  local ok,err=pcall(function()ui:LoadFilters()end)
  assert(ok,"character "..label.." threw in LoadFilters: "..tostring(err))
  ok,err=pcall(function()ui:SaveFilters()end)
  assert(ok,"character "..label.." threw in SaveFilters: "..tostring(err))
 end
 checkBad(nil,"nil")
 for _,bad in ipairs({"bad",7,false})do checkBad(bad,tostring(bad)) end
 addon.char={}
 ui.range=true;ui.includeUnavailable=false
 ui:SaveFilters()
 assert(addon.char.filters.range==true and addon.char.filters.includeUnavailable==false,"SaveFilters persists toggles")
 addon.char=savedChar
 ui:LoadFilters()
end
-- A8 OBJECTIVE-ICON-BOUNDS: objective textures render only under reward icon bounds.
do
 local savedIcon=addon.ItemIcon
 local savedDungeons=addon.dungeons
 addon.quests[990601]={id=990601,name="Objective bound quest",minLevel=1,requirementsKnown=true,objectiveItems={{itemID=801,name="Bound item",quantity=1}}}
 local boundDungeon={key="objective-bound",name="Objective bound dungeon",minLevel=1,maxLevel=80,quests={990601}}
 addon.dungeons={boundDungeon}
 ui.dungeon,ui.quest,ui.questTreeRoot,ui.questTreeDungeon=boundDungeon,990601,nil,nil
 ui.search="";ui.includeUnavailable=true;ui.frame:Show()
 local function visibleObjectiveCount()
  local n=0
  for _,b in ipairs(ui.objectiveButtons or {})do if b:IsShown()then n=n+1 end end
  return n
 end
 local function renderWith(icon)
  addon.ItemIcon=function(itemID)assert(itemID==801);return icon end
  ui:Refresh()
  return visibleObjectiveCount()
 end
 assert(renderWith(134400)==1,"valid objective icon paints")
 assert(renderWith(4294967295)==1,"max uint32 objective icon paints")
 for _,bad in ipairs({0,-1,1.5,4294967296,9007199254740992})do
  assert(renderWith(bad)==0,"objective icon "..tostring(bad).." must not paint")
 end
 addon.ItemIcon=savedIcon
 addon.dungeons=savedDungeons
 addon.quests[990601]=nil
 ui.dungeon,ui.quest=dungeon,990104
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.frame:Show();ui:Refresh()
end
-- A8 CREATE-CHAR-GUARDS: nil/non-table catalogue and character fail closed in Create.
do
 local savedDungeons,savedChar,savedDungeon=addon.dungeons,addon.char,ui.dungeon
 addon.dungeons={dungeon,7,"bad"}
 local ok,err=pcall(function()ui:Create()end)
 assert(ok,"non-table dungeon entries threw in Create: "..tostring(err))
 addon.dungeons=savedDungeons
 for _,bad in ipairs({"bad",7})do
  addon.char=bad
  ok,err=pcall(function()ui:Create()end)
  assert(ok,"character "..tostring(bad).." threw in Create: "..tostring(err))
 end
 addon.char=nil
 ok,err=pcall(function()ui:Create()end)
 assert(ok,"nil character threw in Create: "..tostring(err))
 addon.dungeons,addon.char=savedDungeons,savedChar
 ui:Create()
 ui.dungeon=savedDungeon
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.includeUnavailable=true;ui.frame:Show();ui:Refresh()
 assert(row(990101).navigationControl.enabled,"recreated window restores navigation rows")
end
-- A9 SEARCHFOLD-NONSTRING-GUARD: hostile SearchFold returning a truthy non-string falls back to the raw value without throwing.
do
 local savedFold=addon.SearchFold
 local function shownCards()
  local count=0
  for _,card in ipairs(ui.cards)do if card:IsShown()then count=count+1 end end
  return count
 end
 ui.search="own";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.includeUnavailable=true;ui.frame:Show();ui:RefreshDungeons()
 local expected={}
 for _,card in ipairs(ui.cards)do if card:IsShown()then expected[#expected+1]=card.title.text..":"..tostring(card.matchQuestID) end end
 table.sort(expected)
 assert(#expected>0,"valid search publishes dungeon cards")
 for _,bad in ipairs({42,true,{}})do
  addon.SearchFold=function()return bad end
  local ok,err=pcall(function()
   ui.search="own";ui:RefreshDungeons()
   ui.search="";ui:RefreshQuests()
   ui.search="own";ui:Refresh()
  end)
  local actual={}
  if ok then
   for _,card in ipairs(ui.cards)do if card:IsShown()then actual[#actual+1]=card.title.text..":"..tostring(card.matchQuestID) end end
   table.sort(actual)
  end
  addon.SearchFold=savedFold
  assert(ok,"hostile SearchFold "..type(bad).." threw: "..tostring(err))
  -- Fallback keeps the raw value without case folding, so hostile matching is a
  -- case-sensitive subset of the folded baseline: never throws, never invents rows.
  local known={}
  for _,key in ipairs(expected)do known[key]=true end
  for _,key in ipairs(actual)do assert(known[key],"hostile SearchFold "..type(bad).." invented a row: "..key) end
  assert(#actual<=#expected,"hostile SearchFold "..type(bad).." must not widen results")
 end
 addon.SearchFold=savedFold
 ui.search="";ui.frame:Show();ui:RefreshDungeons()
 assert(shownCards()>0,"valid fold restores dungeon cards")
end
-- A9 DETAIL-XP-UPPER-BOUND: xp capped at 2^53-1 mirroring money.
do
 local savedDialogue, savedLog, savedCache=addon.DialogueRewards, addon.QuestRewards, addon.CachedQuestRewards
 local savedDungeons=addon.dungeons
 addon.quests[990402]={id=990402,name="XP bound quest",minLevel=1,requirementsKnown=true}
 local boundDungeon={key="xp-bound",name="XP bound dungeon",minLevel=1,maxLevel=80,quests={990402}}
 addon.dungeons={boundDungeon}
 ui.dungeon,ui.quest,ui.questTreeRoot,ui.questTreeDungeon=boundDungeon,990402,nil,nil
 ui.search="";ui.includeUnavailable=true;ui.frame:Show()
 if type(ui.SetDetailTab)=="function" then ui:SetDetailTab("quest") end
 local function fieldShown(fs)
  if fs.shown ~= nil then return fs.shown == true end
  if type(fs.IsShown)=="function" then local ok,v=pcall(function()return fs:IsShown()end);return ok and v==true end
  return false
 end
 local function hasText(want)
  for _,fs in ipairs(ui.details)do if fieldShown(fs) and fs.text and fs.text:find(want,1,true)then return true end end
  return false
 end
 local function renderWith(xp)
  addon.DialogueRewards=function(id) if id==990402 then return {source="dialogue",items={},choices={},xp=xp} end end
  addon.QuestRewards=function()return nil end
  addon.CachedQuestRewards=function()return nil end
  ui:Refresh()
  return hasText(addon.L("REWARD_XP",xp))
 end
 assert(renderWith(0)==true,"xp 0 keeps its detail gain")
 assert(renderWith(9007199254740991)==true,"xp 2^53-1 keeps its detail gain")
 assert(renderWith(9007199254740992)==false,"xp 2^53 must not paint a detail gain")
 assert(renderWith(-1)==false,"negative xp must not paint a detail gain")
 assert(renderWith(1.5)==false,"fractional xp must not paint a detail gain")
 assert(renderWith(9007199254740992)==false and not hasText(addon.L("DETAIL_REWARDS")),"uncapped xp must not publish a rewards heading")
 addon.DialogueRewards,addon.QuestRewards,addon.CachedQuestRewards=savedDialogue,savedLog,savedCache
 addon.dungeons=savedDungeons
 addon.quests[990402]=nil
 ui.dungeon,ui.quest=dungeon,990104
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.frame:Show();ui:Refresh()
end
-- A10 OBJECTIVES-RENDER-GUARD: hostile objective entries are skipped, never thrown.
do
 local savedObjectives=addon.QuestObjectives
 local savedDungeons=addon.dungeons
 local savedSecret=issecretvalue
 issecretvalue=function()return false end
 addon.quests[990701]={id=990701,name="Objectives guard quest",minLevel=1,requirementsKnown=true}
 local guardDungeon={key="objectives-guard",name="Objectives guard dungeon",minLevel=1,maxLevel=80,quests={990701}}
 addon.dungeons={guardDungeon}
 ui.dungeon,ui.quest,ui.questTreeRoot,ui.questTreeDungeon=guardDungeon,990701,nil,nil
 ui.search="";ui.includeUnavailable=true;ui.frame:Show()
 if type(ui.SetDetailTab)=="function" then ui:SetDetailTab("quest") end
 local function fieldShown(fs)
  if fs.shown ~= nil then return fs.shown == true end
  if type(fs.IsShown)=="function" then local ok,v=pcall(function()return fs:IsShown()end);return ok and v==true end
  return false
 end
 local function hasText(want)
  for _,fs in ipairs(ui.details)do if fieldShown(fs) and fs.text and fs.text:find(want,1,true)then return true end end
  return false
 end
 local function renderWith(list)
  addon.QuestObjectives=function(id) if id==990701 then return list end end
  local ok,err=pcall(function() ui:Refresh() end)
  return ok,err
 end
 do
  local ok,err=renderWith({{text="Good objective",finished=true}})
  assert(ok,"valid objectives threw: "..tostring(err))
  assert(hasText("Good objective"),"valid objective keeps its detail line")
 end
 do
  local hostile={7,"bad",{text=5,finished=true},{text="Missing finished"},
   {text=("x"):rep(30001),finished=false},{finished=true},{text="Good survivor",finished=false}}
  local ok,err=renderWith(hostile)
  assert(ok,"hostile objectives threw: "..tostring(err))
  assert(hasText("Good survivor"),"valid survivor renders after broken objective entries")
  assert(not hasText("Missing finished"),"finish-less objective stays skipped")
  assert(not hasText(("x"):rep(100)),"overlong objective text stays skipped")
 end
 addon.QuestObjectives=savedObjectives
 issecretvalue=savedSecret
 addon.dungeons=savedDungeons
 addon.quests[990701]=nil
 ui.dungeon,ui.quest=dungeon,990104
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.frame:Show();ui:Refresh()
end
-- A10 LOOT-ITEM-GUARD: hostile loot entries are skipped, counts capped at 2^53-1.
do
 local savedDialogue,savedLog,savedCache=addon.DialogueRewards,addon.QuestRewards,addon.CachedQuestRewards
 local savedDungeons=addon.dungeons
 local savedSecret=issecretvalue
 issecretvalue=function()return false end
 addon.quests[990702]={id=990702,name="Loot guard quest",minLevel=1,requirementsKnown=true}
 local guardDungeon={key="loot-guard",name="Loot guard dungeon",minLevel=1,maxLevel=80,quests={990702}}
 addon.dungeons={guardDungeon}
 ui.dungeon,ui.quest,ui.questTreeRoot,ui.questTreeDungeon=guardDungeon,990702,nil,nil
 ui.search="";ui.includeUnavailable=true;ui.frame:Show()
 if type(ui.SetDetailTab)=="function" then ui:SetDetailTab("quest") end
 local function fieldShown(fs)
  if fs.shown ~= nil then return fs.shown == true end
  if type(fs.IsShown)=="function" then local ok,v=pcall(function()return fs:IsShown()end);return ok and v==true end
  return false
 end
 local function hasText(want)
  for _,fs in ipairs(ui.details)do if fieldShown(fs) and fs.text and fs.text:find(want,1,true)then return true end end
  return false
 end
 local function renderWith(items)
  addon.DialogueRewards=function(id) if id==990702 then return {source="dialogue",items=items,choices={}} end end
  addon.QuestRewards=function()return nil end
  addon.CachedQuestRewards=function()return nil end
  local ok,err=pcall(function() ui:Refresh() end)
  return ok,err
 end
 do
  local ok,err=renderWith({{id=801,name="Fixed reward",count=2}})
  assert(ok,"valid loot threw: "..tostring(err))
  assert(hasText(addon.L("REWARD_ITEM","Fixed reward",2)),"valid loot keeps its detail line")
 end
 do
  local hostile={7,{name="No count"},{count=2},{name="",count=1},{name="Huge count",count=9007199254740992},
   {name="Table count",count={}},{name=("y"):rep(30001),count=1},{id=801,name="Lone survivor",count=3}}
  local ok,err=renderWith(hostile)
  assert(ok,"hostile loot threw: "..tostring(err))
  assert(hasText(addon.L("REWARD_ITEM","Lone survivor",3)),"valid survivor renders after broken loot entries")
  assert(not hasText("No count"),"count-less loot stays skipped")
  assert(not hasText("Huge count"),"uncapped loot count stays skipped")
  assert(not hasText(("y"):rep(100)),"overlong loot name stays skipped")
 end
 addon.DialogueRewards,addon.QuestRewards,addon.CachedQuestRewards=savedDialogue,savedLog,savedCache
 issecretvalue=savedSecret
 addon.dungeons=savedDungeons
 addon.quests[990702]=nil
 ui.dungeon,ui.quest=dungeon,990104
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.frame:Show();ui:Refresh()
end
-- A10 ROW-ACTION-LEVEL-GUARD: a mutated minLevel between State and Next drops
-- the suffix instead of concatenating a table.
do
 local savedDungeons=addon.dungeons
 local savedDungeon,savedPrep=ui.dungeon,ui.preparation
 local reads=0
 local proxy={id=990801,name="Level guard quest",requirementsKnown=true}
 setmetatable(proxy,{__index=function(t,k)
  if k=="minLevel" then reads=reads+1;return reads<=3 and 80 or {} end
 end})
 addon.quests[990801]=proxy
 addon.quests[990802]={id=990802,name="Plain level quest",minLevel=80,requirementsKnown=true}
 local guardDungeon={key="level-guard",name="Level guard dungeon",minLevel=1,maxLevel=80,quests={990801,990802}}
 addon.dungeons={guardDungeon}
 ui.dungeon=guardDungeon;ui.preparation=true;ui.includeUnavailable=true
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.frame:Show()
 local function noteOf(id)
  for _,r in ipairs(ui.rows)do if r:IsShown() and not r.heading and r.questID==id and r.note then return r.note.text end end
 end
 reads=0
 local ok,err=pcall(function() ui:RefreshQuests() end)
 assert(ok,"mutated minLevel threw in RefreshQuests: "..tostring(err))
 local plain=noteOf(990802)
 assert(plain and plain:find("80",1,true),"plain level action keeps its suffix")
 local hostile=noteOf(990801)
 assert(hostile and hostile:find(addon.L("level"),1,true),"mutated level action keeps its kind label")
 assert(hostile and not hostile:find("table:",1,true),"mutated minLevel drops the suffix instead of concatenating a table")
 addon.quests[990801]=nil;addon.quests[990802]=nil
 addon.dungeons=savedDungeons
 ui.dungeon,ui.preparation=savedDungeon,savedPrep
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.includeUnavailable=true;ui.frame:Show();ui:RefreshQuests()
end
-- A11 ROW-MINLEVEL-CLEAN-GUARD: a hostile catalogue minLevel drops the row
-- suffix instead of throwing in concatenation, mirroring the Clean-guarded
-- action level suffix at :2684.
do
 local savedDungeons = addon.dungeons
 local savedDungeon, savedPrep = ui.dungeon, ui.preparation
 local savedLevel = context.level
 addon.quests[990803] = { id = 990803, name = "Hostile minLevel quest", minLevel = {}, requirementsKnown = true,
  start = { npcID = 42, name = "Guard giver", mapID = 1453, x = 10, y = 20 } }
 addon.quests[990804] = { id = 990804, name = "Plain minLevel quest", minLevel = 1, requirementsKnown = true,
  start = { npcID = 43, name = "Plain giver", mapID = 1453, x = 10, y = 20 } }
 local guardDungeon = { key = "row-minlevel-guard", name = "Row minLevel guard dungeon", minLevel = 1, maxLevel = 80, quests = { 990803, 990804 } }
 addon.dungeons = { guardDungeon }
 ui.dungeon = guardDungeon; ui.preparation = false; ui.includeUnavailable = true
 ui.search = ""; ui.questTreeRoot = nil; ui.questTreeDungeon = nil; ui.quest = 990804; ui.frame:Show()
 -- A hostile character level forces UNKNOWN/level rows without reading any
 -- catalogue minimum, so the row render alone faces the hostile minLevel.
 context.level = {}
 local function noteOf(id)
  for _, r in ipairs(ui.rows) do if r:IsShown() and not r.heading and r.questID == id and r.note then return r.note.text end end
 end
 local ok, err = pcall(function() ui:RefreshQuests() end)
 assert(ok, "hostile row minLevel threw in RefreshQuests: " .. tostring(err))
 local hostile = noteOf(990803)
 assert(hostile and hostile:find(addon.L("level"), 1, true), "hostile row minLevel keeps its kind label")
 assert(hostile and not hostile:find("table:", 1, true), "hostile row minLevel drops the suffix instead of concatenating a table")
 local plain = noteOf(990804)
 assert(plain and plain:find("1", 1, true), "plain row minLevel keeps its suffix")
 context.level = savedLevel
 addon.quests[990803] = nil; addon.quests[990804] = nil
 addon.dungeons = savedDungeons
 ui.dungeon, ui.preparation = savedDungeon, savedPrep
 ui.search = ""; ui.questTreeRoot = nil; ui.questTreeDungeon = nil; ui.includeUnavailable = true; ui.frame:Show(); ui:RefreshQuests()
end
-- A11 GIVER-FALLBACK-CAP: an overlong or blank place name falls back to
-- UNKNOWN_PLACE instead of painting, mirroring the 1024-char reviewed-name
-- guards at :297-301 and :308-309.
do
 local savedDungeons = addon.dungeons
 local savedDungeon, savedQuest = ui.dungeon, ui.quest
 addon.quests[990805] = { id = 990805, name = "Long giver quest", minLevel = 1, requirementsKnown = true,
  start = { name = ("n"):rep(1025) } }
 addon.quests[990806] = { id = 990806, name = "Blank giver quest", minLevel = 1, requirementsKnown = true,
  start = { name = "   " } }
 local capDungeon = { key = "giver-fallback-cap", name = "Giver fallback cap dungeon", minLevel = 1, maxLevel = 80, quests = { 990805, 990806 } }
 addon.dungeons = { capDungeon }
 ui.dungeon = capDungeon; ui.questTreeRoot, ui.questTreeDungeon = nil, nil
 ui.search = ""; ui.includeUnavailable = true; ui.frame:Show()
 if type(ui.SetDetailTab) == "function" then ui:SetDetailTab("quest") end
 local function fieldShown(fs)
  if fs.shown ~= nil then return fs.shown == true end
  if type(fs.IsShown) == "function" then local ok, v = pcall(function() return fs:IsShown() end); return ok and v == true end
  return false
 end
 local function hasText(want)
  for _, fs in ipairs(ui.details) do if fieldShown(fs) and fs.text and fs.text:find(want, 1, true) then return true end end
  return false
 end
 ui.quest = 990805; ui:Refresh()
 assert(not hasText(("n"):rep(100)), "overlong giver name stays unpainted")
 ui.quest = 990806; ui:Refresh()
 local blank = false
 for _, fs in ipairs(ui.details) do if fieldShown(fs) and fs.text == "   " then blank = true end end
 assert(not blank, "blank giver name stays unpainted")
 addon.quests[990805] = nil; addon.quests[990806] = nil
 addon.dungeons = savedDungeons
 ui.dungeon, ui.quest = savedDungeon, savedQuest
 ui.search = ""; ui.questTreeRoot = nil; ui.questTreeDungeon = nil; ui.frame:Show(); ui:Refresh()
end
-- A11 REPORTED-PLACES-BOUNDS: reported places mirror scripts/catalog.py with
-- uint32 npc/object identity, 2^53-1 report mapIDs (pinned DP-5 REPORTED-MAP-BOUND
-- in tests/ui_preparation.lua), 500-char report zone names and the 1024-char giver
-- name budget; hostile identities stay unbound while boundary values bind.
do
 local savedDungeons = addon.dungeons
 local savedDungeon, savedQuest = ui.dungeon, ui.quest
 local function validStart(overrides)
  local s = { npcID = 5, name = "Reported giver", mapID = 1453, x = 10, y = 20, zoneName = "Stormwind City",
   reportedLocations = { { mapID = 1453, x = 10, y = 20, zoneName = "Stormwind City" }, { mapID = 1453, x = 40, y = 50, zoneName = "Stormwind City" } } }
  if overrides then for k, v in pairs(overrides) do s[k] = v end end
  return s
 end
 local cases = {
  { label = "valid", start = validStart(), bound = true },
  { label = "max-uint32 report mapID", start = { npcID = 5, name = "Reported giver", mapID = 1453, x = 10, y = 20, zoneName = "Stormwind City",
    reportedLocations = { { mapID = 4294967295, x = 10, y = 20, zoneName = "Far away" }, { mapID = 1453, x = 40, y = 50, zoneName = "Near" } } }, bound = true },
  { label = "max-safe report mapID", start = { npcID = 5, name = "Reported giver", mapID = 1453, x = 10, y = 20, zoneName = "Stormwind City",
    reportedLocations = { { mapID = 9007199254740991, x = 10, y = 20, zoneName = "Far away" }, { mapID = 1453, x = 40, y = 50, zoneName = "Near" } } }, bound = true },
  { label = "huge report mapID", start = { npcID = 5, name = "Reported giver", mapID = 1453, x = 10, y = 20, zoneName = "Stormwind City",
    reportedLocations = { { mapID = 9007199254740992, x = 10, y = 20, zoneName = "Far away" }, { mapID = 1453, x = 40, y = 50, zoneName = "Near" } } }, bound = false },
  { label = "huge npcID", start = validStart({ npcID = 4294967296 }), bound = false },
  { label = "overlong report zone", start = { npcID = 5, name = "Reported giver", mapID = 1453, x = 10, y = 20, zoneName = "Stormwind City",
    reportedLocations = { { mapID = 1453, x = 10, y = 20, zoneName = ("z"):rep(501) }, { mapID = 1453, x = 40, y = 50, zoneName = "Near" } } }, bound = false },
  { label = "overlong parent name", start = validStart({ name = ("n"):rep(1025) }), bound = true },
 }
 for index, case in ipairs(cases) do
  local qid = 990808 + index
  addon.quests[qid] = { id = qid, name = "Reported bound quest " .. index, minLevel = 1, requirementsKnown = true, start = case.start }
  local boundDungeon = { key = "reported-bound-" .. index, name = "Reported bound dungeon " .. index, minLevel = 1, maxLevel = 80, quests = { qid } }
  addon.dungeons = { boundDungeon }
  ui.dungeon, ui.quest, ui.questTreeRoot, ui.questTreeDungeon = boundDungeon, qid, nil, nil
  ui.search = ""; ui.includeUnavailable = true; ui.frame:Show()
  if type(ui.SetDetailTab) == "function" then ui:SetDetailTab("sources") end
  local ok, err = pcall(function() ui:Refresh() end)
  assert(ok, case.label .. " threw in Refresh: " .. tostring(err))
  local toggle = nil
  for _, row in ipairs(ui.reportedToggles or {}) do if row.shown and row.locationKey == "start" then toggle = row end end
  assert((toggle ~= nil) == case.bound, case.label .. " must " .. (case.bound and "bind" or "stay unbound"))
  addon.quests[qid] = nil
 end
 addon.dungeons = savedDungeons
 ui.dungeon, ui.quest = savedDungeon, savedQuest
 ui.search = ""; ui.questTreeRoot = nil; ui.questTreeDungeon = nil; ui.frame:Show(); ui:Refresh()
end
-- A12 ITEMNAME-BLANK-GUARD: a whitespace-only native name stays unknown like
-- empty and oversized names, mirroring every sibling %S producer guard.
do
 local savedItem = C_Item
 local nativeNames = { [880101] = "   ", [880102] = ("n"):rep(1025), [880103] = ("n"):rep(1024), [880104] = "Real item" }
 C_Item = { GetItemNameByID = function(id) return nativeNames[id] end }
 assert(addon.ItemName(880104) == "Real item", "valid native name keeps its producer value")
 assert(addon.ItemName(880103) == ("n"):rep(1024), "1024-char native name keeps its producer value")
 assert(addon.ItemName(880101) == nil, "whitespace-only native name stays unknown")
 assert(addon.ItemName(880102) == nil, "overlong native name stays unknown")
 C_Item = savedItem
end
-- A12 ZONE-DISPLAY-CAPS: overlong or blank native zone names fall back to the
-- catalogue zone instead of painting, mirroring the 500-char report budget.
do
 local savedMap = C_Map
 local savedDungeons = addon.dungeons
 local savedDungeon, savedQuest = ui.dungeon, ui.quest
 local savedExpanded = ui.reportedExpanded.start
 addon.quests[990901] = { id = 990901, name = "Zone cap quest", minLevel = 1, requirementsKnown = true,
  start = { npcID = 91, name = "Zone giver", mapID = 1453, x = 10, y = 20, zoneName = "ZZZ nowhere vale 9909",
   reportedLocations = { { mapID = 1453, x = 10, y = 20, zoneName = "ZZZ nowhere vale 9909" }, { mapID = 1453, x = 40, y = 50, zoneName = "ZZZ far vale 9910" } } } }
 local capDungeon = { key = "zone-cap", name = "Zone cap dungeon", minLevel = 1, maxLevel = 80, quests = { 990901 } }
 addon.dungeons = { capDungeon }
 ui.dungeon, ui.quest, ui.questTreeRoot, ui.questTreeDungeon = capDungeon, 990901, nil, nil
 ui.search = ""; ui.includeUnavailable = true; ui.frame:Show()
 if type(ui.SetDetailTab) == "function" then ui:SetDetailTab("sources") end
 ui.reportedExpanded.start = true
 local function startTitles()
  local out = {}
  for _, row in ipairs(ui.reportedRows or {}) do
   if row.locationKey == "start" and row.title and row.title.text then out[#out + 1] = row.title.text end
  end
  return out
 end
 -- The first paint binds the toggle (a quest change resets expansion), so
 -- re-arm expansion before hostile natives render the reported rows.
 ui:Refresh()
 ui.reportedExpanded.start = true
 for _, native in ipairs({ ("n"):rep(501), "   " }) do
  C_Map = { GetMapInfo = function() return { name = native } end }
  local ok, err = pcall(function() ui:Refresh() end)
  assert(ok, "hostile native zone threw in Refresh: " .. tostring(err))
  local titles = startTitles()
  assert(#titles == 2, "reported rows stay bound with a hostile native zone")
  for _, title in ipairs(titles) do
   assert(not title:find(("n"):rep(100), 1, true), "overlong native zone stays unpainted")
  end
  assert(titles[1]:find("ZZZ nowhere vale 9909", 1, true) and titles[2]:find("ZZZ far vale 9910", 1, true),
   "hostile native zone falls back to the catalogue zone")
 end
 C_Map = savedMap
 ui.reportedExpanded.start = savedExpanded
 addon.quests[990901] = nil
 addon.dungeons = savedDungeons
 ui.dungeon, ui.quest = savedDungeon, savedQuest
 ui.search = ""; ui.questTreeRoot = nil; ui.questTreeDungeon = nil; ui.frame:Show(); ui:Refresh()
end
-- A12 ALTERNATIVE-ZONE-CAPS: overlong or blank catalogue and location zones
-- fall back instead of painting in alternative rows, mirroring giver names.
do
 local savedMap = C_Map
 local savedDungeons = addon.dungeons
 local savedDungeon, savedQuest = ui.dungeon, ui.quest
 addon.quests[990902] = { id = 990902, name = "Alternative zone quest", minLevel = 1, requirementsKnown = true,
  start = { npcID = 92, name = "Alternative zone giver", mapID = 1453, x = 10, y = 20 } }
 local altDungeon = { key = "alternative-zone-cap", name = "Alternative zone cap dungeon", minLevel = 1, maxLevel = 80, quests = { 990902 } }
 addon.dungeons = { altDungeon }
 ui.dungeon, ui.quest, ui.questTreeRoot, ui.questTreeDungeon = altDungeon, 990902, nil, nil
 ui.search = ""; ui.includeUnavailable = true; ui.frame:Show()
 if type(ui.SetDetailTab) == "function" then ui:SetDetailTab("sources") end
 local function startNotes()
  local out = {}
  for _, row in ipairs(ui.startButtons or {}) do
   if row:IsShown() and row.note and row.note.text then out[#out + 1] = row.note.text end
  end
  return out
 end
 local cases = {
  { label = "overlong canonical", zoneName = ("z"):rep(501), locationName = "Short vale", native = nil, want = "Short vale" },
  { label = "blank canonical", zoneName = "   ", locationName = "Short vale", native = nil, want = "Short vale" },
  { label = "overlong native", zoneName = "Plain vale", locationName = nil, native = ("n"):rep(501), want = "Plain vale" },
  { label = "overlong location", zoneName = nil, locationName = ("l"):rep(501), native = nil, want = addon.L("UNKNOWN_PLACE") },
 }
 for _, case in ipairs(cases) do
  addon.quests[990902].startAlternatives = {
   { name = "Alt giver one", mapID = 1453, x = 10, y = 20, zoneName = case.zoneName, locationName = case.locationName },
   { name = "Alt giver two", mapID = 1453, x = 40, y = 50, zoneName = case.zoneName, locationName = case.locationName } }
  if case.native then C_Map = { GetMapInfo = function() return { name = case.native } end }
  else C_Map = nil end
  local ok, err = pcall(function() ui:Refresh() end)
  assert(ok, case.label .. " threw in Refresh: " .. tostring(err))
  local notes = startNotes()
  assert(#notes == 2, case.label .. " keeps both alternative rows")
  for _, note in ipairs(notes) do
   assert(not note:find(("z"):rep(100), 1, true) and not note:find(("n"):rep(100), 1, true) and not note:find(("l"):rep(100), 1, true),
    case.label .. " stays unpainted")
   assert(note:find(case.want, 1, true), case.label .. " falls back to " .. tostring(case.want))
  end
 end
 C_Map = savedMap
 addon.quests[990902] = nil
 addon.dungeons = savedDungeons
 ui.dungeon, ui.quest = savedDungeon, savedQuest
 ui.search = ""; ui.questTreeRoot = nil; ui.questTreeDungeon = nil; ui.frame:Show(); ui:Refresh()
end
-- A12 CHOOSE-BRANCH-ID-BOUNDS: ids beyond 2^53 fail closed without writing choices.
do
 local savedChoices = addon.char.choices
 local HUGE = 9007199254740992
 addon.char.choices = {}
 addon.quests[990301] = { id = 990301, name = "Branch A", minLevel = 1, requirementsKnown = true }
 addon.quests[990302] = { id = 990302, name = "Branch B", minLevel = 1, requirementsKnown = true }
 addon.quests[990303] = { id = 990303, name = "Branch root", minLevel = 1, requirementsKnown = true, requires = { { ids = { 990301, 990302 } } } }
 addon.quests[HUGE] = { id = HUGE, name = "Huge root", minLevel = 1, requirementsKnown = true, requires = { { ids = { 990301, 990302 } } } }
 local ok, result = pcall(function() return ui:ChooseBranch(HUGE, 1, nil) end)
 assert(ok and result == false, "huge branch id must fail closed without throwing")
 assert(addon.char.choices[HUGE] == nil, "huge branch id must not write choices")
 ok, result = pcall(function() return ui:ChooseBranch(990303, HUGE, nil) end)
 assert(ok and result == false, "huge branch index must fail closed without throwing")
 ok, result = pcall(function() return ui:ChooseBranch(990303, 1, HUGE) end)
 assert(ok and result == false, "huge branch parent must fail closed without throwing")
 ok, result = pcall(function() return ui:ChooseBranch(990303, 1, nil) end)
 assert(ok and result == true, "ordinary branch clear keeps working")
 assert(addon.char.choices[HUGE] == nil, "failed branch choices must not leak")
 for _, id in ipairs({ 990301, 990302, 990303, HUGE }) do addon.quests[id] = nil end
 addon.char.choices = savedChoices
end
-- A12 COPYLINK-ID-BOUND: a huge link id fails closed before touching copy UI.
do
 local HUGE = 9007199254740992
 local savedQuest, savedBox = ui.quest, ui.copy
 ui.quest = HUGE
 local ok, result = pcall(function() return ui:CopyLink(HUGE) end)
 ui.quest = savedQuest
 assert(ok, "huge copy id threw: " .. tostring(result))
 assert(result == false, "huge copy id must fail closed")
 assert(ui.copy == savedBox, "huge copy id must not touch copy UI")
 ui.search = ""; ui.questTreeRoot = nil; ui.questTreeDungeon = nil; ui.frame:Show(); ui:Refresh()
end
-- A12 CATALOG-SEARCH-ID-FALLBACK: a hostile catalogue id fails the source
-- match closed instead of throwing in the "#" fallback concatenation.
do
 local savedDungeons = addon.dungeons
 local savedGetter = addon.QuestSourceSearchTerms
 local hostileID = {}
 addon.quests[hostileID] = { id = hostileID }
 local hostileDungeon = { key = "hostile-search", name = "Hostile search dungeon", minLevel = 1, maxLevel = 80, quests = { hostileID } }
 addon.QuestSourceSearchTerms = function(quest)
  if quest and quest.id == hostileID then
   return { { kind = "npc", text = "zzzqqq hostile match" } }, function() return true end, function() return true end
  end
  return savedGetter(quest)
 end
 addon.dungeons = { hostileDungeon }
 local function shownCards()
  local count = 0
  for _, card in ipairs(ui.cards) do if card:IsShown() then count = count + 1 end end
  return count
 end
 ui.search = "zzzqqq"; ui.questTreeRoot = nil; ui.questTreeDungeon = nil; ui.includeUnavailable = true; ui.frame:Show()
 local ok, err = pcall(function() ui:RefreshDungeons() end)
 addon.dungeons = savedDungeons
 addon.quests[hostileID] = nil
 addon.QuestSourceSearchTerms = savedGetter
 assert(ok, "hostile catalogue id threw in RefreshDungeons: " .. tostring(err))
 assert(shownCards() == 0, "hostile catalogue id publishes no card")
 ui.search = ""; ui.frame:Show(); ui:RefreshDungeons()
 assert(shownCards() > 0, "valid catalogue restores dungeon cards")
end
-- A12 DETAIL-TITLE-ID-FALLBACK: a hostile selected id falls back to "#?"
-- instead of throwing in the "#" fallback concatenation.
do
 local savedQuestName = addon.QuestName
 local savedQuest = ui.quest
 local hostileID = {}
 addon.QuestName = function(id)
  if id == hostileID then return nil end
  return savedQuestName(id)
 end
 ui.quest = hostileID
 if type(ui.SetDetailTab) == "function" then ui:SetDetailTab("quest") end
 local ok, err = pcall(function() ui:RefreshDetail() end)
 local found = false
 for _, fs in ipairs(ui.details) do
  if fs.shown and fs.text == "#?" then found = true end
 end
 addon.QuestName = savedQuestName
 ui.quest = savedQuest
 assert(ok, "hostile selected id threw in RefreshDetail: " .. tostring(err))
 assert(found, "hostile selected id falls back to #?")
 ui.search = ""; ui.questTreeRoot = nil; ui.questTreeDungeon = nil; ui.frame:Show(); ui:Refresh()
end
-- A15 DUNGEONART-SHOW-GUARD: a throwing Show cannot escape PaintDungeonArt,
-- mirroring the pcall guards around SetTexture/Hide/SetTexCoord.
do
 local tex = {
  SetTexture = function(self, value) return true end,
  SetTexCoord = function(self, ...) end,
  Show = function(self) error("hostile Show") end,
  Hide = function(self) end,
 }
 local ok, result = pcall(addon.PaintDungeonArt, tex, {}, nil, nil)
 assert(ok, "throwing Show threw in PaintDungeonArt: " .. tostring(result))
 assert(result == true, "valid paint with a throwing Show keeps its success")
end
-- A15 LOOT-WHITESPACE-GUARD: a whitespace-only loot name stays skipped like
-- empty and overlong names, mirroring every sibling %S item guard.
do
 local savedDialogue, savedLog, savedCache = addon.DialogueRewards, addon.QuestRewards, addon.CachedQuestRewards
 local savedDungeons = addon.dungeons
 local savedSecret = issecretvalue
 issecretvalue = function() return false end
 addon.quests[990703] = { id = 990703, name = "Whitespace loot quest", minLevel = 1, requirementsKnown = true }
 local guardDungeon = { key = "loot-whitespace", name = "Loot whitespace dungeon", minLevel = 1, maxLevel = 80, quests = { 990703 } }
 addon.dungeons = { guardDungeon }
 ui.dungeon, ui.quest, ui.questTreeRoot, ui.questTreeDungeon = guardDungeon, 990703, nil, nil
 ui.search = ""; ui.includeUnavailable = true; ui.frame:Show()
 if type(ui.SetDetailTab) == "function" then ui:SetDetailTab("quest") end
 local function blankPainted()
  for _, fs in ipairs(ui.details) do
   if fs.shown and fs.text == "   " then return true end
   if fs.shown and fs.text == "\t" then return true end
  end
  return false
 end
 local function hasText(want)
  for _, fs in ipairs(ui.details) do if fs.shown and fs.text and fs.text:find(want, 1, true) then return true end end
  return false
 end
 addon.DialogueRewards = function(id) if id == 990703 then return { source = "dialogue",
  items = { { id = 801, name = "   ", count = 1 }, { id = 802, name = "\t", count = 1 } }, choices = {} } end end
 addon.QuestRewards = function() return nil end
 addon.CachedQuestRewards = function() return nil end
 local ok, err = pcall(function() ui:Refresh() end)
 assert(ok, "whitespace loot threw in Refresh: " .. tostring(err))
 assert(not blankPainted(), "whitespace-only loot names stay skipped")
 addon.DialogueRewards = function(id) if id == 990703 then return { source = "dialogue",
  items = { { id = 801, name = "   ", count = 1 }, { id = 803, name = "Lone survivor", count = 3 } }, choices = {} } end end
 ok, err = pcall(function() ui:Refresh() end)
 assert(ok, "mixed whitespace loot threw in Refresh: " .. tostring(err))
 assert(not blankPainted(), "whitespace entry stays skipped beside a valid survivor")
 assert(hasText(addon.L("REWARD_ITEM", "Lone survivor", 3)), "valid survivor renders after whitespace loot entries")
 addon.DialogueRewards, addon.QuestRewards, addon.CachedQuestRewards = savedDialogue, savedLog, savedCache
 issecretvalue = savedSecret
 addon.dungeons = savedDungeons
 addon.quests[990703] = nil
 ui.dungeon, ui.quest = dungeon, 990104
 ui.search = ""; ui.questTreeRoot = nil; ui.questTreeDungeon = nil; ui.frame:Show(); ui:Refresh()
end
-- A15 SOURCE-SEARCH-WHITESPACE-GUARD: a whitespace-only member title cannot
-- authorize a source match, mirroring the %S title guard at :1825.
do
 local savedDungeons = addon.dungeons
 local savedGetter = addon.QuestSourceSearchTerms
 local hostileID = {}
 addon.quests[hostileID] = { id = hostileID, name = "   " }
 local hostileDungeon = { key = "whitespace-search", name = "Whitespace search dungeon", minLevel = 1, maxLevel = 80, quests = { hostileID } }
 addon.QuestSourceSearchTerms = function(quest)
  if quest and quest.id == hostileID then
   return { { kind = "npc", text = "zzzqqq whitespace match" } }, function() return true end, function() return true end
  end
  return savedGetter(quest)
 end
 addon.dungeons = { hostileDungeon }
 local function shownCards()
  local count = 0
  for _, card in ipairs(ui.cards) do if card:IsShown() then count = count + 1 end end
  return count
 end
 ui.search = "zzzqqq"; ui.questTreeRoot = nil; ui.questTreeDungeon = nil; ui.includeUnavailable = true; ui.frame:Show()
 local ok, err = pcall(function() ui:RefreshDungeons() end)
 addon.dungeons = savedDungeons
 addon.quests[hostileID] = nil
 addon.QuestSourceSearchTerms = savedGetter
 assert(ok, "whitespace source title threw in RefreshDungeons: " .. tostring(err))
 assert(shownCards() == 0, "whitespace source title publishes no card")
 ui.search = ""; ui.frame:Show(); ui:RefreshDungeons()
 assert(shownCards() > 0, "valid catalogue restores dungeon cards")
end
-- A17 TOOLTIP-ZONE-CAPS: overlong or blank zone names never reach the giver
-- tooltip, mirroring the 500-char detail-row caps at :4512-4515/:4546-4549;
-- a valid zone still paints.
do
 local savedStart=addon.quests[990101].start
 local savedArea=addon.SourceAreaName
 local function giverTip()
  ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.dungeon=dungeon;ui.quest=990101;ui.frame:Show();ui:Refresh()
  tip.shown=false;tip.owner=nil;tip.title=nil;tip.body=nil
  local ok,err=pcall(ui.giver.scripts.OnEnter)
  assert(ok,"giver tooltip threw: "..tostring(err))
  assert(tip.shown and tip.owner==ui.giver and tip.body,"giver tooltip stays owned without a crash")
  return tip.body
 end
 addon.quests[990101].start={npcID=1,name="Own distant giver",mapID=1453,x=10,y=20,zoneName="   "}
 local body=giverTip()
 assert(body:find("Own distant giver",1,true),"blank zone keeps the giver name")
 assert(not body:find("   ",1,true),"blank zone stays unpainted")
 addon.quests[990101].start={npcID=1,name="Own distant giver",mapID=1453,x=10,y=20,zoneName=("z"):rep(10240)}
 body=giverTip()
 assert(body:find("Own distant giver",1,true),"overlong zone keeps the giver name")
 assert(not body:find(("z"):rep(100),1,true),"overlong zone stays unpainted")
 addon.SourceAreaName=function(name,owner) if owner and not owner() then return nil end; return ("n"):rep(10240) end
 addon.quests[990101].start={npcID=1,name="Own distant giver",mapID=1453,x=10,y=20,zoneName="Stormwind City"}
 body=giverTip()
 assert(not body:find(("n"):rep(100),1,true),"overlong area label stays unpainted")
 assert(body:find("Stormwind City",1,true),"overlong area label falls back to the catalogue zone")
 addon.SourceAreaName=savedArea
 addon.quests[990101].start={npcID=1,name="Own distant giver",mapID=1453,x=10,y=20,zoneName="Stormwind City"}
 body=giverTip()
 assert(body:find("Stormwind City",1,true),"valid zone keeps its tooltip place")
 addon.quests[990101].start=savedStart
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
end
-- A18 ROW-HINT-ZONE-CAPS: QuestRowNavigationHint mirrors the A17 500-char
-- giver-tooltip caps; overlong or blank zone sources never reach the row hint.
do
 local savedStart=addon.quests[990101].start
 local savedArea=addon.SourceAreaName
 local savedMap=C_Map
 local function rowTip()
  ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.dungeon=dungeon;ui.quest=990104;ui.frame:Show();ui:Refresh()
  tip.shown=false;tip.owner=nil;tip.title=nil;tip.body=nil
  local target=row(990101)
  local ok,err=pcall(target.navigationControl.scripts.OnEnter)
  assert(ok,"row hint threw: "..tostring(err))
  assert(tip.shown and tip.owner==target.navigationControl and tip.body,"row hint stays owned without a crash")
  return tip.body
 end
 addon.SourceAreaName=function(canonical,owner) if owner and not owner() then return nil end; return canonical end
 addon.quests[990101].start={npcID=1,name="Own distant giver",mapID=1453,x=10,y=20,zoneName="   ",locationName="Short vale"}
 C_Map=nil
 local body=rowTip()
 assert(body:find("Own distant giver",1,true),"blank canonical keeps the giver name")
 assert(body:find("Short vale",1,true),"blank canonical falls back to the recorded location")
 addon.quests[990101].start={npcID=1,name="Own distant giver",mapID=1453,x=10,y=20,zoneName=("z"):rep(501),locationName=("l"):rep(501)}
 C_Map=nil
 body=rowTip()
 assert(body:find("Own distant giver",1,true),"overlong zone keeps the giver name")
 assert(not body:find(("z"):rep(100),1,true),"overlong canonical stays unpainted")
 assert(not body:find(("l"):rep(100),1,true),"overlong location stays unpainted")
 addon.SourceAreaName=function(canonical,owner) if owner and not owner() then return nil end; return ("n"):rep(501) end
 addon.quests[990101].start={npcID=1,name="Own distant giver",mapID=1453,x=10,y=20,zoneName="Stormwind City"}
 C_Map=nil
 body=rowTip()
 assert(not body:find(("n"):rep(100),1,true),"overlong area label stays unpainted")
 assert(body:find("Stormwind City",1,true),"overlong area label falls back to the catalogue zone")
 addon.SourceAreaName=function(canonical,owner) if owner and not owner() then return nil end; return nil end
 addon.quests[990101].start={npcID=1,name="Own distant giver",mapID=1453,x=10,y=20}
 C_Map={GetMapInfo=function(id) assert(id==1453); return {name=("m"):rep(501)} end}
 body=rowTip()
 assert(body:find("Own distant giver",1,true),"overlong native keeps the giver name")
 assert(not body:find(("m"):rep(100),1,true),"overlong native zone stays unpainted")
 addon.SourceAreaName=savedArea
 C_Map={GetMapInfo=function(id) assert(id==1453); return {name="Stormwind City"} end}
 addon.quests[990101].start={npcID=1,name="Own distant giver",mapID=1453,x=10,y=20,zoneName="Stormwind City"}
 body=rowTip()
 assert(body:find("Stormwind City",1,true),"valid zone keeps its row-hint place")
 addon.quests[990101].start=savedStart
 C_Map=savedMap
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=990104;ui.frame:Show();ui:Refresh()
end
-- A18 ACQUISITION-ZONE-CAPS: StarterAcquisitionHint drop zones mirror the
-- A17 500-char giver-tooltip caps; overlong or blank zone sources fall back
-- to the recorded location or UNKNOWN_PLACE instead of painting.
do
 local savedSource,savedArea=addon.SourceName,addon.SourceAreaName
 local function linesWith(start)
  addon.quests[990801]={id=990801,name="Acquisition bound quest",minLevel=1,requirementsKnown=true,start=start}
  local ok,result=pcall(ui.StarterAcquisitionHint,ui,addon.quests[990801],function()return true end)
  assert(ok,"acquisition hint threw: "..tostring(result))
  assert(result and result.lines,"acquisition hint stays available without a crash")
  return table.concat(result.lines,"\n")
 end
 addon.SourceName=function(point,owner) if owner and not owner() then return nil end; return point.name end
 addon.SourceAreaName=function(canonical,owner) if owner and not owner() then return nil end; return canonical end
 local over=linesWith({itemID=801,name="Bound starter",dropSources={{npcID=9,name="Dropper",zoneName=("z"):rep(501)}}})
 assert(not over:find(("z"):rep(100),1,true),"overlong drop zone stays unpainted")
 assert(over:find(addon.L("UNKNOWN_PLACE"),1,true),"overlong drop zone falls back to unknown place")
 local blank=linesWith({itemID=801,name="Bound starter",dropSources={{npcID=9,name="Dropper",zoneName="   ",locationName="Short vale"}}})
 assert(blank:find("Short vale",1,true),"blank drop zone falls back to the recorded location")
 addon.SourceAreaName=function(canonical,owner) if owner and not owner() then return nil end; return ("n"):rep(501) end
 local native=linesWith({itemID=801,name="Bound starter",dropSources={{npcID=9,name="Dropper",zoneName="Plain vale"}}})
 assert(not native:find(("n"):rep(100),1,true),"overlong area label stays unpainted")
 assert(native:find("Plain vale",1,true),"overlong area label falls back to the catalogue zone")
 addon.SourceAreaName=function(canonical,owner) if owner and not owner() then return nil end; return canonical end
 local valid=linesWith({itemID=801,name="Bound starter",dropSources={{npcID=9,name="Dropper",zoneName="Plain vale"}}})
 assert(valid:find("Plain vale",1,true),"valid drop zone keeps its acquisition place")
 addon.SourceName,addon.SourceAreaName=savedSource,savedArea
 addon.quests[990801]=nil
end
-- A18 ENTRANCE-ZONE-BLANK-GUARD: a blank or overlong catalogue entrance
-- zone falls back to the recorded point name instead of painting an empty or
-- unbounded line; upstream producers already bound names at 500 chars.
do
 local savedEntrances=addon.Entrances
 local savedQuest=ui.quest
 local function entranceBody(point)
  addon.Entrances={Get=function(d)
   if d~=dungeon then return nil end
   return point,function()return true end
  end}
  ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.quest=nil;ui.frame:Show();ui:RefreshDungeons()
  local card
  for _,c in ipairs(ui.cards)do if c:IsShown() and c.entranceDungeon==dungeon then card=c end end
  assert(card and card.entranceBinding,"catalogue card keeps its entrance binding")
  tip.shown=false;tip.owner=nil;tip.title=nil;tip.body=nil
  local ok,err=pcall(ui.CatalogEntranceHint,ui,card)
  assert(ok,"entrance hint threw: "..tostring(err))
  assert(tip.shown and tip.body,"entrance hint stays owned without a crash")
  return tip.body
 end
 local body=entranceBody({mapID=1453,x=30,y=40,zoneName="   ",name="Stone vault mouth"})
 assert(body:find("Stone vault mouth",1,true),"blank entrance zone falls back to the recorded point name")
 body=entranceBody({mapID=1453,x=30,y=40,zoneName="   ",name="   "})
 assert(not body:find("\n",1,true),"blank entrance zone and name paint no empty line")
 body=entranceBody({mapID=1453,x=30,y=40,zoneName=("z"):rep(501),name="Stone vault mouth"})
 assert(body:find("Stone vault mouth",1,true),"overlong entrance zone falls back to the recorded point name")
 assert(not body:find(("z"):rep(100),1,true),"overlong entrance zone paints no unbounded line")
 body=entranceBody({mapID=1453,x=30,y=40,zoneName="Ember vault",name="Stone vault mouth"})
 assert(body:find("Ember vault",1,true),"valid entrance zone keeps its catalogue place")
 addon.Entrances=savedEntrances
 ui.quest=savedQuest
 ui.search="";ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.frame:Show();ui:Refresh()
end
print("Middle quest navigation checks passed (modeled, no native input or layout proof)")
