local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local secret, state = {}, {}
local function forbidden()
    state.forbidden = state.forbidden + 1
    error("unrelated reward, quest-log, timer or mutation call")
end
local function reset()
    state = { id = 132, player = "Player-1-ABC", locale = "ruRU", shown = true, detail = true,
        text = "Локальная цель задания", calls = 0, forbidden = 0 }
    addon.quests = { [65] = {}, [132] = {} }
    addon.char = { texts = { [132] = { text = "Saved description", locale = "ruRU" } } }
    issecretvalue = function(v) return v == secret end
    GetQuestID = function(...) assert(select("#", ...) == 0); return state.id end
    UnitGUID = function(unit) assert(unit == "player", "item offers need no NPC"); return state.player end
    GetLocale = function() return state.locale end
    QuestFrame = { IsShown = function() return state.shown end }
    QuestFrameDetailPanel = { IsShown = function() return state.detail end }
    GetObjectiveText = function(...)
        assert(select("#", ...) == 0, "objective summary API has no quest ID parameter")
        state.calls = state.calls + 1
        return state.text
    end
    C_QuestLog = { GetSelectedQuest = forbidden, SetSelectedQuest = forbidden,
        GetQuestObjectives = forbidden, ShouldShowQuestRewards = forbidden }
    GetQuestLogQuestText, GetQuestText = forbidden, forbidden
    GetNumQuestRewards, GetNumQuestChoices, GetQuestItemInfo = forbidden, forbidden, forbidden
    GetRewardMoney, GetRewardXP, GetQuestReward = forbidden, forbidden, forbidden
    AcceptQuest, CompleteQuest, SelectAvailableQuest, CloseQuest = forbidden, forbidden, forbidden, forbidden
    C_Timer = { After = forbidden }
    addon.DialogueRewardEvent("QUEST_FINISHED")
end
local function open() addon.DialogueRewardEvent("QUEST_DETAIL") end
local function check(name, fn)
    reset()
    local ok, err = pcall(fn)
    if not ok then error(name .. ": " .. tostring(err), 0) end
    assert(state.forbidden == 0, name .. ": swallowed a forbidden call")
    total = total + 1; print("PASS " .. name)
end
check("Live item-started offer summary uses only the zero-argument objective API", function()
    open(); assert(addon.DialogueObjectiveText(132) == state.text and state.calls == 1)
    assert(addon.DialogueObjectiveText(65) == nil and state.calls == 1)
end)
check("Uncaptured unknown invalid and restricted IDs never read text", function()
    assert(addon.DialogueObjectiveText(132) == nil and state.calls == 0)
    open()
    for _, id in ipairs({ 0, -1, 1.5, math.huge, 0 / 0, "132", secret, 999 }) do
        assert(addon.DialogueObjectiveText(id) == nil and state.calls == 0)
    end
    state.id = 999; open(); assert(addon.DialogueObjectiveText(999) == nil and state.calls == 0)
end)
check("Reward hiding and unavailable reward APIs do not suppress the summary", function()
    open(); C_QuestLog.ShouldShowQuestRewards = function() return false end
    assert(addon.DialogueRewards(132).hidden == true)
    assert(addon.DialogueObjectiveText(132) == state.text)
    C_QuestLog = nil; assert(addon.DialogueObjectiveText(132) == state.text)
    C_QuestLog = { ShouldShowQuestRewards = function() error("no reward API") end }
    assert(addon.DialogueObjectiveText(132) == state.text)
end)
check("Missing throwing empty malformed and oversized text remain unknown", function()
    for _, value in ipairs({ "", false, 1, {}, secret, string.rep("x", 30001) }) do
        state.text = value; open(); assert(addon.DialogueObjectiveText(132) == nil)
    end
    state.text = nil; open(); assert(addon.DialogueObjectiveText(132) == nil)
    GetObjectiveText = nil; assert(addon.DialogueObjectiveText(132) == nil)
    GetObjectiveText = function() error("unavailable") end
    assert(addon.DialogueObjectiveText(132) == nil)
end)
check("Bounded text remains fresh without overwriting the saved description", function()
    open(); local char, texts, description = addon.char, addon.char.texts, addon.char.texts[132]
    local old = addon.DialogueObjectiveText(132)
    state.text = string.rep("a", 30000); assert(addon.DialogueObjectiveText(132) == state.text)
    state.text = "New summary"; assert(addon.DialogueObjectiveText(132) == "New summary" and old ~= state.text)
    state.text = nil; assert(addon.DialogueObjectiveText(132) == nil)
    state.text = "Loaded later"; addon.DialogueRewardEvent("QUEST_ITEM_UPDATE")
    assert(addon.DialogueObjectiveText(132) == "Loaded later")
    assert(addon.char == char and addon.char.texts == texts and texts[132] == description)
    assert(description.text == "Saved description")
end)
check("Hidden missing failing or restricted panels never authorize native text reads", function()
    open(); state.detail = false; assert(addon.DialogueObjectiveText(132) == nil and state.calls == 0)
    state.detail = true; assert(addon.DialogueObjectiveText(132) == nil)
    reset(); open(); state.shown = false; assert(addon.DialogueObjectiveText(132) == nil and state.calls == 0)
    reset(); open(); QuestFrame = nil; assert(addon.DialogueObjectiveText(132) == nil and state.calls == 0)
    reset(); open(); QuestFrameDetailPanel.IsShown = function() error("gone") end
    assert(addon.DialogueObjectiveText(132) == nil and state.calls == 0)
    reset(); open(); QuestFrameDetailPanel.IsShown = function() return secret end
    assert(addon.DialogueObjectiveText(132) == nil and state.calls == 0)
end)
check("Every phase and world transition discards previously readable text", function()
    for _, event in ipairs({ "QUEST_FINISHED", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_ACCEPTED", "QUEST_REMOVED",
        "QUEST_TURNED_IN", "GOSSIP_SHOW", "GOSSIP_CLOSED", "GOSSIP_OPTIONS_REFRESHED", "QUEST_GREETING",
        "PLAYER_LEAVING_WORLD", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT" }) do
        reset(); open(); assert(addon.DialogueObjectiveText(132))
        addon.DialogueRewardEvent(event); assert(addon.DialogueObjectiveText(132) == nil, event)
    end
end)
check("Reentrant closing and same-ID replacement during text read reject the old result", function()
    for _, event in ipairs({ "QUEST_FINISHED", "QUEST_DETAIL" }) do
        reset(); open()
        GetObjectiveText = function() addon.DialogueRewardEvent(event); return "Old result" end
        assert(addon.DialogueObjectiveText(132) == nil, event)
    end
    GetObjectiveText = function() return "New generation" end
    assert(addon.DialogueObjectiveText(132) == "New generation")
end)
check("Quest player and locale changes during the getter invalidate the full context", function()
    for _, field in ipairs({ "id", "player", "locale" }) do
        reset(); open(); local old = state[field]
        GetObjectiveText = function() state[field] = field == "id" and 65 or "different"; return "Wrong owner" end
        assert(addon.DialogueObjectiveText(132) == nil)
        state[field] = old; GetObjectiveText = function() return "Restored raw identity" end
        assert(addon.DialogueObjectiveText(132) == nil)
        open(); assert(addon.DialogueObjectiveText(132) == "Restored raw identity")
    end
end)
check("Failing or missing text still detects context changes before later identity restoration", function()
    for _, throwing in ipairs({ false, true }) do
        reset(); open()
        GetObjectiveText = function()
            state.locale = "enUS"
            if throwing then error("missing data after locale change") end
        end
        assert(addon.DialogueObjectiveText(132) == nil)
        state.locale = "ruRU"; GetObjectiveText = function() return "Should not resurrect" end
        assert(addon.DialogueObjectiveText(132) == nil)
    end
end)
check("Panel closure or reentrant visibility evaluation rejects the old summary", function()
    open(); GetObjectiveText = function() state.shown = false; return "Closed" end
    assert(addon.DialogueObjectiveText(132) == nil)
    state.shown = true; GetObjectiveText = function() return "Stale" end
    assert(addon.DialogueObjectiveText(132) == nil)
    reset(); open()
    QuestFrameDetailPanel.IsShown = function() addon.DialogueRewardEvent("QUEST_FINISHED"); return true end
    assert(addon.DialogueObjectiveText(132) == nil and state.calls == 0)
end)
check("Restricted context and checker failure never inspect objective text", function()
    for _, field in ipairs({ "id", "player", "locale" }) do
        reset(); open(); state[field] = secret
        assert(addon.DialogueObjectiveText(132) == nil and state.calls == 0)
    end
    reset(); open(); issecretvalue = function() error("checker restricted") end
    assert(addon.DialogueObjectiveText(132) == nil and state.calls == 0)
end)
check("Localized summary never becomes a structured objective or saved log description", function()
    open(); local rows = { { text = "Log objective", type = "monster", finished = false,
        numFulfilled = 1, numRequired = 3 } }
    C_QuestLog.GetQuestObjectives = function(id) assert(id == 65); return rows end
    local structured = addon.QuestObjectives(65)
    assert(structured[1].text == "Log objective" and structured[1].numFulfilled == 1)
    assert(addon.DialogueObjectiveText(132) == "Локальная цель задания")
    assert(structured[1].text == "Log objective" and rows[1].numRequired == 3)
    assert(addon.char.texts[132].text == "Saved description")
end)
print("Offered objective modeled checks passed: " .. total .. " (native client unverified)")
