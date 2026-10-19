-- A pooled overview map control must retire only its obsolete render lease.
local override=...
local loader=loadfile
if override then loadfile=function(path)return loader(path=="UI/Window.lua"and override or path)end end
local f=assert(loader("tests/client_ui.lua"))("fixture");loadfile=loader
local a,u=f.addon,f.addon.UI
-- Controlled component opt-in; not native map availability.
a.experimentalDungeonMaps=true
issecretvalue=function()return false end
C_Timer={After=function()end}
GetLocale=function()return "enUS"end
UnitGUID=function()return "Player-map-retention"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro")
u:Toggle();a.db.locale="enUS"
local dm;for _,d in ipairs(a.dungeons)do if d.key=="dm"then dm=d end end;assert(dm)
local token={}
a.Context=function()
 local own=token
 return{level=60,class="MAGE",faction="Alliance",race=3,current=function()return own==token end,
 active=function()return false end,ready=function()return false end,completed=function()return false end}
end
local function overview()
 token={};u.dungeon,u.quest=dm,nil;u:Refresh()
 local b=u.overviewMapBinding;local current=u.overviewMapControl.questListWrites.ClearAllPoints.current
 assert(b and current()and u.overviewMapControl:IsShown())
 return current
end
local old=overview();local control=u.overviewMapControl;local click=control.scripts.OnClick
local weak=setmetatable({u.engine},{__mode="v"})
u:InspectQuest(166,true);u:Refresh();collectgarbage("collect");collectgarbage("collect")
assert(not old()and not control:IsShown(),"the obsolete map binding is callable and retired")
assert(weak[1]==nil,"leaving the overview must release its old map-control render engine")
local opener=u.OpenDungeonMap;local calls=0
u.OpenDungeonMap=function(self,d)
 calls=calls+1;assert(self==u and d==dm,"only the exact selected dungeon may open")
 return true
end
local current=overview();local physical=u.overviewMapControl
local alive=setmetatable({u.engine},{__mode="v"});collectgarbage("collect");assert(alive[1]and current())
assert(calls==0,"rendering and GC cannot open native map artwork")
physical.scripts.OnClick();assert(calls==1)
click();assert(calls==1,"retained old map callback cannot open over a later render")
local live=u.overviewMapBinding;local ownerCalls=0;local owner=live.owner
assert(type(owner)=="function","map render context must be held in a releasable lease")
live.owner=function()ownerCalls=ownerCalls+1;return owner()end
u:InspectQuest(166,true)
ownerCalls=0;assert(not current()and ownerCalls==0 and live.released and live.owner==nil)
for _,phase in ipairs({"before","after"})do
 a.db.locale="enUS";overview()
 local fs=physical.filterCaption;local native=fs.SetText;local fired=false
 fs.SetText=function(self,value)
  if phase=="after"then native(self,value)end
  if not fired then fired=true;a.db.locale="ruRU";overview()end
  if phase=="before"then native(self,value)end
 end
 u:RefreshDetail();fs.SetText=native
 assert(fired and fs.text==a.L("DUNGEON_MAP_OPEN"),"late native map caption must preserve the newer locale")
 assert(u.overviewMapControl==physical and physical:IsShown())
end
for _,phase in ipairs({"before","after"})do
 overview();local native=physical.Show;local fired=false
 physical.Show=function(self,...)
  if phase=="after"then native(self,...)end
  if not fired then fired=true;u:InspectQuest(166,true)end
  if phase=="before"then native(self,...)end
 end
 u:RefreshDetail();physical.Show=native
 assert(fired and u.quest==166 and not physical:IsShown()and not physical.enabled,
 "late native overview Show cannot revive an obsolete map action")
end
for _,phase in ipairs({"before","after"})do
 overview();local native=physical.SetPoint;local fired=false;local latest
 physical.SetPoint=function(self,...)
  if phase=="after"then native(self,...)end
  if not fired then
   fired=true;a.db.locale="enUS";overview();latest={unpack(self.point)}
  end
  if phase=="before"then native(self,...)end
 end
 u:RefreshDetail();physical.SetPoint=native
 assert(fired and latest and #latest==#physical.point)
 for index,value in ipairs(latest)do assert(physical.point[index]==value,"newest map geometry must survive an old native tail")end
end
local prior=overview();local retained=physical.scripts.OnClick;local before=calls
u.frame:Hide();u.frame.scripts.OnHide();assert(not prior()and u.overviewMapBinding==nil)
retained();assert(calls==before)
u.frame:Show();overview();physical.scripts.OnClick();assert(calls==before+1,"fresh warmed control remains usable after hide/show")
local close=u.CloseDungeonMap;local fired=false
u.CloseDungeonMap=function(self,...)
 local result=close(self,...)
 if not fired then fired=true;self.frame:Show();overview()end
 return result
end
u.frame:Hide();u.frame.scripts.OnHide();u.CloseDungeonMap=close
assert(fired and u.overviewMapBinding and physical:IsShown())
physical.scripts.OnClick();assert(calls==before+2,"old hide cleanup cannot retire the reopened overview")
u.OpenDungeonMap=opener
print("Overview map retention: PASS (GC/current owner, exact explicit dispatch, six native tails and hide/reopen ownership)")
