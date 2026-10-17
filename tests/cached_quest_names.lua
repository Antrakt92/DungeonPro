local addon,total,secret={},0,{}
assert(loadfile("Core/Namespace.lua"))("DungeonPro",addon)
assert(loadfile("Core/Client.lua"))("DungeonPro",addon)
local title,locale,player,reads
local function reset()
 title,locale,player,reads="Cached native title","ruRU","Player-1",0
 addon.char={texts={}};addon.quests={[123]={id=123,name="Source name"}}
 issecretvalue=function(v)return v==secret end
 GetLocale=function()return locale end
 UnitGUID=function(unit)assert(unit=="player");return player end
 C_QuestLog={GetTitleForQuestID=function(...)assert(select("#",...)==1 and (...)==123);reads=reads+1;return title end,
 RequestLoadQuestByID=function()error("loads forbidden")end,GetSelectedQuest=function()error("selection reads forbidden")end,
 SetSelectedQuest=function()error("selection writes forbidden")end}
 C_Timer={After=function()error("timers forbidden")end}
end
local function check(name,fn)reset();local ok,err=pcall(fn);assert(ok,name..": "..tostring(err));total=total+1;print("PASS "..name)end
check("Available native titles are explicit-ID read-only results without fallback or mutation",function()
 local char,entry=addon.char,addon.quests[123]
 assert(addon.CachedQuestName(123)==title and reads==1)
 assert(addon.char==char and next(char.texts)==nil and addon.quests[123]==entry and entry.name=="Source name")
end)
check("Cold empty invalid and restricted names remain nil without initiating hydration",function()
 for _,v in ipairs({false,secret,""," ",string.rep("x",1025)})do title=v;assert(addon.CachedQuestName(123)==nil)end
 title=nil;assert(addon.CachedQuestName(123)==nil)
 C_QuestLog.GetTitleForQuestID=function()error("unavailable")end;assert(addon.CachedQuestName(123)==nil)
end)
check("Invalid or absent catalogue IDs never query native titles",function()
 for _,v in ipairs({false,secret,0,-1,1.5,"123",math.huge,0/0,9007199254740992})do assert(addon.CachedQuestName(v)==nil)end
 assert(addon.CachedQuestName(nil)==nil);addon.quests[123]=nil;assert(addon.CachedQuestName(123)==nil and reads==0)
end)
check("Missing capabilities and unknown player or locale cannot fabricate a cached title",function()
 for _,v in ipairs({false,true,42,"bad",secret})do reset();C_QuestLog=v;assert(addon.CachedQuestName(123)==nil)end
 reset();C_QuestLog=nil;assert(addon.CachedQuestName(123)==nil)
 for _,v in ipairs({false,secret,""," ",string.rep("x",257)})do reset();player=v;assert(addon.CachedQuestName(123)==nil)end
 reset();player=nil;assert(addon.CachedQuestName(123)==nil)
 for _,v in ipairs({false,secret,""," ",string.rep("x",33)})do reset();locale=v;assert(addon.CachedQuestName(123)==nil)end
end)
check("Native title reads discard player locale definition character and API identity drift",function()
 for mode=1,9 do reset();C_QuestLog.GetTitleForQuestID=function()
  if mode==1 then player="Player-2" elseif mode==2 then locale="deDE" elseif mode==3 then addon.char={}
  elseif mode==4 then addon.quests[123]={id=123,name="New"} elseif mode==5 then C_QuestLog={}
  elseif mode==6 then C_QuestLog.GetTitleForQuestID=function()return"New"end
  elseif mode==7 then UnitGUID=function()return player end elseif mode==8 then GetLocale=function()return locale end
  else issecretvalue=function()return false end end;return title end
  assert(addon.CachedQuestName(123)==nil,"mode"..mode)
 end
end)
check("Final title sanitization cannot bypass raw scope checks",function()
 for mode=1,3 do reset();local checkSecret=issecretvalue
  issecretvalue=function(v)if v==title then
   if mode==1 then C_QuestLog={} elseif mode==2 then addon.quests[123]={id=123} else addon.char={}end
  end;return checkSecret(v)end
  assert(addon.CachedQuestName(123)==nil)
 end
 reset();issecretvalue=function()error("restricted")end;assert(addon.CachedQuestName(123)==nil)
end)
check("Results are not cached across player locale or title changes",function()
 assert(addon.CachedQuestName(123)==title);title="Fresh";locale="deDE";player="Player-2"
 assert(addon.CachedQuestName(123)=="Fresh" and reads==2)
end)
print("Cached quest name modeled checks passed: "..total.." (native client unverified)")
