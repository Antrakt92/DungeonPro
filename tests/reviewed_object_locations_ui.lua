-- Recorded object sources preserve identity, complete manual choices and honest area-only hints.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
C_Timer={After=function()end};issecretvalue=function()return false end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle()
a.db.locale="enUS";ui.includeUnavailable=true;ui.range=false
a.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
a.DialogueRewards,a.QuestRewards,a.CachedQuestRewards=function()end,function()end,function()end
C_Map.GetMapInfo=function()return nil end
local visits,maps={},0
a.Navigation={Start=function(action)visits[#visits+1]=action;return true end,Map=function()maps=maps+1;return true end}
local owners,dungeons={},{}
local function associate(id,d,seen)
 if seen[id]then return end;seen[id]=true;owners[id]=owners[id]or d
 local q=assert(a.quests[id])
 for _,member in ipairs(q.storyline or{})do associate(member,d,seen)end
 for _,group in ipairs(q.requires or{})do for _,member in ipairs(group.ids)do associate(member,d,seen)end end
 for _,group in ipairs(q.storylineGroups or{})do for _,member in ipairs(group)do associate(member,d,seen)end end
end
for _,d in ipairs(a.dungeons)do dungeons[d.key]=d;local seen={};for _,id in ipairs(d.quests)do associate(id,d,seen)end end
local function shown(pool)local out={};for _,r in ipairs(pool or{})do if r:IsShown()then out[#out+1]=r end end;return out end
local function render(id,inspection)
 ui.dungeon,ui.quest=assert(owners[id]or inspection),id;ui.questTreeRoot,ui.questTreeDungeon=nil,nil
 ui:Refresh()
 if ui.detailTab~="quest"then assert(ui:SetDetailTab("quest"))end
 assert(ui.quest==id and ui.renderedQuest==id,"actual object quest remains inspected")
end
local function expand()
 assert(ui:SetDetailTab("sources"))
end
local function click(button,id,object,map,x,y)
 assert(button.enabled and type(button.scripts.OnClick)=="function","recorded point has an explicit enabled action")
 local before,selected,roots=#visits,ui.quest,#ui.currentPlan.rows
 button.scripts.OnClick()
 local action=assert(visits[#visits]);local point=assert(action.place)
 assert(#visits==before+1 and action.id==id and action.kind=="visit"and point.objectID==object,"click retains own quest and typed object")
 assert(point.mapID==map and point.x==x and point.y==y,"click dispatches the exact recorded point in percent units")
 assert(ui.quest==selected and #ui.currentPlan.rows==roots,"manual source navigation preserves selection and dungeon roots")
 return button.scripts.OnClick
end
local function reported(key,id,object,expected,map)
 local toggle
 for _,r in ipairs(shown(ui.reportedToggles))do if r.locationKey==key then toggle=r end end
 assert(toggle,"multiple source points are reachable through their own disclosure");toggle.scripts.OnClick()
 local rows={};for _,r in ipairs(shown(ui.reportedRows))do if r.locationKey==key then rows[#rows+1]=r end end
 assert(#rows==#expected,"complete source point list stays visible")
 local retired
 for i,r in ipairs(rows)do retired=click(r,id,object,map,expected[i][1],expected[i][2])end
 return retired
end
local retired
render(720,assert(dungeons.ulda))
retired=click(ui.giver,720,2868,1418,53,34.1)
render(739,assert(dungeons.ulda));local n=#visits;retired()
assert(#visits==n+1 and visits[#visits].id==739 and visits[#visits].place.objectID==2875,"shared primary control resolves the newest inspected object rather than its former source")
click(ui.giver,739,2875,1418,50.9,62.2)
expand();retired=reported("start",739,2875,{{50.9,62.2},{51,62.5}},1418)
render(738,assert(dungeons.ulda));expand()
reported("finish",738,2875,{{50.9,62.2},{51,62.5}},1418)

-- Each bottle remains a different source even when some coordinates match.
local expected={
 {142702,23.6,58.7},{142703,23.2,58.5},{142704,23.2,58.5},{142705,23.6,58.8},
 {142706,23.4,58.8},{142707,23.2,58.5},{142708,31.6,57.8},{142710,31.6,57.7},
 {142711,31.6,57.8},{142712,31.6,57.8},{142713,23.1,57.7},{142714,23,57.8}}
render(2933,assert(dungeons.ulda));n=#visits;retired();assert(#visits==n,"retired reported source cannot route a different quest")
assert(not ui.giverAction and #shown(ui.giverButtons)==0 and ui.detailTab=="quest","twelve alternatives never auto-select one source on Quest")
expand()
local compact=shown(ui.giverButtons)
for i,b in ipairs(compact)do local e=expected[i];click(b,2933,e[1],1425,e[2],e[3])end
expand();local remainder=shown(ui.startButtons);assert(#remainder==10,"all ten remaining bottle objects stay manually reachable")
for i,b in ipairs(remainder)do local e=expected[i+2];click(b,2933,e[1],1425,e[2],e[3])end
assert(#a.quests[2933].startAlternatives==12,"source presentation does not collapse distinct object IDs")
retired=reported("startAlternative:3",2933,142706,{{23.4,58.8},{23.5,58.7}},1425)

-- A known dungeon area is useful context, but is never an invented exact route.
local spark={2945,2951,2949,2947,2952,2953,4605,4604,4606,4603,4601,4602}
local endpoints=0
for _,id in ipairs(spark)do
 local q=assert(a.quests[id]);render(id,assert(dungeons.gnom));n=#visits
 if retired then retired();assert(#visits==n,"old bottle location cannot survive an area-only card");retired=nil end
 for _,key in ipairs({"start","finish"})do local p=q[key]
  if p and(p.objectID==142487 or p.objectID==175084 or p.objectID==175085)then
   endpoints=endpoints+1
   assert(p.zoneName=="Gnomeregan"and not p.mapID and not p.x and not p.y,"typed Sparklematic endpoint retains area without a fabricated map")
   local visible=false
   for _,field in ipairs(ui.details)do if field:IsShown()and field.text:find("Gnomeregan",1,true)then visible=true end end
   assert(visible,"known Gnomeregan area is visible to the player")
   if key=="start"then
    assert(not ui.giver.enabled and ui.giverUnavailableKey=="SOURCE_POSITION_UNKNOWN","area-only object source explains missing precise position")
    if ui.giver.scripts.OnClick then ui.giver.scripts.OnClick()end
    assert(#visits==n and maps==0,"Area721 is never dispatched as a UiMap route")
   end
  end
 end
end
assert(endpoints==21 and maps==0,"all twelve Sparklematic quests retain twenty-one area-only endpoints")
local discs=0
for _,id in ipairs({2278,2279,2280})do
 render(id,assert(dungeons.ulda));local q=a.quests[id];n=#visits
 for _,key in ipairs({"start","finish"})do local p=q[key]
  if p and p.objectID==131474 then
   discs=discs+1
   assert(p.zoneName=="Uldaman"and not p.mapID and not p.x and not p.y,"Discs retain only their reported dungeon area")
  end
 end
 local visible=false
 for _,field in ipairs(ui.details)do if field:IsShown()and field.text:find("Uldaman",1,true)then visible=true end end
 assert(visible and not ui.giver.enabled and ui.giverUnavailableKey=="SOURCE_POSITION_UNKNOWN","Discs area is readable while exact routing stays unavailable")
 if ui.giver.scripts.OnClick then ui.giver.scripts.OnClick()end
 assert(#visits==n and maps==0,"Discs do not substitute a dungeon entrance or finisher route")
end
assert(discs==4,"three Discs quests retain all four typed object endpoints")
print("Reviewed object locations: PASS (actual TOC; Badlands objects, twelve bottle identities, complete point actions and area-only Sparklematic sources; modeled UI)")
