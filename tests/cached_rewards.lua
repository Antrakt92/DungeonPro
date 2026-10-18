local addon, total, secret = {}, 0, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local fixed, choice, loaded, locale, fixedCount, choiceCount, calls
local function reset()
    addon.char, addon.db = nil, nil
    addon.quests = { [65] = { id = 65 } }
    fixed, choice = { "Reward", 123, 2, 3, false, 7001 }, { "Choice", "Icon", 1, 4, true, 8001 }
    loaded, locale, fixedCount, choiceCount, calls = true, "enUS", 1, 1, 0
    issecretvalue = function(value) return value == secret end
    GetLocale = function() return locale end
    HaveQuestRewardData = function(id, ...) assert(id == 65 and select("#", ...) == 0); return loaded end
    GetNumQuestLogRewards = function(id, ...) calls = calls + 1; assert(id == 65 and select("#", ...) == 0); return fixedCount end
    GetNumQuestLogChoices = function(id, ...) calls = calls + 1; assert(id == 65 and select("#", ...) == 0); return choiceCount end
    GetQuestLogRewardInfo = function(index, id, ...) assert(index == 1 and id == 65 and select("#", ...) == 0); return unpack(fixed, 1, 6) end
    GetQuestLogChoiceInfo = function(index, id, ...) assert(index == 1 and id == 65 and select("#", ...) == 0); return unpack(choice, 1, 6) end
    GetQuestLogRewardMoney = function(id, ...) assert(id == 65 and select("#", ...) == 0); return 12345 end
    GetQuestLogRewardXP = function(id, ...) assert(id == 65 and select("#", ...) == 0); return 678 end
    C_QuestLog = { GetSelectedQuest = function() error("selection reads forbidden") end,
        SetSelectedQuest = function() error("selection writes forbidden") end,
        GetLogIndexForQuestID = function() error("log index reads forbidden") end,
        RequestLoadQuestByID = function() error("quest requests forbidden") end }
    C_TaskQuest = { RequestPreloadRewardData = function() error("reward requests forbidden") end }
    C_Timer = { After = function() error("timers forbidden") end }
end
local function check(name, callback)
    reset(); local ok, err = pcall(callback)
    assert(ok, name .. ": " .. tostring(err)); total = total + 1; print("PASS " .. name)
end
check("Explicit preload requests only a clean known cold quest through a current owner", function()
    local requests = 0
    loaded = false
    C_TaskQuest.RequestPreloadRewardData = function(id, ...) requests = requests + 1; assert(id==65 and select("#",...)==0) end
    assert(addon.RequestQuestRewardData(65,function()return true end) and requests==1)
    assert(not addon.RequestQuestRewardData(65,function()return false end) and requests==1)
    loaded=true;assert(not addon.RequestQuestRewardData(65,function()return true end) and requests==1)
    loaded=nil;assert(not addon.RequestQuestRewardData(65,function()return true end) and requests==1)
    loaded=secret;assert(not addon.RequestQuestRewardData(65,function()return true end) and requests==1)
    loaded=false
    for _,id in ipairs({0,-1,65.5,66,9007199254740992,secret})do assert(not addon.RequestQuestRewardData(id,function()return true end))end
    assert(not addon.RequestQuestRewardData(65,nil) and requests==1)
end)
check("Missing failing and rejected preload APIs never claim a dispatched request", function()
    loaded=false
    for _,loader in ipairs({false,function()error("unsupported")end,function()return false end,function()return secret end})do
        C_TaskQuest.RequestPreloadRewardData=loader
        assert(not addon.RequestQuestRewardData(65,function()return true end))
    end
    C_TaskQuest=nil;assert(not addon.RequestQuestRewardData(65,function()return true end))
end)
check("Cold loaded-check reentry must retain character catalogue namespace locale and caller ownership", function()
    local requests=0
    for _,mutate in ipairs({function()addon.char={}end,function()addon.db={}end,function()addon.quests[65]={id=65}end,
        function()addon.quests[65].id=66 end,function()locale="ruRU"end,
        function()C_TaskQuest={}end,function()C_TaskQuest.RequestPreloadRewardData=function()end end})do
        reset();C_TaskQuest.RequestPreloadRewardData=function()requests=requests+1 end
        HaveQuestRewardData=function()mutate();return false end
        assert(not addon.RequestQuestRewardData(65,function()return true end) and requests==0)
    end
    reset();local fresh=true;C_TaskQuest.RequestPreloadRewardData=function()requests=requests+1;fresh=false end
    loaded=false;assert(not addon.RequestQuestRewardData(65,function()return fresh end) and requests==1)
end)
check("Loaded catalogue reward preview routes every explicit ID and exact six-field tuple", function()
    local r = addon.CachedQuestRewards(65)
    assert(r.source == "cache" and #r.items == 1 and #r.choices == 1 and r.money == 12345 and r.xp == 678)
    local a, b = r.items[1], r.choices[1]
    assert(a.id == 7001 and a.name == "Reward" and a.count == 2 and a.texture == 123 and a.quality == 3 and a.usable == false)
    assert(b.id == 8001 and b.texture == "Icon" and b.usable == true)
    assert(addon.db == nil and addon.char == nil)
end)
check("Unknown or restricted loaded evidence rejects before all reward getters", function()
    for _, value in ipairs({ false, secret, 0, 1, "true" }) do
        loaded = value; assert(addon.CachedQuestRewards(65) == nil and calls == 0)
    end
    loaded = nil; assert(addon.CachedQuestRewards(65) == nil and calls == 0)
    HaveQuestRewardData = nil; assert(addon.CachedQuestRewards(65) == nil and calls == 0)
    HaveQuestRewardData = function() error("missing cache") end
    assert(addon.CachedQuestRewards(65) == nil and calls == 0)
end)
check("Only known clean positive integer catalogue IDs can use cached rewards", function()
    for _, id in ipairs({ false, 0, -1, 1.5, math.huge, 0 / 0, "65", secret, 66 }) do
        assert(addon.CachedQuestRewards(id) == nil and calls == 0)
    end
    assert(addon.CachedQuestRewards(nil) == nil)
end)
check("Loaded zero counts are real empty arrays even without item or optional scalar getters", function()
    fixedCount, choiceCount = 0, 0
    GetQuestLogRewardInfo, GetQuestLogChoiceInfo, GetQuestLogRewardMoney, GetQuestLogRewardXP = nil, nil, nil, nil
    local r = addon.CachedQuestRewards(65)
    assert(r and #r.items == 0 and #r.choices == 0 and r.money == nil and r.xp == nil)
    loaded = false; assert(addon.CachedQuestRewards(65) == nil)
end)
check("Malformed unknown counts never become empty rewards", function()
    for _, value in ipairs({ false, -1, 0.5, 101, math.huge, 0 / 0, secret, "0" }) do
        reset(); fixedCount = value; assert(addon.CachedQuestRewards(65) == nil)
        reset(); choiceCount = value; assert(addon.CachedQuestRewards(65) == nil)
    end
    reset(); fixedCount = nil; assert(addon.CachedQuestRewards(65) == nil)
    reset(); GetNumQuestLogChoices = nil; assert(addon.CachedQuestRewards(65) == nil)
end)
check("All present native getter errors discard the full snapshot", function()
    for _, key in ipairs({ "GetNumQuestLogRewards", "GetNumQuestLogChoices", "GetQuestLogRewardInfo",
        "GetQuestLogChoiceInfo", "GetQuestLogRewardMoney", "GetQuestLogRewardXP" }) do
        reset(); _G[key] = function() error("unavailable") end
        assert(addon.CachedQuestRewards(65) == nil, key)
    end
    reset(); GetQuestLogRewardInfo = nil; assert(addon.CachedQuestRewards(65) == nil)
end)
check("Every secret fixed or choice item tuple field rejects partial arrays", function()
    for field = 1, 6 do
        reset(); fixed[field] = secret; assert(addon.CachedQuestRewards(65) == nil)
        reset(); choice[field] = secret; assert(addon.CachedQuestRewards(65) == nil)
    end
    reset(); issecretvalue = function() error("restricted checker") end
    assert(addon.CachedQuestRewards(65) == nil)
end)
check("Essential item names IDs and quantities must be usable clean values", function()
    for _, value in ipairs({ "", false, 7, string.rep("x", 30001) }) do
        reset(); fixed[1] = value; assert(addon.CachedQuestRewards(65) == nil)
    end
    for _, field in ipairs({ 3, 6 }) do
        for _, value in ipairs({ 0, -1, 1.5, math.huge, "2" }) do
            reset(); fixed[field] = value; assert(addon.CachedQuestRewards(65) == nil)
        end
    end
    reset(); choice[1] = nil; assert(addon.CachedQuestRewards(65) == nil)
end)
check("Optional clean scalar and item fields do not fabricate defaults", function()
    fixed[2], fixed[4], fixed[5] = nil, nil, nil
    GetQuestLogRewardMoney = function() return secret end
    GetQuestLogRewardXP = function() return -1 end
    local r = addon.CachedQuestRewards(65)
    assert(r and r.items[1].texture == nil and r.items[1].quality == nil and r.items[1].usable == nil)
    assert(r.money == nil and r.xp == nil)
    GetQuestLogRewardMoney, GetQuestLogRewardXP = function() return 0 end, function() return 0 end
    r = addon.CachedQuestRewards(65); assert(r.money == 0 and r.xp == 0)
end)
check("Cache data loss during item scalar or final guard reads invalidates the snapshot", function()
    GetQuestLogRewardInfo = function() loaded = false; return unpack(fixed, 1, 6) end
    assert(addon.CachedQuestRewards(65) == nil)
    reset(); GetQuestLogRewardXP = function() loaded = nil; return 30 end
    assert(addon.CachedQuestRewards(65) == nil)
    reset(); local guards = 0
    HaveQuestRewardData = function() guards = guards + 1; return guards == 1 end
    assert(addon.CachedQuestRewards(65) == nil and guards == 2)
end)
check("Mid-read locale mutation including the final loaded guard discards mixed locale results", function()
    GetQuestLogChoiceInfo = function() locale = "ruRU"; return unpack(choice, 1, 6) end
    assert(addon.CachedQuestRewards(65) == nil)
    reset(); local guards = 0
    HaveQuestRewardData = function() guards = guards + 1; if guards == 2 then locale = "ruRU" end; return true end
    assert(addon.CachedQuestRewards(65) == nil)
    reset(); GetLocale = nil; assert(addon.CachedQuestRewards(65) == nil and calls == 0)
end)
check("Replacement native capabilities or catalogue identity cannot publish older data", function()
    GetQuestLogRewardInfo = function() GetQuestLogChoiceInfo = function() error("new API") end; return unpack(fixed, 1, 6) end
    assert(addon.CachedQuestRewards(65) == nil)
    reset(); HaveQuestRewardData = function() HaveQuestRewardData = function() return true end; return true end
    assert(addon.CachedQuestRewards(65) == nil)
    reset(); GetQuestLogRewardMoney = function() addon.quests[65] = { id = 65 }; return 0 end
    assert(addon.CachedQuestRewards(65) == nil)
end)
check("Character context and catalogue ownership survive every cached reward read", function()
    for _, mutate in ipairs({
        function() addon.char = {} end,
        function() addon.db = {} end,
        function() addon.quests = { [65] = addon.quests[65] } end,
        function() addon.quests[65].id = 66 end,
        function() addon.quests = nil end,
        function() addon.InvalidateContext() end,
    }) do
        reset()
        GetQuestLogRewardInfo = function() mutate(); return unpack(fixed, 1, 6) end
        assert(addon.CachedQuestRewards(65) == nil, "stale reward survived item read")
        reset()
        local checks = 0
        HaveQuestRewardData = function()
            checks = checks + 1
            if checks == 2 then mutate() end
            return true
        end
        assert(addon.CachedQuestRewards(65) == nil, "stale reward survived final loaded guard")
    end
    reset()
    addon.quests[65].id = 66
    assert(addon.CachedQuestRewards(65) == nil and calls == 0, "wrong source identity read rewards")
end)
check("The hundredth item is bounded and any later malformed row discards earlier rows", function()
    fixedCount, choiceCount = 100, 0
    GetQuestLogRewardInfo = function(index, id) assert(id == 65); return "Reward", 123, 1, 2, true, 7000 + index end
    local r = addon.CachedQuestRewards(65); assert(#r.items == 100 and r.items[100].id == 7100)
    GetQuestLogRewardInfo = function(index) if index < 100 then return "Reward", 123, 1, 2, true, 7000 + index end end
    assert(addon.CachedQuestRewards(65) == nil)
end)
check("Repeated calls reread current data and return detached locale-specific snapshots", function()
    local first = addon.CachedQuestRewards(65)
    locale, fixed[1], fixed[6] = "ruRU", "Награда", 7002
    local next = addon.CachedQuestRewards(65)
    assert(first.items[1].name == "Reward" and next.items[1].name == "Награда" and next.items[1].id == 7002)
    next.items[1].name = "Changed"; assert(addon.CachedQuestRewards(65).items[1].name == "Награда")
end)
issecretvalue = nil
print("Cached reward modeled checks passed: " .. total .. " (native client unverified)")
