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
SPEC = importlib.util.spec_from_file_location("area_case_names", ROOT / "scripts/names.py")
names = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(names)
FIXTURE_SPEC = importlib.util.spec_from_file_location("area_case_fixtures", ROOT / "tests/test_names.py")
fixtures = importlib.util.module_from_spec(FIXTURE_SPEC)
FIXTURE_SPEC.loader.exec_module(fixtures)


def candidate():
    catalog = {"quests": [{"id": 166, "name": "The Defias Brotherhood", "start": {"zoneName": "Westfall"}}],
               "dungeons": [{"key": "dm", "name": "The Deadmines"}]}
    data = {"schema": 1, "checked": "2026-10-19", "provenance": {
        "provider": "Wowhead", "extraction": "world-area-name-only",
        "englishIndex": "https://www.wowhead.com/forever/zones", "localeIndexes": dict(names.AREA_INDEXES),
        "indexRows": 144}, "sources": {"Westfall": [40, 16149]}, "locales": {"ruRU": {"Westfall": {
            "source": "Westfall", "name": "Западный Край", "caseVariantSelection": True,
            "observations": {"40": "Западный Край", "16149": "Западный край"}}}}}
    return data, catalog


class AreaCaseVariantTests(unittest.TestCase):
    def test_explicit_selection_accepts_either_exact_observed_case_without_changing_facts(self):
        for selected in ("Западный Край", "Западный край"):
            data, catalog = candidate()
            data["locales"]["ruRU"]["Westfall"]["name"] = selected
            before, original_catalog = copy.deepcopy(data), copy.deepcopy(catalog)
            with self.subTest(selected=selected):
                self.assertIs(names.validate_areas(data, catalog), data)
                self.assertEqual(data, before)
                self.assertEqual(catalog, original_catalog)

    def test_absent_flag_keeps_exact_homonym_agreement(self):
        data, catalog = candidate()
        entry = data["locales"]["ruRU"]["Westfall"]
        entry.pop("caseVariantSelection")
        with self.assertRaises(ValueError):
            names.validate_areas(data, catalog)
        entry["observations"]["16149"] = entry["name"]
        self.assertIs(names.validate_areas(data, catalog), data)

    def test_selection_flag_is_exact_true_and_requires_a_real_case_difference(self):
        for value in (False, 0, 1, "true", None, {}, []):
            data, catalog = candidate()
            entry = data["locales"]["ruRU"]["Westfall"]
            entry["caseVariantSelection"] = value
            with self.subTest(flag=value), self.assertRaises(ValueError):
                names.validate_areas(data, catalog)
        data, catalog = candidate()
        entry = data["locales"]["ruRU"]["Westfall"]
        entry["observations"]["16149"] = entry["name"]
        with self.assertRaises(ValueError):
            names.validate_areas(data, catalog)

    def test_case_selection_cannot_invent_a_label_or_relax_identity_and_text_rules(self):
        mutations = (
            lambda e: e.update(name="ЗАПАДНЫЙ КРАЙ"),  # Same lower case, but not an observed spelling.
            lambda e: e["observations"].update({"16149": "Западный Кран"}),  # Same length, different word.
            lambda e: e["observations"].update({"16149": "Западный  край"}),
            lambda e: e["observations"].update({"16149": "Западный край "}),
            lambda e: e["observations"].update({"16149": False}),
            lambda e: e["observations"].update({"16149": {}}),
            lambda e: e["observations"].update({"16149": "Западный\x00край"}),
            lambda e: e["observations"].update({"16149": "bad\ud800label"}),
            lambda e: e["observations"].pop("16149"),
            lambda e: e["observations"].update({"1425": "Западный край"}),
            lambda e: e.update(mapID=1436),
            lambda e: e.update(source="Other region"),
        )
        for mutate in mutations:
            data, catalog = candidate()
            mutate(data["locales"]["ruRU"]["Westfall"])
            with self.subTest(mutation=mutate), self.assertRaises(ValueError):
                names.validate_areas(data, catalog)
        # Full case-fold equality is broader than the approved same-length lower-case policy.
        data, catalog = candidate()
        data["locales"]["ruRU"]["Westfall"].update(
            name="Straße", observations={"40": "Straße", "16149": "STRASSE"})
        with self.assertRaises(ValueError):
            names.validate_areas(data, catalog)

    def test_generated_runtime_exports_names_without_selection_or_provider_metadata(self):
        data, catalog = candidate()
        names.validate_areas(data, catalog)
        payload = {"sourceAreas": data["sources"], "locales": {
            locale: {"quests": {}, "dungeons": {}} for locale in names.LOCALES}}
        payload["locales"]["ruRU"]["areas"] = data["locales"]["ruRU"]
        content = names.generate(payload)
        self.assertNotIn("caseVariantSelection", content)
        self.assertNotIn("observations", content)
        lua = shutil.which("lua5.1")
        if not lua:
            self.skipTest("Lua 5.1 unavailable for runtime payload verification")
        program = ('local addon={} local function load(...)\n' + content +
                   '\nend load("DungeonPro",addon)\n'
                   'assert(addon.sourceAreaNames.Westfall.name=="Westfall")\n'
                   'do local count=0 for key in pairs(addon.sourceAreaNames.Westfall)do '
                   'assert(key=="name");count=count+1 end assert(count==1) end\n'
                   'local entry=addon.nameTranslationFactories.loaders.ruRU().areas.Westfall\n'
                   'assert(entry.source=="Westfall" and entry.name=="Западный Край")\n'
                   'local count=0 for key in pairs(entry)do '
                   'assert(key=="source"or key=="name");count=count+1 end assert(count==2)\n')
        result = subprocess.run([lua, "-"], input=program.encode("utf-8"), capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", errors="replace"))

    def test_rejected_selection_cannot_replace_previous_cli_output(self):
        data, catalog = candidate()
        titles, _ = fixtures.fixture()
        authored = fixtures.authored_fixture(titles, catalog)
        italian = copy.deepcopy(authored)
        italian["locales"] = {"itIT": italian["locales"]["itIT"]}
        authored["locales"].pop("itIT")
        inputs = {"catalog.json": catalog, "name_translations.json": titles,
                  "name_translation_supplements.json": authored, "name_translation_itIT.json": italian,
                  "source_name_translations.json": dict(fixtures.source_fixture(), locales={}),
                  "area_name_translations.json": data}
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "scripts").mkdir()
            (root / "data").mkdir()
            (root / "Database").mkdir()
            shutil.copyfile(ROOT / "scripts/names.py", root / "scripts/names.py")
            for filename, value in inputs.items():
                (root / "data" / filename).write_text(json.dumps(value), encoding="utf-8")
            target = root / "Database/NameTranslations.lua"
            for options in ([], ["--check"]):
                result = subprocess.run([sys.executable, str(root / "scripts/names.py"), *options], capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", errors="replace"))
            generated = target.read_bytes()
            self.assertIn("Западный Край".encode("utf-8"), generated)
            self.assertNotIn(b"caseVariantSelection", generated)
            self.assertNotIn(b"observations", generated)
            original = b"previously verified runtime output\n"
            target.write_bytes(original)
            for mutate in (
                lambda e: e.update(caseVariantSelection=False),
                lambda e: e.update(name="ЗАПАДНЫЙ КРАЙ"),
                lambda e: e["observations"].update({"16149": "Западный Кран"}),
            ):
                invalid = copy.deepcopy(data)
                mutate(invalid["locales"]["ruRU"]["Westfall"])
                (root / "data/area_name_translations.json").write_text(json.dumps(invalid), encoding="utf-8")
                for options in ([], ["--check"]):
                    with self.subTest(mutation=mutate, options=options):
                        result = subprocess.run([sys.executable, str(root / "scripts/names.py"), *options], capture_output=True)
                        self.assertNotEqual(result.returncode, 0)
                        self.assertEqual(target.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
