local addon, total = {}, 0
local secret = {}
local checker = function(value) return value == secret end
issecretvalue = checker
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/QuestPayment.lua"))("DungeonPro", addon)
local producer = addon.QuestPayment
local function reset()
    issecretvalue = checker
    addon.QuestPayment = producer
    addon.quests = { [2945] = { id = 2945, requiredMoney = 300, requirementsKnown = false, factions = { "Alliance" } },
        [1] = { id = 1, requiredMoney = 1 }, [2] = { id = 2 } }
    C_CurrencyInfo = { GetCoinTextureString = function(amount, height)
        assert(type(amount) == "number" and height == 14)
        return "Native copper " .. amount
    end }
end
local function check(name, fn)
    reset(); local ok, err = pcall(fn); assert(ok, name .. ": " .. tostring(err))
    total = total + 1; print("PASS " .. name)
end
check("Known copper payments return detached DTOs with the exact optional native format", function()
    local result = producer(2945)
    assert(result.amount == 300 and result.formatted == "Native copper 300")
    result.amount = 99; assert(addon.quests[2945].requiredMoney == 300 and producer(2945).amount == 300)
    assert(producer(1).amount == 1 and producer(1).formatted == "Native copper 1")
    addon.quests[1].requiredMoney = 9007199254740991
    assert(producer(1).amount == 9007199254740991)
end)
check("Unknown or malformed quest IDs and source amounts never become known zero or free", function()
    assert(producer(nil) == nil and producer(2) == nil and producer(999) == nil)
    for _, value in ipairs({ false, true, 0, -1, 1.5, math.huge, -math.huge, 0/0, 9007199254740992, "1", secret, {} }) do
        assert(producer(value) == nil)
        addon.quests[2945].requiredMoney = value; assert(producer(2945) == nil)
    end
    addon.quests[2945].requiredMoney = nil; assert(producer(2945) == nil)
    addon.quests[1].id = 3; assert(producer(1) == nil)
end)
check("Missing malformed failing or restricted formatters preserve known amount", function()
    for _, formatter in ipairs({ false, secret, function() end, function() error("Unavailable") end,
        function() return secret end, function() return 300 end, function() return false end,
        function() return "" end, function() return " \t\n" end, function() return string.rep("x", 4097) end }) do
        C_CurrencyInfo.GetCoinTextureString = formatter
        local dto = assert(producer(2945)); assert(dto.amount == 300 and dto.formatted == nil)
    end
    for _, ns in ipairs({ false, secret }) do
        C_CurrencyInfo = ns; local dto = assert(producer(2945)); assert(dto.amount == 300 and dto.formatted == nil)
    end
    C_CurrencyInfo = nil; local dto = assert(producer(2945)); assert(dto.amount == 300 and dto.formatted == nil)
end)
check("Payment preview never queries money rewards identity selection or quest availability", function()
    local calls = 0
    local function forbidden() calls = calls + 1; error("Unrelated native API") end
    GetMoney, GetCoinTextureString, UnitGUID, GetRewardMoney, AcceptQuest = forbidden, forbidden, forbidden, forbidden, forbidden
    C_QuestLog = setmetatable({}, { __index = forbidden })
    addon.char = nil
    assert(producer(2945).amount == 300 and addon.quests[2945].requirementsKnown == false and calls == 0)
end)
check("Caller ownership is optional and false failed or restricted ownership rejects the DTO", function()
    assert(producer(2945, function() return true end))
    for _, answer in ipairs({ false, secret, 1, "true" }) do assert(producer(2945, function() return answer end) == nil) end
    assert(producer(2945, false) == nil and producer(2945, secret) == nil)
    assert(producer(2945, function() error("Old card") end) == nil)
end)
check("Native formatter source and same-ID definition supersession reject stale results", function()
    for _, change in ipairs({ "amount", "id", "definition", "catalog", "helper", "namespace", "getter", "checker", "owner" }) do
        reset(); local live = true
        C_CurrencyInfo.GetCoinTextureString = function()
            if change == "amount" then addon.quests[2945].requiredMoney = 301
            elseif change == "id" then addon.quests[2945].id = 1
            elseif change == "definition" then addon.quests[2945] = { id = 2945, requiredMoney = 300 }
            elseif change == "catalog" then addon.quests = { [2945] = addon.quests[2945] }
            elseif change == "helper" then addon.QuestPayment = function() return {} end
            elseif change == "namespace" then C_CurrencyInfo = { GetCoinTextureString = C_CurrencyInfo.GetCoinTextureString }
            elseif change == "getter" then C_CurrencyInfo.GetCoinTextureString = function() return "new" end
            elseif change == "checker" then issecretvalue = function() return false end
            else live = false end
            return "old"
        end
        assert(producer(2945, function() return live end) == nil, change)
    end
end)
check("The final restriction sanitizer cannot change source after prior field validation", function()
    for _, boundary in ipairs({ "formatted", "getter" }) do
        reset(); local armed = false; local getter
        getter = function() armed = true; return "formatted money" end
        C_CurrencyInfo.GetCoinTextureString = getter
        issecretvalue = function(value)
            if armed and ((boundary == "formatted" and value == "formatted money") or (boundary == "getter" and value == getter)) then
                armed = false; addon.quests[2945].requiredMoney = 301
            end
            return false
        end
        assert(producer(2945) == nil, boundary)
    end
end)
check("The caller scope cannot replace a capability after validation and publish an old DTO", function()
    local calls = 0
    assert(producer(2945, function()
        calls = calls + 1
        if calls == 2 then C_CurrencyInfo.GetCoinTextureString = function() return "new" end end
        return true
    end) == nil)
    reset(); calls = 0
    assert(producer(2945, function()
        calls = calls + 1
        if calls == 2 then addon.quests[2945].requiredMoney = 301 end
        return true
    end) == nil)
end)
check("A final owner callback cannot install an initially absent currency namespace", function()
    C_CurrencyInfo = nil
    local calls = 0
    assert(producer(2945, function()
        calls = calls + 1
        if calls == 2 then C_CurrencyInfo = { GetCoinTextureString = function() return "new" end } end
        return true
    end) == nil)
end)
check("A final owner callback cannot install an initially absent formatter", function()
    C_CurrencyInfo = {}
    local calls = 0
    assert(producer(2945, function()
        calls = calls + 1
        if calls == 2 then C_CurrencyInfo.GetCoinTextureString = function() return "new" end end
        return true
    end) == nil)
end)
print("Quest payment preview checks passed: " .. total .. " (no native-client validation)")
