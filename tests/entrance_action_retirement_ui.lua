-- Entrance validation owns its final native dispatch across sanitizer callbacks.
local total=0
local function fixture(install)
 local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
 issecretvalue=function()return false end;GetLocale=function()return"enUS"end;C_Timer={After=function()end}
 f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true
 local dm,rfc;for _,d in ipairs(a.dungeons)do if d.key=="dm"then dm=d elseif d.key=="rfc"then rfc=d end end
 if install then install(a,u)end
 u.dungeon,u.quest=assert(dm),nil;u:Refresh();local binding=assert(u.entranceBinding)
 assert(binding.current()and binding.point.mapID==1436,"actual recorded DM entrance control")
 local writes,last=0,nil;local set=C_Map.SetUserWaypoint
 C_Map.SetUserWaypoint=function(point)writes=writes+1;last=point;return set(point)end
 return a,u,dm,rfc,binding,function()return writes,last end
end
for _,mode in ipairs({"dungeon","quest","point","helper"})do
 local binding,clean;local reads,fired,armed=0,false,false
 local a,u,dm,rfc,held,count=fixture(function(a,u)
  clean=a.Clean
  a.Clean=function(value,kind)
   local result=clean(value,kind)
   -- The stable cleaner exists before the binding; fire only its own final read.
   if armed and debug.getinfo(2,"f").func==binding.current and kind=="number"and value==binding.point.y then
    reads=reads+1
    if reads==2 then
     fired=true
     if mode=="dungeon"then for _,d in ipairs(a.dungeons)do if d.key=="rfc"then u.dungeon=d end end
     elseif mode=="quest"then u.quest=166
     elseif mode=="point"then binding.point.mapID=1455
     else a.Navigation.StartEntrance=function()error("replaced helper must never dispatch")end end
    end
   end
   return result
  end
 end)
 binding=held;armed=true
 u:VisitEntrance();armed=false;a.Clean=clean
 assert(fired and reads==2,"late final-coordinate callback must actually fire")
 assert(count()==0,"late "..mode.." change dispatched a retired entrance waypoint")
 if mode=="dungeon"then assert(u.dungeon==rfc)elseif mode=="quest"then assert(u.quest==166)end
 total=total+1
end
print("PASS four late coordinate callbacks reject old dungeon,quest,point and helper dispatch")
-- The owner predicate can itself mutate after computing a previously true result.
do
 local a,u,dm,rfc,_,count=fixture();local armed,fired=false,false;local calls=0
 local function owner()
  local valid=u.dungeon==dm
  if armed then calls=calls+1;if calls==2 then fired=true;u.dungeon=rfc end end
  return valid
 end
 local binding=assert(u:GetEntranceBinding(dm,owner));u.entranceBinding=binding;armed=true
 u:VisitEntrance();armed=false
 assert(fired and u.dungeon==rfc and count()==0,"owner old-true return cannot authorize a stale native route")
 total=total+1
end
print("PASS final owner callback has a raw UI tail")
-- Catalogue entrance controls may legitimately outlive a change in selected detail dungeon.
do
 local a,u,dm,rfc,_,count=fixture();local card
 for _,row in ipairs(u.cards)do if row:IsShown()and row.entranceDungeon==dm then card=row end end
 assert(card and card.entranceBinding);local binding=card.entranceBinding
 u.dungeon,u.quest=rfc,nil;u:RefreshQuests();u:RefreshDetail()
 assert(card.entranceBinding==binding and binding.current(),"per-binding selection freeze would break a valid catalogue control")
 card.entranceControl.scripts.OnClick();local writes,point=count()
 assert(writes==1 and point.mapID==1436,"explicit valid catalogue entrance dispatch preserves its real dungeon")
 total=total+1
end
print("PASS legitimate retained catalogue entrance works after detail selection changes")
-- Valid overview dispatch and unknown recorded entrances keep their existing behavior.
do
 local a,u,dm,rfc,binding,count=fixture();assert(u:VisitEntrance());local writes,point=count()
 assert(writes==1 and point.mapID==1436)
 a.Navigation.Stop()
 local unknown;for _,d in ipairs(a.dungeons)do if not d.entrance and not a.Entrances.Get(d)then unknown=d;break end end
 assert(unknown,"an actual unknown entrance is required for this control")
 u.dungeon,u.quest=unknown,nil;u:Refresh();assert(not u.entranceBinding and not u:VisitEntrance())
 assert(count()==writes,"unknown source positions cannot become waypoints")
 total=total+1
end
print("PASS valid overview and unknown entrance policies remain distinct")
-- A modeled raw comparison failure must not escape direct binding callers.
-- This trap verifies containment; it does not simulate native secret values.
do
 local binding,clean;local checking,coordinateSeen=false,false
 local a,u,dm,rfc,held,count=fixture(function(a)
  clean=a.Clean
  a.Clean=function(value,kind)
   local result=clean(value,kind)
   if checking and debug.getinfo(2,"f").func==binding.current and kind=="number"and value==binding.point.y then coordinateSeen=true end
   return result
  end
 end)
 binding=held;local equal=rawequal;local fired=false
 rawequal=function(left,right)
  if coordinateSeen and left==binding.point.mapID and right==binding.point.mapID then fired=true;error("modeled raw comparison failure")end
  return equal(left,right)
 end
 checking=true;local ok,fresh=pcall(binding.current);checking=false;rawequal=equal;a.Clean=clean
 assert(coordinateSeen and fired and ok and fresh==false and count()==0,"post-sanitizer raw failure must return false without throwing or dispatching")
 total=total+1
end
print("PASS modeled post-sanitizer raw comparison failures stay inside the binding proof")
print("Entrance action retirement UI: PASS "..total.." groups; native-shaped effects only")
