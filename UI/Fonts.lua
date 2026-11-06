local _, addon = ...
local Menu = {}
addon.FontMenu = Menu
local PAGE = 10

local function label(parent, size)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    addon.Theme.ApplyFont(text, size or 14)
    text:SetJustifyH("LEFT")
    return text
end

function Menu:Refresh(ui)
    if ui.fontButton and ui.fontButton.caption then ui.fontButton.caption:SetText("Aa") end
    -- A locale change retires choices filtered for the previous pair of languages.
    local selection = addon.Language and addon.Language:GetSelection() or addon.db and addon.db.locale
    local game = addon.Read(GetLocale, "string")
    if self.popup and (not ui.frame:IsShown() or self.ui ~= ui or self.selection ~= selection or self.game ~= game or
        self.revision ~= addon.Fonts.revision) then self.popup:Hide() end
end

function Menu:Open(ui)
    if addon.UI ~= ui or not ui.frame or not ui.frame:IsShown() then return end
    if self.popup and (self.owner ~= ui or self.parent ~= ui.frame) then
        self.popup:Hide()
        self.popup = nil
    end
    if self.popup and self.popup:IsShown() then self.popup:Hide(); return end
    if addon.Language then addon.Language:Cancel(ui) end
    addon.Fonts:Refresh()
    local popup = self.popup
    if not popup then
        popup = CreateFrame("Frame", nil, ui.frame, "BackdropTemplate")
        self.popup = popup
        self.owner, self.parent = ui, ui.frame
        popup:SetSize(304, 374)
        popup:SetFrameStrata("DIALOG")
        popup:SetFrameLevel(ui.frame:GetFrameLevel() + 20)
        popup:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        popup:SetBackdropColor(.027, .038, .049, 1)
        popup:SetBackdropBorderColor(.2, .27, .3, 1)
        popup:EnableMouse(true)
        popup:EnableMouseWheel(true)
        popup.title = label(popup, 16)
        popup.title:SetPoint("TOPLEFT", 12, -12)
        popup.title:SetWidth(280)
        popup.title:SetHeight(20)
        popup.note = label(popup, 12)
        popup.note:SetPoint("TOPLEFT", 12, -37)
        popup.note:SetWidth(280)
        popup.note:SetHeight(42)
        popup.rows = {}
        for index = 1, PAGE do
            local row = CreateFrame("Button", nil, popup)
            row:SetSize(280, 25)
            row:SetPoint("TOPLEFT", 12, -82 - (index - 1) * 25)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            row.text = label(row)
            row.text:SetPoint("LEFT", 4, 0)
            row.text:SetWidth(270)
            row:SetScript("OnClick", function()
                if not popup:IsShown() or addon.UI ~= ui or not ui.frame:IsShown() or not row.choice then return end
                if addon.Fonts:Select(row.choice.id) then
                    popup:Hide()
                    ui:RefreshLanguagePreview()
                end
            end)
            popup.rows[index] = row
        end
        local function paging(text, x, action)
            local control = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
            control:SetSize(28, 24)
            control:SetPoint("BOTTOMLEFT", x, 10)
            control:SetText(text)
            control:SetScript("OnClick", action)
            addon.Theme.StyleButtonFonts(control)
            return control
        end
        popup.previous = paging("<", 12, function() Menu:Page(-PAGE) end)
        popup.next = paging(">", 46, function() Menu:Page(PAGE) end)
        popup.close = paging("×", 264, function() popup:Hide() end)
        popup.position = label(popup, 12)
        popup.position:SetPoint("BOTTOMLEFT", 86, 15)
        popup:SetScript("OnMouseWheel", function(_, delta) Menu:Page(delta > 0 and -1 or 1) end)
    end
    self.ui = ui
    self.selection = addon.Language and addon.Language:GetSelection() or addon.db and addon.db.locale
    self.game = addon.Read(GetLocale, "string")
    self.revision = addon.Fonts.revision
    self.choices = { { name = addon.L("FONT_DEFAULT") } }
    for _, font in ipairs(addon.Fonts:Choices()) do self.choices[#self.choices + 1] = font end
    self.offset = 0
    popup.title:SetText(addon.L("FONT_LABEL") .. ": " .. addon.Fonts:Caption())
    local note = #self.choices > 1 and "FONT_HELP" or
        (#addon.Fonts.records > 0 and "FONT_NO_COMPATIBLE" or "FONT_INSTALL")
    popup.note:SetText(addon.L(note))
    popup:ClearAllPoints()
    popup:SetPoint("TOPRIGHT", ui.fontButton, "BOTTOMRIGHT", 0, -4)
    self:Page(0)
    popup:Show()
end

function Menu:Page(delta)
    local popup = self.popup
    if not popup or not self.choices then return end
    self.offset = math.max(0, math.min(math.max(0, #self.choices - PAGE), self.offset + delta))
    for index, row in ipairs(popup.rows) do
        local choice = self.choices[self.offset + index]
        row.choice = choice
        if choice then
            addon.Theme.ApplyFont(row.text, 14)
            row.text:SetText((addon.db.fontId == choice.id and "|cffffd080" or "|cffe8e8dc") .. choice.name .. "|r")
            if choice.path then addon.Theme.ApplyFontPreview(row.text, choice.path, 14) end
            row:Show()
        else row:Hide() end
    end
    popup.previous:SetEnabled(self.offset > 0)
    popup.next:SetEnabled(self.offset + PAGE < #self.choices)
    popup.position:SetText(string.format("%d–%d / %d", self.offset + 1, math.min(self.offset + PAGE, #self.choices), #self.choices))
end

function Menu:Attach(ui)
    local control = CreateFrame("Button", nil, ui.frame)
    ui.fontButton = control
    control:SetSize(64, 26)
    control:SetPoint("TOPRIGHT", -188, -14)
    if ui.searchBox then
        ui.searchBox:SetWidth(256)
        ui.searchBox:ClearAllPoints()
        ui.searchBox:SetPoint("TOPRIGHT", control, "TOPLEFT", -12, 0)
        if ui.searchPlaceholder then ui.searchPlaceholder:SetWidth(194) end
    end
    control.caption = label(control, 17)
    control.caption:SetPoint("CENTER", control, "CENTER", -7, 0)
    control.caption:SetWidth(32)
    control.caption:SetHeight(22)
    control.caption:SetJustifyH("CENTER")
    control.chevron = {}
    for index = 1, 2 do
        local stroke = control:CreateTexture(nil, "OVERLAY")
        stroke:SetSize(6, 1.5)
        stroke:SetPoint("CENTER", control, "RIGHT", index == 1 and -16 or -12, 0)
        stroke:SetRotation((index == 1 and -1 or 1) * math.pi / 4)
        stroke:SetColorTexture(.64, .71, .73, 1)
        control.chevron[index] = stroke
    end
    local function hover(active)
        addon.Theme.StyleRow(control, { kind = "control", selected = active })
        control.caption:SetTextColor(unpack(active and { .91, .77, .49 } or { .80, .85, .85 }))
        for _, stroke in ipairs(control.chevron) do
            stroke:SetColorTexture(unpack(active and { .91, .77, .49, 1 } or { .64, .71, .73, 1 }))
        end
    end
    control:SetScript("OnClick", function()
        if ui.HideNavigationHint then ui:HideNavigationHint(control) end
        Menu:Open(ui)
    end)
    control:SetScript("OnEnter", function()
        hover(true)
        if ui.DetailContactHint then
            local selected = addon.db.fontId
            local caption = selected and addon.Fonts:Caption() or "Antrakt UI Sans"
            ui:DetailContactHint(control, addon.L("FONT_LABEL"), caption, addon.L("FONT_HELP"), function()
                return addon.UI == ui and ui.fontButton == control and ui.frame:IsShown() and addon.db.fontId == selected
            end)
        end
    end)
    control:SetScript("OnLeave", function()
        hover(false)
        if ui.HideNavigationHint then ui:HideNavigationHint(control) end
    end)
    hover(false)
    self:Refresh(ui)
end
