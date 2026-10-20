-- Actual Client and queued Events retire the distinct inline turn-in geometry owner.
local cases=0
local function fixture()
 local f=assert(loadfile("tests/client_ui.lua"))("fixture")
 local a,u,e=f.addon,f.addon.UI,f.eventFrame
 local held,ready,queue,visits={},{},{},{}
 issecretvalue=function()return false end;GetLocale=function()return "enUS"end
 UnitLevel=function()return 60 end;UnitClass=function()return "Mage","MAGE",8 end
 UnitFactionGroup=function()return "Horde"end
 C_QuestLog.IsOnQuest=function(id)return held[id]==true end
 C_QuestLog.ReadyForTurnIn=function(id)return ready[id]==true end
 C_QuestLog.IsQuestFlaggedCompleted=function()return false end
 C_Timer={After=function(delay,callback)if delay==0.1 then queue[#queue+1]=callback end end}
 a.Navigation.Start=function(action)visits[#visits+1]=action;return true end
 e.scripts.OnEvent(e,"ADDON_LOADED","DungeonPro");u:Toggle()
 local dungeon;for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do if id==5724 then dungeon=d end end end
 assert(dungeon)
 local function drain()while #queue>0 do local q=queue;queue={};for _,fn in ipairs(q)do fn()end end end
 held[5724],ready[5724]=true,true;e.scripts.OnEvent(e,"QUEST_ACCEPTED",5724);drain()
 u.dungeon,u.quest,u.includeUnavailable,u.range=dungeon,5724,true,false;u:Refresh();drain()
 assert(u.engine:State(5724).status=="READY"and u.turnin:IsShown()and u.turnin.enabled)
 return a,u,e,held,ready,drain,visits,function()return #queue end
end
do
 local a,u,e,held,ready,drain,visits,queued=fixture()
 local control=u.turnin;control.scripts.OnClick()
 assert(#visits==1 and visits[1].kind=="turnin"and visits[1].place==a.quests[5724].finish)
 local click=control.scripts.OnClick;local registry=control.questListWrites;local record=assert(registry.SetPoint)
 local weak=setmetatable({u.engine},{__mode="v"})
 held[5724],ready[5724]=nil,nil;e.scripts.OnEvent(e,"QUEST_REMOVED",5724)
 assert(queued()==1,"a real removal event queues exactly one refresh")
 assert(u:InspectQuest(6981,true));drain();u.frame:Hide();u.frame.scripts.OnHide(u.frame);u.frame:Show();u:Refresh();drain()
 assert(u.quest==6981 and not control:IsShown()and not control.enabled and not u.turninBinding)
 -- The caller drops its intentionally retained stale click after proving it inert; only UI-owned native records remain.
 click();assert(#visits==1);click=nil
 assert(queued()==0,"native notifications are settled before the retention check")
 collectgarbage("collect");collectgarbage("collect")
 assert(weak[1]==nil,"retired inline turn-in geometry must not retain the previous engine")
 assert(control.questListWrites==registry and registry.SetPoint==record)
 local original,reads=a.Clean,0;a.Clean=function(...)reads=reads+1;return original(...)end
 assert(not record.current());assert(reads==0 and #visits==1,"retired native owner and click cannot read providers or guide")
 a.Clean=original;cases=cases+1
end
for _,target in ipairs({6981,6402})do for _,method in ipairs({"ClearAllPoints","SetPoint","SetSize","Show"})do for _,phase in ipairs({"before","after"})do
 local a,u,e,held,ready,drain,visits=fixture()
 local control=u.turnin;local setter,fired,completed=control[method],false,false
 local newerPoint,newerBinding,newerClick
 local function replace()
  fired=true;held[6402],ready[6402]=true,true
  assert(u:InspectQuest(target,true));if target==6981 then assert(u:SetDetailTab("sources"))end
  newerPoint,newerBinding,newerClick=control.point,u.turninBinding,control.scripts.OnClick;completed=true
 end
 control[method]=function(self,...)
  local hit=not fired
  if hit and phase=="before"then replace()end
  local result=setter(self,...)
  if hit and phase=="after"then replace()end
  return result
 end
 u:RefreshDetail();control[method]=setter
 assert(fired and completed and u.quest==target and #visits==0)
 if target==6981 then
  assert(u.detailTab=="quest"and not control:IsShown()and not control.enabled and not u.turninBinding,
   "retired inline native tail cannot revive turn-in over item source details")
 else
  assert(control:IsShown()and control.enabled and u.turninBinding==newerBinding and control.scripts.OnClick==newerClick)
  for i,value in ipairs(newerPoint)do assert(control.point[i]==value,"new turn-in geometry remains current")end
  newerClick();assert(#visits==1 and visits[1].id==6402 and visits[1].place==a.quests[6402].finish)
 end
 cases=cases+1
end end end
print("PASS inline turn-in release: "..cases.." actual READY/queued removal/GC/provider and native before-after/new-endpoint cases")
