local function run(phase,controlKind)
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
for _,id in ipairs(ids)do held[id]=true end;ready[373]=true
event.scripts.OnEvent(event,'QUEST_LOG_UPDATE');drain()
u.dungeon,u.quest,u.includeUnavailable,u.range=dm,nil,false,false;u:Refresh();drain()
local expanded=controlKind=='fewer'
if expanded then u.overviewMoreButton.scripts.OnClick();drain()end
local more=assert(expanded and u.overviewFewerButton or u.overviewMoreButton);assert(more:IsShown()and more.enabled and more.point)
local native,fired,newPoint=more.ClearAllPoints,false,nil
more.ClearAllPoints=function(self,...)
 local hit=not fired
 local function replace()
  fired=true;assert(a.Language:Open(u));assert(a.Language:Commit(assert(a.Language.session),'ruRU'));drain()
  assert(a.db.locale=='ruRU'and u.quest==nil and u.overviewBinding.current())
  assert(more:IsShown()and more.enabled and more.point,'new RU More must have a positively painted anchor before old native tail')
  newPoint=more.point
 end
 if hit and phase=='before'then replace()end
 local value=native(self,...)
 if hit and phase=='after'then replace()end
 return value
end
u:RefreshDetail();drain()
assert(fired and newPoint and more:IsShown()and more.enabled and u.overviewBinding.current())
assert(more.point,'late old ClearAllPoints must not erase newer visible RU More anchor')
for key,value in pairs(newPoint)do assert(rawequal(more.point[key],value))end
for key,value in pairs(more.point)do assert(rawequal(newPoint[key],value))end
more.ClearAllPoints=native
more.scripts.OnClick();drain();assert(#u.overviewBinding.model.steps==(expanded and 6 or 7))
print('PASS '..phase..' '..(expanded and 'Fewer' or 'More')..' ClearAllPoints latestRUanchor/click')

end
for _,kind in ipairs({"more","fewer"})do for _,phase in ipairs({"before","after"})do run(phase,kind)end end

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
local owners={};for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=d end end
event.scripts.OnEvent(event,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true;drain()
local function draw(id)
 u.dungeon,u.quest=assert(owners[id]),id;u:Refresh();drain();assert(u.renderedQuest==id)
end

local dm=assert(owners[166]);local ids={166,214,167,2040,168,92753,373}
for _,id in ipairs(ids)do held[id]=true end;ready[373]=true
event.scripts.OnEvent(event,'QUEST_LOG_UPDATE');drain()
u.dungeon,u.quest,u.includeUnavailable,u.range=dm,nil,false,false;u:Refresh();drain()

local refresh=u.RefreshDetail;u.RefreshDetail=nil
local ok,err=pcall(refresh,u);assert(ok,err)
assert(not u.overviewMoreButton:IsShown()and not u.overviewMoreButton.enabled and u.overviewMoreButton.scripts.OnClick==nil,'missing explicit redraw helper cannot leave active expansion control')
u.RefreshDetail=refresh;refresh(u);drain()
local button=u.overviewMoreButton;assert(button:IsShown()and button.enabled)
local oldClick=button.scripts.OnClick;local b=u.overviewBinding;local helper=b.geometryWrite
assert(type(helper)=='function')
b.presentation.geometryWrite=function()error('foreign geometry helper must not run')end
oldClick();assert(#u.overviewBinding.model.steps==6 and u.overviewStepLimits[dm].limit==6)
b.presentation.geometryWrite=helper
refresh(u);drain();u.overviewMoreButton.scripts.OnClick();drain();assert(#u.overviewBinding.model.steps==7)
print('PASS explicit missing RefreshDetail safely hides controls; presentation geometry helper replacement retires oldclick and fresh recovery works')
end
