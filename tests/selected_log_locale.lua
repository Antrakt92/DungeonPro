local total, secret = 0, {}
local function fixture()
    local addon = {}
    assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
    assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
    addon.L = function(key) return key end
    addon.char = { texts = {} }
    addon.quests = { [65] = { id = 65 } }
    local f = { addon = addon, locale = "enUS", prose = 0, rewards = 0, portrait = 0 }
    issecretvalue = function(value) return value == secret end
    GetLocale = function() return f.locale end
    C_QuestLog = {
        GetSelectedQuest = function() return 65 end,
        GetLogIndexForQuestID = function(id) assert(id == 65); return 7 end,
        GetQuestLogPortraitGiver = function(index)
            assert(index == 7); f.portrait = f.portrait + 1
            return 12345, "", "Native giver"
        end,
        SetSelectedQuest = function() error("selection writes forbidden") end,
    }
    GetQuestLogQuestText = function() f.prose = f.prose + 1; return "Native prose" end
    GetNumQuestLogRewards = function() f.rewards = f.rewards + 1; return 0 end
    GetNumQuestLogChoices = function() f.rewards = f.rewards + 1; return 0 end
    GetQuestLogRewardMoney = function() f.rewards = f.rewards + 1; return 0 end
    GetQuestLogRewardXP, HaveQuestRewardData = nil, nil
    return f
end
local function check(name, fn)
    local ok, message = pcall(fn)
    assert(ok, name .. ": " .. tostring(message))
    total = total + 1; print("PASS " .. name)
end
local function absent(f)
    assert(f.addon.Description(65) == "NO_TEXT")
    assert(f.addon.QuestRewards(65) == nil)
    assert(f.addon.QuestPortrait(65) == nil)
    assert(f.prose == 0 and f.rewards == 0 and f.portrait == 0,
        "unverified locale reached native selected content getters")
    assert(f.addon.char.texts[65] == nil, "unknown locale persisted selected prose")
end
check("Missing failed restricted blank and overbound locale never reads selected native content", function()
    for _, value in ipairs({ "", " \t\n ", string.rep("x", 33), secret, false, 42 }) do
        local f = fixture(); f.locale = value; absent(f)
    end
    local f = fixture(); f.locale = nil; absent(f)
    f = fixture(); GetLocale = nil; absent(f)
    f = fixture(); GetLocale = function() error("locale unavailable") end; absent(f)
end)
check("Recovered known client locales allow independent fresh native selected content", function()
    local f = fixture(); f.locale = nil; absent(f)
    for _, locale in ipairs({ "enUS", "ruRU", "zhCN", "zhTW", "koKR" }) do
        f.locale = locale
        assert(f.addon.Description(65) == "Native prose")
        assert(f.addon.char.texts[65].locale == locale)
        assert(f.addon.QuestRewards(65).money == 0)
        assert(f.addon.QuestPortrait(65).displayID == 12345)
    end
end)
check("Invalid stored locale tags cannot supply cached descriptions", function()
    for _, value in ipairs({ "", " \t ", string.rep("x", 33) }) do
        local f = fixture(); f.locale = value
        f.addon.char.texts[65] = { locale = value, text = "Unverified old prose" }
        assert(f.addon.Description(65) == "NO_TEXT" and f.prose == 0)
    end
end)
check("Known same-locale cached descriptions survive absent live selected scope", function()
    local f = fixture()
    local record = { locale = "enUS", text = "Verified saved prose" }
    f.addon.char.texts[65] = record
    C_QuestLog.GetSelectedQuest = function() return 66 end
    assert(f.addon.Description(65) == record.text and f.prose == 0)
    assert(f.addon.char.texts[65] == record)
    f.locale = "ruRU"
    assert(f.addon.Description(65) == "NO_TEXT" and f.addon.char.texts[65] == record)
end)
print("Selected-log locale checks passed: " .. total .. " (modeled capability failures, no native bug claim)")
