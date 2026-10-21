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
local root=assert(owners[5724]);local roots,definition=a.dungeons,a.quests[5724]
local members,factions,start,finish=root.quests,definition.factions,definition.start,definition.finish
local routes=0;C_Map.SetUserWaypoint=function()routes=routes+1 end
function tooltip:SetOwner(owner)self.owner=owner;self.lines={}end
function tooltip:SetText(value)self.title=value end
function tooltip:AddLine(value)self.lines[#self.lines+1]=value end
local function noticeVisible(text)
 local count=0
 for _,fs in ipairs(u.details)do if fs:IsShown()and fs.text==text then count=count+1 end end
 for _,row in ipairs(u.rows)do if row:IsShown()and row.title and row.title.text==text then count=count+1 end end
 return count
end
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","itIT","ptBR","koKR","zhCN","zhTW"})do
 a.db.locale=locale;u.dungeon,u.quest=root,nil;u.includeUnavailable=true;u:Refresh();drain()
 local all,mine=a.L("FILTER_QUEST_ALL"),a.L("FILTER_QUEST_MINE")
 assert(u.characterButton.filterCaption.text==all and #u.currentPlan.rows==6)
 u.characterButton.scripts.OnEnter();assert(tooltip.shown and tooltip.lines[1]==all and tooltip.lines[2]==a.L("FILTER_SWITCH",mine))
 u.characterButton.scripts.OnClick();drain()
 assert(not u.includeUnavailable and #u.currentPlan.rows==0 and u.engine:State(5724).status=="UNAVAILABLE")
 local raw=a.locales[locale].NO_CHARACTER_QUESTS;local _,arity=raw:gsub("%%s","")
 assert(arity==1,"empty guidance must format exactly one existing filter label")
 local notice=a.L("NO_CHARACTER_QUESTS",all)
 assert(notice:find(all,1,true)and not notice:find("%%s",1,true))
 assert(noticeVisible(notice)==1 and noticeVisible(a.L("OVERVIEW_PICK"))==1,"middle empty state owns the actionable filter choice while the right panel stays a compact prompt")
 assert(u.characterButton.filterCaption.text==mine)
 u.characterButton.scripts.OnEnter();assert(tooltip.shown and tooltip.lines[1]==mine and tooltip.lines[2]==a.L("FILTER_SWITCH",all))
 u.characterButton.scripts.OnClick();drain()
 assert(u.includeUnavailable and #u.currentPlan.rows==6 and u.characterButton.filterCaption.text==all)
 assert(noticeVisible(notice)==0 and u.quest==nil and #u.detailHistory==0 and routes==0)
 assert(a.dungeons==roots and root.quests==members and #members==6 and a.quests[5724]==definition and definition.factions==factions and definition.start==start and definition.finish==finish)
 print("PASS",locale,"actual RFC All6 -> Mine0 -> All6; exactcaption/hint/emptycopy")
end
u.includeUnavailable=false;u:Refresh();drain();held[5724]=true
event.scripts.OnEvent(event,"QUEST_ACCEPTED",5724);drain()
assert(not u.includeUnavailable and #u.currentPlan.rows==1 and u.engine:State(5724).status=="ACTIVE")
held[5724]=nil;event.scripts.OnEvent(event,"QUEST_REMOVED",5724);drain()
assert(#u.currentPlan.rows==0 and u.engine:State(5724).status=="UNAVAILABLE"and routes==0)
print("PASS actual held log evidence still outranks recorded faction restriction, removed restores Mine0")
print("Preparation empty-filter copy: PASS 10locales +nativeheld/removal; no filter/data/action semantics changed")
