import copy
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("catalog", ROOT / "scripts/catalog.py")
catalog = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(catalog)


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads((ROOT / "data/catalog.json").read_text(encoding="utf-8"))

    def test_generated_data_matches(self):
        self.assertEqual(catalog.generate(self.data), (ROOT / "Database/Catalog.lua").read_text(encoding="utf-8"))

    def test_missing_parent_is_rejected(self):
        self.data["quests"][0]["requires"] = [{"ids": [999999]}]
        with self.assertRaisesRegex(ValueError, "Missing prerequisite"):
            catalog.validate(self.data)

    def test_cycles_are_rejected(self):
        self.data["quests"][0]["requires"] = [{"ids": [166]}]
        with self.assertRaisesRegex(ValueError, "cycle"):
            catalog.validate(self.data)

    def test_duplicate_ids_are_rejected(self):
        self.data["quests"].append(copy.deepcopy(self.data["quests"][0]))
        with self.assertRaisesRegex(ValueError, "duplicate"):
            catalog.validate(self.data)

    def test_invalid_coordinates_are_rejected(self):
        for coordinate in [float("nan"), float("inf"), -1, 101, True]:
            with self.subTest(coordinate=coordinate):
                data = copy.deepcopy(self.data)
                data["quests"][0]["start"]["x"] = coordinate
                with self.assertRaisesRegex(ValueError, "coordinate"):
                    catalog.validate(data)

    def test_restrictions_require_nonempty_typed_lists(self):
        for field in ("factions", "classes", "races"):
            for value in (None, True, "Alliance", {"1": "Alliance"}, []):
                with self.subTest(field=field, value=value):
                    data = copy.deepcopy(self.data)
                    data["quests"][0][field] = value
                    with self.assertRaisesRegex(ValueError, "restriction"):
                        catalog.validate(data)

    def test_invalid_restriction_values_are_rejected(self):
        invalid = {
            "factions": [["Allaince"], ["alliance"], [1], [True], ["Alliance", "Alliance"]],
            "classes": [["MGAE"], ["mage"], [8], [True], ["MAGE", "MAGE"]],
            "races": [["3"], [True], [0], [-1], [3.0], [float("inf")], [3, 3]],
        }
        for field, values in invalid.items():
            for value in values:
                with self.subTest(field=field, value=value):
                    data = copy.deepcopy(self.data)
                    data["quests"][0][field] = value
                    with self.assertRaisesRegex(ValueError, "restriction"):
                        catalog.validate(data)

    def test_current_tokens_and_new_race_ids_are_not_classic_mask_limited(self):
        self.data["quests"][0].update(
            factions=["Alliance", "Horde", "Neutral"], classes=["MAGE", "EVOKER"], races=[3, 95],
        )
        catalog.validate(self.data)

    def test_starts_inside_requires_boolean(self):
        for value in (None, "false", 0, 1, [], {}):
            with self.subTest(value=value):
                data = copy.deepcopy(self.data)
                data["quests"][0]["startsInside"] = value
                with self.assertRaisesRegex(ValueError, "startsInside"):
                    catalog.validate(data)
        for value in (False, True):
            self.data["quests"][0]["startsInside"] = value
            catalog.validate(self.data)

    def test_places_and_npc_ids_require_expected_types(self):
        for field in ("start", "finish"):
            for value in (False, "Gryan Stoutmantle", [], 234):
                with self.subTest(field=field, value=value):
                    data = copy.deepcopy(self.data)
                    data["quests"][0][field] = value
                    with self.assertRaisesRegex(ValueError, "place"):
                        catalog.validate(data)
            for value in (None, True, "234", 0, -1, 234.0):
                with self.subTest(field=field, npcID=value):
                    data = copy.deepcopy(self.data)
                    data["quests"][0][field]["npcID"] = value
                    with self.assertRaisesRegex(ValueError, "npcID entity ID"):
                        catalog.validate(data)

    def test_repeatable_requires_explicit_boolean_without_changing_requirements(self):
        for value in (None, "false", 0, 1, [], {}):
            with self.subTest(value=value):
                data = copy.deepcopy(self.data)
                data["quests"][0]["repeatable"] = value
                with self.assertRaisesRegex(ValueError, "repeatable"):
                    catalog.validate(data)
        quest = self.data["quests"][0]
        known, requires = quest["requirementsKnown"], copy.deepcopy(quest.get("requires"))
        for value in (False, True):
            quest["repeatable"] = value
            catalog.validate(self.data)
            self.assertEqual(quest["requirementsKnown"], known)
            self.assertEqual(quest.get("requires"), requires)

    def test_object_starters_remain_distinct_from_npcs(self):
        for field in ("start", "finish"):
            for value in (None, True, "142487", 0, -1, 142487.0):
                with self.subTest(field=field, objectID=value):
                    data = copy.deepcopy(self.data)
                    data["quests"][0][field] = {"objectID": value}
                    with self.assertRaisesRegex(ValueError, "objectID entity ID"):
                        catalog.validate(data)
            data = copy.deepcopy(self.data)
            data["quests"][0][field] = {"objectID": 142487, "npcID": 234}
            with self.assertRaisesRegex(ValueError, "Ambiguous"):
                catalog.validate(data)
        self.data["quests"][0]["start"] = {"objectID": 142487}
        catalog.validate(self.data)

    def test_coordinates_require_both_axes_and_a_map(self):
        for field in ("start", "finish"):
            for missing in ("x", "y", "mapID"):
                with self.subTest(field=field, missing=missing):
                    data = copy.deepcopy(self.data)
                    del data["quests"][0][field][missing]
                    with self.assertRaisesRegex(ValueError, "coordinate"):
                        catalog.validate(data)

    def test_incomplete_locations_remain_valid_when_navigation_is_unknown(self):
        q = self.data["quests"][0]
        q["requirementsKnown"] = False
        q["start"] = {"name": "Unknown location", "npcID": 234}
        q["finish"] = {"mapID": 1436}
        catalog.validate(self.data)
        del q["start"]
        q["finish"] = None
        catalog.validate(self.data)

    def test_unknown_requirements_must_be_explicit(self):
        del self.data["quests"][0]["requirementsKnown"]
        with self.assertRaisesRegex(ValueError, "evidence"):
            catalog.validate(self.data)

    def test_storyline_ids_cannot_replace_requirements(self):
        q = next(q for q in self.data["quests"] if q["id"] == 92753)
        self.assertFalse(q["requirementsKnown"])
        self.assertIn(92742, q["storyline"])

    def test_no_empty_dungeon_is_declared_reviewed(self):
        d = next(d for d in self.data["dungeons"] if not d["quests"])
        d["coverage"] = "reviewed"
        with self.assertRaisesRegex(ValueError, "Empty dungeon"):
            catalog.validate(self.data)

    def test_completion_quests_validate_references_and_item_identity(self):
        quest, other = self.data["quests"][:2]
        quest["completionQuests"] = [{"id": other["id"], "itemID": 7083}]
        catalog.validate(self.data)
        self.assertIn('["completionQuests"]', catalog.generate(self.data))
        quest["completionQuests"] = []
        catalog.validate(self.data)

    def test_completion_quests_require_bounded_lists_and_typed_entries(self):
        other = self.data["quests"][1]["id"]
        for value in (None, True, {}, "quest", [None], [True], [1], ["quest"],
                      [{"id": other}], [{"itemID": 7083}], [{"id": other, "itemID": 7083}] * 101):
            with self.subTest(value=value):
                data = copy.deepcopy(self.data)
                data["quests"][0]["completionQuests"] = value
                with self.assertRaisesRegex(ValueError, "completion quest"):
                    catalog.validate(data)
        for field in ("id", "itemID"):
            for value in (None, True, "7083", 0, -1, 1.5, float("inf"), float("nan")):
                with self.subTest(field=field, value=value):
                    data = copy.deepcopy(self.data)
                    entry = {"id": other, "itemID": 7083}
                    entry[field] = value
                    data["quests"][0]["completionQuests"] = [entry]
                    with self.assertRaisesRegex(ValueError, "completion quest"):
                        catalog.validate(data)

    def test_completion_quests_reject_missing_duplicate_and_self_links(self):
        quest, other = self.data["quests"][:2]
        for entries, message in (
            ([{"id": 99999999, "itemID": 7083}], "Missing completion"),
            ([{"id": quest["id"], "itemID": 7083}], "self-referencing"),
            ([{"id": other["id"], "itemID": 7083}, {"id": other["id"], "itemID": 272448}], "Duplicate"),
        ):
            with self.subTest(entries=entries):
                data = copy.deepcopy(self.data)
                data["quests"][0]["completionQuests"] = entries
                with self.assertRaisesRegex(ValueError, message):
                    catalog.validate(data)

    def test_completion_links_do_not_become_acceptance_dependency_cycles(self):
        quest, other = self.data["quests"][:2]
        quest["completionQuests"] = [{"id": other["id"], "itemID": 7083}]
        other["completionQuests"] = [{"id": quest["id"], "itemID": 272448}]
        catalog.validate(self.data)


if __name__ == "__main__":
    unittest.main()
