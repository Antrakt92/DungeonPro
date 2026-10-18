-- Visible relation labels describe source facts, never full acceptance certainty.
local f = assert(loadfile("tests/client_ui.lua"))("fixture")
local a, ui = f.addon, f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame, "ADDON_LOADED", "DungeonPro")
ui:Toggle(); ui.includeUnavailable = true
local actualDungeons = a.dungeons
local dungeon
for _, d in ipairs(a.dungeons) do if d.key == "dm" then dungeon = d end end
local function row(id)
    for _, r in ipairs(ui.rows) do if r:IsShown() and r.questTreeNode and r.questID == id then return r end end
    error("missing expanded quest " .. id)
end
local function open(d, id)
    ui.dungeon, ui.quest, ui.questTreeRoot, ui.questTreeDungeon = d, id, id, d
    ui:Refresh()
end
local function caption(id, key)
    local r = row(id)
    assert(r.dungeonTargetLabel and r.dungeonTargetLabel:IsShown(), "expanded step must display its relationship: " .. id)
    assert(r.dungeonTargetLabel.text == a.L(key), "step has its own source-backed relationship: " .. id)
    return r
end
for _, locale in ipairs({"enUS","ruRU","deDE","frFR","esES","itIT","ptBR","koKR","zhCN","zhTW"}) do
    a.db.locale = locale
    open(dungeon, 92753)
    assert(a.quests[92753].requires == nil and a.quests[92753].requirementsKnown == false)
    caption(92753, "DUNGEON_QUEST_SHORT")
    assert(caption(92742, "STORY_SHORT").questTreeRelation == "story", "earlier chronology is not a hard requirement")
    caption(92819, "STORY_SHORT")
    open(dungeon, 166)
    assert(a.quests[166].requirementsKnown == false)
    assert(caption(155, "REQUIRED_STEP_SHORT").questTreeRelation == "required", "partial graph still identifies a known prerequisite")
    caption(166, "DUNGEON_QUEST_SHORT")
end

-- An OR option is a prerequisite option; requirements of optional story stay story.
local ids = {991301,991302,991303,991304,991305,991306}
for _, id in ipairs(ids) do a.quests[id] = {id=id,name="Relation "..id,minLevel=1,requirementsKnown=false,
    factions={"Alliance"},classes={"MAGE"},start={npcID=id,name="Own source "..id,mapID=1436,x=20,y=30}} end
a.quests[991301].requires = {{ids={991302,991303}}}
a.quests[991301].storyline = {991301,991304}
a.quests[991304].requires = {{ids={991305}}}
local d = {key="relation-labels",name="Relation labels",minLevel=1,maxLevel=60,quests={991301,991302,991306}}
a.dungeons = {d}; a.db.locale = "enUS"
a.CachedQuestRewards = function()return {source="cache",items={{id=801,name="First reward",count=1,texture=134400},{id=802,name="Second reward",count=1,texture=134400},{id=803,name="Third reward",count=1,texture=134400}},choices={}} end
ui.questList:SetWidth(330)
open(d,991301)
caption(991301,"DUNGEON_QUEST_SHORT")
caption(991302,"DUNGEON_QUEST_SHORT") -- target priority, despite being one OR option
local option = caption(991303,"REQUIRED_STEP_SHORT")
assert(option.branchControl and option.branchControl:IsShown(),"OR choice remains explicit and separate from the label")
caption(991304,"STORY_SHORT")
assert(caption(991305,"STORY_SHORT").questTreeRelation=="required","an optional story's prerequisite is not promoted to the target requirement")
assert(a.quests[991301].requirementsKnown==false and ui.engine:State(991301).status=="UNKNOWN")
for _, r in ipairs(ui.rows) do if r:IsShown() and r.questTreeNode then
    local label=r.dungeonTargetLabel
    assert(r.navigationReserve==32 and r.title.width>0)
    assert(label.width<=92 and label.point[4] <= -6-r.navigationReserve-70,"label remains left of three reward icons and navigation")
    assert(r.dungeonBadgeReserve>=label.width,"title and audience layout reserve the relation label")
    local labelLeft=r:GetWidth()+label.point[4]-label.width
    assert(r.title.point[2]+r.title.width<=labelLeft,"a narrow modeled column keeps the title before the relationship")
end end
-- Controlled font metrics model a wrapped localized label; no native geometry claim.
local height=f.methods.GetStringHeight
f.methods.GetStringHeight=function(self)
    for _,r in ipairs(ui.rows)do if self==r.dungeonTargetLabel then return 48 end end
    return height(self)
end
ui:Refresh()
local previousBottom
for _,r in ipairs(ui.rows)do if r:IsShown()then
    if previousBottom then assert(-r.point[3]>=previousBottom,"wrapped relation cannot overlap the next row")end
    if r.questTreeNode then assert(r:GetHeight()>=60,"wrapped relationship fits inside its row")end
    previousBottom=-r.point[3]+r:GetHeight()
end end
f.methods.GetStringHeight=height
-- A late old Show cannot expose a relationship on a newly collapsed/recycled row.
local nativeShow=f.methods.Show
local oldLabel=caption(991303,"REQUIRED_STEP_SHORT").dungeonTargetLabel
local fired=false
f.methods.Show=function(self)
    if self==oldLabel and not fired then
        fired=true;ui.questTreeRoot,ui.questTreeDungeon=nil,nil;ui:Refresh()
    end
    return nativeShow(self)
end
ui:Refresh();f.methods.Show=nativeShow
assert(fired and not oldLabel:IsShown(),"retired native label Show cannot overwrite the newer collapsed view")
open(d,991301)
local localize=a.L
local localized=false
a.L=function(key,...)
    local value=localize(key,...)
    if key=="REQUIRED_STEP_SHORT" and not localized then
        localized=true;a.db.locale="ruRU";ui:Refresh(true)
    end
    return value
end
ui:Refresh();a.L=localize
assert(localized,"the relationship localizer must exercise a newer locale request")
caption(991303,"REQUIRED_STEP_SHORT")
local old=caption(991303,"REQUIRED_STEP_SHORT").scripts.OnClick
ui.questTreeRoot,ui.questTreeDungeon=nil,nil;ui:Refresh()
for _,r in ipairs(ui.rows)do if r:IsShown()then assert(not r.dungeonTargetLabel or not r.dungeonTargetLabel:IsShown(),"flat/recycled rows never retain a relationship")end end
old();assert(ui.quest==991301,"retired relation row cannot select an old branch")
a.dungeons=actualDungeons
print("Quest relation labels: PASS (actual partial/story chains,10 locales, OR/story scope, target priority, wrapping and recycling)")
