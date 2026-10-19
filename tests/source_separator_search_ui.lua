-- Equivalent Chinese person-name separators share search keys, not display bytes or ID syntax.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;GetLocale=function()return"enUS"end;C_Timer={After=function()end}
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle()
a.db.locale="zhTW";u.includeUnavailable=true;u.range=false
local cases={
 {1855,5742,"提里奧·弗丁","提里奧‧弗丁","strat"},
 {253092,92753,"艾芭‧皎月","艾芭·皎月","dm"},
}
local counts={};for _,d in ipairs(a.dungeons)do counts[d]=#d.quests end
local hydrates,routes=0,0
C_QuestLog.RequestLoadQuestByID=function()hydrates=hydrates+1 end
local start=a.Navigation.Start;a.Navigation.Start=function(...)routes=routes+1;return start(...)end
local selected,engine,plan,history=u.quest,u.engine,u.currentPlan,u.detailHistory
local function results(query)
 u.search=query;u:RefreshDungeons();local signature,visible={},{}
 for _,row in ipairs(u.cards)do if row:IsShown()then
  local r=row.catalogResult
  signature[#signature+1]=r.dungeon.key..":"..tostring(r.questID)..":"..tostring(r.relatedRootID)
  visible[#visible+1]=row
  assert(r.count==counts[r.dungeon],"equivalent typography cannot add dungeon targets")
 end end
 table.sort(signature)
 assert(u.search==query,"native search input retains original UTF-8 bytes")
 assert(u.quest==selected and u.engine==engine and u.currentPlan==plan and u.detailHistory==history)
 assert(hydrates==0 and routes==0,"search cannot hydrate names or automatically navigate")
 return table.concat(signature,"|"),visible
end
for _,sample in ipairs(cases)do
 local npc,id,reviewed,alternate,key=unpack(sample);local point=a.quests[id].start
 assert(point.npcID==npc and a.SourceName(point)==reviewed,"recorded selected-language source control")
 local canonical=point.name;local signature,rows=results(reviewed);local found=false
 for _,row in ipairs(rows)do if row.catalogResult.dungeon.key==key then
  found=true;assert(row.note.text:find(reviewed,1,true),"source caption uses exact reviewed display separator")
 end end
 assert(found,"actual reviewed source query must find its existing dungeon")
 local other,otherRows=results(alternate)
 assert(other==signature and #otherRows==#rows,"equivalent person-name separators must find identical existing records")
 for _,row in ipairs(otherRows)do if row.catalogResult.dungeon.key==key then
  assert(row.note.text:find(reviewed,1,true)and not row.note.text:find(alternate,1,true),"search key normalization never rewrites displayed source text")
 end end
 assert(point.name==canonical and a.SourceName(point)==reviewed,"canonical/reviewed source bytes remain unchanged")
end
assert(a.SearchFold("艾芭‧皎月")=="艾芭‧皎月"and a.SearchFold("艾芭·皎月")=="艾芭·皎月","case folding remains independent of typography")
assert(a.SearchFold("Épreuve")~="epreuve","accent distinctions remain significant")
assert(a.SearchFold("A\194")==nil and a.SearchFold("\237\160\128")==nil,"malformed UTF-8 remains rejected")
local exact,rows=results("1654");assert(#rows>0)
assert(results(" \t1654\r\n")==exact,"ordinary ASCII whitespace keeps exact numeric grammar")
for _,query in ipairs({"1654·","1654‧","\194\1601654\194\160"})do
 assert(a.SearchQuestID(query)==nil,"separator normalization cannot extend raw numeric-ID syntax")
 local _,shown=results(query);assert(#shown==0)
end
for _,query in ipairs({"提里奧‧弗丁\194","艾芭·皎月\237\160\128","Tirion-Fordring"})do
 local _,shown=results(query);assert(#shown==0,"unrelated punctuation or invalid bytes cannot acquire a match")
end
for d,n in pairs(counts)do assert(#d.quests==n)end
a.Navigation.Start=start
print("Source separator search UI: PASS (two actual reviewed names,both dot directions,display/ID/UTF-8 boundaries)")
