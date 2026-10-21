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
 assert(u.overviewMapBinding==nil,"dungeon illustration does not authorize a map binding")
 assert(u.overviewArt and u.overviewArt:IsShown()and u.overviewArt.texture==a.DungeonArt(u.dungeon),"ordinary browsing retains the selected dungeon illustration")
 for _,field in ipairs(u.details or{})do assert(not field:IsShown(),"illustration overview contains no duplicate text")end
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
-- Internal component opt-in cannot add an entry to the compact default overview.
a.db.locale="enUS";a.experimentalDungeonMaps=true;u:RefreshDetail();hidden()
u.frame:Hide();u.frame.scripts.OnHide(u.frame);u.frame:Show();u:RefreshDetail();hidden()
assert(fetches==0 and opens==0)
a.DungeonMapSnapshot,u.OpenDungeonMap=provider,opener
print("PASS default-off map entry: every dungeon illustration remains visible, three locales, internal map opt-in stays hidden, no browsing fetch or extra controls")
