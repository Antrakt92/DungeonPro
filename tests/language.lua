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
    function methods:SetTexture(value) self.texture = value; return true end
    function methods:SetAlpha(value) self.alpha = value end
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:SetPoint(...) self.point = { ... } end
    function methods:CreateTexture() self.textures = self.textures or {};local region=frame();self.textures[#self.textures+1]=region;return region end
    function methods:CreateFontString() return frame() end
    function methods:GetFontString() self.label=self.label or frame();return self.label end
    function methods:SetFrameStrata(value) self.strata = value end
    function methods:SetClampedToScreen(value) self.clamped = value end
    function methods:Show() self.shown = true end
    function methods:Hide()
        local shown = self.shown; self.shown = false
        if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function methods:IsShown() return self.shown end
    function methods:IsMouseOver() return self.over end
    for _, key in ipairs({ "ClearAllPoints", "SetWidth", "SetJustifyH", "SetTextColor", "EnableMouse" }) do methods[key] = function() end end
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
    assert(addon.L("NEXT") == addon.locales.ruRU.NEXT and ui.language.languageCaption == "Русский" and ui.language.text == "RU")
    assert(ui.samples[#ui.samples].next == addon.locales.ruRU.NEXT)
    assert(addon.db == database and addon.db.locale == "enUS" and addon.db.preserved == preserved)
    local renders = ui.renders; state.rows[3].scripts.OnEnter(); assert(ui.renders == renders)
end)

check("Leaving both owner and popup restores the committed language and clears the temporary ticker", function()
    local addon, ui = fixture(); ui.language.scripts.OnEnter()
    local state = addon.Language.session; state.rows[3].scripts.OnEnter()
    ui.language.scripts.OnLeave()
    local tick = assert(state.popup.scripts.OnUpdate)
    tick(state.popup, .001)
    assert(not addon.Language.session and not state.popup:IsShown() and not state.popup.scripts.OnUpdate)
    assert(addon.L("NEXT") == addon.locales.enUS.NEXT and addon.db.locale == "enUS" and ui.language.languageCaption == "English")
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
    assert(addon.db.locale == "deDE" and not addon.Language.session and ui.language.languageCaption == "Deutsch")
    oldTick(state.popup, .2)
    assert(addon.db.locale == "deDE" and addon.L("NEXT") == addon.locales.deDE.NEXT)
end)

check("Automatic selection displays the actual language and aliases retain native captions", function()
    local addon, ui = fixture(); addon.db.locale = "auto"; GetLocale = function() return "ruRU" end
    assert(addon.Language:Refresh(ui) and ui.language.languageCaption == "Русский" and ui.language.text == "RU")
    assert(addon.Language:Caption("enGB") == "English" and addon.Language:Caption("esMX") == "Español (España)")
    GetLocale = function() return "unknown" end
    assert(addon.Language:Refresh(ui) and ui.language.languageCaption == "English")
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
    assert(addon.Language:GetSelection() == "zhCN" and path(hud) == "Fonts\\ARKai_T.ttf" and addon.db == database and database.locale == "enUS")
    ui.frame:Hide(); addon.Language:Cancel(ui)
    local restored = path(hud)
    assert(not addon.Language:GetSelection() and restored and restored:find("NotoSans", 1, true) and
        addon.db == database and database.locale == "enUS", "hidden planner cancellation must restore the committed HUD font")
    ChatFontNormal, CreateFont = chat, creator
end)

check("Neutral language launcher keeps its globe while menu rows show names and committed check only", function()
    local addon, ui = fixture()
    local styled = 0
    addon.Theme = { StyleRow = function(row, options) styled = styled + 1; row.selected = options.selected; return true end }
    assert(addon.Language:Refresh(ui))
    local icon = ui.language.languageIcon
    assert(ui.language.text == "EN" and ui.language.languageCaption == "English" and ui.language.languageLocale == "enUS")
    assert(icon.shown and icon.width == 18 and icon.height == 18 and icon.texture == "Interface\\AddOns\\DungeonPro\\Media\\Icons\\Language")
    assert(ui.language.label.point[4] == 32)
    ui.language.scripts.OnEnter(); local state = addon.Language.session
    assert(state.popup.width == 224 and state.popup.height == 366 and state.popup.point[5] == 0)
    for i, row in ipairs(state.rows) do
        assert(row.width == 212 and row.height == 30 and not row.languageFlag and not row.languageIcon)
        assert(row.languageMark.texture == "Interface\\Buttons\\UI-CheckBox-Check" and row.languageMark.shown == (i == 2))
        assert(row.label.point[1] == "LEFT" and row.label.point[4] == 12)
    end
    assert(styled == 11 and state.rows[9].text == "한국어" and state.rows[10].text == "简体中文" and state.rows[11].text == "繁體中文")
    local row, mark = state.rows[3], state.rows[3].languageMark
    local renders = ui.renders; row.scripts.OnEnter()
    assert(ui.renders == renders + 1 and not state.popup.scripts.OnUpdate and ui.language.languageIcon == icon)
    assert(ui.language.text == "RU" and row.languagePreview and not row.languageSelected and not row.languageMark.shown)
    assert(state.rows[2].languageMark.shown and state.rows[1].text == addon.locales.ruRU.LANGUAGE_AUTO)
    for _ = 1, 10 do addon.Language:Cancel(ui); ui.language.scripts.OnEnter() end
    assert(addon.Language.session.rows[3] == row and row.languageMark == mark)
    assert(#row.textures == 1 and #ui.language.textures == 1 and addon.db.locale == "enUS")
end)

check("Pointer transition uses the next frame without a time threshold and includes hovered rows",function()
    local addon,ui=fixture();ui.language.scripts.OnEnter();local state=addon.Language.session
    state.rows[3].scripts.OnEnter();state.rows[3].over=true;state.rows[3].scripts.OnLeave()
    state.popup.scripts.OnUpdate(state.popup,0)
    assert(addon.Language.session==state and addon.Language:GetSelection()=="ruRU" and not state.popup.scripts.OnUpdate)
    state.rows[3].over=false;state.rows[3].scripts.OnLeave();state.popup.scripts.OnUpdate(state.popup,0)
    assert(not addon.Language.session and addon.db.locale=="enUS" and not state.popup.scripts.OnUpdate)
end)

check("Missing or rejected globe rendering retains an accessible short launcher caption",function()
    for _,failure in ipairs({"missing","false","throw"})do
        local addon,ui,frame=fixture()
        if failure=="missing"then ui.language.CreateTexture=false
        else ui.language.CreateTexture=function()
            local icon=frame();icon.SetTexture=function()if failure=="throw"then error("missing texture")end;return false end
            return icon
        end end
        assert(addon.Language:Refresh(ui) and ui.language.text=="EN" and ui.language.languageCaption=="English")
        assert(not ui.language.languageIcon or not ui.language.languageIcon.shown)
        ui.language.scripts.OnEnter();assert(addon.Language.session.popup.shown)
    end
end)

check("Failed popup visibility expires all preview and commit callbacks without touching settings",function()
    local addon,ui=fixture();local create=CreateFrame
    CreateFrame=function(kind,...)
        local widget=create(kind,...)
        if kind=="Frame"then widget.Show=function()error("popup unavailable")end end
        return widget
    end
    assert(not addon.Language:Open(ui) and not addon.Language.session)
    local renders=ui.renders;local row=addon.Language.rows[3]
    row.scripts.OnEnter();row.scripts.OnClick()
    assert(addon.db.locale=="enUS" and ui.renders==renders and not addon.Language:GetSelection())
end)
check("Hover preserves the committed check and only a click changes it on reopening", function()
    local addon, ui = fixture(); ui.language.scripts.OnEnter()
    local state = addon.Language.session
    for i = 3, 11 do
        state.rows[i].scripts.OnEnter()
        assert(state.rows[2].languageMark.shown and state.rows[2].languageSelected)
        assert(not state.rows[i].languageMark.shown and state.rows[i].languagePreview)
        assert(addon.db.locale == "enUS")
    end
    state.rows[3].scripts.OnClick(); ui.language.scripts.OnEnter()
    state = addon.Language.session
    assert(state.rows[3].languageMark.shown and not state.rows[2].languageMark.shown)
end)

check("Explicit false render failure rolls back preview just like a thrown failure", function()
    local addon, ui = fixture(); local refresh = ui.Refresh
    ui.Refresh = function(self)
        if addon.Language:GetSelection() == "ruRU" then return false end
        return refresh(self)
    end
    ui.language.scripts.OnEnter(); local state = addon.Language.session
    assert(not addon.Language:Preview(state, "ruRU"))
    assert(addon.Language:GetSelection() == nil and addon.db.locale == "enUS")
    assert(ui.language.languageLocale == "enUS")
end)

check("Popup requests screen clamping and each row keeps its own script across previews", function()
    local addon, ui = fixture()
    addon.Theme = { StyleLanguageRow = function(row, locale)
        row.fontLocale = locale
        return locale ~= "koKR" and locale ~= "zhCN" and locale ~= "zhTW"
    end }
    ui.language.scripts.OnEnter(); local state = addon.Language.session
    assert(state.popup.clamped == true)
    state.rows[3].scripts.OnEnter()
    assert(state.rows[1].fontLocale == "ruRU" and state.rows[2].fontLocale == "enUS")
    assert(state.rows[3].fontLocale == "ruRU" and state.rows[4].fontLocale == "deDE")
    assert(state.rows[9].text == "한국어" and state.rows[10].text == "简体中文" and
        state.rows[11].text == "繁體中文")
    assert(state.rows[6].text == "Español (España)" and state.rows[8].text == "Português (Brasil)")
    assert(state.rows[9].fontLocale == "koKR" and state.rows[10].fontLocale == "zhCN" and state.rows[11].fontLocale == "zhTW")
    state.rows[4].scripts.OnEnter()
    assert(state.rows[1].fontLocale == "deDE" and state.rows[3].fontLocale == "ruRU")
    state.rows[10].scripts.OnClick()
    assert(addon.db.locale == "zhCN", "native labels retain the real language choice")
end)

check("A late popup hide cannot cancel the language session reopened inside that native setter",function()
    local addon,ui=fixture();assert(addon.Language:Open(ui))
    local old=addon.Language.session;local popup=old.popup;local native,once=popup.Hide
    popup.Hide=function(self)
        if not once then once=true;assert(addon.Language:Open(ui))end
        return native(self)
    end
    addon.Language:Cancel(ui)
    local newest=addon.Language.session
    assert(once and newest and newest~=old and newest.popup==popup and popup.shown,"newly reopened popup owns visibility")
    newest.rows[3].scripts.OnEnter();assert(addon.Language:GetSelection()=="ruRU")
end)
check("A late popup Show respects a newer cancellation instead of resurrecting the closed chooser",function()
    local addon,ui=fixture();assert(addon.Language:Open(ui));local popup=addon.Language.session.popup
    addon.Language:Cancel(ui);local native,once=popup.Show
    popup.Show=function(self)
        if not once then once=true;addon.Language:Cancel(ui)end
        return native(self)
    end
    assert(not addon.Language:Open(ui))
    assert(once and not addon.Language.session and not popup.shown and addon.db.locale=="enUS")
end)
check("Late language checkmark writes preserve the newer committed selection on reused menu rows",function()
    local addon,ui=fixture();assert(addon.Language:Open(ui));local old=addon.Language.session
    local mark=old.rows[2].languageMark;local native,once=mark.Show
    mark.Show=function(self)
        if not once then once=true;old.rows[3].scripts.OnClick();assert(addon.Language:Open(ui))end
        return native(self)
    end
    assert(not addon.Language:RefreshRows(old))
    local latest=addon.Language.session
    assert(once and latest~=old and addon.db.locale=="ruRU")
    assert(latest.rows[3].languageMark.shown and not latest.rows[2].languageMark.shown,"only the new committed locale stays checked")
end)
check("Restored unsupported locale strings recover to a coherent native language", function()
    local savedDB, savedChar = DungeonProDB, DungeonProCharDB
    for _,native in ipairs({"ruRU","zhCN","enUS"}) do
        for _,choice in ipairs({"xxXX","","   ","enGB","esMX","auto","enUS","ruRU","deDE","frFR","esES","itIT","ptBR","koKR","zhCN","zhTW"}) do
            local addon,ui=fixture()
            assert(loadfile("Core/Client.lua"))("DungeonPro",addon)
            GetLocale=function()return native end
            local window,filters={},{}
            DungeonProDB={schema=1,locale=choice,window=window}
            DungeonProCharDB={texts={},filters=filters}
            assert(addon.RestoreDB() and addon.Language:Refresh(ui))
            local valid=choice~="xxXX" and choice~="" and choice~="   "
            local selected=valid and choice or "auto"
            local resolved=selected=="auto" and native or selected
            if resolved=="enGB" then resolved="enUS" elseif resolved=="esMX" then resolved="esES" end
            assert(ui.language.languageLocale==resolved and addon.L("NEXT")==addon.locales[resolved].NEXT,
                "restored selection caption and actual localized text agree")
            assert(addon.db.locale==selected,"only unsupported saved locale strings recover")
            assert(addon.db.window==window and addon.char.filters==filters)
        end
    end
    DungeonProDB,DungeonProCharDB=savedDB,savedChar
end)
print("Language preview modeled checks passed: " .. total .. " (native pointer and font acceptance pending)")
