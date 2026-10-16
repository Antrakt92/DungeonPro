local _, addon = ...
local UI = { dungeon = nil, quest = nil, search = "", range = false, preparation = false }
addon.UI = UI
local COLOR = { COMPLETED = "66dd99", READY = "ffe066", ACTIVE = "88bfff", AVAILABLE = "ffe9b0",
    LOCKED = "f0b080", UNKNOWN = "b4aacd", UNAVAILABLE = "999999" }
local FONT

local function text(parent, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size or 13, "")
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

function UI:CopyLink(id)
    if not self.copy then
        local box = CreateFrame("EditBox", nil, self.frame, "InputBoxTemplate")
        box:SetSize(650, 26)
        box:SetPoint("BOTTOM", 0, 13)
        box:SetAutoFocus(false)
        box:SetScript("OnEscapePressed", function(b) b:Hide(); b:ClearFocus() end)
        self.copy = box
    end
    self.copy:SetText("https://www.wowhead.com/forever/quest=" .. id)
    self.copy:Show(); self.copy:SetFocus(); self.copy:HighlightText()
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
        row.title = label(row, "", 8, -7, parent:GetWidth() - 22, 14)
        row.note = label(row, "", 8, -29, parent:GetWidth() - 22, 11)
        pool[index] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -(index - 1) * (height + 4))
    row:Show()
    return row
end

local function hideRest(pool, n)
    for i = n + 1, #pool do pool[i]:Hide() end
end

function UI:RefreshDungeons()
    local context = addon.Context()
    local n = 0
    for _, d in ipairs(addon.dungeons) do
        local name = addon.DungeonName(d)
        -- UTF-8 text is matched byte-for-byte; avoid corrupting non-ASCII names.
        local matches = self.search == "" or name:find(self.search, 1, true) or d.name:find(self.search, 1, true)
        if matches and (not self.range or (context.level and context.level >= d.minLevel - 3 and context.level <= d.maxLevel + 3)) then
            n = n + 1
            local row = self:MakeRow(self.catalog, self.cards, n, 64)
            if not row.art then
                row.art = row:CreateTexture(nil, "ARTWORK")
                row.art:SetSize(44, 44); row.art:SetPoint("TOPLEFT", 6, -9)
                row.title:ClearAllPoints(); row.title:SetPoint("TOPLEFT", 58, -7); row.title:SetWidth(158)
                row.note:ClearAllPoints(); row.note:SetPoint("TOPLEFT", 58, -42); row.note:SetWidth(158)
            end
            row.art:SetTexture(addon.DungeonArt(d))
            row.title:SetText(name)
            row.note:SetText(d.minLevel .. "–" .. d.maxLevel .. "   " .. (#d.quests > 0 and tostring(#d.quests) or "—"))
            row.bg:SetColorTexture(self.dungeon == d and 0.22 or 0.13, 0.19, 0.23, 1)
            row:SetScript("OnClick", function()
                self.dungeon, self.quest = d, nil
                addon.char.selectedDungeon = d.key
                self:Refresh()
            end)
        end
    end
    hideRest(self.cards, n)
    self.catalog:SetHeight(math.max(1, n * 68))
end

function UI:RefreshQuests()
    local d, engine = self.dungeon, addon.Planner.New(addon.quests, addon.Context())
    self.engine = engine
    self.heading:SetText(d and addon.DungeonName(d) or addon.L("QUESTS"))
    local n = 0
    if d then
        local plan = engine:Dungeon(d)
        self.summary:SetText(addon.L("SUMMARY", (plan.counts.ACTIVE or 0) + (plan.counts.READY or 0),
            plan.counts.COMPLETED or 0, (plan.counts.LOCKED or 0) + (plan.counts.AVAILABLE or 0), plan.counts.UNKNOWN or 0))
        self.coverage:SetText(plan.unknown and addon.L("PARTIAL") or addon.L(plan.ready and "PREPARED" or "NOT_PREPARED"))
        local entries = plan.rows
        if self.preparation then
            entries = {}
            for _, action in ipairs(plan.actions) do
                entries[#entries + 1] = { id = action.id, state = engine:State(action.id), action = action }
            end
            -- Unresolved targets stay visible even when no trustworthy action exists.
            for _, entry in ipairs(plan.rows) do
                if entry.state.status == "UNKNOWN" then entries[#entries + 1] = entry end
            end
        end
        for _, entry in ipairs(entries) do
            n = n + 1
            local row, id, state = self:MakeRow(self.questList, self.rows, n, 59), entry.id, entry.state
            row.title:SetText(addon.QuestName(id))
            local note = addon.L(state.status)
            if entry.action then
                local action = entry.action
                note = addon.L(action.kind) .. (action.level and (" " .. action.level) or "")
                if action.place then note = note .. " — " .. (action.place.name or addon.L("UNKNOWN_PLACE")) end
            elseif state.reason == "level" then
                note = addon.L("level") .. " " .. addon.quests[id].minLevel
            end
            row.note:SetText("|cff" .. COLOR[state.status] .. note .. "|r")
            row:SetScript("OnClick", function() self.quest = id; self:RefreshDetail() end)
        end
        if #plan.rows == 0 then self.coverage:SetText(addon.L("EMPTY")) end
    else
        self.summary:SetText(""); self.coverage:SetText(addon.L("PICK"))
    end
    hideRest(self.rows, n)
    self.questList:SetHeight(math.max(1, n * 63))
end

function UI:RefreshDetail()
    local pool, n, y = self.details, 0, 0
    self.action = nil
    local function line(value, height)
        n = n + 1
        local fs = pool[n]
        if not fs then fs = label(self.detail, "", 4, 0, 334, 13); pool[n] = fs end
        fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 4, -y); fs:SetText(value); fs:Show()
        local measured = addon.Clean(fs:GetStringHeight(), "number") or height or 18
        y = y + math.max(height or 18, measured) + 8
    end
    for _, b in ipairs(self.chainButtons) do b:Hide() end
    local id, engine = self.quest, self.engine
    if id and addon.quests[id] then
        local q = addon.quests[id]
        line(addon.QuestName(id), 24)
        local state = engine:State(id)
        line("|cff" .. COLOR[state.status] .. addon.L(state.status) .. "|r")
        local function place(p)
            if not p then return addon.L("UNKNOWN_PLACE") end
            local zone = p.mapID and addon.Read(C_Map and C_Map.GetMapInfo, "table", p.mapID)
            return (p.name or "?") .. (zone and zone.name and (" — " .. zone.name) or "") ..
                (p.x and string.format(" (%.1f, %.1f)", p.x, p.y) or "")
        end
        line(addon.L("START") .. ": " .. place(q.start))
        line(addon.L("ENDING") .. ": " .. place(q.finish))
        local actions, uncertain = engine:Next(id)
        line(addon.L("NEXT"))
        local action = actions[1]
        if action then
            line(addon.L(action.kind) .. ": " .. addon.QuestName(action.id) .. (action.level and (" (" .. action.level .. ")") or ""))
        else line(addon.L(state.status == "COMPLETED" and "COMPLETED" or "UNKNOWN")) end
        if uncertain then line(addon.L("UNKNOWN")) end
        self.action = action
        self.map:SetEnabled(action ~= nil and action.place ~= nil and action.place.mapID ~= nil)
        self.guide:SetEnabled(action ~= nil and action.place ~= nil and action.place.x ~= nil)
        line(addon.L(q.storyline and "STORY" or "CHAIN"))
        local seen, chainIndex = {}, 0
        local function visit(qid, depth)
            if seen[qid] or depth > 50 then return end
            seen[qid] = true
            local def = addon.quests[qid]
            for _, group in ipairs(def and def.requires or {}) do
                for _, parent in ipairs(group.ids) do visit(parent, depth + 1) end
            end
            chainIndex = chainIndex + 1
            local b = self.chainButtons[chainIndex]
            if not b then
                b = CreateFrame("Button", nil, self.detail)
                b:SetSize(332, 34)
                b.label = label(b, "", 3, -2, 326, 12)
                b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                self.chainButtons[chainIndex] = b
            end
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", 4, -y)
            local qs = engine:State(qid).status
            b.label:SetText("|cff" .. COLOR[qs] .. chainIndex .. ". " .. addon.QuestName(qid) .. "|r")
            b:SetScript("OnClick", function() self.quest = qid; self:RefreshDetail() end)
            b:Show(); y = y + 37
        end
        if q.storyline then
            for _, stepID in ipairs(q.storyline) do visit(stepID, 0) end
        else visit(id, 0) end
        line(addon.Description(id))
        local objectives = addon.QuestObjectives and addon.QuestObjectives(id)
        for _, objective in ipairs(objectives or {}) do
            line("|cff" .. (objective.finished and COLOR.COMPLETED or COLOR.ACTIVE) .. objective.text .. "|r")
        end
        self.source:SetEnabled(true)
    else
        line(addon.L("PICK")); self.map:SetEnabled(false); self.guide:SetEnabled(false); self.source:SetEnabled(false)
    end
    hideRest(pool, n)
    self.detail:SetHeight(math.max(1, y + 12))
end

function UI:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    self.subtitle:SetText(addon.L("SUBTITLE"))
    self.language:SetText(addon.db.locale == "auto" and "Auto" or addon.db.locale)
    self.rangeButton:SetText(addon.L(self.range and "RANGE" or "ALL"))
    self.preparationButton:SetText(addon.L(self.preparation and "QUESTS" or "NEXT"))
    self.map:SetText(addon.L("MAP")); self.guide:SetText(addon.L("GUIDE")); self.source:SetText(addon.L("SOURCE"))
    self.footer:SetText(addon.L("DEVELOPMENT"))
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
    FONT = STANDARD_TEXT_FONT or "Fonts\\ARIALN.TTF"
    local frame = CreateFrame("Frame", "DungeonPrepWindow", UIParent, "BackdropTemplate")
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
    label(frame, "DungeonPrep", 22, -18, 360, 24)
    self.subtitle = label(frame, "", 22, -49, 500, 13)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -4, -4)
    local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    search:SetSize(230, 25); search:SetPoint("TOPLEFT", 27, -84); search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function(b) self.search = b:GetText(); self:RefreshDungeons() end)
    search:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
    self.rangeButton = button(frame, "", 105, function() self.range = not self.range; self:Refresh() end)
    self.rangeButton:SetPoint("TOPLEFT", 273, -84)
    self.preparationButton = button(frame, "", 170, function()
        self.preparation = not self.preparation; self:Refresh()
    end)
    self.preparationButton:SetPoint("TOPLEFT", 390, -84)
    local language = button(frame, "Auto", 100, function()
        local order = { "auto", "enUS", "ruRU", "deDE", "frFR", "esES", "itIT", "ptBR", "koKR", "zhCN", "zhTW" }
        local current = 1
        for i, code in ipairs(order) do if addon.db.locale == code then current = i end end
        addon.db.locale = order[current % #order + 1]; self:Refresh()
    end)
    self.language = language
    language:SetPoint("TOPRIGHT", -44, -45)
    self.heading = label(frame, "", 288, -125, 730, 20)
    self.summary = label(frame, "", 288, -157, 760, 12)
    self.coverage = label(frame, "", 288, -183, 760, 12)
    self.catalog = scrolling(frame, 22, -125, 235, 518)
    self.questList = scrolling(frame, 288, -218, 355, 425)
    self.detail = scrolling(frame, 690, -218, 350, 425)
    self.map = button(frame, "", 160, function()
        if self.action then addon.Navigation.Map(self.action.place) end
    end)
    self.map:SetPoint("TOPLEFT", 690, -84)
    self.guide = button(frame, "", 172, function()
        if self.action then addon.Navigation.Start(self.action) end
    end)
    self.guide:SetPoint("TOPLEFT", 856, -84)
    self.source = button(frame, "", 160, function() if self.quest then self:CopyLink(self.quest) end end)
    self.source:SetPoint("BOTTOMRIGHT", -43, 19)
    self.footer = label(frame, "", 22, -668, 800, 11)
    self.frame, self.cards, self.rows, self.details, self.chainButtons = frame, {}, {}, {}, {}
    UISpecialFrames[#UISpecialFrames + 1] = "DungeonPrepWindow"
    for _, d in ipairs(addon.dungeons) do if d.key == addon.char.selectedDungeon then self.dungeon = d end end
    frame:SetScript("OnShow", function() self:Fit(); self:Refresh() end)
    frame:Hide()
end

function UI:Toggle()
    if not self.frame then self:Create() end
    self.frame:SetShown(not self.frame:IsShown())
end
addon.listeners[#addon.listeners + 1] = function() UI:Refresh() end
