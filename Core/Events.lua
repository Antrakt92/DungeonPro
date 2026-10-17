local name, addon = ...
local events = CreateFrame("Frame")
local initialized, pending, refreshing = false, false, false

local function refresh()
    if pending or refreshing or not initialized then return end
    local token = {}
    pending = token
    -- Only inline callbacks need recursion suppression; delayed renders may queue new state.
    local immediate = true
    local function run()
        if pending ~= token then return end
        pending, refreshing = false, immediate
        local ok, message = pcall(addon.Notify)
        refreshing = false
        if not ok then error(message) end
    end
    if C_Timer and type(C_Timer.After) == "function" and pcall(C_Timer.After, 0.1, run) then
        immediate = false
    else run() end
end

events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= name or initialized then return end
        local _, _, _, interface = GetBuildInfo()
        if interface ~= 16001 or WOW_PROJECT_ID ~= 18 then
            print("Dungeon Pro: " .. addon.L("UNSUPPORTED")); return
        end
        if not addon.RestoreDB() then print("Dungeon Pro: unsupported saved data version"); return end
        initialized = true
        if addon.Minimap then addon.Minimap:Initialize() end
        for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_DATA_LOAD_RESULT", "ITEM_DATA_LOAD_RESULT", "QUEST_ACCEPTED", "QUEST_REMOVED",
            "QUEST_TURNED_IN", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "QUEST_DETAIL", "PLAYER_LOGOUT",
            "GOSSIP_SHOW", "GOSSIP_CLOSED", "GOSSIP_OPTIONS_REFRESHED", "QUEST_GREETING", "QUEST_FINISHED",
            "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_ITEM_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_LEAVING_WORLD" }) do
            events:RegisterEvent(e)
        end
        SLASH_DUNGEONPRO1 = "/DP"
        SLASH_DUNGEONPRO2 = "/DungeonPro"
        SLASH_DUNGEONPRO3 = "/dprep"
        SLASH_DUNGEONPRO4 = "/dungeonprep"
        SLASH_DUNGEONPRORELOAD1 = "/rl"
        SlashCmdList.DUNGEONPRORELOAD = function()
            local reload = addon.Clean(ReloadUI, "function")
            if reload then reload() end
        end
        SlashCmdList.DUNGEONPRO = function(msg)
            msg = (addon.Clean(msg, "string") or ""):match("^%s*(.-)%s*$"):lower():gsub("%s+", " ")
            if msg == "clear" then addon.Navigation.Stop()
            elseif msg == "probe" then addon.ProbeClient()
            elseif msg == "minimap" and addon.Minimap then addon.Minimap:ToggleVisibility()
            elseif msg == "minimap reset" and addon.Minimap then addon.Minimap:Reset()
            else addon.UI:Toggle() end
        end
        return
    end
    if not initialized then return end
    if event == "PLAYER_ENTERING_WORLD" and addon.Minimap then addon.Minimap:Initialize() end
    if addon.DialogueTextEvent then addon.DialogueTextEvent(event) end
    if addon.DialogueRewardEvent then addon.DialogueRewardEvent(event) end
    if event ~= "QUEST_DATA_LOAD_RESULT" and event ~= "ITEM_DATA_LOAD_RESULT" and event ~= "BAG_UPDATE_DELAYED" then
        addon.OfferEvent(event)
    end
    if event == "QUEST_DATA_LOAD_RESULT" then addon.QuestDataResult(arg1, arg2) end
    if event == "ITEM_DATA_LOAD_RESULT" then addon.ItemDataResult(arg1, arg2) end
    if event == "QUEST_DETAIL" then addon.CaptureQuestText() end
    if event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED" then
        addon.Navigation.QuestChanged(arg1)
    end
    refresh()
end)
