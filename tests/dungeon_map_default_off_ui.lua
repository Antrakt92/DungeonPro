-- Real overview path; client-map scaffolding is not supported map coverage.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end
GetLocale=function()return "enUS"end
C_Timer={After=function()end}
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro")
u:Toggle();a.db.locale="enUS"
local fetches,opens=0,0
local provider,opener=a.DungeonMapSnapshot,u.OpenDungeonMap
a.DungeonMapSnapshot=function()fetches=fetches+1;error("ordinary browsing cannot fetch experimental maps")end
u.OpenDungeonMap=function()opens=opens+1;return true end
local function hidden()
 local b=assert(u.overviewMapControl)
 assert(not b:IsShown()and not b.enabled and b.scripts.OnClick==nil,"normal overview must not offer an unverified dungeon map")
 assert(u.overviewMapBinding==nil and u.overviewArt:IsShown())
end
u.dungeon,u.quest=a.dungeons[1],nil;u:Refresh();hidden()
for _,d in ipairs(a.dungeons)do
 a.experimentalDungeonMaps=false;u.dungeon,u.quest=d,nil;u:Refresh();hidden()
end
for _,locale in ipairs({"enUS","ruRU","zhCN"})do
 a.db.locale=locale
 for _,value in ipairs({false,1,"true"})do
  a.experimentalDungeonMaps=value;u:RefreshDetail();hidden()
 end
 a.experimentalDungeonMaps=nil;u:RefreshDetail();hidden()
end
assert(fetches==0 and opens==0)
-- Controlled internal opt-in preserves the component regressions without advertising coverage.
a.db.locale="enUS";a.experimentalDungeonMaps=true;u:RefreshDetail()
local b=u.overviewMapControl;local old=b.scripts.OnClick
assert(b:IsShown()and b.enabled and type(old)=="function"and u.overviewMapBinding)
local experimentalTop=-u.overviewArt.point[3]
old();assert(opens==1)
a.experimentalDungeonMaps=false
old();assert(opens==1,"disabling an experimental entry must immediately retire its retained click")
u:RefreshDetail();hidden()
assert(-u.overviewArt.point[3]<experimentalTop,"hidden action must not reserve an empty row above artwork")
a.experimentalDungeonMaps=true;u:RefreshDetail()
local binding=u.overviewMapBinding;local owner=binding.owner;local fired=false
binding.owner=function()fired=true;a.experimentalDungeonMaps=false;return owner()end
assert(not b.questListWrites.ClearAllPoints.current()and fired,"owner callbacks cannot keep a disabled experimental entry current")
u:RefreshDetail();hidden()
u.frame:Hide();u.frame.scripts.OnHide(u.frame);u.frame:Show();u:RefreshDetail();hidden()
assert(fetches==0 and opens==1)
a.DungeonMapSnapshot,u.OpenDungeonMap=provider,opener
print("PASS default-off map entry: every dungeon, three locales, strict opt-in, no browsing fetch, retired input and no blank layout row")
