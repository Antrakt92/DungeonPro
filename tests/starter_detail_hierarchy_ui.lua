-- Starter acquisition is practical information; redundant requirements are omitted.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u=f.addon,f.addon.UI
C_Timer={After=function()end};issecretvalue=function()return false end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true
local dungeon;for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do if id==373 then dungeon=d end end end
assert(dungeon,"recorded letter dungeon")
local q=assert(a.quests[373]);assert(q.start.itemID and q.start.dropName=="Edwin VanCleef","actual recorded starter source")
a.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
local routes=0;a.Navigation={Start=function()routes=routes+1;return true end,Map=function()routes=routes+1;return true end}
a.GiverName=function(p)return p.name end;a.ItemName=function()return"Starter letter"end;a.ItemIcon=function()return 134400 end;a.CarriedItemCount=function()return 0 end
local prose="Controlled quest narrative."
a.Description=function(id)if id==373 then return prose end end
a.QuestRewards=function()return{items={},choices={},xp=2050,money=700}end
a.DialogueRewards=function()end;a.CachedQuestRewards=function()end
local function render()u.dungeon,u.quest=dungeon,373;u:Refresh()end
local function field(text)
 for _,fs in ipairs(u.details)do if fs:IsShown()and fs.text==text then return fs end end
end
local function top(fs)return -assert(fs.point)[3]end
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","itIT","koKR","zhCN","zhTW"})do
 a.db.locale=locale;q.minLevel=16;q.start.itemMinLevel=16;render()
 assert(not field(a.L("ITEM_MIN_LEVEL",16)),"equal item level does not duplicate the quest header")
 assert(not field(a.L("ITEM_REQUIREMENTS_NOTICE")),"generic implementation notice is absent")
 local intro=assert(field(a.L("ITEM_STARTER","Starter letter")),"one starter introduction")
 local heading=assert(field(a.L("ITEM_ACQUISITION")),"acquisition is explicit")
 local drop=assert(field(a.L("ITEM_DROP_SOURCE","Edwin VanCleef",a.DungeonName(dungeon))),"recorded drop NPC and own dungeon remain visible")
 local reward=assert(field(a.L("DETAIL_REWARDS")),"controlled reward section")
 assert(top(intro)<top(heading)and top(heading)<top(drop)and top(drop)<top(reward),"starter source is adjacent to its item and precedes rewards")
 assert(top(drop)<top(assert(field(prose))),"starter acquisition precedes long narrative")
 local count=0;for _,fs in ipairs(u.details)do if fs:IsShown()and fs.text==drop.text then count=count+1 end end
 assert(count==1,"acquisition source is not repeated at the bottom")
 q.start.itemMinLevel=15;render();assert(not field(a.L("ITEM_MIN_LEVEL",15)),"weaker item requirement is redundant")
 q.start.itemMinLevel=17;render();assert(field(a.L("ITEM_MIN_LEVEL",17)),"stricter item requirement remains useful")
 assert(not field(a.L("ITEM_REQUIREMENTS_NOTICE")),"stricter requirement does not restore boilerplate")
end
a.db.locale="enUS";q.minLevel=0;q.start.itemMinLevel=16;render()
assert(field(a.L("ITEM_MIN_LEVEL",16)),"unknown quest minimum never hides a known item requirement")
q.minLevel=16;q.start.itemClasses={"WARRIOR"};LOCALIZED_CLASS_NAMES_MALE={WARRIOR="Warrior"};render()
local classes=false;for _,fs in ipairs(u.details)do if fs:IsShown()and fs.text and fs.text:find("Warrior",1,true)then classes=true end end
assert(classes,"item class restriction remains represented")
local hidden={};local nativeSecret,nativeEqual=issecretvalue,rawequal;local comparisons=0
q.start.itemMinLevel=hidden
issecretvalue=function(value)return value==hidden end
rawequal=function(x,y)if x==hidden or y==hidden then comparisons=comparisons+1;error("restricted item minimum compared")end;return nativeEqual(x,y)end
local safe,problem=pcall(render)
issecretvalue,rawequal=nativeSecret,nativeEqual;q.start.itemMinLevel=16
assert(safe and comparisons==0,"restricted item minimum is omitted without comparison: "..tostring(problem))
local clean=a.Clean;local secret=issecretvalue;local fired,foreign=false,0
q.start.itemMinLevel=123456789
local function foreignChecker()foreign=foreign+1;return false end
a.Clean=function(value,kind)
 local result=clean(value,kind)
 if not fired and value==123456789 and kind=="number"then fired=true;issecretvalue=foreignChecker end
 return result
end
local owned,issue=pcall(u.RefreshDetail,u)
a.Clean,issecretvalue=clean,secret;q.start.itemMinLevel=16
assert(fired and owned and foreign==0,"minimum read retires before calling a replacement capability: "..tostring(issue))
q.start.dropNPCID=nil;q.start.dropName=nil;q.start.dungeonKey=nil;render()
assert(not field(a.L("ITEM_ACQUISITION")),"missing source never invents an acquisition heading or NPC")
assert(field(a.L("START_ITEM_LOCATION_UNKNOWN")),"missing acquisition stays explicitly unknown")
assert(routes==0,"rendering acquisition never starts navigation")
print("PASS actual letter starter source before rewards/prose, ten locales, no redundant level/boilerplate, stricter/unknown limits retained, missing source honest")
