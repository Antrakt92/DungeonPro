local total=0
local function check(name,fn)fn();total=total+1;print("PASS "..name)end
local function fresh()
 local a={};assert(loadfile("Core/Namespace.lua"))("DungeonPro",a)
 assert(loadfile("Core/DungeonArt.lua"))("DungeonPro",a);return a
end
check("load is inert with unavailable native capabilities",function()
 local calls=0;local function forbidden()calls=calls+1;error("native reads during load")end
 issecretvalue,GetLFDChoiceOrder,GetLFGDungeonInfo,EJ_GetInstanceInfo=forbidden,forbidden,forbidden,forbidden
 C_EncounterJournal=setmetatable({},{__index=forbidden})
 local a=fresh();assert(type(a.DungeonArt)=="function"and type(a.PaintDungeonArt)=="function"and calls==0)
end)
check("two addon instances cache finder observations independently",function()
 issecretvalue=function()return false end;C_EncounterJournal,EJ_GetInstanceInfo=nil,nil
 local scans=0;GetLFDChoiceOrder=function()scans=scans+1;return{1}end
 GetLFGDungeonInfo=function()local v={};v[11],v[22]=131833,36;return unpack(v,1,22)end
 local a,b=fresh(),fresh();assert(a.DungeonArt({instanceID=36})==131833 and a.DungeonArt({instanceID=36})==131833 and scans==1)
 assert(b.DungeonArt({instanceID=36})==131833 and scans==2)
 a.Clean=function()error("wrong addon closure")end
 assert(b.DungeonArt({instanceID=36})==131833 and scans==2)
end)
check("per-instance paint tokens preserve nested newer winner",function()
 for i=1,2 do
  issecretvalue=function()return false end;C_EncounterJournal,EJ_GetInstanceInfo,GetLFDChoiceOrder,GetLFGDungeonInfo=nil,nil,nil,nil
  local a=fresh();local fired=false
  local t={Show=function(s)s.shown=true end,Hide=function(s)s.shown=false end,SetTexCoord=function()end}
  t.SetTexture=function(s,v)s.texture=v;if not fired then fired=true;assert(a.PaintDungeonArt(s,{art={fileID=7963781,gameMapID=3065}},"overview"))end;return true end
  local ok,k=a.PaintDungeonArt(t,{art={fileID=131833,gameMapID=36}},"overview")
  assert(fired and ok==false and k==nil and t.texture==7963781 and t.shown)
 end
end)
print("Dungeon art module checks passed: "..total)
