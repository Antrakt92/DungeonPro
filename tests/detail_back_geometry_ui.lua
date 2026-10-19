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


local routes=0
C_Map.SetUserWaypoint=function()routes=routes+1 end
local function equal(x,y)
 if type(x)~='table' or type(y)~='table' then return false end
 for k,v in pairs(x)do if y[k]~=v then return false end end
 for k,v in pairs(y)do if x[k]~=v then return false end end
 return true
end
for _,tab in ipairs({'sources','story'})do for _,phase in ipairs({'before','after'})do
 draw(166);assert(u:SetDetailTab('sources'));drain()
 local b=u.detailBackButton;local native=b.ClearAllPoints;local fired,newPoint=false,nil
 b.ClearAllPoints=function(self,...)
  local hit=not fired
  local function newer()
   fired=true;assert(u:InspectQuest(214,true));assert(u:SetDetailTab(tab));drain()
   assert(u.quest==214 and u.detailBackBinding.current() and b:IsShown() and b.enabled)
   assert(type(b.point)=='table','newer Back positively anchored')
   newPoint={unpack(b.point)}
  end
  if hit and phase=='before'then newer()end
  self.point=nil -- modeled native ClearAllPoints has a physical effect, including delayed tails
  if hit and phase=='after'then newer()end
 end
 u:RefreshDetail();drain();b.ClearAllPoints=native
 assert(fired and newPoint,'native reentry fired')
 assert(u.quest==214 and u.detailTab==tab and u.detailBackBinding.current())
 assert(equal(b.point,newPoint),'older ClearAllPoints erased newer Back anchor '..tab..'/'..phase)
 assert(b:IsShown()and b.enabled)
 b.scripts.OnClick(b);drain();assert(u.quest==166 and u.detailTab=='sources','fresh Back remains exact inspection')
 print('PASS BackClear',tab,phase)
end end
assert(routes==0)
print('PASS geometry32 no automatic waypoint')

-- Replacing the physical pooled control retires the older writer before it can repair another widget.
draw(166);assert(u:SetDetailTab('sources'));drain()
local old=u.detailBackButton;local native=old.ClearAllPoints;local fired=false;local replacement,newPoint
old.ClearAllPoints=function(self,...)
 if not fired then
  fired=true
  replacement=CreateFrame('Button',nil,u.detail,'UIPanelButtonTemplate')
  replacement.label=replacement:CreateFontString(nil,'OVERLAY');replacement.footerLabelKey='BACK'
  u.detailBackButton=replacement
  assert(u:InspectQuest(214,true));assert(u:SetDetailTab('sources'));drain()
  assert(replacement:IsShown()and replacement.enabled and replacement.point)
  newPoint={unpack(replacement.point)}
 end
 self.point=nil
end
u:RefreshDetail();drain();old.ClearAllPoints=native
assert(fired and u.detailBackButton==replacement and equal(replacement.point,newPoint))
assert(u.detailBackBinding.current());replacement.scripts.OnClick();drain();assert(u.quest==166)
print('PASS physical replacement retains positively anchored current Back')
-- A repaired SetPoint record is retained by its physical registry but not by the obsolete engine.
draw(166);assert(u:SetDetailTab('sources'));drain()
local b=u.detailBackButton;local clear=b.ClearAllPoints;local fired=false;local repaired
local weak=setmetatable({},{__mode='v'})
b.ClearAllPoints=function(self,...)
 if not fired then
  fired=true;assert(u:InspectQuest(214,true));assert(u:SetDetailTab('story'));drain()
  weak.engine=u.engine;weak.context=u.engine.context
 end
 self.point=nil
end
u:RefreshDetail();drain();b.ClearAllPoints=clear
repaired=assert(b.questListWrites.SetPoint);assert(repaired.current())
assert(u:InspectQuest(166,true));drain();gc()
local read,clean,calls=a.Read,a.Clean,0
a.Read=function(...)calls=calls+1;return read(...)end
a.Clean=function(...)calls=calls+1;return clean(...)end
assert(not repaired.current()and calls==0)
a.Read,a.Clean=read,clean
gc();assert(weak.engine==nil and weak.context==nil,'retained repaired record must release old engine/context')
assert(b==u.detailBackButton and b:IsShown()and b.point and u.detailBackBinding.current())
assert(routes==0 and #queue==0)
print('PASS repaired record retired0providers/engine-contextGC; queue0 tasks'..tasks)
