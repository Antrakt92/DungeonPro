local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, event = fixture.addon, fixture.eventFrame
event.scripts.OnEvent(event, "ADDON_LOADED", "DungeonPro")
SlashCmdList.DUNGEONPRO("")
local ui, get = addon.UI, addon.DungeonStatus.Get
local builds, states = 0, 0
addon.DungeonStatus.Get = function(dungeon, engine)
    builds = builds + 1
    if not engine.cardTestWrapped then
        engine.cardTestWrapped = true
        local state = engine.State
        engine.State = function(...)
            states = states + 1
            return state(...)
        end
    end
    return get(dungeon, engine)
end
ui.search, ui.range = "", false
ui:Refresh()
assert(builds == #addon.dungeons)
local held = {}
for _, row in ipairs(ui.cards) do
    assert(row.dungeonStatusCurrent() and row.dungeonStatusControl ~= row.entranceControl)
    held[row] = row.dungeonStatusDTO
end
local before, reads = builds, states
assert(addon.Language:Open(ui))
local session = addon.Language.session
for _, locale in ipairs({ "koKR", "zhCN", "ruRU", "enUS" }) do
    addon.Language:Preview(session, locale)
    assert(builds == before and states == reads, "native-shaped language previews reuse catalogue status evidence")
    for row, dto in pairs(held) do assert(row.dungeonStatusDTO == dto and row.dungeonStatusCurrent()) end
end
addon.Language:Cancel(ui)
local row, old = ui.cards[1], ui.cards[1].dungeonStatusCurrent
ui.search = "no dungeon matches this"; ui:RefreshDungeons()
assert(not row:IsShown() and not old())
ui.search = ""; ui:RefreshDungeons()
assert(row:IsShown() and row.dungeonStatusCurrent() and not old())

-- Exercise the actual event/listener path, without replacing the context or planner.
local completed = false
C_QuestLog.IsQuestFlaggedCompleted = function() return completed end
ui:Refresh()
local previous = ui.cards[1].dungeonStatusDTO
completed = true
event.scripts.OnEvent(event, "QUEST_TURNED_IN", addon.dungeons[1].quests[1])
local matched = 0
for _, card in ipairs(ui.cards) do
    local dto = card.dungeonStatusDTO
    assert(dto ~= held[card] and card.dungeonStatusCurrent())
    if dto.eligible > 0 then
        matched = matched + 1
        assert(dto.status == "COMPLETED" and dto.completed == dto.eligible)
    end
end
assert(matched > 0 and ui.cards[1].dungeonStatusDTO ~= previous)
ui.frame:Hide()
completed = false
event.scripts.OnEvent(event, "QUEST_LOG_UPDATE")
SlashCmdList.DUNGEONPRO("")
for _, card in ipairs(ui.cards) do
    assert(card.dungeonStatusCurrent() and card.dungeonStatusDTO.status ~= "COMPLETED",
        "reopening after a hidden quest update cannot retain completed badges")
end
print("Actual dungeon cards: PASS (catalogue, warm locales, pooling, quest events, hidden reopen)")
