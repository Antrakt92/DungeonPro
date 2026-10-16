local addon, total, secret = {}, 0, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local locale, calls
local function reset()
    locale, calls = "enUS", 0
    GetLocale = function() return locale end
    issecretvalue = function(value) return value == secret end
    LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage", DEATHKNIGHT = "Death Knight" }
    LocalizedClassList = function(female) assert(female == false); calls = calls + 1; return { MAGE = "Magier" } end
    C_CreatureInfo = { GetRaceInfo = function(id)
        calls = calls + 1; return { raceID = id, raceName = id == 95 and "New native race" or "Human" }
    end }
    C_Timer = { After = function() error("timer forbidden") end }
    C_Item = { RequestLoadItemDataByID = function() error("request forbidden") end }
end
local function check(name, fn)
    reset(); local ok, err = pcall(fn); assert(ok, name .. ": " .. tostring(err))
    total = total + 1; print("PASS " .. name)
end
check("Class map uses exact tokens and no numeric class guesses", function()
    assert(addon.ClassName("MAGE") == "Mage" and calls == 0)
    assert(addon.ClassName("DEATHKNIGHT") == "Death Knight")
    assert(addon.ClassName("UNKNOWN") == nil)
    assert(addon.db == nil and addon.char == nil)
end)
check("Missing class map uses guarded native localization with false argument", function()
    LOCALIZED_CLASS_NAMES_MALE = nil
    assert(addon.ClassName("MAGE") == "Magier" and calls == 1)
    LocalizedClassList = nil; assert(addon.ClassName("MAGE") == nil)
end)
check("Race95 passes unchanged with no classic eight whitelist", function()
    assert(addon.RaceName(95) == "New native race" and calls == 1)
    assert(addon.RaceName(1) == "Human")
    C_CreatureInfo.GetRaceInfo = function() return { raceID = 1, raceName = "Wrong race" } end
    assert(addon.RaceName(95) == nil)
end)
check("Invalid IDs tokens names and restricted fields remain absent", function()
    for _, v in ipairs({ secret, false, 1, "", " ", string.rep("A", 101) }) do assert(addon.ClassName(v) == nil) end
    for _, v in ipairs({ secret, false, "95", 0, -1, 1.5, math.huge, 0/0 }) do assert(addon.RaceName(v) == nil) end
    for _, v in ipairs({ secret, false, 1, "", " ", string.rep("A", 501) }) do
        LOCALIZED_CLASS_NAMES_MALE.MAGE = v; assert(addon.ClassName("MAGE") == nil)
        C_CreatureInfo.GetRaceInfo = function(id) return { raceID = id, raceName = v } end
        assert(addon.RaceName(95) == nil)
    end
    C_CreatureInfo.GetRaceInfo = function() return secret end; assert(addon.RaceName(95) == nil)
    C_CreatureInfo.GetRaceInfo = function() return { raceID = secret, raceName = "Race" } end; assert(addon.RaceName(95) == nil)
end)
check("Missing throwing malformed and restricted providers never invent names", function()
    LOCALIZED_CLASS_NAMES_MALE = nil
    for _, v in ipairs({ false, 2, secret }) do LocalizedClassList = function() return v end; assert(addon.ClassName("MAGE") == nil) end
    LocalizedClassList = function() error("unavailable") end; assert(addon.ClassName("MAGE") == nil)
    C_CreatureInfo = nil; assert(addon.RaceName(95) == nil)
    C_CreatureInfo = {}; assert(addon.RaceName(95) == nil)
    C_CreatureInfo.GetRaceInfo = function() error("unavailable") end; assert(addon.RaceName(95) == nil)
    C_CreatureInfo.GetRaceInfo = function() return nil end; assert(addon.RaceName(95) == nil)
end)
check("Locale mutation and unknown locale reject mixed names", function()
    LOCALIZED_CLASS_NAMES_MALE = nil
    LocalizedClassList = function() locale = "deDE"; return { MAGE = "Mage" } end
    assert(addon.ClassName("MAGE") == nil)
    reset(); C_CreatureInfo.GetRaceInfo = function(id) locale = "deDE"; return { raceID = id, raceName = "Race" } end
    assert(addon.RaceName(95) == nil)
    reset(); GetLocale = function() return nil end
    assert(addon.ClassName("MAGE") == nil and addon.RaceName(95) == nil)
end)
check("Getter table and checker identity drift discards stale results", function()
    LOCALIZED_CLASS_NAMES_MALE = nil
    LocalizedClassList = function() LocalizedClassList = function() return {} end; return { MAGE = "Mage" } end
    assert(addon.ClassName("MAGE") == nil)
    reset(); LOCALIZED_CLASS_NAMES_MALE = nil
    LocalizedClassList = function() LOCALIZED_CLASS_NAMES_MALE = { MAGE = "New" }; return { MAGE = "Old" } end
    assert(addon.ClassName("MAGE") == nil)
    for mode = 1, 4 do
        reset(); C_CreatureInfo.GetRaceInfo = function(id)
            if mode == 1 then C_CreatureInfo = {}
            elseif mode == 2 then C_CreatureInfo.GetRaceInfo = function() return nil end
            elseif mode == 3 then issecretvalue = function() return false end
            else GetLocale = function() return "enUS" end end
            return { raceID = id, raceName = "Stale" }
        end
        assert(addon.RaceName(95) == nil)
    end
end)
check("Class map mutation during scope reads and unavailable restriction checks fail closed", function()
    local reads = 0
    GetLocale = function()
        reads = reads + 1
        if reads == 2 then LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Replacement" } end
        return locale
    end
    assert(addon.ClassName("MAGE") == nil)
    reset(); issecretvalue = function() error("unavailable checker") end
    assert(addon.ClassName("MAGE") == nil and addon.RaceName(95) == nil)
end)
check("Repeated reads use current localized data without persisting or changing policy", function()
    assert(addon.ClassName("MAGE") == "Mage")
    LOCALIZED_CLASS_NAMES_MALE.MAGE = "Magier"; locale = "deDE"
    assert(addon.ClassName("MAGE") == "Magier")
    assert(addon.RaceName(95) == "New native race")
    assert(addon.db == nil and addon.char == nil and next(addon.quests) == nil)
end)
issecretvalue = nil
print("Restriction-name checks passed: " .. total .. " (native client unverified)")
