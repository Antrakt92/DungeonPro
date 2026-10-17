local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon = fixture.addon
local create = CreateFrame
function fixture.methods:SetAlpha(value) self.alpha = value end
CreateFrame = function(kind, name, parent, template)
    local object = create(kind, name, parent, template)
    if template == "InputBoxTemplate" then
        for _, field in ipairs({ "Left", "Middle", "Right" }) do
            object[field] = create("Texture"); object[field]:SetAlpha(1); object[field]:Show()
        end
    end
    return object
end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
SlashCmdList.DUNGEONPRO("")
local ui = addon.UI
for _, field in ipairs({ "Left", "Middle", "Right" }) do
    local region = ui.searchBox[field]
    assert(not region or region.alpha == 0 or not region:IsShown(), "search suppresses the inherited decorative input border")
end
assert(ui.searchBox.point[1] == "TOPRIGHT", "search belongs on the right of the header")
assert(ui.rangeButton:GetText() == "" and ui.characterButton:GetText() == "", "filter controls display icons instead of captions")
assert(ui.rangeButton.filterIcon and ui.characterButton.filterIcon)
assert(ui.heading.point[2] + ui.heading:GetWidth() < ui.rangeButton.point[2], "long dungeon headings reserve filter space")
local function cards()
    local count = 0
    for _, row in ipairs(ui.cards) do if row:IsShown() then count = count + 1 end end
    return count
end
ui.range, ui.includeUnavailable = false, false; ui:Refresh()
local all = cards()
ui.rangeButton.scripts.OnClick()
assert(ui.range and addon.char.filters.range and ui.rangeButton.filterSelected)
assert(cards() > 0 and cards() < all, "level icon applies the actual catalogue filter")
ui.rangeButton.scripts.OnClick()
assert(not ui.range and not addon.char.filters.range and not ui.rangeButton.filterSelected and cards() == all)
ui.characterButton.scripts.OnClick()
assert(ui.includeUnavailable and addon.char.filters.includeUnavailable and not ui.characterButton.filterSelected)
ui.characterButton.scripts.OnClick()
assert(not ui.includeUnavailable and not addon.char.filters.includeUnavailable and ui.characterButton.filterSelected)
local later, timer = {}, C_Timer.After
C_Timer.After = function(delay, callback) later[#later + 1] = callback end
ui.searchBox:SetText("166"); ui.searchBox.scripts.OnTextChanged(ui.searchBox, true)
assert(ui.pendingSearch, "restyled input keeps debounced typing")
ui.searchBox.scripts.OnEnterPressed(ui.searchBox)
assert(not ui.pendingSearch and ui.cards[1]:IsShown() and ui.cards[1].matchQuestID == 166, "Enter immediately applies the pending query")
ui.clearSearch.scripts.OnClick()
assert(ui.search == "" and ui.searchBox:GetText() == "" and cards() == all)
for _, callback in ipairs(later) do callback() end
assert(ui.search == "" and cards() == all, "old debounce callbacks cannot restore cleared results")
C_Timer.After = timer
for locale in pairs(addon.locales) do
    addon.db.locale = locale; ui:Refresh(true)
    assert(ui.rangeButton:GetText() == "" and ui.characterButton:GetText() == "", "language refresh cannot restore text filter buttons")
    assert(ui.characterButton.filterSelected and not ui.rangeButton.filterSelected)
end
local level, character = ui.range, ui.includeUnavailable
assert(ui.footer == nil, "development notice does not reserve a bottom band")
assert(ui.capacityStatus.point[2] >= ui.title.point[2] + ui.title:GetWidth(), "capacity follows the app title")
assert(ui.capacityStatus.point[2] + ui.capacityStatus:GetWidth() < ui.frame:GetWidth() + ui.searchBox.point[2] - ui.searchBox:GetWidth(),
    "capacity stays left of the search field")
assert(ui.heading.point[2] + ui.heading:GetWidth() < ui.rangeButton.point[2])
assert(ui.characterButton.point[2] + ui.characterButton:GetWidth() < ui.detailScroll.point[2], "filters remain beside the quest heading")
for _, control in ipairs({ ui.giver, ui.source }) do
    assert(control.point[1] == "TOPLEFT" and control.point[2] >= ui.detailScroll.point[2])
    assert(-control.point[3] + control:GetHeight() <= -ui.detailScroll.point[3], "actions sit above detail scrolling content")
end
for _, scroll in ipairs({ ui.catalogScroll, ui.questScroll, ui.detailScroll }) do
    assert(-scroll.point[3] + scroll:GetHeight() == 688, "content reclaims the former bottom band")
end
local measure = ui.heading.GetStringHeight
ui.heading.GetStringHeight = function() return 72 end
ui:RefreshQuests()
for _, scroll in ipairs({ ui.questScroll, ui.detailScroll }) do
    assert(scroll.point[3] == -146 and scroll:GetHeight() == 542, "wrapped headings preserve the reclaimed bottom edge")
end
ui.heading.GetStringHeight = measure; ui:RefreshQuests()
ui.frame:Hide()
ui.rangeButton.scripts.OnClick(); ui.characterButton.scripts.OnClick()
assert(ui.range == level and ui.includeUnavailable == character, "retained callbacks cannot change a closed planner")
print("Actual header controls: PASS (right search, filters, capacity, detail actions, reclaimed footer, wrapped heading, saved modes, debounce, locales)")
