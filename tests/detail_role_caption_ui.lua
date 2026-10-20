-- Selected quest roles and direct contacts preserve source ownership and UI state.
do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local root,pre,story,storyPre,other,foreign=995801,995802,995803,995804,995805,995806
for _,id in ipairs({root,pre,story,storyPre,other,foreign})do a.quests[id]={id=id,name="Role selected "..id,minLevel=1,requirementsKnown=true}end
a.quests[root].requires={{ids={pre}}};a.quests[root].storyline={pre,root,story};a.quests[story].requires={{ids={storyPre}}};a.quests[other].requires={{ids={story}}}
local d={key="role",name="Role",minLevel=1,maxLevel=60,quests={root,other},coverage="partial",sharedQuests={foreign},completionQuests={foreign}};a.dungeons={d}
a.Context=function()return {level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
local function draw(selected,group)u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,selected,group,d;u:Refresh()end
local function caption(key)
 local found,title=false,false
 for _,fs in ipairs(u.details)do if fs:IsShown()then if fs:GetText()==a.L(key)then found=true end;if fs:GetText()=="Role selected "..u.quest then title=true end end end
 assert(found and title,"right role caption and selected title: "..key)
end
draw(story,root);caption("STORY_SHORT")
draw(pre,root);caption("REQUIRED_STEP_SHORT")
draw(storyPre,root);caption("STORY_SHORT")
draw(root,root);caption("DUNGEON_QUEST_SHORT")
draw(other,root);caption("DUNGEON_QUEST_SHORT")
draw(story,other);caption("REQUIRED_STEP_SHORT")
draw(foreign,foreign);local m=u.DetailRoleScope and u:DetailRoleScope(foreign,d,u.engine);assert(m==nil,"root equality/shared/completion cannot invent membership")
draw(story,root);local m=assert(u:DetailRoleScope(story,d,u.engine));u.questTreeRoot=other;assert(not m.rawCurrent() and not m.current());u.questTreeRoot=root
m=assert(u:DetailRoleScope(story,d,u.engine));d.quests[3]=story;assert(not m.rawCurrent());d.quests[3]=nil
m=assert(u:DetailRoleScope(story,d,u.engine));a.quests[root].requires[1].ids[1]=foreign;assert(not m.rawCurrent());a.quests[root].requires[1].ids[1]=pre
local roots=d.quests;d.quests={[1]=root,[3]=other};assert(not u:DetailRoleScope(story,d,u.engine));d.quests=roots
local secret={};local checker=issecretvalue;issecretvalue=function(v)return rawequal(v,secret)end;d.quests[1]=secret;assert(not u:DetailRoleScope(story,d,u.engine));d.quests[1]=root;issecretvalue=checker
print("PASS selected title retained; membership beats tree; true prerequisite/story/story-owned prerequisite; group root scoped; unknown no guessed role; source/group/sparse/restricted proof retirement")

end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local root,pre,story,storyPre,other,foreign=995801,995802,995803,995804,995805,995806
for _,id in ipairs({root,pre,story,storyPre,other,foreign})do a.quests[id]={id=id,name="Role selected "..id,minLevel=1,requirementsKnown=true}end
a.quests[root].requires={{ids={pre}}};a.quests[root].storyline={pre,root,story};a.quests[story].requires={{ids={storyPre}}};a.quests[other].requires={{ids={story}}}
local d={key="role",name="Role",minLevel=1,maxLevel=60,quests={root,other},coverage="partial",sharedQuests={foreign},completionQuests={foreign}};a.dungeons={d}
a.Context=function()return {level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
local function draw(selected,group)u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,selected,group,d;u:Refresh()end
local function caption(key)
 local found,title=false,false
 for _,fs in ipairs(u.details)do if fs:IsShown()then if fs:GetText()==a.L(key)then found=true end;if fs:GetText()=="Role selected "..u.quest then title=true end end end
 assert(found and title,"right role caption and selected title: "..key)
end
draw(pre,root)
local actual=a.QuestTree.Build
for _,field in ipairs({"requirementScope","root"})do
 local captured
 a.QuestTree.Build=function(...)local t=actual(...);captured=t;return t end
 local m=assert(u:DetailRoleScope(pre,d,u.engine));local node;for _,v in ipairs(captured)do if v.id==pre then node=v end end;assert(node)
 node[field]=field=="root"and true or"story";assert(not m.rawCurrent() and not m.current(),"nil returned-node field is guarded: "..field)
 a.QuestTree.Build=actual
end
for _,bad in ipairs({"not-a-scope",false,7,{}})do
 a.QuestTree.Build=function(...)local t=actual(...);for _,v in ipairs(t)do if v.id==pre then v.requirementScope=bad end end;return t end
 assert(not u:DetailRoleScope(pre,d,u.engine),"malformed scope cannot become prerequisite")
 a.QuestTree.Build=actual
end
local m=assert(u:DetailRoleScope(pre,d,u.engine));m.current=function()return true end;assert(not m.rawCurrent(),"private model capability replacement retires")
print("PASS absent returned-node fields/current capability guarded; malformed optional scope stays unknown")

end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local root,pre,story,storyPre,other,foreign=995801,995802,995803,995804,995805,995806
for _,id in ipairs({root,pre,story,storyPre,other,foreign})do a.quests[id]={id=id,name="Role selected "..id,minLevel=1,requirementsKnown=true}end
a.quests[root].requires={{ids={pre}}};a.quests[root].storyline={pre,root,story};a.quests[story].requires={{ids={storyPre}}};a.quests[other].requires={{ids={story}}}
local d={key="role",name="Role",minLevel=1,maxLevel=60,quests={root,other},coverage="partial",sharedQuests={foreign},completionQuests={foreign}};a.dungeons={d}
a.Context=function()return {level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
local function draw(selected,group)u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,selected,group,d;u:Refresh()end
local function caption(key)
 local found,title=false,false
 for _,fs in ipairs(u.details)do if fs:IsShown()then if fs:GetText()==a.L(key)then found=true end;if fs:GetText()=="Role selected "..u.quest then title=true end end end
 assert(found and title,"right role caption and selected title: "..key)
end
draw(story,root);caption("STORY_SHORT")
draw(pre,root);caption("REQUIRED_STEP_SHORT")
draw(storyPre,root);caption("STORY_SHORT")
draw(root,root);caption("DUNGEON_QUEST_SHORT")
draw(other,root);caption("DUNGEON_QUEST_SHORT")
draw(story,other);caption("REQUIRED_STEP_SHORT")
draw(foreign,foreign);local m=u.DetailRoleScope and u:DetailRoleScope(foreign,d,u.engine);assert(m==nil,"root equality/shared/completion cannot invent membership")
draw(story,root);local m=assert(u:DetailRoleScope(story,d,u.engine));u.questTreeRoot=other;assert(not m.rawCurrent() and not m.current());u.questTreeRoot=root
m=assert(u:DetailRoleScope(story,d,u.engine));d.quests[3]=story;assert(not m.rawCurrent());d.quests[3]=nil
m=assert(u:DetailRoleScope(story,d,u.engine));a.quests[root].requires[1].ids[1]=foreign;assert(not m.rawCurrent());a.quests[root].requires[1].ids[1]=pre
local roots=d.quests;d.quests={[1]=root,[3]=other};assert(not u:DetailRoleScope(story,d,u.engine));d.quests=roots
local secret={};local checker=issecretvalue;issecretvalue=function(v)return rawequal(v,secret)end;d.quests[1]=secret;assert(not u:DetailRoleScope(story,d,u.engine));d.quests[1]=root;issecretvalue=checker
print("PASS selected title retained; membership beats tree; true prerequisite/story/story-owned prerequisite; group root scoped; unknown no guessed role; source/group/sparse/restricted proof retirement")

draw(root,root);u.quest=story
local oldL=a.L;local fired=false
a.L=function(key)if key=="STORY_SHORT"and not fired then fired=true;a.locales.deDE.STORY_SHORT="Unrelated inactive mutation"end return oldL(key)end
u:RefreshDetail();assert(fired,"rightrolelocalizer callback exercised");caption("STORY_SHORT");print("PASS new selectedStory painted after unrelated German dictionary changed during Englishrole localization")

end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local root,pre,story,storyPre,other,foreign=995801,995802,995803,995804,995805,995806
for _,id in ipairs({root,pre,story,storyPre,other,foreign})do a.quests[id]={id=id,name="Role selected "..id,minLevel=1,requirementsKnown=true}end
a.quests[root].requires={{ids={pre}}};a.quests[root].storyline={pre,root,story};a.quests[story].requires={{ids={storyPre}}};a.quests[other].requires={{ids={story}}}
local d={key="role",name="Role",minLevel=1,maxLevel=60,quests={root,other},coverage="partial",sharedQuests={foreign},completionQuests={foreign}};a.dungeons={d}
a.Context=function()return {level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
local function draw(selected,group)u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,selected,group,d;u:Refresh()end
local function caption(key)
 local found,title=false,false
 for _,fs in ipairs(u.details)do if fs:IsShown()then if fs:GetText()==a.L(key)then found=true end;if fs:GetText()=="Role selected "..u.quest then title=true end end end
 assert(found and title,"right role caption and selected title: "..key)
end
draw(story,root);caption("STORY_SHORT")
draw(pre,root);caption("REQUIRED_STEP_SHORT")
draw(storyPre,root);caption("STORY_SHORT")
draw(root,root);caption("DUNGEON_QUEST_SHORT")
draw(other,root);caption("DUNGEON_QUEST_SHORT")
draw(story,other);caption("REQUIRED_STEP_SHORT")
draw(foreign,foreign);local m=u.DetailRoleScope and u:DetailRoleScope(foreign,d,u.engine);assert(m==nil,"root equality/shared/completion cannot invent membership")
draw(story,root);local m=assert(u:DetailRoleScope(story,d,u.engine));u.questTreeRoot=other;assert(not m.rawCurrent() and not m.current());u.questTreeRoot=root
m=assert(u:DetailRoleScope(story,d,u.engine));d.quests[3]=story;assert(not m.rawCurrent());d.quests[3]=nil
m=assert(u:DetailRoleScope(story,d,u.engine));a.quests[root].requires[1].ids[1]=foreign;assert(not m.rawCurrent());a.quests[root].requires[1].ids[1]=pre
local roots=d.quests;d.quests={[1]=root,[3]=other};assert(not u:DetailRoleScope(story,d,u.engine));d.quests=roots
local secret={};local checker=issecretvalue;issecretvalue=function(v)return rawequal(v,secret)end;d.quests[1]=secret;assert(not u:DetailRoleScope(story,d,u.engine));d.quests[1]=root;issecretvalue=checker
print("PASS selected title retained; membership beats tree; true prerequisite/story/story-owned prerequisite; group root scoped; unknown no guessed role; source/group/sparse/restricted proof retirement")
local function hasSelectedTitle()for _,fs in ipairs(u.details)do if fs:IsShown()and fs:GetText()=="Role selected "..story then return true end end end
local originalL=a.L;local de=a.locales.deDE;local en=a.locales.enUS;local originalDE,originalEN=de.STORY_SHORT,en.STORY_SHORT
-- With an actual German own value, the English reserve is not read.
a.db.locale="deDE";draw(root,root);u.quest=story;local fired=false
a.L=function(key)if key=="STORY_SHORT"and not fired then fired=true;en.STORY_SHORT="Unused English mutation"end;return originalL(key)end
u:RefreshDetail();assert(fired);caption("STORY_SHORT");a.L=originalL;en.STORY_SHORT=originalEN
-- A consulted English value changing during localization must retire this new selection.
a.db.locale="enUS";draw(root,root);u.quest=story;fired=false
a.L=function(key)if key=="STORY_SHORT"and not fired then fired=true;en.STORY_SHORT="Changed active label"end;return originalL(key)end
u:RefreshDetail();assert(fired and not hasSelectedTitle(),"active dictionary change cannot publish mixed selected title");a.L=originalL;en.STORY_SHORT=originalEN
-- A missing German key really consults English and owns its value.
a.db.locale="deDE";de.STORY_SHORT=nil;draw(root,root);u.quest=story;fired=false
a.L=function(key)if key=="STORY_SHORT"and not fired then fired=true;en.STORY_SHORT="Changed consulted fallback"end;return originalL(key)end
u:RefreshDetail();assert(fired and not hasSelectedTitle(),"consulted fallback changes retire");a.L=originalL;de.STORY_SHORT=originalDE;en.STORY_SHORT=originalEN
print("PASS selected-language own value ignores unused English; active locale and genuinely consulted fallback mutations retire new selection")

end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local root,pre,story,storyPre,other,foreign=995801,995802,995803,995804,995805,995806
for _,id in ipairs({root,pre,story,storyPre,other,foreign})do a.quests[id]={id=id,name="Role selected "..id,minLevel=1,requirementsKnown=true}end
a.quests[root].requires={{ids={pre}}};a.quests[root].storyline={pre,root,story};a.quests[story].requires={{ids={storyPre}}};a.quests[other].requires={{ids={story}}}
local d={key="role",name="Role",minLevel=1,maxLevel=60,quests={root,other},coverage="partial",sharedQuests={foreign},completionQuests={foreign}};a.dungeons={d}
a.Context=function()return {level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
local function draw(selected,group)u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,selected,group,d;u:Refresh()end
local function caption(key)
 local found,title=false,false
 for _,fs in ipairs(u.details)do if fs:IsShown()then if fs:GetText()==a.L(key)then found=true end;if fs:GetText()=="Role selected "..u.quest then title=true end end end
 assert(found and title,"right role caption and selected title: "..key)
end
draw(story,root);caption("STORY_SHORT")
draw(pre,root);caption("REQUIRED_STEP_SHORT")
draw(storyPre,root);caption("STORY_SHORT")
draw(root,root);caption("DUNGEON_QUEST_SHORT")
draw(other,root);caption("DUNGEON_QUEST_SHORT")
draw(story,other);caption("REQUIRED_STEP_SHORT")
draw(foreign,foreign);local m=u.DetailRoleScope and u:DetailRoleScope(foreign,d,u.engine);assert(m==nil,"root equality/shared/completion cannot invent membership")
draw(story,root);local m=assert(u:DetailRoleScope(story,d,u.engine));u.questTreeRoot=other;assert(not m.rawCurrent() and not m.current());u.questTreeRoot=root
m=assert(u:DetailRoleScope(story,d,u.engine));d.quests[3]=story;assert(not m.rawCurrent());d.quests[3]=nil
m=assert(u:DetailRoleScope(story,d,u.engine));a.quests[root].requires[1].ids[1]=foreign;assert(not m.rawCurrent());a.quests[root].requires[1].ids[1]=pre
local roots=d.quests;d.quests={[1]=root,[3]=other};assert(not u:DetailRoleScope(story,d,u.engine));d.quests=roots
local secret={};local checker=issecretvalue;issecretvalue=function(v)return rawequal(v,secret)end;d.quests[1]=secret;assert(not u:DetailRoleScope(story,d,u.engine));d.quests[1]=root;issecretvalue=checker
print("PASS selected title retained; membership beats tree; true prerequisite/story/story-owned prerequisite; group root scoped; unknown no guessed role; source/group/sparse/restricted proof retirement")
a.db.locale="deDE";draw(root,root);u.quest=story;a.locales.deDE.STORY_SHORT=false
local baseL=a.L;local fired=false;a.L=function(key)if key=="STORY_SHORT"then fired=true end;return baseL(key)end
u:RefreshDetail();assert(fired,"false selected slot consults English fallback");caption("STORY_SHORT");print("PASS false selected locale label uses actual English fallback")

end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle()
local id=995901;a.quests[id]={id=id,name="Restricted roots",minLevel=1,requirementsKnown=true}
local secret={};local checkerEqual=rawequal;issecretvalue=function(v)return checkerEqual(v,secret)end
local d={key="own",name="Own",minLevel=1,maxLevel=60,quests={id},coverage="partial"};u.quest,u.dungeon=id,d;u.engine={}
local model=assert(u:DetailRoleScope(id,d,u.engine));d.quests[1]=secret
local equal,attempts=rawequal,0;rawequal=function(x,y)if equal(x,secret)or equal(y,secret)then attempts=attempts+1;error("restricted compared")end;return equal(x,y)end
local ok,result=pcall(model.current);rawequal=equal
assert(ok and result==false and attempts==0,"full retained proof rejects restricted live roots before comparison")
print("PASS live restricted roots rejected without comparison")

end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle()
local id=995901;a.quests[id]={id=id,name="Restricted roots",minLevel=1,requirementsKnown=true}
local secret={};local d={key="own",name="Own",minLevel=1,maxLevel=60,quests={secret},coverage="partial"};u.quest,u.dungeon=id,d;u.engine={quests=a.quests,context={},Current=function()return true end}
local eq=rawequal;local attempts=0
issecretvalue=function(v)return eq(v,secret)end
rawequal=function(x,y)if eq(x,secret)or eq(y,secret)then attempts=attempts+1;error("secret root compared")end;return eq(x,y)end
local ok,m=pcall(u.DetailRoleScope,u,id,d,u.engine);rawequal=eq
print("ROLE_RESTRICTED_ROOT",ok,m==nil,attempts)
assert(ok and m==nil and attempts==0,"restricted root compared before rejection")

end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle()
local root,story=995911,995912;a.quests[root]={id=root,name="Root",minLevel=1,requirementsKnown=true,storyline={root,story}};a.quests[story]={id=story,name="Story",minLevel=1,requirementsKnown=true}
local d={key="own",name="Own",minLevel=1,maxLevel=60,quests={root},coverage="partial"};u.quest,u.dungeon,u.questTreeRoot,u.questTreeDungeon=story,d,root,d
local result;local mutated=0;u.engine={quests=a.quests,context={},choices={},State=function(_,id)return {status="AVAILABLE"}end,Current=function()
 if result then for _,n in ipairs(result)do if n.id==story then n.relation="required";n.requirementScope=nil;n.root=nil;mutated=mutated+1 end end end
 return true
end}
local original=a.QuestTree.Build;a.QuestTree.Build=function(...)result=original(...);return result end
local m=u:DetailRoleScope(story,d,u.engine)
print("ROLE_PRE_SNAPSHOT_NODE",mutated,m and m.key)
assert(not m or m.key=="STORY_SHORT","Tree current callback cannot replace initial story relation with required")

end

print("Selected quest role caption checks passed")
