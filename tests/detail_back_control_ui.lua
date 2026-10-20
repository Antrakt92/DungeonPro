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

local dm=assert(owners[166]);local routes,accepts,selections=0,0,0
C_Map.SetUserWaypoint=function()routes=routes+1 end;AcceptQuest=function()accepts=accepts+1 end;C_QuestLog.SetSelectedQuest=function()selections=selections+1 end
local function absent()
 local b=u.detailBackButton
 assert(not b or(not b:IsShown()and not b.enabled and b.scripts.OnClick==nil),"accepted stream has no universal Back control or active callback")
 for _,tab in pairs(u.detailTabButtons or{})do assert(not tab:IsShown(),"no hidden selectable modes")end
end
u.detailScroll.GetHeight=function()return 100 end
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","itIT","ptBR","koKR","zhCN","zhTW"})do
 a.db.locale=locale;u.dungeon,u.quest=dm,166;u.detailHistory={};u:ResetHistoryReading();u:Refresh();drain();absent()
 assert(a.L("BACK")==a.locales[locale].DETAIL_BACK and not a.L("BACK"):find("%%"),"compatibility API copy stays localized")
 assert(u:SetDetailTab("sources")and u.detailTab=="quest");u.detailScroll:SetVerticalScroll(31)
 assert(u:InspectQuest(214,true));drain();assert(u.quest==214 and #u.detailHistory==1);absent()
 assert(u:BackQuest());drain();assert(u.quest==166 and u.renderedQuest==166 and u.detailTab=="quest"and u.detailScroll:GetVerticalScroll()==31 and #u.detailHistory==0);absent()
 assert(u:BackQuest());drain();assert(u.quest==nil and u.dungeon==dm);absent()
 for _,row in ipairs(u.rows)do assert(not row.selected,"overview must clear previous middle selection")end
 print("PASS",locale,"single stream API reading restore and overview, no universal control")
end
u.dungeon,u.quest=dm,166;u:Refresh();drain();assert(u:InspectQuest(214,true));drain()
u.frame:Hide();u.frame.scripts.OnHide();absent();assert(u.quest==214)
u.frame:Show();u:Refresh();drain();absent();assert(u.quest==214 and u.renderedQuest==214)
local native=u.frame.IsShown;local fired=false
u.frame.IsShown=function(self)if not fired then fired=true;assert(u:InspectQuest(166,true));drain()end;return native(self)end
assert(u:BackQuest());u.frame.IsShown=native;drain()
assert(fired and u.quest==166 and u.renderedQuest==166,"native visibility reentry preserves the newer inspection")
assert(routes==0 and accepts==0 and selections==0 and not u.preparation);absent()
print("PASS removed universal Back, retained history API across10locales/31px/overview/hide-reopen/nativevisibility; no quest/nav actions")
