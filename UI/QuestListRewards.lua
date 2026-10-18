local _, addon = ...
local Rewards = {}
addon.QuestListRewards = Rewards
local states = setmetatable({}, { __mode = "k" })
local held, repairDepth, tooltipDepth
local showTooltip

local function integer(value)
    value = addon.Clean(value, "number")
    return value and value > 0 and value % 1 == 0 and value or nil
end

local function release(expected)
    local value = held or expected
    if not value or (expected and value ~= expected) then return end
    if value.tooltip.IsOwned ~= value.isOwned then
        if held == value then held = nil end
        if addon.TooltipLease then addon.TooltipLease.Retire(value.tooltip, value) end
        return
    end
    local owned = addon.Read(value.tooltip.IsOwned, "boolean", value.tooltip, value.button)
    if held and held ~= value then return end
    held = nil
    if addon.TooltipLease then addon.TooltipLease.Retire(value.tooltip, value) end
    if owned == true and value.tooltip.Hide == value.hide then
        pcall(value.hide, value.tooltip)
        if addon.TooltipLease then addon.TooltipLease.Restore(value.tooltip, value); return end
        local newest = held
        if newest and newest ~= value and newest.current() then showTooltip(newest) end
    end
end

local function current(row, state)
    if states[row] ~= state then return false end
    if state.owner and addon.Read(state.owner, "boolean") ~= true then return false end
    if states[row] ~= state then return false end
    if state.clear then return true end
    local ok, sameInset = pcall(function() return rawequal(row.navigationReserve, state.rawInset) end)
    if not ok or not sameInset then return false end
    return addon.CachedQuestRewards == state.provider and addon.char == state.character and
        addon.quests == state.catalogue and state.catalogue[state.id] == state.quest and
        GetLocale == state.localeGetter and issecretvalue == state.checker
end

local function visible(object)
    local seen = {}
    for _ = 1, 20 do
        if seen[object] then return false end
        seen[object] = true
        local getter = addon.Clean(object.IsVisible, "function")
        if getter then return addon.Read(getter, "boolean", object) == true end
        if addon.Read(object.IsShown, "boolean", object) ~= true then return false end
        -- Native frames expose IsVisible. Older adapters can expose ancestry
        -- instead; their own shown flag does not establish parent visibility.
        local parentGetter = addon.Clean(object.GetParent, "function")
        if not parentGetter then return true end
        local ok, parent = pcall(parentGetter, object)
        if not ok or object.GetParent ~= parentGetter then return false end
        if type(issecretvalue) == "function" and addon.Read(issecretvalue, "boolean", parent) ~= false then return false end
        if parent == nil then return true end
        object = addon.Clean(parent, "table") or addon.Clean(parent, "userdata")
        if not object then return false end
    end
    return false
end

showTooltip = function(value)
    if (tooltipDepth or 0) >= 3 then return end
    tooltipDepth = (tooltipDepth or 0) + 1
    local function apply(method, ...)
        if not value.current() then return false end
        local ok, result = pcall(method, value.tooltip, ...)
        local owned = addon.Read(value.isOwned, "boolean", value.tooltip, value.button)
        if not value.current() or owned ~= true then
            local newest = held
            if newest and newest ~= value and newest.current() then showTooltip(newest)
            else release(value) end
            return false
        end
        return ok and addon.Clean(result, "boolean") ~= false
    end
    if apply(value.owner, value.button, "ANCHOR_RIGHT") then
        local native = value.hyperlink and apply(value.hyperlink, "item:" .. value.itemID)
        if value.current() then
            local painted = native or apply(value.text, value.description)
            if native and value.addLine then
                for _, line in ipairs(value.lines) do
                    if not apply(value.addLine, line) then painted = false; break end
                end
            end
            if painted then
                if apply(value.show) and value.current() and addon.TooltipLease then
                    addon.TooltipLease.Retain(value.tooltip, value, function()
                        if not value.current() or addon.Read(value.state.localeGetter, "string") ~= value.state.locale or
                            not value.current() then return end
                        local ours = addon.Read(value.isOwned, "boolean", value.tooltip, value.button) == true
                        local ok, same = pcall(function()
                            local state = value.state
                            return held == value and states[state.row] == state and
                                addon.CachedQuestRewards == state.provider and addon.char == state.character and
                                addon.quests == state.catalogue and rawget(state.catalogue, state.id) == state.quest and
                                GetLocale == state.localeGetter and issecretvalue == state.checker and
                                GameTooltip == value.tooltip and value.tooltip.Show == value.show and value.tooltip.IsOwned == value.isOwned
                        end)
                        if ours and ok and same then pcall(value.show, value.tooltip) end
                    end)
                end
            else release(value) end
        end
    else release(value) end
    tooltipDepth = tooltipDepth - 1
end

local render
local function repair(row)
    if (repairDepth or 0) >= 3 then return end
    repairDepth = (repairDepth or 0) + 1
    local newest = states[row]
    if newest and current(row, newest) then render(row, newest) end
    repairDepth = repairDepth - 1
end

local function write(row, state, object, method, ...)
    if not current(row, state) then return false end
    local fn = addon.Clean(object and object[method], "function")
    if not fn then return false end
    local ok, result = pcall(fn, object, ...)
    if not current(row, state) then repair(row); return false end
    return ok and (method ~= "SetTexture" or addon.Clean(result, "boolean") ~= false)
end

local function enter(row, state, button, item)
    if not current(row, state) or not visible(row) or not visible(button) then return end
    if state.localeGetter and addon.Read(state.localeGetter, "string") ~= state.locale then return end
    if not current(row, state) then return end
    local tooltip = addon.Clean(GameTooltip, "table") or addon.Clean(GameTooltip, "userdata")
    if not tooltip then return end
    local owner, text, show, hide, owned = tooltip.SetOwner, tooltip.SetText, tooltip.Show, tooltip.Hide, tooltip.IsOwned
    local hyperlink, addLine = addon.Clean(tooltip.SetHyperlink, "function"), addon.Clean(tooltip.AddLine, "function")
    if type(owner) ~= "function" or type(text) ~= "function" or type(show) ~= "function" or
        type(hide) ~= "function" or type(owned) ~= "function" then return end
    release()
    if held or not current(row, state) then return end
    local lines = {}
    for _, group in ipairs({ { state.fixed, "REWARD_ITEMS" }, { state.choices, "REWARD_CHOICES" } }) do
        if #group[1] > 0 then
            local label = addon.Read(addon.L, "string", group[2])
            if not label or not current(row, state) then return end
            if #lines > 0 then lines[#lines + 1] = "" end
            lines[#lines + 1] = label:gsub("|", "||")
            for _, reward in ipairs(group[1]) do
                local texture, icon = reward.texture, ""
                if type(texture) == "number" or (type(texture) == "string" and not texture:find("[|:%c]")) then
                    icon = "|T" .. texture .. ":18:18:0:0|t "
                end
                lines[#lines + 1] = icon .. reward.name:gsub("|", "||") .. (reward.count > 1 and (" ×" .. reward.count) or "")
            end
        end
    end
    if not current(row, state) or #lines == 0 then return end
    local value = { tooltip = tooltip, button = button, hide = hide, state = state,
        owner = owner, text = text, show = show, isOwned = owned,
        hyperlink = hyperlink, addLine = addLine, itemID = item.id, lines = lines }
    held = value
    local function fresh()
        return held == value and current(row, state) and visible(row) and visible(button) and
            held == value and current(row, state) and GameTooltip == tooltip and tooltip.SetOwner == owner and
            tooltip.SetText == text and tooltip.Show == show and tooltip.Hide == hide and tooltip.IsOwned == owned and
            addon.Clean(tooltip.SetHyperlink, "function") == hyperlink and addon.Clean(tooltip.AddLine, "function") == addLine
    end
    value.current = fresh
    value.description = table.concat(lines, "\n")
    -- The complete cached list preserves fixed rewards and choose-one options.
    -- Native item tooltips may hydrate item data; quest rewards stay cached.
    showTooltip(value)
end

render = function(row, state)
    for index = 1, 3 do
        if not current(row, state) then return false end
        local item, button = state.items[index], state.buttons[index]
        if item and not button then
            button = addon.Read(CreateFrame, "table", "Button", nil, row)
            if not button then return false end
            if not current(row, state) then return false end
            local icon = addon.Read(button.CreateTexture, "table", button, nil, "ARTWORK")
            if not icon or not current(row, state) then
                if type(button.Hide) == "function" then pcall(button.Hide, button) end
                return false
            end
            button.icon, state.buttons[index] = icon, button
        end
        if button then
            if item then
                if not write(row, state, button, "SetSize", 20, 20) or
                    not write(row, state, button, "ClearAllPoints") or
                    not write(row, state, button, "SetPoint", "TOPRIGHT", row, "TOPRIGHT", -6 - state.rightInset - (index - 1) * 22, -5) or
                    not write(row, state, button.icon, "SetAllPoints", button) or
                    not write(row, state, button.icon, "SetTexture", item.texture) or
                    not write(row, state, button.icon, "Show") or
                    not write(row, state, button, "SetScript", "OnEnter", function() enter(row, state, button, item) end) or
                    not write(row, state, button, "SetScript", "OnLeave", function()
                        if held and held.state == state and held.button == button then release(held) end
                    end) or
                    not write(row, state, button, "SetScript", "OnHide", function()
                        if held and held.state == state and held.button == button then release(held) end
                    end) or not write(row, state, button, "Show") then return false end
                local more = index == #state.items and state.total and state.total - #state.items or 0
                local overflow = button.overflowLabel
                if more > 0 and not overflow then
                    local ok, value = pcall(button.CreateFontString, button, nil, "OVERLAY")
                    overflow = ok and (addon.Clean(value, "table") or addon.Clean(value, "userdata"))
                    if not current(row, state) then repair(row); return false end
                    if not overflow then return false end
                    button.overflowLabel = overflow
                end
                if overflow then
                    if more > 0 then
                        local theme = addon.Clean(addon.Theme, "table")
                        local font = theme and addon.Clean(theme.ApplyFont, "function")
                        local fontOK, fontResult
                        if font then fontOK, fontResult = pcall(font, overflow, 10) end
                        local applied = fontOK and (addon.Clean(fontResult, "string") or
                            addon.Clean(fontResult, "table") or addon.Clean(fontResult, "userdata"))
                        if not current(row, state) then repair(row); return false end
                        for _, operation in ipairs({ { "SetTextColor", 1, 1, 1, 1 },
                            { "SetShadowColor", 0, 0, 0, 1 }, { "SetShadowOffset", 1, -1 } }) do
                            if addon.Clean(overflow[operation[1]], "function") and
                                not write(row, state, overflow, operation[1], unpack(operation, 2)) then return false end
                        end
                        if not applied then
                            local fallback = addon.Clean(GameFontNormalSmall, "table") or addon.Clean(GameFontNormalSmall, "userdata")
                            if not fallback or not write(row, state, overflow, "SetFontObject", fallback) then return false end
                        end
                        if not current(row, state) then repair(row); return false end
                        if not write(row, state, overflow, "ClearAllPoints") or
                            not write(row, state, overflow, "SetPoint", "BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1) or
                            not write(row, state, overflow, "SetWidth", 28) or
                            not write(row, state, overflow, "SetJustifyH", "RIGHT") or
                            not write(row, state, overflow, "SetText", "+" .. more) or
                            not write(row, state, overflow, "Show") then return false end
                    elseif not write(row, state, overflow, "Hide") then return false end
                end
            else
                if button.overflowLabel and not write(row, state, button.overflowLabel, "Hide") then return false end
                if not write(row, state, button, "SetScript", "OnEnter", nil) or
                    not write(row, state, button, "SetScript", "OnLeave", nil) or
                    not write(row, state, button, "SetScript", "OnHide", nil) or
                    not write(row, state, button, "Hide") or
                    not write(row, state, button.icon, "Hide") or
                    not write(row, state, button.icon, "SetTexture", nil) then return false end
            end
        end
    end
    return current(row, state)
end

function Rewards.Clear(row)
    if not row then return end
    local prior = states[row]
    local state = { clear = true, items = {}, fixed = {}, choices = {}, buttons = prior and prior.buttons or {} }
    states[row] = state
    if held and held.state == prior then release(held) end
    if states[row] == state then render(row, state) end
end

function Rewards.Pending(row)
    local state = row and states[row]
    if state and state.pending == true and current(row, state) then return state.id end
end

function Rewards.Paint(row, id, ownerCurrent)
    if not row then return 0 end
    local prior = states[row]
    local insetOK, rawInset = pcall(function() return row.navigationReserve end)
    if not insetOK then return 0 end
    local rightInset = addon.Clean(rawInset, "number")
    if not (rightInset and rightInset >= 0 and rightInset <= 1000 and rightInset % 1 == 0) then rightInset = 0 end
    local state = { row = row, items = {}, fixed = {}, choices = {}, total = 0, buttons = prior and prior.buttons or {}, id = integer(id), owner = ownerCurrent,
        rawInset = rawInset, rightInset = rightInset,
        provider = addon.CachedQuestRewards, character = addon.char, catalogue = addon.quests,
        localeGetter = GetLocale, checker = issecretvalue }
    state.quest = state.id and state.catalogue[state.id]
    states[row] = state
    if held and held.state == prior then release(held) end
    if not current(row, state) then return 0 end
    state.locale = addon.Read(state.localeGetter, "string")
    if not current(row, state) then return 0 end
    local data
    local provider = state.quest and addon.Clean(state.provider, "function")
    if not current(row, state) then return 0 end
    if provider then
        local ok, value = pcall(provider, state.id)
        if not current(row, state) then return 0 end
        local readable = type(state.checker) ~= "function" or addon.Read(state.checker, "boolean", value) == false
        if ok and readable then
            state.pending = value == nil
            data = addon.Clean(value, "table")
        end
    end
    if not current(row, state) then return 0 end
    local hiddenReadable = not data or type(state.checker) ~= "function" or addon.Read(state.checker, "boolean", data.hidden) == false
    local hidden = data and addon.Clean(data.hidden, "boolean")
    if data and hiddenReadable and addon.Clean(data.source, "string") == "cache" and hidden ~= true then
        for _, kind in ipairs({ "items", "choices" }) do
            local entries = addon.Clean(data[kind], "table")
            if entries and #entries <= 100 then
                for index = 1, #entries do
                    local value = addon.Clean(entries[index], "table")
                    local itemID = value and integer(value.id)
                    local name = value and addon.Clean(value.name, "string")
                    local count = value and integer(value.count)
                    local texture = value and (integer(value.texture) or addon.Clean(value.texture, "string"))
                    if itemID and name and #name <= 30000 and name:find("%S") and count then
                        if type(texture) == "string" and (#texture > 1024 or not texture:find("%S")) then texture = nil end
                        local item = { id = itemID, name = name, count = count, texture = texture, choice = kind == "choices" }
                        local group = kind == "choices" and state.choices or state.fixed
                        group[#group + 1] = item; state.total = state.total + 1
                        if texture and #state.items < 3 then state.items[#state.items + 1] = item end
                    end
                end
            end
        end
    end
    if not render(row, state) then
        if states[row] == state then Rewards.Clear(row) end
        return 0
    end
    return #state.items > 0 and (#state.items * 22 + 4) or 0
end
