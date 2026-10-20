-- Compact giver action shares the location's first line and stays gold in both surfaces.
local fixture=assert(loadfile("tests/client_ui.lua"))("fixture")
local addon,ui=fixture.addon,fixture.addon.UI
function fixture.methods:SetAlpha(value)self.alpha=value end
function fixture.methods:SetDesaturated(value)self.desaturated=value end
function fixture.methods:SetVertexColor(...)self.vertex={...}end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();addon.db.locale="enUS"
local q={id=990301,name="Inline navigation",level=16,minLevel=1,requirementsKnown=true,
    start={npcID=1,name="Start One",zoneName="Known area",mapID=1453,x=10,y=20},
    finish={npcID=2,name="Finish Two",zoneName="Known area",mapID=1453,x=30,y=40}}
addon.quests[q.id]=q
local dungeon={key="inline-navigation",name="Inline navigation",minLevel=1,maxLevel=80,quests={q.id}}
addon.dungeons={dungeon};ui.dungeon=dungeon;ui.quest=q.id
local context={level=20,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}
addon.Context=function()return context end
local visits=0
addon.Navigation={Start=function(action)assert(action.id==q.id and action.place==q.start);visits=visits+1;return true end,
    Map=function(point)assert(point==q.start);visits=visits+1;return true end}
local function render()ui:Refresh()end
local function text(part)
    for _,field in ipairs(ui.details)do if field:IsShown()and field.text:find(part,1,true)then return field end end
    for _,row in ipairs(ui.detailContactRows or {})do if row:IsShown()then
        for _,field in ipairs({row.title,row.note})do if field.text:find(part,1,true)then return field end end
    end end
    error("missing field "..part)
end
render()
local giver=ui.giver
local pickup,finish=assert(ui.detailContactRows[1]),assert(ui.detailContactRows[2])
assert(pickup:IsShown()and finish:IsShown()and pickup.enabled and finish.enabled,"two full-width contacts are actionable")
assert(not giver:IsShown()and not giver.enabled and giver.scripts.OnClick==nil,"obsolete right-pane glyph is retired")
local location,turnin=text("Start One"),text("Finish Two")
assert(pickup:GetWidth()==ui.detail:GetWidth()-8 and location:GetWidth()==ui.detail:GetWidth()-92,"own contact text uses full-row width")
assert(pickup:GetHeight()>=76 and finish.point[3]<=pickup.point[3]-pickup:GetHeight()-8,"finisher follows the measured pickup row without overlap")
local retired=assert(pickup.scripts.OnClick)
local function gold(control,alpha)
    assert(control.navigationGold and #control.footerIconParts==3)
    for _,part in ipairs(control.footerIconParts)do
        assert(part.texture=="Interface\\Buttons\\WHITE8X8"and part.vertex[1]==1 and part.vertex[2]==.78 and part.vertex[3]==.15)
        assert(part.alpha==alpha and not part.desaturated,"all solid arrow strokes remain readable gold")
    end
end
gold(giver,.6)
local row=ui.rows[1];assert(row.navigationReserve==32 and row.navigationControl.width==24)
gold(row.navigationControl,.95)
retired();assert(visits==1)
local long=string.rep("Long giver ",20)
q.start.name=long
local measure=fixture.methods.GetStringHeight
fixture.methods.GetStringHeight=function(self)
    if self.text and self.text:find(long,1,true)then assert(self.width==ui.detail:GetWidth()-92);return 72 end
    return 18
end
render();location,turnin=text(long),text("Finish Two")
assert(pickup:GetHeight()>=137 and finish.point[3]<=pickup.point[3]-pickup:GetHeight()-8,"long source and zone text fit measured full rows without overlapping finisher")
fixture.methods.GetStringHeight=measure
q.start.name="Start One";q.start.mapID=nil;q.start.x=nil;q.start.y=nil
render();assert(pickup:IsShown()and not pickup.enabled and pickup.scripts.OnClick==nil and not giver.enabled);gold(row.navigationControl,.6)
assert(text(addon.L("SOURCE_POSITION_UNKNOWN")).detailStyle=="warning")
local tip={}
function tip:SetOwner(owner)self.owner=owner end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetText(value)self.title=value end
function tip:AddLine(value)self.body=value end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip;row.navigationControl.scripts.OnEnter();assert(tip.shown and tip.owner==row.navigationControl and tip.body==addon.L("SOURCE_POSITION_UNKNOWN"))
retired();assert(visits==1,"retained primary click is inert after source replacement")
for _,control in ipairs({giver,row.navigationControl})do
    for _,method in ipairs({"SetAlpha","SetDesaturated"})do
        for _,outerEnabled in ipairs({false,true})do
            local part=control.footerIconParts[1]
            local setter,armed=part[method],true
            part[method]=function(self,...)
                if armed then armed=false;ui:SetFooterEnabled(control,not outerEnabled)end
                return setter(self,...)
            end
            ui:SetFooterEnabled(control,outerEnabled);part[method]=setter
            assert(not armed and control.footerEnabled==not outerEnabled and control.footerPaintDepth==0 and not control.footerPaintRepair)
            gold(control,outerEnabled and .6 or .95)
        end
    end
end
q.start={itemID=801,name="Starter"};render()
for _,field in ipairs(ui.details)do assert(not field:IsShown()or field.text~=addon.L("DETAIL_START_ITEM"),"redundant starter caption is absent")end
assert(not giver:IsShown()and text(addon.L("ITEM_STARTER", "Starter")).navigationInset==0,"item starts retain one introduction without an NPC navigation inset")
q.start={npcID=1,name="Start One",mapID=1453};render()
assert(pickup:IsShown()and pickup.enabled and pickup.detailContactBinding.mapOnly and not giver:IsShown())
location=text("Start One");assert(location.width==ui.detail:GetWidth()-92 and pickup:GetWidth()==ui.detail:GetWidth()-8)
ui.quest=nil;ui:RefreshDetail();assert(not giver:IsShown()and not pickup:IsShown()and not finish:IsShown())
print("Inline gold giver checks passed (geometry and state modeled; native rendering unverified)")
