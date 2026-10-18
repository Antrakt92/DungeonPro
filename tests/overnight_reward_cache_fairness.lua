local addon = {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
issecretvalue=function()return false end
GetLocale=function()return "enUS"end
addon.char,addon.db,addon.quests={},{locale="auto"},{}
local ids,queue,now,preloads,hydrations={},{},0,{},{}
local firstPreload, sliceHydrations, maxSlice = {}, 0, 0
for id=1,42 do ids[id]=id;addon.quests[id]={id=id}end
addon.CachedQuestRewards=function()return nil end
addon.RequestQuestRewardData=function(id,current)assert(current());preloads[id]=(preloads[id]or 0)+1;firstPreload[id]=firstPreload[id]or now end
addon.RequestQuestRewardItems=function(id,current)assert(current());hydrations[id]=(hydrations[id]or 0)+1;sliceHydrations=sliceHydrations+1 end
C_Timer={After=function(delay,fn)queue[#queue+1]={at=now+delay,fn=fn}end}
assert(loadfile("UI/RewardCache.lua"))("DungeonPro",addon)
local owner={frame={IsShown=function()return true end}}
local function watch()addon.RewardCache.Watch(owner,ids,function()return true end,function()end)end
watch()
-- Item data events already coalesce UI repaint at 100 ms; retain that real cadence.
for step=1,20 do queue[#queue+1]={at=step*.1,fn=watch}end
local callbacks=0
while #queue>0 do
 table.sort(queue,function(a,b)return a.at<b.at end)
 local event=table.remove(queue,1);if event.at>2.05 then break end
 now=event.at;sliceHydrations=0;event.fn();maxSlice=math.max(maxSlice,sliceHydrations);callbacks=callbacks+1;assert(callbacks<1000)
end
local distinct,total,last=0,0,0
for id,n in pairs(hydrations)do distinct=distinct+1;total=total+n;last=math.max(last,id)end
print("callbacks",callbacks,"uniqueHydrated",distinct,"totalHydrations",total,"largestID",last,"lastPreloaded",preloads[42]or 0)
assert(distinct==42 and preloads[42]==1,"same-view 100ms refreshes starved reward loading for later quest rows")

assert(maxSlice<=2,"same-view refresh must preserve the two-quest deferred work limit")
assert(firstPreload[42]<.7,"later rows must receive their first load request in the initial fair pass")
print("PASS Same-view item refreshes preserve fair reward preload slices")

-- A fresh character starts its own first pass, even with identical row IDs.
queue, now, preloads, hydrations = {}, 0, {}, {}
addon.char = {}
assert(loadfile("UI/RewardCache.lua"))("DungeonPro", addon)
watch()
local first = table.remove(queue, 1); now = first.at; first.fn()
assert(preloads[1] == 1 and preloads[2] == 1 and preloads[3] == nil)
addon.char, preloads = {}, {}
watch()
local nextSlice = table.remove(queue, 1); now = nextSlice.at; nextSlice.fn()
assert(preloads[1] == 1 and preloads[2] == 1 and preloads[3] == nil,
    "a new character must restart reward ownership at the first cold quest")
print("PASS Character replacement restarts the first reward loading pass")
