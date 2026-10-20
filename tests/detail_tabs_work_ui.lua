-- One selected reading stream renders each provider and compatibility aliases do not poll it.
local f = assert(loadfile("tests/client_ui.lua"))("fixture")
local a, ui = f.addon, f.addon.UI
issecretvalue = function() return false end
C_Timer = { After = function() end }
GetLocale = function() return "enUS" end
f.eventFrame.scripts.OnEvent(f.eventFrame, "ADDON_LOADED", "DungeonPro")
ui:Toggle(); a.db.locale = "enUS"; ui.includeUnavailable = true
assert(type(ui.SetDetailTab) == "function", "legacy callers retain one stream entry point")
local id, reads = 96395, { story = 0, progress = 0, rewards = 0 }
local owner
for _, d in ipairs(a.dungeons) do for _, q in ipairs(d.quests) do if q == id then owner = d end end end
assert(owner and a.quests[id].objectiveKills[1].quantity == nil)
a.Context = function() return { level = 60, faction = "Alliance", class = "MAGE",
    completed = function() return false end, active = function(q) return q == id end } end
local prose = string.rep("Current captured story. ", 45)
a.Description = function(q) assert(q == id); reads.story = reads.story + 1; return prose end
a.QuestObjectives = function(q)
    assert(q == id); reads.progress = reads.progress + 1
    return { { text = "0/1 Faldrim Anvilmar slain", finished = false } }
end
a.DialogueObjectiveText, a.DialogueRewards, a.QuestRewards = function() end, function() end, function() end
a.CachedQuestRewards = function(q)
    assert(q == id); reads.rewards = reads.rewards + 1
    return { source = "cache", items = {}, choices = {}, xp = 2300 }
end
local function visible(text)
    for _, line in ipairs(ui.details) do
        if line:IsShown() and line.text and line.text:find(text, 1, true) then return true end
    end
    return false
end
ui.dungeon, ui.quest = owner, id; ui:Refresh(nil, true)
assert(ui.detailTab == "quest" and visible("0/1 Faldrim Anvilmar slain"))
assert(reads.progress > 0 and reads.rewards > 0 and reads.story == 1 and visible(prose))
local history, count, preparation, engine = ui.detailHistory, #ui.detailHistory, ui.preparation, ui.engine
local questList, scans = ui.questListGeneration, 0
local get = a.DungeonStatus.Get
a.DungeonStatus.Get = function(...) scans = scans + 1; return get(...) end
local progress, rewards = reads.progress, reads.rewards
assert(ui:SetDetailTab("sources"))
assert(reads.progress==progress and reads.rewards==rewards and reads.story==1,"compatibility aliases do not poll displayed providers")
assert(ui:SetDetailTab("story")and visible(prose)and visible("0/1 Faldrim Anvilmar slain")and visible(a.L("REWARD_XP",2300)))
assert(reads.story==1 and reads.progress==progress and reads.rewards==rewards)
assert(ui:SetDetailTab("story")and reads.story==1,"repeated aliases do not poll text")
assert(ui:SetDetailTab("quest")and visible("0/1 Faldrim Anvilmar slain"))
assert(reads.story==1 and reads.progress==progress and reads.rewards==rewards)
assert(ui.detailHistory==history and #history==count and ui.preparation==preparation and ui.engine==engine)
assert(ui.questListGeneration==questList and scans==0,"detail aliases leave catalogue and chain generations alone")
assert(a.quests[id].objectiveKills[1].quantity==nil,"a displayed live counter does not rewrite unknown source quantity")
ui:RefreshDetail()
assert(reads.story==2 and reads.progress>progress and reads.rewards>rewards and scans==0,"one explicit refresh rereads current providers without a list scan")
-- A native scroll setter can finish a newer stream reading transaction before its old write returns.
ui.detailScroll.GetHeight=function()return 40 end
ui.detailScroll:SetVerticalScroll(17)
local scroll,nativeScroll,fired=ui.detailScroll,f.methods.SetVerticalScroll,false
scroll.SetVerticalScroll=function(self,value)
 if not fired and value==17 then fired=true;assert(ui:WriteDetailScroll(self,41,function()return ui.quest==id end))end
 return nativeScroll(self,value)
end
ui:WriteDetailScroll(scroll,17,function()return ui.quest==id end)
scroll.SetVerticalScroll=nativeScroll
assert(fired and ui.detailTab=="quest"and ui.quest==id and scroll:GetVerticalScroll()==41,"late old scroll cannot overwrite newer stream reading")
print("Single-stream work: PASS (once-only providers, quiet aliases, live progress, exact prose and newest scroll ownership)")
