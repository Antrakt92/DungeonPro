local addon, total, secret = {}, 0, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
issecretvalue = function(value) return value == secret end
local methods = {}
local function region()
    return setmetatable({ textures = {}, text = "kept", width = 200, height = 40, scripts = {} }, { __index = methods })
end
function methods:CreateTexture(_, layer, _, sublevel)
    if self.failTexture then error("unavailable") end
    local result = region()
    result.layer, result.sublevel = layer, sublevel
    self.textures[#self.textures + 1] = result
    return result
end
function methods:SetColorTexture(...) self.color = {...} end
function methods:SetTextColor(...) self.textColor = {...} end
function methods:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = {...} end
function methods:SetAllPoints(value) self.allPoints = value end
function methods:SetWidth(value) self.width = value end
function methods:SetHeight(value) self.height = value end
function methods:SetAlpha(value) self.alpha = value end
function methods:SetBackdrop(value) self.backdrop = value; self.backdropCleared = value == nil end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:GetHighlightTexture() return self.highlight end
function methods:GetNormalTexture() return self.normal end
function methods:GetPushedTexture() return self.pushed end
function methods:GetDisabledTexture() return self.disabled end
function methods:GetFontString() return self.font end
local function row()
    local result = region()
    result.bg, result.title, result.note, result.art = region(), region(), region(), region()
    result.highlight = region()
    return result
end
local function reset()
    assert(loadfile("UI/Theme.lua"))("DungeonPro", addon)
end
local function test(name, fn)
    reset(); fn(); total = total + 1; print("ok - " .. name)
end
local function resolvedPath(region)
    if region.path then return region.path end
    if type(region.family) == "table" then return resolvedPath(region.family) end
    return nil
end
local function resolvedHeight(region)
    return region.height or (type(region.family) == "table" and resolvedHeight(region.family))
end
local function resolvedFamily(region, family)
    return region == family or (type(region.family) == "table" and resolvedFamily(region.family, family))
end
test("window hierarchy preserves content geometry and handlers", function()
    local ui = { frame = region(), title = region(), subtitle = region(), coverage = region() }
    local click = function() end
    ui.frame.scripts.OnClick = click
    assert(addon.Theme.Apply(ui))
    assert(ui.frame.backdropCleared and ui.frame.width == 200 and ui.frame.height == 40)
    assert(ui.frame.scripts.OnClick == click and not ui.frame.points)
    assert(ui.title.text == "kept" and ui.title.textColor[1] > ui.subtitle.textColor[1])
    assert(ui.subtitle.textColor[1] > ui.coverage.textColor[1])
    assert(ui.frame.textures[1].color[1] < .05)
end)
test("repeated application uses bounded decoration", function()
    local ui = { frame = region(), back = region() }
    assert(addon.Theme.Apply(ui)); local count = #ui.frame.textures
    local controls = #ui.back.textures
    for _ = 1, 100 do assert(addon.Theme.Apply(ui)) end
    assert(#ui.frame.textures == count and #ui.back.textures == controls)
    assert(count == 8 and controls == 6)
end)

test("compact header divider stays above the raised catalogue and dungeon heading", function()
    local ui = { frame = region() }
    assert(addon.Theme.Apply(ui))
    local found = false
    for _, texture in ipairs(ui.frame.textures) do
        if texture.color and texture.color[1] > .8 and texture.color[2] > .6 and texture.color[3] < .4 then
            local point = texture.points and texture.points[1]
            if point and point[1] == "TOPLEFT" then
                assert(point[5] > -66 and point[5] < -40)
                found = true
            end
        end
    end
    assert(found)
end)
test("recycled selected dungeon clears accent and restores border", function()
    local r = row()
    assert(addon.Theme.StyleRow(r, {kind="dungeon",selected=true}))
    local edge, accent = r.textures[1], r.textures[5]
    assert(accent.shown and edge.color[1] > edge.color[2])
    local selected = r.bg.color[1]
    assert(addon.Theme.StyleRow(r, {kind="dungeon",selected=false}))
    assert(not accent.shown and r.bg.color[1] < selected and edge.color[1] < .2)
    assert(#r.textures == 9)
end)
test("dungeon cards frame existing art and preserve layout assets handlers and bounded decoration", function()
    local r = row(); r.art.texture = "original-cover"
    local click, enter = function() end, function() end
    r.scripts.OnClick, r.scripts.OnEnter = click, enter
    assert(addon.Theme.StyleRow(r, { kind = "dungeon" }))
    assert(#r.textures == 9)
    for i = 6, 9 do
        assert(r.textures[i].shown and r.textures[i].points[1][2] == r.art)
    end
    assert(r.title.textColor[1] > r.note.textColor[1] and r.highlight.color[4] <= .07)
    for _ = 1, 100 do assert(addon.Theme.StyleRow(r, { kind = "dungeon" })) end
    assert(#r.textures == 9 and r.art.texture == "original-cover" and not r.art.points)
    assert(r.width == 200 and r.height == 40 and not r.points)
    assert(r.scripts.OnClick == click and r.scripts.OnEnter == enter and not r.scripts.OnUpdate)
    assert(addon.Theme.StyleRow(r, { kind = "quest" }))
    for i = 6, 9 do assert(not r.textures[i].shown) end
end)

test("late card-frame tint cannot restore a recycled quest thumbnail border", function()
    local r = row()
    assert(addon.Theme.StyleRow(r, { kind = "dungeon" }))
    local edge, armed = r.textures[6], true
    local setter = edge.SetColorTexture
    edge.SetColorTexture = function(self, ...)
        if armed then
            armed = false
            assert(addon.Theme.StyleRow(r, { kind = "quest", selected = true }))
        end
        return setter(self, ...)
    end
    assert(not addon.Theme.StyleRow(r, { kind = "dungeon", selected = true }))
    for i = 6, 9 do assert(not r.textures[i].shown) end
    assert(r.bg.color[2] > r.bg.color[1] and r.title.textColor[2] > .8)
end)

test("quest and section styles retain text art layout and actions", function()
    local r = row(); r.art.texture = "native-art"; r.enabled = false
    local click = function() end; r.scripts.OnClick = click
    assert(addon.Theme.StyleRow(r, {kind="quest",selected=true}))
    assert(r.textures[1].color[2] > r.textures[1].color[1])
    assert(addon.Theme.StyleRow(r, {kind="section"}))
    assert(r.title.textColor[1] > r.note.textColor[1])
    assert(r.title.text == "kept" and r.art.texture == "native-art" and #r.art.textures == 0)
    assert(r.width == 200 and r.height == 40 and not r.points and r.enabled == false and r.scripts.OnClick == click)
end)

test("target paths remain visible while the selected step and chronological goal have distinct styling", function()
    local r = row(); r.questTreeNode, r.questTreePath = true, true
    r.treeRail, r.treeElbow, r.dungeonTargetLabel = region(), region(), region()
    assert(addon.Theme.StyleRow(r, { kind = "quest" }))
    local path = r.treeRail.color[1]
    assert(path > .5 and r.treeElbow.color[1] == path)
    r.questTreePath = false; assert(addon.Theme.StyleRow(r, { kind = "quest" }))
    assert(r.treeRail.color[1] < path and r.title.textColor[1] < .8)
    r.questTreePath, r.questTreeTarget, r.dungeonTarget = true, true, true
    assert(addon.Theme.StyleRow(r, { kind = "quest" }))
    assert(r.textures[1].color[1] > .8 and r.title.textColor[1] > .9)
    local goal = r.bg.color[1]
    assert(addon.Theme.StyleRow(r, { kind = "quest", selected = true }))
    assert(r.bg.color[1] ~= goal and r.textures[5].shown and r.textures[1].color[1] > .8)
    assert(r.treeRail.color[1] == path and r.dungeonTargetLabel.textColor[1] > .9)
end)

test("expanded anchors persist across step selection and recycled rows lose their old target styling", function()
    local anchor, step = row(), row(); anchor.questTreeAnchor = true
    assert(addon.Theme.StyleRow(anchor, { kind = "quest" }))
    local border = anchor.textures[1].color[2]
    assert(anchor.textures[5].shown)
    step.questTreeNode, step.questTreePath = true, true
    assert(addon.Theme.StyleRow(step, { kind = "quest", selected = true }))
    assert(anchor.textures[1].color[2] == border and anchor.textures[5].shown)
    anchor.questTreeAnchor = false
    assert(addon.Theme.StyleRow(anchor, { kind = "quest" }))
    assert(not anchor.textures[5].shown and anchor.textures[1].color[2] < border)
end)

test("a late old target color cannot overwrite the newly selected pooled row", function()
    local r = row(); r.questTreeNode, r.questTreePath, r.questTreeTarget = true, true, true
    local setter, armed = r.title.SetTextColor, true
    r.title.SetTextColor = function(self, ...)
        if armed then
            armed = false; r.questTreeTarget, r.questTreePath = false, false
            assert(addon.Theme.StyleRow(r, { kind = "quest", selected = true }))
        end
        return setter(self, ...)
    end
    assert(not addon.Theme.StyleRow(r, { kind = "quest" }))
    assert(not armed and r.textures[5].shown and r.textures[1].color[1] < .5)
    assert(r.title.textColor[1] > .9 and r.title.textColor[2] > .9)
end)
test("modern control preserves click and disabled state", function()
    local r = row(); r.normal,r.pushed,r.disabled,r.font = region(),region(),region(),region()
    local click = function() end; r.scripts.OnClick = click; r.enabled = false
    assert(addon.Theme.StyleRow(r, {kind="control",selected=true}))
    assert(r.normal.alpha == 0 and r.pushed.alpha == 0 and r.disabled.alpha == 0)
    assert(not r.font.textColor and r.highlight.color[4] < .1)
    assert(r.enabled == false and r.scripts.OnClick == click)
end)
test("composite template textures stay quiet while native font states survive", function()
    local r = row(); r.Left,r.Middle,r.Right,r.font = region(),region(),region(),region()
    r.font.textColor = { .5,.5,.5,1 }; local disabledColor = r.font.textColor
    assert(addon.Theme.StyleRow(r, {kind="control",selected=true}))
    assert(r.Left.alpha == 0 and r.Middle.alpha == 0 and r.Right.alpha == 0)
    assert(r.font.textColor == disabledColor and r.highlight.allPoints == r)
    r.Left.texture = "native-pushed"
    assert(r.Left.alpha == 0)
end)
test("viewport depth follows existing geometry without click frames or polling", function()
    local ui = {frame=region(),catalogScroll=region(),questScroll=region(),detailScroll=region()}
    assert(addon.Theme.Apply(ui))
    assert(#ui.frame.textures == 17)
    local count = #ui.frame.textures
    for _=1,100 do assert(addon.Theme.Apply(ui)) end
    assert(#ui.frame.textures == count)
    for _, target in ipairs({ui.catalogScroll,ui.questScroll,ui.detailScroll}) do
        assert(not target.points and #target.textures == 0 and not next(target.scripts))
    end
    local surfaces = 0
    for _, part in ipairs(ui.frame.textures) do
        if part.points and part.points[1][2] ~= ui.frame then
            surfaces = surfaces + 1
            assert(part.points[1][2] == ui.catalogScroll or part.points[1][2] == ui.questScroll or part.points[1][2] == ui.detailScroll)
        end
    end
    assert(surfaces == 9)
end)
test("invalid and restricted values do not create surfaces", function()
    assert(not addon.Theme.Apply(nil) and not addon.Theme.Apply({frame=secret}))
    assert(not addon.Theme.StyleRow(secret, {kind="quest"}))
    local r = row()
    assert(not addon.Theme.StyleRow(r, {kind="unsupported"}) and #r.textures == 0)
    assert(addon.Theme.StyleRow(r, {kind="quest",selected=secret}))
    assert(not r.textures[5].shown)
end)
test("failed optional native texture capability stays bounded", function()
    local r = row(); r.failTexture = true
    for _ = 1, 100 do assert(not addon.Theme.StyleRow(r, {kind="quest"})) end
    assert(#r.textures == 0 and r.title.text == "kept")
    assert(not addon.Theme.StyleRow({}, {kind="quest"}))
end)
test("readable native font families use real font height and never scale text or mutate the shared family",function()
    local oldChat,oldHighlight=ChatFontNormal,GameFontHighlight
    local family={sentinel=true};ChatFontNormal=family;GameFontHighlight={}
    local r=region();r.SetFontObject=function(self,value)self.family=value end
    r.SetFontHeight=function(self,value)self.fontHeight=value end
    r.SetTextHeight=function()error("text scaling is forbidden")end
    r.SetShadowOffset=function(self,x,y)self.shadow={x,y}end
    assert(addon.Theme.ApplyFont(r,26)==family and r.family==family and r.fontHeight==26)
    assert(r.shadow[1]==0 and r.shadow[2]==0 and family.sentinel and not family.fontHeight)
    ChatFontNormal=secret;assert(addon.Theme.ApplyFont(r,14)==GameFontHighlight)
    r.SetFontHeight=function()error("unavailable native setter")end
    r.SetFont=function(self,path,size,flags)self.path,self.fontHeight,self.flags=path,size,flags;return true end
    assert(addon.Theme.ApplyFont(r,14) and resolvedPath(r) and r.fontHeight==14 and r.flags=="")
    ChatFontNormal,GameFontHighlight=oldChat,oldHighlight
end)
test("button roles use three owned font clones with distinct disabled color and bounded reuse",function()
    local chat,creator=ChatFontNormal,CreateFont
    ChatFontNormal={untouched=true};local made=0
    CreateFont=function(name)
        made=made+1;assert(name:find("DungeonProControlFont",1,true)==1)
        return {SetFontObject=function(self,family)self.family=family end,SetFontHeight=function(self,height)self.height=height end,
            SetTextColor=function(self,...)self.color={...}end,SetShadowOffset=function()end}
    end
    local button=region();local original={Normal={},Highlight={},Disabled={}}
    for _,role in ipairs({"Normal","Highlight","Disabled"})do
        button[role]=original[role]
        button["Get"..role.."FontObject"]=function(self)return self[role]end
        button["Set"..role.."FontObject"]=function(self,font)self[role]=font end
    end
    assert(addon.Theme.StyleButtonFonts(button))
    assert(made==3 and button.Normal~=original.Normal and button.Disabled~=original.Disabled)
    assert(button.Normal.family==ChatFontNormal and button.Normal.height==14 and button.Disabled.height==14)
    assert(button.Normal.color[1]>button.Disabled.color[1] and button.Highlight.color[1]>button.Disabled.color[1])
    assert(not ChatFontNormal.height and ChatFontNormal.untouched)
    for n=1,20 do assert(addon.Theme.StyleButtonFonts(button))end
    assert(made==3)
    local nextButton=region()
    for _,role in ipairs({"Normal","Highlight","Disabled"})do
        nextButton[role]=original[role]
        nextButton["Get"..role.."FontObject"]=button["Get"..role.."FontObject"]
        nextButton["Set"..role.."FontObject"]=button["Set"..role.."FontObject"]
    end
    nextButton.SetHighlightFontObject=function()error("setter unavailable")end
    assert(not addon.Theme.StyleButtonFonts(nextButton) and nextButton.Normal==original.Normal and nextButton.Disabled==original.Disabled)
    ChatFontNormal,CreateFont=chat,creator
end)
test("EditBox uses an owned native-family font clone without a nonexistent direct height setter",function()
    local chat,creator=ChatFontNormal,CreateFont
    ChatFontNormal={native=true};local made=0
    CreateFont=function(name)
        made=made+1;assert(name:find("DungeonProInputFont",1,true)==1)
        return {SetFontObject=function(self,value)self.family=value end,SetFontHeight=function(self,value)self.height=value end,
            SetTextColor=function(self,...)self.color={...}end,SetShadowOffset=function()end}
    end
    local input={SetFontObject=function(self,font)self.font=font end,
        SetFont=function()error("native family must not fall back to a single path")end}
    local font=addon.Theme.ApplyInputFont(input)
    assert(font and input.font==font and font~=ChatFontNormal and font.family==ChatFontNormal and font.height==14)
    for n=1,20 do assert(addon.Theme.ApplyInputFont(input)==font)end
    assert(made==1 and ChatFontNormal.native and not ChatFontNormal.height)
    CreateFont=nil
    assert(addon.Theme.ApplyInputFont(input)==ChatFontNormal and input.font==ChatFontNormal)
    ChatFontNormal,CreateFont=chat,creator
end)
function methods:GetAlpha()return self.alpha or 1 end
function methods:SetRotation(value)self.rotation=value end
function methods:IsEnabled()return self.enabled~=false end
function methods:IsShown()return self.shown~=false end
function methods:IsMouseEnabled()return self.mouseEnabled~=false end
function methods:EnableMouse(value)self.mouseEnabled=value end
function methods:GetMinMaxValues()return self.minimum or 0,self.maximum or 100 end
MouseIsOver=function(object)return object.pointer==true end
function methods:HookScript(name,callback)
    if self.hookFailure==name then return false end
    if self.hookThrow==name then error("unsupported")end
    self.hooks=self.hooks or {};self.hooks[name]=self.hooks[name]or{};table.insert(self.hooks[name],callback);return true
end
local function nativeEvent(object,name,...)
    if object.scripts[name]then object.scripts[name](object,...)end
    for _,fn in ipairs(object.hooks and object.hooks[name]or{})do fn(object,...)end
end
local function scrollFixture()
    local scroll,bar=region(),region();scroll.ScrollBar=bar
    bar.ThumbTexture=region();bar.ThumbTexture.width,bar.ThumbTexture.height=18,24
    bar.ScrollUpButton,bar.ScrollDownButton=region(),region()
    for _,button in ipairs({bar.ScrollUpButton,bar.ScrollDownButton})do
        button.width,button.height=18,16
        for _,key in ipairs({"Normal","Pushed","Disabled","Highlight"})do button[key]=region()end
        button.scripts.OnClick=function(self)self.clicked=(self.clicked or 0)+1 end
        button.scripts.OnEnter=function(self)self.entered=(self.entered or 0)+1 end
    end
    bar.scripts.OnValueChanged=function(self,n)self.value=n end
    bar.scripts.OnMouseDown=function(self,button)self.dragButton=button end
    scroll.scripts.OnMouseWheel=function(self,n)self.wheel=n end
    return scroll,bar
end
test("all three native scrollbars receive bounded quiet cosmetics while native geometry and handlers stay intact",function()
    local ui={frame=region()}
    ui.catalogScroll=scrollFixture();ui.questScroll=scrollFixture();ui.detailScroll=scrollFixture()
    local totalTextures=0
    for _,scroll in ipairs({ui.catalogScroll,ui.questScroll,ui.detailScroll})do
        local bar=scroll.ScrollBar;bar.shown=false;bar.ThumbTexture.shown=false
        local click=bar.ScrollUpButton.scripts.OnClick;local value=bar.scripts.OnValueChanged;local drag=bar.scripts.OnMouseDown
        assert(addon.Theme.Apply(ui))
        assert(not bar.shown and not bar.ThumbTexture.shown and not bar.points)
        assert(bar.ThumbTexture.width==18 and bar.ThumbTexture.height==24 and not bar.ThumbTexture.points)
        assert(bar.ThumbTexture.color[2]>bar.ThumbTexture.color[1])
        assert(#bar.textures==1 and bar.textures[1].width==3)
        assert(bar.ScrollUpButton.width==18 and bar.ScrollUpButton.height==16 and not bar.ScrollUpButton.points)
        assert(bar.ScrollUpButton.scripts.OnClick==click and bar.scripts.OnValueChanged==value and bar.scripts.OnMouseDown==drag)
        assert(not bar.scripts.OnUpdate and not scroll.scripts.OnUpdate)
        nativeEvent(bar.ScrollUpButton,"OnClick");nativeEvent(bar,"OnValueChanged",30);nativeEvent(scroll,"OnMouseWheel",1)
        nativeEvent(bar,"OnMouseDown","LeftButton")
        assert(bar.ScrollUpButton.clicked==1 and bar.value==30 and scroll.wheel==1 and bar.dragButton=="LeftButton")
        local a,b=bar.ScrollUpButton,bar.ScrollDownButton
        assert(#a.textures==2 and #b.textures==2 and a.textures[1].rotation==-b.textures[1].rotation)
        assert(a.Normal.alpha==0 and a.Pushed.alpha==0 and a.Disabled.alpha==0 and a.Highlight.alpha==0)
        totalTextures=totalTextures+#bar.textures+#a.textures+#b.textures
    end
    for n=1,100 do assert(addon.Theme.Apply(ui))end
    local after=0
    for _,scroll in ipairs({ui.catalogScroll,ui.questScroll,ui.detailScroll})do
        local bar=scroll.ScrollBar;after=after+#bar.textures+#bar.ScrollUpButton.textures+#bar.ScrollDownButton.textures
        for _,button in ipairs({bar.ScrollUpButton,bar.ScrollDownButton})do
            for name,list in pairs(button.hooks)do assert(#list==((name=="OnEnter"or name=="OnLeave")and 2 or 1))end
        end
    end
    assert(totalTextures==15 and after==totalTextures)
end)

test("quiet bars reveal on viewport and controls while idle targets stop intercepting clicks",function()
    local scroll,bar=scrollFixture()
    assert(addon.Theme.StyleScrollBar(scroll))
    assert(bar.alpha==0 and not bar.mouseEnabled and not bar.ScrollUpButton.mouseEnabled)
    scroll.pointer=true;nativeEvent(scroll,"OnEnter")
    assert(bar.alpha==.5 and bar.mouseEnabled and bar.ScrollUpButton.mouseEnabled)
    scroll.pointer=false;bar.pointer=true;nativeEvent(scroll,"OnLeave")
    assert(bar.alpha==1 and bar.mouseEnabled)
    bar.pointer=false;nativeEvent(bar,"OnLeave")
    assert(bar.alpha==0 and not bar.mouseEnabled)
    -- Geometry still discovers disabled native controls, without an invisible hit target.
    bar.pointer=true;nativeEvent(scroll,"OnUpdate",.04);assert(bar.alpha==0)
    nativeEvent(scroll,"OnUpdate",.04);assert(bar.alpha==1 and bar.mouseEnabled)
end)

test("native drag wheel and click handlers survive quiet leave and repeated theme application",function()
    local scroll,bar=scrollFixture();local button=bar.ScrollDownButton
    local down,change,wheel,click=bar.scripts.OnMouseDown,bar.scripts.OnValueChanged,scroll.scripts.OnMouseWheel,button.scripts.OnClick
    local nativeUpdate=function(self)self.nativeTicks=(self.nativeTicks or 0)+1 end
    scroll.scripts.OnUpdate=nativeUpdate
    assert(addon.Theme.StyleScrollBar(scroll))
    for i=1,30 do addon.Theme.StyleScrollBar(scroll)end
    assert(bar.scripts.OnMouseDown==down and bar.scripts.OnValueChanged==change and scroll.scripts.OnMouseWheel==wheel and button.scripts.OnClick==click)
    assert(scroll.scripts.OnUpdate==nativeUpdate and #scroll.hooks.OnUpdate==1)
    bar.pointer=true;nativeEvent(scroll,"OnUpdate",.1);nativeEvent(bar,"OnMouseDown","LeftButton")
    bar.pointer=false;nativeEvent(bar,"OnLeave");nativeEvent(scroll,"OnUpdate",.1)
    assert(bar.alpha==1 and bar.mouseEnabled and bar.dragButton=="LeftButton")
    nativeEvent(bar,"OnValueChanged",25);nativeEvent(scroll,"OnMouseWheel",-1);nativeEvent(button,"OnClick")
    assert(bar.value==25 and scroll.wheel==-1 and button.clicked==1 and scroll.nativeTicks==2)
    nativeEvent(bar,"OnMouseUp","LeftButton");assert(bar.alpha==0 and not bar.mouseEnabled)
    addon.Theme.StyleScrollBar(scroll);scroll.pointer=true;nativeEvent(scroll,"OnEnter")
    assert(bar.mouseEnabled,"reapplication must preserve original mouse policy rather than capture idle false")
end)

test("no overflow hidden parents and restricted mouse state leave bars quiet",function()
    local scroll,bar=scrollFixture();scroll.pointer=true;bar.pointer=true
    assert(addon.Theme.StyleScrollBar(scroll));assert(bar.alpha==1)
    bar.maximum=0;nativeEvent(scroll,"OnUpdate",.1);assert(bar.alpha==0 and not bar.mouseEnabled and bar.shown~=false)
    bar.maximum=100;scroll.IsVisible=function()return false end
    nativeEvent(scroll,"OnUpdate",.1);assert(bar.alpha==0 and not bar.mouseEnabled)
    scroll.IsVisible=nil
    local old=MouseIsOver;MouseIsOver=function()return secret end
    local s,b=scrollFixture();addon.Theme.StyleScrollBar(s);nativeEvent(s,"OnUpdate",.1)
    assert(b.alpha==0 and not b.mouseEnabled);MouseIsOver=old
end)

test("quiet styling preserves a disabled native mouse policy and fails without altering input",function()
    local scroll,bar=scrollFixture();bar.mouseEnabled=false;bar.pointer=true
    assert(addon.Theme.StyleScrollBar(scroll));assert(bar.alpha==1 and not bar.mouseEnabled)
    local s,b=scrollFixture();s.hookFailure="OnUpdate"
    assert(addon.Theme.StyleScrollBar(s));assert(b.alpha==nil and b.mouseEnabled==nil)
    s.pointer=true;nativeEvent(s,"OnEnter");assert(b.alpha==nil and b.mouseEnabled==nil)
    for i=1,30 do addon.Theme.StyleScrollBar(s)end
    assert(#s.hooks.OnEnter==1 and not s.hooks.OnUpdate)
end)

test("lost native mouse-up recovers through clean button state and restricted ranges never reveal controls",function()
    local scroll,bar=scrollFixture();bar.pointer=true
    local before=IsMouseButtonDown;local pressed=true
    IsMouseButtonDown=function()return pressed end
    assert(addon.Theme.StyleScrollBar(scroll))
    nativeEvent(bar,"OnMouseDown","LeftButton");bar.pointer=false;nativeEvent(scroll,"OnUpdate",.1)
    assert(bar.alpha==1 and bar.mouseEnabled)
    pressed=false;nativeEvent(scroll,"OnUpdate",.1)
    assert(bar.alpha==0 and not bar.mouseEnabled)
    bar.pointer=true;bar.GetMinMaxValues=function()return 0,secret end
    -- Replaced capabilities restore native input instead of freezing a hidden disabled slider.
    nativeEvent(scroll,"OnUpdate",.1);assert(bar.alpha==1 and bar.mouseEnabled)
    local s,b=scrollFixture();b.GetMinMaxValues=function()return 0,secret end;b.pointer=true
    addon.Theme.StyleScrollBar(s);assert(b.alpha==0 and not b.mouseEnabled)
    IsMouseButtonDown=before
end)
test("native arrow enable hover and disable events update only owned chevrons",function()
    local scroll,bar=scrollFixture();bar.ScrollUpButton.enabled=false
    assert(addon.Theme.StyleScrollBar(scroll))
    local button=bar.ScrollUpButton;local stroke=button.textures[1]
    assert(stroke.alpha==.38 and not button.enabled)
    button.enabled=true;nativeEvent(button,"OnEnable");assert(stroke.alpha==1)
    local normal=stroke.color[2];nativeEvent(button,"OnEnter")
    assert(button.entered==1 and stroke.color[2]~=normal and stroke.color[2]>stroke.color[1])
    nativeEvent(button,"OnLeave");assert(stroke.color[2]==normal)
    button.enabled=false;nativeEvent(button,"OnDisable");assert(stroke.alpha==.38 and not button.enabled)
    bar:Hide();assert(not bar.shown and not bar.ThumbTexture.shown)
    bar:Show();assert(bar.shown and not bar.ThumbTexture.shown)
end)
test("missing rotation hook capabilities and partial hook failures preserve original arrow art without repeated hooks",function()
    for _,failure in ipairs({"rotation","missinghook","falsehook","throwhook","secondtexture","alpha"})do
        local scroll,bar=scrollFixture();local button=bar.ScrollUpButton
        if failure=="rotation"then button.CreateTexture=function(self,...)local t=methods.CreateTexture(self,...);t.SetRotation=false;return t end end
        if failure=="missinghook"then button.HookScript=false end
        if failure=="falsehook"then button.hookFailure="OnEnable"end
        if failure=="throwhook"then button.hookThrow="OnEnable"end
        if failure=="secondtexture"then button.CreateTexture=function(self,...)if #self.textures==1 then error("cold")end;return methods.CreateTexture(self,...)end end
        if failure=="alpha"then button.Normal.SetAlpha=function()error("unavailable")end end
        addon.Theme.StyleScrollBar(scroll)
        assert(button.Normal.alpha==nil and button.Pushed.alpha~=0 and button.Disabled.alpha~=0 and button.Highlight.alpha~=0)
        for _,part in ipairs(button.textures)do assert(not part.shown)end
        local count=#button.textures;local hooks=button.hooks and #(button.hooks.OnEnter or{})or 0
        for n=1,20 do addon.Theme.StyleScrollBar(scroll)end
        assert(#button.textures==count and (button.hooks and #(button.hooks.OnEnter or{})or 0)==hooks)
        nativeEvent(button,"OnClick");assert(button.clicked==1)
    end
    assert(not addon.Theme.StyleScrollBar({}))
end)

local function notoFixture(allowCJK)
    local previous={game=GetLocale,db=addon.db,chat=ChatFontNormal,creator=CreateFont}
    local family={shared=true};ChatFontNormal=family;addon.db={locale="enUS"};GetLocale=function()return"enUS"end
    local made=0
    local function font()
        return{
            SetFont=function(self,path,size,flags)
                if not allowCJK and not path:find("NotoSans-Regular.ttf",1,true) and path ~= "Fonts\\ARIALN.TTF" then return false end
                self.path,self.height,self.flags=path,size,flags;self.family=nil
            end,
            GetFont=function(self)
                if self.family and self.family.GetFont then
                    local path,height,flags=self.family:GetFont();return path,self.height or height,self.flags or flags
                end
                return self.path,self.height,self.flags
            end,
            GetFontObject=function(self)return self.family end,
            SetFontObject=function(self,value)self.family=value;self.path=nil end,
            SetFontHeight=function(self,value)self.height=value end,
            SetShadowOffset=function()end,SetTextColor=function(self,...)self.color={...}end}
    end
    CreateFont=function()made=made+1;return font()end
    local button={}
    for _,role in ipairs({"Normal","Highlight","Disabled"})do
        button[role]=font()
        button["Get"..role.."FontObject"]=function(self)return self[role]end
        button["Set"..role.."FontObject"]=function(self,value)self[role]=value end
    end
    return{font=font,button=button,family=family,made=function()return made end,finish=function()
        GetLocale,addon.db,ChatFontNormal,CreateFont=previous.game,previous.db,previous.chat,previous.creator
    end}
end
test("bundled static Noto is selected only for supported non-CJK client and UI contexts",function()
    local f=notoFixture();local r=f.font()
    for _,code in ipairs({"enUS","enGB","ruRU","deDE","frFR","esES","esMX","itIT","ptBR"})do
        GetLocale=function()return code end;addon.db.locale=code
        assert(addon.Theme.ApplyFont(r,26) and resolvedPath(r):find("NotoSans-Regular.ttf",1,true) and resolvedHeight(r)==26)
    end
    GetLocale=function()return"enUS"end
    for _,code in ipairs({"koKR","zhCN","zhTW"})do
        addon.db.locale=code;assert(addon.Theme.ApplyFont(r,14) and resolvedFamily(r,f.family) and not resolvedPath(r))
        addon.db.locale="enUS";GetLocale=function()return code end
        assert(addon.Theme.ApplyFont(r,14) and resolvedFamily(r,f.family) and not resolvedPath(r))
        GetLocale=function()return"enUS"end
    end
    addon.db.locale="unsupported";assert(addon.Theme.ApplyFont(r,14) and resolvedPath(r))
    GetLocale=function()return"unknown-client"end;assert(addon.Theme.ApplyFont(r,14) and resolvedFamily(r,f.family))
    GetLocale=function()error("unavailable")end;assert(addon.Theme.ApplyFont(r,14) and resolvedFamily(r,f.family))
    assert(f.family.shared and not f.family.height and not f.family.path);f.finish()
end)
test("failed bundled font loads fall back to the native family rather than claiming success",function()
    local f=notoFixture();CreateFont=nil
    for _,mode in ipairs({"false","nil","throw"})do
        local r=f.font();r.SetFont=function()if mode=="throw"then error("no asset")end;return mode=="false"and false or nil end
        assert(addon.Theme.ApplyFont(r,14)==f.family and r.family==f.family and r.height==14)
    end
    f.finish()
end)
test("existing FontStrings inputs and all button states switch font context without mutating shared families",function()
    local f=notoFixture();local r=f.font();local input={SetFontObject=function(self,value)self.font=value end}
    assert(addon.Theme.ApplyFont(r,16));assert(addon.Theme.ApplyInputFont(input));assert(addon.Theme.StyleButtonFonts(f.button))
    assert(resolvedPath(r) and input.font.path and f.button.Normal.path and f.button.Disabled.path)
    local original=input.font
    addon.db.locale="zhCN";addon.Theme.RefreshFonts()
    assert(not resolvedPath(r) and resolvedFamily(r,f.family) and not input.font.path and input.font.family==f.family and input.font~=original)
    assert(not f.button.Normal.path and f.button.Normal.family==f.family and f.button.Disabled.color[1]<f.button.Normal.color[1])
    addon.db.locale="ruRU";addon.Theme.RefreshFonts()
    assert(resolvedPath(r) and input.font.path and f.button.Normal.path and resolvedHeight(r)==16 and input.font.height==14)
    local made=f.made();for i=1,20 do addon.Theme.RefreshFonts()end;assert(f.made()==made)
    original=input.font;addon.db.locale="enGB";addon.Theme.RefreshFonts();assert(input.font==original and input.font.path)
    assert(f.family.shared and not f.family.height and not f.family.path);f.finish()
end)


test("input and button clones require successful asset loads and retain native fallback on failure",function()
    local f=notoFixture();local creator=CreateFont
    CreateFont=function(name)local font=creator(name);font.SetFont=function()return false end;return font end
    local input={SetFontObject=function(self,value)self.font=value end}
    assert(addon.Theme.ApplyInputFont(input) and input.font.family==f.family and not input.font.path and input.font.height==14)
    assert(addon.Theme.StyleButtonFonts(f.button))
    for _,role in ipairs({"Normal","Highlight","Disabled"})do
        assert(f.button[role].family==f.family and not f.button[role].path and f.button[role].height==14)
    end
    assert(not f.family.height and not f.family.path);f.finish()
end)


test("font asset paths retain exact runtime separators for the packaged file and native fallback",function()
    local f=notoFixture();local r=f.font()
    local expected=table.concat({"Interface","AddOns","DungeonPro","Media","Fonts","NotoSans-Regular.ttf"},string.char(92))
    assert(addon.Theme.ApplyFont(r,14) and resolvedPath(r)==expected,"packaged font runtime path must keep directory separators")
    local chat,highlight,standard=ChatFontNormal,GameFontHighlight,STANDARD_TEXT_FONT
    ChatFontNormal,GameFontHighlight,STANDARD_TEXT_FONT=nil,nil,nil;GetLocale=function()return"unknown-client"end
    expected="Fonts"..string.char(92).."ARIALN.TTF"
    assert(addon.Theme.ApplyFont(r,14) and resolvedPath(r)==expected,"native fallback path must keep its directory separator")
    ChatFontNormal,GameFontHighlight,STANDARD_TEXT_FONT=chat,highlight,standard;f.finish()
end)


test("ordinary FontStrings switch from Noto to native CJK through clean owned font objects",function()
    local f=notoFixture();local direct=0
    local fs={SetFont=function(self,path,size)direct=direct+1;self.localPath=path;return true end,
        SetFontObject=function(self,font)self.inherited=font end,
        SetFontHeight=function(self,height)self.localHeight=height end,SetShadowOffset=function()end}
    local font=addon.Theme.ApplyFont(fs,16)
    assert(direct==0 and fs.localPath==nil and fs.inherited==font and font.path:find("NotoSans-Regular.ttf",1,true))
    local same={SetFontObject=function(self,value)self.inherited=value end,SetShadowOffset=function()end}
    assert(addon.Theme.ApplyFont(same,16)==font)
    local made=f.made();for i=1,20 do addon.Theme.ApplyFont(fs,16)end;assert(f.made()==made)
    addon.db.locale="zhCN";addon.Theme.RefreshFonts()
    assert(direct==0 and not fs.localPath and fs.inherited~=font and fs.inherited.family==f.family and not fs.inherited.path)
    addon.db.locale="ruRU";addon.Theme.RefreshFonts()
    assert(direct==0 and fs.inherited.path and fs.inherited.height==16)
    assert(not f.family.path and not f.family.height);f.finish()
end)
test("void SimpleFont setters are verified by current clean font path and height for every owned role",function()
    local f=notoFixture();local creator=CreateFont
    for _,mode in ipairs({"valid","wrong-path","wrong-height","throw"})do
        CreateFont=function(name)
            local font=creator(name)
            font.GetFont=function(self)
                if mode=="throw"then error("unavailable")end
                return mode=="wrong-path"and"Fonts/Other.ttf"or self.path,mode=="wrong-height"and 99 or self.height,self.flags
            end
            return font
        end
        local r=f.font();local applied=addon.Theme.ApplyFont(r,14)
        local input={SetFontObject=function(self,font)self.font=font end}
        assert(applied and addon.Theme.ApplyInputFont(input) and addon.Theme.StyleButtonFonts(f.button))
        local selected=mode=="valid"
        assert((resolvedPath(r)~=nil)==selected and (input.font.path~=nil)==selected and(f.button.Normal.path~=nil)==selected,mode..":"..tostring(resolvedPath(r))..":"..tostring(input.font.path)..":"..tostring(f.button.Normal.path))
        assert((f.button.Disabled.path~=nil)==selected)
    end
    f.finish()
end)


test("repeated locale selections keep bounded per-script source caches while preserving family and creator identity",function()
    local f=notoFixture();local r=f.font();local input={SetFontObject=function(self,font)self.font=font end}
    local function paint()
        addon.Theme.ApplyFont(r,14);addon.Theme.ApplyInputFont(input);addon.Theme.StyleButtonFonts(f.button)
    end
    paint();local noto=input.font;local original=f.made()
    addon.db.locale="zhCN";paint();local native=input.font
    assert(native~=noto)
    local sources={zhCN=native}
    for _,locale in ipairs({"zhTW","koKR"})do addon.db.locale=locale;paint();sources[locale]=input.font end
    local warmed=f.made()
    for i=1,20 do
        for _,locale in ipairs({"ruRU","enGB","zhTW","koKR","zhCN","enUS"})do
            addon.db.locale=locale;paint()
            assert(input.font==((locale=="ruRU"or locale=="enGB"or locale=="enUS")and noto or sources[locale]))
        end
    end
    assert(f.made()==warmed and warmed==original*4)
    ChatFontNormal={newFamily=true};paint();assert(input.font~=noto and f.made()>warmed)
    local last=input.font;local maker=CreateFont;CreateFont=function(name)return maker(name)end
    paint();assert(input.font~=last)
    f.finish()
end)

local function closeFixture()
    local b=region();b.normal,b.pushed,b.disabled,b.highlight=region(),region(),region(),region()
    for _,r in ipairs({b.normal,b.pushed,b.disabled,b.highlight})do r.alpha=1 end
    b.enabled=true;b.fontStrings={};b.hooks={}
    b.IsEnabled=function(self)return self.enabled end
    b.HookScript=function(self,event,fn)self.hooks[event]=self.hooks[event]or{};table.insert(self.hooks[event],fn);return true end
    b.CreateFontString=function(self)local r=region();self.fontStrings[#self.fontStrings+1]=r;return r end
    b.fire=function(self,event,...)
        if self.scripts[event]then self.scripts[event](self,...)end
        for _,fn in ipairs(self.hooks[event]or{})do fn(self,...)end
    end
    return b
end
methods.GetAlpha=function(self)return self.alpha or 1 end
methods.SetText=function(self,v)self.text=v end
methods.SetJustifyH=function(self,v)self.halign=v end
methods.SetJustifyV=function(self,v)self.valign=v end
methods.SetFontObject=function(self,f)self.family=f end
methods.SetFontHeight=function(self,n)self.fontHeight=n end
ChatFontNormal={}
test("Close glyph preserves native handlers with distinct hover press and disabled states",function()
    local b=closeFixture();local click,tooltip=0,0
    b.scripts.OnClick=function()click=click+1 end;b.scripts.OnEnter=function()tooltip=tooltip+1 end
    local beforeClick,beforeEnter=b.scripts.OnClick,b.scripts.OnEnter
    assert(addon.Theme.StyleCloseButton(b))
    local bg,g=b.textures[1],b.fontStrings[1]
    assert(g.text=="×"and g.fontHeight==20 and g.halign=="CENTER"and g.valign=="MIDDLE"and bg.shown and g.shown)
    assert(b.normal.alpha==0 and b.pushed.alpha==0 and b.disabled.alpha==0 and b.highlight.alpha==0)
    local neutral=bg.color[1];b:fire("OnEnter");assert(tooltip==1 and bg.color[1]>neutral)
    local hover=bg.color[1];b:fire("OnMouseDown");assert(bg.color[1]>hover)
    b:fire("OnMouseUp");assert(bg.color[1]==hover)
    b:fire("OnClick");assert(click==1 and b.scripts.OnClick==beforeClick and b.scripts.OnEnter==beforeEnter)
    b.enabled=false;b:fire("OnDisable");assert(g.alpha<1)
    b.enabled=true;b:fire("OnEnable");assert(g.alpha==1)
    b:fire("OnLeave");assert(bg.color[1]==neutral)
    local count=#b.textures
    for _=1,100 do assert(addon.Theme.StyleCloseButton(b));addon.Theme.RefreshFonts()end
    assert(#b.textures==count and #b.fontStrings==1)
    local hooks=0;for _,list in pairs(b.hooks)do hooks=hooks+#list end;assert(hooks==7)
end)
test("Close optional capability and partial setup failures retain native close",function()
    for _,kind in ipairs({"hook","partialhook","texture","font","alpha","badalpha","creation","show"})do
        local b=closeFixture();local clicks=0;b.scripts.OnClick=function()clicks=clicks+1 end
        if kind=="hook"then b.HookScript=false
        elseif kind=="partialhook"then local previous=b.HookScript;b.HookScript=function(self,event,fn)if event=="OnMouseUp"then return false end;return previous(self,event,fn)end
        elseif kind=="badalpha"then b.normal.GetAlpha=function()return -1 end
        elseif kind=="texture"then b.GetHighlightTexture=false
        elseif kind=="font"then b.CreateFontString=function(self)local r=region();r.SetFontObject=false;r.SetFontHeight=false;self.fontStrings[#self.fontStrings+1]=r;return r end
        elseif kind=="alpha"then b.pushed.SetAlpha=function()error("alpha fail")end
        elseif kind=="creation"then b.CreateFontString=function()error("no font")end
        else b.CreateFontString=function(self)local r=region();r.Show=function()error("show failed")end;self.fontStrings[#self.fontStrings+1]=r;return r end end
        assert(not addon.Theme.StyleCloseButton(b),kind)
        assert(b.normal.alpha==1 and b.pushed.alpha==1 and b.disabled.alpha==1 and b.highlight.alpha==1,kind.." native alpha")
        local n=#b.textures+#b.fontStrings
        for _=1,50 do assert(not addon.Theme.StyleCloseButton(b))end
        assert(#b.textures+#b.fontStrings==n,kind.." allocation")
        b:fire("OnClick");assert(clicks==1)
    end
end)
test("Close font refresh repaints glyph after native context changes",function()
    local b=closeFixture();assert(addon.Theme.StyleCloseButton(b));local g=b.fontStrings[1]
    local previous=g.SetFontObject
    g.SetFontObject=function(self,f)self.text="";previous(self,f)end
    ChatFontNormal={};addon.Theme.RefreshFonts();assert(g.text=="×")
end)

test("Close setup cannot paint visible optional regions when their initial Hide fails",function()
 for _,kind in ipairs({"glyph","background"})do
  local b=closeFixture();local created
  b.CreateFontString=function(self)
   local r=region();r.shown=true;r.text=""
   if kind=="glyph"then r.Hide=function()error("initial hide unavailable")end end
   self.fontStrings[#self.fontStrings+1]=r;created=r;return r
  end
  if kind=="background"then b.CreateTexture=function(self)
   local r=region();r.shown=true;r.Hide=function()error("initial hide unavailable")end
   self.textures[#self.textures+1]=r;return r
  end end
  b.HookScript=function()return false end
  assert(not addon.Theme.StyleCloseButton(b))
  for _,r in ipairs({b.normal,b.pushed,b.disabled,b.highlight})do assert(r.alpha==1)end
  assert(not created.shown or created.text=="","failed initial Hide must not leave a painted glyph")
  assert(not b.textures[1].shown or b.textures[1].color==nil,"failed initial Hide must not leave a painted panel")
 end
end)

test("transient language preview switches existing font roles without changing the committed locale", function()
    local f = notoFixture(); local previous = addon.Language; local selection
    addon.Language = { GetSelection = function() return selection end }
    local text, input = f.font(), { SetFontObject = function(self, value) self.font = value end }
    assert(addon.Theme.ApplyFont(text, 16) and addon.Theme.ApplyInputFont(input) and addon.Theme.StyleButtonFonts(f.button))
    assert(resolvedPath(text) and input.font.path and f.button.Normal.path)
    selection = "zhCN"; addon.Theme.RefreshFonts()
    assert(resolvedFamily(text, f.family) and resolvedFamily(input.font, f.family) and resolvedFamily(f.button.Normal, f.family))
    assert(addon.db.locale == "enUS" and not f.family.path and not f.family.height)
    selection = "ruRU"; addon.Theme.RefreshFonts()
    assert(resolvedPath(text) and input.font.path and f.button.Normal.path and addon.db.locale == "enUS")
    selection = nil; addon.Theme.RefreshFonts()
    assert(resolvedPath(text) and addon.db.locale == "enUS")
    selection = secret; addon.Theme.RefreshFonts()
    assert(resolvedPath(text) and addon.db.locale == "enUS")
    addon.Language = previous; f.finish()
end)

test("cross-client CJK UI text inputs and controls keep distinct compatible scripts then restore Noto", function()
    local f = notoFixture(true)
    local text, input = f.font(), { SetFontObject = function(self, value) self.font = value end }
    local paths = { zhCN = "Fonts\\ARKai_T.ttf", zhTW = "Fonts\\bHEI00M.ttf", koKR = "Fonts\\2002.ttf" }
    local sources = {}
    for _, locale in ipairs({ "ruRU", "zhCN", "koKR", "zhTW", "enUS" }) do
        addon.db.locale = locale
        assert(addon.Theme.ApplyFont(text, 16) and addon.Theme.ApplyInputFont(input) and addon.Theme.StyleButtonFonts(f.button))
        local expected = paths[locale] or "Interface\\AddOns\\DungeonPro\\Media\\Fonts\\NotoSans-Regular.ttf"
        assert(resolvedPath(text) == expected and input.font.path == expected and f.button.Highlight.path == expected)
        sources[locale] = input.font
    end
    assert(sources.zhCN ~= sources.zhTW and sources.zhCN ~= sources.koKR and sources.ruRU == sources.enUS)
    local made = f.made()
    for _ = 1, 20 do
        for locale in pairs(paths) do addon.db.locale = locale; addon.Theme.RefreshFonts(); assert(input.font == sources[locale]) end
    end
    assert(f.made() == made and not f.family.path and not f.family.height)
    f.finish()
end)

test("language row labels and all button states retain their own script during another language preview", function()
    local f = notoFixture(true)
    local text = f.font()
    assert(addon.Theme.ApplyLanguageFont(text, "zhCN", 14) and addon.Theme.StyleLanguageRow(f.button, "koKR"))
    local rowFont, labelFont = f.button.Normal, text.family
    addon.db.locale = "zhTW"; addon.Theme.RefreshFonts()
    assert(text.family == labelFont and resolvedPath(text) == "Fonts\\ARKai_T.ttf")
    for _, role in ipairs({ "Normal", "Highlight", "Disabled" }) do assert(f.button[role].path == "Fonts\\2002.ttf") end
    assert(f.button.Normal == rowFont)
    assert(addon.Theme.ApplyLanguageFont(text, "ruRU", 14) and resolvedPath(text):find("NotoSans-Regular.ttf", 1, true))
    assert(not addon.Theme.ApplyLanguageFont(text, secret, 14) and not addon.Theme.StyleLanguageRow(f.button, secret))
    f.finish()
end)

test("CJK probing skips failed candidates and reports unavailable scripts without losing native fallback", function()
    for _, mode in ipairs({ "false", "throw", "second" }) do
        local f = notoFixture(true); local creator = CreateFont
        CreateFont = function(name)
            local font = creator(name); local setter = font.SetFont
            font.SetFont = function(self, path, size, flags)
                if mode == "second" and path == "Fonts\\ARHei.TTF" then return setter(self, path, size, flags) end
                if mode == "throw" then error("unavailable font") end
                return false
            end
            return font
        end
        local text = f.font()
        local result = addon.Theme.ApplyLanguageFont(text, "zhCN", 14)
        local rowResult = addon.Theme.StyleLanguageRow(f.button, "zhCN")
        if mode == "second" then
            assert(result and rowResult and resolvedPath(text) == "Fonts\\ARHei.TTF" and f.button.Disabled.path == "Fonts\\ARHei.TTF")
        else
            assert(not result and not rowResult and resolvedFamily(text, f.family) and resolvedFamily(f.button.Normal, f.family))
        end
        assert(not f.family.path and not f.family.height)
        f.finish()
    end
end)

test("Window base is opaque so lower windows cannot read through the planner",function()
    local window=region();assert(addon.Theme.Apply({frame=window}))
    local found=false
    for _,texture in ipairs(window.textures)do
        if texture.allPoints==window and texture.color and texture.color[1]==0.027 then
            assert(texture.color[4]==1);found=true
        end
    end
    assert(found)
end)
test("warm CJK refresh followed by row repaint writes each changed text font only once", function()
    local f = notoFixture(true)
    local text, input = f.font(), f.font()
    local textSet, inputSet = text.SetFontObject, input.SetFontObject
    local textWrites, inputWrites = 0, 0
    text.SetFontObject = function(self, value) textWrites = textWrites + 1; return textSet(self, value) end
    input.SetFontObject = function(self, value) inputWrites = inputWrites + 1; return inputSet(self, value) end
    assert(addon.Theme.ApplyFont(text, 16) and addon.Theme.ApplyInputFont(input))
    for _, locale in ipairs({ "zhCN", "zhTW", "koKR", "ruRU", "enUS" }) do
        local beforeText, beforeInput = textWrites, inputWrites
        addon.db.locale = locale
        addon.Theme.RefreshFonts()
        local refreshedText, refreshedInput = textWrites, inputWrites
        for _ = 1, 20 do
            assert(addon.Theme.ApplyFont(text, 16) and addon.Theme.ApplyInputFont(input))
        end
        assert(textWrites == refreshedText and inputWrites == refreshedInput, locale .. ": repaint does not bind the font again")
        local changed = locale ~= "enUS"
        assert(textWrites - beforeText == (changed and 1 or 0) and inputWrites - beforeInput == (changed and 1 or 0))
    end
    assert(not f.family.path and not f.family.height)
    f.finish()
end)

test("warm font dedup requires clean effective readback and repairs detached overrides", function()
    for _, mode in ipairs({ "path", "height", "flags", "secret-path", "secret-height", "secret-flags", "throw", "missing" }) do
        local f = notoFixture(true); addon.db.locale = "zhCN"
        local text = f.font(); local originalSet = text.SetFontObject; local writes = 0
        text.SetFontObject = function(self, value) writes = writes + 1; return originalSet(self, value) end
        assert(addon.Theme.ApplyFont(text, 16)); local before = writes
        local read = text.GetFont
        text.GetFont = function(self)
            if mode == "throw" then error("font unavailable") end
            local path, size, flags = read(self)
            if mode == "path" then path = "Fonts\\Other.ttf" end
            if mode == "height" then size = 99 end
            if mode == "flags" then flags = "OUTLINE" end
            if mode == "secret-path" then path = secret end
            if mode == "secret-height" then size = secret end
            if mode == "secret-flags" then flags = secret end
            return path, size, flags
        end
        if mode == "missing" then text.GetFont = false end
        assert(addon.Theme.ApplyFont(text, 16) and writes == before + 1, mode .. ": uncertain readback retries application")
        text.GetFont = read
        assert(addon.Theme.ApplyFont(text, 16) and writes == before + 1)
        f.finish()
    end
end)

test("shared font sources retain independent main-window and fixed-language button contexts", function()
    local f = notoFixture(true)
    local uiButton, languageButton = f.button, {}
    for _, role in ipairs({ "Normal", "Highlight", "Disabled" }) do
        languageButton[role] = f.font()
        languageButton["Get" .. role .. "FontObject"] = uiButton["Get" .. role .. "FontObject"]
        languageButton["Set" .. role .. "FontObject"] = uiButton["Set" .. role .. "FontObject"]
    end
    assert(addon.Theme.StyleButtonFonts(uiButton) and addon.Theme.StyleLanguageRow(languageButton, "ruRU"))
    assert(uiButton.Normal == languageButton.Normal, "identical Noto roles share a cache")
    local fixed = languageButton.Normal
    for _, locale in ipairs({ "zhCN", "zhTW", "koKR", "enUS", "zhCN" }) do
        addon.db.locale = locale; addon.Theme.RefreshFonts()
        assert(languageButton.Normal == fixed and resolvedPath(languageButton.Normal):find("NotoSans-Regular.ttf", 1, true))
        local expected = ({ zhCN = "Fonts\\ARKai_T.ttf", zhTW = "Fonts\\bHEI00M.ttf", koKR = "Fonts\\2002.ttf" })[locale]
            or "Interface\\AddOns\\DungeonPro\\Media\\Fonts\\NotoSans-Regular.ttf"
        for _, role in ipairs({ "Normal", "Highlight", "Disabled" }) do assert(resolvedPath(uiButton[role]) == expected) end
    end
    local original = uiButton.Normal
    uiButton.Normal = f.font()
    assert(addon.Theme.StyleButtonFonts(uiButton) and uiButton.Normal == original, "detached native role is rebound")
    f.finish()
end)

test("warm readback cannot commit an expired locale or native creator context", function()
    for _, mode in ipairs({ "locale", "family", "creator" }) do
        local f = notoFixture(true); local text = f.font()
        assert(addon.Theme.ApplyFont(text, 16))
        local read = text.GetFont; local armed = true; local oldCreator = CreateFont
        text.GetFont = function(self)
            local path, height, flags = read(self)
            if armed then
                armed = false
                if mode == "locale" then addon.db.locale = "zhCN"
                elseif mode == "family" then ChatFontNormal = {}
                else CreateFont = function(...) return oldCreator(...) end end
            end
            return path, height, flags
        end
        assert(not addon.Theme.ApplyFont(text, 16), mode .. ": readback loses its old context")
        text.GetFont = read
        assert(addon.Theme.ApplyFont(text, 16), mode .. ": fresh context can retry")
        f.finish()
    end
end)

function methods:SetAtlas(value)self.atlas=value end
function methods:GetAtlas()return self.atlas end
function methods:SetTexture(value)self.texture=value;return true end
function methods:SetTexCoord(...)self.texCoords={...}end
function methods:SetVertexColor(...)self.vertex={...}end
function methods:HasFocus()return self.focused==true end
test("search skin keeps real input state and handlers with a bounded native magnifier",function()
    local input,clear=region(),region();input.Left,input.Middle,input.Right=region(),region(),region()
    input.font={original=true};input.insets={28,30,0,0};input.text="A long real search query";input.cursor=18
    local changed=function()end;local enter=function()end;input.scripts.OnTextChanged=changed;input.scripts.OnEnterPressed=enter
    local click=function()end;clear.scripts.OnClick=click
    assert(addon.Theme.StyleSearch(input,clear))
    assert(input.text=="A long real search query"and input.cursor==18 and input.insets[1]==28 and input.font.original)
    assert(input.scripts.OnTextChanged==changed and input.scripts.OnEnterPressed==enter and clear.scripts.OnClick==click)
    assert(input.Left.alpha==0 and input.Middle.alpha==0 and input.Right.alpha==0)
    local icon=input.textures[7];assert(icon.atlas=="common-search-magnifyingglass"and icon.width==12 and icon.height==12 and icon.shown)
    local count=#input.textures;for i=1,100 do addon.Theme.StyleSearch(input,clear)end
    assert(#input.textures==count and #input.hooks.OnEditFocusGained==1 and #input.hooks.OnEditFocusLost==1)
    assert(clear.textures[1].color[4]==0 and clear.textures[2].color[4]==0)
end)
test("search focus and hover change only owned decoration then reset on blur and hide",function()
    local input=region();assert(addon.Theme.StyleSearch(input));local edge=input.textures[2]
    local idle=edge.color[2];nativeEvent(input,"OnEnter");assert(edge.color[2]~=idle)
    nativeEvent(input,"OnEditFocusGained");assert(edge.color[2]>edge.color[1])
    nativeEvent(input,"OnLeave");assert(edge.color[2]>edge.color[1])
    nativeEvent(input,"OnEditFocusLost");assert(edge.color[2]==idle)
    nativeEvent(input,"OnEditFocusGained");nativeEvent(input,"OnHide");assert(edge.color[2]==idle and input.text=="kept")
end)
test("unavailable search atlas uses the verified native art crop without adding polling or frames",function()
    local input=region();input.CreateTexture=function(self,...)
        local t=methods.CreateTexture(self,...);t.SetAtlas=function()return false end;return t
    end
    assert(addon.Theme.StyleSearch(input));local icon=input.textures[7]
    assert(icon.texture=="Interface\\EncounterJournal\\UI-EncounterJournalTextures"and icon.texCoords[1]==.8984375 and icon.shown)
    assert(not input.scripts.OnUpdate and not input.hooks.OnUpdate)
end)
test("icon filters distinguish active state without touching glyph text tooltips clicks or native geometry",function()
    local button=region();button.filterIcon=region();button.text="";button.width,button.height=26,26
    local enter=function()end;local click=function()end;button.scripts.OnEnter=enter;button.scripts.OnClick=click
    assert(addon.Theme.StyleFilter(button,false));local idle=button.filterIcon.vertex[1]
    assert(addon.Theme.StyleFilter(button,true));assert(button.filterIcon.vertex[1]>idle and button.filterIcon.vertex[1]>button.filterIcon.vertex[2])
    assert(button.width==26 and button.height==26 and button.text=="" and not button.points)
    assert(button.scripts.OnClick==click and button.scripts.OnEnter==enter)
    assert(addon.Theme.StyleFilter(button,false));assert(button.filterIcon.vertex[1]==idle)
    for i=1,100 do addon.Theme.StyleFilter(button,false)end
    assert(#button.textures==6 and #button.hooks.OnEnter==1 and #button.hooks.OnLeave==1)
    button.enabled=false;nativeEvent(button,"OnDisable");assert(button.filterIcon.alpha==.4)
    button.enabled=true;nativeEvent(button,"OnEnable");assert(button.filterIcon.alpha==1)
end)
test("theme application respects current icon-only filter selections rather than overriding them",function()
    local ui={frame=region(),searchBox=region(),clearSearch=region(),rangeButton=region(),characterButton=region()}
    ui.rangeButton.filterIcon,ui.characterButton.filterIcon=region(),region()
    ui.rangeButton.filterSelected,ui.characterButton.filterSelected=false,true
    assert(addon.Theme.Apply(ui))
    assert(ui.characterButton.filterIcon.vertex[1]>ui.rangeButton.filterIcon.vertex[1])
    ui.rangeButton.filterSelected,ui.characterButton.filterSelected=true,false;addon.Theme.Apply(ui)
    assert(ui.rangeButton.filterIcon.vertex[1]>ui.characterButton.filterIcon.vertex[1])
end)
test("late native color setters preserve the newer focus and filter state",function()
    local input=region();addon.Theme.StyleSearch(input);local edge=input.textures[2];local original,armed=edge.SetColorTexture,true
    local idle=edge.color[2]
    edge.SetColorTexture=function(self,...)
        if armed then armed=false;nativeEvent(input,"OnEditFocusLost")end
        original(self,...)
    end
    nativeEvent(input,"OnEditFocusGained");assert(edge.color[2]==idle)
    local control=region();control.filterIcon=region();addon.Theme.StyleFilter(control,false)
    local icon=control.filterIcon;local paint=icon.SetVertexColor;local once=true;local quiet=icon.vertex[1]
    icon.SetVertexColor=function(self,...)
        if once then once=false;addon.Theme.StyleFilter(control,false)end
        paint(self,...)
    end
    addon.Theme.StyleFilter(control,true);assert(icon.vertex[1]==quiet)
end)
print("theme: " .. total .. " scenarios passed")
