local _, addon = ...
local UI = { dungeon = nil, quest = nil, search = "", range = false, preparation = false, includeUnavailable = false,
    detailHistory = {} }
addon.UI = UI
local COLOR = { COMPLETED = "66dd99", READY = "ffe066", ACTIVE = "88bfff", AVAILABLE = "ffe9b0",
    LOCKED = "f0b080", UNKNOWN = "b4aacd", UNAVAILABLE = "999999" }
local DEVELOPER_LINKS = {
    issue = { label = "REPORT_ISSUE", url = "https://github.com/Antrakt92/DungeonPro/issues" },
    support = { label = "SUPPORT_AUTHOR", url = "https://ko-fi.com/antrakt92" },
}

local FONT
local DETAIL_STYLES = {
    body = { size = 15, minimum = 20, color = { 0.92, 0.91, 0.87 } },
    title = { size = 22, minimum = 30, gap = 6, color = { 0.96, 0.83, 0.59 } },
    caption = { size = 13, minimum = 16, before = 4, gap = 3, color = { 0.64, 0.73, 0.74 } },
    story = { size = 14, minimum = 18, gap = 6, color = { 0.74, 0.77, 0.75 } },
    section = { size = 20, minimum = 26, before = 8, color = { 0.76, 0.86, 0.85 } },
}

local function styleRow(row, kind, selected)
    local theme = addon.Clean(addon.Theme, "table")
    if theme then addon.Read(theme.StyleRow, "boolean", row, { kind = kind, selected = selected == true }) end
    if row.compact and row.questCompleted and type(row.title.SetTextColor) == "function" then
        local ui, current = addon.UI, row.questListCurrent
        if ui and current and ui.QuestListWrite then ui:QuestListWrite(row.title, "SetTextColor", current, .52, .62, .55)
        else pcall(row.title.SetTextColor, row.title, .52, .62, .55) end
    end
end

function UI:CurrentDetailAction()
    local engine, action = self.engine, self.action
    if not engine or not action then return nil end
    local quest, dungeon, character, generation = self.quest, self.dungeon, addon.char, self.rewardGeneration
    local getter, place, id, kind = engine.Current, action.place, action.id, action.kind
    local fresh = getter == nil or addon.Read(getter, "boolean", engine) == true
    if fresh and self.engine == engine and self.action == action and self.quest == quest and self.dungeon == dungeon and
        addon.char == character and self.rewardGeneration == generation and engine.Current == getter and
        action.place == place and action.id == id and action.kind == kind then return action end
end

function UI:NavigationDestination(coordinates)
    local frame, quest, dungeon, engine, character, generation, giver = self.frame, self.quest, self.dungeon, self.engine,
        addon.char, self.rewardGeneration, self.giverAction
    local function current()
        return addon.UI == self and self.frame == frame and self.quest == quest and self.dungeon == dungeon and
            self.engine == engine and addon.char == character and self.rewardGeneration == generation and self.giverAction == giver
    end
    local function usable(action)
        local place = action and addon.Clean(action.place, "table")
        local map = place and addon.Clean(place.mapID, "number")
        if not map or map <= 0 or map % 1 ~= 0 then return false end
        if not coordinates then return true end
        local x, y = addon.Clean(place.x, "number"), addon.Clean(place.y, "number")
        return x ~= nil and y ~= nil and x >= 0 and x <= 100 and y >= 0 and y <= 100
    end
    local binding = self.giverBinding
    local fresh = not binding or addon.Read(binding.current, "boolean") == true
    if not current() or not fresh or self.giverBinding ~= binding then return end
    local available = usable(giver)
    if current() and available then return giver, true end
end

function UI:DispatchDetail(action, mapOnly, giver, ownerCurrent)
    if not action then return false end
    local frame, quest, dungeon, engine, character, generation = self.frame, self.quest, self.dungeon, self.engine, addon.char, self.rewardGeneration
    local navigation = addon.Clean(addon.Navigation, "table")
    local method = navigation and addon.Clean(navigation[mapOnly and "Map" or "Start"], "function")
    if not frame or not method then return false end
    local shown, getter = frame.IsShown, engine and engine.Current
    local place, id, kind = action.place, action.id, action.kind
    local coordinates, checker = self.giverHasCoordinates, issecretvalue
    local giverBinding = giver and self.giverBinding
    local slot = giver and "giverAction" or "action"
    local function current()
        local fresh = not getter or addon.Read(getter, "boolean", engine) == true
        local owned = ownerCurrent == nil or addon.Read(ownerCurrent, "boolean") == true
        local giverFresh = not giverBinding or addon.Read(giverBinding.current, "boolean") == true
        return fresh and owned and giverFresh and (not giver or self.giverBinding == giverBinding) and addon.UI == self and self.frame == frame and self.quest == quest and self.dungeon == dungeon and
            self.engine == engine and addon.char == character and self.rewardGeneration == generation and
            addon.Navigation == navigation and navigation[mapOnly and "Map" or "Start"] == method and
            frame.IsShown == shown and (not engine or engine.Current == getter) and
            (ownerCurrent ~= nil or self[slot] == action) and action.place == place and action.id == id and action.kind == kind and
            (not giver or self.giverHasCoordinates == coordinates) and issecretvalue == checker
    end
    if not current() or addon.Read(shown, "boolean", frame) ~= true or not current() then return false end
    return pcall(method, mapOnly and place or action)
end

function UI:GetEntranceBinding(dungeon, ownerCurrent)
    local provider = addon.Clean(addon.Entrances, "table")
    local getter = provider and addon.Clean(provider.Get, "function")
    local navigation = addon.Clean(addon.Navigation, "table")
    local start = navigation and addon.Clean(navigation.StartEntrance, "function")
    local function owned()
        return addon.UI == self and ownerCurrent() and addon.Entrances == provider and
            provider and provider.Get == getter and addon.Navigation == navigation and navigation and navigation.StartEntrance == start
    end
    if not dungeon or not getter or not start or not owned() then return end
    local ok, point, predicate = pcall(getter, dungeon)
    point, predicate = ok and addon.Clean(point, "table"), ok and addon.Clean(predicate, "function")
    if not owned() or not point or not predicate then return end
    local map, x, y = addon.Clean(point.mapID, "number"), addon.Clean(point.x, "number"), addon.Clean(point.y, "number")
    if not owned() or not map or map <= 0 or map % 1 ~= 0 or not x or not y or x < 0 or x > 100 or y < 0 or y > 100 then return end
    local function current()
        local valid = addon.Read(predicate, "boolean") == true
        if not valid or not owned() then return false end
        return addon.Clean(point.mapID, "number") == map and addon.Clean(point.x, "number") == x and addon.Clean(point.y, "number") == y
    end
    if current() then return { current = current, dungeon = dungeon, point = point, navigation = navigation, start = start } end
end

function UI:RefreshEntrance()
    local frame, dungeon, quest, character, generation = self.frame, self.dungeon, self.quest, addon.char, self.rewardGeneration
    self.entranceBinding = nil
    local function current()
        return addon.UI == self and self.frame == frame and self.dungeon == dungeon and self.quest == quest and
            addon.char == character and self.rewardGeneration == generation
    end
    local binding = self:GetEntranceBinding(dungeon, current)
    if current() then self.entranceBinding = binding end
    return binding ~= nil
end

function UI:CatalogEntranceHint(row)
    self:HideNavigationHint()
    local control, binding, owner = row.entranceControl, row.entranceBinding, row.entranceCurrent
    local tip = addon.Clean(GameTooltip, "table") or addon.Clean(GameTooltip, "userdata")
    local function current()
        return tip and GameTooltip == tip and row.entranceCurrent == owner and owner and owner() and
            row.entranceBinding == binding and addon.Read(row.IsShown, "boolean", row) == true and addon.Read(self.frame.IsShown, "boolean", self.frame) == true
    end
    if not current() then return end
    local text = addon.Read(addon.DungeonName, "string", row.entranceDungeon)
    if not current() or not text then return end
    local point = binding and binding.current() and binding.point
    if not current() then return end
    if point then
        local zone = addon.Clean(point.zoneName, "string") or addon.Clean(point.name, "string")
        if zone then text = text .. "\n" .. zone end
        local x, y = addon.Clean(point.x, "number"), addon.Clean(point.y, "number")
        if not x or not y or x < 0 or x > 100 or y < 0 or y > 100 or not binding.current() or not current() then return end
        text = text .. string.format(" (%.1f, %.1f)", x, y)
        if addon.Clean(point.origin, "string") == "recorded" then
            text = text .. "\n" .. addon.L("DUNGEON_ENTRANCE_RECORDED")
            local source = addon.Clean(point.source, "string")
            if source and #source <= 2048 and source:match("^https://") then text = text .. "\n" .. source end
        end
        if addon.Clean(point.kind, "string") == "approach" then text = text .. "\n" .. addon.L("DUNGEON_ENTRANCE_APPROACH") end
        if addon.Clean(point.scope, "string") == "shared" then text = text .. "\n" .. addon.L("DUNGEON_ENTRANCE_SHARED") end
    else text = text .. "\n" .. addon.L("DUNGEON_ENTRANCE_UNKNOWN") end
    if not current() then return end
    local held = { tip = tip, button = control }; self.navigationTooltip = held
    for _, call in ipairs({ { "SetOwner", control, "ANCHOR_RIGHT" }, { "SetText", addon.L("DUNGEON_ENTRANCE") },
        { "AddLine", text, 1, 1, 1, true }, { "Show" } }) do
        if not current() or self.navigationTooltip ~= held then return end
        local fn = addon.Clean(tip[call[1]], "function")
        if not fn or not pcall(fn, tip, unpack(call, 2)) then
            if self.navigationTooltip == held then self:HideNavigationHint() end
            return
        end
        if not current() or self.navigationTooltip ~= held or addon.Read(tip.IsOwned, "boolean", tip, control) ~= true or
            not current() or self.navigationTooltip ~= held then
            if self.navigationTooltip == held then self:HideNavigationHint() end
            return
        end
    end
end

function UI:VisitEntrance()
    local binding, frame = self.entranceBinding, self.frame
    if not binding or not frame or not binding.current() then return false end
    local shown = addon.Read(frame.IsShown, "boolean", frame)
    if shown ~= true or self.entranceBinding ~= binding or self.frame ~= frame or not binding.current() then return false end
    return pcall(binding.start, binding.dungeon, binding.point)
end

function UI:HideNavigationHint()
    local held = self.navigationTooltip
    self.navigationTooltip = nil
    if held and GameTooltip == held.tip and addon.Read(held.tip.IsOwned, "boolean", held.tip, held.button) == true then
        pcall(held.tip.Hide, held.tip)
    end
end

function UI:CatalogStatusHint(row)
    self:HideNavigationHint()
    local frame, dto, owned, result = self.frame, row.dungeonStatusDTO, row.dungeonStatusCurrent, row.catalogResult
    local control = row.dungeonStatusControl
    local tip = addon.Clean(GameTooltip, "table") or addon.Clean(GameTooltip, "userdata")
    local isOwned = tip and addon.Clean(tip.IsOwned, "function")
    local function current()
        local shown = addon.Read(frame.IsShown, "boolean", frame)
        return shown == true and addon.Read(row.IsShown, "boolean", row) == true and addon.UI == self and self.frame == frame and row.catalogResult == result and row.dungeonStatusDTO == dto and
            row.dungeonStatusCurrent == owned and owned and owned() and GameTooltip == tip and tip.IsOwned == isOwned
    end
    if not tip or not isOwned or not dto or not current() then return end
    local status = addon.Clean(dto.status, "string")
    local allowed = { READY=true, AVAILABLE=true, ACTIVE=true, UNKNOWN=true, LOCKED=true, COMPLETED=true, UNAVAILABLE=true }
    if not status or not allowed[status] or not current() then return end
    local name = addon.Read(addon.DungeonName, "string", row.entranceDungeon)
    if not name or not current() then return end
    local reason = addon.Clean(dto.reason, "string")
    local listed = addon.Clean(dto.listed, "number")
    local statusKey = reason == "level" and "DUNGEON_STATUS_LEVEL" or
        (listed == 0 and "DUNGEON_STATUS_EMPTY" or ("DUNGEON_STATUS_" .. status))
    local minimum = result and addon.Clean(result.minimum, "number")
    local maximum = result and addon.Clean(result.maximum, "number")
    local count = result and addon.Clean(result.count, "number")
    if not minimum or not maximum or not count or not current() then return end
    local held = { tip=tip, button=control }; self.navigationTooltip=held
    for _, call in ipairs({ { "SetOwner", control, "ANCHOR_RIGHT" }, { "SetText", name .. " — " .. addon.L("DUNGEON_STATUS") },
        { "AddLine", addon.L(statusKey), 1, 1, 1, true },
        { "AddLine", addon.L("CATALOG_LEVELS", minimum, maximum) .. " · " .. addon.L("CATALOG_QUESTS", count), .8, .8, .8, true },
        { "AddLine", addon.L("DUNGEON_STATUS_SCOPE"), .7, .7, .7, true }, { "Show" } }) do
        if not current() or self.navigationTooltip ~= held then return end
        local method = addon.Clean(tip[call[1]], "function")
        if not method or not pcall(method, tip, unpack(call, 2)) or not current() or self.navigationTooltip ~= held or
            addon.Read(isOwned, "boolean", tip, control) ~= true or not current() or self.navigationTooltip ~= held then
            if self.navigationTooltip == held then self:HideNavigationHint() end
            return
        end
    end
end

function UI:QuestListHint(row)
    self:HideNavigationHint()
    local owner, frame = row.questListCurrent, self.frame
    local tip = addon.Clean(GameTooltip, "table") or addon.Clean(GameTooltip, "userdata")
    local function current()
        return tip and row.questListCurrent == owner and owner and owner() and self.frame == frame and
            GameTooltip == tip and addon.Read(frame.IsShown, "boolean", frame) == true and owner()
    end
    if not current() then return end
    local title = addon.Read(row.title.GetText, "string", row.title)
    local note = addon.Read(row.note.GetText, "string", row.note)
    if not current() or not title or not note then return end
    if row.dungeonTarget then
        local dungeonName = addon.Clean(row.dungeonName, "string")
        if not current() or not dungeonName then return end
        note = note .. "\n" .. dungeonName .. " — " .. addon.L("QUESTS")
    end
    if row.chainExpandable then note = note .. "\n" .. addon.L(row.chainExpanded and "CHAIN_COLLAPSE" or "CHAIN_EXPAND") end
    local branchControl = row.branchControl
    if branchControl and addon.Read(branchControl.IsShown, "boolean", branchControl) == true then
        note = note .. "\n" .. addon.L("BRANCH_GROUP", branchControl.branchGroup) .. "\n" ..
            addon.L(branchControl.branchSelected and "BRANCH_RESET" or "BRANCH_PREFER")
    end
    if not current() then return end
    local held = { tip = tip, button = row }; self.navigationTooltip = held
    for _, call in ipairs({ { "SetOwner", row, "ANCHOR_RIGHT" }, { "SetText", title }, { "AddLine", note, 1, 1, 1, true }, { "Show" } }) do
        if not current() or self.navigationTooltip ~= held then return end
        local fn = addon.Clean(tip[call[1]], "function")
        if not fn or not pcall(fn, tip, unpack(call, 2)) or not current() or self.navigationTooltip ~= held then
            if self.navigationTooltip == held then self:HideNavigationHint() end
            return
        end
    end
end

function UI:RefreshFooterIcon(control)
    local icon = control.footerIcon
    if not icon then return end
    local enabled = control.footerEnabled == true
    local alpha = enabled and (control.footerPressed and .65 or control.footerHovered and 1 or .88) or .3
    if type(icon.SetAlpha) == "function" then pcall(icon.SetAlpha, icon, alpha) end
    if type(icon.SetDesaturated) == "function" then pcall(icon.SetDesaturated, icon, not enabled) end
end

function UI:SetFooterEnabled(control, enabled)
    control.footerEnabled = enabled == true
    if not control.footerEnabled then control.footerPressed, control.footerHovered = false, false end
    control:SetEnabled(enabled == true)
    self:RefreshFooterIcon(control)
end

function UI:SetFooterLabel(control, key)
    control.footerLabelKey = key
    control:SetText("")
end

local LANGUAGE_CHOICES = { { "auto" }, { "enUS", "English" }, { "ruRU", "Русский" }, { "deDE", "Deutsch" },
        { "frFR", "Français" }, { "esES", "Español" }, { "itIT", "Italiano" }, { "ptBR", "Português" },
        { "koKR", "한국어" }, { "zhCN", "简体中文" }, { "zhTW", "繁體中文" } }

function UI:RefreshLanguageLabel()
    local language = addon.Clean(addon.Language, "table")
    if language and type(language.Refresh) == "function" then return addon.Read(language.Refresh, "boolean", language, self) == true end
    local database, owner, frame, checker = addon.Clean(addon.db, "table"), self.language, self.frame, issecretvalue
    if not database or not owner then return false end
    local locale, localize = addon.Clean(rawget(database, "locale"), "string"), addon.Clean(addon.L, "function")
    if not locale or not localize then return false end
    local revision = {}
    self.languageLabelRevision = revision
    local code = locale == "enGB" and "enUS" or locale == "esMX" and "esES" or locale
    local name = "English"
    if code == "auto" then
        name = addon.Read(localize, "string", "LANGUAGE_AUTO_SHORT")
        if not name or not name:find("%S") then name = "Auto" end
    else
        for _, choice in ipairs(LANGUAGE_CHOICES) do if choice[1] == code then name = choice[2]; break end end
    end
    local function current()
        local ok, value = pcall(function()
            return self.languageLabelRevision == revision and self.language == owner and self.frame == frame and
                addon.db == database and rawget(database, "locale") == locale and addon.L == localize and issecretvalue == checker
        end)
        return ok and value == true
    end
    if not current() then return false end
    local binding = { current = current, value = name }
    owner.languageLabelText = binding
    owner:SetText(name)
    if current() then return true end
    local newer = owner.languageLabelText
    if newer ~= binding and newer and newer.current() and not owner.languageLabelRepair then
        owner.languageLabelRepair = true
        if owner.languageLabelText == newer and newer.current() then pcall(owner.SetText, owner, newer.value) end
        owner.languageLabelRepair = nil
    end
    return false
end

function UI:OpenLanguageMenu()
    local language = addon.Clean(addon.Language, "table")
    if language and type(language.Open) == "function" then return addon.Read(language.Open, "boolean", language, self) == true end
    local choices = LANGUAGE_CHOICES
    local database, owner, checker = addon.Clean(addon.db, "table"), self.language, issecretvalue
    if not database then return false end
    local previous = addon.Clean(database.locale, "string")
    local checkedCode = previous == "enGB" and "enUS" or previous == "esMX" and "esES" or previous
    local supported = false
    for _, choice in ipairs(choices) do if choice[1] == checkedCode then supported = true; break end end
    if not supported then checkedCode = "enUS" end
    local revision = {}
    self.languageMenuRevision = revision
    local function current()
        local shown = addon.Read(self.frame.IsShown, "boolean", self.frame)
        return shown == true and self.languageMenuRevision == revision and addon.Clean(addon.db, "table") == database and
            self.language == owner and issecretvalue == checker and addon.Clean(database.locale, "string") == previous
    end
    local function cycle()
        if not current() then return false end
        local index = 1
        for i, choice in ipairs(choices) do if previous == choice[1] then index = i end end
        database.locale = choices[index % #choices + 1][1]
        self:Refresh()
        return false
    end
    local library = addon.Clean(MenuUtil, "table")
    local create = library and addon.Clean(library.CreateContextMenu, "function")
    if not create then return cycle() end
    local selected = false
    local function capable()
        return current() and addon.Clean(MenuUtil, "table") == library and
            addon.Clean(library.CreateContextMenu, "function") == create
    end
    local ok, menu = pcall(create, owner, function(menuOwner, root)
        if not capable() or menuOwner ~= owner then error("Language menu context changed") end
        root = addon.Clean(root, "table") or addon.Clean(root, "userdata")
        local radio = root and addon.Clean(root.CreateRadio, "function")
        if not radio then error("Language menu choices unavailable") end
        for _, choice in ipairs(choices) do
            local code = choice[1]
            local name = choice[2] or addon.L("LANGUAGE_AUTO")
            radio(root, name, function() return capable() and checkedCode == code end, function()
                if not capable() then return end
                selected = true
                database.locale = code
                self:Refresh()
            end, code)
            if not capable() and not selected then error("Language menu context changed") end
        end
    end)
    if selected then return true end
    if ok and (addon.Clean(menu, "table") or addon.Clean(menu, "userdata")) and capable() then return true end
    return cycle()
end

function UI:RefreshFilterControls()
    local frame, database, character, range, all, localize = self.frame, addon.db, addon.char, self.range, self.includeUnavailable, addon.L
    local locale = database and rawget(database, "locale")
    local revision = {}; self.filterGeneration = revision
    local controls = { self.rangeButton, self.characterButton }
    local function current()
        return addon.UI == self and self.filterGeneration == revision and self.frame == frame and addon.db == database and
            addon.char == character and self.range == range and self.includeUnavailable == all and addon.L == localize and
            (not database or rawget(database, "locale") == locale) and self.rangeButton == controls[1] and self.characterButton == controls[2]
    end
    local function write(object, method, ...) return self:QuestListWrite(object, method, current, ...) end
    self.rangeButton.filterLabelKey = range and "RANGE" or "ALL"
    self.rangeButton.filterTargetKey = range and "ALL" or "RANGE"
    self.rangeButton.filterCaptionKey = range and "FILTER_LEVEL_CURRENT" or "FILTER_LEVEL_ALL"
    self.rangeButton.filterSelected = range
    self.characterButton.filterLabelKey = all and "ALL_CHARACTERS" or "MY_CHARACTER"
    self.characterButton.filterTargetKey = all and "MY_CHARACTER" or "ALL_CHARACTERS"
    self.characterButton.filterCaptionKey = all and "FILTER_QUEST_ALL" or "FILTER_QUEST_MINE"
    self.characterButton.filterSelected = not all
    local theme = addon.Clean(addon.Theme, "table")
    for _, control in ipairs(controls) do
        local caption = addon.Read(localize, "string", control.filterCaptionKey)
        if not current() or not caption then return end
        if theme and addon.Clean(theme.StyleFilter, "function") then addon.Read(theme.StyleFilter, "boolean", control, control.filterSelected)
        else styleRow(control, "control", control.filterSelected) end
        if not current() then return end
        if control.filterCaption then
            local font = theme and addon.Clean(theme.ApplyFont, "function")
            if font then pcall(font, control.filterCaption, 13) end
            if not current() or not write(control.filterCaption, "SetText", caption) then return end
        else
            if theme then addon.Read(theme.StyleButtonFonts, "boolean", control) end
            if not current() or not write(control, "SetText", caption) then return end
        end
    end
    local control = controls[2]
    if not write(control.filterIcon, "SetShown", not all) then return end
    for _, strip in ipairs(control.filterList) do if not write(strip, "SetShown", all) then return end end
end

function UI:ApplyTheme()
    local theme = addon.Clean(addon.Theme, "table")
    if theme then addon.Read(theme.Apply, "boolean", self) end
    self:RefreshFilterControls()
end

function UI:RefreshQuestStyles()
    for _, row in ipairs(self.rows or {}) do
        if row:IsShown() then styleRow(row, row.heading and "section" or "quest", row.questID ~= nil and row.questID == self.quest and not row.heading) end
    end
end

local function statusLabel(state, value)
    local label = value or addon.L(state.status == "UNKNOWN" and state.reason == "requirements" and
        "UNKNOWN_REQUIREMENTS" or state.status)
    if (state.status == "ACTIVE" or state.status == "READY") and
        addon.Clean(state.completedHistory, "boolean") == true then
        label = label .. " — " .. addon.L("COMPLETED_BEFORE")
    end
    return label
end

local AUDIENCE_ICONS = {
    factions = { Alliance = "UI-HUD-UnitFrame-Player-PVP-AllianceIcon", Horde = "UI-HUD-UnitFrame-Player-PVP-HordeIcon" },
    classes = { WARRIOR = "warrior", MAGE = "mage", ROGUE = "rogue", DRUID = "druid", HUNTER = "hunter",
        SHAMAN = "shaman", PRIEST = "priest", WARLOCK = "warlock", PALADIN = "paladin", DEATHKNIGHT = "deathknight",
        MONK = "monk", DEMONHUNTER = "demonhunter", EVOKER = "evoker" },
}
local function audienceName(group, value, name)
    local icons = AUDIENCE_ICONS[group]
    local icon = icons and icons[value]
    if not icon then return name end
    if group == "classes" then icon = "classicon-" .. icon end
    return "|A:" .. icon .. ":14:14|a " .. name
end

local function audienceLabel(q, current)
    q = addon.Clean(q, "table")
    if not q then return nil end
    local groups = {}
    for _, rule in ipairs({ { "factions", "string" }, { "classes", "string", addon.ClassName } }) do
        local entries = addon.Clean(q[rule[1]], "table")
        local names, seen = {}, {}
        for index = 1, math.min(entries and #entries or 0, 100) do
            local value = addon.Clean(entries[index], rule[2])
            local valid = rule[1] == "factions" and (value == "Alliance" or value == "Horde" or value == "Neutral") or
                rule[1] == "classes" and value and #value <= 100 and value:match("^[A-Z]+$")
            if valid and not seen[value] then
                seen[value] = true
                local name
                if rule[1] == "factions" then name = addon.L("FACTION_" .. value)
                else
                    name = addon.Read(rule[3], "string", value)
                    if not current() then return false end
                    if not name or #name > 500 or not name:find("%S") then
                        name = value
                    end
                end
                names[#names + 1] = audienceName(rule[1], value, name)
            end
        end
        if #names > 0 then groups[#groups + 1] = table.concat(names, ", ") end
    end
    if #groups > 0 then return table.concat(groups, " · ") end
end

local function giverName(place)
    place = addon.Clean(place, "table")
    if not place then return addon.L("UNKNOWN_PLACE") end
    local npcID = addon.Clean(place.npcID, "number")
    if npcID and npcID > 0 and npcID % 1 == 0 and not place.itemID and not place.objectID then
        local current = addon.Read(addon.GiverName, "string", place)
        if current and current ~= "" and #current <= 1024 then return current end
    end
    local name = addon.Clean(place.name, "string")
    return name and name ~= "" and name or addon.L("UNKNOWN_PLACE")
end

local function reportedPlaces(parent)
    parent = addon.Clean(parent, "table")
    local locations = parent and addon.Clean(parent.reportedLocations, "table")
    if not locations or #locations < 2 or #locations > 100 then return nil end
    local count, last = 0, 0
    for key in next, locations do
        count = count + 1
        key = addon.Clean(key, "number")
        if count > 100 or not key or key < 1 or key > 100 or key % 1 ~= 0 then return nil end
        if key > last then last = key end
    end
    if last ~= count then return nil end
    local npcID, objectID = addon.Clean(parent.npcID, "number"), addon.Clean(parent.objectID, "number")
    if npcID and (npcID <= 0 or npcID % 1 ~= 0) then npcID = nil end
    if objectID and (objectID <= 0 or objectID % 1 ~= 0) then objectID = nil end
    if not npcID and not objectID then return nil end
    local result = {}
    for i = 1, #locations do
        local report = addon.Clean(locations[i], "table")
        if not report then return nil end
        local mapID = addon.Clean(report.mapID, "number")
        local x, y = addon.Clean(report.x, "number"), addon.Clean(report.y, "number")
        if not mapID or mapID <= 0 or mapID % 1 ~= 0 or not x or not y or
            x < 0 or x > 100 or y < 0 or y > 100 then return nil end
        result[i] = { npcID = npcID, objectID = objectID, name = addon.Clean(parent.name, "string"),
            mapID = mapID, x = x, y = y, zoneName = addon.Clean(report.zoneName, "string") or
                (addon.Clean(parent.mapID, "number") == mapID and addon.Clean(parent.zoneName, "string") or nil) }
    end
    return result
end

local function searchText(value)
    if type(addon.SearchFold) == "function" then return addon.SearchFold(value) or value end
    return value:gsub("[A-Z]", function(letter) return string.char(letter:byte() + 32) end)
end

local function measuredHeight(fs, fallback)
    local value = addon.Read(fs.GetStringHeight, "number", fs)
    if value and value > 0 then fs.measuredHeight = value; return value end
    return fs.measuredHeight or fallback
end

local function setFont(fs, size)
    local theme = addon.Clean(addon.Theme, "table")
    if theme and addon.Clean(theme.ApplyFont, "function") then
        local ok, font = pcall(theme.ApplyFont, fs, size)
        font = ok and (addon.Clean(font, "table") or addon.Clean(font, "userdata") or addon.Clean(font, "string"))
        if font then return font end
    end
    fs:SetFont(FONT, size, "")
    return FONT
end

local function setInputFont(box)
    local theme = addon.Clean(addon.Theme, "table")
    if theme and addon.Clean(theme.ApplyInputFont, "function") then pcall(theme.ApplyInputFont, box) end
end

local function text(parent, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    setFont(fs, size or 14)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(unpack(color or { 0.92, 0.91, 0.87 }))
    return fs
end

local function button(parent, label, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 25)
    b:SetText(label)
    b:SetScript("OnClick", callback)
    return b
end

local function scrolling(parent, x, y, width, height)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll.scrollBarHideable = true
    if scroll.ScrollBar then scroll.ScrollBar:Hide() end
    scroll:SetPoint("TOPLEFT", x, y)
    scroll:SetSize(width, height)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(width - 4, 1)
    scroll:SetScrollChild(child)
    return child, scroll
end

local function label(parent, value, x, y, width, size)
    local fs = text(parent, size)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetText(value)
    return fs
end

function UI:DeveloperLinkHint(control, key)
    key = addon.Clean(key, "string")
    self:HideNavigationHint()
    local link, frame = DEVELOPER_LINKS[key], self.frame
    local tip = addon.Clean(GameTooltip, "table") or addon.Clean(GameTooltip, "userdata")
    local isOwned = tip and addon.Clean(tip.IsOwned, "function")
    local function current()
        local shown = addon.Read(frame.IsShown, "boolean", frame)
        return shown == true and link and GameTooltip == tip and self.frame == frame and tip.IsOwned == isOwned
    end
    if not tip or not isOwned or not current() then return end
    local held = { tip = tip, button = control }; self.navigationTooltip = held
    for _, call in ipairs({ { "SetOwner", control, "ANCHOR_RIGHT" }, { "SetText", addon.L(link.label) }, { "AddLine", link.url, 1, 1, 1, true }, { "Show" } }) do
        if not current() or self.navigationTooltip ~= held then return end
        local method = addon.Clean(tip[call[1]], "function")
        if not method or not pcall(method, tip, unpack(call, 2)) or not current() or self.navigationTooltip ~= held or
            addon.Read(isOwned, "boolean", tip, control) ~= true or not current() or self.navigationTooltip ~= held then
            if self.navigationTooltip == held then self:HideNavigationHint() end
            return
        end
    end
end

function UI:FilterHint(control)
    self:HideNavigationHint()
    local frame, database, range, unavailable = self.frame, addon.db, self.range, self.includeUnavailable
    local locale = database and database.locale
    local tip = addon.Clean(GameTooltip, "table") or addon.Clean(GameTooltip, "userdata")
    local owned = tip and addon.Clean(tip.IsOwned, "function")
    local function current()
        local shown = addon.Read(frame.IsShown, "boolean", frame)
        return shown == true and addon.UI == self and self.frame == frame and addon.db == database and
            (not database or database.locale == locale) and self.range == range and self.includeUnavailable == unavailable and
            (control == self.rangeButton or control == self.characterButton) and GameTooltip == tip and tip.IsOwned == owned
    end
    if not tip or not owned or not current() then return end
    local held = { tip = tip, button = control }; self.navigationTooltip = held
    for _, call in ipairs({ { "SetOwner", control, "ANCHOR_RIGHT" }, { "SetText", addon.L(control.filterHeadingKey) },
        { "AddLine", addon.L(control.filterLabelKey), 1, 1, 1, true },
        { "AddLine", addon.L("FILTER_SWITCH", addon.L(control.filterTargetKey)), .8, .8, .8, true }, { "Show" } }) do
        if not current() or self.navigationTooltip ~= held then return end
        local method = addon.Clean(tip[call[1]], "function")
        if not method or not pcall(method, tip, unpack(call, 2)) or not current() or self.navigationTooltip ~= held or
            addon.Read(owned, "boolean", tip, control) ~= true or not current() or self.navigationTooltip ~= held then
            if self.navigationTooltip == held then self:HideNavigationHint() end
            return
        end
    end
end

function UI:ShowDeveloperLink(key)
    key = addon.Clean(key, "string")
    local link, frame = DEVELOPER_LINKS[key], self.frame
    local dialogs = addon.Clean(StaticPopupDialogs, "table")
    local show, hide = addon.Clean(StaticPopup_Show, "function"), addon.Clean(StaticPopup_Hide, "function")
    if not link or not frame or not dialogs or not show or not hide or addon.Read(frame.IsShown, "boolean", frame) ~= true then return false end
    local popupKey, request = "DUNGEONPRO_COPY_DEVELOPER_LINK", { link = link }
    self.developerLinkRequest = request
    local function current()
        local shown = addon.Read(frame.IsShown, "boolean", frame)
        return shown == true and addon.UI == self and self.frame == frame and self.developerLinkRequest == request and
            StaticPopupDialogs == dialogs and StaticPopup_Show == show and StaticPopup_Hide == hide and DEVELOPER_LINKS[key] == link
    end
    request.current = current
    local function onShow(popup, data)
        if data ~= request or not current() then return end
        local ok, value = pcall(function() return popup:GetEditBox() end)
        local box = ok and (addon.Clean(value, "table") or addon.Clean(value, "userdata"))
        if not box or not current() then return end
        for _, call in ipairs({ { "SetText", link.url }, { "HighlightText" }, { "SetFocus" } }) do
            local method = addon.Clean(box[call[1]], "function")
            if not method or not current() then return end
            local bindings = self.developerLinkWrites or {}; self.developerLinkWrites = bindings
            local binding = { current = current, object = box, method = method, args = call }
            bindings[call[1]] = binding
            local written = pcall(method, box, unpack(call, 2))
            if not written or not current() then
                local newer = bindings[call[1]]
                if newer and newer ~= binding and not newer.repairing and newer.current() then
                    newer.repairing = true
                    if bindings[call[1]] == newer and newer.current() then pcall(newer.method, newer.object, unpack(newer.args, 2)) end
                    newer.repairing = nil
                end
                return
            end
        end
    end
    local function close(box)
        if not current() then return end
        local getter = addon.Clean(box.GetParent, "function")
        if not getter then return end
        local ok, popup = pcall(getter, box)
        if ok and popup and current() then self.developerLinkRequest = nil; pcall(popup.Hide, popup) end
    end
    dialogs[popupKey] = { text = "%s", button1 = addon.L("CLOSE"), hasEditBox = true, editBoxWidth = 340,
        OnShow = onShow, EditBoxOnEnterPressed = close, EditBoxOnEscapePressed = close,
        timeout = 0, whileDead = true, hideOnEscape = true, exclusive = true, preferredIndex = 3 }
    if not current() then return false end
    pcall(hide, popupKey)
    if not current() then return false end
    local ok, popup = pcall(show, popupKey, addon.L(link.label) .. "\n" .. addon.L("COPY"), nil, request)
    return ok and current() and (addon.Clean(popup, "table") ~= nil or addon.Clean(popup, "userdata") ~= nil)
end

function UI:CloseCopyLink()
    self.copyRevision = {}
    self.copyQuest, self.copyReturn = nil, nil
    if self.copy then self.copy:SetText(""); self.copy:Hide(); self.copy:ClearFocus() end
    if self.copyHint then self.copyHint:SetText(""); self.copyHint:Hide() end
end

function UI:EscapeCopyLink()
    local saved = self.copyReturn
    self:CloseCopyLink()
    local revision = self.copyRevision
    self:RefreshDetail()
    if self.copyRevision ~= revision or not saved or self.quest ~= saved.quest or self.copyQuest ~= nil or
        addon.Read(self.frame.IsShown, "boolean", self.frame) ~= true then return end
    local generation, scroll, checker = self.rewardGeneration, self.detailScroll, issecretvalue
    local content = addon.Read(self.detail.GetHeight, "number", self.detail)
    local viewport = addon.Read(scroll.GetHeight, "number", scroll)
    if self.copyRevision ~= revision or self.rewardGeneration ~= generation or self.quest ~= saved.quest or self.copyQuest ~= nil or issecretvalue ~= checker then return end
    if content and viewport and content >= 0 and viewport > 0 then
        scroll:SetVerticalScroll(math.min(saved.offset, math.max(0, content - viewport)))
    end
end

function UI:CopyLink(id)
    id = addon.Clean(id, "number")
    if not id or id < 1 or id % 1 ~= 0 or id ~= self.quest or
        addon.Read(self.frame.IsShown, "boolean", self.frame) ~= true then return false end
    if self.copyQuest ~= id then
        local scroll, generation, checker = self.detailScroll, self.rewardGeneration, issecretvalue
        local getter = scroll.GetVerticalScroll
        local offset = addon.Read(getter, "number", scroll)
        if self.quest ~= id or self.rewardGeneration ~= generation or self.detailScroll ~= scroll or scroll.GetVerticalScroll ~= getter or issecretvalue ~= checker then return false end
        self.copyReturn = offset and offset >= 0 and { quest = id, offset = offset } or nil
    end
    if not self.copy then
        local box = CreateFrame("EditBox", nil, self.detail, "InputBoxTemplate")
        box:SetSize(326, 26)
        setInputFont(box)
        box:SetAutoFocus(false)
        box:SetScript("OnEscapePressed", function() self:EscapeCopyLink() end)
        self.copy, self.copyHint = box, label(box, "", 0, -34, 326, 13)
    end
    self.copyQuest = id
    self.copy:SetText("https://www.wowhead.com/forever/quest=" .. id)
    self:RefreshDetail()
    local frame, box, detail, scroll = self.frame, self.copy, self.detail, self.detailScroll
    local dungeon, engine, character = self.dungeon, self.engine, addon.char
    local revision, generation, checker = self.copyRevision, self.rewardGeneration, issecretvalue
    local shown, contentGetter, viewportGetter = box.IsShown, detail.GetHeight, scroll.GetHeight
    local scrollSetter, focus, highlight = scroll.SetVerticalScroll, box.SetFocus, box.HighlightText
    local function current()
        return addon.UI == self and self.frame == frame and self.copy == box and self.detail == detail and
            self.detailScroll == scroll and self.quest == id and self.copyQuest == id and self.dungeon == dungeon and
            self.engine == engine and addon.char == character and self.copyRevision == revision and
            self.rewardGeneration == generation and issecretvalue == checker and box.IsShown == shown and
            detail.GetHeight == contentGetter and scroll.GetHeight == viewportGetter and
            scroll.SetVerticalScroll == scrollSetter and box.SetFocus == focus and box.HighlightText == highlight
    end
    if not current() or addon.Read(shown, "boolean", box) ~= true or not current() then return false end
    local content = addon.Read(contentGetter, "number", detail)
    if not current() then return false end
    local viewport = addon.Read(viewportGetter, "number", scroll)
    if not current() then return false end
    if content and viewport and content >= 0 and viewport > 0 then
        if not pcall(scrollSetter, scroll, math.max(0, content - viewport)) or not current() then return false end
    end
    if not pcall(focus, box) or not current() then return false end
    return pcall(highlight, box) and current()
end

function UI:QuestListWrite(object, method, ownerCurrent, ...)
    if not ownerCurrent() then return false end
    local bindings = object.questListWrites or {}; object.questListWrites = bindings
    local key = (method == "Show" or method == "Hide" or method == "SetShown") and "visibility" or
        (method == "SetScript" and "script:" .. tostring((...)) or method)
    local binding = { current = ownerCurrent, setter = object[method], args = { ... }, count = select("#", ...) }
    bindings[key] = binding
    local ok = pcall(binding.setter, object, ...)
    local fresh = ownerCurrent()
    if not fresh then
        local newer = bindings[key]
        if newer and newer ~= binding and not newer.repairing and newer.current() then
            newer.repairing = true
            if bindings[key] == newer and newer.current() then pcall(newer.setter, object, unpack(newer.args, 1, newer.count)) end
            newer.repairing = nil
        end
    end
    return ok and fresh
end

function UI:MakeRow(parent, pool, index, height, ownerCurrent, staged)
    local row = pool[index]
    if not row then
        row = CreateFrame("Button", nil, parent)
        row:SetSize(parent:GetWidth() - 4, height)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.13, 0.16, 0.20, 1)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.title = label(row, "", 8, -7, parent:GetWidth() - 22, 17)
        row.note = label(row, "", 8, -29, parent:GetWidth() - 22, 14)
        pool[index] = row
    end
    if ownerCurrent then self:QuestListWrite(row, staged and "Hide" or "Show", ownerCurrent) else row:Show() end
    styleRow(row, "quest", false)
    return row
end

function UI:LayoutRow(row, minimum, offset, ownerCurrent, ownerWrite)
    local function current() return not ownerCurrent or ownerCurrent() end
    local function write(object, method, ...)
        if not current() then return false end
        if ownerWrite then return ownerWrite(object, method, ...) end
        object[method](object, ...)
        return current()
    end
    if not current() then return nil end
    if row.catalogCard then
        local titleHeight = measuredHeight(row.title, 18)
        local noteHeight = measuredHeight(row.note, 14)
        local height = math.max(84, 8 + titleHeight + 4 + noteHeight + 8)
        if not current() or not write(row.title, "ClearAllPoints") or not write(row.title, "SetPoint", "TOPLEFT", 72, -8) or
            not write(row.note, "Show") or not write(row.note, "ClearAllPoints") or
            not write(row.note, "SetPoint", "TOPLEFT", 72, -(8 + titleHeight + 4)) or not write(row, "SetHeight", height) or
            not write(row, "ClearAllPoints") or not write(row, "SetPoint", "TOPLEFT", 0, -offset) then return nil end
        return offset + height + 8
    end
    if row.compact then
        local left = 8 + (row.chainInset or 0) + (row.statusInset or 0)
        local height = math.max(minimum, 12 + measuredHeight(row.title, 18))
        if not current() or not write(row.note, "Hide") or not write(row.title, "ClearAllPoints") or
            not write(row.title, "SetPoint", "TOPLEFT", left, -6) or not write(row, "SetHeight", height) or
            not write(row, "ClearAllPoints") or not write(row, "SetPoint", "TOPLEFT", row.questTreeInset or 0, -offset) then return nil end
        return offset + height + 2
    end
    if not write(row.note, "SetShown", not row.heading) then return nil end
    local noteLeft = row.art and 58 or 8
    local titleLeft = noteLeft + (not row.art and row.statusInset or 0)
    local titleHeight = measuredHeight(row.title, 18)
    if not current() then return nil end
    local noteHeight = row.heading and 0 or measuredHeight(row.note, 18)
    if not current() then return nil end
    local height = math.max(minimum, 7 + titleHeight + (row.heading and 0 or 4) + noteHeight + 7)
    if not write(row.title, "ClearAllPoints") or not write(row.title, "SetPoint", "TOPLEFT", titleLeft, -7) or
        not write(row.note, "ClearAllPoints") or not write(row.note, "SetPoint", "TOPLEFT", noteLeft, -(7 + titleHeight + 4)) or
        not write(row, "SetHeight", height) or not write(row, "ClearAllPoints") or
        not write(row, "SetPoint", "TOPLEFT", 0, -offset) then return nil end
    return offset + height + 4
end

local function hideRest(pool, n)
    for i = n + 1, #pool do pool[i]:Hide() end
end

function UI:LoadFilters()
    local filters = addon.Clean(addon.char.filters, "table") or {}
    for _, key in ipairs({ "range", "includeUnavailable" }) do
        self[key] = addon.Clean(filters[key], "boolean") == true
    end
    self.preparation = false
end

function UI:SaveFilters()
    if not addon.Clean(addon.char.filters, "table") then addon.char.filters = {} end
    for _, key in ipairs({ "range", "includeUnavailable" }) do
        addon.char.filters[key] = addon.Clean(self[key], "boolean") == true
    end
end

function UI:ResetHistoryReading()
    self.detailNavigationRevision = {}
    self.detailOffsets, self.detailOffsetsOwner, self.detailOffsetsDungeon = nil, nil, nil
end

function UI:HistoryOffsets()
    if self.detailOffsetsOwner ~= self.detailHistory or self.detailOffsetsDungeon ~= self.dungeon then
        self.detailOffsets = {}
        self.detailOffsetsOwner, self.detailOffsetsDungeon = self.detailHistory, self.dungeon
    end
    return self.detailOffsets
end

function UI:InspectQuest(id, refreshList)
    id = addon.Clean(id, "number")
    if not id or id <= 0 or id % 1 ~= 0 then return false end
    local history, dungeon = self.detailHistory, self.dungeon
    local offsets = self:HistoryOffsets()
    local revision = {}
    self.detailNavigationRevision = revision
    if self.quest ~= id then
        local previous = addon.Clean(self.quest, "number")
        if previous and previous > 0 and previous % 1 == 0 then
            local scroll, generation, checker = self.detailScroll, self.rewardGeneration, issecretvalue
            local getter = scroll.GetVerticalScroll
            local offset = addon.Read(getter, "number", scroll)
            if self.detailNavigationRevision ~= revision or self.quest ~= previous or self.dungeon ~= dungeon or
                self.detailHistory ~= history or self.rewardGeneration ~= generation or
                scroll.GetVerticalScroll ~= getter or issecretvalue ~= checker then return false end
            history[#history + 1] = previous
            offsets[#history] = { quest = previous, offset = offset and offset >= 0 and offset or nil }
            if #history > 20 then
                table.remove(history, 1)
                for index = 1, #history do offsets[index] = offsets[index + 1] end
                offsets[#history + 1] = nil
            end
        end
        self.quest = id
    end
    if refreshList then
        self:RefreshQuests()
        if self.quest ~= id or self.dungeon ~= dungeon or self.detailHistory ~= history or self.detailNavigationRevision ~= revision then return false end
    end
    self:RefreshDetail()
    return true
end

function UI:CanReturnToOverview()
    local id = addon.Clean(self.quest, "number")
    return id ~= nil and id > 0 and id % 1 == 0 and addon.Clean(self.dungeon, "table") ~= nil
end

function UI:BackQuest()
    local history, dungeon = self.detailHistory, self.dungeon
    local offsets, index = self:HistoryOffsets(), #history
    local previous = history[index]
    if not previous and not self:CanReturnToOverview() then return false end
    local saved = offsets[index]
    offsets[index] = nil
    table.remove(history)
    local revision = {}
    self.detailNavigationRevision = revision
    self.quest = previous
    self:RefreshDetail()
    local offset = saved and saved.quest == previous and addon.Clean(saved.offset, "number")
    if previous and offset and offset >= 0 and self.detailNavigationRevision == revision and self.quest == previous and
        self.dungeon == dungeon and self.detailHistory == history and addon.Read(self.frame.IsShown, "boolean", self.frame) == true then
        local generation, checker = self.rewardGeneration, issecretvalue
        local content = addon.Read(self.detail.GetHeight, "number", self.detail)
        local viewport = addon.Read(self.detailScroll.GetHeight, "number", self.detailScroll)
        if self.detailNavigationRevision == revision and self.rewardGeneration == generation and issecretvalue == checker and
            self.quest == previous and self.dungeon == dungeon and self.detailHistory == history and
            content and viewport and content >= 0 and viewport > 0 then
            self.detailScroll:SetVerticalScroll(math.min(offset, math.max(0, content - viewport)))
        end
    end
    return true
end

function UI:ChooseBranch(id, index, parent)
    id, index = addon.Clean(id, "number"), addon.Clean(index, "number")
    if not id or id <= 0 or id ~= math.floor(id) or not index or index <= 0 or index ~= math.floor(index) then return false end
    local q = addon.quests[id]
    local group = q and q.requires and q.requires[index]
    if not group or #group.ids < 2 then return false end
    if type(parent) ~= "nil" then
        parent = addon.Clean(parent, "number")
        if not parent or parent <= 0 or parent ~= math.floor(parent) then return false end
        local member = false
        for _, candidate in ipairs(group.ids) do if candidate == parent then member = true end end
        if not member then return false end
        local fresh = addon.Planner.New(addon.quests, addon.Context(), addon.Clean(addon.char.choices, "table"))
        if fresh:State(parent).status == "UNAVAILABLE" then return false end
    end
    if not addon.Clean(addon.char.choices, "table") then addon.char.choices = {} end
    if not addon.Clean(addon.char.choices[id], "table") then addon.char.choices[id] = {} end
    addon.char.choices[id][index] = parent
    self:Refresh()
    return true
end

function UI:FlushPendingSearch(expected)
    local pending = self.pendingSearch
    if not pending or (expected and pending ~= expected) then return false end
    self.pendingSearch = nil
    local frame = pending.frame
    local shown = frame and addon.Read(frame.IsShown, "boolean", frame)
    if self.pendingSearch or addon.UI ~= self or self.frame ~= frame or self.search ~= pending.query or
        self.RefreshDungeons ~= pending.refresh or shown ~= true then return false end
    self:RefreshDungeons()
    return true
end

function UI:QueueSearch()
    local pending = { frame = self.frame, query = self.search, refresh = self.RefreshDungeons }
    self.pendingSearch = pending
    local timer = addon.Clean(C_Timer, "table")
    local after = timer and addon.Clean(timer.After, "function")
    -- Only the latest edit renders; the timer API does not provide cancellation.
    if after and pcall(after, 0.15, function() self:FlushPendingSearch(pending) end) then return end
    self:FlushPendingSearch(pending)
end

function UI:CatalogResultNote(result, matchedName)
    local note = addon.L("CATALOG_COMPACT_META", result.minimum, result.maximum, result.count)
    matchedName = matchedName or result.matchedName
    if matchedName then note = note .. "\n" .. addon.L("SEARCH_QUEST_MATCH", matchedName) end
    if result.sourceMatch then
        note = note .. "\n" .. addon.L(result.sourceMatch.kind == "npc" and "SEARCH_NPC_MATCH" or "SEARCH_PLACE_MATCH", result.sourceMatch.text)
    end
    return note
end

function UI:CatalogLanguageKey()
    local language = addon.Clean(addon.Language, "table")
    local selection = language and addon.Read(language.GetSelection, "string", language)
    local locale = selection or addon.Clean(addon.db.locale, "string") or "auto"
    if locale == "auto" then locale = addon.Read(GetLocale, "string") end
    return locale
end

function UI:RefreshCatalogData()
    local view = self.catalogLanguageView
    local locale = self:CatalogLanguageKey()
    local function current()
        return self.catalogLanguageView == view and view and view.current()
    end
    if not view or view.query ~= "" or not locale or view.uiLanguage ~= locale or not current() then return false end
    for _, result in ipairs(view.results) do
        if result.statusCurrent and addon.Read(result.statusCurrent, "boolean") ~= true then return false end
        if not current() then return false end
    end
    if self:CatalogLanguageKey() ~= locale or not current() then return false end
    local selected = self.dungeon
    if selected ~= view.selectedDungeon then
        for _, result in ipairs(view.results) do
            if result.dungeon == selected or result.dungeon == view.selectedDungeon then
                styleRow(result.row, "dungeon", result.dungeon == selected)
                if not current() or self.dungeon ~= selected then
                    -- A nested selection may never have touched this pending
                    -- card. Repair its late styling using the newest selection.
                    if current() and not view.selectionRepair then
                        view.selectionRepair = true
                        styleRow(result.row, "dungeon", result.dungeon == self.dungeon)
                        view.selectionRepair = nil
                    end
                    return false, "superseded"
                end
            end
        end
        view.selectedDungeon = selected
    end
    return current()
end

function UI:RefreshCatalogLanguage()
    local view = self.catalogLanguageView
    if not view then return false end
    -- Free-text results can include a UI-localized wing name. Numeric quest
    -- searches and the unfiltered catalogue have language-independent membership.
    if view.query ~= "" and not view.queryID then return false end
    if not view.current() then
        return false, self.catalogLanguageView ~= view and "superseded" or nil
    end
    local paint = {}; self.catalogLanguagePaint = paint
    local function current()
        return self.catalogLanguageView == view and self.catalogLanguagePaint == paint and view.owned()
    end
    local function failed()
        return false, (self.catalogLanguageView ~= view or self.catalogLanguagePaint ~= paint) and "superseded" or nil
    end
    local function write(object, method, ...)
        return view.write(current, true, object, method, ...)
    end
    if not write(self.searchPlaceholder, "SetText", addon.L("SEARCH")) or
        not write(self.searchHint, "SetText", addon.L("SEARCH_HELP")) then return failed() end
    local offset = view.query ~= "" and measuredHeight(self.searchHint, 42) + 10 or 0
    for _, result in ipairs(view.results) do
        if not current() then return failed() end
        local row = result.row
        if result.statusCurrent and addon.Read(result.statusCurrent, "boolean") ~= true then return false end
        if not current() then return failed() end
        local title = addon.Read(addon.DungeonName, "string", result.dungeon)
        local matchedName = result.questID and result.matchedName and addon.Read(addon.CachedQuestName, "string", result.questID)
        if not current() or not title or not write(row.title, "SetText", title) or
            not write(row.note, "SetText", self:CatalogResultNote(result, matchedName)) then return failed() end
        offset = self:LayoutRow(row, 64, offset, current, write)
        if not offset then return failed() end
        local inspect = result.inspect
        if inspect then
            if not write(inspect.label, "SetText", addon.L("BRANCH_INSPECT")) then return failed() end
            local height = math.max(28, measuredHeight(inspect.label, 18) + 10)
            if not write(inspect, "SetHeight", height) or not write(inspect, "ClearAllPoints") or
                not write(inspect, "SetPoint", "TOPLEFT", 8, -offset) then return failed() end
            offset = offset + height + 6
        end
    end
    if #view.results == 0 then
        if not write(self.catalogNotice, "SetText", addon.L("NO_DUNGEONS")) or
            not write(self.catalogNotice, "ClearAllPoints") or
            not write(self.catalogNotice, "SetPoint", "TOPLEFT", 4, -offset) then return failed() end
        offset = offset + measuredHeight(self.catalogNotice, 42) + 10
    end
    if not write(self.catalog, "SetHeight", math.max(1, offset)) then return failed() end
    if not current() or not view.current() then return failed() end
    local locale = self:CatalogLanguageKey()
    if not current() or not view.current() then return failed() end
    view.uiLanguage = locale
    return true
end

function UI:RefreshDungeons()
    self.catalogLanguageView = nil
    self.pendingSearch = nil
    local generation = {}
    self.catalogGeneration = generation
    local catalogue, definitions, character, database = addon.dungeons, addon.quests, addon.char, addon.db
    local search, range, locale, catalogScroll = self.search, self.range, addon.db.locale, self.catalogScroll
    local getter, dungeonGetter, fold, checker = addon.CachedQuestName, addon.DungeonName, addon.SearchFold, issecretvalue
    local context = addon.Context()
    local contextCurrent = context.current
    local query = (addon.Clean(search, "string") or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local needle = searchText(query)
    local inputs, results, memo, sourceMemo, sourceMatches = {}, {}, {}, {}, {}
    local renderInput, inputByDungeon, staging = nil, {}, true
    local sourceGetter, idParser = addon.QuestSourceSearchTerms, addon.SearchQuestID
    for index, dungeon in ipairs(catalogue) do
        local targets = dungeon.quests
        local input = { dungeon = dungeon, name = dungeon.name, key = dungeon.key, wing = dungeon.wing,
            minimum = dungeon.minLevel, maximum = dungeon.maxLevel, targets = targets, members = {} }
        inputs[index], input.index, inputByDungeon[dungeon] = input, index, input
        for other, id in ipairs(targets) do
            local quest = definitions[id]
            input.members[other] = { id = id, quest = quest, name = quest and quest.name, questID = quest and quest.id }
        end
    end
    local sourceReady = true
    local function baseCurrent(sourceOnly)
        local ok, valid = pcall(function()
            if context.current ~= contextCurrent or addon.QuestSourceSearchTerms ~= sourceGetter or
                addon.SearchQuestID ~= idParser then return false end
            if self.catalogGeneration ~= generation or self.search ~= search or self.range ~= range or self.catalogScroll ~= catalogScroll or
                addon.dungeons ~= catalogue or addon.quests ~= definitions or addon.char ~= character or
                addon.db ~= database or database.locale ~= locale or addon.CachedQuestName ~= getter or
                addon.DungeonName ~= dungeonGetter or addon.SearchFold ~= fold or issecretvalue ~= checker or
                #catalogue ~= #inputs then return false end
            -- The source-only scan has no effects; publication still proves every member.
            if sourceOnly == true then return true end
            local function matches(input, index)
                local dungeon = input.dungeon
                if catalogue[index] ~= dungeon or dungeon.name ~= input.name or dungeon.key ~= input.key or dungeon.wing ~= input.wing or
                    dungeon.minLevel ~= input.minimum or dungeon.maxLevel ~= input.maximum or dungeon.quests ~= input.targets or
                    #input.targets ~= #input.members then return false end
                for other, member in ipairs(input.members) do
                    if input.targets[other] ~= member.id or definitions[member.id] ~= member.quest or
                        (member.quest and (member.quest.name ~= member.name or member.quest.id ~= member.questID)) then return false end
                end
                return true
            end
            if renderInput and sourceOnly ~= "full" then return matches(renderInput, renderInput.index) end
            for index, input in ipairs(inputs) do if not matches(input, index) then return false end end
            return true
        end)
        return ok and valid == true
    end
    local function ownedWrite(ownerCurrent, skipUnchangedText, object, method, ...)
        if not ownerCurrent() then return false end
        local bindings = object.catalogWrites or {}
        object.catalogWrites = bindings
        local key = (method == "Show" or method == "Hide" or method == "SetShown") and "visibility" or
            ((method == "SetPoint" or method == "ClearAllPoints") and "anchor" or method)
        local args, count = { ... }, select("#", ...)
        local binding = { current = ownerCurrent, args = args, count = count, method = method }
        bindings[key] = binding
        -- Keep the new ownership record even when native text already matches:
        -- an older reentrant setter may still finish and need this value restored.
        if skipUnchangedText and method == "SetText" then
            local desired = addon.Clean(args[1], "string")
            local existing = addon.Read(object.GetText, "string", object)
            if not ownerCurrent() then return false end
            if desired and existing == desired then return true end
        end
        local ok = pcall(object[method], object, unpack(args, 1, count))
        local fresh = ownerCurrent()
        if not fresh then
            local latest = object.catalogWrites
            local newer = latest and latest[key]
            if newer and newer ~= binding and not newer.repairing then
                newer.repairing = true
                local repairCurrent = newer.current()
                if repairCurrent and object.catalogWrites == latest and latest[key] == newer then
                    pcall(object[newer.method], object, unpack(newer.args, 1, newer.count))
                end
                newer.repairing = nil
            end
        end
        return ok and fresh
    end
    local function retire()
        sourceReady = false
        local function cleanupCurrent() return self.catalogGeneration == generation and self.catalogScroll == catalogScroll end
        for _, controls in ipairs({ self.cards, self.catalogInspectButtons }) do
            for _, control in ipairs(controls) do
                if not ownedWrite(cleanupCurrent, false, control, "Hide") then return false end
            end
        end
        return false
    end
    local function expireSources()
        sourceReady = false
        for _, controls in ipairs({ self.cards, self.catalogInspectButtons }) do
            for _, control in ipairs(controls) do
                if not ownedWrite(baseCurrent, false, control, "Hide") or
                    not ownedWrite(baseCurrent, false, control, "SetScript", "OnClick", nil) then return false end
            end
        end
        return false
    end
    local function unchanged(cached)
        local ok, valid = pcall(cached.unchanged)
        if not ok or valid ~= true then return false end
        ok, valid = pcall(function()
            if #cached.terms ~= #cached.entries then return false end
            for index, entry in ipairs(cached.entries) do
                local term = rawget(cached.terms, index)
                if term ~= entry.term or rawget(term, "text") ~= entry.text or rawget(term, "kind") ~= entry.kind then return false end
            end
            return true
        end)
        return ok and valid == true
    end
    local function current(sourceOnly)
        -- Full member validation follows callbacks; keep the entry guard cheap.
        if not sourceReady or not baseCurrent(true) then return false end
        if contextCurrent and addon.Read(contextCurrent, "boolean") ~= true then return false end
        for _, cached in ipairs(sourceMatches) do
            if addon.Read(cached.current, "boolean") ~= true then return expireSources() end
        end
        for _, cached in ipairs(sourceMatches) do
            if not unchanged(cached) then return expireSources() end
        end
        return baseCurrent(sourceOnly)
    end
    local function proveSources()
        if not current("full") then return false end
        for _, cached in pairs(sourceMemo) do
            if cached.current and addon.Read(cached.current, "boolean") ~= true then return expireSources() end
        end
        if not current("full") then return false end
        -- Complete callback preflights before the callback-free ownership pass.
        for _, cached in pairs(sourceMemo) do
            if cached.current and not unchanged(cached) then return expireSources() end
        end
        return baseCurrent("full")
    end
    local function scanMember(input, index, member, other)
        local ok, valid = pcall(function()
            local dungeon = input.dungeon
            return baseCurrent(true) and catalogue[index] == dungeon and dungeon.name == input.name and
                dungeon.key == input.key and dungeon.minLevel == input.minimum and dungeon.maxLevel == input.maximum and
                dungeon.quests == input.targets and #input.targets == #input.members and
                (not member or (input.targets[other] == member.id and definitions[member.id] == member.quest and
                (not member.quest or (member.quest.name == member.name and member.quest.id == member.questID))))
        end)
        return ok and valid == true
    end
    local queryID = addon.Read(idParser, "number", query)
    if queryID and (queryID <= 0 or queryID > 9007199254740991 or queryID % 1 ~= 0) then queryID = nil end
    if not current() then return end
    for inputIndex, input in ipairs(inputs) do
        local dungeon = input.dungeon
        if not range or (context.level and context.level >= input.minimum - 3 and context.level <= input.maximum + 3) then
            if not scanMember(input, inputIndex) then return end
            local matchedName, matchedID, sourceMatch, idMatch
            if queryID then
                for memberIndex, member in ipairs(input.members) do
                    if not scanMember(input, inputIndex, member, memberIndex) then return end
                    if member.id == queryID and member.quest and member.questID == queryID then
                        local title = addon.Clean(member.name, "string")
                        if not current(true) then return end
                        matchedName = title and title ~= "" and (title .. " (#" .. query .. ")") or ("#" .. query)
                        matchedID, idMatch = member.id, true
                        break
                    end
                end
            end
            local name, matches = "", false
            if not queryID or matchedID then
                name = addon.Read(dungeonGetter, "string", dungeon) or addon.Clean(input.name, "string") or ""
                if not current(true) then return end
                if not queryID then matches = query == "" or searchText(name):find(needle, 1, true) or searchText(input.name):find(needle, 1, true) end
            end
            if not queryID and not matches then
                for _, member in ipairs(input.members) do
                    local source = addon.Clean(member.name, "string")
                    if not current(true) then return end
                    if source and searchText(source):find(needle, 1, true) then
                        matchedName, matchedID = source, member.id; break
                    end
                end
            end
            if not queryID and not matches and not matchedName then
                for memberIndex, member in ipairs(input.members) do
                    if not scanMember(input, inputIndex, member, memberIndex) then return end
                    local cached = memo[member.id]
                    if not cached then
                        cached = { name = addon.Read(getter, "string", member.id) }
                        memo[member.id] = cached
                    end
                    if not current(true) then return end
                    if cached.name and searchText(cached.name):find(needle, 1, true) then
                        matchedName, matchedID = cached.name, member.id; break
                    end
                end
            end
            if not queryID and not matches and not matchedName and addon.Clean(sourceGetter, "function") then
                for memberIndex, member in ipairs(input.members) do
                    if not scanMember(input, inputIndex, member, memberIndex) then return end
                    local cached = sourceMemo[member.id]
                    if not cached then
                        cached = {}; sourceMemo[member.id] = cached
                        local ok, terms, owner, proof = false, nil, nil, nil
                        if member.quest then ok, terms, owner, proof = pcall(sourceGetter, member.quest) end
                        terms, owner, proof = addon.Clean(terms, "table"), addon.Clean(owner, "function"), addon.Clean(proof, "function")
                        if ok and terms and owner and proof and #terms <= 1024 then
                            local entries, valid = {}, true
                            local length, count = #terms, 0
                            for key in next, terms do
                                local index = addon.Clean(key, "number")
                                if not index or index < 1 or index > length or index % 1 ~= 0 then valid = false; break end
                                count = count + 1
                            end
                            if count ~= length then valid = false end
                            for index = 1, length do
                                if not valid then break end
                                local term = addon.Clean(rawget(terms, index), "table")
                                local text = term and addon.Clean(rawget(term, "text"), "string")
                                local kind = term and addon.Clean(rawget(term, "kind"), "string")
                                if not text or #text > 2000 or not text:find("%S") or (kind ~= "npc" and kind ~= "place") then
                                    valid = false; break
                                end
                                entries[index] = { term = term, text = text, kind = kind }
                            end
                            if valid then
                                local ready = addon.Read(owner, "boolean")
                                if ready == true then cached.terms, cached.current, cached.entries, cached.unchanged = terms, owner, entries, proof end
                            end
                        end
                    end
                    for _, entry in ipairs(cached.entries or {}) do
                        local found = searchText(entry.text):find(needle, 1, true)
                        if found then
                            local title = addon.Clean(member.name, "string")
                            matchedName = title and title ~= "" and title or (memo[member.id] and memo[member.id].name) or ("#" .. member.id)
                            matchedID, sourceMatch = member.id, entry
                            if not cached.matched then cached.matched = true; sourceMatches[#sourceMatches + 1] = cached end
                            break
                        end
                    end
                    if matchedName then break end
                end
            end
            if not current(true) then return end
            if matches or matchedName then
                local result = { dungeon = dungeon, title = name, questID = matchedID, sourceMatch = sourceMatch,
                    idMatch = idMatch, minimum = input.minimum, maximum = input.maximum, count = #input.members, matchedName = matchedName }
                result.note = self:CatalogResultNote(result)
                if not current(true) then return end
                results[#results + 1] = result
            end
        end
    end
    if not proveSources() then return end
    local statusModule = addon.Clean(addon.DungeonStatus, "table")
    local statusGetter = statusModule and addon.Clean(statusModule.Get, "function")
    local statusEngine = statusGetter and addon.Read(addon.Planner.New, "table", definitions, context, addon.Clean(character.choices, "table"))
    if not current() then return end
    for _, result in ipairs(results) do
        renderInput = inputByDungeon[result.dungeon]
        local ok, dto, fresh
        if statusEngine then ok, dto, fresh = pcall(statusGetter, result.dungeon, statusEngine) end
        if not current() then return end
        if ok and addon.Clean(dto, "table") and addon.Clean(fresh, "function") then
            result.statusDTO, result.statusCurrent = dto, fresh
        end
    end
    local function write(object, method, ...)
        return ownedWrite(current, false, object, method, ...)
    end
    renderInput = nil
    if not proveSources() then return end
    for _, row in ipairs(self.cards) do if not write(row, "Hide") then return retire() end end
    for _, control in ipairs(self.catalogInspectButtons) do
        if not write(control, "Hide") or not write(control, "SetEnabled", false) or
            not write(control, "SetScript", "OnClick", nil) then return end
        control.questID = nil
    end
    local inspectIndex = 0
    local offset = 0
    if not write(self.searchPlaceholder, "SetText", addon.L("SEARCH")) or
        not write(self.searchPlaceholder, "SetShown", search == "") or
        not write(self.clearSearch, "SetEnabled", search ~= "") or
        not write(self.searchHint, "SetText", addon.L("SEARCH_HELP")) or
        not write(self.searchHint, "SetShown", query ~= "") or not write(self.catalogNotice, "Hide") then return end
    if query ~= "" then offset = measuredHeight(self.searchHint, 42) + 10 end
    if not current() then return end
    for index, result in ipairs(results) do
        local dungeon = result.dungeon
        renderInput = inputByDungeon[dungeon]
        local row = self:MakeRow(self.catalog, self.cards, index, 84, current, true)
        row.catalogCard = true
        local theme = addon.Clean(addon.Theme, "table")
        if theme then addon.Read(theme.ApplyFont, "boolean", row.note, 12) end
        if not current() then return end
        result.row = row
        row.catalogResult = result
        if not current() or not write(row, "Hide") then return end
        if not row.art then
            row.art = row:CreateTexture(nil, "ARTWORK")
            if not write(row.art, "SetSize", 52, 56) or not write(row.art, "SetPoint", "TOPLEFT", 8, -8) then return end
        end
        if not row.entranceControl then
            local control = CreateFrame("Button", nil, row)
            row.entranceControl = control
            control:SetSize(28, 28); control:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -6)
            if type(control.SetMotionScriptsWhileDisabled) == "function" then control:SetMotionScriptsWhileDisabled(true) end
            local icon = control:CreateTexture(nil, "ARTWORK"); control.footerIcon = icon
            icon:SetSize(20, 20); icon:SetPoint("CENTER", control, "CENTER", 0, 0)
            local atlas = "Waypoint-MapPin-Untracked"
            local loaded = type(icon.SetAtlas) == "function" and pcall(icon.SetAtlas, icon, atlas)
            if not loaded or addon.Read(icon.GetAtlas, "string", icon) ~= atlas then icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01") end
            icon:Show()
            control:SetScript("OnEnter", function() control.footerHovered = true; self:RefreshFooterIcon(control); self:CatalogEntranceHint(row) end)
            control:SetScript("OnLeave", function() control.footerHovered = false; self:RefreshFooterIcon(control); self:HideNavigationHint() end)
            control:SetScript("OnHide", function() control.footerHovered = false; self:RefreshFooterIcon(control); self:HideNavigationHint() end)
        end
        -- The separate icon rail never overlaps title or metadata wrapping.
        local textWidth = math.max(1, row:GetWidth() - 72 - 36)
        if not write(row.title, "SetWidth", textWidth) or not write(row.note, "SetWidth", textWidth) then return end
        local control, frame = row.entranceControl, self.frame
        local function entranceCurrent()
            local shown = addon.Read(row.IsShown, "boolean", row)
            return (shown == true or staging) and addon.UI == self and self.frame == frame and self.catalogGeneration == generation and self.cards[index] == row and
                row.entranceDungeon == dungeon and row.entranceCurrent == entranceCurrent and addon.dungeons == catalogue and
                addon.char == character and addon.db == database and self.search == search and self.range == range and sourceReady
        end
        row.entranceDungeon, row.entranceCurrent = dungeon, entranceCurrent
        local candidate = self:GetEntranceBinding(dungeon, entranceCurrent)
        if not current() or not entranceCurrent() then return end
        row.entranceBinding = candidate
        local enabled = candidate ~= nil
        control.footerEnabled = enabled
        if not enabled then control.footerPressed, control.footerHovered = false, false end
        if not write(control, "SetEnabled", enabled) then return end
        local icon = control.footerIcon
        local alpha = enabled and (control.footerHovered and 1 or .88) or .3
        if type(icon.SetAlpha) == "function" and not write(icon, "SetAlpha", alpha) then return end
        if type(icon.SetDesaturated) == "function" and not write(icon, "SetDesaturated", not enabled) then return end
        if not row.dungeonStatusControl then
            local statusControl = CreateFrame("Frame", nil, row)
            row.dungeonStatusControl = statusControl
            statusControl:SetSize(28, 28); statusControl:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -44)
            statusControl:EnableMouse(true)
            local statusIcon = statusControl:CreateTexture(nil, "ARTWORK"); statusControl.statusIcon = statusIcon
            statusIcon:SetSize(20, 20); statusIcon:SetPoint("CENTER", statusControl, "CENTER", 0, 0)
            statusControl:SetScript("OnEnter", function() self:CatalogStatusHint(row) end)
            statusControl:SetScript("OnLeave", function() self:HideNavigationHint() end)
            statusControl:SetScript("OnHide", function() self:HideNavigationHint() end)
        end
        local dto, statusCurrent = result.statusDTO, result.statusCurrent
        local function statusOwned()
            if not entranceCurrent() or row.dungeonStatusDTO ~= dto or row.dungeonStatusCurrent ~= statusOwned then return false end
            if not statusCurrent or addon.Read(statusCurrent, "boolean") ~= true then return false end
            return entranceCurrent() and row.dungeonStatusDTO == dto and row.dungeonStatusCurrent == statusOwned
        end
        row.dungeonStatusDTO, row.dungeonStatusCurrent = dto, statusOwned
        local statusIcon = row.dungeonStatusControl.statusIcon
        if not write(row.dungeonStatusControl, "SetShown", dto ~= nil) or not write(statusIcon, "Hide") then return end
        if dto and statusOwned() then
            local status = addon.Clean(dto.status, "string")
            local painter = (status == "ACTIVE" or status == "READY") and addon.PaintQuestStatus or addon.PaintCompactQuestStatus
            if status == "ACTIVE" or status == "READY" then addon.Read(painter, "boolean", statusIcon, status, statusOwned)
            else addon.Read(painter, "boolean", statusIcon, status, dto.reason, statusOwned) end
            if not current() then return end
        end
        local binding = row.entranceBinding
        if not write(control, "SetScript", "OnClick", function()
            if addon.Read(row.IsShown, "boolean", row) ~= true then return end
            if not entranceCurrent() or row.entranceBinding ~= binding or not binding or not binding.current() then return end
            if addon.Read(frame.IsShown, "boolean", frame) ~= true or not entranceCurrent() or not binding.current() then return end
            pcall(binding.start, binding.dungeon, binding.point)
        end) then return end
        if not write(row.art, "Hide") then return end
        addon.Read(addon.PaintDungeonArt, "boolean", row.art, dungeon)
        if not current() then return end
        if not write(row.title, "SetText", result.title) or not write(row.note, "SetText", result.note) or
            not write(row.bg, "SetColorTexture", self.dungeon == dungeon and 0.22 or 0.13, 0.19, 0.23, 1) then return end
        styleRow(row, "dungeon", self.dungeon == dungeon)
        if not current() then return end
        row.matchQuestID = result.questID
        if not write(row, "SetScript", "OnClick", function()
            if addon.Read(row.IsShown, "boolean", row) ~= true then return end
            if not proveSources() then return end
            self:ResetHistoryReading()
            self.detailHistory = {}
            self.dungeon, self.quest = dungeon, nil
            character.selectedDungeon = dungeon.key
            self.preparation = false
            self:Refresh(nil, true)
        end) then return end
        offset = self:LayoutRow(row, 64, offset, current, write)
        if not offset then return end
        if result.questID then
            local questID, definition = result.questID, definitions[result.questID]
            local localeGetter, nativeRoot, guidGetter = GetLocale, C_QuestLog, UnitGUID
            local native = addon.Clean(nativeRoot, "table")
            local titleGetter = native and rawget(native, "GetTitleForQuestID")
            local gameLocale = addon.Read(localeGetter, "string")
            local function inspectCurrent()
                local language = addon.Read(localeGetter, "string")
                if not current() then return false end
                return GetLocale == localeGetter and language == gameLocale and C_QuestLog == nativeRoot and
                    UnitGUID == guidGetter and (not native or rawget(native, "GetTitleForQuestID") == titleGetter) and
                    definitions[questID] == definition and definition and rawget(definition, "id") == questID
            end
            if not inspectCurrent() then return end
            inspectIndex = inspectIndex + 1
            local inspect = self.catalogInspectButtons[inspectIndex]
            if not inspect then
                inspect = CreateFrame("Button", nil, self.catalog)
                if not write(inspect, "Hide") then return end
                inspect:SetWidth(self.catalog:GetWidth() - 16); inspect.label = label(inspect, "", 7, -5, self.catalog:GetWidth() - 30, 14)
                inspect.title = inspect.label
                inspect:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                self.catalogInspectButtons[inspectIndex] = inspect
            end
            if not inspectCurrent() then return end
            inspect.questID = questID
            result.inspect = inspect
            if not write(inspect.label, "SetText", addon.L("BRANCH_INSPECT")) then return end
            local height = math.max(28, measuredHeight(inspect.label, 18) + 10)
            if not inspectCurrent() or not write(inspect, "SetHeight", height) or
                not write(inspect, "ClearAllPoints") or not write(inspect, "SetPoint", "TOPLEFT", 8, -offset) or
                not write(inspect, "SetEnabled", true) then return end
            styleRow(inspect, "control", false)
            if not inspectCurrent() or not write(inspect, "SetScript", "OnClick", function()
                local shown = addon.Read(self.frame.IsShown, "boolean", self.frame)
                if shown ~= true or not inspectCurrent() then return end
                local matches
                if result.idMatch then
                    matches = queryID == questID
                elseif result.sourceMatch then
                    matches = searchText(result.sourceMatch.text):find(needle, 1, true)
                    if not inspectCurrent() then return end
                else
                    local source = addon.Clean(rawget(definition, "name"), "string")
                    matches = source and searchText(source):find(needle, 1, true)
                    if not inspectCurrent() then return end
                    if not matches then
                        local cached = addon.Read(getter, "string", questID)
                        if not inspectCurrent() then return end
                        matches = cached and searchText(cached):find(needle, 1, true)
                    end
                end
                if addon.Read(row.IsShown, "boolean", row) ~= true or not matches or not inspectCurrent() or not proveSources() then return end
                self:ResetHistoryReading(); self.detailHistory = {}
                self.dungeon, self.quest = dungeon, questID
                character.selectedDungeon = dungeon.key
                self:Refresh()
            end) or not write(inspect, "Hide") then return end
            offset = offset + height + 6
        end
    end
    renderInput, staging = nil, false
    for index = #results + 1, #self.cards do
        local row = self.cards[index]
        if not write(row, "Hide") or not write(row, "SetScript", "OnClick", nil) then return end
        row.matchQuestID = nil
        row.entranceCurrent, row.entranceBinding, row.entranceDungeon = nil, nil, nil
    end
    if #results == 0 then
        if not write(self.catalogNotice, "SetText", addon.L("NO_DUNGEONS")) or
            not write(self.catalogNotice, "ClearAllPoints") or not write(self.catalogNotice, "SetPoint", "TOPLEFT", 4, -offset) or
            not write(self.catalogNotice, "Show") then return end
        offset = offset + measuredHeight(self.catalogNotice, 42) + 10
    end
    if not current() then return end
    if not write(self.catalog, "SetHeight", math.max(1, offset)) then return end
    if not proveSources() then return retire() end
    if self.catalogQueryKey ~= nil and self.catalogQueryKey ~= needle then
        if not write(catalogScroll, "SetVerticalScroll", 0) or not proveSources() then return end
    end
    self.catalogQueryKey = needle
    for _, result in ipairs(results) do
        if not write(result.row, "Show") then return retire() end
        if result.inspect and not write(result.inspect, "Show") then return retire() end
    end
    if not proveSources() then return retire() end
    local uiLanguage = self:CatalogLanguageKey()
    if not proveSources() then return retire() end
    self.catalogLanguageView = { current = proveSources, owned = function() return baseCurrent(true) end,
        write = ownedWrite, query = query, queryID = queryID, results = results,
        uiLanguage = uiLanguage, selectedDungeon = self.dungeon }
end

function UI:PaintQuestRowStatus(row, entry, engine, ownerCurrent)
    local id, state, heading = entry.id, entry.state, entry.heading
    local status = state and state.status
    local compactRole = row.compact and status ~= "ACTIVE" and status ~= "READY"
    local painter, checker, token = compactRole and addon.PaintCompactQuestStatus or addon.PaintQuestStatus, issecretvalue, {}
    local definition = id and addon.quests[id]
    local widthGetter, widthSetter = row.title.GetWidth, row.title.SetWidth
    local eligible = not heading and (row.compact or status == "ACTIVE" or status == "READY")
    row.statusGeneration = token
    local function current()
        if not ownerCurrent() then return false end
        local fresh = not eligible or not engine.Current or addon.Read(engine.Current, "boolean", engine) == true
        local ok, same = pcall(function()
            return fresh and ownerCurrent() and row.statusGeneration == token and row.questID == id and row.heading == heading and
                entry.id == id and entry.state == state and (not state or state.status == status) and
                (not id or addon.quests[id] == definition) and (compactRole and addon.PaintCompactQuestStatus or addon.PaintQuestStatus) == painter and issecretvalue == checker and
                row.title.GetWidth == widthGetter and row.title.SetWidth == widthSetter
        end)
        return ok and same == true
    end
    if not current() then return false end
    local width = row.statusBaseWidth or addon.Read(widthGetter, "number", row.title)
    if not current() then return false end
    if not width or width <= 20 then
        row.statusInset = 0
        if row.statusIcon then pcall(row.statusIcon.Hide, row.statusIcon) end
        return current()
    end
    row.statusBaseWidth = width
    local usable = addon.Clean(painter, "function")
    if not current() then return false end
    local painted = false
    if eligible and usable then
        local texture = row.statusIcon
        if not texture then
            local ok, value = pcall(row.CreateTexture, row, nil, "ARTWORK")
            texture = ok and (addon.Clean(value, "table") or addon.Clean(value, "userdata"))
            if not current() then return false end
            if texture then row.statusIcon = texture end
        end
        if texture then
            local function configure(method, ...)
                if not current() then return false end
                local ok = pcall(texture[method], texture, ...)
                return ok and current()
            end
            if configure("SetSize", 16, 16) and configure("ClearAllPoints") and configure("SetPoint", "TOPLEFT", 8 + (row.chainInset or 0), row.compact and -7 or -8) then
                if compactRole then painted = addon.Read(usable, "boolean", texture, status, state and state.reason, current) == true
                else painted = addon.Read(usable, "boolean", texture, status, current, row.compact, state and state.reason) == true end
            end
            if not current() then return false end
        end
    end
    if not painted and row.statusIcon then
        pcall(row.statusIcon.Hide, row.statusIcon)
        if not current() then return false end
    end
    row.statusInset = painted and 20 or 0
    local binding = { current = current, width = width - row.statusInset }
    row.statusWidth = binding
    row.title:SetWidth(binding.width)
    if current() then return true end
    local newer = row.statusWidth
    if newer ~= binding and newer and newer.current() and not row.statusWidthRepair then
        row.statusWidthRepair = true
        if row.statusWidth == newer and newer.current() then pcall(row.title.SetWidth, row.title, newer.width) end
        row.statusWidthRepair = nil
    end
    return false
end

function UI:RefreshQuests()
    local d, character, previousGeneration = self.dungeon, addon.char, self.questListGeneration
    local preparation, includeUnavailable = self.preparation, self.includeUnavailable
    local targets, targetIDs, targetSet = d and d.quests, {}, {}
    for index, id in ipairs(targets or {}) do targetIDs[index] = id; targetSet[id] = true end
    local needsEngine = d ~= nil or self.quest ~= nil
    local context = needsEngine and addon.Context() or nil
    if self.dungeon ~= d or addon.char ~= character or self.questListGeneration ~= previousGeneration then return end
    local engine = needsEngine and addon.Planner.New(addon.quests, context, addon.Clean(character.choices, "table")) or nil
    self.engine = engine
    self.currentPlan = nil
    local generation, treeCurrent, treeFailed, rendering = {}, nil, false, true
    local infoProofs, infoFailed = {}, false
    self.questListGeneration = generation
    local proveTree
    local function current()
        local owned = self.questListGeneration == generation and self.engine == engine and self.dungeon == d and addon.char == character and
            self.preparation == preparation and self.includeUnavailable == includeUnavailable
        if not owned or treeFailed or infoFailed then return false end
        if d and (d.quests ~= targets or #targets ~= #targetIDs) then return false end
        for index, id in ipairs(targetIDs) do if targets[index] ~= id then return false end end
        if not rendering and not proveTree() then return false end
        return self.questListGeneration == generation and self.engine == engine and self.dungeon == d and addon.char == character and
            self.preparation == preparation and self.includeUnavailable == includeUnavailable
    end
    proveTree = function()
        if treeCurrent and addon.Read(treeCurrent, "boolean") ~= true then
            treeFailed = true
            -- Retire only this still-current hierarchy; callbacks may already
            -- have published a replacement list while validating the source.
            for _, row in ipairs(self.rows) do
                if self.questListGeneration ~= generation then return false end
                if row.questTreeNode then
                    local function cleanupCurrent() return self.questListGeneration == generation end
                    if not self:QuestListWrite(row, "Hide", cleanupCurrent) then return false end
                    if not self:QuestListWrite(row, "SetScript", cleanupCurrent, "OnClick", nil) then return false end
                end
            end
            return false
        end
        return self.questListGeneration == generation and not treeFailed
    end
    local function write(object, method, ...)
        return self:QuestListWrite(object, method, current, ...)
    end
    local function retireInfos()
        infoFailed = true
        for _, row in ipairs(self.rows) do
            local function cleanupCurrent() return self.questListGeneration == generation end
            if not self:QuestListWrite(row, "Hide", cleanupCurrent) or
                not self:QuestListWrite(row, "SetScript", cleanupCurrent, "OnClick", nil) then return false end
        end
        return false
    end
    local function proveInfos()
        if not current() or not proveTree() then return retireInfos() end
        for _, proof in ipairs(infoProofs) do
            if addon.Read(proof, "boolean") ~= true or not current() then return retireInfos() end
        end
        return (current() and proveTree()) or retireInfos()
    end
    local function writeText(fs, value)
        if not current() then return false end
        local binding = { current = current, value = value }
        fs.questListText = binding
        fs:SetText(value)
        if current() then return true end
        local newer = fs.questListText
        if newer ~= binding and newer and newer.current() and not fs.questListTextRepair then
            fs.questListTextRepair = true
            if fs.questListText == newer and newer.current() then pcall(fs.SetText, fs, newer.value) end
            fs.questListTextRepair = nil
        end
        return false
    end
    -- Hidden rows use local source guards while building. Prove the complete
    -- hierarchy at publication boundaries; retained input always rechecks it.
    local function render()
    for _, row in ipairs(self.rows) do
        if not write(row, "Hide") or not write(row, "SetEnabled", false) or not write(row, "SetScript", "OnClick", nil) then return end
    end
    local heading = d and addon.DungeonName(d) or addon.L("QUESTS")
    if not current() then return end
    if not writeText(self.heading, heading) then return end
    local n, offset = 0, 0
    if d then
        local plan = engine:Dungeon(d, { includeUnavailable = self.includeUnavailable })
        if not current() then return end
        self.currentPlan = { engine = engine, dungeon = d, rows = plan.rows, counts = plan.counts, unknown = plan.unknown, ready = plan.ready }
        local entries = plan.rows
        if self.preparation then
            entries = {}
            local groups = { outside = {}, inside = {}, level = {}, progress = {}, uncertain = {}, unavailable = {} }
            for _, action in ipairs(plan.actions) do
                local q, group = addon.quests[action.id], "progress"
                if action.kind == "level" then group = "level"
                elseif action.kind == "inside" or (action.kind == "pickup" and q and q.startsInside) then group = "inside"
                elseif action.kind == "pickup" then group = "outside" end
                local rows = groups[group]
                rows[#rows + 1] = { id = action.id, state = engine:State(action.id), action = action }
            end
            -- Unresolved targets stay visible even when no trustworthy action exists.
            for _, entry in ipairs(plan.rows) do
                local _, uncertain = engine:Next(entry.id)
                if entry.state.status == "UNAVAILABLE" then groups.unavailable[#groups.unavailable + 1] = entry
                elseif entry.state.status == "UNKNOWN" or uncertain then groups.uncertain[#groups.uncertain + 1] = entry end
            end
            for _, group in ipairs({ "outside", "inside", "level", "progress", "uncertain", "unavailable" }) do
                if #groups[group] > 0 then
                    entries[#entries + 1] = { heading = "PREP_" .. group }
                    for _, entry in ipairs(groups[group]) do entries[#entries + 1] = entry end
                end
            end
        end
        if not current() then return end
        self.currentPlan.preparationEmpty = preparation and #plan.rows > 0 and #entries == 0
        if self.currentPlan.preparationEmpty then
            entries = { { heading = "PREPARATION_EMPTY", argument = addon.L("QUESTS") } }
        elseif #plan.rows == 0 then
            self.currentPlan.notice = #d.quests > 0 and "NO_CHARACTER_QUESTS" or "EMPTY"
            entries = { { heading = self.currentPlan.notice } }
        end
        local tree, treeBuilder = nil, addon.Clean(addon.QuestTree, "table")
        if not preparation and self.questTreeDungeon == d and self.questTreeRoot and treeBuilder then
            local build = addon.Clean(treeBuilder.Build, "function")
            tree = build and addon.Read(build, "table", addon.quests, engine, self.questTreeRoot)
            if not current() then return end
            if tree then
                local expanded, treeIDs, anchor = {}, {}, false
                local presentation = addon.Clean(tree.presentation, "table") or tree
                treeCurrent = addon.Clean(tree.current, "function")
                local names, counts = {}, {}
                for _, entry in ipairs(entries) do if entry.id == self.questTreeRoot then anchor = true end end
                anchor = anchor and #presentation > 1
                if anchor then
                    for _, node in ipairs(presentation) do
                        treeIDs[node.id] = true
                        local name = addon.Read(addon.QuestName, "string", node.id)
                        if not current() or not name then return end
                        names[node.id] = name; counts[name] = (counts[name] or 0) + 1
                    end
                end
                local seen = {}
                for _, entry in ipairs(entries) do
                    if entry.heading or (anchor and entry.id == self.questTreeRoot) or (not treeIDs[entry.id] and not seen[entry.id]) then
                        if anchor and entry.id == self.questTreeRoot then
                            expanded[#expanded + 1] = { anchorID = entry.id, title = names[entry.id] }
                            local last
                            for _, node in ipairs(presentation) do
                                if not seen[node.id] then
                                    local name = names[node.id]
                                    local branch = { id = node.id, state = node.state, tree = node, rootID = entry.id,
                                        title = name and (name .. (counts[name] > 1 and (" #" .. node.id) or "")) }
                                    expanded[#expanded + 1] = branch; seen[node.id] = true; last = branch
                                end
                            end
                            if last then last.treeLast = true end
                        else
                            expanded[#expanded + 1] = entry
                            if entry.id then seen[entry.id] = true end
                        end
                    end
                end
                entries = expanded
            end
        end
        treeCurrent = tree and addon.Clean(tree.current, "function")
        for _, entry in ipairs(entries) do
            local id, state = entry.id, entry.state
            local parentCurrent = current
            local infoModule = addon.Clean(addon.QuestRowInfo, "table")
            local infoGetter = infoModule and addon.Clean(infoModule.Get, "function")
            local info, infoCurrent
            if infoGetter and (id or entry.anchorID) then
                local ok, value, proof = pcall(infoGetter, addon.quests, id or entry.anchorID)
                if not parentCurrent() then return end
                if ok then info, infoCurrent = addon.Clean(value, "table"), addon.Clean(proof, "function") end
                if not infoCurrent then info = nil end
            end
            if infoCurrent then infoProofs[#infoProofs + 1] = infoCurrent end
            local function current()
                if not parentCurrent() then return false end
                if infoCurrent and addon.Read(infoCurrent, "boolean") ~= true then return false end
                return parentCurrent()
            end
            local function write(object, method, ...) return self:QuestListWrite(object, method, current, ...) end
            local title, note
            if entry.heading then title, note = addon.L(entry.heading, entry.argument), ""
            elseif entry.anchorID then title, note = entry.title, ""
            else
                title = entry.title or addon.QuestName(id)
                if not current() then return end
                if state.status == "UNAVAILABLE" then
                    note = audienceLabel(addon.quests[id], current)
                    if note == false then return end
                elseif entry.action then
                    local action = entry.action
                    note = addon.L(action.kind) .. (action.level and (" " .. action.level) or "")
                    if action.place then note = note .. " — " .. giverName(action.place) end
                elseif state.reason == "level" then
                    note = addon.L("level") .. " " .. addon.quests[id].minLevel
                end
                if not current() then return end
                note = "|cff" .. COLOR[state.status] .. statusLabel(state, note) .. "|r"
                if entry.tree and not entry.tree.root then
                    if entry.tree.requirementScope == "story" then
                        local parentName = addon.Read(addon.QuestName, "string", entry.tree.parentID)
                        if not current() then return end
                        parentName = parentName or ("#" .. entry.tree.parentID)
                        note = note .. "\n" .. addon.L("REQUIREMENT_FOR", parentName) .. " · " .. addon.L("REQUIREMENT_GROUP", entry.tree.group or 1)
                    end
                    note = note .. "\n" .. addon.L(entry.tree.relation == "story" and "STORY_GROUP_NOTICE" or "REQUIREMENT_NOTICE")
                    if entry.tree.alternatives and entry.tree.alternatives > 1 then note = note .. "\n" .. addon.L(entry.tree.mode == "active" and "REQUIREMENT_ACTIVE" or "REQUIREMENT_COMPLETE") end
                end
            end
            if not current() then return end
            n = n + 1
            local row = self:MakeRow(self.questList, self.rows, n, entry.heading and 32 or 30, current, true)
            if not current() then return end
            row.heading, row.questID, row.compact = entry.heading, id, not entry.heading and not preparation
            row.anchorQuestID = entry.anchorID
            row.questTreeAnchor = entry.anchorID ~= nil
            row.rowInfo, row.rowInfoCurrent = info, infoCurrent
            row.chainExpandable = not preparation and not entry.tree and info and addon.Clean(info.chain, "boolean") == true or false
            row.chainExpanded = row.chainExpandable and row.questTreeAnchor
            row.chainInset = row.compact and not entry.tree and 14 or 0
            local faction = info and addon.Clean(info.faction, "string")
            if faction ~= "Alliance" and faction ~= "Horde" then faction = nil end
            row.factionReserve = faction and 18 or 0
            row.questTreeSelected = id ~= nil and id == self.quest
            row.questTreePath = entry.tree and entry.tree.onTargetPath == true or false
            row.questTreeTarget = entry.tree ~= nil and id == entry.rootID
            row.questCompleted = state and state.status == "COMPLETED"
            row.questTreeNode = entry.tree ~= nil
            row.questTreeRoot = entry.rootID or entry.anchorID or id
            row.questTreeRelation = entry.tree and entry.tree.relation
            row.questTreeDepth = entry.tree and entry.tree.depth or 0
            row.questTreeIndent, row.questTreeInset = 0, entry.tree and 24 or 0
            row.dungeonTarget, row.dungeonName = targetSet[id] == true, heading
            row.dungeonBadgeVisible = row.dungeonTarget and row.questTreeNode
            local width = addon.Read(self.questList.GetWidth, "number", self.questList)
            if not current() or not width or width <= 28 or not write(row, "SetWidth", width - 4 - row.questTreeInset) then return end
            local function interactionCurrent() return current() and proveTree() and current() end
            row.questListCurrent = interactionCurrent
            if not write(row, "SetScript", "OnEnter", function() if interactionCurrent() then self:QuestListHint(row) end end) or
                not write(row, "SetScript", "OnLeave", function() self:HideNavigationHint() end) then return end
            local rewards = addon.Clean(addon.QuestListRewards, "table")
            local rewardPaint = rewards and addon.Clean(rewards.Paint, "function")
            local reserve = id and not entry.heading and rewardPaint and addon.Read(rewardPaint, "number", row, id, current) or 0
            if not current() then return end
            if not reserve or reserve < 0 or reserve > 100 then reserve = 0 end
            if (entry.heading or entry.anchorID) and rewards then addon.Read(rewards.Clear, "nil", row) end
            if not current() then return end
            local badge = row.dungeonBadge
            if row.dungeonBadgeVisible and not badge then
                local ok, texture = pcall(row.CreateTexture, row, nil, "ARTWORK")
                if not current() then return end
                if ok then row.dungeonBadge, badge = texture, texture end
            end
            if badge then
                if not write(badge, "Hide") then return end
                if row.dungeonBadgeVisible then
                    if not write(badge, "SetTexture", "Interface\\Icons\\INV_Misc_Map_01") or not write(badge, "SetSize", 12, 12) or
                        not write(badge, "ClearAllPoints") or not write(badge, "SetPoint", "TOPRIGHT", row, "TOPRIGHT", -6 - reserve, -9) or
                        not write(badge, "Show") then return end
                end
            end
            local targetLabel = row.dungeonTargetLabel
            local labelledTarget = row.dungeonTarget and row.questTreeNode
            if labelledTarget and not targetLabel then
                targetLabel = label(row, "", 0, 0, 92, 11)
                if not current() then return end
                row.dungeonTargetLabel = targetLabel
            end
            local targetLabelWidth = 0
            if targetLabel then
                if not write(targetLabel, "Hide") then return end
                if labelledTarget then
                    if not writeText(targetLabel, addon.L("DUNGEON_QUEST_SHORT")) then return end
                    targetLabelWidth = math.min(92, math.max(30, addon.Read(targetLabel.GetStringWidth, "number", targetLabel) or 72))
                    if not current() or not write(targetLabel, "SetWidth", targetLabelWidth) or
                        not write(targetLabel, "ClearAllPoints") or not write(targetLabel, "SetPoint", "TOPRIGHT", row, "TOPRIGHT", -24 - reserve, -8) or
                        not write(targetLabel, "SetTextColor", .96, .78, .35) or not write(targetLabel, "Show") then return end
                end
            end
            row.dungeonBadgeReserve = row.dungeonBadgeVisible and (22 + targetLabelWidth) or 0
            local branch = entry.tree and entry.tree.relation == "required" and (entry.tree.alternatives or 0) > 1 and entry.tree or nil
            local branchControl = row.branchControl
            if branch and not branchControl then
                branchControl = CreateFrame("Button", nil, row)
                branchControl.icon = branchControl:CreateTexture(nil, "ARTWORK")
                branchControl.icon:SetAllPoints()
                if not current() then return end
                row.branchControl = branchControl
            end
            row.branchReserve = branch and 22 or 0
            if branchControl then
                if not write(branchControl, "Hide") or not write(branchControl, "SetScript", "OnClick", nil) or
                    not write(branchControl, "SetScript", "OnEnter", nil) then return end
                if branch then
                    local choices = addon.Clean(character.choices, "table")
                    local groupChoices = choices and addon.Clean(choices[branch.parentID], "table")
                    local choice = groupChoices and addon.Clean(groupChoices[branch.group], "number")
                    local selected = choice == id
                    local function branchCurrent()
                        return interactionCurrent() and character.choices == choices and
                            (not choices or choices[branch.parentID] == groupChoices) and
                            (not groupChoices or addon.Clean(groupChoices[branch.group], "number") == choice) and interactionCurrent()
                    end
                    branchControl.branchChild, branchControl.branchGroup, branchControl.branchParent = branch.parentID, branch.group, id
                    branchControl.branchSelected = selected
                    if addon.Clean(branchControl.icon.SetAlpha, "function") and not write(branchControl.icon, "SetAlpha", selected and 1 or .25) then return end
                    if not write(branchControl, "SetSize", 18, 18) or not write(branchControl, "ClearAllPoints") or
                        not write(branchControl, "SetPoint", "TOPRIGHT", row, "TOPRIGHT", -6 - reserve - row.dungeonBadgeReserve, -6) or
                        not write(branchControl.icon, "SetTexture", selected and "Interface\\RaidFrame\\ReadyCheck-Ready" or "Interface\\Buttons\\WHITE8X8") or
                        not write(branchControl, "SetEnabled", state.status ~= "UNAVAILABLE") or
                        not write(branchControl, "SetScript", "OnClick", function()
                            if addon.Read(self.frame.IsShown, "boolean", self.frame) ~= true or not branchCurrent() or state.status == "UNAVAILABLE" then return end
                            if selected then self:ChooseBranch(branch.parentID, branch.group, nil)
                            else self:ChooseBranch(branch.parentID, branch.group, id) end
                        end) or not write(branchControl, "SetScript", "OnEnter", function()
                            if branchCurrent() then self:QuestListHint(row) end
                        end) or not write(branchControl, "SetScript", "OnLeave", function() self:HideNavigationHint() end) or
                        not write(branchControl, "Show") then return end
                end
            end
            row.statusBaseWidth = math.max(24, row:GetWidth() - 22 - reserve - row.dungeonBadgeReserve - row.factionReserve - row.chainInset - row.branchReserve)
            if not current() then return end
            if not self:PaintQuestRowStatus(row, entry, engine, current) then return end
            if not writeText(row.title, title) or not writeText(row.note, note) or
                not write(row, "SetEnabled", not entry.heading) then return end
            if entry.heading then
                if not write(row.bg, "SetColorTexture", 0.20, 0.22, 0.26, 1) or
                    not write(row, "SetScript", "OnClick", nil) then return end
            else
                if not write(row.bg, "SetColorTexture", 0.13, 0.16, 0.20, 1) or
                    not write(row, "SetScript", "OnClick", function()
                        if addon.Read(self.frame.IsShown, "boolean", self.frame) ~= true or not current() or not proveTree() or not current() then return end
                        local destination = entry.anchorID or id
                        if entry.anchorID then
                            self.questTreeRoot, self.questTreeDungeon = nil, nil
                        elseif not entry.tree then
                            if self.questTreeDungeon == d and self.questTreeRoot == destination and self.quest == destination then
                                self.questTreeRoot, self.questTreeDungeon = nil, nil
                            else self.questTreeRoot, self.questTreeDungeon = destination, d end
                        end
                        self:InspectQuest(destination, true)
                    end) then return end
            end
            if not current() then return end
            if type(row.title.SetTextColor) == "function" then
                local completed = state and state.status == "COMPLETED"
                if not write(row.title, "SetTextColor", completed and .52 or .92, completed and .62 or .91, completed and .55 or .87) then return end
            end
            local complete = row.compact and state and state.status == "COMPLETED"
            if complete and not row.completedStrike then
                local ok, texture = pcall(row.CreateTexture, row, nil, "ARTWORK")
                if not current() then return end
                if ok then row.completedStrike = texture end
            end
            local strike = row.completedStrike
            if strike then
                if not write(strike, "Hide") then return end
                if complete and type(strike.SetColorTexture) == "function" then
                    local width = addon.Read(row.title.GetStringWidth, "number", row.title) or row.statusBaseWidth - (row.statusInset or 0)
                    if not current() then return end
                    width = math.min(row.statusBaseWidth - (row.statusInset or 0), math.max(1, width))
                    if not write(strike, "SetColorTexture", .5, .65, .55, .65) or not write(strike, "SetSize", width, 1) or
                        not write(strike, "ClearAllPoints") or not write(strike, "SetPoint", "TOPLEFT", row.title, "TOPLEFT", 0, -9) or
                        not write(strike, "Show") then return end
                end
            end
            offset = self:LayoutRow(row, entry.heading and 32 or (preparation and 59 or 30), offset, current)
            if not offset then return end
            local factionIcon = row.factionIcon
            if faction and not factionIcon then
                local ok, value = pcall(row.CreateTexture, row, nil, "ARTWORK")
                if not current() then return end
                if ok then row.factionIcon, factionIcon = value, value end
            end
            if factionIcon then
                if not write(factionIcon, "Hide") then return end
                local atlas = faction and AUDIENCE_ICONS.factions[faction]
                local width = atlas and addon.Read(row.title.GetStringWidth, "number", row.title)
                local cap = atlas and addon.Read(row.title.GetWidth, "number", row.title)
                if not current() then return end
                if width and width >= 0 and cap and cap > 0 and addon.Clean(factionIcon.SetAtlas, "function") then
                    local painted = write(factionIcon, "SetAtlas", atlas)
                    if not current() then return end
                    if painted and addon.Read(factionIcon.GetAtlas, "string", factionIcon) == atlas then
                        if not current() or not write(factionIcon, "SetSize", 14, 14) or not write(factionIcon, "ClearAllPoints") or
                            not write(factionIcon, "SetPoint", "TOPLEFT", row.title, "TOPLEFT", math.min(width, cap) + 4, -2) or
                            not write(factionIcon, "Show") then return end
                    end
                end
            end
            if not current() then return end
            if row.chainExpandable and not row.chainChevron then
                local ok, first, second = pcall(function() return row:CreateTexture(nil, "ARTWORK"), row:CreateTexture(nil, "ARTWORK") end)
                if not current() then return end
                if ok then row.chainChevron = { first, second } end
            end
            for index, segment in ipairs(row.chainChevron or {}) do
                if not write(segment, "Hide") then return end
                if row.chainExpandable and addon.Clean(segment.SetRotation, "function") then
                    local x = row.chainExpanded and (index == 1 and 10 or 15) or 12
                    local cy = row.chainExpanded and -14 or (index == 1 and -12 or -17)
                    if not write(segment, "SetTexture", "Interface\\Buttons\\WHITE8X8") or not write(segment, "SetSize", 7, 2) or
                        not write(segment, "ClearAllPoints") or not write(segment, "SetPoint", "CENTER", row, "TOPLEFT", x, cy) or
                        not write(segment, "SetRotation", (index == 1 and -1 or 1) * math.pi / 4) or not write(segment, "Show") then return end
                end
            end
            if entry.tree and not row.treeRail then
                local ok, rail, elbow = pcall(function() return row:CreateTexture(nil, "ARTWORK"), row:CreateTexture(nil, "ARTWORK") end)
                if not current() then return end
                if ok then row.treeRail, row.treeElbow = rail, elbow end
            end
            for _, connector in ipairs({ row.treeRail, row.treeElbow }) do if not write(connector, "Hide") then return end end
            if entry.tree and row.treeRail and row.treeElbow then
                for _, connector in ipairs({ row.treeRail, row.treeElbow }) do
                    if not write(connector, "SetColorTexture", row.questTreePath and .9 or .32, row.questTreePath and .69 or .48, row.questTreePath and .3 or .57, .85) or not write(connector, "ClearAllPoints") then return end
                end
                local height = addon.Read(row.GetHeight, "number", row)
                if not current() or not height or not write(row.treeRail, "SetSize", 1, entry.treeLast and 18 or height + 2) or
                    not write(row.treeRail, "SetPoint", "TOPLEFT", row, "TOPLEFT", -12, 2) or
                    not write(row.treeElbow, "SetSize", 12, 1) or not write(row.treeElbow, "SetPoint", "TOPLEFT", row, "TOPLEFT", -12, -15) or
                    not write(row.treeRail, "Show") or not write(row.treeElbow, "Show") then return end
            end
            styleRow(row, entry.heading and "section" or "quest", id ~= nil and id == self.quest and not entry.heading)
            if not current() then return end
        end
    else
        local row = self:MakeRow(self.questList, self.rows, 1, 32, current, true)
        n = 1; row.heading, row.questID, row.compact = "PICK", nil, false
        row.questTreeNode, row.questTreeIndent, row.questTreeInset = false, 0, 0
        row.questTreeAnchor, row.anchorQuestID, row.questTreeSelected, row.questTreePath, row.questTreeTarget = false, nil, false, false, false
        row.dungeonTarget, row.dungeonBadgeVisible, row.dungeonBadgeReserve, row.statusInset, row.questCompleted = false, false, 0, 0, false
        row.rowInfo, row.rowInfoCurrent, row.chainExpandable, row.chainExpanded, row.chainInset, row.factionReserve, row.branchReserve = nil, nil, false, false, 0, 0, 0
        row.questListCurrent = current
        local rewards = addon.Clean(addon.QuestListRewards, "table")
        if rewards then addon.Read(rewards.Clear, "nil", row) end
        if not current() then return end
        for _, segment in ipairs(row.chainChevron or {}) do if not write(segment, "Hide") then return end end
        for _, field in ipairs({ "factionIcon", "dungeonBadge", "dungeonTargetLabel", "statusIcon", "completedStrike", "treeRail", "treeElbow", "branchControl" }) do
            if row[field] and not write(row[field], "Hide") then return end
        end
        if not write(row, "SetWidth", self.questList:GetWidth() - 4) or not write(row.title, "SetWidth", self.questList:GetWidth() - 22) then return end
        if not writeText(row.title, addon.L("PICK")) or not writeText(row.note, "") then return end
        offset = self:LayoutRow(row, 32, 0, current)
        if not offset then return end
    end
    local headingHeight = math.max(26, measuredHeight(self.heading, 26))
    if not current() then return end
    local listY = 66 + headingHeight + 8
    if not write(self.questScroll, "ClearAllPoints") or not write(self.questScroll, "SetPoint", "TOPLEFT", 278, -listY) or
        not write(self.questScroll, "SetHeight", math.max(80, 688 - listY)) or
        not write(self.detailScroll, "ClearAllPoints") or not write(self.detailScroll, "SetPoint", "TOPLEFT", 674, -66) or
        not write(self.detailScroll, "SetHeight", 622) then return end
    for index = n + 1, #self.rows do
        local row = self.rows[index]
        if not write(row, "Hide") then return end
        local rewards = addon.Clean(addon.QuestListRewards, "table")
        if rewards then addon.Read(rewards.Clear, "nil", row) end
        if not current() then return end
    end
    if not write(self.questList, "SetHeight", math.max(1, offset)) then return end
    -- Publish only after every reused row has its new text, geometry and owner.
    if not proveInfos() then return end
    for index = 1, n do if not write(self.rows[index], "Show") then return end end
    if not proveInfos() then return end
    local identity = d and (addon.Clean(d.key, "string") or d)
    if not current() then return end
    if self.questListDungeon ~= identity then
        self.questListDungeon = identity
        write(self.questScroll, "SetVerticalScroll", 0)
    end
    if not current() then return end
    local rewards, cache = addon.Clean(addon.QuestListRewards, "table"), addon.Clean(addon.RewardCache, "table")
    local pending = rewards and addon.Clean(rewards.Pending, "function")
    if cache and pending then
        local cold, frame = {}, self.frame
        for index = 1, n do
            local id = addon.Read(pending, "number", self.rows[index])
            if not current() then return end
            if id then cold[#cold + 1] = id end
        end
        local function visibleCurrent()
            local function owned()
                local valid = addon.UI == self and self.frame == frame and self.questListGeneration == generation and
                    self.engine == engine and self.dungeon == d and addon.char == character and not treeFailed and not infoFailed and
                    self.preparation == preparation and self.includeUnavailable == includeUnavailable and
                    (not d or (d.quests == targets and #targets == #targetIDs))
                if not valid then return false end
                for index, id in ipairs(targetIDs) do if targets[index] ~= id then return false end end
                return true
            end
            if not owned() or addon.Read(frame.IsShown, "boolean", frame) ~= true then return false end
            if engine and addon.Read(engine.Current, "boolean", engine) ~= true then return false end
            return owned()
        end
        addon.Read(cache.Watch, "nil", self, cold, visibleCurrent, function()
            if visibleCurrent() then addon.Notify("data") end
        end)
        proveInfos()
    end
    end
    local ok, failure = pcall(function() render(); proveInfos() end)
    rendering = false
    if not ok then retireInfos(); error(failure, 0) end
end

local function rewardData(id)
    local value = addon.Read(addon.DialogueRewards, "table", id)
    if value then return value, "dialogue" end
    value = addon.Read(addon.QuestRewards, "table", id)
    if value then return value, "log" end
    return addon.Read(addon.CachedQuestRewards, "table", id), "cache"
end

local function tooltipMethod(tooltip, key)
    return addon.Read(function() return tooltip[key] end, "function")
end

function UI:ReleaseRewardTooltip(expected)
    local held = self.rewardTooltip
    if not held or (expected and held ~= expected) then return end
    local owned = addon.Read(held.isOwned, "boolean", held.tooltip, held.button)
    if self.rewardTooltip ~= held then return end
    self.rewardTooltip = nil
    if owned == true and tooltipMethod(held.tooltip, "Hide") == held.hide then
        pcall(held.hide, held.tooltip)
    end
end

function UI:SetRewardTexture(icon, texture)
    if self.rewardTextureBusy then return false end
    self.rewardTextureBusy = true
    local ok, rendered = pcall(icon.SetTexture, icon, texture)
    self.rewardTextureBusy = false
    return ok and addon.Clean(rendered, "boolean") == true
end

function UI:ResetRewardPresentation()
    local generation = {}
    self.rewardGeneration = generation
    self:ReleaseRewardTooltip()
    if self.rewardGeneration ~= generation then return nil end
    self:ReleaseObjectiveTooltip()
    if self.rewardGeneration ~= generation then return nil end
    self.rewardButtons = self.rewardButtons or {}
    for _, button in ipairs(self.rewardButtons) do
        button.rewardBinding = nil
        button:SetScript("OnEnter", nil); button:SetScript("OnLeave", nil); button:SetScript("OnHide", nil)
        button:Hide(); button.icon:Hide(); self:SetRewardTexture(button.icon, nil)
        if self.rewardGeneration ~= generation then return nil end
    end
    self.objectiveButtons = self.objectiveButtons or {}
    for _, button in ipairs(self.objectiveButtons) do
        button.objectiveBinding = nil
        button:SetScript("OnEnter", nil); button:SetScript("OnLeave", nil); button:SetScript("OnHide", nil)
        button:Hide(); button.icon:Hide(); self:SetRewardTexture(button.icon, nil)
        if self.rewardGeneration ~= generation then return nil end
    end
    return generation
end

function UI:RewardBindingCurrent(button, binding)
    local function same()
        return self.rewardGeneration == binding.generation and self.quest == binding.quest and
            button.rewardBinding == binding and addon.DialogueRewards == binding.dialogue and
            addon.QuestRewards == binding.log and addon.CachedQuestRewards == binding.cache
    end
    if not same() or addon.Read(self.frame.IsShown, "boolean", self.frame) ~= true or
        addon.Read(button.IsShown, "boolean", button) ~= true then return false end
    local fresh, origin = rewardData(binding.quest)
    if not same() or not fresh or origin ~= binding.origin or
        addon.Clean(fresh.source, "string") ~= binding.source or addon.Clean(fresh.hidden, "boolean") == true then return false end
    local entries = addon.Clean(fresh[binding.kind], "table")
    local item = entries and addon.Clean(entries[binding.index], "table")
    return item ~= nil and addon.Clean(item.id, "number") == binding.id and same()
end

function UI:EnterReward(button, binding)
    if not self:RewardBindingCurrent(button, binding) then
        local held = self.rewardTooltip
        if held and held.binding == binding then self:ReleaseRewardTooltip(held) end
        return
    end
    local tooltip = addon.Clean(GameTooltip, "table") or addon.Clean(GameTooltip, "userdata")
    if not tooltip then return end
    local held = { tooltip = tooltip, button = button, binding = binding,
        setOwner = tooltipMethod(tooltip, "SetOwner"), setItem = tooltipMethod(tooltip, "SetItemByID"),
        isOwned = tooltipMethod(tooltip, "IsOwned"), hide = tooltipMethod(tooltip, "Hide") }
    if not held.setOwner or not held.setItem or not held.isOwned or not held.hide then return end
    local priorObjective, priorReward = self.objectiveTooltip, self.rewardTooltip
    self:ReleaseObjectiveTooltip(priorObjective)
    if self.rewardTooltip ~= priorReward or self.objectiveTooltip then return end
    self:ReleaseRewardTooltip(priorReward)
    if self.rewardTooltip or self.objectiveTooltip or not self:RewardBindingCurrent(button, binding) then return end
    self.rewardTooltip = held
    local function current()
        return self.rewardTooltip == held and GameTooltip == tooltip and
            tooltipMethod(tooltip, "SetOwner") == held.setOwner and tooltipMethod(tooltip, "SetItemByID") == held.setItem and
            tooltipMethod(tooltip, "IsOwned") == held.isOwned and tooltipMethod(tooltip, "Hide") == held.hide and
            self:RewardBindingCurrent(button, binding) and self.rewardTooltip == held
    end
    button:SetScript("OnLeave", function()
        if self.rewardGeneration == binding.generation and button.rewardBinding == binding then self:ReleaseRewardTooltip(held) end
    end)
    local ok = pcall(held.setOwner, tooltip, button, "ANCHOR_RIGHT")
    if not ok or not current() then self:ReleaseRewardTooltip(held); return end
    local owned = addon.Read(held.isOwned, "boolean", tooltip, button)
    if owned ~= true or not current() then self:ReleaseRewardTooltip(held); return end
    local shown
    ok, shown = pcall(held.setItem, tooltip, binding.id)
    shown = addon.Clean(shown, "boolean")
    if not ok or shown ~= true or not current() then self:ReleaseRewardTooltip(held); return end
    owned = addon.Read(held.isOwned, "boolean", tooltip, button)
    if owned ~= true or not current() then self:ReleaseRewardTooltip(held) end
end

function UI:ReleaseObjectiveTooltip(expected)
    local held = self.objectiveTooltip
    if not held or (expected and held ~= expected) then return end
    local owned = addon.Read(held.isOwned, "boolean", held.tooltip, held.button)
    if self.objectiveTooltip ~= held then return end
    self.objectiveTooltip = nil
    if owned == true and tooltipMethod(held.tooltip, "Hide") == held.hide then pcall(held.hide, held.tooltip) end
end

function UI:ObjectiveBindingCurrent(button, binding)
    if not binding.current() or button.objectiveBinding ~= binding or self.rewardGeneration ~= binding.generation then return false end
    return addon.Read(self.frame.IsShown, "boolean", self.frame) == true and
        addon.Read(button.IsShown, "boolean", button) == true and binding.current() and button.objectiveBinding == binding
end

function UI:EnterObjective(button, binding)
    if not self:ObjectiveBindingCurrent(button, binding) then
        local held = self.objectiveTooltip
        if held and held.binding == binding then self:ReleaseObjectiveTooltip(held) end
        return
    end
    local tooltip = addon.Clean(GameTooltip, "table") or addon.Clean(GameTooltip, "userdata")
    if not tooltip then return end
    local held = { tooltip = tooltip, button = button, binding = binding,
        setOwner = tooltipMethod(tooltip, "SetOwner"), setItem = tooltipMethod(tooltip, "SetItemByID"),
        addLine = tooltipMethod(tooltip, "AddLine"), show = tooltipMethod(tooltip, "Show"),
        isOwned = tooltipMethod(tooltip, "IsOwned"), hide = tooltipMethod(tooltip, "Hide") }
    if not held.setOwner or not held.setItem or not held.isOwned or not held.hide then return end
    local priorReward, priorObjective = self.rewardTooltip, self.objectiveTooltip
    self:ReleaseRewardTooltip(priorReward)
    if self.objectiveTooltip ~= priorObjective or self.rewardTooltip then return end
    self:ReleaseObjectiveTooltip(priorObjective)
    if self.objectiveTooltip or self.rewardTooltip or not self:ObjectiveBindingCurrent(button, binding) then return end
    self.objectiveTooltip = held
    local function current()
        return self.objectiveTooltip == held and GameTooltip == tooltip and
            tooltipMethod(tooltip, "SetOwner") == held.setOwner and tooltipMethod(tooltip, "SetItemByID") == held.setItem and
            tooltipMethod(tooltip, "IsOwned") == held.isOwned and tooltipMethod(tooltip, "Hide") == held.hide and
            tooltipMethod(tooltip, "AddLine") == held.addLine and tooltipMethod(tooltip, "Show") == held.show and
            self:ObjectiveBindingCurrent(button, binding) and self.objectiveTooltip == held
    end
    button:SetScript("OnLeave", function()
        if self.rewardGeneration == binding.generation and button.objectiveBinding == binding then self:ReleaseObjectiveTooltip(held) end
    end)
    local ok = pcall(held.setOwner, tooltip, button, "ANCHOR_RIGHT")
    if not ok or not current() then self:ReleaseObjectiveTooltip(held); return end
    local owned = addon.Read(held.isOwned, "boolean", tooltip, button)
    if owned ~= true or not current() then self:ReleaseObjectiveTooltip(held); return end
    local shown
    ok, shown = pcall(held.setItem, tooltip, binding.id)
    if not ok or addon.Clean(shown, "boolean") ~= true or not current() then self:ReleaseObjectiveTooltip(held); return end
    owned = addon.Read(held.isOwned, "boolean", tooltip, button)
    if owned ~= true or not current() then self:ReleaseObjectiveTooltip(held); return end
    local context = addon.Clean(binding.context, "string")
    if context and held.addLine and held.show then
        ok = pcall(held.addLine, tooltip, context, .7, .75, .8, true)
        owned = addon.Read(held.isOwned, "boolean", tooltip, button)
        if not ok or owned ~= true or not current() then self:ReleaseObjectiveTooltip(held); return end
        ok = pcall(held.show, tooltip)
        owned = addon.Read(held.isOwned, "boolean", tooltip, button)
        if not ok or owned ~= true or not current() then self:ReleaseObjectiveTooltip(held) end
    end
end

function UI:ResetQuestLogControl()
    local revision, control = {}, self.questLogButton
    self.questLogGeneration = revision
    if control then
        local function clear(method, ...)
            pcall(control[method], control, ...)
            return self.questLogGeneration == revision
        end
        if not clear("Hide") or not clear("SetEnabled", false) or not clear("SetScript", "OnClick", nil) then return false end
    end
    return true
end

function UI:SourceStory(id, definition, current)
    local checker, source = issecretvalue, definition.storylineGroups or definition.storyline
    local grouped = definition.storylineGroups ~= nil
    if not addon.Clean(source, "table") then return nil end
    local snapshots, distinct, count = {}, {}, 0
    local function capture(list)
        local length = #list
        if length < 1 or length > 100 then return false end
        local copy = { list = list, length = length, values = {} }
        snapshots[#snapshots + 1] = copy
        for index = 1, length do copy.values[index] = rawget(list, index) end
        return copy
    end
    local top = capture(source)
    if not top then return nil end
    local function add(value)
        local clean = addon.Clean(value, "number")
        if not clean or clean <= 0 or clean > 9007199254740991 or clean % 1 ~= 0 then return false end
        if not distinct[clean] then distinct[clean] = true; count = count + 1 end
        return true
    end
    for index = 1, top.length do
        if grouped then
            local group = addon.Clean(top.values[index], "table")
            local copy = group and capture(group)
            if not copy then return nil end
            for other = 1, copy.length do if not add(copy.values[other]) then return nil end end
        elseif not add(top.values[index]) then return nil end
    end
    local function same()
        local ok, valid = pcall(function()
            if issecretvalue ~= checker or addon.quests[id] ~= definition or
                definition.storylineGroups ~= (grouped and source or nil) or
                (not grouped and definition.storyline ~= source) then return false end
            for _, copy in ipairs(snapshots) do
                if #copy.list ~= copy.length then return false end
                for index = 1, copy.length do if rawget(copy.list, index) ~= copy.values[index] then return false end end
            end
            return true
        end)
        return ok and valid == true
    end
    if not same() or not current() then return nil end
    self.storyStates, self.storyOrder = self.storyStates or {}, self.storyOrder or {}
    local record = self.storyStates[id]
    if not record or record.definition ~= definition or not record.same() then
        record = { definition = definition, same = same, count = count, expanded = count <= 4 }
        if not self.storyStates[id] then
            self.storyOrder[#self.storyOrder + 1] = id
            if #self.storyOrder > 100 then self.storyStates[table.remove(self.storyOrder, 1)] = nil end
        end
        self.storyStates[id] = record
    end
    return record
end

function UI:RefreshDetail()
    local renderQuest, renderDungeon = self.quest, self.dungeon
    local renderEngine, renderCharacter, pendingAction, pendingGiver = self.engine, addon.char, nil, nil
    local rewardGeneration = self:ResetRewardPresentation()
    if not rewardGeneration or self.quest ~= renderQuest then return end
    self:HideNavigationHint()
    if self.rewardGeneration ~= rewardGeneration or self.quest ~= renderQuest or self.dungeon ~= renderDungeon or
        self.engine ~= renderEngine or addon.char ~= renderCharacter then return end
    if self.detailReferenceQuest ~= renderQuest or self.detailReferenceDungeon ~= renderDungeon then
        self.detailReferencesExpanded, self.detailChainExpanded, self.detailNarrativeExpanded = false, false, false
        local selected = renderQuest and addon.quests[renderQuest]
        if selected and selected.requires and #selected.requires > 0
            and not selected.storyline and not selected.storylineGroups then
            local seen, count = {}, 0
            local function countSteps(questID, depth)
                if seen[questID] or count > 6 or depth > 50 then return end
                seen[questID], count = true, count + 1
                local source = addon.quests[questID]
                for _, group in ipairs(source and source.requires or {}) do
                    for _, parent in ipairs(group.ids) do
                        countSteps(parent, depth + 1)
                        if count > 6 then return end
                    end
                end
            end
            countSteps(renderQuest, 0)
            self.detailChainExpanded = count <= 6
        end
        self.detailReferenceQuest, self.detailReferenceDungeon = renderQuest, renderDungeon
    end
    local referencesExpanded, chainExpanded = self.detailReferencesExpanded == true, self.detailChainExpanded == true
    local narrativeExpanded = self.detailNarrativeExpanded == true
    local overviewIdentity = not renderQuest and renderDungeon and (addon.Clean(renderDungeon.key, "string") or renderDungeon) or nil
    if self.renderedQuest ~= self.quest or self.renderedOverview ~= overviewIdentity then
        self:CloseCopyLink()
        self.detailActionChoice = nil
        self.detailScroll:SetVerticalScroll(0)
        self.renderedQuest, self.renderedOverview = self.quest, overviewIdentity
        self.reportedExpanded = {}
    end
    self:RefreshQuestStyles()
    if self.rewardGeneration ~= rewardGeneration or self.quest ~= renderQuest then return end
    local pool, n, y = self.details, 0, 0
    local detailWidth = addon.Read(self.detail.GetWidth, "number", self.detail)
    if self.rewardGeneration ~= rewardGeneration or self.quest ~= renderQuest or self.dungeon ~= renderDungeon then return end
    local contentWidth = detailWidth and detailWidth > 56 and detailWidth < 2000 and detailWidth - 8 or 334
    self.reportedExpanded = self.reportedExpanded or {}
    self.reportedToggles, self.reportedRows = self.reportedToggles or {}, self.reportedRows or {}
    local reportedGeneration, toggleIndex, reportIndex = {}, 0, 0
    self.reportedGeneration = reportedGeneration
    for _, buttons in ipairs({ self.reportedToggles, self.reportedRows }) do
        for _, row in ipairs(buttons) do row:Hide(); row:SetEnabled(false); row:SetScript("OnClick", nil) end
    end
    local function portraitCardCurrent()
        return self.quest == renderQuest and self.dungeon == renderDungeon and self.engine == renderEngine and
            addon.char == renderCharacter and self.rewardGeneration == rewardGeneration and
            (self.detailReferencesExpanded == true) == referencesExpanded and (self.detailChainExpanded == true) == chainExpanded and
            (self.detailNarrativeExpanded == true) == narrativeExpanded
    end
    self.clientWaypointBinding = nil
    if self.clientWaypointButton then
        local busy = self.clientWaypointWriteBusy
        if not busy then self.clientWaypointWriteBusy = {} end
        pcall(self.clientWaypointButton.Hide, self.clientWaypointButton)
        if not busy then self.clientWaypointWriteBusy = nil end
        if not portraitCardCurrent() then return end
    end
    local previousPaymentLine, previousPaymentBinding = self.heldPaymentDetail, self.heldPaymentBinding
    self.heldPaymentDetail, self.heldPaymentBinding = nil, nil
    if previousPaymentLine then
        previousPaymentLine:Hide()
        if not portraitCardCurrent() then
            local newer = self.heldPaymentBinding
            if newer and newer ~= previousPaymentBinding and newer.field == previousPaymentLine and
                self.heldPaymentDetail == previousPaymentLine and addon.Read(newer.current, "boolean") == true and
                self.heldPaymentBinding == newer and self.heldPaymentDetail == previousPaymentLine then
                pcall(previousPaymentLine.Show, previousPaymentLine)
            end
            return
        end
    end
    for _, field in ipairs({ "portrait", "giverPortrait" }) do
        local texture = self[field]
        if texture then
            texture:Hide()
            if not self.portraitRenderBusy then
                self.portraitRenderBusy = true
                pcall(texture.SetTexture, texture, nil)
                self.portraitRenderBusy = nil
                if not portraitCardCurrent() then return end
            end
        end
    end
    if self.overviewArt then self.overviewArt:Hide() end
    self.action = nil
    self.giverAction, self.giverHasCoordinates, self.giverBinding = nil, false, nil
    self:SetFooterEnabled(self.giver, false)
    self:SetFooterLabel(self.giver, "VISIT_GIVER")
    local rewardIndex, objectiveIndex = 0, 0
    local function line(value, style, reward, objective, ownerCurrent)
        if ownerCurrent and not ownerCurrent() then return false end
        local function write(object, method, ...)
            if ownerCurrent and not ownerCurrent() then return false end
            local binding
            if method == "SetText" then
                binding = { current = ownerCurrent or portraitCardCurrent, value = (...), quest = renderQuest,
                    dungeon = renderDungeon, engine = renderEngine, character = renderCharacter, generation = rewardGeneration }
                object.detailTextBinding = binding
            end
            object[method](object, ...)
            if ownerCurrent and not ownerCurrent() then
                local newer = binding and object.detailTextBinding
                if newer and newer ~= binding and not object.detailTextRepair and addon.Read(newer.current, "boolean") == true and
                    object.detailTextBinding == newer then
                    local repair = {}
                    object.detailTextRepair = repair
                    local fresh = addon.Read(newer.current, "boolean")
                    if fresh == true and object.detailTextBinding == newer and object.detailTextRepair == repair and
                        self.quest == newer.quest and self.dungeon == newer.dungeon and self.engine == newer.engine and
                        addon.char == newer.character and self.rewardGeneration == newer.generation then
                        pcall(object.SetText, object, newer.value)
                    end
                    if object.detailTextRepair == repair then object.detailTextRepair = nil end
                end
                return false
            end
            return true
        end
        style = DETAIL_STYLES[style] and style or "body"
        local format = DETAIL_STYLES[style]
        local height = format.minimum
        y = y + (format.before or 0)
        n = n + 1
        local fs = pool[n]
        if not fs then
            fs = label(self.detail, "", 4, 0, contentWidth, 13)
            if ownerCurrent and not ownerCurrent() then return false end
            pool[n] = fs
        end
        local font = setFont(fs, format.size)
        if ownerCurrent and not ownerCurrent() then return false end
        if fs.detailStyle ~= style or fs.detailFont ~= font then fs.measuredHeight = nil end
        fs.detailStyle, fs.detailFont = style, font
        if not write(fs, "SetTextColor", unpack(format.color)) or not write(fs, "SetWidth", style == "title" and contentWidth - 80 or contentWidth) or
            not write(fs, "ClearAllPoints") or not write(fs, "SetPoint", "TOPLEFT", 4, -y) or
            not write(fs, "SetText", value) or not write(fs, "Show") then return false end
        local itemID = reward and addon.Clean(reward.item.id, "number")
        local texture = reward and (addon.Clean(reward.item.texture, "string") or addon.Clean(reward.item.texture, "number"))
        local validTexture = type(texture) == "string" and texture ~= "" and #texture <= 1024 or
            type(texture) == "number" and texture > 0 and texture % 1 == 0
        if itemID and itemID > 0 and itemID % 1 == 0 and validTexture and rewardIndex < 200 and not self.rewardTextureBusy then
            rewardIndex = rewardIndex + 1
            local b = self.rewardButtons[rewardIndex]
            if not b then
                b = CreateFrame("Button", nil, self.detail); b:SetSize(32, 32)
                b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints()
                self.rewardButtons[rewardIndex] = b
            end
            local rendered = self:SetRewardTexture(b.icon, texture)
            if self.rewardGeneration ~= rewardGeneration or self.quest ~= renderQuest then return false end
            if rendered then
                local binding = { quest = renderQuest, generation = rewardGeneration, id = itemID,
                    origin = reward.origin, source = reward.source, kind = reward.kind, index = reward.index,
                    dialogue = addon.DialogueRewards, log = addon.QuestRewards, cache = addon.CachedQuestRewards }
                b.rewardBinding = binding
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", 4, -y); b.icon:Show(); b:Show()
                b:SetScript("OnEnter", function() self:EnterReward(b, binding) end)
                b:SetScript("OnHide", function()
                    local held = self.rewardTooltip
                    if held and held.binding == binding and b.rewardBinding == binding then self:ReleaseRewardTooltip(held) end
                end)
                b:SetSize(32, 32)
                fs:SetWidth(contentWidth - 40); fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 44, -y)
                height = math.max(height or 18, 32)
            else
                b.icon:Hide(); self:SetRewardTexture(b.icon, nil)
                if self.rewardGeneration ~= rewardGeneration or self.quest ~= renderQuest then return false end
            end
        end
        if objective and not self.rewardTextureBusy then
            objectiveIndex = objectiveIndex + 1
            local button = self.objectiveButtons[objectiveIndex]
            if not button then
                button = CreateFrame("Button", nil, self.detail); button:SetSize(24, 24)
                button.icon = button:CreateTexture(nil, "ARTWORK"); button.icon:SetAllPoints()
                self.objectiveButtons[objectiveIndex] = button
            end
            local rendered = self:SetRewardTexture(button.icon, objective.texture)
            if self.rewardGeneration ~= rewardGeneration or self.quest ~= renderQuest or not objective.current() then return false end
            if rendered then
                objective.generation = rewardGeneration; button.objectiveBinding = objective
                button:ClearAllPoints(); button:SetPoint("TOPLEFT", 4, -y); button.icon:Show(); button:Show()
                button:SetScript("OnEnter", function() self:EnterObjective(button, objective) end)
                button:SetScript("OnHide", function()
                    local held = self.objectiveTooltip
                    if held and held.binding == objective and button.objectiveBinding == objective then self:ReleaseObjectiveTooltip(held) end
                end)
                fs:SetWidth(contentWidth - 30); fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 34, -y)
                height = math.max(height or 18, 24)
            else
                button.icon:Hide(); self:SetRewardTexture(button.icon, nil)
                if self.rewardGeneration ~= rewardGeneration or self.quest ~= renderQuest or not objective.current() then return false end
            end
        end
        local measured = measuredHeight(fs, height or 18)
        if ownerCurrent and not ownerCurrent() then return false end
        y = y + math.max(height or 18, measured) + (format.gap or 8)
        return true
    end
    if self.narrativeToggle then
        for _, operation in ipairs({ { "Hide" }, { "SetEnabled", false }, { "SetScript", "OnClick", nil } }) do
            if not self:QuestListWrite(self.narrativeToggle, operation[1], portraitCardCurrent, unpack(operation, 2)) then return end
        end
    end
    if self.storyToggle then self.storyToggle:Hide(); self.storyToggle:SetEnabled(false); self.storyToggle:SetScript("OnClick", nil) end
    if self.referenceToggle then self.referenceToggle:Hide(); self.referenceToggle:SetEnabled(false); self.referenceToggle:SetScript("OnClick", nil) end
    for _, b in ipairs(self.chainButtons) do b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil) end
    for _, buttons in ipairs({ self.actionButtons, self.actionInspectButtons, self.preparationForButtons }) do
        for _, b in ipairs(buttons) do b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil) end
    end
    for _, b in ipairs(self.branchButtons) do b:Hide() end
    for _, b in ipairs(self.branchInspectButtons) do b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil) end
    for _, b in ipairs(self.requirementButtons) do b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil) end
    for _, b in ipairs(self.materialButtons) do b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil) end
    for _, buttons in ipairs({ self.startButtons, self.finishButtons, self.containerButtons, self.dropButtons, self.objectiveContainerButtons, self.giverButtons }) do
        for _, b in ipairs(buttons) do
            b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil)
        end
    end
    if not self:ResetQuestLogControl() or not portraitCardCurrent() then return end
    self:RefreshEntrance()
    if not portraitCardCurrent() then return end
    local id, engine = self.quest, self.engine
    if id then
        local definition = addon.quests[id]
        local q = definition or {}
        do
            local titleGetter, titleChecker = addon.QuestName, issecretvalue
            local function titleCurrent()
                return portraitCardCurrent() and addon.quests[id] == definition and addon.QuestName == titleGetter and issecretvalue == titleChecker
            end
            local title = addon.Read(titleGetter, "string", id)
            if not titleCurrent() then return end
            if not title then
                local sourceName = addon.Clean(q.name, "string")
                title = sourceName and #sourceName <= 1024 and sourceName:find("%S") and sourceName or ("#" .. id)
            end
            if not titleCurrent() or line(title, "title", nil, nil, titleCurrent) == false then return end
        end
        local state = engine:State(id)
        local logCapability, logOpener = addon.CanOpenQuestLog, addon.OpenQuestLogQuest
        local logRevision, logChecker = self.questLogGeneration, issecretvalue
        local logFrame = self.frame
        local logShown = logFrame.IsShown
        local function logCurrent()
            return portraitCardCurrent() and addon.UI == self and self.frame == logFrame and
                logFrame.IsShown == logShown and
                addon.quests[id] == definition and self.questLogGeneration == logRevision and
                addon.CanOpenQuestLog == logCapability and addon.OpenQuestLogQuest == logOpener and issecretvalue == logChecker
        end
        local canOpen = addon.Read(logCapability, "boolean", id)
        local usableOpener = addon.Clean(logOpener, "function")
        if not logCurrent() then return end
        if canOpen == true and usableOpener then
            local control = self.questLogButton
            if not control then
                control = CreateFrame("Button", nil, self.detail); control:Hide(); control:SetWidth(contentWidth)
                control.label = label(control, "", 7, -5, contentWidth - 14, 14)
                control.title = control.label
                control:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                if not logCurrent() then return end
                self.questLogButton = control
            end
            local function write(object, method, ...)
                if not logCurrent() then return false end
                local ok = pcall(object[method], object, ...)
                return ok and logCurrent()
            end
            if not write(control.label, "SetText", addon.L("OPEN_QUEST_LOG")) then return end
            local height = math.max(28, measuredHeight(control.label, 18) + 10)
            if not logCurrent() then return end
            styleRow(control, "control", false)
            if not logCurrent() then return end
            if not write(control, "SetHeight", height) or not write(control, "ClearAllPoints") or
                not write(control, "SetPoint", "TOPLEFT", 4, -y) or not write(control, "SetEnabled", true) or
                not write(control, "SetScript", "OnClick", function()
                    if self.questLogButton ~= control or not logCurrent() or addon.Read(logShown, "boolean", logFrame) ~= true or not logCurrent() then return end
                    local fresh = addon.Read(logCapability, "boolean", id)
                    if fresh ~= true or not logCurrent() or self.questLogButton ~= control then return end
                    addon.Read(logOpener, "boolean", id)
                end) or not write(control, "Show") then return end
            y = y + height + 8
        end
        local metadataDB, metadataLocalize = addon.db, addon.L
        local metadataLocale = metadataDB and rawget(metadataDB, "locale")
        local minimum = addon.Clean(rawget(q, "minLevel"), "number")
        local questLevel = addon.Clean(rawget(q, "level"), "number")
        local rawRepeatable = rawget(q, "repeatable")
        local repeatable = addon.Clean(rawRepeatable, "boolean")
        if not (questLevel and questLevel > 0 and questLevel <= 9007199254740991 and questLevel % 1 == 0) then questLevel = nil end
        if not (minimum and minimum > 0 and minimum % 1 == 0) then minimum = nil end
        local metadataParts = {}
        local function metadataCurrent()
            local ok, same = pcall(function()
                return portraitCardCurrent() and addon.quests[id] == definition and addon.L == metadataLocalize and
                    addon.db == metadataDB and (not metadataDB or rawget(metadataDB, "locale") == metadataLocale) and
                    (not questLevel or rawget(q, "level") == questLevel) and (not minimum or rawget(q, "minLevel") == minimum) and
                    rawequal(rawget(q, "repeatable"), rawRepeatable)
            end)
            return ok and same == true
        end
        if minimum or questLevel then
            if not metadataCurrent() then return end
            if questLevel then
                local value = addon.Read(metadataLocalize, "string", "DETAIL_LEVEL", questLevel)
                if value and value:find("%S") then metadataParts[#metadataParts + 1] = value end
            end
            if not metadataCurrent() then return end
            if minimum then
                local value = addon.Read(metadataLocalize, "string", "DETAIL_MIN_LEVEL", minimum)
                if value and value:find("%S") then metadataParts[#metadataParts + 1] = value end
            end
            if not metadataCurrent() then return end
        end
        local factions = audienceLabel({ factions = q.factions }, function()
            return self.quest == renderQuest and self.dungeon == renderDungeon and self.rewardGeneration == rewardGeneration and addon.char == renderCharacter
        end)
        if factions == false then return end
        if factions then metadataParts[#metadataParts + 1] = factions end
        for _, rule in ipairs({ { "classes", "string", "QUEST_CLASSES", addon.ClassName } }) do
            local entries = addon.Clean(q[rule[1]], "table")
            local names, seen = {}, {}
            for index = 1, math.min(entries and #entries or 0, 100) do
                local value = addon.Clean(entries[index], rule[2])
                local valid = value and #value <= 100 and value:find("%S")
                if valid and not seen[value] then
                    seen[value] = true
                    local name = addon.Read(rule[4], "string", value)
                    if self.quest ~= renderQuest or self.rewardGeneration ~= rewardGeneration then return end
                    if not name or #name > 500 or not name:find("%S") then
                        name = value
                    end
                    names[#names + 1] = audienceName(rule[1], value, name)
                end
            end
            if #names > 0 then metadataParts[#metadataParts + 1] = table.concat(names, ", ") end
        end
        if repeatable == true then
            local value = addon.Read(metadataLocalize, "string", "REPEATABLE")
            if not metadataCurrent() then return end
            if value and value:find("%S") then metadataParts[#metadataParts + 1] = value end
        end
        if #metadataParts > 0 and line(table.concat(metadataParts, " · "), "caption", nil, nil, metadataCurrent) == false then return end
        local offerGetter = addon.CurrentOffer
        local offer = addon.Read(offerGetter, "table", id)
        local offeredNow = offer and addon.Clean(offer.offeredNow, "boolean") == true
        if not portraitCardCurrent() or addon.quests[id] ~= definition or addon.CurrentOffer ~= offerGetter then return end
        if offeredNow then line(addon.L("OFFERED_NOW")) end
        local start = addon.Clean(q.start, "table")
        local map = start and addon.Clean(start.mapID, "number")
        if map and map > 0 then
            local x, gy = addon.Clean(start.x, "number"), addon.Clean(start.y, "number")
            pendingGiver = { action = { id = id, kind = "visit", place = start }, source = q, map = map, x = x, y = gy,
                coordinates = x ~= nil and gy ~= nil and x >= 0 and x <= 100 and gy >= 0 and gy <= 100 }
            local fields = { npcID = "number", objectID = "number", itemID = "number", name = "string", zoneName = "string" }
            local values = {}
            for field, kind in pairs(fields) do values[field] = addon.Clean(rawget(start, field), kind) end
            pendingGiver.same = function()
                local checker = issecretvalue
                if not portraitCardCurrent() or addon.quests[id] ~= q or q.start ~= start then return false end
                for field, kind in pairs(fields) do
                    local value = rawget(start, field)
                    if type(checker) == "function" and addon.Read(checker, "boolean", value) ~= false then return false end
                    local clean = addon.Clean(value, kind)
                    if value ~= nil and clean == nil or clean ~= values[field] then return false end
                end
                return portraitCardCurrent() and issecretvalue == checker
            end
        end
        local function locationCurrent()
            return self.quest == renderQuest and self.dungeon == renderDungeon and self.engine == renderEngine and
                addon.char == renderCharacter and self.rewardGeneration == rewardGeneration and self.reportedGeneration == reportedGeneration
        end
        local function locationWrite(current, object, method, ...)
            if not current() then return false end
            local ok = pcall(object[method], object, ...)
            return ok and current()
        end
        local function reported(parent, key, ownerCurrent)
            local function current() return locationCurrent() and (not ownerCurrent or ownerCurrent()) end
            if not current() then return false end
            local places = reportedPlaces(parent)
            if not current() then return false end
            if not places then return end
            local parentName = giverName(parent)
            if not current() then return false end
            toggleIndex = toggleIndex + 1
            local toggle = self:MakeRow(self.detail, self.reportedToggles, toggleIndex, 40)
            if not current() then return false end
            toggle.locationKey, toggle.heading = key, true
            local expanded = self.reportedExpanded[key] == true
            if not locationWrite(current, toggle.title, "SetText", (expanded and "- " or "+ ") .. addon.L("REPORTED_POSITIONS", parentName, #places)) or
                not locationWrite(current, toggle.note, "SetText", "") or not locationWrite(current, toggle, "SetEnabled", true) then return false end
            if not locationWrite(current, toggle, "SetScript", "OnClick", function()
                if not current() then return end
                self.reportedExpanded[key] = not expanded
                self:RefreshDetail()
            end) then return false end
            local nextY = self:LayoutRow(toggle, 40, y, current)
            if not nextY then return false end
            y = nextY
            if not expanded then return end
            line(addon.L("REPORTED_NOTICE"))
            for _, destination in ipairs(places) do
                local point = destination
                local zone = addon.Read(C_Map and C_Map.GetMapInfo, "table", point.mapID)
                if not current() then return false end
                local zoneName = (zone and addon.Clean(zone.name, "string")) or point.zoneName or addon.L("UNKNOWN_PLACE")
                if not current() then return false end
                reportIndex = reportIndex + 1
                local row = self:MakeRow(self.detail, self.reportedRows, reportIndex, 59)
                if not current() then return false end
                row.locationKey, row.destination, row.heading = key, point, nil
                if not locationWrite(current, row.title, "SetText", zoneName .. string.format(" (%.1f, %.1f)", point.x, point.y)) or
                    not locationWrite(current, row.note, "SetText", addon.L("REPORTED_VISIT")) or
                    not locationWrite(current, row, "SetEnabled", true) then return false end
                if not locationWrite(current, row, "SetScript", "OnClick", function()
                    if current() then
                        self:DispatchDetail({ id = id, kind = "visit", place = point }, false, nil, current)
                    end
                end) then return false end
                local nextY = self:LayoutRow(row, 59, y, current)
                if not nextY then return false end
                y = nextY
            end
        end
        local function carried(itemID)
            itemID = addon.Clean(itemID, "number")
            if not itemID or itemID <= 0 or itemID % 1 ~= 0 then return nil end
            local count = addon.Read(addon.CarriedItemCount, "number", itemID)
            if count and count >= 0 and count % 1 == 0 then return addon.L("ITEM_CARRIED", count) end
        end
        local function place(p)
            if not p then return addon.L("UNKNOWN_PLACE") end
            local zone = p.mapID and addon.Read(C_Map and C_Map.GetMapInfo, "table", p.mapID)
            if not locationCurrent() then return nil end
            local zoneName = (zone and addon.Clean(zone.name, "string")) or addon.Clean(p.zoneName, "string")
            local name = giverName(p)
            if not locationCurrent() then return nil end
            if p.itemID then
                name = addon.L("ITEM_STARTER", addon.Read(addon.ItemName, "string", p.itemID) or name)
                if not locationCurrent() then return nil end
            end
            local x, py = addon.Clean(p.x, "number"), addon.Clean(p.y, "number")
            local coordinates = x ~= nil and py ~= nil and x >= 0 and x <= 100 and py >= 0 and py <= 100
            return name .. (zoneName and (" — " .. zoneName) or "") ..
                (coordinates and string.format(" (%.1f, %.1f)", x, py) or "")
        end
        local function alternativePlaces(places, buttons, heading, slot, ownerCurrent, offset, clickCurrent, rowWriter)
            local function current() return locationCurrent() and (not ownerCurrent or ownerCurrent()) end
            local function write(object, method, ...)
                if rowWriter then return rowWriter(current, object, method, ...) end
                return locationWrite(current, object, method, ...)
            end
            if not current() then return false end
            if heading then line(addon.L(heading), "section") end
            if not current() then return false end
            for index, possible in ipairs(places) do
                local destination = possible
                local title = giverName(destination)
                if not current() then return false end
                local mapID = addon.Clean(destination.mapID, "number")
                local validMap = mapID ~= nil and mapID > 0 and mapID % 1 == 0
                local zone = validMap and addon.Read(C_Map and C_Map.GetMapInfo, "table", mapID)
                if not current() then return false end
                local x, py = addon.Clean(destination.x, "number"), addon.Clean(destination.y, "number")
                local coordinates = validMap and x ~= nil and py ~= nil and x >= 0 and x <= 100 and py >= 0 and py <= 100
                local note = ((zone and addon.Clean(zone.name, "string")) or
                    addon.Clean(destination.zoneName, "string") or destination.locationName or addon.L("UNKNOWN_PLACE")) ..
                    (coordinates and string.format(" (%.1f, %.1f)", x, py) or "")
                if not current() then return false end
                local row = self:MakeRow(self.detail, buttons, (offset or 0) + index, 59)
                if not current() then return false end
                if not write(row.title, "SetText", title) or
                    not write(row.note, "SetText", note) or
                    not write(row, "SetEnabled", validMap) then return false end
                if not write(row, "SetScript", "OnClick", validMap and function()
                    if not current() or (clickCurrent and not clickCurrent()) then return end
                    local visit = { id = id, kind = "visit", place = destination }
                    local function visitCurrent() return current() and (not clickCurrent or clickCurrent()) end
                    self:DispatchDetail(visit, not coordinates, nil, visitCurrent)
                end or nil) then return false end
                local nextY = self:LayoutRow(row, 59, y, current)
                if not nextY then return false end
                y = nextY
                if reported(destination, slot .. index, ownerCurrent) == false or not current() then return false end
            end
        end
        if line(addon.L("DETAIL_GIVER"), "caption", nil, nil, portraitCardCurrent) == false then return end
        if start then
            local giverFields = { "npcID", "objectID", "itemID", "name", "zoneName", "locationName", "mapID", "x", "y" }
            local giverValues, nameGetter, itemGetter, mapRoot, checker = {}, addon.GiverName, addon.ItemName, C_Map, issecretvalue
            for _, field in ipairs(giverFields) do giverValues[field] = rawget(start, field) end
            local function giverCurrent()
                local ok, same = pcall(function()
                    if not portraitCardCurrent() or addon.quests[id] ~= definition or q.start ~= start
                        or addon.GiverName ~= nameGetter or addon.ItemName ~= itemGetter or C_Map ~= mapRoot or issecretvalue ~= checker then return false end
                    for _, field in ipairs(giverFields) do
                        local value = rawget(start, field)
                        if type(checker) == "function" and addon.Read(checker, "boolean", value) ~= false then return false end
                        if value ~= giverValues[field] then return false end
                    end
                    return portraitCardCurrent()
                end)
                return ok and same == true
            end
            if not giverCurrent() then return end
            local description = addon.Read(place, "string", start)
            if not giverCurrent() then return end
            if description and description ~= addon.L("UNKNOWN_PLACE") and line(description, nil, nil, nil, giverCurrent) == false then return end
            if not pendingGiver or not pendingGiver.coordinates then
                if line(addon.L(pendingGiver and "GIVER_COORDINATES_UNKNOWN" or "GIVER_LOCATION_UNKNOWN"), nil, nil, nil, giverCurrent) == false then return end
            end
        elseif q.startAlternatives then
            local alternatives = q.startAlternatives
            local count, preview = #alternatives, {}
            for index = 1, math.min(count, 2) do preview[index] = alternatives[index] end
            local function giverCurrent()
                if not portraitCardCurrent() or addon.quests[id] ~= definition or q.startAlternatives ~= alternatives or #alternatives ~= count then return false end
                for index, point in ipairs(preview) do if alternatives[index] ~= point then return false end end
                return portraitCardCurrent()
            end
            if alternativePlaces(preview, self.giverButtons, "START_ALTERNATIVES", "giverAlternative:", giverCurrent) == false then return end
        elseif line(addon.L("GIVER_LOCATION_UNKNOWN"), nil, nil, nil, portraitCardCurrent) == false then return end
        do
            local finish = addon.Clean(q.finish, "table")
            local fields, values, startingValues = { "npcID", "objectID", "itemID", "name", "zoneName", "mapID", "x", "y" }, {}, {}
            local endpointChecker = issecretvalue
            if finish then
                local same = start ~= nil
                for _, field in ipairs(fields) do
                    values[field], startingValues[field] = rawget(finish, field), start and rawget(start, field)
                    if type(endpointChecker) == "function" and (addon.Read(endpointChecker, "boolean", values[field]) ~= false or
                        addon.Read(endpointChecker, "boolean", startingValues[field]) ~= false) then return end
                    if not rawequal(values[field], startingValues[field]) then same = false end
                end
                local function endingCurrent()
                    if not portraitCardCurrent() or addon.quests[id] ~= definition or q.finish ~= finish or q.start ~= start or issecretvalue ~= endpointChecker then return false end
                    for _, field in ipairs(fields) do
                        local ending, starting = rawget(finish, field), start and rawget(start, field)
                        if type(endpointChecker) == "function" and (addon.Read(endpointChecker, "boolean", ending) ~= false or
                            addon.Read(endpointChecker, "boolean", starting) ~= false) then return false end
                        if not rawequal(ending, values[field]) or not rawequal(starting, startingValues[field]) then return false end
                    end
                    return portraitCardCurrent()
                end
                if not same then
                    local ending = addon.Read(place, "string", finish)
                    if not endingCurrent() then return end
                    if ending and ending ~= addon.L("UNKNOWN_PLACE") then
                        if line(addon.L("DETAIL_TURNIN") .. ": " .. ending, "caption", nil, nil, endingCurrent) == false then return end
                    end
                end
            end
        end
        local actions, uncertain = engine:Next(id)
        local action = actions[1]
        local character = addon.char
        local preferred = self.detailActionChoice
        if preferred and (preferred.quest ~= id or preferred.dungeon ~= renderDungeon or preferred.character ~= addon.char) then
            self.detailActionChoice, preferred = nil, nil
        end
        if preferred then
            for _, candidate in ipairs(actions) do
                if candidate.id == preferred.id and candidate.kind == preferred.kind then action = candidate; break end
            end
        end
        if not action or not preferred or action.id ~= preferred.id or action.kind ~= preferred.kind then self.detailActionChoice = nil end
        local function current()
            local fresh = not engine.Current or addon.Read(engine.Current, "boolean", engine) == true
            return fresh and self.quest == renderQuest and self.dungeon == renderDungeon and self.rewardGeneration == rewardGeneration and
                self.engine == engine and addon.char == character
        end
        pendingAction = action
        if (state.status == "ACTIVE" or state.status == "READY" or state.status == "COMPLETED" or state.status == "AVAILABLE") then
            if line("|cff" .. COLOR[state.status] .. statusLabel(state) .. "|r", nil, nil, nil, portraitCardCurrent) == false then return end
        end
        if state.reason and state.reason ~= "level" then
            local key = state.reason == "requirements" and state.status == "UNKNOWN" and "REASON_requirementsUnknown" or "REASON_" .. state.reason
            if line(addon.L(key), nil, nil, nil, portraitCardCurrent) == false then return end
        end
        local function actionText(candidate)
            if candidate.id == id then return addon.L(candidate.kind) .. (candidate.level and (" " .. candidate.level) or "") end
            local title = addon.QuestName(candidate.id)
            if not current() then return nil end
            return addon.L(candidate.kind) .. ": " .. title .. (candidate.level and (" (" .. candidate.level .. ")") or "")
        end
        if not metadataCurrent() then return end
        local function acquisitionPortraits(sourceOnly)
        local portraitSetter, portraitChecker = addon.Clean(SetPortraitTextureFromCreatureDisplayID, "function"), issecretvalue
        local function renderPortrait(field, displayID, caption, current)
            if not displayID or displayID <= 0 or displayID > 4294967295 or displayID % 1 ~= 0 or self.portraitRenderBusy then return true end
            local setter = portraitSetter
            if not setter then return true end
            local texture = self[field]
            if not texture then
                texture = self.detail:CreateTexture(nil, "ARTWORK"); texture:SetSize(64, 64); texture:Hide()
                self[field] = texture
            end
            local captionField, captionBinding
            local function imageCurrent()
                local fresh = addon.Read(current, "boolean") == true
                return fresh and portraitCardCurrent() and self[field] == texture
            end
            local function retireOwnedImage()
                if portraitCardCurrent() and self[field] == texture then
                    local busy = self.portraitRenderBusy
                    if not busy then self.portraitRenderBusy = true end
                    pcall(texture.Hide, texture)
                    if portraitCardCurrent() and captionField and captionField.detailTextBinding == captionBinding then
                        pcall(captionField.Hide, captionField)
                        local newer = captionField.detailTextBinding
                        if newer and newer ~= captionBinding and addon.Read(newer.current, "boolean") == true and
                            captionField.detailTextBinding == newer and self.quest == newer.quest and self.dungeon == newer.dungeon and
                            self.engine == newer.engine and addon.char == newer.character and self.rewardGeneration == newer.generation then
                            pcall(captionField.Show, captionField)
                        end
                    end
                    if not busy then self.portraitRenderBusy = nil end
                end
                return false
            end
            texture:ClearAllPoints()
            if not imageCurrent() then return retireOwnedImage() end
            self.portraitRenderBusy = true
            local rendered = pcall(setter, texture, displayID)
            self.portraitRenderBusy = nil
            if not imageCurrent() then return retireOwnedImage() end
            if SetPortraitTextureFromCreatureDisplayID ~= setter then rendered = false end
            if rendered then
                local captionIndex = n + 1
                local captionWritten = line(caption, nil, nil, nil, current)
                local captionCandidate = pool[captionIndex]
                local binding = captionCandidate and captionCandidate.detailTextBinding
                if binding and binding.generation == rewardGeneration and binding.current == current then
                    captionField, captionBinding = captionCandidate, binding
                end
                if captionWritten == false then return retireOwnedImage() end
                texture:SetPoint("TOPLEFT", 4, -y)
                if not imageCurrent() then return retireOwnedImage() end
                texture:Show()
                if not imageCurrent() then return retireOwnedImage() end
                y = y + 64 + 8
            else
                self.portraitRenderBusy = true; pcall(texture.SetTexture, texture, nil); self.portraitRenderBusy = nil
                if not imageCurrent() then return retireOwnedImage() end
            end
            return true
        end
        if not sourceOnly then
        local completionProvider, dialoguePortrait, questPortrait = addon.DialogueTurnInPortrait, addon.DialoguePortrait, addon.QuestPortrait
        local completionCapability = addon.Clean(completionProvider, "function")
        local completionDB, completionLocaleGetter = addon.db, GetLocale
        local completionUILocale = completionDB and rawget(completionDB, "locale")
        local completionGameLocale = completionCapability and addon.Read(completionLocaleGetter, "string")
        local completionEngineGetter = engine.Current
        local function completionBaseCurrent()
            local locale = addon.Read(completionLocaleGetter, "string")
            local fresh = completionEngineGetter == nil or addon.Read(completionEngineGetter, "boolean", engine) == true
            return fresh and portraitCardCurrent() and addon.quests[id] == q and rawget(q, "id") == id and
                addon.DialogueTurnInPortrait == completionProvider and addon.db == completionDB and
                (not completionDB or rawget(completionDB, "locale") == completionUILocale) and GetLocale == completionLocaleGetter and
                locale == completionGameLocale and engine.Current == completionEngineGetter and issecretvalue == portraitChecker
        end
        local completion = completionCapability and addon.Read(completionProvider, "table", id, completionBaseCurrent)
        if not portraitCardCurrent() then return end
        local completionValues
        if completion then
            completionValues = {}
            for field, kind in pairs({ source="string", stage="string", displayID="number", hidden="boolean", name="string", current="function" }) do
                local value = rawget(completion, field)
                if type(portraitChecker) == "function" and addon.Read(portraitChecker, "boolean", value) ~= false then completionValues=nil; break end
                if value ~= nil then
                    local clean = addon.Clean(value, kind)
                    if clean == nil then completionValues=nil; break end
                    completionValues[field] = clean
                end
            end
        end
        if completion and not completionBaseCurrent() then return end
        local validCompletion = completionValues and completionValues.source == "dialogue" and completionValues.stage == "completion" and
            completionValues.current and ((completionValues.hidden == true and completionValues.displayID == nil) or
            (completionValues.hidden == nil and completionValues.displayID and completionValues.displayID > 0 and
                completionValues.displayID <= 4294967295 and completionValues.displayID % 1 == 0))
        local function completionCurrent()
            local live = completionValues and addon.Read(completionValues.current, "boolean") == true
            if not live or not completionBaseCurrent() then return false end
            local ok, same = pcall(function()
                for field, value in pairs(completionValues) do if rawget(completion, field) ~= value then return false end end
                return rawget(completion, "displayID") == completionValues.displayID and rawget(completion, "hidden") == completionValues.hidden and
                    rawget(completion, "name") == completionValues.name and portraitCardCurrent() and addon.quests[id] == q and rawget(q, "id") == id and
                    addon.DialogueTurnInPortrait == completionProvider and issecretvalue == portraitChecker
            end)
            return ok and same == true
        end
        local portrait, nativeCurrent
        if validCompletion then
            if not completionCurrent() then return end
            portrait, nativeCurrent = completionValues, completionCurrent
        else
            portrait = addon.Read(dialoguePortrait, "table", id)
            if not portraitCardCurrent() then return end
            if not portrait then portrait = addon.Read(questPortrait, "table", id) end
            nativeCurrent = function()
                return addon.DialogueTurnInPortrait == completionProvider and addon.DialoguePortrait == dialoguePortrait and
                    addon.QuestPortrait == questPortrait and issecretvalue == portraitChecker
            end
        end
        if not portraitCardCurrent() then return end
        local displayID = portrait and addon.Clean(portrait.hidden, "boolean") ~= true and addon.Clean(portrait.displayID, "number")
        local nativeCaption = addon.L("QUEST_PORTRAIT")
        if validCompletion and not completionCurrent() then return end
        if not renderPortrait("portrait", displayID, nativeCaption, nativeCurrent) then return end
        end
        if sourceOnly then
        local producer = addon.GiverPortrait
        local fieldTypes = { npcID = "number", objectID = "number", itemID = "number", dropNPCID = "number",
            creatureDisplayID = "number", portraitSource = "string", name = "string", mapID = "number", x = "number", y = "number", zoneName = "string" }
        local referenceActions, referenceAction, referenceEngineGetter
        if state.status == "READY" then
            referenceEngineGetter = engine.Current
            referenceActions = engine:Next(id)
            if not portraitCardCurrent() then return end
            if #referenceActions == 1 then
                local candidate = referenceActions[1]
                if candidate.id == id and candidate.kind == "turnin" and candidate.place == q.finish and not q.finishAlternatives then
                    referenceAction = candidate
                end
            end
        end
        local function sourceReference(point, endpoint, captionKey, turnin)
            local function sourceSnapshot()
                local values = {}
                for field, kind in pairs(fieldTypes) do
                    local value = point and rawget(point, field)
                    if type(portraitChecker) == "function" and addon.Read(portraitChecker, "boolean", value) ~= false then return nil end
                    if value ~= nil then
                        value = addon.Clean(value, kind)
                        if value == nil then return nil end
                        values[field] = value
                    end
                end
                return values
            end
            local sourceValues = sourceSnapshot()
            local function sourceCurrent()
                local fresh = not turnin or referenceEngineGetter == nil or addon.Read(referenceEngineGetter, "boolean", engine) == true
                if not fresh or not portraitCardCurrent() or addon.quests[id] ~= q or q[endpoint] ~= point or addon.GiverPortrait ~= producer or
                    SetPortraitTextureFromCreatureDisplayID ~= portraitSetter or issecretvalue ~= portraitChecker then return false end
                local values = sourceSnapshot()
                if not sourceValues or not values then return false end
                for field in pairs(fieldTypes) do if sourceValues[field] ~= values[field] then return false end end
                local ok, same = pcall(function()
                    for field in pairs(fieldTypes) do if rawget(point, field) ~= sourceValues[field] then return false end end
                    return portraitCardCurrent() and addon.quests[id] == q and q[endpoint] == point and
                        addon.GiverPortrait == producer and SetPortraitTextureFromCreatureDisplayID == portraitSetter and issecretvalue == portraitChecker and
                        (not turnin or (state.status == "READY" and rawget(q, "id") == id and q.finishAlternatives == nil and
                            engine.Current == referenceEngineGetter and #referenceActions == 1 and referenceActions[1] == referenceAction and
                            referenceAction.id == id and referenceAction.kind == "turnin" and referenceAction.place == point))
                end)
                return ok and same == true
            end
            if not portraitCardCurrent() then return false end
            local npcID = sourceValues and sourceValues.npcID
            if npcID and npcID > 0 and npcID <= 4294967295 and npcID % 1 == 0 and
                not sourceValues.objectID and not sourceValues.itemID and not sourceValues.dropNPCID then
                local reference = addon.Read(producer, "table", point)
                if not sourceCurrent() then return false end
                local referenceNPC = reference and addon.Clean(rawget(reference, "npcID"), "number")
                local referenceDisplay = reference and addon.Clean(rawget(reference, "displayID"), "number")
                local referenceSource = reference and addon.Clean(rawget(reference, "source"), "string")
                if referenceNPC == npcID and referenceDisplay == sourceValues.creatureDisplayID and
                    referenceSource and referenceSource == sourceValues.portraitSource then
                    local name = addon.Clean(rawget(reference, "name"), "string")
                    if not name or #name > 1024 or not name:find("%S") then name = giverName(point) end
                    if not sourceCurrent() then return false end
                    if not renderPortrait("giverPortrait", referenceDisplay, addon.L(captionKey, name), sourceCurrent) then return false end
                    return true, true
                end
            end
            return true, false
        end
        local referenceShown = false
        local finish = referenceAction and addon.Clean(q.finish, "table")
        local startNPC = start and addon.Clean(rawget(start, "npcID"), "number")
        local finishNPC = finish and addon.Clean(rawget(finish, "npcID"), "number")
        if not portraitCardCurrent() then return end
        if finish and (not startNPC or startNPC ~= finishNPC) then
            local current, shown = sourceReference(finish, "finish", "TURNIN_REFERENCE_PORTRAIT", true)
            if not current then return end
            referenceShown = shown
        end
        if not referenceShown then
            if not sourceReference(start, "start", "GIVER_REFERENCE_PORTRAIT", false) then return end
        end
        end
        return true
        end
        do
            local progressGetter, dialogueGetter, objectiveChecker = addon.QuestObjectives, addon.DialogueObjectiveText, issecretvalue
            local function objectivesCurrent()
                return portraitCardCurrent() and addon.quests[id] == definition and
                    addon.QuestObjectives == progressGetter and addon.DialogueObjectiveText == dialogueGetter and issecretvalue == objectiveChecker
            end
            local objectives = addon.Read(progressGetter, "table", id)
            if not objectivesCurrent() then return end
            if objectives and #objectives > 0 then
                if line(addon.L("OBJECTIVE_PROGRESS"), "caption", nil, nil, objectivesCurrent) == false then return end
            end
            for _, objective in ipairs(objectives or {}) do
                local text = "|cff" .. (objective.finished and COLOR.COMPLETED or COLOR.ACTIVE) .. objective.text .. "|r"
                if line(text, nil, nil, nil, objectivesCurrent) == false then return end
            end
            do
                local getter, checker, localize = addon.HeldQuestPayment, issecretvalue, addon.L
                if type(getter) == "function" and addon.Clean(rawget(q, "id"), "number") == id then
                    local database, selectedLocale, localeGetter = addon.db, addon.db.locale, GetLocale
                    local gameLocale = addon.Read(localeGetter, "string")
                    local currencyRoot = C_CurrencyInfo
                    local currency = addon.Clean(currencyRoot, "table")
                    local formatter = currency and rawget(currency, "GetCoinTextureString")
                    local result, rawAmount, rawFormatted, proofReady
                    local function heldPaymentCurrent()
                        local language = addon.Read(localeGetter, "string")
                        local ok, same = pcall(function()
                            return portraitCardCurrent() and addon.quests[id] == definition and rawget(q, "id") == id and
                                addon.HeldQuestPayment == getter and issecretvalue == checker and addon.L == localize and
                                addon.db == database and database.locale == selectedLocale and GetLocale == localeGetter and language == gameLocale and
                                C_CurrencyInfo == currencyRoot and (not currency or rawget(currency, "GetCoinTextureString") == formatter) and
                                (not proofReady or (rawget(result, "amount") == rawAmount and rawget(result, "formatted") == rawFormatted))
                        end)
                        return ok and same == true
                    end
                    if not heldPaymentCurrent() then return end
                    local candidate = addon.Read(getter, "table", id, heldPaymentCurrent)
                    if not heldPaymentCurrent() then return end
                    if candidate then
                        result = candidate
                        rawAmount, rawFormatted = rawget(result, "amount"), rawget(result, "formatted")
                        local amount = addon.Clean(rawAmount, "number")
                        local readable = type(checker) ~= "function" or addon.Read(checker, "boolean", rawFormatted) == false
                        if not heldPaymentCurrent() then return end
                        if amount and amount > 0 and amount <= 9007199254740991 and amount % 1 == 0 and readable then
                            local formatted = addon.Clean(rawFormatted, "string")
                            proofReady = true
                            if not heldPaymentCurrent() then return end
                            if not formatted or #formatted > 4096 or not formatted:find("%S") then
                                formatted = addon.Read(localize, "string", "MONEY_COPPER", amount)
                            end
                            if not heldPaymentCurrent() then return end
                            local title = formatted and addon.Read(localize, "string", "QUEST_LOG_PAYMENT", formatted)
                            if not heldPaymentCurrent() then return end
                            if title and title:find("%S") then
                                if line(title, nil, nil, nil, heldPaymentCurrent) == false then return end
                                self.heldPaymentDetail = pool[n]
                                self.heldPaymentBinding = { field = pool[n], current = heldPaymentCurrent }
                            end
                        end
                    end
                end
            end
            local dialogueObjective = addon.Read(dialogueGetter, "string", id)
            if not objectivesCurrent() then return end
            if dialogueObjective and dialogueObjective ~= "" and #dialogueObjective <= 30000 then
                if line(addon.L("OBJECTIVE_DIALOGUE"), "section", nil, nil, objectivesCurrent) == false or
                    line(dialogueObjective, nil, nil, nil, objectivesCurrent) == false then return end
            end
        end
        if not self.clientWaypointWriteBusy and type(addon.HeldQuestWaypoint) == "function" then
            local provider, checker, localize = addon.HeldQuestWaypoint, issecretvalue, addon.L
            local engineCurrent = renderEngine and renderEngine.Current
            local database, selectedLocale, localeGetter = addon.db, addon.db.locale, GetLocale
            local gameLocale = addon.Read(localeGetter, "string")
            local navigationRoot = addon.Navigation
            local navigation = addon.Clean(navigationRoot, "table")
            local rawStart = navigation and rawget(navigation, "Start")
            local start = addon.Clean(rawStart, "function")
            local function waypointCurrent()
                local language = addon.Read(localeGetter, "string")
                local engineFresh = type(engineCurrent) == "nil" or addon.Read(engineCurrent, "boolean", renderEngine) == true
                return engineFresh and (not renderEngine or renderEngine.Current == engineCurrent) and portraitCardCurrent() and addon.quests[id] == definition and definition and rawget(definition, "id") == id and addon.HeldQuestWaypoint == provider and
                    issecretvalue == checker and addon.L == localize and addon.db == database and database.locale == selectedLocale and
                    GetLocale == localeGetter and language == gameLocale and addon.Navigation == navigationRoot and
                    (not navigation or rawget(navigation, "Start") == rawStart)
            end
            local function snapshotCurrent(snapshot)
                if not waypointCurrent() then return false end
                local ok, same = pcall(function()
                    local dto = snapshot.dto
                    return portraitCardCurrent() and rawget(dto, "source") == "clientWaypoint" and rawget(dto, "questID") == id and
                        rawget(dto, "uiMapID") == snapshot.map and rawget(dto, "normalizedX") == snapshot.x and
                        rawget(dto, "normalizedY") == snapshot.y and rawget(dto, "text") == snapshot.text
                end)
                return ok and same == true
            end
            local function readWaypoint()
                if not waypointCurrent() then return nil end
                local dto = addon.Read(provider, "table", id, waypointCurrent)
                if not waypointCurrent() or not dto then return nil end
                local source = addon.Clean(rawget(dto, "source"), "string")
                local quest = addon.Clean(rawget(dto, "questID"), "number")
                local map = addon.Clean(rawget(dto, "uiMapID"), "number")
                local x = addon.Clean(rawget(dto, "normalizedX"), "number")
                local z = addon.Clean(rawget(dto, "normalizedY"), "number")
                local rawText = rawget(dto, "text")
                local readable = type(checker) ~= "function" or addon.Read(checker, "boolean", rawText) == false
                if not waypointCurrent() then return nil end
                local text = readable and addon.Clean(rawText, "string")
                if source ~= "clientWaypoint" or quest ~= id or not map or map <= 0 or map > 9007199254740991 or map % 1 ~= 0 or
                    not x or x < 0 or x > 1 or not z or z < 0 or z > 1 or not readable or
                    (rawText ~= nil and (not text or #text > 1024 or not text:find("%S"))) then return nil end
                local snapshot = { dto = dto, map = map, x = x, y = z, text = text }
                return snapshotCurrent(snapshot) and snapshot or nil
            end
            local snapshot = readWaypoint()
            if not portraitCardCurrent() then return end
            if snapshot then
                local function previewCurrent() return snapshotCurrent(snapshot) end
                local heading = addon.Read(localize, "string", "GAME_WAYPOINT")
                local notice = addon.Read(localize, "string", "GAME_WAYPOINT_NOTICE")
                local follow = addon.Read(localize, "string", "GAME_WAYPOINT_FOLLOW")
                if not previewCurrent() then return end
                if heading and notice and follow then
                    if line(heading, "section", nil, nil, previewCurrent) == false or
                        line(notice, nil, nil, nil, previewCurrent) == false then return end
                    if snapshot.text and line(snapshot.text, nil, nil, nil, previewCurrent) == false then return end
                    if start then
                        local control = self.clientWaypointButton
                        if not control then
                            control = CreateFrame("Button", nil, self.detail); control:Hide(); control:SetWidth(contentWidth)
                            control.label = label(control, "", 7, -5, contentWidth - 14, 14); control.title = control.label
                            control:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                            if not previewCurrent() then return end
                            self.clientWaypointButton = control
                        end
                        local function write(object, method, ...)
                            if not previewCurrent() then return false end
                            local busy = {}
                            self.clientWaypointWriteBusy = busy
                            local ok = pcall(object[method], object, ...)
                            local fresh = previewCurrent()
                            if not fresh and self.clientWaypointWriteBusy == busy then pcall(control.Hide, control) end
                            if self.clientWaypointWriteBusy == busy then self.clientWaypointWriteBusy = nil end
                            return ok and fresh
                        end
                        if not write(control.label, "SetText", follow) then return end
                        local height = math.max(28, measuredHeight(control.label, 18) + 10)
                        if not previewCurrent() then return end
                        styleRow(control, "control", false)
                        if not previewCurrent() then return end
                        local binding = {}
                        if not write(control, "SetHeight", height) or not write(control, "ClearAllPoints") or
                            not write(control, "SetPoint", "TOPLEFT", 4, -y) or not write(control, "SetEnabled", true) or
                            not write(control, "SetScript", "OnClick", function()
                                if self.clientWaypointBinding ~= binding or not waypointCurrent() or
                                    addon.Read(self.frame.IsShown, "boolean", self.frame) ~= true or not waypointCurrent() then return end
                                local fresh = readWaypoint()
                                if not fresh or self.clientWaypointBinding ~= binding or not snapshotCurrent(fresh) then return end
                                local place = { mapID = fresh.map, x = fresh.x * 100, y = fresh.y * 100, name = fresh.text }
                                if self.clientWaypointBinding == binding and snapshotCurrent(fresh) then
                                    self:DispatchDetail({ id = id, kind = "visit", place = place }, false, nil,
                                        function() return self.clientWaypointBinding == binding and snapshotCurrent(fresh) end)
                                end
                            end) or not write(control, "Show") then return end
                        self.clientWaypointBinding = binding
                        y = y + height + 8
                    end
                end
            end
        end
        do
            local killChecker, localize = issecretvalue, addon.L
            local database, selectedLocale, localeGetter = addon.db, addon.db.locale, GetLocale
            local gameLocale = addon.Read(localeGetter, "string")
            local objectiveKills = addon.Clean(rawget(q, "objectiveKills"), "table")
            local length = objectiveKills and #objectiveKills or 0
            local function killsCurrent()
                local language = addon.Read(localeGetter, "string")
                local ok, same = pcall(function()
                    return portraitCardCurrent() and addon.quests[id] == definition and rawget(q, "objectiveKills") == objectiveKills and
                        (not objectiveKills or #objectiveKills == length) and issecretvalue == killChecker and addon.L == localize and
                        addon.db == database and database.locale == selectedLocale and GetLocale == localeGetter and language == gameLocale
                end)
                return ok and same == true
            end
            if not killsCurrent() then return end
            local shownKills, seenKills = false, {}
            for index = 1, math.min(length, 100) do
                local entry = addon.Clean(rawget(objectiveKills, index), "table")
                local npcID = entry and addon.Clean(rawget(entry, "npcID"), "number")
                local name = entry and addon.Clean(rawget(entry, "name"), "string")
                local rawQuantity = entry and rawget(entry, "quantity")
                local quantityReadable = true
                if type(killChecker) == "function" then
                    local ok, restricted = pcall(killChecker, rawQuantity)
                    quantityReadable = ok and addon.Clean(restricted, "boolean") == false
                end
                local quantityUnknown = quantityReadable and rawQuantity == nil
                local quantity = quantityReadable and addon.Clean(rawQuantity, "number")
                if not killsCurrent() then return end
                if npcID and npcID > 0 and npcID <= 4294967295 and npcID % 1 == 0 and
                    name and #name <= 500 and name:find("%S") and not seenKills[npcID] and
                    (quantityUnknown or (quantity and quantity > 0 and quantity <= 9007199254740991 and quantity % 1 == 0)) then
                    local function killCurrent()
                        if not killsCurrent() then return false end
                        local ok, same = pcall(function()
                            return rawget(objectiveKills, index) == entry and rawget(entry, "npcID") == npcID and
                                rawget(entry, "name") == name and rawget(entry, "quantity") == rawQuantity
                        end)
                        return ok and same == true
                    end
                    local heading = addon.Read(localize, "string", "OBJECTIVE_KILLS")
                    local notice = addon.Read(localize, "string", "OBJECTIVE_KILLS_NOTICE")
                    local text = quantityUnknown and (name .. " ×?") or
                        addon.Read(localize, "string", "OBJECTIVE_ITEM", name, quantity)
                    if not killCurrent() then return end
                    if heading and notice and text then
                        seenKills[npcID] = true
                        if not shownKills then
                            if line(heading, "caption", nil, nil, killCurrent) == false then return end
                            shownKills = true
                        end
                        if line(text, nil, nil, nil, killCurrent) == false then return end
                    end
                end
            end
        end
        do
            local factChecker = issecretvalue
            local roots = { objectiveObjects = rawget(q, "objectiveObjects"), objectiveEvents = rawget(q, "objectiveEvents") }
            local sources = { { field = "objectiveObjects", identity = "objectID", other = "npcID" },
                { field = "objectiveEvents", identity = "npcID", other = "objectID" } }
            local function sectionCurrent()
                local ok, same = pcall(function()
                    return portraitCardCurrent() and addon.quests[id] == definition and issecretvalue == factChecker and
                        rawget(q, "objectiveObjects") == roots.objectiveObjects and rawget(q, "objectiveEvents") == roots.objectiveEvents
                end)
                return ok and same == true
            end
            for _, source in ipairs(sources) do
                source.rows = addon.Clean(roots[source.field], "table")
                source.length = source.rows and #source.rows or 0
                if not sectionCurrent() then return end
            end
            local function listsCurrent()
                if not sectionCurrent() then return false end
                for _, source in ipairs(sources) do
                    if source.rows and #source.rows ~= source.length then return false end
                end
                return true
            end
            local shown = false
            for _, source in ipairs(sources) do
                local rows, length, seen = source.rows, source.length, {}
                if length >= 1 and length <= 100 then
                    for index = 1, length do
                        local entry = addon.Clean(rawget(rows, index), "table")
                        local identity = entry and addon.Clean(rawget(entry, source.identity), "number")
                        local name = entry and addon.Clean(rawget(entry, "name"), "string")
                        local rawQuantity = entry and rawget(entry, "quantity")
                        local quantityReadable = true
                        if type(factChecker) == "function" then
                            local ok, restricted = pcall(factChecker, rawQuantity)
                            quantityReadable = ok and addon.Clean(restricted, "boolean") == false
                        end
                        local unknown = quantityReadable and rawQuantity == nil
                        local quantity = quantityReadable and addon.Clean(rawQuantity, "number")
                        if not listsCurrent() then return end
                        if identity and identity > 0 and identity <= 4294967295 and identity % 1 == 0 and
                            name and #name <= 500 and name:find("%S") and not seen[identity] and
                            (unknown or (quantity and quantity > 0 and quantity <= 9007199254740991 and quantity % 1 == 0)) then
                            local function entryCurrent()
                                if not listsCurrent() then return false end
                                local ok, same = pcall(function()
                                    return sectionCurrent() and rawget(rows, index) == entry and rawget(entry, source.identity) == identity and
                                        rawget(entry, "name") == name and rawget(entry, "quantity") == rawQuantity and
                                        rawget(entry, "itemID") == nil and rawget(entry, source.other) == nil
                                end)
                                return ok and same == true
                            end
                            if entryCurrent() then
                                local heading, notice = addon.L("OBJECTIVE_OBJECTS"), addon.L("OBJECTIVE_OBJECTS_NOTICE")
                                local text = unknown and (name .. " ×?") or addon.L("OBJECTIVE_ITEM", name, quantity)
                                if not entryCurrent() then return end
                                seen[identity] = true
                                if not shown then
                                    if line(heading, "caption", nil, nil, entryCurrent) == false then return end
                                    shown = true
                                end
                                if line(text, nil, nil, nil, entryCurrent) == false then return end
                            elseif not listsCurrent() then return end
                        end
                    end
                end
            end
        end
        for _, source in ipairs({ { "objective", "objectiveItems", "OBJECTIVE_ITEMS", "OBJECTIVE_ITEMS_NOTICE", 9007199254740991 },
            { "provided", "providedItems", "PROVIDED_ITEMS", "PROVIDED_ITEMS_NOTICE", 4294967295 } }) do
            local sourceRole, sourceField, heading, notice, maximumID = unpack(source)
            local objectiveItems = addon.Clean(q[sourceField], "table")
            local sourceLength = objectiveItems and #objectiveItems or 0
            local objectiveChecker = issecretvalue
            local function objectiveCurrent()
                return portraitCardCurrent() and addon.quests[id] == definition and q[sourceField] == objectiveItems and issecretvalue == objectiveChecker
            end
            local shownObjectives, seenItems = false, {}
            for index = 1, math.min(objectiveItems and #objectiveItems or 0, 100) do
                local entry = addon.Clean(objectiveItems[index], "table")
                local itemID = entry and addon.Clean(entry.itemID, "number")
                local sourceName = entry and addon.Clean(rawget(entry, "name"), "string")
                local validName = sourceRole ~= "provided" or (sourceName and #sourceName <= 500 and sourceName:find("%S"))
                local rawQuantity = entry and rawget(entry, "quantity")
                local quantityReadable = true
                if type(issecretvalue) == "function" then
                    local ok, restricted = pcall(issecretvalue, rawQuantity)
                    quantityReadable = ok and addon.Clean(restricted, "boolean") == false
                end
                local quantityUnknown = quantityReadable and rawQuantity == nil
                local quantity = quantityReadable and addon.Clean(rawQuantity, "number")
                if not objectiveCurrent() then return end
                if validName and itemID and itemID > 0 and itemID <= maximumID and itemID % 1 == 0 and
                    (quantityUnknown or (quantity and quantity > 0 and quantity <= 9007199254740991 and quantity % 1 == 0)) and not seenItems[itemID] then
                    seenItems[itemID] = true
                    local iconGetter = addon.ItemIcon
                    local function entryCurrent(binding)
                        if not objectiveCurrent() or (binding and (binding.role ~= sourceRole or binding.sourceField ~= sourceField)) or
                            addon.ItemIcon ~= iconGetter or objectiveItems[index] ~= entry or
                            addon.Clean(rawget(entry, "itemID"), "number") ~= itemID then return false end
                        if not objectiveCurrent() then return false end
                        local raw = rawget(entry, "quantity")
                        if type(objectiveChecker) == "function" and addon.Read(objectiveChecker, "boolean", raw) ~= false then return false end
                        if not objectiveCurrent() then return false end
                        local unknown = raw == nil
                        local amount = addon.Clean(raw, "number")
                        if unknown ~= quantityUnknown or (not unknown and amount ~= quantity) or not objectiveCurrent() then return false end
                        local ok, same = pcall(function()
                            return self.quest == renderQuest and self.dungeon == renderDungeon and self.engine == renderEngine and
                                addon.char == renderCharacter and self.rewardGeneration == rewardGeneration and
                                addon.quests[id] == definition and q[sourceField] == objectiveItems and #objectiveItems == sourceLength and
                                rawget(objectiveItems, index) == entry and rawget(entry, "itemID") == itemID and
                                rawget(entry, "quantity") == raw and addon.ItemIcon == iconGetter and
                                (not binding or (binding.role == sourceRole and binding.sourceField == sourceField)) and
                                (sourceRole ~= "provided" or rawget(entry, "name") == sourceName) and
                                issecretvalue == objectiveChecker and true or false
                        end)
                        return ok and same == true
                    end
                    if not entryCurrent() then return end
                    local name = addon.Read(addon.ItemName, "string", itemID)
                    if not entryCurrent() then return end
                    if not name or #name > 1024 or not name:find("%S") then
                        name = addon.Clean(entry.name, "string")
                        if not name or #name > 2000 or not name:find("%S") then name = string.format("#%.0f", itemID) end
                    end
                    local count = carried(itemID)
                    if not entryCurrent() then return end
                    local icon = itemID <= 4294967295 and addon.Read(iconGetter, "number", itemID) or nil
                    if not entryCurrent() then return end
                    local binding
                    if icon and icon > 0 and icon <= 4294967295 and icon % 1 == 0 then
                        binding = { id = itemID, texture = icon, role = sourceRole, sourceField = sourceField, context = addon.L(notice) .. (quantityUnknown and ("\n" .. addon.L("OBJECTIVE_ITEM_UNKNOWN", name)) or "") }
                        binding.current = function() return entryCurrent(binding) end
                        if not binding.current() then return end
                    end
                    if not shownObjectives then
                        line(addon.L(sourceRole == "objective" and "DETAIL_OBJECTIVES" or heading), "caption"); shownObjectives = true
                    end
                    local text = quantityUnknown and (name .. " ×?") or addon.L("OBJECTIVE_ITEM", name, quantity)
                    if count then text = text .. " · " .. count end
                    if line(text, nil, nil, binding) == false then return end
                end
            end
        end

        local function acquisitionObjectives()
        do
            local sources = addon.Clean(rawget(q, "objectiveItemSources"), "table")
            local items = addon.Clean(rawget(q, "objectiveItems"), "table")
            local checker, localize, nameGetter = issecretvalue, addon.L, addon.ItemName
            local database, choice, localeGetter = addon.db, addon.db.locale, GetLocale
            local locale = addon.Read(localeGetter, "string")
            local mapNamespace, mapGetter = C_Map, C_Map and C_Map.GetMapInfo
            local navigation = addon.Navigation
            local navigate, showMap = navigation and navigation.Start, navigation and navigation.Map
            local snapshots = {}
            local function capture(object, fields, list, exact)
                local values, count = {}, 0
                if exact then for _ in next, object do count = count + 1 end end
                for _, field in ipairs(fields) do values[field] = rawget(object, field) end
                snapshots[#snapshots + 1] = { object = object, fields = fields, values = values, length = list and #object or nil, count = exact and count or nil }
            end
            capture(q, { "objectiveItemSources", "objectiveItems" })
            local function current()
                local language = addon.Read(localeGetter, "string")
                local ok, same = pcall(function()
                    if not portraitCardCurrent() or not locationCurrent() or addon.quests[id] ~= definition or
                        issecretvalue ~= checker or addon.L ~= localize or addon.ItemName ~= nameGetter or
                        addon.db ~= database or database.locale ~= choice or GetLocale ~= localeGetter or language ~= locale or
                        C_Map ~= mapNamespace or (mapNamespace and mapNamespace.GetMapInfo ~= mapGetter) or
                        addon.Navigation ~= navigation or (navigation and (navigation.Start ~= navigate or navigation.Map ~= showMap)) then return false end
                    for _, snapshot in ipairs(snapshots) do
                        if snapshot.length and #snapshot.object ~= snapshot.length then return false end
                        if snapshot.count then
                            local count = 0; for _ in next, snapshot.object do count = count + 1 end
                            if count ~= snapshot.count then return false end
                        end
                        for _, field in ipairs(snapshot.fields) do
                            if rawget(snapshot.object, field) ~= snapshot.values[field] then return false end
                        end
                    end
                    return true
                end)
                return ok and same == true
            end
            local function positive(value, maximum)
                value = addon.Clean(value, "number")
                return value and value > 0 and value <= maximum and value % 1 == 0 and value
            end
            local routes, definitions, seen, valid = {}, {}, {}, sources and items and #sources > 0 and #sources <= 100 and #items <= 100
            if valid then
                capture(sources, {}, true); capture(items, {}, true)
                for index = 1, #items do
                    capture(items, { index })
                    local entry = addon.Clean(rawget(items, index), "table")
                    if entry then
                        capture(entry, { "itemID", "name" })
                        local item = positive(rawget(entry, "itemID"), 9007199254740991)
                        if item then
                            if definitions[item] ~= nil then valid = false; break end
                            definitions[item] = entry
                        end
                    end
                end
                for index = 1, #sources do
                    if not valid then break end
                    capture(sources, { index })
                    local entry = addon.Clean(rawget(sources, index), "table")
                    local item = entry and positive(rawget(entry, "itemID"), 9007199254740991)
                    local containers = entry and addon.Clean(rawget(entry, "containerSources"), "table")
                    if not item or not definitions[item] or seen[item] or not containers or #containers < 1 or #containers > 100 then valid = false; break end
                    for key in next, entry do local cleanKey = addon.Clean(key, "string"); if not cleanKey or (cleanKey ~= "itemID" and cleanKey ~= "containerSources") then valid = false; break end end
                    if not valid then break end
                    seen[item] = true
                    capture(entry, { "itemID", "containerSources" }, nil, true); capture(containers, {}, true)
                    local route = { itemID = item, definition = definitions[item], containers = containers, index = index }
                    local objects = {}
                    for sourceIndex = 1, #containers do
                        capture(containers, { sourceIndex })
                        local point = addon.Clean(rawget(containers, sourceIndex), "table")
                        if not point then valid = false; break end
                        local pointFields = { "objectID", "name", "source", "zoneName", "mapID", "x", "y" }
                        for _, field in ipairs(pointFields) do
                            if type(checker) == "function" and addon.Read(checker, "boolean", rawget(point, field)) ~= false then valid = false; break end
                        end
                        if not valid then break end
                        capture(point, pointFields, nil, true)
                        local object = positive(rawget(point, "objectID"), 4294967295)
                        local name, source = addon.Clean(rawget(point, "name"), "string"), addon.Clean(rawget(point, "source"), "string")
                        local zone = rawget(point, "zoneName")
                        local validZone = zone == nil or (addon.Clean(zone, "string") and #zone <= 500 and zone:find("%S"))
                        local map = rawget(point, "mapID")
                        local x, py = rawget(point, "x"), rawget(point, "y")
                        local allowed = { objectID = true, name = true, source = true, zoneName = true, mapID = true, x = true, y = true }
                        for key in next, point do local cleanKey = addon.Clean(key, "string"); if not cleanKey or not allowed[cleanKey] then valid = false; break end end
                        local prefix = object and ("https://www.wowhead.com/forever/object=" .. string.format("%.0f", object))
                        local matched = prefix and source and (source == prefix or
                            (source:sub(1, #prefix + 1) == prefix .. "/" and source:sub(#prefix + 2):match("^[^%s/?#]+$")))
                        local cleanMap = map == nil or positive(map, 9007199254740991)
                        local cleanX, cleanY = addon.Clean(x, "number"), addon.Clean(py, "number")
                        local coordinates = x == nil and py == nil or (cleanMap and map ~= nil and cleanX and cleanY and
                            cleanX >= 0 and cleanX <= 100 and cleanY >= 0 and cleanY <= 100)
                        if not valid or not object or objects[object] or not validZone or not name or #name > 500 or not name:find("%S") or
                            not source or #source > 2048 or not matched or not cleanMap or not coordinates then valid = false; break end
                        objects[object] = true
                    end
                    if not valid then break end
                    routes[#routes + 1] = route
                end
            end
            if not current() then return end
            local function writeRow(ownerCurrent, object, method, ...)
                if not ownerCurrent() then return false end
                local args, count = { ... }, select("#", ...)
                local bindings = object.objectiveSourceWrites or {}
                object.objectiveSourceWrites = bindings
                local binding = { current = ownerCurrent, args = args, count = count }
                bindings[method] = binding
                local ok = pcall(object[method], object, unpack(args, 1, count))
                local fresh = ownerCurrent()
                if not fresh then
                    local latest = object.objectiveSourceWrites
                    local newer = latest and latest[method]
                    if newer and newer ~= binding and not newer.repairing then
                        newer.repairing = true
                        local repairCurrent = newer.current()
                        if repairCurrent and object.objectiveSourceWrites == latest and latest[method] == newer then
                            pcall(object[method], object, unpack(newer.args, 1, newer.count))
                        end
                        newer.repairing = nil
                    end
                end
                return ok and fresh
            end
            if valid and #routes > 0 then
                local heading, notice = addon.Read(localize, "string", "OBJECTIVE_ITEM_SOURCES"),
                    addon.Read(localize, "string", "OBJECTIVE_ITEM_SOURCES_NOTICE")
                if not current() then return end
                if heading and notice then
                    if line(heading, "section", nil, nil, current) == false or line(notice, nil, nil, nil, current) == false then return end
                    local offset = 0
                    for _, route in ipairs(routes) do
                        local name = addon.Read(nameGetter, "string", route.itemID)
                        if not current() then return end
                        if not name or #name > 1024 or not name:find("%S") then
                            name = addon.Clean(rawget(route.definition, "name"), "string")
                            if not name or #name > 2000 or not name:find("%S") then name = string.format("#%.0f", route.itemID) end
                        end
                        if line(name, "section", nil, nil, current) == false then return end
                        local slot = "objectiveItem:" .. string.format("%.0f", route.itemID) .. ":"
                        if alternativePlaces(route.containers, self.objectiveContainerButtons, nil, slot, current, offset, function() return addon.Read(self.frame.IsShown, "boolean", self.frame) == true and current() end, writeRow) == false then return end
                        offset = offset + #route.containers
                    end
                end
            end
        end

        return true
        end
        do
            local paymentGetter, paymentChecker, localize = addon.QuestPayment, issecretvalue, addon.L
            local currencyRoot = C_CurrencyInfo
            local currency = addon.Clean(currencyRoot, "table")
            local formatter = currency and rawget(currency, "GetCoinTextureString")
            local database, selectedLocale, localeGetter = addon.db, addon.db.locale, GetLocale
            local gameLocale = addon.Read(localeGetter, "string")
            local amount = addon.Clean(rawget(q, "requiredMoney"), "number")
            local result, rawFormatted
            local function paymentCurrent()
                local language = addon.Read(localeGetter, "string")
                local ok, same = pcall(function()
                    return portraitCardCurrent() and addon.quests[id] == definition and rawget(q, "id") == id and
                        rawget(q, "requiredMoney") == amount and addon.QuestPayment == paymentGetter and issecretvalue == paymentChecker and
                        addon.L == localize and addon.db == database and database.locale == selectedLocale and
                        GetLocale == localeGetter and language == gameLocale and C_CurrencyInfo == currencyRoot and
                        (not currency or rawget(currency, "GetCoinTextureString") == formatter) and
                        (not result or (rawget(result, "amount") == amount and rawget(result, "formatted") == rawFormatted))
                end)
                return ok and same == true
            end
            if not portraitCardCurrent() then return end
            if amount and amount > 0 and amount <= 9007199254740991 and amount % 1 == 0 then
                if not paymentCurrent() then return end
                local candidate = addon.Read(paymentGetter, "table", id, paymentCurrent)
                if not paymentCurrent() then return end
                if candidate then
                    local candidateFormatted = rawget(candidate, "formatted")
                    local value = addon.Clean(rawget(candidate, "amount"), "number")
                    local formatted = addon.Clean(candidateFormatted, "string")
                    if not paymentCurrent() then return end
                    if value == amount then
                        result, rawFormatted = candidate, candidateFormatted
                        if not paymentCurrent() then return end
                        if not formatted or #formatted > 4096 or not formatted:find("%S") then formatted = addon.Read(localize, "string", "MONEY_COPPER", amount) end
                        if not paymentCurrent() then return end
                        local title = formatted and addon.Read(localize, "string", "QUEST_PAYMENT", formatted)
                        local notice = addon.Read(localize, "string", "QUEST_PAYMENT_NOTICE")
                        if not paymentCurrent() then return end
                        if title and title:find("%S") and notice and notice:find("%S") then
                            if line(title, nil, nil, nil, paymentCurrent) == false or
                                (referencesExpanded and line(notice, nil, nil, nil, paymentCurrent) == false) then return end
                        end
                    end
                elseif not paymentCurrent() then return end
            end
        end
        local rewards, rewardOrigin = rewardData(id)
        local items = rewards and addon.Clean(rewards.items, "table")
        local choices = rewards and addon.Clean(rewards.choices, "table")
        local hidden = rewards and addon.Clean(rewards.hidden, "boolean") == true
        local xp = rewards and addon.Clean(rewards.xp, "number")
        local money = rewards and addon.Clean(rewards.money, "number")
        local validXP = xp and xp >= 0 and xp % 1 == 0
        if not hidden and items and choices and (#items > 0 or #choices > 0 or validXP or (money and money > 0)) then
            line(addon.L("DETAIL_REWARDS"), "caption")
        end
        if not hidden and items and choices then
            local function lootGroup(entries, kind, heading)
                if #entries == 0 then return true end
                if line(addon.L(heading), "caption") == false then return false end
                local columns = contentWidth >= 340 and 2 or 1
                local tileWidth = (contentWidth - (columns - 1) * 8) / columns
                local top, rowHeight = y, 0
                for index, item in ipairs(entries) do
                    local column = (index - 1) % columns
                    y = top
                    local rewardText = addon.Clean(item.count, "number") == 1 and item.name or addon.L("REWARD_ITEM", item.name, item.count)
                    if line(rewardText, nil,
                        { item = item, origin = rewardOrigin, source = addon.Clean(rewards.source, "string"), kind = kind, index = index }) == false then return false end
                    if not portraitCardCurrent() then return false end
                    local field, button = pool[n], self.rewardButtons[rewardIndex]
                    local binding = button and button.rewardBinding
                    local function tileCurrent()
                        return portraitCardCurrent() and (not binding or button.rewardBinding == binding)
                    end
                    local function write(object, method, ...) return self:QuestListWrite(object, method, tileCurrent, ...) end
                    local x = 4 + column * (tileWidth + 8)
                    local hasIcon = binding and binding.kind == kind and binding.index == index and button:IsShown()
                    if hasIcon then
                        button.rewardLabel, button.rewardTileWidth = field, tileWidth
                        if not write(button, "ClearAllPoints") or not write(button, "SetPoint", "TOPLEFT", x, -top) then return false end
                    end
                    if not write(field, "SetWidth", tileWidth - (hasIcon and 40 or 0)) or not write(field, "ClearAllPoints") or
                        not write(field, "SetPoint", "TOPLEFT", x + (hasIcon and 40 or 0), -top) then return false end
                    local height = measuredHeight(field, 20)
                    if not tileCurrent() then return false end
                    rowHeight = math.max(rowHeight, hasIcon and 32 or 20, height)
                    if column == columns - 1 or index == #entries then
                        top, rowHeight = top + rowHeight + 8, 0
                    end
                end
                y = top
                return true
            end
            if not lootGroup(items, "items", "DETAIL_GUARANTEED") or not lootGroup(choices, "choices", "REWARD_CHOICES") then return end

            local gains = {}
            if validXP then
                gains[#gains + 1] = addon.L("REWARD_XP", xp)
            end
            if money and money > 0 then
                local formatted = addon.Read(GetCoinTextureString, "string", money)
                local gain = formatted and (addon.L("REWARD_MONEY") .. ": " .. formatted) or addon.L("REWARD_MONEY_UNKNOWN")
                gains[#gains + 1] = gain
            end
            if #gains > 0 then line(table.concat(gains, " · "), "caption") end
        end
        do
            local getter, checker, localize = addon.Clean(addon.DialogueText, "function"), issecretvalue, addon.L
            if getter then
                local database, selectedLocale, localeGetter = addon.db, addon.db.locale, GetLocale
                local gameLocale = addon.Read(localeGetter, "string")
                local engineGetter = renderEngine and renderEngine.Current
                local function baseCurrent()
                    local language = addon.Read(localeGetter, "string")
                    local fresh = engineGetter == nil or addon.Read(engineGetter, "boolean", renderEngine) == true
                    local ok, same = pcall(function()
                        return fresh and portraitCardCurrent() and addon.quests[id] == definition and rawget(q, "id") == id and
                            addon.DialogueText == getter and issecretvalue == checker and addon.L == localize and
                            addon.db == database and database.locale == selectedLocale and GetLocale == localeGetter and
                            language == gameLocale and renderEngine.Current == engineGetter
                    end)
                    return ok and same == true
                end
                local result = addon.Read(getter, "table", id, baseCurrent)
                if not portraitCardCurrent() then return end
                if result and baseCurrent() then
                    local source, stage, text, proof = addon.Clean(rawget(result, "source"), "string"),
                        addon.Clean(rawget(result, "stage"), "string"), addon.Clean(rawget(result, "text"), "string"),
                        addon.Clean(rawget(result, "current"), "function")
                    local function dialogueCurrent()
                        if not baseCurrent() or addon.Read(proof, "boolean") ~= true or not baseCurrent() then return false end
                        local ok, same = pcall(function()
                            return portraitCardCurrent() and addon.quests[id] == definition and rawget(q, "id") == id and
                                rawget(result, "source") == source and rawget(result, "stage") == stage and
                                rawget(result, "text") == text and rawget(result, "current") == proof and
                                addon.DialogueText == getter and issecretvalue == checker and addon.L == localize and
                                addon.db == database and database.locale == selectedLocale and GetLocale == localeGetter and
                                renderEngine.Current == engineGetter
                        end)
                        return ok and same == true
                    end
                    if not portraitCardCurrent() then return end
                    if source == "dialogue" and (stage == "progress" or stage == "completion") and proof and
                        text and #text <= 30000 and text:find("%S") and dialogueCurrent() then
                        local heading = addon.Read(localize, "string", stage == "progress" and "DIALOGUE_PROGRESS_TEXT" or "DIALOGUE_TURNIN_TEXT")
                        if not portraitCardCurrent() then return end
                        if heading and dialogueCurrent() then
                            if line(heading, "section", nil, nil, dialogueCurrent) == false or
                                line(text, nil, nil, nil, dialogueCurrent) == false then return end
                        end
                    end
                end
            end
        end
        local function acquisitionItems()
        local starterSource = addon.Clean(q.start, "table")
        local starterID = starterSource and addon.Clean(rawget(starterSource, "itemID"), "number")
        local starterName = starterSource and addon.Clean(rawget(starterSource, "name"), "string")
        local starterChecker, starterIconGetter = issecretvalue, addon.ItemIcon
        local starterNameGetter, starterCountGetter = addon.ItemName, addon.CarriedItemCount
        local starterCount
        local typedStarter = false
        if starterID and starterID > 0 and starterID <= 9007199254740991 and starterID % 1 == 0 then
            local ok, typed = pcall(function()
                return rawget(starterSource, "npcID") == nil and rawget(starterSource, "objectID") == nil and
                    q.startAlternatives == nil and true or false
            end)
            typedStarter = ok and typed == true
        end
        local function starterCurrent(binding)
            if not locationCurrent() or addon.quests[id] ~= definition or q.start ~= starterSource or
                issecretvalue ~= starterChecker or addon.ItemIcon ~= starterIconGetter or
                addon.ItemName ~= starterNameGetter or addon.CarriedItemCount ~= starterCountGetter or
                addon.Clean(rawget(starterSource, "itemID"), "number") ~= starterID then return false end
            local ok, same = pcall(function()
                return self.quest == renderQuest and self.dungeon == renderDungeon and self.engine == renderEngine and
                    addon.char == renderCharacter and self.rewardGeneration == rewardGeneration and
                    self.reportedGeneration == reportedGeneration and addon.quests[id] == definition and q.start == starterSource and
                    rawget(starterSource, "itemID") == starterID and rawget(starterSource, "name") == starterName and
                    rawget(starterSource, "npcID") == nil and rawget(starterSource, "objectID") == nil and q.startAlternatives == nil and
                    (not binding or (binding.id == starterID and binding.role == "starter" and binding.sourceField == "start")) and
                    issecretvalue == starterChecker and addon.ItemIcon == starterIconGetter and
                    addon.ItemName == starterNameGetter and addon.CarriedItemCount == starterCountGetter and true or false
            end)
            return ok and same == true
        end
        if q.startAlternatives then
            local alternatives, remaining, snapshot = q.startAlternatives, {}, {}
            local count = #alternatives
            local previewCount = not start and math.min(count, 2) or 0
            for index, point in ipairs(alternatives) do
                snapshot[index] = point
                if index > previewCount then remaining[#remaining + 1] = point end
            end
            local function alternativesCurrent()
                if not locationCurrent() or addon.quests[id] ~= definition or q.startAlternatives ~= alternatives or
                    #alternatives ~= count or addon.Clean(q.start, "table") ~= start then return false end
                for index, point in ipairs(snapshot) do if alternatives[index] ~= point then return false end end
                return locationCurrent()
            end
            if #remaining > 0 and alternativePlaces(remaining, self.startButtons, "START_ALTERNATIVES", "startAlternative:", alternativesCurrent) == false then return end
        else
            if typedStarter and not starterCurrent() then return end
            local starting = place(q.start)
            if not starting or (typedStarter and not starterCurrent()) then return end
            local starterBinding
            if typedStarter then
                starterCount = carried(starterID)
                if not starterCurrent() then return end
                local icon = starterID <= 4294967295 and addon.Read(starterIconGetter, "number", starterID) or nil
                if not starterCurrent() then return end
                if icon and icon > 0 and icon <= 4294967295 and icon % 1 == 0 then
                    starterBinding = { id = starterID, texture = icon, role = "starter", sourceField = "start" }
                    starterBinding.current = function() return starterCurrent(starterBinding) end
                end
            end
            if starterBinding and line(starting, nil, nil, starterBinding) == false then return end
            if reported(q.start, "start") == false then return end
        end
        local start = q.start
        if start and start.itemID then
            local count = typedStarter and starterCount or nil
            if not typedStarter then count = carried(start.itemID) end
            if typedStarter and not starterCurrent() then return end
            if count then line(count) end
            local shown = false
            local classes = addon.Clean(start.itemClasses, "table")
            if classes then
                local localized = addon.Clean(LOCALIZED_CLASS_NAMES_MALE, "table") or
                    addon.Read(LocalizedClassList, "table", false)
                local names, seen = {}, {}
                for i = 1, math.min(#classes, 13) do
                    local token = addon.Clean(classes[i], "string")
                    if token and #token > 0 and #token <= 100 and not seen[token] then
                        seen[token] = true
                        local name = localized and addon.Read(function() return localized[token] end, "string")
                        names[#names + 1] = audienceName("classes", token, name and name ~= "" and #name <= 500 and name or token)
                    end
                end
                if #names > 0 then line(addon.L("ITEM_CLASSES", table.concat(names, ", "))); shown = true end
            end
            local minimum = addon.Clean(start.itemMinLevel, "number")
            if minimum and minimum > 0 and minimum % 1 == 0 then
                line(addon.L("ITEM_MIN_LEVEL", minimum)); shown = true
            end
            if shown then line(addon.L("ITEM_REQUIREMENTS_NOTICE")) end
        end
        if typedStarter then
            -- Route facts remain separate from the item that starts the quest.
            local routes, snapshots, mappedDrops = {}, {}, {}
            local mapNamespace, mapGetter = C_Map, C_Map and C_Map.GetMapInfo
            local giverGetter, dungeonGetter = addon.GiverName, addon.DungeonName
            local function capture(object, fields, list, exact)
                local values, count = {}, 0
                if exact then for _ in next, object do count = count + 1 end end
                for _, field in ipairs(fields) do values[field] = rawget(object, field) end
                snapshots[#snapshots + 1] = { object = object, values = values, fields = fields, length = list and #object or nil }
            end
            capture(starterSource, { "containerSource", "dropNPCID", "dropName", "dungeonKey", "dropSources" })
            local function acquisitionCurrent()
                if not starterCurrent() then return false end
                local ok, same = pcall(function()
                    if C_Map ~= mapNamespace or (mapNamespace and mapNamespace.GetMapInfo ~= mapGetter) or
                        addon.GiverName ~= giverGetter or addon.DungeonName ~= dungeonGetter then return false end
                    for _, snapshot in ipairs(snapshots) do
                        if snapshot.length and #snapshot.object ~= snapshot.length then return false end
                        if snapshot.count then
                            local count = 0; for _ in next, snapshot.object do count = count + 1 end
                            if count ~= snapshot.count then return false end
                        end
                        for _, field in ipairs(snapshot.fields) do
                            if rawget(snapshot.object, field) ~= snapshot.values[field] then return false end
                        end
                    end
                    return true
                end)
                return ok and same == true
            end
            local function positive(value)
                value = addon.Clean(value, "number")
                return value and value > 0 and value <= 9007199254740991 and value % 1 == 0 and value
            end
            local container = addon.Clean(rawget(starterSource, "containerSource"), "table")
            local containerName = container and addon.Clean(rawget(container, "name"), "string")
            local containerTyped, containerIsObject = pcall(function()
                return container and rawget(container, "npcID") == nil and rawget(container, "itemID") == nil and true or false
            end)
            if container and positive(rawget(container, "objectID")) and containerName and containerName:find("%S") and
                containerTyped and containerIsObject == true then
                capture(container, { "objectID", "name", "zoneName", "mapID", "x", "y", "reportedLocations" })
                local points = addon.Clean(rawget(container, "reportedLocations"), "table")
                if points then
                    capture(points, {}, true)
                    local length = #points
                    for index = 1, math.min(length, 100) do
                        local point = addon.Clean(rawget(points, index), "table")
                        capture(points, { index })
                        if point then capture(point, { "mapID", "x", "y", "zoneName" }) end
                    end
                end
                routes[#routes + 1] = { container = container }
            end
            local dropID = positive(rawget(starterSource, "dropNPCID"))
            if dropID then
                local dungeonName = addon.L("UNKNOWN_PLACE")
                for _, dungeon in ipairs(addon.dungeons) do
                    if dungeon.key == starterSource.dungeonKey then dungeonName = addon.DungeonName(dungeon); break end
                end
                if not acquisitionCurrent() then return end
                local name = giverName({ npcID = dropID, name = addon.Clean(starterSource.dropName, "string") or ("#" .. dropID) })
                if not acquisitionCurrent() then return end
                routes[#routes + 1] = { text = addon.L("ITEM_DROP_SOURCE", name, dungeonName) }
            end
            local drops = addon.Clean(rawget(starterSource, "dropSources"), "table")
            if drops then
                capture(drops, {}, true)
                for index = 1, math.min(#drops, 100) do
                    capture(drops, { index })
                    local drop = addon.Clean(rawget(drops, index), "table")
                    if drop then
                        capture(drop, { "npcID", "objectID", "itemID", "name", "locationName", "mapID", "x", "y", "zoneName", "reportedLocations" })
                        local points = addon.Clean(rawget(drop, "reportedLocations"), "table")
                        if points then
                            capture(points, {}, true)
                            for pointIndex = 1, math.min(#points, 100) do
                                capture(points, { pointIndex })
                                local point = addon.Clean(rawget(points, pointIndex), "table")
                                if point then capture(point, { "mapID", "x", "y", "zoneName" }) end
                            end
                        end
                        local name, location = addon.Clean(drop.name, "string"), addon.Clean(drop.locationName, "string")
                        if positive(drop.npcID) and name and name:find("%S") and location and location:find("%S") then
                            name = giverName(drop)
                            if not acquisitionCurrent() then return end
                            routes[#routes + 1] = { text = addon.L("ITEM_DROP_SOURCE", name, location) }
                            local map = positive(rawget(drop, "mapID"))
                            local reportedPoints = reportedPlaces(drop)
                            local ok, npcOnly = pcall(function()
                                return rawget(drop, "objectID") == nil and rawget(drop, "itemID") == nil and true or false
                            end)
                            if not acquisitionCurrent() then return end
                            if ok and npcOnly == true and drop.npcID <= 4294967295 and (map or reportedPoints) then mappedDrops[#mappedDrops + 1] = drop end
                        end
                    end
                end
            end
            if not acquisitionCurrent() then return end
            line(addon.L("ITEM_ACQUISITION"), "section")
            if #routes == 0 then line(addon.L("ITEM_ACQUISITION_UNKNOWN")) end
            for _, route in ipairs(routes) do
                if route.container then
                    if alternativePlaces({ route.container }, self.containerButtons, "CONTAINER_SOURCE", "container:", acquisitionCurrent) == false then return end
                else line(route.text) end
                if not acquisitionCurrent() then return end
            end
            if #mappedDrops > 0 and alternativePlaces(mappedDrops, self.dropButtons, "ITEM_DROP_LOCATIONS", "dropSource:", acquisitionCurrent) == false then return end
        end
        if q.finishAlternatives then
            if alternativePlaces(q.finishAlternatives, self.finishButtons, "POSSIBLE_TURNINS", "finishAlternative:") == false then return end
        elseif q.finish and q.finish ~= q.start then
            if reported(q.finish, "finish") == false then return end
        end
        local materialSource, materialGetter = q.completionQuests, engine.CompletionSteps
        local function materialCurrent()
            return current() and portraitCardCurrent() and addon.quests[id] == definition and
                q.completionQuests == materialSource and engine.CompletionSteps == materialGetter
        end
        local materials = addon.Read(materialGetter, "table", engine, id)
        if not materialCurrent() then return end
        if materials and #materials > 0 then
            line(addon.L("MATERIAL_QUESTS"), "section")
            line(addon.L("MATERIAL_NOTICE"))
            for index, entry in ipairs(materials) do
                local other, itemID = entry.id, entry.itemID
                local title = addon.QuestName(other)
                if not materialCurrent() then return end
                local status = entry.state.status
                local count = carried(itemID)
                if not materialCurrent() then return end
                local itemName = addon.Read(addon.ItemName, "string", itemID) or addon.L("MATERIAL_ITEM", itemID)
                if not materialCurrent() then return end
                local note = "|cff" .. COLOR[status] .. statusLabel(entry.state) .. "|r\n" .. itemName ..
                    (entry.unknown and status ~= "UNKNOWN" and (" — " .. addon.L("UNKNOWN")) or "") ..
                    (count and ("\n" .. count) or "")
                local row = self:MakeRow(self.detail, self.materialButtons, index, 59)
                row.questID, row.itemID = other, itemID
                row.title:SetText(title); row.note:SetText(note)
                row:SetEnabled(true)
                row:SetScript("OnClick", function()
                    if materialCurrent() and row.questID == other and row.itemID == itemID then self:InspectQuest(other) end
                end)
                y = self:LayoutRow(row, 59, y)
            end
        end
        return true
        end
        local descriptionGetter, descriptionChecker = addon.Description, issecretvalue
        local description = addon.Read(descriptionGetter, "string", id)
        local placeholder = addon.L("NO_TEXT")
        local database, localize, frame = addon.db, addon.L, self.frame
        local locale = database and rawget(database, "locale")
        local function narrativeCurrent()
            return portraitCardCurrent() and addon.quests[id] == definition and self.frame == frame and addon.db == database and
                (not database or rawget(database, "locale") == locale) and addon.L == localize and
                addon.Description == descriptionGetter and issecretvalue == descriptionChecker
        end
        if not narrativeCurrent() then return end
        if not description or #description > 30000 or not description:find("%S") then description = placeholder end
        if description ~= placeholder then
            local excerpt, long = description, false
            -- Native markup stays intact. Plain prose can safely use a character-bound excerpt.
            if not description:find("|", 1, true) then
                local position, characters = 1, 0
                while position <= #description and characters < 240 do
                    local byte = description:byte(position)
                    local width = byte >= 240 and byte <= 244 and 4 or (byte >= 224 and byte <= 239 and 3 or (byte >= 194 and byte <= 223 and 2 or 1))
                    for offset = 1, width - 1 do
                        local continuation = description:byte(position + offset)
                        if not continuation or continuation < 128 or continuation > 191 then width = 1; break end
                    end
                    position, characters = position + width, characters + 1
                end
                long = position <= #description
                if long and not narrativeExpanded then excerpt = description:sub(1, position - 1) .. "…" end
            end
            if line(addon.L("DETAIL_STORY"), "caption", nil, nil, narrativeCurrent) == false or
                line(excerpt, "story", nil, nil, narrativeCurrent) == false then return end
            if long then
                local toggle = self.narrativeToggle
                if not toggle then
                    toggle = CreateFrame("Button", nil, self.detail); toggle:SetWidth(contentWidth - 2)
                    toggle.label = label(toggle, "", 7, -5, contentWidth - 16, 13); toggle.title = toggle.label
                    if not narrativeCurrent() then return end
                    self.narrativeToggle = toggle
                end
                local function toggleCurrent() return narrativeCurrent() and self.narrativeToggle == toggle end
                local function write(object, method, ...) return self:QuestListWrite(object, method, toggleCurrent, ...) end
                if not write(toggle.label, "SetText", (narrativeExpanded and "− " or "+ ") .. addon.L(narrativeExpanded and "DETAIL_STORY_HIDE" or "DETAIL_STORY_READ")) then return end
                local height = math.max(28, measuredHeight(toggle.label, 18) + 8)
                if not write(toggle, "SetHeight", height) or not write(toggle, "ClearAllPoints") or
                    not write(toggle, "SetPoint", "TOPLEFT", 4, -y) or not write(toggle, "SetEnabled", true) then return end
                styleRow(toggle, "control", narrativeExpanded)
                if not toggleCurrent() or not write(toggle, "SetScript", "OnClick", function()
                    if not toggleCurrent() or addon.Read(frame.IsShown, "boolean", frame) ~= true or not toggleCurrent() then return end
                    self.detailNarrativeExpanded = not narrativeExpanded
                    self:RefreshDetail()
                end) or not write(toggle, "Show") then return end
                y = y + height + 6
            end
        end
        if not narrativeCurrent() then return end
        if not acquisitionPortraits(false) then return end
        local function nonemptySource(value)
            local list = addon.Clean(value, "table")
            return list and #list > 0 and #list <= 100
        end
        local sourceStart, sourceFinish = addon.Clean(q.start, "table"), addon.Clean(q.finish, "table")
        local starterID = sourceStart and addon.Clean(rawget(sourceStart, "itemID"), "number")
        local itemOnly = false
        if starterID and starterID > 0 and starterID <= 9007199254740991 and starterID % 1 == 0 then
            local ok, typed = pcall(function()
                return rawget(sourceStart, "npcID") == nil and rawget(sourceStart, "objectID") == nil and q.startAlternatives == nil
            end)
            itemOnly = ok and typed == true
        end
        local alternativeSource = addon.Clean(q.startAlternatives, "table")
        local extraStarters = alternativeSource and #alternativeSource > (sourceStart and 0 or 2) and #alternativeSource <= 100
        local acquisition = extraStarters or nonemptySource(q.finishAlternatives) or
            nonemptySource(q.completionQuests) or nonemptySource(q.objectiveItemSources) or itemOnly or
            (sourceStart and nonemptySource(sourceStart.reportedLocations)) or
            (sourceFinish and nonemptySource(sourceFinish.reportedLocations))
        if not narrativeCurrent() then return end
        if acquisition then
        do
            local toggle = self.referenceToggle
            if not toggle then
                toggle = CreateFrame("Button", nil, self.detail); toggle:SetWidth(contentWidth - 2)
                toggle.label = label(toggle, "", 7, -5, contentWidth - 16, 14); toggle.title = toggle.label
                toggle:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                self.referenceToggle = toggle
            end
            local frame, database, localize = self.frame, addon.db, addon.L
            if not portraitCardCurrent() or database ~= metadataDB or type(database) ~= "table" then return end
            local locale = rawget(database, "locale")
            local function referencesCurrent()
                return current() and portraitCardCurrent() and addon.UI == self and self.frame == frame and
                    self.referenceToggle == toggle and addon.quests[id] == definition and addon.db == database and
                    rawget(database, "locale") == locale and addon.L == localize
            end
            local function write(object, method, ...)
                if not referencesCurrent() then return false end
                local ok = pcall(object[method], object, ...)
                return ok and referencesCurrent()
            end
            if not write(toggle.label, "SetText", (referencesExpanded and "− " or "+ ") .. addon.L(referencesExpanded and "DETAIL_ACQUISITION_HIDE" or "DETAIL_ACQUISITION")) then return end
            local height = math.max(30, measuredHeight(toggle.label, 18) + 10)
            if not write(toggle, "SetHeight", height) or not write(toggle, "ClearAllPoints") or
                not write(toggle, "SetPoint", "TOPLEFT", 4, -y) or not write(toggle, "SetEnabled", true) then return end
            styleRow(toggle, "control", referencesExpanded)
            if not write(toggle, "SetScript", "OnClick", function()
                if not referencesCurrent() or addon.Read(frame.IsShown, "boolean", frame) ~= true or not referencesCurrent() then return end
                local scroll, getter, checker = self.detailScroll, self.detailScroll.GetVerticalScroll, issecretvalue
                local offset = addon.Read(getter, "number", scroll)
                if not referencesCurrent() or self.detailScroll ~= scroll or scroll.GetVerticalScroll ~= getter or issecretvalue ~= checker then return end
                self.detailReferencesExpanded = not referencesExpanded
                local generation = self:RefreshDetail()
                local function fresh()
                    return generation and self.detailScroll == scroll and scroll.GetVerticalScroll == getter and issecretvalue == checker and self.rewardGeneration == generation and self.quest == renderQuest and self.dungeon == renderDungeon and
                        self.engine == renderEngine and addon.char == renderCharacter and self.frame == frame and self.detailReferencesExpanded ~= referencesExpanded
                end
                if not fresh() or not offset or offset < 0 then return end
                local content = addon.Read(self.detail.GetHeight, "number", self.detail)
                local viewport = addon.Read(scroll.GetHeight, "number", scroll)
                if fresh() and content and content >= 0 and viewport and viewport > 0 then
                    scroll:SetVerticalScroll(math.min(offset, math.max(0, content - viewport)))
                end
            end) or not write(toggle, "Show") then return end
            y = y + height + 8
        end
            if referencesExpanded then
                if not acquisitionPortraits(true) or not acquisitionObjectives() or not acquisitionItems() then return end
            end
        end
        self:SetFooterEnabled(self.source, true)
    else
        self:SetFooterEnabled(self.source, false)
        if renderDungeon then
            local name = addon.Read(addon.DungeonName, "string", renderDungeon)
            if self.quest ~= renderQuest or self.dungeon ~= renderDungeon or self.rewardGeneration ~= rewardGeneration then return end
            line(name or addon.Clean(renderDungeon.name, "string") or addon.L("UNKNOWN_PLACE"), "title")
            if not self.entranceBinding then line(addon.L("DUNGEON_ENTRANCE_UNKNOWN"))
            elseif addon.Clean(self.entranceBinding.point.origin, "string") == "recorded" then
                line(addon.L("DUNGEON_ENTRANCE_RECORDED"))
            end
            local entrancePoint = self.entranceBinding and self.entranceBinding.point
            if entrancePoint and addon.Clean(entrancePoint.kind, "string") == "approach" then
                line(addon.L("DUNGEON_ENTRANCE_APPROACH"))
            end
            if entrancePoint and addon.Clean(entrancePoint.scope, "string") == "shared" then
                line(addon.L("DUNGEON_ENTRANCE_SHARED"))
            end
            if not self.overviewArt then
                self.overviewArt = self.detail:CreateTexture(nil, "ARTWORK")
            end
            self.overviewArt:SetSize(contentWidth, contentWidth)
            if not portraitCardCurrent() then return end
            self.overviewArt:ClearAllPoints(); self.overviewArt:SetPoint("TOPLEFT", 4, -y)
            if not portraitCardCurrent() then return end
            local painter = addon.Clean(addon.PaintDungeonArt, "function")
            local ok, painted, kind, aspect
            if painter then ok, painted, kind, aspect = pcall(painter, self.overviewArt, renderDungeon, "overview") end
            painted, kind = ok and addon.Clean(painted, "boolean"), ok and addon.Clean(kind, "string")
            aspect = ok and addon.Clean(aspect, "number")
            if not portraitCardCurrent() or addon.PaintDungeonArt ~= painter then return end
            if painted == true then
                local compact = kind == "generic"
                local height = kind == "art" and aspect and aspect > 0 and addon.Clean(contentWidth / aspect, "number") or nil
                if not portraitCardCurrent() then return end
                height = height and height > 0 and height or contentWidth
                self.overviewArt:SetSize(compact and 48 or contentWidth, compact and 48 or height)
                if not portraitCardCurrent() then return end
                self.overviewArt:ClearAllPoints(); self.overviewArt:SetPoint("TOPLEFT", compact and (contentWidth - 48) / 2 + 4 or 4, -y)
                if not portraitCardCurrent() then return end
                y = y + (compact and 56 or height + 8)
            end
            local minimum, maximum = addon.Clean(renderDungeon.minLevel, "number"), addon.Clean(renderDungeon.maxLevel, "number")
            if minimum and maximum and minimum > 0 and maximum >= minimum and minimum % 1 == 0 and maximum % 1 == 0 then
                line(addon.L("CATALOG_LEVELS", minimum, maximum))
            end
            local quests = addon.Clean(renderDungeon.quests, "table")
            local count = quests and #quests or 0
            line(addon.L("CATALOG_QUESTS", count))
            if count == 0 then line(addon.L("EMPTY")) end
            local plan, preparation = self.currentPlan, self.preparation
            local function promptCurrent()
                return portraitCardCurrent() and self.currentPlan == plan and self.preparation == preparation
            end
            local ownedPlan = plan and plan.engine == renderEngine and plan.dungeon == renderDungeon
            local emptyPreparation = preparation and ownedPlan and plan.preparationEmpty == true and #plan.rows > 0
            if count > 0 then
                local prompt = emptyPreparation and addon.L("PREPARATION_EMPTY", addon.L("QUESTS")) or
                    addon.L(ownedPlan and #plan.rows == 0 and "NO_CHARACTER_QUESTS" or "OVERVIEW_PICK")
                if not promptCurrent() or line(prompt, nil, nil, nil, promptCurrent) == false then return end
            end
        else line(addon.L("PICK")) end
    end
    if renderQuest and self.copyQuest == renderQuest and self.copy then
        self.copy:ClearAllPoints(); self.copy:SetPoint("TOPLEFT", 8, -(y + 6))
        setFont(self.copyHint, 13); self.copyHint:SetText(addon.L("COPY")); self.copyHint:Show()
        self.copy:Show()
        y = y + 6 + 26 + 8 + measuredHeight(self.copyHint, 18) + 8
    end
    if self.quest ~= renderQuest or self.dungeon ~= renderDungeon or self.rewardGeneration ~= rewardGeneration or
        self.engine ~= renderEngine or addon.char ~= renderCharacter then return end
    hideRest(pool, n)
    self.detail:SetHeight(math.max(1, y + 12))
    self:ApplyTheme()
    local fresh = not pendingAction or not renderEngine.Current or addon.Read(renderEngine.Current, "boolean", renderEngine) == true
    if not fresh or self.quest ~= renderQuest or self.dungeon ~= renderDungeon or self.rewardGeneration ~= rewardGeneration or
        self.engine ~= renderEngine or addon.char ~= renderCharacter then return end
    self.action = pendingAction
    local giverPlace = pendingGiver and pendingGiver.action.place
    if giverPlace and pendingGiver.same() and addon.quests[renderQuest] == pendingGiver.source and pendingGiver.source.start == giverPlace and
        addon.Clean(giverPlace.mapID, "number") == pendingGiver.map and addon.Clean(giverPlace.x, "number") == pendingGiver.x and
        addon.Clean(giverPlace.y, "number") == pendingGiver.y then
        self.giverAction, self.giverHasCoordinates = pendingGiver.action, pendingGiver.coordinates
        local binding = { action = pendingGiver.action }
        binding.current = function()
            local fresh = not renderEngine.Current or addon.Read(renderEngine.Current, "boolean", renderEngine) == true
            return fresh and portraitCardCurrent() and pendingGiver.same() and addon.UI == self and self.giverBinding == binding
                and self.giverAction == binding.action and addon.quests[renderQuest] == pendingGiver.source
                and pendingGiver.source.start == giverPlace and addon.Clean(giverPlace.mapID, "number") == pendingGiver.map
                and addon.Clean(giverPlace.x, "number") == pendingGiver.x and addon.Clean(giverPlace.y, "number") == pendingGiver.y
        end
        self.giverBinding = binding
        self:SetFooterLabel(self.giver, pendingGiver.coordinates and "VISIT_GIVER" or "GIVER_MAP")
        self:SetFooterEnabled(self.giver, true)
    end
    if not portraitCardCurrent() then return end
    return portraitCardCurrent() and rewardGeneration or nil
end

function UI:RefreshLanguagePreview()
    return self:Refresh(true)
end

function UI:Refresh(languageOnly, dataOnly)
    if not self.frame or not self.frame:IsShown() then return end
    if languageOnly ~= true and dataOnly ~= true then self.preparation = false end
    if addon.Theme and addon.Theme.RefreshFonts then addon.Theme.RefreshFonts() end
    self.title:SetText(addon.L("TITLE"))
    if not self:RefreshLanguageLabel() then return end
    self:RefreshFilterControls()
    self:SetFooterLabel(self.source, "SOURCE")
    local log = addon.Read(addon.QuestLogCapacity, "table")
    local count = log and addon.Clean(log.count, "number")
    local capacity = log and addon.Clean(log.capacity, "number")
    local known = count ~= nil and capacity ~= nil and count >= 0 and count % 1 == 0 and capacity > 0 and capacity % 1 == 0
    self.capacityStatus:SetText(known and addon.L("QUEST_LOG_CAPACITY", count, capacity) or "")
    self.capacityStatus:SetShown(known)
    if languageOnly == true or dataOnly == true then
        local reused, reason
        if dataOnly == true and languageOnly ~= true then reused, reason = self:RefreshCatalogData() end
        if not reused and reason ~= "superseded" then reused, reason = self:RefreshCatalogLanguage() end
        if reason == "superseded" then return true end
        if not reused then self:RefreshDungeons() end
    else self:RefreshDungeons() end
    self:RefreshQuests(); self:RefreshDetail()
end

function UI:Fit()
    local width = addon.Read(GetScreenWidth, "number") or 1400
    local height = addon.Read(GetScreenHeight, "number") or 900
    if width <= 0 or height <= 0 then return end
    local scale = math.min(1, width * 0.92 / 1100, height * 0.92 / 700)
    self.frame:SetScale(scale)
    local pos = addon.db.window
    local x = addon.Clean(pos.x, "number") or 0
    local y = addon.Clean(pos.y, "number") or 0
    local maxX, maxY = math.max(0, (width / scale - 1100) / 2), math.max(0, (height / scale - 700) / 2)
    x, y = math.max(-maxX, math.min(maxX, x)), math.max(-maxY, math.min(maxY, y))
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

function UI:Create()
    self:LoadFilters()
    FONT = STANDARD_TEXT_FONT or "Fonts\\ARIALN.TTF"
    local frame = CreateFrame("Frame", "DungeonProWindow", UIParent, "BackdropTemplate")
    frame:SetSize(1100, 700); frame:SetPoint("CENTER")
    self.frame = frame
    self:Fit()
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:SetFrameStrata("DIALOG"); frame:EnableMouse(true); frame:SetMovable(true)
    if type(frame.SetToplevel) == "function" then pcall(frame.SetToplevel, frame, true) end
    local function raiseWindow(f)
        if self.frame == f and type(f.Raise) == "function" then pcall(f.Raise, f) end
    end
    frame:SetScript("OnMouseDown", raiseWindow)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) raiseWindow(f); f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, relativePoint, x, y = f:GetPoint()
        if point ~= "CENTER" or relativePoint ~= "CENTER" then
            if f.GetCenter and UIParent.GetCenter then
                local ok, cx, cy = pcall(f.GetCenter, f)
                local parentOK, px, py = pcall(UIParent.GetCenter, UIParent)
                cx, cy, px, py = addon.Clean(cx, "number"), addon.Clean(cy, "number"),
                    addon.Clean(px, "number"), addon.Clean(py, "number")
                local fs = addon.Read(f.GetEffectiveScale, "number", f)
                local ps = addon.Read(UIParent.GetEffectiveScale, "number", UIParent)
                if ok and parentOK and cx and cy and px and py and fs and ps and fs > 0 then
                    x, y = cx - px * ps / fs, cy - py * ps / fs
                else x, y = nil, nil end
            else x, y = nil, nil end
        end
        x, y = addon.Clean(x, "number"), addon.Clean(y, "number")
        if x and y then addon.db.window = { x = x, y = y } end
        self:Fit()
    end)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
    frame:SetBackdropColor(0.045, 0.065, 0.085, 0.98)
    frame:SetBackdropBorderColor(0.7, 0.55, 0.27, 1)
    self.title = label(frame, addon.L("TITLE"), 16, -10, 145, 22)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -4, -4)
    local closeTheme = addon.Clean(addon.Theme, "table")
    if closeTheme then addon.Read(closeTheme.StyleCloseButton, "boolean", close) end
    local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    search:SetSize(330, 26); search:SetPoint("TOPRIGHT", -190, -14); search:SetAutoFocus(false)
    self.searchBox = search
    if type(search.SetTextInsets) == "function" then search:SetTextInsets(28, 30, 0, 0) end
    setInputFont(search)
    self.searchPlaceholder = label(search, "", 28, -6, 268, 13)
    search:SetScript("OnTextChanged", function(b, userInput)
        self.search = addon.Read(b.GetText, "string", b) or ""
        if self.searchPlaceholder then self.searchPlaceholder:SetShown(self.search == "") end
        if self.clearSearch then self.clearSearch:SetEnabled(self.search ~= "") end
        if addon.Clean(userInput, "boolean") == true then self:QueueSearch() else self:RefreshDungeons() end
    end)
    search:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(b) self:FlushPendingSearch(); b:ClearFocus() end)
    self.clearSearch = button(frame, "×", 25, function()
        local generation = self.catalogGeneration
        self.search = ""; self.searchBox:SetText("")
        if self.catalogGeneration == generation then self:RefreshDungeons() end
    end)
    self.clearSearch:SetSize(24, 24); self.clearSearch:SetPoint("RIGHT", search, "RIGHT", -3, 0)
    local function filterCurrent(control, field)
        local shown = addon.Read(frame.IsShown, "boolean", frame)
        return shown == true and addon.UI == self and self.frame == frame and self[field] == control
    end
    local rangeControl
    rangeControl = button(frame, "", 160, function()
        if not filterCurrent(rangeControl, "rangeButton") then return end
        self.range = not self.range; self:SaveFilters(); self:Refresh()
    end)
    self.rangeButton = rangeControl
    self.rangeButton:SetSize(160, 32); self.rangeButton:SetPoint("TOPLEFT", 178, -14)
    self.rangeButton.filterHeadingKey = "LEVEL_FILTER"
    local characterControl
    characterControl = button(frame, "", 100, function()
        if not filterCurrent(characterControl, "characterButton") then return end
        self.includeUnavailable = not self.includeUnavailable; self:SaveFilters(); self:Refresh()
    end)
    self.characterButton = characterControl
    self.characterButton:SetSize(100, 32); self.characterButton:SetPoint("TOPLEFT", 548, -66)
    local portrait = characterControl:CreateTexture(nil, "ARTWORK"); characterControl.filterIcon = portrait
    characterControl.filterPortrait = true; characterControl.filterHeadingKey = "CHARACTER_FILTER"
    portrait:SetSize(26, 26); portrait:SetPoint("TOPLEFT", characterControl, "TOPLEFT", 4, -3)
    if addon.Clean(portrait.SetAtlas, "function") then pcall(portrait.SetAtlas, portrait, "GM-indicator-player") end
    if addon.Clean(SetPortraitTexture, "function") then pcall(SetPortraitTexture, portrait, "player") end
    characterControl.filterCaption = label(characterControl, "", 38, -8, 56, 13)
    characterControl.filterList = {}
    for index = 1, 3 do
        local strip = characterControl:CreateTexture(nil, "ARTWORK")
        strip:SetTexture("Interface\\Buttons\\WHITE8X8"); strip:SetSize(18, 2)
        strip:SetPoint("TOPLEFT", characterControl, "TOPLEFT", 8, -9 - (index - 1) * 6)
        characterControl.filterList[index] = strip
    end
    for _, control in ipairs({ rangeControl, characterControl }) do
        control:SetScript("OnEnter", function() self:FilterHint(control) end)
        control:SetScript("OnLeave", function() self:HideNavigationHint() end)
    end
    local language = button(frame, "", 64, function() self:OpenLanguageMenu() end)
    self.language = language
    language:SetPoint("TOPRIGHT", -116, -14)
    local languageModule = addon.Clean(addon.Language, "table")
    if languageModule then addon.Read(languageModule.Attach, "boolean", languageModule, language, self) end
    for _, entry in ipairs({ { "issue", -80 }, { "support", -48 } }) do
        local key = entry[1]
        local control = CreateFrame("Button", nil, frame); self[key .. "Link"] = control
        control:SetSize(24, 24); control:SetPoint("TOPRIGHT", entry[2], -14)
        local icon = control:CreateTexture(nil, "ARTWORK"); control.icon = icon
        icon:SetSize(16, 16); icon:SetPoint("CENTER", control, "CENTER", 0, key == "support" and 3 or 0)
        if key == "support" then
            icon:SetTexture("Interface\\COMMON\\friendship-heart"); icon:SetTexCoord(.21875, .78125, .09375, .6875)
            if type(icon.SetVertexColor) == "function" then icon:SetVertexColor(1, .36, .35, 1) end
        else
            local ok = type(icon.SetAtlas) == "function" and pcall(icon.SetAtlas, icon, "transmog-icon-chat")
            if not ok or addon.Read(icon.GetAtlas, "string", icon) ~= "transmog-icon-chat" then icon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up") end
        end
        icon:Show()
        control:SetScript("OnClick", function() self:ShowDeveloperLink(key) end)
        control:SetScript("OnEnter", function() if type(icon.SetAlpha) == "function" then icon:SetAlpha(1) end; self:DeveloperLinkHint(control, key) end)
        control:SetScript("OnLeave", function() if type(icon.SetAlpha) == "function" then icon:SetAlpha(.76) end; self:HideNavigationHint() end)
        if type(icon.SetAlpha) == "function" then icon:SetAlpha(.76) end
    end
    self.heading = label(frame, "", 278, -66, 258, 26)
    self.catalog, self.catalogScroll = scrolling(frame, 12, -66, 238, 622)
    self.searchHint = label(self.catalog, "", 4, 0, 202, 13)
    self.catalogNotice = label(self.catalog, "", 4, 0, 202, 13)
    self.questList, self.questScroll = scrolling(frame, 278, -100, 370, 588)
    self.detail, self.detailScroll = scrolling(frame, 674, -66, 400, 622)
    self.source = button(self.detail, "", 32, function() if self.quest then self:CopyLink(self.quest) end end)
    self.source:SetPoint("TOPRIGHT", self.detail, "TOPRIGHT", -4, 0)
    self.giver = button(self.detail, "", 32, function()
        if self.giverAction then
            self:DispatchDetail(self.giverAction, not self.giverHasCoordinates, true)
        end
    end)
    self.giver:SetPoint("TOPRIGHT", self.detail, "TOPRIGHT", -40, 0)
    for _, control in ipairs({ self.giver, self.source }) do
        control:SetHeight(32)
        if type(control.SetMotionScriptsWhileDisabled) == "function" then pcall(control.SetMotionScriptsWhileDisabled, control, true) end
        local icon = control:CreateTexture(nil, "ARTWORK"); control.footerIcon = icon
        icon:SetSize(24, 24); icon:SetPoint("CENTER", control, "CENTER", 0, 0)
        icon:SetTexture(control == self.giver and "Interface\\Minimap\\MinimapArrow" or "Interface\\AddOns\\DungeonPro\\Media\\Icons\\Wowhead")
        if control == self.source then icon:SetTexCoord(0, .75, 0, .75) end
        icon:Show()
        control:SetScript("OnMouseDown", function(_, mouse) if mouse == "LeftButton" then control.footerPressed = true; self:RefreshFooterIcon(control) end end)
        control:SetScript("OnMouseUp", function() control.footerPressed = false; self:RefreshFooterIcon(control) end)
        control:SetScript("OnHide", function() control.footerHovered, control.footerPressed = false, false; self:RefreshFooterIcon(control) end)
    end
    self:SetFooterLabel(self.source, "SOURCE"); self:SetFooterLabel(self.giver, "VISIT_GIVER")
    local function navigationHint(control, destination, bodyKey)
        control:SetScript("OnEnter", function()
            if control.footerIcon then control.footerHovered = true; self:RefreshFooterIcon(control) end
            self:HideNavigationHint()
            local quest, dungeon, generation = self.quest, self.dungeon, self.rewardGeneration
            local tip = addon.Clean(GameTooltip, "table") or addon.Clean(GameTooltip, "userdata")
            local function current()
                return addon.UI == self and self.frame == frame and self.quest == quest and self.dungeon == dungeon and
                    self.rewardGeneration == generation and GameTooltip == tip and addon.Read(frame.IsShown, "boolean", frame) == true
            end
            local point = destination and destination()
            if not tip or (not point and not bodyKey) or not current() then return end
            local text = bodyKey and addon.L(bodyKey) or addon.Read(giverName, "string", point)
            local zone = point and addon.Clean(point.zoneName, "string")
            local x, y = point and addon.Clean(point.x, "number"), point and addon.Clean(point.y, "number")
            if text and zone and zone:find("%S") then text = text .. " — " .. zone end
            if text and x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 then text = text .. string.format(" (%.1f, %.1f)", x, y) end
            if text and point and addon.Clean(point.origin, "string") == "recorded" then
                text = text .. "\n" .. addon.L("DUNGEON_ENTRANCE_RECORDED")
                local source = addon.Clean(point.source, "string")
                if source and #source <= 2048 and source:match("^https://") then text = text .. "\n" .. source end
            end
            if text and point and addon.Clean(point.kind, "string") == "approach" then
                text = text .. "\n" .. addon.L("DUNGEON_ENTRANCE_APPROACH")
            end
            if text and point and addon.Clean(point.scope, "string") == "shared" then
                text = text .. "\n" .. addon.L("DUNGEON_ENTRANCE_SHARED")
            end
            local title = control.footerLabelKey and addon.L(control.footerLabelKey) or addon.Read(control.GetText, "string", control)
            if not text or not title or not current() then return end
            local held = { tip = tip, button = control }; self.navigationTooltip = held
            for _, call in ipairs({ { "SetOwner", control, "ANCHOR_RIGHT" }, { "SetText", title }, { "AddLine", text, 1, 1, 1, true }, { "Show" } }) do
                if not current() or self.navigationTooltip ~= held then return end
                local fn = addon.Clean(tip[call[1]], "function")
                if not fn or not pcall(fn, tip, unpack(call, 2)) then self:HideNavigationHint(); return end
                if not current() or addon.Read(tip.IsOwned, "boolean", tip, control) ~= true or not current() then self:HideNavigationHint(); return end
            end
        end)
        control:SetScript("OnLeave", function()
            if control.footerIcon then control.footerHovered, control.footerPressed = false, false; self:RefreshFooterIcon(control) end
            self:HideNavigationHint()
        end)
    end
    navigationHint(self.giver, function() local action = self:NavigationDestination(false); return action and action.place end)
    navigationHint(self.source, nil, "COPY")
    self.capacityStatus = label(frame, "", 350, -22, 220, 12)
    self.capacityStatus:Hide()
    self.frame, self.cards, self.rows, self.details, self.chainButtons, self.branchButtons = frame, {}, {}, {}, {}, {}
    self.materialButtons, self.catalogInspectButtons = {}, {}
    self.requirementButtons, self.branchInspectButtons = {}, {}
    self.actionButtons, self.actionInspectButtons, self.preparationForButtons = {}, {}, {}
    self.startButtons, self.finishButtons, self.containerButtons, self.dropButtons, self.giverButtons = {}, {}, {}, {}, {}
    self.objectiveContainerButtons = {}
    UISpecialFrames[#UISpecialFrames + 1] = "DungeonProWindow"
    for _, d in ipairs(addon.dungeons) do if d.key == addon.char.selectedDungeon then self.dungeon = d end end
    frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    frame:RegisterEvent("UI_SCALE_CHANGED")
    frame:SetScript("OnEvent", function(f, event)
        if (event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED") and
            addon.Read(f.IsShown, "boolean", f) == true then self:Fit() end
    end)
    frame:SetScript("OnShow", function(f) raiseWindow(f); self:Fit(); self.preparation = false; self:Refresh(nil, true) end)
    frame:SetScript("OnHide", function() local pending = self.developerLinkRequest; self.developerLinkRequest = nil; if pending and type(StaticPopup_Hide) == "function" then pcall(StaticPopup_Hide, "DUNGEONPRO_COPY_DEVELOPER_LINK") end; self:HideNavigationHint(); local language = addon.Clean(addon.Language, "table"); if language then addon.Read(language.Cancel, "boolean", language, self) end; self.pendingSearch = nil; self.detailReferencesExpanded, self.detailChainExpanded, self.detailNarrativeExpanded = false, false, false; self.storyStates, self.storyOrder = nil, nil; if not self:ResetQuestLogControl() then return end; self.detailActionChoice = nil; self.languageMenuRevision = {}; self:ResetHistoryReading(); self:ResetRewardPresentation(); self:CloseCopyLink() end)
    self:ApplyTheme()
    frame:Hide()
end

function UI:Toggle()
    if not self.frame then self:Create() end
    self.frame:SetShown(not self.frame:IsShown())
end
addon.listeners[#addon.listeners + 1] = function(reason) UI:Refresh(nil, reason == "data") end
