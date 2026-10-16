local _, addon = ...
local UI = { dungeon = nil, quest = nil, search = "", range = false, preparation = false, includeUnavailable = false,
    detailHistory = {} }
addon.UI = UI
local COLOR = { COMPLETED = "66dd99", READY = "ffe066", ACTIVE = "88bfff", AVAILABLE = "ffe9b0",
    LOCKED = "f0b080", UNKNOWN = "b4aacd", UNAVAILABLE = "999999" }
local FONT

local function statusLabel(state, value)
    local label = value or addon.L(state.status == "UNKNOWN" and state.reason == "requirements" and
        "UNKNOWN_REQUIREMENTS" or state.status)
    if (state.status == "ACTIVE" or state.status == "READY") and
        addon.Clean(state.completedHistory, "boolean") == true then
        label = label .. " — " .. addon.L("COMPLETED_BEFORE")
    end
    return label
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
    -- Only ASCII bytes are folded; UTF-8 sequences pass through unchanged.
    return value:gsub("[A-Z]", function(letter) return string.char(letter:byte() + 32) end)
end

local function measuredHeight(fs, fallback)
    local value = addon.Read(fs.GetStringHeight, "number", fs)
    if value and value > 0 then fs.measuredHeight = value; return value end
    return fs.measuredHeight or fallback
end

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
    row:Show()
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

function UI:InspectQuest(id)
    id = addon.Clean(id, "number")
    if not id or id <= 0 or id % 1 ~= 0 then return false end
    if self.quest ~= id then
        local previous = addon.Clean(self.quest, "number")
        if previous and previous > 0 and previous % 1 == 0 then
            self.detailHistory[#self.detailHistory + 1] = previous
            if #self.detailHistory > 20 then table.remove(self.detailHistory, 1) end
        end
        self.quest = id
    end
    self:RefreshDetail()
    return true
end

function UI:BackQuest()
    local previous = table.remove(self.detailHistory)
    if not previous then return false end
    self.quest = previous
    self:RefreshDetail()
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
            row.art:SetTexture(addon.DungeonArt(d))
            row.title:SetText(name)
            row.note:SetText(addon.L("CATALOG_LEVELS", d.minLevel, d.maxLevel) .. "\n" ..
                addon.L("CATALOG_QUESTS", #d.quests))
            row.bg:SetColorTexture(self.dungeon == d and 0.22 or 0.13, 0.19, 0.23, 1)
            row:SetScript("OnClick", function()
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
    local d, engine = self.dungeon, addon.Planner.New(addon.quests, addon.Context(), addon.Clean(addon.char.choices, "table"))
    self.engine = engine
    for _, row in ipairs(self.rows) do row:SetEnabled(false); row:SetScript("OnClick", nil) end
    self.heading:SetText(d and addon.DungeonName(d) or addon.L("QUESTS"))
    local n, offset = 0, 0
    if d then
        local plan = engine:Dungeon(d, { includeUnavailable = self.includeUnavailable })
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
            n = n + 1
            local row, id, state = self:MakeRow(self.questList, self.rows, n, 59), entry.id, entry.state
            row.heading = entry.heading
            row:SetEnabled(not entry.heading)
            row:SetHighlightTexture(not entry.heading and "Interface\\QuestFrame\\UI-QuestTitleHighlight" or nil)
            if entry.heading then
                row.title:SetText(addon.L(entry.heading)); row.note:SetText("")
                row.bg:SetColorTexture(0.20, 0.22, 0.26, 1)
                row:SetScript("OnClick", nil)
            else
                row.bg:SetColorTexture(0.13, 0.16, 0.20, 1)
                row.title:SetText(addon.QuestName(id))
                local note
                if entry.action then
                    local action = entry.action
                    note = addon.L(action.kind) .. (action.level and (" " .. action.level) or "")
                    if action.place then note = note .. " — " .. giverName(action.place) end
                elseif state.reason == "level" then
                    note = addon.L("level") .. " " .. addon.quests[id].minLevel
                end
                row.note:SetText("|cff" .. COLOR[state.status] .. statusLabel(state, note) .. "|r")
                row:SetScript("OnClick", function() self:InspectQuest(id) end)
            end
            offset = self:LayoutRow(row, entry.heading and 32 or 59, offset)
        end
        if #plan.rows == 0 then
            self.coverage:SetText(addon.L(#d.quests > 0 and "NO_CHARACTER_QUESTS" or "EMPTY"))
        end
    else
        self.summary:SetText(""); self.coverage:SetText(addon.L("PICK"))
    end
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
    self.rewardButtons = self.rewardButtons or {}
    for _, button in ipairs(self.rewardButtons) do
        button.rewardBinding = nil
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
    self:ReleaseRewardTooltip()
    if self.rewardTooltip or not self:RewardBindingCurrent(button, binding) then return end
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

function UI:RefreshDetail()
    local renderQuest = self.quest
    local rewardGeneration = self:ResetRewardPresentation()
    if not rewardGeneration or self.quest ~= renderQuest then return end
    if self.renderedQuest ~= self.quest then
        if self.copy then
            self.copy:SetText(""); self.copy:Hide(); self.copy:ClearFocus()
        end
        self.detailScroll:SetVerticalScroll(0)
        self.renderedQuest = self.quest
        self.reportedExpanded = {}
    end
    local pool, n, y = self.details, 0, 0
    self.reportedExpanded = self.reportedExpanded or {}
    self.reportedToggles, self.reportedRows = self.reportedToggles or {}, self.reportedRows or {}
    local reportedGeneration, toggleIndex, reportIndex = {}, 0, 0
    self.reportedGeneration = reportedGeneration
    for _, buttons in ipairs({ self.reportedToggles, self.reportedRows }) do
        for _, row in ipairs(buttons) do row:Hide(); row:SetEnabled(false); row:SetScript("OnClick", nil) end
    end
    self.back:SetEnabled(#self.detailHistory > 0)
    if self.portrait then self.portrait:Hide(); self.portrait:SetTexture(nil) end
    self.action = nil
    self.giverAction, self.giverHasCoordinates = nil, false
    self.giver:SetEnabled(false)
    self.giver:SetText(addon.L("VISIT_GIVER"))
    local rewardIndex = 0
    local function line(value, height, reward)
        n = n + 1
        local fs = pool[n]
        if not fs then fs = label(self.detail, "", 4, 0, 334, 13); pool[n] = fs end
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
        local measured = measuredHeight(fs, height or 18)
        y = y + math.max(height or 18, measured) + 8
        return true
    end
    for _, b in ipairs(self.chainButtons) do b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil) end
    for _, b in ipairs(self.branchButtons) do b:Hide() end
    for _, b in ipairs(self.requirementButtons) do b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil) end
    for _, b in ipairs(self.materialButtons) do b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil) end
    for _, buttons in ipairs({ self.startButtons, self.finishButtons, self.containerButtons }) do
        for _, b in ipairs(buttons) do
            b:Hide(); b:SetEnabled(false); b:SetScript("OnClick", nil)
        end
    end
    local id, engine = self.quest, self.engine
    if id then
        local q = addon.quests[id] or {}
        line(addon.QuestName(id), 24)
        local state = engine:State(id)
        line("|cff" .. COLOR[state.status] .. statusLabel(state) .. "|r")
        local minimum = addon.Clean(q.minLevel, "number")
        if minimum and minimum > 0 and minimum % 1 == 0 then line(addon.L("QUEST_MIN_LEVEL", minimum)) end
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
        local offer = addon.Read(addon.CurrentOffer, "table", id)
        if offer and addon.Clean(offer.offeredNow, "boolean") == true then line(addon.L("OFFERED_NOW")) end
        local portrait = addon.Read(addon.DialoguePortrait, "table", id) or
            addon.Read(addon.QuestPortrait, "table", id)
        local displayID = portrait and addon.Clean(portrait.hidden, "boolean") ~= true and
            addon.Clean(portrait.displayID, "number")
        if displayID and displayID > 0 and displayID % 1 == 0 and
            type(SetPortraitTextureFromCreatureDisplayID) == "function" then
            if not self.portrait then
                self.portrait = self.detail:CreateTexture(nil, "ARTWORK")
                self.portrait:SetSize(64, 64)
                self.portrait:Hide()
            end
            self.portrait:ClearAllPoints()
            local rendered = pcall(SetPortraitTextureFromCreatureDisplayID, self.portrait, displayID)
            if rendered then
                line(addon.L("QUEST_PORTRAIT"))
                self.portrait:SetPoint("TOPLEFT", 4, -y); self.portrait:Show()
                y = y + 64 + 8
            else self.portrait:SetTexture(nil) end
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
        local function reported(parent, key)
            local places = reportedPlaces(parent)
            if not places then return end
            toggleIndex = toggleIndex + 1
            local toggle = self:MakeRow(self.detail, self.reportedToggles, toggleIndex, 40)
            toggle.locationKey, toggle.heading = key, true
            local expanded = self.reportedExpanded[key] == true
            toggle.title:SetText((expanded and "− " or "+ ") .. addon.L("REPORTED_POSITIONS", giverName(parent), #places))
            toggle.note:SetText(""); toggle:SetEnabled(true)
            toggle:SetScript("OnClick", function()
                if self.quest ~= id or self.reportedGeneration ~= reportedGeneration then return end
                self.reportedExpanded[key] = not expanded
                self:RefreshDetail()
            end)
            y = self:LayoutRow(toggle, 40, y)
            if not expanded then return end
            line(addon.L("REPORTED_NOTICE"))
            for _, destination in ipairs(places) do
                local point = destination
                reportIndex = reportIndex + 1
                local row = self:MakeRow(self.detail, self.reportedRows, reportIndex, 59)
                row.locationKey, row.destination, row.heading = key, point, nil
                local zone = addon.Read(C_Map and C_Map.GetMapInfo, "table", point.mapID)
                local zoneName = (zone and addon.Clean(zone.name, "string")) or point.zoneName or addon.L("UNKNOWN_PLACE")
                row.title:SetText(zoneName .. string.format(" (%.1f, %.1f)", point.x, point.y))
                row.note:SetText(addon.L("REPORTED_VISIT")); row:SetEnabled(true)
                row:SetScript("OnClick", function()
                    if self.quest == id and self.reportedGeneration == reportedGeneration then
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
            local zoneName = (zone and addon.Clean(zone.name, "string")) or addon.Clean(p.zoneName, "string")
            local name = giverName(p)
            if p.itemID then
                name = addon.L("ITEM_STARTER", addon.Read(addon.ItemName, "string", p.itemID) or name)
            end
            return name .. (zoneName and (" — " .. zoneName) or "") ..
                (p.x and string.format(" (%.1f, %.1f)", p.x, p.y) or "")
        end
        local function alternativePlaces(places, buttons, heading, slot)
            line(addon.L(heading))
            for index, possible in ipairs(places) do
                local destination = possible
                local row = self:MakeRow(self.detail, buttons, index, 59)
                row.title:SetText(giverName(destination))
                local mapID = addon.Clean(destination.mapID, "number")
                local validMap = mapID ~= nil and mapID > 0 and mapID % 1 == 0
                local zone = validMap and addon.Read(C_Map and C_Map.GetMapInfo, "table", mapID)
                local x, py = addon.Clean(destination.x, "number"), addon.Clean(destination.y, "number")
                local coordinates = validMap and x ~= nil and py ~= nil and x >= 0 and x <= 100 and py >= 0 and py <= 100
                row.note:SetText(((zone and addon.Clean(zone.name, "string")) or
                    addon.Clean(destination.zoneName, "string") or destination.locationName or addon.L("UNKNOWN_PLACE")) ..
                    (coordinates and string.format(" (%.1f, %.1f)", x, py) or ""))
                row:SetEnabled(validMap)
                row:SetScript("OnClick", validMap and function()
                    if self.quest ~= id or self.reportedGeneration ~= reportedGeneration then return end
                    local visit = { id = id, kind = "visit", place = destination }
                    if coordinates then addon.Navigation.Start(visit)
                    else addon.Navigation.Map(destination) end
                end or nil)
                y = self:LayoutRow(row, 59, y)
                reported(destination, slot .. index)
            end
        end
        if q.startAlternatives then
            alternativePlaces(q.startAlternatives, self.startButtons, "START_ALTERNATIVES", "startAlternative:")
        else line(addon.L("START") .. ": " .. place(q.start)); reported(q.start, "start") end
        local start = q.start
        if start and start.itemID then
            local count = carried(start.itemID)
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
            local container = addon.Clean(start.containerSource, "table")
            if container then
                alternativePlaces({ container }, self.containerButtons, "CONTAINER_SOURCE", "container:")
            end
        end
        if start and start.itemID and start.dropNPCID then
            local dungeonName = addon.L("UNKNOWN_PLACE")
            for _, dungeon in ipairs(addon.dungeons) do
                if dungeon.key == start.dungeonKey then dungeonName = addon.DungeonName(dungeon); break end
            end
            line(addon.L("ITEM_DROP_SOURCE", giverName({ npcID = start.dropNPCID, name = start.dropName or ("#" .. start.dropNPCID) }), dungeonName))
        end
        for _, drop in ipairs(start and start.dropSources or {}) do
            line(addon.L("ITEM_DROP_SOURCE", giverName(drop), drop.locationName))
        end
        local map = start and addon.Clean(start.mapID, "number")
        if map and map > 0 then
            local x, gy = addon.Clean(start.x, "number"), addon.Clean(start.y, "number")
            self.giverHasCoordinates = x ~= nil and gy ~= nil and x >= 0 and x <= 100 and gy >= 0 and gy <= 100
            self.giverAction = { id = id, kind = "visit", place = start }
            self.giver:SetEnabled(true)
            self.giver:SetText(addon.L(self.giverHasCoordinates and "VISIT_GIVER" or "GIVER_MAP"))
            if state.status ~= "AVAILABLE" then line(addon.L("LOCATION_ONLY")) end
        end
        if q.finishAlternatives then
            alternativePlaces(q.finishAlternatives, self.finishButtons, "POSSIBLE_TURNINS", "finishAlternative:")
        else line(addon.L("ENDING") .. ": " .. place(q.finish)); reported(q.finish, "finish") end
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
        local branchIndex = 0
        local requirementIndex = 0
        if q.requires and #q.requires > 0 then
            line(addon.L("REQUIREMENT_GROUPS"))
            line(addon.L("REQUIREMENT_NOTICE"))
        end
        for groupIndex, group in ipairs(q.requires or {}) do
            line(addon.L("REQUIREMENT_GROUP", groupIndex))
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
                        b:SetWidth(332); b.label = label(b, "", 3, -3, 326, 12)
                        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                        self.branchButtons[branchIndex] = b
                    end
                    b.questID, b.groupIndex, b.parentID = id, index, parent
                    b.label:SetText(chosen and addon.L("BRANCH_SELECTED", value) or value)
                    local height = math.max(30, measuredHeight(b.label, 18) + 6)
                    b:SetHeight(height); b:ClearAllPoints(); b:SetPoint("TOPLEFT", 4, -y)
                    b:SetEnabled(enabled)
                    b:SetScript("OnClick", enabled and function() self:ChooseBranch(id, index, parent) end or nil)
                    b:Show(); y = y + height + 3
                end
                option(addon.L("BRANCH_AUTO"), nil, true, selected == nil)
                for _, parentID in ipairs(group.ids) do
                    local parent, parentState = parentID, engine:State(parentID)
                    option(addon.QuestName(parent) .. " — " .. statusLabel(parentState), parent,
                        parentState.status ~= "UNAVAILABLE", parent == selected)
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
        line(addon.L((q.storyline or q.storylineGroups) and "STORY" or "CHAIN"))
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
                b.label = label(b, "", 3, -2, 326, 12)
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
            b:SetScript("OnClick", function() self:InspectQuest(qid) end)
            b:Show(); y = y + height + 3
        end
        if q.storylineGroups then
            line(addon.L("STORY_GROUP_NOTICE"))
            for groupIndex, group in ipairs(q.storylineGroups) do
                line(addon.L("STORY_GROUP", groupIndex))
                for _, stepID in ipairs(group) do visit(stepID, 0, true) end
            end
        elseif q.storyline then
            for _, stepID in ipairs(q.storyline) do visit(stepID, 0) end
        else visit(id, 0) end
        local materials = addon.Read(engine.CompletionSteps, "table", engine, id)
        if materials and #materials > 0 then
            line(addon.L("MATERIAL_QUESTS"))
            line(addon.L("MATERIAL_NOTICE"))
            for index, entry in ipairs(materials) do
                local other = entry.id
                local row = self:MakeRow(self.detail, self.materialButtons, index, 59)
                row.questID, row.itemID = other, entry.itemID
                row.title:SetText(addon.QuestName(other))
                local status = entry.state.status
                local count = carried(entry.itemID)
                row.note:SetText("|cff" .. COLOR[status] .. statusLabel(entry.state) .. "|r\n" ..
                    (addon.Read(addon.ItemName, "string", entry.itemID) or addon.L("MATERIAL_ITEM", entry.itemID)) ..
                    (entry.unknown and status ~= "UNKNOWN" and (" — " .. addon.L("UNKNOWN")) or "") ..
                    (count and ("\n" .. count) or ""))
                row:SetEnabled(true)
                row:SetScript("OnClick", function() self:InspectQuest(other) end)
                y = self:LayoutRow(row, 59, y)
            end
        end
        local objectiveItems = addon.Clean(q.objectiveItems, "table")
        local shownObjectives, seenItems = false, {}
        for index = 1, math.min(objectiveItems and #objectiveItems or 0, 100) do
            local entry = addon.Clean(objectiveItems[index], "table")
            local itemID = entry and addon.Clean(entry.itemID, "number")
            local quantity = entry and addon.Clean(entry.quantity, "number")
            if itemID and itemID > 0 and itemID <= 9007199254740991 and itemID % 1 == 0 and
                quantity and quantity > 0 and quantity <= 9007199254740991 and quantity % 1 == 0 and not seenItems[itemID] then
                seenItems[itemID] = true
                local name = addon.Read(addon.ItemName, "string", itemID)
                if self.quest ~= renderQuest or self.rewardGeneration ~= rewardGeneration then return end
                if not name or #name > 1024 or not name:find("%S") then
                    name = addon.Clean(entry.name, "string")
                    if not name or #name > 2000 or not name:find("%S") then name = string.format("#%.0f", itemID) end
                end
                local count = carried(itemID)
                if self.quest ~= renderQuest or self.rewardGeneration ~= rewardGeneration then return end
                if not shownObjectives then
                    line(addon.L("OBJECTIVE_ITEMS")); line(addon.L("OBJECTIVE_ITEMS_NOTICE")); shownObjectives = true
                end
                line(addon.L("OBJECTIVE_ITEM", name, quantity))
                if count then line(count) end
            end
        end
        line(addon.Description(id))
        local dialogueObjective
        if type(addon.DialogueObjectiveText) == "function" then
            dialogueObjective = addon.Read(addon.DialogueObjectiveText, "string", id)
        end
        if dialogueObjective and dialogueObjective ~= "" and #dialogueObjective <= 30000 then
            line(addon.L("OBJECTIVE_DIALOGUE"))
            line(dialogueObjective)
        end
        local objectives = addon.QuestObjectives and addon.QuestObjectives(id)
        if objectives and #objectives > 0 then line(addon.L("OBJECTIVE_PROGRESS")) end
        for _, objective in ipairs(objectives or {}) do
            line("|cff" .. (objective.finished and COLOR.COMPLETED or COLOR.ACTIVE) .. objective.text .. "|r")
        end
        local rewards, rewardOrigin = rewardData(id)
        if rewards and addon.Clean(rewards.source, "string") == "dialogue" then line(addon.L("REWARD_DIALOGUE"))
        elseif rewards and addon.Clean(rewards.source, "string") == "cache" then line(addon.L("REWARD_PREVIEW")) end
        local items = rewards and addon.Clean(rewards.items, "table")
        local choices = rewards and addon.Clean(rewards.choices, "table")
        if rewards and addon.Clean(rewards.hidden, "boolean") == true then
            line(addon.L("REWARD_HIDDEN"))
        elseif items and choices then
            if #items > 0 then
                line(addon.L("REWARD_ITEMS"))
                for index, item in ipairs(items) do
                    if line(addon.L("REWARD_ITEM", item.name, item.count), nil,
                        { item = item, origin = rewardOrigin, source = addon.Clean(rewards.source, "string"), kind = "items", index = index }) == false then return end
                end
            end
            if #choices > 0 then
                line(addon.L("REWARD_CHOICES"))
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
        line(addon.L("PICK")); self.map:SetEnabled(false); self.guide:SetEnabled(false); self.source:SetEnabled(false)
    end
    hideRest(pool, n)
    self.detail:SetHeight(math.max(1, y + 12))
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
    self.title = label(frame, addon.L("TITLE"), 22, -18, 360, 24)
    self.subtitle = label(frame, "", 22, -49, 500, 13)
    self.back = button(frame, addon.L("DETAIL_BACK"), 120, function() self:BackQuest() end)
    self.back:SetPoint("TOPLEFT", 560, -45)
    self.back:SetEnabled(false)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -4, -4)
    local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    search:SetSize(200, 25); search:SetPoint("TOPLEFT", 27, -84); search:SetAutoFocus(false)
    self.searchBox = search
    self.searchPlaceholder = label(search, "", 5, -5, 188, 11)
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
    self.searchHint = label(self.catalog, "", 4, 0, 220, 11)
    self.catalogNotice = label(self.catalog, "", 4, 0, 220, 13)
    self.questList, self.questScroll = scrolling(frame, 288, -218, 355, 425)
    self.detail, self.detailScroll = scrolling(frame, 690, -218, 350, 425)
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
    self.giver = button(frame, "", 195, function()
        if self.giverAction then
            if self.giverHasCoordinates then addon.Navigation.Start(self.giverAction)
            else addon.Navigation.Map(self.giverAction.place) end
        end
    end)
    self.giver:SetPoint("BOTTOMLEFT", 690, 19)
    self.capacityStatus = label(frame, "", 22, -646, 640, 11)
    self.capacityStatus:Hide()
    self.footer = label(frame, "", 22, -668, 640, 11)
    self.frame, self.cards, self.rows, self.details, self.chainButtons, self.branchButtons = frame, {}, {}, {}, {}, {}
    self.materialButtons = {}
    self.requirementButtons = {}
    self.startButtons, self.finishButtons, self.containerButtons = {}, {}, {}
    UISpecialFrames[#UISpecialFrames + 1] = "DungeonProWindow"
    for _, d in ipairs(addon.dungeons) do if d.key == addon.char.selectedDungeon then self.dungeon = d end end
    frame:SetScript("OnShow", function() self:Fit(); self:Refresh() end)
    frame:SetScript("OnHide", function() self:ResetRewardPresentation() end)
    frame:Hide()
end

function UI:Toggle()
    if not self.frame then self:Create() end
    self.frame:SetShown(not self.frame:IsShown())
end
addon.listeners[#addon.listeners + 1] = function() UI:Refresh() end
