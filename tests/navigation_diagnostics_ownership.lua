local n=0
local function fixture()
 local a={};issecretvalue=function()return false end
 assert(loadfile('Core/Namespace.lua'))('DungeonPro',a)
 assert(loadfile('Core/Diagnostics.lua'))('DungeonPro',a)
 local row={status='known',shown=true,visible=false,strata='MEDIUM',level=4,scale=.75,left=-2.5,bottom=9,width=354,height=104,questText='DO_NOT_PRINT'}
 local dto={status='known',frames={hud=row,planner={status='unknown'},worldMap={status='known',shown=true,displayedMapID=1436}}}
 a.Navigation={ProbeGeometry=function()return dto end}
 return a,dto,row
end
local function output(a)
 local saved,lines=print,{};print=function(s)lines[#lines+1]=s end
 local ok,err=pcall(a.Diagnostics.Navigation);print=saved;assert(ok,err)
 for _,s in ipairs(lines)do assert(not s:find('DO_NOT_PRINT',1,true)and#s<240)end
 return lines
end
local function unknown(lines)assert(#lines==1 and lines[1]=='Dungeon Pro nav: snapshot unknown','retired formatter must print one existing unknown line')end
local function check(name,fn)fn();n=n+1;print('PASS '..name)end
check('exact ordinary whitelist and partial unknowns',function()
 local a=fixture();local lines=output(a)
 assert(lines[1]=='Dungeon Pro nav/hud: shown=true visible=false strata=MEDIUM level=4 scale=0.750 uiUnit=(-2.50,9.00,354.00,104.00)')
 assert(lines[2]=='Dungeon Pro nav/planner: unknown'and lines[3]:find('mapID=1436',1,true))
end)
for _,mode in ipairs({'getter','navigation','Clean','Read','checker','report','row','absence'})do
 check('format retirement '..mode,function()
  local a,dto,row=fixture();local clean=a.Clean;local fired=false;local knowns=0
  a.Clean=function(v,k)
   local result=clean(v,k)
   if v=='known'and k=='string'then knowns=knowns+1 end
   if not fired and knowns==2 then
    fired=true
    if mode=='getter'then a.Navigation.ProbeGeometry=function()return dto end
    elseif mode=='navigation'then a.Navigation={ProbeGeometry=a.Navigation.ProbeGeometry}
    elseif mode=='Clean'then a.Clean=clean
    elseif mode=='Read'then local read=a.Read;a.Read=function(...)return read(...)end
    elseif mode=='checker'then issecretvalue=function()return false end
    elseif mode=='report'then dto.status='unknown'
    elseif mode=='row'then dto.frames.hud={status='unknown'}
    else dto.frames.planner={}end
   end
   return result
  end
  unknown(output(a));assert(fired)
 end)
end
check('late formatter mutation of earlier consumed field',function()
 local a,dto,row=fixture();local clean=a.Clean;local fired=false
 a.Clean=function(v,k)local result=clean(v,k);if not fired and v==104 and k=='number'then fired=true;row.shown=false end;return result end
 unknown(output(a));assert(fired)
end)
check('format callback final-tail source mutation',function()
 local a,dto,row=fixture();local format=string.format;local fired=false
 string.format=function(fmt,value)local s=format(fmt,value);if not fired and value==1436 then fired=true;row.width=353 end;return s end
 local lines=output(a);string.format=format;unknown(lines);assert(fired)
end)
check('restricted and out of range fields keep individual unknowns',function()
 local a,dto,row=fixture();local restricted={};row.shown=restricted;row.left=math.huge;row.width=-1;row.strata='DO_NOT_PRINT'
 issecretvalue=function(v)return rawequal(v,restricted)end
 local lines=output(a);assert(#lines==3 and lines[1]:find('shown=unknown',1,true)and lines[1]:find('strata=unknown',1,true))
end)
check('getter failure and unknown report remain unknown',function()
 local a,dto=fixture();dto.status='unknown';unknown(output(a));a.Navigation.ProbeGeometry=function()error('unavailable')end;unknown(output(a))
end)
check('per-addon state and unused fields remain independent',function()
 local a,dto,row=fixture();local b=fixture();b.Clean=function()error('foreign')end
 row.questText='PRIVATE_NEW';dto.frames.character={name='DO_NOT_PRINT'};assert(#output(a)==3)
end)
check('ordinary NaN stays conservative unknown after later valid arrival',function()
 for _,replacement in ipairs({12,{}})do
 local a,dto,row=fixture();row.left=0/0
 local clean=a.Clean;local fired=false
 a.Clean=function(v,k)local result=clean(v,k);if not fired and v==104 and k=='number'then fired=true;row.left=replacement end;return result end
 local lines=output(a);assert(fired and #lines==3 and lines[1]:find('uiUnit=(unknown,9.00,354.00,104.00)',1,true))
 end
end)
print('Navigation diagnostic ownership: '..n..' PASS')
