local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local secret, state = {}, {}
local fixed, choice, itemHook
local function forbidden()
    state.forbiddenCalls = (state.forbiddenCalls or 0) + 1
    error("client mutation or selected-log read forbidden")
end
local function reset()
    state = { id = 65, player = "Player-1-ABC", locale = "ruRU", shown = true, detail = true,
        fixed = 1, choices = 1, money = 12345, xp = 500, allowed = true, reads = 0, forbiddenCalls = 0 }
    fixed, choice, itemHook = { "Reward", 123, 2, 3, false, 7001 },
        { "Choice", "Interface\\Icons\\Choice", 1, 4, true, 8001 }, nil
    addon.quests = { [65] = {}, [132] = {} }
    issecretvalue = function(v) return v == secret end
    GetQuestID = function(...) assert(select("#", ...) == 0); return state.id end
    GetLocale = function() return state.locale end
    UnitGUID = function(unit) assert(unit == "player", "item offer must not require NPC"); return state.player end
    QuestFrame = { IsShown = function() return state.shown end }
    QuestFrameDetailPanel = { IsShown = function() return state.detail end }
    C_QuestLog = { ShouldShowQuestRewards = function(id) assert(id == state.id); return state.allowed end,
        GetSelectedQuest = forbidden, SetSelectedQuest = forbidden, GetLogIndexForQuestID = forbidden }
    GetNumQuestRewards = function(...) assert(select("#", ...) == 0); state.reads = state.reads + 1; return state.fixed end
    GetNumQuestChoices = function(...) assert(select("#", ...) == 0); return state.choices end
    GetQuestItemInfo = function(kind, index, ...)
        assert((kind == "reward" or kind == "choice") and index >= 1 and select("#", ...) == 0)
        if itemHook then itemHook(kind, index) end
        return unpack(kind == "reward" and fixed or choice, 1, 6)
    end
    GetRewardMoney = function(...) assert(select("#", ...) == 0); return state.money end
    GetRewardXP = function(...) assert(select("#", ...) == 0); return state.xp end
    AcceptQuest, CompleteQuest, GetQuestReward = forbidden, forbidden, forbidden
    SelectAvailableQuest, SelectGossipAvailableQuest, CloseQuest = forbidden, forbidden, forbidden
    addon.DialogueRewardEvent("QUEST_FINISHED")
end
local function open() addon.DialogueRewardEvent("QUEST_DETAIL") end
local function check(name, fn)
    reset()
    local ok, err = pcall(fn)
    if not ok then error(name .. ": " .. tostring(err), 0) end
    assert(state.forbiddenCalls == 0, name .. ": forbidden client call was caught and hidden")
    total = total + 1; print("PASS " .. name)
end
check("Item-started detail uses six-value native tuples without NPC or selection reads", function()
    open(); local r = addon.DialogueRewards(65)
    assert(r.source == "dialogue" and r.hidden == nil and r.money == 12345 and r.xp == 500)
    assert(r.items[1].id == 7001 and r.items[1].name == "Reward" and r.items[1].count == 2)
    assert(r.items[1].texture == 123 and r.items[1].quality == 3 and r.items[1].usable == false)
    assert(r.choices[1].id == 8001 and r.choices[1].usable == true)
end)
check("Matching raw ID without a captured detail event never authorizes reads", function()
    assert(addon.DialogueRewards(65) == nil and state.reads == 0)
end)
check("Unknown catalog and wrong requested IDs never inspect another reward list", function()
    open(); assert(addon.DialogueRewards(132) == nil and state.reads == 0)
    for _, id in ipairs({ 0, -1, 1.5, math.huge, 0 / 0, "65", secret }) do
        assert(addon.DialogueRewards(id) == nil)
    end
    state.id = 999; open(); assert(addon.DialogueRewards(999) == nil)
end)
check("Hidden rewards are explicit and distinct from real empty or unknown lists", function()
    open(); state.allowed = false
    GetNumQuestRewards = forbidden
    local r = addon.DialogueRewards(65)
    assert(r and r.hidden == true and r.source == "dialogue" and r.items == nil and r.choices == nil)
    reset(); open(); state.fixed, state.choices = 0, 0; GetQuestItemInfo = nil
    r = addon.DialogueRewards(65); assert(r and #r.items == 0 and #r.choices == 0 and not r.hidden)
    state.fixed = nil; assert(addon.DialogueRewards(65) == nil)
end)
check("Unavailable restricted and failing reward visibility never become hidden false", function()
    for _, predicate in ipairs({ function() return nil end, function() return secret end,
        function() error("not loaded") end, function() return 1 end }) do
        reset(); open(); C_QuestLog.ShouldShowQuestRewards = predicate
        assert(addon.DialogueRewards(65) == nil)
    end
    reset(); open(); C_QuestLog.ShouldShowQuestRewards = nil; assert(addon.DialogueRewards(65) == nil)
    C_QuestLog = nil; assert(addon.DialogueRewards(65) == nil)
end)
check("Hidden or missing dialogue panels invalidate a stale matching native quest ID", function()
    open(); assert(addon.DialogueRewards(65)); state.shown = false; assert(addon.DialogueRewards(65) == nil)
    state.shown = true; assert(addon.DialogueRewards(65) == nil)
    open(); assert(addon.DialogueRewards(65)); state.detail = false; assert(addon.DialogueRewards(65) == nil)
    reset(); open(); QuestFrame = nil; assert(addon.DialogueRewards(65) == nil)
    reset(); open(); QuestFrameDetailPanel.IsShown = function() return secret end
    assert(addon.DialogueRewards(65) == nil)
end)
check("Every close transition clears ownership while item refresh preserves it", function()
    for _, event in ipairs({ "QUEST_FINISHED", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_ACCEPTED", "QUEST_REMOVED",
        "QUEST_TURNED_IN", "GOSSIP_SHOW", "GOSSIP_CLOSED", "GOSSIP_OPTIONS_REFRESHED", "QUEST_GREETING",
        "PLAYER_LEAVING_WORLD", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT" }) do
        reset(); open(); addon.DialogueRewardEvent(event); assert(addon.DialogueRewards(65) == nil, event)
    end
    reset(); open(); addon.DialogueRewardEvent("QUEST_ITEM_UPDATE"); assert(addon.DialogueRewards(65))
    addon.DialogueRewardEvent("ITEM_DATA_LOAD_RESULT"); assert(addon.DialogueRewards(65))
    addon.DialogueRewardEvent("QUEST_LOG_UPDATE"); assert(addon.DialogueRewards(65))
end)
check("Player locale and current quest changes require a fresh detail generation", function()
    for _, field in ipairs({ "player", "locale", "id" }) do
        reset(); open(); local old = state[field]
        state[field] = field == "id" and 132 or "different"
        assert(addon.DialogueRewards(65) == nil)
        state[field] = old; assert(addon.DialogueRewards(65) == nil)
        open(); assert(addon.DialogueRewards(65))
    end
end)
check("Reentrant closure or same-ID reopening during reads rejects the prior snapshot", function()
    for _, event in ipairs({ "QUEST_FINISHED", "QUEST_DETAIL" }) do
        reset(); open(); itemHook = function() addon.DialogueRewardEvent(event) end
        assert(addon.DialogueRewards(65) == nil, event)
    end
    itemHook = nil; assert(addon.DialogueRewards(65))
end)
check("Hidden predicate and optional money readers cannot race ownership checks", function()
    open(); C_QuestLog.ShouldShowQuestRewards = function() addon.DialogueRewardEvent("QUEST_FINISHED"); return false end
    assert(addon.DialogueRewards(65) == nil)
    reset(); open(); GetRewardMoney = function() state.player = "Player-2"; return 50 end
    assert(addon.DialogueRewards(65) == nil)
    reset(); open(); GetRewardXP = function() state.locale = "enUS"; return 50 end
    assert(addon.DialogueRewards(65) == nil)
end)
check("Native reads stop immediately when a count or item loses dialogue ownership", function()
    open(); GetNumQuestRewards = function() addon.DialogueRewardEvent("QUEST_FINISHED"); return 1 end
    GetNumQuestChoices, GetQuestItemInfo = forbidden, forbidden
    assert(addon.DialogueRewards(65) == nil)
    reset(); open(); local calls = 0
    itemHook = function() calls = calls + 1; addon.DialogueRewardEvent("QUEST_FINISHED") end
    assert(addon.DialogueRewards(65) == nil and calls == 1)
    reset(); open(); GetRewardMoney = function() addon.DialogueRewardEvent("QUEST_FINISHED"); return 1 end
    GetRewardXP = forbidden; assert(addon.DialogueRewards(65) == nil)
end)
check("Reentrant panel visibility checks cannot authorize a detached old generation", function()
    open(); QuestFrameDetailPanel.IsShown = function() addon.DialogueRewardEvent("QUEST_FINISHED"); return true end
    assert(addon.DialogueRewards(65) == nil and state.reads == 0)
end)
check("Partial item cache stays unknown then item updates return fresh detached snapshots", function()
    open(); fixed[1] = nil; assert(addon.DialogueRewards(65) == nil)
    fixed[1] = "Loaded"; addon.DialogueRewardEvent("QUEST_ITEM_UPDATE")
    local r = addon.DialogueRewards(65); assert(r.items[1].name == "Loaded")
    r.items[1].name = "caller changed"; assert(addon.DialogueRewards(65).items[1].name == "Loaded")
    fixed[6] = nil; assert(addon.DialogueRewards(65) == nil)
end)
check("Missing and throwing native getters never produce partial reward arrays", function()
    for _, key in ipairs({ "GetNumQuestRewards", "GetNumQuestChoices", "GetQuestItemInfo" }) do
        reset(); open(); _G[key] = nil; assert(addon.DialogueRewards(65) == nil, key)
        reset(); open(); _G[key] = function() error("unavailable") end; assert(addon.DialogueRewards(65) == nil, key)
    end
end)
check("Counts must be finite bounded integers with both hundredth rows included", function()
    for _, value in ipairs({ -1, 0.5, 101, math.huge, 0 / 0, "1", secret }) do
        reset(); open(); state.fixed = value; assert(addon.DialogueRewards(65) == nil)
        reset(); open(); state.choices = value; assert(addon.DialogueRewards(65) == nil)
    end
    reset(); open(); state.fixed, state.choices = 100, 100
    itemHook = function(_, i) fixed[6], choice[6] = 7000 + i, 8000 + i end
    local r = addon.DialogueRewards(65); assert(#r.items == 100 and r.items[100].id == 7100)
    assert(#r.choices == 100 and r.choices[100].id == 8100)
    itemHook = function(kind, i) if kind == "choice" and i == 100 then choice[1] = nil end end
    assert(addon.DialogueRewards(65) == nil)
end)
check("Every restricted consumed tuple field fails closed before interpretation", function()
    for i = 1, 6 do
        reset(); open(); fixed[i] = secret; assert(addon.DialogueRewards(65) == nil)
        reset(); open(); choice[i] = secret; assert(addon.DialogueRewards(65) == nil)
    end
    reset(); open(); issecretvalue = function() error("restricted checker") end
    assert(addon.DialogueRewards(65) == nil)
end)
check("Malformed item names quantities and IDs do not become usable rows", function()
    for _, value in ipairs({ "", 12, false }) do
        reset(); open(); fixed[1] = value; assert(addon.DialogueRewards(65) == nil)
    end
    for _, field in ipairs({ 3, 6 }) do
        for _, value in ipairs({ 0, -1, 1.5, math.huge, 0 / 0, "1" }) do
            reset(); open(); fixed[field] = value; assert(addon.DialogueRewards(65) == nil)
        end
    end
end)
check("Optional clean fields preserve real zero and false without fabricated data", function()
    open(); fixed[2], fixed[4], fixed[5] = nil, nil, nil
    state.money, state.xp = 0, 0
    local r = addon.DialogueRewards(65)
    assert(r.money == 0 and r.xp == 0 and r.items[1].texture == nil and r.items[1].quality == nil)
    assert(r.items[1].usable == nil and r.choices[1].usable == true)
    for _, value in ipairs({ -1, 0.5, math.huge, 0 / 0, secret }) do
        state.money, state.xp = value, value; r = addon.DialogueRewards(65)
        assert(r.money == nil and r.xp == nil)
    end
    GetRewardMoney, GetRewardXP = nil, nil; r = addon.DialogueRewards(65)
    assert(r and r.money == nil and r.xp == nil)
end)
check("Bad capture identity and reentrant detail capture never authorize rewards", function()
    for _, field in ipairs({ "id", "player", "locale" }) do
        reset(); state[field] = secret; open(); assert(addon.DialogueRewards(65) == nil)
    end
    reset(); GetQuestID = function() addon.DialogueRewardEvent("QUEST_FINISHED"); return 65 end
    open(); assert(addon.DialogueRewards(65) == nil)
end)
check("Offered rewards cannot cross character catalogue definition or native scope replacement", function()
    for _,kind in ipairs({"character","catalogue","definition","idGetter","localeGetter","playerGetter","checker"})do
        reset();open()
        itemHook=function()
            itemHook=nil
            if kind=="character"then addon.char={}
            elseif kind=="catalogue"then addon.quests={[65]=addon.quests[65]}
            elseif kind=="definition"then addon.quests[65]={}
            elseif kind=="idGetter"then GetQuestID=function()return state.id end
            elseif kind=="localeGetter"then GetLocale=function()return state.locale end
            elseif kind=="playerGetter"then UnitGUID=function()return state.player end
            else issecretvalue=function()return false end end
        end
        assert(addon.DialogueRewards(65)==nil,kind.." returned a stale dialogue reward DTO")
    end
end)
check("Offered reward getters cannot mix capabilities within one detached snapshot", function()
    for _,kind in ipairs({"items","choices","fixedCount","choiceCount","money","xp","visibility","namespace"})do
        reset();open()
        itemHook=function()
            itemHook=nil
            if kind=="items"or kind=="choices"then GetQuestItemInfo=function()return"New",999,1,1,true,9999 end
            elseif kind=="fixedCount"then GetNumQuestRewards=function()return 0 end
            elseif kind=="choiceCount"then GetNumQuestChoices=function()return 0 end
            elseif kind=="money"then GetRewardMoney=function()return 999 end
            elseif kind=="xp"then GetRewardXP=function()return 999 end
            elseif kind=="visibility"then C_QuestLog.ShouldShowQuestRewards=function()return false end
            else C_QuestLog={ShouldShowQuestRewards=C_QuestLog.ShouldShowQuestRewards}end
        end
        assert(addon.DialogueRewards(65)==nil,kind.." mixed reward producers")
    end
end)
check("Native visibility validation cannot authorize a replaced reward producer",function()
    open()
    QuestFrameDetailPanel.IsShown=function()
        GetRewardXP=function()return 999 end
        return true
    end
    assert(addon.DialogueRewards(65)==nil and state.reads==0)
end)
check("Malformed reward visibility namespaces quietly remain unavailable",function()
    for _,value in ipairs({false,3,"missing",secret})do
        reset();open();C_QuestLog=value
        assert(addon.DialogueRewards(65)==nil and state.reads==0)
    end
end)
check("Offered event-before-show survives early reads by every dialogue consumer",function()
    for _,role in ipairs({"DialogueRewards","DialogueObjectiveText","DialoguePortrait"})do
        reset();state.shown,state.detail=false,false
        GetObjectiveText=function()return"Objective summary"end
        GetQuestPortraitGiver=function()return 1234 end
        open();assert(addon[role](65)==nil and state.reads==0)
        assert(addon.DialogueRewards(132)==nil,"wrong consumer must not clear pending evidence")
        state.shown,state.detail=true,true
        assert(addon[role](65),role.." permanently erased pending offered evidence")
        state.detail=false;assert(addon[role](65)==nil)
        state.detail=true;assert(addon[role](65)==nil,"observed close must remain terminal")
    end
end)
check("Unknown visibility and terminal pending identity loss cannot resurrect offered evidence",function()
    for _,kind in ipairs({"unknown","restricted","player","getter"})do
        reset();state.shown,state.detail=false,false;open()
        local old=QuestFrame.IsShown
        if kind=="unknown"then state.shown=nil elseif kind=="restricted"then state.shown=secret
        elseif kind=="player"then state.player="Player-other"else QuestFrame.IsShown=function()return false end end
        assert(addon.DialogueRewards(65)==nil)
        state.shown,state.detail,state.player=true,true,"Player-1-ABC";QuestFrame.IsShown=old
        assert(addon.DialogueRewards(65)==nil,kind.." revived stale pending evidence")
    end
end)
print("Offered reward modeled checks passed: " .. total .. " (native client unverified)")
