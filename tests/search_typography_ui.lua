-- Pasted typography changes search keys, never displayed titles or exact-ID syntax.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui = fixture.addon, fixture.addon.UI
C_Timer = { After = function() end }
GetLocale = function() return "enUS" end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
ui:Toggle()
ui.dungeon, ui.quest, ui.includeUnavailable, ui.range = nil, nil, true, false
local curly, nbsp, wide = "\226\128\153", "\194\160", "\227\128\128"
local names = {}
for _, dungeon in ipairs(addon.dungeons) do names[dungeon] = dungeon.name end
local function results(query)
    ui.search = query; ui:RefreshDungeons()
    local matches = {}
    for _, card in ipairs(ui.cards) do if card:IsShown() then
        matches[#matches + 1] = card.title.text .. ":" .. tostring(card.matchQuestID)
    end end
    table.sort(matches)
    return table.concat(matches, "\n"), #matches
end
for _, locale in ipairs({ "enUS", "ruRU", "zhCN" }) do
    addon.db.locale = locale
    for _, case in ipairs({
        { "Zul'Farrak", "Zul" .. curly .. "Farrak" },
        { "Atal'Hakkar", "Atal" .. curly .. "Hakkar" },
        { "Zul'Farrak", nbsp .. "Zul'Farrak" .. nbsp },
        { "Zul'Farrak", wide .. "Zul'Farrak" .. wide },
        { "The Orb of Soran'ruk", "The Orb of Soran" .. curly .. "ruk" },
    }) do
        local expected, count = results(case[1])
        assert(count > 0, "actual canonical query must find an existing listed dungeon or quest")
        local actual, actualCount = results(case[2])
        assert(actualCount == count and actual == expected, "pasted typography must find the same displayed records: " .. case[2])
        assert(ui.search == case[2], "search input keeps its original UTF-8 bytes")
    end
end
for dungeon, name in pairs(names) do assert(dungeon.name == name, "canonical display names remain byte-for-byte unchanged") end
assert(addon.SearchFold("Zul" .. curly .. "Farrak") == "zul" .. curly .. "farrak", "Unicode case folding keeps its independent meaning")
assert(addon.SearchFold("Zul\194") == nil and addon.SearchFold("\237\160\128") == nil, "malformed UTF-8 remains rejected")
addon.db.locale = "enUS"
local exact, count = results("1654")
assert(count > 0)
assert(results(" \t1654\r\n") == exact, "ordinary whitespace preserves existing numeric-ID lookup")
for _, padding in ipairs({ nbsp, wide }) do
    assert(addon.SearchQuestID(padding .. "1654" .. padding) == nil, "pasted Unicode spaces do not extend exact-ID grammar")
    local _, matches = results(padding .. "1654" .. padding)
    assert(matches == 0, "a normalized text key never silently becomes an exact-ID lookup")
end
local emptyResults, emptyCount = results("")
for _, malformed in ipairs({ "Zul'Farrak\194", "Zul" .. curly .. "Farrak\237\160\128" }) do
    local actual, matches = results(malformed)
    assert(matches == emptyCount and actual == emptyResults, "invalid UTF-8 fails closed as empty")
end
print("Search typography: PASS (five actual queries, three locales, display preservation, UTF-8 and exact-ID boundaries)")
