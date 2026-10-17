local _, addon = ...
local Language = {}
addon.Language = Language
local choices = { { "auto" }, { "enUS", "English" }, { "ruRU", "Русский" }, { "deDE", "Deutsch" },
    { "frFR", "Français" }, { "esES", "Español" }, { "itIT", "Italiano" }, { "ptBR", "Português" },
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

local function owned(state)
    local ok, same = pcall(function()
        return addon.Language == Language and Language.session == state and addon.UI == state.ui and
            state.ui.frame == state.frame and state.ui.language == state.button and addon.db == state.db and
            rawget(state.db, "locale") == state.committed and state.ui.Refresh == state.refresh and
            GetLocale == state.gameGetter and issecretvalue == state.checker
    end)
    return ok and same == true
end

local function current(state)
    if not owned(state) then return false end
    local shown = addon.Read(state.shown, "boolean", state.frame)
    return shown == true and owned(state) and method(state.frame, "IsShown") == state.shown and owned(state)
end

-- Only transient UI selection is exposed; committed settings remain untouched.
function Language:GetSelection()
    local state = self.session
    if state and owned(state) then return state.preview end
end

function Language:Caption(selection)
    selection = code(selection) or "auto"
    if selection == "auto" then selection = code(addon.Read(GetLocale, "string")) or "enUS" end
    for _, choice in ipairs(choices) do if choice[1] == selection then return choice[2] or "English" end end
    return "English"
end

function Language:Refresh(ui)
    local button, frame, database = ui.language, ui.frame, addon.Clean(addon.db, "table")
    if addon.UI ~= ui or not button or not frame or not database then return false end
    local committed, getter, checker = rawget(database, "locale"), GetLocale, issecretvalue
    local selection = self:GetSelection() or code(committed) or "auto"
    local name = self:Caption(selection)
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
    local binding = { current = same, value = name }; button.languageLabelText = binding
    local ok = invoke(button, "SetText", name)
    if ok and same() then return true end
    local newer = button.languageLabelText
    if newer ~= binding and newer and newer.current() and not button.languageLabelRepair then
        button.languageLabelRepair = true
        if button.languageLabelText == newer and newer.current() then invoke(button, "SetText", newer.value) end
        button.languageLabelRepair = nil
    end
    return false
end

function Language:Cancel(ui, expected)
    local state = self.session
    if not state or (expected and state ~= expected) or (ui and state.ui ~= ui) then return false end
    self.session = nil
    state.leave = nil
    invoke(state.popup, "SetScript", "OnUpdate", nil)
    invoke(state.popup, "Hide")
    if state.preview and addon.UI == state.ui and addon.db == state.db and state.ui.frame == state.frame then
        local theme = addon.Clean(addon.Theme, "table")
        if theme then addon.Read(theme.RefreshFonts, "boolean") end
        if self.session or addon.UI ~= state.ui or addon.db ~= state.db or state.ui.frame ~= state.frame then return true end
        pcall(state.refresh, state.ui)
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
    local ok = pcall(state.refresh, state.ui)
    if not ok and owned(state) then
        state.preview = previous
        pcall(state.refresh, state.ui)
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
    invoke(state.popup, "Hide")
    if addon.UI == state.ui and addon.db == state.db and state.ui.frame == state.frame then pcall(state.refresh, state.ui) end
    return true
end

function Language:Leave(state)
    if not current(state) then return end
    local elapsed, token = 0, {}; state.leave = token
    local function stop()
        if self.session == state and state.leave == token then
            state.leave = nil; invoke(state.popup, "SetScript", "OnUpdate", nil)
        end
    end
    invoke(state.popup, "SetScript", "OnUpdate", function(_, delta)
        if state.leave ~= token or self.session ~= state then return end
        delta = addon.Clean(delta, "number")
        if not delta or delta < 0 or not current(state) then stop(); return end
        elapsed = elapsed + math.min(delta, 1)
        if elapsed < 0.1 then return end
        stop()
        local buttonOver = addon.Read(method(state.button, "IsMouseOver"), "boolean", state.button)
        local popupOver = addon.Read(method(state.popup, "IsMouseOver"), "boolean", state.popup)
        if current(state) and buttonOver ~= true and popupOver ~= true then self:Cancel(state.ui) end
    end)
end

function Language:Open(ui)
    if self.session and self.session.ui == ui and current(self.session) then return true end
    self:Cancel()
    local database, frame, button = addon.Clean(addon.db, "table"), object(ui.frame), object(ui.language)
    if addon.UI ~= ui or not database or not frame or not button then return false end
    local committed = addon.Clean(rawget(database, "locale"), "string")
    local state = { ui = ui, db = database, frame = frame, button = button, committed = committed,
        refresh = addon.Clean(ui.Refresh, "function"), shown = method(frame, "IsShown"), gameGetter = GetLocale, checker = issecretvalue }
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
    invoke(popup, "SetSize", 194, #choices * 27 + 12)
    invoke(popup, "SetPoint", "TOPRIGHT", button, "BOTTOMRIGHT", 0, -2)
    invoke(popup, "SetFrameStrata", "TOOLTIP")
    invoke(popup, "EnableMouse", true)
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
        invoke(row, "SetSize", 182, 25); invoke(row, "SetPoint", "TOPLEFT", 6, -6 - (i - 1) * 27)
        invoke(row, "SetText", choice[2] or addon.L("LANGUAGE_AUTO"))
        invoke(row, "SetScript", "OnEnter", function() self:Preview(state, value) end)
        invoke(row, "SetScript", "OnLeave", function() self:Leave(state) end)
        invoke(row, "SetScript", "OnClick", function() self:Commit(state, value) end)
        -- Native template fonts retain script fallback for every language name.
        invoke(row, "Show")
    end
    invoke(popup, "SetScript", "OnLeave", function() self:Leave(state) end)
    invoke(popup, "SetScript", "OnEnter", function() if current(state) then state.leave = nil; invoke(popup, "SetScript", "OnUpdate", nil) end end)
    invoke(popup, "SetScript", "OnHide", function() if self.session == state then self:Cancel(ui, state) end end)
    if not current(state) then self:Cancel(ui, state); return false end
    return invoke(popup, "Show") and current(state)
end

function Language:Attach(button, ui)
    if addon.UI ~= ui or ui.language ~= button then return false end
    invoke(button, "SetScript", "OnEnter", function() if addon.UI == ui and ui.language == button then self:Open(ui) end end)
    invoke(button, "SetScript", "OnLeave", function() local state = self.session; if state and state.ui == ui then self:Leave(state) end end)
    return true
end
