-- Single-stream source focus and reading transactions use the actual selected quest.
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return"enUS"end
function f.methods:GetVerticalScroll()return self.verticalScroll or 0 end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true
local owners={};for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=d end end
local token={};a.Context=function()local own=token;return{level=60,faction="Alliance",class="MAGE",race=3,current=function()return token==own end,completed=function()return false end,active=function()return false end}end
local routes=0;a.Navigation={Start=function()routes=routes+1;return true end,Map=function()routes=routes+1;return true end}
a.ItemName=function(id)return"Item "..id end;a.ItemIcon=function()return 134400 end;a.CarriedItemCount=function()return 0 end
local scroll=u.detailScroll;function scroll:GetHeight()return 90 end
local function show(id,d)
 token={};u.dungeon,u.quest=assert(d or owners[id]),id;u.questTreeRoot,u.questTreeDungeon=nil,nil;u:Refresh()
 assert(u.quest==id and u.renderedQuest==id and u.detailTab=="quest")
end
local function offset()return scroll:GetVerticalScroll()end
show(92458);local dungeon=u.dungeon;local history=u.detailHistory;local count=#history
scroll:SetVerticalScroll(41);assert(u:InspectQuest(92458,true,true))
assert(u.quest==92458 and u.dungeon==dungeon and u.detailHistory==history and #history==count and offset()==0,"same-quest source focus uses bounded top fallback without history or selection change")
scroll:SetVerticalScroll(37);assert(u:InspectQuest(92459,true));assert(u:BackQuest())
assert(u.quest==92458 and u.detailHistory==history and #history==count and offset()==37,"Back restores exact selected Dalaran stream reading")
show(2204,owners[2201]or owners[166]);history=u.detailHistory;count=#history
scroll:SetVerticalScroll(17);assert(u:InspectQuest(2204,true,true))
local text=a.L("SOURCE_SUMMON_ITEM","Item 7667",a.quests[2204].start.name);local anchor
for _,line in ipairs(u.details)do if line:IsShown()and line.text==text then anchor=-line.point[3]end end
assert(anchor and anchor>0,"actual own summon instruction supplies nonzero source anchor")
local expected=math.min(anchor,math.max(0,u.detail:GetHeight()-90))
assert(offset()==expected and #history==count and u.quest==2204,"source focus scrolls to its actual acquisition instruction")
local before=offset();assert(u:SetDetailTab("sources")and u:SetDetailTab("story")and offset()==before and u.detailTab=="quest","compatibility aliases leave stream reading unchanged")
-- Source-focus native scroll completion must preserve a newer selected quest.
local native=scroll.SetVerticalScroll;local fired=false
scroll.SetVerticalScroll=function(self,value)
 if not fired then fired=true;assert(u:InspectQuest(92458,true));assert(u:WriteDetailScroll(self,23,function()return u.quest==92458 end))end
 return native(self,value)
end
u:InspectQuest(2204,true,true);scroll.SetVerticalScroll=native
assert(fired and u.quest==92458 and u.renderedQuest==92458 and offset()==23,"late source-focus scroll cannot overwrite newer selected reading")
assert(routes==0,"inspection and reading never navigate or use an item")
print("PASS actual single-stream source anchor, missing anchor, Dalaran history and newer native scroll ownership")

show(92458);scroll:SetVerticalScroll(900000);assert(u:InspectQuest(92459,true));assert(u:BackQuest())
assert(u.quest==92458 and offset()==math.max(0,u.detail:GetHeight()-90),"actual Back clamps current stream dimensions")
show(92458);scroll:SetVerticalScroll(29);assert(u:InspectQuest(92459,true));scroll:SetVerticalScroll(31)
local history=u.detailHistory;local count=#history;local saved=u:HistoryOffsets()[count]
local refresh=u.RefreshQuests;local fired=false
u.RefreshQuests=function(self,...)local result=refresh(self,...);if not fired then fired=true;self.includeUnavailable=not self.includeUnavailable end;return result end
assert(u:BackQuest());u.RefreshQuests=refresh
assert(fired and u.quest==92459 and u.renderedQuest==92459 and offset()==31 and #history==count and u:HistoryOffsets()[count]==saved,"actual filter-drift Back restores reading and history transaction")
local getter=scroll.GetVerticalScroll;fired=false
scroll.GetVerticalScroll=function(self)
 if not fired then fired=true;assert(u:InspectQuest(92458,true));assert(u:WriteDetailScroll(self,19,function()return u.quest==92458 end))end
 return getter(self)
end
local accepted=u:InspectQuest(2204,true,true);scroll.GetVerticalScroll=getter
assert(fired and not accepted and u.quest==92458 and u.renderedQuest==92458 and offset()==19,"stale Inspect cannot overwrite newer scroll-getter inspection")
-- Start a separate hide/reopen scenario after replacing temporary native helpers.
u:Refresh();local retainedHistory=u.detailHistory;local old=u.detailNavigationRevision
u.frame:Hide();u.frame.scripts.OnHide(u.frame)
assert(u.detailHistory==retainedHistory and u.detailOffsets==nil and u.detailNavigationRevision~=old,"hide clears ephemeral reading")
u.frame:Show();u.frame.scripts.OnShow(u.frame);assert(u.quest==92458 and u.renderedQuest==92458 and offset()==0,"reopen starts selected stream at top")
assert(routes==0)
