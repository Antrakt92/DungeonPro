local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon = fixture.addon
function fixture.methods:SetColorTexture(...) self.color = {...} end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
SlashCmdList.DUNGEONPRO("")
local ui, dungeon = addon.UI
for _, value in ipairs(addon.dungeons) do if value.key == "dm" then dungeon = value end end
addon.db.locale = "enUS"
ui.dungeon, ui.quest, ui.questTreeRoot, ui.questTreeDungeon = dungeon, nil, nil, nil
ui:Refresh()
local function row(id)
    for _, value in ipairs(ui.rows) do if value:IsShown() and value.questID == id then return value end end
    error("Missing quest " .. id)
end
assert(addon.quests[92753].requires == nil)
row(92753).scripts.OnClick()
local anchor, branch = nil, {}
for _, value in ipairs(ui.rows) do if value:IsShown() then
    if value.questTreeAnchor then anchor = value end
    if value.questTreeNode then branch[#branch + 1] = value end
end end
assert(anchor and anchor.anchorQuestID == 92753 and anchor.questID == nil)
local expected = addon.quests[92753].storyline
assert(#branch == #expected and #branch == 11)
for index, value in ipairs(branch) do
    assert(value.questID == expected[index], "each step keeps its recorded position")
    assert(value.questTreePath == (index <= 10), "the route ends at the exact target, not its same-named successor")
end
assert(branch[10].questID == 92753 and branch[11].questID == 92819)
assert(branch[10].dungeonTarget and branch[10].questTreeTarget and branch[10].dungeonTargetLabel:IsShown())
assert(not branch[11].dungeonTarget and not branch[11].questTreeTarget)
assert(not branch[11].dungeonTargetLabel or not branch[11].dungeonTargetLabel:IsShown())
for _, id in ipairs({92748, 92752, 92750, 92751, 92753, 92819}) do
    assert(row(id).title.text:find("#" .. id, 1, true), "same-named steps display distinct quest IDs")
end
local first = row(92742)
assert(first.point[3] <= anchor.point[3] - anchor:GetHeight(), "the first child cannot overlap its anchor")
first.scripts.OnClick()
assert(ui.quest == 92742 and ui.questTreeRoot == 92753 and row(92742).questTreeSelected)
assert(row(92742).bg.color[2] > row(92742).bg.color[1], "the selected first step has a visible teal background")
assert(row(92753).bg.color[1] > row(92753).bg.color[2], "the dungeon goal retains its separate warm background")
assert(row(92742).treeRail.color[1] > .5 and row(92819).treeRail.color[1] < .5)
assert(row(92742).questTreeRelation == "story" and addon.quests[92753].requires == nil)
row(92753).scripts.OnClick()
assert(ui.quest == 92753 and ui.questTreeRoot == 92753)
local stale = row(92742).scripts.OnClick
anchor = ui.rows[1]
for _, value in ipairs(ui.rows) do if value:IsShown() and value.questTreeAnchor then anchor = value end end
anchor.scripts.OnClick()
assert(ui.questTreeRoot == nil and ui.quest == 92753)
stale(); assert(ui.quest == 92753, "collapsed branch callbacks expire")
local collapsed = row(92753)
assert(not collapsed.dungeonTargetLabel or not collapsed.dungeonTargetLabel:IsShown(), "collapsed lists avoid repeating dungeon captions")
print("Actual dungeon target path: PASS (chronology, exact IDs, selected first child, persistent goal, collapse)")
