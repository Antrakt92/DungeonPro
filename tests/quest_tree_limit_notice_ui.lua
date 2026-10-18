-- Future valid large story lists must disclose the existing bounded preview.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui = fixture.addon, fixture.addon.UI
C_Timer = { After = function() end }
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
ui:Toggle(); ui.includeUnavailable = true
local original = addon.quests
local quests, ids, root = {}, {}, 92753
for id, quest in pairs(original) do quests[id] = quest; ids[#ids + 1] = id end
table.sort(ids)
local controlled = {}
for key, value in pairs(original[root]) do controlled[key] = value end
controlled.storyline, controlled.storylineGroups = { root }, nil
for _, id in ipairs(ids) do
    if id ~= root and #controlled.storyline < 100 then controlled.storyline[#controlled.storyline + 1] = id end
end
assert(#controlled.storyline == 100)
quests[root] = controlled; addon.quests = quests
local function parent(id)
    for _, dungeon in ipairs(addon.dungeons) do
        for _, target in ipairs(dungeon.quests) do if target == id then return dungeon end end
    end
    error("missing actual dungeon target " .. id)
end
local function open(id)
    local dungeon = parent(id)
    ui.dungeon, ui.quest, ui.questTreeRoot, ui.questTreeDungeon = dungeon, id, id, dungeon
    ui:Refresh()
end
local function notices()
    local result = {}
    for _, row in ipairs(ui.rows) do
        if row:IsShown() and row.heading == "CHAIN_TRUNCATED_NOTICE" then result[#result + 1] = row end
    end
    return result
end
open(root)
local tree = assert(addon.QuestTree.Build(quests, ui.engine, root))
assert(tree.truncated and #tree <= 80, "controlled valid 100-step list exercises the existing model limit")
local shown, roots = 0, 0
for _, row in ipairs(ui.rows) do if row:IsShown() and row.questTreeNode then
    shown = shown + 1
    if row.questID == root then roots = roots + 1 end
end end
assert(shown <= 80 and roots == 1, "limited preview remains bounded and keeps its exact target once")
local warnings = notices()
assert(#warnings == 1, "a truncated tree must show exactly one visible partial-chain notice")
assert(warnings[1].title.text == addon.L("CHAIN_TRUNCATED_NOTICE"))
assert(warnings[1].enabled == false and warnings[1].scripts.OnClick == nil, "the notice cannot select or navigate a quest")
ui.questTreeRoot, ui.questTreeDungeon = nil, nil; ui:Refresh()
assert(#notices() == 0, "collapsing and recycling rows clears the old limit notice")
addon.quests = original
open(8945)
tree = assert(addon.QuestTree.Build(original, ui.engine, 8945))
assert(#tree == 24 and not tree.truncated, "the actual largest current chain remains complete")
assert(#notices() == 0, "current complete catalogue chains do not acquire a new warning")
print("Quest tree limit notice: PASS (valid future 100-step story, one noninteractive notice, target/bounds and current 24-step chain)")
