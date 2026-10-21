-- Actual Client context and registered quest events drive the overview; no Context/Planner mocks.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui, events = fixture.addon, fixture.addon.UI, fixture.eventFrame
if not addon.DungeonOverview then assert(loadfile("Core/DungeonOverview.lua"))("DungeonPro", addon) end
local nativeContext, nativePlanner, nativeNavigation = addon.Context, addon.Planner, addon.Navigation
local held, ready, completed, faction = {}, {}, {}, "Alliance"
issecretvalue = function() return false end
GetLocale = function() return "enUS" end
UnitLevel = function() return 60 end
UnitClass = function() return "Mage", "MAGE", 8 end
UnitRace = function() return "Human", "Human", 1 end
UnitFactionGroup = function() return faction end
C_QuestLog.IsOnQuest = function(id) return held[id] == true end
C_QuestLog.ReadyForTurnIn = function(id) return ready[id] == true end
C_QuestLog.IsQuestFlaggedCompleted = function(id) return completed[id] == true end
-- Only the registered event refresh is immediate; unrelated hydration retries are not manufactured.
C_Timer = { After = function(delay, callback) if delay == 0.1 then callback() end end }
GetItemCount = function() return 0 end
local routes, selections, accepts = 0, 0, 0
C_Map.SetUserWaypoint = function() routes = routes + 1; return true end
C_QuestLog.SetSelectedQuest = function() selections = selections + 1 end
SelectQuestLogEntry = function() selections = selections + 1 end
AcceptQuest = function() accepts = accepts + 1 end
CompleteQuest = function() accepts = accepts + 1 end
GetQuestReward = function() accepts = accepts + 1 end
events.scripts.OnEvent(events, "ADDON_LOADED", "DungeonPro")
ui:Toggle(); addon.db.locale = "enUS"
local dungeon
for _, value in ipairs(addon.dungeons) do if value.key == "dm" then dungeon = value end end
assert(dungeon)
local target, other, classQuest, support = addon.quests[166], addon.quests[214], addon.quests[1654], addon.quests[155]
local catalogue, group1, group2, classes, start, finish = dungeon.quests, target.requires, other.requires,
    classQuest.classes, classQuest.start, support.finish
ui.dungeon, ui.quest, ui.includeUnavailable, ui.range = dungeon, nil, false, false
ui:Refresh()
local ids={166,214,167,2040,168,92753,373}
local function draw(activeIDs,readyIDs)
 held,ready={},{}
 for _,id in ipairs(activeIDs)do held[id]=true end
 for _,id in ipairs(readyIDs)do held[id]=true;ready[id]=true end
 events.scripts.OnEvent(events,"QUEST_LOG_UPDATE")
 ui.dungeon,ui.quest,ui.includeUnavailable=dungeon,nil,false;ui:Refresh()
 local model,current,raw=addon.DungeonOverview.Get(ui.currentPlan,dungeon,ui.engine)
 local b={model=assert(model),current=current,rawProof=raw};assert(current()and raw());assert(model.unknown and not model.knownPrepared)
 assert(ui.overviewBinding==nil,"native quest events leave the default right panel compact")
 return b,b.model
end
local function order(model,expected)
 assert(#model.steps==#expected)
 for index,id in ipairs(expected)do assert(model.steps[index].id==id,"READY turn-ins must precede ACTIVE work before the six-step cap")end
end
local b,m=draw({166,214,167,2040,168,92753},{373})
assert(m.counts.READY==1 and m.counts.ACTIVE==6 and m.shownRoots==7 and #m.steps==6 and m.remainingSteps==1)
order(m,{373,166,214,167,2040,168})
local readyRow
for _,r in ipairs(ui.rows)do if r:IsShown()and r.questID==373 then readyRow=r end end
assert(readyRow and ui.engine:State(373).status=="READY"and m.steps[1].listedTarget==true)
assert(routes==0 and selections==0 and accepts==0)
readyRow.scripts.OnClick();assert(ui.quest==373 and ui.dungeon==dungeon and routes==0 and selections==0 and accepts==0)
assert(ui:BackQuest()and ui.quest==nil)
b,m=draw({166,167,2040,168,92753},{214,373});order(m,{214,373,166,167,2040,168})
assert(m.remainingSteps==1 and m.counts.READY==2 and m.counts.ACTIVE==5)
b,m=draw({},ids);order(m,{166,214,167,2040,168,92753});assert(m.remainingSteps==1 and m.counts.READY==7)
b,m=draw(ids,{});order(m,{166,214,167,2040,168,92753});assert(m.remainingSteps==1 and m.counts.ACTIVE==7)
b,m=draw({155},{373});order(m,{373,155})
assert(m.remainingSteps==0 and m.counts.READY==1 and m.counts.ACTIVE==0 and m.counts.UNKNOWN==6 and m.steps[2].listedTarget==false)
m.steps[1],m.steps[2]=m.steps[2],m.steps[1]
assert(not b.current()and not b.rawProof());assert(ui.quest==nil and routes==0)
assert(addon.Context==nativeContext and addon.Planner==nativePlanner and addon.Navigation==nativeNavigation)
assert(dungeon.quests==catalogue and #catalogue==9 and target.requires==group1 and other.requires==group2 and classQuest.classes==classes and classQuest.start==start and support.finish==finish)
print("Preparation priority: PASS (actual native-event READY373 and middle selection, stable mixed/all-ready/all-active order, shared155 counts, cap6, no automatic actions)")

-- Controlled eligibility fixture, not new catalogue facts: actionable pickup/level
-- work joins the overview subset after held READY/ACTIVE without changing counts.
local a={};assert(loadfile("Core/Namespace.lua"))("DungeonPro",a);assert(loadfile("Core/Planner.lua"))("DungeonPro",a);assert(loadfile("Core/DungeonOverview.lua"))("DungeonPro",a)
local q={};for id=1,4 do q[id]={id=id,minLevel=id==2 and 100 or 1,requirementsKnown=true}end
local ctx={level=60,class="MAGE",faction="Alliance",current=function()return true end,active=function(id)return id==3 or id==4 end,ready=function(id)return id==4 end,completed=function()return false end}
local d={quests={1,2,3,4},coverage="reviewed"};local e=a.Planner.New(q,ctx);local p=e:Dungeon(d,{includeUnavailable=true});p.engine,p.dungeon=e,d
local model,current,raw=a.DungeonOverview.Get(p,d,e)
assert(model and current()and raw()and model.counts.AVAILABLE==1 and model.counts.LOCKED==1 and model.counts.ACTIVE==1 and model.counts.READY==1)
order(model,{4,3,1,2});assert(model.remainingSteps==0 and not model.knownPrepared)
print("PASS controlled mixed AVAILABLE/LOCKED/ACTIVE/READY preserves counts and full actionable priority")
