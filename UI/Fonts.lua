local _, addon = ...
local Menu = { generation = 0, serial = 0 }
addon.FontMenu = Menu
local BASELINE = "Interface\\AddOns\\DungeonPro\\Media\\Fonts\\AntraktUISans.ttf"

local function label(parent, size)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    addon.Theme.ApplyBaselineFont(text, size or 14)
    text:SetJustifyH("LEFT")
    return text
end
local function combat() return addon.Read(InCombatLockdown, "boolean") == true end
local function selection() return addon.Language and addon.Language:GetSelection() or addon.db and addon.db.locale end

function Menu:Current()
    return self.popup and self.popup:IsShown() and addon.UI == self.ui and self.ui.frame == self.parent and
        self.parent:IsShown() and addon.db == self.database and self.selection == selection() and
        self.game == addon.Read(GetLocale, "string") and self.revision == addon.Fonts.revision and not combat()
end

function Menu:CancelPreview()
    self.generation = self.generation + 1
    if addon.Fonts:CancelPreview() and self.ui and addon.UI == self.ui and self.ui.frame == self.parent and self.parent:IsShown() then
        self.ui:RefreshLanguagePreview()
    end
end
function Menu:TakeEscape()
    if self.escapeLease and self.escapeLease.frame == self.parent then return end
    if type(UISpecialFrames) ~= "table" then return end
    local name = addon.Read(self.parent.GetName, "string", self.parent) or "DungeonProWindow"
    local lease = { list = UISpecialFrames, name = name, frame = self.parent, positions = {} }
    for index = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[index] == name then
            table.insert(lease.positions, 1, index)
            table.remove(UISpecialFrames, index)
        end
    end
    self.escapeLease = lease
end
function Menu:ReturnEscape()
    local lease = self.escapeLease
    if not lease or lease.queued then return end
    lease.queued = true
    local function restore()
        lease.queued = false
        if self.escapeLease ~= lease or (self.popup and self.popup:IsShown()) then return end
        self.escapeLease = nil
        if UISpecialFrames ~= lease.list or addon.UI ~= self.ui or self.ui.frame ~= lease.frame then return end
        for _, name in ipairs(lease.list) do if name == lease.name then return end end
        for _, index in ipairs(lease.positions) do table.insert(lease.list, math.min(index, #lease.list + 1), lease.name) end
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0, restore) else restore() end
end
function Menu:Close()
    if self.popup then self.popup:Hide() end
    if self.catcher then self.catcher:Hide() end
    self:CancelPreview()
    self:ReturnEscape()
end
function Menu:Refresh(ui)
    if ui.fontButton and ui.fontButton.caption then ui.fontButton.caption:SetText("Aa") end
    if self.popup and self.popup:IsShown() and not self:Current() then self:Close() end
end
function Menu:Hint(control, heading, name, description)
    if self.ui and self.ui.DetailContactHint then
        self.ui:DetailContactHint(control, heading, name, description, function() return self:Current() and control:IsShown() end)
    end
end
function Menu:LeavePreview()
    self.generation = self.generation + 1
    local generation = self.generation
    local function restore() if self.generation == generation then self:CancelPreview() end end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(.06, restore) else restore() end
end
function Menu:Preview(choice)
    if not self:Current() or not choice or not addon.Theme.FontAvailable(choice.path) then return false end
    self.generation = self.generation + 1
    if not addon.Fonts:Preview(choice.id) then return false end
    self.ui:RefreshLanguagePreview()
    return self:Current()
end
function Menu:SetScroll(value)
    self:CancelPreview()
    value = math.max(0, math.min(self.maxScroll or 0, value))
    self.scroll:SetVerticalScroll(value)
    if self.scrollBar then
        if self.scrollBar.SetMinMaxValues then self.scrollBar:SetMinMaxValues(0, self.maxScroll or 0) end
        if self.scrollBar.SetValue then self.scrollBar:SetValue(value) end
    end
end
function Menu:Metrics()
    local width = addon.Read(UIParent.GetWidth, "number", UIParent) or 1920
    local height = addon.Read(UIParent.GetHeight, "number", UIParent) or 1080
    return { cols = math.max(1, math.min(3, math.floor((width - 30) / 180))),
        buttonWidth = math.min(180, math.max(80, width - 30)), buttonHeight = 26,
        visibleRows = math.max(1, math.floor(math.min(308, height - 100) / 26)) }
end
function Menu:WatchMedia()
    local ok, media = pcall(function() return LibStub and LibStub("LibSharedMedia-3.0", true) end)
    if not ok or not media or self.media == media or type(media.RegisterCallback) ~= "function" then return end
    if self.media and type(self.media.UnregisterCallback) == "function" then
        pcall(self.media.UnregisterCallback, self, "LibSharedMedia_Registered")
    end
    local registered = pcall(media.RegisterCallback, self, "LibSharedMedia_Registered", function(_, kind)
        if kind ~= "font" or self.media ~= media or self.mediaPending then return end
        self.mediaPending = true
        local function update()
            self.mediaPending = false
            if self.media ~= media or not self:Current() then return end
            self:CancelPreview()
            addon.Fonts:Refresh()
            if self.revision ~= addon.Fonts.revision then self:Close(); return end
            self:Populate(false)
        end
        if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(.1, update) else update() end
    end)
    if registered then self.media = media end
end
function Menu:Populate(centerSelection)
    local oldScroll = addon.Read(self.scroll.GetVerticalScroll, "number", self.scroll) or 0
    local fonts = { { name = "Antrakt UI Sans", path = BASELINE, kind = "default" } }
    for _, choice in ipairs(addon.Fonts:Choices()) do
        if addon.Theme.FontAvailable(choice.path) then fonts[#fonts + 1] = choice end
    end
    table.sort(fonts, function(a,b)
        local af,bf = addon.Fonts:IsFavorite(a.id),addon.Fonts:IsFavorite(b.id)
        if af ~= bf then return af end
        if a.name ~= b.name then return a.name < b.name end
        return (a.id or "") < (b.id or "")
    end)
    self.choices = fonts
    local m = self:Metrics()
    self.metrics,self.columns = m,m.cols
    local gridRows = math.ceil(#fonts / m.cols)
    local height = math.min(gridRows,m.visibleRows) * m.buttonHeight
    self.maxScroll = math.max(0,gridRows*m.buttonHeight-height)
    self.popup:SetSize(m.cols*m.buttonWidth+30,height+42)
    self.content:SetSize(m.cols*m.buttonWidth,math.max(1,gridRows*m.buttonHeight))
    self.scroll:SetSize(m.cols * m.buttonWidth, height)
    local selectedRow
    for index,choice in ipairs(fonts) do
        local row = self.rows[index]
        if not row then
            row = CreateFrame("Button",nil,self.content); self.rows[index] = row
            local slot = index
            local function currentRow()
                return self:Current() and self.rows[slot] == row and row.choice and row:IsShown()
            end
            row.bg = row:CreateTexture(nil,"BACKGROUND"); row.bg:SetAllPoints(row)
            row.text = label(row); row.text:SetPoint("LEFT",6,0)
            if row.text.SetWordWrap then row.text:SetWordWrap(false) end
            if row.text.SetMaxLines then row.text:SetMaxLines(1) end
            row.star = CreateFrame("Button",nil,row); row.star:SetSize(24,24); row.star:SetPoint("RIGHT",row,"RIGHT",-2,0)
            row.star.icon = label(row.star,16); row.star.icon:SetAllPoints(row.star); row.star.icon:SetJustifyH("CENTER")
            local function tint(hover)
                row.bg:SetColorTexture(unpack(hover and { .8,.65,.2,.18 } or row.selected and { .12,.22,.28,.9 } or { 0,0,0,0 }))
                row.text:SetTextColor(unpack(hover and { 1,.87,.45 } or { .80,.87,.94 }))
            end
            row.paint = tint
            row:SetScript("OnEnter",function()
                if not currentRow() then return end
                tint(true)
                if self:Preview(row.choice) then self:Hint(row,addon.L("FONT_LABEL"),row.choice.name,addon.L("FONT_HOVER_HELP")) end
            end)
            row:SetScript("OnLeave",function()
                if not currentRow() then return end
                tint(false)
                if self.ui.HideNavigationHint then self.ui:HideNavigationHint(row) end
                self:LeavePreview()
            end)
            row:SetScript("OnClick",function()
                if not currentRow() or not addon.Theme.FontAvailable(row.choice.path) then return end
                if addon.Fonts:Select(row.choice.id) then
                    if self.ui.HideNavigationHint then self.ui:HideNavigationHint(row) end
                    self:Close(); self.ui:RefreshLanguagePreview()
                end
            end)
            row.star:SetScript("OnEnter",function()
                if not currentRow() then return end
                self:Preview(row.choice); tint(true)
                self:Hint(row.star,addon.L(addon.Fonts:IsFavorite(row.choice.id) and "FONT_FAVORITE_REMOVE" or "FONT_FAVORITE_ADD"),
                    row.choice.name,addon.L("FONT_FAVORITE_HELP"))
            end)
            row.star:SetScript("OnLeave",function()
                if not currentRow() then return end
                tint(false)
                if self.ui.HideNavigationHint then self.ui:HideNavigationHint(row.star) end
                self:LeavePreview()
            end)
            row.star:SetScript("OnClick",function()
                if not currentRow() then return end
                self:CancelPreview()
                if addon.Fonts:ToggleFavorite(row.choice.id) then
                    if self.ui.HideNavigationHint then self.ui:HideNavigationHint(row.star) end
                    self:Populate(false)
                end
            end)
        end
        local gridRow,column = math.floor((index-1)/m.cols),(index-1)%m.cols
        row.choice = choice
        row:SetSize(m.buttonWidth,m.buttonHeight); row:ClearAllPoints()
        row:SetPoint("TOPLEFT",self.content,"TOPLEFT",column*m.buttonWidth,-gridRow*m.buttonHeight)
        row.text:SetWidth(m.buttonWidth-34); addon.Theme.ApplyBaselineFont(row.text,14); row.text:SetText(choice.name)
        row.selected = addon.db.fontId == choice.id
        row.star.icon:SetText(addon.Fonts:IsFavorite(choice.id) and "★" or "☆")
        row.star.icon:SetTextColor(1,.82,.35)
        row.paint(false); row:Show()
        if row.selected then selectedRow = gridRow end
    end
    for index=#fonts+1,#self.rows do self.rows[index].choice=nil; self.rows[index]:Hide() end
    local scroll = oldScroll
    if centerSelection then scroll = selectedRow and (selectedRow-math.floor(m.visibleRows/2))*m.buttonHeight or 0 end
    self:SetScroll(scroll)
    self.popup.title:SetText(addon.L("FONT_LABEL")..": "..addon.Fonts:Caption())
    self.popup.title:SetWidth(m.cols*m.buttonWidth-32)
    self.popup.note:SetText(addon.L(#fonts>1 and "FONT_HOVER_HELP" or (#addon.Fonts.records>0 and "FONT_NO_COMPATIBLE" or "FONT_INSTALL")))
    self.popup.help.text:SetText(addon.Fonts:ProviderState() == "ready" and "i" or "!")
end
function Menu:Build(ui)
    self.serial = self.serial+1
    local name = "DungeonProFontPicker"..self.serial
    -- Keep the dropdown in the planner window's native stacking family.
    local popup = CreateFrame("Frame",name,ui.frame,"BackdropTemplate")
    self.popup,self.owner,self.parent = popup,ui,ui.frame
    popup:Hide(); popup:SetFrameStrata("DIALOG"); popup:SetFrameLevel(ui.frame:GetFrameLevel()+50)
    popup:SetClampedToScreen(true); popup:EnableMouse(true)
    popup:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    popup:SetBackdropColor(.035,.055,.07,.99); popup:SetBackdropBorderColor(.25,.43,.54,1)
    popup.title=label(popup,13); popup.title:SetPoint("TOPLEFT",10,-10); popup.title:SetHeight(18)
    popup.note=label(popup,12); popup.note:Hide()
    local help=CreateFrame("Button",nil,popup); help:SetSize(22,22); help:SetPoint("TOPRIGHT",-5,-4)
    help.text=label(help,14); help.text:SetAllPoints(help); help.text:SetJustifyH("CENTER"); help.text:SetText("i")
    help:SetScript("OnEnter",function()
        local state = addon.Fonts:ProviderState()
        local description = popup.note:GetText()
        if state ~= "ready" then description = description .. "\n\n" .. addon.L("FONT_PROVIDER_" .. state) end
        self:Hint(help,"Antrakt Fonts",addon.L("FONT_PROVIDER_"..state),description)
    end)
    help:SetScript("OnClick", function()
        if not self:Current() then return end
        self:Close()
        if ui.ShowDeveloperLink then ui:ShowDeveloperLink("fonts") end
    end)
    help:SetScript("OnLeave",function() if ui.HideNavigationHint then ui:HideNavigationHint(help) end end)
    popup.help=help
    local catcher=CreateFrame("Frame",nil,ui.frame)
    catcher:SetFrameStrata("DIALOG"); catcher:SetFrameLevel(popup:GetFrameLevel()-1)
    catcher:SetAllPoints(UIParent); catcher:EnableMouse(true); catcher:Hide()
    catcher:SetScript("OnMouseDown",function() self:Close() end); self.catcher=catcher
    local scroll=CreateFrame("ScrollFrame",nil,popup,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",6,-34)
    scroll:HookScript("OnVerticalScroll", function() self:CancelPreview() end)
    local content=CreateFrame("Frame",nil,scroll); scroll:SetScrollChild(content)
    self.scroll,self.content,self.scrollBar,self.rows=scroll,content,scroll.ScrollBar,{}
    popup.rows=self.rows; addon.Theme.StyleScrollBar(scroll)
    popup:EnableMouseWheel(true)
    popup:SetScript("OnMouseWheel",function(_,delta)
        self:SetScroll((addon.Read(scroll.GetVerticalScroll,"number",scroll) or 0)-delta*78)
    end)
    popup:SetScript("OnHide",function()
        if self.popup~=popup then return end
        catcher:Hide()
        if ui.HideNavigationHint then ui:HideNavigationHint() end
        self:CancelPreview()
        self:ReturnEscape()
    end)
    popup:RegisterEvent("PLAYER_REGEN_DISABLED")
    popup:SetScript("OnEvent", function() if popup:IsShown() then self:Close() end end)
    if type(UISpecialFrames)=="table" then UISpecialFrames[#UISpecialFrames+1]=name end
end
function Menu:Open(ui)
    if addon.UI~=ui or not ui.frame or not ui.frame:IsShown() then return false end
    if combat() then print("Dungeon Pro: " .. addon.L("FONT_COMBAT")); return false end
    if self.popup and self.popup:IsShown() and self.owner==ui then self:Close(); return false end
    self:Close()
    if addon.Language then addon.Language:Cancel(ui) end
    addon.Fonts:Refresh()
    self:WatchMedia()
    if not self.popup or self.owner~=ui or self.parent~=ui.frame then self:Build(ui) end
    self.ui,self.database=ui,addon.db
    self.selection,self.game,self.revision=selection(),addon.Read(GetLocale,"string"),addon.Fonts.revision
    self:Populate(true)
    self.popup:ClearAllPoints(); self.popup:SetPoint("TOPRIGHT",ui.fontButton,"BOTTOMRIGHT",0,-4)
    self.popup:SetFrameLevel(ui.frame:GetFrameLevel()+50); self.catcher:SetFrameLevel(self.popup:GetFrameLevel()-1)
    self.catcher:Show(); self.popup:Show()
    self:TakeEscape()
    return self:Current()
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
            ui:DetailContactHint(control, addon.L("FONT_LABEL"), caption, addon.L(combat() and "FONT_COMBAT" or "FONT_HELP"), function()
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
