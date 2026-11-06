-- Real planner/picker flow with native-shaped fonts, scrolling and deferred leave.
local f = assert(loadfile("tests/client_ui.lua"))("fixture")
local a, event, m = f.addon, f.eventFrame, f.methods
local BASE = "Interface\\AddOns\\DungeonPro\\Media\\Fonts\\AntraktUISans.ttf"
local total, pending, unavailable, combat, mouse = 0, {}, {}, false, nil
local function check(ok, why) assert(ok, why); total = total + 1 end
function m:GetFrameLevel() return self.level or 1 end
function m:SetFrameLevel(v) self.level = v end
function m:EnableMouseWheel(v) self.mouseWheel = v end
function m:SetClampedToScreen(v) self.clamped = v end
function m:EnableKeyboard(v) self.keyboard = v end
function m:SetPropagateKeyboardInput(v) self.propagate = v end
function m:SetWordWrap(v) self.wordWrap = v end
function m:SetMaxLines(v) self.maxLines = v end
function m:SetJustifyV(v) self.justifyV = v end
function m:SetOrientation(v) self.orientation = v end
function m:SetValueStep(v) self.valueStep = v end
function m:SetObeyStepOnDrag(v) self.obeyStep = v end
function m:SetThumbTexture(v)
    self.thumb = type(v) == "string" and self:CreateTexture() or v
    if type(v) == "string" then self.thumb:SetTexture(v) end
end
function m:GetThumbTexture() return self.thumb end
function m:SetMinMaxValues(lo, hi) self.minimum, self.maximum = lo, hi end
function m:GetMinMaxValues() return self.minimum or 0, self.maximum or 0 end
function m:SetValue(v) self.value = v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end end
function m:GetValue() return self.value or 0 end
function m:SetScrollChild(v) self.scrollChild = v end
function m:SetVerticalScroll(value)
    local changed = self.verticalScroll ~= value
    self.verticalScroll, self.scrollWrites = value, (self.scrollWrites or 0) + 1
    if changed and self.scripts.OnVerticalScroll then self.scripts.OnVerticalScroll(self, value) end
end
function m:GetVerticalScrollRange() return math.max(0, (self.scrollChild and self.scrollChild.height or 0) - self:GetHeight()) end
function m:GetParent() return self.parent end
function m:IsMouseOver() return mouse == self end
function m:SetFont(path, size, flags)
    if unavailable[path] or (path:sub(1, 6) == "Fonts\\" and path ~= "Fonts\\ARIALN.TTF") then return false end
    self.fontPath, self.fontSize, self.fontFlags, self.fontObject = path, size, flags, nil
    if self.kind ~= "FontObject" then return true end
end
function m:GetFont()
    if self.fontPath then return self.fontPath, self.fontSize, self.fontFlags end
    if self.fontObject then local p, s, flags = self.fontObject:GetFont(); return p, self.fontSize or s, flags end
end
function m:SetFontObject(v) self.fontObject, self.fontPath, self.fontSize, self.fontFlags = v, nil, nil, nil end
function m:GetFontObject() return self.fontObject end
function m:SetFontHeight(v) self.fontSize = v end
function m:SetShadowOffset() end
function m:Hide() local shown = self.shown; self.shown = false; if shown and self.scripts.OnHide then self.scripts.OnHide(self) end end
function m:HookScript(name, fn) local old = self.scripts[name]; self.scripts[name] = function(...) if old then old(...) end; fn(...) end; return true end
local nativeCreate = CreateFrame
CreateFrame = function(kind, name, parent, template)
    local frame = nativeCreate(kind, name); frame.parent, frame.template = parent, template
    if kind == "ScrollFrame" and template then
        frame.ScrollBar = nativeCreate("Slider")
        frame.ScrollBar:SetScript("OnValueChanged", function(_, value) frame:SetVerticalScroll(value) end)
    end
    return frame
end
CreateFont = function() return nativeCreate("FontObject") end
ChatFontNormal = CreateFont(); ChatFontNormal:SetFont("Fonts\\ARIALN.TTF", 14, "")
UIParent.width, UIParent.height = 1920, 1080
InCombatLockdown = function() return combat end
MouseIsOver = function(region) return mouse == region end
local function flush() local queue = pending; pending = {}; for _, fn in ipairs(queue) do fn() end end
local function enter(row) mouse = row; assert(row.scripts.OnEnter, "font row must preview on hover")(row) end
local function leave(row) mouse = nil; assert(row.scripts.OnLeave)(row) end
local function click(row) assert(row.scripts.OnClick)(row) end
AntraktFonts = nil
unavailable["Fonts\\ARIALN.TTF"] = true
-- Keep the client's font object readable even when optional native picker assets fail.
event.scripts.OnEvent(event, "ADDON_LOADED", "DungeonPro"); SlashCmdList.DUNGEONPRO("")
local ui, menu = a.UI, a.FontMenu
C_Timer.After = function(_, fn) pending[#pending + 1] = fn end
check(ui.fontButton and ui.fontButton.scripts.OnClick, "planner owns clickable font control")
check(ui.fontButton.caption:GetText() == "Aa" and ui.fontButton.width == 64 and #ui.fontButton.chevron == 2, "compact header sample and chevron")
ui.fontButton.scripts.OnEnter(ui.fontButton)
check(not menu.popup or not menu.popup:IsShown(), "header hover supplies help without opening click-only picker")
ui.fontButton.scripts.OnLeave(ui.fontButton)
local function bounds(control)
    local p, right = control.point; assert(p[1] == "TOPRIGHT")
    if type(p[2]) == "number" then right = ui.frame.width + p[2]
    else local left = bounds(p[2]); assert(p[3] == "TOPLEFT"); right = left + p[4] end
    return right - control.width, right
end
local sl, sr = bounds(ui.searchBox); local fl, fr = bounds(ui.fontButton); local ll = bounds(ui.language)
check(ui.searchBox.width == 256 and sr + 8 <= fl and fr + 8 <= ll, "search and compact controls have separate hit areas")
check(sl > ui.capacityStatus.point[2] + ui.capacityStatus.width, "search avoids level/filter text")
click(ui.fontButton)
check(menu.popup:IsShown() and #menu.choices == 1, "absent provider and unavailable native assets retain baseline")
menu.popup:Hide()
local fonts = {}
for i = 1, 48 do
    local id = string.format("face-%02d", i)
    fonts[i] = { id = id, name = string.format("Face %02d", i), file = id .. ".ttf", path = "Interface\\AddOns\\AntraktFonts\\fonts\\" .. id .. ".ttf", sha256 = string.rep("a", 64), latin = true, cyrillic = true, hans = false, hant = false, hangul = false, japanese = false }
end
fonts[2].name, fonts[3].name = "Equal Name", "Equal Name"
fonts[49] = { id = "latin-only", name = "Latin Only", file = "Latin.ttf", path = "Interface\\AddOns\\AntraktFonts\\fonts\\Latin.ttf", sha256 = string.rep("b", 64), latin = true, cyrillic = false, hans = false, hant = false, hangul = false, japanese = false }
local catalog = { formatMajor = 1, catalogRevision = string.rep("c", 64), fonts = fonts }
AntraktFonts = { GetCatalog = function() return catalog end }
event.scripts.OnEvent(event, "ADDON_LOADED", "AntraktFonts"); flush()
for _, d in ipairs(a.dungeons) do if d.key == "dm" then ui.dungeon = d end end
ui.quest, ui.search, ui.range, ui.preparation = 166, "166", false, true; ui:RefreshLanguagePreview()
local dungeon, quest, search, preparation = ui.dungeon, ui.quest, ui.search, ui.preparation
local function row(id)
    for _, r in ipairs(menu.rows or menu.popup.rows) do if r.choice and r.choice.id == id and r:IsShown() then return r end end
    error("Missing current row " .. tostring(id))
end
local function same() return ui.dungeon == dungeon and ui.quest == quest and ui.search == search and ui.preparation == preparation end
click(ui.fontButton)
enter(row("face-01"))
check(ui.heading:GetFont() == fonts[1].path and ui.title:GetFont() == fonts[1].path, "hover previews whole planner rather than a label")
check(a.db.fontId == nil and a.Fonts.preview ~= nil and same(), "hover is transient and retains browsing context")
check(row("face-01").text:GetFont() == BASE and menu.popup:IsShown(), "picker labels stay baseline while planner previews")
leave(row("face-01")); enter(row("face-02")); flush()
check(ui.heading:GetFont() == fonts[2].path and a.Fonts.preview ~= nil, "queued leave cannot cancel newer hover")
leave(row("face-02")); flush()
check(ui.heading:GetFont() == BASE and a.Fonts.preview == nil and a.db.fontId == nil, "next-tick row leave restores committed baseline")
check(#menu.choices == 49 and menu.rows == menu.popup.rows, "all compatible faces are grid rows without pagination")
check(menu.columns == 3 and menu.metrics.cols == 3, "wide screen uses three columns")
check(menu.scroll and menu.content and menu.scrollBar and menu.catcher, "native scroll frame, scrollbar and outside catcher exist")
check(menu.popup.parent == UIParent and menu.popup.clamped and menu.catcher.level < menu.popup.level,
    "popup clamps independently above its outside catcher")
check(menu.popup.previous == nil and menu.popup.next == nil and menu.popup.position == nil, "no numbered page controls")
check(menu.maxScroll > 0, "long collection has overflow")
local before = menu.scroll:GetVerticalScroll(); menu.popup.scripts.OnMouseWheel(menu.popup, -1)
check(menu.scroll:GetVerticalScroll() > before, "wheel scrolls grid")
menu.scrollBar:SetValue(menu.maxScroll)
check(menu.scroll:GetVerticalScroll() == menu.maxScroll, "scrollbar reaches last row")
local choices, offset = menu.choices, menu.scroll:GetVerticalScroll(); ui:Refresh(nil, true)
check(menu.popup:IsShown() and menu.choices == choices and menu.scroll:GetVerticalScroll() == offset, "data refresh preserves picker and reading position")
ui:RefreshLanguagePreview()
check(menu.popup:IsShown() and menu.choices == choices and menu.scroll:GetVerticalScroll() == offset,
    "same-language repaint preserves picker choices and scroll")
enter(row("face-01")); menu.popup.scripts.OnMouseWheel(menu.popup, 1)
check(a.Fonts.preview == nil and ui.heading:GetFont() == BASE and menu.popup:IsShown(),
    "wheel movement retires the old row preview while retaining picker")
enter(row("face-02")); menu.scrollBar:SetValue(0)
check(a.Fonts.preview == nil and ui.heading:GetFont() == BASE,
    "native scrollbar movement retires preview from the old visible row")
local function favorite(id) return a.db.fontFavorites and a.db.fontFavorites[id or "default"] == true end
enter(row("face-01")); click(row("face-48").star)
check(favorite("face-48") and a.db.fontId == nil, "favorite persists without selecting")
check(a.Fonts.preview == nil and ui.heading:GetFont() == BASE, "favorite reorder retires preview before row reuse")
check(menu.choices[1].id == "face-48", "favorites sort first")
enter(row("face-01")); leave(row("face-01")); enter(row("face-01").star); flush()
check(a.Fonts.preview ~= nil and ui.heading:GetFont() == fonts[1].path and a.db.fontId == nil,
    "moving from row to its favorite star retains same-face preview and saved preference")
leave(row("face-01").star); flush()
check(a.Fonts.preview == nil and ui.heading:GetFont() == BASE and a.db.fontId == nil,
    "leaving a favorite star restores committed font after row-to-star preview")
local equal = {}; for _, c in ipairs(menu.choices) do if c.name == "Equal Name" then equal[#equal + 1] = c.id end end
check(table.concat(equal, ",") == "face-02,face-03", "same names sort by stable ID")
click(row(nil).star); check(favorite(nil) and a.db.fontId == nil, "baseline has independent default favorite key")
click(row("face-48").star); check(not favorite("face-48"), "favorite toggles off without selecting")
local sorted = true
for i = 2, #menu.choices do
    local x, y = menu.choices[i - 1], menu.choices[i]; local xf, yf = favorite(x.id), favorite(y.id)
    if (not xf and yf) or (xf == yf and (x.name > y.name or (x.name == y.name and (x.id or "") > (y.id or "")))) then sorted = false end
end
check(sorted and row(nil).choice.name == "Antrakt UI Sans", "favorite groups sort alphabetically and baseline is named")
enter(row("face-01")); click(row("face-01"))
check(a.db.fontId == "face-01" and a.Fonts.preview == nil and not menu.popup:IsShown(), "click commits face and retires preview")
check(ui.heading:GetFont() == fonts[1].path and same(), "saved face retains planner context")
click(ui.fontButton); enter(row(nil))
check(ui.heading:GetFont() == BASE and a.db.fontId == "face-01", "baseline hover previews without resetting custom preference")
leave(row(nil)); flush()
check(ui.heading:GetFont() == fonts[1].path and a.Fonts.preview == nil, "baseline leave restores custom preference")
click(row(nil))
check(a.db.fontId == nil and ui.heading:GetFont() == BASE and not menu.popup:IsShown(), "baseline click explicitly clears custom preference")
click(ui.fontButton); click(row("face-01"))
click(ui.fontButton); enter(row("face-02")); menu.catcher.scripts.OnMouseDown(menu.catcher)
check(not menu.popup:IsShown() and not menu.catcher:IsShown() and a.Fonts.preview == nil and ui.heading:GetFont() == fonts[1].path, "outside click restores committed face")
click(ui.fontButton); enter(row("face-03"))
local escape = false; for _, name in ipairs(UISpecialFrames) do if _G[name] == menu.popup then escape = true end end
check(escape or menu.popup.scripts.OnKeyDown ~= nil, "picker supports native Escape")
local function parentEscapeCount()
    local count = 0
    for _, name in ipairs(UISpecialFrames) do if _G[name] == ui.frame then count = count + 1 end end
    return count
end
check(parentEscapeCount() == 0, "open picker leases parent out of global Escape closing")
-- Model CloseSpecialWindows walking every named shown special frame. Merely
-- hiding the popup directly would miss a same-Escape planner dismissal.
for _, name in ipairs(UISpecialFrames) do
    local frame = _G[name]
    if frame and frame:IsShown() then frame:Hide() end
end
check(a.Fonts.preview == nil and ui.heading:GetFont() == fonts[1].path, "Escape restores committed face")
check(ui.frame:IsShown() and not menu.popup:IsShown(), "native Escape closes picker while planner stays open")
check(parentEscapeCount() == 0, "parent Escape registration remains absent during close traversal")
flush()
check(parentEscapeCount() == 1 and ui.frame:IsShown(), "next tick restores one parent Escape registration")
click(ui.fontButton); enter(row("face-02")); menu.popup:Hide()
check(a.Fonts.preview == nil and not menu.catcher:IsShown() and ui.heading:GetFont() == fonts[1].path,
    "native popup hide independently restores committed face")
click(ui.fontButton); enter(row("face-02")); leave(row("face-02")); menu.popup:Hide()
click(ui.fontButton); enter(row("face-03")); flush()
check(a.Fonts.preview ~= nil and ui.heading:GetFont() == fonts[3].path,
    "deferred leave from closed session cannot cancel a new session preview")
check(parentEscapeCount() == 0 and menu.popup:IsShown(),
    "close/reopen suppresses pending parent Escape restoration while picker is open")
menu.popup:Hide()
click(ui.fontButton); unavailable[fonts[4].path] = true; local rejected = row("face-04"); enter(rejected); click(rejected)
check(a.db.fontId == "face-01" and ui.heading:GetFont() == fonts[1].path, "native unavailable asset cannot preview or persist")
menu.popup:Hide(); a.db.fontId = "face-04"; ui:RefreshLanguagePreview(); click(ui.fontButton)
local unavailableOffered = false
for _, choice in ipairs(menu.choices) do if choice.id == "face-04" then unavailableOffered = true end end
check(not unavailableOffered and a.db.fontId == "face-04" and ui.heading:GetFont() == BASE,
    "native failed face is omitted on reopen while saved identity survives fallback")
unavailable[fonts[4].path] = nil; menu.popup:Hide(); click(ui.fontButton); check(row("face-04") ~= nil and a.db.fontId == "face-04", "reopening retries unavailable asset without rewriting preference")
menu.popup:Hide(); a.db.fontId = "face-48"; ui:RefreshLanguagePreview(); click(ui.fontButton)
check(menu.scroll:GetVerticalScroll() > 0, "opening scrolls late saved selection into view")
local selected = row("face-48"); local point = selected.point; local top = -(point[5] or point[3] or 0)
check(top >= menu.scroll:GetVerticalScroll() and top + selected.height <= menu.scroll:GetVerticalScroll() + menu.scroll:GetHeight() + 1, "selected row fits visible viewport")
menu.popup:Hide(); local wide = menu.popup.width; UIParent.width, UIParent.height = 420, 700; click(ui.fontButton)
check(menu.columns >= 1 and menu.columns < 3 and menu.popup.width <= UIParent.width and menu.popup.width < wide, "narrow screen reduces columns and fits")
menu.popup:Hide(); UIParent.width, UIParent.height = 1920, 1080; click(ui.fontButton); enter(row("face-01")); combat = true
check(menu.popup.events.PLAYER_REGEN_DISABLED and menu.popup.scripts.OnEvent,
    "picker independently listens for combat entry")
menu.popup.scripts.OnEvent(menu.popup, "PLAYER_REGEN_DISABLED")
check(not menu.popup:IsShown() and a.Fonts.preview == nil and a.db.fontId == "face-48", "combat retires hover without changing preference")
local oldPrint, blocked = print, nil
print = function(message) blocked = message end
click(ui.fontButton)
print = oldPrint
check(not menu.popup:IsShown() and blocked and blocked:find(a.L("FONT_COMBAT"), 1, true),
    "combat click explains the restriction instead of silently ignoring input")
local originalHint, combatHint = ui.DetailContactHint, nil
ui.DetailContactHint = function(_, _, _, _, description) combatHint = description end
ui.fontButton.scripts.OnEnter(ui.fontButton)
ui.DetailContactHint = originalHint
check(combatHint == a.L("FONT_COMBAT"), "combat hover explains why selection is unavailable")
combat = false; click(ui.fontButton)
check(menu.popup:IsShown(), "the same header click opens normally once combat ends")
enter(row("face-01")); a.db.locale = "koKR"; ui:RefreshLanguagePreview()
check(not menu.popup:IsShown() and a.Fonts.preview == nil and a.db.fontId == "face-48", "locale change retires preview without losing preference")
click(ui.fontButton)
check(#menu.choices == 1 and row(nil).choice.name == "Antrakt UI Sans" and menu.popup.note.text == a.L("FONT_NO_COMPATIBLE"), "empty language intersection retains baseline and explains compatibility")
local oldHint, hintName, hintDescription = ui.DetailContactHint
ui.DetailContactHint = function(_, _, _, name, description) hintName, hintDescription = name, description end
menu.popup.help.scripts.OnEnter(menu.popup.help)
local explanation = a.L("FONT_NO_COMPATIBLE")
check((hintName and hintName:find(explanation, 1, true)) or (hintDescription and hintDescription:find(explanation, 1, true)),
    "empty-intersection explanation appears in visible help rather than only a hidden label")
ui.DetailContactHint = oldHint
menu.popup:Hide(); a.db.locale = "ruRU"; ui:RefreshLanguagePreview(); click(ui.fontButton); enter(row("face-01")); catalog.catalogRevision = string.rep("d", 64)
event.scripts.OnEvent(event, "ADDON_LOADED", "AntraktFonts"); flush()
check(not menu.popup:IsShown() and a.Fonts.preview == nil, "provider revision retires preview and old choices")
click(ui.fontButton); enter(row("face-01")); ui.frame:Hide()
check(not menu.popup:IsShown() and a.Fonts.preview == nil, "planner hide retires UIParent popup")
ui.frame:Show(); check(not menu.popup:IsShown(), "planner reopen does not resurrect picker")

-- Shared media arriving after opening is coalesced, with the same snapshot and
-- scroll ownership as the ordinary collection rather than a second picker.
a.db.locale = "enUS"; GetLocale = function() return "enUS" end; ui:RefreshLanguagePreview()
local registrations, callback, mediaNames, mediaPaths = 0, nil, {}, {}
local media = {}
function media:List(kind) assert(kind == "font"); return mediaNames end
function media:Fetch(kind, name, noDefault) assert(kind == "font" and noDefault); return mediaPaths[name] end
media.RegisterCallback = function(owner, name, fn)
    assert(owner == menu and name == "LibSharedMedia_Registered")
    registrations, callback = registrations + 1, fn
end
local savedStub = LibStub
LibStub = function(name, silent) assert(name == "LibSharedMedia-3.0" and silent); return media end
click(ui.fontButton); flush()
check(registrations == 1 and type(callback) == "function", "opening registers one shared-media listener")
menu:SetScroll(math.min(52, menu.maxScroll)); local heldOffset = menu.scroll:GetVerticalScroll()
local committed = ui.heading:GetFont(); enter(row("face-01"))
mediaNames[1], mediaPaths["Late Face"] = "Late Face", "Interface\\AddOns\\OtherMedia\\Late.ttf"
local beforeCallbacks = #pending
callback("LibSharedMedia_Registered", "sound", "unrelated")
check(#pending == beforeCallbacks, "non-font media registrations do not refresh picker")
local refresh, refreshes = a.Fonts.Refresh, 0
a.Fonts.Refresh = function(self, ...) refreshes = refreshes + 1; return refresh(self, ...) end
for _ = 1, 3 do callback("LibSharedMedia_Registered", "font", "Late Face") end
check(#pending == beforeCallbacks + 1 and refreshes == 0, "font registration burst schedules one deferred update")
flush(); a.Fonts.Refresh = refresh
local lateID
for _, choice in ipairs(menu.choices) do if choice.name == "Late Face" then lateID = choice.id end end
check(refreshes == 1 and lateID and row(lateID), "coalesced update reads new shared-media face exactly once")
check(menu.popup:IsShown() and menu.scroll:GetVerticalScroll() == heldOffset and a.Fonts.preview == nil and ui.heading:GetFont() == committed,
    "shared-media update retains scroll and clears old hover to saved face")
menu.popup:Hide(); click(ui.fontButton)
check(registrations == 1, "reopening reuses existing media listener")
menu.popup:Hide(); callback("LibSharedMedia_Registered", "font", "Late Face"); flush()
check(not menu.popup:IsShown() and a.Fonts.preview == nil, "late media callback cannot reopen a closed picker")

-- Exercise the normal copy-link flow, including its actual canonical URL.
local savedDialogs, savedShow, savedHide = StaticPopupDialogs, StaticPopup_Show, StaticPopup_Hide
local linkBox, linkPopup
StaticPopupDialogs = {}
StaticPopup_Hide = function() if linkPopup then linkPopup:Hide() end end
StaticPopup_Show = function(name, _, _, request)
    linkPopup, linkBox = CreateFrame("Frame"), CreateFrame("EditBox")
    linkPopup.GetEditBox = function() return linkBox end
    StaticPopupDialogs[name].OnShow(linkPopup, request)
    linkPopup:Show()
    return linkPopup
end
click(ui.fontButton); enter(row("face-01")); click(menu.popup.help)
check(linkPopup and linkPopup:IsShown() and linkBox:GetText() == "https://www.curseforge.com/wow/addons/antrakt-fonts",
    "collection help opens existing copy-link flow with canonical CurseForge URL")
check(not menu.popup:IsShown() and a.Fonts.preview == nil and ui.heading:GetFont() == committed,
    "collection link action closes hover preview before displaying copy box")
StaticPopupDialogs, StaticPopup_Show, StaticPopup_Hide = savedDialogs, savedShow, savedHide
ui.developerLinkRequest = nil
LibStub = savedStub

click(ui.fontButton)
local retired, retiredRow = menu.popup, row("face-02")
local replacement = { frame = CreateFrame("Frame"), RefreshLanguagePreview = function() end }
replacement.frame:Show(); a.UI = replacement; menu:Attach(replacement); click(replacement.fontButton)
check(menu.popup ~= retired and menu.popup:IsShown() and not retired:IsShown(), "recreated planner owns a new popup")
enter(row("face-03"))
local heldPreview, savedID, heldFavorites = a.Fonts.preview, a.db.fontId, a.db.fontFavorites
for _, control in ipairs({ retiredRow, retiredRow.star }) do
    for _, script in ipairs({ "OnEnter", "OnLeave", "OnClick" }) do control.scripts[script](control) end
end
flush()
check(menu.popup:IsShown() and a.Fonts.preview == heldPreview and a.db.fontId == savedID and a.db.fontFavorites == heldFavorites,
    "retired row and favorite handlers cannot alter replacement picker preview, choice or favorites")
click(row("face-01")); check(a.db.fontId == "face-01", "replacement planner owns working actions")
print("Font picker UI: " .. total .. " checks passed")
