local total=0
local function fixture()
    local addon={}
    issecretvalue=function()return false end
    GetLocale=function()return "enUS"end
    assert(loadfile("Core/Namespace.lua"))("DungeonPro",addon)
    assert(loadfile("Database/Catalog.lua"))("DungeonPro",addon)
    assert(loadfile("Database/NameTranslations.lua"))("DungeonPro",addon)
    assert(loadfile("Core/Client.lua"))("DungeonPro",addon)
    addon.char,addon.db={},{locale="ruRU"}
    C_QuestLog=nil
    return addon
end
local function current()return true end
local function count(t)local n=0 for _ in pairs(t)do n=n+1 end return n end
local function test(name,fn)
    local ok,message=pcall(fn,fixture());assert(ok,name..": "..tostring(message))
    total=total+1;print("PASS "..name)
end
test("TOC title dictionaries remain ordinary empty tables until a selected locale is read",function(a)
    assert(getmetatable(a.nameTranslations)==nil and next(a.nameTranslations)==nil)
    assert(count(a.nameTranslationFactories.loaders)==9)
    assert(a.CachedQuestName(166)=="Братство Справедливости")
    local ru=a.nameTranslations.ruRU
    assert(ru and count(a.nameTranslations)==1)
    for _=1,20 do assert(a.CachedQuestName(166)=="Братство Справедливости")end
    assert(a.nameTranslations.ruRU==ru and count(a.nameTranslations)==1)
    assert(a.nameTranslationFactories.loaders.ruRU==nil)
    a.db.locale="deDE";assert(a.CachedQuestName(166)=="Die Bruderschaft der Defias")
    assert(count(a.nameTranslations)==2 and a.nameTranslations.ruRU==ru)
end)
test("Explicit English selection does not construct unused translated dictionaries",function(a)
    a.db.locale="enUS";a.QuestName(166);a.CachedQuestName(166)
    assert(next(a.nameTranslations)==nil)
end)
test("Each visited dictionary materializes once including full Italian coverage",function(a)
    for locale,loader in pairs(a.nameTranslationFactories.loaders)do
        local calls=0
        a.nameTranslationFactories.loaders[locale]=function()calls=calls+1;return loader()end
        local first=assert(a.GetNameTranslations(locale,current))
        assert(a.GetNameTranslations(locale,current)==first and calls==1)
        assert(a.nameTranslationFactories.loaders[locale]==nil)
    end
    assert(count(a.nameTranslations)==9 and count(a.nameTranslations.itIT.quests)==count(a.quests) and count(a.nameTranslations.itIT.dungeons)==#a.dungeons)
    assert(next(a.nameTranslationFactories.loaders)==nil)
end)
test("Plain replacement dictionaries preserve existing table semantics without factory writes",function(a)
    a.nameTranslations={ruRU={quests={[166]={source="The Defias Brotherhood",name="Replacement"}},dungeons={}}}
    assert(a.CachedQuestName(166)=="Replacement")
    assert(a.GetNameTranslations("deDE",current)==nil and a.nameTranslations.deDE==nil)
end)
test("Throwing malformed and recursively entered factories cannot poison the cache",function(a)
    local loaders=a.nameTranslationFactories.loaders
    local original=loaders.ruRU
    for _,bad in ipairs({function()error("cold")end,function()return false end,function()return {}end})do
        loaders.ruRU=bad;assert(a.GetNameTranslations("ruRU",current)==nil and a.nameTranslations.ruRU==nil and loaders.ruRU==bad)
    end
    loaders.ruRU=function()
        assert(a.GetNameTranslations("ruRU",current)==nil)
        return original()
    end
    assert(a.GetNameTranslations("ruRU",current))
end)
test("Expired locale ownership cannot publish a detached factory result",function(a)
    local original=a.nameTranslationFactories.loaders.ruRU
    a.nameTranslationFactories.loaders.ruRU=function()a.db.locale="deDE";return original()end
    assert(a.CachedQuestName(166)==nil and a.nameTranslations.ruRU==nil)
    assert(a.CachedQuestName(166)=="Die Bruderschaft der Defias" and count(a.nameTranslations)==1)
end)
test("Factory reentry preserves a newer root dictionary loader and provider",function(a)
    for mode=1,4 do
        a=fixture()
        local root,registry=a.nameTranslations,a.nameTranslationFactories
        local original=registry.loaders.ruRU
        local newer={quests={},dungeons={}}
        registry.loaders.ruRU=function()
            if mode==1 then a.nameTranslations={ruRU=newer}
            elseif mode==2 then root.ruRU=newer
            elseif mode==3 then registry.loaders.ruRU=function()return newer end
            else a.GetNameTranslations=function()return newer end end
            return original()
        end
        local getter=a.GetNameTranslations
        assert(getter("ruRU",current)==nil)
        if mode==1 then assert(a.nameTranslations.ruRU==newer and root.ruRU==nil)
        elseif mode==2 then assert(root.ruRU==newer)
        else assert(root.ruRU==nil)end
    end
end)
test("Restricted factories and failed caller ownership cannot allocate locale tables",function(a)
    local registry=a.nameTranslationFactories
    local calls=0;registry.loaders.ruRU=function()calls=calls+1;return{quests={},dungeons={}}end
    assert(a.GetNameTranslations("ruRU",function()return false end)==nil and calls==0)
    local restricted=registry.loaders.ruRU
    issecretvalue=function(value)return value==restricted end
    assert(a.GetNameTranslations("ruRU",current)==nil and calls==0 and next(a.nameTranslations)==nil)
end)
test("Final caller validation cannot publish a dictionary whose validated sections changed",function(a)
    local dictionary={quests={},dungeons={}}
    a.nameTranslationFactories.loaders.ruRU=function()return dictionary end
    local calls=0
    assert(a.GetNameTranslations("ruRU",function()
        calls=calls+1;if calls==2 then dictionary.quests=nil end;return true
    end)==nil and a.nameTranslations.ruRU==nil)
    dictionary={quests={},dungeons={}}
    assert(a.GetNameTranslations("ruRU",current)==dictionary)
end)
print("Lazy localized dictionaries: "..total.." checks passed")
