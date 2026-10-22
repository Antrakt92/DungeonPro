-- Selected quest roles and direct contacts preserve source ownership and UI state.
do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local q={id=995901,name="Contact selected",minLevel=1,requirementsKnown=true,start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20},finish={npcID=82,name="Finish actor",zoneName="Stormwind City",mapID=1453,x=30,y=40}}
a.quests[q.id]=q;local d={key="contacts",name="Contacts",minLevel=1,maxLevel=60,quests={q.id}};a.dungeons={d};u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,q.id,q.id,d
local ctx={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end};a.Context=function()return ctx end
local calls={};a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={action=action,purpose=purpose};return true end,Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}
q.factions={"Alliance"};u:Refresh()

f.methods.GetStringWidth=function()return 80 end
u:Refresh()
local s,t=assert(u.detailContactRows[1]),assert(u.detailContactRows[2])
assert(s.detailAvatar.texture=="Interface\\GossipFrame\\AvailableQuestIcon","pickup uses exclamation mark")
assert(t.detailAvatar.texture=="Interface\\GossipFrame\\ActiveQuestIcon","turn-in uses question mark")
for _,row in ipairs({s,t})do
 assert(row.width==28 and row.height==28 and row.detailAvatar.width==24 and row.detailAvatar.height==24,"compact clickable target and readable icon")
 assert(not row.title:IsShown()and not row.note:IsShown()and not row.detailPurpose:IsShown(),"contact text belongs to tooltip instead of tall rows")
 assert(row.motionWhileDisabled==true,"mapless disabled contact still receives hover")
end
assert(s.point[1]=="TOPRIGHT"and s.point[2]==u.detail and s.point[3]=="TOPRIGHT"and s.point[4]==-40 and t.point[4]==-8,"contact icons occupy the standalone right-edge slots")
assert(s.point[5]==t.point[5]and t.point[4]-s.point[4]==32,"both actions share the audience line without overlap")
local audience
for _,fs in ipairs(u.details)do if fs:IsShown()and fs.text and fs.text:find("Alliance",1,true)then audience=fs end end
assert(audience and audience.width==u.detail:GetWidth()-8-68,"audience reserves contact space instead of drawing underneath icons")
assert(s.point[5]==audience.point[3]+6,"28px contact buttons center beside the 15px faction caption")
local divider=assert(u.detailJournalSections.header)
assert(-divider.point[3]+audience.point[3]<35,"contact icons do not inflate the faction row or divider gap")
local measured,originalWidth=0,audience.GetStringWidth
audience.GetStringWidth=function()measured=measured+1;error("contact placement must not measure faction text")end
local originalDetailWidth=u.detail.width
for _,width in ipairs({260,540})do
 u.detail:SetWidth(width);u:RefreshDetail()
 assert(s.point[1]=="TOPRIGHT"and s.point[4]==-40 and t.point[4]==-8,"right anchors survive narrow and wide detail panes")
 assert(audience.width==width-8-68,"faction text retains space for right-edge actions after resize")
end
u.detail.width=originalDetailWidth;audience.GetStringWidth=originalWidth;u:RefreshDetail()
assert(measured==0,"right-edge contact placement is independent of faction text measurements")
local tip={lines={},shown=false}
function tip:SetOwner(owner)self.owner=owner;self.lines={}end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetText(text)self.heading=text end
function tip:AddLine(text)self.lines[#self.lines+1]=text end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip
s.scripts.OnEnter()
assert(tip.shown and tip.heading==a.L("DETAIL_GIVER")and tip.lines[1]=="Pickup actor"and tip.lines[2]=="Westfall","pickup hover explains purpose, actor and zone")
s.scripts.OnLeave();assert(not tip.shown,"leaving contact closes its own tooltip")
t.scripts.OnEnter()
assert(tip.shown and tip.heading==a.L("DETAIL_TURNIN")and tip.lines[1]=="Finish actor"and tip.lines[2]=="Stormwind City","turn-in hover has its own endpoint")
local oldEnter,oldLeave=t.scripts.OnEnter,t.scripts.OnLeave
u:Refresh();assert(not tip.shown,"refresh retires old tooltip")
t=u.detailContactRows[2];t.scripts.OnEnter();local held=u.navigationTooltip
oldLeave();assert(u.navigationTooltip==held and tip.shown,"retired leave cannot hide the new tooltip on a reused control")
oldEnter();assert(u.navigationTooltip==held,"retired hover cannot replace the new tooltip")
t.scripts.OnLeave()
-- No faction and no pickup: the finishing contact keeps its fixed slot and header.
q.factions=nil;q.start=nil;q.finish={npcID=82,name="No map finisher",zoneName="Unknown zone"}
u:Refresh();t=assert(u.detailContactRows[2])
assert(t.point[4]==-8 and t.point[1]=="TOPRIGHT","finish retains rightmost slot even when faction text is absent")
assert(not u.detailContactRows[1]:IsShown()and t:IsShown()and t.height==28,"finish-only contact does not require faction or pickup")
assert(not t.enabled and t.scripts.OnClick==nil and t.motionWhileDisabled,"missing navigation remains inert and informative")
t.scripts.OnEnter();assert(tip.shown and tip.lines[1]=="No map finisher","mapless contact still identifies the actor")
t.scripts.OnLeave()
-- Reentrant tooltip calls must not publish old text after selection changes.
local original=tip.AddLine;local fired=false
function tip:AddLine(text)
 original(self,text)
 if not fired then fired=true;u.quest=nil;u:Refresh()end
end
local enter=t.scripts.OnEnter;enter()
assert(fired and not tip.shown and u.navigationTooltip==nil,"selection change inside native tooltip callback retires the old hint")
GameTooltip=nil
assert(#calls==0,"hovering and layout never start navigation")
print("PASS compact contact icons, audience reserve, exact endpoint tooltips, retired hover, mapless/no-faction/sparse finish, tooltip reentry")
end
