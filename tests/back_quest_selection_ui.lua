-- Back restores the inspected card and its selected middle-row presentation together.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return"enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();a.db.locale="enUS";ui.includeUnavailable=true
local dungeon
for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do if id==166 then dungeon=d end end end
assert(dungeon and a.quests[166]and a.quests[141])
local routes=0
a.Navigation={Start=function()routes=routes+1 end,Map=function()routes=routes+1 end}
ui.detailScroll.GetHeight=function()return 90 end
local total=0
local function selection()
 local ids={}
 for _,row in ipairs(ui.rows)do
  if row:IsShown()and row.questTreeSelected then ids[#ids+1]=row.questID or row.anchorQuestID end
 end
 return ids
end
local function selected(id)
 local ids=selection()
 assert(#ids==1 and ids[1]==id,"restored detail must own the only selected middle quest row")
end
local function reset(id,expanded)
 ui:ResetHistoryReading();ui.detailHistory={};ui.dungeon,ui.quest=dungeon,id
 ui.questTreeRoot,ui.questTreeDungeon=expanded and 166 or nil,expanded and dungeon or nil
 ui.preparation=false;ui.search="";ui:Refresh()
 assert(ui.quest==id and ui.renderedQuest==id)
end
local function test(name,fn)fn();assert(routes==0);total=total+1;print("PASS "..name)end

test("Back restores actual Deadmines selection, Sources reading and filter state",function()
 reset(166,true);assert(ui:SetDetailTab("sources"));ui.detailScroll:SetVerticalScroll(31)
 local tree,history,character=ui.questTreeRoot,ui.detailHistory,a.char
 local mine,range,search,preparation=ui.includeUnavailable,ui.range,ui.search,ui.preparation
 assert(ui:InspectQuest(141,true));selected(141);assert(#history==1)
 assert(ui:BackQuest())
 assert(ui.quest==166 and ui.renderedQuest==166 and ui.detailTab=="sources"and ui.detailScroll:GetVerticalScroll()==31)
 assert(ui.detailHistory==history and #history==0 and a.char==character and ui.questTreeRoot==tree)
 assert(ui.includeUnavailable==mine and ui.range==range and ui.search==search and ui.preparation==preparation)
 selected(166)
end)

test("Back to an inspected support definition clears the old visible selection without inventing a row",function()
 reset(141,false);assert(ui:SetDetailTab("sources"));ui.detailScroll:SetVerticalScroll(27)
 for _,row in ipairs(ui.rows)do assert(not(row:IsShown()and row.questID==141),"support is not an invented flat dungeon target")end
 assert(ui:InspectQuest(166,true));selected(166)
 assert(ui:BackQuest());assert(ui.quest==141 and ui.renderedQuest==141 and ui.detailTab=="sources")
 assert(ui.detailScroll:GetVerticalScroll()==27 and #selection()==0)
 for _,row in ipairs(ui.rows)do assert(not(row:IsShown()and row.questID==141))end
end)

test("Back to overview clears selection and preserves an active preparation view",function()
 reset(166,true);ui.preparation=true;ui:RefreshQuests()
 local search,filter=ui.search,ui.includeUnavailable
 assert(ui:BackQuest());assert(ui.quest==nil and #selection()==0)
 assert(ui.preparation==true and ui.search==search and ui.includeUnavailable==filter)
end)

test("new inspection during Back list refresh supersedes the retired restore",function()
 reset(166,true);assert(ui:SetDetailTab("sources"));ui.detailScroll:SetVerticalScroll(31)
 assert(ui:InspectQuest(141,true))
 local original,fired=ui.RefreshQuests,false
 ui.RefreshQuests=function(self,...)
  if not fired then
   fired=true;assert(self:InspectQuest(92753,true));assert(self:SetDetailTab("story"));self.detailScroll:SetVerticalScroll(7)
  end
  return original(self,...)
 end
 ui:BackQuest();ui.RefreshQuests=original
 assert(fired,"Back must repaint list under retained navigation ownership")
 assert(ui.quest==92753 and ui.renderedQuest==92753 and ui.detailTab=="story"and ui.detailScroll:GetVerticalScroll()==7,
  "retired Back cannot overwrite a newer inspected quest, pane or reading offset")
end)
test("native middle-row text reentry preserves the newer selected quest and reading view",function()
 reset(166,true);assert(ui:SetDetailTab("sources"));ui.detailScroll:SetVerticalScroll(31)
 assert(ui:InspectQuest(141,true))
 local title
 for _,row in ipairs(ui.rows)do if row:IsShown()and row.questID==166 then title=row.title;break end end
 assert(title)
 local original,fired=title.SetText,false
 title.SetText=function(self,value)
  if not fired then
   fired=true;assert(ui:InspectQuest(92753,true));assert(ui:SetDetailTab("story"));ui.detailScroll:SetVerticalScroll(7)
  end
  return original(self,value)
 end
 ui:BackQuest();title.SetText=original
 assert(fired,"the real middle-row native setter must run during Back repaint")
 assert(ui.quest==92753 and ui.renderedQuest==92753 and ui.detailTab=="story"and ui.detailScroll:GetVerticalScroll()==7)
 selected(92753)
end)

test("same-quest owner changes during native list repaint retire the old detail restore",function()
 for _,field in ipairs({"includeUnavailable","range","preparation","search","frame","detailScroll"})do
  reset(166,true);assert(ui:SetDetailTab("sources"));ui.detailScroll:SetVerticalScroll(31)
  assert(ui:InspectQuest(141,true))
  local title
  for _,row in ipairs(ui.rows)do if row:IsShown()and row.questID==166 then title=row.title;break end end
  assert(title)
  local native,detail=title.SetText,ui.RefreshDetail
  local before,replacement=ui[field]
  if field=="frame"or field=="detailScroll"then replacement={}
  elseif field=="search"then replacement="new search during Back"
  else replacement=not before end
  local fired,detailCalls=false,0
  local history=ui.detailHistory;assert(#history==1 and history[1]==166)
  ui.RefreshDetail=function(self,...)detailCalls=detailCalls+1;return detail(self,...)end
  title.SetText=function(self,value)
   if not fired then fired=true;ui[field]=replacement end
   return native(self,value)
  end
  local restored=ui:BackQuest()
  title.SetText,ui.RefreshDetail=native,detail
  assert(fired and restored==true and detailCalls==0,"consumed Back stays handled while changed "..field.." retires old detail rendering")
  assert(ui.detailHistory==history and #history==0,"handled Back must consume exactly its history entry")
  assert(ui.quest==166 and ui[field]==replacement,"the same inspected quest must not hide owner drift")
  ui[field]=before
 end
end)
print("Back quest selection modeled groups passed: "..total)
