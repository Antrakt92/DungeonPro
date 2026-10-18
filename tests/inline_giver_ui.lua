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
    error("missing field "..part)
end
render()
local giver=ui.giver
assert(giver.width==24 and giver.height==24 and not giver.caption,"compact giver navigation has no full-width button or duplicate label")
local location,turnin=text("Start One"),text("Finish Two")
assert(location.point[2]==36 and location.width==ui.detail:GetWidth()-40,"location reserves icon width before wrapping")
assert(giver.point[4]==4 and giver.point[5]==location.point[3],"giver icon shares first location line")
assert(-turnin.point[3]-(-location.point[3])==36,"turn-in follows the location without a separate action band")
local function gold(control,alpha)
    assert(control.navigationGold and #control.footerIconParts==3)
    for _,part in ipairs(control.footerIconParts)do
        assert(part.texture=="Interface\\Buttons\\WHITE8X8"and part.vertex[1]==1 and part.vertex[2]==.78 and part.vertex[3]==.15)
        assert(part.alpha==alpha and not part.desaturated,"all solid arrow strokes remain readable gold")
    end
end
gold(giver,.95)
local row=ui.rows[1];assert(row.navigationReserve==32 and row.navigationControl.width==24)
gold(row.navigationControl,.95)
giver.scripts.OnClick();assert(visits==1)
local long=string.rep("Long giver ",20)
q.start.name=long
local measure=fixture.methods.GetStringHeight
fixture.methods.GetStringHeight=function(self)
    if self.text and self.text:find(long,1,true)then assert(self.width==ui.detail:GetWidth()-40);return 72 end
    return 18
end
render();location,turnin=text(long),text("Finish Two")
assert(giver.point[5]==location.point[3]and -turnin.point[3]>=-location.point[3]+72+12,"long names wrap without centring the icon inside the whole paragraph")
fixture.methods.GetStringHeight=measure
q.start.name="Start One";q.start.mapID=nil;q.start.x=nil;q.start.y=nil
render();assert(not giver.enabled);gold(giver,.6)
assert(text(addon.L("GIVER_LOCATION_UNKNOWN")).detailStyle=="warning")
local tip={}
function tip:SetOwner(owner)self.owner=owner end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetText(value)self.title=value end
function tip:AddLine(value)self.body=value end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip;giver.scripts.OnEnter();assert(tip.shown and tip.body==addon.L("GIVER_LOCATION_UNKNOWN"))
giver.scripts.OnClick();assert(visits==1)
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
assert(giver:IsShown()and giver.enabled and giver.footerLabelKey=="GIVER_MAP")
location=text("Start One");assert(location.navigationInset==32 and location.width==ui.detail:GetWidth()-40)
ui.quest=nil;ui:RefreshDetail();assert(not giver:IsShown())
print("Inline gold giver checks passed (geometry and state modeled; native rendering unverified)")
