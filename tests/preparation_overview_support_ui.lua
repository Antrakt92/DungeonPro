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
local function summary()
 local b=assert(ui.overviewBinding);assert(b.current()and b.rawProof());return b,b.model
end
local function row(id)
 local found;for _,r in ipairs(ui.actionInspectButtons)do if r:IsShown()and r.questID==id then assert(not found);found=r end end;return assert(found)
end
local function event(name,id)events.scripts.OnEvent(events,name,id)end
held[155],ready[155]=true,true;event("QUEST_ACCEPTED",155)
local binding,model=summary();local r=row(155)
assert(model.counts.READY==0 and model.counts.UNKNOWN==7 and #model.steps==1)
assert(r.note.text:find("Supporting quest",1,true),"a visible support cue must explain the READY step beside zero READY primary targets")
assert(model.steps[1].listedTarget==false,"a held support step must be identified separately from listed primary targets")
local function note(status,supporting)
 return (supporting and addon.L("OVERVIEW_SUPPORTING_QUEST").." · "or "")..addon.L(status).." · "..addon.L("BRANCH_INSPECT")
end
assert(r.note.text==note("READY",true)and routes==0 and selections==0 and accepts==0)
for _,all in ipairs({true,false})do
 ui.includeUnavailable=all;ui:Refresh();local _,m=summary()
 assert(m.steps[1].listedTarget==false and m.counts.READY==0 and row(155).note.text==note("READY",true))
end
binding,model=summary();local oldClick=row(155).scripts.OnClick
model.steps[1].listedTarget=true
assert(not binding.rawProof()and not binding.current());oldClick();assert(ui.quest==nil and routes==0)
ui:Refresh();summary()
held[155],ready[155]=false,false;held[1654],ready[1654]=true,true;event("QUEST_ACCEPTED",1654)
binding,model=summary();assert(model.counts.READY==1 and #model.steps==1 and model.steps[1].listedTarget==true)
assert(row(1654).note.text==note("READY",false))
local primaryClick=row(1654).scripts.OnClick
model.steps[1].listedTarget=nil
assert(not binding.rawProof()and not binding.current());primaryClick();assert(ui.quest==nil and routes==0)
ui:Refresh();summary()
for _,all in ipairs({true,false})do
 ui.includeUnavailable=all;ui:Refresh();local _,m=summary()
 assert(m.steps[1].listedTarget==true and m.counts.READY==1 and row(1654).note.text==note("READY",false))
end
held[1654],ready[1654]=false,false;held[155],ready[155]=true,true;event("QUEST_LOG_UPDATE")
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","itIT","ptBR","koKR","zhCN","zhTW"})do
 addon.db.locale=locale;ui:Refresh();local _,m=summary();local r=row(155)
 assert(addon.L("OVERVIEW_SUPPORTING_QUEST")~="OVERVIEW_SUPPORTING_QUEST"and r.note.text==note("READY",true))
 assert(m.counts.READY==0 and #m.steps==1 and m.steps[1].listedTarget==false and r.enabled and r.height>=48)
 assert(r.note.point and r.note.width>0 and routes==0 and selections==0 and accepts==0)
end
local measured=row(155).note
local originalHeight=measured.GetStringHeight
measured.GetStringHeight=function(self)
 if self.text==note("READY",true)then return 48 end
 return originalHeight(self)
end
ui:RefreshDetail();local wrapped=row(155);assert(wrapped.note==measured and wrapped.height>=80,"support cue keeps measured multiline notes inside the row")
measured.GetStringHeight=originalHeight
assert(addon.Context==nativeContext and addon.Planner==nativePlanner and addon.Navigation==nativeNavigation)
assert(dungeon.quests==catalogue and #catalogue==9 and target.requires==group1 and other.requires==group2 and classQuest.classes==classes and classQuest.start==start and support.finish==finish)
print("Supporting quest cue: PASS (actual155/1654, Mine/All,10locales, DTO ownership, no source/count/route changes)")

addon.db.locale="enUS";ui:Refresh()
for _,trigger in ipairs({"READY","BRANCH_INSPECT","OVERVIEW_SUPPORTING_QUEST"})do
 local localize=addon.L;local fired=false
 local oldClick=row(155).scripts.OnClick
 addon.L=function(key,...)
  if not fired and key==trigger and ui.overviewBinding and ui.overviewBinding.model then
   fired=true;local step=ui.overviewBinding.model.steps[1]
   rawset(step,"listedTarget",nil)
   setmetatable(step,{__index=function(_,field)if field=="listedTarget"then error("retired DTO field read after localizer")end end})
  end
  return localize(key,...)
 end
 local ok,message=pcall(ui.RefreshDetail,ui)
 assert(fired and ok,message or "the localizer must fire without any retired DTO read")
 assert(ui.overviewBinding and not ui.overviewBinding.rawProof()and not ui.overviewBinding.current())
 oldClick();assert(ui.quest==nil and routes==0 and selections==0 and accepts==0)
 addon.L=localize;ui:Refresh();local _,m=summary()
 assert(m.steps[1].listedTarget==false and row(155).note.text==note("READY",true))
end
print("Supporting quest localizer ownership: PASS READY/inspect/prefix callbacks, no retired field reads or actions")
