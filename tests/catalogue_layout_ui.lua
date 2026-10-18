-- Catalogue collapse reclaims chain space while retaining the existing detail context.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return"enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle();a.db.locale="enUS";ui.includeUnavailable=true
local d;for _,v in ipairs(a.dungeons)do if v.key=="dm"then d=v end end
ui.dungeon,ui.quest=d,166;ui:Refresh()
local toggle=ui.catalogToggle
assert(toggle and toggle:IsShown()and toggle.scripts.OnClick,"dungeon catalogue needs a reachable collapse control")
assert(toggle:GetWidth()==24 and toggle:GetHeight()==24)
local function layout(collapsed)
 assert(ui.catalogCollapsed==collapsed)
 assert(ui.questScroll.point[2]==(collapsed and 54 or 278))
 assert(ui.questScroll:GetWidth()==(collapsed and 594 or 370))
 assert(ui.questList:GetWidth()==ui.questScroll:GetWidth()-4)
 assert(ui.heading.point[2]==(collapsed and 54 or 278)and ui.heading.width==(collapsed and 450 or 226))
 assert(ui.detailScroll.point[2]==674 and ui.detailScroll:GetWidth()==400 and ui.detail:GetWidth()==396)
 assert(ui.questEntrance.point[2]==510 and ui.characterButton.point[2]==548)
 assert(ui.catalogScroll:IsShown()==not collapsed)
 assert(toggle.point[2]==(collapsed and 12 or 250)and toggle:IsShown())
 assert(toggle:GetText()==""and toggle.label and toggle.label.text==(collapsed and "›"or"‹"),"the compact catalogue control points toward its next action")
end
layout(false)
local root=d;local tree=ui.questTreeRoot;local history=ui.detailHistory
local range,all,preparation=ui.range,ui.includeUnavailable,ui.preparation
ui.detailScroll:SetVerticalScroll(12);ui.questScroll:SetVerticalScroll(24)
local provider=a.DungeonStatus.Get;local scans=0
a.DungeonStatus.Get=function(...)scans=scans+1;return provider(...)end
-- Publish a fresh catalogue with this stable provider before measuring warm layout work.
ui:Refresh();scans=0
local scroll=ui.detailScroll.verticalScroll;local listScroll=ui.questScroll.verticalScroll
toggle.scripts.OnClick(toggle);layout(true)
assert(ui.dungeon==root and ui.quest==166 and ui.questTreeRoot==tree and ui.detailHistory==history)
assert(ui.range==range and ui.includeUnavailable==all and ui.preparation==preparation)
assert(ui.detailScroll.verticalScroll==scroll and ui.questScroll.verticalScroll==listScroll)
assert(scans==0,"layout must reuse catalogue status evidence instead of rescanning all dungeons")
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","itIT","koKR","zhCN","zhTW"})do
 a.db.locale=locale;ui:RefreshLanguagePreview();layout(true)
 assert(ui.quest==166 and ui.dungeon==d)
end
a.db.locale="enUS"
toggle.scripts.OnClick(toggle);layout(false)
assert(ui.quest==166 and ui.detailHistory==history)
ui:SetCatalogCollapsed(true);layout(true)
ui.search="1654";ui:QueueSearch();ui:FlushPendingSearch();layout(false)
assert(ui.search=="1654"and ui.quest==166 and ui.dungeon==d,"search reveals its results without choosing a different quest")
local found=false;for _,card in ipairs(ui.cards)do if card:IsShown()and card.matchQuestID==1654 then found=true end end
assert(found,"expanded catalogue exposes the actual numeric search result")
ui.search="";ui.preparation=true;ui:Refresh(nil,true)
ui:SetCatalogCollapsed(true);layout(true)
assert(ui.preparation==true,"layout does not silently switch an existing preparation context")
ui.preparation=false;ui.quest=nil;ui.dungeon=nil;ui:Refresh(nil,true)
assert(toggle:IsShown(),"the rail can be restored even without a selected dungeon or quest")
toggle.scripts.OnClick(toggle);layout(false)
a.DungeonStatus.Get=provider
print("Catalogue layout: PASS (default geometry, reclaimed chain width, preserved reading/context,10 locales and visible search)")
