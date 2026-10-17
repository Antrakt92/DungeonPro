local total = 0
local function fixture()
    local addon, methods = {}, {}
    issecretvalue = function() return false end
    GetLocale = function() return "enUS" end
    local function frame()
        return setmetatable({ scripts = {}, shown = false, over = false }, { __index = methods })
    end
    function methods:SetScript(event, fn) self.scripts[event] = fn end
    function methods:SetText(text) self.text = text end
    function methods:SetFrameStrata(value) self.strata = value end
    function methods:Show() self.shown = true end
    function methods:Hide()
        local shown = self.shown; self.shown = false
        if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function methods:IsShown() return self.shown end
    function methods:IsMouseOver() return self.over end
    for _, key in ipairs({ "SetSize", "SetPoint", "EnableMouse" }) do methods[key] = function() end end
    CreateFrame = function() return frame() end
    assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
    assert(loadfile("Locales/Strings.lua"))("DungeonPro", addon)
    assert(loadfile("Locales/Translations.lua"))("DungeonPro", addon)
    addon.db = { locale = "enUS", preserved = {} }
    local ui = { frame = frame(), language = frame(), renders = 0, samples = {} }
    addon.UI = ui; ui.frame:Show()
    function ui:Refresh()
        self.renders = self.renders + 1
        self.samples[#self.samples + 1] = { next = addon.L("NEXT"), map = addon.L("SHOW_MAP") }
        return addon.Language:Refresh(self)
    end
    assert(loadfile("UI/Language.lua"))("DungeonPro", addon)
    assert(addon.Language:Attach(ui.language, ui))
    return addon, ui, frame
end

local function check(name, fn)
    fn(); total = total + 1; print("PASS " .. name)
end

check("Hover opens all language choices and previews labels without writing settings", function()
    local addon, ui = fixture()
    local database, preserved = addon.db, addon.db.preserved
    ui.language.scripts.OnEnter()
    local state = assert(addon.Language.session)
    assert(state.popup:IsShown() and #state.rows == 11 and state.popup.strata == "TOOLTIP")
    state.rows[3].scripts.OnEnter()
    assert(addon.L("NEXT") == addon.locales.ruRU.NEXT and ui.language.text == "Русский")
    assert(ui.samples[#ui.samples].next == addon.locales.ruRU.NEXT)
    assert(addon.db == database and addon.db.locale == "enUS" and addon.db.preserved == preserved)
    local renders = ui.renders; state.rows[3].scripts.OnEnter(); assert(ui.renders == renders)
end)

check("Leaving both owner and popup restores the committed language and clears the temporary ticker", function()
    local addon, ui = fixture(); ui.language.scripts.OnEnter()
    local state = addon.Language.session; state.rows[3].scripts.OnEnter()
    ui.language.scripts.OnLeave()
    local tick = assert(state.popup.scripts.OnUpdate)
    tick(state.popup, .05); assert(addon.Language:GetSelection() == "ruRU")
    tick(state.popup, .06)
    assert(not addon.Language.session and not state.popup:IsShown() and not state.popup.scripts.OnUpdate)
    assert(addon.L("NEXT") == addon.locales.enUS.NEXT and addon.db.locale == "enUS" and ui.language.text == "English")
end)

check("Moving from trigger to popup keeps the preview and moving away later cancels it", function()
    local addon, ui = fixture(); ui.language.scripts.OnEnter()
    local state = addon.Language.session; state.rows[4].scripts.OnEnter(); state.popup.over = true
    ui.language.scripts.OnLeave(); state.popup.scripts.OnUpdate(state.popup, .11)
    assert(addon.Language:GetSelection() == "deDE" and not state.popup.scripts.OnUpdate)
    state.popup.over = false; state.popup.scripts.OnLeave(); state.popup.scripts.OnUpdate(state.popup, .11)
    assert(not addon.Language.session and addon.db.locale == "enUS")
end)

check("Only an explicit language click commits and a delayed old leave cannot undo it", function()
    local addon, ui = fixture(); ui.language.scripts.OnEnter()
    local state = addon.Language.session; state.rows[3].scripts.OnEnter(); ui.language.scripts.OnLeave()
    local oldTick = state.popup.scripts.OnUpdate
    state.rows[4].scripts.OnClick()
    assert(addon.db.locale == "deDE" and not addon.Language.session and ui.language.text == "Deutsch")
    oldTick(state.popup, .2)
    assert(addon.db.locale == "deDE" and addon.L("NEXT") == addon.locales.deDE.NEXT)
end)

check("Automatic selection displays the actual language and aliases retain native captions", function()
    local addon, ui = fixture(); addon.db.locale = "auto"; GetLocale = function() return "ruRU" end
    assert(addon.Language:Refresh(ui) and ui.language.text == "Русский")
    assert(addon.Language:Caption("enGB") == "English" and addon.Language:Caption("esMX") == "Español")
    GetLocale = function() return "unknown" end
    assert(addon.Language:Refresh(ui) and ui.language.text == "English")
end)

check("Old callbacks cannot preview or commit after UI settings or helper ownership changes", function()
    for _, kind in ipairs({ "ui", "database", "locale", "frame", "button", "refresh", "checker" }) do
        local addon, ui, frame = fixture(); ui.language.scripts.OnEnter()
        local state = addon.Language.session
        if kind == "ui" then addon.UI = {}
        elseif kind == "database" then addon.db = { locale = "frFR" }
        elseif kind == "locale" then addon.db.locale = "frFR"
        elseif kind == "frame" then ui.frame = frame()
        elseif kind == "button" then ui.language = frame()
        elseif kind == "refresh" then ui.Refresh = function() error("expired refresh") end
        else issecretvalue = function() return false end end
        local committed, renders = addon.db.locale, ui.renders
        state.rows[3].scripts.OnEnter(); state.rows[3].scripts.OnClick()
        assert(addon.db.locale == committed and ui.renders == renders and addon.Language:GetSelection() == nil, kind)
    end
end)

check("Closing the popup or planner cancels preview without persisting it", function()
    for _, mode in ipairs({ "popup", "planner" }) do
        local addon, ui = fixture(); ui.language.scripts.OnEnter()
        local state = addon.Language.session; state.rows[3].scripts.OnEnter()
        if mode == "popup" then state.popup:Hide() else ui.frame:Hide(); addon.Language:Cancel(ui) end
        assert(not addon.Language.session and addon.db.locale == "enUS" and addon.Language:GetSelection() == nil)
    end
end)

check("Every UI dictionary participates in preview and cancel returns to the same committed root", function()
    local addon, ui = fixture(); local database = addon.db
    ui.language.scripts.OnEnter(); local state = addon.Language.session
    for index, locale in ipairs({ "enUS", "ruRU", "deDE", "frFR", "esES", "itIT", "ptBR", "koKR", "zhCN", "zhTW" }) do
        state.rows[index + 1].scripts.OnEnter()
        assert(addon.L("NEXT") == addon.locales[locale].NEXT and addon.L("STEP_GUIDE") == addon.locales[locale].STEP_GUIDE)
        assert(addon.db == database and database.locale == "enUS")
    end
    addon.Language:Cancel(ui); assert(addon.L("NEXT") == addon.locales.enUS.NEXT)
end)

check("Repeated hover-open reuses the same popup and rows while old saved callbacks expire", function()
    local addon, ui = fixture(); ui.language.scripts.OnEnter()
    local first = addon.Language.session; local popup, row = first.popup, first.rows[3]
    local expired = row.scripts.OnClick
    for _ = 1, 20 do
        addon.Language:Cancel(ui); ui.language.scripts.OnEnter()
        local state = addon.Language.session
        assert(state.popup == popup and state.rows[3] == row)
    end
    expired(); assert(addon.db.locale == "enUS" and addon.Language.session)
end)

check("Failed popup creation and closed trigger cannot activate or persist a preview", function()
    local addon, ui = fixture(); local creator = CreateFrame
    CreateFrame = function() error("unavailable") end
    assert(not addon.Language:Open(ui) and not addon.Language.session and addon.db.locale == "enUS")
    CreateFrame = creator; ui.frame:Hide(); ui.language.scripts.OnEnter()
    assert(not addon.Language.session and addon.db.locale == "enUS")
end)

check("A newer session created inside styling is not cancelled by the expired builder", function()
    local addon, ui = fixture(); local armed = true
    addon.Theme = { Apply = function()
        if armed then armed = false; addon.Language:Cancel(ui); addon.Language:Open(ui) end
        return true
    end }
    assert(not addon.Language:Open(ui))
    local state = assert(addon.Language.session)
    assert(state.popup:IsShown() and #state.rows == 11 and addon.db.locale == "enUS")
    state.rows[3].scripts.OnClick(); assert(addon.db.locale == "ruRU")
end)

check("Failed preview rendering rolls back transient selection and closed planner cancellation refreshes fonts", function()
    local addon, ui = fixture(); local rendering, fonts = false, 0
    ui.Refresh = function()
        if addon.Language:GetSelection() == "ruRU" then error("render unavailable") end
        rendering = true
    end
    addon.Theme = { RefreshFonts = function() fonts = fonts + 1 end }
    ui.language.scripts.OnEnter(); local state = addon.Language.session
    assert(not addon.Language:Preview(state, "ruRU") and rendering and addon.Language:GetSelection() == nil and addon.db.locale == "enUS")
    assert(addon.Language:Preview(state, "zhCN")); ui.frame:Hide(); addon.Language:Cancel(ui)
    assert(fonts == 1 and addon.Language:GetSelection() == nil and addon.db.locale == "enUS")
end)

check("Saved leave callbacks cannot clear the pending close of a newer hover session", function()
    local addon, ui = fixture(); ui.language.scripts.OnEnter(); ui.language.scripts.OnLeave()
    local old = addon.Language.session.popup.scripts.OnUpdate
    addon.Language:Cancel(ui); ui.language.scripts.OnEnter(); ui.language.scripts.OnLeave()
    local state = addon.Language.session; local pending = state.popup.scripts.OnUpdate
    old(state.popup, .2)
    assert(addon.Language.session == state and state.popup.scripts.OnUpdate == pending)
    pending(state.popup, .2); assert(not addon.Language.session)
end)

check("Cancelling from a hidden planner restores the actual tracked HUD font context", function()
    local addon, ui = fixture(); local chat, creator = ChatFontNormal, CreateFont
    local family = {}; ChatFontNormal = family
    local function font()
        return {
            SetFont = function(self, path, size) self.path, self.height, self.family = path, size, nil end,
            GetFont = function(self) return self.path, self.height, "" end,
            SetFontObject = function(self, value) self.family, self.path = value, nil end,
            SetFontHeight = function(self, value) self.height = value end,
            SetShadowOffset = function() end, SetTextColor = function() end,
        }
    end
    CreateFont = font
    assert(loadfile("UI/Theme.lua"))("DungeonPro", addon)
    local hud = font()
    local function path(region) return region.path or (region.family and path(region.family)) end
    local refresh = ui.Refresh
    ui.Refresh = function(self)
        if not self.frame:IsShown() then return end
        addon.Theme.RefreshFonts(); return refresh(self)
    end
    assert(addon.Theme.ApplyFont(hud, 16) and path(hud):find("NotoSans", 1, true))
    local database = addon.db
    ui.language.scripts.OnEnter(); local state = addon.Language.session
    state.rows[10].scripts.OnEnter()
    assert(addon.Language:GetSelection() == "zhCN" and not path(hud) and addon.db == database and database.locale == "enUS")
    ui.frame:Hide(); addon.Language:Cancel(ui)
    local restored = path(hud)
    assert(not addon.Language:GetSelection() and restored and restored:find("NotoSans", 1, true) and
        addon.db == database and database.locale == "enUS", "hidden planner cancellation must restore the committed HUD font")
    ChatFontNormal, CreateFont = chat, creator
end)

print("Language preview modeled checks passed: " .. total .. " (native pointer and font acceptance pending)")
