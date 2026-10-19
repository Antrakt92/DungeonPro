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
local weak=setmetatable({},{__mode="v"})
draw(6981);weak.old=u.engine
local retained=assert(u.details[9].detailTextBinding)
local originalCurrent,oldReads=u.engine.Current,0
u.engine.Current=function(...)oldReads=oldReads+1;return originalCurrent(...)end
local hovered
for _,b in ipairs(u.objectiveButtons)do if b:IsShown()and b.objectiveBinding then hovered=b;break end end
assert(hovered and hovered.scripts.OnEnter);hovered.scripts.OnEnter();assert(tooltip.shown)
hovered.scripts.OnLeave();assert(not tooltip.shown);drain()
assert(u:SetDetailTab("sources"));drain();assert(u:SetDetailTab("story"));drain();gc()
assert(weak.old==u.engine,"tab changes deliberately keep the current list engine")
assert(u:InspectQuest(1491,true));drain();assert(u.engine~=weak.old,"ordinary row inspection publishes a fresh middle-list engine")
held[1491]=true;event.scripts.OnEvent(event,"QUEST_ACCEPTED",1,1491);drain()
assert(u.engine~=weak.old and u.quest==1491,"accepted event publishes a fresh current engine")
originalCurrent=nil
local priorReads=oldReads
assert(retained.current()==false and oldReads==priorReads,"retired text proof must stop before its former owner")
gc()
assert(weak.old==nil,"settled quest/tab/hover context must not retain its superseded engine")
weak.second=u.engine;held[1491]=nil;event.scripts.OnEvent(event,"QUEST_REMOVED",1491);drain();gc()
assert(weak.second==nil,"removed-event refresh releases the former held-quest engine")
u.frame:Hide();u.frame.scripts.OnHide();drain();u.frame:Show();u:Refresh();drain()
assert(u.quest==1491 and u.engine:State(1491).status~="ACTIVE")
-- Stored physical records remain usable for latest native SetText-tail repair.
for _,phase in ipairs({"before","after"})do
 for _,transition in ipairs({"quest","reopen","locale"})do
  draw(6981)
  local target=assert(u.details[1]);local native=target.SetText;local fired=false
  local function replace()
   if fired then return end;fired=true
   if transition=="reopen"then u.frame:Hide();u.frame.scripts.OnHide();u.frame:Show()end
   if transition=="locale"then a.db.locale="ruRU"end
   assert(u:InspectQuest(1491,true))
  end
  target.SetText=function(self,value)
   if phase=="before"then replace()end
   local result=native(self,value)
   if phase=="after"then replace()end
   return result
  end
  u:RefreshDetail();target.SetText=native;drain()
  assert(fired and u.quest==1491 and u.renderedQuest==1491,"retired text callback must preserve latest quest")
  local binding=assert(target.detailTextBinding)
  assert(binding.current() and binding.engine==u.engine and target.text==binding.value,
   "late native SetText must preserve the latest binding and displayed text")
  a.db.locale="enUS"
 end
end
-- Entry cleanup may itself reopen and paint a newer detail.
draw(6981)
local sync=u.SyncDungeonMapContext;local fired=false;local newest
u.SyncDungeonMapContext=function(self)
 if not fired then fired=true;assert(self:InspectQuest(1491,true));newest=self.detailTextLease end
 return sync(self)
end
u:RefreshDetail();u.SyncDungeonMapContext=sync;drain()
assert(fired and u.quest==1491 and u.renderedQuest==1491 and newest and u.detailTextLease==newest and not newest.released,
 "reentrant entry cleanup must not orphan the newer text lease")
local live=assert(u.details[1].detailTextBinding);assert(live.current())
u.frame:Hide();u.frame.scripts.OnHide();assert(live.current()==false and live.engine==nil,
 "ordinary owned hide releases text guards and direct engine references")
print("Detail text retention: PASS (settled queued events/tabs/hover, GC, retired proofs, six native tails and entry reentry)")
