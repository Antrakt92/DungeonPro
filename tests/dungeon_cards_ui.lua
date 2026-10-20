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
-- One- and two-line dungeon names use the same compact card. Longer content grows
-- the whole card, keeping cover, text, and both rail controls vertically balanced.
local measure = fixture.methods.GetStringHeight
local tall = false
fixture.methods.GetStringHeight = function(self)
    if self == ui.cards[1].title then return 18 end
    if self == ui.cards[2].title then return tall and 72 or 36 end
    if self == ui.cards[2].note then return tall and 36 or 18 end
    return 18
end
local function compactGeometry()
    local first, second = ui.cards[1], ui.cards[2]
    assert(first.height == 76, "short dungeon card removes the blank lower strip")
    assert(second.height == (tall and 128 or 76), "two-line names stay compact and long text grows without truncation")
    for _, card in ipairs({first, second}) do
        local coverTop = -card.art.point[3]
        assert(card.art.width == 56 and card.art.height == 60 and coverTop == (card.height - 60) / 2)
        assert(coverTop == card.height - coverTop - card.art.height, "cover has equal top and bottom padding")
        local titleHeight = card == first and 18 or tall and 72 or 36
        local noteHeight = card == second and tall and 36 or 18
        local textTop, noteTop = -card.title.point[3], -card.note.point[3]
        assert(noteTop == textTop + titleHeight + 4 and textTop == card.height - noteTop - noteHeight,
            "title and metadata form one vertically centred readable block")
        assert(card.title.point[2] == 76 and card.note.point[2] == 76 and card.title.width == card:GetWidth() - 112)
        assert(card.title.point[2] + card.title.width <= card:GetWidth() - 36, "text reserves the control rail before wrapping")
        assert(-card.entranceControl.point[5] == coverTop and -card.dungeonStatusControl.point[5] == coverTop + 32)
        assert(-card.entranceControl.point[5] + card.entranceControl.height + 4 == -card.dungeonStatusControl.point[5])
        assert(-card.dungeonStatusControl.point[5] + card.dungeonStatusControl.height == card.height - coverTop)
    end
    assert(-second.point[3] == -first.point[3] + first.height + 8, "card offsets remain cumulative after relayout")
end
ui:RefreshDungeons(); compactGeometry()
local firstCard, firstDTO = ui.cards[1], ui.cards[1].dungeonStatusDTO
local aggregates, stateReads = builds, states
tall = true
assert(addon.Language:Open(ui))
local geometrySession = addon.Language.session
for _, locale in ipairs({"koKR", "ruRU", "enUS"}) do
    addon.Language:Preview(geometrySession, locale)
    compactGeometry()
    assert(ui.cards[1] == firstCard and ui.cards[1].dungeonStatusDTO == firstDTO,
        "language relayout reuses existing card and status evidence")
    assert(builds == aggregates and states == stateReads, "language relayout does not rebuild quest status")
end
addon.Language:Cancel(ui)
fixture.methods.GetStringHeight = measure; ui:RefreshDungeons()
-- Entrance portal glyph prefers the guarded native Dungeon atlas with a map-texture fallback.
do
    local methods = fixture.methods
    local savedSetAtlas, savedGetAtlas = methods.SetAtlas, methods.GetAtlas
    local fallback = "Interface\\Icons\\INV_Misc_Map_01"
    local function freshCards()
        for _, row in ipairs(ui.cards) do row.entranceControl = nil end
        ui:RefreshDungeons()
    end
    local function icons()
        local found = {}
        for _, row in ipairs(ui.cards) do
            local control = row.entranceControl
            assert(control and control.footerIcon, "entrance glyph control exists")
            found[#found + 1] = control.footerIcon
        end
        assert(#found == #addon.dungeons and #found > 0, "entrance glyph paints every dungeon card")
        return found
    end
    methods.SetAtlas = function(self, v) self.atlas = v end
    methods.GetAtlas = function(self) return self.atlas end
    freshCards()
    for _, icon in ipairs(icons()) do assert(icon.atlas == "Dungeon" and icon.texture ~= fallback, "accepted Dungeon atlas keeps the portal glyph") end
    methods.SetAtlas, methods.GetAtlas = nil, nil
    freshCards()
    for _, icon in ipairs(icons()) do assert(icon.texture == fallback, "missing atlas falls back to the map texture") end
    methods.SetAtlas = function() error("missing atlas") end
    methods.GetAtlas = function() return nil end
    freshCards()
    for _, icon in ipairs(icons()) do assert(icon.texture == fallback, "throwing atlas falls back to the map texture") end
    methods.SetAtlas = function(self, v) self.atlas = v; return false end
    methods.GetAtlas = function(self) return self.atlas end
    freshCards()
    for _, icon in ipairs(icons()) do assert(icon.texture == fallback, "rejected atlas falls back to the map texture") end
    methods.SetAtlas = function(self) self.atlas = "wrong" end
    methods.GetAtlas = function(self) return self.atlas end
    freshCards()
    for _, icon in ipairs(icons()) do assert(icon.texture == fallback, "mismatched atlas readback falls back to the map texture") end
    methods.SetAtlas, methods.GetAtlas = savedSetAtlas, savedGetAtlas
    freshCards()
    print("Entrance portal glyph: PASS (native Dungeon atlas with map-texture fallback)")
end
print("Actual dungeon cards: PASS (catalogue, warm locales, pooling, quest events, hidden reopen)")
