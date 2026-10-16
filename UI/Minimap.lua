local _, addon = ...
local M = {}
addon.Minimap = M

local function cleanFrame(value)
    return addon.Clean(value, "table") or addon.Clean(value, "userdata")
end

local function method(value, key)
    return addon.Read(function() return value[key] end, "function")
end

local function angle(value)
    value = addon.Clean(value, "number")
    if value then return value % 360 end
end

function M:Current()
    return self.button and cleanFrame(Minimap) == self.parent and
        addon.Clean(addon.db, "table") == self.db and
        addon.Clean(self.db.minimap, "table") == self.persisted
end

function M:ReleaseTooltip(expected)
    local held = self.tooltip
    if not held or (expected and expected ~= held) then return end
    local owned = addon.Read(held.owned, "boolean", held.tip, held.button)
    if self.tooltip ~= held then return end
    self.tooltip = nil
    if owned == true and method(held.tip, "Hide") == held.hide then pcall(held.hide, held.tip) end
end

function M:Tooltip()
    if not self:Current() or self.drag or addon.Read(self.button.IsShown, "boolean", self.button) ~= true then return end
    local tip = cleanFrame(GameTooltip)
    if not tip then return end
    local held = { tip = tip, button = self.button, parent = self.parent,
        owner = method(tip, "SetOwner"), text = method(tip, "SetText"), line = method(tip, "AddLine"),
        show = method(tip, "Show"), owned = method(tip, "IsOwned"), hide = method(tip, "Hide") }
    if not held.owner or not held.text or not held.line or not held.show or not held.owned or not held.hide then return end
    self:ReleaseTooltip()
    if self.tooltip or not self:Current() then return end
    self.tooltip = held
    held.button:SetScript("OnLeave", function()
        if self.tooltip == held then self:ReleaseTooltip(held) end
    end)
    local function current()
        return self.tooltip == held and self.button == held.button and self.parent == held.parent and
            self:Current() and cleanFrame(GameTooltip) == tip and
            addon.Read(held.button.IsShown, "boolean", held.button) == true and
            method(tip, "SetOwner") == held.owner and method(tip, "SetText") == held.text and
            method(tip, "AddLine") == held.line and method(tip, "Show") == held.show and
            method(tip, "IsOwned") == held.owned and method(tip, "Hide") == held.hide
    end
    local function call(fn, ...)
        local ok = pcall(fn, tip, ...)
        return ok and current() and addon.Read(held.owned, "boolean", tip, held.button) == true and current()
    end
    if not call(held.owner, held.button, "ANCHOR_LEFT") or
        not call(held.text, addon.L("TITLE")) or not call(held.line, addon.L("MINIMAP_OPEN")) or
        not call(held.line, addon.L("MINIMAP_DRAG")) or not call(held.show) then self:ReleaseTooltip(held) end
end

function M:Place(value)
    local button, parent = self.button, self.parent
    value = angle(value)
    if not value or not self:Current() then return false end
    local width = addon.Read(method(parent, "GetWidth"), "number", parent)
    if not width or width <= 0 or not self:Current() or self.parent ~= parent or self.button ~= button then return false end
    local radius = width / 2 + 8
    local radians = math.rad(value)
    local x, y = math.cos(radians) * radius, math.sin(radians) * radius
    local ok = pcall(function()
        button:ClearAllPoints()
        button:SetPoint("CENTER", parent, "CENTER", x, y)
        local placed = method(button, "SetUserPlaced")
        if placed then placed(button, true) end
    end)
    if not ok or not self:Current() or self.button ~= button or self.parent ~= parent then return false end
    self.angle = value
    return true
end

function M:StopDrag(save, expected)
    local held = self.drag
    if not held or (expected and expected ~= held) then return end
    self.drag = nil
    held.button:SetScript("OnUpdate", nil)
    if save and self:Current() and self.button == held.button and self.parent == held.parent then
        local value = angle(self.angle)
        if value then self.config.angle = value end
    end
end

function M:StartDrag(mouse)
    if mouse ~= "LeftButton" or not self:Current() or
        addon.Read(self.button.IsShown, "boolean", self.button) ~= true then return end
    self:StopDrag(false)
    self:ReleaseTooltip()
    if not self:Current() then return end
    local parent, button = self.parent, self.button
    local held = { parent = parent, button = button, cursor = addon.Clean(GetCursorPosition, "function"),
        scale = method(parent, "GetEffectiveScale"), center = method(parent, "GetCenter"),
        atan = addon.Clean(math.atan2, "function"), checker = issecretvalue }
    if not held.cursor or not held.scale or not held.center or not held.atan then return end
    self.drag, self.suppressClick = held, true
    button:SetScript("OnDragStop", function() self:StopDrag(true, held) end)
    local function current()
        return self.drag == held and self:Current() and self.parent == parent and self.button == button and
            addon.Clean(GetCursorPosition, "function") == held.cursor and method(parent, "GetEffectiveScale") == held.scale and
            method(parent, "GetCenter") == held.center and addon.Clean(math.atan2, "function") == held.atan and
            issecretvalue == held.checker and addon.Read(button.IsShown, "boolean", button) == true
    end
    button:SetScript("OnUpdate", function()
        if not current() then self:StopDrag(false, held); return end
        local ok, x, y = pcall(held.cursor)
        x, y = addon.Clean(x, "number"), addon.Clean(y, "number")
        local scale = addon.Read(held.scale, "number", parent)
        local centerOK, cx, cy = pcall(held.center, parent)
        cx, cy = addon.Clean(cx, "number"), addon.Clean(cy, "number")
        if not ok or not centerOK or not x or not y or not scale or scale <= 0 or not cx or not cy or not current() then
            self:StopDrag(false, held); return
        end
        x, y = x / scale - cx, y / scale - cy
        if not addon.Clean(x, "number") or not addon.Clean(y, "number") then self:StopDrag(false, held); return end
        if x == 0 and y == 0 then return end
        local result = addon.Read(held.atan, "number", y, x)
        if not result or not current() or not self:Place(math.deg(result)) then self:StopDrag(false, held) end
    end)
end

function M:Initialize()
    local parent, db = cleanFrame(Minimap), addon.Clean(addon.db, "table")
    if not parent or not db or not method(parent, "GetWidth") then
        self:StopDrag(false); self:ReleaseTooltip()
        if self.button then self.button:Hide() end
        return false
    end
    self:StopDrag(false)
    self:ReleaseTooltip()
    local original = rawget(db, "minimap")
    local config = addon.Clean(original, "table")
    local readable = true
    if type(issecretvalue) == "function" then
        local ok, restricted = pcall(issecretvalue, original)
        readable = ok and addon.Clean(restricted, "boolean") == false
    end
    if readable and type(original) == "nil" then config = {}; db.minimap = config end
    local previousParent = self.parent
    self.db, self.parent, self.persisted = db, parent, config
    self.config = config or (self.ephemeral or {})
    if not config then self.ephemeral = self.config end
    local button = self.button
    if button then
        if previousParent ~= parent then
            local setter = method(button, "SetParent")
            if not setter or not pcall(setter, button, parent) then
                self.parent = nil
                button:Hide()
                return false
            end
        end
    else
        local ok
        ok, button = pcall(CreateFrame, "Button", "DungeonProMinimapButton", parent)
        if not ok or not cleanFrame(button) then return false end
        self.button = button
        button:SetSize(32, 32); button:EnableMouse(true); button:RegisterForClicks("LeftButtonUp")
        button:RegisterForDrag("LeftButton")
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        local rendered, success = pcall(icon.SetTexture, icon, "Interface\\Icons\\INV_Misc_Map_01")
        if rendered and addon.Clean(success, "boolean") == true then icon:Show()
        else
            icon:Hide()
            local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetAllPoints(); text:SetText("DP"); text:Show()
        end
    end
    local session = {}
    self.session = session
    local function current() return self.session == session and self.button == button and self:Current() end
    button:SetScript("OnMouseDown", function(_, mouse)
        if current() and mouse == "LeftButton" and not self.drag then self.suppressClick = nil end
    end)
    button:SetScript("OnClick", function(_, mouse)
        if not current() then return end
        if self.suppressClick then self.suppressClick = nil; return end
        if mouse == "LeftButton" and addon.UI and type(addon.UI.Toggle) == "function" then addon.UI:Toggle() end
    end)
    button:SetScript("OnDragStart", function(_, mouse) if current() then self:StartDrag(mouse) end end)
    button:SetScript("OnDragStop", function() if current() then self:StopDrag(true) end end)
    button:SetScript("OnEnter", function() if current() then self:Tooltip() end end)
    button:SetScript("OnLeave", function() if current() then self:ReleaseTooltip() end end)
    button:SetScript("OnHide", function()
        if self.session == session and self.button == button then
            self:StopDrag(false); self:ReleaseTooltip(); self.suppressClick = nil
        end
    end)
    if not self:Place(angle(self.config.angle) or 225) then button:Hide(); return false end
    if addon.Clean(self.config.hide, "boolean") == true then button:Hide() else button:Show() end
    return true
end

function M:ToggleVisibility()
    if not self:Current() and not self:Initialize() then return false end
    if addon.Clean(self.config.hide, "boolean") ~= true then
        self.config.hide = true
        self.button:Hide(); self:StopDrag(false); self:ReleaseTooltip()
    else
        if not self:Place(angle(self.config.angle) or 225) then self.button:Hide(); return false end
        self.config.hide = false
        self.button:Show()
    end
    return true
end

function M:Reset()
    if not self:Current() and not self:Initialize() then return false end
    self:StopDrag(false); self:ReleaseTooltip()
    if not self:Place(225) then self.button:Hide(); return false end
    self.config.angle, self.config.hide = 225, false
    self.button:Show()
    return true
end
