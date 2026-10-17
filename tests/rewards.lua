local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local selected, logIndex, fixedCount, choiceCount, money = 65, 1, 1, 1, 12345
local fixed, choice = {}, {}
local secret = {}
local function reset()
    selected, logIndex, fixedCount, choiceCount, money = 65, 1, 1, 1, 12345
    GetQuestLogRewardXP, HaveQuestRewardData = nil, nil
    fixed = { "Reward", 123, 2, 3, false, 7001 }
    choice = { "Choice", "Interface\\Icons\\Choice", 1, 4, true, 8001 }
    issecretvalue = function(v) return v == secret end
    C_QuestLog = {
        GetSelectedQuest = function(...) assert(select("#", ...) == 0); return selected end,
        GetLogIndexForQuestID = function(id) assert(id == 65); return logIndex end,
        SetSelectedQuest = function() error("selection writes forbidden") end,
    }
    GetNumQuestLogRewards = function(...) assert(select("#", ...) == 0); return fixedCount end
    GetNumQuestLogChoices = function(...) assert(select("#", ...) == 0); return choiceCount end
    GetQuestLogRewardMoney = function(...) assert(select("#", ...) == 0); return money end
    GetQuestLogRewardInfo = function(index, ...) assert(index == 1 and select("#", ...) == 0); return unpack(fixed, 1, 6) end
    GetQuestLogChoiceInfo = function(index, ...) assert(index == 1 and select("#", ...) == 0); return unpack(choice, 1, 6) end
end
local function check(name, fn)
    reset()
    local ok, err = pcall(fn)
    if not ok then error(name .. ": " .. tostring(err), 0) end
    total = total + 1; print("PASS " .. name)
end
check("Selected active quest maps exact native item tuples and optional money", function()
    local r = addon.QuestRewards(65)
    assert(#r.items == 1 and #r.choices == 1 and r.money == 12345)
    assert(r.items[1].id == 7001 and r.items[1].name == "Reward" and r.items[1].count == 2)
    assert(r.items[1].texture == 123 and r.items[1].quality == 3 and r.items[1].usable == false)
    assert(r.choices[1].id == 8001 and r.choices[1].texture == "Interface\\Icons\\Choice")
    assert(r.choices[1].quality == 4 and r.choices[1].usable == true and r.xp == nil)
end)
check("Missing API and another selected quest never return unrelated rewards", function()
    C_QuestLog = nil; assert(addon.QuestRewards(65) == nil)
    reset(); selected = 66; assert(addon.QuestRewards(65) == nil)
    GetNumQuestLogRewards = function() error("must not inspect other quest rewards") end
    assert(addon.QuestRewards(65) == nil)
end)
check("Only clean positive integer quest IDs and active log indexes qualify", function()
    for _, id in ipairs({ 0, -1, 65.5, math.huge, 0 / 0, "65", secret }) do
        assert(addon.QuestRewards(id) == nil)
    end
    for _, value in ipairs({ 0, -1, 1.5, math.huge, 0 / 0, secret }) do
        logIndex = value; assert(addon.QuestRewards(65) == nil)
    end
    logIndex = nil; assert(addon.QuestRewards(65) == nil)
end)
check("Known zero counts are valid even when item getters are missing", function()
    fixedCount, choiceCount = 0, 0
    GetQuestLogRewardInfo, GetQuestLogChoiceInfo, GetQuestLogRewardMoney = nil, nil, nil
    local r = addon.QuestRewards(65)
    assert(r and #r.items == 0 and #r.choices == 0 and r.money == nil)
end)
check("Unknown fractional negative and excessive counts do not become empty rewards", function()
    for _, value in ipairs({ -1, 0.5, 101, math.huge, 0 / 0, secret }) do
        fixedCount = value; assert(addon.QuestRewards(65) == nil)
        fixedCount, choiceCount = 0, value; assert(addon.QuestRewards(65) == nil)
    end
    fixedCount, choiceCount = 0, nil; assert(addon.QuestRewards(65) == nil)
    reset(); GetNumQuestLogRewards = nil; assert(addon.QuestRewards(65) == nil)
end)
check("Bounded item loops include the hundredth record and reject a later uncached row", function()
    fixedCount, choiceCount = 100, 0
    GetQuestLogRewardInfo = function(index)
        return "Reward " .. index, 123, 1, 2, true, 7000 + index
    end
    local r = addon.QuestRewards(65)
    assert(#r.items == 100 and r.items[100].id == 7100 and #r.choices == 0)
    GetQuestLogRewardInfo = function(index)
        if index == 100 then return nil end
        return "Reward " .. index, 123, 1, 2, true, 7000 + index
    end
    assert(addon.QuestRewards(65) == nil)
end)
check("Count and item getter errors fail the entire snapshot", function()
    GetNumQuestLogRewards = function() error("unavailable") end
    assert(addon.QuestRewards(65) == nil)
    reset(); GetQuestLogRewardInfo = function() error("uncached") end
    assert(addon.QuestRewards(65) == nil)
    reset(); GetQuestLogChoiceInfo = nil; assert(addon.QuestRewards(65) == nil)
end)
check("Every secret tuple field fails closed without partial item arrays", function()
    for field = 1, 6 do
        reset(); fixed[field] = secret; assert(addon.QuestRewards(65) == nil)
        reset(); choice[field] = secret; assert(addon.QuestRewards(65) == nil)
    end
    reset(); issecretvalue = function() error("restricted checker") end
    assert(addon.QuestRewards(65) == nil)
end)
check("Uncached names and invalid item IDs or stack counts fail closed", function()
    for _, value in ipairs({ "", false, 99 }) do
        reset(); fixed[1] = value; assert(addon.QuestRewards(65) == nil)
    end
    reset(); fixed[1] = nil; assert(addon.QuestRewards(65) == nil)
    for _, field in ipairs({ 3, 6 }) do
        for _, value in ipairs({ 0, -1, 0.5, math.huge, 0 / 0, "42" }) do
            reset(); fixed[field] = value; assert(addon.QuestRewards(65) == nil)
        end
    end
end)
check("Missing optional fields remain absent and false usability is preserved", function()
    fixed[2], fixed[4], fixed[5] = nil, nil, nil
    local r = addon.QuestRewards(65)
    assert(r.items[1].texture == nil and r.items[1].quality == nil and r.items[1].usable == nil)
    assert(r.choices[1].usable == true)
end)
check("Unknown restricted negative and failed money remain absent while zero is real", function()
    for _, value in ipairs({ -1, math.huge, 0 / 0, secret }) do
        money = value; assert(addon.QuestRewards(65).money == nil)
    end
    money = 0; assert(addon.QuestRewards(65).money == 0)
    GetQuestLogRewardMoney = function() error("money unavailable") end
    assert(addon.QuestRewards(65).money == nil)
end)
check("Rewards are fresh across changes and locale switches with detached snapshots", function()
    local old = addon.QuestRewards(65)
    fixed = { "Награда", 456, 3, 2, true, 7002 }
    GetLocale = function() return "ruRU" end
    local fresh = addon.QuestRewards(65)
    assert(fresh.items[1].name == "Награда" and fresh.items[1].id == 7002)
    assert(old.items[1].name == "Reward" and old.items[1].id == 7001)
    fresh.items[1].name = "Changed"; assert(addon.QuestRewards(65).items[1].name == "Награда")
end)
check("Selection changes during reads invalidate the snapshot without rewrites", function()
    GetQuestLogRewardInfo = function() selected = 66; return unpack(fixed, 1, 6) end
    assert(addon.QuestRewards(65) == nil)
    reset(); GetQuestLogRewardMoney = function() selected = 66; return 25 end
    assert(addon.QuestRewards(65) == nil)
end)
check("Selected reward namespace and log-index changes cannot retain old ownership", function()
    GetNumQuestLogRewards = function()
        C_QuestLog = { GetSelectedQuest = function() return 66 end, GetLogIndexForQuestID = function() return nil end }
        return 1
    end
    assert(addon.QuestRewards(65) == nil)
    reset(); GetQuestLogRewardInfo = function() logIndex = 2; return unpack(fixed, 1, 6) end
    assert(addon.QuestRewards(65) == nil)
end)
check("Changed selected reward getters locale and checker discard mixed snapshots", function()
    local oldLocale = GetLocale
    for mode = 1, 6 do
        reset(); GetLocale = function() return "enUS" end
        GetQuestLogRewardInfo = function()
            if mode == 1 then GetQuestLogChoiceInfo = function() return unpack(choice, 1, 6) end
            elseif mode == 2 then GetQuestLogRewardInfo = function() return unpack(fixed, 1, 6) end
            elseif mode == 3 then C_QuestLog.GetSelectedQuest = function() return 65 end
            elseif mode == 4 then GetLocale = function() return "ruRU" end
            elseif mode == 5 then GetLocale = function() return "enUS" end
            else issecretvalue = function() return false end end
            return unpack(fixed, 1, 6)
        end
        assert(addon.QuestRewards(65) == nil)
    end
    GetLocale = oldLocale
end)
local function xpSetup()
    GetLocale = function() return "enUS" end
    local state = { value = 1234, loaded = true, visible = true, reads = 0 }
    HaveQuestRewardData = function(id) assert(id == 65); return state.loaded end
    C_QuestLog.ShouldShowQuestRewards = function(id) assert(id == 65); return state.visible end
    GetQuestLogRewardXP = function(id, ...)
        assert(id == 65 and id ~= logIndex and select("#", ...) == 0)
        state.reads = state.reads + 1
        if state.hook then state.hook() end
        return state.value, secret
    end
    C_QuestLog.RequestLoadQuestByID = function() error("XP must not request data") end
    C_TaskQuest = { RequestPreloadRewardData = function() error("XP must not preload data") end }
    C_Timer = { After = function() error("XP must not schedule") end }
    GetMoney = function() error("XP must not inspect balance") end
    return state
end
check("Selected reward XP uses explicit quest ID and first native total without suppressing existing rewards", function()
    local state = xpSetup()
    local result = assert(addon.QuestRewards(65))
    assert(result.xp == 1234 and state.reads == 1 and #result.items == 1 and #result.choices == 1 and result.money == 12345)
    assert(result.items[1].id == 7001 and result.choices[1].id == 8001)
    result.xp = 1; assert(addon.QuestRewards(65).xp == 1234)
end)
check("Loaded visible zero XP is real while cold hidden and unknown data omit only XP", function()
    for _,mode in ipairs({ "zero", "cold", "hidden", "loadedUnknown", "visibleUnknown", "loadedSecret", "visibleSecret" }) do
        reset(); local state = xpSetup()
        if mode == "zero" then state.value = 0 elseif mode == "cold" then state.loaded = false elseif mode == "hidden" then state.visible = false
        elseif mode == "loadedUnknown" then state.loaded = nil elseif mode == "visibleUnknown" then state.visible = nil
        elseif mode == "loadedSecret" then state.loaded = secret else state.visible = secret end
        local result = assert(addon.QuestRewards(65))
        assert(#result.items == 1 and #result.choices == 1 and result.money == 12345)
        if mode == "zero" then assert(result.xp == 0 and state.reads == 1) else assert(result.xp == nil and state.reads == 0,mode) end
    end
end)
check("Missing malformed restricted throwing or invalid XP leaves valid item and money snapshots intact", function()
    for _,mode in ipairs({ "missingXP", "missingLoaded", "missingVisible", "badXP", "throwXP", "secretFunction", "negative", "fraction", "overflow", "nan", "secretValue" }) do
        reset(); local state = xpSetup()
        if mode == "missingXP" then GetQuestLogRewardXP = nil elseif mode == "missingLoaded" then HaveQuestRewardData = nil
        elseif mode == "missingVisible" then C_QuestLog.ShouldShowQuestRewards = nil elseif mode == "badXP" then GetQuestLogRewardXP = false
        elseif mode == "throwXP" then GetQuestLogRewardXP = function() error("cold XP") end
        elseif mode == "secretFunction" then local fn=GetQuestLogRewardXP;issecretvalue=function(v)return v==fn end
        elseif mode == "negative" then state.value = -1 elseif mode == "fraction" then state.value = 1.5 elseif mode == "overflow" then state.value = 9007199254740992
        elseif mode == "nan" then state.value = 0/0 else state.value = secret end
        local result = assert(addon.QuestRewards(65)); assert(result.xp == nil and result.money == 12345 and result.items[1].id == 7001,mode)
    end
end)
check("XP loses only its optional field on loaded visibility or XP capability drift", function()
    for _,mode in ipairs({ "loadedFalse", "hidden", "xpGetter", "loadedGetter", "visibleGetter" }) do
        reset(); local state = xpSetup()
        state.hook = function()
            if mode == "loadedFalse" then state.loaded = false elseif mode == "hidden" then state.visible = false
            elseif mode == "xpGetter" then GetQuestLogRewardXP = function() return 9999 end
            elseif mode == "loadedGetter" then HaveQuestRewardData = function() return true end
            else C_QuestLog.ShouldShowQuestRewards = function() return true end end
        end
        local result = assert(addon.QuestRewards(65)); assert(result.xp == nil and result.items[1].id == 7001 and result.money == 12345,mode)
    end
end)
check("XP callbacks cannot return rewards from a new selection index namespace character or locale", function()
    for _,mode in ipairs({ "selection", "index", "namespace", "character", "locale", "checker" }) do
        reset();local state=xpSetup();local char=addon.char
        state.hook=function()
            if mode=="selection"then selected=66 elseif mode=="index"then logIndex=2 elseif mode=="namespace"then C_QuestLog={}
            elseif mode=="character"then addon.char={} elseif mode=="locale"then GetLocale=function()return"ruRU"end
            else issecretvalue=function()return false end end
        end
        assert(addon.QuestRewards(65)==nil,mode);addon.char=char
    end
end)
check("Final XP scalar sanitization cannot publish replaced optional API data", function()
    local state=xpSetup();local checkSecret=issecretvalue;local armed=true
    issecretvalue=function(value)
        if armed and value==1234 then armed=false;GetQuestLogRewardXP=function()return 9999 end end
        return checkSecret(value)
    end
    local result=assert(addon.QuestRewards(65));assert(not armed and result.xp==nil and result.items[1].id==7001)
end)
check("Another selected quest cannot trigger an XP read and normal selected DTO carries XP without cache fallback", function()
    local state=xpSetup();selected=66
    assert(addon.QuestRewards(65)==nil and state.reads==0)
    selected=65;local result=assert(addon.QuestRewards(65));assert(result.xp==1234)
    -- A valid selected DTO is already the existing UI priority; no separate cache API is needed to fill XP.
end)
check("Late selected ownership reads cannot retain positive or zero XP after cache or visibility loss", function()
    for _,mode in ipairs({"loaded", "visible"}) do
        for _,value in ipairs({1234, 0}) do
            reset(); local state=xpSetup(); state.value=value
            local loadedReads, visibleReads, expired=0,0,false
            HaveQuestRewardData=function(id)assert(id==65);loadedReads=loadedReads+1;return state.loaded end
            C_QuestLog.ShouldShowQuestRewards=function(id)assert(id==65);visibleReads=visibleReads+1;return state.visible end
            GetLocale=function()
                if loadedReads==3 and visibleReads==3 and not expired then
                    expired=true;if mode=="loaded"then state.loaded=false else state.visible=false end
                end
                return "enUS"
            end
            local result=assert(addon.QuestRewards(65))
            assert(expired and state.reads==1 and result.xp==nil,mode)
            assert(result.items[1].id==7001 and result.choices[1].id==8001 and result.money==12345)
        end
    end
end)
check("Final optional visibility reads cannot retain base rewards after selected quest index or character changes", function()
    for _,mode in ipairs({"selection", "index", "character"}) do
        reset(); local state=xpSetup(); local reads,changed=0,false
        C_QuestLog.ShouldShowQuestRewards=function(id)
            assert(id==65);reads=reads+1
            if reads==4 then
                changed=true
                if mode=="selection"then selected=66 elseif mode=="index"then logIndex=2 else addon.char={} end
            end
            return true
        end
        assert(addon.QuestRewards(65)==nil,mode)
        assert(changed and state.reads==1)
    end
end)
issecretvalue = nil
print("Quest reward adapter modeled checks passed: " .. total .. " (native client unverified)")
