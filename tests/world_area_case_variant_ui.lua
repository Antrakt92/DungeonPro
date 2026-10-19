-- A reviewed observed spelling changes captions only, never the destination.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
issecretvalue=function()return false end;GetLocale=function()return"enUS"end;C_Timer={After=function()end}
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle();ui.includeUnavailable=true
a.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
local dungeon;for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do if id==214 then dungeon=d end end end
assert(dungeon)
local q=assert(a.quests[214]);local point=assert(q.start)
assert(q.name=="Red Silk Bandanas"and point.npcID==820 and q.finish.npcID==820)
assert(point.zoneName=="Westfall"and point.mapID==1436 and point.x==56.6 and point.y==47.4)
local name,map,x,y=point.name,point.mapID,point.x,point.y
local nav=a.Navigation;local start=nav.Start;local routes={}
nav.Start=function(action)routes[#routes+1]=action;return start(action)end
local tip={}
function tip:SetOwner(owner)self.owner=owner end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetText(text)self.title=text end
function tip:AddLine(text)self.body=text end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip
local chosen="Западный Край"
local function visible(text)
 for _,field in ipairs(ui.details)do if field:IsShown()and field.text and field.text:find(text,1,true)then return true end end
end
a.db.locale="ruRU";ui.quest,ui.dungeon=214,dungeon;ui:Refresh()
assert(ui.renderedQuest==214 and visible(chosen),"Quest must show the explicitly reviewed observed Westfall spelling")
assert(a.SourceAreaName("Westfall")==chosen)
assert(#routes==0,"displaying a selected spelling does not start navigation")
ui.giver.scripts.OnEnter();assert(tip.shown and tip.body:find(chosen,1,true),"giver hint uses the selected observed spelling")
local row;for _,r in ipairs(ui.rows)do if r:IsShown()and r.questID==214 then row=r;break end end
assert(row and row.navigationBinding.action);row.navigationControl.scripts.OnEnter()
assert(tip.shown and tip.body:find(chosen,1,true),"middle-list hint agrees with Quest")
assert(ui:SetDetailTab("sources")and visible(chosen),"Sources uses the same reviewed spelling")
assert(#routes==0 and ui.quest==214)
assert(ui:SetDetailTab("quest"));ui.giver.scripts.OnClick()
assert(#routes==1 and routes[1].id==214 and routes[1].place==point)
local guide;for _,o in ipairs(f.objects)do if o.title and o.note and o.label and o.scripts.OnUpdate then guide=o end end
assert(guide and guide:IsShown()and guide.note.text:find(chosen,1,true),"guide keeps the same area display without selecting a provider zone as a map")
nav.Stop()
local terms,current,unchanged=a.QuestSourceSearchTerms(q);local canonical,translated=false,false
for _,term in ipairs(terms)do if term.kind=="place"then
 if term.text=="Westfall"then canonical=true end;if term.text==chosen then translated=true end
end end
assert(canonical and translated and current()and unchanged(),"search retains English and the exact selected observed alias")
for _,query in ipairs({chosen,"Westfall"})do
 ui.search=query;ui:RefreshDungeons()
 local matched=false;for _,card in ipairs(ui.cards)do if card:IsShown()and card.catalogResult and card.catalogResult.dungeon==dungeon then matched=true end end
 assert(matched,"both source spellings find the existing Deadmines catalogue result")
 assert(ui.quest==214 and #routes==1,"search never changes the inspected quest or starts another route")
end
assert(a.SourceAreaName("Westfall / Ironforge")==nil and a.SourceAreaName("Blackrock Spire")==nil,
 "an explicit spelling selection does not authorize composite or ambiguous area guesses")
assert(point.name==name and point.npcID==820 and point.mapID==map and point.x==x and point.y==y and point.zoneName=="Westfall")
nav.Start=start
print("Westfall reviewed spelling UI: PASS (Quest/Sources, hints, guide, bilingual search and exact NPC820 route; modeled)")
