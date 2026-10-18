import copy
import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
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


def authored_fixture(data, catalog):
    supplement = {"schema": 1, "provenance": {"provider": "Dungeon Pro", "extraction": "authored-title-translation"}, "locales": {}}
    for locale in names.LOCALES:
        supplement["locales"][locale] = {"quests": {}, "dungeons": {}}
        for kind, definitions in (("quests", catalog["quests"]), ("dungeons", catalog["dungeons"])):
            for definition in definitions:
                key = str(definition["id"]) if kind == "quests" else definition["key"]
                if key not in data["locales"][locale][kind]:
                    supplement["locales"][locale][kind][key] = {"source": definition["name"], "name": locale + " localized title"}
    return supplement


class NamesTests(unittest.TestCase):
    def test_invalid_unicode_inputs_preserve_generated_names_in_write_and_check_modes(self):
        data, catalog = fixture()
        authored = authored_fixture(data, catalog)
        italian = copy.deepcopy(authored)
        italian["locales"] = {"itIT": italian["locales"]["itIT"]}
        authored["locales"].pop("itIT")
        inputs = {"catalog.json": catalog, "name_translations.json": data,
                  "name_translation_supplements.json": authored, "name_translation_itIT.json": italian}
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name in ("scripts", "data", "Database"):
                (root / name).mkdir()
            shutil.copy2(ROOT / "scripts/names.py", root / "scripts/names.py")
            target = root / "Database/NameTranslations.lua"
            original = b"previous verified localized titles\n"
            for filename, locale in (("name_translations.json", "ruRU"),
                                     ("name_translation_supplements.json", "zhCN"),
                                     ("name_translation_itIT.json", "itIT")):
                for invalid in ("bad\ud800title", "bad\udffftitle"):
                    candidate = copy.deepcopy(inputs)
                    candidate[filename]["locales"][locale]["quests"]["166"]["name"] = invalid
                    for name, payload in candidate.items():
                        (root / "data" / name).write_text(json.dumps(payload), encoding="utf-8")
                    for options in ([], ["--check"]):
                        with self.subTest(filename=filename, invalid=repr(invalid), options=options):
                            target.write_bytes(original)
                            result = subprocess.run([sys.executable, str(root / "scripts/names.py"), *options],
                                                    capture_output=True)
                            self.assertNotEqual(result.returncode, 0)
                            self.assertEqual(target.read_bytes(), original)
            valid = copy.deepcopy(inputs)
            valid["name_translations.json"]["locales"]["ruRU"]["quests"]["166"]["name"] = "探検😀e\u0301"
            for name, payload in valid.items():
                (root / "data" / name).write_text(json.dumps(payload), encoding="utf-8")
            result = subprocess.run([sys.executable, str(root / "scripts/names.py")], capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("探検😀e\u0301".encode("utf-8"), target.read_bytes())

    def test_file_loader_rejects_duplicate_json_keys_in_every_input(self):
        data, catalog = fixture()
        authored = authored_fixture(data, catalog)
        italian = copy.deepcopy(authored)
        italian["locales"] = {"itIT": italian["locales"]["itIT"]}
        authored["locales"].pop("itIT")
        inputs = {"catalog.json": catalog, "name_translations.json": data,
                  "name_translation_supplements.json": authored, "name_translation_itIT.json": italian}
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "data").mkdir()
            for name, payload in inputs.items():
                (root / "data" / name).write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
            self.assertEqual(len(names.load_data(root)["locales"]), 9)
            for name, payload in inputs.items():
                path = root / "data" / name
                original = path.read_text(encoding="utf-8")
                first = next(iter(payload))
                duplicate = json.dumps({first: payload[first]}, ensure_ascii=False)[1:-1]
                path.write_text("{" + duplicate + "," + original[1:], encoding="utf-8")
                with self.subTest(file=name), self.assertRaisesRegex(ValueError, "Duplicate"):
                    names.load_data(root)
                path.write_text(original, encoding="utf-8")
            path = root / "data/name_translations.json"
            original = path.read_text(encoding="utf-8")
            title = '"name": "Братство Справедливости"'
            self.assertIn(title, original)
            path.write_text(original.replace(title, '"name": "Скрытая подмена", ' + title, 1), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Duplicate"):
                names.load_data(root)

    def test_authored_entries_fill_every_hole_without_overriding_primary_sources(self):
        data, catalog = fixture()
        supplement = authored_fixture(data, catalog)
        merged = names.merge(data, catalog, supplement)
        for locale in names.LOCALES:
            self.assertEqual(set(merged["locales"][locale]["quests"]), {"166"})
            self.assertEqual(set(merged["locales"][locale]["dungeons"]), {"dm"})
        self.assertEqual(merged["locales"]["ruRU"], data["locales"]["ruRU"])
        self.assertEqual(data["locales"]["itIT"], {"quests": {}, "dungeons": {}})
        supplement["locales"]["ruRU"]["quests"]["166"] = {"source": "The Defias Brotherhood", "name": "Overwrite"}
        with self.assertRaisesRegex(ValueError, "overlaps"):
            names.merge(data, catalog, supplement)

    def test_authored_schema_identity_provenance_and_coverage_fail_closed(self):
        mutations = (
            lambda s: s.update({"schema": True}),
            lambda s: s["provenance"].update({"provider": "Wowhead"}),
            lambda s: s["provenance"].update({"url": "https://example.com"}),
            lambda s: s["locales"]["zhCN"]["quests"]["166"].update({"source": "Stale English source"}),
            lambda s: s["locales"]["zhCN"]["quests"]["166"].update({"url": "https://example.com"}),
            lambda s: s["locales"]["zhCN"]["quests"].update({"999": {"source": "The Defias Brotherhood", "name": "Orphan"}}),
            lambda s: s["locales"]["zhCN"]["quests"].pop("166"),
            lambda s: s["locales"]["zhCN"]["dungeons"].pop("dm"),
            lambda s: s["locales"].pop("itIT"),
        )
        for mutation in mutations:
            data, catalog = fixture()
            supplement = authored_fixture(data, catalog)
            mutation(supplement)
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                names.merge(data, catalog, supplement)

    def test_authored_proper_names_may_match_source_but_placeholders_and_markup_cannot(self):
        data, catalog = fixture()
        supplement = authored_fixture(data, catalog)
        entry = supplement["locales"]["itIT"]["quests"]["166"]
        entry["name"] = entry["source"]
        with self.assertRaises(ValueError):
            names.merge(data, catalog, supplement)
        for invalid_flag in (False, 1, "true"):
            entry["unchangedProperName"] = invalid_flag
            with self.subTest(invalid_flag=invalid_flag), self.assertRaises(ValueError):
                names.merge(data, catalog, supplement)
        entry["unchangedProperName"] = True
        self.assertEqual(names.merge(data, catalog, supplement)["locales"]["itIT"]["quests"]["166"]["name"], entry["source"])
        entry["name"] = "An actual translation"
        with self.assertRaises(ValueError):
            names.merge(data, catalog, supplement)
        entry.pop("unchangedProperName")
        for invalid in ("", " ", "Unknown", "[The Defias Brotherhood]", "|cffffffffTitle", "<b>Title</b>", "Name\n"):
            entry["name"] = invalid
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                names.merge(data, catalog, supplement)
        with self.assertRaises(ValueError):
            names.validate_supplement(supplement, catalog, {"itIT"})
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
        merged = names.load_data()
        content = names.generate(merged)
        self.assertEqual((ROOT / "Database/NameTranslations.lua").read_bytes(), content.encode("utf-8"))
        # Every supported non-English locale must cover the complete current catalogue.
        self.assertEqual(data["provenance"]["englishVerifiedCount"], len(catalog["quests"]))
        for locale, payload in merged["locales"].items():
            self.assertEqual(set(payload["quests"]), {str(q["id"]) for q in catalog["quests"]}, locale)
            self.assertEqual(set(payload["dungeons"]), {d["key"] for d in catalog["dungeons"]}, locale)
        for locale in ("deDE", "frFR", "esES", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"):
            self.assertIn("166", data["locales"][locale]["quests"])
            self.assertIn("dm", data["locales"][locale]["dungeons"])

    def test_actual_lua_factories_preserve_every_reviewed_title_and_materialize_independently(self):
        data = names.load_data()
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
