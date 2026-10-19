-- History/navigation methods remain inert and belong to each loaded addon instance.
local loader=assert(loadfile("UI/QuestHistory.lua"))
local first,second={},{}
local effects=0
local oldCreate,oldLocale=CreateFrame,GetLocale
CreateFrame=function()effects=effects+1;error("loading history cannot create UI")end
GetLocale=function()effects=effects+1;error("loading history cannot query the client")end
loader("DungeonPro",first);loader("DungeonPro",second)
assert(effects==0 and first.UI==nil and second.UI==nil)
CreateFrame,GetLocale=oldCreate,oldLocale
local names={"ResetHistoryReading","HistoryOffsets","SetDetailTab","InspectQuest","CanReturnToOverview","BackQuest"}
local count=0;for _ in pairs(first.QuestHistory)do count=count+1 end
assert(count==#names and first.QuestHistory~=second.QuestHistory)
for _,name in ipairs(names)do assert(type(first.QuestHistory[name])=="function"and first.QuestHistory[name]~=second.QuestHistory[name])end
local function attach(a)
 a.char={};a.quests={[1]={id=1},[2]={id=2},[3]={id=3}}
 a.Clean=function(value,kind)
  if type(value)~=kind then return nil end
  if kind=="number"and(value~=value or value==math.huge or value==-math.huge)then return nil end
  return value
 end
 a.Read=function(fn,kind,...)
  if type(fn)~="function"then return nil end
  local ok,value=pcall(fn,...);if ok then return a.Clean(value,kind)end
 end
 local scroll={offset=0,GetVerticalScroll=function(self)return self.offset end,GetHeight=function()return 100 end}
 local ui={quest=1,dungeon={},frame={IsShown=function()return true end},detailScroll=scroll,
  detail={GetHeight=function()return 1000 end},detailHistory={},detailTab="quest",detailTabRevision={},detailTabOffsets={},
  engine={Current=function()return true end},rewardGeneration={},renderedQuest=1,rendered={},lists=0}
 for name,method in pairs(a.QuestHistory)do ui[name]=method end
 a.UI=ui
 ui.RefreshQuests=function(self)self.lists=self.lists+1 end
 ui.RefreshDetail=function(self)
  if self.detailTabQuest~=self.quest then
   self.detailTabQuest=self.quest;self.detailTab="quest";self.detailTabOffsets={};self.detailTabRevision={}
  end
  self.rewardGeneration={};self.renderedQuest=self.quest;self.rendered[#self.rendered+1]=self.quest
  return self.rewardGeneration
 end
 ui.WriteDetailScroll=function(self,region,value,current)
  if not current()then return false end;region.offset=value;return true
 end
 ui.detailTabQuest=1
 return ui
end
local a,b=attach(first),attach(second)
assert(a:SetDetailTab("sources"));a.detailScroll.offset=43
assert(a:InspectQuest(2,true));assert(#a.detailHistory==1 and a.detailHistory[1]==1)
assert(a:BackQuest()and a.quest==1 and a.detailTab=="sources"and a.detailScroll.offset==43)
assert(b.quest==1 and b.detailTab=="quest"and #b.detailHistory==0 and b.lists==0)
-- Borrowing a function from another addon must not bless this UI as its owner.
local own=b.SetDetailTab;b.SetDetailTab=first.QuestHistory.SetDetailTab
assert(not b:SetDetailTab("story")and b.detailTab=="quest")
b.SetDetailTab=own;assert(b:SetDetailTab("story")and b.detailTab=="story")
assert(a.detailTab=="sources")
-- Back is handled once its history entry is consumed, even if newer work wins.
assert(a:InspectQuest(2,true));local history=a.detailHistory;assert(#history==1)
local refresh=a.RefreshQuests;local fired=false;local rendered=#a.rendered
local search,preparation="unchanged filter",true;a.search,a.preparation=search,preparation
a.RefreshQuests=function(self)
 refresh(self)
 if not fired then fired=true;assert(self:InspectQuest(3,false));self.detailScroll.offset=9 end
end
assert(a:BackQuest()and fired and a.quest==3 and a.renderedQuest==3 and a.detailScroll.offset==9)
assert(#a.rendered==rendered+1 and a.rendered[#a.rendered]==3,"retired Back must not repaint its older destination")
assert(a.detailHistory==history and #history==1 and history[1]==1,"only the newer inspection appends history after the consumed Back")
assert(a.search==search and a.preparation==preparation)
assert(b.quest==1 and b.detailTab=="story"and #b.detailHistory==0)
print("Quest history module: PASS (inert load, six exports, two-addon ownership, reading restoration and handled reentry)")
