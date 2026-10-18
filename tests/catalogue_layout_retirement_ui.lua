-- A later catalogue layout or selected card owns late native geometry writes.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
issecretvalue=function()return false end
C_Timer={After=function()end}
GetLocale=function()return"enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();a.db.locale="enUS";ui.includeUnavailable=true
assert(type(ui.SetCatalogCollapsed)=="function","catalogue collapse needs one current layout entry point")
local owners={};for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=d end end
a.Context=function()return{level=60,class="MAGE",faction="Alliance",race=3,
 completed=function()return false end,active=function(id)return id==141 end,ready=function(id)return id==141 end}end
local routes=0
a.Navigation={Start=function()routes=routes+1 end,Map=function()routes=routes+1 end}
local tip={shown=false}
function tip:SetOwner(owner)self.owner=owner end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetText(text)self.text=text end
function tip:AddLine(text)self.line=text end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip
local function render(id)
 ui.dungeon,ui.quest=assert(owners[id]),id;ui.questTreeRoot,ui.questTreeDungeon=nil,nil;ui:Refresh(nil,true)
 assert(ui.quest==id and ui.renderedQuest==id)
end
local function geometry(collapsed)
 assert(ui.catalogCollapsed==collapsed)
 assert(ui.questScroll:GetWidth()==(collapsed and 594 or 370)and ui.questList:GetWidth()==(collapsed and 590 or 366),
 "late old width cannot overwrite the newest catalogue layout")
 local _,x=ui.questScroll:GetPoint();assert(x==(collapsed and 54 or 278),"latest quest rail anchor survives")
 local _,dx=ui.detailScroll:GetPoint();assert(dx==674 and ui.detailScroll:GetWidth()==400,"detail column remains fixed")
 assert(ui.catalogScroll:IsShown()==not collapsed,"a retired refresh cannot reopen the hidden catalogue")
end
render(166);ui:SetCatalogCollapsed(false)
local width=f.methods.SetWidth
local fired=false
ui.questScroll.SetWidth=function(self,value)
 if value==594 and not fired then fired=true;ui:SetCatalogCollapsed(false)end
 return width(self,value)
end
ui:SetCatalogCollapsed(true)
ui.questScroll.SetWidth=width
assert(fired,"native width callback must actually switch back to expanded")
geometry(false);assert(ui.quest==166 and ui.renderedQuest==166 and routes==0)

-- The header is another native boundary after the width mutation.
local point=f.methods.SetPoint
fired=false
ui.heading.SetPoint=function(self,...)
 local args={...}
 if args[1]=="TOPLEFT"and args[2]==54 and not fired then fired=true;ui:SetCatalogCollapsed(false)end
 return point(self,...)
end
ui:SetCatalogCollapsed(true)
ui.heading.SetPoint=point
assert(fired,"native heading anchor callback must execute the newer expansion")
geometry(false)
local _,hx=ui.heading:GetPoint();assert(hx==278,"late heading anchor is repaired to the newest expansion")

-- A selected-card change during geometry must not repaint the previous card.
fired=false
ui.questScroll.SetWidth=function(self,value)
 if value==594 and not fired then fired=true;ui:InspectQuest(92753,true)end
 return width(self,value)
end
ui:SetCatalogCollapsed(true)
ui.questScroll.SetWidth=width
assert(fired and ui.quest==92753 and ui.renderedQuest==92753)
geometry(true)
assert(not ui.ancestorActionButton or not ui.ancestorActionButton:IsShown()or not ui.ancestorActionButton.enabled,
 "a late layout tail cannot restore the previous card's ancestor action")

-- Previously active catalogue handlers cannot operate through a hidden parent.
ui:SetCatalogCollapsed(false);render(166)
local row=assert(ui.cards[1]);local click=assert(row.scripts.OnClick)
local entrance=assert(row.entranceControl);local enter=assert(entrance.scripts.OnEnter)
enter(entrance)
assert(tip.shown,"the actual catalogue entrance hint must be active before collapse")
ui:SetCatalogCollapsed(true)
local dungeon=ui.dungeon
click(row);enter(entrance)
assert(ui.quest==166 and ui.dungeon==dungeon and routes==0 and not tip.shown,
 "hidden catalogue handlers cannot select, route or resurrect a tooltip")
geometry(true)
ui:SetCatalogCollapsed(false);geometry(false)
assert(ui.catalogToggle and ui.catalogToggle:IsShown()and ui.catalogToggle.scripts.OnClick)
ui.catalogToggle.scripts.OnClick();geometry(true)
print("Catalogue layout retirement: PASS (fired width/anchor reentry, newer selection and hidden rail input retirement)")
