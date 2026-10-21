-- Artwork component publication; the compact dungeon overview does not invoke this painter.
local total = 0
local function check(name, test)
    if arg and arg[1] and arg[1] ~= name then return end
    test(); total = total + 1; print("PASS " .. name)
end
local a={}
assert(loadfile("Core/Namespace.lua"))("DungeonPro",a)
assert(loadfile("Core/Client.lua"))("DungeonPro",a)
assert(loadfile("Core/DungeonArt.lua"))("DungeonPro",a)
local function canvas()
 return {shows=0,SetTexture=function(self,v)self.texture=v;return true end,
 SetTexCoord=function(self,...)self.coords={...}end,
 Show=function(self)self.shows=self.shows+1;self.shown=true end,
 Hide=function(self)self.shown=false end}
end
local dungeon={instanceID=36,art={fileID=131833,gameMapID=36}}
local function pure(name,fn)
 issecretvalue=function()return false end
 C_EncounterJournal,EJ_GetInstanceInfo,GetLFDChoiceOrder,GetLFGDungeonInfo=nil,nil,nil,nil
 fn();total=total+1;print("PASS "..name)
end
pure("omitted and explicit nil preserve legacy Show",function()
 for i=1,2 do local t=canvas();local ok,k
  if i==1 then ok,k=a.PaintDungeonArt(t,dungeon,"overview")else ok,k=a.PaintDungeonArt(t,dungeon,"overview",nil)end
  assert(ok and k=="art"and t.shows==1 and t.texture==131833)
 end
end)
pure("invalid optional callbacks never fall back to raw Show",function()
 for _,v in ipairs({false,true,1,"show",{}})do
  local t=canvas();local ok,k,ratio=a.PaintDungeonArt(t,dungeon,"overview",v)
  assert(ok==false and k==nil and ratio==nil and t.shows==0 and t.texture==nil)
 end
end)
pure("restricted callback or failed classification never reaches paint",function()
 local fn=function()error("restricted callback invoked")end
 for _,mode in ipairs({"restricted","throw"})do
  issecretvalue=function(v)if v==fn then if mode=="throw"then error("classifier unavailable")end;return true end;return false end
  local t=canvas();assert(a.PaintDungeonArt(t,dungeon,"overview",fn)==false and t.shows==0 and t.texture==nil)
 end
end)
pure("rejected callback results have no direct fallback or positive kind",function()
 for _,mode in ipairs({"false","nil","string","number","throw"})do
  local t=canvas();local calls=0
  local ok,k,ratio=a.PaintDungeonArt(t,dungeon,"overview",function(texture)
   assert(texture==t);calls=calls+1
   if mode=="throw"then error("unavailable")elseif mode=="false"then return false elseif mode=="string"then return "true"elseif mode=="number"then return 1 end
  end)
  assert(ok==false and k==nil and ratio==nil and calls==1 and t.shows==0)
 end
end)
pure("accepted owned writer runs exactly once",function()
 local t=canvas();local calls=0
 local ok,k=a.PaintDungeonArt(t,dungeon,"overview",function(texture)assert(texture==t);calls=calls+1;texture:Show();return true end)
 assert(ok and k=="art"and calls==1 and t.shows==1 and t.texture==131833 and t.coords[1]==0)
end)
pure("rejected writer cannot abandon a newer paint",function()
 for _,mode in ipairs({"false","throw"})do
  local t=canvas()
  local ok,k=a.PaintDungeonArt(t,dungeon,"overview",function(texture)
   assert(a.PaintDungeonArt(texture,{},"overview"))
   if mode=="throw"then error("old writer retired")end;return false
  end)
  assert(ok==false and k==nil and t.texture=="Interface\\Icons\\INV_Misc_Map_01"and t.shown and t.shows==1)
 end
end)
pure("newer token during owned Show remains winner",function()
 local t=canvas();local ok,k=a.PaintDungeonArt(t,dungeon,"overview",function(texture)
  assert(a.PaintDungeonArt(texture,{},"overview"));return true
 end)
 assert(ok==false and k==nil and t.texture=="Interface\\Icons\\INV_Misc_Map_01"and t.shown and t.shows==1)
end)
pure("checker replacement during callback classification rejects supplied owner",function()
 local fn=function()error("must not run")end
 issecretvalue=function(v)if v==fn then issecretvalue=function()return false end end;return false end
 local t=canvas();assert(a.PaintDungeonArt(t,dungeon,"overview",fn)==false and t.shows==0 and t.texture==nil)
end)
print("Owned art painter checks passed: "..total)

pure("restricted callback acknowledgement cannot authorize success",function()
 local result={};issecretvalue=function(v)return v==result end
 local t=canvas();local ok,k=a.PaintDungeonArt(t,dungeon,"overview",function()return result end)
 assert(ok==false and k==nil and t.shows==0)
end)
print("Owned art painter FINAL checks passed: "..total)

for _,optional in ipairs({false,true})do
 pure("first classifier newer paint wins "..tostring(optional),function()
  local t=canvas();local armed=true;local nested=false
  local newer={art={fileID=7963781,gameMapID=3065}}
  issecretvalue=function()
   if armed then armed=false;assert(a.PaintDungeonArt(t,newer,"overview"));nested=true end
   return false
  end
  local writer=optional and function(texture)texture:Show();return true end or nil
  local ok,k=a.PaintDungeonArt(t,dungeon,"overview",writer)
  assert(nested and not armed and ok==false and k==nil and t.texture==7963781 and t.shown and t.shows==1,
   "earlier invocation cannot assign ownership after a callback published a newer paint")
 end)
end
pure("nil callback classification cannot adopt replacement checker",function()
 local t=canvas();local armed=true
 issecretvalue=function()
  if armed then armed=false;issecretvalue=function()return false end end
  return false
 end
 local ok,k=a.PaintDungeonArt(t,dungeon,"overview")
 assert(not armed and ok==false and k==nil and t.texture==nil and t.shows==0)
end)
print("Owned art painter classification checks passed: "..total)

pure("checker replacement during callback Clean rejects supplied owner",function()
 local fn=function()error("retired owner must not run")end
 local calls=0
 issecretvalue=function(v)
  if v==fn then calls=calls+1;if calls==2 then issecretvalue=function()return false end end end
  return false
 end
 local t=canvas();local ok,k=a.PaintDungeonArt(t,dungeon,"overview",fn)
 assert(calls==2 and ok==false and k==nil and t.texture==nil and t.shows==0)
end)
print("Owned art painter FINAL repaired checks passed: "..total)
