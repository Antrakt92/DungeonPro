local addon, total = {}, 0
local secret = {}
issecretvalue = function(value) return value == secret end
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local function place()
    return { npcID = 5204, creatureDisplayID = 4056, name = "Apothecary Zinge",
        portraitSource = "https://www.wowhead.com/forever/npc=5204/apothecary-zinge" }
end
local function check(label, fn)
    local ok, err = pcall(fn)
    assert(ok, label .. ": " .. tostring(err))
    total = total + 1; print("PASS " .. label)
end
check("Sourced NPC display references stay distinct from creature identity and detach from the place", function()
    local source = place()
    local result = addon.GiverPortrait(source)
    assert(result.npcID == 5204 and result.displayID == 4056 and result.name == source.name)
    assert(result.source == source.portraitSource and result ~= source)
    result.displayID = 1
    assert(source.creatureDisplayID == 4056 and addon.GiverPortrait(source).displayID == 4056)
end)
check("Missing malformed and restricted portrait facts never substitute an NPC ID", function()
    for _, field in ipairs({ "npcID", "creatureDisplayID" }) do
        for _, value in ipairs({ false, 0, -1, 1.5, 4294967296, "5204", math.huge, secret }) do
            local source = place(); source[field] = value
            assert(addon.GiverPortrait(source) == nil, field)
        end
        local source = place(); source[field] = nil
        assert(addon.GiverPortrait(source) == nil)
    end
    for _, source in ipairs({ false, true, "place", secret }) do assert(addon.GiverPortrait(source) == nil) end
    assert(addon.GiverPortrait(nil) == nil)
end)
check("A display reference needs the exact same-NPC Forever source", function()
    for _, value in ipairs({ false, secret, "", "https://www.wowhead.com/forever/npc=52040",
        "https://www.wowhead.com/forever/npc=5204/one/two", "https://www.wowhead.com/forever/npc=5204?x=1",
        "https://www.wowhead.com/classic/npc=5204", "https://www.wowhead.com/forever/quest=5204" }) do
        local source = place(); source.portraitSource = value
        assert(addon.GiverPortrait(source) == nil)
    end
    local source = place(); source.portraitSource = nil
    assert(addon.GiverPortrait(source) == nil)
    source.portraitSource = "https://www.wowhead.com/forever/npc=5204"
    assert(addon.GiverPortrait(source))
end)
check("Objects starter items and drop creatures cannot become giver portrait identities", function()
    for _, field in ipairs({ "objectID", "itemID", "dropNPCID" }) do
        for _, value in ipairs({ 5204, false, secret }) do
            local source = place(); source[field] = value
            assert(addon.GiverPortrait(source) == nil, field)
        end
    end
end)
check("Optional names are bounded and no native identity or model API is called", function()
    local source = place()
    UnitGUID = function() error("Source portraits do not inspect units") end
    SetPortraitTextureFromCreatureDisplayID = function() error("Producer must not render") end
    for _, value in ipairs({ false, secret, "", "  ", string.rep("x", 1025) }) do
        source.name = value
        local result = addon.GiverPortrait(source)
        assert(result.displayID == 4056 and result.name == nil)
    end
end)
check("A changed source reference or restriction checker cannot publish a mixed identity", function()
    local checker = issecretvalue
    for _, mutation in ipairs({ "display", "npc", "source", "checker" }) do
        local source, armed = place(), true
        issecretvalue = function(value)
            if armed and ((mutation == "source" and value == "Apothecary Zinge") or
                (mutation ~= "source" and value == 4056)) then
                armed = false
                if mutation == "display" then source.creatureDisplayID = 54321
                elseif mutation == "npc" then source.npcID = 5205
                elseif mutation == "source" then source.portraitSource = "https://www.wowhead.com/forever/npc=5204/new"
                else issecretvalue = function(item) return item == secret end end
            end
            return value == secret
        end
        assert(addon.GiverPortrait(source) == nil, mutation)
    end
    issecretvalue = checker
end)
print("Giver reference portrait checks passed: " .. total .. " (no native appearance validation)")
