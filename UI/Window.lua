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
    warning = { size = 15, minimum = 20, before = 4, color = { 1, .35, .3 } },
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

for name, method in pairs(addon.QuestNavigation) do UI[name] = method end
for name, method in pairs(addon.QuestHistory) do UI[name] = method end
for name, method in pairs(addon.PreparationOverviewUI) do UI[name] = method end
for name, method in pairs(addon.DungeonMapUI or {}) do UI[name] = method end

function UI:QuestLevelPalette(questLevel, ownerCurrent)
    local levelGetter, effectiveGetter, trivialGetter = UnitLevel, UnitEffectiveLevel, UnitQuestTrivialLevelRange
    local colorGetter, checker = GetQuestDifficultyColor, issecretvalue
    local function number(getter, minimum)
        local value = addon.Read(getter, "number", "player")
        return value and value >= minimum and value <= 9007199254740991 and value % 1 == 0 and value or nil
    end
    local level = number(levelGetter, 1)
    local effective = number(effectiveGetter, 1)
    local trivial = number(trivialGetter, 0)
    local color, components, hex
    local function current()
        if not ownerCurrent() or UnitLevel ~= levelGetter or UnitEffectiveLevel ~= effectiveGetter or
            UnitQuestTrivialLevelRange ~= trivialGetter or GetQuestDifficultyColor ~= colorGetter or issecretvalue ~= checker then return false end
        local freshLevel = number(levelGetter, 1)
        local ok, same = pcall(function()
            if color and components then
                for key, value in pairs(components) do if rawget(color, key) ~= value then return false end end
            end
            return ownerCurrent() and UnitLevel == levelGetter and UnitEffectiveLevel == effectiveGetter and
                UnitQuestTrivialLevelRange == trivialGetter and GetQuestDifficultyColor == colorGetter and
                issecretvalue == checker and freshLevel == level
        end)
        return ok and same == true
    end
    if not current() then return nil end
    if level and questLevel then
        color = addon.Read(colorGetter, "table", questLevel)
        if not current() then return nil end
        local afterEffective, afterTrivial = number(effectiveGetter, 1), number(trivialGetter, 0)
        if not current() or afterEffective ~= effective or afterTrivial ~= trivial then return nil end
        if color then
            local r, g, b = addon.Clean(rawget(color, "r"), "number"), addon.Clean(rawget(color, "g"), "number"), addon.Clean(rawget(color, "b"), "number")
            if not current() then return nil end
            if r and g and b and r >= 0 and r <= 1 and g >= 0 and g <= 1 and b >= 0 and b <= 1 then
                components = { r = r, g = g, b = b }
                if not current() then return nil end
                hex = string.format("%02x%02x%02x", math.floor(r * 255 + .5), math.floor(g * 255 + .5), math.floor(b * 255 + .5))
            end
        end
    end
    return { level = level, difficulty = hex, current = current }
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
    if not write(control.filterCaption, "ClearAllPoints") or
        not write(control.filterCaption, "SetPoint", "TOPLEFT", control, "TOPLEFT", all and 8 or 38, -8) or
        not write(control.filterCaption, "SetWidth", all and 84 or 56) or
        not write(control.filterCaption, "SetJustifyH", all and "CENTER" or "LEFT") then return end
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

local function giverName(place, ownerCurrent, proofs, fallback)
    place = addon.Clean(place, "table")
    if not place then return addon.L("UNKNOWN_PLACE") end
    if proofs then
        local getter = addon.SourceName
        if type(getter) == "function" then
            local ok, name, proof = pcall(getter, place, ownerCurrent)
            if addon.SourceName ~= getter or (ownerCurrent and not ownerCurrent()) then return nil end
            name, proof = addon.Clean(name, "string"), addon.Clean(proof, "function")
            if ok and proof and addon.Read(proof, "boolean") == true then
                if addon.SourceName ~= getter or (ownerCurrent and not ownerCurrent()) then return nil end
                proofs[#proofs + 1] = proof
                if name and #name <= 1024 and name:find("%S") then return name end
            end
        end
    end
    if fallback then return fallback end
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
    if type(addon.SearchFold) == "function" then
        local folded = addon.SearchFold(value)
        if not folded then return value end
        -- Normalize common pasted typography in search keys, never displayed names.
        return folded:gsub("’", "'"):gsub("‧", "·"):gsub("\194\160", " "):gsub("\227\128\128", " "):gsub("^%s+", ""):gsub("%s+$", "")
    end
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
    self:RetainNavigationHint(held, current)
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
    self:RetainNavigationHint(held, current)
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
    local revision = {}; self.copyRevision = revision
    self.copyQuest, self.copyReturn = nil, nil
    local box, hint, frame, character = self.copy, self.copyHint, self.frame, addon.char
    local writer, checker = self.QuestListWrite, issecretvalue
    local function current()
        return addon.UI == self and self.copyRevision == revision and self.copyQuest == nil and self.copyReturn == nil and
            self.copy == box and self.copyHint == hint and self.frame == frame and addon.char == character and
            self.QuestListWrite == writer and issecretvalue == checker
    end
    local function write(object, method, ...)
        return not object or writer(self, object, method, current, ...)
    end
    if not write(box, "SetText", "") or not write(box, "Hide") or not write(box, "ClearFocus") then return false end
    if not write(hint, "SetText", "") or not write(hint, "Hide") then return false end
end

function UI:EscapeCopyLink()
    local saved = self.copyReturn
    if self:CloseCopyLink() == false then return end
    local revision = self.copyRevision
    self:RefreshDetail()
    if self.copyRevision ~= revision or not saved or self.quest ~= saved.quest or self.copyQuest ~= nil or
        addon.Read(self.frame.IsShown, "boolean", self.frame) ~= true then return end
    local generation, scroll, checker = self.rewardGeneration, self.detailScroll, issecretvalue
    local content = addon.Read(self.detail.GetHeight, "number", self.detail)
    local viewport = addon.Read(scroll.GetHeight, "number", scroll)
    local function current()
        return self.copyRevision == revision and self.rewardGeneration == generation and self.quest == saved.quest and
            self.copyQuest == nil and self.detailScroll == scroll and issecretvalue == checker
    end
    if not current() then return end
    if content and viewport and content >= 0 and viewport > 0 then
        self:WriteDetailScroll(scroll, math.min(saved.offset, math.max(0, content - viewport)), current)
    end
end

function UI:CopyLink(id)
    local previous, frame, quest, dungeon, engine, character = self.copyRevision, self.frame, self.quest, self.dungeon, self.engine, addon.char
    local scroll, detail, generation = self.detailScroll, self.detail, self.rewardGeneration
    local clean, read, checker, writer, refresh = addon.Clean, addon.Read, issecretvalue, self.QuestListWrite, self.RefreshDetail
    local initialShown = frame and frame.IsShown
    local function initial()
        return addon.UI == self and self.copyRevision == previous and self.frame == frame and self.quest == quest and
            self.dungeon == dungeon and self.engine == engine and addon.char == character and self.detailScroll == scroll and
            self.detail == detail and self.rewardGeneration == generation and addon.Clean == clean and addon.Read == read and
            issecretvalue == checker and self.QuestListWrite == writer and self.RefreshDetail == refresh and frame and frame.IsShown == initialShown
    end
    id = clean(id, "number")
    if not initial() or not id or id < 1 or id % 1 ~= 0 or id ~= quest or read(initialShown, "boolean", frame) ~= true or not initial() then return false end
    local revision = {}; self.copyRevision = revision
    local copyQuest, box, hint = self.copyQuest, self.copy, self.copyHint
    local function requestCurrent()
        return addon.UI == self and self.copyRevision == revision and self.frame == frame and self.quest == id and
            self.dungeon == dungeon and self.engine == engine and addon.char == character and self.detailScroll == scroll and
            self.detail == detail and self.copyQuest == copyQuest and self.copy == box and self.copyHint == hint and
            addon.Clean == clean and addon.Read == read and issecretvalue == checker and self.QuestListWrite == writer and self.RefreshDetail == refresh
    end
    if copyQuest ~= id then
        local getter = scroll.GetVerticalScroll
        local offset = read(getter, "number", scroll)
        if not requestCurrent() or self.rewardGeneration ~= generation or scroll.GetVerticalScroll ~= getter then return false end
        self.copyReturn = offset and offset >= 0 and { quest = id, offset = offset } or nil
    end
    if not box then
        local made = CreateFrame("EditBox", nil, detail, "InputBoxTemplate")
        if not requestCurrent() then return false end
        made:SetSize(326, 26); setInputFont(made); made:SetAutoFocus(false)
        if not requestCurrent() then return false end
        made:SetScript("OnEscapePressed", function() self:EscapeCopyLink() end)
        if not requestCurrent() then return false end
        local caption = label(made, "", 0, -34, 326, 13)
        if not requestCurrent() then return false end
        box, hint = made, caption
        self.copy, self.copyHint = box, hint
    end
    copyQuest = id; self.copyQuest = id
    if not writer(self, box, "SetText", requestCurrent, "https://www.wowhead.com/forever/quest=" .. id) then return false end
    refresh(self)
    if not requestCurrent() then return false end
    generation = self.rewardGeneration
    local shown, contentGetter, viewportGetter = box.IsShown, detail.GetHeight, scroll.GetHeight
    local scrollSetter, focus, highlight = scroll.SetVerticalScroll, box.SetFocus, box.HighlightText
    local function current()
        return requestCurrent() and self.rewardGeneration == generation and box.IsShown == shown and
            detail.GetHeight == contentGetter and scroll.GetHeight == viewportGetter and
            scroll.SetVerticalScroll == scrollSetter and box.SetFocus == focus and box.HighlightText == highlight
    end
    if not current() or read(shown, "boolean", box) ~= true or not current() then return false end
    local content = read(contentGetter, "number", detail)
    if not current() then return false end
    local viewport = read(viewportGetter, "number", scroll)
    if not current() then return false end
    if content and viewport and content >= 0 and viewport > 0 then
        if not self:WriteDetailScroll(scroll, math.max(0, content - viewport), current) or not current() then return false end
    end
    local function focusCurrent()
        return addon.UI == self and self.copyRevision == revision and self.copyQuest == id and self.quest == id and
            self.copy == box and self.frame == frame and addon.char == character and box.SetFocus == focus and issecretvalue == checker
    end
    if not writer(self, box, "SetFocus", focusCurrent) or not current() then return false end
    local function highlightCurrent()
        return focusCurrent() and box.HighlightText == highlight
    end
    return writer(self, box, "HighlightText", highlightCurrent) and current()
end

-- Share the bounded owned writer with list layout; direct user scrolling stays native.
function UI:WriteDetailScroll(scroll, value, ownerCurrent)
    local frame, quest, dungeon, engine, character = self.frame, self.quest, self.dungeon, self.engine, addon.char
    local generation, revision, checker = self.rewardGeneration, self.detailNavigationRevision, issecretvalue
    local setter = addon.Clean(scroll.SetVerticalScroll, "function")
    value = addon.Clean(value, "number")
    if not setter or not value or value < 0 then return false end
    local function same()
        return addon.UI == self and self.frame == frame and self.detailScroll == scroll and self.quest == quest and
            self.dungeon == dungeon and self.engine == engine and addon.char == character and
            self.rewardGeneration == generation and self.detailNavigationRevision == revision and
            scroll.SetVerticalScroll == setter and issecretvalue == checker
    end
    local function current()
        return same() and (not ownerCurrent or ownerCurrent()) and
            addon.Read(frame.IsShown, "boolean", frame) == true and same()
    end
    return self:QuestListWrite(scroll, "SetVerticalScroll", current, value)
end

function UI:QuestListWrite(object, method, ownerCurrent, ...)
    if not ownerCurrent() then return false end
    local bindings = object.questListWrites or {}; object.questListWrites = bindings
    local key = (method == "Show" or method == "Hide" or method == "SetShown") and "visibility" or
        ((method == "SetFocus" or method == "ClearFocus") and "focus" or
        (method == "SetScript" and "script:" .. tostring((...)) or method))
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
        local height = math.max(76, 8 + titleHeight + 4 + noteHeight + 8)
        local textTop = (height - titleHeight - 4 - noteHeight) / 2
        local artTop = (height - 60) / 2
        if not current() or not write(row.title, "ClearAllPoints") or not write(row.title, "SetPoint", "TOPLEFT", 76, -textTop) or
            not write(row.note, "Show") or not write(row.note, "ClearAllPoints") or
            not write(row.note, "SetPoint", "TOPLEFT", 76, -(textTop + titleHeight + 4)) or not write(row, "SetHeight", height) or
            not write(row, "ClearAllPoints") or not write(row, "SetPoint", "TOPLEFT", 0, -offset) then return nil end
        if row.art and (not write(row.art, "ClearAllPoints") or not write(row.art, "SetPoint", "TOPLEFT", 8, -artTop)) then return nil end
        if row.entranceControl and (not write(row.entranceControl, "ClearAllPoints") or
            not write(row.entranceControl, "SetPoint", "TOPRIGHT", row, "TOPRIGHT", -4, -artTop)) then return nil end
        if row.dungeonStatusControl and (not write(row.dungeonStatusControl, "ClearAllPoints") or
            not write(row.dungeonStatusControl, "SetPoint", "TOPRIGHT", row, "TOPRIGHT", -4, -(artTop + 32))) then return nil end
        return offset + height + 8
    end
    if row.compact then
        local left = 8 + (row.chainInset or 0) + (row.statusInset or 0)
        local titleHeight = measuredHeight(row.title, 18)
        local height = math.max(minimum, 12 + titleHeight + (row.audienceExtra or 0), 12 + (row.relationLabelHeight or 0))
        row.audienceTop = 6 + titleHeight + 4
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
    row.audienceTop = 7 + titleHeight + 4
    local height = math.max(minimum, 7 + titleHeight + (row.heading and 0 or 4) + (row.audienceExtra or 0) + noteHeight + 7)
    if not write(row.title, "ClearAllPoints") or not write(row.title, "SetPoint", "TOPLEFT", titleLeft, -7) or
        not write(row.note, "ClearAllPoints") or not write(row.note, "SetPoint", "TOPLEFT", noteLeft, -(7 + titleHeight + 4 + (row.audienceExtra or 0))) or
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

function UI:ApplyColumns(listY)
    local revision, collapsed, frame = self.layoutRevision, self.catalogCollapsed == true, self.frame
    local intent = {}; self.columnIntent = intent
    local questScroll, questList, detailScroll, heading, catalogScroll, toggle = self.questScroll, self.questList,
        self.detailScroll, self.heading, self.catalogScroll, self.catalogToggle
    local glyph = toggle and toggle.label
    local themeRoot = addon.Theme
    local theme = addon.Clean(themeRoot,"table")
    local rawVisible = theme and rawget(theme,"SetCatalogVisible")
    local visible = addon.Clean(rawVisible,"function")
    local function current()
        return addon.UI == self and self.frame == frame and self.layoutRevision == revision and self.columnIntent == intent and
            (self.catalogCollapsed == true) == collapsed and self.questScroll == questScroll and self.questList == questList and
            self.detailScroll == detailScroll and self.heading == heading and self.catalogScroll == catalogScroll and self.catalogToggle == toggle and (not toggle or toggle.label == glyph) and
            addon.Theme == themeRoot and (not theme or rawget(theme,"SetCatalogVisible") == rawVisible)
    end
    local function write(object, method, ...) return self:QuestListWrite(object, method, current, ...) end
    local x, width = collapsed and 54 or 278, collapsed and 594 or 370
    listY = listY or 100
    if not write(self.questScroll,"ClearAllPoints") or not write(self.questScroll,"SetPoint","TOPLEFT",x,-listY) or
        not write(self.questScroll,"SetWidth",width) or not write(self.questList,"SetWidth",width-4) or
        not write(self.questScroll,"SetHeight",math.max(80,688-listY)) or
        not write(self.detailScroll,"ClearAllPoints") or not write(self.detailScroll,"SetPoint","TOPLEFT",674,-66) or
        not write(self.detailScroll,"SetHeight",622) or not write(self.heading,"ClearAllPoints") or
        not write(self.heading,"SetPoint","TOPLEFT",x,-66) or not write(self.heading,"SetWidth",collapsed and 450 or 226) or
        not write(self.catalogScroll,"SetShown",not collapsed) then return false end
    if toggle then
        toggle.footerLabelKey = collapsed and "CATALOG_SHOW" or "CATALOG_HIDE"
        if not current() then return false end
        setFont(glyph,20)
        if not current() or not write(toggle,"ClearAllPoints") or not write(toggle,"SetPoint","TOPLEFT",collapsed and 12 or 250,-66) or
            not write(glyph,"SetText",collapsed and "›" or "‹") or not write(toggle,"Show") then return false end
    end
    if not current() or (visible and addon.Read(visible,"boolean",self) ~= true) then return false end
    return current()
end

function UI:SetCatalogCollapsed(value, deferRefresh)
    value = addon.Clean(value,"boolean")
    local frame = self.frame
    if value == nil or not frame or addon.Read(frame.IsShown,"boolean",frame) ~= true or addon.UI ~= self then return false end
    if (self.catalogCollapsed == true) == value then return true end
    local revision = {}; self.layoutRevision, self.catalogCollapsed = revision, value
    self:HideNavigationHint()
    if self.layoutRevision ~= revision or not self:ApplyColumns() then return false end
    if not deferRefresh then self:Refresh(nil,true) end
    return self.layoutRevision == revision and self.catalogCollapsed == value
end

function UI:FlushPendingSearch(expected)
    local pending = self.pendingSearch
    if not pending or (expected and pending ~= expected) then return false end
    self.pendingSearch = nil
    local frame = pending.frame
    local shown = frame and addon.Read(frame.IsShown, "boolean", frame)
    if self.pendingSearch or addon.UI ~= self or self.frame ~= frame or self.search ~= pending.query or
        self.RefreshDungeons ~= pending.refresh or shown ~= true then return false end
    if self.catalogCollapsed == true and pending.query:find("%S") then
        if not self:SetCatalogCollapsed(false,true) then return false end
        self:Refresh(nil,true)
    else self:RefreshDungeons() end
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
    local note = result.count ~= nil and addon.L("CATALOG_COMPACT_META", result.minimum, result.maximum, result.count) or
        addon.L("CATALOG_LEVELS", result.minimum, result.maximum)
    matchedName = matchedName or result.matchedName
    if matchedName then note = note .. "\n" .. addon.L(result.related and "SEARCH_RELATED_STEP" or "SEARCH_QUEST_MATCH", matchedName) end
    if result.sourceMatch then
        note = note .. "\n" .. addon.L(result.sourceMatch.kind == "objective" and "SEARCH_OBJECTIVE_MATCH" or result.sourceMatch.kind == "npc" and "SEARCH_NPC_MATCH" or "SEARCH_PLACE_MATCH", result.sourceMatch.text)
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
    -- Batch pure reads before the final complete membership preflight.
    if view and view.query ~= "" and not view.queryID and locale and view.uiLanguage == locale and
        self.dungeon == view.selectedDungeon then
        -- Snapshot selection before the callback-bearing initial proof.
        local selected = self.dungeon
        if not current() or self.dungeon ~= selected or view.selectedDungeon ~= selected then
            return false, self.catalogLanguageView ~= view and "superseded" or nil
        end
        local read, clean, restriction = addon.Read, addon.Clean, issecretvalue
        local owned, membership = view.owned, view.membershipCurrent
        local generation = self.catalogGeneration
        local function rawSame()
            return self.catalogLanguageView == view and self.catalogGeneration == generation and
                addon.Read == read and addon.Clean == clean and issecretvalue == restriction and
                view.owned == owned and view.membershipCurrent == membership
        end
        local function same()
            if not rawSame() then return false end
            local valid = owned()
            return rawSame() and valid
        end
        for _, result in ipairs(view.results) do
            if result.statusCurrent and read(result.statusCurrent, "boolean") ~= true then return false end
            if not same() then return false, self.catalogLanguageView ~= view and "superseded" or nil end
        end
        local currentLocale = self:CatalogLanguageKey()
        if not same() or currentLocale ~= locale then return false, self.catalogLanguageView ~= view and "superseded" or nil end
        if read(membership, "boolean") ~= true or not rawSame() or self.dungeon ~= selected then
            return false, self.catalogLanguageView ~= view and "superseded" or nil
        end
        return true
    end
    if not view or(view.query~=""and view.queryID)or not locale or view.uiLanguage ~= locale or not current() then return false end
    local function membership()
        if view.query==""then return true end
        return not view.queryID and addon.Read(view.membershipCurrent,"boolean")==true and current()
    end
    if not membership()then return false, self.catalogLanguageView~=view and "superseded"or nil end
    for _, result in ipairs(view.results) do
        if result.statusCurrent and addon.Read(result.statusCurrent, "boolean") ~= true then return false end
        if not current() then return false end
    end
    if self:CatalogLanguageKey() ~= locale or not current() then return false, self.catalogLanguageView~=view and "superseded"or nil end
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
    if not current()or not membership()or self.dungeon~=selected then return false,self.catalogLanguageView~=view and "superseded"or nil end
    return true
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
        if result.idMatch then
            if matchedName and #matchedName <= 1024 and matchedName:find("%S") then
                matchedName = matchedName .. " (#" .. view.query .. ")"
            else matchedName = result.idFallbackName end
        end
        local function noteCurrent()
            return current() and (not result.statusCurrent or addon.Read(result.statusCurrent, "boolean") == true)
        end
        if not current() or not title or not write(row.title, "SetText", title) or
            not view.write(noteCurrent, true, row.note, "SetText", self:CatalogResultNote(result, matchedName)) then return failed() end
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
    local previousRelease = self.catalogSearchRelease
    self.catalogSearchRelease = nil
    if previousRelease then previousRelease() end
    local catalogue, definitions, character, database = addon.dungeons, addon.quests, addon.char, addon.db
    local search, range, locale, catalogScroll = self.search, self.range, addon.db.locale, self.catalogScroll
    local includeUnavailable = self.includeUnavailable
    local getter, dungeonGetter, fold, checker = addon.CachedQuestName, addon.DungeonName, addon.SearchFold, issecretvalue
    local context = addon.Context()
    local contextCurrent = context.current
    local query = (addon.Clean(search, "string") or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local needle = searchText(query)
    local inputs, results, memo, sourceMemo, sourceMatches = {}, {}, {}, {}, {}
    local relationMemo, relationMatches = {}, {}
    local renderInput, inputByDungeon, staging = nil, {}, true
    local sourceGetter, idParser, relationGetter = addon.QuestSourceSearchTerms, addon.SearchQuestID, addon.QuestSearchRelations
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
    local titleMemo = {}
    local nameLedger, nameScope, nameSnapshotCurrent, membershipSafe = {}, nil, nil, true
    local statusProofs = {}
    if self.catalogGeneration ~= generation then return end
    -- Pooled write records must survive native setter tails, but need not retain
    -- obsolete request snapshots once a newer catalogue owns the view.
    self.catalogSearchRelease = function()
        sourceReady = false
        membershipSafe=false
        for _, record in ipairs(statusProofs) do record.current = nil end
        statusProofs = {}
        memo, sourceMemo, sourceMatches, relationMemo, relationMatches, titleMemo = {}, {}, {}, {}, {}, {}
        nameLedger,nameScope={},nil
    end
    local function baseCurrent(sourceOnly)
        local ok, valid = pcall(function()
            if context.current ~= contextCurrent or addon.QuestSourceSearchTerms ~= sourceGetter or
                addon.SearchQuestID ~= idParser or addon.QuestSearchRelations ~= relationGetter then return false end
            if self.catalogGeneration ~= generation or self.search ~= search or self.range ~= range or self.includeUnavailable ~= includeUnavailable or self.catalogScroll ~= catalogScroll or
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
    local function captureClick(control)
        local frame, quest, dungeon = self.frame, self.quest, self.dungeon
        local tabRevision, navigationRevision = self.detailTabRevision, self.detailNavigationRevision
        local frameShown, controlShown, read = frame and frame.IsShown, control.IsShown, addon.Read
        local function raw()
            return baseCurrent(true) and addon.UI == self and self.frame == frame and self.quest == quest and self.dungeon == dungeon and
                self.detailTabRevision == tabRevision and self.detailNavigationRevision == navigationRevision and not self.catalogCollapsed and
                addon.Read == read and frame and frame.IsShown == frameShown and control.IsShown == controlShown
        end
        local function visible()
            return raw() and read(frameShown, "boolean", frame) == true and raw() and
                read(controlShown, "boolean", control) == true and raw()
        end
        return visible, raw
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
    local function relationRaw(record)
        local ok,fresh=pcall(record.raw)
        return ok and fresh==true
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
        -- Pure scans use raw graph ownership; publication and input preflight every consulted graph.
        for _, record in ipairs(relationMatches) do
            if (sourceOnly~=true and addon.Read(record.current,"boolean")~=true) or not relationRaw(record) then return expireSources() end
        end
        return baseCurrent(sourceOnly)
    end
    local function proveSources()
        if not current("full") then return false end
        for _, cached in pairs(sourceMemo) do
            if cached.current and addon.Read(cached.current, "boolean") ~= true then return expireSources() end
        end
        for _, record in ipairs(relationMemo) do
            if addon.Read(record.current,"boolean")~=true then return expireSources() end
        end
        if not current("full") then return false end
        -- Complete callback preflights before the callback-free ownership pass.
        for _, cached in pairs(sourceMemo) do
            if cached.current and not unchanged(cached) then return expireSources() end
        end
        for _,record in ipairs(relationMemo)do if not relationRaw(record) then return expireSources() end end
        if nameSnapshotCurrent and not nameSnapshotCurrent()then return expireSources()end
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
    local function sourcesFor(id,quest)
        local cached = sourceMemo[id]
        if not cached then
            cached = {}; sourceMemo[id] = cached
            local ok, terms, owner, proof = false, nil, nil, nil
            if quest then ok, terms, owner, proof = pcall(sourceGetter, quest) end
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
                    if not text or #text > 2000 or not text:find("%S") or (kind ~= "npc" and kind ~= "place" and kind ~= "objective") then
                        valid = false; break
                    end
                    entries[index] = { term = term, text = text, kind = kind }
                end
                if valid then
                    local ready = addon.Read(owner, "boolean")
                    if ready == true then cached.terms, cached.current, cached.entries, cached.unchanged = terms, owner, entries, proof end
                end
            end
            if not cached.current then membershipSafe=false end
        end
        return cached
    end
    local textMembership=false
    local function scopeRaw()
        local scope=nameScope
        return sourceReady and scope and baseCurrent(true) and addon.Clean==scope.clean and addon.Read==scope.read and
            issecretvalue==scope.checker and self.CatalogLanguageKey==scope.keyGetter and addon.GetNameTranslations==scope.dictionaryGetter and
            addon.Language==scope.language and addon.db==scope.database and GetLocale==scope.gameGetter and UnitGUID==scope.guidGetter and
            C_QuestLog==scope.native and GetRealZoneText==scope.zoneGetter and
            (type(scope.native)~="table"or rawequal(rawget(scope.native,"GetTitleForQuestID"),scope.titleGetter)) and
            (type(scope.database)~="table"or rawequal(rawget(scope.database,"locale"),scope.choice)) and
            (type(scope.language)~="table"or(rawequal(rawget(scope.language,"GetSelection"),scope.selection)and
                rawequal(rawget(scope.language,"session"),scope.session)))and
            (type(scope.session)~="table"or rawequal(rawget(scope.session,"preview"),scope.preview))
    end
    local function ledgerRaw(record)
        if not scopeRaw()then return false end
        local ok,fresh=pcall(function()
            for _,field in ipairs(record.fields)do
                if not rawequal(rawget(record.subject,field.key),field.value)then return false end
            end
            if record.art then
                for _,field in ipairs(record.artFields)do
                    if not rawequal(rawget(record.art,field.key),field.value)then return false end
                end
            end
            if record.wingKey and(addon.L~=record.localize or not rawequal(addon.locales,record.strings)or
                not rawequal(rawget(record.strings,nameScope.locale),record.interface)or
                not rawequal(rawget(record.strings,"enUS"),record.english)or
                (type(record.interface)=="table"and not rawequal(rawget(record.interface,record.wingKey),record.selectedWing))or
                not rawequal(rawget(record.english,record.wingKey),record.defaultWing))then return false end
            return rawequal(addon.nameTranslations,record.root)and
                (type(record.root)~="table"or rawequal(rawget(record.root,nameScope.locale),record.dictionary))and
                (type(record.dictionary)~="table"or rawequal(rawget(record.dictionary,record.kind),record.entries))and
                (type(record.entries)~="table"or rawequal(rawget(record.entries,record.key),record.entry))and
                (type(record.entry)~="table"or(rawequal(rawget(record.entry,"source"),record.source)and
                    rawequal(rawget(record.entry,"name"),record.name)))
        end)
        return ok and fresh==true
    end
    nameSnapshotCurrent=function()
        if not textMembership then return true end
        for _,record in ipairs(nameLedger)do if not ledgerRaw(record)then return false end end
        return true
    end
    local function catalogName(kind,argument,subject)
        local provider=kind=="quests"and getter or dungeonGetter
        if not textMembership then return addon.Read(provider,"string",argument)end
        if not nameScope then
            local clean,read,keyGetter,dictionaryGetter=addon.Clean,addon.Read,self.CatalogLanguageKey,addon.GetNameTranslations
            local selected=read(keyGetter,"string",self)
            if selected=="enGB"then selected="enUS"elseif selected=="esMX"then selected="esES"end
            if not current(true)then return end
            if selected~="enUS"and type(dictionaryGetter)=="function"then read(dictionaryGetter,"table",selected,function()return current(true)end)end
            if not current(true)then return end
            local language,database,native=addon.Language,addon.db,C_QuestLog
            local session=type(language)=="table"and rawget(language,"session")
            nameScope={clean=clean,read=read,checker=issecretvalue,keyGetter=keyGetter,dictionaryGetter=dictionaryGetter,
                locale=selected,language=language,database=database,session=session,
                choice=type(database)=="table"and rawget(database,"locale"),selection=type(language)=="table"and rawget(language,"GetSelection"),
                preview=type(session)=="table"and rawget(session,"preview"),native=native,
                titleGetter=type(native)=="table"and rawget(native,"GetTitleForQuestID"),
                gameGetter=GetLocale,guidGetter=UnitGUID,zoneGetter=GetRealZoneText}
            nameScope.game=read(nameScope.gameGetter,"string")
            if not scopeRaw()then return end
            nameScope.player=read(nameScope.guidGetter,"string","player")
            if not scopeRaw()then return end
            local function supported(value)
                if value=="enGB"then value="enUS"elseif value=="esMX"then value="esES"end
                return value=="enUS"or value=="ruRU"or value=="deDE"or value=="frFR"or value=="esES"or
                    value=="itIT"or value=="ptBR"or value=="koKR"or value=="zhCN"or value=="zhTW"
            end
            if not supported(selected)or not supported(nameScope.game)or not nameScope.player or
                #nameScope.player>256 or not nameScope.player:find("%S")then nameScope.invalid=true end
        end
        local record={kind=kind,argument=argument,subject=subject,provider=provider,fields={}}
        if not scopeRaw()then return end
        if type(provider)~="function"or type(subject)~="table"then nameScope.invalid=true;return addon.Read(provider,"string",argument)end
        for _,key in ipairs(kind=="quests"and{"id","name"}or{"key","name","wing","instanceID","art"})do
            record.fields[#record.fields+1]={key=key,value=rawget(subject,key)}
        end
        if kind=="quests"then
            local id=addon.Clean(argument,"number")
            record.key=id and id>0 and id<=9007199254740991 and id%1==0 and id or nil
        else record.key=addon.Clean(rawget(subject,"key"),"string")end
        record.art=kind=="dungeons"and addon.Clean(rawget(subject,"art"),"table")or nil
        local wing=kind=="dungeons"and addon.Clean(rawget(subject,"wing"),"string")
        if not scopeRaw()then return end
        record.artFields={}
        if record.art then for _,key in ipairs({"fileID","gameMapID"})do record.artFields[#record.artFields+1]={key=key,value=rawget(record.art,key)}end end
        record.root=addon.nameTranslations
        record.dictionary=type(record.root)=="table"and rawget(record.root,nameScope.locale)
        record.entries=type(record.dictionary)=="table"and rawget(record.dictionary,kind)
        record.entry=type(record.entries)=="table"and record.key and rawget(record.entries,record.key)
        record.source=type(record.entry)=="table"and rawget(record.entry,"source")
        record.name=type(record.entry)=="table"and rawget(record.entry,"name")
        if wing=="lower"or wing=="upper"then
            record.wingKey="DUNGEON_WING_"..wing
            record.localize=addon.L
            record.strings=addon.locales
            record.interface=type(record.strings)=="table"and rawget(record.strings,nameScope.locale)
            record.english=type(record.strings)=="table"and rawget(record.strings,"enUS")
            if type(record.strings)~="table"or type(record.english)~="table"then membershipSafe=false;record.wingKey=nil
            else
                record.selectedWing=type(record.interface)=="table"and rawget(record.interface,record.wingKey)
                record.defaultWing=rawget(record.english,record.wingKey)
            end
        end
        if not record.key then nameScope.invalid=true end
        nameLedger[#nameLedger+1]=record
        record.value=addon.Read(provider,"string",argument)
        return record.value
    end
    local function membershipCurrent()
        if not textMembership or not membershipSafe or not scopeRaw()or nameScope.invalid then return false end
        local function scopeCurrent()
            if not scopeRaw()then return false end
            local scope=nameScope
            local selected=addon.Read(scope.keyGetter,"string",self)
            if not scopeRaw()then return false end
            if selected=="enGB"then selected="enUS"elseif selected=="esMX"then selected="esES"end
            if selected~=scope.locale then return false end
            local game=addon.Read(scope.gameGetter,"string")
            if not scopeRaw()or game~=scope.game then return false end
            local player=addon.Read(scope.guidGetter,"string","player")
            return scopeRaw()and player==scope.player
        end
        if not scopeCurrent()then return false end
        for _,record in ipairs(nameLedger)do
            if not scopeRaw()or not ledgerRaw(record)then return false end
            local value=addon.Read(record.provider,"string",record.argument)
            if not scopeRaw()or value~=record.value then return false end
        end
        if not scopeCurrent()or not proveSources()then return false end
        return nameSnapshotCurrent()and scopeRaw()
    end
    local function searchTitle(id,definition)
        local previous=titleMemo[id]
        if previous then
            if addon.Read(previous.proof.current,"boolean")~=true or not relationRaw(previous.proof) or not current(true)then return end
            return previous.name,previous.proof
        end
        local keyGetter,dictionaryGetter=self.CatalogLanguageKey,addon.GetNameTranslations
        local read,clean=addon.Read,addon.Clean
        local function normalize(value)
            if value=="enGB"then value="enUS"elseif value=="esMX"then value="esES"end
            if value=="enUS"or value=="ruRU"or value=="deDE"or value=="frFR"or value=="esES"or
                value=="itIT"or value=="ptBR"or value=="koKR"or value=="zhCN"or value=="zhTW"then return value end
            return "enUS"
        end
        local selected=normalize(read(keyGetter,"string",self))
        if not current(true) then return end
        if selected~="enUS" and type(dictionaryGetter)=="function" then
            read(dictionaryGetter,"table",selected,function()return current(true)end)
            if not current(true) then return end
        end
        -- Own only the title entry actually consulted, including a missing entry.
        local root=addon.nameTranslations
        local dictionary=type(root)=="table"and rawget(root,selected)
        local entries=type(dictionary)=="table"and rawget(dictionary,"quests")
        local entry=type(entries)=="table"and rawget(entries,id)
        local original=type(entry)=="table"and rawget(entry,"source")
        local translated=type(entry)=="table"and rawget(entry,"name")
        local source=rawget(definition,"name")
        local native,gameGetter,guidGetter=C_QuestLog,GetLocale,UnitGUID
        local nativeGetter=type(native)=="table"and rawget(native,"GetTitleForQuestID")
        local function raw()
            local ok,fresh=pcall(function()
                return baseCurrent(true) and self.CatalogLanguageKey==keyGetter and addon.GetNameTranslations==dictionaryGetter and
                    addon.Read==read and addon.Clean==clean and GetLocale==gameGetter and UnitGUID==guidGetter and C_QuestLog==native and
                    (type(native)~="table"or rawequal(rawget(native,"GetTitleForQuestID"),nativeGetter)) and
                    rawequal(rawget(definitions,id),definition) and rawequal(rawget(definition,"name"),source) and
                    rawequal(addon.nameTranslations,root) and (type(root)~="table"or rawequal(rawget(root,selected),dictionary)) and
                    (type(dictionary)~="table"or rawequal(rawget(dictionary,"quests"),entries)) and
                    (type(entries)~="table"or rawequal(rawget(entries,id),entry)) and
                    (type(entry)~="table"or(rawequal(rawget(entry,"source"),original)and rawequal(rawget(entry,"name"),translated)))
            end)
            return ok and fresh==true
        end
        local function fresh()
            if not raw()then return false end
            local language=normalize(read(keyGetter,"string",self))
            return language==selected and raw()
        end
        local title=catalogName("quests",id,definition)
        if not fresh()then return end
        if not title or #title>1024 or not title:find("%S")then title=clean(source,"string")or("#"..id)end
        if not fresh()then return end
        local proof={current=fresh,raw=raw}
        titleMemo[id]={name=title,proof=proof}
        relationMemo[#relationMemo+1]=proof
        relationMatches[#relationMatches+1]=proof
        return title,proof
    end
    local queryID = addon.Read(idParser, "number", query)
    if queryID and (queryID <= 0 or queryID > 9007199254740991 or queryID % 1 ~= 0) then queryID = nil end
    if not current() then return end
    textMembership=query~=""and not queryID
    for inputIndex, input in ipairs(inputs) do
        local dungeon = input.dungeon
        if not range or (context.level and context.level >= input.minimum - 3 and context.level <= input.maximum + 3) then
            if not scanMember(input, inputIndex) then return end
            local matchedName, matchedID, sourceMatch, idMatch, idFallbackName, relatedRootID
            if queryID then
                for memberIndex, member in ipairs(input.members) do
                    if not scanMember(input, inputIndex, member, memberIndex) then return end
                    if member.id == queryID and member.quest and member.questID == queryID then
                        local title = addon.Clean(member.name, "string")
                        if not current(true) then return end
                        idFallbackName = title and title ~= "" and (title .. " (#" .. query .. ")") or ("#" .. query)
                        local cached = memo[member.id]
                        if not cached then
                            cached = { name = addon.Read(getter, "string", member.id) }; memo[member.id] = cached
                        end
                        if not current(true) then return end
                        local localized = cached.name
                        matchedName = localized and #localized <= 1024 and localized:find("%S") and
                            (localized .. " (#" .. query .. ")") or idFallbackName
                        matchedID, idMatch = member.id, true
                        break
                    end
                end
            end
            local name, matches = "", false
            if not queryID or matchedID then
                name = catalogName("dungeons",dungeon,dungeon) or addon.Clean(input.name, "string") or ""
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
                        cached = { name = catalogName("quests",member.id,member.quest) }
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
                    local cached = sourcesFor(member.id,member.quest)
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
            if not queryID and query~="" and not matches and not matchedName and addon.Clean(relationGetter,"function") then
                for memberIndex,member in ipairs(input.members)do
                    if not scanMember(input,inputIndex,member,memberIndex) then return end
                    local ok,model,proof,raw=pcall(relationGetter,dungeon,member.id,function()return current(true)end)
                    proof,raw=addon.Clean(proof,"function"),addon.Clean(raw,"function")
                    if not current(true) then return end
                    local record
                    if ok and proof and raw then
                        record={current=proof,raw=raw}
                        relationMemo[#relationMemo+1]=record
                        if addon.Read(proof,"boolean")~=true or not relationRaw(record) or not current(true) then return end
                    end
                    if not record then membershipSafe=false end
                    model=addon.Clean(model,"table")
                    local nodes=model and addon.Clean(rawget(model,"nodes"),"table")
                    if record and nodes and addon.Clean(rawget(model,"rootTargetID"),"number")==member.id and #nodes<=79 then
                        for index=1,#nodes do
                            local node=addon.Clean(rawget(nodes,index),"table")
                            local id=node and addon.Clean(rawget(node,"questID"),"number")
                            local root=node and addon.Clean(rawget(node,"rootTargetID"),"number")
                            local relation=node and addon.Clean(rawget(node,"relation"),"string")
                            local definition=id and addon.Clean(definitions[id],"table")
                            if not current(true) then return end
                            if id and id>0 and id<=9007199254740991 and id%1==0 and id~=member.id and root==member.id and
                                relation=="related" and definition and addon.Clean(rawget(definition,"id"),"number")==id then
                                local cached=sourcesFor(id,definition)
                                for _,entry in ipairs(cached.entries or{})do
                                    if searchText(entry.text):find(needle,1,true) then
                                        local title,titleProof=searchTitle(id,definition)
                                        if not titleProof then return expireSources()end
                                        if not current(true)then return end
                                        matchedName,matchedID,sourceMatch,relatedRootID=title,id,entry,member.id
                                        if not cached.matched then cached.matched=true;sourceMatches[#sourceMatches+1]=cached end
                                        relationMatches[#relationMatches+1]=record
                                        break
                                    end
                                end
                            end
                            if matchedName then break end
                        end
                    end
                    if matchedName then break end
                end
            end
            if matchedName and not idMatch and not relatedRootID then
                local definition=addon.Clean(rawget(definitions,matchedID),"table")
                if not current(true)then return end
                if not definition then return expireSources()end
                local title,proof=searchTitle(matchedID,definition)
                if not proof then return expireSources()end
                local canonical=addon.Clean(rawget(definition,"name"),"string")or""
                if not current(true)then return end
                if not sourceMatch and not searchText(canonical):find(needle,1,true) and
                    not searchText(title):find(needle,1,true)then
                    matchedName,matchedID=nil,nil
                else matchedName=title end
            end
            if not current(true) then return end
            if matches or matchedName then
                local result = { dungeon = dungeon, title = name, questID = matchedID, sourceMatch = sourceMatch,
                    idMatch = idMatch, idFallbackName = idFallbackName, related = relatedRootID~=nil, relatedRootID = relatedRootID, includeUnavailable = includeUnavailable, minimum = input.minimum, maximum = input.maximum, count = includeUnavailable == true and #input.members or nil, matchedName = matchedName }
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
            local record = { current = fresh }
            local read, clean, restriction = addon.Read, addon.Clean, issecretvalue
            statusProofs[#statusProofs + 1] = record
            result.statusDTO = dto
            result.statusCurrent = function()
                local proof = record.current
                if not sourceReady or not proof or addon.Read ~= read or addon.Clean ~= clean or issecretvalue ~= restriction then return false end
                local valid = read(proof, "boolean") == true
                return sourceReady and record.current == proof and addon.Read == read and addon.Clean == clean and issecretvalue == restriction and valid
            end
            result.count = includeUnavailable == true and dto.listedRoots or dto.characterRoots
            result.note = self:CatalogResultNote(result)
            if not current() or addon.Read(fresh, "boolean") ~= true then return end
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
        local row = self:MakeRow(self.catalog, self.cards, index, 76, current, true)
        row.catalogCard = true
        local theme = addon.Clean(addon.Theme, "table")
        if theme then addon.Read(theme.ApplyFont, "boolean", row.note, 12) end
        if not current() then return end
        result.row = row
        row.catalogResult = result
        if not current() or not write(row, "Hide") then return end
        if not row.art then
            row.art = row:CreateTexture(nil, "ARTWORK")
            if not write(row.art, "SetSize", 56, 60) or not write(row.art, "SetPoint", "TOPLEFT", 8, -8) then return end
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
            control:SetScript("OnEnter", function() if self.catalogCollapsed then return end; control.footerHovered = true; self:RefreshFooterIcon(control); self:CatalogEntranceHint(row) end)
            control:SetScript("OnLeave", function() control.footerHovered = false; self:RefreshFooterIcon(control); self:HideNavigationHint(control) end)
            control:SetScript("OnHide", function() control.footerHovered = false; self:RefreshFooterIcon(control); self:HideNavigationHint(control) end)
        end
        -- The separate icon rail never overlaps title or metadata wrapping.
        local textWidth = math.max(1, row:GetWidth() - 76 - 36)
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
            statusControl:SetScript("OnEnter", function() if not self.catalogCollapsed then self:CatalogStatusHint(row) end end)
            statusControl:SetScript("OnLeave", function() self:HideNavigationHint(statusControl) end)
            statusControl:SetScript("OnHide", function() self:HideNavigationHint(statusControl) end)
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
            if self.catalogCollapsed or addon.Read(row.IsShown, "boolean", row) ~= true then return end
            if not entranceCurrent() or row.entranceBinding ~= binding or not binding or not binding.current() then return end
            if addon.Read(frame.IsShown, "boolean", frame) ~= true or not entranceCurrent() or not binding.current() then return end
            pcall(binding.start, binding.dungeon, binding.point)
        end) then return end
        if not write(row.art, "Hide") then return end
        addon.Read(addon.PaintDungeonArt, "boolean", row.art, dungeon)
        if not current() then return end
        local function noteCurrent()
            return current() and (not result.statusCurrent or addon.Read(result.statusCurrent, "boolean") == true)
        end
        if not write(row.title, "SetText", result.title) or not ownedWrite(noteCurrent, false, row.note, "SetText", result.note) or
            not write(row.bg, "SetColorTexture", self.dungeon == dungeon and 0.22 or 0.13, 0.19, 0.23, 1) then return end
        styleRow(row, "dungeon", self.dungeon == dungeon)
        if not current() then return end
        row.matchQuestID = result.questID
        if not write(row, "SetScript", "OnClick", function()
            local clickCurrent, clickRaw = captureClick(row)
            if not clickCurrent() or not proveSources() or not clickRaw() then return end
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
            local related, relatedRoot = result.related, result.relatedRootID
            local localeGetter, nativeRoot, guidGetter = GetLocale, C_QuestLog, UnitGUID
            local native = addon.Clean(nativeRoot, "table")
            local titleGetter = native and rawget(native, "GetTitleForQuestID")
            local gameLocale = addon.Read(localeGetter, "string")
            local function inspectCurrent()
                local language = addon.Read(localeGetter, "string")
                if not current() then return false end
                return GetLocale == localeGetter and language == gameLocale and C_QuestLog == nativeRoot and
                    UnitGUID == guidGetter and (not native or rawget(native, "GetTitleForQuestID") == titleGetter) and
                    result.related==related and result.relatedRootID==relatedRoot and
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
                local clickCurrent, clickRaw = captureClick(inspect)
                if not clickCurrent() or not inspectCurrent() then return end
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
                if addon.Read(row.IsShown, "boolean", row) ~= true or not matches or not inspectCurrent() or not proveSources() or not clickRaw() then return end
                self:ResetHistoryReading(); self.detailHistory = {}
                self.dungeon, self.quest = dungeon, questID
                character.selectedDungeon = dungeon.key
                if related then self.questTreeRoot,self.questTreeDungeon=relatedRoot,dungeon end
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
        if result.statusCurrent and addon.Read(result.statusCurrent, "boolean") ~= true then return retire() end
        if not write(result.row, "Show") then return retire() end
        if result.inspect and not write(result.inspect, "Show") then return retire() end
    end
    if not proveSources() then return retire() end
    local uiLanguage = self:CatalogLanguageKey()
    if not proveSources() then return retire() end
    self.catalogLanguageView = { current = proveSources, owned = function() return baseCurrent(true) end,
        membershipCurrent = membershipCurrent,
        write = ownedWrite, query = query, queryID = queryID, results = results,
        uiLanguage = uiLanguage, selectedDungeon = self.dungeon }
end

function UI:PaintQuestRowStatus(row, entry, engine, ownerCurrent, engineLease)
    local heldEngine = engineLease or { engine = engine }
    engine = nil
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
        local engine = heldEngine.engine
        local fresh = not eligible or (engine and (not engine.Current or addon.Read(engine.Current, "boolean", engine) == true))
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
    local request, previousRelease = {}, self.questListRelease
    self.questListRequest = request
    if previousRelease then previousRelease() end
    local layoutRevision = self.layoutRevision
    if not self:ApplyColumns() or self.layoutRevision ~= layoutRevision or self.questListRequest ~= request then return end
    local d, character, previousGeneration = self.dungeon, addon.char, self.questListGeneration
    local preparation, includeUnavailable = self.preparation, self.includeUnavailable
    local targets, targetIDs, targetSet = d and d.quests, {}, {}
    for index, id in ipairs(targets or {}) do targetIDs[index] = id; targetSet[id] = true end
    local needsEngine = d ~= nil or self.quest ~= nil
    local context = needsEngine and addon.Context() or nil
    if self.questListRequest ~= request or self.dungeon ~= d or addon.char ~= character or self.questListGeneration ~= previousGeneration then return end
    local engine = needsEngine and addon.Planner.New(addon.quests, context, addon.Clean(character.choices, "table")) or nil
    if self.questListRequest ~= request then return end
    local engineLease = { engine = engine }
    self.engine = engine
    self.currentPlan = nil
    local generation, treeCurrent, treeRaw, treeFailed, rendering = {}, nil, nil, false, true
    local completed, planLease = false, {}
    local infoProofs, infoRawProofs, infoRawMissing, infoFailed = {}, {}, false, false
    self.questListGeneration = generation
    local released, read, clean, checker = false, addon.Read, addon.Clean, issecretvalue
    self.questListRelease = function()
        released = true
        planLease.current, planLease.raw = nil, nil
        engineLease.engine, engine, context, treeCurrent, treeRaw = nil, nil, nil, nil, nil
        infoProofs, infoRawProofs = {}, {}
    end
    local proveTree
    local function current()
        if released or self.questListRequest ~= request or addon.Read ~= read or addon.Clean ~= clean or issecretvalue ~= checker then return false end
        local owned = self.layoutRevision == layoutRevision and self.questListGeneration == generation and self.engine == engine and self.dungeon == d and addon.char == character and
            self.preparation == preparation and self.includeUnavailable == includeUnavailable
        if not owned or treeFailed or infoFailed then return false end
        if d and (d.quests ~= targets or #targets ~= #targetIDs) then return false end
        for index, id in ipairs(targetIDs) do if targets[index] ~= id then return false end end
        if not rendering and not proveTree() then return false end
        return self.layoutRevision == layoutRevision and self.questListGeneration == generation and self.engine == engine and self.dungeon == d and addon.char == character and
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
    -- Finish borrowed list ownership after callbacks without reentering its readers.
    local function rawListCurrent()
        if released or rendering or treeFailed or infoFailed or infoRawMissing or
            self.questListRequest ~= request or self.layoutRevision ~= layoutRevision or self.questListGeneration ~= generation or
            self.engine ~= engine or self.dungeon ~= d or addon.char ~= character or self.preparation ~= preparation or
            self.includeUnavailable ~= includeUnavailable or addon.Read ~= read or addon.Clean ~= clean or issecretvalue ~= checker then return false end
        if d and (rawget(d, "quests") ~= targets or #targets ~= #targetIDs) then return false end
        for index, id in ipairs(targetIDs) do if not rawequal(rawget(targets,index),id) then return false end end
        if treeCurrent and (not treeRaw or treeRaw() ~= true) then return false end
        for _, proof in ipairs(infoRawProofs) do if proof() ~= true then return false end end
        return true
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
    if not self:RefreshQuestEntrance(current) then return end
    local n, offset = 0, 0
    if d then
        local plan = engine:Dungeon(d, { includeUnavailable = self.includeUnavailable })
        if not current() then return end
        self.currentPlan = { engine = engine, dungeon = d, includeUnavailable = self.includeUnavailable, rows = plan.rows, actions = plan.actions, counts = plan.counts, unknown = plan.unknown, ready = plan.ready }
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
                            if addon.Clean(tree.truncated, "boolean") == true then
                                expanded[#expanded + 1] = { heading = "CHAIN_TRUNCATED_NOTICE" }
                            end
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
        treeRaw = tree and addon.Clean(tree.rawCurrent, "function")
        for _, entry in ipairs(entries) do
            local id, state = entry.id, entry.state
            local parentCurrent = current
            local infoModule = addon.Clean(addon.QuestRowInfo, "table")
            local infoGetter = infoModule and addon.Clean(infoModule.Get, "function")
            local info, infoCurrent, infoRaw
            if infoGetter and (id or entry.anchorID) then
                local ok, value, proof, raw = pcall(infoGetter, addon.quests, id or entry.anchorID)
                if not parentCurrent() then return end
                if ok then info, infoCurrent, infoRaw = addon.Clean(value, "table"), addon.Clean(proof, "function"), addon.Clean(raw, "function") end
                if not infoCurrent then info = nil end
            end
            if infoCurrent then
                infoProofs[#infoProofs + 1] = infoCurrent
                if infoRaw then infoRawProofs[#infoRawProofs + 1] = infoRaw else infoRawMissing = true end
            elseif id or entry.anchorID then infoRawMissing = true end
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
            local classes, seenClasses = {}, {}
            local classSource = info and addon.Clean(info.classes, "table")
            for index = 1, math.min(classSource and #classSource or 0, 13) do
                local token = addon.Clean(rawget(classSource, index), "string")
                if token and AUDIENCE_ICONS.classes[token] and not seenClasses[token] then
                    classes[#classes + 1] = token; seenClasses[token] = true
                end
            end
            if not current() then return end
            row.classReserve, row.audienceExtra, row.audienceBelow, row.audienceColumns = #classes * 18, 0, false, nil
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
            if not self:BindQuestRowNavigation(row, not entry.heading and (id or entry.anchorID), current) then return end
            if not write(row, "SetScript", "OnEnter", function() if interactionCurrent() then self:QuestListHint(row) end end) or
                not write(row, "SetScript", "OnLeave", function() self:HideNavigationHint(row) end) or
                not write(row, "SetScript", "OnHide", function() self:HideNavigationHint(row) end) then return end
            local rewards = addon.Clean(addon.QuestListRewards, "table")
            local rewardPaint = rewards and addon.Clean(rewards.Paint, "function")
            local reserve = id and not entry.heading and rewardPaint and addon.Read(rewardPaint, "number", row, id, current) or 0
            if not current() then return end
            if not reserve or reserve < 0 or reserve > 100 then reserve = 0 end
            reserve = reserve + row.navigationReserve
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
            local relation, relationKey = entry.tree
            if labelledTarget then relationKey = "DUNGEON_QUEST_SHORT"
            elseif relation and relation.relation == "required" and relation.requirementScope ~= "story" then relationKey = "REQUIRED_STEP_SHORT"
            elseif relation and (relation.relation == "story" or relation.requirementScope == "story") then relationKey = "STORY_SHORT" end
            if relationKey and not targetLabel then
                targetLabel = label(row, "", 0, 0, 92, 11)
                if not current() then return end
                row.dungeonTargetLabel = targetLabel
            end
            local targetLabelWidth = 0
            row.relationLabelHeight = 0
            if targetLabel then
                if not write(targetLabel, "Hide") then return end
                if relationKey then
                    if not writeText(targetLabel, addon.L(relationKey)) then return end
                    targetLabelWidth = math.min(92, math.max(30, addon.Read(targetLabel.GetStringWidth, "number", targetLabel) or 72))
                    if not current() or not write(targetLabel, "SetWidth", targetLabelWidth) or
                        not write(targetLabel, "ClearAllPoints") or not write(targetLabel, "SetPoint", "TOPRIGHT", row, "TOPRIGHT", -(labelledTarget and 24 or 6) - reserve, -8) or
                        not write(targetLabel, "SetTextColor", .96, .78, .35) or
                        not write(targetLabel, "Show") then return end
                    local relationHeight = measuredHeight(targetLabel, 14)
                    if not current() then return end
                    row.relationLabelHeight = relationHeight
                end
            end
            row.dungeonBadgeReserve = relationKey and ((labelledTarget and 22 or 4) + targetLabelWidth) or 0
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
                        end) or not write(branchControl, "SetScript", "OnLeave", function() self:HideNavigationHint(row) end) or
                        not write(branchControl, "Show") then return end
                end
            end
            local audienceSpace = row:GetWidth() - 22 - reserve - row.dungeonBadgeReserve - row.chainInset - row.branchReserve
            if row.classReserve > 0 and audienceSpace - row.factionReserve - row.classReserve < 64 then
                row.audienceBelow = true
                row.audienceColumns = math.max(1, math.floor((audienceSpace - 20) / 18))
                row.audienceExtra = math.ceil((#classes + (faction and 1 or 0)) / row.audienceColumns) * 18 + 2
                row.classReserve, row.factionReserve = 0, 0
            end
            row.statusBaseWidth = math.max(24, audienceSpace - row.factionReserve - row.classReserve)
            if not current() then return end
            if not self:PaintQuestRowStatus(row, entry, engine, current, engineLease) then return end
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
            row.classIcons = row.classIcons or {}
            for _, icon in ipairs(row.classIcons) do if not write(icon, "Hide") then return end end
            local function paintAudience(icon, atlas, slot)
                if not write(icon, "Hide") then return false end
                local width = atlas and addon.Read(row.title.GetStringWidth, "number", row.title)
                local cap = atlas and addon.Read(row.title.GetWidth, "number", row.title)
                if not current() then return end
                if width and width >= 0 and cap and cap > 0 and addon.Clean(icon.SetAtlas, "function") then
                    local painted = write(icon, "SetAtlas", atlas)
                    if not current() then return end
                    if painted and addon.Read(icon.GetAtlas, "string", icon) == atlas then
                        local x, top = math.min(width, cap) + 4 + slot * 18, -2
                        if row.audienceBelow then
                            x, top = (slot % row.audienceColumns) * 18, -(row.audienceTop - (row.compact and 6 or 7) + math.floor(slot / row.audienceColumns) * 18)
                        end
                        if not current() or not write(icon, "SetSize", 14, 14) or not write(icon, "ClearAllPoints") or
                            not write(icon, "SetPoint", "TOPLEFT", row.title, "TOPLEFT", x, top) or not write(icon, "Show") then return false end
                    end
                end
                return current()
            end
            if factionIcon and paintAudience(factionIcon, faction and AUDIENCE_ICONS.factions[faction], 0) ~= true then return end
            for index, token in ipairs(classes) do
                local icon = row.classIcons[index]
                if not icon then
                    local ok, value = pcall(row.CreateTexture, row, nil, "ARTWORK")
                    if not current() then return end
                    if ok then icon = value; row.classIcons[index] = icon end
                end
                if icon and paintAudience(icon, "classicon-" .. AUDIENCE_ICONS.classes[token], index - 1 + (faction and 1 or 0)) ~= true then return end
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
        row.rowInfo, row.rowInfoCurrent, row.chainExpandable, row.chainExpanded, row.chainInset, row.factionReserve, row.classReserve, row.branchReserve = nil, nil, false, false, 0, 0, 0, 0
        row.audienceExtra, row.audienceBelow, row.audienceColumns = 0, false, nil
        for _, icon in ipairs(row.classIcons or {}) do if not write(icon, "Hide") then return end end
        row.questListCurrent = current
        if not self:BindQuestRowNavigation(row, nil, current) then return end
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
    if not self:ApplyColumns(listY) or not current() then return end
    for index = n + 1, #self.rows do
        local row = self.rows[index]
        if not write(row, "Hide") then return end
        for _, icon in ipairs(row.classIcons or {}) do if not write(icon, "Hide") then return end end
        if not self:BindQuestRowNavigation(row, nil, current) then return end
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
                local valid = self.layoutRevision == layoutRevision and addon.UI == self and self.frame == frame and self.questListGeneration == generation and
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
    completed = proveInfos() == true
    end
    local ok, failure = pcall(function() render(); proveInfos() end)
    rendering = false
    if not ok then retireInfos(); error(failure, 0) end
    local published = self.currentPlan
    if completed and published and rawListCurrent() then
        local engineCurrent = engine and engine.Current
        planLease.current = function()
            if released or self.currentPlan ~= published or not current() then return false end
            return engine and engine.Current == engineCurrent and addon.Read(engineCurrent, "boolean", engine) == true and
                not released and self.currentPlan == published and engine.Current == engineCurrent and rawListCurrent()
        end
        planLease.raw = function() return self.currentPlan == published and rawListCurrent() end
        published.rawCurrent = function() return planLease.raw and planLease.raw() == true or false end
        published.current = function() return planLease.current and planLease.current() == true or false end
    end
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
    if addon.TooltipLease then addon.TooltipLease.Retire(held.tooltip, held) end
    if owned == true and tooltipMethod(held.tooltip, "Hide") == held.hide then
        pcall(held.hide, held.tooltip)
        if addon.TooltipLease then addon.TooltipLease.Restore(held.tooltip, held) end
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
    local function current() return self.rewardGeneration == generation end
    -- Share native write ownership with icon publication so a late clear restores the newest arguments.
    local function clear(button, bindingKey)
        button[bindingKey] = nil
        for _, script in ipairs({ "OnEnter", "OnLeave", "OnHide" }) do
            if not self:QuestListWrite(button, "SetScript", current, script, nil) then return false end
        end
        if not self:QuestListWrite(button, "Hide", current) or
            not self:QuestListWrite(button.icon, "Hide", current) then return false end
        self:SetRewardTexture(button.icon, nil)
        return current()
    end
    self.rewardButtons = self.rewardButtons or {}
    for _, button in ipairs(self.rewardButtons) do
        if not clear(button, "rewardBinding") then return nil end
    end
    self.objectiveButtons = self.objectiveButtons or {}
    for _, button in ipairs(self.objectiveButtons) do
        if not clear(button, "objectiveBinding") then return nil end
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
    if not self:QuestListWrite(button, "SetScript", current, "OnLeave", function()
        if self.rewardGeneration == binding.generation and button.rewardBinding == binding then self:ReleaseRewardTooltip(held) end
    end) then self:ReleaseRewardTooltip(held); return end
    local ok = pcall(held.setOwner, tooltip, button, "ANCHOR_RIGHT")
    if not ok or not current() then self:ReleaseRewardTooltip(held); return end
    local owned = addon.Read(held.isOwned, "boolean", tooltip, button)
    if owned ~= true or not current() then self:ReleaseRewardTooltip(held); return end
    local shown
    ok, shown = pcall(held.setItem, tooltip, binding.id)
    shown = addon.Clean(shown, "boolean")
    if not ok or shown ~= true or not current() then self:ReleaseRewardTooltip(held); return end
    owned = addon.Read(held.isOwned, "boolean", tooltip, button)
    if owned ~= true or not current() then self:ReleaseRewardTooltip(held); return end
    self:RetainTooltipHint(held, current, "rewardTooltip")
end

function UI:ReleaseObjectiveTooltip(expected)
    local held = self.objectiveTooltip
    if not held or (expected and held ~= expected) then return end
    local owned = addon.Read(held.isOwned, "boolean", held.tooltip, held.button)
    if self.objectiveTooltip ~= held then return end
    self.objectiveTooltip = nil
    if addon.TooltipLease then addon.TooltipLease.Retire(held.tooltip, held) end
    if owned == true and tooltipMethod(held.tooltip, "Hide") == held.hide then
        pcall(held.hide, held.tooltip)
        if addon.TooltipLease then addon.TooltipLease.Restore(held.tooltip, held) end
    end
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
    if not self:QuestListWrite(button, "SetScript", current, "OnLeave", function()
        if self.rewardGeneration == binding.generation and button.objectiveBinding == binding then self:ReleaseObjectiveTooltip(held) end
    end) then self:ReleaseObjectiveTooltip(held); return end
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
        if not ok or owned ~= true or not current() then self:ReleaseObjectiveTooltip(held); return end
    end
    self:RetainTooltipHint(held, current, "objectiveTooltip")
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

local function releaseDetailText(ui)
    local lease = ui.detailTextLease
    ui.detailTextLease = nil
    if not lease then return end
    lease.released = true
    for _, record in ipairs(lease.bindings) do
        record.scope.current, record.binding.engine = nil, nil
    end
    lease.bindings = {}
end

local function releaseSourceControls(ui)
    local lease = ui.sourceControlsLease
    ui.sourceControlsLease = nil
    if not lease then return end
    lease.released = true
    for _, cell in ipairs(lease.cells) do cell.callback = nil end
    lease.cells, lease.memo = {}, {}
end

function UI:RefreshDetail(sourceFocus)
    releaseSourceControls(self)
    local sourceControlsLease = { cells = {}, memo = {} }
    self.sourceControlsLease = sourceControlsLease
    releaseDetailText(self)
    local detailTextLease = { bindings = {} }
    self.detailTextLease = detailTextLease
    local previousMap = self.overviewMapBinding
    self.overviewMapBinding = nil
    if previousMap then previousMap.released, previousMap.owner = true, nil end
    self:ReleasePreparationOverview()
    if detailTextLease.released or self.detailTextLease ~= detailTextLease then return end
    if self.SyncDungeonMapContext then self:SyncDungeonMapContext() end
    if detailTextLease.released or self.detailTextLease ~= detailTextLease then return end
    local layoutRevision = self.layoutRevision
    local renderQuest, renderDungeon = self.quest, self.dungeon
    local renderIncludeUnavailable = self.includeUnavailable
    local renderEngine, renderCharacter, pendingAction, pendingGiver, pendingTurnin = self.engine, addon.char, nil, nil, nil
    local primaryGiver = self.giver
    local sameDetailOwner = self.detailTabQuest == renderQuest and self.detailTabDungeon == renderDungeon and self.detailTabCharacter == renderCharacter
    if not sameDetailOwner then
        self.detailTabQuest, self.detailTabDungeon, self.detailTabCharacter = renderQuest, renderDungeon, renderCharacter
        self.detailTab, self.detailTabOffsets, self.detailTabRevision = "quest", {}, {}
    end
    if sourceFocus == true and self.detailTab ~= "sources" then
        local previous, offsets, scroll, frame = self.detailTab, self.detailTabOffsets, self.detailScroll, self.frame
        local getter, engineGetter, reader = scroll.GetVerticalScroll, renderEngine and renderEngine.Current, addon.Read
        local generation, refresh = self.rewardGeneration, self.RefreshDetail
        local intent = {}; self.detailTabRevision = intent
        local offset = sameDetailOwner and reader(getter,"number",scroll)
        local fresh = not engineGetter or reader(engineGetter,"boolean",renderEngine) == true
        if not fresh or self.rewardGeneration ~= generation or self.RefreshDetail ~= refresh or self.detailTabRevision ~= intent or self.detailTab ~= previous or self.detailTabOffsets ~= offsets or
            self.quest ~= renderQuest or self.dungeon ~= renderDungeon or addon.char ~= renderCharacter or self.engine ~= renderEngine or
            self.frame ~= frame or self.detailScroll ~= scroll or scroll.GetVerticalScroll ~= getter or addon.Read ~= reader or
            (renderEngine and renderEngine.Current ~= engineGetter) then return end
        if sameDetailOwner and offset and offset >= 0 then offsets[previous] = offset end
        self.detailTab = "sources"
    end
    local detailTab, tabRevision = self.detailTab or "quest", self.detailTabRevision
    self.detailReferencesExpanded = detailTab == "sources"
    local rewardGeneration = self:ResetRewardPresentation()
    if not rewardGeneration or self.quest ~= renderQuest then return end
    self:HideNavigationHint()
    if self.rewardGeneration ~= rewardGeneration or self.quest ~= renderQuest or self.dungeon ~= renderDungeon or
        self.engine ~= renderEngine or addon.char ~= renderCharacter then return end
    if self.detailReferenceQuest ~= renderQuest or self.detailReferenceDungeon ~= renderDungeon then
        self.detailReferencesExpanded, self.detailNarrativeExpanded = detailTab == "sources", false
        self.detailReferenceQuest, self.detailReferenceDungeon = renderQuest, renderDungeon
    end
    if self.detailObjectivesQuest ~= renderQuest or self.detailObjectivesDungeon ~= renderDungeon or
        self.detailObjectivesCharacter ~= renderCharacter then
        self.detailObjectivesExpanded = false
        self.detailObjectivesQuest, self.detailObjectivesDungeon, self.detailObjectivesCharacter = renderQuest, renderDungeon, renderCharacter
    end
    if sourceFocus == true then self.detailReferencesExpanded = true end
    local sourceFocusOffset, sourceFocusCurrent = 0, nil
    local referencesExpanded = self.detailReferencesExpanded == true
    local narrativeExpanded = self.detailNarrativeExpanded == true
    local objectivesExpanded = self.detailObjectivesExpanded == true
    local overviewIdentity = not renderQuest and renderDungeon and (addon.Clean(renderDungeon.key, "string") or renderDungeon) or nil
    if not sameDetailOwner or self.renderedQuest ~= self.quest or self.renderedOverview ~= overviewIdentity then
        self:CloseCopyLink()
        self.detailActionChoice = nil
        local function current()
            return self.detailTabRevision == tabRevision and self.detailTab == detailTab and self.quest == renderQuest and self.dungeon == renderDungeon and self.engine == renderEngine and
                addon.char == renderCharacter and self.rewardGeneration == rewardGeneration and
                self.includeUnavailable == renderIncludeUnavailable
        end
        if not self:WriteDetailScroll(self.detailScroll, 0, current) then return end
        self.renderedQuest, self.renderedOverview = renderQuest, overviewIdentity
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
    local function portraitCardCurrent()
        return self.detailTabRevision == tabRevision and self.detailTab == detailTab and self.layoutRevision == layoutRevision and self.quest == renderQuest and self.dungeon == renderDungeon and self.engine == renderEngine and
            self.includeUnavailable == renderIncludeUnavailable and addon.char == renderCharacter and self.rewardGeneration == rewardGeneration and
            (self.detailReferencesExpanded == true) == referencesExpanded and
            (self.detailNarrativeExpanded == true) == narrativeExpanded and
            (self.detailObjectivesExpanded == true) == objectivesExpanded
    end
    if detailTextLease.released or self.detailTextLease ~= detailTextLease or not portraitCardCurrent() then return end
    local function sourceCallback(callback)
        local existing = sourceControlsLease.memo[callback]
        if existing then return existing end
        local cell = { callback = callback }
        sourceControlsLease.cells[#sourceControlsLease.cells + 1] = cell
        local function retained(...)
            local current = cell.callback
            if sourceControlsLease.released or not current then return false end
            local result = current(...)
            return not sourceControlsLease.released and cell.callback == current and result
        end
        sourceControlsLease.memo[callback] = retained
        return retained
    end
    local function sourceWrite(current, object, method, rowWriter, ...)
        if sourceControlsLease.released or self.sourceControlsLease ~= sourceControlsLease then return false end
        local owner = sourceCallback(current)
        if method == "Show" or method == "Hide" or method == "SetEnabled" or method == "SetScript" then rowWriter = nil end
        if method == "SetScript" and type(select(2, ...)) == "function" then
            local event, action = ...
            if rowWriter then return rowWriter(owner, object, method, event, sourceCallback(action)) end
            return self:QuestListWrite(object, method, owner, event, sourceCallback(action))
        end
        if rowWriter then return rowWriter(owner, object, method, ...) end
        return self:QuestListWrite(object, method, owner, ...)
    end
    local primaryLocalize, primaryRefreshIcon = addon.L, self.RefreshFooterIcon
    local primaryCaption = primaryGiver and primaryGiver.caption
    local function primaryRaw()
        return addon.UI == self and self.giver == primaryGiver and primaryGiver ~= nil and
            primaryGiver.caption == primaryCaption and addon.L == primaryLocalize and self.RefreshFooterIcon == primaryRefreshIcon and
            type(primaryLocalize) == "function" and type(primaryRefreshIcon) == "function" and
            not sourceControlsLease.released and self.sourceControlsLease == sourceControlsLease
    end
    local function primaryCurrent(owner)
        if not primaryRaw() then return false end
        local current = owner or portraitCardCurrent
        return current() == true and primaryRaw()
    end
    local function primaryEnabled(enabled, owner)
        if not primaryCurrent(owner) then return false end
        primaryGiver.footerEnabled = enabled == true
        if not primaryGiver.footerEnabled then primaryGiver.footerPressed, primaryGiver.footerHovered = false, false end
        local function current() return primaryCurrent(owner) end
        if not sourceWrite(current, primaryGiver, "SetEnabled", nil, enabled == true) or not current() then return false end
        primaryRefreshIcon(self, primaryGiver)
        return current()
    end
    local function primaryLabel(key, owner)
        if not primaryCurrent(owner) then return false end
        primaryGiver.footerLabelKey = key
        local function current() return primaryCurrent(owner) end
        if not sourceWrite(current, primaryGiver, "SetText", nil, "") then return false end
        if primaryCaption then
            local value = primaryLocalize(key)
            if not current() or not sourceWrite(current, primaryCaption, "SetText", nil, value) then return false end
        end
        return current()
    end
    local function locationWrite(current, object, method, ...)
        return sourceWrite(current, object, method, nil, ...)
    end
    local function sourceGeometryWrite(current, object, method, ...)
        local fresh = locationWrite(current, object, method, ...)
        if fresh or method ~= "ClearAllPoints" or object.sourceGeometryRepair then return fresh end
        local registry = object.questListWrites
        local point = type(registry) == "table" and rawget(registry, "SetPoint")
        local owner = type(point) == "table" and rawget(point, "current")
        local args, count = type(point) == "table" and rawget(point, "args"), type(point) == "table" and rawget(point, "count")
        local setter, recordSetter = object.SetPoint, type(point) == "table" and rawget(point, "setter")
        local writer, reader, clean, checker = self.QuestListWrite, addon.Read, addon.Clean, issecretvalue
        if type(owner) ~= "function" or type(args) ~= "table" or type(count) ~= "number" or count < 1 or count > 5 or count % 1 ~= 0 or
            type(writer) ~= "function" or type(reader) ~= "function" or type(clean) ~= "function" then return false end
        local values = {}; for index = 1, count do values[index] = rawget(args, index) end
        local repair = {}; object.sourceGeometryRepair = repair
        local cell = {}
        local function repairOwner()
            local current = cell.current
            return current ~= nil and current() == true
        end
        local ownPoint, ownArgs, validating
        local function baseSame()
            if not rawequal(object.sourceGeometryRepair, repair) or not rawequal(object.questListWrites, registry) or
                not rawequal(rawget(point, "current"), owner) or not rawequal(rawget(point, "args"), args) or not rawequal(rawget(point, "count"), count) or
                not rawequal(rawget(point, "setter"), recordSetter) or not rawequal(object.SetPoint, setter) or
                self.QuestListWrite ~= writer or addon.Read ~= reader or addon.Clean ~= clean or issecretvalue ~= checker then return false end
            for index = 1, count do if not rawequal(rawget(args, index), values[index]) then return false end end
            return true
        end
        local function publication(record, arguments)
            if not baseSame() or not rawequal(rawget(registry, "SetPoint"), record) then return false end
            if rawequal(record, point) then return rawequal(arguments, args) end
            if type(record) ~= "table" or type(arguments) ~= "table" or (ownPoint and not rawequal(record, ownPoint)) or
                not rawequal(rawget(record, "current"), repairOwner) or not rawequal(rawget(record, "setter"), setter) or
                not rawequal(rawget(record, "count"), count) or not rawequal(rawget(record, "args"), arguments) then return false end
            for index = 1, count do if not rawequal(rawget(arguments, index), values[index]) then return false end end
            return true
        end
        cell.current = function()
            if validating then return false end
            local record = rawget(registry, "SetPoint")
            local arguments = type(record) == "table" and rawget(record, "args")
            if not publication(record, arguments) then return false end
            if not rawequal(record, point) and not ownPoint then ownPoint, ownArgs = record, arguments end
            validating = true
            local current = reader(owner, "boolean") == true
            validating = false
            return current and publication(record, arguments)
        end
        local native, recorded = clean(setter, "function"), clean(recordSetter, "function")
        local succeeded = false
        if type(native) == "function" and type(recorded) == "function" and rawequal(native, setter) and rawequal(recorded, recordSetter) and rawequal(native, recorded) and
            repairOwner() then
            local ok, wrote = pcall(writer, self, object, "SetPoint", repairOwner, unpack(values, 1, count))
            succeeded = ok and wrote == true and ownPoint ~= nil and publication(ownPoint, ownArgs)
        end
        cell.current = succeeded and owner or nil
        if object.sourceGeometryRepair == repair then object.sourceGeometryRepair = nil end
        return false
    end
    for _, buttons in ipairs({ self.reportedToggles, self.reportedRows }) do
        for index, row in ipairs(buttons) do
            local function current() return portraitCardCurrent() and buttons[index] == row end
            if not sourceWrite(current,row,"Hide") or not sourceWrite(current,row,"SetEnabled",nil,false) or
                not sourceWrite(current,row,"SetScript",nil,"OnClick",nil) then return end
        end
    end
    for _, tab in pairs(self.detailTabButtons or {}) do
        if not self:QuestListWrite(tab,"Hide",portraitCardCurrent) or not self:QuestListWrite(tab,"SetEnabled",portraitCardCurrent,false) or
            not self:QuestListWrite(tab,"SetScript",portraitCardCurrent,"OnClick",nil) then return end
    end
    if self.recordedObjectivesToggle then
        local toggle = self.recordedObjectivesToggle
        local function current() return portraitCardCurrent() and self.recordedObjectivesToggle == toggle end
        if not self:QuestListWrite(toggle, "Hide", current) or not self:QuestListWrite(toggle, "SetEnabled", current, false) or
            not self:QuestListWrite(toggle, "SetScript", current, "OnClick", nil) then return end
    end
    if self.ancestorActionButton then
        local control = self.ancestorActionButton
        local function current() return portraitCardCurrent() and self.ancestorActionButton == control end
        if not self:QuestListWrite(control, "Hide", current) or not self:QuestListWrite(control, "SetEnabled", current, false) or
            not self:QuestListWrite(control, "SetScript", current, "OnClick", nil) then return end
    end
    self.turninBinding = nil
    if self.turnin then
        local control = self.turnin
        local function current() return portraitCardCurrent() and self.turnin == control end
        control.footerEnabled = false
        self:RefreshFooterIcon(control)
        if not current() or not self:QuestListWrite(control, "Hide", current) or
            not self:QuestListWrite(control, "SetEnabled", current, false) or
            not self:QuestListWrite(control, "SetScript", current, "OnClick", nil) then return end
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
            local function current() return portraitCardCurrent() and self[field] == texture end
            if not sourceWrite(current, texture, "Hide", nil) then return end
            if not self.portraitRenderBusy then
                self.portraitRenderBusy = true
                pcall(texture.SetTexture, texture, nil)
                self.portraitRenderBusy = nil
                if not portraitCardCurrent() then return end
            end
        end
    end
    if self.overviewArt then self.overviewArt:Hide() end
    self.overviewMapBinding = nil
    if self.overviewMapControl then
        if not self:QuestListWrite(self.overviewMapControl, "Hide", portraitCardCurrent) or
            not self:QuestListWrite(self.overviewMapControl, "SetEnabled", portraitCardCurrent, false) or
            not self:QuestListWrite(self.overviewMapControl, "SetScript", portraitCardCurrent, "OnClick", nil) then return end
    end
    self.action = nil
    self.giverAction, self.giverHasCoordinates, self.giverBinding = nil, false, nil
    if not primaryCurrent() then return end
    self.giverUnavailableKey = nil
    if not primaryEnabled(false) or not primaryLabel("VISIT_GIVER") or
        not sourceWrite(function() return primaryCurrent() end, primaryGiver, "Hide", nil) then return end
    local rewardIndex, objectiveIndex = 0, 0
    local function line(value, style, reward, objective, ownerCurrent, navigation)
        if detailTextLease.released or self.detailTextLease ~= detailTextLease or (ownerCurrent and not ownerCurrent()) then return false end
        local function write(object, method, ...)
            if detailTextLease.released or self.detailTextLease ~= detailTextLease or (ownerCurrent and not ownerCurrent()) then return false end
            local binding
            if method == "SetText" then
                local scope = { current = ownerCurrent or portraitCardCurrent }
                local function current()
                    if detailTextLease.released or self.detailTextLease ~= detailTextLease or not scope.current then return false end
                    local fresh = scope.current()
                    return fresh == true and not detailTextLease.released and self.detailTextLease == detailTextLease
                end
                binding = { current = current, scope = scope, value = (...), quest = renderQuest,
                    dungeon = renderDungeon, engine = renderEngine, character = renderCharacter, generation = rewardGeneration }
                detailTextLease.bindings[#detailTextLease.bindings + 1] = { scope = scope, binding = binding }
                object.detailTextBinding = binding
            end
            object[method](object, ...)
            if detailTextLease.released or self.detailTextLease ~= detailTextLease or (ownerCurrent and not ownerCurrent()) then
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
        local width = navigation and contentWidth - 32 or style == "title" and contentWidth - 40 or contentWidth
        if fs.detailStyle ~= style or fs.detailFont ~= font or fs.detailWidth ~= width then fs.measuredHeight = nil end
        fs.detailStyle, fs.detailFont, fs.detailWidth, fs.navigationInset = style, font, width, navigation and 32 or 0
        if navigation then height = math.max(height, 24) end
        if not write(fs, "SetTextColor", unpack(format.color)) or not write(fs, "SetWidth", width) or
            not write(fs, "ClearAllPoints") or not write(fs, "SetPoint", "TOPLEFT", navigation and 36 or 4, -y) or
            not write(fs, "SetText", value) or not write(fs, "Show") then return false end
        if navigation then
            local control = navigation == true and primaryGiver or navigation
            local primary = control == primaryGiver
            local function position(method, ...)
                if primary then
                    return sourceGeometryWrite(function() return primaryCurrent(ownerCurrent) end, control, method, ...)
                end
                return sourceGeometryWrite(ownerCurrent or portraitCardCurrent, control, method, ...)
            end
            if not position("ClearAllPoints") or not position("SetPoint", "TOPLEFT", self.detail, "TOPLEFT", 4, -y) or
                not position("SetSize", 24, 24) or not position("Show") then return false end
        end
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
                local function iconCurrent()
                    return self.rewardGeneration == rewardGeneration and self.quest == renderQuest and b.rewardBinding == binding
                end
                local function configure(object, method, ...) return self:QuestListWrite(object, method, iconCurrent, ...) end
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", 4, -y)
                if not configure(b.icon, "Show") or not configure(b, "Show") or
                    not configure(b, "SetScript", "OnEnter", function() self:EnterReward(b, binding) end) or
                    not configure(b, "SetScript", "OnHide", function()
                        local held = self.rewardTooltip
                        if held and held.binding == binding and b.rewardBinding == binding then self:ReleaseRewardTooltip(held) end
                    end) then return false end
                b:SetSize(32, 32)
                if not iconCurrent() then return false end
                fs:SetWidth(contentWidth - 40); fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 44, -y)
                height = math.max(height or 18, 32)
            else
                if not self:QuestListWrite(b.icon, "Hide", function()
                    return self.rewardGeneration == rewardGeneration and self.quest == renderQuest
                end) then return false end
                self:SetRewardTexture(b.icon, nil)
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
                local function iconCurrent()
                    return self.rewardGeneration == rewardGeneration and self.quest == renderQuest and button.objectiveBinding == objective
                end
                local function configure(object, method, ...) return self:QuestListWrite(object, method, iconCurrent, ...) end
                button:ClearAllPoints(); button:SetPoint("TOPLEFT", 4, -y)
                if not configure(button.icon, "Show") or not configure(button, "Show") or
                    not configure(button, "SetScript", "OnEnter", function() self:EnterObjective(button, objective) end) or
                    not configure(button, "SetScript", "OnHide", function()
                        local held = self.objectiveTooltip
                        if held and held.binding == objective and button.objectiveBinding == objective then self:ReleaseObjectiveTooltip(held) end
                    end) then return false end
                fs:SetWidth(contentWidth - 30); fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 34, -y)
                height = math.max(height or 18, 24)
            else
                if not self:QuestListWrite(button.icon, "Hide", function()
                    return self.rewardGeneration == rewardGeneration and self.quest == renderQuest
                end) then return false end
                self:SetRewardTexture(button.icon, nil)
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
    for _, buttons in ipairs({ self.actionButtons, self.preparationForButtons }) do
        for _, b in ipairs(buttons) do b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil) end
    end
    if not self:ResetPreparationOverviewControls(portraitCardCurrent) then return end
    for _, b in ipairs(self.branchButtons) do b:Hide() end
    for _, b in ipairs(self.branchInspectButtons) do b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil) end
    for _, b in ipairs(self.requirementButtons) do b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil) end
    for index, row in ipairs(self.materialButtons) do
        local function current() return portraitCardCurrent() and self.materialButtons[index] == row end
        if not self:QuestListWrite(row,"Hide",current) or not self:QuestListWrite(row,"SetEnabled",current,false) or
            not self:QuestListWrite(row,"SetScript",current,"OnClick",nil) then return end
    end
    for _, buttons in ipairs({ self.startButtons, self.finishButtons, self.containerButtons, self.dropButtons, self.objectiveContainerButtons, self.giverButtons }) do
        for index, row in ipairs(buttons) do
            local function current() return portraitCardCurrent() and buttons[index] == row end
            if not sourceWrite(current,row,"Hide") or not sourceWrite(current,row,"SetEnabled",nil,false) or
                not sourceWrite(current,row,"SetScript",nil,"OnClick",nil) then return end
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
        local canOpen = detailTab == "quest" and addon.Read(logCapability, "boolean", id)
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
        local metadataDB, metadataLocalize, metadataChecker = addon.db, addon.L, issecretvalue
        local metadataLocale = metadataDB and rawget(metadataDB, "locale")
        local rawMinimum, rawQuestLevel = rawget(q, "minLevel"), rawget(q, "level")
        local minimum = addon.Clean(rawMinimum, "number")
        local questLevel = addon.Clean(rawQuestLevel, "number")
        local rawRepeatable = rawget(q, "repeatable")
        local repeatable = addon.Clean(rawRepeatable, "boolean")
        if not (questLevel and questLevel > 0 and questLevel <= 9007199254740991 and questLevel % 1 == 0) then questLevel = nil end
        if not (minimum and minimum > 0 and minimum <= 9007199254740991 and minimum % 1 == 0) then minimum = nil end
        local metadataParts = {}
        local function metadataBaseCurrent()
            local ok, same = pcall(function()
                return portraitCardCurrent() and addon.quests[id] == definition and addon.L == metadataLocalize and issecretvalue == metadataChecker and
                    addon.db == metadataDB and (not metadataDB or rawget(metadataDB, "locale") == metadataLocale) and
                    rawequal(rawget(q, "level"), rawQuestLevel) and rawequal(rawget(q, "minLevel"), rawMinimum) and
                    rawequal(rawget(q, "repeatable"), rawRepeatable)
            end)
            return ok and same == true
        end
        local palette = self:QuestLevelPalette(questLevel, metadataBaseCurrent)
        if not palette then return end
        local function metadataCurrent() return metadataBaseCurrent() and palette.current() end
        if minimum or questLevel then
            if not metadataCurrent() then return end
            if questLevel then
                local value = addon.Read(metadataLocalize, "string", "DETAIL_LEVEL", questLevel)
                if value and value:find("%S") and palette.difficulty then value = "|cff" .. palette.difficulty .. value .. "|r" end
                if value and value:find("%S") then metadataParts[#metadataParts + 1] = value end
            end
            if not metadataCurrent() then return end
            if minimum then
                local value = addon.Read(metadataLocalize, "string", "DETAIL_MIN_LEVEL", minimum)
                if value and value:find("%S") and palette.level then value = "|cff" .. (palette.level >= minimum and "66dd99" or "ff5555") .. value .. "|r" end
                if value and value:find("%S") then metadataParts[#metadataParts + 1] = value end
            end
            if not metadataCurrent() then return end
        end
        local factions = audienceLabel({ factions = q.factions }, function()
            return self.quest == renderQuest and self.dungeon == renderDungeon and self.rewardGeneration == rewardGeneration and addon.char == renderCharacter
        end)
        if factions == false then return end

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
        if factions and line(factions, "caption", nil, nil, metadataCurrent) == false then return end
        do
            local keys = { {"quest","TAB_QUEST"}, {"sources","TAB_SOURCES"}, {"story","TAB_STORY"} }
            local buttons = self.detailTabButtons or {}; self.detailTabButtons = buttons
            local setter, localize, database, frame = self.SetDetailTab, addon.L, addon.db, self.frame
            local locale = database and rawget(database,"locale")
            local function current()
                return portraitCardCurrent() and addon.UI == self and self.frame == frame and self.detailTabButtons == buttons and
                    self.SetDetailTab == setter and addon.L == localize and addon.db == database and
                    (not database or rawget(database,"locale") == locale)
            end
            local width, height = (contentWidth-8)/3, 26
            for index, entry in ipairs(keys) do
                local key, localeKey = entry[1], entry[2]
                local control = buttons[key]
                if not control then
                    local candidate = CreateFrame("Button",nil,self.detail); candidate:Hide()
                    candidate.label = label(candidate,"",4,-4,width-8,13)
                    candidate:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                    if not current() then return end
                    control = candidate; buttons[key] = control
                end
                local function owned() return current() and buttons[key] == control end
                local function write(object,method,...) return self:QuestListWrite(object,method,owned,...) end
                setFont(control.label,13)
                local caption = addon.Read(localize,"string",localeKey)
                if not owned() or not caption or not write(control.label,"SetWidth",width-8) or not write(control.label,"SetText",caption) or
                    not write(control.label,"SetTextColor",unpack(detailTab == key and {.96,.83,.59} or {.64,.73,.74})) then return end
                height = math.max(height,measuredHeight(control.label,16)+8)
            end
            for index, entry in ipairs(keys) do
                local key, control = entry[1], buttons[entry[1]]
                local function owned() return current() and buttons[key] == control end
                local function write(object,method,...) return self:QuestListWrite(object,method,owned,...) end
                if not write(control,"SetSize",width,height) or not write(control,"ClearAllPoints") or
                    not write(control,"SetPoint","TOPLEFT",4+(index-1)*(width+4),-y) or not write(control,"SetEnabled",true) then return end
                styleRow(control,"control",detailTab == key)
                if not owned() or not write(control,"SetScript","OnClick",function()
                    if addon.Read(frame.IsShown,"boolean",frame) == true and owned() then setter(self,key) end
                end) or not write(control,"Show") then return end
            end
            y = y + height + 8
        end
        local offerGetter = addon.CurrentOffer
        local offer = detailTab == "quest" and addon.Read(offerGetter, "table", id)
        local offeredNow = offer and addon.Clean(offer.offeredNow, "boolean") == true
        if not portraitCardCurrent() or addon.quests[id] ~= definition or addon.CurrentOffer ~= offerGetter then return end
        if offeredNow and detailTab == "quest" then line(addon.L("OFFERED_NOW")) end
        local start = addon.Clean(q.start, "table")
        local map = start and addon.Clean(start.mapID, "number")
        if detailTab ~= "story" and map and map > 0 and addon.Read(self.HasSummonSource,"boolean",self,start) == false then
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
        local sourceAreaGetter, sourceNameGetter = addon.SourceAreaName, addon.SourceName
        local function namesCurrent(proofs)
            if addon.SourceName ~= sourceNameGetter or addon.SourceAreaName ~= sourceAreaGetter then return false end
            for _, proof in ipairs(proofs) do if addon.Read(proof, "boolean") ~= true then return false end end
            return addon.SourceName == sourceNameGetter and addon.SourceAreaName == sourceAreaGetter and portraitCardCurrent() and self.reportedGeneration == reportedGeneration and
                addon.db == metadataDB and addon.L == metadataLocalize and (not metadataDB or rawget(metadataDB, "locale") == metadataLocale)
        end
        local function locationCurrent()
            return self.quest == renderQuest and self.dungeon == renderDungeon and self.engine == renderEngine and
                addon.char == renderCharacter and self.rewardGeneration == rewardGeneration and self.reportedGeneration == reportedGeneration and
                addon.SourceAreaName == sourceAreaGetter and addon.SourceName == sourceNameGetter and addon.db == metadataDB and addon.L == metadataLocalize and
                (not metadataDB or rawget(metadataDB, "locale") == metadataLocale)
        end
        local function areaName(canonical, current, proofs)
            if type(sourceAreaGetter) ~= "function" then return nil end
            local ok, name, proof = pcall(sourceAreaGetter, canonical, current)
            if not current() then return nil end
            proof = addon.Clean(proof, "function")
            if proof then
                if proofs then proofs[#proofs + 1] = proof end
                if addon.Read(proof, "boolean") ~= true or not current() then return nil end
            end
            if ok then return addon.Clean(name, "string") end
        end
        local function reported(parent, key, ownerCurrent)
            local nameProofs = {}
            local function current() return locationCurrent() and (not ownerCurrent or ownerCurrent()) and namesCurrent(nameProofs) end
            if not current() then return false end
            -- Created objects have no fixed spawn route, even if stale endpoint facts survive a refresh.
            if addon.Read(self.HasSummonSource,"boolean",self,parent) ~= false then return end
            local places = reportedPlaces(parent)
            if not current() then return false end
            if not places then return end
            local parentName = giverName(parent, current, nameProofs)
            if not current() then return false end
            toggleIndex = toggleIndex + 1
            local toggle = self:MakeRow(self.detail, self.reportedToggles, toggleIndex, 40, sourceCallback(current), true)
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
            local nextY = self:LayoutRow(toggle, 40, y, current, function(object, method, ...) return sourceGeometryWrite(current, object, method, ...) end)
            if not nextY then return false end
            y = nextY
            if not locationWrite(current, toggle, "Show") then return false end
            if not expanded then return end
            line(addon.L("REPORTED_NOTICE"))
            local parentCurrent = current
            for _, destination in ipairs(places) do
                local point = destination
                local areaProofs = {}
                local function current() return parentCurrent() and namesCurrent(areaProofs) end
                local zoneName = areaName(point.zoneName, current, areaProofs)
                if not current() then return false end
                if not zoneName then
                    local zone = addon.Read(C_Map and C_Map.GetMapInfo, "table", point.mapID)
                    if not current() then return false end
                    zoneName = (zone and addon.Clean(zone.name, "string")) or point.zoneName or addon.L("UNKNOWN_PLACE")
                end
                if not current() then return false end
                reportIndex = reportIndex + 1
                local row = self:MakeRow(self.detail, self.reportedRows, reportIndex, 59, sourceCallback(current), true)
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
                local nextY = self:LayoutRow(row, 59, y, current, function(object, method, ...) return sourceGeometryWrite(current, object, method, ...) end)
                if not nextY then return false end
                y = nextY
                if not locationWrite(current, row, "Show") then return false end
            end
        end
        local function carried(itemID)
            itemID = addon.Clean(itemID, "number")
            if not itemID or itemID <= 0 or itemID % 1 ~= 0 then return nil end
            local count = addon.Read(addon.CarriedItemCount, "number", itemID)
            if count and count >= 0 and count % 1 == 0 then return addon.L("ITEM_CARRIED", count) end
        end
        local function place(p, ownerCurrent, nameProofs)
            local function current() return locationCurrent() and (not ownerCurrent or ownerCurrent()) end
            if not p then return addon.L("UNKNOWN_PLACE") end
            local canonical = addon.Clean(p.zoneName, "string")
            local zoneName = areaName(canonical, current, nameProofs)
            if not current() then return nil end
            if not zoneName then
                local zone = p.mapID and addon.Read(C_Map and C_Map.GetMapInfo, "table", p.mapID)
                if not current() then return nil end
                zoneName = (zone and addon.Clean(zone.name, "string")) or canonical
            end
            local name = giverName(p, current, nameProofs)
            if not current() then return nil end
            if p.itemID then
                name = addon.L("ITEM_STARTER", addon.Read(addon.ItemName, "string", p.itemID) or name)
                if not current() then return nil end
            end
            local x, py = addon.Clean(p.x, "number"), addon.Clean(p.y, "number")
            local coordinates = x ~= nil and py ~= nil and x >= 0 and x <= 100 and py >= 0 and py <= 100
            return name .. (zoneName and (" — " .. zoneName) or "") ..
                (coordinates and string.format(" (%.1f, %.1f)", x, py) or "")
        end
        local function alternativePlaces(places, buttons, heading, slot, ownerCurrent, offset, clickCurrent, rowWriter, warnPosition)
            local catalogue, count = addon.quests, #places
            local function current()
                return locationCurrent() and (not ownerCurrent or ownerCurrent()) and addon.quests == catalogue and
                    catalogue[id] == definition and #places == count
            end
            if not current() then return false end
            if heading then line(addon.L(heading), "section") end
            if not current() then return false end
            local parentCurrent = current
            for index, possible in ipairs(places) do
                local destination = possible
                local nameProofs = {}
                local fields = { "npcID", "objectID", "itemID", "name", "zoneName", "locationName", "mapID", "x", "y", "reportedLocations" }
                local values = {}; for _, field in ipairs(fields) do values[field] = rawget(destination, field) end
                local clean, reader, localize, nameGetter, checker = addon.Clean, addon.Read, addon.L, addon.GiverName, issecretvalue
                local mapRoot = C_Map
                local mapNamespace = clean(mapRoot, "table")
                local mapGetter = mapNamespace and rawget(mapNamespace, "GetMapInfo")
                local function current()
                    if not parentCurrent() or not namesCurrent(nameProofs) or not rawequal(rawget(places, index), destination) or addon.Clean ~= clean or addon.Read ~= reader or addon.L ~= localize or
                        addon.GiverName ~= nameGetter or issecretvalue ~= checker or C_Map ~= mapRoot or
                        (mapNamespace and rawget(mapNamespace, "GetMapInfo") ~= mapGetter) then return false end
                    for _, field in ipairs(fields) do if not rawequal(rawget(destination, field), values[field]) then return false end end
                    return true
                end
                local function write(object, method, ...)
                    return sourceWrite(current, object, method, rowWriter, ...)
                end
                if not current() then return false end
                local title = giverName(destination, current, nameProofs)
                if not current() then return false end
                local mapID = addon.Clean(destination.mapID, "number")
                local validMap = mapID ~= nil and mapID > 0 and mapID % 1 == 0
                local canonical = addon.Clean(destination.zoneName, "string")
                local area = areaName(canonical, current, nameProofs)
                if not current() then return false end
                if not area then
                    local zone = validMap and reader(mapGetter, "table", mapID)
                    if not current() then return false end
                    area = (zone and addon.Clean(zone.name, "string")) or canonical or addon.Clean(destination.locationName, "string")
                end
                local x, py = addon.Clean(destination.x, "number"), addon.Clean(destination.y, "number")
                local coordinates = validMap and x ~= nil and py ~= nil and x >= 0 and x <= 100 and py >= 0 and py <= 100
                local note = (area or addon.L("UNKNOWN_PLACE")) ..
                    (coordinates and string.format(" (%.1f, %.1f)", x, py) or "")
                if warnPosition and not coordinates then
                    note = (area and (area .. " — ") or "") .. "|cffff594d" .. addon.L("SOURCE_POSITION_UNKNOWN") .. "|r"
                elseif not validMap then
                    note = (area and (area .. " — ") or "") .. "|cffff594d" ..
                        addon.L(area and "SOURCE_POSITION_UNKNOWN" or "UNKNOWN_PLACE") .. "|r"
                end
                if not current() then return false end
                local row = self:MakeRow(self.detail, buttons, (offset or 0) + index, 59, sourceCallback(current), true)
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
                local nextY = self:LayoutRow(row, 59, y, current, function(object, method, ...) return sourceGeometryWrite(current, object, method, ...) end)
                if not nextY then return false end
                y = nextY
                if reported(destination, slot .. index, current) == false or not current() or not write(row, "Show") then return false end
            end
        end
        local summonGetter = self.SummonSource
        local declaredSummon = addon.Read(self.HasSummonSource,"boolean",self,start) ~= false
        local startSummon = addon.Read(summonGetter, "table", self, start)
        if not locationCurrent() or self.SummonSource ~= summonGetter then return end
        local function summonInstruction(endpoint, sourceField, ownerCurrent, source)
            source = source or addon.Read(summonGetter, "table", self, endpoint)
            if not source then return true end
            local itemGetter, iconGetter, countGetter, localize = addon.ItemName, addon.ItemIcon, addon.CarriedItemCount, addon.L
            local objectGetter = addon.GiverName
            local nameProofs = {}
            local database = addon.db; local locale = database and rawget(database,"locale")
            local function current(binding)
                return locationCurrent() and portraitCardCurrent() and addon.quests[id] == definition and q[sourceField] == endpoint and
                    self.SummonSource == summonGetter and source.current() and (not ownerCurrent or ownerCurrent()) and
                    addon.ItemName == itemGetter and addon.ItemIcon == iconGetter and addon.CarriedItemCount == countGetter and addon.L == localize and
                    addon.db == database and (not database or rawget(database,"locale")==locale) and
                    (not binding or (binding.id==source.itemID and binding.role=="source-tool" and binding.sourceField==sourceField..".summonItem")) and
                    addon.GiverName == objectGetter and source.same() and namesCurrent(nameProofs)
            end
            local name = addon.Read(itemGetter,"string",source.itemID)
            if not current() then return false end
            if not name or #name>1024 or not name:find("%S") then name=source.name end
            local objectName = giverName(endpoint,current,nameProofs)
            if not current() then return false end
            if not objectName or #objectName>1024 or not objectName:find("%S") then objectName=source.objectName end
            local text = addon.Read(localize,"string","SOURCE_SUMMON_ITEM",name,objectName)
            if not current() or not text or not text:find("%S") then return false end
            local texture = addon.Read(iconGetter,"number",source.itemID)
            if not current() then return false end
            local count = addon.Read(countGetter,"number",source.itemID)
            if not current() then return false end
            local binding = texture and texture>0 and texture<=4294967295 and texture%1==0 and
                {id=source.itemID,texture=texture,role="source-tool",sourceField=sourceField..".summonItem",current=current}
            sourceFocusOffset,sourceFocusCurrent=y,current
            if text and text:find("%S") and line(text,nil,nil,binding,current)==false then return false end
            if count and count>=0 and count<=9007199254740991 and count%1==0 then
                local carriedText=addon.Read(localize,"string","ITEM_CARRIED",count)
                if not current() or line(carriedText,"caption",nil,nil,current)==false then return false end
            end
            return current()
        end
        local startItemID = start and addon.Clean(rawget(start, "itemID"), "number")
        local itemStarter = startItemID and startItemID > 0 and startItemID <= 9007199254740991 and startItemID % 1 == 0 and
            rawget(start, "npcID") == nil and rawget(start, "objectID") == nil and q.startAlternatives == nil
        local missingStart = rawequal(rawget(q, "start"), nil) and rawequal(rawget(q, "startAlternatives"), nil)
        local function missingStartCurrent()
            return metadataCurrent() and portraitCardCurrent() and addon.quests[id] == definition and
                rawequal(rawget(q, "start"), nil) and rawequal(rawget(q, "startAlternatives"), nil)
        end
        local pendingStarterCarried
        if detailTab ~= "story" then
        if not primaryCurrent() then return end
        self.giverUnavailableKey = missingStart and "QUEST_START_UNKNOWN" or itemStarter and "START_ITEM_LOCATION_UNKNOWN" or q.startAlternatives and "GIVER_CHOICES_REQUIRED" or "GIVER_LOCATION_UNKNOWN"
        if missingStart and not primaryLabel("SOURCE_DETAILS", missingStartCurrent) then return end
        if not itemStarter and line(addon.L(missingStart and "SOURCE_DETAILS" or "DETAIL_GIVER"), "caption", nil, nil, missingStart and missingStartCurrent or portraitCardCurrent, not start and q.startAlternatives ~= nil) == false then return end
        if start then
            local nameProofs = {}
            local giverFields = { "npcID", "objectID", "itemID", "name", "zoneName", "locationName", "mapID", "x", "y" }
            local giverValues, nameGetter, itemGetter, iconGetter, countGetter, mapRoot, checker = {}, addon.GiverName, addon.ItemName, addon.ItemIcon, addon.CarriedItemCount, C_Map, issecretvalue
            for _, field in ipairs(giverFields) do giverValues[field] = rawget(start, field) end
            local function giverCurrent()
                local ok, same = pcall(function()
                    if not locationCurrent() or not portraitCardCurrent() or addon.quests[id] ~= definition or q.start ~= start
                        or addon.SourceAreaName ~= sourceAreaGetter or addon.GiverName ~= nameGetter or addon.ItemName ~= itemGetter or addon.ItemIcon ~= iconGetter or addon.CarriedItemCount ~= countGetter or C_Map ~= mapRoot or issecretvalue ~= checker then return false end
                    for _, field in ipairs(giverFields) do
                        local value = rawget(start, field)
                        if type(checker) == "function" and addon.Read(checker, "boolean", value) ~= false then return false end
                        if value ~= giverValues[field] then return false end
                    end
                    for _, field in ipairs(giverFields) do if rawget(start, field) ~= giverValues[field] then return false end end
                    return portraitCardCurrent() and namesCurrent(nameProofs)
                end)
                return ok and same == true
            end
            if not giverCurrent() then return end
            local description = addon.Read(place, "string", start, giverCurrent, nameProofs)
            if not giverCurrent() then return end
            local starterBinding, starterCarried
            if itemStarter then
                local itemID = addon.Clean(rawget(start, "itemID"), "number")
                if itemID and itemID > 0 and itemID <= 4294967295 and itemID % 1 == 0 then
                    local count = carried(itemID)
                    if not giverCurrent() then return end
                    starterCarried = count
                    local icon = addon.Read(iconGetter, "number", itemID)
                    if not giverCurrent() then return end
                    if icon and icon > 0 and icon <= 4294967295 and icon % 1 == 0 then
                        starterBinding = { id = itemID, texture = icon, role = "starter", sourceField = "start", current = giverCurrent }
                    end
                end
            end
            local giverInlinePlaced = description and description ~= addon.L("UNKNOWN_PLACE")
            if giverInlinePlaced and line(description, nil, nil, starterBinding, giverCurrent, not itemStarter and not declaredSummon) == false then return end
            if starterCarried then
                local duplicateCandidate = false
                if detailTab == "quest" then
                    local provided = addon.Clean(rawget(q, "providedItems"), "table")
                    for index = 1, math.min(provided and #provided or 0, 100) do
                        local entry = addon.Clean(rawget(provided, index), "table")
                        if entry and addon.Clean(rawget(entry, "itemID"), "number") == startItemID then duplicateCandidate = true; break end
                    end
                end
                if not giverCurrent() then return end
                if duplicateCandidate then
                    pendingStarterCarried = { id = startItemID, value = starterCarried, current = giverCurrent }
                elseif line(starterCarried, "caption", nil, nil, giverCurrent) == false then return end
            end
            if itemStarter and rawget(start, "containerSource") == nil and rawget(start, "dropNPCID") == nil and rawget(start, "dropSources") == nil then
                if line(addon.L("START_ITEM_LOCATION_UNKNOWN"), "warning", nil, nil, giverCurrent) == false then return end
            end
            if startSummon then
                if not primaryCurrent(giverCurrent) then return end
                self.giverUnavailableKey = "SOURCE_SUMMON_HINT"
                if not summonInstruction(start,"start",giverCurrent,startSummon) then return end
            end
            if not itemStarter and not startSummon and (not pendingGiver or not pendingGiver.coordinates) then
                local area = addon.Clean(rawget(start, "zoneName"), "string")
                if not area or not area:find("%S") then area = addon.Clean(rawget(start, "locationName"), "string") end
                if not primaryCurrent(giverCurrent) then return end
                local warning = pendingGiver and "GIVER_COORDINATES_UNKNOWN" or
                    area and area:find("%S") and "SOURCE_POSITION_UNKNOWN" or "GIVER_LOCATION_UNKNOWN"
                self.giverUnavailableKey = warning
                if line(addon.L(warning), "warning", nil, nil, giverCurrent, not giverInlinePlaced) == false then return end
            end
        elseif q.startAlternatives then
            local alternatives = q.startAlternatives
            local primary = rawget(q, "start")
            local count, preview, remaining, snapshot = #alternatives, {}, {}, {}
            for index, point in ipairs(alternatives) do
                snapshot[index] = point
                if index <= 2 then preview[index] = point else remaining[#remaining + 1] = point end
            end
            local function giverCurrent()
                if not portraitCardCurrent() or addon.quests[id] ~= definition or not rawequal(rawget(q, "start"), primary) or
                    q.startAlternatives ~= alternatives or #alternatives ~= count then return false end
                for index, point in ipairs(snapshot) do if alternatives[index] ~= point then return false end end
                return portraitCardCurrent()
            end
            if detailTab == "sources" then
                if alternativePlaces(preview, self.giverButtons, "START_ALTERNATIVES", "giverAlternative:", giverCurrent) == false then return end
                if #remaining > 0 and alternativePlaces(remaining, self.startButtons, nil, "startAlternative:", giverCurrent) == false then return end
            elseif line(addon.L("GIVER_CHOICES_REQUIRED"),"caption",nil,nil,giverCurrent) == false then return end
        elseif line(addon.L(missingStart and "QUEST_START_UNKNOWN" or "GIVER_LOCATION_UNKNOWN"), "warning", nil, nil, missingStart and missingStartCurrent or portraitCardCurrent, true) == false then return end
        do
            local finish = addon.Clean(q.finish, "table")
            local nameProofs = {}
            local fields, values, startingValues = { "npcID", "objectID", "itemID", "name", "zoneName", "mapID", "x", "y" }, {}, {}
            local endpointChecker = issecretvalue
            if finish then
                local alternatives, declaredSummon = rawget(q, "finishAlternatives"), rawget(finish, "summonItem")
                local summonPresence, engineGetter, nextGetter, stateGetter = self.HasSummonSource, engine.Current, engine.Next, engine.State
                local same = start ~= nil
                for _, field in ipairs(fields) do
                    values[field], startingValues[field] = rawget(finish, field), start and rawget(start, field)
                    if type(endpointChecker) == "function" and (addon.Read(endpointChecker, "boolean", values[field]) ~= false or
                        addon.Read(endpointChecker, "boolean", startingValues[field]) ~= false) then return end
                    if not rawequal(values[field], startingValues[field]) then same = false end
                end
                local function endingCurrent()
                    if not locationCurrent() or not portraitCardCurrent() or addon.SourceAreaName ~= sourceAreaGetter or addon.quests[id] ~= definition or q.finish ~= finish or q.start ~= start or issecretvalue ~= endpointChecker then return false end
                    for _, field in ipairs(fields) do
                        local ending, starting = rawget(finish, field), start and rawget(start, field)
                        if type(endpointChecker) == "function" and (addon.Read(endpointChecker, "boolean", ending) ~= false or
                            addon.Read(endpointChecker, "boolean", starting) ~= false) then return false end
                        if not rawequal(ending, values[field]) or not rawequal(starting, startingValues[field]) then return false end
                    end
                    for _, field in ipairs(fields) do
                        if not rawequal(rawget(finish, field), values[field]) or not rawequal(start and rawget(start, field), startingValues[field]) then return false end
                    end
                    if not rawequal(rawget(q, "finishAlternatives"), alternatives) or not rawequal(rawget(finish, "summonItem"), declaredSummon) then return false end
                    return portraitCardCurrent() and namesCurrent(nameProofs)
                end
                if not same then
                    local ending = addon.Read(place, "string", finish, endingCurrent, nameProofs)
                    if not endingCurrent() then return end
                    if ending and ending ~= addon.L("UNKNOWN_PLACE") then
                        if state.status == "READY" then
                            local readable = type(endpointChecker) ~= "function" or
                                (addon.Read(endpointChecker, "boolean", alternatives) == false and addon.Read(endpointChecker, "boolean", declaredSummon) == false)
                            local npc, object = addon.Clean(values.npcID, "number"), addon.Clean(values.objectID, "number")
                            local map, x, gy = addon.Clean(values.mapID, "number"), addon.Clean(values.x, "number"), addon.Clean(values.y, "number")
                            local ok, typed = pcall(function()
                                return (npc and npc > 0 and npc <= 4294967295 and npc % 1 == 0 and values.objectID == nil and values.itemID == nil) or
                                    (object and object > 0 and object <= 4294967295 and object % 1 == 0 and values.npcID == nil and values.itemID == nil)
                            end)
                            if not endingCurrent() then return end
                            if readable and alternatives == nil and ok and typed and map and map > 0 and map <= 9007199254740991 and map % 1 == 0 and
                                addon.Read(summonPresence, "boolean", self, finish) == false then
                                local function current()
                                    local fresh = not engineGetter or addon.Read(engineGetter, "boolean", engine) == true
                                    return fresh and endingCurrent() and state.status == "READY" and self.HasSummonSource == summonPresence and
                                        engine.Current == engineGetter and engine.Next == nextGetter and engine.State == stateGetter
                                end
                                if not current() then return end
                                pendingTurnin = { place = finish, current = current,
                                    coordinates = x ~= nil and gy ~= nil and x >= 0 and x <= 100 and gy >= 0 and gy <= 100 }
                            end
                        end
                        if line(addon.L("DETAIL_TURNIN") .. ": " .. ending, "caption", nil, nil, endingCurrent,
                            pendingTurnin and self.turnin) == false then return end
                        local area = addon.Clean(values.zoneName, "string")
                        local map, x, gy = addon.Clean(values.mapID, "number"), addon.Clean(values.x, "number"), addon.Clean(values.y, "number")
                        local mapped = map and map > 0 and map <= 9007199254740991 and map % 1 == 0
                        local exact = mapped and x and gy and x >= 0 and x <= 100 and gy >= 0 and gy <= 100
                        local name = addon.Clean(values.name, "string")
                        local npc, object = addon.Clean(values.npcID, "number"), addon.Clean(values.objectID, "number")
                        local identityOK, identity = pcall(function()
                            return name and #name <= 256 and name:find("%S") and
                                ((npc and npc > 0 and npc <= 4294967295 and npc % 1 == 0 and values.objectID == nil and values.itemID == nil) or
                                (object and object > 0 and object <= 4294967295 and object % 1 == 0 and values.npcID == nil and values.itemID == nil))
                        end)
                        local readable = type(endpointChecker) ~= "function" or
                            (addon.Read(endpointChecker, "boolean", alternatives) == false and addon.Read(endpointChecker, "boolean", declaredSummon) == false)
                        if not endingCurrent() then return end
                        if readable and alternatives == nil and declaredSummon == nil and not exact and (mapped or area and area:find("%S") or identityOK and identity == true) then
                            if line(addon.L("SOURCE_POSITION_UNKNOWN"), "warning", nil, nil, endingCurrent) == false then return end
                        end
                    end
                end
                local finishSummon = addon.Read(summonGetter,"table",self,finish)
                if not endingCurrent() or self.SummonSource~=summonGetter or (startSummon and not startSummon.current()) or
                    (finishSummon and not finishSummon.current()) then return end
                if finishSummon and not (startSummon and startSummon.objectID==finishSummon.objectID and startSummon.itemID==finishSummon.itemID) then
                    if not summonInstruction(finish,"finish",endingCurrent,finishSummon) then return end
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
        if detailTab == "quest" then
        if (state.status == "ACTIVE" or state.status == "READY" or state.status == "COMPLETED" or state.status == "AVAILABLE") then
            if line("|cff" .. COLOR[state.status] .. statusLabel(state) .. "|r", nil, nil, nil, portraitCardCurrent) == false then return end
        end
        if state.reason and state.reason ~= "level" then
            local key = state.reason == "requirements" and state.status == "UNKNOWN" and "REASON_requirementsUnknown" or "REASON_" .. state.reason
            if line(addon.L(key), nil, nil, nil, portraitCardCurrent) == false then return end
        end
        if not metadataCurrent() then return end
        do
            local actionID = action and addon.Clean(action.id, "number")
            local kind = action and addon.Clean(action.kind, "string")
            local ancestor = actionID and addon.Clean(addon.quests[actionID], "table")
            if ancestor and actionID ~= id and (kind == "complete" or kind == "turnin") then
                local endpoint = rawget(ancestor, "finish")
                local destination = action.place
                local heldState = engine:State(actionID)
                local heldStatus = kind == "turnin" and "READY" or "ACTIVE"
                if heldState.status == heldStatus and ((kind == "complete" and destination == nil) or
                    (kind == "turnin" and rawequal(destination, endpoint))) then
                    local clean, reader, localize, names, inspect = addon.Clean, addon.Read, addon.L, addon.CachedQuestName, self.InspectQuest
                    local checker, catalogue, database, frame = issecretvalue, addon.quests, addon.db, self.frame
                    local locale = database and rawget(database, "locale")
                    local engineCurrent, engineNext, engineState = engine.Current, engine.Next, engine.State
                    local snapshots, seen, valid = {}, {}, true
                    local function capture(object, keys, length)
                        if #snapshots >= 512 then valid = false; return end
                        local values = {}; for _, key in ipairs(keys) do values[key] = rawget(object, key) end
                        snapshots[#snapshots + 1] = { object = object, keys = keys, values = values, length = length }
                    end
                    local function dependency(questID)
                        if seen[questID] or not valid then return end
                        seen[questID] = true
                        if #snapshots >= 256 then valid = false; return end
                        local definition = clean(catalogue[questID], "table")
                        if not definition then valid = false; return end
                        capture(catalogue, { questID })
                        capture(definition, { "id", "name", "requires" })
                        local groups = clean(rawget(definition, "requires"), "table")
                        if not groups then return end
                        if #groups > 100 then valid = false; return end
                        local keys = {}; for index = 1, #groups do keys[index] = index end
                        capture(groups, keys, #groups)
                        for _, index in ipairs(keys) do
                            local group = clean(rawget(groups, index), "table")
                            local ids = group and clean(rawget(group, "ids"), "table")
                            if not ids or #ids > 100 then valid = false; return end
                            capture(group, { "ids", "mode" })
                            local members = {}; for n = 1, #ids do members[n] = n end
                            capture(ids, members, #ids)
                            for _, n in ipairs(members) do
                                local parent = clean(rawget(ids, n), "number")
                                if not parent or parent <= 0 or parent % 1 ~= 0 then valid = false; return end
                                dependency(parent)
                            end
                        end
                    end
                    dependency(id)
                    capture(ancestor, { "id", "name", "finish" })
                    if type(endpoint) == "table" then
                        capture(endpoint, { "npcID", "objectID", "itemID", "name", "zoneName", "mapID", "x", "y", "summonItem", "reportedLocations" })
                    end
                    local control = self.ancestorActionButton
                    local function cueCurrent()
                        if not current() or not portraitCardCurrent() then return false end
                        local ok, same = pcall(function()
                            if addon.UI ~= self or not valid or not seen[actionID] or addon.Clean ~= clean or addon.Read ~= reader or addon.L ~= localize or
                                addon.CachedQuestName ~= names or self.InspectQuest ~= inspect or issecretvalue ~= checker or
                                addon.quests ~= catalogue or addon.db ~= database or (database and rawget(database,"locale") ~= locale) or
                                engine.Current ~= engineCurrent or engine.Next ~= engineNext or engine.State ~= engineState or
                                self.frame ~= frame or self.ancestorActionButton ~= control or action.id ~= actionID or action.kind ~= kind or action.place ~= destination or
                                engine.states[actionID] ~= heldState or heldState.status ~= heldStatus then return false end
                            for _, snapshot in ipairs(snapshots) do
                                if snapshot.length and #snapshot.object ~= snapshot.length then return false end
                                for _, key in ipairs(snapshot.keys) do
                                    if not rawequal(rawget(snapshot.object, key), snapshot.values[key]) then return false end
                                end
                            end
                            local member = false; for _, candidate in ipairs(actions) do if candidate == action then member = true; break end end
                            return member
                        end)
                        return ok and same == true
                    end
                    if not cueCurrent() then return end
                    if not control then
                        local candidate = CreateFrame("Button", nil, self.detail); candidate:Hide()
                        candidate.label = label(candidate, "", 4, -3, contentWidth - 8, 13)
                        candidate:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                        if not cueCurrent() then return end
                        control = candidate; self.ancestorActionButton = control
                    end
                    local function write(object, method, ...) return self:QuestListWrite(object, method, cueCurrent, ...) end
                    setFont(control.label, 13)
                    if not cueCurrent() then return end
                    local name = reader(names, "string", actionID)
                    if not cueCurrent() then return end
                    local targetName = reader(names, "string", id)
                    if not cueCurrent() then return end
                    if not name or not name:find("%S") then name = clean(ancestor.name, "string") end
                    if name and (name == targetName or rawget(ancestor,"name") == rawget(q,"name")) then name = name .. " #" .. actionID end
                    local prefix, status = reader(localize,"string","ANCESTOR_ACTION"), reader(localize,"string",heldStatus)
                    if not cueCurrent() then return end
                    if name and prefix and status then
                        local text = prefix .. ": " .. name .. " — " .. status
                        if not write(control.label,"SetWidth",contentWidth - 8) or not write(control.label,"SetText",text) or
                            not write(control.label,"SetTextColor",.53,.77,1) then return end
                        local height = math.max(22, measuredHeight(control.label,16) + 6)
                        if not cueCurrent() or not write(control,"SetSize",contentWidth,height) or not write(control,"ClearAllPoints") or
                            not write(control,"SetPoint","TOPLEFT",4,-y) or not write(control,"SetEnabled",true) or
                            not write(control,"SetScript","OnClick",function()
                                if reader(frame.IsShown,"boolean",frame) ~= true or reader(control.IsShown,"boolean",control) ~= true or
                                    not cueCurrent() or self.action ~= action then return end
                                inspect(self,actionID,true)
                            end) or not write(control,"Show") then return end
                        y = y + height + 6
                    end
                end
            end
        end
        end
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
                if binding and binding.generation == rewardGeneration and binding.scope and binding.scope.current == current then
                    captionField, captionBinding = captionCandidate, binding
                end
                if captionWritten == false then return retireOwnedImage() end
                texture:SetPoint("TOPLEFT", 4, -y)
                if not imageCurrent() then return retireOwnedImage() end
                if not sourceWrite(imageCurrent, texture, "Show", nil) or not imageCurrent() then return retireOwnedImage() end
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
            referenceActions = actions
            if not portraitCardCurrent() then return end
            if #referenceActions == 1 then
                local candidate = referenceActions[1]
                if candidate.id == id and candidate.kind == "turnin" and candidate.place == q.finish and not q.finishAlternatives then
                    referenceAction = candidate
                end
            end
        end
        local function sourceReference(point, endpoint, captionKey, turnin)
            local nameProofs = {}
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
                            referenceAction.id == id and referenceAction.kind == "turnin" and referenceAction.place == point)) and namesCurrent(nameProofs)
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
                    if not name or #name > 1024 or not name:find("%S") then name = nil end
                    name = giverName(point, sourceCurrent, nameProofs, name)
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
        if detailTab == "quest" then
        local recordedGoals
        do
            local progressGetter, dialogueGetter, objectiveChecker = addon.QuestObjectives, addon.DialogueObjectiveText, issecretvalue
            local clean, reader = addon.Clean, addon.Read
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
            if objectives and #objectives > 0 and #objectives <= 100 then
                local snapshots, meaningful = {}, false
                for index = 1, #objectives do
                    local entry = addon.Clean(rawget(objectives, index), "table")
                    local text = entry and addon.Clean(rawget(entry, "text"), "string")
                    local finished = entry and addon.Clean(rawget(entry, "finished"), "boolean")
                    if not entry or not text or #text > 30000 or finished == nil then snapshots = nil; break end
                    snapshots[index] = { entry = entry, text = text, finished = finished }
                    meaningful = meaningful or text:find("%S") ~= nil
                end
                if snapshots and meaningful then
                    local nativeRoot = C_QuestLog
                    local native = addon.Clean(nativeRoot, "table")
                    local nativeGetter = native and rawget(native, "GetQuestObjectives")
                    local localize, database, localeGetter = addon.L, addon.db, GetLocale
                    local locale = database and rawget(database, "locale")
                    local gameLocale = addon.Read(localeGetter, "string")
                    local function rawCurrent()
                        if addon.Clean ~= clean or addon.Read ~= reader or addon.L ~= localize or addon.db ~= database or (database and rawget(database, "locale") ~= locale) or
                            GetLocale ~= localeGetter or C_QuestLog ~= nativeRoot or
                            (native and rawget(native, "GetQuestObjectives") ~= nativeGetter) or #objectives ~= #snapshots then return false end
                        for index, snapshot in ipairs(snapshots) do
                            if rawget(objectives, index) ~= snapshot.entry or not rawequal(rawget(snapshot.entry, "text"), snapshot.text) or
                                not rawequal(rawget(snapshot.entry, "finished"), snapshot.finished) then return false end
                        end
                        return true
                    end
                    local function liveCurrent()
                        if not objectivesCurrent() or addon.Read(localeGetter, "string") ~= gameLocale then return false end
                        local ok, same = pcall(rawCurrent)
                        return ok and same == true and objectivesCurrent()
                    end
                    local function readCurrentLive()
                        if not liveCurrent() then return false end
                        local fresh = addon.Read(progressGetter, "table", id)
                        if not liveCurrent() or not fresh or #fresh ~= #snapshots then return false end
                        for index, snapshot in ipairs(snapshots) do
                            local entry = addon.Clean(rawget(fresh, index), "table")
                            if not entry or addon.Clean(rawget(entry, "text"), "string") ~= snapshot.text or
                                addon.Clean(rawget(entry, "finished"), "boolean") ~= snapshot.finished then return false end
                        end
                        return liveCurrent()
                    end
                    if not liveCurrent() then return end
                    recordedGoals = { current = liveCurrent, readCurrent = readCurrentLive }
                end
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
        if recordedGoals then
            local snapshots = {}
            local function capture(object, keys, length)
                local values = {}; for _, key in ipairs(keys) do values[key] = rawget(object, key) end
                snapshots[#snapshots + 1] = { object = object, keys = keys, values = values, length = length }
            end
            for _, field in ipairs({ "objectiveKills", "objectiveObjects", "objectiveEvents" }) do
                capture(q, { field })
                local rows = addon.Clean(rawget(q, field), "table")
                if rows then
                    local indexes = {}; for index = 1, math.min(#rows, 100) do indexes[index] = index end
                    capture(rows, indexes, #rows)
                    for _, index in ipairs(indexes) do
                        local row = addon.Clean(rawget(rows, index), "table")
                        if row then capture(row, { "npcID", "objectID", "itemID", "name", "quantity" }) end
                    end
                end
            end
            recordedGoals.sourceSame = function()
                local ok, same = pcall(function()
                    for _, snapshot in ipairs(snapshots) do
                        if snapshot.length and #snapshot.object ~= snapshot.length then return false end
                        for _, key in ipairs(snapshot.keys) do
                            if not rawequal(rawget(snapshot.object, key), snapshot.values[key]) then return false end
                        end
                    end
                    return true
                end)
                return ok and same == true
            end
        end
        local function recordedLine(value, style, reward, objective, ownerCurrent)
            if not recordedGoals then return line(value, style, nil, nil, ownerCurrent) end
            if not recordedGoals.current() or not ownerCurrent() then return false end
            if #recordedGoals >= 302 then return false end
            recordedGoals[#recordedGoals + 1] = { value = value, style = style, current = ownerCurrent }
            return true
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
                            if recordedLine(heading, "caption", nil, nil, killCurrent) == false then return end
                            shownKills = true
                        end
                        if recordedLine(text, nil, nil, nil, killCurrent) == false then return end
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
                                    if recordedLine(heading, "caption", nil, nil, entryCurrent) == false then return end
                                    shown = true
                                end
                                if recordedLine(text, nil, nil, nil, entryCurrent) == false then return end
                            elseif not listsCurrent() then return end
                        end
                    end
                end
            end
        end
        if recordedGoals and #recordedGoals > 0 then
            local toggle = self.recordedObjectivesToggle
            if not toggle then
                toggle = CreateFrame("Button", nil, self.detail); toggle:Hide()
                toggle.label = label(toggle, "", 4, -3, contentWidth - 8, 13)
                toggle:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                if not portraitCardCurrent() then return end
                self.recordedObjectivesToggle = toggle
            end
            local frame, refresh = self.frame, self.RefreshDetail
            local function current()
                return recordedGoals.current() and portraitCardCurrent() and self.frame == frame and
                    self.RefreshDetail == refresh and self.recordedObjectivesToggle == toggle
            end
            local function sourcesCurrent()
                if not current() then return false end
                for _, goal in ipairs(recordedGoals) do if not goal.current() then return false end end
                return current() and recordedGoals.sourceSame()
            end
            local function write(object, method, ...) return self:QuestListWrite(object, method, current, ...) end
            setFont(toggle.label, 13)
            if not sourcesCurrent() then return end
            local caption = addon.Read(addon.L, "string", "DETAIL_RECORDED_OBJECTIVES")
            if not current() or not caption or not caption:find("%S") then return end
            if not write(toggle.label, "SetText", (objectivesExpanded and "− " or "+ ") .. caption) or
                not write(toggle.label, "SetTextColor", .64, .73, .74) then return end
            local width = math.min(contentWidth, math.max(40, (addon.Read(toggle.label.GetStringWidth, "number", toggle.label) or 180) + 8))
            if not current() or not write(toggle.label, "SetWidth", width - 8) then return end
            local height = math.max(22, measuredHeight(toggle.label, 16) + 6)
            if not current() or not write(toggle, "SetSize", width, height) or not write(toggle, "ClearAllPoints") or
                not write(toggle, "SetPoint", "TOPLEFT", 4, -y) or not write(toggle, "SetEnabled", true) or
                not write(toggle, "SetScript", "OnClick", function()
                    if not sourcesCurrent() or addon.Read(frame.IsShown, "boolean", frame) ~= true or
                        addon.Read(toggle.IsShown, "boolean", toggle) ~= true or not sourcesCurrent() or
                        not recordedGoals.readCurrent() or not sourcesCurrent() then return end
                    local scroll, getter, checker = self.detailScroll, self.detailScroll.GetVerticalScroll, issecretvalue
                    local offset = addon.Read(getter, "number", scroll)
                    if not sourcesCurrent() or self.detailScroll ~= scroll or scroll.GetVerticalScroll ~= getter or issecretvalue ~= checker then return end
                    self.detailObjectivesExpanded = not objectivesExpanded
                    local generation = refresh(self)
                    local function fresh()
                        return generation and self.rewardGeneration == generation and self.quest == renderQuest and self.dungeon == renderDungeon and
                            self.engine == renderEngine and addon.char == renderCharacter and self.frame == frame and self.RefreshDetail == refresh and
                            self.detailScroll == scroll and scroll.GetVerticalScroll == getter and issecretvalue == checker and
                            (self.detailObjectivesExpanded == true) ~= objectivesExpanded
                    end
                    if not fresh() or not offset or offset < 0 then return end
                    local content = addon.Read(self.detail.GetHeight, "number", self.detail)
                    local viewport = addon.Read(scroll.GetHeight, "number", scroll)
                    if fresh() and content and content >= 0 and viewport and viewport > 0 then
                        self:WriteDetailScroll(scroll, math.min(offset, math.max(0, content - viewport)), fresh)
                    end
                end) or not write(toggle, "Show") then return end
            if not sourcesCurrent() then
                if current() then write(toggle, "Hide") end
                return
            end
            y = y + height + 4
            if objectivesExpanded then
                for _, goal in ipairs(recordedGoals) do
                    if line(goal.value, goal.style, nil, nil, goal.current) == false then return end
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
                    if line(text, nil, nil, binding, entryCurrent) == false then return end
                    if sourceRole == "provided" and pendingStarterCarried and itemID == pendingStarterCarried.id and count then
                        if not pendingStarterCarried.current() or not entryCurrent() then return end
                        pendingStarterCarried = nil
                    end
                end
            end
        end

        if pendingStarterCarried then
            local pending = pendingStarterCarried
            if not pending.current() or line(pending.value, "caption", nil, nil, pending.current) == false then return end
            pendingStarterCarried = nil
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
        if detailTab == "quest" or detailTab == "sources" then
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
        end
        if detailTab == "quest" then
        local rewards, rewardOrigin = rewardData(id)
        local items = rewards and addon.Clean(rewards.items, "table")
        local choices = rewards and addon.Clean(rewards.choices, "table")
        local hidden = rewards and addon.Clean(rewards.hidden, "boolean") == true
        local xp = rewards and addon.Clean(rewards.xp, "number")
        local money = rewards and addon.Clean(rewards.money, "number")
        if not (money and money > 0 and money <= 9007199254740991 and money % 1 == 0) then money = nil end
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

            local gains, gainsCurrent = {}, portraitCardCurrent
            if validXP then gains[#gains + 1] = addon.L("REWARD_XP", xp) end
            if money then
                local currencyRoot, legacy, checker = C_CurrencyInfo, GetCoinTextureString, issecretvalue
                local currency = addon.Clean(currencyRoot, "table")
                local native = currency and rawget(currency, "GetCoinTextureString")
                local database, localize, localeGetter = addon.db, addon.L, GetLocale
                local locale = database and rawget(database, "locale")
                local gameLocale = addon.Read(localeGetter, "string")
                local function moneyCurrent()
                    local language = addon.Read(localeGetter, "string")
                    local ok, same = pcall(function()
                        return portraitCardCurrent() and addon.quests[id] == definition and rewards.money == money and
                            C_CurrencyInfo == currencyRoot and GetCoinTextureString == legacy and issecretvalue == checker and
                            (not currency or rawget(currency, "GetCoinTextureString") == native) and
                            addon.db == database and (not database or rawget(database, "locale") == locale) and
                            addon.L == localize and GetLocale == localeGetter and language == gameLocale
                    end)
                    return ok and same == true
                end
                if not moneyCurrent() then return end
                local formatted = addon.Read(native, "string", money)
                if not moneyCurrent() then return end
                if not formatted or #formatted > 4096 or not formatted:find("%S") then formatted = addon.Read(legacy, "string", money) end
                if not moneyCurrent() then return end
                if not formatted or #formatted > 4096 or not formatted:find("%S") then formatted = addon.Read(localize, "string", "MONEY_COPPER", money) end
                if not moneyCurrent() then return end
                local heading = addon.Read(localize, "string", "REWARD_MONEY")
                if not moneyCurrent() then return end
                if formatted and heading then gains[#gains + 1] = heading .. ": " .. formatted end
                gainsCurrent = moneyCurrent
            end
            if #gains > 0 and line(table.concat(gains, " · "), "caption", nil, nil, gainsCurrent) == false then return end
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
        end
        local function acquisitionItems(summary)
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
        if not summary then
        if q.startAlternatives and start then
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
            local heading = previewCount == 0 and "START_ALTERNATIVES" or nil
            if #remaining > 0 and alternativePlaces(remaining, self.startButtons, heading, "startAlternative:", alternativesCurrent) == false then return end
        elseif not q.startAlternatives then
            if typedStarter and not starterCurrent() then return end
            local starting = place(q.start)
            if not starting or (typedStarter and not starterCurrent()) then return end
            if reported(q.start, "start") == false then return end
        end
        local start = q.start
        if start and start.itemID then
            local count = typedStarter and starterCount or nil
            if not typedStarter then count = carried(start.itemID) end
            if typedStarter and not starterCurrent() then return end
            if count and not typedStarter then line(count) end
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
        end
        if typedStarter then
            -- Route facts remain separate from the item that starts the quest.
            local routes, snapshots, mappedDrops = {}, {}, {}
            local nameProofs = {}
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
                if not starterCurrent() or not namesCurrent(nameProofs) then return false end
                local ok, same = pcall(function()
                    if C_Map ~= mapNamespace or (mapNamespace and mapNamespace.GetMapInfo ~= mapGetter) or
                        addon.GiverName ~= giverGetter or addon.DungeonName ~= dungeonGetter or addon.SourceAreaName ~= sourceAreaGetter then return false end
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
                local name = giverName({ npcID = dropID, name = addon.Clean(starterSource.dropName, "string") or ("#" .. dropID) }, acquisitionCurrent, nameProofs)
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
                            name = giverName(drop, acquisitionCurrent, nameProofs)
                            if not acquisitionCurrent() then return end
                            location = areaName(location, acquisitionCurrent, nameProofs) or location
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
            if #routes > 0 and not summary then
                sourceFocusOffset, sourceFocusCurrent = y, acquisitionCurrent
                if line(addon.L("ITEM_ACQUISITION"), "caption",nil,nil,acquisitionCurrent) == false then return end
            elseif #routes == 0 and (rawget(starterSource, "containerSource") ~= nil or rawget(starterSource, "dropNPCID") ~= nil or rawget(starterSource, "dropSources") ~= nil) then
                if line(addon.L("START_ITEM_LOCATION_UNKNOWN"), "warning",nil,nil,acquisitionCurrent) == false then return end
            end
            local multipleSummary = summary and #routes > 1
            if multipleSummary then
                local text = addon.Read(addon.L,"string","ITEM_SOURCE_SUMMARY",#routes,addon.L("TAB_SOURCES"))
                if not acquisitionCurrent() or not text or line(text,"caption",nil,nil,acquisitionCurrent) == false then return end
            end
            for _, route in ipairs(routes) do
                if multipleSummary then
                    if route.container then
                        local container = route.container
                        local map, x, gy = addon.Clean(container.mapID,"number"), addon.Clean(container.x,"number"), addon.Clean(container.y,"number")
                        if not acquisitionCurrent() then return end
                        if not map or not x or not gy or x < 0 or x > 100 or gy < 0 or gy > 100 then
                            local text = addon.Read(place,"string",container,acquisitionCurrent,nameProofs)
                            if not acquisitionCurrent() or (text and line(text,"caption",nil,nil,acquisitionCurrent) == false) or
                                line(addon.L("SOURCE_POSITION_UNKNOWN"),"warning",nil,nil,acquisitionCurrent) == false then return end
                        end
                    end
                elseif summary and route.container then
                    local container = route.container
                    local text = addon.Read(place,"string",container,acquisitionCurrent,nameProofs)
                    local map, x, gy = addon.Clean(container.mapID,"number"), addon.Clean(container.x,"number"), addon.Clean(container.y,"number")
                    if not acquisitionCurrent() then return end
                    if text and line(text,"caption",nil,nil,acquisitionCurrent) == false then return end
                    if not map or not x or not gy or x < 0 or x > 100 or gy < 0 or gy > 100 then
                        if line(addon.L("SOURCE_POSITION_UNKNOWN"),"warning",nil,nil,acquisitionCurrent) == false then return end
                    end
                elseif route.container then
                    if alternativePlaces({ route.container }, self.containerButtons, "CONTAINER_SOURCE", "container:", acquisitionCurrent, nil, nil, nil, true) == false then return end
                elseif line(route.text, summary and "caption" or nil, nil, nil, acquisitionCurrent) == false then return end
                if not acquisitionCurrent() then return end
            end
            if not summary and #mappedDrops > 0 and alternativePlaces(mappedDrops, self.dropButtons, "ITEM_DROP_LOCATIONS", "dropSource:", acquisitionCurrent) == false then return end
        end
        if summary then return true end
        if q.finishAlternatives then
            local finishes = q.finishAlternatives
            local function finishesCurrent()
                return portraitCardCurrent() and addon.quests[id] == definition and q.finishAlternatives == finishes
            end
            if alternativePlaces(finishes, self.finishButtons, "POSSIBLE_TURNINS", "finishAlternative:", finishesCurrent) == false then return end
        elseif q.finish and q.finish ~= q.start then
            local starting = not q.startAlternatives and reportedPlaces(q.start)
            local ending = reportedPlaces(q.finish)
            if not locationCurrent() then return end
            local repeated = starting and ending and #starting == #ending
            if repeated then
                for index, point in ipairs(starting) do
                    for _, field in ipairs({ "npcID", "objectID", "name", "mapID", "x", "y", "zoneName" }) do
                        if point[field] ~= ending[index][field] then repeated = false; break end
                    end
                    if not repeated then break end
                end
            end
            if not repeated and reported(q.finish, "finish") == false then return end
        end
        local materialSource, materialGetter = q.completionQuests, engine.CompletionSteps
        local materialRows, materialCount = addon.Clean(materialSource,"table"), 0
        local materialSnapshots = {}
        if materialRows then
            materialCount = #materialRows
            if materialCount > 100 then return end
            for index = 1, materialCount do
                local entry = addon.Clean(rawget(materialRows,index),"table")
                if not entry then return end
                local sourceID, sourceItem = addon.Clean(rawget(entry,"id"),"number"), addon.Clean(rawget(entry,"itemID"),"number")
                if not sourceID or sourceID <= 0 or sourceID % 1 ~= 0 or not sourceItem or sourceItem <= 0 or sourceItem % 1 ~= 0 then return end
                materialSnapshots[index] = { entry = entry, id = rawget(entry,"id"), itemID = rawget(entry,"itemID"), questID = sourceID, item = sourceItem }
            end
        end
        local nameGetter, itemGetter, countGetter, localize = addon.QuestName, addon.ItemName, addon.CarriedItemCount, addon.L
        local database, engineGetter, inspector, materialFrame = addon.db, engine.Current, self.InspectQuest, self.frame
        local locale = database and rawget(database,"locale")
        local function materialCurrent()
            if not current() or not portraitCardCurrent() then return false end
            local ok, same = pcall(function()
                if addon.UI ~= self or self.frame ~= materialFrame or self.InspectQuest ~= inspector or addon.quests[id] ~= definition or q.completionQuests ~= materialSource or engine.CompletionSteps ~= materialGetter or
                    engine.Current ~= engineGetter or addon.QuestName ~= nameGetter or addon.ItemName ~= itemGetter or addon.CarriedItemCount ~= countGetter or
                    addon.L ~= localize or addon.db ~= database or (database and rawget(database,"locale") ~= locale) or
                    (materialRows and #materialRows ~= materialCount) then return false end
                for index, source in ipairs(materialSnapshots) do
                    if rawget(materialRows,index) ~= source.entry or not rawequal(rawget(source.entry,"id"),source.id) or
                        not rawequal(rawget(source.entry,"itemID"),source.itemID) then return false end
                end
                return true
            end)
            return ok and same == true
        end
        local materials = addon.Read(materialGetter, "table", engine, id)
        if not materialCurrent() then return end
        if materials and #materials > 0 then
            if line(addon.L("MATERIAL_QUESTS"), "section",nil,nil,materialCurrent) == false or
                line(addon.L("MATERIAL_NOTICE"),nil,nil,nil,materialCurrent) == false then return end
            local buttons = self.materialButtons
            for index, entry in ipairs(materials) do
                local other, itemID = addon.Clean(entry.id,"number"), addon.Clean(entry.itemID,"number")
                local state = addon.Clean(entry.state,"table")
                local status = state and addon.Clean(state.status,"string")
                if not other or other <= 0 or other % 1 ~= 0 or not itemID or itemID <= 0 or itemID % 1 ~= 0 or not COLOR[status] then return end
                local relation = false
                for _, source in ipairs(materialSnapshots) do if source.questID == other and source.item == itemID then relation = true; break end end
                if not relation then return end
                local otherDefinition, rawUnknown = addon.quests[other], rawget(entry,"unknown")
                local function entryCurrent()
                    return materialCurrent() and addon.quests[other] == otherDefinition and rawequal(rawget(entry,"id"),other) and
                        rawequal(rawget(entry,"itemID"),itemID) and rawequal(rawget(entry,"state"),state) and
                        rawequal(rawget(state,"status"),status) and rawequal(rawget(entry,"unknown"),rawUnknown)
                end
                local title = addon.Read(nameGetter,"string",other)
                if not entryCurrent() then return end
                local count = carried(itemID)
                if not entryCurrent() then return end
                local itemName = addon.Read(itemGetter, "string", itemID) or addon.L("MATERIAL_ITEM", itemID)
                if not entryCurrent() then return end
                local note = "|cff" .. COLOR[status] .. statusLabel(state) .. "|r\n" .. itemName ..
                    (addon.Clean(rawUnknown,"boolean") == true and status ~= "UNKNOWN" and (" — " .. addon.L("UNKNOWN")) or "") ..
                    (count and ("\n" .. count) or "")
                local row = self:MakeRow(self.detail, buttons, index, 59, entryCurrent, true)
                if not entryCurrent() then return end
                row.questID, row.itemID = other, itemID
                local function rowCurrent()
                    return entryCurrent() and self.materialButtons == buttons and buttons[index] == row and row.questID == other and row.itemID == itemID
                end
                local function write(object,method,...)return self:QuestListWrite(object,method,rowCurrent,...)end
                if not write(row.title,"SetText",title) or not write(row.note,"SetText",note) or not write(row,"SetEnabled",true) or
                    not write(row,"SetScript","OnClick",function()
                        if rowCurrent() and addon.Read(materialFrame.IsShown,"boolean",materialFrame) == true and rowCurrent() then inspector(self,other) end
                    end) then return end
                local nextY = self:LayoutRow(row,59,y,rowCurrent,write)
                if not nextY or not write(row,"Show") then return end
                y = nextY
            end
        end
        return true
        end
        if detailTab == "quest" then
            if not acquisitionPortraits(false) then return end
            if itemStarter and not acquisitionItems(true) then return end
        elseif detailTab == "sources" then
            if not acquisitionPortraits(true) or not acquisitionObjectives() or not acquisitionItems() then return end
        else
            local getter, localize, checker, database = addon.Description, addon.L, issecretvalue, addon.db
            local locale = database and rawget(database,"locale")
            local function current()
                return portraitCardCurrent() and addon.quests[id] == definition and addon.Description == getter and addon.L == localize and
                    issecretvalue == checker and addon.db == database and (not database or rawget(database,"locale") == locale)
            end
            local text = addon.Read(getter,"string",id)
            local placeholder = addon.Read(localize,"string","NO_TEXT")
            if not current() then return end
            if not text or #text > 30000 or not text:find("%S") or text == placeholder then
                text = addon.Read(localize,"string","DETAIL_STORY_UNAVAILABLE")
            end
            if not current() or not text or line(text,"story",nil,nil,current) == false then return end
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
            local offset = self:RenderPreparationOverview(portraitCardCurrent, contentWidth, y,
                { label = label, setFont = setFont, measuredHeight = measuredHeight, styles = DETAIL_STYLES })
            if not offset then return end
            y = offset
            local control, opener = self.overviewMapControl, self.OpenDungeonMap
            local gameMap = addon.Clean(renderDungeon.instanceID, "number")
            if control and type(opener) == "function" and gameMap and gameMap > 0 and gameMap <= 4294967295 and gameMap % 1 == 0 then
                local binding = { owner = portraitCardCurrent }
                self.overviewMapBinding = binding
                local function current()
                    return not binding.released and binding.owner and binding.owner() and addon.UI == self and self.overviewMapBinding == binding and
                        self.overviewMapControl == control and self.OpenDungeonMap == opener and
                        rawequal(rawget(renderDungeon, "instanceID"), gameMap)
                end
                local mapLabel = addon.L("DUNGEON_MAP_OPEN")
                if not current() then return end
                setFont(control.filterCaption, 15)
                if not current() or not self:QuestListWrite(control.filterCaption, "SetText", current, mapLabel) or
                    not self:QuestListWrite(control, "ClearAllPoints", current) or
                    not self:QuestListWrite(control, "SetPoint", current, "TOPLEFT", 4, -y) or
                    not self:QuestListWrite(control, "SetWidth", current, contentWidth) or
                    not self:QuestListWrite(control.filterCaption, "SetWidth", current, contentWidth - 16) or
                    not self:QuestListWrite(control, "SetEnabled", current, true) or
                    not self:QuestListWrite(control, "SetScript", current, "OnClick", function()
                        if current() and addon.Read(control.IsShown, "boolean", control) == true and current() then
                            opener(self, renderDungeon)
                        end
                    end) or not self:QuestListWrite(control, "Show", current) then return end
                y = y + 38
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
            local plan, preparation = self.currentPlan, self.preparation
            local countOwned = plan and plan.engine == renderEngine and plan.dungeon == renderDungeon and
                plan.includeUnavailable == renderIncludeUnavailable
            local count, countProof
            if countOwned then
                local view = self.catalogLanguageView
                if view and view.current() then
                    for _, result in ipairs(view.results) do
                        if result.dungeon == renderDungeon and result.statusCurrent and result.statusCurrent() then
                            count, countProof = result.count, result.statusCurrent
                            break
                        end
                    end
                end
                if not countProof then
                    local provider = addon.Clean(addon.DungeonStatus, "table")
                    local getter = provider and addon.Clean(provider.Get, "function")
                    local dto, proof
                    if getter then
                        local ok; ok, dto, proof = pcall(getter, renderDungeon, renderEngine)
                        if ok and addon.Clean(dto, "table") and addon.Clean(proof, "function") then
                            count = renderIncludeUnavailable == true and dto.listedRoots or dto.characterRoots
                            countProof = proof
                        end
                    end
                end
            end
            if count ~= nil and countProof then
                local function countCurrent()
                    return portraitCardCurrent() and self.currentPlan == plan and addon.Read(countProof, "boolean") == true
                end
                if not countCurrent() or line(addon.L("CATALOG_QUESTS", count), nil, nil, nil, countCurrent) == false then return end
                if count == 0 then
                    local roots = addon.Clean(renderDungeon.quests, "table")
                    local emptyKey = renderIncludeUnavailable ~= true and roots and #roots > 0 and "NO_CHARACTER_QUESTS" or "EMPTY"
                    if line(addon.L(emptyKey), nil, nil, nil, countCurrent) == false then return end
                end
            end
            local function promptCurrent()
                return portraitCardCurrent() and self.currentPlan == plan and self.preparation == preparation
            end
            local ownedPlan = plan and plan.engine == renderEngine and plan.dungeon == renderDungeon
            local emptyPreparation = preparation and ownedPlan and plan.preparationEmpty == true and #plan.rows > 0
            if count and count > 0 then
                local prompt = emptyPreparation and addon.L("PREPARATION_EMPTY", addon.L("QUESTS")) or
                    addon.L(ownedPlan and #plan.rows == 0 and "NO_CHARACTER_QUESTS" or "OVERVIEW_PICK")
                if not promptCurrent() or line(prompt, nil, nil, nil, promptCurrent) == false then return end
            end
        else line(addon.L("PICK")) end
    end
    if renderQuest and self.copyQuest == renderQuest and self.copy then
        local box, hint, revision = self.copy, self.copyHint, self.copyRevision
        local function copyCurrent()
            return portraitCardCurrent() and self.copy == box and self.copyHint == hint and self.copyQuest == renderQuest and self.copyRevision == revision
        end
        local function copyWrite(object, method, ...) return self:QuestListWrite(object, method, copyCurrent, ...) end
        local textGetter = box.GetText
        local value = addon.Read(textGetter, "string", box)
        if not copyCurrent() or box.GetText ~= textGetter or not value then return end
        if not copyWrite(box, "SetText", value) then return end
        box:ClearAllPoints()
        if not copyCurrent() then return end
        box:SetPoint("TOPLEFT", 8, -(y + 6))
        if not copyCurrent() then return end
        setFont(hint, 13)
        if not copyCurrent() then return end
        local text = addon.L("COPY")
        if not copyCurrent() or not copyWrite(hint, "SetText", text) or not copyWrite(hint, "Show") or not copyWrite(box, "Show") then return end
        y = y + 6 + 26 + 8 + measuredHeight(hint, 18) + 8
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
        if not primaryCurrent() then return end
        self.giverAction, self.giverHasCoordinates = pendingGiver.action, pendingGiver.coordinates
        local binding = { action = pendingGiver.action }
        binding.current = sourceCallback(function()
            if not primaryCurrent() then return false end
            local fresh = not renderEngine.Current or addon.Read(renderEngine.Current, "boolean", renderEngine) == true
            return fresh and primaryCurrent() and pendingGiver.same() and addon.UI == self and self.giverBinding == binding
                and self.giverAction == binding.action and addon.quests[renderQuest] == pendingGiver.source
                and pendingGiver.source.start == giverPlace and addon.Clean(giverPlace.mapID, "number") == pendingGiver.map
                and addon.Clean(giverPlace.x, "number") == pendingGiver.x and addon.Clean(giverPlace.y, "number") == pendingGiver.y and primaryCurrent()
        end)
        self.giverBinding = binding
        if not primaryLabel(pendingGiver.coordinates and "VISIT_GIVER" or "GIVER_MAP", binding.current) or
            not primaryEnabled(true, binding.current) then return end
    end
    if pendingTurnin and pendingTurnin.current() and pendingAction and pendingAction.kind == "turnin" and
        pendingAction.id == renderQuest and pendingAction.place == pendingTurnin.place then
        local control, action, dispatch = self.turnin, pendingAction, self.DispatchDetail
        local navigationRoot = addon.Navigation
        local navigation = addon.Clean(navigationRoot, "table")
        local key = pendingTurnin.coordinates and "Start" or "Map"
        local rawMethod = navigation and rawget(navigation, key)
        local method = addon.Clean(rawMethod, "function")
        if method and pendingTurnin.current() and portraitCardCurrent() then
            local binding = { action = action, coordinates = pendingTurnin.coordinates }
            binding.current = function()
                return pendingTurnin.current() and portraitCardCurrent() and addon.UI == self and self.turnin == control and
                    self.turninBinding == binding and binding.action == action and self.action == action and action.id == renderQuest and
                    action.kind == "turnin" and action.place == pendingTurnin.place and binding.coordinates == pendingTurnin.coordinates and
                    self.DispatchDetail == dispatch and addon.Navigation == navigationRoot and navigationRoot == navigation and rawget(navigation, key) == rawMethod
            end
            self.turninBinding = binding
            control.footerEnabled = true
            self:RefreshFooterIcon(control)
            if not binding.current() or not self:QuestListWrite(control, "SetEnabled", binding.current, true) or
                not self:QuestListWrite(control, "SetScript", binding.current, "OnClick", function()
                    if addon.Read(control.IsShown, "boolean", control) ~= true or not binding.current() then return end
                    dispatch(self, action, not binding.coordinates, false, binding.current)
                end) then return end
        end
    end
    if not portraitCardCurrent() then return end
    if sourceFocus == true then
        local scroll = self.detailScroll
        local viewport = addon.Read(scroll.GetHeight, "number", scroll)
        local function focusCurrent()
            return portraitCardCurrent() and self.detailScroll == scroll and
                (not sourceFocusCurrent or sourceFocusCurrent())
        end
        if not focusCurrent() then return end
        if viewport and viewport > 0 and not self:WriteDetailScroll(scroll,
            math.min(sourceFocusOffset, math.max(0, y + 12 - viewport)), focusCurrent) then return end
    end
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
    for _, control in ipairs({ rangeControl, characterControl }) do
        control:SetScript("OnEnter", function() self:FilterHint(control) end)
        control:SetScript("OnLeave", function() self:HideNavigationHint(control) end)
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
        control:SetScript("OnLeave", function() if type(icon.SetAlpha) == "function" then icon:SetAlpha(.76) end; self:HideNavigationHint(control) end)
        if type(icon.SetAlpha) == "function" then icon:SetAlpha(.76) end
    end
    self.heading = label(frame, "", 278, -66, 226, 26)
    self.questEntrance = button(frame, "", 28, nil)
    self.questEntrance:SetSize(28, 28); self.questEntrance:SetPoint("TOPLEFT", 510, -66)
    self.questEntrance.entranceControl = self.questEntrance
    if type(self.questEntrance.SetMotionScriptsWhileDisabled) == "function" then self.questEntrance:SetMotionScriptsWhileDisabled(true) end
    self.questEntrance.footerIcon = self.questEntrance:CreateTexture(nil, "ARTWORK")
    self.questEntrance.footerIcon:SetSize(20, 20); self.questEntrance.footerIcon:SetPoint("CENTER", self.questEntrance, "CENTER", 0, 0)
    self.questEntrance.footerIcon:SetTexture("Interface\\Icons\\INV_Misc_Map_01"); self.questEntrance.footerIcon:Show()
    self.questEntrance:SetScript("OnEnter", function() self:CatalogEntranceHint(self.questEntrance) end)
    local function leaveQuestEntrance()
        if self.navigationTooltip and self.navigationTooltip.button == self.questEntrance then self:HideNavigationHint() end
    end
    self.questEntrance:SetScript("OnLeave", leaveQuestEntrance); self.questEntrance:SetScript("OnHide", leaveQuestEntrance)
    self.catalog, self.catalogScroll = scrolling(frame, 12, -66, 238, 622)
    self.searchHint = label(self.catalog, "", 4, 0, 202, 13)
    self.catalogNotice = label(self.catalog, "", 4, 0, 202, 13)
    self.questList, self.questScroll = scrolling(frame, 278, -100, 370, 588)
    self.detail, self.detailScroll = scrolling(frame, 674, -66, 400, 622)
    self.overviewMapControl = button(self.detail, "", 392, nil)
    self.overviewMapControl:SetHeight(32)
    self.overviewMapControl.filterCaption = label(self.overviewMapControl, "", 8, -6, 376, 15)
    self.overviewMapControl:Hide()
    if addon.Theme and addon.Theme.StyleFilter then addon.Theme.StyleFilter(self.overviewMapControl, false) end
    self.source = button(self.detail, "", 32, function() if self.quest then self:CopyLink(self.quest) end end)
    self.source:SetPoint("TOPRIGHT", self.detail, "TOPRIGHT", -4, 0)
    self.giver = button(self.detail, "", 32, function()
        if self.giverAction then
            self:DispatchDetail(self.giverAction, not self.giverHasCoordinates, true)
        end
    end)
    self.turnin = button(self.detail, "", 24, function() end)
    self:SetFooterLabel(self.turnin, "VISIT_TURNIN")
    self.turnin:Hide(); self.turnin:SetEnabled(false)
    self.giver:SetPoint("TOPLEFT", self.detail, "TOPLEFT", 4, -80)
    for _, control in ipairs({ self.giver, self.source, self.turnin }) do
        control:SetHeight(32)
        if type(control.SetMotionScriptsWhileDisabled) == "function" then pcall(control.SetMotionScriptsWhileDisabled, control, true) end
        local icon
        if control == self.giver or control == self.turnin then icon = self:CreateGoldNavigationIcon(control)
        else
            icon = control:CreateTexture(nil, "ARTWORK")
            icon:SetSize(24, 24); icon:SetPoint("CENTER", control, "CENTER", 0, 0)
            icon:SetTexture("Interface\\AddOns\\DungeonPro\\Media\\Icons\\Wowhead")
            icon:SetTexCoord(0, .75, 0, .75); icon:Show()
        end
        control.footerIcon = icon
        control:SetScript("OnMouseDown", function(_, mouse) if mouse == "LeftButton" then control.footerPressed = true; self:RefreshFooterIcon(control) end end)
        control:SetScript("OnMouseUp", function() control.footerPressed = false; self:RefreshFooterIcon(control) end)
        control:SetScript("OnHide", function() control.footerHovered, control.footerPressed = false, false; self:RefreshFooterIcon(control); self:HideNavigationHint(control) end)
    end
    self:SetFooterLabel(self.source, "SOURCE"); self:SetFooterLabel(self.giver, "VISIT_GIVER")
    self.catalogCollapsed, self.layoutRevision = false, {}
    local catalogToggle
    catalogToggle = button(frame,"",24,function()
        if addon.UI == self and self.frame == frame and self.catalogToggle == catalogToggle then
            self:SetCatalogCollapsed(not self.catalogCollapsed)
        end
    end)
    self.catalogToggle = catalogToggle
    catalogToggle:SetSize(24,24)
    catalogToggle.label = label(catalogToggle,"",2,-1,20,20)
    styleRow(catalogToggle,"control",false)
    catalogToggle.label:SetJustifyH("CENTER")
    catalogToggle.label:SetTextColor(1,.78,.15)
    if not self:ApplyColumns() then return end
    local function navigationHint(control, destination, bodyKey)
        control:SetScript("OnEnter", function()
            local isCatalogToggle, revision = control == self.catalogToggle, self.layoutRevision
            local resolvedBodyKey = bodyKey == true and control.footerLabelKey or bodyKey
            local isTurnin = control == self.turnin
            local turninBinding = isTurnin and self.turninBinding
            if control.footerIcon then control.footerHovered = true; self:RefreshFooterIcon(control) end
            self:HideNavigationHint()
            local quest, dungeon, generation = self.quest, self.dungeon, self.rewardGeneration
            local areaGetter, sourceGetter, localize, database = addon.SourceAreaName, addon.SourceName, addon.L, addon.db
            local nameProofs = {}
            local locale = database and rawget(database, "locale")
            local tip = addon.Clean(GameTooltip, "table") or addon.Clean(GameTooltip, "userdata")
            local function current()
                local shown = addon.Read(frame.IsShown, "boolean", frame)
                for _, proof in ipairs(nameProofs) do if addon.Read(proof, "boolean") ~= true then return false end end
                local turninCurrent = not isTurnin or (self.turnin == control and turninBinding and self.turninBinding == turninBinding and
                    addon.Read(turninBinding.current, "boolean") == true)
                return (not isCatalogToggle or (self.catalogToggle == control and self.layoutRevision == revision)) and turninCurrent and addon.UI == self and self.frame == frame and self.quest == quest and self.dungeon == dungeon and
                    self.rewardGeneration == generation and addon.SourceAreaName == areaGetter and addon.SourceName == sourceGetter and addon.L == localize and addon.db == database and
                    (not database or rawget(database, "locale") == locale) and GameTooltip == tip and shown == true
            end
            local point = destination and destination()
            local reason = not point and control == self.giver and self.quest and self.giverUnavailableKey
            if not tip or (not point and not resolvedBodyKey and not reason) or not current() then return end
            local text = (resolvedBodyKey or reason) and addon.L(resolvedBodyKey or reason) or addon.Read(giverName, "string", point, current, nameProofs)
            local canonical = point and addon.Clean(point.zoneName, "string")
            local zone
            if canonical and type(areaGetter) == "function" then
                local ok, label, proof = pcall(areaGetter, canonical, current)
                if not current() then return end
                proof = addon.Clean(proof, "function")
                if proof then
                    nameProofs[#nameProofs + 1] = proof
                    if addon.Read(proof, "boolean") ~= true or not current() then return end
                end
                if ok then zone = addon.Clean(label, "string") end
            end
            zone = zone or canonical
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
                if not fn or not pcall(fn, tip, unpack(call, 2)) then self:HideNavigationHint(held); return end
                if not current() or addon.Read(tip.IsOwned, "boolean", tip, control) ~= true or not current() then self:HideNavigationHint(held); return end
            end
            self:RetainNavigationHint(held, current)
        end)
        control:SetScript("OnLeave", function()
            if control.footerIcon then control.footerHovered, control.footerPressed = false, false; self:RefreshFooterIcon(control) end
            self:HideNavigationHint(control)
        end)
    end
    navigationHint(self.giver, function() local action = self:NavigationDestination(false); return action and action.place end)
    navigationHint(self.turnin, function() local binding = self.turninBinding; return binding and binding.current() and binding.action.place end)
    navigationHint(self.source, nil, "COPY")
    navigationHint(self.catalogToggle, nil, true)
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
    frame:SetScript("OnHide", function()
        self.detailTabQuest, self.detailTabRevision = nil, {}
        local revision, character, quest, dungeon, engine = self.detailTabRevision, addon.char, self.quest, self.dungeon, self.engine
        local clean, read, shown, checker = addon.Clean, addon.Read, frame.IsShown, issecretvalue
        local methodKeys = { "ReleasePreparationOverview", "CloseDungeonMap", "HideNavigationHint", "ResetQuestLogControl", "ResetHistoryReading", "ResetRewardPresentation", "CloseCopyLink" }
        local methods = {}
        for _, key in ipairs(methodKeys) do methods[key] = self[key] end
        local generation = self.rewardGeneration
        local function rawCurrent()
            for _, key in ipairs(methodKeys) do if self[key] ~= methods[key] then return false end end
            return addon.UI == self and self.frame == frame and self.detailTabRevision == revision and
                addon.char == character and self.quest == quest and self.dungeon == dungeon and self.engine == engine and
                self.rewardGeneration == generation and addon.Clean == clean and addon.Read == read and issecretvalue == checker and frame.IsShown == shown
        end
        local function current()
            if not rawCurrent() then return false end
            local visible = read(shown, "boolean", frame)
            return visible == false and rawCurrent()
        end
        -- Cleanup callbacks may reopen and render the planner; that newer view owns its state.
        if not current() then return end
        releaseSourceControls(self)
        releaseDetailText(self)
        self:ReleasePreparationOverview()
        if not current() then return end
        local previousMap = self.overviewMapBinding
        self.overviewMapBinding = nil
        if previousMap then previousMap.released, previousMap.owner = true, nil end
        if self.CloseDungeonMap then self:CloseDungeonMap(true); if not current() then return end end
        local pending = self.developerLinkRequest
        self.developerLinkRequest = nil
        if pending and type(StaticPopup_Hide) == "function" then
            pcall(StaticPopup_Hide, "DUNGEONPRO_COPY_DEVELOPER_LINK")
            if not current() then return end
        end
        self:HideNavigationHint()
        if not current() then return end
        local language = clean(addon.Language, "table")
        if not current() then return end
        if language then
            read(language.Cancel, "boolean", language, self)
            if not current() then return end
        end
        self.pendingSearch = nil
        self.detailReferencesExpanded, self.detailNarrativeExpanded, self.detailObjectivesExpanded = false, false, false
        if not self:ResetQuestLogControl() or not current() then return end
        self.detailActionChoice = nil
        self.languageMenuRevision = {}
        self:ResetHistoryReading()
        if not current() then return end
        local reset = self:ResetRewardPresentation()
        if not reset then return end
        generation = reset
        if not current() then return end
        self:CloseCopyLink()
        if not current() then return end
    end)
    self:ApplyTheme()
    frame:Hide()
end

function UI:Toggle()
    if not self.frame then self:Create() end
    self.frame:SetShown(not self.frame:IsShown())
end
addon.listeners[#addon.listeners + 1] = function(reason) UI:Refresh(nil, reason == "data") end
