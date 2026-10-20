local passed,failed=0,0
local function case(name,fn)
 local ok,err=pcall(fn)
 if ok then passed=passed+1;print("PASS",name)else failed=failed+1;print("FAIL",name,err)end
end
local function fixture()
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

 local routes=0
 a.Navigation.Start=function()routes=routes+1;return true end
 a.Navigation.Map=function()routes=routes+1;return true end
 return {a=a,u=u,draw=draw,drain=drain,gc=gc,methods=f.methods,routes=function()return routes end,
  settled=function()return #queue,tasks end}
end
local function retiredSelectors(x)
 for _,button in ipairs(x.u.materialButtons or{})do
  assert(not button:IsShown()and not button.enabled and button.scripts.OnClick==nil,
   "neutral material context must not leave a duplicate quest selector")
 end
end
local function visibleMaterial(x,id,item)
 local other=id==1654 and 1442 or 95042
 local declared=false
 for _,entry in ipairs(x.a.quests[id].completionQuests or{})do
  if entry.id==other and entry.itemID==item then declared=true end
 end
 assert(declared,"neutral material text retains its exact typed completion quest and item relationship")
 local title,note
 for i,field in ipairs(x.u.details)do if field:IsShown()and field.text==x.a.QuestName(other)and field.detailStyle=="caption"then
  title=field;note=x.u.details[i+1];break
 end end
 assert(title and note and note:IsShown()and note.text:find(tostring(item),1,true),"actual material quest and item identity remain paired")
 assert(title.detailTextBinding.quest==id and note.detailTextBinding.quest==id and
  title.detailTextBinding.current()and note.detailTextBinding.current(),"material text belongs to the selected canonical definition")
 assert((not title.scripts or not title.scripts.OnClick)and(not note.scripts or not note.scripts.OnClick),
  "material FontStrings are information rather than secondary selectors")
 retiredSelectors(x)
 return{title=title,note=note,other=other,item=item}
end
local function material(x,id,item)
 x.draw(id);assert(x.u:SetDetailTab("sources")and x.u.detailTab=="quest");x.drain()
 return visibleMaterial(x,id,item)
end
local function snapshot(pair)
 local result={}
 for _,part in ipairs({"title","note"})do
  local field=pair[part];local point={}
  for i,v in ipairs(field.point or{})do point[i]=v end
  result[part]={text=field.text,visible=field:IsShown(),width=field.width,height=field.height,point=point,binding=field.detailTextBinding}
 end
 return result
end
local function same(pair,expected)
 for _,part in ipairs({"title","note"})do
  local field,prior=pair[part],expected[part]
  assert(field.text==prior.text and field:IsShown()==prior.visible and field.width==prior.width and field.height==prior.height and
   field.detailTextBinding==prior.binding,"old native material tail overwrote newer text, visibility or publication")
  if prior.visible then for i,v in ipairs(prior.point)do assert(field.point and field.point[i]==v,"old native material tail overwrote newer visible anchor")end end
 end
end
case("settled obsolete neutral material engine released after inspection and reopen",function()
 local x=fixture();local row=material(x,1654,7083);local record=assert(row.title.detailTextBinding)
 local proof=record.current;assert(proof());local weak=setmetatable({x.u.engine},{__mode="v"})
 assert(x.u:InspectQuest(214,true));x.drain();assert(x.u:SetDetailTab("sources"));x.drain()
 x.u.frame:Hide();x.u.frame.scripts.OnHide();x.drain();x.u.frame:Show();x.u:Refresh();x.drain()
 assert(x.u.quest==214 and not row.title:IsShown()and not row.note:IsShown());retiredSelectors(x)
 assert(not proof(),"retained neutral text proof must retire")
 record=nil;proof=nil;x.gc();local queued,tasks=x.settled();assert(queued==0 and tasks>0)
 assert(weak[1]==nil,"settled obsolete1654 engine retained by a neutral material native publication")
 assert(x.u.engine and x.u.engine:Current())
end)
case("material provenance stays informational and explicit inspection API remains exact",function()
 local x=fixture();local q=x.a.quests[1654];local sources=q.completionQuests
 local row=material(x,1654,7083);assert(q.requires==nil and q.classes[1]=="PALADIN")
 assert(x.routes()==0 and row.note.text:find("7083",1,true))
 assert(x.u:InspectQuest(1442,true));x.drain()
 assert(x.u.quest==1442 and x.u.renderedQuest==1442 and x.u.detailTab=="quest"and x.routes()==0)
 assert(q.completionQuests==sources and q.requires==nil and q.classes[1]=="PALADIN")
 material(x,95036,272448);assert(x.u:InspectQuest(95042,true));x.drain()
 assert(x.u.quest==95042 and x.u.renderedQuest==95042 and x.routes()==0)
end)
case("retained neutral material proof retires without old owner reads",function()
 local x=fixture();local row=material(x,1654,7083);local proof=row.title.detailTextBinding.current
 assert(x.u:InspectQuest(214,true));x.drain()
 local reads=0;local read,clean=x.a.Read,x.a.Clean
 x.a.Read=function(...)reads=reads+1;return read(...)end
 x.a.Clean=function(...)reads=reads+1;return clean(...)end
 assert(not proof())
 x.a.Read,x.a.Clean=read,clean
 assert(x.u.quest==214 and x.routes()==0)
 assert(reads==0,"retired neutral material proof consults a released source owner")
 retiredSelectors(x)
end)
local operations={{"title","SetText"},{"note","SetText"},{"title","Show"},{"title","Hide"},
 {"title","SetWidth"},{"title","ClearAllPoints"},{"title","SetPoint"}}
for _,op in ipairs(operations)do for _,after in ipairs({false,true})do
 for _,destination in ipairs({95036,214})do
 local part,method=op[1],op[2]
 case(part.."."..method..(after and" AFTER"or" BEFORE").." newer "..destination,function()
  local x=fixture();local row=material(x,1654,7083);local object=row[part]
  local native=object[method];local fired=false;local newest
  local function replace()
   if fired then return end;fired=true
   assert(x.u:InspectQuest(destination,true));assert(x.u:SetDetailTab("sources"));x.drain()
   newest=snapshot(row)
  end
  object[method]=function(self,...)
   if not after then replace()end
   local result=native(self,...)
   if after then replace()end
   return result
  end
  if method=="Hide"then assert(x.u:InspectQuest(214,true))else x.u:RefreshDetail()end
  x.drain()
  assert(fired and newest,"native neutral material callback must actually fire")
  assert(x.u.quest==destination and x.u.renderedQuest==destination and x.u.detailTab=="quest")
  same(row,newest);retiredSelectors(x)
  if destination==95036 then visibleMaterial(x,95036,272448)
  else assert(not row.title:IsShown()and not row.note:IsShown(),"unneeded material fields remain hidden")end
  assert(x.routes()==0,"neutral material native publication never navigates or selects a supplier")
  object[method]=native
 end)
 end
end end
-- A newer visible publication changes real measured geometry before an old native tail.
for _,method in ipairs({"SetPoint","ClearAllPoints"})do
 case(method.." BEFORE newer visible same-quest material geometry",function()
  local x=fixture();local row=material(x,1654,7083);local field=row.title
  local native=field[method];local fired,newest=false,nil
  local header=x.u.details[1];local measure=header.GetStringHeight
  field[method]=function(self,...)
   if not fired then
    fired=true;header.GetStringHeight=function()return 90 end
    x.u:RefreshDetail();x.drain();visibleMaterial(x,1654,7083);newest=snapshot(row)
   end
   return native(self,...)
  end
  x.u:RefreshDetail();x.drain();field[method]=native;header.GetStringHeight=measure
  assert(fired and newest and newest.title.visible and newest.note.visible)
  same(row,newest);assert(x.u.quest==1654 and x.routes()==0)
 end)
end
print("Neutral material lifecycle regression: "..passed.." PASS / "..failed.." FAIL")
assert(failed==0,"neutral material lifecycle regression failures: "..failed)
