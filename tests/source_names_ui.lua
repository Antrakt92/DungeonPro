-- Reviewed source labels retain typed destinations and remain separate from item names.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
local sourceAPI=assert(a.SourceName)
issecretvalue=function()return false end;GetLocale=function()return"enUS"end;C_Timer={After=function()end}
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle();ui.includeUnavailable=true
a.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
local owners={};for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=owners[id]or d end end
local labels={objects={},npcs={}}
for _,p in ipairs(a.quests[2933].startAlternatives)do labels.objects[p.objectID]="Reviewed bottle "..p.objectID end
labels.objects[112877]="Reviewed scrying bowl";labels.objects[614679]="Reviewed crest container"
labels.npcs[234]="Reviewed Gryan"
-- Controlled reviewed-label adapter exercises callers independently of dictionary coverage.
local function provider(point,owner)
 if owner and not owner()then return nil end
 if point.itemID then return nil end
 local group=point.objectID and labels.objects or point.npcID and labels.npcs
 local id=point.objectID or point.npcID;local raw=point.name;local locale=a.db.locale
 local name=locale=="ruRU"and group and group[id]
 local function current()return a.SourceName==provider and a.db.locale==locale and point.name==raw and
  (point.objectID or point.npcID)==id and(not name or group[id]==name)end
 return name,current
end
a.SourceName=provider;a.db.locale="ruRU"
a.ItemName=function(id)return"Item "..id end;a.ItemIcon=function()return 134400 end;a.CarriedItemCount=function()return 0 end
local function render(id,tab)
 ui.quest,ui.dungeon=id,owners[id]or owners[166];ui:Refresh()
 if tab then assert(ui:SetDetailTab(tab))end
 assert(ui.quest==id and ui.renderedQuest==id)
end
local function visible(text)
 for _,v in ipairs(ui.details)do if v:IsShown()and v.text and v.text:find(text,1,true)then return true end end
end
render(2933,"sources")
local alternatives=a.quests[2933].startAlternatives
assert(ui.giverButtons[1].title.text==labels.objects[alternatives[1].objectID],"source choices use selected-language object labels")
assert(ui.startButtons[1].title.text==labels.objects[alternatives[3].objectID])
render(2204);assert(visible(labels.objects[112877]),"summoned-object identity and instruction share the reviewed label")
assert(visible("Item 7667"),"summoning tool keeps item naming rather than object naming")
render(95189);assert(visible(labels.objects[614679]),"starter container uses its own typed object label")
assert(visible("Item 268579"),"same-named starter remains an item")
render(166);assert(visible(labels.npcs[234]),"reviewed selected language wins over unrelated client language")
a.db.locale="zhCN";render(2933,"sources")
assert(ui.giverButtons[1].title.text==alternatives[1].name,"missing reviewed language retains canonical source fallback")
a.db.locale="ruRU"
local calls={};local nav=a.Navigation
a.Navigation={Start=function(action)calls[#calls+1]=action;return true end,Map=function()return true end}
render(2933,"sources");ui.startButtons[1].scripts.OnClick()
assert(#calls==1 and calls[1].place==alternatives[3]and calls[1].place.objectID==alternatives[3].objectID,
 "localized labels never replace numeric route identity")
a.Navigation=nav
-- A controlled direct object endpoint exercises both arrow hints and the live guide;
-- the recorded object and exact point are reused without changing catalogue membership.
local q=a.quests[166];local start=q.start;q.start=alternatives[1]
local tip={}
function tip:SetOwner(owner)self.owner=owner end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetText(text)self.title=text end
function tip:AddLine(text)self.body=text end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip
render(166)
local row;for _,r in ipairs(ui.rows)do if r:IsShown()and r.questID==166 then row=r;break end end
assert(row and row.navigationBinding.action)
row.navigationControl.scripts.OnEnter()
assert(tip.shown and tip.body:find(labels.objects[alternatives[1].objectID],1,true),"row hint matches its reviewed typed object")
ui.giver.scripts.OnEnter()
assert(tip.shown and tip.body:find(labels.objects[alternatives[1].objectID],1,true),"detail hint uses the same source label")
assert(nav.Start({id=166,kind="visit",place=q.start}))
local guide;for _,object in ipairs(f.objects)do if object.title and object.note and object.label and object.scripts.OnUpdate then guide=object end end
assert(guide and guide:IsShown()and guide.note.text:find(labels.objects[alternatives[1].objectID],1,true),"live guide shares the selected source name")
nav.Stop();q.start=start
-- The production resolver uses the real lazy dictionary, not live NPC names.
a.SourceName=sourceAPI
local dictionary=assert(a.GetNameTranslations("ruRU",function()return true end))
local objects,npcs=dictionary.objects,dictionary.npcs
dictionary.objects={};dictionary.npcs={}
local first=alternatives[1]
dictionary.objects[first.objectID]={source=first.name,name="Проверенное название объекта"}
dictionary.npcs[first.objectID]={source=first.name,name="Different NPC namespace"}
render(2933,"sources")
assert(ui.giverButtons[1].title.text=="Проверенное название объекта","actual resolver respects selected language and object namespace")
dictionary.objects,dictionary.npcs=objects,npcs
a.SourceName=nil;render(2933,"sources")
assert(ui.giverButtons[1].title.text==first.name,"absent optional resolver preserves existing source presentation")
a.SourceName=sourceAPI
print("Source names UI: PASS (reviewed labels, typed namespace, missing-language fallback and exact routes)")
