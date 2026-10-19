local total=0
local function check(name,fn)fn();total=total+1;print('PASS '..name)end
local function run(oldID,newID,phase,mode)
 local f=assert(loadfile('tests/client_ui.lua'))('fixture');local a,u,e=f.addon,f.addon.UI,f.eventFrame
 issecretvalue=function()return false end;GetLocale=function()return'enUS'end;C_Timer={After=function()end}
 UnitGUID=function()return'Player-nav25'end;UnitLevel=function()return 60 end;UnitClass=function()return'Mage','MAGE',8 end;UnitFactionGroup=function()return'Alliance'end
 C_QuestLog.IsOnQuest=function()return false end;C_QuestLog.ReadyForTurnIn=function()return false end
 C_QuestLog.GetTitleForQuestID=function(id)return a.quests[id]and a.quests[id].name end
 local pin,sets,clears,getters,armed,fired,newPin=nil,0,0,0,false,false,nil
 local foreign={uiMapID=1436,position={x=.12,y=.34}}
 TomTom=nil
 C_Map.GetUserWaypoint=function()getters=getters+1;if phase=='dispatch'and getters==2 then armed=true end;return pin end
 C_Map.SetUserWaypoint=function(value)sets=sets+1;pin=value;if phase=='assignment'then armed=true end;return true end
 C_Map.ClearUserWaypoint=function()clears=clears+1;pin=nil end
 C_Map.CanSetUserWaypointOnMap=function()if phase=='constructor'then armed=true end;return true end
 UiMapPoint.CreateFromCoordinates=function(map,x,y)return{uiMapID=map,position={x=x,y=y}}end
 C_Map.OpenWorldMap=function()end
 local oldPoint=a.quests[oldID].start
 local clean=a.Clean
 a.Clean=function(value,kind)
  local result=clean(value,kind)
  if armed and not fired and kind=='number'and value==oldPoint.y then
   fired=true;armed=false
   if mode=='new'then
    -- Model the pending native point disappearing before a replacement placement.
    if phase=='assignment'then C_Map.ClearUserWaypoint()end
    assert(u:InspectQuest(newID,true));assert(u:SetDetailTab('sources'));local action=assert(u.giverAction)
    assert(a.Navigation.Start(action),'new real giver guide positively starts');newPin=pin
    assert(newPin and newPin.uiMapID==action.place.mapID and newPin.position.x==action.place.x/100)
   elseif mode=='manual'then a.Navigation.Stop();pin=foreign
   elseif mode=='cancel'then a.Navigation.Stop()
   elseif mode=='setter'then C_Map.SetUserWaypoint=function()error('unproven replacement setter cannot run')end
   elseif mode=='clean'then a.Clean=clean end
  end
  return result
 end
 e.scripts.OnEvent(e,'ADDON_LOADED','DungeonPro');u:Toggle();u.includeUnavailable=true;u.range=false
 for _,card in ipairs(u.cards)do if card.entranceDungeon and card.entranceDungeon.key=='dm'then card.scripts.OnClick(card);break end end
 assert(u:InspectQuest(oldID,true));assert(u:SetDetailTab('sources'));local oldAction=assert(u.giverAction)
 getters,armed=0,false
 local accepted=a.Navigation.Start(oldAction)
 assert(fired,'late capability callback must fire')
 if mode=='new'then
  assert(not accepted and pin==newPin and u.quest==newID,'old request must preserve newer positive waypoint')
  a.Navigation.QuestChanged(oldID);assert(pin==newPin,'old quest event cannot retire newer guide')
  a.Navigation.QuestChanged(newID);assert(pin==nil,'newest guide retains exact cleanup ownership')
 elseif mode=='manual'then assert(not accepted and pin==foreign,'manual pin survives stale resolution');a.Navigation.Stop();assert(pin==foreign)
 elseif mode=='cancel'then assert(not accepted and pin==nil and sets==0,'cancellation prevents stale native dispatch')
 else assert(sets==0,'helper drift prevents native dispatch')end
 return sets,clears
end
for _,phase in ipairs({'constructor','dispatch','assignment'})do
 for _,ids in ipairs({{166,214},{214,166}})do check(phase..' real'..ids[1]..' to '..ids[2],function()run(ids[1],ids[2],phase,'new')end)end
end
for _,mode in ipairs({'manual','cancel','setter','clean'})do
 check('final dispatch '..mode,function()run(166,214,'dispatch',mode)end)
end
print('Navigation resolution lifecycle: '..total..' PASS; actual catalogue endpoints, controlled native callbacks, no game runtime claim')

check("raw capability tail cannot invoke inherited native getter",function()
local f=assert(loadfile('tests/client_ui.lua'))('fixture');local a,u,e=f.addon,f.addon.UI,f.eventFrame
issecretvalue=function()return false end;GetLocale=function()return'enUS'end;C_Timer={After=function()end}
UnitGUID=function()return'Player-nav25'end;UnitLevel=function()return 60 end;UnitClass=function()return'Mage','MAGE',8 end;UnitFactionGroup=function()return'Alliance'end
C_QuestLog.IsOnQuest=function()return false end;C_QuestLog.ReadyForTurnIn=function()return false end
C_QuestLog.GetTitleForQuestID=function(id)return a.quests[id]and a.quests[id].name end
local pin,sets,clears,getters,stage,fired,newPin=nil,0,0,0,false,false,nil
TomTom=nil
C_Map.GetUserWaypoint=function()getters=getters+1;if getters==2 then stage=true end;return pin end
C_Map.SetUserWaypoint=function(value)sets=sets+1;pin=value;return true end
C_Map.ClearUserWaypoint=function()clears=clears+1;pin=nil end
C_Map.CanSetUserWaypointOnMap=function()return true end
UiMapPoint.CreateFromCoordinates=function(map,x,y)return{uiMapID=map,position={x=x,y=y}}end
C_Map.OpenWorldMap=function()end
local oldPoint=a.quests[166].start
local entered=false;local savedGetter
local clean=a.Clean
a.Clean=function(value,kind)
 local result=clean(value,kind)
 if stage and not fired and kind=='number'and value==oldPoint.y then
  fired=true;stage=false
  local library=C_Map;local originalGetter=library.GetUserWaypoint;savedGetter=originalGetter
  rawset(library,'GetUserWaypoint',nil)
  setmetatable(library,{__index=function(_,key)
   if key=='GetUserWaypoint'then
    if not entered then
     entered=true
     assert(u:InspectQuest(214,true));assert(u:SetDetailTab('sources'));local action=assert(u.giverAction)
     assert(a.Navigation.Start(action),'new real214guide positively starts');newPin=pin
     assert(newPin and newPin.uiMapID==action.place.mapID)
    end
    return originalGetter
   end
  end})
 end
 return result
end
e.scripts.OnEvent(e,'ADDON_LOADED','DungeonPro');u:Toggle();u.includeUnavailable=true;u.range=false
for _,card in ipairs(u.cards)do if card.entranceDungeon and card.entranceDungeon.key=='dm'then card.scripts.OnClick(card);break end end
assert(u:InspectQuest(166,true));assert(u:SetDetailTab('sources'));local oldAction=assert(u.giverAction)
getters,stage=0,false
local accepted=a.Navigation.Start(oldAction)

assert(fired,'final coordinate sanitizer must fire')
if entered then
 assert(newPin and u.quest==214)
 assert(not accepted and pin==newPin,'metatable callback cannot allow stale setter over newer guide')
else
 assert(sets==0,'missing native raw capability must not dispatch through inherited method')
end
-- A rejected inherited capability does not poison later explicit ordinary navigation.
local library=C_Map;local getter=assert(savedGetter)
setmetatable(library,nil);rawset(library,'GetUserWaypoint',getter)
a.Navigation.Stop();pin=nil
assert(u:InspectQuest(214,true));assert(u:SetDetailTab('sources'));assert(a.Navigation.Start(u.giverAction))
assert(pin and pin.position.x==a.quests[214].start.x/100)
a.Navigation.QuestChanged(214);assert(pin==nil)
-- The permission capability remains optional; absent waypoint readback remains conservative.
C_Map.CanSetUserWaypointOnMap=nil
assert(a.Navigation.Start(u.giverAction)and pin,'missing optional permission retains native placement')
a.Navigation.Stop();assert(pin==nil)
local beforeSets=sets;C_Map.GetUserWaypoint=nil
assert(a.Navigation.Start(u.giverAction)and pin==nil and sets==beforeSets,'missing readback keeps internal guide without native ownership')
a.Navigation.Stop()

end)
print("Navigation resolution v2: "..total.." PASS")
