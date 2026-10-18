local addon, total, calls, row, tooltip, secret = {}, 0, 0, nil, nil, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
local function frame()
    local f = { shown = true, scripts = {} }
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:SetWidth(value)self.width=value end
    function f:SetText(value)self.text=value end
    function f:SetJustifyH(value)self.justify=value end
    function f:SetFontObject(value)self.font=value end
    function f:CreateFontString()return frame()end
    function f:ClearAllPoints() self.point = nil end
    function f:SetPoint(...) self.point = { ... } end
    function f:SetAllPoints(value) self.allPoints = value end
    function f:SetTexture(value) self.texture = value; return true end
    function f:SetScript(kind, fn) self.scripts[kind] = fn end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide() end end
    function f:IsShown() return self.shown end
    function f:CreateTexture() self.textureObject = frame(); return self.textureObject end
    return f
end
local buttons, payload
local function reset()
    buttons, calls = {}, 0
    issecretvalue = function(v) return v == secret end
    GetLocale = function() return "enUS" end
    addon.char, addon.quests = {}, { [1] = {}, [2] = {} }
    addon.Theme={ApplyFont=function(region,size)region.fontSize=size;return "Fonts\\FRIZQT__.TTF" end}
    GameFontNormalSmall={}
    addon.L = function(key) return key == "REWARD_CHOICES" and "Choose one" or "Rewards" end
    payload = { source = "cache", items = { { id = 10, name = "Sword", count = 1, texture = 123 } }, choices = {} }
    addon.CachedQuestRewards = function(id) calls = calls + 1; assert(id == 1 or id == 2); return payload end
    addon.QuestRewards = function() error("selected log must never be queried") end
    addon.DialogueRewards = function() error("dialogue must never be queried") end
    RequestLoadQuestByID = function() error("no reward requests") end
    CreateFrame = function(_, _, parent) local f = frame(); f.parent = parent; buttons[#buttons + 1] = f; return f end
    row = frame()
    tooltip = frame()
    function tooltip:SetOwner(button) self.owner = button end
    function tooltip:IsOwned(button) return self.owner == button end
    function tooltip:SetText(value) self.text = value end
    function tooltip:SetItemByID() error("hover must not load items") end
    GameTooltip = tooltip
    assert(loadfile("UI/QuestListRewards.lua"))("DungeonPro", addon)
    return addon.QuestListRewards
end
local function check(name, fn)
    local ok, err = pcall(fn); assert(ok, name .. ": " .. tostring(err)); total = total + 1; print("PASS " .. name)
end
check("Cached-only reward paint reserves compact title space and never changes quest selection", function()
    local r = reset(); assert(r.Paint(row, 1, function() return true end) == 26)
    assert(calls == 1 and #buttons == 1 and buttons[1].width == 20 and buttons[1].height == 20)
    assert(buttons[1].icon.texture == 123 and buttons[1].point[1] == "TOPRIGHT" and buttons[1].point[4] == -6)
end)
check("Only three actual cached textures paint with fixed-before-choice provenance", function()
    local r = reset(); payload.items[2] = { id = 11, name = "No icon", count = 1 }
    payload.choices = { { id = 12, name = "Hat", count = 2, texture = "hat" },
        { id = 13, name = "Boots", count = 1, texture = 456 }, { id = 14, name = "Ring", count = 1, texture = 789 } }
    assert(r.Paint(row, 1) == 70 and #buttons == 3)
    assert(buttons[2].icon.texture == "hat" and buttons[3].icon.texture == 456)
    buttons[2].scripts.OnEnter(); assert(tooltip.text:find("Choose one\n|That:18:18:0:0|t Hat ×2",1,true) and calls == 1)
end)
check("Missing hidden or foreign-origin rewards never invent an icon and clear recycled rows", function()
    for _, value in ipairs({ {}, { source = "cache", hidden = true }, { source = "dialogue" } }) do
        local r = reset(); r.Paint(row, 1); payload = value
        assert(r.Paint(row, 2) == 0 and not buttons[1].shown and not buttons[1].icon.shown)
        assert(buttons[1].icon.texture == nil and buttons[1].scripts.OnEnter == nil)
    end
end)
check("Malformed restricted and excessive payloads cannot authorize icon layout", function()
    for _, field in ipairs({ "id", "name", "count", "texture" }) do
        local r = reset(); payload.items[1][field] = secret; assert(r.Paint(row, 1) == 0)
    end
    local r = reset(); for i = 2, 101 do payload.items[i] = payload.items[1] end
    assert(r.Paint(row, 1) == 0)
    r = reset(); payload.hidden = secret; assert(r.Paint(row, 1) == 0)
end)
check("Unknown catalogue quests skip provider and expired owner prevents allocation", function()
    local r = reset(); assert(r.Paint(row, 999) == 0 and calls == 0)
    assert(r.Paint(row, 1, function() return false end) == 0 and calls == 0 and #buttons == 0)
end)
check("Hover only uses cached names and expired catalogue provider locale and character bindings do nothing", function()
    for _, change in ipairs({ function() addon.quests[1] = {} end, function() addon.char = {} end,
        function() addon.CachedQuestRewards = function() error("no hover reads") end end,
        function() GetLocale = function() return "koKR" end end }) do
        local r = reset(); r.Paint(row, 1); local enter = buttons[1].scripts.OnEnter
        tooltip.shown = false; change(); enter(); assert(not tooltip.shown and tooltip.text == nil and calls == 1)
    end
end)
check("Clear hides only the held owned tooltip and retained callbacks cannot reopen it", function()
    local r = reset(); r.Paint(row, 1); local enter = buttons[1].scripts.OnEnter
    enter(); assert(tooltip.owner == buttons[1]); r.Clear(row); assert(not tooltip.shown and not buttons[1].shown)
    enter(); assert(not tooltip.shown)
    r.Paint(row, 1); buttons[1].scripts.OnEnter(); tooltip.owner = {}; tooltip.shown = true
    r.Clear(row); assert(tooltip.shown)
end)
check("Provider reentry cannot publish old rewards into a newer row", function()
    local r = reset(); local once
    addon.CachedQuestRewards = function()
        if not once then once = true; r.Paint(row, 2); return { source = "cache", items = { { id = 99, name = "Old", count = 1, texture = 999 } } } end
        return payload
    end
    assert(r.Paint(row, 1) == 0); assert(#buttons == 1 and buttons[1].icon.texture == 123)
end)
check("Late native texture writes restore a newer paint and clear", function()
    for _, clear in ipairs({ false, true }) do
        local r = reset(); r.Paint(row, 1); local icon = buttons[1].icon; local original, once = icon.SetTexture
        icon.SetTexture = function(self, value)
            if not once then
                once = true
                if clear then r.Clear(row) else payload.items[1].texture = 456; r.Paint(row, 2) end
            end
            return original(self, value)
        end
        assert(r.Paint(row, 1) == 0)
        assert(icon.texture == (not clear and 456 or nil))
        assert(buttons[1].shown == not clear)
    end
end)
check("Native hide reentry preserves a newer reward icon", function()
    local r = reset(); r.Paint(row, 1); local button = buttons[1]; local original, once = button.Hide
    button.Hide = function(self)
        if not once then once = true; r.Paint(row, 2) end
        original(self)
    end
    r.Clear(row); assert(button.shown and button.icon.shown and button.icon.texture == 123)
end)
check("Late native tooltip text restores the newer icon tooltip", function()
    local r = reset(); r.Paint(row, 1); local original, once = tooltip.SetText
    tooltip.SetText = function(self, value)
        if not once then
            once = true; payload.items[1].name = "New sword"; r.Paint(row, 2); buttons[1].scripts.OnEnter()
        end
        original(self, value)
    end
    buttons[1].scripts.OnEnter(); assert(tooltip.text=="Rewards\n|T123:18:18:0:0|t New sword" and tooltip.shown)
end)
check("Partial icon creation remains retryable without retaining a broken button", function()
    local r = reset(); local native, once = CreateFrame
    CreateFrame = function(...)
        local button = native(...)
        if not once then once = true; button.CreateTexture = function() return nil end end
        return button
    end
    assert(r.Paint(row, 1) == 0 and not buttons[1].shown)
    assert(r.Paint(row, 1) == 26 and #buttons == 2 and buttons[2].icon.texture == 123)
end)
check("Late tooltip hide restores the newer icon owner without querying rewards on hover", function()
    local r = reset(); r.Paint(row, 1); buttons[1].scripts.OnEnter()
    local original, once = tooltip.Hide
    tooltip.Hide = function(self)
        if not once then
            once = true; payload.items[1].name = "Newest"; r.Paint(row, 2); buttons[1].scripts.OnEnter()
        end
        original(self)
    end
    -- The held contract refuses replacement methods, so acquire the replacement first.
    buttons[1].scripts.OnEnter(); local leave = buttons[1].scripts.OnLeave
    leave(); assert(tooltip.shown and tooltip.text=="Rewards\n|T123:18:18:0:0|t Newest")
end)
check("A foreign tooltip takeover inside SetText cannot be shown or hidden by an old icon", function()
    local r = reset(); r.Paint(row, 1)
    tooltip.SetText = function(self, value) self.text = value; self.owner = {}; self.shown = false end
    buttons[1].scripts.OnEnter(); assert(not tooltip.shown)
end)
check("Hidden ancestor icons cannot open tooltips through retained callbacks", function()
    local r = reset(); r.Paint(row, 1); local enter = buttons[1].scripts.OnEnter
    row.IsVisible = function() return false end
    enter(); assert(tooltip.text == nil)
    row.IsVisible = function() return secret end
    enter(); assert(tooltip.text == nil)
    row.IsVisible = nil
    local parent = frame(); parent:Hide(); row.GetParent = function() return parent end
    enter(); assert(tooltip.text == nil)
    parent:Show(); enter(); assert(tooltip.text=="Rewards\n|T123:18:18:0:0|t Sword")
end)
check("A failed replacement texture hides recycled rewards instead of leaking the old quest icon", function()
    for _, fail in ipairs({ function() error("native texture failure") end, function() return false end }) do
        local r = reset(); r.Paint(row, 1); local button = buttons[1]
        button.icon.SetTexture = fail
        payload.items[1] = { id = 22, name = "New", count = 1, texture = 456 }
        assert(r.Paint(row, 2) == 0)
        assert(not button.shown and not button.icon.shown and button.scripts.OnEnter == nil)
    end
end)
check("Every fixed reward and choose-one option remains in grouped hover preview beyond three icons",function()
    local r=reset()
    payload.items={{id=10,name="Fixed sword",count=1,texture=123},{id=11,name="Fixed ring",count=2,texture=124}}
    payload.choices={}
    for i=1,4 do payload.choices[i]={id=20+i,name="Choice "..i,count=i,texture=200+i}end
    assert(r.Paint(row,1)==70 and #buttons==3 and buttons[3].overflowLabel.text=="+3"and buttons[3].overflowLabel.shown)
    for _,button in ipairs(buttons)do
        button.scripts.OnEnter()
        assert(tooltip.text:find("Rewards\n|T123:18:18:0:0|t Fixed sword",1,true))
        assert(tooltip.text:find("|T124:18:18:0:0|t Fixed ring ×2\n\nChoose one\n",1,true))
        for i=1,4 do assert(tooltip.text:find("|T"..(200+i)..":18:18:0:0|t Choice "..i,1,true))end
        assert(calls==1)
    end
    r.Clear(row);assert(not buttons[3].overflowLabel.shown)
end)
check("Three fixed previews never discard the complete separate choice group",function()
    local r=reset();payload.items={};payload.choices={}
    for i=1,3 do payload.items[i]={id=i,name="Fixed "..i,count=1,texture=100+i}end
    payload.choices={{id=1,name="Also a choice",count=1,texture=101},{id=20,name="Other choice",count=1,texture=200}}
    assert(r.Paint(row,1)==70 and buttons[3].overflowLabel.text=="+2")
    buttons[1].scripts.OnEnter()
    assert(tooltip.text:find("Rewards\n",1,true)==1 and tooltip.text:find("Choose one\n|T101:18:18:0:0|t Also a choice",1,true))
    assert(tooltip.text:find("Other choice",1,true)and calls==1)
end)
check("Known choices without textures remain named in full hover preview and overflow count",function()
    local r=reset();payload.choices={{id=20,name="No texture choice",count=1},{id=21,name="Textured choice",count=1,texture=222}}
    assert(r.Paint(row,1)==48 and buttons[2].overflowLabel.text=="+1")
    buttons[1].scripts.OnEnter()
    assert(tooltip.text:find("Choose one\nNo texture choice\n|T222:18:18:0:0|t Textured choice",1,true)and calls==1)
end)
check("Both bounded hundred-item groups are retained with a truthful remaining count",function()
    local r=reset();payload.items={};payload.choices={}
    for i=1,100 do
        payload.items[i]={id=i,name="Fixed "..i,count=1,texture=100+i}
        payload.choices[i]={id=1000+i,name="Choice "..i,count=1,texture=1000+i}
    end
    assert(r.Paint(row,1)==70 and #buttons==3 and buttons[3].overflowLabel.text=="+197")
    buttons[3].scripts.OnEnter()
    for i=1,100 do assert(tooltip.text:find("|T"..(100+i)..":18:18:0:0|t Fixed "..i,1,true))
        assert(tooltip.text:find("|T"..(1000+i)..":18:18:0:0|t Choice "..i,1,true))end
    assert(calls==1)
end)
check("Full reward markup escapes names and permits inline icons only for safe cached paths or numeric IDs",function()
    local r=reset()
    payload.items[1].name="Sword |cffff0000|Hitem:fake|h"
    payload.choices={{id=20,name="Unsafe path",count=1,texture="bad|T999:99|t"},
        {id=21,name="Colon path",count=1,texture="bad:99"},
        {id=22,name="Safe path",count=1,texture="Interface\\Icons\\Safe"}}
    assert(r.Paint(row,1)==70)
    buttons[1].scripts.OnEnter()
    assert(tooltip.text:find("Sword ||cffff0000||Hitem:fake||h",1,true))
    assert(tooltip.text:find("Choose one\nUnsafe path\nColon path\n|TInterface\\Icons\\Safe:18:18:0:0|t Safe path",1,true))
    assert(not tooltip.text:find("\n|Tbad",1,true)and calls==1)
end)
check("Overflow labels use locale-aware fonts and reuse bounded labels while smaller rewards clear them",function()
    local r=reset();payload.choices={}
    for i=1,4 do payload.choices[i]={id=20+i,name="Choice "..i,count=1,texture=200+i}end
    local paints=0;addon.Theme.ApplyFont=function(region,size)paints=paints+1;region.fontSize=size;region.language="koKR";return {family="Hangul"} end
    r.Paint(row,1);local label=buttons[3].overflowLabel
    assert(label.fontSize==10 and label.language=="koKR"and label.text=="+2")
    for i=1,5 do assert(r.Paint(row,1)==70 and buttons[3].overflowLabel==label)end
    assert(#buttons==3 and paints==6)
    payload.choices={};assert(r.Paint(row,2)==26 and not label.shown)
end)
check("Late overflow setters cannot overwrite a newer count or resurrect a cleared reward row",function()
    for _,clear in ipairs({false,true})do
        local r=reset();payload.choices={}
        for i=1,5 do payload.choices[i]={id=20+i,name="Choice "..i,count=1,texture=200+i}end
        r.Paint(row,1);local label=buttons[3].overflowLabel;local original,once=label.SetText
        label.SetText=function(self,value)
            if not once then
                once=true
                if clear then r.Clear(row)
                else payload.choices[5]=nil;payload.choices[4]=nil;r.Paint(row,2)end
            end
            return original(self,value)
        end
        assert(r.Paint(row,1)==0)
        assert(clear and not label.shown or not clear and label.shown and label.text=="+1")
    end
end)
check("Missing or failed theme fonts fall back safely without silently hiding overflow information",function()
    local r=reset();payload.choices={}
    for i=1,3 do payload.choices[i]={id=20+i,name="Choice "..i,count=1,texture=200+i}end
    addon.Theme=nil;assert(r.Paint(row,1)==70 and buttons[3].overflowLabel.font==GameFontNormalSmall)
    addon.Theme={ApplyFont=function()error("font unavailable")end};assert(r.Paint(row,1)==70)
    GameFontNormalSmall=nil;assert(r.Paint(row,2)==0)
    for _,button in ipairs(buttons)do assert(not button.shown)end
end)
check("Pending identifies only a current cold nil cache and clears on replacement invalid data or explicit cleanup",function()
    local r=reset();payload=nil
    assert(r.Paint(row,1)==0 and r.Pending(row)==1 and calls==1)
    r.Clear(row);assert(r.Pending(row)==nil)
    for _,data in ipairs({{},false,"invalid",secret,{source="cache",items={},choices={}}})do
        payload=data;r.Paint(row,1);assert(r.Pending(row)==nil)
    end
    addon.CachedQuestRewards=function()error("unavailable provider")end
    r.Paint(row,1);assert(r.Pending(row)==nil)
    addon.CachedQuestRewards=function()return nil end;r.Paint(row,1,function()return true end);assert(r.Pending(row)==1)
    addon.char={};assert(r.Pending(row)==nil)
    r.Paint(row,1,function()return false end);assert(r.Pending(row)==nil)
end)
check("Successful real theme return shapes preserve the applied locale font without fallback",function()
    local results={"Fonts\\2002.ttf",{family="Hangul"}}
    if type(newproxy)=="function"then results[#results+1]=newproxy()end
    for _,result in ipairs(results)do
        local r=reset();payload.choices={}
        for i=1,3 do payload.choices[i]={id=20+i,name="Choice "..i,count=1,texture=200+i}end
        local styled=0
        addon.Theme.ApplyFont=function(region,size)styled=styled+1;region.localeFont=result;return result end
        GameFontNormalSmall=nil
        assert(r.Paint(row,1)==70)
        local label=buttons[3].overflowLabel
        assert(styled==1 and label.shown and label.localeFont==result and label.font==nil and label.text=="+1")
        label.SetFontObject=function()error("successful theme font must never be replaced")end
        GameFontNormalSmall={};assert(r.Paint(row,2)==70 and styled==2 and label.localeFont==result)
    end
end)
check("Native item stats survive full grouped reward additions for each actual hovered choice",function()
    local r=reset();payload.choices={{id=21,name="Choice one",count=1,texture=201},{id=22,name="Choice two",count=1,texture=202}}
    local textWrites=0;local original=tooltip.SetText
    tooltip.SetText=function(self,value)textWrites=textWrites+1;return original(self,value)end
    tooltip.SetHyperlink=function(self,link)self.link=link;self.text="Native item stats";self.lines={}end
    tooltip.AddLine=function(self,value)self.lines[#self.lines+1]=value end
    assert(r.Paint(row,1)==70)
    for index,id in ipairs({10,21,22})do
        buttons[index].scripts.OnEnter()
        assert(tooltip.link=="item:"..id and tooltip.text=="Native item stats"and textWrites==0)
        local list=table.concat(tooltip.lines,"\n")
        assert(list:find("Rewards",1,true)and list:find("Choose one",1,true)and list:find("Choice two",1,true)and calls==1)
    end
    buttons[3].scripts.OnLeave();assert(not tooltip.shown)
end)
check("Unsupported or failed native hyperlinks retain cached fallback and native-only tooltips retain stats",function()
    for _,failure in ipairs({false,"throw"})do
        local r=reset()
        tooltip.SetHyperlink=function()if failure=="throw"then error("missing item")end;return false end
        r.Paint(row,1);buttons[1].scripts.OnEnter()
        assert(tooltip.shown and tooltip.text:find("Sword",1,true)and calls==1)
    end
    local r=reset();tooltip.SetHyperlink=function(self,link)self.link=link;self.text="Stats"end
    r.Paint(row,1);buttons[1].scripts.OnEnter();assert(tooltip.shown and tooltip.text=="Stats"and tooltip.link=="item:10")
end)
check("Late native item and appended lines preserve newer hover while foreign ownership and Clear stay untouched",function()
    for _,stage in ipairs({"hyperlink","line","foreign","clear"})do
        local r=reset();local once
        tooltip.SetHyperlink=function(self,link)
            if not once and stage~="line"then
                once=true
                if stage=="clear"then r.Clear(row)
                elseif stage=="foreign"then self.owner={};self.shown=false
                else payload.items[1].id=11;r.Paint(row,2);buttons[1].scripts.OnEnter()end
            end
            self.link=link;self.text="Stats";self.lines={}
        end
        tooltip.AddLine=function(self,line)
            if not once and stage=="line"then once=true;payload.items[1].id=11;r.Paint(row,2);buttons[1].scripts.OnEnter()end
            self.lines[#self.lines+1]=line
        end
        r.Paint(row,1);buttons[1].scripts.OnEnter();assert(once)
        if stage=="clear"then assert(not tooltip.shown and not buttons[1].shown)
        elseif stage=="foreign"then assert(not tooltip.shown and tooltip.owner~=buttons[1])
        else assert(tooltip.shown and tooltip.link=="item:11"and tooltip.text=="Stats"and calls==2)end
    end
end)
print("Quest list reward checks passed: " .. total .. " (modeled, no native layout proof)")
