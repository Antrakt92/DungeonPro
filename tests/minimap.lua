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
function methods:SetAllPoints() end
function methods:SetTexture(value) self.texture=value; return textureResult end
function methods:SetText(value) self.text=value end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
local function frame(parent) return setmetatable({parent=parent,scripts={}}, {__index=methods}) end
function methods:CreateTexture() self.icon=frame(self); return self.icon end
function methods:CreateFontString() self.label=frame(self); return self.label end
local function reset(config)
    created, clicks, cursorX, cursorY, scale, cx, cy, width, textureResult=0,0,400,200,2,100,100,200,true
    issecretvalue=function(value) return value==secret end
    GetCursorPosition=function(...) assert(select("#",...)==0); return cursorX,cursorY end
    Minimap=frame(); Minimap.GetWidth=function() return width end
    Minimap.GetEffectiveScale=function() return scale end
    Minimap.GetCenter=function() return cx,cy end
    addon.db={ minimap=config }; addon.UI={Toggle=function() clicks=clicks+1 end}
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
    assert(m.button.parent==native and m.button.shown and m.button.userPlaced and m.button.scripts.OnUpdate==nil)
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
issecretvalue=nil
print("Minimap modeled checks passed: "..total.." (native client unverified)")
