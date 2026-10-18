local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local secret, state, hook = {}, {}, nil
local function forbidden() error("unrelated native read or game interaction") end
local function reset()
    addon.DialogueRewardEvent("QUEST_FINISHED")
    addon.quests = { [65] = { id = 65 }, [132] = { id = 132 } }
    state = { id = 65, player = "Player-one", locale = "ruRU", shown = true, detail = true,
        display = 88001, mount = secret, scene = secret, reads = 0 }
    hook = nil
    issecretvalue = function(v) return v == secret end
    GetQuestID = function() return state.id end
    GetLocale = function() return state.locale end
    UnitGUID = function(unit) assert(unit == "player", "portrait ownership must not require an NPC"); return state.player end
    QuestFrame = { IsShown = function() return state.shown end }
    QuestFrameDetailPanel = { IsShown = function() return state.detail end }
    GetQuestPortraitGiver = function(...)
        assert(select("#", ...) == 0, "current-interaction portrait getter takes no questID or log index")
        state.reads = state.reads + 1
        if hook then hook() end
        return state.display, secret, secret, state.mount, state.scene
    end
    C_QuestLog = { GetSelectedQuest = forbidden, GetLogIndexForQuestID = forbidden,
        GetQuestLogPortraitGiver = forbidden, ShouldShowQuestRewards = forbidden, SetSelectedQuest = forbidden }
    AcceptQuest, SelectAvailableQuest, CloseQuest = forbidden, forbidden, forbidden
    addon.db, addon.char = {}, {}
end
local function open() addon.DialogueRewardEvent("QUEST_DETAIL") end
local function read(id)
    assert(type(addon.DialoguePortrait) == "function", "current dialogue portrait producer is required")
    return addon.DialoguePortrait(id or 65)
end
local function check(label, fn)
    reset()
    local ok, err = pcall(fn); assert(ok, label .. ": " .. tostring(err))
    assert(next(addon.db) == nil and next(addon.char) == nil, "portrait must not persist runtime or image data")
    total = total + 1; print("PASS " .. label)
end
check("Ordinary offered portrait uses the zero-argument display tuple without NPC or selected-log binding", function()
    open()
    local portrait = read()
    assert(portrait.displayID == 88001 and portrait.source == "dialogue" and not portrait.hidden)
    assert(state.reads == 1)
    for _, field in ipairs({ "npcID", "questID", "id", "name", "text", "mount", "modelSceneID", "texture" }) do
        assert(portrait[field] == nil, "portrait must not certify a catalogue giver or carry unused fields")
    end
end)
check("Clean zero and player sentinel explicitly hide instead of allowing selected-log fallback", function()
    open()
    for _, display in ipairs({ 0, -1 }) do
        state.display, state.mount = display, 99001
        local portrait = read()
        assert(portrait.hidden == true and portrait.source == "dialogue" and portrait.displayID == nil)
    end
end)
check("Missing throwing restricted and malformed portrait values remain unknown rather than explicit hide", function()
    open()
    for _, value in ipairs({ secret, -2, 0.5, "88001", math.huge, 0/0, false }) do
        state.display = value; assert(read() == nil)
    end
    state.display = nil; assert(read() == nil)
    GetQuestPortraitGiver = nil; assert(read() == nil)
    GetQuestPortraitGiver = function() error("native unavailable") end; assert(read() == nil)
end)
check("No detail token or wrong unknown invalid quest IDs never read an unrelated portrait", function()
    assert(read() == nil and state.reads == 0)
    open()
    for _, value in ipairs({ 132, 999, secret, 0, -1, 1.5, "65", math.huge, 0/0 }) do
        assert(read(value) == nil and state.reads == 0)
    end
    assert(addon.DialoguePortrait(nil) == nil and state.reads == 0)
end)
check("Hidden missing throwing or restricted ordinary panels invalidate matching raw quest ID", function()
    open(); assert(read()); state.shown = false; assert(read() == nil and state.reads == 1)
    state.shown = true; assert(read() == nil)
    reset(); open(); assert(read()); state.detail = false; assert(read() == nil and state.reads == 1)
    reset(); open(); QuestFrame = nil; assert(read() == nil and state.reads == 0)
    reset(); open(); QuestFrameDetailPanel.IsShown = function() return secret end
    assert(read() == nil and state.reads == 0)
    reset(); open(); QuestFrameDetailPanel.IsShown = function() error("not readable") end
    assert(read() == nil and state.reads == 0)
end)
check("Every dialogue transition invalidates portraits while same-generation data refresh preserves ownership", function()
    for _, event in ipairs({ "QUEST_FINISHED", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_ACCEPTED", "QUEST_REMOVED",
        "QUEST_TURNED_IN", "GOSSIP_SHOW", "GOSSIP_CLOSED", "GOSSIP_OPTIONS_REFRESHED", "QUEST_GREETING",
        "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT" }) do
        reset(); open(); addon.DialogueRewardEvent(event); assert(read() == nil and state.reads == 0, event)
    end
    reset(); open(); addon.DialogueRewardEvent("QUEST_ITEM_UPDATE"); assert(read())
    addon.DialogueRewardEvent("ITEM_DATA_LOAD_RESULT"); assert(read())
end)
check("Quest player locale and restricted ownership changes cannot resurrect old portrait evidence", function()
    for _, key in ipairs({ "id", "player", "locale" }) do
        for _, value in ipairs({ secret, "changed" }) do
            reset(); open(); local old = state[key]; state[key] = value
            assert(read() == nil and state.reads == 0)
            state[key] = old; assert(read() == nil)
            open(); assert(read())
        end
    end
end)
check("Close same-ID reopen and character changes during portrait reads reject the prior generation", function()
    for _, event in ipairs({ "QUEST_FINISHED", "QUEST_DETAIL" }) do
        reset(); open(); hook = function() addon.DialogueRewardEvent(event) end
        assert(read() == nil and state.reads == 1, event)
    end
    for _, key in ipairs({ "id", "player", "locale" }) do
        reset(); open(); hook = function() state[key] = key == "id" and 132 or "changed" end
        assert(read() == nil and state.reads == 1)
    end
end)
check("Unused restricted narrative mount and scene values are ignored while fresh display IDs remain detached", function()
    open()
    local first = read(); first.displayID = 7
    assert(read().displayID == 88001)
    state.display, state.mount, state.scene = 88002, 1234, 309
    assert(read().displayID == 88002)
    state.display = 0; assert(read().hidden == true)
    state.display = nil; assert(read() == nil, "unknown must not reuse either previous image or hidden DTO")
end)
check("Reentrant visible-panel checks cannot authorize stale portrait reads", function()
    open(); QuestFrameDetailPanel.IsShown = function() addon.DialogueRewardEvent("QUEST_FINISHED"); return true end
    assert(read() == nil and state.reads == 0)
end)
check("Portrait getter replacement cannot publish its detached previous display",function()
    open();GetQuestPortraitGiver=function()
        GetQuestPortraitGiver=function()return 222 end
        return 111
    end
    assert(read()==nil)
    assert(read().displayID==222)
end)
check("Visibility callbacks cannot dispatch an expired portrait getter",function()
    local armed=false
    QuestFrameDetailPanel.IsShown=function()
        if armed then armed=false;GetQuestPortraitGiver=function()return 222 end end
        return state.detail
    end
    open();armed=true
    assert(read()==nil and state.reads==0)
end)
print("Offered portrait modeled checks passed: " .. total .. " (native client unverified)")
