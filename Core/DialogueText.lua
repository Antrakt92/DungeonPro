local _, addon = ...
local generation, observation = {}, nil
local onEvent, dialogueText, turnInPortrait
local invalidates = {
    QUEST_FINISHED=true, QUEST_DETAIL=true, QUEST_GREETING=true, GOSSIP_SHOW=true,
    GOSSIP_CLOSED=true, GOSSIP_OPTIONS_REFRESHED=true, QUEST_ACCEPTED=true, QUEST_REMOVED=true,
    QUEST_TURNED_IN=true, PLAYER_LEAVING_WORLD=true, PLAYER_ENTERING_WORLD=true, PLAYER_LOGOUT=true,
}
local function integer(value)
    value = addon.Clean(value, "number")
    if value and value > 0 and value <= 9007199254740991 and value % 1 == 0 then return value end
end
local function object(value)
    return addon.Clean(value, "table") or addon.Clean(value, "userdata")
end
local function method(value, key)
    local ok, fn = pcall(function() return value[key] end)
    return ok and addon.Clean(fn, "function") or nil
end
local function identities(s, pending)
    local ok, same = pcall(function()
        return (pending or observation == s) and generation == s.generation and
            addon.DialogueTextEvent == onEvent and addon.quests == s.catalog and rawget(s.catalog, s.id) == s.definition and
            rawget(s.definition, "id") == s.id and addon.char == s.character and issecretvalue == s.checker and
            addon.Clean == s.clean and addon.Read == s.read and GetQuestID == s.idGetter and
            UnitGUID == s.playerGetter and GetLocale == s.localeGetter and
            QuestFrame == s.frame and QuestFrameProgressPanel == s.progressPanel and QuestFrameRewardPanel == s.rewardPanel and
            s.frame.IsShown == s.frameShown and s.progressPanel.IsShown == s.progressShown and s.rewardPanel.IsShown == s.rewardShown
    end)
    return ok and same == true
end
local function abandon(s)
    if observation == s and generation == s.generation then observation, generation = nil, {} end
end
onEvent = function(event)
    local entry = generation
    event = addon.Clean(event, "string")
    if entry ~= generation then return end
    local stage = event == "QUEST_PROGRESS" and "progress" or event == "QUEST_COMPLETE" and "completion"
    if not stage then
        if event and invalidates[event] then observation, generation = nil, {} end
        return
    end
    generation, observation = {}, nil
    local token = generation
    local s = { generation=token, stage=stage, checker=issecretvalue, clean=addon.Clean, read=addon.Read,
        idGetter=GetQuestID, playerGetter=UnitGUID, localeGetter=GetLocale,
        textGetter=stage == "progress" and GetProgressText or GetRewardText,
        frame=QuestFrame, progressPanel=QuestFrameProgressPanel, rewardPanel=QuestFrameRewardPanel }
    s.catalog, s.character = addon.Clean(addon.quests, "table"), addon.Clean(addon.char, "table")
    if not s.catalog or not s.character or not object(s.frame) or not object(s.progressPanel) or not object(s.rewardPanel) or
        not addon.Clean(s.idGetter, "function") or not addon.Clean(s.playerGetter, "function") or
        not addon.Clean(s.localeGetter, "function") then return end
    s.frameShown, s.progressShown, s.rewardShown = method(s.frame, "IsShown"), method(s.progressPanel, "IsShown"), method(s.rewardPanel, "IsShown")
    if not s.frameShown or not s.progressShown or not s.rewardShown then return end
    s.id = integer(addon.Read(s.idGetter, "number"))
    s.definition = s.id and addon.Clean(rawget(s.catalog, s.id), "table")
    s.player, s.locale = addon.Read(s.playerGetter, "string", "player"), addon.Read(s.localeGetter, "string")
    if generation ~= token or not s.id or not s.definition or integer(rawget(s.definition, "id")) ~= s.id or
        not s.player or #s.player > 256 or not s.player:find("%S") or not s.locale or #s.locale > 32 or not s.locale:find("%S") then return end
    if not identities(s, true) then return end
    observation = s
end

local function stageScope(id, ownerCurrent)
    local s = observation
    id = integer(id)
    if not s or id ~= s.id then return nil end
    if not identities(s) then abandon(s); return nil end
    local owner = addon.Clean(ownerCurrent, "function")
    if type(ownerCurrent) ~= "nil" and not owner then return nil end
    local function validate()
        if not identities(s) then return false, "context" end
        local owned = not owner or addon.Read(owner, "boolean") == true
        if not identities(s) then return false, "context" end
        if not owned then return false, "owner" end
        if addon.Read(s.playerGetter, "string", "player") ~= s.player or
            addon.Read(s.localeGetter, "string") ~= s.locale or not identities(s) then return false, "context" end
        local shown = addon.Read(s.frameShown, "boolean", s.frame)
        local progress = addon.Read(s.progressShown, "boolean", s.progressPanel)
        local completion = addon.Read(s.rewardShown, "boolean", s.rewardPanel)
        if shown == nil or progress == nil or completion == nil then return false, "context" end
        if addon.Read(s.idGetter, "number") ~= id then return false, "context" end
        owned = not owner or addon.Read(owner, "boolean") == true
        if not identities(s) then return false, "context" end
        if not owned then return false, "owner" end
        local visible = shown and (s.stage == "progress" and progress and not completion or
            s.stage == "completion" and completion and not progress)
        if not visible then return false, "visibility" end
        return true
    end
    local function current()
        local valid = validate()
        return valid == true
    end
    local function readable()
        local valid, reason = validate()
        if not valid and reason ~= "owner" and (reason ~= "visibility" or s.observedVisible) then abandon(s) end
        return valid
    end
    return s, current, readable
end

dialogueText = function(id, ownerCurrent)
    local s, stageCurrent, readable = stageScope(id, ownerCurrent)
    if not s then return nil end
    local function capabilityCurrent()
        local ok, same = pcall(function()
            return not s.textInvalid and addon.DialogueText == dialogueText and
                (s.stage == "progress" and GetProgressText == s.textGetter or
                 s.stage == "completion" and GetRewardText == s.textGetter)
        end)
        return ok and same == true
    end
    local getter = addon.Clean(s.textGetter, "function")
    local function current()
        return stageCurrent() and capabilityCurrent()
    end
    if not capabilityCurrent() then s.textInvalid = true; return nil end
    if not readable() then return nil end
    s.observedVisible = true
    if not capabilityCurrent() then s.textInvalid = true; return nil end
    if not getter then return nil end
    local text = addon.Read(getter, "string")
    if not readable() then return nil end
    if not capabilityCurrent() then s.textInvalid = true; return nil end
    if not text or #text > 30000 or not text:find("%S") then return nil end
    if not current() then return nil end
    return { source="dialogue", stage=s.stage, text=text, current=current }
end

turnInPortrait = function(id, ownerCurrent)
    local s, stageCurrent, readable = stageScope(id, ownerCurrent)
    if not s or s.stage ~= "completion" then return nil end
    local getter = addon.Clean(GetQuestPortraitTurnIn, "function")
    local function capabilityCurrent()
        local ok, same = pcall(function()
            return addon.DialogueTurnInPortrait == turnInPortrait and GetQuestPortraitTurnIn == getter
        end)
        return ok and same == true
    end
    local function current()
        return stageCurrent() and capabilityCurrent()
    end
    if not readable() then return nil end
    s.observedVisible = true
    if not getter or not current() then return nil end
    local ok, display, _, name = pcall(getter)
    display = addon.Clean(display, "number")
    name = addon.Clean(name, "string")
    if not readable() or not current() then return nil end
    if not ok or not display or display < 0 or display > 4294967295 or display % 1 ~= 0 then return nil end
    local dto = { source="dialogue", stage="completion", current=current }
    if display == 0 then dto.hidden = true else dto.displayID = display end
    if name and #name <= 1024 and name:find("%S") then dto.name = name end
    if not current() then return nil end
    return dto
end
addon.DialogueTextEvent, addon.DialogueText, addon.DialogueTurnInPortrait = onEvent, dialogueText, turnInPortrait
