local total=0
local function check(name,fn)fn();total=total+1;print("PASS "..name)end
local function fresh()
 local a={};assert(loadfile("Core/Namespace.lua"))("DungeonPro",a)
 assert(loadfile("Core/Diagnostics.lua"))("DungeonPro",a);return a
end
local function capture(fn)
 local original=print;local lines={};print=function(line)lines[#lines+1]=line end
 local ok,message=pcall(fn);print=original;assert(ok,message);return lines
end
check("load exports diagnostics without reading native capabilities or printing",function()
 local calls=0;local function forbidden()calls=calls+1;error("load cannot call native capabilities")end
 local originalPrint=print
 CreateFrame,GetLocale,issecretvalue,print=forbidden,forbidden,forbidden,forbidden
 local a,b=fresh(),fresh()
 print=originalPrint
 assert(calls==0 and a.Diagnostics~=b.Diagnostics and a.Diagnostics.Navigation~=b.Diagnostics.Navigation and a.Diagnostics.Minimap~=b.Diagnostics.Minimap)
end)
check("navigation output remains bound to its own addon",function()
 issecretvalue=nil;local a,b=fresh(),fresh()
 local function report(width)return{status="known",frames={hud={status="known",shown=true,visible=true,strata="MEDIUM",level=1,scale=1,left=0,bottom=0,width=width,height=20}}}end
 a.Navigation={ProbeGeometry=function()return report(111)end};b.Navigation={ProbeGeometry=function()return report(222)end}
 local first=capture(a.Diagnostics.Navigation);local second=capture(b.Diagnostics.Navigation)
 assert(#first==3 and #second==3 and first[1]:find(",111.00,20.00)",1,true)and second[1]:find(",222.00,20.00)",1,true))
 b.Clean=function()error("foreign addon called")end
 assert(capture(a.Diagnostics.Navigation)[1]==first[1])
end)
check("minimap output reads only each addon's existing hide preference",function()
 issecretvalue=nil;Minimap=nil;local a,b=fresh(),fresh()
 a.db={minimap={hide=false},private="MUST_NOT_PRINT"};b.db={minimap={hide=true},private="MUST_NOT_PRINT"}
 local first=capture(a.Diagnostics.Minimap);local second=capture(b.Diagnostics.Minimap)
 assert(#first==3 and #second==3 and first[1]=="Dungeon Pro minimap: created=false hide=false"and second[1]=="Dungeon Pro minimap: created=false hide=true")
 for _,lines in ipairs({first,second})do for _,line in ipairs(lines)do assert(not line:find("MUST_NOT_PRINT",1,true))end end
 assert(a.db.minimap.hide==false and b.db.minimap.hide==true)
end)
print("Diagnostics module checks passed: "..total)
