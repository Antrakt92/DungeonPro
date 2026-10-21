local _, addon = ...
local Language = {}
addon.Language = Language
local choices = { { "auto" }, { "enUS", "English" }, { "ruRU", "Русский" }, { "deDE", "Deutsch" },
    { "frFR", "Français" }, { "esES", "Español (España)" }, { "itIT", "Italiano" }, { "ptBR", "Português (Brasil)" },
    { "koKR", "한국어" }, { "zhCN", "简体中文" }, { "zhTW", "繁體中文" } }

local function code(value)
    value = addon.Clean(value, "string")
    if value == "enGB" then value = "enUS" elseif value == "esMX" then value = "esES" end
    for _, choice in ipairs(choices) do if choice[1] == value then return value end end
end

local function object(value)
    return addon.Clean(value, "table") or addon.Clean(value, "userdata")
end

local function method(owner, key)
    return addon.Read(function() return owner[key] end, "function")
end

local function invoke(owner, key, ...)
    local fn = owner and method(owner, key)
    if fn then return pcall(fn, owner, ...) end
    return false
end

local function resolved(value)
    value = code(value) or "auto"
    if value == "auto" then
        local native = code(addon.Read(GetLocale, "string"))
        value = native and native ~= "auto" and native or "enUS"
    end
    return value
end

local function languageIcon(owner, check)
    if not check() then return false end
    local texture = owner.languageIcon
    if not texture then
        local create = method(owner, "CreateTexture")
        local ok, made = pcall(function() return create and create(owner, nil, "ARTWORK") end)
        texture = ok and object(made)
        if not check() then return false end
        if not texture then return false end
        owner.languageIcon = texture
    end
    if not invoke(texture, "Hide") or not check() then return false end
    if not invoke(texture, "SetSize", 18, 18) or not check() then return false end
    if not invoke(texture, "ClearAllPoints") or not check() then return false end
    if not invoke(texture, "SetPoint", "LEFT", owner, "LEFT", 8, 0) or not check() then return false end
    local accepted = addon.Read(method(texture, "SetTexture"), "boolean", texture,
        "Interface\\AddOns\\DungeonPro\\Media\\Icons\\Language")
    if accepted ~= true or not check() then return false end
    return invoke(texture, "Show") and check()
end

local function owned(state)
    local ok, same = pcall(function()
        return addon.Language == Language and Language.session == state and addon.UI == state.ui and
            state.ui.frame == state.frame and state.ui.language == state.button and addon.db == state.db and
            rawget(state.db, "locale") == state.committed and state.ui.Refresh == state.refresh and
            state.ui.RefreshLanguagePreview == state.previewRefresh and
            GetLocale == state.gameGetter and issecretvalue == state.checker
    end)
    return ok and same == true
end

local function current(state)
    if not owned(state) then return false end
    local shown = addon.Read(state.shown, "boolean", state.frame)
    return shown == true and owned(state) and method(state.frame, "IsShown") == state.shown and owned(state)
end

local function popupVisibility(state, shown)
    local popup = state.popup
    local binding = { state = state, shown = shown }
    popup.languageVisibility = binding
    local function apply(value)
        local previous = popup.languageVisibilityWriting
        popup.languageVisibilityWriting = value
        local ok = invoke(popup, value.shown and "Show" or "Hide")
        if popup.languageVisibilityWriting == value then popup.languageVisibilityWriting = previous end
        return ok
    end
    local ok = apply(binding)
    local newer = popup.languageVisibility
    if newer and newer ~= binding and not popup.languageVisibilityRepair then
        local valid = newer.shown and current(newer.state) or
            (not newer.shown and Language.session == nil and addon.Language == Language)
        if valid and popup.languageVisibility == newer then
            popup.languageVisibilityRepair = true
            apply(newer)
            popup.languageVisibilityRepair = nil
        end
    end
    return ok
end

local function rowWrite(owner, key, check, ...)
    if not check() then return false end
    local writes = owner.languageWrites or {}; owner.languageWrites = writes
    local slot = (key == "Show" or key == "Hide") and "visibility" or key
    local binding = { check = check, key = key, args = { ... }, count = select("#", ...) }
    writes[slot] = binding
    local ok = invoke(owner, key, ...)
    if check() then return ok end
    local newer = writes[slot]
    if newer and newer ~= binding and not newer.repairing then
        newer.repairing = true
        if newer.check() and owner.languageWrites == writes and writes[slot] == newer then
            invoke(owner, newer.key, unpack(newer.args, 1, newer.count))
        end
        newer.repairing = nil
    end
    return false
end

-- Only transient UI selection is exposed; committed settings remain untouched.
function Language:GetSelection()
    local state = self.session
    if state and owned(state) then return state.preview end
end

function Language:Caption(selection)
    selection = resolved(selection)
    for _, choice in ipairs(choices) do if choice[1] == selection then return choice[2] or "English" end end
    return "English"
end

function Language:Refresh(ui)
    local button, frame, database = ui.language, ui.frame, addon.Clean(addon.db, "table")
    if addon.UI ~= ui or not button or not frame or not database then return false end
    local committed, getter, checker = rawget(database, "locale"), GetLocale, issecretvalue
    local selection = self:GetSelection() or code(committed) or "auto"
    local name = self:Caption(selection)
    local locale = resolved(selection)
    local revision = {}; ui.languageLabelRevision = revision
    local function same()
        local ok, value = pcall(function()
            return addon.Language == self and addon.UI == ui and ui.language == button and ui.frame == frame and
                ui.languageLabelRevision == revision and addon.db == database and rawget(database, "locale") == committed and
                (self:GetSelection() or code(committed) or "auto") == selection and GetLocale == getter and issecretvalue == checker
        end)
        return ok and value == true
    end
    if not same() then return false end
    local painted = languageIcon(button, same)
    if not same() then return false end
    button.languageCaption, button.languageLocale = name, locale
    local text = locale:sub(1, 2):upper()
    local label = object(addon.Read(method(button, "GetFontString"), "table", button))
    if not same() then return false end
    if label then
        invoke(label, "ClearAllPoints")
        if not same() then return false end
        invoke(label, "SetPoint", painted and "LEFT" or "CENTER", button, painted and "LEFT" or "CENTER", painted and 32 or 0, 0)
        if not same() then return false end
        invoke(label, "SetWidth", painted and 24 or 48)
        if not same() then return false end
        invoke(label, "SetJustifyH", "CENTER")
        if not same() then return false end
    end
    local binding = { current = same, value = text }; button.languageLabelText = binding
    local ok = invoke(button, "SetText", text)
    local state = self.session
    if ok and same() and state and state.ui == ui and current(state) then self:RefreshRows(state) end
    if ok and same() then return true end
    local newer = button.languageLabelText
    if newer ~= binding and newer and newer.current() and not button.languageLabelRepair then
        button.languageLabelRepair = true
        if button.languageLabelText == newer and newer.current() then invoke(button, "SetText", newer.value) end
        button.languageLabelRepair = nil
    end
    return false
end

function Language:RefreshRows(state)
    if not current(state) then return false end
    local selection = state.preview or code(state.committed) or "auto"
    local function same() return current(state) and (state.preview or code(state.committed) or "auto") == selection end
    for i, choice in ipairs(choices) do
        local row = state.rows[i]
        if row then
            local selected = (code(state.committed) or "auto") == choice[1]
            local preview = selection == choice[1]
            local label = choice[2] or addon.L("LANGUAGE_AUTO")
            if not same() then return false end
            local theme = addon.Clean(addon.Theme, "table")
            local font = theme and addon.Clean(theme.StyleLanguageRow, "function")
            if font then
                local locale = choice[1] == "auto" and resolved(selection) or choice[1]
                addon.Read(font, "boolean", row, locale)
                if not same() then return false end
            end
            if not rowWrite(row, "SetText", same, label) then return false end
            if theme then addon.Read(theme.StyleRow, "boolean", row, { selected = preview }) end
            if not same() then return false end
            if row.languageMark then
                if not rowWrite(row.languageMark, selected and "Show" or "Hide", same) then return false end
            end
            row.languageSelected, row.languagePreview = selected, preview
        end
    end
    return same()
end

function Language:Cancel(ui, expected)
    local state = self.session
    if not state or (expected and state ~= expected) or (ui and state.ui ~= ui) then return false end
    self.session = nil
    state.leave = nil
    invoke(state.popup, "SetScript", "OnUpdate", nil)
    popupVisibility(state, false)
    if state.preview and addon.UI == state.ui and addon.db == state.db and state.ui.frame == state.frame then
        local theme = addon.Clean(addon.Theme, "table")
        if theme then addon.Read(theme.RefreshFonts, "boolean") end
        if self.session or addon.UI ~= state.ui or addon.db ~= state.db or state.ui.frame ~= state.frame then return true end
        pcall(state.previewRefresh or state.refresh, state.ui)
    end
    return true
end

function Language:Preview(state, value)
    value = code(value)
    if not value or not current(state) then return false end
    state.leave = nil
    invoke(state.popup, "SetScript", "OnUpdate", nil)
    if state.preview == value then return true end
    local previous = state.preview
    state.preview = value
    local ok, result = pcall(state.previewRefresh or state.refresh, state.ui)
    ok = ok and result ~= false
    if not ok and owned(state) and state.preview == value then
        state.preview = previous
        pcall(state.previewRefresh or state.refresh, state.ui)
    end
    return ok and current(state)
end

function Language:Commit(state, value)
    value = code(value)
    if not value or not current(state) then return false end
    state.db.locale = value
    self.session = nil
    state.leave = nil
    invoke(state.popup, "SetScript", "OnUpdate", nil)
    popupVisibility(state, false)
    if addon.UI == state.ui and addon.db == state.db and state.ui.frame == state.frame then pcall(state.refresh, state.ui) end
    return true
end

function Language:Leave(state)
    if not current(state) then return end
    local token = {}; state.leave = token
    state.leaveElapsed = 0
    local function stop()
        if self.session == state and state.leave == token then
            state.leave = nil; invoke(state.popup, "SetScript", "OnUpdate", nil)
        end
    end
    -- Sampled like the map-marker ticker: accumulate frame deltas and read
    -- hover state at most every 0.1s instead of paying up to 13 IsMouseOver
    -- reads per frame. Cancellation still follows the first settled sample.
    invoke(state.popup, "SetScript", "OnUpdate", function(_, elapsed)
        if state.leave ~= token or self.session ~= state then return end
        if not current(state) then stop(); return end
        elapsed = addon.Clean(elapsed, "number")
        if not elapsed or elapsed < 0 then return end
        state.leaveElapsed = (state.leaveElapsed or 0) + elapsed
        if state.leaveElapsed < 0.1 then return end
        state.leaveElapsed = 0
        stop()
        local buttonOver = addon.Read(method(state.button, "IsMouseOver"), "boolean", state.button)
        local popupOver = addon.Read(method(state.popup, "IsMouseOver"), "boolean", state.popup)
        local rowOver = false
        for _, row in ipairs(state.rows) do
            if addon.Read(method(row, "IsMouseOver"), "boolean", row) == true then rowOver = true end
            if not current(state) then return end
        end
        if current(state) and buttonOver ~= true and popupOver ~= true and not rowOver then self:Cancel(state.ui) end
    end)
end

function Language:Open(ui)
    if self.session and self.session.ui == ui and current(self.session) then return true end
    self:Cancel()
    local database, frame, button = addon.Clean(addon.db, "table"), object(ui.frame), object(ui.language)
    if addon.UI ~= ui or not database or not frame or not button then return false end
    local committed = addon.Clean(rawget(database, "locale"), "string")
    local state = { ui = ui, db = database, frame = frame, button = button, committed = committed,
        refresh = addon.Clean(ui.Refresh, "function"), previewRefresh = addon.Clean(ui.RefreshLanguagePreview, "function"),
        shown = method(frame, "IsShown"), gameGetter = GetLocale, checker = issecretvalue }
    if not committed or not state.refresh or not state.shown then return false end
    self.session = state
    if not current(state) then self.session = nil; return false end
    local popup = self.popupFrame == frame and self.popup or nil
    if not popup then
        local ok, created = pcall(CreateFrame, "Frame", nil, frame, "BackdropTemplate")
        popup = ok and object(created)
        if popup and current(state) then self.popup, self.popupFrame, self.rows = popup, frame, {} end
    end
    if not popup or not current(state) then if self.session == state then self.session = nil end; return false end
    state.popup, state.rows = popup, self.rows
    invoke(popup, "SetSize", 224, #choices * 32 + 14)
    invoke(popup, "ClearAllPoints")
    invoke(popup, "SetPoint", "TOPRIGHT", button, "BOTTOMRIGHT", 0, 0)
    invoke(popup, "SetFrameStrata", "TOOLTIP")
    invoke(popup, "EnableMouse", true)
    invoke(popup, "SetClampedToScreen", true)
    local theme = addon.Clean(addon.Theme, "table")
    if theme then addon.Read(theme.Apply, "boolean", { frame = popup }) end
    for i, choice in ipairs(choices) do
        if not current(state) then self:Cancel(ui, state); return false end
        local row = state.rows[i]
        if not row then
            local made, created = pcall(CreateFrame, "Button", nil, popup, "UIPanelButtonTemplate")
            row = made and object(created)
        end
        if not current(state) then return false end
        if not row then self:Cancel(ui, state); return false end
        state.rows[i] = row
        local value = choice[1]
        invoke(row, "SetSize", 212, 30); invoke(row, "ClearAllPoints")
        invoke(row, "SetPoint", "TOPLEFT", 6, -7 - (i - 1) * 32)
        for _, key in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
            local original = object(addon.Read(method(row, key), "table", row))
            if original then invoke(original, "SetAlpha", 0) end
            if not current(state) then return false end
        end
        for _, key in ipairs({ "Left", "Middle", "Right" }) do
            local original = object(row[key])
            if original then invoke(original, "SetAlpha", 0) end
            if not current(state) then return false end
        end
        invoke(row, "SetText", choice[2] or addon.L("LANGUAGE_AUTO"))
        local text = addon.Read(method(row, "GetFontString"), "table", row)
        if text then
            invoke(text, "ClearAllPoints"); invoke(text, "SetPoint", "LEFT", row, "LEFT", 12, 0)
            invoke(text, "SetWidth", 170); invoke(text, "SetJustifyH", "LEFT")
        end
        if not row.languageMark then
            local create = method(row, "CreateTexture")
            local made, marker = pcall(function() return create and create(row, nil, "OVERLAY") end)
            if current(state) and made then row.languageMark = object(marker) end
        end
        if not current(state) then return false end
        if row.languageMark then
            invoke(row.languageMark, "SetPoint", "RIGHT", row, "RIGHT", -8, 0)
            invoke(row.languageMark, "SetSize", 18, 18)
            invoke(row.languageMark, "SetTexture", "Interface\\Buttons\\UI-CheckBox-Check")
            invoke(row.languageMark, "SetAlpha", .8)
        end
        invoke(row, "SetScript", "OnEnter", function() self:Preview(state, value) end)
        invoke(row, "SetScript", "OnLeave", function() self:Leave(state) end)
        invoke(row, "SetScript", "OnClick", function() self:Commit(state, value) end)
        -- Row fonts follow their own language, independently of the hovered preview.
        invoke(row, "Show")
    end
    invoke(popup, "SetScript", "OnLeave", function() self:Leave(state) end)
    invoke(popup, "SetScript", "OnEnter", function() if current(state) then state.leave = nil; invoke(popup, "SetScript", "OnUpdate", nil) end end)
    invoke(popup, "SetScript", "OnHide", function()
        local writing, latest = popup.languageVisibilityWriting, popup.languageVisibility
        if writing and latest and writing ~= latest and latest.state == state and latest.shown then return end
        if self.session == state then self:Cancel(ui, state) end
    end)
    if not current(state) then self:Cancel(ui, state); return false end
    if not self:RefreshRows(state) then self:Cancel(ui, state); return false end
    if not popupVisibility(state, true) or not current(state) then self:Cancel(ui, state); return false end
    return true
end

function Language:Attach(button, ui)
    if addon.UI ~= ui or ui.language ~= button then return false end
    invoke(button, "SetScript", "OnEnter", function() if addon.UI == ui and ui.language == button then self:Open(ui) end end)
    invoke(button, "SetScript", "OnLeave", function() local state = self.session; if state and state.ui == ui then self:Leave(state) end end)
    return true
end
