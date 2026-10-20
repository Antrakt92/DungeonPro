-- Actual TOC rendering must retain the journal's visual hierarchy and ownership.
-- These are modeled native anchors/fonts/colors, not an in-game pixel claim.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u,m=f.addon,f.addon.UI,f.methods
function m:SetFont(path,size,flags)self.fontPath,self.fontSize,self.fontFlags=path,size,flags;return true end
function m:GetFont()return self.fontPath or STANDARD_TEXT_FONT,self.fontSize or 14,self.fontFlags end
function m:SetTextColor(...)self.textColor={...}end
function m:SetColorTexture(...)self.fill={...}end
function m:SetBackdropColor(...)self.fill={...}end
function m:SetBackdropBorderColor(...)self.border={...}end
function m:SetFrameLevel(level)self.frameLevel=level end
function m:GetFrameLevel()return self.frameLevel or(self.parent and self.parent:GetFrameLevel()+1)or 0 end
function m:SetAllPoints(relative)self.allPoints=relative or self.parent end
function m:SetPoint(...)self.points=self.points or{};self.points[#self.points+1]={...};self.point={...}end
function m:ClearAllPoints()self.points=nil;self.point=nil end
function m:GetStringHeight()
 local size,width=self.fontSize or 14,self.width or 340
 return math.max(size*1.4,math.ceil(#(self.text or "")*size*.5/math.max(1,width))*size*1.4)
end
local create=CreateFrame
CreateFrame=function(kind,name,parent,...)local object=create(kind,name,parent,...);object.parent=parent;return object end
for _,key in ipairs({"CreateFontString","CreateTexture"})do
 local original=m[key]
 m[key]=function(self,...)local object=original(self,...);object.parent=self;object.shown=true;return object end
end
issecretvalue=function()return false end;GetLocale=function()return"enUS"end
C_Timer={After=function()end};UnitLevel=function()return 60 end;UnitFactionGroup=function()return"Alliance"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true
local dungeon;for _,d in ipairs(a.dungeons)do if d.key=="dalaran"then dungeon=d end end
assert(dungeon,"actual catalogue dungeon required")
local text="Controlled native description. "..string.rep("Long readable narrative paragraph. ",40)
a.Description=function(id)if id==92458 then return text end end
a.DialogueText=nil;a.QuestObjectives=function()return nil end
a.ItemName=function(id)return id==251961 and"Arcane Mote"or id==277507 and"Dalaran Sewer Key"or("Item "..id)end
a.ItemIcon=function()return 134400 end;a.CarriedItemCount=function()return 0 end
local routes=0;a.Navigation={Start=function()routes=routes+1;return true end,Map=function()routes=routes+1;return true end}
u.dungeon,u.quest=dungeon,92458;u:Refresh()
local function visibleText(value)
 for _,v in ipairs(u.details or{})do if v:IsShown()and v.text==value then return v end end
end
local title=assert(visibleText(a.quests[92458].name),"selected quest has its own visible title")
local role=assert(visibleText(a.L("DUNGEON_QUEST_SHORT")),"selected dungeon role is a distinct visible caption")
local prose=assert(visibleText(text),"native long description remains visible")
assert(title.fontSize and title.fontSize>=24 and prose.fontSize==16,"journal title is expressive and narrative stays readable at sixteen")
assert(role.fontSize==11 and title.fontSize>prose.fontSize and prose.fontSize>role.fontSize,"title, body and metadata have distinct visual hierarchy")
local factors={TOPLEFT={0,0},TOP={.5,0},TOPRIGHT={1,0},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,1},BOTTOM={.5,1},BOTTOMRIGHT={1,1}}
local function rectangle(object,depth)
 assert(object and(depth or 0)<30,"finite actual anchor chain")
 if object==u.detail then return 0,0,object:GetWidth(),object:GetHeight()end
 if object.allPoints then return rectangle(object.allPoints,(depth or 0)+1)end
 local points=object.points or{assert(object.point,"drawn journal region has an anchor")}
 local width=object.width or 0;local height=object.height or(object.kind=="FontString"and object:GetStringHeight())or 0
 local positions={}
 for _,p in ipairs(points)do
  local relative,anchor,dx,dy
  if type(p[2])=="number"then relative,anchor,dx,dy=object.parent,p[1],p[2],p[3]
  else relative,anchor,dx,dy=p[2]or object.parent,p[3]or p[1],p[4]or 0,p[5]or 0 end
  local x,y,w,h=rectangle(relative,(depth or 0)+1)
  local from,to=assert(factors[p[1]]),assert(factors[anchor])
  positions[#positions+1]={x+w*to[1]+dx,y+h*to[2]-dy,from[1],from[2]}
 end
 local first=positions[1]
 for _,p in ipairs(positions)do
  if p[3]~=first[3]then width=(p[1]-first[1])/(p[3]-first[3])end
  if p[4]~=first[4]then height=(p[2]-first[2])/(p[4]-first[4])end
 end
 return first[1]-width*first[3],first[2]-height*first[4],width,height
end
local function top(object)local _,y=rectangle(object);return y end
assert(top(role)<top(title),"role is placed above the selected title")
local objective,supplied
for _,button in ipairs(u.objectiveButtons or{})do if button:IsShown()and button.objectiveBinding then
 if button.objectiveBinding.role=="objective"then objective=button elseif button.objectiveBinding.role=="provided"then supplied=button end
end end
assert(objective and supplied,"actual objective and provided item have distinct rendered roles")
assert(objective.width==36 and objective.height==36 and supplied.width==24 and supplied.height==24,
 "goal items have a readable journal icon while supplied tools stay compact")
local ox,oy,ow,oh=rectangle(objective)
local region
for _,object in ipairs(f.objects)do
 local surface=object.detailJournalSurface
 if surface and surface.background and surface.left and surface.background.fill and surface.left.fill then
  local x,y,w,h=rectangle(object)
  if x<=ox and y<=oy and x+w>=ox+ow and y+h>=oy+oh then region=object;break end
 end
end
assert(region,"actual objective is enclosed by a tinted journal objective region")
assert(region:GetFrameLevel()<u.detail:GetFrameLevel(),"opaque objective region is behind the frame that owns its text")
local surface=region.detailJournalSurface;local _,_,accentWidth,accentHeight=rectangle(surface.left)
assert(accentWidth>0 and accentWidth<=3 and accentHeight>=oh,"objective region has a narrow full-height left accent")
assert(surface.background.fill[4]and surface.background.fill[4]>0 and surface.left.fill[4]and surface.left.fill[4]>0,"objective fill and accent are actually painted")
assert(top(title)<oy and top(prose)>oy+oh and top(prose)>top(supplied),"practical goals and supplied items precede long prose")
for index,field in ipairs({"start","finish"})do
 local row=assert(u.detailContactRows[index]);local binding=assert(row.detailContactBinding)
 assert(row:IsShown()and binding.current()and binding.questID==92458 and binding.endpoint==a.quests[92458][field],"journal contact belongs to selected exact endpoint")
 local purpose=assert(row.purpose or row.detailPurpose,"purpose is a separate text region")
 local avatar=assert(row.avatar or row.detailAvatar,"contact has a visible portrait region")
 assert(purpose:IsShown()and purpose.text==a.L(field=="start"and"DETAIL_GIVER"or"DETAIL_TURNIN"),"contact purpose is separate from its actor name")
 assert(row.title.text==a.quests[92458][field].name and row.note.text and row.note.text~="","contact actor and zone are separately readable")
 assert(purpose.fontSize==11 and row.title.fontSize==15 and row.note.fontSize==11,"contact purpose/name/zone preserve intended hierarchy")
 assert(avatar:IsShown()and avatar.width==36 and avatar.height==36,"contact portrait is thirty-six pixels rather than the retired glyph")
 local px,py=rectangle(purpose);local nx,ny=rectangle(row.title);local zx,zy=rectangle(row.note);local ax,_,aw=rectangle(avatar)
 assert(py<ny and ny<zy and nx==px and zx==px and nx>=ax+aw+8,"purpose/name/zone stack clearly beside the portrait")
 assert(top(objective)<top(row)and top(supplied)<top(row),"goals and provided items precede both practical contact rows")
 assert(top(prose)>top(row)+row.height,"both practical contacts precede long prose")
end
assert(routes==0,"visual composition never starts navigation automatically")
assert(u:InspectQuest(92459,true),"story node remains selectable in the central model")
assert(not visibleText(text),"a previous quest's long prose retires on selected-node change")
assert(not region:IsShown(),"a previous objective surface hides when the new selected quest has no objectives")
for _,button in pairs(u.detailTabButtons or{})do assert(not button:IsShown(),"journal has no repeated section modes")end
-- A count adapter is callback-capable; it cannot authorize a new formatter.
do
 local owner;for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do if id==6981 then owner=d end end end
 assert(owner,"actual item starter dungeon required")
 local localize,counts=a.L,a.CarriedItemCount
 local foreign,fired=0,false
 u.dungeon,u.quest=owner,6981
 a.CarriedItemCount=function(id)
  if id==10441 and not fired then
   fired=true;a.L=function()foreign=foreign+1;error("retired starter count called a replacement formatter")end
  end
  return 0
 end
 local ok,err=pcall(u.Refresh,u);a.L,a.CarriedItemCount=localize,counts
 assert(fired and ok and foreign==0,"starter pre-read retires before calling a replaced localizer: "..tostring(err))
end
do
 local start=a.quests[6981].start;local itemID=start.itemID
 local checker,equal,counts=issecretvalue,rawequal,a.CarriedItemCount
 local opaque={};local compared,fired=0,false
 issecretvalue=function(value)return equal(value,opaque)end
 rawequal=function(left,right)
  if equal(left,opaque)or equal(right,opaque)then compared=compared+1;error("restricted starter identity compared")end
  return equal(left,right)
 end
 a.CarriedItemCount=function(id)
  if id==10441 and not fired then fired=true;start.itemID=opaque end
  return 0
 end
 local ok,err=pcall(u.Refresh,u)
 issecretvalue,rawequal,a.CarriedItemCount=checker,equal,counts;start.itemID=itemID
 assert(fired and ok and compared==0,"starter pre-read proves an identity readable before comparing it: "..tostring(err))
end
-- Unknown second inventory reads preserve known counts only in the same epoch.
do
 local counts=a.CarriedItemCount
 for _,replace in ipairs({false,true})do
  a.CarriedItemCount=function()return 7 end;u:Refresh()
  assert(not visibleText(a.L("ITEM_CARRIED",0)),"probe begins without a previously rendered standalone zero caption")
  local calls=0;local replacement=function()return 7 end
  local original=function(id)
   if id==10441 then
    calls=calls+1
    if calls==1 then return 0 end
    if calls==2 and replace then a.CarriedItemCount=replacement end
   end
   return nil
  end
  a.CarriedItemCount=original
  local ok,err=pcall(u.Refresh,u)
  local zero=0;for _,field in ipairs(u.details)do if field:IsShown()and field.text==a.L("ITEM_CARRIED",0)then zero=zero+1 end end
  assert(ok and calls==2,"actual starter and later provided count callbacks ran: "..tostring(err))
  if replace then
   assert(a.CarriedItemCount==replacement and zero==0,"cached starter count retires after its original count capability is replaced")
  else assert(zero==1,"unknown later inventory retains one known starter count under the same capability")end
 end
 a.CarriedItemCount=counts
end
print("PASS journal visual contract: actual role/title hierarchy, tinted objective accent, distinct36px contacts, readable native prose and selected ownership")
