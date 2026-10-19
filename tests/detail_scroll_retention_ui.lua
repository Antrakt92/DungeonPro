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



local dm=assert(owners[166]);local rfc=assert(owners[5724]);local ids={166,214,167,2040,168,92753,373}
for _,id in ipairs(ids)do held[id]=true end;held[155]=true;ready[373]=true
event.scripts.OnEvent(event,'QUEST_LOG_UPDATE');drain()
local routes=0;local start=a.Navigation.Start;a.Navigation.Start=function(...)routes=routes+1;return start(...)end

local weak=setmetatable({},{__mode='v'})
local function overview()
 u.dungeon,u.quest,u.includeUnavailable,u.range=dm,nil,false,false;u:Refresh();drain()
 assert(u.overviewBinding.current());return u.overviewBinding
end
local b=overview();local more=u.overviewMoreButton;local native=more.ClearAllPoints;local fired=false
more.ClearAllPoints=function(self,...)
 if not fired then
  fired=true;assert(a.Language:Open(u));assert(a.Language:Commit(assert(a.Language.session),'ruRU'));drain()
  assert(u.overviewBinding.current()and more.point and more:IsShown())
 end
 self.point=nil
end
u:RefreshDetail();drain();more.ClearAllPoints=native
assert(fired and more.point and u.overviewBinding.current())
local current=u.overviewBinding
weak.engine=u.engine;weak.context=u.engine.context;weak.binding=current;weak.bridge=current.geometryWrite;weak.presentation=current.presentation
local pointRecord=assert(more.questListWrites.SetPoint);assert(pointRecord.current())
local oldClick=more.scripts.OnClick
oldClick();drain();local fewer=u.overviewFewerButton;assert(#u.overviewBinding.model.steps==7)
fewer.scripts.OnClick();drain();assert(#u.overviewBinding.model.steps==6)
assert(current.released and current.geometryWrite==nil and current.presentation==nil)
assert(u:InspectQuest(214,true));drain()
local clean,read,calls=a.Clean,a.Read,0
a.Clean=function(...)calls=calls+1;return clean(...)end;a.Read=function(...)calls=calls+1;return read(...)end
assert(not pointRecord.current()and not current.current());oldClick();assert(u.quest==214 and calls==0)
a.Clean,a.Read=clean,read
current,b=nil,nil;gc()
assert(weak.engine==nil and weak.context==nil and weak.bridge==nil and weak.presentation==nil,'retained repaired SetPoint and oldclick cannot retain Window bridge/engine/context')
print('PASS repaired SetPoint/More retained: bridge+presentation+engine/contextGC; retired0providers')
-- A callback replacing the presentation helper retires old publication without calling the foreign helper.
overview();local size=more.SetSize;local fired,foreign=false,0
more.SetSize=function(self,...)
 if not fired then fired=true;u.overviewBinding.presentation.geometryWrite=function()foreign=foreign+1;error('foreign helper')end end
 return size(self,...)
end
u:RefreshDetail();drain();more.SetSize=size
assert(fired and foreign==0 and not u.overviewBinding.current())
local limit=u.overviewStepLimits[dm].limit;local click=more.scripts.OnClick;if click then click()end
assert(u.overviewStepLimits[dm].limit==limit)
u:RefreshDetail();drain();assert(u.overviewBinding.current()and more:IsShown())
more.scripts.OnClick();drain();assert(#u.overviewBinding.model.steps==7)
print('PASS native callback helper replacement rejects foreign publication; fresh expansion recovers')
local old=u.overviewBinding;weak.hide=u.engine;weak.hideContext=u.engine.context
u.frame:Hide();u.frame.scripts.OnHide(u.frame);drain();assert(old.released and old.geometryWrite==nil and old.presentation==nil)
u.frame:Show();u:Refresh();drain();old=nil;click,size,oldClick,pointRecord,native=nil,nil,nil,nil,nil;gc()
assert(weak.hide==nil and weak.hideContext==nil and #queue==0 and routes==0)
assert(more==u.overviewMoreButton and fewer==u.overviewFewerButton and u.overviewBinding.current())
print('PASS ordinary Hide/reopen releases bridge owner with physical reuse; queue0 tasks'..tasks)

-- The retained physical wrapper is cell-only; current records stay live until the owning render retires.
draw(166);assert(u:SetDetailTab('sources'));drain()
u.detailScroll.GetHeight=function()return 100 end
assert(u:WriteDetailScroll(u.detailScroll,31,function()return true end))
local active=u.detailScroll.questListWrites.SetVerticalScroll;local weakActive=setmetatable({u.engine},{__mode='v'})
gc();assert(active.current()and weakActive[1]==u.engine and u.detailScroll:GetVerticalScroll()==31)
local name=debug.getupvalue(active.current,1);assert(name=='scope' and debug.getupvalue(active.current,2)==nil,'stored wrapper captures only releasable cell')
local release=u.ReleasePreparationOverview;local fired=false
u.ReleasePreparationOverview=function(self,...)
 if not fired then fired=true;assert(u:InspectQuest(214,true));assert(u:SetDetailTab('story'));drain()end
 return release(self,...)
end
u:RefreshDetail();drain();u.ReleasePreparationOverview=release
assert(fired and u.quest==214 and not active.current())
gc();assert(weakActive[1]==nil,'early detail cleanup reentry must release even when old render aborts before a new scroll write')
print('PASS current scroll31 live; wrapper cell-only; early-aborted refresh releases oldengine')
for _,phase in ipairs({'before','after'})do
 draw(166);assert(u:SetDetailTab('sources'));drain()
 local scroll=u.detailScroll;local native=scroll.SetVerticalScroll;local fired=false
 scroll.SetVerticalScroll=function(self,value)
  local hit=not fired
  local function newer()
   fired=true;assert(u:InspectQuest(214,true));assert(u:SetDetailTab('sources'));drain()
   assert(u:WriteDetailScroll(scroll,19,function()return true end));assert(scroll:GetVerticalScroll()==19)
  end
  if hit and phase=='before'then newer()end
  local result=native(self,value)
  if hit and phase=='after'then newer()end
  return result
 end
 assert(not u:WriteDetailScroll(scroll,81,function()return true end))
 assert(fired and u.quest==214 and scroll:GetVerticalScroll()==19 and scroll.questListWrites.SetVerticalScroll.current())
 scroll.SetVerticalScroll=native
 print('PASS native SetVerticalScroll '..phase..' latest214 exact19 restored')
end
-- Constructor sanitizer reentry cannot publish an older cell over a newer record.
draw(166);assert(u:SetDetailTab('sources'));drain()
local cleaner=a.Clean;local fired=false;local setter=u.detailScroll.SetVerticalScroll
local newest
a.Clean=function(value,kind,...)
 if not fired and kind=='function'and value==setter then
  fired=true;assert(u:InspectQuest(214,true));assert(u:SetDetailTab('sources'));drain()
  assert(u:WriteDetailScroll(u.detailScroll,23,function()return true end));newest=u.detailScroll.questListWrites.SetVerticalScroll
 end
 return cleaner(value,kind,...)
end
assert(not u:WriteDetailScroll(u.detailScroll,85,function()return true end));a.Clean=cleaner
assert(fired and u.quest==214 and u.detailScroll:GetVerticalScroll()==23 and u.detailScroll.questListWrites.SetVerticalScroll==newest and newest.current())
assert(routes==0 and #queue==0)
print('PASS constructor Clean reentry preserves latest214 record and exact23; queue0/no routes')
