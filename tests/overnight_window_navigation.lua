-- The navigation module is inert at load; actual TOC integration retains its own sources.
local isolated = {}
assert(loadfile("UI/QuestNavigation.lua"))("DungeonPro", isolated)
assert(type(isolated.QuestNavigation) == "table" and isolated.UI == nil,
    "loading navigation must not create or replace the window")

local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui = fixture.addon, fixture.addon.UI
assert(addon.QuestNavigation ~= isolated.QuestNavigation, "separate addon loads retain separate exports")
for name, method in pairs(addon.QuestNavigation) do
    assert(type(method) == "function" and ui[name] == method,
        "the actual window must use the loaded navigation methods")
end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
ui:Toggle(); addon.db.locale = "enUS"
for _, dungeon in ipairs(addon.dungeons) do if dungeon.key == "dm" then ui.dungeon = dungeon end end
ui.quest = 166; ui.includeUnavailable = true; ui:Refresh()
local function row(id)
    for _, candidate in ipairs(ui.rows) do
        if candidate:IsShown() and candidate.questID == id then return candidate end
    end
    error("missing actual quest row " .. id)
end
local selected, history = ui.quest, ui.detailHistory
local destination, visits = addon.quests[166].start, 0
addon.Navigation.Start = function(action)
    assert(action.id == 166 and action.kind == "visit" and action.place == destination,
        "the row must dispatch its own actual recorded giver")
    visits = visits + 1
    return true
end
ui:Refresh()
local first = row(166).navigationControl
assert(first:IsShown() and first.enabled)
local retired = first.scripts.OnClick
retired()
assert(visits == 1 and ui.quest == selected and ui.detailHistory == history,
    "direct navigation must preserve detail selection and history")
local originalX = destination.x
destination.x = originalX + .1
retired()
assert(visits == 1, "a retained click must reject an in-place source change")
destination.x = originalX
ui:Refresh()
local oldClick = row(166).navigationControl.scripts.OnClick
local character = addon.char
addon.char = {}; oldClick()
assert(visits == 1, "a retained click must reject a different character")
addon.char = character

-- Actual item sources remain manual inspection, not a guessed NPC destination.
for _, dungeon in ipairs(addon.dungeons) do if dungeon.key == "wc" then ui.dungeon = dungeon end end
ui.quest = nil; ui:Refresh()
local source = row(6981).navigationControl
assert(source.enabled and source.sourceInspect == true)
source.scripts.OnClick()
assert(ui.quest == 6981 and ui.renderedQuest == 6981 and visits == 1,
    "the item-source book opens its own details without navigation")
local mutanusVisible = false
for _, field in ipairs(ui.details) do
    if field:IsShown() and field.text and field.text:find("Mutanus the Devourer", 1, true) then mutanusVisible = true end
end
assert(mutanusVisible, "source inspection must expose the recorded acquisition source immediately")
print("Extracted window navigation checks passed (actual TOC, modeled native controls)")
