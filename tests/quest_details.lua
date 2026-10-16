local addon, total = {}, 0
local locale, selected, textCalls = "ruRU", 200, 0
local secret = {}
issecretvalue = function(value) return value == secret end
GetLocale = function() return locale end
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
addon.L = function(key) return key end
addon.char = { texts = {} }
local function check(name, fn)
    selected = 166
    C_QuestLog = { GetSelectedQuest = function() return selected end }
    GetQuestLogQuestText = nil
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err))
    total = total + 1
    print("PASS " .. name)
end
check("Another selected quest never contaminates the requested description cache", function()
    selected = 200
    local reads = 0
    C_QuestLog.GetLogIndexForQuestID = function() return 7 end
    GetQuestLogQuestText = function() reads = reads + 1; return "Other quest's text" end
    assert(addon.Description(166) == "NO_TEXT")
    assert(addon.char.texts[166] == nil and selected == 200 and reads == 0)
end)
check("Selected active quest description is read without changing selection", function()
    C_QuestLog.GetLogIndexForQuestID = function(id) assert(id == 166); return 7 end
    C_QuestLog.SetSelectedQuest = function() error("Selection must not change") end
    GetQuestLogQuestText = function(...)
        assert(select("#", ...) == 0 and selected == 166); textCalls = textCalls + 1
        return "Current localized description", "Objective summary"
    end
    assert(addon.Description(166) == "Current localized description")
    assert(textCalls == 1 and selected == 166)
    assert(addon.char.texts[166].locale == "ruRU")
end)
check("Selection changes during description reads preserve the original quest cache", function()
    local previous = addon.char.texts[166]
    C_QuestLog.GetLogIndexForQuestID = function() return 7 end
    GetQuestLogQuestText = function() selected = 200; return "Another quest's description" end
    assert(addon.Description(166) == "Current localized description")
    assert(addon.char.texts[166] == previous and addon.char.texts[200] == nil)
end)
check("Changed log index invalidates a selected-description snapshot", function()
    local previous, index = addon.char.texts[166], 7
    C_QuestLog.GetLogIndexForQuestID = function() return index end
    GetQuestLogQuestText = function() index = 8; return "Changed log snapshot" end
    assert(addon.Description(166) == "Current localized description")
    assert(addon.char.texts[166] == previous)
end)
check("Locale changes during description reads never mislabel cached text", function()
    local previous = addon.char.texts[166]
    C_QuestLog.GetLogIndexForQuestID = function() return 7 end
    GetQuestLogQuestText = function() locale = "enUS"; return "New English description" end
    assert(addon.Description(166) == "NO_TEXT")
    assert(addon.char.texts[166] == previous)
    locale = "ruRU"
end)
check("Cached native description remains available after leaving the quest log", function()
    C_QuestLog.GetLogIndexForQuestID = function() return nil end
    assert(addon.Description(166) == "Current localized description")
    assert(addon.Description(167) == "NO_TEXT")
end)
check("Descriptions from another client locale are not reused", function()
    locale = "enUS"
    assert(addon.Description(166) == "NO_TEXT")
    locale = "ruRU"
end)
check("Native description works before persistence initialization", function()
    local saved = addon.char; addon.char = nil
    selected = 168
    C_QuestLog.GetLogIndexForQuestID = function() return 1 end
    GetQuestLogQuestText = function() return "Uncached description" end
    assert(addon.Description(168) == "Uncached description")
    addon.char = saved
end)
check("Description rejects unknown and invalid log indexes", function()
    selected = 168
    GetQuestLogQuestText = function() error("Invalid index reached reader") end
    for _, value in ipairs({ 0, -1, 0.5, math.huge, secret }) do
        C_QuestLog.GetLogIndexForQuestID = function() return value end
        assert(addon.Description(168) == "NO_TEXT")
    end
end)
check("Missing restricted or failing selection APIs never read another quest's text", function()
    local reads = 0
    C_QuestLog.GetLogIndexForQuestID = function() return 1 end
    GetQuestLogQuestText = function() reads = reads + 1; return "Unverified text" end
    C_QuestLog.GetSelectedQuest = nil
    assert(addon.Description(168) == "NO_TEXT")
    C_QuestLog.GetSelectedQuest = function() return secret end
    assert(addon.Description(168) == "NO_TEXT")
    C_QuestLog.GetSelectedQuest = function() error("Unavailable") end
    assert(addon.Description(168) == "NO_TEXT")
    assert(reads == 0)
end)
check("Description API errors and restricted text preserve prior cached text", function()
    C_QuestLog.GetLogIndexForQuestID = function() return 7 end
    for _, value in ipairs({ secret, string.rep("x", 30001), "" }) do
        GetQuestLogQuestText = function() return value end
        assert(addon.Description(166) == "Current localized description")
    end
    GetQuestLogQuestText = function() error("Unavailable") end
    assert(addon.Description(166) == "Current localized description")
    C_QuestLog.GetLogIndexForQuestID = function() error("Unavailable") end
    assert(addon.Description(166) == "Current localized description")
end)
check("Restricted or invalid quest IDs never reach native readers", function()
    C_QuestLog.GetLogIndexForQuestID = function() error("Invalid ID reached reader") end
    C_QuestLog.GetQuestObjectives = function() error("Invalid ID reached reader") end
    for _, id in ipairs({ secret, "166", 0, -1, math.huge, 1.5 }) do
        assert(addon.Description(id) == "NO_TEXT" and addon.QuestObjectives(id) == nil)
    end
end)
local function objective()
    return { text = "Defias defeated: 2/6", type = "monster", finished = false,
        numFulfilled = 2, numRequired = 6, objectiveType = 0 }
end
check("Objective adapter returns detached clean native rows preserving false", function()
    local rows = { objective() }
    C_QuestLog.GetQuestObjectives = function(id) assert(id == 166); return rows end
    local result = addon.QuestObjectives(166)
    assert(result ~= rows and result[1] ~= rows[1])
    assert(result[1].text == rows[1].text and result[1].finished == false)
    assert(result[1].numFulfilled == 2 and result[1].numRequired == 6)
    result[1].numFulfilled = 99
    assert(rows[1].numFulfilled == 2)
end)
check("Unavailable and failing objective APIs remain unknown", function()
    assert(addon.QuestObjectives(166) == nil)
    C_QuestLog.GetQuestObjectives = function() return nil end
    assert(addon.QuestObjectives(166) == nil)
    C_QuestLog.GetQuestObjectives = function() error("Unavailable") end
    assert(addon.QuestObjectives(166) == nil)
    C_QuestLog.GetQuestObjectives = function() return secret end
    assert(addon.QuestObjectives(166) == nil)
end)
check("Restricted fields do not become empty or completed objectives", function()
    for _, field in ipairs({ "text", "type", "finished", "numFulfilled", "numRequired" }) do
        local row = objective(); row[field] = secret
        C_QuestLog.GetQuestObjectives = function() return { row } end
        assert(addon.QuestObjectives(166) == nil, field)
    end
end)
check("Invalid counts and malformed objective records remain unknown", function()
    for _, value in ipairs({ -1, math.huge, "2" }) do
        local row = objective(); row.numFulfilled = value
        C_QuestLog.GetQuestObjectives = function() return { row } end
        assert(addon.QuestObjectives(166) == nil)
    end
    C_QuestLog.GetQuestObjectives = function() return { "not a row" } end
    assert(addon.QuestObjectives(166) == nil)
    local rows = {}; for i = 1, 101 do rows[i] = objective() end
    C_QuestLog.GetQuestObjectives = function() return rows end
    assert(addon.QuestObjectives(166) == nil)
end)
check("Optional restricted objective metadata is omitted and empty arrays preserved", function()
    local row = objective(); row.objectiveType = secret
    C_QuestLog.GetQuestObjectives = function() return { row } end
    assert(addon.QuestObjectives(166)[1].objectiveType == nil)
    C_QuestLog.GetQuestObjectives = function() return {} end
    local result = addon.QuestObjectives(166)
    assert(type(result) == "table" and next(result) == nil)
end)
check("Empty offered text preserves the last valid cached description", function()
    GetQuestID = function() return 166 end
    GetQuestText = function() return "Valid offered text" end
    addon.quests = { [166] = { name = "Fallback" } }
    addon.CaptureQuestText()
    GetQuestText = function() return "" end
    addon.CaptureQuestText()
    assert(addon.Description(166) == "Valid offered text")
end)
check("Offered quest changes during reads never cache text for the old quest", function()
    local previous, offered = addon.char.texts[166], 166
    addon.quests[200] = { name = "Other quest" }
    GetQuestID = function() return offered end
    GetQuestText = function() offered = 200; return "Other offered description" end
    addon.CaptureQuestText()
    assert(addon.char.texts[166] == previous and addon.char.texts[200] == nil)
    addon.quests[200] = nil
end)
check("Offered text is not persisted under a locale that changes during the read", function()
    local previous = addon.char.texts[166]
    GetQuestID = function() return 166 end
    local localeCalls = 0
    GetLocale = function()
        localeCalls = localeCalls + 1
        return localeCalls == 1 and "ruRU" or "enUS"
    end
    GetQuestText = function() return "Unstable locale description" end
    addon.CaptureQuestText()
    assert(addon.char.texts[166] == previous)
    GetLocale = function() return locale end
end)
check("Failed title loads retry with a bound and coalesce repeated reads", function()
    local callbacks, calls = {}, 0
    C_Timer = { After = function(_, fn) callbacks[#callbacks + 1] = fn end }
    addon.quests = { [167] = { name = "Fallback" } }
    addon.Notify = function() addon.QuestName(167) end
    C_QuestLog.RequestLoadQuestByID = function()
        calls = calls + 1
        error("Temporary failure")
    end
    for i = 1, 10 do assert(addon.QuestName(167) == "Fallback") end
    assert(calls == 1 and #callbacks == 1)
    callbacks[1](); assert(calls == 2 and #callbacks == 2)
    callbacks[2](); assert(calls == 3 and #callbacks == 2)
    for i = 1, 10 do addon.QuestName(167) end
    assert(calls == 3)
    C_QuestLog.GetTitleForQuestID = function() return "Localized title" end
    assert(addon.QuestName(167) == "Localized title")
end)
check("Synchronous title failure events keep pending state and delayed recovery", function()
    local callbacks, calls = {}, 0
    C_Timer = { After = function(_, fn) callbacks[#callbacks + 1] = fn end }
    addon.quests = { [168] = { name = "Fallback" } }
    addon.Notify = function() addon.QuestName(168) end
    C_QuestLog.RequestLoadQuestByID = function(id)
        calls = calls + 1; addon.QuestDataResult(id, false)
    end
    addon.QuestName(168); assert(calls == 1 and #callbacks == 1)
    addon.QuestDataResult(168, false); addon.QuestDataResult(999, false)
    assert(#callbacks == 1)
    callbacks[1](); assert(calls == 2)
    C_QuestLog.RequestLoadQuestByID = function(id)
        calls = calls + 1; addon.QuestDataResult(id, true)
    end
    callbacks[2](); assert(calls == 3)
    for i = 1, 5 do addon.QuestName(168) end
    assert(calls == 3 and #callbacks == 2)
end)
check("Silent title requests time out and stale watchdogs cannot fail a newer attempt", function()
    local isolated = {}
    assert(loadfile("Core/Namespace.lua"))("DungeonPro", isolated)
    assert(loadfile("Core/Client.lua"))("DungeonPro", isolated)
    isolated.quests = { [169] = { name = "Fallback" } }
    local queue, calls = {}, 0
    C_Timer = { After = function(delay, fn) queue[#queue + 1] = { delay, fn } end }
    C_QuestLog = { RequestLoadQuestByID = function() calls = calls + 1 end }
    isolated.Notify = function() isolated.QuestName(169) end
    assert(isolated.QuestName(169) == "Fallback" and calls == 1)
    assert(#queue == 1 and queue[1][1] == 10)
    local old = queue[1][2]
    old(); assert(#queue == 2 and queue[2][1] == 2)
    queue[2][2](); assert(calls == 2 and #queue == 3)
    old(); assert(#queue == 3 and calls == 2)
    queue[3][2](); queue[4][2](); assert(calls == 3 and #queue == 5)
    queue[5][2](); assert(#queue == 5)
    for _ = 1, 10 do isolated.QuestName(169) end
    assert(calls == 3)
end)
check("Successful title events invalidate a pending request watchdog", function()
    local isolated = {}
    assert(loadfile("Core/Namespace.lua"))("DungeonPro", isolated)
    assert(loadfile("Core/Client.lua"))("DungeonPro", isolated)
    isolated.quests = { [170] = { name = "Fallback" } }
    local callbacks, calls = {}, 0
    C_Timer = { After = function(_, fn) callbacks[#callbacks + 1] = fn end }
    C_QuestLog = { RequestLoadQuestByID = function() calls = calls + 1 end }
    isolated.QuestName(170)
    assert(#callbacks == 1)
    isolated.QuestDataResult(170, true); callbacks[1]()
    isolated.QuestName(170); assert(calls == 1 and #callbacks == 1)
end)
check("Invalid and future schemas preserve saved roots and active state exactly", function()
    local savedDB, savedChar, activeDB, activeChar = DungeonProDB, DungeonProCharDB, addon.db, addon.char
    for _, schema in ipairs({ 0 / 0, math.huge, -math.huge, -1, 0, 0.5, 1.5, false, "1", {}, 2, 99, secret }) do
        local marker, charMarker = {}, {}
        local db = { schema = schema, locale = false, window = false, marker = marker }
        local char = { texts = false, filters = false, marker = charMarker }
        DungeonProDB, DungeonProCharDB = db, char
        assert(addon.RestoreDB() == false)
        assert(DungeonProDB == db and DungeonProCharDB == char)
        assert(addon.db == activeDB and addon.char == activeChar)
        assert(db.marker == marker and db.locale == false and db.window == false)
        assert(char.marker == charMarker and char.texts == false and char.filters == false)
        if type(schema) == "number" and schema ~= schema then assert(db.schema ~= db.schema)
        else assert(db.schema == schema) end
    end
    DungeonProDB, DungeonProCharDB = savedDB, savedChar
end)
check("Current and absent schemas retain valid roots nested identities and unrelated fields", function()
    local savedDB, savedChar, activeDB, activeChar = DungeonProDB, DungeonProCharDB, addon.db, addon.char
    for _, withSchema in ipairs({ false, true }) do
        local window, texts, filters, marker = {}, {}, {}, {}
        local db = { locale = "ruRU", window = window, marker = marker }
        if withSchema then db.schema = 1 end
        local char = { texts = texts, filters = filters, marker = marker }
        DungeonProDB, DungeonProCharDB = db, char
        assert(addon.RestoreDB() == true)
        assert(db.schema == 1 and db.locale == "ruRU" and db.marker == marker)
        assert(DungeonProDB == db and addon.db == db and db.window == window)
        assert(DungeonProCharDB == char and addon.char == char and char.texts == texts and char.filters == filters)
        assert(char.marker == marker)
    end
    DungeonProDB, DungeonProCharDB, addon.db, addon.char = savedDB, savedChar, activeDB, activeChar
end)
check("Renamed saved roots adopt loaded legacy roots without replacing nested settings", function()
    local newDB, newChar, legacyDB, legacyChar = DungeonProDB, DungeonProCharDB, DungeonPrepDB, DungeonPrepCharDB
    local activeDB, activeChar = addon.db, addon.char
    local window, texts, filters, marker = {}, {}, {}, {}
    local db = { schema = 1, locale = "ruRU", window = window, marker = marker }
    local char = { texts = texts, filters = filters, marker = marker }
    DungeonProDB, DungeonProCharDB, DungeonPrepDB, DungeonPrepCharDB = nil, nil, db, char
    assert(addon.RestoreDB())
    assert(DungeonProDB == db and DungeonProCharDB == char and addon.db == db and addon.char == char)
    assert(DungeonPrepDB == db and DungeonPrepCharDB == char)
    assert(db.window == window and char.texts == texts and char.filters == filters and char.marker == marker)
    DungeonProDB, DungeonProCharDB, DungeonPrepDB, DungeonPrepCharDB = newDB, newChar, legacyDB, legacyChar
    addon.db, addon.char = activeDB, activeChar
end)
check("New saved roots win independently over legacy settings without altering the ignored root", function()
    local newDB, newChar, legacyDB, legacyChar = DungeonProDB, DungeonProCharDB, DungeonPrepDB, DungeonPrepCharDB
    local activeDB, activeChar = addon.db, addon.char
    for _, accountNew in ipairs({ false, true }) do
        for _, characterNew in ipairs({ false, true }) do
            local db, char = { schema = 1, locale = "enUS", window = {} }, { texts = {}, filters = {} }
            local oldDB = { schema = accountNew and 99 or 1, locale = "ruRU", window = {} }
            local oldChar = { texts = {}, filters = {} }
            DungeonProDB, DungeonProCharDB = accountNew and db or nil, characterNew and char or nil
            DungeonPrepDB, DungeonPrepCharDB = oldDB, oldChar
            assert(addon.RestoreDB())
            assert(DungeonProDB == (accountNew and db or oldDB))
            assert(DungeonProCharDB == (characterNew and char or oldChar))
            assert(DungeonPrepDB == oldDB and DungeonPrepCharDB == oldChar)
            assert(oldDB.locale == "ruRU" and oldDB.schema == (accountNew and 99 or 1))
        end
    end
    DungeonProDB, DungeonProCharDB, DungeonPrepDB, DungeonPrepCharDB = newDB, newChar, legacyDB, legacyChar
    addon.db, addon.char = activeDB, activeChar
end)
check("Invalid legacy schema fails atomically before adopting or normalizing either root", function()
    local newDB, newChar, legacyDB, legacyChar = DungeonProDB, DungeonProCharDB, DungeonPrepDB, DungeonPrepCharDB
    local activeDB, activeChar = addon.db, addon.char
    for _, schema in ipairs({ 99, "1", false, secret, 0/0 }) do
        local db, char = { schema = schema, window = false, locale = false }, { texts = false, filters = false }
        DungeonProDB, DungeonProCharDB, DungeonPrepDB, DungeonPrepCharDB = nil, nil, db, char
        assert(addon.RestoreDB() == false)
        assert(DungeonProDB == nil and DungeonProCharDB == nil)
        assert(DungeonPrepDB == db and DungeonPrepCharDB == char and db.window == false and db.locale == false)
        assert(char.texts == false and char.filters == false and addon.db == activeDB and addon.char == activeChar)
    end
    DungeonProDB, DungeonProCharDB, DungeonPrepDB, DungeonPrepCharDB = newDB, newChar, legacyDB, legacyChar
end)
check("An invalid new root is preserved and cannot fall through to a valid legacy root", function()
    local newDB, newChar, legacyDB, legacyChar = DungeonProDB, DungeonProCharDB, DungeonPrepDB, DungeonPrepCharDB
    local activeDB, activeChar = addon.db, addon.char
    for _, bad in ipairs({ false, "invalid", 123, secret, { schema = 99, window = false } }) do
        DungeonProDB, DungeonProCharDB = bad, nil
        DungeonPrepDB, DungeonPrepCharDB = { schema = 1 }, { texts = {}, filters = {} }
        assert(addon.RestoreDB() == false and DungeonProDB == bad and DungeonProCharDB == nil)
        assert(addon.db == activeDB and addon.char == activeChar)
        if type(bad) ~= "table" or bad == secret then
            DungeonProDB, DungeonProCharDB = { schema = 1, window = false }, bad
            assert(addon.RestoreDB() == false and DungeonProCharDB == bad and DungeonProDB.window == false)
        end
    end
    DungeonProDB, DungeonProCharDB, DungeonPrepDB, DungeonPrepCharDB = newDB, newChar, legacyDB, legacyChar
end)
check("Broken or missing title schedulers release pending requests within three attempts", function()
    local savedTimer = C_Timer
    for _, timer in ipairs({ {}, { After = true }, { After = function() error("scheduler failed") end } }) do
        local isolated, calls, notifications = {}, 0, 0
        assert(loadfile("Core/Namespace.lua"))("DungeonPro", isolated)
        assert(loadfile("Core/Client.lua"))("DungeonPro", isolated)
        isolated.quests[777] = { name = "Fallback" }
        isolated.Notify = function() notifications = notifications + 1; isolated.QuestName(777) end
        C_Timer = timer
        C_QuestLog = { RequestLoadQuestByID = function() calls = calls + 1 end }
        for _ = 1, 20 do assert(isolated.QuestName(777) == "Fallback") end
        assert(calls == 3 and notifications == 0, "scheduler failure must neither stick pending nor notify recursively")
    end
    C_Timer = savedTimer
end)
check("A throwing retry scheduler permits bounded later title requests", function()
    local isolated, calls = {}, 0
    assert(loadfile("Core/Namespace.lua"))("DungeonPro", isolated)
    assert(loadfile("Core/Client.lua"))("DungeonPro", isolated)
    isolated.quests[778] = { name = "Fallback" }
    isolated.Notify = function() error("must not notify immediately") end
    C_QuestLog = { RequestLoadQuestByID = function(id) calls = calls + 1; isolated.QuestDataResult(id, false) end }
    local saved = C_Timer
    C_Timer = { After = function() error("retry timer failed") end }
    for _ = 1, 10 do isolated.QuestName(778) end
    assert(calls == 3)
    C_Timer = saved
end)
check("Selected descriptions cannot write into a replaced character or texts destination", function()
    local saved = addon.char
    for mode = 1, 2 do
        local originalTexts = { [166] = { text = "Previous verified text", locale = "ruRU" } }
        local character = { texts = originalTexts }
        addon.char = character
        C_QuestLog.GetLogIndexForQuestID = function() return 7 end
        GetQuestLogQuestText = function()
            if mode == 1 then addon.char = { texts = {} } else character.texts = {} end
            return "Old source text"
        end
        assert(addon.Description(166) == "NO_TEXT")
        assert(addon.char.texts[166] == nil and originalTexts[166].text == "Previous verified text")
    end
    addon.char = saved
end)
check("Description capability replacement preserves the prior verified same-locale cache", function()
    local saved, oldLocale, oldChecker = addon.char, GetLocale, issecretvalue
    for mode = 1, 5 do
        local prior = { text = "Previous verified text", locale = "ruRU" }
        addon.char = { texts = { [166] = prior } }
        GetLocale = function() return "ruRU" end
        issecretvalue = oldChecker
        C_QuestLog = { GetSelectedQuest = function() return 166 end, GetLogIndexForQuestID = function() return 7 end }
        GetQuestLogQuestText = function()
            if mode == 1 then C_QuestLog = { GetSelectedQuest = function() return 166 end, GetLogIndexForQuestID = function() return 7 end }
            elseif mode == 2 then GetQuestLogQuestText = function() return "Replacement" end
            elseif mode == 3 then C_QuestLog.GetSelectedQuest = function() return 166 end
            elseif mode == 4 then GetLocale = function() return "ruRU" end
            else issecretvalue = function() return false end end
            return "Mixed native text"
        end
        assert(addon.Description(166) == "Previous verified text" and addon.char.texts[166] == prior)
    end
    addon.char, GetLocale, issecretvalue = saved, oldLocale, oldChecker
end)
print("Quest detail modeled checks passed: " .. total .. " (native client unverified)")
