-- Pooled quest rows keep their current owner but release superseded engines.
local f=assert(loadfile('tests/client_ui.lua'))('fixture');local a,ui=f.addon,f.addon.UI
issecretvalue=function()return false end;GetLocale=function()return'enUS'end
UnitGUID=function(unit)return unit=='player'and'Player-QuestRowRelease'or nil end
C_Timer={After=function()end};f.eventFrame.scripts.OnEvent(f.eventFrame,'ADDON_LOADED','DungeonPro');ui:Toggle()
ui.includeUnavailable=true;ui.preparation=false
local rewards,cache=a.QuestListRewards,a.RewardCache;a.QuestListRewards=nil;a.RewardCache=nil
local dungeons={};for _,d in ipairs(a.dungeons)do dungeons[d.key]=d end
local weak=setmetatable({},{__mode='v'});local active;local reads={};local create=a.Planner.New
a.Planner.New=function(...)
 local engine=create(...);local label=active
 if label then
  weak[label]=engine;local current=engine.Current
  engine.Current=function(...)reads[label]=(reads[label]or 0)+1;return current(...)end
 end
 return engine
end
local function gc()collectgarbage('collect');collectgarbage('collect')end
local function draw(key,label)
 ui.dungeon=key and assert(dungeons[key])or nil;ui.quest=nil;ui.questTreeRoot=nil;ui.questTreeDungeon=nil
 active=label or key;ui:RefreshQuests();active=nil
end
draw('brd');assert(weak.brd and weak.brd==ui.engine)
local pool=ui.rows;local row=assert(pool[7]);local registry=row.questListWrites
local old=assert(row.questListCurrent);assert(old())
draw('rfc');gc()
assert(not weak.brd and weak.rfc==ui.engine,'superseded BRD engine must collect while current RFC engine remains owned')
local before=reads.brd;assert(old()==false and reads.brd==before,'retired row proof cannot call its former engine')
assert(ui.rows==pool and row.questListWrites==registry,'pooled rows and native repair registries retain identity')
draw(nil);gc();assert(not weak.rfc and ui.engine==nil and ui.currentPlan==nil,'overview releases former RFC engine')
print('PASS obsolete row engines collect without deleting pooled bindings')
draw('rfc','capability');local live=assert(ui.rows[1].questListCurrent);assert(live())
for _,key in ipairs({'Read','Clean','checker'})do
 local saved=key=='checker'and issecretvalue or a[key];local count=reads.capability
 if key=='checker'then issecretvalue=function()return false end else a[key]=function()return true end end
 local ok,result=pcall(live)
 if key=='checker'then issecretvalue=saved else a[key]=saved end
 assert(ok and result==false and reads.capability==count,'changed '..key..' must reject before provider reads')
end
assert(live());ui.frame:Hide();ui.frame:Show();assert(ui.dungeon==dungeons.rfc and ui.engine,'reopening preserves a usable current list')
print('PASS capability drift rejects and current list recovers')
local first=ui.rows[1];local set=first.title.SetText;local fired=false;local latestTitle,latestOwner
first.title.SetText=function(self,text)
 if not fired then fired=true;draw('rfc','native-latest');latestTitle=first.title.text;latestOwner=first.questListCurrent end
 return set(self,text)
end
draw('brd','native-old');first.title.SetText=set
assert(fired and ui.dungeon==dungeons.rfc and first.title.text==latestTitle and first.questListCurrent==latestOwner and latestOwner(),
 'late old native title tail must preserve newest row text and callable owner')
assert(first:IsShown() and ui.currentPlan.engine==ui.engine)
print('PASS native title reentry preserves latest row and status owner')
local widthSet=first.title.SetWidth;local prior=first.statusWidth;local widthFired=false;local latestWidth
first.title.SetWidth=function(self,value)
 if not widthFired and first.statusWidth~=prior and first.statusWidth and value==first.statusWidth.width then
  widthFired=true;draw('rfc','status-latest');latestWidth=first.statusWidth
 end
 return widthSet(self,value)
end
draw('brd','status-old')
assert(widthFired and ui.dungeon==dungeons.rfc and first.statusWidth==latestWidth and latestWidth.current() and first.title:GetWidth()==latestWidth.width,
 'late old status width tail must restore newest status binding and width')
first.title.SetWidth=widthSet
print('PASS native status width reentry preserves latest binding and geometry')
a.QuestListRewards,a.RewardCache=rewards,cache
draw('brd','normal-old');draw('rfc','normal-current');gc()
assert(not weak['normal-old'] and weak['normal-current']==ui.engine,'normal reward helpers must not retain obsolete row engines')
assert(ui.rows[1].questListCurrent() and ui.currentPlan.engine==ui.engine)
print('PASS normal optional reward helpers keep only current list engine')
local apply=ui.ApplyColumns;local columnFired=false
ui.ApplyColumns=function(self,...)
 if not columnFired then columnFired=true;draw('rfc','column-latest') end
 return apply(self,...)
end
draw('brd','column-old');ui.ApplyColumns=apply
assert(columnFired and ui.dungeon==dungeons.rfc and ui.engine==weak['column-latest'] and ui.rows[1].questListCurrent(),
 'an older layout callback cannot retire or replace a newer list request')
print('PASS early layout reentry retains newest request and engine')
