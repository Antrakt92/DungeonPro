-- Live progress stays primary; source goals remain available without text-based deduplication.
local f = assert(loadfile("tests/client_ui.lua"))("fixture")
local a, ui = f.addon, f.addon.UI
C_Timer = { After = function() end }
issecretvalue = function() return false end
GetLocale = function() return "enUS" end
f.eventFrame.scripts.OnEvent(f.eventFrame, "ADDON_LOADED", "DungeonPro")
ui:Toggle(); ui.includeUnavailable = true; a.db.locale = "enUS"
a.Context = function() return { level = 60, faction = "Alliance", class = "MAGE",
    completed = function() return false end, active = function() return true end } end
local owners = {}
for _, d in ipairs(a.dungeons) do for _, id in ipairs(d.quests) do owners[id] = owners[id] or d end end
local liveID, liveRows = 96395, nil
local nativeObjectives = C_QuestLog.GetQuestObjectives
C_QuestLog.GetQuestObjectives = function(id)
    if id == liveID then return liveRows end
    return nil
end
local function live(text, kind)
    return { { text = text, type = kind or "monster", finished = false, numFulfilled = 0, numRequired = 1 } }
end
local function visible(text)
    for _, field in ipairs(ui.details) do
        if field:IsShown() and field.text and field.text:find(text, 1, true) then return true end
    end
    return false
end
local function render(id, rows)
    liveID, liveRows = id, rows
    ui.dungeon, ui.quest = assert(owners[id]), id
    ui.questTreeRoot, ui.questTreeDungeon = nil, nil
    ui:Refresh()
    assert(ui.quest == id and ui.renderedQuest == id, "actual quest detail must own the test")
end
local function toggle()
    local button = ui.recordedObjectivesToggle
    assert(button and button:IsShown() and button.scripts.OnClick,
        "meaningful native progress needs one inline recorded-objectives disclosure")
    return button
end
local function click()
    local button = toggle(); button.scripts.OnClick(button)
end
local function unknown(name) return name .. " ×?" end
local faldrim = assert(a.quests[96395].objectiveKills[1])
assert(faldrim.npcID == 261306 and faldrim.quantity == nil)
render(96395, live("0/1 Faldrim Anvilmar slain"))
assert(visible("0/1 Faldrim Anvilmar slain"))
toggle()
assert(ui.detailObjectivesExpanded ~= true and not visible(unknown(faldrim.name)),
    "live progress is primary and the redundant source quantity stays behind disclosure")
click()
assert(ui.detailObjectivesExpanded == true and visible(unknown(faldrim.name)),
    "manual expansion preserves the actual unknown source quantity")
click()
assert(ui.detailObjectivesExpanded ~= true and not visible(unknown(faldrim.name)))

local explosives = assert(a.quests[92753].objectiveEvents[1])
assert(explosives.npcID == 253370 and explosives.quantity == nil)
render(92753, live("0/1 Explosives placed", "event"))
assert(visible("0/1 Explosives placed") and visible("Extra-Destructive Explosives"),
    "supplied item context remains outside the recorded-goals disclosure")
assert(not visible(unknown(explosives.name)) and ui.detailObjectivesExpanded ~= true)
click(); assert(visible(unknown(explosives.name)) and visible("Extra-Destructive Explosives"))

-- A different native goal is not evidence that catalogue references are duplicates or complete.
render(96395, live("A different live task: 0/1", "event"))
assert(visible("A different live task: 0/1")); toggle(); click()
assert(visible(unknown(faldrim.name)), "all source references stay accessible regardless of client language/text")
for _, rows in ipairs({ {}, live(""), live("  \t ") }) do
    render(92753, rows)
    assert(visible(unknown(explosives.name)), "empty live text must not hide useful source goals")
    assert(not ui.recordedObjectivesToggle or not ui.recordedObjectivesToggle:IsShown(), "empty progress has no empty toggle")
end
render(92753, nil)
assert(visible(unknown(explosives.name)) and (not ui.recordedObjectivesToggle or not ui.recordedObjectivesToggle:IsShown()))

-- Collected items and their acquisition controls are not collapsed just because progress exists.
render(1221, live("Blueleaf Tubers: 0/6", "item"))
assert(visible("Blueleaf Tuber") and visible("Crate With Holes") and visible("Snufflenose Command Stick"))
assert(not ui.recordedObjectivesToggle or not ui.recordedObjectivesToggle:IsShown(), "item-only reference list does not create the goal toggle")

-- Transient disclosure state belongs to the quest, dungeon, character and visible window.
render(96395, live("0/1 Faldrim Anvilmar slain")); click()
render(92753, live("0/1 Explosives placed", "event"))
assert(ui.detailObjectivesExpanded ~= true and not visible(unknown(explosives.name)))
local originalDungeon = ui.dungeon
ui.dungeon = assert(owners[96395]); ui:RefreshDetail()
assert(ui.detailObjectivesExpanded ~= true, "another dungeon cannot inherit expanded state")
ui.dungeon = originalDungeon; ui:RefreshDetail(); click()
local character = a.char; a.char = {}; ui:RefreshDetail()
assert(ui.detailObjectivesExpanded ~= true and not visible(unknown(explosives.name)), "new character starts collapsed")
a.char = character; ui:RefreshDetail(); click()
local retired = toggle().scripts.OnClick
ui.frame:Hide(); if ui.frame.scripts.OnHide then ui.frame.scripts.OnHide(ui.frame) end
retired()
assert(ui.detailObjectivesExpanded ~= true, "hidden window retires the disclosure action")
ui.frame:Show(); ui:RefreshDetail()
assert(ui.detailObjectivesExpanded ~= true)

-- Retained callbacks must not repaint source or live data that has since changed.
render(96395, live("0/1 Faldrim Anvilmar slain")); retired = toggle().scripts.OnClick
render(92753, live("0/1 Explosives placed", "event")); retired()
assert(ui.quest == 92753 and ui.detailObjectivesExpanded ~= true and not visible(unknown(faldrim.name)))
render(96395, live("0/1 Faldrim Anvilmar slain")); retired = toggle().scripts.OnClick
local name = faldrim.name; faldrim.name = "Changed recorded target"; retired()
assert(ui.detailObjectivesExpanded ~= true and not visible(unknown(name)), "retired source identity cannot expand")
faldrim.name = name; ui:RefreshDetail(); retired = toggle().scripts.OnClick
liveRows = live("Fresh live task: 0/1"); retired()
assert(ui.detailObjectivesExpanded ~= true, "changed live evidence retires its old disclosure callback")

-- Ordinary expansion preserves a user reading offset, clamped to the current viewport.
render(96395, live("0/1 Faldrim Anvilmar slain"))
local scroll = ui.detailScroll
scroll.GetVerticalScroll = function(self) return self.verticalScroll or 0 end
scroll.GetVerticalScrollRange = function() return math.max(0, ui.detail:GetHeight() - scroll:GetHeight()) end
local offset = math.min(30, scroll:GetVerticalScrollRange())
scroll:SetVerticalScroll(offset); click()
assert(scroll:GetVerticalScroll() == math.min(offset, scroll:GetVerticalScrollRange()))
click(); assert(scroll:GetVerticalScroll() == math.min(offset, scroll:GetVerticalScrollRange()))

-- A late native expansion write cannot publish old source rows into another quest.
render(96395, live("0/1 Faldrim Anvilmar slain"))
local writer, armed, fired = f.methods.SetText, true, false
f.methods.SetText = function(self, text)
    if armed and text == unknown(faldrim.name) then
        armed, fired = false, true
        render(92753, live("0/1 Explosives placed", "event"))
    end
    return writer(self, text)
end
click(); f.methods.SetText = writer
assert(fired and ui.quest == 92753 and ui.detailObjectivesExpanded ~= true and not visible(unknown(faldrim.name)),
    "source-line reentry cannot resurrect the former card")
-- Reused caption labels refresh their script-capable font after every selected-language change.
local theme, font = assert(a.Theme), assert(a.Theme.ApplyFont)
local fontReads, currentLocale = {}, nil
a.Theme.ApplyFont = function(field, size, ...)
    local control = ui.recordedObjectivesToggle
    if control and field == control.label then
        assert(size == 13 and a.db.locale == currentLocale, "caption font follows the current selected locale")
        fontReads[currentLocale] = (fontReads[currentLocale] or 0) + 1
    end
    return font(field, size, ...)
end
for _, locale in ipairs({ "enUS", "ruRU", "deDE", "frFR", "esES", "ptBR", "koKR", "zhCN", "zhTW", "itIT" }) do
    currentLocale, a.db.locale = locale, locale
    ui.detailObjectivesExpanded = false
    local previousReads = fontReads[locale] or 0
    render(96395, live("0/1 Faldrim Anvilmar slain"))
    local control, caption = toggle(), a.L("DETAIL_RECORDED_OBJECTIVES")
    assert(caption ~= "DETAIL_RECORDED_OBJECTIVES" and control.label.text == "+ " .. caption,
        "collapsed caption uses the actual selected-language dictionary")
    assert((fontReads[locale] or 0) > previousReads, "reused caption must request a fresh locale-aware font")
    click()
    assert(control.label.text == "− " .. caption and visible(unknown(faldrim.name)),
        "expanded source facts remain unchanged in each selected language")
    click()
    assert(control.label.text == "+ " .. caption and not visible(unknown(faldrim.name)))
end
a.Theme.ApplyFont = font
C_QuestLog.GetQuestObjectives = nativeObjectives
print("Recorded objectives UI: PASS (actual held quests, unknown quantities, items, resets, retained ownership and scroll)")
