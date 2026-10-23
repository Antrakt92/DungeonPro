local addon, total, secret = {}, 0, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Planner.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local function reset()
    issecretvalue = function(value) return value == secret end
    addon.char = {}
    UnitGUID = function() error("planning must not read player GUID") end
    UnitLevel = function(unit) assert(unit == "player"); return 40 end
    UnitFactionGroup = function() return "Alliance" end
    UnitClass = function() return "Mage", "MAGE" end
    UnitRace = function() return "Dwarf", "Dwarf", 3 end
    C_QuestLog = {
        IsQuestFlaggedCompleted = function() return false end,
        IsOnQuest = function() return false end,
        ReadyForTurnIn = function() return false end,
    }
end
local function check(name, fn)
    reset(); fn(); total = total + 1; print("PASS " .. name)
end
local function quest(id, fields)
    local q = { id = id, minLevel = 1, requirementsKnown = true, start = { npcID = id } }
    for key, value in pairs(fields or {}) do q[key] = value end
    return q
end
check("A captured context loses old character evidence permanently after its root changes", function()
    local old = addon.char
    local c = addon.Context()
    assert(c.level == 40 and c.class == "MAGE" and c.race == 3 and c.faction == "Alliance")
    addon.char = {}
    assert(c.completed(1) == nil and c.active(1) == nil and c.ready(1) == nil)
    assert(c.level == nil and c.class == nil and c.race == nil and c.faction == nil)
    addon.char = old
    assert(c.current() == false and c.completed(1) == nil, "old contexts cannot revive")
    assert(addon.Context().current() == true, "a new context recovers independently")
end)
check("Quest namespaces getters and checker drift cannot publish old booleans", function()
    for _, mode in ipairs({ "namespace", "getter", "character", "checker" }) do
        reset()
        C_QuestLog.IsOnQuest = function()
            if mode == "namespace" then C_QuestLog = {}
            elseif mode == "getter" then C_QuestLog.IsOnQuest = function() return false end
            elseif mode == "character" then addon.char = {}
            else issecretvalue = function() return false end end
            return true
        end
        local c = addon.Context()
        assert(c.active(1) == nil and not c.current(), mode)
    end
end)
check("Character snapshot construction cannot mix facts from changed native readers", function()
    for mode = 1, 3 do
        reset()
        if mode == 3 then
            UnitRace = function() addon.char = {}; return "Dwarf", "Dwarf", 3 end
        else
            UnitLevel = function()
                if mode == 1 then addon.char = {}
                else UnitRace = function() return "Human", "Human", 1 end end
                return 40
            end
        end
        local c = addon.Context()
        assert(c.level == nil and c.class == nil and c.race == nil and not c.current())
        assert(c.completed(1) == nil)
    end
end)
check("Malformed namespaces and restricted facts stay quiet without authorizing progress", function()
    for _, value in ipairs({ true, 1, "quest service", secret }) do
        reset(); C_QuestLog = value
        local c = addon.Context()
        assert(c.completed(1) == nil and c.active(1) == nil and c.ready(1) == nil)
    end
    reset(); UnitLevel = function() return secret end
    UnitClass = function() return "Restricted", secret end
    UnitRace = function() return "Restricted", "Restricted", secret end
    local c = addon.Context()
    assert(c.level == nil and c.class == nil and c.race == nil and c.completed(1) == false)
end)
check("Explicit clean quest reads preserve the ready fallback and stable pre-DB context", function()
    addon.char = nil
    C_QuestLog.ReadyForTurnIn = nil
    C_QuestLog.IsComplete = function(id, ...) assert(id == 7 and select("#", ...) == 0); return true end
    local c = addon.Context()
    assert(c.current() and c.ready(7) == true and c.completed(7) == false and c.active(7) == false)
    for _, id in ipairs({ secret, false, 0, -1, 1.5, "7", math.huge, 0/0 }) do
        assert(c.ready(id) == nil)
    end
end)
check("Huge quest IDs never reach native completion readers", function()
    local reads = 0
    local function counting() reads = reads + 1; return false end
    C_QuestLog.IsQuestFlaggedCompleted = counting
    C_QuestLog.IsOnQuest = counting
    C_QuestLog.ReadyForTurnIn = counting
    C_QuestLog.IsComplete = counting
    local c = addon.Context()
    for _, huge in ipairs({ 9007199254740992, 2 ^ 60 }) do
        assert(c.completed(huge) == nil, "huge completed ID reached a reader")
        assert(c.active(huge) == nil, "huge active ID reached a reader")
        assert(c.ready(huge) == nil, "huge ready ID reached a reader")
    end
    assert(reads == 0, "huge quest ID reached a native reader")
    assert(c.completed(7) == false and c.active(7) == false and c.ready(7) == false, "valid ID lost its read")
    assert(reads > 0, "valid ID lost its native read")
end)
check("Planning discards cached completion and restrictions after context invalidation", function()
    C_QuestLog.IsQuestFlaggedCompleted = function() return true end
    local c = addon.Context()
    local q = quest(1, { factions = { "Horde" } })
    local engine = addon.Planner.New({ [1] = q }, c)
    assert(engine:State(1).status == "COMPLETED")
    addon.char = {}
    local state = engine:State(1)
    assert(state.status == "UNKNOWN" and state.reason == "character" and state.completedHistory == false)
    local eligible, why = addon.Planner.Eligible(q, c)
    assert(eligible == nil and why == "character")
end)
check("An active read cannot survive character replacement inside the ready reader", function()
    C_QuestLog.IsOnQuest = function() return true end
    C_QuestLog.ReadyForTurnIn = function() addon.char = {}; return true end
    local engine = addon.Planner.New({ [1] = quest(1) }, addon.Context())
    local state = engine:State(1)
    assert(state.status == "UNKNOWN" and state.completedHistory == false)
    local actions, unknown = engine:Next(1)
    assert(#actions == 0 and unknown)
end)
local function scopedGraph()
    local valid = true
    local c = { level = 40, completed = function() return false end, active = function() return false end,
        current = function() return valid end }
    local graph = { [1] = quest(1), [2] = quest(2), [3] = quest(3, { requires = { { ids = {1} }, { ids = {2} } } }) }
    return addon.Planner.New(graph, c), function() valid = false end
end
check("A later prerequisite cannot leave accumulated actions from an invalid context", function()
    local engine, invalidate = scopedGraph()
    local place, firstPickupBuilt, laterPrerequisiteRead = engine.quests[1].start, false, false
    engine.quests[1].start = nil
    setmetatable(engine.quests[1], {__index = function(_, key)
        if key == "start" then firstPickupBuilt = true; return place end
    end})
    local native = engine.State
    engine.State = function(self, id)
        -- The initial state walk reads both ancestors before any pickup exists.
        -- This later read belongs to the second AND group, after the first
        -- pickup has been built, validated and accumulated by Next.
        if id == 2 and firstPickupBuilt then laterPrerequisiteRead = true; invalidate() end
        return native(self, id)
    end
    local actions, unknown = engine:Next(3)
    assert(firstPickupBuilt and laterPrerequisiteRead, "invalidation must follow the first safe pickup")
    assert(#actions == 0 and unknown)
end)
check("Dungeon invalidation cannot retain earlier completed counts actions or readiness", function()
    C_QuestLog.IsQuestFlaggedCompleted = function(id) return id == 1 end
    C_QuestLog.IsOnQuest = function(id) if id == 2 then addon.char = {} end; return false end
    local engine = addon.Planner.New({ [1] = quest(1), [2] = quest(2) }, addon.Context())
    local result = engine:Dungeon({ quests = { 1, 2 }, coverage = "reviewed" })
    assert(result.unknown and not result.ready and #result.actions == 0 and #result.rows == 2)
    assert(result.counts.COMPLETED == nil and result.counts.UNKNOWN == 2)
    for _, row in ipairs(result.rows) do assert(row.state.status == "UNKNOWN" and not row.state.completedHistory) end
end)
check("Completion links remain inspectable while invalidated actions and evidence are removed", function()
    local engine, invalidate = scopedGraph()
    engine.quests[3].completionQuests = { { id = 1, itemID = 11 }, { id = 2, itemID = 12 } }
    local native = engine.Next
    engine.Next = function(self, id, path)
        if id == 2 then invalidate(); return {}, true end
        return native(self, id, path)
    end
    local links = engine:CompletionSteps(3)
    assert(#links == 2)
    for _, link in ipairs(links) do assert(#link.actions == 0 and link.unknown and link.state.status == "UNKNOWN") end
end)
check("Optional validity adapters fail closed while absent adapters preserve legacy planning", function()
    local c = { level = 40, completed = function() return false end, active = function() return false end }
    assert(addon.Planner.New({ [1] = quest(1) }, c):State(1).status == "AVAILABLE")
    for _, value in ipairs({ false, true, secret, function() error("scope failed") end,
        function() return nil end, function() return secret end, function() return "true" end }) do
        c.current = value
        local state = addon.Planner.New({ [1] = quest(1) }, c):State(1)
        assert(state.status == "UNKNOWN" and state.completedHistory == false)
    end
end)
check("Huge native creature and race IDs fail closed at 2^53-1", function()
    local MAX = 9007199254740991
    GetLocale = function() return "enUS" end
    -- A huge race input never reaches the native info reader, even when the
    -- native side would echo the same huge identity back.
    local raceReads = 0
    C_CreatureInfo = { GetRaceInfo = function(id)
        raceReads = raceReads + 1
        return { raceID = id, raceName = "Echo race" }
    end }
    assert(addon.RaceName(3) == "Echo race" and raceReads == 1, "valid race ID lost its read")
    assert(addon.RaceName(MAX) == "Echo race", "2^53-1 race ID lost its read")
    for _, huge in ipairs({ 9007199254740992, 2 ^ 60 }) do
        raceReads = 0
        assert(addon.RaceName(huge) == nil, "huge race ID published a name")
        assert(raceReads == 0, "huge race ID reached the native info reader")
    end
    -- A huge returned race identity cannot match a valid input either.
    C_CreatureInfo = { GetRaceInfo = function(id)
        return { raceID = 9007199254740992, raceName = "Wrong race" }
    end }
    assert(addon.RaceName(3) == nil, "huge returned race ID published a name")
    -- A huge native creature ID never authorizes the giver unit name.
    local nameReads = 0
    UnitGUID = function(unit) assert(unit == "npc"); return "Creature-GUID" end
    C_CreatureInfo = { GetCreatureID = function(guid)
        assert(guid == "Creature-GUID"); return 9007199254740992
    end }
    UnitName = function(unit) nameReads = nameReads + 1; return "Native name" end
    local place = { npcID = 234, name = "Source name" }
    assert(addon.GiverName(place) == nil, "huge native creature ID published a name")
    assert(nameReads == 0, "huge native creature ID reached the unit name reader")
    C_CreatureInfo = { GetCreatureID = function(guid)
        assert(guid == "Creature-GUID"); return 234
    end }
    assert(addon.GiverName(place) == "Native name" and nameReads == 1, "matching creature ID lost its name")
end)
check("Probe client caps huge line and quest IDs at 2^53-1 without membership reads", function()
    GetBuildInfo = function() return "11.0.0", "60000", "", "110000" end
    local reads = 0
    local function forbidden()
        reads = reads + 1
        error("huge line ID reached the membership reader")
    end
    C_QuestLine = {
        GetQuestLineInfo = function() return { questLineID = 9007199254740992 } end,
        GetQuestLineQuests = forbidden,
    }
    assert(next(addon.ProbeClient().questLines) == nil, "huge line ID published a quest line")
    assert(reads == 0, "huge line ID reached the membership reader")
    C_QuestLine = {
        GetQuestLineInfo = function() return { questLineID = 9007199254740991 } end,
        GetQuestLineQuests = function() return { 9007199254740991, 9007199254740992, 7 } end,
    }
    local line = addon.ProbeClient().questLines[166]
    assert(line and line.lineID == 9007199254740991, "2^53-1 line ID lost its probe")
    assert(#line.quests == 2 and line.quests[1] == 9007199254740991 and line.quests[2] == 7, "valid member IDs lost their probe")
    assert(line.invalidMembers, "huge member ID did not flag invalid members")
end)
check("Probe client keeps short clean build strings and drops absurd build identity", function()
    C_QuestLine = nil
    GetBuildInfo = function() return "11.0.0", "60000", "", "110000" end
    local r = addon.ProbeClient()
    assert(r.build == "11.0.0" and r.interface == "110000", "valid build strings lost their probe")
    GetBuildInfo = function() return "11.0.0", "60000", "", 16001 end
    r = addon.ProbeClient()
    assert(r.build == "11.0.0" and r.interface == 16001, "numeric interface version lost its probe")
    GetBuildInfo = function() return string.rep("a", 200), "60000", "", string.rep("b", 200) end
    r = addon.ProbeClient()
    assert(r.build == string.rep("a", 200) and r.interface == string.rep("b", 200), "200-character build strings lost their probe")
    GetBuildInfo = function() return string.rep("a", 201), "60000", "", string.rep("b", 500) end
    r = addon.ProbeClient()
    assert(r.build == nil and r.interface == nil, "overlong build strings reached SavedVariables")
    GetBuildInfo = function() return 12345, "60000", "", 9007199254740992 end
    r = addon.ProbeClient()
    assert(r.build == nil and r.interface == nil, "absurd build identity reached SavedVariables")
    for _, absurd in ipairs({ 1.5, -1, math.huge, 0 / 0, secret, false, {} }) do
        GetBuildInfo = function() return "11.0.0", "60000", "", absurd end
        r = addon.ProbeClient()
        assert(r.interface == nil, "absurd interface identity reached SavedVariables")
    end
    GetBuildInfo = function() return secret, "60000", "", "110000" end
    r = addon.ProbeClient()
    assert(r.build == nil and r.interface == "110000", "restricted build did not fail closed")
    GetBuildInfo = nil
    r = addon.ProbeClient()
    assert(r.build == nil and r.interface == nil, "missing build reader did not fail closed")
end)
check("Probe client drops whitespace-only build identity instead of saving blanks", function()
    C_QuestLine = nil
    for _, blank in ipairs({ "", "   ", "\t\n ", "  \r " }) do
        GetBuildInfo = function() return blank, "60000", "", "110000" end
        local r = addon.ProbeClient()
        assert(r.build == nil and r.interface == "110000", "blank build reached SavedVariables")
        GetBuildInfo = function() return "11.0.0", "60000", "", blank end
        r = addon.ProbeClient()
        assert(r.build == "11.0.0" and r.interface == nil, "blank interface reached SavedVariables")
    end
    GetBuildInfo = function() return "11.0.0", "60000", "", "110000" end
    local r = addon.ProbeClient()
    assert(r.build == "11.0.0" and r.interface == "110000", "valid build strings lost their probe")
end)
check("Whitespace-only dialogue and offer scope identities stay unknown", function()
    local savedQuests, savedLog, savedGossip, savedTimer, savedNotify, savedTime, savedGUID,
        savedQuestID, savedLocale, savedFrame, savedPanel, savedObjective =
        addon.quests, C_QuestLog, C_GossipInfo, C_Timer, addon.Notify, GetTime, UnitGUID,
        GetQuestID, GetLocale, QuestFrame, QuestFrameDetailPanel, GetObjectiveText
    local now, player, npc = 100, "Player-one", "Creature-one"
    GetTime = function() return now end
    UnitGUID = function(unit) return unit == "player" and player or npc end
    addon.quests = { [1] = { id = 1 } }
    C_GossipInfo = { GetAvailableQuests = function() return { { questID = 1 } } end }
    C_Timer = nil
    addon.Notify = function() end
    addon.ClearOffers()
    addon.CaptureOffers()
    assert(addon.CurrentOffer(1) ~= nil, "valid offer scope lost its capture")
    for _, blank in ipairs({ "   ", "\t\n ", "  \r " }) do
        player = blank
        addon.ClearOffers(); addon.CaptureOffers()
        assert(addon.CurrentOffer(1) == nil, "blank offer player kept a capture")
        player = "Player-one"; npc = blank
        addon.ClearOffers(); addon.CaptureOffers()
        assert(addon.CurrentOffer(1) == nil, "blank offer NPC kept a capture")
        npc = "Creature-one"
    end
    addon.quests = { [132] = {} }
    player = "Player-1-ABC"
    local locale = "enUS"
    GetQuestID = function() return 132 end
    UnitGUID = function(unit) assert(unit == "player"); return player end
    GetLocale = function() return locale end
    QuestFrame = { IsShown = function() return true end }
    QuestFrameDetailPanel = { IsShown = function() return true end }
    GetObjectiveText = function() return "Summary" end
    C_QuestLog = {}
    addon.DialogueRewardEvent("QUEST_FINISHED")
    addon.DialogueRewardEvent("QUEST_DETAIL")
    assert(addon.DialogueObjectiveText(132) == "Summary", "valid dialogue scope lost its text")
    for _, blank in ipairs({ "   ", "\t\n ", "  \r " }) do
        player = blank; locale = "enUS"
        addon.DialogueRewardEvent("QUEST_FINISHED"); addon.DialogueRewardEvent("QUEST_DETAIL")
        assert(addon.DialogueObjectiveText(132) == nil, "blank dialogue player kept a text")
        player = "Player-1-ABC"; locale = blank
        addon.DialogueRewardEvent("QUEST_FINISHED"); addon.DialogueRewardEvent("QUEST_DETAIL")
        assert(addon.DialogueObjectiveText(132) == nil, "blank dialogue locale kept a text")
    end
    addon.DialogueRewardEvent("QUEST_FINISHED")
    addon.ClearOffers()
    addon.quests, C_QuestLog, C_GossipInfo, C_Timer, addon.Notify, GetTime, UnitGUID,
        GetQuestID, GetLocale, QuestFrame, QuestFrameDetailPanel, GetObjectiveText =
        savedQuests, savedLog, savedGossip, savedTimer, savedNotify, savedTime, savedGUID,
        savedQuestID, savedLocale, savedFrame, savedPanel, savedObjective
end)
check("RestoreDB drops malformed texts members while keeping valid quest texts", function()
    local savedPro, savedChar, savedPrep, savedPrepChar = DungeonProDB, DungeonProCharDB, DungeonPrepDB, DungeonPrepCharDB
    DungeonProDB, DungeonProCharDB, DungeonPrepDB, DungeonPrepCharDB = nil, nil, nil, nil
    local keep, edge = { text = "Valid text", locale = "enUS" }, { text = "Edge text", locale = "enUS" }
    DungeonProCharDB = { texts = {
        [7] = keep, [9007199254740991] = edge, [9007199254740992] = { text = "Huge", locale = "enUS" },
        [0] = { text = "Zero", locale = "enUS" }, [-3] = { text = "Negative", locale = "enUS" },
        [1.5] = { text = "Fractional", locale = "enUS" },
        [8] = "not a table", [9] = 42, [11] = secret,
        filters = {},
    }, filters = {} }
    DungeonProCharDB.texts["7"] = { text = "String key", locale = "enUS" }
    assert(addon.RestoreDB() == true)
    local texts = addon.char.texts
    assert(texts[7] == keep and texts[9007199254740991] == edge, "valid quest texts lost their retention")
    assert(texts[9007199254740992] == nil and texts[0] == nil and texts[-3] == nil and texts[1.5] == nil,
        "absurd text IDs survived retention")
    assert(texts["7"] == nil and texts[8] == nil and texts[9] == nil and texts[11] == nil,
        "malformed text members survived retention")
    DungeonProCharDB = { texts = "not a table", filters = {} }
    assert(addon.RestoreDB() == true and type(addon.char.texts) == "table" and next(addon.char.texts) == nil)
    DungeonProDB, DungeonProCharDB, DungeonPrepDB, DungeonPrepCharDB = savedPro, savedChar, savedPrep, savedPrepChar
end)
print("Character context modeled checks passed: " .. total .. " (no native character validation)")
