local addon, total, calls, row, tooltip, secret = {}, 0, 0, nil, nil, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
local function frame()
    local f = { shown = true, scripts = {} }
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:ClearAllPoints() self.point = nil end
    function f:SetPoint(...) self.point = { ... } end
    function f:SetAllPoints(value) self.allPoints = value end
    function f:SetTexture(value) self.texture = value; return true end
    function f:SetScript(kind, fn) self.scripts[kind] = fn end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide() end end
    function f:IsShown() return self.shown end
    function f:CreateTexture() self.textureObject = frame(); return self.textureObject end
    return f
end
local buttons, payload
local function reset()
    buttons, calls = {}, 0
    issecretvalue = function(v) return v == secret end
    GetLocale = function() return "enUS" end
    addon.char, addon.quests = {}, { [1] = {}, [2] = {} }
    addon.L = function(key) return key == "REWARD_CHOICES" and "Choose one" or "Rewards" end
    payload = { source = "cache", items = { { id = 10, name = "Sword", count = 1, texture = 123 } }, choices = {} }
    addon.CachedQuestRewards = function(id) calls = calls + 1; assert(id == 1 or id == 2); return payload end
    addon.QuestRewards = function() error("selected log must never be queried") end
    addon.DialogueRewards = function() error("dialogue must never be queried") end
    RequestLoadQuestByID = function() error("no reward requests") end
    CreateFrame = function(_, _, parent) local f = frame(); f.parent = parent; buttons[#buttons + 1] = f; return f end
    row = frame()
    tooltip = frame()
    function tooltip:SetOwner(button) self.owner = button end
    function tooltip:IsOwned(button) return self.owner == button end
    function tooltip:SetText(value) self.text = value end
    function tooltip:SetItemByID() error("hover must not load items") end
    GameTooltip = tooltip
    assert(loadfile("UI/QuestListRewards.lua"))("DungeonPro", addon)
    return addon.QuestListRewards
end
local function check(name, fn)
    local ok, err = pcall(fn); assert(ok, name .. ": " .. tostring(err)); total = total + 1; print("PASS " .. name)
end
check("Cached-only reward paint reserves compact title space and never changes quest selection", function()
    local r = reset(); assert(r.Paint(row, 1, function() return true end) == 26)
    assert(calls == 1 and #buttons == 1 and buttons[1].width == 20 and buttons[1].height == 20)
    assert(buttons[1].icon.texture == 123 and buttons[1].point[1] == "TOPRIGHT" and buttons[1].point[4] == -6)
end)
check("Only three actual cached textures paint with fixed-before-choice provenance", function()
    local r = reset(); payload.items[2] = { id = 11, name = "No icon", count = 1 }
    payload.choices = { { id = 12, name = "Hat", count = 2, texture = "hat" },
        { id = 13, name = "Boots", count = 1, texture = 456 }, { id = 14, name = "Ring", count = 1, texture = 789 } }
    assert(r.Paint(row, 1) == 70 and #buttons == 3)
    assert(buttons[2].icon.texture == "hat" and buttons[3].icon.texture == 456)
    buttons[2].scripts.OnEnter(); assert(tooltip.text == "Hat ×2\nChoose one" and calls == 1)
end)
check("Missing hidden or foreign-origin rewards never invent an icon and clear recycled rows", function()
    for _, value in ipairs({ {}, { source = "cache", hidden = true }, { source = "dialogue" } }) do
        local r = reset(); r.Paint(row, 1); payload = value
        assert(r.Paint(row, 2) == 0 and not buttons[1].shown and not buttons[1].icon.shown)
        assert(buttons[1].icon.texture == nil and buttons[1].scripts.OnEnter == nil)
    end
end)
check("Malformed restricted and excessive payloads cannot authorize icon layout", function()
    for _, field in ipairs({ "id", "name", "count", "texture" }) do
        local r = reset(); payload.items[1][field] = secret; assert(r.Paint(row, 1) == 0)
    end
    local r = reset(); for i = 2, 101 do payload.items[i] = payload.items[1] end
    assert(r.Paint(row, 1) == 0)
    r = reset(); payload.hidden = secret; assert(r.Paint(row, 1) == 0)
end)
check("Unknown catalogue quests skip provider and expired owner prevents allocation", function()
    local r = reset(); assert(r.Paint(row, 999) == 0 and calls == 0)
    assert(r.Paint(row, 1, function() return false end) == 0 and calls == 0 and #buttons == 0)
end)
check("Hover only uses cached names and expired catalogue provider locale and character bindings do nothing", function()
    for _, change in ipairs({ function() addon.quests[1] = {} end, function() addon.char = {} end,
        function() addon.CachedQuestRewards = function() error("no hover reads") end end,
        function() GetLocale = function() return "koKR" end end }) do
        local r = reset(); r.Paint(row, 1); local enter = buttons[1].scripts.OnEnter
        tooltip.shown = false; change(); enter(); assert(not tooltip.shown and tooltip.text == nil and calls == 1)
    end
end)
check("Clear hides only the held owned tooltip and retained callbacks cannot reopen it", function()
    local r = reset(); r.Paint(row, 1); local enter = buttons[1].scripts.OnEnter
    enter(); assert(tooltip.owner == buttons[1]); r.Clear(row); assert(not tooltip.shown and not buttons[1].shown)
    enter(); assert(not tooltip.shown)
    r.Paint(row, 1); buttons[1].scripts.OnEnter(); tooltip.owner = {}; tooltip.shown = true
    r.Clear(row); assert(tooltip.shown)
end)
check("Provider reentry cannot publish old rewards into a newer row", function()
    local r = reset(); local once
    addon.CachedQuestRewards = function()
        if not once then once = true; r.Paint(row, 2); return { source = "cache", items = { { id = 99, name = "Old", count = 1, texture = 999 } } } end
        return payload
    end
    assert(r.Paint(row, 1) == 0); assert(#buttons == 1 and buttons[1].icon.texture == 123)
end)
check("Late native texture writes restore a newer paint and clear", function()
    for _, clear in ipairs({ false, true }) do
        local r = reset(); r.Paint(row, 1); local icon = buttons[1].icon; local original, once = icon.SetTexture
        icon.SetTexture = function(self, value)
            if not once then
                once = true
                if clear then r.Clear(row) else payload.items[1].texture = 456; r.Paint(row, 2) end
            end
            return original(self, value)
        end
        assert(r.Paint(row, 1) == 0)
        assert(icon.texture == (not clear and 456 or nil))
        assert(buttons[1].shown == not clear)
    end
end)
check("Native hide reentry preserves a newer reward icon", function()
    local r = reset(); r.Paint(row, 1); local button = buttons[1]; local original, once = button.Hide
    button.Hide = function(self)
        if not once then once = true; r.Paint(row, 2) end
        original(self)
    end
    r.Clear(row); assert(button.shown and button.icon.shown and button.icon.texture == 123)
end)
check("Late native tooltip text restores the newer icon tooltip", function()
    local r = reset(); r.Paint(row, 1); local original, once = tooltip.SetText
    tooltip.SetText = function(self, value)
        if not once then
            once = true; payload.items[1].name = "New sword"; r.Paint(row, 2); buttons[1].scripts.OnEnter()
        end
        original(self, value)
    end
    buttons[1].scripts.OnEnter(); assert(tooltip.text == "New sword\nRewards" and tooltip.shown)
end)
check("Partial icon creation remains retryable without retaining a broken button", function()
    local r = reset(); local native, once = CreateFrame
    CreateFrame = function(...)
        local button = native(...)
        if not once then once = true; button.CreateTexture = function() return nil end end
        return button
    end
    assert(r.Paint(row, 1) == 0 and not buttons[1].shown)
    assert(r.Paint(row, 1) == 26 and #buttons == 2 and buttons[2].icon.texture == 123)
end)
check("Late tooltip hide restores the newer icon owner without querying rewards on hover", function()
    local r = reset(); r.Paint(row, 1); buttons[1].scripts.OnEnter()
    local original, once = tooltip.Hide
    tooltip.Hide = function(self)
        if not once then
            once = true; payload.items[1].name = "Newest"; r.Paint(row, 2); buttons[1].scripts.OnEnter()
        end
        original(self)
    end
    -- The held contract refuses replacement methods, so acquire the replacement first.
    buttons[1].scripts.OnEnter(); local leave = buttons[1].scripts.OnLeave
    leave(); assert(tooltip.shown and tooltip.text == "Newest\nRewards")
end)
check("A foreign tooltip takeover inside SetText cannot be shown or hidden by an old icon", function()
    local r = reset(); r.Paint(row, 1)
    tooltip.SetText = function(self, value) self.text = value; self.owner = {}; self.shown = false end
    buttons[1].scripts.OnEnter(); assert(not tooltip.shown)
end)
check("Hidden ancestor icons cannot open tooltips through retained callbacks", function()
    local r = reset(); r.Paint(row, 1); local enter = buttons[1].scripts.OnEnter
    row.IsVisible = function() return false end
    enter(); assert(tooltip.text == nil)
    row.IsVisible = function() return secret end
    enter(); assert(tooltip.text == nil)
    row.IsVisible = nil
    local parent = frame(); parent:Hide(); row.GetParent = function() return parent end
    enter(); assert(tooltip.text == nil)
    parent:Show(); enter(); assert(tooltip.text == "Sword\nRewards")
end)
check("A failed replacement texture hides recycled rewards instead of leaking the old quest icon", function()
    for _, fail in ipairs({ function() error("native texture failure") end, function() return false end }) do
        local r = reset(); r.Paint(row, 1); local button = buttons[1]
        button.icon.SetTexture = fail
        payload.items[1] = { id = 22, name = "New", count = 1, texture = 456 }
        assert(r.Paint(row, 2) == 0)
        assert(not button.shown and not button.icon.shown and button.scripts.OnEnter == nil)
    end
end)
print("Quest list reward checks passed: " .. total .. " (modeled, no native layout proof)")
