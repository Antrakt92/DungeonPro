local addon, queue, ready, requests, valid, shown, loaded, cacheState, notices, idValue, count, locale
local total, secret = 0, {}
local function reset()
    addon, queue, ready, requests = {}, {}, {}, {}
    valid, shown, loaded, cacheState, notices, idValue, count, locale = true, true, true, false, 0, 7001, 1, "enUS"
    issecretvalue = function(value) return value == secret end
    GetLocale = function() return locale end
    assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
    assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
    addon.char, addon.db, addon.quests = {}, {locale="auto"}, {[65]={id=65},[66]={id=66}}
    HaveQuestRewardData = function() return loaded end
    GetNumQuestLogRewards = function() return count end
    GetNumQuestLogChoices = function() return 1 end
    local function reward()
        return ready[idValue] and "Sword" or nil, ready[idValue] and 123 or nil, 1, 2, true, idValue
    end
    GetQuestLogRewardInfo, GetQuestLogChoiceInfo = reward, reward
    GetQuestLogRewardMoney, GetQuestLogRewardXP = nil, nil
    C_QuestLog = {SetSelectedQuest=function()error("selection forbidden")end}
    C_TaskQuest = {RequestPreloadRewardData=function() loaded=true end}
    C_Item = {
        GetItemNameByID=function(id)return ready[id] and "Sword" or nil end,
        IsItemDataCachedByID=function(id)return ready[id] or cacheState end,
        RequestLoadItemDataByID=function(id)requests[id]=(requests[id] or 0)+1 end,
    }
    C_Timer = {After=function(delay, fn)queue[#queue+1]={delay=delay,fn=fn}end}
    addon.listeners[1]=function()notices=notices+1 end
    assert(loadfile("UI/RewardCache.lua"))("DungeonPro", addon)
end
local function fire(delay)
    for index, item in ipairs(queue) do
        if item.delay==delay then table.remove(queue,index);item.fn();return end
    end
    error("missing timer "..delay)
end
local function current()return valid end
local function watch(owner, ids)
    addon.RewardCache.Watch(owner,ids or {65},current,function()notices=notices+1 end)
end
local function owner()return {frame={IsShown=function()return shown end}}end
local function test(name,fn)
    reset();local ok,err=pcall(fn);assert(ok,name..": "..tostring(err));total=total+1;print("PASS "..name)
end
test("Loaded reward IDs with cold item names request outside pure cached reads and later resolve",function()
    assert(addon.CachedQuestRewards(65)==nil and requests[7001]==nil)
    local view=owner();watch(view,{65,66})
    assert(requests[7001]==1,"cold loaded rewards must warm item metadata once")
    for _=1,10 do watch(view,{65,66})end
    assert(requests[7001]==1)
    ready[7001]=true;addon.ItemDataResult(7001,true);fire(.2)
    local value=addon.CachedQuestRewards(65)
    assert(value and value.items[1].id==7001 and value.choices[1].name=="Sword" and notices==1)
end)
test("Cold quest preload progresses into separate item metadata then a real reward DTO",function()
    loaded=false;local view=owner();watch(view);assert(requests[7001]==nil)
    fire(.2);assert(loaded and requests[7001]==1 and notices==0)
    ready[7001]=true;fire(.6);assert(notices==1 and addon.CachedQuestRewards(65))
end)
test("Exhausted polling still permits bounded transient item retry on visible Notify repaint",function()
    local view=owner();watch(view);fire(.2);fire(.6);fire(1.2)
    assert(requests[7001]==1)
    for attempt=1,3 do
        addon.ItemDataResult(7001,false)
        if attempt<3 then
            fire(2);fire(.1)
            addon.db.locale=attempt==1 and "ruRU" or "enUS"
            watch(view);assert(requests[7001]==attempt+1)
        end
    end
    for _=1,20 do watch(view)end
    assert(requests[7001]==3)
end)
test("Only clean false item-cache evidence dispatches a load",function()
    for _,value in ipairs({true,secret,0,"false"})do
        cacheState=value;addon.RequestQuestRewardItems(65,current);assert(requests[7001]==nil)
    end
    cacheState=nil;addon.RequestQuestRewardItems(65,current);assert(requests[7001]==nil)
    C_Item.IsItemDataCachedByID=function()error("unreadable")end
    addon.RequestQuestRewardItems(65,current);assert(requests[7001]==nil)
end)
test("Malformed reward identity and counts fail before any item load",function()
    for _,value in ipairs({0,-1,1.5,4294967296,secret,"7001",math.huge})do
        idValue=value;assert(not addon.RequestQuestRewardItems(65,current) and next(requests)==nil)
    end
    idValue=7001;count=101;assert(not addon.RequestQuestRewardItems(65,current) and next(requests)==nil)
    count=1;assert(not addon.RequestQuestRewardItems(67,current) and next(requests)==nil)
end)
test("Hidden or expired caller never dispatches even when cache getters expire it",function()
    local view=owner();shown=false;watch(view);assert(next(requests)==nil)
    shown=true;valid=false;addon.RequestQuestRewardItems(65,current);assert(next(requests)==nil)
    valid=true;C_Item.IsItemDataCachedByID=function()valid=false;return false end
    addon.RequestQuestRewardItems(65,current);assert(next(requests)==nil)
end)
test("Source and owner replacement during reward read cannot request stale item IDs",function()
    GetQuestLogRewardInfo=function()addon.quests[65]={id=65};return nil,nil,1,2,true,7001 end
    assert(not addon.RequestQuestRewardItems(65,current) and next(requests)==nil)
end)
test("Missing item API stays optional and never changes selection",function()
    C_Item=nil;addon.RequestQuestRewardItems(65,current);assert(next(requests)==nil)
end)
print("Reward item hydration: "..total.." checks passed")
