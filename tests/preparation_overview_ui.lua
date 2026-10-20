-- Current dungeon preparation is summarized without a second planner traversal.
local override=...
local loader=loadfile
if override then loadfile=function(path) return loader(path=="UI/Window.lua" and override or path) end end
local f=assert(loader("tests/client_ui.lua"))("fixture")
loadfile=loader
local a,u=f.addon,f.addon.UI
assert(a.DungeonOverview and type(a.DungeonOverview.Get)=="function","actual TOC must load the overview producer")
issecretvalue=function()return false end
C_Timer={After=function()end}
GetLocale=function()return "enUS"end
UnitGUID=function()return "Player-overview"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro")
u:Toggle();a.db.locale="enUS"
local dm;for _,d in ipairs(a.dungeons)do if d.key=="dm"then dm=d end end;assert(dm)
local token,active,ready,done={},155,155,nil
local routes=0
a.Navigation={Start=function()routes=routes+1;return true end,Map=function()routes=routes+1;return true end}
a.Context=function()
 local own=token
 return {level=60,class="MAGE",faction="Alliance",race=3,current=function()return own==token end,
 active=function(id)return active=="all"or id==active end,ready=function(id)return ready=="all"or id==ready end,completed=function(id)return id==done end}
end
local function render(all)
 token={};u.includeUnavailable=all==true;u.dungeon,u.quest=dm,nil;u.questTreeRoot,u.questTreeDungeon=nil,nil;u:Refresh()
 assert(u.quest==nil and u.engine and u.currentPlan)
end
local function summary()
 local b=u.overviewBinding
 assert(b and b.model and b.current() and b.rawProof(),"dungeon overview must publish a current preparation summary")
 return b,b.model
end
local function visible(id)
 local result
 for _,r in ipairs(u.actionInspectButtons)do if r:IsShown()and r.enabled and r.questID==id then assert(not result);result=r end end
 return assert(result,"known held step must have an explicit visible inspect control")
end
local function text(value)
 for _,pool in ipairs({u.overviewTexts or {},u.details})do for _,fs in ipairs(pool)do if fs:IsShown()and fs.text==value then return fs end end end
end
render(false)
local binding,model=summary()
assert(model.shownRoots==7 and model.counts.READY==0 and model.counts.UNKNOWN>0 and model.unknown and not model.knownPrepared)
assert(#model.steps==1 and model.steps[1].id==155 and model.steps[1].kind=="turnin"and model.steps[1].status=="READY")
local row=visible(155)
assert(row.note.text:find(a.L("READY"),1,true)and row.note.text:find(a.L("BRANCH_INSPECT"),1,true))
assert(text(a.L("OVERVIEW_UNCERTAIN"))and routes==0)
local roots=dm.quests;local count=#roots
row.scripts.OnClick()
assert(u.quest==155 and u.dungeon==dm and #dm.quests==count and dm.quests==roots and routes==0)
assert(u:BackQuest()and u.quest==nil and u.dungeon==dm);summary()
render(true);local _,all=summary();assert(all.shownRoots==9 and all.counts.UNAVAILABLE==2)
assert(text(a.L("OVERVIEW_STATUS_COUNT",a.L("UNAVAILABLE"),2)),"positive non-held statuses cannot disappear")
active,ready=1654,1654;render(false);local _,held=summary();assert(held.shownRoots==8 and held.counts.READY==1);visible(1654)
active,ready=155,nil;render(false);assert(visible(155).note.text:find(a.L("ACTIVE"),1,true))
done=155;render(false);local _,complete=summary();for _,s in ipairs(complete.steps)do assert(s.id~=155)end
done=nil;active,ready=nil,nil;render(false);local _,empty=summary();assert(#empty.steps==0)
do local hint=a.L("OVERVIEW_NO_KNOWN_STEPS");assert(text(hint),"empty overview must render the neutral hint")
local count=0;for _,pool in ipairs({u.overviewTexts or {},u.details})do for _,fs in ipairs(pool)do if fs:IsShown()and fs.text==hint then count=count+1 end end end;assert(count==1,"empty hint appears exactly once")
assert(not text(a.L("OVERVIEW_KNOWN_STEPS"))and not text(a.L("OVERVIEW_NEXT_STEPS")),"empty means no held and no next, so no group headers")
local folded=hint:lower();assert(not folded:find("questlog",1,true)and not folded:find("quest-log",1,true)and not folded:find("quest log",1,true)and not folded:find("journal",1,true)and not hint:find("журнал",1,true)and not hint:find("Questlog",1,true)and not hint:find("%%",1,true),"empty hint stays neutral with no counters: "..hint) end
active,ready="all","all";render(false);local _,many=summary()
assert(#many.steps==6 and many.remainingSteps==3 and many.shownRoots==9)
local shown=0;for _,r in ipairs(u.actionInspectButtons)do if r:IsShown()then shown=shown+1 end end;assert(shown==6)
active,ready=155,155
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","itIT","koKR","zhCN","zhTW"})do
 a.db.locale=locale;render(false);local _,m=summary();assert(m.shownRoots==7)
 assert(text(a.L("OVERVIEW_PREPARATION"))and text(a.L("OVERVIEW_STATUS_ACTIVE",0,0)))
 assert(visible(155).note.text:find(a.L("READY"),1,true))
end
a.db.locale="enUS";render(false)
local engine=u.engine;local n,s,d=engine.Next,engine.State,engine.Dungeon
engine.Next=function()error("overview cannot rescan next actions")end
engine.State=function()error("overview cannot rescan states")end
engine.Dungeon=function()error("overview cannot rebuild plan")end
u:RefreshDetail();summary();visible(155);engine.Next,engine.State,engine.Dungeon=n,s,d
for _,kind in ipairs({"context","inspector","plan","locale","character","physical"})do
 render(false);local old=visible(155).scripts.OnClick;local inspect,char,plan,locale=u.InspectQuest,a.char,u.currentPlan,a.db.locale
 if kind=="context"then token={}
 elseif kind=="inspector"then u.InspectQuest=function()error("retired callback cannot call replacement inspector")end
 elseif kind=="plan"then u.currentPlan={}
 elseif kind=="locale"then a.db.locale="zhCN"
 elseif kind=="physical"then visible(155).questID=141
 else a.char={}end
 old();assert(u.quest==nil and routes==0,"retired "..kind.." step cannot inspect")
 u.InspectQuest,a.char,u.currentPlan,a.db.locale=inspect,char,plan,locale
end
render(false);local old=visible(155);local native=old.Show;local fired=false
old.Show=function(self,...)
 if not fired then fired=true;u:InspectQuest(166,true)end
 return native(self,...)
end
u:RefreshDetail();old.Show=native
assert(fired and u.quest==166 and not old:IsShown()and not old.enabled,"late old overview Show cannot revive a hidden action")
for _,phase in ipairs({"before","after"})do
 render(false);local fs=assert(text(a.L("OVERVIEW_STATUS_ACTIVE",0,0)));local setter=fs.SetText;local fired=false
 fs.SetText=function(self,value)
  if phase=="after"then setter(self,value)end
  if not fired then fired=true;active,ready=1654,1654;render(false)end
  if phase=="before"then setter(self,value)end
 end
 u:RefreshDetail();fs.SetText=setter
 assert(fired and fs.text==a.L("OVERVIEW_STATUS_ACTIVE",1,0),"late summary text must preserve the newer overview status")
 summary();visible(1654);active,ready=155,155
end
render(false);local originalL=a.L;local fired=false
a.L=function(key,...)
 if key=="OVERVIEW_STATUS_ACTIVE"and not fired then fired=true;u:InspectQuest(166,true)end
 return originalL(key,...)
end
u:RefreshDetail();a.L=originalL
assert(fired and u.quest==166 and not u.overviewBinding,"a retired localizer result cannot republish overview content")
render(false);local incomplete=u.currentPlan;incomplete.current=nil;u:RefreshDetail()
assert(not u.overviewBinding,"incomplete plans must keep the conservative existing overview")
for _,r in ipairs(u.actionInspectButtons)do assert(not r:IsShown()and not r.enabled)end
render(false);local oldBinding=summary();local modelOnly=setmetatable({oldBinding.model},{__mode="v"})
u:InspectQuest(166,true);u:Refresh();collectgarbage("collect");collectgarbage("collect")
assert(modelOnly[1]==nil and oldBinding.released and oldBinding.model==nil and not oldBinding.current(),
 "summary model and producer proofs retire with the normal map controller enabled")
render(false);local closed=summary();local retainedClose=visible(155).scripts.OnClick
u.frame:Hide();u.frame.scripts.OnHide();assert(u.overviewBinding==nil and closed.released and closed.model==nil)
retainedClose();assert(u.quest==nil and routes==0)
u.frame:Show();u:Refresh();summary()
local close=u.CloseDungeonMap;local reopened=false
u.CloseDungeonMap=function(self,...)
 local result=close(self,...)
 if not reopened then reopened=true;self.frame:Show();self.quest=nil;self:Refresh()end
 return result
end
u.frame:Hide();u.frame.scripts.OnHide();u.CloseDungeonMap=close
assert(reopened and u.frame:IsShown());summary();visible(155).scripts.OnClick();assert(u.quest==155 and routes==0)
-- The pre-existing map-button geometry registry owns its last engine independently.
-- Isolate the new summary's engine-release check with that optional control absent.
local mapOpener=u.OpenDungeonMap;u.OpenDungeonMap=nil
render(false);local b=summary();local weak=setmetatable({u.engine,b.model},{__mode="v"});local retained=visible(155).scripts.OnClick
u:InspectQuest(166,true);u:Refresh();collectgarbage("collect");collectgarbage("collect")
assert(weak[1]==nil and weak[2]==nil,"retired overview controls must not retain the old engine or model")
retained();assert(u.quest==166 and routes==0);u.OpenDungeonMap=mapOpener
print("Preparation overview UI: PASS (actual shared/held steps, root counts, ten locales, explicit inspection, retirement and no planner rescans)")
