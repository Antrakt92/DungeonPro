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

    def test_item_starters_keep_drop_source_and_dungeon_identity(self):
        q = self.data["quests"][0]
        q["start"] = {"itemID": 17008, "dropNPCID": 4421, "dungeonKey": "rfk"}
        catalog.validate(self.data)
        for field, value in (("itemID", True), ("dropNPCID", "4421"), ("dungeonKey", "missing"), ("dungeonKey", 47)):
            with self.subTest(field=field, value=value):
                data = copy.deepcopy(self.data)
                data["quests"][0]["start"][field] = value
                with self.assertRaises(ValueError):
                    catalog.validate(data)
        q["start"]["npcID"] = 4421
        with self.assertRaisesRegex(ValueError, "Ambiguous"):
            catalog.validate(self.data)
        del q["start"]["npcID"]
        del q["start"]["itemID"]
        with self.assertRaisesRegex(ValueError, "without starter"):
            catalog.validate(self.data)

    def test_item_drop_alternatives_require_real_distinct_named_sources(self):
        place = {"itemID": 7666, "dropSources": [
            {"npcID": 4852, "name": "Stonevault Oracle", "locationName": "Uldaman"},
            {"npcID": 4845, "name": "Shadowforge Ruffian", "locationName": "Badlands"},
        ]}
        self.data["quests"][0]["start"] = place
        catalog.validate(self.data)
        for value in (None, [], {}, [None], [{"npcID": True}], [place["dropSources"][0]] * 2):
            with self.subTest(drops=value):
                data = copy.deepcopy(self.data)
                data["quests"][0]["start"]["dropSources"] = value
                with self.assertRaises(ValueError):
                    catalog.validate(data)
        del place["itemID"]
        with self.assertRaisesRegex(ValueError, "drop sources"):
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

    def test_alternative_starts_preserve_typed_entities_without_class_inference(self):
        q = self.data["quests"][0]
        q.pop("start", None)
        q.pop("classes", None)
        q["startAlternatives"] = [{"npcID": 4568, "name": "Anastasia"},
                                  {"objectID": 4568, "name": "Object", "mapID": 1, "x": 0, "y": 100}]
        catalog.validate(self.data)
        self.assertNotIn("classes", q)
        self.assertNotIn("start", q)
        self.assertIn('["startAlternatives"]', catalog.generate(self.data))
        q["startAlternatives"] = [{"objectID": i, "name": "Object"} for i in range(1, 13)]
        catalog.validate(self.data)

    def test_alternative_starts_reject_ambiguous_invalid_and_duplicate_places(self):
        valid = [{"npcID": 1, "name": "First"}, {"objectID": 2, "name": "Second"}]
        invalid = [None, True, {}, [], valid[:1], valid * 51,
                   [valid[0], valid[0]], [valid[0], {"itemID": 2, "name": "Item"}],
                   [valid[0], {"npcID": True, "name": "Bad"}],
                   [valid[0], {"npcID": 2, "objectID": 3, "name": "Mixed"}],
                   [valid[0], {"npcID": 2}], [valid[0], {"npcID": 2, "name": " "}],
                   [valid[0], {"npcID": 2, "name": "Bad", "x": 10}],
                   [valid[0], {"npcID": 2, "name": "Bad", "x": 10, "y": 20}],
                   [valid[0], {"npcID": 2, "name": "Bad", "mapID": True}],
                   [valid[0], {"npcID": 2, "name": "Bad", "mapID": 1, "x": float("inf"), "y": 1}],
                   [valid[0], {"npcID": 2, "name": "Bad", "dungeonKey": "missing-dungeon"}]]
        for value in invalid:
            with self.subTest(value=value):
                data = copy.deepcopy(self.data)
                data["quests"][0].pop("start", None)
                data["quests"][0]["startAlternatives"] = value
                with self.assertRaises(ValueError):
                    catalog.validate(data)
        for start in (None, {"npcID": 3}):
            data = copy.deepcopy(self.data)
            data["quests"][0].update(start=start, startAlternatives=valid)
            with self.assertRaisesRegex(ValueError, "single and alternative"):
                catalog.validate(data)

    def test_place_zone_name_requires_bounded_nonempty_string(self):
        for field in ("start", "finish", "startAlternatives"):
            for value in (None, True, 1, "", " ", "x" * 501):
                with self.subTest(field=field, value=value):
                    data = copy.deepcopy(self.data)
                    q = data["quests"][0]
                    if field == "startAlternatives":
                        q.pop("start", None)
                        q[field] = [{"npcID": 1, "name": "First", "zoneName": value},
                                    {"objectID": 2, "name": "Second"}]
                    else:
                        q[field] = {"npcID": 1, "name": "Giver", "zoneName": value}
                    with self.assertRaisesRegex(ValueError, "zone name"):
                        catalog.validate(data)
        self.data["quests"][0]["start"] = {"npcID": 1, "zoneName": "Alterac Mountains"}
        catalog.validate(self.data)

    def test_storyline_groups_preserve_shared_rows_without_acceptance_edges(self):
        q, other, third = self.data["quests"][:3]
        q.pop("storyline", None)
        q["storylineGroups"] = [[q["id"], other["id"]], [third["id"]]]
        before = copy.deepcopy(q.get("requires"))
        known = q["requirementsKnown"]
        catalog.validate(self.data)
        self.assertEqual(q.get("requires"), before)
        self.assertEqual(q["requirementsKnown"], known)
        self.assertIn('["storylineGroups"] = { { ', catalog.generate(self.data))

    def test_storyline_groups_reject_malformed_dangling_duplicate_and_mixed_forms(self):
        first, second = [q["id"] for q in self.data["quests"][:2]]
        invalid = (None, True, {}, [], [[first]] * 101, [first], [[]], [[first] * 101],
                   [[True]], [[str(first)]], [[99999999]], [[first, first]], [[first], [first]])
        for value in invalid:
            with self.subTest(value=value):
                data = copy.deepcopy(self.data)
                data["quests"][0].pop("storyline", None)
                data["quests"][0]["storylineGroups"] = value
                with self.assertRaises(ValueError):
                    catalog.validate(data)
        self.data["quests"][0].update(storyline=[first], storylineGroups=[[first, second]])
        with self.assertRaisesRegex(ValueError, "Ambiguous"):
            catalog.validate(self.data)


if __name__ == "__main__":
    unittest.main()
