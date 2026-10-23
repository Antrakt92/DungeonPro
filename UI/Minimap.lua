local _, addon = ...
local M = {}
addon.Minimap = M

local function cleanFrame(value)
    return addon.Clean(value, "table") or addon.Clean(value, "userdata")
end

local function method(value, key)
    return addon.Read(function() return value[key] end, "function")
end

local function setScript(button, name, fn)
    local setter = method(button, "SetScript")
    if not setter then return false end
    return pcall(setter, button, name, fn)
end

local function angle(value)
    value = addon.Clean(value, "number")
    if value then return value % 360 end
end

local function legacyConfig(config)
    local value = rawget(config, "launcherVersion")
    if type(issecretvalue) == "function" then
        local ok, restricted = pcall(issecretvalue, value)
        if not ok or addon.Clean(restricted, "boolean") ~= false then return false end
    end
    return type(value) == "nil" and type(rawget(config, "launcherVersion")) == "nil"
end

function M:RetryPlacement(db, held)
    if not db or addon.Minimap ~= self or addon.Clean(addon.db, "table") ~= db then return end
    local config = addon.Clean(rawget(db, "minimap"), "table")
    if config and addon.Clean(config.hide, "boolean") == true and not legacyConfig(config) then self.retry = nil; return end
    if not held then
        local timer = addon.Clean(C_Timer, "table")
        local after = timer and method(timer, "After")
        if not after then return end
        held = { db = db, config = config, parent = cleanFrame(Minimap), session = self.session, timer = timer, after = after, attempts = 0 }
        self.retry = held
    end
    local function current()
        return addon.Minimap == self and self.retry == held and addon.Clean(addon.db, "table") == db and
            addon.Clean(rawget(db, "minimap"), "table") == held.config and self.session == held.session and
            (not held.parent or cleanFrame(Minimap) == held.parent) and C_Timer == held.timer and
            method(held.timer, "After") == held.after
    end
    if not current() or held.attempts >= 8 then if self.retry == held then self.retry = nil end; return end
    held.attempts = held.attempts + 1
    local ok = pcall(held.after, .25, function()
        if not current() then return end
        if held.config and addon.Clean(held.config.hide, "boolean") == true and not legacyConfig(held.config) then self.retry = nil; return end
        if current() then self:Initialize(held) end
    end)
    if not ok and self.retry == held then self.retry = nil end
end

function M:StyleLauncher()
    local button, parent = self.button, self.parent
    local db, config, session = self.db, self.persisted, self.session
    local function current()
        return addon.Minimap == self and self.button == button and self.parent == parent and self.db == db and
            self.persisted == config and self.session == session and self:Current()
    end
    if not current() then return false end
    local strata = method(button, "SetFrameStrata")
    if not current() then return false end
    if strata then pcall(strata, button, "MEDIUM") end
    if not current() then return false end
    local level = addon.Read(method(parent, "GetFrameLevel"), "number", parent)
    local setter = method(button, "SetFrameLevel")
    if not current() then return false end
    if level and level >= 0 and level <= 99990 and level % 1 == 0 and setter then pcall(setter, button, level + 10) end
    if not current() then return false end
    local clamp = method(button, "SetClampedToScreen")
    if not current() then return false end
    if clamp then pcall(clamp, button, true) end
    return current()
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
    if addon.TooltipLease then addon.TooltipLease.Retire(held.tip, held) end
    if owned == true and method(held.tip, "Hide") == held.hide then
        pcall(held.hide, held.tip)
        if addon.TooltipLease then addon.TooltipLease.Restore(held.tip, held) end
    end
end

function M:Tooltip()
    if not self:Current() or self.drag or addon.Read(self.button.IsShown, "boolean", self.button) ~= true then return end
    local tip = cleanFrame(GameTooltip)
    if not tip then return end
    local db, config, session, localize = self.db, self.persisted, self.session, addon.L
    local rawConfig = rawget(db, "minimap")
    local locale, checker = rawget(db, "locale"), issecretvalue
    local held = { tip = tip, button = self.button, parent = self.parent,
        owner = method(tip, "SetOwner"), text = method(tip, "SetText"), line = method(tip, "AddLine"),
        show = method(tip, "Show"), owned = method(tip, "IsOwned"), hide = method(tip, "Hide") }
    if not held.owner or not held.text or not held.line or not held.show or not held.owned or not held.hide then return end
    self:ReleaseTooltip()
    if self.tooltip or not self:Current() then return end
    self.tooltip = held
    if not setScript(held.button, "OnLeave", function()
        if self.tooltip == held then self:ReleaseTooltip(held) end
    end) then self:ReleaseTooltip(held); return end
    local function current()
        return self.tooltip == held and self.button == held.button and self.parent == held.parent and
            self.db == db and self.persisted == config and self.session == session and addon.L == localize and
            rawequal(rawget(db, "locale"), locale) and issecretvalue == checker and
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
        not call(held.line, addon.L("MINIMAP_DRAG")) or not call(held.show) then self:ReleaseTooltip(held); return end
    if addon.TooltipLease then
        local function restore()
            if not current() then return end
            local ours = addon.Read(held.owned, "boolean", tip, held.button) == true
            local ok, same = pcall(function()
                return addon.Minimap == self and self.tooltip == held and self.button == held.button and
                    self.parent == held.parent and Minimap == held.parent and self.db == db and addon.db == db and
                    self.persisted == config and rawequal(rawget(db, "minimap"), rawConfig) and self.session == session and
                    addon.L == localize and rawequal(rawget(db, "locale"), locale) and issecretvalue == checker and
                    GameTooltip == tip and tip.Show == held.show and tip.IsOwned == held.owned
            end)
            if ours and ok and same then pcall(held.show, tip) end
        end
        addon.TooltipLease.Retain(tip, held, restore)
    end
end

function M:Place(value)
    local button, parent = self.button, self.parent
    value = angle(value)
    if not value or not self:Current() then return false end
    local binding = { session = self.session }
    self.placement = binding
    local function current()
        return self.placement == binding and self.session == binding.session and
            self:Current() and self.parent == parent and self.button == button
    end
    binding.current = current
    local width = addon.Read(method(parent, "GetWidth"), "number", parent)
    if not current() then return false, "superseded" end
    if not width or width <= 0 then return false end
    local heightGetter = method(parent, "GetHeight")
    local height = heightGetter and addon.Read(heightGetter, "number", parent)
    if not current() then return false, "superseded" end
    if heightGetter and (not height or height <= 0) then return false end
    local radius = width / 2 + 8
    local radians = math.rad(value)
    local x, y = math.cos(radians) * radius, math.sin(radians) * radius
    local function apply()
        if not current() then return end
        button:ClearAllPoints()
        if not current() then return end
        button:SetPoint("CENTER", parent, "CENTER", x, y)
    end
    binding.apply = apply
    local ok = pcall(apply)
    if not current() then
        local newer = self.placement
        if newer and newer ~= binding and newer.apply and not newer.repairing and newer.current() then
            newer.repairing = true
            if self.placement == newer and newer.current() then pcall(newer.apply) end
            newer.repairing = nil
        end
        return false, "superseded"
    end
    if not ok then return false end
    self.angle = value
    return true
end

-- Keep the latest launcher visibility intent on the physical button so a late
-- native write can repair a newer initialization without reviving an old session.
function M:SetVisible(shown)
    local button, parent, config, session = self.button, self.parent, self.config, self.session
    if not button or addon.Minimap ~= self then return false end
    local held = { shown = shown }
    local function current()
        return addon.Minimap == self and self.button == button and self.parent == parent and
            self.config == config and self.session == session and button.launcherVisibility == held and
            (not shown or self:Current())
    end
    held.current = current
    button.launcherVisibility = held
    local function apply()
        if not current() then return false end
        local setter = method(button, shown and "Show" or "Hide")
        if not setter or not current() then return false end
        button.launcherVisibilityWriting = (button.launcherVisibilityWriting or 0) + 1
        local ok = pcall(setter, button)
        button.launcherVisibilityWriting = button.launcherVisibilityWriting - 1
        return ok
    end
    held.apply = apply
    local ok = apply()
    if not current() then
        local newer = button.launcherVisibility
        if newer and newer ~= held and newer.current() and not newer.repairing then
            newer.repairing = true
            if button.launcherVisibility == newer and newer.current() then newer.apply() end
            newer.repairing = nil
        end
        return false
    end
    return ok
end

function M:HideForPlacement()
    local button, parent, config, session = self.button, self.parent, self.config, self.session
    if not self:SetVisible(false) then return false end
    local intent = button.launcherVisibility
    local held = self.sizeHooks and self.sizeHooks[parent]
    local hidden = addon.Clean(config and config.hide, "boolean")
    if held and held.active and hidden ~= true and addon.Minimap == self and self:Current() and
        self.button == button and self.parent == parent and self.config == config and self.session == session and
        button.launcherVisibility == intent and intent and intent.current() then
        held.hiddenForSize = intent
    end
    return true
end

function M:WatchSize()
    local parent = self.parent
    local hook, has = method(parent, "HookScript"), method(parent, "HasScript")
    if not hook or not has or addon.Read(has, "boolean", parent, "OnSizeChanged") ~= true then return true end
    if addon.Minimap ~= self or self.parent ~= parent or not self:Current() then return false end
    self.sizeHooks = self.sizeHooks or setmetatable({}, {__mode="k"})
    if self.sizeHooks[parent] then return true end
    local held = {}
    self.sizeHooks[parent] = held
    local ok, result = pcall(hook, parent, "OnSizeChanged", function()
        if not held.active or held.running or addon.Minimap ~= self or self.sizeHooks[parent] ~= held or
            self.parent ~= parent or not self:Current() then return end
        local button, config, session = self.button, self.config, self.session
        local function current()
            return addon.Minimap == self and self.sizeHooks[parent] == held and self.parent == parent and
                self.button == button and self.config == config and self.session == session and self:Current()
        end
        held.running = true
        pcall(function()
            if addon.Clean(config.hide, "boolean") == true then held.hiddenForSize = nil; return end
            local shown = addon.Read(method(button, "IsShown"), "boolean", button)
            if not current() then return end
            local placed, reason = self:Place(angle(self.angle) or angle(config.angle) or 225)
            if not current() then return end
            if not placed then
                if reason ~= "superseded" and shown == true then
                    self:HideForPlacement()
                    self:RetryPlacement(self.db)
                end
            elseif held.hiddenForSize then
                local hidden = held.hiddenForSize
                held.hiddenForSize = nil
                if button.launcherVisibility == hidden and hidden.current() and
                    addon.Clean(config.hide, "boolean") ~= true and current() then self:SetVisible(true) end
            end
        end)
        held.running = nil
    end)
    -- Registration is optional. Keep a failed record inert instead of risking
    -- duplicate native hooks when a provider installs a callback and then throws.
    held.active = ok and addon.Clean(result, "boolean") ~= false
    return addon.Minimap == self and self.parent == parent and self:Current()
end

function M:StopDrag(save, expected)
    local held = self.drag
    if not held or (expected and expected ~= held) then return end
    self.drag = nil
    if not setScript(held.button, "OnUpdate", nil) then return false end
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
    if not setScript(button, "OnDragStop", function() self:StopDrag(true, held) end) then
        self.drag, self.suppressClick = nil, nil
        setScript(button, "OnDragStop", nil)
        return
    end
    local function current()
        return self.drag == held and self:Current() and self.parent == parent and self.button == button and
            addon.Clean(GetCursorPosition, "function") == held.cursor and method(parent, "GetEffectiveScale") == held.scale and
            method(parent, "GetCenter") == held.center and addon.Clean(math.atan2, "function") == held.atan and
            issecretvalue == held.checker and addon.Read(button.IsShown, "boolean", button) == true
    end
    if not setScript(button, "OnUpdate", function()
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
    end) then
        self.drag, self.suppressClick = nil, nil
        setScript(button, "OnDragStop", nil)
        setScript(button, "OnUpdate", nil)
        return
    end
end

function M:Initialize(retry)
    if retry then if self.retry ~= retry then return false end else self.retry = nil end
    local parent, db = cleanFrame(Minimap), addon.Clean(addon.db, "table")
    if not parent or not db or not method(parent, "GetWidth") then
        self:StopDrag(false); self:ReleaseTooltip()
        if self.button then self:SetVisible(false) end
        self:RetryPlacement(db, retry)
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
    if retry and retry.config == nil and type(original) == "nil" and config then retry.config = config end
    local previousParent = self.parent
    self.db, self.parent, self.persisted = db, parent, config
    self.config = config or (self.ephemeral or {})
    if not config then self.ephemeral = self.config end
    if config and legacyConfig(config) and self.db == db and addon.db == db and addon.Minimap == self and
        addon.Clean(rawget(db, "minimap"), "table") == config then
        config.hide, config.launcherVersion = false, 1
    end
    local button = self.button
    if button then
        if previousParent ~= parent then
            local setter = method(button, "SetParent")
            if not setter or not pcall(setter, button, parent) then
                self.parent = nil
                self:SetVisible(false)
                return false
            end
        end
    else
        local ok
        ok, button = pcall(CreateFrame, "Button", "DungeonProMinimapButton", parent)
        if not ok or not cleanFrame(button) then return false end
        self.button = button
        do
            local sizeFn = method(button, "SetSize")
            local mouseFn = method(button, "EnableMouse")
            local clicksFn = method(button, "RegisterForClicks")
            local dragFn = method(button, "RegisterForDrag")
            if not sizeFn or not mouseFn or not clicksFn or not dragFn then return false end
            if not pcall(sizeFn, button, 32, 32) then return false end
            if not pcall(mouseFn, button, true) then return false end
            if not pcall(clicksFn, button, "LeftButtonUp") then return false end
            if not pcall(dragFn, button, "LeftButton") then return false end
        end
        local function fallbackLabel()
            local create = method(button, "CreateFontString")
            if not create then return false end
            local okF, text = pcall(create, button, nil, "OVERLAY", "GameFontNormal")
            if not okF or not cleanFrame(text) then return false end
            local points = method(text, "SetAllPoints")
            local setText = method(text, "SetText")
            local show = method(text, "Show")
            if not points or not setText or not show then return false end
            if not pcall(points, text) then return false end
            if not pcall(setText, text, "DP") then return false end
            if not pcall(show, text) then return false end
            return true
        end
        local create = method(button, "CreateTexture")
        local okC, icon
        if create then okC, icon = pcall(create, button, nil, "ARTWORK") end
        if okC and cleanFrame(icon) then
            button.icon = icon
            local setSize = method(icon, "SetSize")
            local clearPoints = method(icon, "ClearAllPoints")
            local setPoint = method(icon, "SetPoint")
            if not setSize or not clearPoints or not setPoint then return false end
            if not pcall(setSize, icon, 26, 26) then return false end
            if not pcall(clearPoints, icon) then return false end
            if not pcall(setPoint, icon, "CENTER", button, "CENTER", 0, 0) then return false end
            local setTexture = method(icon, "SetTexture")
            local rendered, success
            if setTexture then rendered, success = pcall(setTexture, icon, "Interface\\Icons\\INV_Misc_Map_01") end
            if rendered and addon.Clean(success, "boolean") == true then
                local show = method(icon, "Show")
                if not show or not pcall(show, icon) then return false end
            else
                local hide = method(icon, "Hide")
                if not hide or not pcall(hide, icon) then return false end
                if not fallbackLabel() then return false end
            end
        else
            if not fallbackLabel() then return false end
        end
        pcall(function()
            local createMask, addMask = method(button, "CreateMaskTexture"), method(icon, "AddMaskTexture")
            if createMask and addMask then
                local mask = createMask(button, nil, "ARTWORK")
                mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                mask:SetAllPoints(icon); addMask(icon, mask); button.mask = mask
            end
        end)
        pcall(function()
            local border = button:CreateTexture(nil, "OVERLAY")
            border:SetSize(42, 42); border:ClearAllPoints(); border:SetPoint("CENTER", button, "CENTER", 0, 0)
            if addon.Read(border.SetTexture, "boolean", border, "Interface\\Common\\RingBorder") == true then border:Show() end
            button.border = border
        end)
        local highlight = method(button, "SetHighlightTexture")
        if highlight then pcall(highlight, button, "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD") end
    end
    local session = {}
    self.session = session
    if retry then retry.session, retry.parent = session, parent end
    local function current() return addon.Minimap == self and self.session == session and self.button == button and self:Current() end
    if not setScript(button, "OnMouseDown", function(_, mouse)
        if current() and mouse == "LeftButton" and not self.drag then self.suppressClick = nil end
    end) then return false end
    if not setScript(button, "OnClick", function(_, mouse)
        if not current() then return end
        if self.suppressClick then self.suppressClick = nil; return end
        if mouse == "LeftButton" and addon.UI and type(addon.UI.Toggle) == "function" then addon.UI:Toggle() end
    end) then return false end
    if not setScript(button, "OnDragStart", function(_, mouse) if current() then self:StartDrag(mouse) end end) then return false end
    if not setScript(button, "OnDragStop", function() if current() then self:StopDrag(true) end end) then return false end
    if not setScript(button, "OnEnter", function() if current() then self:Tooltip() end end) then return false end
    if not setScript(button, "OnLeave", function() if current() then self:ReleaseTooltip() end end) then return false end
    if not setScript(button, "OnHide", function()
        if not button.launcherVisibilityWriting or button.launcherVisibilityWriting == 0 then
            button.launcherVisibility = nil
        end
        if self.session == session and self.button == button then
            self:StopDrag(false); self:ReleaseTooltip(); self.suppressClick = nil
        end
    end) then return false end
    if not self:StyleLauncher() or not current() then return false end
    if not self:WatchSize() or not current() then return false end
    local placed, reason = self:Place(angle(self.config.angle) or 225)
    if not current() then return false end
    if not placed then
        if reason ~= "superseded" then self:HideForPlacement(); self:RetryPlacement(db, retry) end
        return false
    end
    self.retry = nil
    if addon.Clean(self.config.hide, "boolean") == true then self:SetVisible(false) else self:SetVisible(true) end
    return true
end

function M:ToggleVisibility()
    if not self:Current() and not self:Initialize() then return false end
    local button, parent, config, session = self.button, self.parent, self.config, self.session
    local function current()
        return addon.Minimap == self and self:Current() and self.button == button and self.parent == parent and
            self.config == config and self.session == session
    end
    local shown = addon.Read(method(button, "IsShown"), "boolean", button)
    if not current() or shown == nil then return false end
    if shown then
        self.retry = nil
        config.hide = true
        self:SetVisible(false); self:StopDrag(false); self:ReleaseTooltip()
    else
        local position = angle(config.angle) or 225
        if not current() then return false end
        local placed, reason = self:Place(position)
        if not current() then return false end
        if not placed then if reason ~= "superseded" then self:HideForPlacement(); self:RetryPlacement(self.db) end; return false end
        config.hide = false
        self:SetVisible(true)
    end
    return current()
end

function M:Reset()
    if not self:Current() and not self:Initialize() then return false end
    local button, parent, config, session = self.button, self.parent, self.config, self.session
    local function current()
        return addon.Minimap == self and self:Current() and self.button == button and self.parent == parent and
            self.config == config and self.session == session
    end
    self:StopDrag(false); self:ReleaseTooltip()
    if not current() then return false end
    local placed, reason = self:Place(225)
    if not current() then return false end
    if not placed then
        if reason ~= "superseded" then self:HideForPlacement(); self:RetryPlacement(self.db) end
        return false
    end
    config.angle, config.hide = 225, false
    self:SetVisible(true)
    return current()
end
