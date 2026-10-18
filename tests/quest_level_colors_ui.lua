-- Client-returned quest difficulty and actual character minimum-level state stay separate.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui = fixture.addon, fixture.addon.UI
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();addon.db.locale="enUS"
local q={id=990201,name="Colour quest",level=16,minLevel=9,requirementsKnown=true,classes={"PALADIN"},factions={"Alliance"}}
addon.quests[q.id]=q
local dungeon={key="level-colours",name="Colour dungeon",minLevel=1,maxLevel=80,quests={q.id}}
addon.dungeons={dungeon};ui.dungeon=dungeon;ui.quest=q.id;ui.includeUnavailable=true
-- Deliberately different inspected context: only native UnitLevel may colour the minimum.
local context={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}
addon.Context=function()return context end
local actual,effective,trivial=8,8,5
UnitLevel=function(unit)assert(unit=="player");return actual end
UnitEffectiveLevel=function(unit)assert(unit=="player");return effective end
UnitQuestTrivialLevelRange=function(unit)assert(unit=="player");return trivial end
local calls,colour=0,{r=1,g=0,b=0}
local native=function(level)calls=calls+1;assert(level==q.level);return colour end
GetQuestDifficultyColor=native
local function render()ui:Refresh()end
local function caption()
    for _,field in ipairs(ui.details)do if field:IsShown()and field.text:find(addon.L("DETAIL_MIN_LEVEL",q.minLevel),1,true)then return field.text,field end end
    return ""
end
local function tag(hex,key,value)return "|cff"..hex..addon.L(key,value).."|r"end
render()
local status=ui.engine:State(q.id).status
assert(caption():find(tag("ff0000","DETAIL_LEVEL",16),1,true),"native quest difficulty colour is visible")
assert(caption():find(tag("ff5555","DETAIL_MIN_LEVEL",9),1,true),"actual low character level is red despite a higher inspected context")
for _,sample in ipairs({{{r=1,g=0,b=0},"ff0000"},{{r=1,g=.5,b=0},"ff8000"},{{r=1,g=1,b=0},"ffff00"},{{r=0,g=1,b=0},"00ff00"},{{r=.5,g=.5,b=.5},"808080"}})do
    colour=sample[1];render();assert(caption():find(tag(sample[2],"DETAIL_LEVEL",16),1,true))
    assert(caption():find(tag("ff5555","DETAIL_MIN_LEVEL",9),1,true)and ui.engine:State(q.id).status==status)
end
actual=9;colour={r=1,g=0,b=0};render()
assert(caption():find(tag("ff0000","DETAIL_LEVEL",16),1,true)and caption():find(tag("66dd99","DETAIL_MIN_LEVEL",9),1,true),
    "hard quest remains red while its met minimum becomes green")
local text=caption();assert(text:find("|r · |cff66dd99",1,true)and text:find("|r · ",1,true),"each metadata field closes its own colour before class text")
assert(ui.engine:State(q.id).status==status,"green minimum never overrides class or quest availability")
local marker={}
issecretvalue=function(value)return value==marker end
for _,bad in ipairs({false,"red",{}, {r=1,g=0}, {r="1",g=0,b=0}, {r=-1,g=0,b=0}, {r=2,g=0,b=0}, {r=math.huge,g=0,b=0}, {r=0/0,g=0,b=0}, {r=marker,g=0,b=0},marker})do
    colour=bad;render()
    assert(caption():find(addon.L("DETAIL_LEVEL",16).." · ",1,true),"malformed or restricted native colours stay neutral")
    assert(caption():find(tag("66dd99","DETAIL_MIN_LEVEL",9),1,true))
end
for _,getter in ipairs({false,function()error("not available")end})do
    GetQuestDifficultyColor=getter;render();assert(caption():find(addon.L("DETAIL_LEVEL",16).." · ",1,true))
end
GetQuestDifficultyColor=native;colour={r=1,g=0,b=0}
for _,bad in ipairs({false,0,-1,9.5,math.huge,marker})do
    actual=bad;local reads=calls;render()
    assert(calls==reads and caption():find(addon.L("DETAIL_LEVEL",16).." · "..addon.L("DETAIL_MIN_LEVEL",9),1,true),"unknown real level stays neutral without a native difficulty call")
end
actual=nil;render();assert(caption():find(addon.L("DETAIL_MIN_LEVEL",9),1,true))
local savedLevelGetter=UnitLevel
for _,getter in ipairs({false,function()error("unit level unavailable")end})do
    UnitLevel=getter;local reads=calls;render()
    assert(calls==reads and caption():find(addon.L("DETAIL_LEVEL",16).." · "..addon.L("DETAIL_MIN_LEVEL",9),1,true))
end
UnitLevel=savedLevelGetter

actual=8;render()
assert(caption():find(tag("ff5555","DETAIL_MIN_LEVEL",9),1,true))
actual=10
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame,"PLAYER_LEVEL_UP",10)
assert(caption():find(tag("66dd99","DETAIL_MIN_LEVEL",9),1,true),"native level-up event refreshes the existing metadata")
-- Every external callback can invalidate the sampled state before a new colour is published.
local function hasMarker()
    for _,field in ipairs(ui.details)do if field:IsShown()and field.text:find("|cff010203",1,true)then return true end end
    return false
end
for _,kind in ipairs({"level","effective","trivial","source","minimum","character","getter","levelGetter","effectiveGetter","trivialGetter","localizer","locale"})do
    actual,effective,trivial=10,10,5;q.level,q.minLevel=16,9;addon.db.locale="enUS"
    local oldchar,oldL,oldLevel,oldEffective,oldTrivial=addon.char,addon.L,UnitLevel,UnitEffectiveLevel,UnitQuestTrivialLevelRange
    GetQuestDifficultyColor=native;colour={r=1,g=0,b=0};render()
    local armed=true
    GetQuestDifficultyColor=function()
        if armed then
            armed=false
            if kind=="level"then actual=11
            elseif kind=="effective"then effective=11
            elseif kind=="trivial"then trivial=6
            elseif kind=="source"then q.level=17
            elseif kind=="minimum"then q.minLevel=10
            elseif kind=="character"then addon.char={}
            elseif kind=="getter"then GetQuestDifficultyColor=native
            elseif kind=="levelGetter"then UnitLevel=function()return 10 end
            elseif kind=="effectiveGetter"then UnitEffectiveLevel=function()return 10 end
            elseif kind=="trivialGetter"then UnitQuestTrivialLevelRange=function()return 5 end
            elseif kind=="localizer"then addon.L=function(...)return oldL(...)end
            else addon.db.locale="ruRU"end
        end
        return{r=1/255,g=2/255,b=3/255}
    end
    ui:RefreshDetail();assert(not armed and not hasMarker(),"stale colour rejected: "..kind)
    addon.char,addon.L,UnitLevel,UnitEffectiveLevel,UnitQuestTrivialLevelRange=oldchar,oldL,oldLevel,oldEffective,oldTrivial
end
actual,effective,trivial=8,8,5;q.level,q.minLevel=16,9;addon.db.locale="enUS";GetQuestDifficultyColor=native;colour={r=1,g=0,b=0};render()
local _,field=caption();local setter,armed=field.SetText,true
field.SetText=function(self,value)
    if armed and value:find(addon.L("DETAIL_MIN_LEVEL",9),1,true)then armed=false;actual=10;ui:RefreshDetail()end
    return setter(self,value)
end
ui:RefreshDetail();field.SetText=setter
assert(not armed and caption():find(tag("66dd99","DETAIL_MIN_LEVEL",9),1,true)and not caption():find(tag("ff5555","DETAIL_MIN_LEVEL",9),1,true),"late native text write repairs the newly owned level colour")
q.level=nil;local L=addon.L;armed=true
addon.L=function(key,...)
    local value=L(key,...)
    if armed and key=="DETAIL_MIN_LEVEL"then armed=false;q.level=16;return "STALE ABSENT LEVEL" end
    return value
end
ui:RefreshDetail();addon.L=L
assert(not armed,"absent recorded level is also snapshotted before localization")
for _,entry in ipairs(ui.details)do assert(not entry:IsShown()or not entry.text:find("STALE ABSENT LEVEL",1,true))end
for _,blank in ipairs({"","   "})do
    addon.L=function(key,...)
        if key=="DETAIL_LEVEL"or key=="DETAIL_MIN_LEVEL"then return blank end
        return L(key,...)
    end
    render()
    for _,entry in ipairs(ui.details)do if entry:IsShown()then
        assert(not entry.text:find("|cffff0000"..blank.."|r",1,true)and not entry.text:find("|cff66dd99"..blank.."|r",1,true),
            "colour markup never promotes blank localized metadata into visible content")
    end end
end
addon.L=L
print("Quest level colour checks passed (native-returned RGB modeled; native rendering unverified)")
