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
assert(a:BackQuest()and a.quest==1 and a.detailTab=="quest"and a.detailScroll.offset==43)
assert(b.quest==1 and b.detailTab=="quest"and #b.detailHistory==0 and b.lists==0)
-- Borrowing a function from another addon must not bless this UI as its owner.
local own=b.SetDetailTab;b.SetDetailTab=first.QuestHistory.SetDetailTab
assert(not b:SetDetailTab("story")and b.detailTab=="quest")
b.SetDetailTab=own;assert(b:SetDetailTab("story")and b.detailTab=="quest")
assert(a.detailTab=="quest")
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
assert(b.quest==1 and b.detailTab=="quest"and #b.detailHistory==0)
print("Quest history module: PASS (inert load, six exports, two-addon ownership, reading restoration and handled reentry)")

-- A compatibility call cannot hide any section or spend reading position.
do
 local u=attach(first);local count=#u.rendered;u.detailScroll.offset=87
 local revision,offsets=u.detailTabRevision,u.detailTabOffsets
 for _,key in ipairs({"quest","sources","story"})do
  assert(u:SetDetailTab(key)and u.detailTab=="quest"and u.detailScroll.offset==87 and #u.rendered==count)
  assert(u.detailTabRevision==revision and u.detailTabOffsets==offsets)
 end
 assert(not u:SetDetailTab("hidden")and #u.rendered==count)
 u.detailTab="story";u.detailTabOffsets={story=999,sources=888}
 assert(u:SetDetailTab("sources")and u.detailTab=="quest"and next(u.detailTabOffsets)==nil and u.detailScroll.offset==87)
end
-- Old history entries may restore their measured offset, never an old mode or mode offset.
do
 local u=attach(first);u.quest=2;u.detailTabQuest=2
 u.detailHistory={1};local old={story=777,sources=666};local offsets=u:HistoryOffsets()
 offsets[1]={quest=1,character=first.char,offset=43,tab="story",tabOffsets=old}
 assert(u:BackQuest()and u.quest==1 and u.detailTab=="quest"and u.detailScroll.offset==43)
 assert(next(u.detailTabOffsets)==nil and u.detailTabOffsets~=old)
end
-- New entries are stream-only and source-focus stays an explicit renderer intent.
do
 local u=attach(first);u.detailScroll.offset=64
 local refresh=u.RefreshDetail;local received
 u.RefreshDetail=function(self,focus)received=focus;return refresh(self)end
 assert(u:InspectQuest(2,true,true)and received==true)
 local saved=u:HistoryOffsets()[1]
 assert(saved.quest==1 and saved.offset==64 and saved.character==first.char and saved.tab==nil and saved.tabOffsets==nil)
 local history=u.detailHistory;local n=#history
 assert(u:InspectQuest(2,true,true)and #history==n and u.detailHistory==history)
end
-- Another character cannot inherit a saved pixel position; history reset leaves IDs but removes readings.
do
 local u=attach(first);u.detailScroll.offset=57;assert(u:InspectQuest(2,true))
 local character=first.char;first.char={};u.detailScroll.offset=9
 assert(u:BackQuest()and u.detailScroll.offset==9 and u.detailTab=="quest")
 first.char=character
 local history=u.detailHistory;history[1]=1;u:ResetHistoryReading()
 assert(u.detailHistory==history and history[1]==1 and u.detailOffsets==nil and u.detailOffsetsOwner==nil)
end
-- Same-destination list drift rolls back the whole tentative navigation and reading entry.
do
 local u=attach(first);u.detailScroll.offset=43;assert(u:InspectQuest(2,true));u.detailScroll.offset=60
 local history=u.detailHistory;local offsets=u:HistoryOffsets();local saved=offsets[1]
 local tabOffsets,revision=u.detailTabOffsets,u.detailTabRevision
 local nav=u.detailNavigationRevision;local native=u.RefreshQuests;local fired=false
 u.RefreshQuests=function(self)native(self);if not fired then fired=true;self.includeUnavailable=true end end
 assert(u:BackQuest()and fired and u.quest==2 and u.renderedQuest==2 and u.detailScroll.offset==60)
 assert(u.detailHistory==history and #history==1 and history[1]==1 and offsets[1]==saved)
 assert(u.detailTabOffsets==tabOffsets and u.detailTabRevision==revision and u.detailNavigationRevision==nav and u.includeUnavailable==true)
end
-- Bounded history shifts IDs and their own reading records together.
do
 local u=attach(first)
 for id=4,25 do first.quests[id]={id=id}end
 for id=2,25 do u.detailScroll.offset=id*3;assert(u:InspectQuest(id,true))end
 local offsets=u:HistoryOffsets();assert(#u.detailHistory==20 and u.detailHistory[1]==5 and u.detailHistory[20]==24)
 assert(offsets[1].quest==5 and offsets[20].quest==24 and offsets[21]==nil)
end
-- Helper replacement during the compatibility sanitizer retires the old call.
do
 local u=attach(first);local clean=first.Clean;local original=u.SetDetailTab;local fired=false
 first.Clean=function(v,k)if not fired then fired=true;u.quest=3 end;return clean(v,k)end
 assert(not original(u,"sources")and u.quest==3)
 first.Clean=clean
end
print("PASS single-stream history aliases, legacy normalization, reading ownership, source focus and rollback")

-- Callback state replacement cannot authorize an older compatibility alias.
do
 local u=attach(first);local clean=first.Clean;local original=u.SetDetailTab;local fired=false
 first.Clean=function(v,k)if not fired then fired=true;u.detailTab="story";u.detailNavigationRevision={}end;return clean(v,k)end
 assert(not original(u,"sources")and u.detailTab=="story")
 first.Clean=clean
end
-- Restored stream offsets clamp to the current content and viewport.
do
 local u=attach(first);u.quest=2;u.detailTabQuest=2;u.detailHistory={1}
 local offsets=u:HistoryOffsets();offsets[1]={quest=1,character=first.char,offset=900,tab="sources"}
 u.detail.GetHeight=function()return 180 end
 assert(u:BackQuest()and u.detailTab=="quest"and u.detailScroll.offset==80)
end
