local fixture=assert(loadfile("tests/client_ui.lua"))("fixture")
local addon=fixture.addon
function fixture.methods:SetTextColor(r,g,b)self.textColor={r,g,b}end
function fixture.methods:SetAtlas(value)self.atlas=value end
function fixture.methods:GetAtlas()return self.atlas end
C_Texture={GetAtlasInfo=function()return {}end}
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame,"ADDON_LOADED","DungeonPro")
SlashCmdList.DUNGEONPRO("")
local ui=addon.UI
addon.Description=function(id)return "Selected quest description "..id end
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
for _,value in ipairs(ui.details)do if value:IsShown() then
    assert(value.text~=addon.L("PARTIAL") and value.text~=addon.L("OVERVIEW_REVIEWED"),"overview does not repeat the removed coverage banner")
end end
assert(not ui.map and not ui.guide)
assert(ui.summary==nil and ui.coverage==nil,"aggregate status and coverage labels must not occupy the workspace")
assert(ui.questScroll.point[3]>-200 and ui.detailScroll.point[3]==-66 and ui.detailScroll:GetHeight()==622,"detail title reclaims its action band independently of the quest list")
local show=fixture.methods.Show
local expected={0,71001,71002,71003,71004,71005}
function fixture.methods:Show()
    for index,value in ipairs(ui.rows)do
        if value==self then
            assert(not self.heading,"publish only the finished branch, without old rows or oversized headings")
            if expected[index]==0 then
                assert(self.questTreeAnchor and self.questID==nil and self.anchorQuestID==71003,"expanded header is a separate nonquest anchor")
            else
                assert(self.questID==expected[index])
                local title=addon.QuestName(self.questID)
                if self.questID==71003 or self.questID==71004 then title=title.." #"..self.questID end
                assert(self.title.text==title,"published row already has its final disambiguated quest title")
            end
        end
    end
    return show(self)
end
row(71003,false).scripts.OnClick()
fixture.methods.Show=show
assert(ui.quest==71003 and ui.questTreeRoot==71003)
local anchor=ui.rows[1]
local target=row(71003,true)
assert(not ui.storyToggle or not ui.storyToggle:IsShown(),"the default right pane does not repeat the left quest tree")
local description,giverLines,rewardLine=nil,0,false
for _,value in ipairs(ui.details)do if value:IsShown() then
    if value.text=="Selected quest description 71003" then description=value end
    local plain=value.text and value.text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
    assert(plain~=addon.L("LOCKED") and plain~=addon.L("UNKNOWN"),"default details use a concrete reason instead of generic preparation labels")
    if value.text and value.text:find("Tree giver 71003",1,true)then giverLines=giverLines+1 end
    if value.text and value.text:find("Cached reward",1,true)then rewardLine=true end
end end
assert(description and giverLines==1 and rewardLine,"default details keep the actual selected description giver and rewards without duplicated references")
assert(not ui.referenceToggle or not ui.referenceToggle:IsShown(),"NPC-only facts do not invent an empty acquisition disclosure")
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
assert(target.title.text~=otherTarget.title.text and target.title.text:find("#71003",1,true) and otherTarget.title.text:find("#71004",1,true),"same-named quest IDs have visible disambiguation")
local completed=row(71001,true)
assert(not completed.dungeonTarget and (not completed.dungeonBadge or not completed.dungeonBadge:IsShown()),"supporting steps are not invented dungeon quests")
assert(completed.questTreeInset==24 and completed.point[2]==24 and completed:GetWidth()==target:GetWidth() and completed:GetWidth()==anchor:GetWidth()-24,"chronological quest surfaces share an aligned right edge beneath the anchor")
assert(completed.treeRail:IsShown() and completed.treeElbow:IsShown(),"branch lines visibly connect steps to their owning quest")
for _,value in ipairs(ui.details)do if value:IsShown() then assert(value.text~=addon.L("STORY"),"bulky story caution is absent from the visible detail heading") end end
assert(completed.questTreeRelation=="required" and completed.questTreeDepth>0)
assert(completed.statusIcon and completed.statusIcon.texture=="Interface\\RaidFrame\\ReadyCheck-Ready" and completed.title.textColor[1]<.7,"completed history has a green check and dimmed title")
assert(completed.height<=40 and not completed.note:IsShown(),"ordinary title rows must be compact")
completed.scripts.OnClick()
assert(ui.quest==71001 and ui.questTreeRoot==71003 and ui.giverAction.id==71001)
row(71002,true).scripts.OnClick()
assert(ui.quest==71002 and ui.questTreeRoot==71003 and ui.giverAction.id==71002)
row(71003,true).scripts.OnClick()
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
C_QuestLog.IsOnQuest=function(id)return id==71002 end
ui:Refresh()
row(71003,false).scripts.OnClick()
assert(row(71002,true).statusIcon.atlas=="Quest-In-Progress-Icon-yellow","a quest in the journal has its row progress icon")
C_QuestLog.ReadyForTurnIn=function(id)return id==71002 end
ui:Refresh()
assert(row(71002,true).statusIcon.atlas=="UI-QuestIcon-TurnIn-Normal","ready-to-turn-in status is visible on its own row")
print("Actual compact quest tree composition: PASS (target, completed parent, sibling, target, other root, stale click)")
