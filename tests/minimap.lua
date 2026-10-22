local addon, total, secret = {}, 0, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
local created, clicks, cursorX, cursorY, scale, cx, cy, width, textureResult
local methods = {}
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:EnableMouse() end
function methods:RegisterForClicks(...) self.clicks={...} end
function methods:RegisterForDrag(...) self.drags={...} end
function methods:SetScript(name,fn) self.scripts[name]=fn end
function methods:SetParent(parent) self.parent=parent end
function methods:ClearAllPoints() self.order="clear" end
function methods:SetPoint(...) assert(self.order=="clear"); self.point={...}; self.order="point" end
function methods:SetUserPlaced(value) assert(self.order=="point"); self.userPlaced=value end
function methods:SetFrameStrata(value) self.strata=value end
function methods:SetFrameLevel(value) self.level=value end
function methods:GetFrameLevel() return self.level or 2 end
function methods:SetClampedToScreen(value) self.clamped=value end
function methods:SetHighlightTexture(value,mode) self.highlight,self.highlightMode=value,mode end
function methods:AddMaskTexture(mask) self.mask=mask end
function methods:SetAllPoints() end
function methods:SetTexture(value) self.texture=value; return textureResult end
function methods:SetText(value) self.text=value end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
local function frame(parent) return setmetatable({parent=parent,scripts={}}, {__index=methods}) end
function methods:CreateTexture() local texture=frame(self);if not self.icon then self.icon=texture end;return texture end
function methods:CreateMaskTexture() return frame(self) end
function methods:CreateFontString() self.label=frame(self); return self.label end
local function reset(config, legacy)
    created, clicks, cursorX, cursorY, scale, cx, cy, width, textureResult=0,0,400,200,2,100,100,200,true
    issecretvalue=function(value) return value==secret end
    GetCursorPosition=function(...) assert(select("#",...)==0); return cursorX,cursorY end
    Minimap=frame(); Minimap.GetWidth=function() return width end
    Minimap.GetEffectiveScale=function() return scale end
    Minimap.GetCenter=function() return cx,cy end
    addon.db={ minimap=config }; addon.UI={Toggle=function() clicks=clicks+1 end}
    if type(config)=="table" and config~=secret and not legacy then config.launcherVersion=1 end
    C_Timer=nil
    addon.L=function(key) return key end
    CreateFrame=function(kind,name,parent)
        assert(kind=="Button" and name=="DungeonProMinimapButton" and parent==Minimap)
        created=created+1; return frame(parent)
    end
    GameTooltip={hides=0,lines={}}
    function GameTooltip:SetOwner(owner,anchor) assert(anchor=="ANCHOR_LEFT"); self.owner=owner end
    function GameTooltip:IsOwned(owner) return self.owner==owner end
    function GameTooltip:SetText(value) self.text=value end
    function GameTooltip:AddLine(value) self.lines[#self.lines+1]=value end
    function GameTooltip:Show() self.shown=true end
    function GameTooltip:Hide() self.hides=self.hides+1; self.shown=false end
    assert(loadfile("UI/TooltipLease.lua"))("DungeonPro",addon)
    assert(loadfile("UI/Minimap.lua"))("DungeonPro",addon)
    return addon.Minimap
end
local function check(name,fn)
    local ok,err=pcall(fn); assert(ok,name..": "..tostring(err)); total=total+1; print("PASS "..name)
end
local function near(a,b) assert(math.abs(a-b)<0.00001,tostring(a).." differs from "..tostring(b)) end
check("Missing native minimap omits launcher then idempotent initialization uses actual parent",function()
    local m=reset(); local native=Minimap; Minimap=nil
    assert(m:Initialize()==false and created==0)
    Minimap=native; assert(m:Initialize() and m:Initialize() and created==1)
    assert(m.button.parent==native and m.button.shown and m.button.scripts.OnUpdate==nil)
    assert(m.button.icon.texture=="Interface\\Icons\\INV_Misc_Map_01")
    assert(addon.db.minimap.angle==nil)
    near(m.angle,225)
end)
check("Left click opens existing UI and drag suppresses its release click",function()
    local m=reset(); assert(m:Initialize()); local b=m.button
    b.scripts.OnClick(b,"RightButton"); assert(clicks==0)
    b.scripts.OnClick(b,"LeftButton"); assert(clicks==1)
    b.scripts.OnDragStart(b,"LeftButton"); assert(b.scripts.OnUpdate)
    b.scripts.OnUpdate(b); near(m.angle,0); near(b.point[4],108); near(b.point[5],0)
    b.scripts.OnDragStop(b); assert(not b.scripts.OnUpdate and addon.db.minimap.angle==0)
    b.scripts.OnClick(b,"LeftButton"); assert(clicks==1)
    b.scripts.OnClick(b,"LeftButton"); assert(clicks==2)
end)
check("Scaled cursor geometry preserves all quadrants and exact saved angle",function()
    local m=reset({angle=90}); assert(m:Initialize()); near(m.button.point[4],0); near(m.button.point[5],108)
    for _,entry in ipairs({{200,400,90},{0,200,180},{200,0,270}}) do
        cursorX,cursorY=entry[1],entry[2]
        m:StartDrag("LeftButton"); m.button.scripts.OnUpdate(); m:StopDrag(true)
        near(addon.db.minimap.angle,entry[3])
    end
    m:Initialize(); near(m.angle,270)
end)
check("Hide reset and reopen are recoverable without a permanent ticker",function()
    local m=reset({angle=17,hide=true}); assert(m:Initialize() and not m.button.shown)
    assert(m:ToggleVisibility() and m.button.shown and not addon.db.minimap.hide)
    m:StartDrag("LeftButton"); assert(m.button.scripts.OnUpdate)
    assert(m:ToggleVisibility() and not m.button.shown and not m.drag and not m.button.scripts.OnUpdate)
    assert(m:Reset() and m.button.shown and addon.db.minimap.angle==225 and addon.db.minimap.hide==false)
end)
check("Malformed existing config is preserved with ephemeral user controls",function()
    for _,value in ipairs({false,7,"legacy",secret}) do
        local m=reset(value); assert(m:Initialize()); assert(addon.db.minimap==value)
        m:ToggleVisibility(); m:Reset(); assert(addon.db.minimap==value and m.button.shown)
    end
    local config={angle=secret,hide="legacy",other="keep"}; local m=reset(config)
    assert(m:Initialize() and config.angle==secret and config.hide=="legacy" and config.other=="keep")
    near(m.angle,225)
end)
check("Unknown restricted nonfinite and throwing geometry stops drag without overwriting saved angle",function()
    for mode=1,9 do
        local m=reset({angle=45}); assert(m:Initialize()); m:StartDrag("LeftButton")
        if mode==1 then cursorX=secret elseif mode==2 then cursorY=nil elseif mode==3 then scale=0
        elseif mode==4 then scale=secret elseif mode==5 then cx=math.huge elseif mode==6 then cy=secret
        elseif mode==7 then GetCursorPosition=function() error("missing") end
        elseif mode==8 then width=secret else Minimap.GetCenter=function() error("unavailable") end end
        m.button.scripts.OnUpdate(); assert(not m.drag and not m.button.scripts.OnUpdate and addon.db.minimap.angle==45)
    end
end)
check("Stale drag and click callbacks cannot write changed native parent or DB",function()
    local m=reset({angle=45}); assert(m:Initialize()); local oldClick=m.button.scripts.OnClick
    m:StartDrag("LeftButton"); local update=m.button.scripts.OnUpdate; local stop=m.button.scripts.OnDragStop
    local old=addon.db; addon.db={minimap={angle=80}}
    update(); stop(); oldClick(m.button,"LeftButton"); assert(old.minimap.angle==45 and clicks==0)
    local native=frame(); native.GetWidth=function() return 180 end; Minimap=native
    assert(m:Initialize() and created==1 and m.button.parent==native)
    oldClick(m.button,"LeftButton"); assert(clicks==0)
end)
check("Old stop callbacks preserve a new drag and hide cleans even invalidated context",function()
    local m=reset({angle=45}); assert(m:Initialize()); m:StartDrag("LeftButton")
    local stop=m.button.scripts.OnDragStop; local update=m.button.scripts.OnUpdate
    m:StopDrag(false); m:StartDrag("LeftButton"); local current=m.drag
    stop(); update(); assert(m.drag==current and m.button.scripts.OnUpdate)
    addon.db={}; m.button:Hide(); assert(not m.drag and not m.button.scripts.OnUpdate)
end)
check("Tooltip is ordinary localized text and cleanup preserves foreign or newer owners",function()
    local m=reset(); assert(m:Initialize()); local b=m.button
    b.scripts.OnEnter(); assert(GameTooltip.shown and GameTooltip.owner==b and GameTooltip.text=="TITLE")
    assert(GameTooltip.lines[1]=="MINIMAP_OPEN" and GameTooltip.lines[2]=="MINIMAP_DRAG")
    local oldLeave=b.scripts.OnLeave
    b.scripts.OnEnter(); local hides=GameTooltip.hides
    oldLeave(); assert(GameTooltip.hides==hides and GameTooltip.shown)
    GameTooltip.owner={}; b.scripts.OnLeave(); assert(GameTooltip.hides==hides)
    b.scripts.OnEnter(); b:Hide(); assert(not GameTooltip.shown and GameTooltip.hides==hides+1)
end)
check("Tooltip reentry and missing capabilities fail quietly",function()
    local m=reset(); assert(m:Initialize()); local b=m.button
    GameTooltip.SetOwner=function(self,owner) self.owner={}; b:Hide() end
    b.scripts.OnEnter(); assert(not m.tooltip and not GameTooltip.shown)
    b:Show(); GameTooltip=nil; b.scripts.OnEnter(); assert(not m.tooltip)
end)
check("Optional native texture failure retains a visible text launcher",function()
    local m=reset(); textureResult=false; assert(m:Initialize())
    assert(not m.button.icon.shown and m.button.label.text=="DP" and m.button.label.shown and m.button.shown)
end)
check("Fresh left press opens after drag when the client emits no release click",function()
    local m=reset(); assert(m:Initialize()); local b=m.button
    b.scripts.OnDragStart(b,"LeftButton"); b.scripts.OnUpdate(); b.scripts.OnDragStop(b)
    assert(clicks==0)
    if b.scripts.OnMouseDown then b.scripts.OnMouseDown(b,"LeftButton") end
    b.scripts.OnClick(b,"LeftButton"); assert(clicks==1,"fresh click was swallowed")
end)
check("Failed placement never shows an unanchored launcher through toggle or reset",function()
    local m=reset({hide=true}); width=0
    assert(not m:Initialize() and not m.button.shown)
    assert(m:ToggleVisibility()==false and not m.button.shown)
    assert(m:Reset()==false and not m.button.shown)
    width=200; assert(m:Reset() and m.button.shown)
    width=0; assert(not m:Reset() and not m.button.shown)
end)
check("Missing or throwing reparent capability hides the old button quietly",function()
    for mode=1,2 do
        local m=reset(); assert(m:Initialize()); local b=m.button
        Minimap=frame(); Minimap.GetWidth=function() return 200 end
        b.SetParent=mode==1 and false or function() error("cannot reparent") end
        local ok,result=pcall(m.Initialize,m)
        assert(ok and result==false and not b.shown)
        assert(not m:Current(),"failed parent change must not become current")
    end
end)
check("Failed show preserves hidden intent so the next toggle recovers immediately",function()
    local config={hide=true,angle=17}; local m=reset(config); width=0
    assert(not m:Initialize())
    assert(not m:ToggleVisibility() and config.hide==true and config.angle==17)
    width=200; assert(m:ToggleVisibility() and m.button.shown and config.hide==false)
    width=0; assert(not m:Reset() and config.angle==17 and config.hide==false)
    width=200; assert(m:Reset() and config.angle==225 and config.hide==false)
end)
check("A hidden launcher recovers in one toggle after initially unavailable minimap geometry",function()
    local config={hide=false,angle=17};local m=reset(config);width=0
    assert(not m:Initialize() and not m.button.shown and config.hide==false)
    width=200
    assert(m:ToggleVisibility() and m.button.shown and config.hide==false and config.angle==17)
    assert(m:ToggleVisibility() and not m.button.shown and config.hide==true)
    assert(m:ToggleVisibility() and m.button.shown and config.hide==false)
end)
check("Unknown visibility and replaced launcher sessions cannot toggle a newer preference",function()
    for _,kind in ipairs({"unknown","restricted","throw","session","config","owner"})do
        local config={hide=false,angle=17};local m=reset(config);assert(m:Initialize())
        local button=m.button;local newer
        button.IsShown=function()
            if kind=="throw"then error("visibility unavailable")end
            if kind=="session"then m.session={};return true end
            if kind=="config"then newer={hide=false};m.config=newer;return true end
            if kind=="owner"then addon.Minimap={};return true end
            return kind=="restricted"and secret or nil
        end
        assert(m:ToggleVisibility()==false and config.hide==false and button.shown,kind)
        assert(not newer or newer.hide==false)
    end
end)
check("Launcher has a stable raised round presentation without altering click or drag hitbox",function()
    local m=reset();assert(m:Initialize());local b=m.button
    assert(b.width==32 and b.height==32 and b.strata=="MEDIUM" and b.level==12 and b.clamped)
    assert(b.icon.width==26 and b.icon.height==26 and b.icon.mask==b.mask)
    assert(b.mask.texture=="Interface\\CharacterFrame\\TempPortraitAlphaMask")
    assert(b.border.width==42 and b.border.height==42 and b.border.texture=="Interface\\Common\\RingBorder")
    assert(b.highlight=="Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" and b.highlightMode=="ADD")
    for i=1,20 do assert(m:Initialize() and b.level==12) end
    assert(created==1 and not b.scripts.OnUpdate)
    b.scripts.OnClick(b,"LeftButton");assert(clicks==1)
end)
check("Unversioned hidden launchers recover once while current future or malformed revisions retain explicit visibility",function()
    local config={hide=true,angle=19,other="keep"};local m=reset(config,true)
    assert(m:Initialize() and m.button.shown and config.hide==false and config.launcherVersion==1 and config.angle==19 and config.other=="keep")
    assert(m:ToggleVisibility() and config.hide==true);assert(m:Initialize() and not m.button.shown)
    for _,revision in ipairs({1,2,false,"legacy",secret})do
        config={hide=true,angle=19,launcherVersion=revision};m=reset(config,true)
        assert(m:Initialize() and not m.button.shown and config.hide==true and config.launcherVersion==revision)
    end
end)
local function scheduled()
    local queue={};C_Timer={After=function(delay,fn)assert(delay==.25);queue[#queue+1]=fn end}
    return queue
end
check("Missing parent capabilities and zero startup geometry recover through bounded timers without a ticker",function()
    for _,kind in ipairs({"missing","getter","width","height"})do
        local config={hide=true,angle=19};local m=reset(config,true);local queue=scheduled();local native=Minimap
        local getter=native.GetWidth
        if kind=="missing"then Minimap=nil elseif kind=="getter"then native.GetWidth=false
        elseif kind=="width"then width=0 else native.GetHeight=function()return 0 end end
        assert(not m:Initialize() and #queue==1)
        Minimap=native;native.GetWidth=getter;native.GetHeight=function()return 200 end;width=200
        queue[1]();assert(m.button.shown and not m.retry and #queue==1 and not m.button.scripts.OnUpdate)
        assert(config.launcherVersion==1 and config.hide==false and config.angle==19)
    end
end)
check("Retry budgets finish even with inline or throwing schedulers and stale callbacks have no effects",function()
    local m=reset();width=0;local calls=0
    C_Timer={After=function(_,fn)calls=calls+1;fn()end}
    assert(not m:Initialize() and calls==8 and not m.retry and not m.button.shown)
    m=reset();width=0;local saved
    C_Timer={After=function(_,fn)saved=fn;error("queued then failed")end}
    assert(not m:Initialize() and not m.retry);width=200;saved();assert(not m.button.shown)
    for _,kind in ipairs({"owner","db","parent","session","timer","hide"})do
        m=reset();width=0;local queue=scheduled();assert(not m:Initialize() and #queue==1)
        if kind=="owner"then addon.Minimap={} elseif kind=="db"then addon.db={}
        elseif kind=="parent"then Minimap=frame() elseif kind=="session"then m.session={}
        elseif kind=="timer"then C_Timer={}else addon.db.minimap.hide=true end
        width=200;queue[1]();assert(not m.button.shown and #queue==1,kind)
    end
end)
check("A replacement initialization owns retries and manual hiding remains effective after recovery",function()
    local config={hide=false,launcherVersion=1};local m=reset(config);width=0;local queue=scheduled()
    assert(not m:Initialize());local stale=queue[1]
    assert(not m:Initialize() and #queue==2);width=200
    stale();assert(not m.button.shown);queue[2]();assert(m.button.shown and not m.retry)
    assert(m:ToggleVisibility() and not m.button.shown and config.hide)
    queue[2]();assert(not m.button.shown and config.hide)
end)
check("Optional launcher styling failures keep controls usable and reentry cannot place an older session",function()
    local m=reset();assert(m:Initialize());local b=m.button
    b.SetFrameStrata=function()error("protected")end;b.SetFrameLevel=false;b.SetClampedToScreen=false
    Minimap.GetFrameLevel=function()return secret end
    assert(m:Initialize() and b.shown)
    b.scripts.OnClick(b,"LeftButton");assert(clicks==1)
    m=reset({angle=17});assert(m:Initialize());b=m.button
    local setter=b.SetFrameStrata;local armed=true
    b.SetFrameStrata=function(self,value)
        setter(self,value)
        if armed then armed=false;addon.db.minimap.angle=90;assert(m:Initialize())end
    end
    assert(not m:Initialize() and not armed and b.shown)
    near(m.angle,90);near(b.point[4],0);near(b.point[5],108)
    assert(not b.scripts.OnUpdate)
end)
check("Native position persistence is unnecessary for placement drag reload and explicit hiding",function()
    local config={hide=false,angle=19,launcherVersion=1};local m=reset(config)
    local factory=CreateFrame;local calls=0
    CreateFrame=function(...)
        local b=factory(...)
        b.SetUserPlaced=function()calls=calls+1;error("optional persistence unavailable")end
        return b
    end
    assert(m:Initialize(),"optional persistence must not hide an anchored launcher")
    assert(m.button.shown and m.button.point[1]=="CENTER" and config.angle==19 and config.hide==false)
    m.button.scripts.OnClick(m.button,"LeftButton");assert(clicks==1)
    m:StartDrag("LeftButton");m.button.scripts.OnUpdate();m:StopDrag(true)
    near(config.angle,0);assert(m:Initialize() and m.button.shown);near(m.button.point[4],108)
    assert(m:ToggleVisibility() and config.hide and not m.button.shown)
    assert(m:Initialize() and config.hide and not m.button.shown)
    assert(m:Reset() and m.button.shown and config.angle==225 and config.hide==false and calls==0)
end)
check("Failed essential native anchoring still hides the launcher without changing user preferences",function()
    local config={hide=false,angle=19,launcherVersion=1};local m=reset(config)
    local factory=CreateFrame
    CreateFrame=function(...)
        local b=factory(...);b.SetPoint=function()error("anchor unavailable")end;return b
    end
    assert(not m:Initialize() and not m.button.shown and config.hide==false and config.angle==19)
    assert(not m:ToggleVisibility() and not m.button.shown and config.hide==false)
    assert(not m:Reset() and not m.button.shown and config.angle==19)
end)
check("Nested placement owns the final launcher anchor and angle",function()
    for _,method in ipairs({"ClearAllPoints","SetPoint"})do
        local m=reset({hide=false});assert(m:Initialize());local b=m.button
        local original,armed,snapshot=b[method],true
        b[method]=function(self,...)
            if armed then
                armed=false;assert(m:Place(90));snapshot={unpack(b.point)}
            end
            if method=="SetPoint"then self.order="clear"end
            return original(self,...)
        end
        assert(not m:Place(0),"superseded placement must retire")
        assert(snapshot and b.point[4]==snapshot[4]and b.point[5]==snapshot[5]and m.angle==90,method)
    end
end)
check("Superseded initialization and reset cannot hide a newer launcher placement",function()
    for _,operation in ipairs({"Initialize","Reset","ToggleVisibility"})do
        local m=reset({hide=false});assert(m:Initialize());local b=m.button
        if operation=="ToggleVisibility"then b:Hide()end
        local original,armed=b.SetPoint,true
        b.SetPoint=function(self,...)
            if armed then armed=false;assert(m:Place(90));b:Show()end
            self.order="clear";return original(self,...)
        end
        assert(not m[operation](m))
        assert(b.shown and m.angle==90,"older "..operation.." cannot hide a newer placement")
    end
    local m=reset({hide=false});assert(m:Initialize());local b=m.button
    local original,armed=b.SetPoint,true
    b.SetPoint=function(self,...)
        if armed then armed=false;assert(m:Initialize())end
        self.order="clear";return original(self,...)
    end
    assert(not m:Initialize()and b.shown,"older session cannot hide replacement initialization")
end)
check("Idle minimap resizing follows the same angle without replacing native handlers or adding hooks",function()
    local m=reset({hide=false,angle=0});local parent=Minimap;local hooks,calls={},0
    function parent:HasScript(key)return key=="OnSizeChanged"end
    function parent:HookScript(key,callback)assert(key=="OnSizeChanged");hooks[#hooks+1]=callback end
    parent.scripts.OnSizeChanged=function()calls=calls+1 end
    local function resize(value)
        width=value;parent.scripts.OnSizeChanged(parent)
        for _,callback in ipairs(hooks)do callback(parent,value,200)end
    end
    assert(m:Initialize());near(m.button.point[4],108)
    resize(400);near(m.button.point[4],208)
    assert(calls==1 and #hooks==1 and addon.db.minimap.angle==0)
    assert(m:Initialize()and m:Initialize()and #hooks==1)
    resize(300);near(m.button.point[4],158)
    assert(calls==2 and m.button.scripts.OnUpdate==nil)
end)
check("Resize recovery preserves explicit and external hiding without writing user preferences",function()
    local m=reset({hide=false,angle=0});local resize
    function Minimap:HasScript(key)return key=="OnSizeChanged"end
    function Minimap:HookScript(_,callback)resize=callback end
    assert(m:Initialize());local config=addon.db.minimap
    width=0;resize();assert(not m.button.shown and config.hide==false and config.angle==0)
    width=400;resize();assert(m.button.shown);near(m.button.point[4],208)
    m.button:Hide();width=300;resize();assert(not m.button.shown and config.hide==false)
    m.button:Show();assert(m:ToggleVisibility()and config.hide==true)
    width=500;resize();assert(not m.button.shown and config.hide==true and config.angle==0)
    assert(m:ToggleVisibility());near(m.button.point[4],258)
end)
check("Old minimap resize hooks become inert after parent or manager replacement",function()
    local m=reset({hide=false,angle=0});local hooks={}
    local function capabilities(parent)
        function parent:HasScript(key)return key=="OnSizeChanged"end
        function parent:HookScript(_,callback)hooks[parent]=callback end
    end
    local old=Minimap;capabilities(old);assert(m:Initialize())
    local newer=frame();newer.GetWidth=old.GetWidth;newer.GetEffectiveScale=old.GetEffectiveScale;newer.GetCenter=old.GetCenter
    capabilities(newer);Minimap=newer;width=300;assert(m:Initialize())
    local previous={unpack(m.button.point)};width=400;hooks[old]()
    assert(m.button.point[4]==previous[4]and m.button.parent==newer)
    hooks[newer]();near(m.button.point[4],208)
    previous={unpack(m.button.point)};addon.Minimap={};width=500;hooks[newer]()
    assert(m.button.point[4]==previous[4]);addon.Minimap=m
end)
check("Failed optional resize hooks stay inert and never compound during initialization",function()
    for _,mode in ipairs({"missing","unsupported","throws","lateThrows","false"})do
        local m=reset({hide=false,angle=0});local calls,callback=0
        if mode~="missing"then
            function Minimap:HasScript()return mode~="unsupported"end
            function Minimap:HookScript(_,fn)
                calls=calls+1
                if mode=="throws"then error("unsupported hook")end
                callback=fn
                if mode=="lateThrows"then error("hook installed before failure")end
                return false
            end
        end
        assert(m:Initialize()and m:Initialize()and m.button.shown)
        assert(calls<=1)
        width=400;if callback then callback()end
        near(m.button.point[4],108)
        m.button.scripts.OnClick(m.button,"LeftButton");assert(clicks==1)
    end
end)
check("Late resize Hide repairs a newer initialized launcher",function()
    local m=reset({hide=false,angle=0});local callback
    function Minimap:HasScript()return true end
    function Minimap:HookScript(_,fn)callback=fn end
    assert(m:Initialize());local b=m.button;local hide=b.Hide;local armed=true
    b.Hide=function(self)
        if armed then armed=false;width=200;assert(m:Initialize())end
        return hide(self)
    end
    width=0;callback();b.Hide=hide
    assert(not armed and b.shown)
end)
check("Late resize Show preserves a newer explicit hide",function()
    local m=reset({hide=false,angle=0});local callback
    function Minimap:HasScript()return true end
    function Minimap:HookScript(_,fn)callback=fn end
    assert(m:Initialize());local b=m.button
    width=0;callback();assert(not b.shown)
    local show=b.Show;local armed=true
    b.Show=function(self)
        if armed then
            armed=false;show(self);assert(m:ToggleVisibility()and addon.db.minimap.hide==true)
        end
        return show(self)
    end
    width=400;callback();b.Show=show
    assert(not armed and not b.shown and addon.db.minimap.hide==true)
end)
check("External hiding retires visibility intent before later resizing",function()
    local m=reset({hide=false,angle=0});local callback
    function Minimap:HasScript()return true end
    function Minimap:HookScript(_,fn)callback=fn end
    assert(m:Initialize());local b=m.button
    assert(b.launcherVisibility and b.launcherVisibility.shown)
    b:Hide();assert(b.launcherVisibility==nil)
    width=400;callback();assert(not b.shown and addon.db.minimap.hide==false)
end)
check("A new session or external hide retires an older size recovery intent",function()
    for _,mode in ipairs({"session","external"})do
        local m=reset({hide=false,angle=0});local callback
        function Minimap:HasScript()return true end
        function Minimap:HookScript(_,fn)callback=fn end
        assert(m:Initialize());width=0;callback();assert(not m.button.shown)
        width=200
        if mode=="session"then assert(m:Initialize());m.button:Hide()
        else m.button:Hide()end
        width=400;callback();assert(not m.button.shown and addon.db.minimap.hide==false)
    end
end)
check("Explicit recovery attempts during zero-size retain the later resize recovery",function()
    for _,action in ipairs({"ToggleVisibility","Reset","Initialize"})do
        local m=reset({hide=false,angle=0});local callback
        function Minimap:HasScript()return true end
        function Minimap:HookScript(_,fn)callback=fn end
        assert(m:Initialize());width=0;callback();assert(not m.button.shown)
        assert(m[action](m)==false and addon.db.minimap.hide==false)
        width=400;callback()
        assert(m.button.shown,action.." discarded pending geometry recovery")
        near(m.button.point[4],208)
    end
end)
check("Reset schedules bounded retry when placement geometry is unavailable",function()
    local config={hide=false,angle=17};local m=reset(config);assert(m:Initialize())
    local queue=scheduled();width=0
    assert(m:Reset()==false and #queue==1 and config.angle==17 and config.hide==false)
    assert(not m.button.shown and m.retry)
    width=200;queue[1]()
    assert(m.button.shown and not m.retry)
    assert(m:Reset() and config.angle==225 and config.hide==false and m.button.shown)
end)
check("Toggle show schedules bounded retry when placement geometry is unavailable",function()
    local config={hide=false,angle=17};local m=reset(config);assert(m:Initialize())
    local queue=scheduled();m.button:Hide()
    width=0
    assert(m:ToggleVisibility()==false and #queue==1 and config.angle==17 and config.hide==false)
    assert(not m.button.shown and m.retry)
    width=200;queue[1]()
    assert(m.button.shown and not m.retry and #queue==1 and not m.button.scripts.OnUpdate)
    assert(config.hide==false and config.angle==17)
end)
check("Toggle show recovers through a manual repeat after unavailable geometry",function()
    local config={hide=false,angle=17};local m=reset(config);assert(m:Initialize())
    local queue=scheduled();m.button:Hide()
    width=0
    assert(m:ToggleVisibility()==false and #queue==1 and config.hide==false)
    width=200
    assert(m:ToggleVisibility() and m.button.shown and config.hide==false and config.angle==17)
    queue[1]();assert(m.button.shown and config.hide==false)
end)
issecretvalue=nil
print("Minimap modeled checks passed: "..total.." (native client unverified)")
