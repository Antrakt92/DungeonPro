-- Class restrictions are pure badges after faction and belong to each displayed quest.
local fixture=assert(loadfile("tests/client_ui.lua"))("fixture")
local addon,ui=fixture.addon,fixture.addon.UI
function fixture.methods:GetStringWidth()return self.measuredWidth or #(self.text or "")*5 end
function fixture.methods:SetAtlas(value)self.atlas=value;return true end
function fixture.methods:GetAtlas()return self.atlas end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();addon.db.locale="enUS"
local dungeon
for _,d in ipairs(addon.dungeons)do if d.key=="dm"then dungeon=d end end
ui.dungeon,ui.quest,ui.includeUnavailable=dungeon,1654,true;ui:Refresh()
local function row(id)
    for _,r in ipairs(ui.rows)do if r:IsShown()and r.questID==id then return r end end
    error("missing row "..id)
end
local paladin=row(1654)
assert(paladin.title.text==addon.QuestName(1654),"class badge never changes literal title")
assert(paladin.classIcons and paladin.classIcons[1]:IsShown()and paladin.classIcons[1].atlas=="classicon-paladin", "Test of Righteousness shows a Paladin icon")
assert(paladin.factionIcon:IsShown()and paladin.classReserve==18 and paladin.factionReserve==18)
assert(paladin.classIcons[1].point[4]==paladin.factionIcon.point[4]+18,"class follows the Alliance crest")
local dtoGet=addon.QuestRowInfo.Get
for _,sample in ipairs({{1442,"PALADIN","Alliance"},{95042,"PALADIN","Horde"},{1740,"WARLOCK"},{1275,nil,"Alliance"}})do
    local dto,proof=dtoGet(addon.quests,sample[1]);assert(dto and proof())
    assert(dto.faction==sample[3]and (#dto.classes==0 and sample[2]==nil or #dto.classes==1 and dto.classes[1]==sample[2]),"actual screenshot restrictions are preserved")
end
local actual=addon.quests[1654]
local originalClasses,originalFactions=actual.classes,actual.factions
local function render()ui:RefreshQuests()end
local all={"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","DEATHKNIGHT","SHAMAN","MAGE","WARLOCK","MONK","DRUID","DEMONHUNTER","EVOKER"}
for _,token in ipairs(all)do
    actual.classes={token};render();local r=row(1654)
    assert(r.classIcons[1].atlas=="classicon-"..token:lower()and r.classIcons[1]:IsShown())
    assert(r.classIcons[1].width==14 and r.classIcons[1].height==14 and r.classReserve==18)
end
actual.classes={"PALADIN","WARRIOR","PALADIN"};render();paladin=row(1654)
assert(paladin.classReserve==36 and paladin.classIcons[1].atlas=="classicon-paladin"and paladin.classIcons[2].atlas=="classicon-warrior")
assert(paladin.classIcons[2].point[4]==paladin.classIcons[1].point[4]+18)
actual.factions=nil;render();paladin=row(1654)
assert(not paladin.factionIcon:IsShown()and paladin.factionReserve==0 and paladin.classIcons[1].point[4]==math.min(paladin.title:GetStringWidth(),paladin.title:GetWidth())+4,
    "class-only quests begin badges immediately after the title")
actual.factions={"Alliance"}
local cached=addon.CachedQuestRewards
addon.CachedQuestRewards=function(id)if id==1654 then return{source="cache",items={{id=1,name="One",count=1,texture=134400},{id=2,name="Two",count=1,texture=134401},{id=3,name="Three",count=1,texture=134402}},choices={}}end end
render();paladin=row(1654)
local last=paladin.classIcons[2]
assert(paladin.title.point[2]+last.point[4]+14<=paladin:GetWidth()-32-70,"all class badges remain left of rewards and navigation")
local sourceProof=paladin.rowInfoCurrent
actual.classes[1]="MAGE";assert(not sourceProof(),"in-place class changes expire existing row actions")
render();paladin=row(1654)
local icon=paladin.classIcons[1];local setter,armed=icon.SetPoint,true
icon.SetPoint=function(self,...)
    if armed then armed=false;actual.classes=nil;ui:RefreshQuests()end
    return setter(self,...)
end
render();icon.SetPoint=setter
assert(not armed and not row(1654).classIcons[1]:IsShown()and not row(1654).classIcons[2]:IsShown(),"late class placement cannot revive retired badges")
actual.classes=all
local widthGetter=ui.questList.GetWidth;ui.questList.GetWidth=function()return 240 end
render();paladin=row(1654)
assert(paladin.audienceBelow and paladin.audienceExtra>0 and paladin.title:GetWidth()>=24,"oversized valid badge groups wrap without negative title width")
for _,badge in ipairs({paladin.factionIcon,unpack(paladin.classIcons)})do
    if badge:IsShown()then
        assert(paladin.title.point[2]+badge.point[4]+14<=paladin:GetWidth()-32-70)
        assert(-paladin.title.point[3]-badge.point[5]+14<=paladin.height,"wrapped class badges stay inside the expanded row")
    end
end
for index,r in ipairs(ui.rows)do if r==paladin and ui.rows[index+1]and ui.rows[index+1]:IsShown()then assert(-ui.rows[index+1].point[3]>=-r.point[3]+r.height+2)end end
ui.questList.GetWidth=widthGetter
actual.classes,actual.factions=originalClasses,originalFactions;addon.CachedQuestRewards=cached
ui.dungeon=nil;render()
for _,r in ipairs(ui.rows)do for _,badge in ipairs(r.classIcons or{})do assert(not badge:IsShown(),"PICK and surplus rows clear pooled class badges")end end
print("Quest class icons: PASS (all13, faction adjacency, multiclass, narrow wrapping, reward/navigation separation and stale pooling)")
