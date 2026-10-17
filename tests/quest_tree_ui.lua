local fixture=assert(loadfile("tests/client_ui.lua"))("fixture")
local addon=fixture.addon
function fixture.methods:SetTextColor(r,g,b)self.textColor={r,g,b}end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame,"ADDON_LOADED","DungeonPro")
SlashCmdList.DUNGEONPRO("")
local ui=addon.UI
local ids={71001,71002,71003,71004,71005}
for _,id in ipairs(ids)do addon.quests[id]={id=id,name="Tree quest "..id,minLevel=1,requirementsKnown=true,
    start={mapID=1455,x=25,y=35,name="Tree giver "..id}}end
addon.quests[71003].requires={{ids={71001}},{ids={71002}}}
addon.quests[71003].storyline={71001,71002,71003,71004}
addon.quests[71004].name=addon.quests[71003].name
C_QuestLog.IsQuestFlaggedCompleted=function(id)return id==71001 end
addon.CachedQuestRewards=function(id)
    if id==71003 then return {source="cache",items={{id=17001,name="Cached reward",count=1,texture=134400}},choices={}} end
end
local dungeon={key="tree-composition",name="Tree composition",minLevel=1,maxLevel=60,coverage="reviewed",quests={71003,71004,71005}}
addon.dungeons={dungeon};ui.dungeon=dungeon;ui.quest=nil;ui:Refresh()
local function row(id,branch)
    for _,value in ipairs(ui.rows)do
        if value:IsShown() and value.questID==id and (value.questTreeNode==true)==branch then return value end
    end
    error("Missing tree row "..id.." branch="..tostring(branch))
end
assert(not ui.map and not ui.guide)
local show=fixture.methods.Show
local expected={71003,71001,71002,71004,71005}
function fixture.methods:Show()
    for index,value in ipairs(ui.rows)do
        if value==self then
            assert(self.questID==expected[index] and not self.heading,"publish only the finished branch, without old rows or oversized headings")
            assert(self.title.text==addon.QuestName(self.questID),"published row already has its final quest title")
        end
    end
    return show(self)
end
row(71003,false).scripts.OnClick()
fixture.methods.Show=show
assert(ui.quest==71003 and ui.questTreeRoot==71003)
local target=row(71003,false)
assert(target.title:GetWidth()<=target:GetWidth()-22-26-20-18,"cached reward and status icons reserve real title space")
local reward
for _,object in ipairs(fixture.objects)do
    if object.shown and object.icon and object.icon.texture==134400 and object.point and object.point[2]==target then reward=object end
end
assert(reward,"actual TOC composition renders the cached reward beside the target title")
assert(target.dungeonTarget and target.dungeonBadge:IsShown(),"owning target is marked as a dungeon quest")
local otherTarget=row(71004,true)
assert(otherTarget.dungeonTarget and otherTarget.dungeonBadge:IsShown(),"every dungeon quest in the branch is marked")
local matches=0
for _,value in ipairs(ui.rows)do if value:IsShown() and value.questID==71004 then matches=matches+1 end end
assert(matches==1,"nested dungeon targets are not duplicated as independent cards")
assert(target.title.text==otherTarget.title.text,"distinct same-named quest IDs stay inspectable")
local completed=row(71001,true)
assert(not completed.dungeonTarget and (not completed.dungeonBadge or not completed.dungeonBadge:IsShown()),"supporting steps are not invented dungeon quests")
assert(completed.questTreeInset==24 and completed.point[2]==24 and completed:GetWidth()==target:GetWidth()-24,"child surface is inset with its right edge aligned")
assert(completed.treeRail:IsShown() and completed.treeElbow:IsShown(),"branch lines visibly connect steps to their owning quest")
for _,value in ipairs(ui.details)do if value:IsShown() then assert(value.text~=addon.L("STORY"),"bulky story caution is absent from the visible detail heading") end end
assert(completed.questTreeRelation=="required" and completed.questTreeDepth>0)
assert(completed.statusIcon and completed.statusIcon.texture=="Interface\\RaidFrame\\ReadyCheck-Ready" and completed.title.textColor[1]<.7,"completed history has a green check and dimmed title")
assert(completed.height<=40 and not completed.note:IsShown(),"ordinary title rows must be compact")
completed.scripts.OnClick()
assert(ui.quest==71001 and ui.questTreeRoot==71003 and ui.giverAction.id==71001)
row(71002,true).scripts.OnClick()
assert(ui.quest==71002 and ui.questTreeRoot==71003 and ui.giverAction.id==71002)
row(71003,false).scripts.OnClick()
assert(ui.quest==71003 and ui.questTreeRoot==71003,"returning to target preserves the opened chain")
local old=row(71002,true).scripts.OnClick
row(71005,false).scripts.OnClick()
assert(ui.quest==71005 and ui.questTreeRoot==71005)
old();assert(ui.quest==71005,"callbacks from the replaced branch must expire")
ui:Refresh(true)
assert(ui.quest==71005 and ui.questTreeRoot==71005,"language repaint preserves tree ownership")
local before=ui.quest
local hiddenClick=row(71003,false).scripts.OnClick
ui.frame:Hide();hiddenClick()
assert(ui.quest==before,"closed planner cannot act on a retained row callback")
ui.frame:Show()
print("Actual compact quest tree composition: PASS (target, completed parent, sibling, target, other root, stale click)")
