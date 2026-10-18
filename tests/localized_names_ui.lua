local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon = fixture.addon
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
SlashCmdList.DUNGEONPRO("")
local ui = addon.UI
GetLocale = function() return "enUS" end
C_QuestLog.GetTitleForQuestID = function(id) return addon.quests[id] and addon.quests[id].name end
local requests = 0
C_QuestLog.RequestLoadQuestByID = function() requests = requests + 1 end
local dungeon
for _, value in ipairs(addon.dungeons) do if value.key == "dm" then dungeon = value end end
assert(dungeon and addon.quests[166])
ui.dungeon, ui.quest, ui.search, ui.range = dungeon, 166, "", false
addon.db.locale = "enUS"
ui:Refresh()
local function visibleTitle(title)
    for _, row in ipairs(ui.cards) do if row:IsShown() and row.title.text == title then return true end end
    return false
end
local function questTitle(title)
    for _, text in ipairs(ui.details) do if text:IsShown() and text.text == title then return true end end
    return false
end
local coverage = 0
for _, locale in ipairs({ "deDE", "frFR", "esES", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }) do
    addon.db.locale = locale; ui:Refresh()
    local translations = assert(addon.nameTranslations[locale], "selected locale materializes on first use")
    local quest = translations.quests[166]
    local name = translations.dungeons.dm
    if quest and name then
        assert(visibleTitle(name.name), locale .. " catalogue uses selected language")
        assert(ui.heading.text == name.name and questTitle(quest.name), locale .. " heading and selected quest translate together")
        local before = requests
        ui.search = quest.name; ui:RefreshDungeons()
        assert(visibleTitle(name.name), locale .. " translated quest title is searchable")
        assert(requests == before, "translated search does not request native title hydration")
        ui.search = ""; coverage = coverage + 1
    end
end
assert(coverage == 9, "all supported title languages cover both quest and dungeon names")
addon.db.locale = "enUS"; ui:Refresh()
local previous = addon.QuestName(166)
ui.language.scripts.OnEnter()
local session = assert(addon.Language.session)
local russian
for _, row in ipairs(session.rows) do if row.text == "Русский" then russian = row end end
assert(russian); russian.scripts.OnEnter()
local translated = addon.nameTranslations.ruRU
assert(addon.db.locale == "enUS" and questTitle(translated.quests[166].name))
assert(visibleTitle(translated.dungeons.dm.name), "hover previews ordinary dungeon titles too")
addon.Language:Cancel(ui)
assert(addon.db.locale == "enUS" and addon.QuestName(166) == previous and questTitle(previous))
assert(ui.dungeon == dungeon and ui.quest == 166, "language preview retains current dungeon and quest")
local nativeReads = 0
C_QuestLog.GetTitleForQuestID = function(id)
    nativeReads = nativeReads + 1
    return addon.quests[id] and addon.quests[id].name
end
local screenshotIDs = {92747,92748,92750,92751,92752,92753,92819}
local originalDungeon, originalQuest = ui.dungeon, ui.quest
local initialRequests = requests
for _, locale in ipairs({"deDE","frFR","esES","itIT","ptBR","ruRU","koKR","zhCN","zhTW"}) do
    GetLocale = function() return locale end
    addon.db.locale = locale
    local dictionary = assert(addon.GetNameTranslations(locale, function()return true end))
    for id, definition in pairs(addon.quests) do
        local entry = assert(dictionary.quests[id], locale .. " missing quest " .. id)
        assert(entry.source == definition.name and addon.CachedQuestName(id) == entry.name and addon.QuestName(id) == entry.name,
            "the complete selected-language pack wins over matching-client English cache text")
    end
    for _, definition in ipairs(addon.dungeons) do
        local entry = assert(dictionary.dungeons[definition.key], locale .. " missing dungeon " .. definition.key)
        assert(entry.source == definition.name and addon.DungeonName(definition) == entry.name,
            "all dungeon titles retain the selected language and wing suffix exactly once")
    end
    ui.dungeon, ui.quest = dungeon, 92753; ui.questTreeRoot, ui.questTreeDungeon = 92753, dungeon
    ui:Refresh()
    for _, id in ipairs(screenshotIDs) do
        local entry = dictionary.quests[id]
        assert(entry.name ~= entry.source, locale .. " screenshot quest still falls back to English")
        ui.quest = id; ui:RefreshDetail()
        assert(questTitle(entry.name), locale .. " selected screenshot quest title is localized")
    end
    for _, row in ipairs(ui.rows) do
        local id = row.questID or row.anchorQuestID
        if row:IsShown() and id then assert(row.title.text == dictionary.quests[id].name or row.title.text == dictionary.quests[id].name .. " #" .. id, "chain and list titles use the same language as details, with IDs only to distinguish repeated names") end
    end
end
assert(nativeReads == 0 and requests == initialRequests, "complete title browsing uses lazy offline dictionaries without native reads or hydration")
addon.db.locale = "enUS"; GetLocale = function()return "zhCN"end
assert(addon.QuestName(92753) == addon.quests[92753].name, "forcing English never reuses the Chinese dictionary")
ui.dungeon, ui.quest = originalDungeon, originalQuest
print("Actual localized name composition: PASS (selected titles, translated search, preview, cancellation)")
