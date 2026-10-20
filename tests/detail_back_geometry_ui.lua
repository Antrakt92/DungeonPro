local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u,event=f.addon,f.addon.UI,f.eventFrame
local queue,clock,tasks={},0,0
C_Timer={After=function(delay,fn)queue[#queue+1]={at=clock+delay,fn=fn}end}
GetTime=function()return clock end
issecretvalue=function()return false end;GetLocale=function()return "enUS"end
UnitGUID=function()return "Player-detail-memory"end
UnitLevel=function()return 60 end;UnitClass=function()return "Mage","MAGE",8 end
UnitFactionGroup=function()return "Alliance"end
local held,ready={},{}
C_QuestLog.IsOnQuest=function(id)return held[id]==true end
C_QuestLog.ReadyForTurnIn=function(id)return ready[id]==true end
C_QuestLog.IsQuestFlaggedCompleted=function()return false end
C_QuestLog.GetTitleForQuestID=function(id)return a.quests[id]and a.quests[id].name end
HaveQuestRewardData=function()return true end;GetNumQuestLogRewards=function()return 0 end;GetNumQuestLogChoices=function()return 0 end
GetQuestLogRewardMoney=function()return 0 end
C_Item={GetItemNameByID=function(id)return "Item "..id end,GetItemIconByID=function()return 134400 end,
 GetItemCount=function()return 4 end,IsItemDataCachedByID=function()return true end}
local tooltip={}
function tooltip:SetOwner(owner)self.owner=owner end
function tooltip:IsOwned(owner)return self.owner==owner end
function tooltip:SetItemByID(id)self.id=id;self.shown=true;return true end
function tooltip:AddLine(text)self.context=text end
function tooltip:Show()self.shown=true end
function tooltip:Hide()self.shown=false end
GameTooltip=tooltip
local function drain()
 while #queue>0 do
  tasks=tasks+1;assert(tasks<2500,"queued work must settle before GC classification")
  table.sort(queue,function(x,y)return x.at<y.at end)
  local t=table.remove(queue,1);clock=t.at;t.fn()
 end
end
local function gc()collectgarbage("collect");collectgarbage("collect")end
local owners={};for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=d end end
event.scripts.OnEvent(event,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true;drain()
local function draw(id)
 u.dungeon,u.quest=assert(owners[id]),id;u:Refresh();drain();assert(u.renderedQuest==id)
end



local routes=0;C_Map.SetUserWaypoint=function()routes=routes+1 end
draw(166);local b=assert(u.detailBackButton,"legacy pooled control may remain only as retired storage")
assert(not b:IsShown()and not b.enabled and b.scripts.OnClick==nil)
local geometryWrites=0;local clear,set=b.ClearAllPoints,b.SetPoint
b.ClearAllPoints=function(self,...)geometryWrites=geometryWrites+1;return clear(self,...)end
b.SetPoint=function(self,...)geometryWrites=geometryWrites+1;return set(self,...)end
for _,key in ipairs({"quest","sources","story"})do
 assert(u:SetDetailTab(key));draw(166);assert(u:InspectQuest(214,true));drain();assert(u:BackQuest());drain()
 assert(u.quest==166 and u.detailTab=="quest"and not b:IsShown()and not b.enabled and b.scripts.OnClick==nil)
end
assert(geometryWrites==0,"retired Back has no geometry callbacks for an old writer to resume")
b.ClearAllPoints,b.SetPoint=clear,set
-- Native scroll-tail reentry is still an active physical boundary of BackQuest.
u.detailScroll.GetHeight=function()return 100 end
u.detail.GetHeight=function()return 1000 end
for _,phase in ipairs({"before","after"})do
 draw(166);u.detailScroll:SetVerticalScroll(73);assert(u:InspectQuest(214,true));drain()
 local native=u.detailScroll.SetVerticalScroll;local armed,fired=false,false
 u.detailScroll.SetVerticalScroll=function(self,value)
  local hit=armed and not fired and value==73
  local function replace()
   fired=true;assert(u:InspectQuest(166,true));drain()
   local scroll,generation,engine=u.detailScroll,u.rewardGeneration,u.engine
   u:WriteDetailScroll(scroll,19,function()return u.quest==166 and u.detailScroll==scroll and u.rewardGeneration==generation and u.engine==engine end)
  end
  if hit and phase=="before"then replace()end
  local result=native(self,value)
  if hit and phase=="after"then replace()end
  return result
 end
 armed=true;assert(u:BackQuest());drain();u.detailScroll.SetVerticalScroll=native
 assert(fired and u.quest==166 and u.detailScroll:GetVerticalScroll()==19,"old Back scroll tail cannot overwrite newer physical reading position "..phase)
end
-- The retired button must retain no obsolete render engine through a repair lease.
draw(166);local weak=setmetatable({engine=u.engine,context=u.engine.context},{__mode="v"})
assert(u:InspectQuest(214,true));drain();gc()
assert(weak.engine==nil and weak.context==nil,"retired Back storage must not retain old engine/context")
assert(not b:IsShown()and not b.enabled and b.scripts.OnClick==nil and routes==0 and #queue==0)
print("PASS no retired Back geometry writes; retained API physical scroll tails before/after, old engine/contextGC, no waypoints")
