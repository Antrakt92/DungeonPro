local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,event=f.addon,f.eventFrame
event.scripts.OnEvent(event,"ADDON_LOADED","DungeonPro")
SlashCmdList.DUNGEONPRO("")
local ui=a.UI
local character={level=20,faction="Alliance",class="MAGE"}
local live,done={},{}
local epoch=0
a.Context=function()
 local owned=epoch
 return {level=character.level,faction=character.faction,class=character.class,
 active=function(id)return live[id]==true end,ready=function()return false end,
 completed=function(id)return done[id]==true end,current=function()return epoch==owned end}
end
a.quests={}
for id=1,8 do a.quests[id]={id=id,name="Count quest "..id,minLevel=1,requirementsKnown=true}end
a.quests[2].factions={"Horde"};a.quests[3].classes={"PALADIN"}
a.quests[4].minLevel=60;a.quests[5].requires={{ids={8}}}
a.quests[6].requirementsKnown=false;a.quests[7].factions={"Horde"};live[7]=true
local d={key="counts",name="Counts dungeon",minLevel=1,maxLevel=60,coverage="reviewed",quests={1,2,3,4,5,6,7}}
a.dungeons={d};ui.dungeon=d;ui.quest=nil;ui.search="";ui.range=false;ui.includeUnavailable=false
local function assertCount(expected)
 local card=ui.cards[1]
 assert(card.catalogResult.count==expected,"card count must match filtered roots: "..tostring(card.catalogResult.count))
 assert(#ui.currentPlan.rows==expected,"middle root plan parity")
 assert(card.note.text==a.L("CATALOG_COMPACT_META",1,60,expected))
 local found=false
 for _,line in ipairs(ui.details)do if line.shown and line.text==a.L("CATALOG_QUESTS",expected)then found=true end end
 assert(not found,"compact overview does not duplicate catalogue counts")
 return card
end
ui:Refresh();local card=assertCount(5)
-- Count neither prerequisite expansion nor only currently available quests.
assert(ui.engine:State(4).status=="LOCKED" and ui.engine:State(6).status=="UNKNOWN")
local prior=card.dungeonStatusCurrent
ui.characterButton.scripts.OnClick(ui.characterButton);assert(ui.includeUnavailable);assertCount(7)
assert(not prior(),"retained tooltip ownership expires when mode changes")
ui.characterButton.scripts.OnClick(ui.characterButton);assert(not ui.includeUnavailable);assertCount(5)
-- Warm data and language reuse may not preserve a previous filter count.
ui.includeUnavailable=true;assert(not ui:RefreshCatalogData());assert(not ui:RefreshCatalogLanguage())
ui:Refresh();assertCount(7)
ui.includeUnavailable=false;ui:Refresh();assertCount(5)
character.class="PALADIN";character.faction="Horde";character.level=1;epoch=epoch+1;ui:Refresh();assertCount(7)
character.class=nil;character.faction=nil;epoch=epoch+1;ui:Refresh();assertCount(7)
-- Historical completion does not retain a known foreign class; active does.
character.class="MAGE";character.faction="Alliance";epoch=epoch+1;done[3]=true;ui:Refresh();assertCount(5)
live[3]=true;epoch=epoch+1;ui:Refresh();assertCount(6)
-- Source and shared membership-provider changes invalidate retained aggregate counts.
local dto,fresh=a.DungeonStatus.Get(d,ui.engine);assert(dto.characterRoots==6 and fresh())
a.quests[1].classes={"WARRIOR"};assert(not fresh());epoch=epoch+1;ui:Refresh();assertCount(5)
local old=a.Planner.RelevantToCharacter;local _,owned=a.DungeonStatus.Get(d,ui.engine)
a.Planner.RelevantToCharacter=function(...)return old(...)end;assert(not owned());a.Planner.RelevantToCharacter=old
-- Unavailable aggregate evidence must not falsely display zero or the All total.
local status=a.DungeonStatus.Get;a.DungeonStatus.Get=function()return nil end
ui:RefreshDungeons();assert(ui.cards[1].catalogResult.count==nil)
assert(ui.cards[1].note.text==a.L("CATALOG_LEVELS",1,60));a.DungeonStatus.Get=status



-- Tooltip count is the same visible scope, and cannot survive an unpainted toggle.
ui:Refresh()
local tip={lines={}}
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetOwner(owner)self.owner=owner end
function tip:SetText(text)self.title=text end
function tip:AddLine(text)self.lines[#self.lines+1]=text end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip
ui:CatalogStatusHint(ui.cards[1]);assert(tip.shown)
assert(tip.lines[2]:find(a.L("CATALOG_QUESTS",5),1,true))
ui.includeUnavailable=true;tip.lines={};ui:CatalogStatusHint(ui.cards[1]);assert(#tip.lines==0)
ui.includeUnavailable=false
-- A populated dungeon with no matching roots is not missing catalogue data.
a.quests[8].classes={"WARRIOR"};d.quests={8};epoch=epoch+1;ui:Refresh();assertCount(0)
local function has(text)for _,line in ipairs(ui.details)do if line.shown and line.text==text then return true end end end
assert(ui.currentPlan.notice=="NO_CHARACTER_QUESTS" and has(a.L("OVERVIEW_PICK")) and not has(a.L("EMPTY")), "middle list owns the filtered-empty notice; compact overview remains a prompt")
ui.characterButton.scripts.OnClick(ui.characterButton);assertCount(1)
-- Compact detail rendering never asks for the removed aggregate count caption.
ui.includeUnavailable=false;d.quests={1,2};epoch=epoch+1;ui:Refresh()
local L=a.L;local armed=true
a.L=function(key,...)local value=L(key,...);if armed and key=="CATALOG_QUESTS"then armed=false;a.quests[2].factions={"Alliance"}end;if key=="CATALOG_QUESTS"then return "STALECOUNT "..value end;return value end
ui:RefreshDetail();a.L=L
assert(armed and not has("STALECOUNT "..a.L("CATALOG_QUESTS",0)),"compact overview cannot invoke a removed count provider or publish its text")

-- Hiding a catalogue card cannot introduce a duplicate count into the compact overview.
ui.search="not a matching dungeon";ui:Refresh();assert(#ui.currentPlan.rows==0)
assert(not has(a.L("CATALOG_QUESTS",0)) and has(a.L("OVERVIEW_PICK")))
ui.search="";ui:Refresh()
-- A native metadata setter may invalidate an excluded root before publication.
a.quests[2].factions={"Horde"};epoch=epoch+1;ui:Refresh()
local row=ui.cards[1];local set=row.note.SetText;local entered=false
row.note.SetText=function(self,text)
 if not entered then entered=true;a.quests[2].factions={"Alliance"}end
 set(self,text)
end
ui:RefreshDungeons();row.note.SetText=set
assert(entered and not row.shown,"stale count card remains unpublished")
ui:Refresh();assertCount(1)
print("Dungeon Mine/All count modeled checks passed")
