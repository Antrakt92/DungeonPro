local _, addon = ...
local UI = { dungeon = nil, quest = nil, search = "", range = false, preparation = false, includeUnavailable = false,
    detailHistory = {} }
addon.UI = UI
local COLOR = { COMPLETED = "66dd99", READY = "ffe066", ACTIVE = "88bfff", AVAILABLE = "ffe9b0",
    LOCKED = "f0b080", UNKNOWN = "b4aacd", UNAVAILABLE = "999999" }
local FONT
local DETAIL_STYLES = {
    body = { size = 14, minimum = 20, color = { 0.92, 0.91, 0.87 } },
    title = { size = 26, minimum = 34, color = { 0.96, 0.83, 0.59 } },
    section = { size = 20, minimum = 26, before = 8, color = { 0.76, 0.86, 0.85 } },
}

local function styleRow(row, kind, selected)
    local theme = addon.Clean(addon.Theme, "table")
    if theme then addon.Read(theme.StyleRow, "boolean", row, { kind = kind, selected = selected == true }) end
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

function UI:OpenLanguageMenu()
    local choices = { { "auto" }, { "enUS", "English" }, { "ruRU", "Русский" }, { "deDE", "Deutsch" },
        { "frFR", "Français" }, { "esES", "Español" }, { "itIT", "Italiano" }, { "ptBR", "Português" },
        { "koKR", "한국어" }, { "zhCN", "简体中文" }, { "zhTW", "繁體中文" } }
    local database, owner, checker = addon.Clean(addon.db, "table"), self.language, issecretvalue
    if not database then return false end
    local previous = addon.Clean(database.locale, "string")
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
            radio(root, name, function() return capable() and previous == code end, function()
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

function UI:ApplyTheme()
    local theme = addon.Clean(addon.Theme, "table")
    if theme then addon.Read(theme.Apply, "boolean", self) end
    styleRow(self.rangeButton, "control", self.range)
    styleRow(self.preparationButton, "control", self.preparation)
    styleRow(self.characterButton, "control", self.includeUnavailable)
end

function UI:RefreshQuestStyles()
    for _, row in ipairs(self.rows or {}) do
        if row:IsShown() then styleRow(row, row.heading and "section" or "quest", row.questID == self.quest and not row.heading) end
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

local function audienceLabel(q, current)
    q = addon.Clean(q, "table")
    if not q then return nil end
    local groups = {}
    for _, rule in ipairs({ { "factions", "string" }, { "classes", "string", addon.ClassName },
        { "races", "number", addon.RaceName } }) do
        local entries = addon.Clean(q[rule[1]], "table")
        local names, seen = {}, {}
        for index = 1, math.min(entries and #entries or 0, 100) do
            local value = addon.Clean(entries[index], rule[2])
            local valid = rule[1] == "factions" and (value == "Alliance" or value == "Horde" or value == "Neutral") or
                rule[1] == "classes" and value and #value <= 100 and value:match("^[A-Z]+$") or
                rule[1] == "races" and value and value > 0 and value <= 9007199254740991 and value % 1 == 0
            if valid and not seen[value] then
                seen[value] = true
                local name
                if rule[1] == "factions" then name = addon.L("FACTION_" .. value)
                else
                    name = addon.Read(rule[3], "string", value)
                    if not current() then return false end
                    if not name or #name > 500 or not name:find("%S") then
                        name = rule[1] == "races" and addon.L("RACE_ID", value) or value
                    end
                end
                names[#names + 1] = name
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
    if self.quest ~= id or self.copyQuest ~= id or addon.Read(self.copy.IsShown, "boolean", self.copy) ~= true then return false end
    local content = addon.Read(self.detail.GetHeight, "number", self.detail)
    local viewport = addon.Read(self.detailScroll.GetHeight, "number", self.detailScroll)
    if content and viewport and content >= 0 and viewport > 0 then self.detailScroll:SetVerticalScroll(math.max(0, content - viewport)) end
    if self.quest ~= id or self.copyQuest ~= id then return false end
    self.copy:SetFocus(); self.copy:HighlightText()
    return true
end

function UI:MakeRow(parent, pool, index, height)
    local row = pool[index]
    if not row then
        row = CreateFrame("Button", nil, parent)
        row:SetSize(parent:GetWidth() - 4, height)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.13, 0.16, 0.20, 1)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.title = label(row, "", 8, -7, parent:GetWidth() - 22, 16)
        row.note = label(row, "", 8, -29, parent:GetWidth() - 22, 13)
        pool[index] = row
    end
    row:Show()
    styleRow(row, "quest", false)
    return row
end

function UI:LayoutRow(row, minimum, offset)
    local left = row.art and 58 or 8
    local titleHeight = measuredHeight(row.title, 18)
    local noteHeight = row.heading and 0 or measuredHeight(row.note, 18)
    local height = math.max(minimum, 7 + titleHeight + (row.heading and 0 or 4) + noteHeight + 7)
    row.title:ClearAllPoints(); row.title:SetPoint("TOPLEFT", left, -7)
    row.note:ClearAllPoints(); row.note:SetPoint("TOPLEFT", left, -(7 + titleHeight + 4))
    row:SetHeight(height)
    row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -offset)
    return offset + height + 4
end

local function hideRest(pool, n)
    for i = n + 1, #pool do pool[i]:Hide() end
end

function UI:LoadFilters()
    local filters = addon.Clean(addon.char.filters, "table") or {}
    for _, key in ipairs({ "range", "preparation", "includeUnavailable" }) do
        self[key] = addon.Clean(filters[key], "boolean") == true
    end
end

function UI:SaveFilters()
    if not addon.Clean(addon.char.filters, "table") then addon.char.filters = {} end
    for _, key in ipairs({ "range", "preparation", "includeUnavailable" }) do
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

function UI:InspectQuest(id)
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

function UI:RefreshDungeons()
    local generation = {}
    self.catalogGeneration = generation
    local context = addon.Context()
    local query = (addon.Clean(self.search, "string") or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local needle = searchText(query)
    local n, offset = 0, 0
    self.searchPlaceholder:SetText(addon.L("SEARCH"))
    self.searchPlaceholder:SetShown(self.search == "")
    self.clearSearch:SetEnabled(self.search ~= "")
    self.searchHint:SetText(addon.L("SEARCH_HELP"))
    self.searchHint:SetShown(query ~= "")
    if query ~= "" then offset = measuredHeight(self.searchHint, 42) + 10 end
    self.catalogNotice:Hide()
    for _, d in ipairs(addon.dungeons) do
        local name = addon.DungeonName(d)
        local matches = query == "" or searchText(name):find(needle, 1, true) or searchText(d.name):find(needle, 1, true)
        if matches and (not self.range or (context.level and context.level >= d.minLevel - 3 and context.level <= d.maxLevel + 3)) then
            n = n + 1
            local row = self:MakeRow(self.catalog, self.cards, n, 64)
            if not row.art then
                row.art = row:CreateTexture(nil, "ARTWORK")
                row.art:SetSize(44, 44); row.art:SetPoint("TOPLEFT", 6, -9)
                row.title:ClearAllPoints(); row.title:SetPoint("TOPLEFT", 58, -7); row.title:SetWidth(158)
                row.note:ClearAllPoints(); row.note:SetPoint("TOPLEFT", 58, -42); row.note:SetWidth(158)
            end
            row.art:Hide()
            addon.Read(addon.PaintDungeonArt, "boolean", row.art, d)
            if self.catalogGeneration ~= generation then return end
            row.title:SetText(name)
            row.note:SetText(addon.L("CATALOG_LEVELS", d.minLevel, d.maxLevel) .. "\n" ..
                addon.L("CATALOG_QUESTS", #d.quests))
            row.bg:SetColorTexture(self.dungeon == d and 0.22 or 0.13, 0.19, 0.23, 1)
            styleRow(row, "dungeon", self.dungeon == d)
            row:SetScript("OnClick", function()
                self:ResetHistoryReading()
                self.detailHistory = {}
                self.dungeon, self.quest = d, nil
                addon.char.selectedDungeon = d.key
                self:Refresh()
            end)
            offset = self:LayoutRow(row, 64, offset)
        end
    end
    hideRest(self.cards, n)
    if n == 0 then
        self.catalogNotice:SetText(addon.L("NO_DUNGEONS"))
        self.catalogNotice:ClearAllPoints(); self.catalogNotice:SetPoint("TOPLEFT", 4, -offset)
        self.catalogNotice:Show(); offset = offset + measuredHeight(self.catalogNotice, 42) + 10
    end
    self.catalog:SetHeight(math.max(1, offset))
end

function UI:RefreshQuests()
    local d, character, previousGeneration = self.dungeon, addon.char, self.questListGeneration
    local preparation, includeUnavailable = self.preparation, self.includeUnavailable
    local context = addon.Context()
    if self.dungeon ~= d or addon.char ~= character or self.questListGeneration ~= previousGeneration then return end
    local engine = addon.Planner.New(addon.quests, context, addon.Clean(character.choices, "table"))
    self.engine = engine
    self.currentPlan = nil
    local generation = {}
    self.questListGeneration = generation
    local function current()
        return self.questListGeneration == generation and self.engine == engine and self.dungeon == d and addon.char == character and
            self.preparation == preparation and self.includeUnavailable == includeUnavailable
    end
    for _, row in ipairs(self.rows) do row:SetEnabled(false); row:SetScript("OnClick", nil) end
    local heading = d and addon.DungeonName(d) or addon.L("QUESTS")
    if not current() then return end
    self.heading:SetText(heading)
    local n, offset = 0, 0
    if d then
        local plan = engine:Dungeon(d, { includeUnavailable = self.includeUnavailable })
        if not current() then return end
        self.currentPlan = { engine = engine, dungeon = d, rows = plan.rows }
        self.summary:SetText(addon.L("SUMMARY", (plan.counts.ACTIVE or 0) + (plan.counts.READY or 0),
            plan.counts.COMPLETED or 0, (plan.counts.LOCKED or 0) + (plan.counts.AVAILABLE or 0), plan.counts.UNKNOWN or 0))
        self.coverage:SetText(plan.unknown and addon.L("PARTIAL") or addon.L(plan.ready and "PREPARED" or "NOT_PREPARED"))
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
        for _, entry in ipairs(entries) do
            local id, state = entry.id, entry.state
            local title, note
            if entry.heading then title, note = addon.L(entry.heading), ""
            else
                title = addon.QuestName(id)
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
            end
            if not current() then return end
            n = n + 1
            local row = self:MakeRow(self.questList, self.rows, n, 59)
            row.heading, row.questID = entry.heading, id
            row.title:SetText(title); row.note:SetText(note)
            row:SetEnabled(not entry.heading)
            if entry.heading then
                row.bg:SetColorTexture(0.20, 0.22, 0.26, 1)
                row:SetScript("OnClick", nil)
            else
                row.bg:SetColorTexture(0.13, 0.16, 0.20, 1)
                row:SetScript("OnClick", function() if current() then self:InspectQuest(id) end end)
            end
            styleRow(row, entry.heading and "section" or "quest", id == self.quest and not entry.heading)
            offset = self:LayoutRow(row, entry.heading and 32 or 59, offset)
            if not current() then return end
        end
        if #plan.rows == 0 then
            self.coverage:SetText(addon.L(#d.quests > 0 and "NO_CHARACTER_QUESTS" or "EMPTY"))
        end
    else
        self.summary:SetText(""); self.coverage:SetText(addon.L("PICK"))
    end
    local headingHeight = math.max(34, measuredHeight(self.heading, 34))
    local summaryY = 125 + headingHeight + 8
    local coverageY = summaryY + math.max(20, measuredHeight(self.summary, 20)) + 8
    local listY = math.max(218, coverageY + math.max(20, measuredHeight(self.coverage, 20)) + 12)
    if not current() then return end
    self.summary:ClearAllPoints(); self.summary:SetPoint("TOPLEFT", 288, -summaryY)
    self.coverage:ClearAllPoints(); self.coverage:SetPoint("TOPLEFT", 288, -coverageY)
    self.questScroll:ClearAllPoints(); self.questScroll:SetPoint("TOPLEFT", 288, -listY)
    self.questScroll:SetHeight(math.max(80, 643 - listY))
    hideRest(self.rows, n)
    self.questList:SetHeight(math.max(1, offset))
    local identity = d and (addon.Clean(d.key, "string") or d)
    if self.questListDungeon ~= identity then
        self.questListDungeon = identity
        self.questScroll:SetVerticalScroll(0)
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
    if owned ~= true or not current() then self:ReleaseObjectiveTooltip(held) end
end

function UI:RefreshDetail()
    local renderQuest, renderDungeon = self.quest, self.dungeon
    local renderEngine, renderCharacter, pendingAction, pendingGiver = self.engine, addon.char, nil, nil
    local rewardGeneration = self:ResetRewardPresentation()
    if not rewardGeneration or self.quest ~= renderQuest then return end
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
    self.reportedExpanded = self.reportedExpanded or {}
    self.reportedToggles, self.reportedRows = self.reportedToggles or {}, self.reportedRows or {}
    local reportedGeneration, toggleIndex, reportIndex = {}, 0, 0
    self.reportedGeneration = reportedGeneration
    for _, buttons in ipairs({ self.reportedToggles, self.reportedRows }) do
        for _, row in ipairs(buttons) do row:Hide(); row:SetEnabled(false); row:SetScript("OnClick", nil) end
    end
    self.back:SetEnabled(#self.detailHistory > 0 or self:CanReturnToOverview())
    local function portraitCardCurrent()
        return self.quest == renderQuest and self.dungeon == renderDungeon and self.engine == renderEngine and
            addon.char == renderCharacter and self.rewardGeneration == rewardGeneration
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
    self.map:SetEnabled(false); self.guide:SetEnabled(false)
    self.giverAction, self.giverHasCoordinates = nil, false
    self.giver:SetEnabled(false)
    self.giver:SetText(addon.L("VISIT_GIVER"))
    local rewardIndex, objectiveIndex = 0, 0
    local function line(value, style, reward, objective)
        style = DETAIL_STYLES[style] and style or "body"
        local format = DETAIL_STYLES[style]
        local height = format.minimum
        y = y + (format.before or 0)
        n = n + 1
        local fs = pool[n]
        if not fs then fs = label(self.detail, "", 4, 0, 334, 13); pool[n] = fs end
        local font = setFont(fs, format.size)
        if fs.detailStyle ~= style or fs.detailFont ~= font then fs.measuredHeight = nil end
        fs.detailStyle, fs.detailFont = style, font
        fs:SetTextColor(unpack(format.color))
        fs:SetWidth(334)
        fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 4, -y); fs:SetText(value); fs:Show()
        local itemID = reward and addon.Clean(reward.item.id, "number")
        local texture = reward and (addon.Clean(reward.item.texture, "string") or addon.Clean(reward.item.texture, "number"))
        local validTexture = type(texture) == "string" and texture ~= "" and #texture <= 1024 or
            type(texture) == "number" and texture > 0 and texture % 1 == 0
        if itemID and itemID > 0 and itemID % 1 == 0 and validTexture and rewardIndex < 200 and not self.rewardTextureBusy then
            rewardIndex = rewardIndex + 1
            local b = self.rewardButtons[rewardIndex]
            if not b then
                b = CreateFrame("Button", nil, self.detail); b:SetSize(24, 24)
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
                fs:SetWidth(304); fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 34, -y)
                height = math.max(height or 18, 24)
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
                fs:SetWidth(304); fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 34, -y)
                height = math.max(height or 18, 24)
            else
                button.icon:Hide(); self:SetRewardTexture(button.icon, nil)
                if self.rewardGeneration ~= rewardGeneration or self.quest ~= renderQuest or not objective.current() then return false end
            end
        end
        local measured = measuredHeight(fs, height or 18)
        y = y + math.max(height or 18, measured) + 8
        return true
    end
    for _, b in ipairs(self.chainButtons) do b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil) end
    for _, buttons in ipairs({ self.actionButtons, self.actionInspectButtons, self.preparationForButtons }) do
        for _, b in ipairs(buttons) do b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil) end
    end
    for _, b in ipairs(self.branchButtons) do b:Hide() end
    for _, b in ipairs(self.branchInspectButtons) do b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil) end
    for _, b in ipairs(self.requirementButtons) do b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil) end
    for _, b in ipairs(self.materialButtons) do b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil) end
    for _, buttons in ipairs({ self.startButtons, self.finishButtons, self.containerButtons }) do
        for _, b in ipairs(buttons) do
            b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil)
        end
    end
    local id, engine = self.quest, self.engine
    if id then
        local definition = addon.quests[id]
        local q = definition or {}
        line(addon.QuestName(id), "title")
        local state = engine:State(id)
        line("|cff" .. COLOR[state.status] .. statusLabel(state) .. "|r")
        local minimum = addon.Clean(q.minLevel, "number")
        if minimum and minimum > 0 and minimum % 1 == 0 then line(addon.L("QUEST_MIN_LEVEL", minimum)) end
        local factions = audienceLabel({ factions = q.factions }, function()
            return self.quest == renderQuest and self.dungeon == renderDungeon and self.rewardGeneration == rewardGeneration and addon.char == renderCharacter
        end)
        if factions == false then return end
        if factions then line(addon.L("QUEST_FACTIONS", factions)) end
        for _, rule in ipairs({ { "classes", "string", "QUEST_CLASSES", addon.ClassName },
            { "races", "number", "QUEST_RACES", addon.RaceName } }) do
            local entries = addon.Clean(q[rule[1]], "table")
            local names, seen = {}, {}
            for index = 1, math.min(entries and #entries or 0, 100) do
                local value = addon.Clean(entries[index], rule[2])
                local valid = rule[2] == "number" and value and value > 0 and value % 1 == 0 or
                    rule[2] == "string" and value and #value <= 100 and value:find("%S")
                if valid and not seen[value] then
                    seen[value] = true
                    local name = addon.Read(rule[4], "string", value)
                    if self.quest ~= renderQuest or self.rewardGeneration ~= rewardGeneration then return end
                    if not name or #name > 500 or not name:find("%S") then
                        name = rule[2] == "number" and addon.L("RACE_ID", value) or value
                    end
                    names[#names + 1] = name
                end
            end
            if #names > 0 then line(addon.L(rule[3], table.concat(names, ", "))) end
        end
        local offerGetter = addon.CurrentOffer
        local offer = addon.Read(offerGetter, "table", id)
        local offeredNow = offer and addon.Clean(offer.offeredNow, "boolean") == true
        if not portraitCardCurrent() or addon.quests[id] ~= definition or addon.CurrentOffer ~= offerGetter then return end
        if offeredNow then line(addon.L("OFFERED_NOW")) end
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
            texture:ClearAllPoints()
            self.portraitRenderBusy = true
            local rendered = pcall(setter, texture, displayID)
            self.portraitRenderBusy = nil
            if not portraitCardCurrent() or not current() then return false end
            if SetPortraitTextureFromCreatureDisplayID ~= setter then rendered = false end
            if rendered then
                line(caption)
                texture:SetPoint("TOPLEFT", 4, -y); texture:Show(); y = y + 64 + 8
            else
                self.portraitRenderBusy = true; pcall(texture.SetTexture, texture, nil); self.portraitRenderBusy = nil
                if not portraitCardCurrent() or not current() then return false end
            end
            return true
        end
        local dialoguePortrait, questPortrait = addon.DialoguePortrait, addon.QuestPortrait
        local portrait = addon.Read(dialoguePortrait, "table", id)
        if not portraitCardCurrent() then return end
        if not portrait then portrait = addon.Read(questPortrait, "table", id) end
        if not portraitCardCurrent() then return end
        local displayID = portrait and addon.Clean(portrait.hidden, "boolean") ~= true and addon.Clean(portrait.displayID, "number")
        if not renderPortrait("portrait", displayID, addon.L("QUEST_PORTRAIT"), function()
            return addon.DialoguePortrait == dialoguePortrait and addon.QuestPortrait == questPortrait and issecretvalue == portraitChecker
        end) then return end
        local start = addon.Clean(q.start, "table")
        local producer = addon.GiverPortrait
        local fieldTypes = { npcID = "number", objectID = "number", itemID = "number", dropNPCID = "number",
            creatureDisplayID = "number", portraitSource = "string", name = "string", mapID = "number", x = "number", y = "number", zoneName = "string" }
        local function sourceSnapshot()
            local values = {}
            for field, kind in pairs(fieldTypes) do
                local value = start and rawget(start, field)
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
            if not portraitCardCurrent() or addon.quests[id] ~= q or q.start ~= start or addon.GiverPortrait ~= producer or
                SetPortraitTextureFromCreatureDisplayID ~= portraitSetter or issecretvalue ~= portraitChecker then return false end
            local values = sourceSnapshot()
            if not sourceValues or not values then return false end
            for field in pairs(fieldTypes) do if sourceValues[field] ~= values[field] then return false end end
            return portraitCardCurrent()
        end
        if not portraitCardCurrent() then return end
        local npcID = sourceValues and sourceValues.npcID
        if npcID and npcID > 0 and npcID <= 4294967295 and npcID % 1 == 0 and
            not sourceValues.objectID and not sourceValues.itemID and not sourceValues.dropNPCID then
            local reference = addon.Read(producer, "table", start)
            if not sourceCurrent() then return end
            local referenceNPC = reference and addon.Clean(rawget(reference, "npcID"), "number")
            local referenceDisplay = reference and addon.Clean(rawget(reference, "displayID"), "number")
            local referenceSource = reference and addon.Clean(rawget(reference, "source"), "string")
            if referenceNPC == npcID and referenceDisplay == sourceValues.creatureDisplayID and
                referenceSource and referenceSource == sourceValues.portraitSource then
                local name = addon.Clean(rawget(reference, "name"), "string")
                if not name or #name > 1024 or not name:find("%S") then name = giverName(start) end
                if not sourceCurrent() then return end
                if not renderPortrait("giverPortrait", referenceDisplay, addon.L("GIVER_REFERENCE_PORTRAIT", name), sourceCurrent) then return end
            end
        end
        if addon.Clean(q.repeatable, "boolean") == true then line(addon.L("REPEATABLE")) end
        if state.reason then
            local reason = "REASON_" .. state.reason
            if state.reason == "requirements" and state.status == "UNKNOWN" then
                reason = "REASON_requirementsUnknown"
            end
            if state.reason == "level" then
                local required = addon.Clean(q.minLevel, "number")
                local current = addon.Clean(engine.context.level, "number")
                if required and current then line(addon.L("REASON_level_current", required, current))
                elseif required then line(addon.L("REASON_level", required)); line(addon.L("REASON_levelUnknown"))
                else line(addon.L("REASON_levelUnknown")) end
            else line(addon.L(reason)) end
        end
        local function locationCurrent()
            return self.quest == renderQuest and self.dungeon == renderDungeon and self.engine == renderEngine and
                addon.char == renderCharacter and self.rewardGeneration == rewardGeneration and self.reportedGeneration == reportedGeneration
        end
        local function reported(parent, key, ownerCurrent)
            local function current() return locationCurrent() and (not ownerCurrent or ownerCurrent()) end
            if not current() then return false end
            local places = reportedPlaces(parent)
            if not places then return end
            local parentName = giverName(parent)
            if not current() then return false end
            toggleIndex = toggleIndex + 1
            local toggle = self:MakeRow(self.detail, self.reportedToggles, toggleIndex, 40)
            toggle.locationKey, toggle.heading = key, true
            local expanded = self.reportedExpanded[key] == true
            toggle.title:SetText((expanded and "− " or "+ ") .. addon.L("REPORTED_POSITIONS", parentName, #places))
            toggle.note:SetText(""); toggle:SetEnabled(true)
            toggle:SetScript("OnClick", function()
                if not current() then return end
                self.reportedExpanded[key] = not expanded
                self:RefreshDetail()
            end)
            y = self:LayoutRow(toggle, 40, y)
            if not expanded then return end
            line(addon.L("REPORTED_NOTICE"))
            for _, destination in ipairs(places) do
                local point = destination
                local zone = addon.Read(C_Map and C_Map.GetMapInfo, "table", point.mapID)
                if not current() then return false end
                reportIndex = reportIndex + 1
                local row = self:MakeRow(self.detail, self.reportedRows, reportIndex, 59)
                row.locationKey, row.destination, row.heading = key, point, nil
                local zoneName = (zone and addon.Clean(zone.name, "string")) or point.zoneName or addon.L("UNKNOWN_PLACE")
                row.title:SetText(zoneName .. string.format(" (%.1f, %.1f)", point.x, point.y))
                row.note:SetText(addon.L("REPORTED_VISIT")); row:SetEnabled(true)
                row:SetScript("OnClick", function()
                    if current() then
                        addon.Navigation.Start({ id = id, kind = "visit", place = point })
                    end
                end)
                y = self:LayoutRow(row, 59, y)
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
            return name .. (zoneName and (" — " .. zoneName) or "") ..
                (p.x and string.format(" (%.1f, %.1f)", p.x, p.y) or "")
        end
        local function alternativePlaces(places, buttons, heading, slot, ownerCurrent)
            local function current() return locationCurrent() and (not ownerCurrent or ownerCurrent()) end
            if not current() then return false end
            line(addon.L(heading), "section")
            for index, possible in ipairs(places) do
                local destination = possible
                local title = giverName(destination)
                if not current() then return false end
                local mapID = addon.Clean(destination.mapID, "number")
                local validMap = mapID ~= nil and mapID > 0 and mapID % 1 == 0
                local zone = validMap and addon.Read(C_Map and C_Map.GetMapInfo, "table", mapID)
                if not current() then return false end
                local row = self:MakeRow(self.detail, buttons, index, 59)
                row.title:SetText(title)
                local x, py = addon.Clean(destination.x, "number"), addon.Clean(destination.y, "number")
                local coordinates = validMap and x ~= nil and py ~= nil and x >= 0 and x <= 100 and py >= 0 and py <= 100
                row.note:SetText(((zone and addon.Clean(zone.name, "string")) or
                    addon.Clean(destination.zoneName, "string") or destination.locationName or addon.L("UNKNOWN_PLACE")) ..
                    (coordinates and string.format(" (%.1f, %.1f)", x, py) or ""))
                row:SetEnabled(validMap)
                row:SetScript("OnClick", validMap and function()
                    if not current() then return end
                    local visit = { id = id, kind = "visit", place = destination }
                    if coordinates then addon.Navigation.Start(visit)
                    else addon.Navigation.Map(destination) end
                end or nil)
                y = self:LayoutRow(row, 59, y)
                if reported(destination, slot .. index, ownerCurrent) == false or not current() then return false end
            end
        end
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
            if alternativePlaces(q.startAlternatives, self.startButtons, "START_ALTERNATIVES", "startAlternative:") == false then return end
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
            if line(addon.L("START") .. ": " .. starting, nil, nil, starterBinding) == false then return end
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
                        names[#names + 1] = name and name ~= "" and #name <= 500 and name or token
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
            local routes, snapshots = {}, {}
            local function capture(object, fields, list)
                local values = {}
                for _, field in ipairs(fields) do values[field] = rawget(object, field) end
                snapshots[#snapshots + 1] = { object = object, values = values, fields = fields, length = list and #object or nil }
            end
            capture(starterSource, { "containerSource", "dropNPCID", "dropName", "dungeonKey", "dropSources" })
            local function acquisitionCurrent()
                if not starterCurrent() then return false end
                local ok, same = pcall(function()
                    for _, snapshot in ipairs(snapshots) do
                        if snapshot.length and #snapshot.object ~= snapshot.length then return false end
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
                        capture(drop, { "npcID", "name", "locationName" })
                        local name, location = addon.Clean(drop.name, "string"), addon.Clean(drop.locationName, "string")
                        if positive(drop.npcID) and name and name:find("%S") and location and location:find("%S") then
                            name = giverName(drop)
                            if not acquisitionCurrent() then return end
                            routes[#routes + 1] = { text = addon.L("ITEM_DROP_SOURCE", name, location) }
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
        end
        local map = start and addon.Clean(start.mapID, "number")
        if map and map > 0 then
            local x, gy = addon.Clean(start.x, "number"), addon.Clean(start.y, "number")
            pendingGiver = { action = { id = id, kind = "visit", place = start }, source = q, map = map, x = x, y = gy,
                coordinates = x ~= nil and gy ~= nil and x >= 0 and x <= 100 and gy >= 0 and gy <= 100 }
            if state.status ~= "AVAILABLE" then line(addon.L("LOCATION_ONLY")) end
        end
        if q.finishAlternatives then
            if alternativePlaces(q.finishAlternatives, self.finishButtons, "POSSIBLE_TURNINS", "finishAlternative:") == false then return end
        else
            local ending = place(q.finish)
            if not ending then return end
            line(addon.L("ENDING") .. ": " .. ending)
            if reported(q.finish, "finish") == false then return end
        end
        local actions, uncertain = engine:Next(id)
        line(addon.L("NEXT"), "section")
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
        local function actionText(candidate)
            local title = addon.QuestName(candidate.id)
            if not current() then return nil end
            return addon.L(candidate.kind) .. ": " .. title .. (candidate.level and (" (" .. candidate.level .. ")") or "")
        end
        if action then
            local title = actionText(action)
            if not title then return end
            line(title)
        else line(addon.L(state.status == "COMPLETED" and "COMPLETED" or "UNKNOWN")) end
        if uncertain then line(addon.L("UNKNOWN")) end
        pendingAction = action
        if #actions > 1 then
            local inspectIndex = 0
            for index, candidate in ipairs(actions) do
                local title = actionText(candidate)
                if not title then return end
                local description = candidate.place and place(candidate.place) or ""
                if not current() then return end
                local row = self:MakeRow(self.detail, self.actionButtons, index, 59)
                row.actionID, row.actionKind = candidate.id, candidate.kind
                row.title:SetText(candidate == action and addon.L("BRANCH_SELECTED", title) or title)
                row.note:SetText(description); row:SetEnabled(true)
                styleRow(row, "quest", candidate == action)
                local actionID, kind = candidate.id, candidate.kind
                row:SetScript("OnClick", function()
                    if not current() then return end
                    self.detailActionChoice = { quest = id, id = actionID, kind = kind, dungeon = renderDungeon, character = addon.char }
                    self:RefreshDetail()
                end)
                y = self:LayoutRow(row, 59, y)
                if actionID ~= id then
                    inspectIndex = inspectIndex + 1
                    local inspect = self.actionInspectButtons[inspectIndex]
                    if not inspect then
                        inspect = CreateFrame("Button", nil, self.detail)
                        inspect:SetWidth(316); inspect.label = label(inspect, "", 7, -5, 302, 14)
                        inspect:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                        self.actionInspectButtons[inspectIndex] = inspect
                    end
                    inspect.actionID = actionID; inspect.label:SetText(addon.L("BRANCH_INSPECT"))
                    local height = math.max(28, measuredHeight(inspect.label, 18) + 10)
                    inspect:SetHeight(height); inspect:ClearAllPoints(); inspect:SetPoint("TOPLEFT", 16, -y)
                    inspect:SetEnabled(true); styleRow(inspect, "control", false)
                    inspect:SetScript("OnClick", function() if current() then self:InspectQuest(actionID) end end)
                    inspect:Show(); y = y + height + 6
                end
            end
        end
        local plan = self.currentPlan
        if plan and plan.engine == engine and plan.dungeon == renderDungeon then
            local related, seen = {}, {}
            for index = 1, math.min(#plan.rows, 100) do
                local entry = plan.rows[index]
                local targetID = addon.Clean(entry.id, "number")
                if targetID and targetID > 0 and targetID % 1 == 0 and targetID ~= id and not seen[targetID] then
                    seen[targetID] = true
                    local nextActions = engine:Next(targetID)
                    if not current() or self.currentPlan ~= plan then return end
                    for _, nextAction in ipairs(nextActions) do
                        if nextAction.id == id then related[#related + 1] = targetID; break end
                    end
                end
            end
            if #related > 0 then
                line(addon.L("PREPARATION_FOR"), "section")
                line(addon.L("PREPARATION_FOR_NOTICE"))
                for index, targetID in ipairs(related) do
                    local targetName = addon.QuestName(targetID)
                    local targetState = engine:State(targetID)
                    if not current() or self.currentPlan ~= plan then return end
                    local row = self:MakeRow(self.detail, self.preparationForButtons, index, 59)
                    row.questID = targetID
                    row.title:SetText(targetName)
                    row.note:SetText("|cff" .. COLOR[targetState.status] .. statusLabel(targetState) .. "|r")
                    row:SetEnabled(true); styleRow(row, "quest", false)
                    local other = targetID
                    row:SetScript("OnClick", function()
                        if current() and self.currentPlan == plan then self:InspectQuest(other) end
                    end)
                    y = self:LayoutRow(row, 59, y)
                end
            end
        end
        local branchIndex, branchInspectIndex = 0, 0
        local requirementIndex = 0
        if q.requires and #q.requires > 0 then
            line(addon.L("REQUIREMENT_GROUPS"), "section")
            line(addon.L("REQUIREMENT_NOTICE"))
        end
        for groupIndex, group in ipairs(q.requires or {}) do
            line(addon.L("REQUIREMENT_GROUP", groupIndex), "section")
            line(addon.L(group.mode == "active" and "REQUIREMENT_ACTIVE" or "REQUIREMENT_COMPLETE"))
            if #group.ids > 1 then
                local index = groupIndex
                local choices = addon.Clean(addon.char.choices, "table")
                local saved = choices and addon.Clean(choices[id], "table")
                local selected = saved and addon.Clean(saved[index], "number")
                local valid = false
                for _, parent in ipairs(group.ids) do
                    if parent == selected and engine:State(parent).status ~= "UNAVAILABLE" then valid = true end
                end
                if not valid then selected = nil end
                local function option(value, parent, enabled, chosen)
                    branchIndex = branchIndex + 1
                    local b = self.branchButtons[branchIndex]
                    if not b then
                        b = CreateFrame("Button", nil, self.detail)
                        b:SetWidth(332); b.label = label(b, "", 3, -3, 326, 14)
                        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                        self.branchButtons[branchIndex] = b
                    end
                    b.questID, b.groupIndex, b.parentID = id, index, parent
                    b.label:SetText(chosen and addon.L("BRANCH_SELECTED", value) or value)
                    local height = math.max(30, measuredHeight(b.label, 18) + 6)
                    b:SetHeight(height); b:ClearAllPoints(); b:SetPoint("TOPLEFT", 4, -y)
                    b:SetEnabled(enabled)
                    styleRow(b, "quest", chosen)
                    b:SetScript("OnClick", enabled and function() self:ChooseBranch(id, index, parent) end or nil)
                    b:Show(); y = y + height + 3
                end
                option(addon.L("BRANCH_AUTO"), nil, true, selected == nil)
                for _, parentID in ipairs(group.ids) do
                    local parent, parentState = parentID, engine:State(parentID)
                    option(addon.QuestName(parent) .. " — " .. statusLabel(parentState), parent,
                        parentState.status ~= "UNAVAILABLE", parent == selected)
                    branchInspectIndex = branchInspectIndex + 1
                    local inspect = self.branchInspectButtons[branchInspectIndex]
                    if not inspect then
                        inspect = CreateFrame("Button", nil, self.detail)
                        inspect:SetWidth(316); inspect.label = label(inspect, "", 7, -5, 302, 14)
                        inspect:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                        self.branchInspectButtons[branchInspectIndex] = inspect
                    end
                    inspect.parentID = parent
                    inspect.label:SetText(addon.L("BRANCH_INSPECT"))
                    local inspectHeight = math.max(28, measuredHeight(inspect.label, 18) + 10)
                    inspect:SetHeight(inspectHeight); inspect:ClearAllPoints(); inspect:SetPoint("TOPLEFT", 16, -y)
                    inspect:SetEnabled(true); styleRow(inspect, "control", false)
                    inspect:SetScript("OnClick", function()
                        if self.quest == renderQuest and self.dungeon == renderDungeon and self.rewardGeneration == rewardGeneration then
                            self:InspectQuest(parent)
                        end
                    end)
                    inspect:Show(); y = y + inspectHeight + 6
                end
            elseif #group.ids == 1 then
                requirementIndex = requirementIndex + 1
                local parent = group.ids[1]
                local row = self:MakeRow(self.detail, self.requirementButtons, requirementIndex, 59)
                row.questID = parent
                row.title:SetText(addon.QuestName(parent))
                local parentState = engine:State(parent)
                row.note:SetText("|cff" .. COLOR[parentState.status] .. statusLabel(parentState) .. "|r")
                row:SetEnabled(true)
                row:SetScript("OnClick", function() self:InspectQuest(parent) end)
                y = self:LayoutRow(row, 59, y)
            end
        end
        line(addon.L((q.storyline or q.storylineGroups) and "STORY" or "CHAIN"), "section")
        local seen, chainIndex = {}, 0
        local function visit(qid, depth, grouped)
            if seen[qid] or depth > 50 then return end
            seen[qid] = true
            local def = addon.quests[qid]
            if not grouped then
                for _, group in ipairs(def and def.requires or {}) do
                    for _, parent in ipairs(group.ids) do visit(parent, depth + 1) end
                end
            end
            chainIndex = chainIndex + 1
            local b = self.chainButtons[chainIndex]
            if not b then
                b = CreateFrame("Button", nil, self.detail)
                b:SetSize(332, 34)
                b.label = label(b, "", 3, -2, 326, 14)
                b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                self.chainButtons[chainIndex] = b
            end
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", 4, -y)
            local questState = engine:State(qid)
            b.label:SetText("|cff" .. COLOR[questState.status] .. (grouped and "• " or (chainIndex .. ". ")) ..
                statusLabel(questState, addon.QuestName(qid)) .. "|r")
            local height = math.max(34, measuredHeight(b.label, 18) + 6)
            b:SetHeight(height)
            b:SetEnabled(true)
            styleRow(b, "quest", qid == self.quest)
            b:SetScript("OnClick", function() self:InspectQuest(qid) end)
            b:Show(); y = y + height + 3
        end
        if q.storylineGroups then
            line(addon.L("STORY_GROUP_NOTICE"))
            for groupIndex, group in ipairs(q.storylineGroups) do
                line(addon.L("STORY_GROUP", groupIndex), "section")
                for _, stepID in ipairs(group) do visit(stepID, 0, true) end
            end
        elseif q.storyline then
            for _, stepID in ipairs(q.storyline) do visit(stepID, 0) end
        else visit(id, 0) end
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
        local objectiveKills = addon.Clean(q.objectiveKills, "table")
        local shownKills, seenKills = false, {}
        for index = 1, math.min(objectiveKills and #objectiveKills or 0, 100) do
            local entry = addon.Clean(objectiveKills[index], "table")
            local npcID = entry and addon.Clean(rawget(entry, "npcID"), "number")
            local name = entry and addon.Clean(rawget(entry, "name"), "string")
            local rawQuantity = entry and rawget(entry, "quantity")
            local quantityReadable = true
            if type(issecretvalue) == "function" then
                local ok, restricted = pcall(issecretvalue, rawQuantity)
                quantityReadable = ok and addon.Clean(restricted, "boolean") == false
            end
            local quantityUnknown = quantityReadable and rawQuantity == nil
            local quantity = quantityReadable and addon.Clean(rawQuantity, "number")
            if not portraitCardCurrent() or addon.quests[id] ~= q or q.objectiveKills ~= objectiveKills then return end
            if npcID and npcID > 0 and npcID <= 4294967295 and npcID % 1 == 0 and
                name and #name <= 500 and name:find("%S") and not seenKills[npcID] and
                (quantityUnknown or (quantity and quantity > 0 and quantity <= 9007199254740991 and quantity % 1 == 0)) then
                seenKills[npcID] = true
                if not shownKills then
                    line(addon.L("OBJECTIVE_KILLS"), "section"); line(addon.L("OBJECTIVE_KILLS_NOTICE")); shownKills = true
                end
                line(quantityUnknown and addon.L("OBJECTIVE_ITEM_UNKNOWN", name) or addon.L("OBJECTIVE_ITEM", name, quantity))
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
                        binding = { id = itemID, texture = icon, role = sourceRole, sourceField = sourceField }
                        binding.current = function() return entryCurrent(binding) end
                        if not binding.current() then return end
                    end
                    if not shownObjectives then
                        line(addon.L(heading), "section"); line(addon.L(notice)); shownObjectives = true
                    end
                    if line(quantityUnknown and addon.L("OBJECTIVE_ITEM_UNKNOWN", name) or addon.L("OBJECTIVE_ITEM", name, quantity), nil, nil, binding) == false then return end
                    if count then line(count) end
                end
            end
        end
        line(addon.Description(id))
        local dialogueObjective
        if type(addon.DialogueObjectiveText) == "function" then
            dialogueObjective = addon.Read(addon.DialogueObjectiveText, "string", id)
        end
        if dialogueObjective and dialogueObjective ~= "" and #dialogueObjective <= 30000 then
            line(addon.L("OBJECTIVE_DIALOGUE"), "section")
            line(dialogueObjective)
        end
        local objectives = addon.QuestObjectives and addon.QuestObjectives(id)
        if objectives and #objectives > 0 then line(addon.L("OBJECTIVE_PROGRESS"), "section") end
        for _, objective in ipairs(objectives or {}) do
            line("|cff" .. (objective.finished and COLOR.COMPLETED or COLOR.ACTIVE) .. objective.text .. "|r")
        end
        local rewards, rewardOrigin = rewardData(id)
        if rewards and addon.Clean(rewards.source, "string") == "dialogue" then line(addon.L("REWARD_DIALOGUE"), "section")
        elseif rewards and addon.Clean(rewards.source, "string") == "cache" then line(addon.L("REWARD_PREVIEW"), "section") end
        local items = rewards and addon.Clean(rewards.items, "table")
        local choices = rewards and addon.Clean(rewards.choices, "table")
        if rewards and addon.Clean(rewards.hidden, "boolean") == true then
            line(addon.L("REWARD_HIDDEN"))
        elseif items and choices then
            if #items > 0 then
                line(addon.L("REWARD_ITEMS"), "section")
                for index, item in ipairs(items) do
                    if line(addon.L("REWARD_ITEM", item.name, item.count), nil,
                        { item = item, origin = rewardOrigin, source = addon.Clean(rewards.source, "string"), kind = "items", index = index }) == false then return end
                end
            end
            if #choices > 0 then
                line(addon.L("REWARD_CHOICES"), "section")
                for index, item in ipairs(choices) do
                    if line(addon.L("REWARD_ITEM", item.name, item.count), nil,
                        { item = item, origin = rewardOrigin, source = addon.Clean(rewards.source, "string"), kind = "choices", index = index }) == false then return end
                end
            end
            if #items == 0 and #choices == 0 then line(addon.L("REWARD_NO_ITEMS")) end
            local xp = addon.Clean(rewards.xp, "number")
            if xp and xp >= 0 and xp % 1 == 0 then line(addon.L("REWARD_XP", xp)) end
            local money = addon.Clean(rewards.money, "number")
            if money and money > 0 then
                local formatted = addon.Read(GetCoinTextureString, "string", money)
                line(formatted and (addon.L("REWARD_MONEY") .. ": " .. formatted) or addon.L("REWARD_MONEY_UNKNOWN"))
            end
        else line(addon.L("REWARD_UNAVAILABLE")) end
        self.source:SetEnabled(true)
    else
        self.map:SetEnabled(false); self.guide:SetEnabled(false); self.source:SetEnabled(false)
        if renderDungeon then
            local name = addon.Read(addon.DungeonName, "string", renderDungeon)
            if self.quest ~= renderQuest or self.dungeon ~= renderDungeon or self.rewardGeneration ~= rewardGeneration then return end
            line(name or addon.Clean(renderDungeon.name, "string") or addon.L("UNKNOWN_PLACE"), "title")
            if not self.overviewArt then
                self.overviewArt = self.detail:CreateTexture(nil, "ARTWORK")
                self.overviewArt:SetSize(148, 148)
            end
            self.overviewArt:ClearAllPoints(); self.overviewArt:SetPoint("TOPLEFT", 97, -y)
            local painted = addon.Read(addon.PaintDungeonArt, "boolean", self.overviewArt, renderDungeon)
            if self.quest ~= renderQuest or self.dungeon ~= renderDungeon or self.rewardGeneration ~= rewardGeneration then return end
            if painted == true then y = y + 156 end
            local minimum, maximum = addon.Clean(renderDungeon.minLevel, "number"), addon.Clean(renderDungeon.maxLevel, "number")
            if minimum and maximum and minimum > 0 and maximum >= minimum and minimum % 1 == 0 and maximum % 1 == 0 then
                line(addon.L("CATALOG_LEVELS", minimum, maximum))
            end
            local quests = addon.Clean(renderDungeon.quests, "table")
            local count = quests and #quests or 0
            line(addon.L("CATALOG_QUESTS", count))
            if count == 0 then line(addon.L("EMPTY")) end
            line(addon.L(renderDungeon.coverage == "reviewed" and "OVERVIEW_REVIEWED" or "PARTIAL"))
            line(addon.L("OVERVIEW_PICK"))
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
    self.map:SetEnabled(pendingAction ~= nil and pendingAction.place ~= nil and pendingAction.place.mapID ~= nil)
    self.guide:SetEnabled(pendingAction ~= nil and pendingAction.place ~= nil and pendingAction.place.x ~= nil)
    local giverPlace = pendingGiver and pendingGiver.action.place
    if giverPlace and addon.quests[renderQuest] == pendingGiver.source and pendingGiver.source.start == giverPlace and
        addon.Clean(giverPlace.mapID, "number") == pendingGiver.map and addon.Clean(giverPlace.x, "number") == pendingGiver.x and
        addon.Clean(giverPlace.y, "number") == pendingGiver.y then
        self.giverAction, self.giverHasCoordinates = pendingGiver.action, pendingGiver.coordinates
        self.giver:SetText(addon.L(pendingGiver.coordinates and "VISIT_GIVER" or "GIVER_MAP"))
        self.giver:SetEnabled(true)
    end
end

function UI:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    self.subtitle:SetText(addon.L("SUBTITLE"))
    self.back:SetText(addon.L("DETAIL_BACK"))
    self.language:SetText(addon.db.locale == "auto" and "Auto" or addon.db.locale)
    self.rangeButton:SetText(addon.L(self.range and "RANGE" or "ALL"))
    self.preparationButton:SetText(addon.L(self.preparation and "QUESTS" or "NEXT"))
    self.characterButton:SetText(addon.L(self.includeUnavailable and "ALL_CHARACTERS" or "MY_CHARACTER"))
    self.map:SetText(addon.L("MAP")); self.guide:SetText(addon.L("GUIDE")); self.source:SetText(addon.L("SOURCE"))
    self.footer:SetText(addon.L("DEVELOPMENT"))
    local log = addon.Read(addon.QuestLogCapacity, "table")
    local count = log and addon.Clean(log.count, "number")
    local capacity = log and addon.Clean(log.capacity, "number")
    local known = count ~= nil and capacity ~= nil and count >= 0 and count % 1 == 0 and capacity > 0 and capacity % 1 == 0
    self.capacityStatus:SetText(known and addon.L("QUEST_LOG_CAPACITY", count, capacity) or "")
    self.capacityStatus:SetShown(known)
    self:RefreshDungeons(); self:RefreshQuests(); self:RefreshDetail()
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
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
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
    self.title = label(frame, addon.L("TITLE"), 22, -16, 360, 26)
    self.subtitle = label(frame, "", 22, -49, 500, 13)
    self.back = button(frame, addon.L("DETAIL_BACK"), 120, function() self:BackQuest() end)
    self.back:SetPoint("TOPLEFT", 560, -45)
    self.back:SetEnabled(false)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -4, -4)
    local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    search:SetSize(200, 25); search:SetPoint("TOPLEFT", 27, -84); search:SetAutoFocus(false)
    self.searchBox = search
    setInputFont(search)
    self.searchPlaceholder = label(search, "", 5, -5, 188, 13)
    search:SetScript("OnTextChanged", function(b) self.search = addon.Read(b.GetText, "string", b) or ""; self:RefreshDungeons() end)
    search:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
    self.clearSearch = button(frame, "×", 25, function()
        self.search = ""; self.searchBox:SetText(""); self:RefreshDungeons()
    end)
    self.clearSearch:SetPoint("TOPLEFT", 233, -84)
    self.rangeButton = button(frame, "", 105, function() self.range = not self.range; self:SaveFilters(); self:Refresh() end)
    self.rangeButton:SetPoint("TOPLEFT", 273, -84)
    self.preparationButton = button(frame, "", 170, function()
        self.preparation = not self.preparation; self:SaveFilters(); self:Refresh()
    end)
    self.preparationButton:SetPoint("TOPLEFT", 390, -84)
    self.characterButton = button(frame, "", 120, function()
        self.includeUnavailable = not self.includeUnavailable; self:SaveFilters(); self:Refresh()
    end)
    self.characterButton:SetPoint("TOPLEFT", 564, -84)
    local language = button(frame, "Auto", 100, function() self:OpenLanguageMenu() end)
    self.language = language
    language:SetPoint("TOPRIGHT", -44, -45)
    self.heading = label(frame, "", 288, -125, 730, 26)
    self.summary = label(frame, "", 288, -163, 760, 14)
    self.coverage = label(frame, "", 288, -191, 760, 14)
    self.catalog, self.catalogScroll = scrolling(frame, 22, -125, 235, 518)
    self.searchHint = label(self.catalog, "", 4, 0, 220, 13)
    self.catalogNotice = label(self.catalog, "", 4, 0, 220, 13)
    self.questList, self.questScroll = scrolling(frame, 288, -218, 355, 425)
    self.detail, self.detailScroll = scrolling(frame, 690, -218, 350, 425)
    self.map = button(frame, "", 160, function()
        local action = self:CurrentDetailAction()
        if action then addon.Navigation.Map(action.place) end
    end)
    self.map:SetPoint("TOPLEFT", 690, -84)
    self.guide = button(frame, "", 172, function()
        local action = self:CurrentDetailAction()
        if action then addon.Navigation.Start(action) end
    end)
    self.guide:SetPoint("TOPLEFT", 856, -84)
    self.source = button(frame, "", 160, function() if self.quest then self:CopyLink(self.quest) end end)
    self.source:SetPoint("BOTTOMRIGHT", -43, 19)
    self.giver = button(frame, "", 195, function()
        if self.giverAction then
            if self.giverHasCoordinates then addon.Navigation.Start(self.giverAction)
            else addon.Navigation.Map(self.giverAction.place) end
        end
    end)
    self.giver:SetPoint("BOTTOMLEFT", 690, 19)
    self.capacityStatus = label(frame, "", 22, -646, 640, 13)
    self.capacityStatus:Hide()
    self.footer = label(frame, "", 22, -668, 640, 13)
    self.frame, self.cards, self.rows, self.details, self.chainButtons, self.branchButtons = frame, {}, {}, {}, {}, {}
    self.materialButtons = {}
    self.requirementButtons, self.branchInspectButtons = {}, {}
    self.actionButtons, self.actionInspectButtons, self.preparationForButtons = {}, {}, {}
    self.startButtons, self.finishButtons, self.containerButtons = {}, {}, {}
    UISpecialFrames[#UISpecialFrames + 1] = "DungeonProWindow"
    for _, d in ipairs(addon.dungeons) do if d.key == addon.char.selectedDungeon then self.dungeon = d end end
    frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    frame:RegisterEvent("UI_SCALE_CHANGED")
    frame:SetScript("OnEvent", function(f, event)
        if (event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED") and
            addon.Read(f.IsShown, "boolean", f) == true then self:Fit() end
    end)
    frame:SetScript("OnShow", function() self:Fit(); self:Refresh() end)
    frame:SetScript("OnHide", function() self.detailActionChoice = nil; self.languageMenuRevision = {}; self:ResetHistoryReading(); self:ResetRewardPresentation(); self:CloseCopyLink() end)
    self:ApplyTheme()
    frame:Hide()
end

function UI:Toggle()
    if not self.frame then self:Create() end
    self.frame:SetShown(not self.frame:IsShown())
end
addon.listeners[#addon.listeners + 1] = function() UI:Refresh() end
