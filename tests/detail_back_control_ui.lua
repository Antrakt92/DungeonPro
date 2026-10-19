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
local styleCount=0;local nativeStyle=a.Theme.StyleRow
a.Theme.StyleRow=function(row,options)
 if row==u.detailBackButton then assert(options.kind=="control"and options.selected==false);styleCount=styleCount+1 end
 return nativeStyle(row,options)
end
local dm=assert(owners[166]);local routes,accepts,selections=0,0,0
C_Map.SetUserWaypoint=function()routes=routes+1 end;AcceptQuest=function()accepts=accepts+1 end;C_QuestLog.SetSelectedQuest=function()selections=selections+1 end
function tooltip:SetOwner(owner)self.owner=owner;self.lines={}end
function tooltip:SetText(text)self.text=text end
function tooltip:AddLine(text)self.lines[#self.lines+1]=text end
u.dungeon,u.quest=dm,166;u:Refresh();drain()
local control=assert(u.detailBackButton,"selected quest needs a visible compact Back control")
assert(control:IsShown()and control.enabled and control.label.text=="‹"and control:GetWidth()==28)
assert(styleCount>0,"Back uses the same Theme.StyleRow control style as contextual tabs")
local function click()assert(control.scripts.OnClick);control.scripts.OnClick(control);drain()end
-- The bounded native-shaped viewport makes a real reading offset reachable in this offline fixture.
u.detailScroll.GetHeight=function()return 100 end
assert(u:SetDetailTab("sources"));drain();assert(u.detail:GetHeight()-u.detailScroll:GetHeight()>=31)
u.detailScroll:SetVerticalScroll(31)
assert(u:InspectQuest(214,true));drain();assert(u.quest==214 and #u.detailHistory==1)
click();assert(u.quest==166 and u.renderedQuest==166 and u.detailTab=="sources"and u.detailScroll:GetVerticalScroll()==31 and #u.detailHistory==0)
click();assert(u.quest==nil and u.dungeon==dm and not control:IsShown()and not control.enabled and control.scripts.OnClick==nil)
for _,row in ipairs(u.rows)do assert(not row.selected,"overview must not retain an old middle selection")end
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","itIT","ptBR","koKR","zhCN","zhTW"})do
 a.db.locale=locale;assert(u:InspectQuest(166,true));drain()
 assert(a.L("BACK")==a.locales[locale].DETAIL_BACK and not a.L("BACK"):find("%%"))
 control.scripts.OnEnter();assert(tooltip.shown and tooltip.text==a.L("BACK")and #tooltip.lines==0)
 local last=control.point[2]+control.width
 for _,key in ipairs({"quest","sources","story"})do
  local tab=u.detailTabButtons[key];assert(tab:IsShown()and tab.point[2]>=last+4 and tab.width>0)
  assert(tab.point[2]+tab.width<=u.detail:GetWidth()and tab.height>=26)
  last=tab.point[2]+tab.width
 end
 assert(control.height==u.detailTabButtons.quest.height)
 local stale,proof=control.scripts.OnClick,u.detailBackBinding.current
 assert(u:InspectQuest(214,true));drain();assert(not proof());stale(control);assert(u.quest==214)
 print("PASS",locale,"localizedBackhint/rowbounds/retiredclick")
end
local stale=control.scripts.OnClick;u.frame:Hide();u.frame.scripts.OnHide();stale(control)
assert(u.quest==214);u.frame:Show();u:Refresh();drain();assert(control:IsShown()and control.enabled)
assert(routes==0 and accepts==0 and selections==0 and not u.preparation)
for _,method in ipairs({"SetText","Show","SetEnabled","SetScript"})do for _,phase in ipairs({"before","after"})do
 u.dungeon,u.quest=dm,166;u.detailHistory={};u:Refresh();drain()
 local object=method=="SetText"and control.label or control
 local native,fired=object[method],false
 object[method]=function(self,...)
  local hit=not fired
  local function replace()fired=true;assert(u:BackQuest());drain();assert(u.quest==nil and not control:IsShown()and not control.enabled)end
  if hit and phase=="before"then replace()end
  local value=native(self,...)
  if hit and phase=="after"then replace()end
  return value
 end
 u:RefreshDetail();drain();object[method]=native
 assert(fired and u.quest==nil and not control:IsShown()and not control.enabled and control.scripts.OnClick==nil)
 print("PASS native",method,phase,"newer overview wins")
end end
u.dungeon,u.quest=dm,166;u.detailHistory={};u:Refresh();drain()
local nativeShown=u.frame.IsShown;local armed,fired=false,false
u.frame.IsShown=function(self)
 if armed and not fired then fired=true;assert(u:InspectQuest(214,true));drain()end
 return nativeShown(self)
end
u:RefreshDetail();local oldClick=control.scripts.OnClick;armed=true;oldClick(control)
assert(fired and u.quest==214 and u.renderedQuest==214)
u.frame.IsShown=nativeShown;u:RefreshDetail();drain()
assert(routes==0 and accepts==0 and selections==0)
print("PASS last shown-getter input callback cannot consume newer history")
for _,phase in ipairs({"before","after"})do
 u.dungeon,u.quest=dm,166;u.detailHistory={};u:Refresh();drain()
 local style=a.Theme.StyleRow;local fired=false
 a.Theme.StyleRow=function(row,options)
  local hit=row==control and not fired
  local function replace()fired=true;assert(u:BackQuest());drain();assert(u.quest==nil and not control:IsShown()and not control.enabled)end
  if hit and phase=="before"then replace()end
  local result=style(row,options)
  if hit and phase=="after"then replace()end
  return result
 end
 u:RefreshDetail();drain()
 assert(fired and u.quest==nil and not control:IsShown()and not control.enabled and control.scripts.OnClick==nil)
 a.Theme.StyleRow=style
 print("PASS Theme.StyleRow",phase,"new overview survives late styling and oldShow")
end
print("Compact Back: PASS actual166Sources31 ->214 ->166Sources31 ->overview;10locales, layout, stale/hide/reopen, no quest/nav actions")
