local name, addon = ...
local events = CreateFrame("Frame")
local initialized, pending = false, false

local function refresh()
    if pending or not initialized then return end
    pending = true
    local function run() pending = false; addon.Notify() end
    if C_Timer and C_Timer.After then C_Timer.After(0.1, run) else run() end
end

events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= name or initialized then return end
        local _, _, _, interface = GetBuildInfo()
        if interface ~= 16001 or WOW_PROJECT_ID ~= 18 then
            print("DungeonPrep: " .. addon.L("UNSUPPORTED")); return
        end
        if not addon.RestoreDB() then print("DungeonPrep: unsupported saved data version"); return end
        initialized = true
        for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_DATA_LOAD_RESULT", "QUEST_ACCEPTED", "QUEST_REMOVED",
            "QUEST_TURNED_IN", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "QUEST_DETAIL", "PLAYER_LOGOUT" }) do
            events:RegisterEvent(e)
        end
        SLASH_DUNGEONPREP1 = "/dprep"
        SLASH_DUNGEONPREP2 = "/dungeonprep"
        SlashCmdList.DUNGEONPREP = function(msg)
            if msg == "clear" then addon.Navigation.Stop()
            elseif msg == "probe" then addon.ProbeClient()
            else addon.UI:Toggle() end
        end
        return
    end
    if not initialized then return end
    if event == "QUEST_DETAIL" then addon.CaptureQuestText() end
    if event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" then addon.Navigation.Stop() end
    refresh()
end)
