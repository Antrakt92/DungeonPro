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


local dm=assert(owners[166]);local ids={166,214,167,2040,168,92753,373}
local mapCalls,actions=0,0
C_Map.OpenWorldMap=function()mapCalls=mapCalls+1 end
C_Map.SetUserWaypoint=function()actions=actions+1 end
C_QuestLog.SetSelectedQuest=function()actions=actions+1 end
AcceptQuest=function()actions=actions+1 end
local function overview()
 u.dungeon,u.quest,u.includeUnavailable,u.range=dm,nil,false,false;u:Refresh();drain()
 assert(u.overviewBinding.current()and u.overviewBinding.rawProof())
 return u.overviewBinding.model
end
for _,id in ipairs(ids)do held[id]=true end;held[155]=true;ready[373]=true
event.scripts.OnEvent(event,'QUEST_LOG_UPDATE');drain()
local m=overview()
assert(m.shownRoots==7 and m.counts.READY==1 and m.counts.ACTIVE==6 and #m.steps==6 and m.remainingSteps==1)
assert(m.steps[1].id==373)
local more=assert(u.overviewMoreButton,'overview needs explicit more control for hidden held steps')
assert(more:IsShown()and more.enabled and more.label.text==a.L('OVERVIEW_SHOW_MORE',1))
local compact=u.overviewBinding;local compactModel=compact.model
local weak=setmetatable({compactModel},{__mode='v'})
local planner=a.Planner;local oldNew=planner.New;local created=0
planner.New=function(...)created=created+1;return oldNew(...)end
local beforeEngine=u.engine
more=u.overviewMoreButton;more.scripts.OnClick(more);drain()
assert(u.engine==beforeEngine and created==0,'expansion renders existing completed plan without rebuilding Planner')
m=u.overviewBinding.model;assert(#m.steps==7 and m.remainingSteps==0 and m.shownRoots==7 and m.counts.READY==1)
assert(not more:IsShown()and not more.enabled)
local fewer=assert(u.overviewFewerButton);assert(fewer:IsShown()and fewer.enabled and fewer.label.text==a.L('OVERVIEW_SHOW_FEWER'))
for i,step in ipairs(m.steps)do assert(step.id==({373,166,214,167,2040,168,92753})[i])end
fewer.scripts.OnClick(fewer);drain();assert(#u.overviewBinding.model.steps==6 and u.overviewBinding.model.remainingSteps==1 and created==0)
planner.New=oldNew
compactModel=nil;compact=nil;gc();assert(weak[1]==nil,'retired compact model is not held by more/fewer native records')
print('PASS actual7 primary held:6->7->6, READYfirst, sameengine/no newPlanner, oldmodel collected')
-- Ordinary support remains separate from primary counts.
held,ready={[155]=true,[373]=true},{[373]=true};event.scripts.OnEvent(event,'QUEST_LOG_UPDATE');drain();m=overview()
assert(#m.steps==2 and m.steps[1].id==373 and m.steps[2].id==155 and not m.steps[2].listedTarget and m.counts.READY==1 and m.counts.ACTIVE==0)
assert(not u.overviewMoreButton:IsShown()and not u.overviewFewerButton:IsShown())
held,ready={},{};event.scripts.OnEvent(event,'QUEST_LOG_UPDATE');drain();m=overview()
assert(#m.steps==0 and not u.overviewMoreButton:IsShown()and not u.overviewFewerButton:IsShown())
print('PASS actual support155 and READY373 remain truthful;0/2 rows have no expansion controls')
-- Restore a genuine >6 context; optional count labels format all ten selected languages.
for _,id in ipairs(ids)do held[id]=true end;held[155]=true
for _,locale in ipairs({'enUS','ruRU','deDE','frFR','esES','itIT','ptBR','koKR','zhCN','zhTW'})do
 a.db.locale=locale;m=overview()
 assert(u.overviewMoreButton.label.text==a.L('OVERVIEW_SHOW_MORE',1)and not a.L('OVERVIEW_SHOW_MORE',1):find('%%'))
 local b=u.overviewBinding;local oldClick=u.overviewMoreButton.scripts.OnClick
 assert(u:InspectQuest(166,true));drain();oldClick();assert(u.quest==166 and not b.current())
end
print('PASS ten locale counts/oldclick cannot expand quest details')
a.db.locale='enUS';overview()
u.overviewMoreButton.scripts.OnClick();drain()
local oldMore=u.overviewFewerButton.scripts.OnClick
local rfc=assert(owners[5724]);u.dungeon,u.quest=rfc,nil;u:Refresh();drain()
oldMore();assert(u.dungeon==rfc and u.overviewStepLimits[dm].limit==12)
overview();assert(#u.overviewBinding.model.steps==7 and u.overviewFewerButton:IsShown())
u.overviewFewerButton.scripts.OnClick();drain()
print('PASS explicit expansion is transient per dungeon; old other-dungeon click cannot change it')
for _,method in ipairs({'SetText','Show'})do for _,phase in ipairs({'before','after'})do
 overview();local button=u.overviewMoreButton
 local object=method=='SetText'and button.label or button
 local old,fired=object[method],false
 object[method]=function(self,...)
  local hit=not fired
  local function replace()fired=true;assert(u:InspectQuest(214,true));drain()end
  if hit and phase=='before'then replace()end
  local value=old(self,...)
  if hit and phase=='after'then replace()end
  return value
 end
 u:RefreshDetail();drain();object[method]=old
 assert(fired and u.quest==214 and u.renderedQuest==214 and not button:IsShown()and not button.enabled and button.scripts.OnClick==nil)
end end
print('PASS four native caption/Show tails preserve newer214 detail and retired controls')
overview();local button=u.overviewMoreButton;local getter=u.frame.IsShown;local fired=false
u.frame.IsShown=function(self)
 if not fired then fired=true;assert(u:InspectQuest(214,true));drain()end
 return getter(self)
end
button.scripts.OnClick();u.frame.IsShown=getter
assert(fired and u.quest==214 and u.overviewStepLimits[dm].limit==6)
print('PASS final shown getter cannot expand newer quest')
overview();local cleaner=a.Clean;local firedLimit=false
a.Clean=function(value,kind)
 local result=cleaner(value,kind)
 local caller=debug.getinfo(2,'f').func
 if not firedLimit and value==6 and kind=='number'and caller==a.PreparationOverviewUI.RenderPreparationOverview then
  firedLimit=true;assert(u:InspectQuest(214,true));drain()
 end
 return result
end
u:RefreshDetail();drain();a.Clean=cleaner
assert(firedLimit and u.quest==214 and u.renderedQuest==214 and u.overviewBinding==nil,'limit classification cannot overwrite a newer quest owner')
print('PASS limit-classification callback preserves newer detail ownership before binding publication')
assert(mapCalls==0 and actions==0)
-- Controlled actions are not catalogue facts; one primary root plus bounded supporting action IDs.
local function controlled(count)
 local states,actions={},{}
 for id=1,count do states[id]={id=id,status=id==count and 'READY'or'ACTIVE'};actions[id]={id=id,kind=id==count and'turnin'or'complete'}end
 local d={quests={1}};local e={State=function()error('no new State')end,Next=function()error('no new Next')end,Dungeon=function()error('no new Dungeon')end,Current=function()return true end,states=states,context={current=function()return true end},quests={},invalid=false}
 local plan={engine=e,dungeon=d,rows={{id=1,state=states[1]}},actions=actions,unknown=true,ready=false}
 return plan,d,e
end
for _,count in ipairs({8,50,1024})do
 local plan,d,e=controlled(count);local fourth=0
 local owner=function()fourth=fourth+1;return true end
 local originalCalls=0;local oldCurrent=e.Current;e.Current=function(self)originalCalls=originalCalls+1;return oldCurrent(self)end
 local default=assert(a.DungeonOverview.Get(plan,d,e,owner))
 assert(#default.steps==6 and default.remainingSteps==count-6 and fourth==1)
 local reads=originalCalls
 local expanded,current,raw=a.DungeonOverview.Get(plan,d,e,owner,count)
 assert(expanded and #expanded.steps==count and expanded.remainingSteps==0 and expanded.steps[1].id==count and expanded.shownRoots==1 and current()and raw())
 assert(originalCalls==reads+2,'constructor and explicit retained validation only call Current; no source/native/Planner scan')
 local compact=assert(a.DungeonOverview.Get(plan,d,e,nil,6));assert(#compact.steps==6)
 for _,invalid in ipairs({0,5,6.5,1025,'6',false,math.huge})do assert(a.DungeonOverview.Get(plan,d,e,nil,invalid)==nil)end
end
assert(a.DungeonOverview.Get(controlled(8)),'three argument existing call remains supported')
print('PASS controlled8/50/1024 bounds, default6/fourthowner, invalid limits failclosed, no extra producer scans')
print('PASS overview-more31 bounded feature regression')

do
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

local ids={};a.quests={}
for index=1,14 do
 local id=31000000+index;ids[index]=id
 a.quests[id]={id=id,name='Controlled held step '..index,minLevel=1,requirementsKnown=true}
 held[id]=true
end
ready[ids[14]]=true
local d={key='controlled14',name='Controlled UI fixture',minLevel=1,maxLevel=60,coverage='partial',quests=ids}
a.dungeons={d}
local routes,accepts,selections=0,0,0
C_Map.SetUserWaypoint=function()routes=routes+1 end
AcceptQuest=function()accepts=accepts+1 end
C_QuestLog.SetSelectedQuest=function()selections=selections+1 end
event.scripts.OnEvent(event,'ADDON_LOADED','DungeonPro');u:Toggle();drain()
a.db.locale='enUS';u.dungeon,u.quest,u.includeUnavailable,u.range=d,nil,false,false;u:Refresh();drain()
local engine=u.engine
local function model(count,remaining)
 local b=assert(u.overviewBinding);assert(b.current()and b.rawProof())
 local m=b.model;assert(#m.steps==count and m.remainingSteps==remaining and m.shownRoots==14 and m.counts.READY==1 and m.counts.ACTIVE==13)
 assert(m.steps[1].id==ids[14]and m.steps[1].status=='READY')
 for i=2,#m.steps do assert(m.steps[i].id==ids[i-1])end
 assert(u.engine==engine and u.quest==nil)
 return m
end
model(6,8)
local more=u.overviewMoreButton;assert(more:IsShown()and more.label.text==a.L('OVERVIEW_SHOW_MORE',6))
more.scripts.OnClick(more);drain();model(12,2)
local fewer=u.overviewFewerButton
assert(more:IsShown()and fewer:IsShown()and more.label.text==a.L('OVERVIEW_SHOW_MORE',2))
-- Explicit simulated multiline native measurement, not a real font claim.
fewer.label.GetStringHeight=function()return 52 end
u:RefreshDetail();drain();model(12,2)
assert(more.height==60 and fewer.height==60 and more.point[3]==fewer.point[3])
assert(fewer.point[2]==more.point[2]+more.width+4 and more.point[2]>=0 and fewer.point[2]+fewer.width<=u.detail:GetWidth())
local bottom=-more.point[3]+more.height;local following
for _,fs in ipairs(u.details)do if fs:IsShown()and fs.text==a.L('CATALOG_QUESTS',14)then following=fs;break end end
assert(following and -following.point[3]>=bottom+8 and u.detail:GetHeight()>=-following.point[3]+following:GetStringHeight())
local viewport=u.detailScroll:GetHeight();local offset=math.max(0,bottom-viewport+8)
assert(offset<=math.max(0,u.detail:GetHeight()-viewport))
assert(u:WriteDetailScroll(u.detailScroll,offset,u.overviewBinding.current))
assert(-more.point[3]-offset>=0 and bottom-offset<=viewport)
more.scripts.OnClick(more);drain();model(14,0)
assert(not more:IsShown()and fewer:IsShown())
fewer.scripts.OnClick(fewer);drain();model(6,8)
assert(more:IsShown()and not fewer:IsShown()and routes==0 and accepts==0 and selections==0)
print('PASS controlled UI14:6->12 BOTH More2/Fewer->14 Feweronly->6, order/counts/sameengine/4pxgap/common60pxheight/rightbounds/followingbody/scrollreach;0actions; not catalogue facts')

end
