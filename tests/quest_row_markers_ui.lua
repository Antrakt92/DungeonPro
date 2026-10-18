local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon = fixture.addon
function fixture.methods:GetStringWidth() return self.measuredWidth or #(self.text or "")*5 end
function fixture.methods:SetAtlas(value) self.atlas=value;return true end
function fixture.methods:GetAtlas() return self.atlas end
function fixture.methods:SetRotation(value) self.rotation=value end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame,"ADDON_LOADED","DungeonPro")
SlashCmdList.DUNGEONPRO("")
local ui,dungeon=addon.UI
for _,value in ipairs(addon.dungeons)do if value.key=="dm"then dungeon=value end end
addon.db.locale="enUS"
ui.dungeon,ui.quest,ui.questTreeRoot,ui.questTreeDungeon=dungeon,nil,nil,nil
ui.includeUnavailable=true;ui:Refresh()
local function row(id)
 for _,value in ipairs(ui.rows)do if value:IsShown()and value.questID==id then return value end end
 error("Missing row "..id)
end
local function chevron(value,visible)
 if not value.chainChevron then assert(not visible);return end
 assert(value.chainChevron and #value.chainChevron==2)
 for _,stroke in ipairs(value.chainChevron)do assert(stroke:IsShown()==visible)end
end
local target=row(92753)
assert(target.title.text==addon.QuestName(92753),"marker never changes literal quest title")
assert(target.factionIcon and target.factionIcon:IsShown()and target.factionReserve==18)
assert(target.factionIcon.width==14 and target.factionIcon.height==14)
assert(target.chainExpandable and not target.chainExpanded and target.chainInset==14)
chevron(target,true)
local singleton=row(168)
assert(not singleton.chainExpandable);chevron(singleton,false)
local oldClick=target.scripts.OnClick
target.scripts.OnClick()
local anchor
for _,value in ipairs(ui.rows)do if value:IsShown()and value.questTreeAnchor then anchor=value end end
assert(anchor and anchor.anchorQuestID==92753 and anchor.chainExpanded)
chevron(anchor,true)
for _,value in ipairs(ui.rows)do if value:IsShown()and value.questTreeNode then
 assert(not value.chainExpandable and not value.chainExpanded)
 chevron(value,false)
end end
row(92742).scripts.OnClick();assert(ui.quest==92742 and ui.questTreeRoot==92753)
anchor.scripts.OnClick();assert(ui.quest==92753 and ui.questTreeRoot==nil)
oldClick();assert(ui.questTreeRoot==nil,"expired collapsed callback cannot reopen chain")

local quest=addon.quests[168]
local original=quest.factions
for _,factions in ipairs({{"Horde"},{"Alliance","Horde"},{"Unknown"},{}})do
 quest.factions=factions;ui:RefreshQuests()
 local value=row(168);local show=#factions==1 and factions[1]=="Horde"
 assert((value.factionIcon and value.factionIcon:IsShown()or false)==show)
 assert(value.factionReserve==(show and 18 or 0))
end
quest.factions=nil;ui:RefreshQuests();assert(not row(168).factionIcon or not row(168).factionIcon:IsShown())
quest.factions=original;ui:RefreshQuests()
local prior=row(168);local current=prior.rowInfoCurrent
assert(current and current())
quest.factions[1]="Horde";assert(not current(),"in-place faction mutation invalidates old marker source")
quest.factions[1]="Alliance";ui:RefreshQuests()
local required=row(166);local proof=required.rowInfoCurrent;assert(proof())
local member=addon.quests[166].requires[1].ids[1]
addon.quests[166].requires[1].ids[1]=168;assert(not proof(),"in-place requirement mutation expires chain proof")
addon.quests[166].requires[1].ids[1]=member
ui:RefreshQuests()
local cache=addon.CachedQuestRewards
addon.CachedQuestRewards=function(id)
 if id==166 then return {source="cache",items={
  {id=7001,name="First",count=1,texture=134400},
  {id=7002,name="Second",count=1,texture=134401},
  {id=7003,name="Third",count=1,texture=134402}},choices={}} end
end
ui:RefreshQuests()
required=row(166)
local iconPoint=required.factionIcon.point
assert(iconPoint[2]==required.title and iconPoint[4]==math.min(required.title:GetStringWidth(),required.title:GetWidth())+4)
local titleLeft=required.title.point[2]
local iconRight=titleLeft+iconPoint[4]+14
assert(iconRight<=required:GetWidth()-70,"faction marker stays left of all three reward slots")
required.title.measuredWidth=30;ui:RefreshQuests()
assert(row(166).factionIcon.point[4]==34,"short names keep the faction marker beside visible text")
required.title.measuredWidth=nil
addon.CachedQuestRewards=cache;ui:RefreshQuests()
local marked=row(166);local marker=marked.factionIcon
local setter,armed=marker.SetPoint,true
marker.SetPoint=function(self,...)
 if armed then armed=false;ui.dungeon=nil;ui:RefreshQuests()end
 return setter(self,...)
end
ui:RefreshQuests()
assert(not armed and ui.rows[1].heading=="PICK"and not marker:IsShown(),"late old marker placement cannot revive a retired row")
marker.SetPoint=setter;ui.dungeon=dungeon;ui:RefreshQuests()
local old=row(166).scripts.OnClick;ui.dungeon=nil;ui:RefreshQuests();old()
assert(ui.rows[1].heading=="PICK"and (not ui.rows[1].factionIcon or not ui.rows[1].factionIcon:IsShown()))
chevron(ui.rows[1],false)
assert(not ui.rows[1].chainExpandable and not ui.rows[1].chainExpanded and ui.rows[1].chainInset==0 and ui.rows[1].factionReserve==0)
print("Actual quest row markers: PASS (literal names, faction scope, chain anchors, singleton cleanup, source drift and stale callbacks)")
