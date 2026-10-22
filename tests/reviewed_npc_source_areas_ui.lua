-- Actual NPC identities retain independently recorded areas without invented interior routes.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
-- Native FontStrings are shown on creation; journal purpose is its own region.
local createFontString=f.methods.CreateFontString
function f.methods:CreateFontString(...)local value=createFontString(self,...);value.shown=true;return value end
C_Timer={After=function()end};issecretvalue=function()return false end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle();ui.includeUnavailable=true;a.db.locale="enUS"
local selected,ready
local routes,maps=0,0
a.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function(id)return ready and id==selected end,ready=function(id)return ready and id==selected end}end
a.Navigation={Start=function()routes=routes+1;return true end,Map=function()maps=maps+1;return true end}
a.DialogueRewards,a.QuestRewards,a.CachedQuestRewards=function()end,function()end,function()end
local owners={}
local function own(id,d,seen)
 if seen[id]then return end;seen[id]=true;owners[id]=owners[id]or d
 local q=assert(a.quests[id])
 for _,other in ipairs(q.storyline or{})do own(other,d,seen)end
 for _,g in ipairs(q.requires or{})do for _,other in ipairs(g.ids)do own(other,d,seen)end end
 for _,g in ipairs(q.storylineGroups or{})do for _,other in ipairs(g)do own(other,d,seen)end end
end
for _,d in ipairs(a.dungeons)do local seen={};for _,id in ipairs(d.quests)do own(id,d,seen)end end
local function render(id,isReady,inspection)
 selected,ready=id,isReady==true;ui.dungeon,ui.quest=assert(inspection or owners[id]),id;ui:Refresh()
 if ui.detailTab~="quest"then assert(ui:SetDetailTab("quest"))end
 assert(ui.quest==id and ui.renderedQuest==id)
end
local function field(text)
 for _,v in ipairs(ui.details)do if v:IsShown()and v.text:find(text,1,true)then return v end end
 local name,zone=text:match("^(.-) — (.+)$")
 for index=1,2 do local contact=ui.detailContactRows and ui.detailContactRows[index];if contact and contact:IsShown()then
  if name then
   if contact.title.text:find(name,1,true)and contact.note.text:find(zone,1,true)==1 then return contact end
  elseif contact.title.text:find(text,1,true)then return contact end
 end end
end
local function ownContact(field,zone)
 local point=assert(a.quests[ui.quest][field]);local contact=assert(ui.detailContactRows[field=="start"and 1 or 2])
 local binding=assert(contact.detailContactBinding);local purpose=assert(contact.detailPurpose)
 assert(contact:IsShown()and binding.current()and binding.questID==ui.quest and binding.field==field and binding.endpoint==point,
  "reviewed area belongs to the exact selected typed endpoint")
 assert(not purpose:IsShown()and purpose.text==a.L(field=="start"and "DETAIL_GIVER"or"DETAIL_TURNIN")and contact.title.text==point.name,
  "source purpose and actor retain independent tooltip values")
 if zone then assert(contact.note.text==zone,"recorded own endpoint area remains tooltip metadata")end
 return contact
end
local function row(id)
 for _,r in ipairs(ui.rows)do if r:IsShown()and r.questID==id then return r end end
 error("missing own quest row "..id)
end
for _,id in ipairs({3801,3802})do
 render(id)
 local control=row(id).navigationControl
 assert(control.enabled and control.sourceInspect,"manual alternatives remain source inspection rather than an arbitrary NPC route")
 control.scripts.OnClick()
 assert(ui.quest==id and ui.renderedQuest==id and ui.detailTab=="quest","source inspection opens its own choice details")
 local known,unknown=assert(ui.giverButtons[1]),assert(ui.giverButtons[2])
 assert(known:IsShown()and unknown:IsShown()and known.title.text==unknown.title.text,"same-name typed NPC alternatives stay separate choices")
 assert(known.note.text=="Burning Steppes — |cffff594d"..a.L("SOURCE_POSITION_UNKNOWN").."|r"and unknown.note.text=="|cffff594d"..a.L("UNKNOWN_PLACE").."|r","only NPC8888 receives the verified area; each missing position is visible and NPC184290 stays unknown")
 assert(not known.enabled and not unknown.enabled and not known.scripts.OnClick and not unknown.scripts.OnClick,"an area name alone does not invent a route for either alternative")
 if id==3801 then
  local finishKnown,finishUnknown=assert(ui.finishButtons[1]),assert(ui.finishButtons[2])
  assert(finishKnown:IsShown()and finishUnknown:IsShown()and finishKnown.note.text=="Burning Steppes — |cffff594d"..a.L("SOURCE_POSITION_UNKNOWN").."|r"and finishUnknown.note.text=="|cffff594d"..a.L("UNKNOWN_PLACE").."|r","turn-in alternatives preserve the same independent NPC variant areas and visible unknown positions")
  assert(not finishKnown.enabled and not finishUnknown.enabled,"turn-in area facts do not become a fabricated map")
 else
  assert(ownContact("finish","Blackrock Depths"),"second quest still turns in at its own object rather than either starting NPC")
 end
end
for _,sample in ipairs({{7046,13716},{7066,12238}})do
 for _,isReady in ipairs({false,true})do
  render(sample[1],isReady)
  local q=a.quests[sample[1]];assert(q.start.npcID==sample[2])
  assert(field(q.start.name.." — Maraudon"),"recorded own starting NPC area is immediately visible")
  local warning=assert(field(a.L("SOURCE_POSITION_UNKNOWN")))
  assert(warning.detailStyle=="warning"and not field(a.L("GIVER_LOCATION_UNKNOWN")),"known interior area is distinct from wholly unknown giver location")
  assert(not ui.giver.enabled and not row(sample[1]).navigationControl.enabled and not ui:NavigationDestination(false),"known interior without a map remains informational even after quest becomes ready")
  if isReady then
   assert(ui.engine:State(sample[1]).status=="READY"and ui.action and ui.action.kind=="turnin"and ui.action.place==q.finish,"actual ready action retains the recorded finish endpoint")
   if sample[1]==7046 then assert(ui.action.place.zoneName=="Maraudon","ready Celebras action keeps its independently recorded finish area")end
  end
 end
end
render(7044)
local q=a.quests[7044]
assert(ownContact("finish","Maraudon"),"Celebras area belongs to this quest's turn-in, not its different starting NPC")
assert(field(a.L("GIVER_LOCATION_UNKNOWN"))and ui.giverUnavailableKey=="GIVER_LOCATION_UNKNOWN" and
 not field(q.start.name.." — Maraudon"),"unknown Cavindra start does not borrow Celebras's known area")
local finishLine=assert(ownContact("finish","Maraudon"))
local finishWarning,warningCount
warningCount=0
for _,line in ipairs(ui.details)do if line:IsShown()and line.text==a.L("SOURCE_POSITION_UNKNOWN")then
 warningCount=warningCount+1;finishWarning=line
end end
assert(warningCount==1 and -finishLine.point[5]+finishLine:GetHeight()<=-finishWarning.point[3],
 "the compact finisher header keeps one separate missing-position warning below it")
assert(finishWarning and finishWarning.text==a.L("SOURCE_POSITION_UNKNOWN")and finishWarning.detailStyle=="warning",
 "the distinct known Maraudon finisher explains its own missing exact position")
assert(not row(7044).navigationControl.enabled and not ui.giver.enabled and not ui:NavigationDestination(false) and not ui.turnin.enabled,
 "neither the unknown pickup nor the finisher area fabricates a route")
-- Standalone Warosh is inspected explicitly, without creating a natural dungeon association.
assert(not owners[4867])
for _,sample in ipairs({{4867,10799},{5160,10740},{5047,10776}})do
 render(sample[1],false,sample[1]==4867 and assert(owners[4742])or nil)
 local q=a.quests[sample[1]]
 assert(q.start.npcID==sample[2]and field(q.start.name.." — Blackrock Spire"),"own typed NPC exposes the verified broad Spire area without inventing a wing")
 assert(field(a.L("SOURCE_POSITION_UNKNOWN"))and not field(a.L("GIVER_LOCATION_UNKNOWN")),"broad known area retains the exact-position warning")
 assert(not ui.giver.enabled and not ui:NavigationDestination(false),"broad Spire area cannot become a precise route")
 if sample[1]~=4867 then assert(not row(sample[1]).navigationControl.enabled,"own Spire list route remains unavailable")end
 if sample[1]==4867 then
  render(4867,true,assert(owners[4742]))
  assert(ui.action and ui.action.kind=="turnin"and ui.action.place==q.finish and ui.action.place.zoneName=="Blackrock Spire","Warosh remains the actual ready finisher, with no invented destination")
 else
  assert(ownContact("finish"),"different Winterspring turn-in remains independent of the known starting area")
 end
end
assert(routes==0 and maps==0,"eleven area facts enable no arbitrary pickup or turn-in route")
print("Reviewed NPC source areas: PASS (actual TOC; own variants and endpoint roles, no native map proof)")
