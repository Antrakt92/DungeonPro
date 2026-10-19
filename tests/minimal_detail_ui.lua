-- Actual composition of the compact detail pane; native appearance remains human acceptance.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui = fixture.addon, fixture.addon.UI
UnitLevel = function() return 60 end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
ui:Toggle()
addon.db.locale = "enUS"
local dungeon
for _, value in ipairs(addon.dungeons) do
    for _, id in ipairs(value.quests) do if id == 4764 then dungeon = value end end
end
assert(dungeon)
local description = addon.Description
addon.Description = function() return "A short optional story." end
addon.ItemIcon = function() return 134400 end
addon.CarriedItemCount = function() return 0 end
local function render(id)
    ui.dungeon, ui.quest = dungeon, id or 4764
    ui:Refresh()
    if ui.detailTab ~= "quest" then assert(ui:SetDetailTab("quest")) end
end
local function lines()
    local result = {}
    for _, field in ipairs(ui.details) do if field:IsShown() then result[#result + 1] = field end end
    return result
end
local function find(text)
    for _, field in ipairs(lines()) do if field.text and field.text:find(text, 1, true) then return field end end
end
local function occurrences(text)
    local count = 0
    for _, field in ipairs(lines()) do if field.text and field.text:find(text, 1, true) then count = count + 1 end end
    return count
end
render()
assert(occurrences("Mayara Brightwing") == 1, "identical starter/turn-in location is printed once")
assert(find("Doomrigger's Clasp ×?") and not find(addon.L("OBJECTIVE_ITEM_UNKNOWN", "Doomrigger's Clasp")))
assert(find(addon.L("DETAIL_OBJECTIVES")) and not find(addon.L("OBJECTIVE_ITEMS_NOTICE")))
assert(not ui.referenceToggle or not ui.referenceToggle:IsShown(), "plain source facts do not produce a generic details drawer")
assert(not ui.storyToggle or not ui.storyToggle:IsShown())
for _, row in ipairs(ui.chainButtons) do assert(not row:IsShown(), "left hierarchy is not copied into details") end
local originalRepeatable=addon.quests[4764].repeatable
addon.quests[4764].repeatable=true
render()
local repeatableLine=find(addon.L("REPEATABLE"))
assert(repeatableLine and repeatableLine.detailStyle=="caption" and occurrences(addon.L("REPEATABLE"))==1,
    "repeatability remains visible as compact metadata without an acquisition drawer")
assert(not ui.referenceToggle or not ui.referenceToggle:IsShown())
local emptyQuest = addon.quests[4764]
local emptySaved = {startAlternatives=emptyQuest.startAlternatives,finishAlternatives=emptyQuest.finishAlternatives,
    completionQuests=emptyQuest.completionQuests,objectiveItemSources=emptyQuest.objectiveItemSources,
    reportedStart=emptyQuest.start.reportedLocations,reportedFinish=emptyQuest.finish.reportedLocations}
emptyQuest.startAlternatives,emptyQuest.finishAlternatives,emptyQuest.completionQuests,emptyQuest.objectiveItemSources={},{},{},{}
emptyQuest.start.reportedLocations,emptyQuest.finish.reportedLocations={},{}
render()
assert(not ui.referenceToggle or not ui.referenceToggle:IsShown(), "empty source arrays never create an empty acquisition drawer")
emptyQuest.startAlternatives,emptyQuest.finishAlternatives=emptySaved.startAlternatives,emptySaved.finishAlternatives
emptyQuest.completionQuests,emptyQuest.objectiveItemSources=emptySaved.completionQuests,emptySaved.objectiveItemSources
emptyQuest.start.reportedLocations,emptyQuest.finish.reportedLocations=emptySaved.reportedStart,emptySaved.reportedFinish
local objectStart=emptyQuest.start
emptyQuest.start={objectID=1234,name="Known quest object",mapID=1428,x=10,y=20}
render()
assert(not ui.referenceToggle or not ui.referenceToggle:IsShown(), "a basic object start already printed above is not additional acquisition content")
emptyQuest.start=objectStart
render()
local objective
for _, button in ipairs(ui.objectiveButtons) do if button:IsShown() then objective = button end end
assert(objective and objective.objectiveBinding.context:find(addon.L("OBJECTIVE_ITEMS_NOTICE"), 1, true))
assert(objective.objectiveBinding.context:find("quantity", 1, true), "unknown quantity is explained on hover")

local priorTooltip, objectiveTip = GameTooltip, {shows=0}
function objectiveTip:SetOwner(owner) self.owner=owner end
function objectiveTip:IsOwned(owner) return self.owner==owner end
function objectiveTip:SetItemByID(id) self.item=id;self.context=nil;return true end
function objectiveTip:AddLine(text) self.context=text end
function objectiveTip:Show() assert(self.context);self.shows=self.shows+1 end
function objectiveTip:Hide() self.owner=nil end
GameTooltip=objectiveTip
objective.scripts.OnEnter()
assert(objectiveTip.item==12352 and objectiveTip.context and objectiveTip.shows==1,
    "native objective item statistics append context and then reflow the tooltip")
objective.scripts.OnLeave()
local foreign={}
objectiveTip.AddLine=function(self,text) self.context=text;self.owner=foreign end
objective.scripts.OnEnter()
assert(objectiveTip.owner==foreign and objectiveTip.shows==1, "foreign takeover during context append is never shown or hidden")
GameTooltip=priorTooltip

local quest, finish = addon.quests[4764], addon.quests[4764].finish
local moved = {}; for key, value in pairs(finish) do moved[key] = value end
moved.mapID, moved.zoneName, moved.x, moved.y = 1453, "Stormwind City", 10, 20
quest.finish = moved
render()
assert(find(addon.L("DETAIL_TURNIN")) and occurrences("Mayara Brightwing") == 2,
    "the same NPC at a different location retains its distinct turn-in")
quest.finish = finish
local start, reported = quest.start, quest.start.reportedLocations
start.reportedLocations = { {mapID=1428,x=84.8,y=69}, {mapID=1428,x=85,y=70} }
render()
assert(ui.detailTabButtons.sources:IsShown(), "reported locations have an explicit Sources view")
local stale = ui.detailTabButtons.sources.scripts.OnClick
local kills,objects,events=quest.objectiveKills,quest.objectiveObjects,quest.objectiveEvents
quest.objectiveKills={{npcID=1234,name="Listed target"},{npcID=1235,name="Known target",quantity=2}}
quest.objectiveObjects={{objectID=4321,name="Listed object"}}
quest.objectiveEvents={{npcID=4532,name="Listed event"}}
render();stale=ui.detailTabButtons.sources.scripts.OnClick
assert(find("Listed target ×?") and find("Listed object ×?") and find("Listed event ×?") and find("Known target ×2"),
    "typed goals share a compact unknown marker without inventing or dropping known quantities")
assert(not find(addon.L("OBJECTIVE_KILLS_NOTICE")) and not find(addon.L("OBJECTIVE_OBJECTS_NOTICE")),
    "source expansion does not inject generic objective prose into the practical pane")
quest.objectiveKills,quest.objectiveObjects,quest.objectiveEvents=kills,objects,events
assert(occurrences(addon.L("REPEATABLE"))==1, "Quest keeps repeatability metadata exactly once")
assert(not find("A short optional story."), "optional prose does not crowd practical Quest information")
stale();assert(ui.detailTab=="sources" and not (ui.storyToggle and ui.storyToggle:IsShown()))
assert(not find("Listed target ×?"), "recorded practical goals remain on Quest instead of repeating inside Sources")
assert(occurrences("Mayara Brightwing") == 1 and ui.reportedToggles[1]:IsShown(), "expanded sources keep the primary giver once and expose reported points separately")
assert(ui:SetDetailTab("story"));assert(find("A short optional story."), "optional prose remains available in Story")
render(4765)
stale()
assert(ui.quest == 4765 and ui.detailTab=="quest", "saved Sources controls cannot change another quest's view")
start.reportedLocations = reported
quest.repeatable=originalRepeatable

local actualSourceAlternatives=addon.quests[8151].startAlternatives
local unmappedAlternatives={}
for index,point in ipairs(actualSourceAlternatives)do
    unmappedAlternatives[index]={npcID=point.npcID,name=point.name}
end
addon.quests[8151].startAlternatives=unmappedAlternatives
render(8151)
local function starterRows()
    local result={}
    for _,pool in ipairs({ui.giverButtons,ui.startButtons})do
        for _,row in ipairs(pool)do if row:IsShown()then result[#result+1]=row end end
    end
    return result
end
assert(#starterRows()==0 and ui.detailTab=="quest", "Quest leaves manual source choices to Sources")
assert(ui:SetDetailTab("sources"))
assert(#starterRows()==5, "the actual five starter alternatives are each shown once after expansion")
local names={}
for _,row in ipairs(starterRows())do
    assert(not names[row.title.text], "the default starter preview is not repeated inside acquisition details")
    names[row.title.text]=true
    assert(not row.enabled, "unmapped catalogue NPCs do not acquire invented visit locations")
end
local realAlternatives=addon.quests[8151].startAlternatives
addon.quests[8151].startAlternatives={realAlternatives[1],realAlternatives[2]}
render(4764);render(8151)
assert(#starterRows()==0 and ui.detailTab=="quest")
assert(ui:SetDetailTab("sources"))
assert(#starterRows()==2 and (not ui.referenceToggle or not ui.referenceToggle:IsShown()), "Sources shows both alternatives without a redundant drawer")
addon.quests[8151].startAlternatives=realAlternatives
local mapped={}
for index,point in ipairs(realAlternatives)do
    local copy={};for key,value in pairs(point)do copy[key]=value end
    copy.mapID,copy.x,copy.y=1428,index*10,index*5
    if index==3 then copy.reportedLocations={{mapID=1428,x=30,y=15},{mapID=1428,x=31,y=16}}end
    mapped[index]=copy
end
addon.quests[8151].startAlternatives=mapped
render(4764);render(8151)
assert(ui:SetDetailTab("sources"))
assert(#starterRows()==5)
local navigation,visits=addon.Navigation,{}
addon.Navigation={Start=function(action)visits[#visits+1]=action.place;return true end,Map=function(point)visits[#visits+1]=point;return true end}
for index,row in ipairs(starterRows())do assert(row.enabled);row.scripts.OnClick();assert(visits[index]==mapped[index])end
assert(ui.reportedToggles[1] and ui.reportedToggles[1]:IsShown(), "remaining starter alternatives retain reported-point disclosures")
local oldAlternative=ui.startButtons[1].scripts.OnClick
mapped[3]={npcID=999,name="Replacement",mapID=1428,x=1,y=2}
oldAlternative()
assert(#visits==5, "an older sliced alternative handler rejects changed source membership")
addon.quests[8151].startAlternatives,addon.Navigation=actualSourceAlternatives,navigation
render(4764)

local testID, rewards = 9904764, nil
addon.quests[testID] = { id=testID, name="Reward geometry", level=60, minLevel=1, requirementsKnown=true, start=start, finish=finish }
local cached = addon.CachedQuestRewards
addon.DialogueRewards = function() return nil end
addon.QuestRewards = function() return nil end
addon.CachedQuestRewards = function(id) return id == testID and rewards or nil end
rewards = {source="cache", items={}, choices={}, xp=1200, money=500}
for index=1,3 do rewards.items[index]={id=7100+index,name="Guaranteed "..index,texture=134400,count=index} end
for index=1,5 do rewards.choices[index]={id=8100+index,name="Choice "..index,texture=134401,count=1} end
render(testID)
assert(find(addon.L("DETAIL_GUARANTEED")) and find(addon.L("REWARD_CHOICES")))
local visible={}
for _, button in ipairs(ui.rewardButtons) do if button:IsShown() then visible[#visible+1]=button end end
assert(#visible==8, "all fixed rewards and every choice remain visible")
assert(visible[1].width==32 and visible[1].height==32)
assert(visible[1].point[3]==visible[2].point[3] and visible[1].point[2]<visible[2].point[2], "wide pane uses two loot columns")
assert(visible[3].point[3]<visible[1].point[3] and visible[4].point[3]<visible[3].point[3], "guaranteed and choice groups have separate rows")
assert(visible[1].rewardLabel.width<=visible[1].rewardTileWidth-40)
local tip={}
function tip:SetOwner(owner) self.owner=owner end
function tip:IsOwned(owner) return self.owner==owner end
function tip:SetItemByID(id) self.item=id;return true end
function tip:SetText() error("full native item tooltip must not be replaced by names") end
function tip:Hide() self.owner=nil end
GameTooltip=tip
visible[4].scripts.OnEnter()
assert(tip.item==8101 and tip.owner==visible[4], "reward hover presents native item statistics")
visible[4].scripts.OnLeave();assert(tip.owner==nil)
local width=ui.detail.width
ui.detail:SetWidth(300);ui:RefreshDetail()
local first,second=ui.rewardButtons[1],ui.rewardButtons[2]
assert(first.point[2]==second.point[2] and second.point[3]<first.point[3], "narrow pane falls back to one column")
ui.detail:SetWidth(width)
render(4764)
for _,button in ipairs(ui.rewardButtons) do assert(not button:IsShown(), "another quest retires all reward tiles") end
local parentA, parentB = testID+1, testID+2
addon.quests[parentA]={id=parentA,name="Alternative A",requirementsKnown=true,minLevel=1}
addon.quests[parentB]={id=parentB,name="Alternative B",requirementsKnown=true,minLevel=1,factions={"Horde"}}
addon.quests[testID].requires={{ids={parentA,parentB}}}
local branchDungeon={key="minimal-or",name="OR alternatives",quests={testID}}
ui.dungeon,ui.quest,ui.questTreeDungeon,ui.questTreeRoot=branchDungeon,testID,branchDungeon,testID
ui:RefreshQuests()
local function choiceRow(id)
    for _,row in ipairs(ui.rows)do if row:IsShown() and row.questID==id and row.questTreeNode then return row end end
end
local available,unavailable=choiceRow(parentA),choiceRow(parentB)
assert(available and unavailable and available.branchControl:IsShown() and unavailable.branchControl.enabled==false)
assert(available.branchReserve==22 and available.branchControl.branchChild==testID)
function tip:SetText(text) self.title=text end
function tip:AddLine(text) self.note=text end
function tip:Show() end
available.branchControl.scripts.OnEnter()
assert(tip.note:find(addon.L("BRANCH_PREFER"),1,true) and not tip.note:find(addon.L("BRANCH_SELECTED",available.title.text),1,true),
    "an unselected alternative describes the action without claiming it is selected")
local oldChoice=available.branchControl.scripts.OnClick
oldChoice()
assert(addon.char.choices[testID][1]==parentA and choiceRow(parentA).branchControl.branchSelected)
choiceRow(parentA).branchControl.scripts.OnEnter()
assert(tip.note:find(addon.L("BRANCH_RESET"),1,true), "the chosen route explains its reset action")
choiceRow(parentA).branchControl.scripts.OnClick()
assert(addon.char.choices[testID][1]==nil, "clicking the chosen left alternative restores automatic planning")
oldChoice()
assert(addon.char.choices[testID][1]==nil, "retained preference controls cannot change a newer tree")
local parentC=testID+3
addon.quests[parentC]={id=parentC,name="Optional story route",requirementsKnown=true,minLevel=1}
addon.quests[testID].requires=nil
addon.quests[testID].storyline={testID,parentA}
addon.quests[parentA].requires={{ids={parentB,parentC}}}
ui:RefreshQuests()
local scoped=choiceRow(parentC)
assert(scoped and scoped.questTreePath==false and scoped.note.text:find(addon.QuestName(parentA),1,true),
    "a story member's prerequisite identifies its actual dependent in the tooltip without becoming the target path")
assert(scoped.branchControl and scoped.branchControl.enabled)
local rootState=ui.engine:State(testID).status
scoped.branchControl.scripts.OnClick()
assert(addon.char.choices[parentA][1]==parentC and ui.engine:State(testID).status==rootState,
    "story-scoped OR preference belongs to its dependent quest and never changes root readiness")
local nameGetter,parentReads,replaced=addon.QuestName,0,false
addon.QuestName=function(id,...)
    if id==parentA then
        parentReads=parentReads+1
        if parentReads==2 then
            replaced=true
            ui.dungeon,ui.quest,ui.questTreeRoot,ui.questTreeDungeon=dungeon,4764,nil,nil
            ui:RefreshQuests()
        end
    end
    return nameGetter(id,...)
end
ui:RefreshQuests()
addon.QuestName=nameGetter
assert(replaced and ui.quest==4764 and ui.dungeon==dungeon,
    "a dependent-name getter may publish a newer selection during tooltip construction")
for _,row in ipairs(ui.rows)do
    if row:IsShown() and row.questID then assert(row.questID~=testID and row.questID~=parentA and row.questID~=parentB and row.questID~=parentC,
        "old story-scope annotation never restores obsolete rows over the newer view")end
end
addon.quests[parentC],addon.char.choices[parentA]=nil,nil
addon.quests[parentA],addon.quests[parentB],addon.char.choices[testID]=nil,nil,nil
addon.quests[testID], addon.Description, addon.CachedQuestRewards = nil, description, cached
print("Minimal quest detail: PASS (actual4764, source disclosure, moving giver, objective context, complete loot grid and native tooltips)")
