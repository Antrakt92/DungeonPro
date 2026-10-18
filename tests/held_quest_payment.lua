local total, secret = 0, {}
local addon, fixture
local function setup()
    fixture = { held = true, index = 7, amount = 300, locale = "enUS", moneyReads = 0, formats = 0 }
    addon = { char = {}, quests = { [2945] = { id = 2945 } } }
    issecretvalue = function(value) return value == secret end
    GetLocale = function() return fixture.locale end
    C_QuestLog = {
        IsOnQuest = function(id) assert(id == 2945); return fixture.held end,
        GetLogIndexForQuestID = function(id) assert(id == 2945); return fixture.index end,
        GetRequiredMoney = function(id)
            assert(id == 2945 and id ~= fixture.index, "money accessor takes explicit quest ID, not log index")
            fixture.moneyReads = fixture.moneyReads + 1
            if fixture.moneyHook then fixture.moneyHook() end
            return fixture.amount
        end,
        GetSelectedQuest = function() error("selection is irrelevant to an explicit-ID read") end,
        SetSelectedQuest = function() error("must not change selection") end,
        RequestLoadQuestByID = function() error("must not request data") end,
    }
    C_CurrencyInfo = { GetCoinTextureString = function(amount, size)
        assert(amount == 300 and size == 14); fixture.formats = fixture.formats + 1
        if fixture.formatHook then fixture.formatHook() end
        return fixture.formatted or "3 silver"
    end }
    GetMoney = function() error("must not inspect balance") end
    C_Timer = { After = function() error("must not schedule requests") end }
    AcceptQuest = function() error("must not accept quests") end
    CompleteQuest = function() error("must not complete quests") end
    assert(loadfile("Core/HeldQuestPayment.lua"))("DungeonPro", addon)
end
local function check(name, fn)
    setup()
    local ok, err = pcall(fn); assert(ok, name .. ": " .. tostring(err))
    total = total + 1; print("PASS " .. name)
end
check("Held quest payments use explicit ID and detached positive native money without a source fact", function()
    local result = addon.HeldQuestPayment(2945)
    assert(result.amount == 300 and result.formatted == "3 silver" and fixture.moneyReads == 1)
    assert(addon.quests[2945].requiredMoney == nil)
    result.amount = 600
    assert(addon.HeldQuestPayment(2945).amount == 300)
end)
check("Source amounts neither enable nor override the independent journal payment", function()
    addon.quests[2945].requiredMoney = 900
    assert(addon.HeldQuestPayment(2945).amount == 300 and addon.quests[2945].requiredMoney == 900)
    fixture.held = false
    assert(addon.HeldQuestPayment(2945) == nil and fixture.moneyReads == 1)
end)
check("Missing held evidence log identity or character omits payment before the money read", function()
    for _, stage in ipairs({ "heldFalse", "heldUnknown", "heldSecret", "indexZero", "indexFraction", "indexSecret", "character", "unknownID", "definitionID" }) do
        setup(); local id = 2945
        if stage == "heldFalse" then fixture.held = false
        elseif stage == "heldUnknown" then fixture.held = nil
        elseif stage == "heldSecret" then fixture.held = secret
        elseif stage == "indexZero" then fixture.index = 0
        elseif stage == "indexFraction" then fixture.index = 1.5
        elseif stage == "indexSecret" then fixture.index = secret
        elseif stage == "character" then addon.char = nil
        elseif stage == "unknownID" then id = 123
        else addon.quests[2945].id = 2946 end
        assert(addon.HeldQuestPayment(id) == nil and fixture.moneyReads == 0, stage)
    end
end)
check("Missing malformed and failing native capability stays optional", function()
    for _, key in ipairs({ "IsOnQuest", "GetLogIndexForQuestID", "GetRequiredMoney" }) do
        for _, value in ipairs({ false, 17, function() error("unavailable") end }) do
            setup(); C_QuestLog[key] = value
            assert(addon.HeldQuestPayment(2945) == nil, key)
        end
    end
    for _, value in ipairs({ false, 12, secret }) do
        setup(); C_QuestLog = value; assert(addon.HeldQuestPayment(2945) == nil)
    end
end)
check("Zero malformed restricted fractional and overflowing costs never become a free label", function()
    for _, value in ipairs({ 0, -1, 0.5, math.huge, -math.huge, 0/0, 9007199254740992, "300", false, secret }) do
        setup(); fixture.amount = value
        assert(addon.HeldQuestPayment(2945) == nil and fixture.formats == 0)
    end
    fixture.amount = nil; assert(addon.HeldQuestPayment(2945) == nil)
end)
check("Exact positive Lua safe costs retain their amount without requiring coin formatting", function()
    for _, value in ipairs({ 1, 300, 9007199254740991 }) do
        setup(); fixture.amount = value; C_CurrencyInfo = nil
        local result = addon.HeldQuestPayment(2945); assert(result.amount == value and result.formatted == nil)
    end
end)
check("Bad optional formatted output retains only the known native amount", function()
    for _, mode in ipairs({ "missingNamespace", "missingGetter", "throw", "blank", "long", "secret", "number" }) do
        setup()
        if mode == "missingNamespace" then C_CurrencyInfo = nil
        elseif mode == "missingGetter" then C_CurrencyInfo = {}
        else C_CurrencyInfo.GetCoinTextureString = function()
            if mode == "throw" then error("unavailable") end
            if mode == "blank" then return "  " end
            if mode == "long" then return string.rep("x", 4097) end
            if mode == "secret" then return secret end
            return 300
        end end
        local result = addon.HeldQuestPayment(2945)
        assert(result.amount == 300 and result.formatted == nil, mode)
    end
end)
check("Money and formatter callbacks cannot retain a released or reindexed held quest", function()
    for _, stage in ipairs({ "moneyHook", "formatHook" }) do
        for _, field in ipairs({ "held", "index" }) do
            setup(); fixture[stage] = function() fixture[field] = field == "held" and false or 8 end
            assert(addon.HeldQuestPayment(2945) == nil, stage .. field)
        end
    end
end)
check("Native reads cannot mix replaced character catalogue namespace getters or locale", function()
    for _, field in ipairs({ "character", "catalog", "definition", "id", "namespace", "held", "index", "money", "checker", "localeGetter", "localeValue", "formatterNamespace", "formatterGetter", "helper" }) do
        setup()
        fixture.moneyHook = function()
            if field == "character" then addon.char = {}
            elseif field == "catalog" then addon.quests = { [2945] = addon.quests[2945] }
            elseif field == "definition" then addon.quests[2945] = { id = 2945 }
            elseif field == "id" then addon.quests[2945].id = 2946
            elseif field == "namespace" then local new = {}; for k,v in pairs(C_QuestLog) do new[k] = v end; C_QuestLog = new
            elseif field == "held" then C_QuestLog.IsOnQuest = function() return true end
            elseif field == "index" then C_QuestLog.GetLogIndexForQuestID = function() return 7 end
            elseif field == "money" then C_QuestLog.GetRequiredMoney = function() return 300 end
            elseif field == "checker" then issecretvalue = function() return false end
            elseif field == "localeGetter" then GetLocale = function() return "enUS" end
            elseif field == "localeValue" then fixture.locale = "ruRU"
            elseif field == "formatterNamespace" then C_CurrencyInfo = {}
            elseif field == "formatterGetter" then C_CurrencyInfo.GetCoinTextureString = function() return "new" end
            else addon.HeldQuestPayment = function() end end
        end
        assert(addon.HeldQuestPayment(2945) == nil, field)
    end
end)
check("Caller scope stays optional and cannot publish payment after a late held or capability change", function()
    for _, mode in ipairs({ "false", "secret", "throw", "held", "index", "namespace", "getter" }) do
        setup()
        if mode == "namespace" then C_CurrencyInfo = nil end
        if mode == "getter" then C_CurrencyInfo = {} end
        local result = addon.HeldQuestPayment(2945, function()
            if mode == "false" then return false end
            if mode == "secret" then return secret end
            if mode == "throw" then error("stale") end
            if fixture.moneyReads > 0 then
                if mode == "held" then fixture.held = false
                elseif mode == "index" then fixture.index = 8
                elseif mode == "namespace" then C_CurrencyInfo = {}
                elseif mode == "getter" then C_CurrencyInfo.GetCoinTextureString = function() return "new" end end
            end
            return true
        end)
        assert(result == nil, mode)
    end
    setup(); assert(addon.HeldQuestPayment(2945, false) == nil)
end)
check("Final index and locale reads cannot retain payment after the held quest is released", function()
    for _, stage in ipairs({ "index", "locale" }) do
        setup()
        local getter = stage == "index" and C_QuestLog.GetLogIndexForQuestID or GetLocale
        local afterFormat = 0
        local wrapped = function(...)
            local value = getter(...)
            if fixture.formats > 0 then
                afterFormat = afterFormat + 1
                if afterFormat == 2 then fixture.held = false end
            end
            return value
        end
        if stage == "index" then C_QuestLog.GetLogIndexForQuestID = wrapped else GetLocale = wrapped end
        assert(addon.HeldQuestPayment(2945) == nil and fixture.held == false and afterFormat == 2, stage)
    end
end)
check("Final sanitizer drift is rejected and a stable reload recovers without changing source facts", function()
    local original = issecretvalue
    issecretvalue = function(value)
        if value == "3 silver" then addon.char = {} end
        return original(value)
    end
    assert(addon.HeldQuestPayment(2945) == nil)
    setup(); local snapshot = addon.quests[2945]
    assert(addon.HeldQuestPayment(2945).amount == 300 and addon.quests[2945] == snapshot and snapshot.requiredMoney == nil)
end)
check("Final native held read cannot return payment after its caller owner expires", function()
    local owner, afterFormat = true, 0
    local held = C_QuestLog.IsOnQuest
    C_QuestLog.IsOnQuest = function(...)
        local result = held(...)
        if fixture.formats > 0 then
            afterFormat = afterFormat + 1
            if afterFormat == 4 then owner = false end
        end
        return result
    end
    assert(addon.HeldQuestPayment(2945, function() return owner end) == nil,
        "payment escaped the final native read with an expired caller")
    assert(not owner and afterFormat == 4)
end)
print("Held quest payment modeled checks passed: " .. total .. " (no native money validation)")
