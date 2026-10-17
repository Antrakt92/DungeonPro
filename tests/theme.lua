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
test("recycled selected dungeon clears accent and restores border", function()
    local r = row()
    assert(addon.Theme.StyleRow(r, {kind="dungeon",selected=true}))
    local edge, accent = r.textures[1], r.textures[5]
    assert(accent.shown and edge.color[1] > edge.color[2])
    local selected = r.bg.color[1]
    assert(addon.Theme.StyleRow(r, {kind="dungeon",selected=false}))
    assert(not accent.shown and r.bg.color[1] < selected and edge.color[1] < .2)
    assert(#r.textures == 5)
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
    scroll.scripts.OnMouseWheel=function(self,n)self.wheel=n end
    return scroll,bar
end
test("all three native scrollbars receive bounded quiet cosmetics while native geometry and handlers stay intact",function()
    local ui={frame=region()}
    ui.catalogScroll=scrollFixture();ui.questScroll=scrollFixture();ui.detailScroll=scrollFixture()
    local totalTextures=0
    for _,scroll in ipairs({ui.catalogScroll,ui.questScroll,ui.detailScroll})do
        local bar=scroll.ScrollBar;bar.shown=false;bar.ThumbTexture.shown=false
        local click=bar.ScrollUpButton.scripts.OnClick;local value=bar.scripts.OnValueChanged
        assert(addon.Theme.Apply(ui))
        assert(not bar.shown and not bar.ThumbTexture.shown and not bar.points)
        assert(bar.ThumbTexture.width==18 and bar.ThumbTexture.height==24 and not bar.ThumbTexture.points)
        assert(bar.ThumbTexture.color[2]>bar.ThumbTexture.color[1])
        assert(#bar.textures==1 and bar.textures[1].width==3)
        assert(bar.ScrollUpButton.width==18 and bar.ScrollUpButton.height==16 and not bar.ScrollUpButton.points)
        assert(bar.ScrollUpButton.scripts.OnClick==click and bar.scripts.OnValueChanged==value)
        assert(not bar.scripts.OnUpdate and not scroll.scripts.OnUpdate)
        nativeEvent(bar.ScrollUpButton,"OnClick");nativeEvent(bar,"OnValueChanged",30);nativeEvent(scroll,"OnMouseWheel",1)
        assert(bar.ScrollUpButton.clicked==1 and bar.value==30 and scroll.wheel==1)
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
            for _,list in pairs(button.hooks)do assert(#list==1)end
        end
    end
    assert(totalTextures==15 and after==totalTextures)
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

local function notoFixture()
    local previous={game=GetLocale,db=addon.db,chat=ChatFontNormal,creator=CreateFont}
    local family={shared=true};ChatFontNormal=family;addon.db={locale="enUS"};GetLocale=function()return"enUS"end
    local made=0
    local function font()
        return{
            SetFont=function(self,path,size,flags)self.path,self.height,self.flags=path,size,flags;self.family=nil end,
            GetFont=function(self)return self.path,self.height,self.flags end,
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


test("repeated locale selections allocate only two actual source caches while preserving family and creator identity",function()
    local f=notoFixture();local r=f.font();local input={SetFontObject=function(self,font)self.font=font end}
    local function paint()
        addon.Theme.ApplyFont(r,14);addon.Theme.ApplyInputFont(input);addon.Theme.StyleButtonFonts(f.button)
    end
    paint();local noto=input.font;local original=f.made()
    addon.db.locale="zhCN";paint();local native=input.font
    assert(native~=noto)
    local warmed=f.made()
    for i=1,20 do
        for _,locale in ipairs({"ruRU","enGB","zhTW","koKR","zhCN","enUS"})do
            addon.db.locale=locale;paint()
            assert(input.font==((locale=="ruRU"or locale=="enGB"or locale=="enUS")and noto or native))
        end
    end
    assert(f.made()==warmed and warmed==original*2)
    ChatFontNormal={newFamily=true};paint();assert(input.font~=noto and f.made()>warmed)
    local last=input.font;local maker=CreateFont;CreateFont=function(name)return maker(name)end
    paint();assert(input.font~=last)
    f.finish()
end)

print("theme: " .. total .. " scenarios passed")
