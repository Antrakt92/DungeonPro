local addon, secret = {}, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Database/SearchCaseFold.lua"))("DungeonPro", addon)
assert(loadfile("Core/Search.lua"))("DungeonPro", addon)
issecretvalue = function(value) return value == secret end
local function same(left, right) assert(addon.SearchFold(left) == addon.SearchFold(right), left) end
same("DeAdMiNeS", "deadmines")
same("ОГНЕННАЯ ПРОПАСТЬ", "Огненная Пропасть")
same("ТЁМНЫЕ ПЕЩЕРЫ", "тёмные пещеры")
same("ÉCOLE À L'ENTRÉE", "école à l'entrée")
same("Straße", "STRASSE")
same("MARAUDÓN", "maraudón")
same("AÇÃO", "ação")
same("Σίσυφος", "ΣΊΣΥΦΟΣ")
same("𐐀𐐁", "𐐨𐐩")
for _, text in ipairs({ "死亡礦坑", "죽음의 폐광", "Мёртвые копи · Deadmines", "🙂 dungeon", "", "100% [quest].*" }) do
    assert(addon.SearchFold(addon.SearchFold(text)) == addon.SearchFold(text))
end
assert(addon.SearchFold("é") ~= addon.SearchFold("e"), "case folding does not strip accents")
assert(addon.SearchFold("é") ~= addon.SearchFold("é"), "normalization is a separate operation")
assert(addon.SearchFold("I") == "i" and addon.SearchFold("İ") == "i̇", "default, not Turkic folding")
for _, bad in ipairs({ false, 123, secret, {}, "\128", "\192\128", "\194", "\224\128\128", "\237\160\128",
    "\240\128\128\128", "\244\144\128\128", "\245\128\128\128", "\226x\172", string.rep("A", 16385) }) do
    assert(addon.SearchFold(bad) == nil, "malformed, restricted or oversized input")
end
assert(addon.SearchFold("A\0Б") == "a\0б")
issecretvalue = function() error("restricted") end
assert(addon.SearchFold("A") == nil)
print("Unicode search: multilingual folding, idempotence, literal and malformed-input checks passed")
