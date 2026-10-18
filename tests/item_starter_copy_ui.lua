-- Item starters retain one introduction and both recorded roles through the real TOC.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui = fixture.addon, fixture.addon.UI
C_Timer = { After = function() end }
issecretvalue = function() return false end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
ui:Toggle(); addon.db.locale = "enUS"; ui.includeUnavailable = true
local ready, selected, visits = false, nil, {}
addon.Context = function()
    return {level=60, faction="Alliance", class="MAGE", race=3,
        completed=function(id) return id==155 end,
        active=function(id) return ready and id==selected end,
        ready=function(id) return ready and id==selected end}
end
UnitLevel = function() return 60 end
UnitEffectiveLevel = function() return 60 end
UnitQuestTrivialLevelRange = function() return 5 end
GetQuestDifficultyColor = function() return {r=0,g=1,b=0} end
addon.Navigation = {Start=function(action) visits[#visits+1]=action; return true end}
addon.GiverName = function(point) return point.name end
addon.ItemName = function(id) return "Recorded item "..id end
addon.ItemIcon = function() return 134400 end
addon.CarriedItemCount = function() return 0 end
addon.DialogueRewards, addon.QuestRewards, addon.CachedQuestRewards = function() end, function() end, function() end
local owners = {}
local function associate(id,dungeon,seen)
    if seen[id] then return end
    seen[id]=true; owners[id]=owners[id] or dungeon
    local quest=assert(addon.quests[id])
    for _,member in ipairs(quest.storyline or {}) do associate(member,dungeon,seen) end
    for _,group in ipairs(quest.requires or {}) do
        for _,member in ipairs(group.ids) do associate(member,dungeon,seen) end
    end
    for _,group in ipairs(quest.storylineGroups or {}) do
        for _,member in ipairs(group) do associate(member,dungeon,seen) end
    end
end
for _,dungeon in ipairs(addon.dungeons) do
    local seen={}
    for _,id in ipairs(dungeon.quests) do associate(id,dungeon,seen) end
end
local function contains(text)
    for _,field in ipairs(ui.details) do
        if field:IsShown() and field.text:find(text,1,true) then return true end
    end
    return false
end
local function render(id, turnin, inspectionDungeon)
    selected, ready = id, turnin == true
    ui.dungeon, ui.quest = assert(inspectionDungeon or owners[id]), id
    if inspectionDungeon then ui.questTreeRoot, ui.questTreeDungeon = nil, nil
    else ui.questTreeRoot, ui.questTreeDungeon = 92819, ui.dungeon end
    ui:Refresh()
    assert(ui.quest==id and ui.renderedQuest==id, "render keeps inspected quest identity")
end
local function visible(text)
 for _,field in ipairs(ui.details)do if field:IsShown()and field.text==text then return true end end
 return false
end
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","koKR","zhCN","zhTW","itIT"})do
 addon.db.locale=locale
 for _,sample in ipairs({{7508,18513},{4264,11446},{7503,18361},{7502,18360},{7506,18364},{7498,18356},{7499,18357},{98423,281030}})do
  render(sample[1])
  assert(not visible(addon.L("DETAIL_START_ITEM")),"starter item has one semantic label instead of duplicate introductory caption")
  assert(visible(addon.L("ITEM_STARTER","Recorded item "..sample[2])),"localized starter identification remains visible")
  local roles={}
  for _,button in ipairs(ui.objectiveButtons)do if button:IsShown()then
   local b=button.objectiveBinding
   if b.id==sample[2]and b.current()then roles[b.role]=b.sourceField end
  end end
  assert(roles.starter=="start"and roles.provided=="providedItems","both distinct recorded item roles survive caption simplification")
  assert(visible(addon.L("ITEM_CARRIED",0)),"starter carried count remains visible")
  if sample[1]==7508 or sample[1]==98423 then assert(visible(addon.L("START_ITEM_LOCATION_UNKNOWN")),"unknown starter source remains explicit")end
 end
 render(214);assert(visible(addon.L("DETAIL_GIVER")),"NPC giver keeps its heading")
 render(7492);assert(visible(addon.L("DETAIL_GIVER")),"alternative givers keep their heading")
end
addon.db.locale="enUS"
render(7508)
local nativeName=addon.ItemName
local armed,fired=true,false
addon.ItemName=function(id)
 if armed and id==18513 then
  armed,fired=false,true
  ui.quest,ui.dungeon=65,assert(owners[65]);ui:Refresh()
  return "Retired blade name"
 end
 return nativeName(id)
end
ui:RefreshDetail()
assert(fired,"item-name callback really retired the old starter card")
assert(ui.quest==65 and ui.renderedQuest==65 and not contains("Retired blade name"),"old item-name callback cannot overwrite newer inspected quest")
addon.ItemName=nativeName
render(7508)
local providerFired=false
addon.ItemName=function(id)
 if id==18513 then
  providerFired=true
  addon.ItemName=nativeName
  return "Retired provider identity"
 end
 return nativeName(id)
end
ui:RefreshDetail()
assert(providerFired,"item-name provider really changed during its callback")
assert(not contains("Retired provider identity"),"retired item-name provider cannot publish its text")
print("Item starter copy UI: PASS (actual TOC;10locales,both roles,NPC/alternatives,retiredcallback)")
