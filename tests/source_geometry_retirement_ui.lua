-- Native control records must release source ownership without dropping newest tail repairs.
local cases=0
local function fixture(mapped)
 local f=assert(loadfile("tests/client_ui.lua"))("fixture")
 local a,u=f.addon,f.addon.UI
 issecretvalue=function()return false end;GetLocale=function()return "enUS"end
 UnitLevel=function()return 60 end;UnitClass=function()return "Mage","MAGE",8 end
 UnitFactionGroup=function()return "Alliance"end;C_Timer={After=function()end}
 C_QuestLog.IsOnQuest=function()return false end;C_QuestLog.ReadyForTurnIn=function()return false end
 local routes={};a.Navigation.Start=function(action)routes[#routes+1]=action;return true end
 f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle()
 local brd;for _,d in ipairs(a.dungeons)do if d.key=="brd"then brd=d end end;assert(brd)
 if mapped then for _,id in ipairs({3801,3802})do
  local point=a.quests[id].startAlternatives[1]
  -- Controlled native navigation shape, not a new catalogue position observation.
  point.mapID,point.x,point.y=1418,10,20
 end end
 u.dungeon,u.quest,u.includeUnavailable,u.range=brd,3801,true,false;u:Refresh();assert(u:SetDetailTab("sources"))
 return a,u,routes
end
local groups=0
local function select(u,key)
 for _,card in ipairs(u.cards)do if card:IsShown()and card.entranceDungeon and card.entranceDungeon.key==key then
  assert(card.scripts.OnClick);card.scripts.OnClick(card);assert(u.dungeon.key==key);return
 end end
 error("actual dungeon card missing: "..key)
end
local function report(u,id)
 select(u,id==971 and"bfd"or"wc");assert(u:InspectQuest(id,true));assert(u:SetDetailTab("sources"))
 local toggle=assert(u.reportedToggles[1]);assert(toggle:IsShown());toggle.scripts.OnClick()
 assert(u.reportedRows[1]:IsShown())
end
local function setup(kind)
 local a,u,routes=fixture(false)
 if kind=="alternative"then select(u,"brd");u:InspectQuest(3801,true);u:SetDetailTab("sources")
 else report(u,971)end
 local row=kind=="alternative"and u.giverButtons[1]or kind=="toggle"and u.reportedToggles[1]or u.reportedRows[1]
 return a,u,routes,row
end
local function latest(u,kind)
 if kind=="alternative"then select(u,"zf");u:InspectQuest(2933,true);u:SetDetailTab("sources")
 else report(u,1490)end
end
local function geometry(object)
 return{height=object:GetHeight(),point=object.point and{unpack(object.point)}}
end
local function same(object,expected)
 assert(object:GetHeight()==expected.height,"current source geometry must retain height")
 assert(object.point and expected.point,"current source geometry must retain an anchor")
 for key,value in next,expected.point do assert(rawequal(rawget(object.point,key),value),"current source geometry must retain latest point")end
 for key,value in next,object.point do assert(rawequal(rawget(expected.point,key),value),"current source geometry must not add anchor arguments")end
end
for _,kind in ipairs({"reported","toggle","alternative"})do
 for _,part in ipairs({"row","title","note"})do
  for _,method in ipairs({"ClearAllPoints","SetPoint"})do
   for _,phase in ipairs({"before","after"})do
    local a,u,routes,row=setup(kind);local target=part=="row"and row or row[part]
    local native=target[method];local fired,expected=false
    target[method]=function(self,...)
     local hit=not fired
     local function replace()fired=true;latest(u,kind);expected=geometry(target)end
     if hit and phase=="before"then replace()end
     local result=native(self,...)
     if hit and phase=="after"then replace()end
     return result
    end
    u:RefreshDetail();target[method]=native
    assert(fired and expected and u.detailTab=="quest"and row:IsShown()and #routes==0)
    same(target,expected)
    assert(row.enabled and row.scripts.OnClick,"latest exact source remains usable")
    if kind~="toggle"then
     row.scripts.OnClick();assert(#routes==1 and routes[1].id==(kind=="alternative"and 2933 or 1490),"source route must retain its exact current quest")
     if kind=="alternative"then assert(routes[1].place==a.quests[2933].startAlternatives[1])
     else
      local expectedPoint=a.quests[1490].start.reportedLocations[1]
      assert(routes[1].place.npcID==a.quests[1490].start.npcID)
      for _,key in ipairs({"mapID","x","y"})do assert(routes[1].place[key]==expectedPoint[key],"reported route keeps exact native point")end
     end
    end
    groups=groups+1
   end
  end
 end
end
-- Height setters and native measurement getters already have current checks.
for _,kind in ipairs({"reported","toggle","alternative"})do
 for _,method in ipairs({"SetHeight","GetStringHeight"})do for _,phase in ipairs({"before","after"})do
  local a,u,routes,row=setup(kind);local target=method=="GetStringHeight"and row.title or row
  local native=target[method];local fired,expected=false
  target[method]=function(self,...)
   local hit=not fired
   local function replace()fired=true;latest(u,kind);expected=geometry(row)end
   if hit and phase=="before"then replace()end
   local result=native(self,...)
   if hit and phase=="after"then replace()end
   return result
  end
  u:RefreshDetail();target[method]=native;assert(fired and row:IsShown()and #routes==0);same(row,expected)
  groups=groups+1
 end end
end
-- Reopening, locale replacement and a second newer render during anchor restore.
for _,transition in ipairs({"reopen","locale","twice-before","twice-after"})do
 local a,u,routes,row=setup("reported");local clear,point=row.ClearAllPoints,row.SetPoint
 local stage,expected="initial",nil
 row.ClearAllPoints=function(self,...)
  if stage~="initial"then return clear(self,...)end
  stage="nested"
  if transition=="reopen"then u.frame:Hide();u.frame.scripts.OnHide();u.frame:Show()end
  if transition=="locale"then a.db.locale="ruRU";u:Refresh()end
  report(u,1490);expected=geometry(row)
  local result=clear(self,...);stage="restore";return result
 end
 row.SetPoint=function(self,...)
  local hit=stage=="restore"and transition:find("twice",1,true)
  if hit then stage="final"end
  if hit and transition=="twice-before"then report(u,971);expected=geometry(row)end
  local result=point(self,...)
  if hit and transition=="twice-after"then report(u,971);expected=geometry(row)end
  return result
 end
 u:RefreshDetail();row.ClearAllPoints,row.SetPoint=clear,point
 assert(stage~="initial"and row:IsShown()and u.detailTab=="quest"and #routes==0,transition.." stage="..stage.." shown="..tostring(row:IsShown()).." tab="..tostring(u.detailTab).." quest="..tostring(u.quest));same(row,expected)
 assert(u.quest==(transition:find("twice",1,true)and 971 or 1490))
 groups=groups+1
end
-- Objective-container custom text remains intact while geometry shares owned keys.
for _,part in ipairs({"row","title","note"})do
 for _,phase in ipairs({"before","after"})do
  local a,u,routes=fixture(false);u:InspectQuest(1221,true);u:SetDetailTab("sources")
  local row=assert(u.objectiveContainerButtons[1]);assert(row:IsShown())
  local target=part=="row"and row or row[part];local native=target.ClearAllPoints;local fired,expected=false
  target.ClearAllPoints=function(self,...)
   local hit=not fired
   local function replace()
    fired=true;u.frame:Hide();u.frame.scripts.OnHide();u.frame:Show();a.db.locale="ruRU";u:Refresh();u:SetDetailTab("sources");expected=geometry(target)
   end
   if hit and phase=="before"then replace()end
   local result=native(self,...)
   if hit and phase=="after"then replace()end
   return result
  end
  u:RefreshDetail();target.ClearAllPoints=native
  assert(fired and u.quest==1221 and row:IsShown()and row.enabled and row.title.text and row.note.text and #routes==0);same(target,expected)
  row.scripts.OnClick();assert(#routes==1 and routes[1].id==1221)
  groups=groups+1
 end
end
-- Native records stay physical, but obsolete source guards no longer own engines.
do
 local a,u,routes,row=setup("reported")
 local registry,record=row.questListWrites,assert(row.questListWrites.SetPoint)
 local weak=setmetatable({u.engine},{__mode="v"})
 u:InspectQuest(5724,true);u.frame:Hide();u.frame.scripts.OnHide();u.frame:Show();u:Refresh()
 collectgarbage("collect");collectgarbage("collect")
 assert(weak[1]==nil and row.questListWrites==registry and not record.current())
 local clean,reads=a.Clean,0;a.Clean=function(...)reads=reads+1;return clean(...)end
 assert(not record.current()and reads==0);a.Clean=clean
 groups=groups+1
end
-- Optional anchor restore cannot dispatch a setter replaced during its owner proof.
for _,mutation in ipairs({"native","record"})do for _,when in ipairs({"initial","proof"})do
 local a,u,routes=fixture(false);local reader=a.Read
 local armed,fired,foreignCalls,record,owner=false,false,0
 local function foreign()foreignCalls=foreignCalls+1 end
 a.Read=function(fn,...)
  local result=reader(fn,...)
  if armed and when=="proof"and fn==owner and not fired then
   fired=true
   if mutation=="native"then u.reportedRows[1].SetPoint=foreign else record.setter=foreign end
  end
  return result
 end
 u:Refresh();report(u,971)
 local row=u.reportedRows[1];local clear,native=row.ClearAllPoints,row.SetPoint;local replaced=false
 row.ClearAllPoints=function(self,...)
  if replaced then return clear(self,...)end
  replaced=true;report(u,1490)
  record=self.questListWrites.SetPoint;owner=record.current
  local result=clear(self,...)
  if when=="initial"then
   fired=true;if mutation=="native"then self.SetPoint=foreign else record.setter=foreign end
  end
  armed=true;return result
 end
 u:RefreshDetail();row.ClearAllPoints=clear
 assert(replaced and fired and foreignCalls==0 and row.questListWrites.SetPoint==record,
  "changed native/record setter must abort optional anchor restore before unknown dispatch")
 armed=false;row.SetPoint=native;record.setter=native
 u:RefreshDetail();assert(row:IsShown()and row.enabled and row.point and u.quest==1490)
 row.scripts.OnClick();assert(#routes==1 and routes[1].id==1490,"fresh safe anchor recovers its actual source route")
 groups=groups+1
end end
-- The delegated guard must revalidate setter capabilities on writer pre/post callbacks too.
for _,mutation in ipairs({"native","record"})do for _,at in ipairs({2,3})do
 local a,u,routes,row=setup("reported");local clear,native=row.ClearAllPoints,row.SetPoint
 local replaced,record,calls,fired,foreignCalls=false,nil,0,false,0
 local function foreign()foreignCalls=foreignCalls+1 end
 row.ClearAllPoints=function(self,...)
  if replaced then return clear(self,...)end
  replaced=true;report(u,1490);record=self.questListWrites.SetPoint
  local original=record.current
  record.current=function()
   calls=calls+1;local valid=original()
   if calls==at then fired=true;if mutation=="native"then row.SetPoint=foreign else record.setter=foreign end end
   return valid
  end
  return clear(self,...)
 end
 u:RefreshDetail();row.ClearAllPoints=clear
 assert(replaced and fired and foreignCalls==0,"writer pre/post callback cannot introduce an unowned setter")
 local publication=row.questListWrites.SetPoint
 if publication~=record then assert(not publication.current(),"failed repair publication must retain only a retired guard")end
 row.SetPoint=native;record.setter=native;u:RefreshDetail()
 assert(row:IsShown()and row.enabled and row.point and u.quest==1490);row.scripts.OnClick()
 assert(#routes==1 and routes[1].id==1490);groups=groups+1
end end
-- A writer failure, later helper change or newer render cannot bless an abandoned publication.
for _,mode in ipairs({"false","throw","helper","newer"})do
 local a,u,routes=fixture(false);local writer=u.QuestListWrite;local armed,fired,abandoned,newerGeometry=false,false,nil,nil
 u.QuestListWrite=function(self,object,method,current,...)
  local result=writer(self,object,method,current,...)
  if armed and not fired and object==self.reportedRows[1]and method=="SetPoint"then
   fired=true;armed=false;abandoned=object.questListWrites.SetPoint
   if mode=="false"then return false
   elseif mode=="throw"then error("controlled failed anchor writer")
   elseif mode=="helper"then self.QuestListWrite=writer
   else report(self,971);newerGeometry=geometry(self.reportedRows[1])end
  end
  return result
 end
 u:Refresh();report(u,971)
 local row=u.reportedRows[1];local clear=row.ClearAllPoints;local replaced=false
 row.ClearAllPoints=function(self,...)
  if replaced then return clear(self,...)end
  replaced=true;report(u,1490);local result=clear(self,...);armed=true;return result
 end
 u:RefreshDetail();row.ClearAllPoints=clear
 assert(fired and abandoned and not abandoned.current()and row.sourceGeometryRepair==nil,
  "rejected writer or superseding state must discard temporary validation captures")
 if mode=="newer"then
  assert(u.quest==971 and row:IsShown()and row.questListWrites.SetPoint.current())
  same(row,assert(newerGeometry,"latest source geometry precedes the retired native tail"))
 end
 u.QuestListWrite=writer;u:RefreshDetail();assert(row:IsShown()and row.point and #routes==0)
 groups=groups+1
end
-- Successful guards remain usable by a future generic native repair but drop raw snapshots.
do
 local a,u,routes,row=setup("reported");local clear,native=row.ClearAllPoints,row.SetPoint;local replaced,latestGeometry=false,nil
 local weak=setmetatable({},{__mode="v"})
 row.ClearAllPoints=function(self,...)
  if replaced then return clear(self,...)end
  replaced=true;report(u,1490);latestGeometry=geometry(self)
  local previous=self.questListWrites.SetPoint;weak.point,weak.args=previous,previous.args
  return clear(self,...)
 end
 u:RefreshDetail();row.ClearAllPoints=clear
 local publication=assert(row.questListWrites.SetPoint);local proof=publication.current
 assert(proof()and row.sourceGeometryRepair==nil)
 local name,cell=debug.getupvalue(proof,1)
 assert(name=="cell"and type(cell)=="table"and debug.getupvalue(proof,2)==nil,
  "persisted repair proof must capture only its delegated cell")
 weak.engine=u.engine;collectgarbage("collect");collectgarbage("collect")
 assert(weak.point==nil and weak.args==nil and weak.engine==u.engine,
  "successful guard must release raw publication snapshots while keeping only intentional current ownership")
 local calls=0
 row.SetPoint=function(self,...)
  self.questListWrites.SetPoint=publication;return native(self,...)
 end
 local function stale()calls=calls+1;return calls==1 end
 assert(not u:QuestListWrite(row,"SetPoint",stale,"TOPLEFT",0,-999))
 row.SetPoint=native
 assert(proof(),"persisted guard must still repair a later native tail after its temporary busy token is cleared")
 same(row,assert(latestGeometry,"new source geometry precedes the first retired clear"))
 u:InspectQuest(5724,true);u.frame:Hide();u.frame.scripts.OnHide();u.frame:Show();u:Refresh()
 collectgarbage("collect");collectgarbage("collect")
 assert(weak.engine==nil and not proof(),"externally retained repaired record must release its obsolete source engine")
 local reader,reads=a.Read,0;a.Read=function(...)reads=reads+1;return reader(...)end
 assert(not proof()and reads==0,"retired delegated guard cannot call former providers");a.Read=reader
 groups=groups+1
end
-- Two nested retired native clears may delegate twice, but retain no strict snapshots.
do
 local a,u,routes,row=setup("reported");local clear=row.ClearAllPoints;local stage=0;local originalOwner,latestGeometry
 row.ClearAllPoints=function(self,...)
  if stage==0 then stage=1;report(u,1490)
  elseif stage==1 then stage=2;report(u,971);latestGeometry=geometry(row);originalOwner=row.questListWrites.SetPoint.current end
  return clear(self,...)
 end
 u:RefreshDetail();row.ClearAllPoints=clear
 assert(stage==2 and u.quest==971 and row:IsShown()and #routes==0)
 same(row,assert(latestGeometry,"innermost source geometry survives both retired clears"))
 local proof=row.questListWrites.SetPoint.current;assert(proof())
 local firstName,firstCell=debug.getupvalue(proof,1)
 local secondName,secondCell=debug.getupvalue(firstCell.current,1)
 assert(firstName=="cell"and secondName=="cell"and secondCell.current==originalOwner,
  "each successful nested repair must drop its strict validator and delegate only to the prior light owner")
 local weak=setmetatable({u.engine},{__mode="v"})
 u:InspectQuest(5724,true);u.frame:Hide();u.frame.scripts.OnHide();u.frame:Show();u:Refresh()
 collectgarbage("collect");collectgarbage("collect")
 assert(weak[1]==nil and not proof(),"one source-lease retirement must sever the nested delegated owner chain")
 groups=groups+1
end
print("Source geometry ownership PASS",groups,"native geometry/getter/reopen/locale/repair/custom-text/GC cases")
