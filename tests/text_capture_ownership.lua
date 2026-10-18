local total = 0
local function fixture()
    local addon = {}
    assert(loadfile("Core/Namespace.lua"))("DungeonPro",addon)
    assert(loadfile("Core/Client.lua"))("DungeonPro",addon)
    addon.char,addon.quests={texts={}},{[65]={id=65}}
    GetLocale=function()return"enUS"end
    GetQuestID=function()return 65 end
    issecretvalue=function()return false end
    return addon
end
local function test(name,fn)
    local ok,err=pcall(fn);assert(ok,name..": "..tostring(err));total=total+1;print("PASS "..name)
end
test("Final capability sanitization cannot overwrite a newer same-quest capture",function()
    local addon=fixture();local armed,fired,count=false,false,0
    GetQuestText=function()armed=true;return fired and"New captured text"or"Old captured text"end
    issecretvalue=function(value)
        if armed and value==GetQuestText and not fired then
            count=count+1
            if count==2 then fired=true;addon.CaptureQuestText();assert(addon.char.texts[65].text=="New captured text")end
        end
        return false
    end
    addon.CaptureQuestText()
    assert(fired and addon.char.texts[65].text=="New captured text","old capture replaced the newer persisted record")
end)
test("Late sanitizers cannot persist into a replaced character destination or source",function()
    for _,kind in ipairs({"character","texts","catalogue","definition","textGetter","capture","read","clean"})do
        local addon=fixture();local destination=addon.char.texts
        local armed,fired,count=false,false,0
        local native=function()armed=true;return"Old text"end;GetQuestText=native
        issecretvalue=function(value)
            if armed and value==native and not fired then
                count=count+1
                if count==2 then
                    fired=true
                    if kind=="character"then addon.char={texts={}}
                    elseif kind=="texts"then addon.char.texts={}
                    elseif kind=="catalogue"then addon.quests={}
                    elseif kind=="definition"then addon.quests[65]={id=65}
                    elseif kind=="textGetter"then GetQuestText=function()return"New text"end
                    elseif kind=="capture"then addon.CaptureQuestText=function()end
                    elseif kind=="read"then addon.Read=function()return nil end
                    else addon.Clean=function()return nil end end
                end
            end
            return false
        end
        addon.CaptureQuestText();assert(fired and destination[65]==nil,kind)
    end
end)
test("Normal offered captures retain exact destination and reject empty replacement text",function()
    local addon=fixture();local text="Valid offered text";GetQuestText=function()return text end
    addon.CaptureQuestText();local record=addon.char.texts[65]
    assert(record.text==text and record.locale=="enUS")
    text="";addon.CaptureQuestText();assert(addon.char.texts[65]==record)
end)
test("Whitespace-only selected-log prose cannot erase a verified saved description",function()
    local addon=fixture();addon.L=function(key)return key end
    local prior={text="Verified prose",locale="enUS"};addon.char.texts[65]=prior
    C_QuestLog={GetSelectedQuest=function()return 65 end,GetLogIndexForQuestID=function()return 7 end}
    for _,text in ipairs({"", " \t\r\n "})do
        GetQuestLogQuestText=function()return text end
        assert(addon.Description(65)=="Verified prose"and addon.char.texts[65]==prior,
            "blank native prose replaced the verified saved record")
    end
    GetQuestLogQuestText=nil;addon.char.texts[65]={text=" \n\t ",locale="enUS"}
    assert(addon.Description(65)=="NO_TEXT","legacy whitespace must remain missing prose")
    local multiline=" \nReal multiline\nquest narrative.\n "
    GetQuestLogQuestText=function()return multiline end
    assert(addon.Description(65)==multiline and addon.char.texts[65].text==multiline,
        "valid multiline prose must remain exact")
end)
test("Selected-log read cannot overwrite a newer same-quest offered capture",function()
    local addon=fixture();addon.L=function(key)return key end
    C_QuestLog={GetSelectedQuest=function()return 65 end,GetLogIndexForQuestID=function()return 7 end}
    GetQuestText=function()return"New offered prose"end
    GetQuestLogQuestText=function()
        addon.CaptureQuestText();assert(addon.char.texts[65].text=="New offered prose")
        return"Old selected prose"
    end
    assert(addon.Description(65)=="New offered prose"and addon.char.texts[65].text=="New offered prose")
end)
test("Last cache sanitizer cannot return a replaced record or mutated prose",function()
    for _,kind in ipairs({"record","text","character","texts"})do
        local addon=fixture();addon.L=function(key)return key end
        C_QuestLog={}
        local record={text="Old cached prose",locale="enUS"};addon.char.texts[65]=record
        local visits=0
        issecretvalue=function(value)
            if value==record then
                visits=visits+1
                if visits==2 then
                    if kind=="record"then addon.char.texts[65]={text="New cached prose",locale="enUS"}
                    elseif kind=="text"then record.text="New cached prose"
                    elseif kind=="character"then addon.char={texts={}}
                    else addon.char.texts={}end
                end
            end
            return false
        end
        assert(addon.Description(65)~="Old cached prose",kind.." returned an expired cached record")
        assert(visits==2)
    end
end)
print("Text capture ownership: "..total.." checks passed")
