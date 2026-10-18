-- A sourced continuation is inspected through the existing dungeon quest tree.
local fixture=assert(loadfile("tests/client_ui.lua"))("fixture")
local addon,ui,event=fixture.addon,fixture.addon.UI,fixture.eventFrame
GetLocale=function()return "enUS"end
UnitFactionGroup=function()return "Horde"end
UnitLevel=function()return 20 end
C_Timer={After=function(delay,callback)if delay<1 then callback()end end}
local held,ready=false,false
C_QuestLog.IsOnQuest=function(id)return held and id==5729 end
C_QuestLog.ReadyForTurnIn=function(id)return ready and id==5729 end
C_QuestLog.IsQuestFlaggedCompleted=function()return false end
local visits={}
addon.Navigation={Start=function(action)visits[#visits+1]=action;return true end}
event.scripts.OnEvent(event,"ADDON_LOADED","DungeonPro")
ui:Toggle();addon.db.locale="enUS";ui.range=false;ui.includeUnavailable=true;ui.search="";ui:Refresh()
local dungeon=assert(addon.dungeons[1]);assert(dungeon.key=="rfc")
local roots={};for i,id in ipairs(dungeon.quests)do roots[i]=id;assert(id~=5729 and id~=5730)end
local source=addon.quests[5728]
local requires,known=source.requires,source.requirementsKnown
assert(known==false and requires[1].ids[1]==5727)
local function row(id,branch)
    for _,value in ipairs(ui.rows)do
        if value:IsShown()and value.questID==id and(value.questTreeNode==true)==branch then return value end
    end
    error("Missing Hidden Enemies row "..id.." branch="..tostring(branch))
end
assert(ui.cards[1]:IsShown());ui.cards[1].scripts.OnClick()
assert(ui.dungeon==dungeon)
local initial=ui.engine:Dungeon(dungeon,{includeUnavailable=true})
local rootState=ui.engine:State(5728).status
local originalStatus={};for _,id in ipairs({5726,5727,5728,5729,5730})do originalStatus[id]=ui.engine:State(id).status end
row(5728,false).scripts.OnClick()
assert(ui.quest==5728 and ui.questTreeRoot==5728 and ui.questTreeDungeon==dungeon)
local tree=assert(addon.QuestTree.Build(addon.quests,ui.engine,5728))
local presented={};for _,node in ipairs(tree.presentation)do presented[node.id]=node end
local previous=0
for _,id in ipairs({5726,5727,5728,5729,5730})do
    local node=row(id,true);local index
    for i,value in ipairs(ui.rows)do if value==node then index=i end end
    assert(index>previous,"visible chain preserves source chronology");previous=index
    if id==5729 or id==5730 then
        assert(presented[id].presentationRelation=="story"and not node.questTreePath,
            "later continuations stay optional presentation rather than required target work")
        assert(not node.dungeonTarget and(not node.dungeonBadge or not node.dungeonBadge:IsShown()),
            "a continuation is not an extra dungeon target")
    end
end
local after=ui.engine:Dungeon(dungeon,{includeUnavailable=true})
assert(#after.rows==#initial.rows and #after.rows==#roots)
for status,count in pairs(initial.counts)do assert(after.counts[status]==count)end
for _,id in ipairs({5726,5727,5728,5729,5730})do assert(ui.engine:State(id).status==originalStatus[id])end
assert(ui.engine:State(5728).status==rootState)
for i,id in ipairs(roots)do assert(dungeon.quests[i]==id)end
assert(#dungeon.quests==#roots and source.requires==requires and source.requirementsKnown==known)

row(5729,true).scripts.OnClick()
assert(ui.quest==5729 and ui.renderedQuest==5729 and ui.questTreeRoot==5728 and ui.dungeon==dungeon)
row(5730,true).scripts.OnClick()
assert(ui.quest==5730 and ui.renderedQuest==5730 and ui.questTreeRoot==5728)
row(5729,true).scripts.OnClick()
held,ready=true,true
event.scripts.OnEvent(event,"QUEST_LOG_UPDATE")
assert(ui.quest==5729 and ui.renderedQuest==5729 and ui.questTreeRoot==5728)
local finish=assert(addon.quests[5729].finish)
assert(finish.npcID==3216 and finish.name=="Neeru Fireblade")
assert(ui.action and ui.action.id==5729 and ui.action.kind=="turnin"and ui.action.place==finish)
assert(ui:DispatchDetail(ui.action,false))
assert(#visits==1 and visits[1].id==5729 and visits[1].place==finish,
    "clicked continuation dispatches to its own corrected finisher")
assert(source.requires==requires and source.requirementsKnown==false and #dungeon.quests==#roots)
print("Hidden Enemies storyline UI: PASS (actual row expansion, optional continuations, own finisher, unchanged roots/readiness)")
