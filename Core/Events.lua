local name, addon = ...
local events = CreateFrame("Frame")
local initialized, pending, refreshing = false, false, false

local function probeNavigation()
    local navigation = addon.Clean(addon.Navigation, "table")
    local getter = navigation and addon.Clean(navigation.ProbeGeometry, "function")
    local report = addon.Read(getter, "table")
    if not report or addon.Clean(rawget(report, "status"), "string") ~= "known" then
        print("Dungeon Pro nav: snapshot unknown"); return
    end
    local frames = addon.Clean(rawget(report, "frames"), "table")
    local strata = { BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true,
        FULLSCREEN = true, FULLSCREEN_DIALOG = true, TOOLTIP = true }
    local lines = {}
    for _, key in ipairs({ "hud", "planner", "worldMap" }) do
        local row = frames and addon.Clean(rawget(frames, key), "table")
        local prefix = "Dungeon Pro nav/" .. key .. ": "
        local known = row and addon.Clean(rawget(row, "status"), "string") == "known"
        if not known then
            lines[#lines + 1] = prefix .. "unknown"
        else
            local function flag(field)
                local value = addon.Clean(rawget(row, field), "boolean")
                if value == nil then return "unknown" end
                return value and "true" or "false"
            end
            local function number(field, format)
                local value = addon.Clean(rawget(row, field), "number")
                if not value or value < -1000000 or value > 1000000 or
                    ((field == "width" or field == "height" or field == "level") and value < 0) or
                    (field == "level" and value % 1 ~= 0) or (field == "scale" and value <= 0) then return "unknown" end
                return string.format(format, value)
            end
            local layer = addon.Clean(rawget(row, "strata"), "string")
            layer = layer and strata[layer] and layer or "unknown"
            lines[#lines + 1] = prefix .. "shown=" .. flag("shown") .. " visible=" .. flag("visible") ..
                " strata=" .. layer .. " level=" .. number("level", "%.0f") .. " scale=" .. number("scale", "%.3f") ..
                " uiUnit=(" .. number("left", "%.2f") .. "," .. number("bottom", "%.2f") ..
                "," .. number("width", "%.2f") .. "," .. number("height", "%.2f") .. ")"
        end
        if key == "worldMap" then
            local mapID = known and addon.Clean(rawget(row, "shown"), "boolean") == true and
                addon.Clean(rawget(row, "displayedMapID"), "number")
            local displayed = "unknown"
            if mapID and mapID > 0 and mapID <= 9007199254740991 and mapID % 1 == 0 then displayed = string.format("%.0f", mapID) end
            lines[#lines] = lines[#lines] .. " mapID=" .. displayed
        end
    end
    for _, line in ipairs(lines) do print(line) end
end

local function probeMinimap()
    local ok, lines = pcall(function()
        local function object(value)
            return addon.Clean(value, "table") or addon.Clean(value, "userdata")
        end
        local manager, parent, checker = addon.Clean(addon.Minimap, "table"), object(Minimap), issecretvalue
        local button = manager and object(manager.button)
        local database = addon.Clean(addon.db, "table")
        local config = database and addon.Clean(database.minimap, "table")
        local hidden = config and addon.Clean(config.hide, "boolean")
        local rawButton = manager and rawget(manager, "button")
        local rawConfig = database and rawget(database, "minimap")
        local rawHidden = config and rawget(config, "hide")
        local function flag(value)
            if value == nil then return "unknown" end
            return value and "true" or "false"
        end
        local output = { "Dungeon Pro minimap: created=" .. flag(button ~= nil) .. " hide=" .. flag(hidden) }
        local strata = { BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true,
            FULLSCREEN = true, FULLSCREEN_DIALOG = true, TOOLTIP = true }
        local bindings = {}
        for _, role in ipairs({ { "button", button }, { "parent", parent } }) do
            local owner, getters, slots = role[2], {}, {}
            local function read(key, kind)
                if type(owner) == "table" then slots[key] = {value = rawget(owner, key)} end
                local getter = owner and addon.Read(function() return owner[key] end, "function")
                getters[key] = getter
                return addon.Read(getter, kind, owner)
            end
            local shown, visible = read("IsShown", "boolean"), read("IsVisible", "boolean")
            local layer = read("GetFrameStrata", "string")
            layer = layer and strata[layer] and layer or "unknown"
            local function number(key, minimum, maximum, integral)
                local value = read(key, "number")
                if not value or value < minimum or value > maximum or (integral and value % 1 ~= 0) then return "unknown" end
                return string.format(integral and "%.0f" or "%.2f", value)
            end
            output[#output + 1] = "Dungeon Pro minimap/" .. role[1] .. ": shown=" .. flag(shown) ..
                " visible=" .. flag(visible) .. " strata=" .. layer .. " level=" .. number("GetFrameLevel", 0, 100000, true) ..
                " alpha=" .. number("GetAlpha", 0, 1) .. " uiUnit=(" .. number("GetLeft", -1000000, 1000000) ..
                "," .. number("GetBottom", -1000000, 1000000) .. "," .. number("GetWidth", 0, 1000000) ..
                "," .. number("GetHeight", 0, 1000000) .. ")"
            bindings[#bindings + 1] = { owner = owner, getters = getters, slots = slots }
        end
        for _, binding in ipairs(bindings) do
            for key, getter in pairs(binding.getters) do
                if addon.Read(function() return binding.owner[key] end, "function") ~= getter then return end
            end
        end
        if addon.Minimap ~= manager or object(Minimap) ~= parent or issecretvalue ~= checker or
            (manager and object(manager.button) ~= button) or addon.db ~= database or
            (database and addon.Clean(database.minimap, "table") ~= config) or
            (config and addon.Clean(config.hide, "boolean") ~= hidden) then return end
        -- Final raw checks call no getters or restriction checks that could replace an earlier binding.
        if not rawequal(rawget(addon, "Minimap"), manager) or not rawequal(rawget(_G, "Minimap"), parent) or
            not rawequal(rawget(_G, "issecretvalue"), checker) or not rawequal(rawget(addon, "db"), database) or
            (manager and not rawequal(rawget(manager, "button"), rawButton)) or
            (database and not rawequal(rawget(database, "minimap"), rawConfig)) or
            (config and not rawequal(rawget(config, "hide"), rawHidden)) then return end
        for _, binding in ipairs(bindings) do
            for key, slot in pairs(binding.slots) do
                if not rawequal(rawget(binding.owner, key), slot.value) then return end
            end
        end
        return output
    end)
    if not ok or not lines then print("Dungeon Pro minimap: snapshot unknown"); return end
    for _, line in ipairs(lines) do print(line) end
end

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
            elseif msg == "probe nav" then probeNavigation()
            elseif msg == "probe minimap" then probeMinimap()
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
