local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local secret, selected, index, display, name, calls, writes = {}, nil, nil, nil, nil, 0, 0
local function reset()
    GetLocale = function() return "enUS" end
    selected, index, display, name, calls, writes = 95036, 7, 12345, "Native Portrait", 0, 0
    issecretvalue = function(v) return v == secret end
    C_QuestLog = {
        GetSelectedQuest = function() return selected end,
        GetLogIndexForQuestID = function(id) assert(id == 95036); return index end,
        GetQuestLogPortraitGiver = function(logIndex, ...)
            calls = calls + 1
            assert(logIndex == 7 and select("#", ...) == 0, "expected explicit log index, not quest ID")
            return display, "Portrait narrative", name, 888, 999
        end,
        SetSelectedQuest = function() writes = writes + 1; error("selection writes forbidden") end,
    }
end
local function check(label, fn)
    reset()
    local ok, err = pcall(fn)
    if not ok then error(label .. ": " .. tostring(err), 0) end
    assert(writes == 0, "quest selection changed")
    total = total + 1; print("PASS " .. label)
end
check("Portrait uses explicit log index and exact first and third tuple fields", function()
    local p = addon.QuestPortrait(95036)
    assert(calls == 1 and p.displayID == 12345 and p.name == "Native Portrait")
    assert(p.id == nil and p.npcID == nil and p.questID == nil and p.mount == nil and p.text == nil)
end)
check("Another selected quest and missing APIs never read an unrelated portrait", function()
    selected = 95042; assert(addon.QuestPortrait(95036) == nil and calls == 0)
    reset(); C_QuestLog.GetQuestLogPortraitGiver = nil; assert(addon.QuestPortrait(95036) == nil)
    C_QuestLog = nil; assert(addon.QuestPortrait(95036) == nil)
end)
check("Invalid quest IDs and absent or invalid log indexes never reach the reader", function()
    for _, value in ipairs({ 0, -1, 1.5, "95036", math.huge, 0 / 0, secret }) do
        assert(addon.QuestPortrait(value) == nil and calls == 0)
    end
    assert(addon.QuestPortrait(nil) == nil)
    for _, value in ipairs({ 0, -1, 1.5, "7", math.huge, 0 / 0, secret }) do
        index = value; assert(addon.QuestPortrait(95036) == nil and calls == 0)
    end
    index = nil; assert(addon.QuestPortrait(95036) == nil and calls == 0)
end)
check("Negative restricted and malformed display IDs produce no portrait", function()
    for _, value in ipairs({ -1, -22, 1.5, false, "12345", math.huge, 0 / 0, secret }) do
        display = value; assert(addon.QuestPortrait(95036) == nil)
    end
    display = nil; assert(addon.QuestPortrait(95036) == nil)
end)
check("Precision-collapsed and over-wide display IDs are unknown while uint32 max stays valid", function()
    display = 4294967295
    local p = addon.QuestPortrait(95036)
    assert(p and p.displayID == 4294967295, "uint32 max display stays accepted")
    display = 4294967296; assert(addon.QuestPortrait(95036) == nil)
    display = 9007199254740992; assert(addon.QuestPortrait(95036) == nil)
    display = 9007199254740993; assert(addon.QuestPortrait(95036) == nil)
end)
check("Native zero portrait is an explicit hidden instruction", function()
    display = 0
    local p = addon.QuestPortrait(95036)
    assert(calls == 1 and p.hidden == true and p.displayID == nil and p.name == nil and p.source == nil)
end)
check("Missing tuple and native selection index or portrait errors remain unknown", function()
    C_QuestLog.GetQuestLogPortraitGiver = function() end
    assert(addon.QuestPortrait(95036) == nil)
    reset(); C_QuestLog.GetQuestLogPortraitGiver = function() error("portrait unavailable") end
    assert(addon.QuestPortrait(95036) == nil)
    reset(); C_QuestLog.GetSelectedQuest = function() error("selection unavailable") end
    assert(addon.QuestPortrait(95036) == nil and calls == 0)
    reset(); C_QuestLog.GetLogIndexForQuestID = function() error("log unavailable") end
    assert(addon.QuestPortrait(95036) == nil and calls == 0)
end)
check("Optional restricted or oversized name is omitted without rejecting a clean display", function()
    for _, value in ipairs({ secret, false, 55, "", string.rep("N", 1025) }) do
        name = value
        local p = addon.QuestPortrait(95036)
        assert(p.displayID == 12345 and p.name == nil)
    end
    name = nil; assert(addon.QuestPortrait(95036).name == nil)
    name = string.rep("N", 1024); assert(addon.QuestPortrait(95036).name == name)
end)
check("Whitespace-only portrait giver names are omitted without rejecting a clean display", function()
    for _, value in ipairs({ "   ", "\t\n ", "  \r " }) do
        name = value
        local p = addon.QuestPortrait(95036)
        assert(p.displayID == 12345 and p.name == nil)
    end
end)
check("Unused secret text mount and model scene fields are never inspected or returned", function()
    C_QuestLog.GetQuestLogPortraitGiver = function(logIndex)
        assert(logIndex == 7)
        return 12345, secret, "Native Name", secret, secret
    end
    local p = addon.QuestPortrait(95036)
    assert(p.displayID == 12345 and p.name == "Native Name")
end)
check("Selection and log-index changes during the read invalidate the result", function()
    C_QuestLog.GetQuestLogPortraitGiver = function() selected = 95042; return 12345, "", "Other" end
    assert(addon.QuestPortrait(95036) == nil)
    reset(); C_QuestLog.GetQuestLogPortraitGiver = function() index = 8; return 12345, "", "Reordered" end
    assert(addon.QuestPortrait(95036) == nil)
    reset(); C_QuestLog.GetQuestLogPortraitGiver = function() index = nil; return 12345, "", "Removed" end
    assert(addon.QuestPortrait(95036) == nil)
end)
check("Restricted selection and changed ownership never recover from prior results", function()
    assert(addon.QuestPortrait(95036))
    selected = secret; assert(addon.QuestPortrait(95036) == nil)
    selected = 95042; assert(addon.QuestPortrait(95036) == nil)
end)
check("Fresh localized portrait names do not mutate or reuse earlier snapshots", function()
    local old = addon.QuestPortrait(95036)
    display, name = 54321, "Портрет из журнала"
    GetLocale = function() return "ruRU" end
    local fresh = addon.QuestPortrait(95036)
    assert(old.displayID == 12345 and old.name == "Native Portrait")
    assert(fresh.displayID == 54321 and fresh.name == "Портрет из журнала")
    fresh.name = "Changed"; assert(addon.QuestPortrait(95036).name == "Портрет из журнала")
end)
check("A replaced quest-log namespace cannot publish the previous selection portrait", function()
    C_QuestLog.GetQuestLogPortraitGiver = function(logIndex)
        assert(logIndex == 7)
        C_QuestLog = { GetSelectedQuest = function() return 95042 end,
            GetLogIndexForQuestID = function() return 8 end }
        return 12345, "", "Previous portrait"
    end
    assert(addon.QuestPortrait(95036) == nil)
end)
check("Portrait hydration rejects same-ID getter locale character and checker changes", function()
    local character, localeGetter = addon.char, GetLocale
    for _, mutation in ipairs({ "getter", "selectedGetter", "indexGetter", "locale", "localeGetter", "character", "checker" }) do
        reset()
        local locale = "enUS"
        GetLocale = function() return locale end
        addon.char = {}
        C_QuestLog.GetQuestLogPortraitGiver = function()
            if mutation == "getter" then C_QuestLog.GetQuestLogPortraitGiver = function() return 54321 end
            elseif mutation == "selectedGetter" then C_QuestLog.GetSelectedQuest = function() return 95036 end
            elseif mutation == "indexGetter" then C_QuestLog.GetLogIndexForQuestID = function() return 7 end
            elseif mutation == "locale" then locale = "ruRU"
            elseif mutation == "localeGetter" then GetLocale = function() return "enUS" end
            elseif mutation == "character" then addon.char = {}
            else issecretvalue = function(value) return value == secret end end
            return 12345, "", "Old ownership"
        end
        assert(addon.QuestPortrait(95036) == nil, mutation)
    end
    addon.char, GetLocale = character, localeGetter
end)
check("Malformed portrait namespaces never reach a selected reader", function()
    for _, namespace in ipairs({ false, true, 1, "namespace", secret }) do
        C_QuestLog = namespace
        assert(addon.QuestPortrait(95036) == nil and calls == 0)
    end
end)
check("Oversized item IDs never reach the native name getter", function()
    local calls = 0
    C_Item = { GetItemNameByID = function(id) calls = calls + 1; return "Native Item" end,
        IsItemDataCachedByID = function() return true end,
        RequestLoadItemDataByID = function() end }
    assert(addon.ItemName(4294967295) == "Native Item" and calls == 1)
    for _, id in ipairs({ 4294967296, 2 ^ 40 }) do
        calls = 0
        assert(addon.ItemName(id) == nil and calls == 0, "huge item ID reached the native name getter")
    end
end)
check("Oversized carried item IDs never reach the native bag count", function()
    local calls = 0
    addon.quests = { [1] = { objectiveItems = { { itemID = 4294967295 } } },
        [2] = { objectiveItems = { { itemID = 2 ^ 40 } } } }
    C_Item = { GetItemCount = function(id) calls = calls + 1; return 3 end }
    assert(addon.CarriedItemCount(4294967295) == 3 and calls == 1)
    calls = 0
    assert(addon.CarriedItemCount(2 ^ 40) == nil and calls == 0, "huge item ID reached the native bag count")
end)
check("Oversized selected-log reward item IDs fail the snapshot closed", function()
    C_QuestLog = { GetSelectedQuest = function() return 65 end,
        GetLogIndexForQuestID = function(id) assert(id == 65); return 1 end }
    GetNumQuestLogRewards = function() return 1 end
    GetNumQuestLogChoices = function() return 0 end
    GetQuestLogRewardMoney = function() return 0 end
    GetQuestLogChoiceInfo = function() error("no choices expected") end
    GetQuestLogRewardInfo = function(index) return "Reward", 123, 1, 2, true, 2 ^ 40 end
    assert(addon.QuestRewards(65) == nil)
    GetQuestLogRewardInfo = function(index) return "Reward", 123, 1, 2, true, 4294967295 end
    local r = addon.QuestRewards(65)
    assert(r and r.items[1].id == 4294967295)
end)
check("Oversized cached reward item IDs fail the snapshot closed", function()
    addon.quests = { [65] = { id = 65 } }
    HaveQuestRewardData = function(id) assert(id == 65); return true end
    GetNumQuestLogRewards = function(id) assert(id == 65); return 1 end
    GetNumQuestLogChoices = function(id) assert(id == 65); return 0 end
    GetQuestLogRewardInfo = function(index, id) return "Reward", 123, 1, 2, true, 2 ^ 40 end
    GetQuestLogChoiceInfo = nil
    assert(addon.CachedQuestRewards(65) == nil)
    GetQuestLogRewardInfo = function(index, id) return "Reward", 123, 1, 2, true, 4294967295 end
    local r = addon.CachedQuestRewards(65)
    assert(r and r.items[1].id == 4294967295)
end)
check("QuestName caps IDs at 2^53 and never hydrates uncatalogued IDs", function()
    local savedQuests, savedTimer, savedLog, savedDB, savedLanguage, savedNames =
        addon.quests, C_Timer, C_QuestLog, addon.db, addon.Language, addon.nameTranslations
    addon.quests = { [123] = { id = 123, name = "Source name" } }
    addon.db, addon.Language, addon.nameTranslations = nil, nil, nil
    GetLocale = function() return "enUS" end
    local titleCalls, loadCalls, timerCalls = 0, 0, 0
    C_QuestLog = {
        GetTitleForQuestID = function(id) titleCalls = titleCalls + 1; return nil end,
        RequestLoadQuestByID = function(id) loadCalls = loadCalls + 1 end,
    }
    C_Timer = { After = function(delay, fn) timerCalls = timerCalls + 1 end }
    assert(addon.QuestName(9007199254740992) == "#?")
    assert(addon.QuestName(2 ^ 60) == "#?")
    assert(titleCalls == 0 and loadCalls == 0 and timerCalls == 0, "huge quest ID reached native title APIs")
    assert(addon.QuestName(99999) == "#99999")
    assert(titleCalls == 0 and loadCalls == 0 and timerCalls == 0, "uncatalogued quest ID reached native title APIs")
    assert(addon.QuestName(123) == "Source name")
    assert(loadCalls == 1 and timerCalls == 1, "catalogued cold quest ID lost its bounded hydration request")
    assert(addon.QuestName(99999) == "#99999")
    assert(loadCalls == 1 and timerCalls == 1, "uncatalogued quest ID leaked a hydration request")
    addon.quests, C_Timer, C_QuestLog, addon.db, addon.Language, addon.nameTranslations =
        savedQuests, savedTimer, savedLog, savedDB, savedLanguage, savedNames
end)
check("Huge quest IDs never reach selected-log readers and write no cached text", function()
    local savedQuests, savedChar, savedL = addon.quests, addon.char, addon.L
    addon.quests = { [65] = { id = 65 }, [95036] = { id = 95036 } }
    addon.char = { texts = {} }
    addon.L = function(key) return key end
    local nativeReads = 0
    C_QuestLog.GetLogIndexForQuestID = function(id) nativeReads = nativeReads + 1; return index end
    GetQuestLogQuestText = function() nativeReads = nativeReads + 1; return "Huge text" end
    C_QuestLog.GetQuestObjectives = function(id) nativeReads = nativeReads + 1; return {} end
    GetNumQuestLogRewards = function() nativeReads = nativeReads + 1; return 0 end
    for _, huge in ipairs({ 9007199254740992, 2 ^ 60 }) do
        assert(addon.Description(huge) == "NO_TEXT", "huge description ID missed its fallback")
        assert(addon.QuestObjectives(huge) == nil, "huge objectives ID reached a reader")
        assert(addon.QuestRewards(huge) == nil, "huge rewards ID reached a reader")
        assert(addon.QuestPortrait(huge) == nil, "huge portrait ID reached a reader")
    end
    assert(nativeReads == 0, "huge quest ID reached a native reader")
    assert(next(addon.char.texts) == nil, "huge quest ID wrote cached text")
    addon.quests, addon.char, addon.L = savedQuests, savedChar, savedL
end)
check("Boundary quest ID 2^53-1 keeps its selected-log portrait and description", function()
    local savedChar, savedL = addon.char, addon.L
    local MAX = 9007199254740991
    selected = MAX
    C_QuestLog.GetLogIndexForQuestID = function(id) assert(id == MAX); return index end
    local p = addon.QuestPortrait(MAX)
    assert(p and p.displayID == 12345, "2^53-1 portrait lost")
    addon.char = { texts = {} }
    addon.L = function(key) return key end
    GetQuestLogQuestText = function(...) assert(select("#", ...) == 0); return "Boundary text" end
    assert(addon.Description(MAX) == "Boundary text", "2^53-1 description lost")
    assert(addon.char.texts[MAX].text == "Boundary text", "2^53-1 description lost its cache write")
    addon.char, addon.L = savedChar, savedL
end)
check("Oversized selected-log numeric textures fail safe while 2^53-1 passes", function()
    C_QuestLog = { GetSelectedQuest = function() return 65 end,
        GetLogIndexForQuestID = function(id) assert(id == 65); return 1 end }
    GetNumQuestLogRewards = function() return 1 end
    GetNumQuestLogChoices = function() return 0 end
    GetQuestLogRewardMoney = function() return 0 end
    GetQuestLogChoiceInfo = function() error("no choices expected") end
    local function selectedWith(texture)
        GetQuestLogRewardInfo = function(index)
            assert(index == 1)
            return "Reward", texture, 1, 2, true, 7001
        end
        return addon.QuestRewards(65)
    end
    assert(selectedWith(123).items[1].texture == 123, "valid numeric texture lost")
    assert(selectedWith(9007199254740991).items[1].texture == 9007199254740991, "2^53-1 texture lost")
    for _, huge in ipairs({ 9007199254740992, 1e18 }) do
        local r = selectedWith(huge)
        assert(r and r.items[1].texture == nil, "huge texture kept an icon")
    end
end)
check("Oversized cached numeric textures fail safe while a valid file ID passes", function()
    addon.quests = { [65] = { id = 65 } }
    HaveQuestRewardData = function(id) assert(id == 65); return true end
    GetNumQuestLogRewards = function(id) assert(id == 65); return 1 end
    GetNumQuestLogChoices = function(id) assert(id == 65); return 0 end
    GetQuestLogRewardMoney = function(id) assert(id == 65); return 0 end
    GetQuestLogChoiceInfo = nil
    local function cachedWith(texture)
        GetQuestLogRewardInfo = function(index, id)
            assert(index == 1 and id == 65)
            return "Reward", texture, 1, 2, true, 7001
        end
        return addon.CachedQuestRewards(65)
    end
    assert(cachedWith(123).items[1].texture == 123, "valid cached texture lost")
    assert(cachedWith(9007199254740991).items[1].texture == 9007199254740991, "cached 2^53-1 texture lost")
    for _, huge in ipairs({ 9007199254740992, 1e18 }) do
        local r = cachedWith(huge)
        assert(r and r.items[1].texture == nil, "huge cached texture kept an icon")
    end
end)
check("Oversized dialogue numeric textures fail safe while a valid file ID passes", function()
    addon.quests = { [65] = {} }
    GetQuestID = function() return 65 end
    UnitGUID = function(unit) assert(unit == "player"); return "Player-1-ABC" end
    QuestFrame = { IsShown = function() return true end }
    QuestFrameDetailPanel = { IsShown = function() return true end }
    C_QuestLog = { ShouldShowQuestRewards = function(id) assert(id == 65); return true end }
    GetNumQuestRewards = function() return 1 end
    GetNumQuestChoices = function() return 0 end
    GetRewardMoney = function() return 0 end
    GetRewardXP = function() return 0 end
    local function dialogueWith(texture)
        GetQuestItemInfo = function(kind, index)
            assert(kind == "reward" and index == 1)
            return "Reward", texture, 1, 2, true, 7001
        end
        return addon.DialogueRewards(65)
    end
    addon.DialogueRewardEvent("QUEST_DETAIL")
    assert(dialogueWith(123).items[1].texture == 123, "valid dialogue texture lost")
    assert(dialogueWith(9007199254740991).items[1].texture == 9007199254740991, "dialogue 2^53-1 texture lost")
    for _, huge in ipairs({ 9007199254740992, 1e18 }) do
        local r = dialogueWith(huge)
        assert(r and r.items[1].texture == nil, "huge dialogue texture kept an icon")
    end
    addon.DialogueRewardEvent("QUEST_FINISHED")
end)
check("Carried counts report raw native values without authorizing quest actions", function()
    -- Pinned display contract (tests/ui_preparation.lua "Carried item counts show
    -- real zero ..."): the producer reports the native bag count verbatim,
    -- including huge values; only negative/fractional counts fail closed.
    local native, calls = 3, 0
    addon.quests = { [68] = { id = 68, objectiveItems = { { itemID = 20606 } } } }
    C_Item = { GetItemCount = function(id, bank, uses, reagent, account)
        assert(id == 20606 and bank == false and uses == false and reagent == false and account == false)
        calls = calls + 1; return native
    end }
    assert(addon.CarriedItemCount(20606) == 3 and calls == 1)
    native = 9007199254740991
    assert(addon.CarriedItemCount(20606) == 9007199254740991 and calls == 2)
    for _, huge in ipairs({ 9007199254740992, 1e20 }) do
        native = huge
        assert(addon.CarriedItemCount(20606) == huge, "raw native carried count lost")
    end
    native = -1
    assert(addon.CarriedItemCount(20606) == nil, "negative carried count passed through")
    native = 1.5
    assert(addon.CarriedItemCount(20606) == nil, "fractional carried count passed through")
    assert(calls == 6)
end)
check("Uncapped display amounts fail closed while 2^53-1 stays live", function()
    local MAX = 9007199254740991
    addon.quests = { [65] = {} }
    GetQuestID = function() return 65 end
    UnitGUID = function(unit) assert(unit == "player"); return "Player-1-ABC" end
    QuestFrame = { IsShown = function() return true end }
    QuestFrameDetailPanel = { IsShown = function() return true end }
    C_QuestLog = { ShouldShowQuestRewards = function(id) assert(id == 65); return true end }
    GetNumQuestRewards = function() return 1 end
    GetNumQuestChoices = function() return 0 end
    GetRewardMoney = function() return 0 end
    GetRewardXP = function() return 0 end
    local function dialogueWith(amount)
        GetQuestItemInfo = function(kind, index)
            assert(kind == "reward" and index == 1)
            return "Reward", 123, amount, 2, true, 7001
        end
        return addon.DialogueRewards(65)
    end
    addon.DialogueRewardEvent("QUEST_DETAIL")
    assert(dialogueWith(1).items[1].count == 1, "valid dialogue amount lost")
    assert(dialogueWith(MAX).items[1].count == MAX, "2^53-1 dialogue amount lost")
    for _, huge in ipairs({ 9007199254740992, 1e18 }) do
        assert(dialogueWith(huge) == nil, "huge dialogue amount reached display")
    end
    addon.DialogueRewardEvent("QUEST_FINISHED")
    C_QuestLog = { GetSelectedQuest = function() return 65 end,
        GetLogIndexForQuestID = function(id) assert(id == 65); return 1 end }
    GetNumQuestLogRewards = function() return 1 end
    GetNumQuestLogChoices = function() return 0 end
    GetQuestLogRewardMoney = function() return 0 end
    GetQuestLogChoiceInfo = function() error("no choices expected") end
    local function selectedWith(amount)
        GetQuestLogRewardInfo = function(index)
            assert(index == 1)
            return "Reward", 123, amount, 2, true, 7001
        end
        return addon.QuestRewards(65)
    end
    assert(selectedWith(1).items[1].count == 1, "valid selected-log amount lost")
    assert(selectedWith(MAX).items[1].count == MAX, "2^53-1 selected-log amount lost")
    for _, huge in ipairs({ 9007199254740992, 1e18 }) do
        assert(selectedWith(huge) == nil, "huge selected-log amount reached display")
    end
    addon.quests = { [65] = { id = 65 } }
    HaveQuestRewardData = function(id) assert(id == 65); return true end
    GetNumQuestLogRewards = function(id) assert(id == 65); return 1 end
    GetNumQuestLogChoices = function(id) assert(id == 65); return 0 end
    GetQuestLogRewardMoney = function(id) assert(id == 65); return 0 end
    GetQuestLogChoiceInfo = nil
    local function cachedWith(amount)
        GetQuestLogRewardInfo = function(index, id)
            assert(index == 1 and id == 65)
            return "Reward", 123, amount, 2, true, 7001
        end
        return addon.CachedQuestRewards(65)
    end
    assert(cachedWith(1).items[1].count == 1, "valid cached amount lost")
    assert(cachedWith(MAX).items[1].count == MAX, "2^53-1 cached amount lost")
    for _, huge in ipairs({ 9007199254740992, 1e18 }) do
        assert(cachedWith(huge) == nil, "huge cached amount reached display")
    end
end)
check("Uncapped dialogue and cached XP fail safe while 2^53-1 stays live", function()
    local MAX = 9007199254740991
    addon.quests = { [65] = {} }
    GetQuestID = function() return 65 end
    UnitGUID = function(unit) assert(unit == "player"); return "Player-1-ABC" end
    QuestFrame = { IsShown = function() return true end }
    QuestFrameDetailPanel = { IsShown = function() return true end }
    C_QuestLog = { ShouldShowQuestRewards = function(id) assert(id == 65); return true end }
    GetNumQuestRewards = function() return 1 end
    GetNumQuestChoices = function() return 0 end
    GetRewardMoney = function() return 0 end
    GetQuestItemInfo = function(kind, index)
        assert(kind == "reward" and index == 1)
        return "Reward", 123, 1, 2, true, 7001
    end
    local function dialogueXP(value)
        GetRewardXP = function() return value end
        return addon.DialogueRewards(65)
    end
    addon.DialogueRewardEvent("QUEST_DETAIL")
    assert(dialogueXP(0).xp == 0, "valid zero dialogue XP lost")
    assert(dialogueXP(MAX).xp == MAX, "2^53-1 dialogue XP lost")
    for _, huge in ipairs({ 9007199254740992, 1e18, 1.5 }) do
        local r = dialogueXP(huge)
        assert(r and r.xp == nil and r.items[1].count == 1, "huge dialogue XP reached display")
    end
    addon.DialogueRewardEvent("QUEST_FINISHED")
    addon.quests = { [65] = { id = 65 } }
    HaveQuestRewardData = function(id) assert(id == 65); return true end
    GetNumQuestLogRewards = function(id) assert(id == 65); return 0 end
    GetNumQuestLogChoices = function(id) assert(id == 65); return 0 end
    GetQuestLogRewardMoney = function(id) assert(id == 65); return 0 end
    local function cachedXP(value)
        GetQuestLogRewardXP = function(id) assert(id == 65); return value end
        return addon.CachedQuestRewards(65)
    end
    assert(cachedXP(0).xp == 0, "valid zero cached XP lost")
    assert(cachedXP(MAX).xp == MAX, "2^53-1 cached XP lost")
    for _, huge in ipairs({ 9007199254740992, 1e18, 1.5 }) do
        local r = cachedXP(huge)
        assert(r and r.xp == nil and #r.items == 0, "huge cached XP reached display")
    end
end)
check("Uncapped quest-log counts fail closed while generous boundaries stay truthful", function()
    local count, capacity = 7, 40
    C_QuestLog = {
        GetNumQuestLogEntries = function(...) assert(select("#", ...) == 0); return 12, count end,
        GetMaxNumQuestsCanAccept = function(...) assert(select("#", ...) == 0); return capacity end,
    }
    Constants = { QuestLogConsts = { MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT = 25 } }
    local r = addon.QuestLogCapacity()
    assert(r.count == 7 and r.capacity == 40, "valid occupancy lost")
    count, capacity = 0, 1
    r = addon.QuestLogCapacity()
    assert(r.count == 0 and r.capacity == 1, "zero boundary lost")
    count, capacity = 1000000, 1000000
    r = addon.QuestLogCapacity()
    assert(r.count == 1000000 and r.capacity == 1000000, "generous boundary lost")
    for _, huge in ipairs({ 1000001, 9007199254740992, 1e18 }) do
        count, capacity = huge, 40
        assert(addon.QuestLogCapacity() == nil, "huge log count reached display")
        count, capacity = 7, huge
        assert(addon.QuestLogCapacity() == nil, "huge log capacity reached display")
    end
    C_QuestLog.GetMaxNumQuestsCanAccept = nil
    local function fallbackWith(value)
        Constants.QuestLogConsts.MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT = value
        count = 7
        return addon.QuestLogCapacity()
    end
    assert(fallbackWith(1000000).capacity == 1000000, "generous fallback boundary lost")
    for _, huge in ipairs({ 1000001, 9007199254740992, 1e18 }) do
        assert(fallbackWith(huge) == nil, "huge fallback capacity reached display")
    end
    Constants = nil
end)
check("Dialogue and selected-log money enforce integer 2^53-1 caps", function()
    local MAX = 9007199254740991
    addon.quests = { [65] = {} }
    GetQuestID = function() return 65 end
    UnitGUID = function(unit) assert(unit == "player"); return "Player-1-ABC" end
    QuestFrame = { IsShown = function() return true end }
    QuestFrameDetailPanel = { IsShown = function() return true end }
    C_QuestLog = { ShouldShowQuestRewards = function(id) assert(id == 65); return true end }
    GetNumQuestRewards = function() return 0 end
    GetNumQuestChoices = function() return 0 end
    GetQuestItemInfo = function() error("no items expected") end
    local function dialogueMoney(value)
        GetRewardMoney = function() return value end
        GetRewardXP = function() return 0 end
        return addon.DialogueRewards(65)
    end
    addon.DialogueRewardEvent("QUEST_DETAIL")
    assert(dialogueMoney(0).money == 0, "valid zero dialogue money lost")
    assert(dialogueMoney(MAX).money == MAX, "2^53-1 dialogue money lost")
    for _, huge in ipairs({ 9007199254740992, 1e18, 1.5 }) do
        local r = dialogueMoney(huge)
        assert(r and r.money == nil, "uncapped dialogue money reached display")
    end
    addon.DialogueRewardEvent("QUEST_FINISHED")
    C_QuestLog = { GetSelectedQuest = function() return 65 end,
        GetLogIndexForQuestID = function(id) assert(id == 65); return 1 end }
    GetNumQuestLogRewards = function() return 0 end
    GetNumQuestLogChoices = function() return 0 end
    GetQuestLogRewardInfo = nil
    GetQuestLogChoiceInfo = function() error("no choices expected") end
    local function selectedMoney(value)
        GetQuestLogRewardMoney = function() return value end
        return addon.QuestRewards(65)
    end
    assert(selectedMoney(0).money == 0, "valid zero selected-log money lost")
    assert(selectedMoney(MAX).money == MAX, "2^53-1 selected-log money lost")
    for _, huge in ipairs({ 9007199254740992, 1e18, 1.5 }) do
        local r = selectedMoney(huge)
        assert(r and r.money == nil, "uncapped selected-log money reached display")
    end
end)
check("Fractional and oversized objective counters fail closed while 2^53-1 stays live", function()
    local MAX = 9007199254740991
    local fulfilled, required = 2, 6
    C_QuestLog.GetQuestObjectives = function(id)
        assert(id == 65)
        return { { text = "Defias defeated", type = "monster", finished = false,
            numFulfilled = fulfilled, numRequired = required } }
    end
    local r = addon.QuestObjectives(65)
    assert(r and r[1].numFulfilled == 2 and r[1].numRequired == 6, "valid objective counters lost")
    fulfilled, required = MAX, MAX
    r = addon.QuestObjectives(65)
    assert(r and r[1].numFulfilled == MAX and r[1].numRequired == MAX, "2^53-1 objective counters lost")
    for _, huge in ipairs({ 9007199254740992, 1e18 }) do
        fulfilled, required = huge, 6
        assert(addon.QuestObjectives(65) == nil, "huge fulfilled reached display")
        fulfilled, required = 2, huge
        assert(addon.QuestObjectives(65) == nil, "huge required reached display")
    end
    for _, fractional in ipairs({ 1.5, 2.5 }) do
        fulfilled, required = fractional, 6
        assert(addon.QuestObjectives(65) == nil, "fractional fulfilled reached display")
        fulfilled, required = 2, fractional
        assert(addon.QuestObjectives(65) == nil, "fractional required reached display")
    end
end)
check("Whitespace-only quest objective text and kind stay unknown instead of blank rows", function()
    local function withObjectives(text, kind)
        C_QuestLog.GetQuestObjectives = function(id)
            assert(id == 65)
            return { { text = text, type = kind, finished = false, numFulfilled = 1, numRequired = 3 } }
        end
        return addon.QuestObjectives(65)
    end
    for _, value in ipairs({ "", "   ", "\t\n ", "  \r " }) do
        assert(withObjectives(value, "monster") == nil, "blank objective text kept a row")
        assert(withObjectives("Defias defeated", value) == nil, "blank objective kind kept a row")
    end
    local r = withObjectives("Defias defeated", "monster")
    assert(r and r[1].text == "Defias defeated" and r[1].type == "monster", "valid objective row lost")
end)
issecretvalue = nil
check("Whitespace-only reward item names stay unknown instead of blank rows", function()
    addon.quests = { [65] = {} }
    GetQuestID = function() return 65 end
    UnitGUID = function(unit) assert(unit == "player"); return "Player-1-ABC" end
    QuestFrame = { IsShown = function() return true end }
    QuestFrameDetailPanel = { IsShown = function() return true end }
    C_QuestLog = { ShouldShowQuestRewards = function(id) assert(id == 65); return true end }
    GetNumQuestRewards = function() return 1 end
    GetNumQuestChoices = function() return 0 end
    GetRewardMoney = function() return 0 end
    GetRewardXP = function() return 0 end
    GetQuestItemInfo = function(kind, index)
        assert(kind == "reward" and index == 1)
        return "   ", 123, 1, 2, true, 7001
    end
    addon.DialogueRewardEvent("QUEST_DETAIL")
    assert(addon.DialogueRewards(65) == nil, "blank dialogue reward name kept a row")
    addon.DialogueRewardEvent("QUEST_FINISHED")
    C_QuestLog = { GetSelectedQuest = function() return 65 end,
        GetLogIndexForQuestID = function(id) assert(id == 65); return 1 end }
    GetNumQuestLogRewards = function() return 1 end
    GetNumQuestLogChoices = function() return 0 end
    GetQuestLogRewardMoney = function() return 0 end
    GetQuestLogChoiceInfo = function() error("no choices expected") end
    GetQuestLogRewardInfo = function(index)
        assert(index == 1)
        return "\t\n ", 123, 1, 2, true, 7001
    end
    assert(addon.QuestRewards(65) == nil, "blank selected-log reward name kept a row")
    addon.quests = { [65] = { id = 65 } }
    HaveQuestRewardData = function(id) assert(id == 65); return true end
    GetNumQuestLogRewards = function(id) assert(id == 65); return 1 end
    GetNumQuestLogChoices = function(id) assert(id == 65); return 0 end
    GetQuestLogRewardMoney = function(id) assert(id == 65); return 0 end
    GetQuestLogChoiceInfo = nil
    GetQuestLogRewardInfo = function(index, id)
        assert(index == 1 and id == 65)
        return "  \r ", 123, 1, 2, true, 7001
    end
    assert(addon.CachedQuestRewards(65) == nil, "blank cached reward name kept a row")
end)
check("Whitespace-only reward textures are omitted without rejecting clean rows", function()
    addon.quests = { [65] = {} }
    GetQuestID = function() return 65 end
    UnitGUID = function(unit) assert(unit == "player"); return "Player-1-ABC" end
    QuestFrame = { IsShown = function() return true end }
    QuestFrameDetailPanel = { IsShown = function() return true end }
    C_QuestLog = { ShouldShowQuestRewards = function(id) assert(id == 65); return true end }
    GetNumQuestRewards = function() return 1 end
    GetNumQuestChoices = function() return 0 end
    GetRewardMoney = function() return 0 end
    GetRewardXP = function() return 0 end
    local function dialogueWith(texture)
        GetQuestItemInfo = function(kind, index)
            assert(kind == "reward" and index == 1)
            return "Reward", texture, 1, 2, true, 7001
        end
        return addon.DialogueRewards(65)
    end
    addon.DialogueRewardEvent("QUEST_DETAIL")
    local r = dialogueWith("Interface\\Icons\\INV_Sword")
    assert(r and r.items[1].texture == "Interface\\Icons\\INV_Sword", "valid dialogue texture lost")
    for _, blank in ipairs({ "", "   ", "\t\n ", "  \r " }) do
        r = dialogueWith(blank)
        assert(r and r.items[1].name == "Reward" and r.items[1].texture == nil, "blank dialogue texture kept an icon")
    end
    assert(dialogueWith(123).items[1].texture == 123, "numeric dialogue texture lost")
    addon.DialogueRewardEvent("QUEST_FINISHED")
    C_QuestLog = { GetSelectedQuest = function() return 65 end,
        GetLogIndexForQuestID = function(id) assert(id == 65); return 1 end }
    GetNumQuestLogRewards = function() return 1 end
    GetNumQuestLogChoices = function() return 0 end
    GetQuestLogRewardMoney = function() return 0 end
    GetQuestLogChoiceInfo = function() error("no choices expected") end
    local function selectedWith(texture)
        GetQuestLogRewardInfo = function(index)
            assert(index == 1)
            return "Reward", texture, 1, 2, true, 7001
        end
        return addon.QuestRewards(65)
    end
    r = selectedWith("Interface\\Icons\\INV_Sword")
    assert(r and r.items[1].texture == "Interface\\Icons\\INV_Sword", "valid selected-log texture lost")
    for _, blank in ipairs({ "", "   ", "\t\n ", "  \r " }) do
        r = selectedWith(blank)
        assert(r and r.items[1].name == "Reward" and r.items[1].texture == nil, "blank selected-log texture kept an icon")
    end
    addon.quests = { [65] = { id = 65 } }
    HaveQuestRewardData = function(id) assert(id == 65); return true end
    GetNumQuestLogRewards = function(id) assert(id == 65); return 1 end
    GetNumQuestLogChoices = function(id) assert(id == 65); return 0 end
    GetQuestLogRewardMoney = function(id) assert(id == 65); return 0 end
    GetQuestLogChoiceInfo = nil
    local function cachedWith(texture)
        GetQuestLogRewardInfo = function(index, id)
            assert(index == 1 and id == 65)
            return "Reward", texture, 1, 2, true, 7001
        end
        return addon.CachedQuestRewards(65)
    end
    r = cachedWith("Interface\\Icons\\INV_Sword")
    assert(r and r.items[1].texture == "Interface\\Icons\\INV_Sword", "valid cached texture lost")
    for _, blank in ipairs({ "", "   ", "\t\n ", "  \r " }) do
        r = cachedWith(blank)
        assert(r and r.items[1].name == "Reward" and r.items[1].texture == nil, "blank cached texture kept an icon")
    end
end)
print("Quest portrait adapter modeled checks passed: " .. total .. " (native client unverified)")
