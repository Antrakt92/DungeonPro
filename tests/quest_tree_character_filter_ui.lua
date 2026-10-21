-- Real expanded Stratholme story uses the same audience policy as dungeon roots.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;GetLocale=function()return"enUS"end
C_Timer={After=function()end}
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local dungeon;for _,d in ipairs(a.dungeons)do if d.key=="strat"then dungeon=d end end
assert(dungeon and a.quests[8945])
local facts={[8926]={faction="Alliance"},[8927]={faction="Horde"},[8935]={faction="Alliance",class="ROGUE"},[8937]={faction="Alliance",class="WARRIOR"},[8941]={faction="Horde",class="ROGUE"}}
for id,rule in pairs(facts)do
 local q=assert(a.quests[id]);assert(#q.factions==1 and q.factions[1]==rule.faction)
 if rule.class then assert(#q.classes==1 and q.classes[1]==rule.class)end
end
local done,held,ready={},{},{}
local function row(id)
 for _,r in ipairs(u.rows)do if r:IsShown()and r.questTreeNode and r.questID==id then return r end end
end
local function draw(faction,class)
 done,held,ready={},{},{}
 a.Context=function()return{level=60,faction=faction or nil,class=class or nil,completed=function(id)return done[id]==true end,active=function(id)return held[id]==true end,ready=function(id)return ready[id]==true end}end
 u.search="";u.dungeon,u.quest=dungeon,nil;a.char.selectedDungeon=dungeon.key
 u.range=false;u.includeUnavailable=false;u.questTreeRoot,u.questTreeDungeon=nil,nil;u:Refresh()
 local root;for _,r in ipairs(u.rows)do if r:IsShown()and r.questID==8945 then root=r;break end end
 assert(root and root.scripts.OnClick);root.scripts.OnClick(root,"LeftButton",false)
 assert(u.quest==8945 and u.questTreeRoot==8945 and u.questTreeDungeon==dungeon)
end
local function checkRows(faction,class,all)
 assert(u.includeUnavailable==all)
 for id,rule in pairs(facts)do
  local eligible=not(faction and faction~=rule.faction)and not(class and rule.class and class~=rule.class)
  local expected=all or eligible or held[id]==true
  assert((row(id)~=nil)==expected,"expanded story audience filter "..id.." faction="..tostring(faction).." class="..tostring(class).." All="..tostring(all))
 end
 assert(u.questTreeRoot==8945 and u.questTreeDungeon==dungeon,"filter preserves expanded actual root")
end
local cases=0
for _,faction in ipairs({"Alliance","Horde",false})do for _,class in ipairs({"MAGE","WARRIOR","ROGUE",false})do
 draw(faction,class);checkRows(faction,class,false)
 u.characterButton.scripts.OnClick(u.characterButton,"LeftButton");checkRows(faction,class,true)
 local foreign=faction=="Horde"and 8926 or 8927;local click=assert(row(foreign)).scripts.OnClick
 u.characterButton.scripts.OnClick(u.characterButton,"LeftButton");checkRows(faction,class,false)
 local selected=u.quest;click();assert(u.quest==selected,"old All row cannot inspect after returning to Mine")
 cases=cases+1
end end
assert(cases==12)
for _,faction in ipairs({"Alliance","Horde"})do
 draw(faction,"MAGE")
 local foreign=faction=="Alliance"and 8927 or 8926
 done[foreign]=true;u:RefreshQuests();checkRows(faction,"MAGE",false)
 assert(u.engine:State(foreign).status=="COMPLETED"and not row(foreign),"past completion does not override foreign audience")
 held[foreign]=true;u:RefreshQuests();checkRows(faction,"MAGE",false)
 assert(row(foreign)and u.engine:State(foreign).status=="ACTIVE","actual active foreign log evidence remains visible")
 ready[foreign]=true;u:RefreshQuests();checkRows(faction,"MAGE",false)
 assert(row(foreign)and u.engine:State(foreign).status=="READY","actual ready foreign log evidence remains visible")
end
draw("Alliance","MAGE")
done[8935]=true;u:RefreshQuests();checkRows("Alliance","MAGE",false)
assert(u.engine:State(8935).status=="COMPLETED"and not row(8935),"past completion does not override a foreign class")
held[8935]=true;u:RefreshQuests();checkRows("Alliance","MAGE",false)
assert(row(8935)and u.engine:State(8935).status=="ACTIVE","held class-conflicting quest remains visible")
ready[8935]=true;u:RefreshQuests();checkRows("Alliance","MAGE",false)
assert(row(8935)and u.engine:State(8935).status=="READY","ready class-conflicting quest remains visible")
-- A hidden peer still belongs to the rendered audience projection's source proof.
for _,mutation in ipairs({{8935,"classes","MAGE"},{8927,"factions","Alliance"}})do
 draw("Alliance","MAGE")
 assert(not row(mutation[1]))
 local click=assert(row(8926)).scripts.OnClick
 local values=a.quests[mutation[1]][mutation[2]];local saved=values[1];values[1]=mutation[3]
 click();values[1]=saved
 assert(u.quest==8945,"mutated hidden peer audience retires old tree controls")
end
local model=assert(a.QuestTree.Build(a.quests,u.engine,8945))
local full={};for _,node in ipairs(model.presentation)do full[node.id]=true end
for id in pairs(facts)do assert(full[id],"audience projection preserves the complete underlying story model")end
for _,helper in ipairs({"Eligible","RelevantToCharacter"})do
 draw("Alliance","MAGE");local old=assert(row(8926)).scripts.OnClick
 local original=a.Planner[helper];local calls=0
 a.Planner[helper]=function()calls=calls+1;return true end
 old();a.Planner[helper]=original
 assert(u.quest==8945 and calls==0,"replaced audience helper retires old tree controls")
end
print("Expanded quest audience filtering: PASS (actual Stratholme story, twelve contexts, real Mine/All toggles, history vs held evidence, hidden-source and helper retirement)")
