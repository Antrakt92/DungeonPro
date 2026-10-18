import copy
import importlib.util
import json
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("names", ROOT / "scripts/names.py")
names = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(names)


def fixture():
    catalog = {"quests": [{"id": 166, "name": "The Defias Brotherhood"}],
               "dungeons": [{"key": "dm", "name": "The Deadmines"}]}
    data = {"schema": 1, "checked": "2026-10-17", "provenance": {
        "provider": "Wowhead", "endpoint": names.ENDPOINT, "extraction": "name-only",
        "localeIDs": dict(names.LOCALES), "catalogueQuestCount": 1, "englishVerifiedCount": 1, "dungeonSources": {"dm": 1581}},
        "locales": {locale: {"quests": {}, "dungeons": {}} for locale in names.LOCALES}}
    data["locales"]["ruRU"]["quests"]["166"] = {
        "source": "The Defias Brotherhood", "name": "Братство Справедливости",
        "url": names.ENDPOINT.format(kind="quest", id=166, locale=7)}
    data["locales"]["ruRU"]["dungeons"]["dm"] = {
        "source": "The Deadmines", "name": "Мертвые копи",
        "url": names.ENDPOINT.format(kind="zone", id=1581, locale=7)}
    return data, catalog


class NamesTests(unittest.TestCase):
    def test_exact_id_source_and_primary_locale_url(self):
        data, catalog = fixture()
        self.assertIs(names.validate(data, catalog), data)
        for field, value in (("source", "A changed quest"), ("url", "https://example.com/name")):
            invalid = copy.deepcopy(data)
            invalid["locales"]["ruRU"]["quests"]["166"][field] = value
            with self.assertRaises(ValueError):
                names.validate(invalid, catalog)

    def test_quest_and_zone_namespaces_cannot_be_confused(self):
        data, catalog = fixture()
        for kind, key in (("quests", "166"), ("dungeons", "dm")):
            invalid = copy.deepcopy(data)
            invalid["locales"]["ruRU"][kind][key]["url"] = names.ENDPOINT.format(kind="quest", id=1581, locale=7)
            with self.assertRaises(ValueError):
                names.validate(invalid, catalog)

    def test_generic_unknown_english_fallback_and_unsafe_title_are_rejected(self):
        for value in ("", "Unknown", "Sconosciuto", "[Sconosciuto]", "The Defias Brotherhood",
                      "[The Defias Brotherhood]", "\tName", "Name\n", "|cffffffffName", "<b>Name</b>"):
            data, catalog = fixture()
            data["locales"]["ruRU"]["quests"]["166"]["name"] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                names.validate(data, catalog)

    def test_strict_identity_locale_and_schema_fields(self):
        for mutation in (
            lambda d: d["locales"].pop("koKR"),
            lambda d: d["locales"].update({"xxXX": {"quests": {}, "dungeons": {}}}),
            lambda d: d["locales"]["ruRU"]["quests"].update({"0166": d["locales"]["ruRU"]["quests"].pop("166")}),
            lambda d: d["locales"]["ruRU"]["quests"]["166"].update({"tooltip": "not title-only"}),
            lambda d: d["provenance"]["localeIDs"].update({"koKR": 8}),
            lambda d: d["provenance"].update({"catalogueQuestCount": 2}),
            lambda d: d.update({"schema": 2}),
            lambda d: d.update({"schema": True}),
            lambda d: d.update({"checked": "2026-99-99"}),
            lambda d: d["provenance"]["localeIDs"].update({"koKR": True}),
        ):
            data, catalog = fixture()
            mutation(data)
            with self.assertRaises(ValueError):
                names.validate(data, catalog)

    def test_generation_is_deterministic_and_exports_no_tooltip_or_urls(self):
        data, catalog = fixture()
        expected = names.generate(names.validate(data, catalog))
        shuffled = dict(reversed(list(data.items())))
        shuffled["locales"] = dict(reversed(list(data["locales"].items())))
        self.assertEqual(names.generate(names.validate(shuffled, catalog)), expected)
        self.assertIn('[166] = { source = "The Defias Brotherhood", name = "Братство Справедливости" }', expected)
        self.assertNotIn("https://", expected)
        self.assertNotIn("tooltip", expected)

    def test_saved_dataset_and_generated_bytes_remain_consistent(self):
        path = ROOT / "data/name_translations.json"
        self.assertTrue(path.exists(), "Title source data is required")
        data = json.loads(path.read_text(encoding="utf-8"))
        catalog = json.loads((ROOT / "data/catalog.json").read_text(encoding="utf-8"))
        content = names.generate(names.validate(data, catalog))
        self.assertEqual((ROOT / "Database/NameTranslations.lua").read_bytes(), content.encode("utf-8"))
        # Exact source coverage is explicit; an untranslated locale may be empty.
        self.assertEqual(data["provenance"]["englishVerifiedCount"], len(catalog["quests"]))
        for locale in ("deDE", "frFR", "esES", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"):
            self.assertIn("166", data["locales"][locale]["quests"])
            self.assertIn("dm", data["locales"][locale]["dungeons"])

    def test_actual_lua_factories_preserve_every_reviewed_title_and_materialize_independently(self):
        data = json.loads((ROOT / "data/name_translations.json").read_text(encoding="utf-8"))
        lines = ['local addon={} local function load(...)', names.generate(data), 'end load("DungeonPro",addon)',
                 'assert(next(addon.nameTranslations)==nil and getmetatable(addon.nameTranslations)==nil)',
                 'local total=0']
        for locale, payload in sorted(data["locales"].items()):
            lines.append(f'local dictionary=addon.nameTranslationFactories.loaders.{locale}()')
            for kind, entries in payload.items():
                lines.append(f'local count=0 for _ in pairs(dictionary.{kind})do count=count+1 end assert(count=={len(entries)})')
                for key, entry in entries.items():
                    index = key if kind == "quests" else names.quoted(key)
                    lines.append(f'assert(dictionary.{kind}[{index}].source=={names.quoted(entry["source"])} and '
                                 f'dictionary.{kind}[{index}].name=={names.quoted(entry["name"])}) total=total+1')
        count = sum(len(entries) for payload in data["locales"].values() for entries in payload.values())
        lines.append(f'assert(total=={count} and next(addon.nameTranslations)==nil)')
        lua = shutil.which("lua5.1")
        self.assertIsNotNone(lua, "Lua 5.1 is required for localized-title parity verification")
        result = subprocess.run([lua, "-"], input="\n".join(lines), text=True, encoding="utf-8", capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
