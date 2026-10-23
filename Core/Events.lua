local name, addon = ...
local events = CreateFrame("Frame")
local initialized, pending, refreshing = false, false, false
local contextEvents = { QUEST_LOG_UPDATE = true, QUEST_ACCEPTED = true, QUEST_REMOVED = true, QUEST_TURNED_IN = true,
    QUEST_ITEM_UPDATE = true, BAG_UPDATE_DELAYED = true, PLAYER_LEVEL_UP = true, PLAYER_ENTERING_WORLD = true,
    PLAYER_LEAVING_WORLD = true, PLAYER_LOGOUT = true }
local dataEvents = { QUEST_DATA_LOAD_RESULT = true, ITEM_DATA_LOAD_RESULT = true, QUEST_DETAIL = true,
    GOSSIP_SHOW = true, GOSSIP_CLOSED = true, GOSSIP_OPTIONS_REFRESHED = true, QUEST_GREETING = true,
    QUEST_FINISHED = true, QUEST_PROGRESS = true, QUEST_COMPLETE = true }

local probeNavigation, probeMinimap = addon.Diagnostics.Navigation, addon.Diagnostics.Minimap

local function renderVisible()
    local ui = addon.Clean(addon.UI, "table")
    if not ui then return true end
    local frame = addon.Clean(ui.frame, "table") or addon.Clean(ui.frame, "userdata")
    -- Opening the planner always reads current state; an unopened frame has nothing to paint.
    if not frame then return false end
    local getter = addon.Read(function() return frame.IsShown end, "function")
    local shown = addon.Read(getter, "boolean", frame)
    if addon.UI ~= ui or ui.frame ~= frame then return true end
    return shown ~= false
end

local function refresh(dataOnly)
    if pending then
        if dataOnly ~= true then pending.dataOnly = false end
        return
    end
    if refreshing or not initialized then return end
    if not renderVisible() then return end
    local token = { dataOnly = dataOnly == true }
    pending = token
    -- Only inline callbacks need recursion suppression; delayed renders may queue new state.
    local immediate = true
    local function run()
        if pending ~= token then return end
        pending, refreshing = false, immediate
        if not renderVisible() then refreshing = false; return end
        local ok, message = pcall(addon.Notify, token.dataOnly and "data" or nil)
        refreshing = false
        if not ok then error(message) end
    end
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, 0.1, run) then
        immediate = false
    else run() end
end

events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= name or initialized then return end
        local interface
        if type(GetBuildInfo) == "function" then
            local ok, _, _, _, toc = pcall(GetBuildInfo)
            if ok then interface = toc end
        end
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
        if type(SlashCmdList) == "table" then
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
                if #msg > 1024 then return end
                if msg == "clear" then
                    local nav = addon.Clean(addon.Navigation, "table")
                    local stop = nav and addon.Clean(nav.Stop, "function")
                    if stop then addon.Read(stop, "table") end
                elseif msg == "probe" then addon.ProbeClient()
                elseif msg == "probe nav" then probeNavigation()
                elseif msg == "probe minimap" then probeMinimap()
                elseif msg == "minimap" and addon.Minimap then addon.Minimap:ToggleVisibility()
                elseif msg == "minimap reset" and addon.Minimap then addon.Minimap:Reset()
                else
                    local ui = addon.Clean(addon.UI, "table")
                    local toggle = ui and addon.Clean(ui.Toggle, "function")
                    if toggle then toggle(ui) end
                end
            end
        end
        return
    end
    if not initialized then return end
    if contextEvents[event] then addon.Read(addon.InvalidateContext, "boolean") end
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
        local nav = addon.Clean(addon.Navigation, "table")
        local changed = nav and addon.Clean(nav.QuestChanged, "function")
        if changed then addon.Read(changed, "boolean", arg1) end
    end
    refresh(dataEvents[event] == true)
end)
