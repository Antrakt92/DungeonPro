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
local function material(x,id,item)
 x.draw(id);assert(x.u:SetDetailTab("sources"));x.drain()
 local row=assert(x.u.materialButtons[1]);local other=id==1654 and 1442 or 95042
 assert(row:IsShown()and row.enabled and row.questID==other and row.itemID==item)
 return row
end
case("settled obsolete material engine released after ordinary inspection and reopen",function()
 local x=fixture();local row=material(x,1654,7083);local record=assert(row.title.questListWrites.SetText)
 assert(record.current());local weak=setmetatable({x.u.engine},{__mode="v"})
 assert(x.u:InspectQuest(214,true));x.drain();assert(x.u:SetDetailTab("sources"));x.drain()
 x.u.frame:Hide();x.u.frame.scripts.OnHide();x.drain();x.u.frame:Show();x.u:Refresh();x.drain()
 assert(x.u.quest==214 and not row:IsShown()and not row.enabled and row.scripts.OnClick==nil)
 assert(not record.current()and row.title.questListWrites.SetText==record)
 record=nil;x.gc();local queued,tasks=x.settled();assert(queued==0 and tasks>0)
 assert(weak[1]==nil,"settled obsolete1654 engine retained by hidden material native record")
 assert(x.u.engine and x.u.engine:Current())
end)
case("current material identity is informational and explicit inspection remains exact",function()
 local x=fixture();local q=x.a.quests[1654];local sources=q.completionQuests
 local row=material(x,1654,7083);assert(q.requires==nil and q.classes[1]=="PALADIN")
 assert(x.routes()==0 and row.note.text:find("7083",1,true))
 row.scripts.OnClick(row);x.drain()
 assert(x.u.quest==1442 and x.u.renderedQuest==1442 and x.u.detailTab=="quest"and x.routes()==0)
 assert(q.completionQuests==sources and q.requires==nil and q.classes[1]=="PALADIN")
 row=material(x,95036,272448);row.scripts.OnClick(row);x.drain()
 assert(x.u.quest==95042 and x.u.renderedQuest==95042 and x.routes()==0)
end)
case("retained material click and text proof retire without old owner reads",function()
 local x=fixture();local row=material(x,1654,7083)
 local click,proof=row.scripts.OnClick,row.title.questListWrites.SetText.current
 assert(x.u:InspectQuest(214,true));x.drain()
 local reads=0;local read,clean=x.a.Read,x.a.Clean
 x.a.Read=function(...)reads=reads+1;return read(...)end
 x.a.Clean=function(...)reads=reads+1;return clean(...)end
 assert(not proof());click(row)
 x.a.Read,x.a.Clean=read,clean
 assert(x.u.quest==214 and x.routes()==0)
 assert(reads==0,"retired material callbacks still consult released source owner")
end)
local operations={{"title","SetText"},{"note","SetText"},{"row","Show"},{"row","Hide"},
 {"row","SetEnabled"},{"row","SetScript"}}
for _,op in ipairs(operations)do for _,after in ipairs({false,true})do
 for _,destination in ipairs({95036,214})do
 local part,method=op[1],op[2]
 case(part.."."..method..(after and " AFTER"or" BEFORE").." newer "..destination,function()
  local x=fixture();local row=material(x,1654,7083);local object=part=="row"and row or row[part]
  local native=object[method];local fired=false;local newest
  local function replace()
   if fired then return end;fired=true
   assert(x.u:InspectQuest(destination,true));assert(x.u:SetDetailTab("sources"));x.drain()
   newest={title=row.title.text,note=row.note.text,visible=row:IsShown(),enabled=row.enabled,
    id=row.questID,item=row.itemID,click=row.scripts.OnClick,height=row.height}
  end
  object[method]=function(self,...)
   if not after then replace()end
   local result=native(self,...)
   if after then replace()end
   return result
  end
  if method=="Hide"then assert(x.u:InspectQuest(214,true))else x.u:RefreshDetail()end
  x.drain()
  assert(fired and newest,"native material callback must actually fire")
  assert(x.u.quest==destination and x.u.renderedQuest==destination and x.u.detailTab=="sources")
  assert(row.title.text==newest.title and row.note.text==newest.note and row:IsShown()==newest.visible
   and row.enabled==newest.enabled and row.questID==newest.id and row.itemID==newest.item
   and row.scripts.OnClick==newest.click and row.height==newest.height,"old native tail overwrote newer material state")
  if destination==95036 then
   assert(row.questID==95042 and row.itemID==272448 and row:IsShown()and row.enabled)
   row.scripts.OnClick(row);x.drain();assert(x.u.quest==95042 and x.routes()==0)
  else assert(not row:IsShown()and not row.enabled and row.scripts.OnClick==nil and x.routes()==0)end
  object[method]=native
 end)
 end
end end
print("Material lifecycle regression: "..passed.." PASS / "..failed.." FAIL")
assert(failed==0,"material lifecycle regression failures: "..failed)
