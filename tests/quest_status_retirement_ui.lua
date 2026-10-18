-- Actual-TOC composition plus direct native setter tails; no native-client claim.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,event,m=f.addon,f.eventFrame,f.methods
GetLocale=function()return "enUS"end
issecretvalue=function()return false end
function m:SetAtlas(value)self.atlas,self.texture=value,nil end
function m:GetAtlas()return self.atlas end
function m:SetTexture(value)self.texture,self.atlas=value,nil;return true end
function m:SetVertexColor(r,g,b)self.vertex={r,g,b}end
function m:SetDesaturated(value)self.desaturated=value end
C_Texture={GetAtlasInfo=function()return {}end}
local ready=false
C_QuestLog.IsOnQuest=function(id)return id==166 end
C_QuestLog.ReadyForTurnIn=function(id)return id==166 and ready end
event.scripts.OnEvent(event,"ADDON_LOADED","DungeonPro");SlashCmdList.DUNGEONPRO("")
local ui=a.UI;for _,d in ipairs(a.dungeons)do if d.key=="dm"then ui.dungeon=d end end
ui.includeUnavailable=true;ui:Refresh()
local function row()for _,r in ipairs(ui.rows)do if r:IsShown()and r.questID==166 then return r end end end
local r=assert(row());local icon=r.statusIcon
assert(icon.atlas=="Quest-In-Progress-Icon-yellow")
local native,fired=icon.SetAtlas,false
icon.SetAtlas=function(self,value,...)
 if not fired then fired=true;ready=true;event.scripts.OnEvent(event,"QUEST_LOG_UPDATE")end
 return native(self,value,...)
end
ui:Refresh();r=assert(row())
assert(fired and ui.engine:State(166).status=="READY")
assert(r.statusIcon.atlas=="UI-QuestIcon-TurnIn-Normal","retired ACTIVE setter replaced current READY icon")
icon.SetAtlas=native
local total=1
local function test(name,fn)local ok,err=pcall(fn);assert(ok,name..": "..tostring(err));total=total+1;print("PASS "..name)end
local function texture()
 local t=CreateFrame("Texture");t.calls={}
 for _,key in ipairs({"Hide","Show","SetTexture","SetAtlas","SetVertexColor","SetDesaturated"})do
  local native=m[key]
  t[key]=function(self,...)self.calls[key]=(self.calls[key]or 0)+1;return native(self,...)end
 end
 return t
end
for _,boundary in ipairs({"Hide","SetTexture","SetAtlas","Show"})do
 test("Late "..boundary.." preserves the newest complete status",function()
  local t=texture();local native,armed=t[boundary],true
  t[boundary]=function(self,...)
   if armed then armed=false;assert(a.PaintQuestStatus(t,"READY"))end
   return native(self,...)
  end
  assert(not a.PaintQuestStatus(t,"ACTIVE"))
  assert(not armed and t.shown and t.atlas=="UI-QuestIcon-TurnIn-Normal")
 end)
end
test("Late Show preserves a newer deliberate hidden fallback",function()
 local t=texture();local native,armed=t.Show,true
 t.Show=function(self,...)
  if armed then armed=false;assert(not a.PaintQuestStatus(t,"UNKNOWN"))end
  return native(self,...)
 end
 assert(not a.PaintQuestStatus(t,"ACTIVE"))
 assert(not armed and not t.shown and t.texture==nil and t.atlas==nil)
end)
test("Late compact asset retains the newest asset color and saturation together",function()
 local t=texture();local native,armed=t.SetTexture,true
 t.SetTexture=function(self,value)
  if armed and value=="Interface\\RaidFrame\\ReadyCheck-Ready"then
   armed=false;assert(a.PaintCompactQuestStatus(t,"AVAILABLE"))
  end
  return native(self,value)
 end
 assert(not a.PaintCompactQuestStatus(t,"COMPLETED"))
 assert(not armed and t.shown and t.texture=="Interface\\GossipFrame\\AvailableQuestIcon"and t.vertex[1]==1 and t.vertex[2]==1 and t.vertex[3]==0 and t.desaturated==false)
end)
test("Failed newer atlas write stays hidden after the old setter resumes",function()
 local t=texture();local native,armed=t.SetAtlas,true
 t.SetAtlas=function(self,value,...)
  if armed then armed=false;assert(not a.PaintQuestStatus(t,"READY"))
  elseif value=="UI-QuestIcon-TurnIn-Normal"then native(self,value,...);error("failed newer native write")end
  return native(self,value,...)
 end
 assert(not a.PaintQuestStatus(t,"ACTIVE"))
 assert(not armed and not t.shown and t.atlas==nil)
end)
test("Expired newer scope clears owned visuals without reviving the old status",function()
 local t=texture();local native,armed,live=t.SetAtlas,true,true
 t.SetAtlas=function(self,value,...)
  if armed then armed=false;assert(a.PaintQuestStatus(t,"READY",function()return live end));live=false end
  return native(self,value,...)
 end
 assert(not a.PaintQuestStatus(t,"ACTIVE"))
 assert(not armed and not t.shown and t.atlas==nil)
end)
test("Changed native capability is never called by retained restoration",function()
 local t=texture();local native,armed,foreign=t.SetAtlas,true,0
 t.SetAtlas=function(self,value,...)
  if armed then armed=false;assert(a.PaintQuestStatus(t,"READY"));t.Show=function()foreign=foreign+1 end end
  return native(self,value,...)
 end
 assert(not a.PaintQuestStatus(t,"ACTIVE"))
 assert(not armed and foreign==0 and not t.shown and t.atlas==nil)
end)
test("Healthy repeated paints add no restoration writes",function()
 local t=texture()
 for _=1,5 do assert(a.PaintQuestStatus(t,"ACTIVE"))end
 assert(t.calls.Hide==5 and t.calls.SetTexture==5 and t.calls.SetAtlas==5 and t.calls.Show==5)
end)
test("A rejected restoration asset clears instead of claiming the stale asset",function()
 local t=texture();local native,armed,available=t.SetTexture,true,0
 t.SetTexture=function(self,value)
  if value=="Interface\\GossipFrame\\AvailableQuestIcon"then
   available=available+1;if available>1 then return false end
  end
  if armed and value=="Interface\\RaidFrame\\ReadyCheck-Ready"then
   armed=false;assert(a.PaintCompactQuestStatus(t,"AVAILABLE"))
  end
  return native(self,value)
 end
 assert(not a.PaintCompactQuestStatus(t,"COMPLETED"))
 assert(not armed and available==2 and not t.shown and t.texture==nil)
end)
test("A newer paint inside restoration wins with bounded setter depth",function()
 local t=texture();local native,armed,readies,depth,maxDepth=t.SetAtlas,true,0,0,0
 t.SetAtlas=function(self,value,...)
  depth=depth+1;maxDepth=math.max(maxDepth,depth);assert(depth<=4)
  if value=="UI-QuestIcon-TurnIn-Normal"then
   readies=readies+1
   if readies==2 then assert(a.PaintCompactQuestStatus(t,"AVAILABLE"))end
  elseif armed then armed=false;assert(a.PaintQuestStatus(t,"READY"))end
  local result=native(self,value,...);depth=depth-1;return result
 end
 assert(not a.PaintQuestStatus(t,"ACTIVE"))
 assert(readies==2 and depth==0 and maxDepth<=3 and t.calls.SetAtlas==3)
 assert(t.shown and t.texture=="Interface\\GossipFrame\\AvailableQuestIcon"and t.vertex[3]==0 and not t.desaturated)
end)
local function plainTexture()
 return {scripts={},Hide=m.Hide,Show=m.Show,SetTexture=m.SetTexture,SetAtlas=m.SetAtlas,
  SetVertexColor=m.SetVertexColor,SetDesaturated=m.SetDesaturated}
end
for _,status in ipairs({"UNKNOWN","ACTIVE"})do
 test("Discarded "..status.." targets and their retained recipes collect",function()
  local function discarded()
   local t=plainTexture();local watch=setmetatable({t},{__mode="v"})
   local painted=a.PaintQuestStatus(t,status,function()return t.scripts~=nil end);assert(painted==(status=="ACTIVE"))
   assert(t._dungeonProQuestStatusPaint)
   return watch
  end
  local watch=discarded();collectgarbage("collect");collectgarbage("collect")
  assert(watch[1]==nil,"weak registry retained its target through the recipe")
 end)
end
test("A live target anchors its latest completed paint across garbage collection",function()
 local t=plainTexture();local native,armed=t.SetAtlas,true
 t.SetAtlas=function(self,value,...)
  if armed then armed=false;assert(a.PaintQuestStatus(t,"READY"));collectgarbage("collect");collectgarbage("collect")end
  return native(self,value,...)
 end
 assert(not a.PaintQuestStatus(t,"ACTIVE"))
 assert(not armed and t.shown and t.atlas=="UI-QuestIcon-TurnIn-Normal")
end)
test("Replacing a live target's paint releases the retired anchor",function()
 local t=plainTexture();assert(a.PaintQuestStatus(t,"ACTIVE"))
 local old=setmetatable({t._dungeonProQuestStatusPaint},{__mode="v"})
 assert(a.PaintQuestStatus(t,"READY"));collectgarbage("collect");collectgarbage("collect")
 assert(old[1]==nil and t._dungeonProQuestStatusPaint and t.atlas=="UI-QuestIcon-TurnIn-Normal")
end)
test("Writable native-shaped userdata anchors a paint without a registry leak",function()
 local function discarded()
  local t=newproxy(true);local fields=plainTexture();local mt=getmetatable(t)
  mt.__index=fields;mt.__newindex=function(_,key,value)fields[key]=value end
  assert(a.PaintQuestStatus(t,"ACTIVE")and t._dungeonProQuestStatusPaint)
  return setmetatable({t},{__mode="v"})
 end
 local watch=discarded();collectgarbage("collect");collectgarbage("collect");assert(watch[1]==nil)
end)
test("An unanchorable native adapter declines before any native paint writes",function()
 local t=newproxy(true);local calls=0;local mt=getmetatable(t)
 mt.__index={Hide=function()calls=calls+1 end,SetTexture=function()calls=calls+1 end}
 mt.__newindex=function()error("read-only native adapter")end
 assert(not a.PaintQuestStatus(t,"UNKNOWN")and calls==0)
end)
test("A newer userdata paint also retains its anchor after an older assignment resumes",function()
 local t=newproxy(true);local fields=plainTexture();local mt=getmetatable(t);local armed=true
 mt.__index=fields
 mt.__newindex=function(_,key,value)
  if armed and key=="_dungeonProQuestStatusPaint"then armed=false;assert(a.PaintQuestStatus(t,"READY"))end
  fields[key]=value
 end
 assert(not a.PaintQuestStatus(t,"ACTIVE"));collectgarbage("collect");collectgarbage("collect")
 assert(not armed and t.shown and t.atlas=="UI-QuestIcon-TurnIn-Normal"and t._dungeonProQuestStatusPaint.restore)
end)
test("A second userdata reanchor reentry keeps the latest recipe alive across GC",function()
 local t=newproxy(true);local fields=plainTexture();local mt=getmetatable(t)
 local anchors,counting,fired=0,false,false
 mt.__index=fields
 mt.__newindex=function(_,key,value)
  if counting and key=="_dungeonProQuestStatusPaint"then
   anchors=anchors+1
   if anchors==1 then assert(a.PaintQuestStatus(t,"READY"))
   elseif anchors==3 then assert(a.PaintCompactQuestStatus(t,"AVAILABLE"))end
  end
  fields[key]=value
 end
 fields.SetAtlas=function(self,value)
  if not fired then
   fired=true;counting=true;assert(not a.PaintQuestStatus(t,"ACTIVE"));counting=false
   collectgarbage("collect");collectgarbage("collect")
  end
  fields.atlas,fields.texture=value,nil
 end
 assert(not a.PaintQuestStatus(t,"ACTIVE"))
 assert(fired and anchors>=4 and anchors<=6,"both anchor callbacks must run within the repair budget")
 assert(t.shown and t.texture=="Interface\\GossipFrame\\AvailableQuestIcon"and t.vertex[3]==0)
end)
test("Recursive native anchor callbacks stop before any visual write",function()
 local t=newproxy(true);local fields=plainTexture();local mt=getmetatable(t)
 local anchors,writes=0,0
 mt.__index=fields
 fields.Hide=function()writes=writes+1 end
 fields.SetTexture=function()writes=writes+1 end
 fields.SetAtlas=function()writes=writes+1 end
 fields.Show=function()writes=writes+1 end
 mt.__newindex=function(_,key,value)
  if key=="_dungeonProQuestStatusPaint"then
   anchors=anchors+1;assert(anchors<=40,"anchor recursion exceeded its bounded budget")
   assert(not a.PaintQuestStatus(t,"READY"))
  end
  fields[key]=value
 end
 assert(not a.PaintQuestStatus(t,"ACTIVE"))
 assert(anchors>1 and writes==0)
end)
test("A throwing anchor repair does not clear a newer completed view",function()
 local t=newproxy(true);local fields=plainTexture();local mt=getmetatable(t);local anchors=0
 mt.__index=fields
 mt.__newindex=function(_,key,value)
  if key=="_dungeonProQuestStatusPaint"then
   anchors=anchors+1
   if anchors==1 then assert(a.PaintQuestStatus(t,"READY"));error("retired anchor failed")end
   if anchors==3 then error("repair anchor failed")end
  end
  fields[key]=value
 end
 assert(not a.PaintQuestStatus(t,"ACTIVE"))
 collectgarbage("collect");collectgarbage("collect")
 assert(anchors==3 and t.shown and t.atlas=="UI-QuestIcon-TurnIn-Normal"and t._dungeonProQuestStatusPaint.restore)
end)
print("Quest status retirement: "..total.." checks passed (modeled native setter paths)")
