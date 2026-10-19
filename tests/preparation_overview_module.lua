-- The preparation view owns only its own addon instance and releasable render lease.
local modulePath=(...)or "UI/PreparationOverview.lua"
local chunk=assert(loadfile(modulePath))
local first,second={},{}
local nativeCalls=0
local savedCreate,savedLocale=CreateFrame,GetLocale
CreateFrame=function()nativeCalls=nativeCalls+1;error("module load cannot construct UI")end
GetLocale=function()nativeCalls=nativeCalls+1;error("module load cannot inspect the client")end
chunk("DungeonPro",first);chunk("DungeonPro",second)
assert(nativeCalls==0 and first.UI==nil and second.UI==nil and first.PreparationOverviewUI~=second.PreparationOverviewUI)
CreateFrame,GetLocale=savedCreate,savedLocale
local names={"ReleasePreparationOverview","ResetPreparationOverviewControls","RenderPreparationOverview"}
local count=0;for _ in pairs(first.PreparationOverviewUI)do count=count+1 end;assert(count==3)
for _,key in ipairs(names)do assert(type(first.PreparationOverviewUI[key])=="function"and first.PreparationOverviewUI[key]~=second.PreparationOverviewUI[key])end
local function attach(a)
 local u={actionInspectButtons={},overviewTexts={},includeUnavailable=false,frame={}}
 for key,fn in pairs(a.PreparationOverviewUI)do u[key]=fn end;a.UI=u
 a.Read=function(fn,kind,...)
  if type(fn)~="function"then return nil end
  local ok,value=pcall(fn,...);if ok and type(value)==kind then return value end
 end
 a.Clean=function(value,kind)if type(value)==kind then return value end end
 a.db={locale="enUS"};a.quests={};a.L=function(key)return key end
 u.CatalogLanguageKey=function()return "enUS"end
 u.InspectQuest=function()error("rendering cannot inspect a quest")end
 u.QuestListWrite=function(self,object,method,current,...)
  if not current()then return false end
  object[method](object,...);return current()
 end
 u.MakeRow=function()error("no rows without a valid published model")end
 u.LayoutRow=function()error("no layout without a valid published model")end
 return u
end
local one,two=attach(first),attach(second)
local function lease(u)
 local engine,model={},{}
 local b={engine=engine,model=model,modelCurrent=function()return true end,modelRaw=function()return true end,
  listCurrent=function()return true end,listRaw=function()return true end,plan={},titles={},presentation={}}
 local reads=0;b.base=function()reads=reads+1;return engine~=nil end
 b.current=function()return not b.released and b.base and b.base()or false end
 u.overviewBinding=b
 return b,setmetatable({engine,model},{__mode="v"}),function()return reads end
end
local b1,weak,reads=lease(one);local b2=lease(two)
local record={current=b1.current};local physical={record=record}
assert(record.current()and b2.current());local before=reads()
one:ReleasePreparationOverview()
assert(one.overviewBinding==nil and b1.released and not record.current()and reads()==before)
assert(two.overviewBinding==b2 and b2.current(),"releasing one addon cannot retire the other's lease")
assert(physical.record==record,"release preserves pooled native repair record identity")
collectgarbage("collect");collectgarbage("collect")
assert(weak[1]==nil and weak[2]==nil,"retained callable proof cannot retain the released model or engine")
for _,key in ipairs({"model","modelCurrent","modelRaw","base","listCurrent","listRaw","engine","plan","titles","presentation"})do assert(b1[key]==nil)end
local row={shown=true,enabled=true,overviewStep={},questID=155,scripts={OnClick=function()end}}
function row:Hide()self.shown=false end
function row:SetEnabled(value)self.enabled=value end
function row:SetScript(key,value)self.scripts[key]=value end
local text={shown=true,Hide=function(self)self.shown=false end}
one.actionInspectButtons={row};one.overviewTexts={text}
assert(not one:ResetPreparationOverviewControls(function()return false end)and row.shown and text.shown)
local reset,writer=one.ResetPreparationOverviewControls,one.QuestListWrite
for _,case in ipairs({{},{false},{"not a writer"},{{}}})do
 one.QuestListWrite=case[1]
 local ok,value=pcall(reset,one,function()return true end)
 assert(ok and value==false and row.shown and text.shown,"malformed reset writer must fail conservatively before native changes")
end
one.QuestListWrite=writer
one.ResetPreparationOverviewControls=function()error("replacement reset helper cannot run")end
assert(reset(one,function()return true end)==false and row.shown and text.shown,"retained reset must reject helper replacement")
one.ResetPreparationOverviewControls=reset
local fired=false
local ok,value=pcall(reset,one,function()fired=true;one.QuestListWrite=nil;return true end)
assert(fired and ok and value==false and row.shown and text.shown,"owner callback helper removal cannot cause a nil writer call")
one.QuestListWrite=writer
assert(one:ResetPreparationOverviewControls(function()return true end))
assert(not row.shown and not row.enabled and row.questID==nil and row.overviewStep==nil and row.scripts.OnClick==nil and not text.shown)
local calls=0
first.DungeonOverview={Get=function()calls=calls+1;return nil end}
one.dungeon={};one.engine={};one.currentPlan={engine=one.engine,dungeon=one.dungeon,includeUnavailable=false,
 current=function()return true end,rawCurrent=function()return true end}
local function presentation()
 return{label=function()error("invalid presentation must not allocate labels")end,setFont=function()end,measuredHeight=function()return 18 end,
 styles={body={},caption={},warning={}}}
end
for _,field in ipairs({"label","setFont","measuredHeight","styles"})do
 local p=presentation();p[field]=false
 assert(one:RenderPreparationOverview(function()return true end,392,21,p)==21)
end
assert(calls==0,"forged formatting helpers must not reach the producer or create native UI")
assert(one:RenderPreparationOverview(function()return false end,392,21,presentation())==nil and calls==0)
for _,field in ipairs({"presentation","writer","module"})do
 local p=presentation();local writer=one.QuestListWrite;local renderer=first.PreparationOverviewUI.RenderPreparationOverview
 first.DungeonOverview.Get=function(plan,dungeon,engine,current)
  calls=calls+1;assert(current())
  if field=="presentation"then p.label=function()error("retired label helper cannot run")end
  elseif field=="writer"then one.QuestListWrite=function()error("replacement writer cannot run")end
  else first.PreparationOverviewUI.RenderPreparationOverview=function()error("replacement module renderer cannot run")end end
  return{steps={},counts={},remainingSteps=0},function()return true end,function()return true end
 end
 assert(one:RenderPreparationOverview(function()return true end,392,21,p)==nil)
 assert(one.overviewBinding and not one.overviewBinding.current(),"callback-forged helpers retire the original render before any publication")
 one.QuestListWrite=writer;first.PreparationOverviewUI.RenderPreparationOverview=renderer;one:ReleasePreparationOverview()
end
assert(calls==3 and nativeCalls==0)
print("Preparation overview module: PASS (inert load, two-addon isolation, pooled reset/release GC and callback-forged helper retirement)")
