-- A selected target exposes a known actionable ancestor without inventing availability.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
issecretvalue=function()return false end
C_Timer={After=function()end}
GetLocale=function()return"enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();a.db.locale="enUS";ui.includeUnavailable=true
local owners={};for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=d end end
local token,held,ready={},141,141
a.Context=function()
 local own=token
 return{level=60,class="MAGE",faction="Alliance",race=3,current=function()return own==token end,
 completed=function()return false end,active=function(id)return id==held end,ready=function(id)return id==ready end}
end
local routes={}
a.Navigation={Start=function(action)routes[#routes+1]=action;return true end,Map=function()error("no automatic map route from inspection")end}
local function render(id,status)
 token={};held=status and 141 or nil;ready=status=="READY"and 141 or nil
 ui.dungeon,ui.quest=assert(owners[id]),id;ui.questTreeRoot,ui.questTreeDungeon=nil,nil;ui:Refresh()
 assert(ui.quest==id and ui.renderedQuest==id)
end
local function cue()
 local prefix=a.L("ANCESTOR_ACTION")
 for _,field in ipairs(ui.details)do if field:IsShown()and field.detailStyle=="caption"and field.text and field.text:find(prefix,1,true)then
  assert(field.detailTextBinding and field.detailTextBinding.current(),"ancestor context belongs to the selected current card")
  assert(not field.scripts or not field.scripts.OnClick,"ancestor context is not a duplicate quest selector")
  assert(not ui.ancestorActionButton or not ui.ancestorActionButton:IsShown(),"the retired ancestor selector stays hidden")
  return field
 end end
 error("selected target must expose its proven actionable ancestor as neutral context")
end
local function caption(control)return control.text or""end
local function absent()
 for _,field in ipairs(ui.details)do assert(not field:IsShown()or not field.text or not field.text:find(a.L("ANCESTOR_ACTION"),1,true),
  "no ancestor action may be guessed from story order or selected quest itself")end
 assert(not ui.ancestorActionButton or not ui.ancestorActionButton:IsShown())
end
local function centralAncestor()
 local root
 for _,row in ipairs(ui.rows)do if row:IsShown()and row.questID==166 and not row.questTreeNode then root=row end end
 if root then assert(root.scripts.OnClick);root.scripts.OnClick()end
 for _,row in ipairs(ui.rows)do if row:IsShown()and row.questID==141 and row.questTreeNode then
  assert(row.scripts.OnClick,"the actual required predecessor remains reachable from the central hierarchy")
  return row
 end end
 error("actual required predecessor141 missing from central hierarchy")
end
render(166,"READY")
assert(ui.engine:State(166).status=="UNKNOWN"and ui.engine:State(166).reason=="requirements")
assert(ui.action.id==141 and ui.action.kind=="turnin"and ui.action.place==a.quests[141].finish)
local control=cue();local text=caption(control)
assert(text:find(a.L("ANCESTOR_ACTION"),1,true)and text:find("#141",1,true)and text:find(a.L("READY"),1,true),
 "same-named known predecessor needs its exact ID and current native status")
assert(ui.giverAction.id==166 and #routes==0,"ancestor inspection keeps the target pickup route distinct")
local history=ui.detailHistory;local count=#history
centralAncestor().scripts.OnClick()
assert(ui.quest==141 and ui.renderedQuest==141 and ui.detailHistory==history and #history==count+1 and history[#history]==166,
 "the cue uses normal detail inspection and retains return history")
assert(ui.engine:State(141).status=="READY"and #routes==0,"inspection does not navigate or accept/turn in")
assert(ui.turnin and ui.turnin:IsShown()and ui.turnin.enabled)
ui.turnin.scripts.OnClick()
assert(#routes==1 and routes[1].id==141 and routes[1].kind=="turnin"and routes[1].place==a.quests[141].finish)
absent()
for _,mode in ipairs({"action","context","character","source","inspector","ui"})do
 render(166,"READY");local proof=cue().detailTextBinding.current
 local action,char,finish,inspect=ui.action,a.char,a.quests[141].finish,ui.InspectQuest
 local kind=action.kind;local foreign=0
 if mode=="action"then action.kind="complete"
 elseif mode=="context"then token={}
 elseif mode=="character"then a.char={}
 elseif mode=="source"then a.quests[141].finish={npcID=234,name="Changed source"}
 elseif mode=="ui"then a.UI={}
 else ui.InspectQuest=function()foreign=foreign+1 end end
 assert(proof()==false,"expired ancestor context proof retires before any selector or route")
 assert(ui.quest==166 and foreign==0 and #routes==1,"retired "..mode.." cue cannot inspect or route")
 action.kind=kind;a.char=char;a.quests[141].finish=finish;ui.InspectQuest=inspect;a.UI=ui
end
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","itIT","koKR","zhCN","zhTW"})do
 a.db.locale=locale;render(166,"READY");local text=caption(cue())
 assert(text:find(a.L("ANCESTOR_ACTION"),1,true)and text:find(a.L("READY"),1,true)and text:find("#141",1,true))
 local control=cue()
 assert(control.detailWidth>=300,"neutral context keeps the full available text width")
 local nextTop
 for _,field in ipairs(ui.details)do if field:IsShown()and field~=control and field.point and -field.point[3]>-control.point[3]then
  nextTop=math.min(nextTop or math.huge,-field.point[3])
 end end
 local boundary=nextTop or ui.detail:GetHeight()
 assert(boundary+control.point[3]>=control:GetStringHeight(),
  "the stream reserves the full wrapped ancestor caption height in every supported language")
end
a.db.locale="enUS"
render(166,"ACTIVE")
assert(ui.action.id==141 and ui.action.kind=="complete")
assert(caption(cue()):find(a.L("ACTIVE"),1,true),"unfinished ancestor is labeled in-log, never ready to turn in")
for _,id in ipairs({92753,4322})do
 render(id,nil);assert(ui.action==nil and ui.engine:State(id).status=="UNKNOWN");absent()
end
render(166,"READY");local stale=cue().detailTextBinding.current
render(92753,nil);assert(stale()==false and ui.quest==92753 and #routes==1)
print("Ancestor action cue: PASS (actual141/166, honest unknown targets, source/context retirement and normal inspection)")
