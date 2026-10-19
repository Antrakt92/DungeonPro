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

local dm=assert(owners[166]);held[166],held[373],ready[373],held[155]=true,true,true,true
event.scripts.OnEvent(event,'QUEST_LOG_UPDATE');drain()
u.dungeon,u.quest,u.includeUnavailable,u.range=dm,nil,false,false;u:Refresh();drain()
local function row(id)
 for _,r in ipairs(u.actionInspectButtons)do if r:IsShown()and r.questID==id then return r end end
 error('missing visible held step '..id)
end
local function expected(step)
 local status='|cff'..(step.status=='READY'and'ffe066'or'88bfff')..a.L(step.status)..'|r'
 return (step.listedTarget==false and(a.L('OVERVIEW_SUPPORTING_QUEST')..' · ')or'')..status..' · '..a.L('BRANCH_INSPECT')
end
assert(row(373).note.text==expected(row(373).overviewStep),'READY word alone must use existing gold status color')
assert(row(166).note.text==expected(row(166).overviewStep),'ACTIVE word alone must use existing blue status color')
assert(row(155).note.text==expected(row(155).overviewStep)and not row(155).overviewStep.listedTarget)
assert(u.overviewBinding.model.shownRoots==7 and u.overviewBinding.model.counts.READY==1 and u.overviewBinding.model.counts.ACTIVE==1 and u.overviewBinding.model.unknown)
print('PASS actual373READY/166ACTIVE exact existing palette words; support155/plainaction/counts/unknown unchanged')

local routes=0;C_Map.SetUserWaypoint=function()routes=routes+1 end
for _,locale in ipairs({'enUS','ruRU','deDE','frFR','esES','itIT','ptBR','koKR','zhCN','zhTW'})do
 a.db.locale=locale;u:Refresh();drain()
 for _,r in ipairs(u.actionInspectButtons)do if r:IsShown()then
  assert(r.note.text==expected(r.overviewStep))
  local plain=r.note.text:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
  assert(plain:find(a.L(r.overviewStep.status),1,true)and plain:find(a.L('BRANCH_INSPECT'),1,true))
 end end
end
print('PASS ten locales retain exact status/action/support words, only status color span')
ready[373]=false;event.scripts.OnEvent(event,'QUEST_LOG_UPDATE');drain();u:Refresh();drain()
assert(row(373).overviewStep.status=='ACTIVE'and row(373).note.text==expected(row(373).overviewStep))
assert(row(166).note.text==expected(row(166).overviewStep))
for _,r in ipairs(u.actionInspectButtons)do if r:IsShown()then assert(not r.note.text:find('|cffffe066',1,true))end end
print('PASS actual READY->ACTIVE event reuses rows without old gold/status')
for _,phase in ipairs({'before','after'})do
 ready[373]=true;a.db.locale='enUS';event.scripts.OnEvent(event,'QUEST_LOG_UPDATE');drain();u:Refresh();drain()
 local oldRow=row(373);local fs=oldRow.note;local native,fired=fs.SetText,false
 fs.SetText=function(self,value)
  local hit=not fired and value:find('|cffffe066',1,true)
  local function replace()
   fired=true;ready[373]=false;event.scripts.OnEvent(event,'QUEST_LOG_UPDATE');drain()
   assert(a.Language:Open(u));assert(a.Language:Commit(assert(a.Language.session),'ruRU'));drain()
   assert(row(166)==oldRow and oldRow.note.text==expected(oldRow.overviewStep))
  end
  if hit and phase=='before'then replace()end
  local result=native(self,value)
  if hit and phase=='after'then replace()end
  return result
 end
 u:RefreshDetail();drain()
 assert(fired and a.db.locale=='ruRU'and row(166)==oldRow and fs.text==expected(oldRow.overviewStep)and u.overviewBinding.current())
 fs.SetText=native;u:RefreshDetail();drain()
end
print('PASS late old gold SetText before/after cannot replace newer RU ACTIVE same pooled row')
-- Legacy standalone presentation is optional and retains its original plain text.
local b=u.overviewBinding;local owner=b.base;local presentation={}
for key,value in pairs(b.presentation)do presentation[key]=value end
presentation.formatStatus=nil
u:ReleasePreparationOverview();assert(u:ResetPreparationOverviewControls(owner))
assert(u:RenderPreparationOverview(owner,u.detail:GetWidth()-8,0,presentation))
for _,r in ipairs(u.actionInspectButtons)do if r:IsShown()then assert(not r.note.text:find('|c',1,true)and r.note.text:find(a.L(r.overviewStep.status),1,true))end end
local legacy=u.overviewBinding;local click=row(166).scripts.OnClick
presentation.formatStatus=function()error('inserted optional helper cannot be called by retained legacy owner')end
click();assert(u.quest==nil and not legacy.current())
u:RefreshDetail();drain();assert(row(166).note.text==expected(row(166).overviewStep))
print('PASS absent optional formatter stays plain; later insertion retires old owner/fresh colored view recovers')
local read=a.Read;local fired=false
a.Read=function(getter,kind,...)
 local b=u.overviewBinding
 if not fired and b and getter==b.formatStatus and type(getter)=='function'then
  fired=true;assert(u:InspectQuest(214,true));drain()
 end
 return read(getter,kind,...)
end
u.dungeon,u.quest=dm,nil;u:Refresh();drain();a.Read=read
assert(fired and u.quest==214 and u.renderedQuest==214 and u.overviewBinding==nil)
for _,r in ipairs(u.actionInspectButtons)do assert(not r:IsShown()and not r.enabled and r.scripts.OnClick==nil)end
assert(routes==0 and #queue==0)
print('PASS formatter dispatch reentry cannot publish an old colored row over newer214')
