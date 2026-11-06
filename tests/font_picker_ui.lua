-- Exercise the actual TOC, selector and planner together; native asset rendering
-- and readable layout still require the matching client.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, event, methods = fixture.addon, fixture.eventFrame, fixture.methods
local count = 0
local function check(condition, message)
    assert(condition, message)
    count = count + 1
end
function methods:GetFrameLevel() return self.frameLevel or 1 end
function methods:SetFrameLevel(value) self.frameLevel = value end
function methods:EnableMouseWheel(value) self.mouseWheel = value end
function methods:SetFont(path, size, flags)
    self.fontPath, self.fontSize, self.fontFlags = path, size, flags
    return true
end
function methods:GetFont() return self.fontPath, self.fontSize, self.fontFlags end
function methods:Hide()
    local changed = self.shown
    self.shown = false
    if changed and self.scripts.OnHide then self.scripts.OnHide(self) end
end

AntraktFonts = nil
event.scripts.OnEvent(event, "ADDON_LOADED", "DungeonPro")
SlashCmdList.DUNGEONPRO("")
local ui, menu = addon.UI, addon.FontMenu
check(ui.fontButton and ui.fontButton.scripts.OnClick, "planner owns font control")
check(ui.fontButton.caption:GetText() == "Aa" and #ui.fontButton.chevron == 2 and ui.fontButton.width == 64,
    "compact font control has an owned type sample and drawn dropdown chevron")
ui.fontButton.scripts.OnEnter()
ui.fontButton.scripts.OnLeave()
check(ui.fontButton.point[1] == "TOPRIGHT" and ui.fontButton.point[2] == -188,
    "font control sits left of language and links")
local function horizontalBounds(control)
    local point, width = control.point, control.width
    assert(point[1] == "TOPRIGHT", "header uses top-right anchoring")
    local right
    if type(point[2]) == "number" then
        right = ui.frame.width + point[2]
    else
        local left = horizontalBounds(point[2])
        assert(point[3] == "TOPLEFT")
        right = left + point[4]
    end
    return right - width, right
end
local searchLeft, searchRight = horizontalBounds(ui.searchBox)
local fontLeft, fontRight = horizontalBounds(ui.fontButton)
local languageLeft = horizontalBounds(ui.language)
check(searchRight + 8 <= fontLeft and fontRight + 8 <= languageLeft,
    "search, font and language controls have separate horizontal hit areas")
check(searchLeft > ui.capacityStatus.point[2] + ui.capacityStatus.width and ui.searchBox.width >= 240,
    "search retains useful width without overlapping the level filter")
ui.fontButton.scripts.OnClick()
check(menu.popup:IsShown() and #menu.choices == 1, "missing provider keeps a usable default choice")
check(menu.popup.rows[1].choice.id == nil and not menu.popup.rows[2]:IsShown(),
    "missing provider exposes no stale font actions")
check(not menu.popup.previous.enabled and not menu.popup.next.enabled, "single default has no paging")
menu.popup.close.scripts.OnClick()
check(not menu.popup:IsShown(), "close dismisses picker")

local fonts = {}
for index = 1, 15 do
    fonts[index] = { id = "face-" .. index, name = "Face " .. index, file = "Face" .. index .. ".ttf",
        path = "Interface\\AddOns\\AntraktFonts\\fonts\\Face" .. index .. ".ttf",
        sha256 = string.rep("a", 64), latin = true, cyrillic = true,
        hans = false, hant = false, hangul = false, japanese = false }
end
fonts[16] = { id = "latin-only", name = "Latin Only", file = "Latin.ttf",
    path = "Interface\\AddOns\\AntraktFonts\\fonts\\Latin.ttf", sha256 = string.rep("b", 64),
    latin = true, cyrillic = false, hans = false, hant = false, hangul = false, japanese = false }
local catalog = { formatMajor = 1, catalogRevision = string.rep("c", 64), fonts = fonts }
local reads = 0
AntraktFonts = { GetCatalog = function() reads = reads + 1; return catalog end }
event.scripts.OnEvent(event, "ADDON_LOADED", "AntraktFonts")
check(reads == 1, "late provider refreshes snapshot once")
ui.fontButton.scripts.OnClick()
check(#menu.choices == 16, "Russian client filters Latin-only face")
check(menu.popup.next.enabled and not menu.popup.previous.enabled, "first page has forward control")
check(menu.popup.title.width == 280 and menu.popup.title.height == 20,
    "selected font title stays inside popup bounds")
menu.popup.next.scripts.OnClick()
check(menu.offset == 6 and menu.popup.rows[10].choice.id == "face-15", "last page reaches final font")
check(not menu.popup.next.enabled and menu.popup.previous.enabled, "last page disables forward control")
local displayedChoices, displayedLast = menu.choices, menu.popup.rows[10].choice
ui:RefreshLanguagePreview()
check(menu.popup:IsShown() and menu.offset == 6 and menu.choices == displayedChoices and
    menu.popup.rows[10].choice == displayedLast, "same-locale refresh preserves open picker and reading position")
ui:Refresh(nil, true)
check(menu.popup:IsShown() and menu.offset == 6 and menu.choices == displayedChoices,
    "quest-data refresh preserves open picker")
menu.popup.scripts.OnMouseWheel(menu.popup, 1)
check(menu.offset == 5, "wheel moves one font")
menu.popup.previous.scripts.OnClick()
check(menu.offset == 0 and menu.popup.rows[2].choice.id == "face-1", "back paging rebinds pooled rows")
catalog.catalogRevision = string.rep("d", 64)
event.scripts.OnEvent(event, "ADDON_LOADED", "AntraktFonts")
check(not menu.popup:IsShown(), "provider revision refresh retires obsolete choices")

-- Font changes reuse language-only refresh so browsing context survives.
for _, dungeon in ipairs(addon.dungeons) do if dungeon.key == "dm" then ui.dungeon = dungeon end end
ui.quest, ui.search, ui.range, ui.preparation = 166, "166", false, true
ui:RefreshLanguagePreview()
local dungeon, quest, search, preparation = ui.dungeon, ui.quest, ui.search, ui.preparation
ui.fontButton.scripts.OnClick()
menu.popup.rows[2].scripts.OnClick()
check(addon.db.fontId == "face-1" and not menu.popup:IsShown(), "click persists selected identity and closes")
check(ui.dungeon == dungeon and ui.quest == quest and ui.search == search and ui.preparation == preparation,
    "font selection retains dungeon, quest, search and preparation")
check(ui.heading:GetFont() == fonts[1].path, "tracked planner text applies selected provider asset")
ui.fontButton.scripts.OnClick()
menu.popup.rows[1].scripts.OnClick()
check(addon.db.fontId == nil and not menu.popup:IsShown(), "default explicitly resets preference")
check(ui.heading:GetFont():find("AntraktUISans", 1, true), "default returns to shared multilingual baseline")

ui.fontButton.scripts.OnClick()
ui.fontButton.scripts.OnClick()
check(not menu.popup:IsShown(), "header toggle closes existing picker")
ui.fontButton.scripts.OnClick()
local oldClick = menu.popup.rows[2].scripts.OnClick
addon.db.locale = "koKR"
ui:RefreshLanguagePreview()
check(not menu.popup:IsShown(), "locale refresh retires old filtered choices")
oldClick()
check(addon.db.fontId == nil, "retired choice callback cannot select old incompatible face")
ui.fontButton.scripts.OnClick()
check(#menu.choices == 1 and menu.popup.rows[2].choice == nil and not menu.popup.rows[2]:IsShown(),
    "reopen with no compatible faces clears pooled rows")
check(menu.popup.note.text == addon.L("FONT_NO_COMPATIBLE"),
    "loaded collection without a shared script intersection does not ask for reinstall")
menu.popup.rows[2].scripts.OnClick()
check(addon.db.fontId == nil, "empty pooled row cannot change preference")
menu.popup.close.scripts.OnClick()

addon.db.locale = "ruRU"
ui:RefreshLanguagePreview()
ui.fontButton.scripts.OnClick()
ui.frame:Hide()
check(not menu.popup:IsShown(), "planner hide explicitly retires picker")
oldClick()
check(addon.db.fontId == nil, "hidden planner cannot accept old row click")
ui.frame:Show()
check(not menu.popup:IsShown(), "reopening planner does not resurrect prior picker")

local retiredPopup = menu.popup
local replacement = { frame = CreateFrame("Frame"), RefreshLanguagePreview = function() end }
replacement.frame:Show()
addon.UI = replacement
menu:Attach(replacement)
replacement.fontButton.scripts.OnClick()
check(menu.popup ~= retiredPopup and menu.popup:IsShown() and not retiredPopup:IsShown(),
    "recreated planner receives its own popup instead of stale parent and click handlers")
menu.popup.rows[2].scripts.OnClick()
check(addon.db.fontId == "face-1", "replacement planner owns working font actions")

print("Font picker UI: " .. count .. " checks passed")
