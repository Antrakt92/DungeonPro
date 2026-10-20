-- Native writes cannot publish ancestor context from an expired selected card.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return"enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();a.db.locale="enUS";ui.includeUnavailable=true
local owners={};for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=d end end
local token,ready={},true
a.Context=function()
 local own=token
 return{level=60,class="MAGE",faction="Alliance",race=3,current=function()return own==token end,
 completed=function()return false end,active=function(id)return id==141 end,ready=function(id)return ready and id==141 end}
end
local routes=0
a.Navigation={Start=function()routes=routes+1 end,Map=function()routes=routes+1 end}
local function render(id,status)
 token={};ready=status~="ACTIVE"
 ui.dungeon,ui.quest=assert(owners[id]),id;ui.questTreeRoot,ui.questTreeDungeon=nil,nil;ui:Refresh()
end
local function cue()
 for _,field in ipairs(ui.details)do if field:IsShown()and field.text and field.text:find(a.L("ANCESTOR_ACTION"),1,true)then
  assert(field.detailStyle=="caption"and field.detailTextBinding.current())
  assert(not field.scripts or not field.scripts.OnClick,"ancestor context never duplicates the central selector")
  assert(not ui.ancestorActionButton or not ui.ancestorActionButton:IsShown())
  return field
 end end
 error("actual166 target needs neutral known141 context")
end
local function centralAncestor()
 for _,row in ipairs(ui.rows)do if row:IsShown()and row.questID==166 and not row.questTreeNode then row.scripts.OnClick();break end end
 for _,row in ipairs(ui.rows)do if row:IsShown()and row.questID==141 and row.questTreeNode then return row end end
 error("actual required ancestor141 must remain centrally reachable")
end
local function snapshot(field)
 local point={};for i,v in ipairs(field.point or{})do point[i]=v end
 return{text=field.text,shown=field:IsShown(),width=field.width,height=field.height,point=point,binding=field.detailTextBinding}
end
local function same(field,expected)
 assert(field.text==expected.text and field:IsShown()==expected.shown and field.width==expected.width and field.height==expected.height,
  "retired native ancestor tail preserves newest text, visibility and measured width")
 for i,v in ipairs(expected.point)do assert(field.point[i]==v,"retired ancestor tail preserves newest anchor")end
 assert(field.detailTextBinding==expected.binding,"the actual pooled FontString binding belongs to the new publication")
end
render(166,"READY")
assert(ui.action.id==141 and ui.action.kind=="turnin"and ui.engine:State(166).status=="UNKNOWN")
local field=cue();local retired=field.detailTextBinding.current;local native=field.SetText
local fired,expected=false,nil
field.SetText=function(self,text)
 if not fired then fired=true;ui:InspectQuest(92753,true);expected=snapshot(self)end
 return native(self,text)
end
render(166,"READY");field.SetText=native
assert(fired and expected and ui.quest==92753 and ui.renderedQuest==92753,"native caption setter must finish the newer selected card")
same(field,expected);assert(not retired()and routes==0)

-- A native Show may replace READY with ACTIVE while reusing the same pooled field.
render(166,"READY");field=cue();retired=field.detailTextBinding.current;native=field.Show;fired=false
field.Show=function(self)
 if not fired then fired=true;render(166,"ACTIVE");expected=snapshot(self)end
 return native(self)
end
render(166,"READY");field.Show=native
assert(fired and ui.quest==166 and ui.engine:State(141).status=="ACTIVE"and ui.action.kind=="complete")
same(field,expected);assert(not retired()and routes==0)
assert(cue().text:find(a.L("ACTIVE"),1,true),"the newest neutral caption retains actual in-log status")
centralAncestor().scripts.OnClick()
assert(ui.quest==141 and ui.renderedQuest==141 and routes==0,"only the central hierarchy explicitly selects the ancestor")

-- Redrawing during native Show replaces the real pooled publication token.
render(166,"READY");field=cue();local binding=field.detailTextBinding;retired=binding.current;native=field.Show;fired=false
field.Show=function(self)
 if not fired then fired=true;ui:RefreshDetail();expected=snapshot(self)end
 return native(self)
end
render(166,"READY");field.Show=native
assert(fired and expected.binding~=binding and ui.quest==166 and ui.renderedQuest==166)
same(field,expected);assert(not retired()and cue().detailTextBinding.current()and routes==0,
 "retained publication proof cannot authorize the physical field after its binding is replaced")
centralAncestor().scripts.OnClick()
assert(ui.quest==141 and ui.renderedQuest==141 and routes==0,"central selection recovers after pooled binding replacement")
print("Ancestor context retirement: PASS (native caption/Show, actual pooled ownership, status replacement and central selection)")
