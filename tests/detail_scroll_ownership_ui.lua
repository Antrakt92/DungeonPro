local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,event=f.addon,f.eventFrame
event.scripts.OnEvent(event,"ADDON_LOADED","DungeonPro")
SlashCmdList.DUNGEONPRO("")
local ui=a.UI;local scroll=ui.detailScroll
local native=scroll.SetVerticalScroll
function scroll:GetVerticalScroll()return self.verticalScroll or 0 end
function scroll:GetHeight()return 100 end
function ui.detail:GetHeight()return 1000 end
local cases=0
for _,mode in ipairs({"back","escape","copy","acquisition","reset"})do
 scroll.SetVerticalScroll=native
 ui.dungeon=a.dungeons[1];ui.quest=nil;ui.detailHistory={};ui:ResetHistoryReading();ui:Refresh()
 if mode=="acquisition"then
  ui:InspectQuest(3801);scroll:SetVerticalScroll(300)
  assert(ui.referenceToggle and ui.referenceToggle.shown,"actual Dark Iron Legacy exposes additional giver locations")
 else
  ui:InspectQuest(65);scroll:SetVerticalScroll(300)
  if mode=="back"then ui:InspectQuest(66)
  elseif mode=="escape"then assert(ui:CopyLink(65))
  elseif mode=="reset"then ui:InspectQuest(66);scroll:SetVerticalScroll(150);ui:InspectQuest(67);scroll:SetVerticalScroll(125)end
 end
 local fired,depth,maxDepth=false,0,0
 scroll.SetVerticalScroll=function(self,value)
  depth=depth+1;maxDepth=math.max(maxDepth,depth)
  assert(depth<5,"scroll repair remains bounded")
  if not fired and (value>0 or mode=="reset")then
   fired=true
   if mode=="reset"then assert(ui:BackQuest())else assert(ui:InspectQuest(67))end
  end
  native(self,value);depth=depth-1
 end
 if mode=="back"then ui:BackQuest()
 elseif mode=="escape"then ui:EscapeCopyLink()
 elseif mode=="copy"then ui:CopyLink(65)
 elseif mode=="acquisition"then ui.referenceToggle.scripts.OnClick(ui.referenceToggle)
 else ui:InspectQuest(68)end
 assert(fired,"native scroll setter reentry must execute: "..mode)
 assert(ui.quest==67 and scroll.verticalScroll==(mode=="reset"and 125 or 0),
  "late "..mode.." scroll cannot overwrite the newer reader position: "..tostring(scroll.verticalScroll))
 assert(depth==0 and maxDepth<=3,"bounded native setter depth")
 cases=cases+1
end
scroll.SetVerticalScroll=native
-- Same-card repaints keep a direct user scroll position; ordinary Back still clamps.
ui.quest=nil;ui.detailHistory={};ui:ResetHistoryReading();ui:Refresh();ui:InspectQuest(65)
scroll:SetVerticalScroll(77);ui:RefreshDetail();assert(scroll.verticalScroll==77)
ui:InspectQuest(66);assert(ui:BackQuest()and ui.quest==65 and scroll.verticalScroll==77)
-- A native viewport read may replace the physical scroll owner before Back writes.
ui:InspectQuest(66);local oldHeight=scroll.GetHeight
local replacement=setmetatable({verticalScroll=7,scripts={},shown=true},getmetatable(scroll))
local fired=false
scroll.GetHeight=function(self)fired=true;ui.detailScroll=replacement;return oldHeight(self)end
assert(ui:BackQuest());scroll.GetHeight=oldHeight
assert(fired and ui.detailScroll==replacement and replacement.verticalScroll==7 and not replacement.scrollWrites,
 "Back must not write a replacement viewport using an older reading offset")
ui.detailScroll=scroll
print("Detail scroll ownership UI checks passed: "..cases.." native setter interleavings")

