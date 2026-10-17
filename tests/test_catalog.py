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

    def test_quest_source_must_identify_the_same_forever_quest(self):
        for source in (
            "https://www.wowhead.com/forever/quest=132",
            "https://www.wowhead.com/forever/npc=65",
            "https://www.wowhead.com/forever/quest=650",
            "https://www.wowhead.com/forever/quest=65/another/path",
            "https://www.wowhead.com/classic/quest=65",
            "http://www.wowhead.com/forever/quest=65",
            None, 65, {},
        ):
            with self.subTest(source=source):
                self.data["quests"][0]["source"] = source
                with self.assertRaisesRegex(ValueError, "Forever source"):
                    catalog.validate(self.data)

    def test_matching_quest_source_allows_the_original_title_slug(self):
        for source in (
            "https://www.wowhead.com/forever/quest=65",
            "https://www.wowhead.com/forever/quest=65/the-defias-brotherhood",
        ):
            self.data["quests"][0]["source"] = source
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

    def test_item_container_sources_preserve_facts_and_generate_without_mutation(self):
        quest = self.data["quests"][0]
        quest["start"] = {"itemID": 5791, "name": "Henrig's Journal"}
        for container in (
            {"objectID": 19861, "name": "Henrig Lonebrow's Journal"},
            {"objectID": 19861, "name": "Journal", "zoneName": "Zone", "mapID": 1441},
            {"objectID": 19861, "name": "Journal", "mapID": 1441, "x": 0, "y": 100,
             "reportedLocations": [{"mapID": 1441, "x": 0, "y": 100},
                                   {"mapID": 1441, "x": 1.5, "y": 99}]},
            {"objectID": 19861, "name": "Journal",
             "reportedLocations": [{"mapID": 1441, "x": 0, "y": 100},
                                   {"mapID": 1442, "x": 1, "y": 99, "zoneName": "Other"}]},
        ):
            with self.subTest(container=container):
                quest["start"]["containerSource"] = container
                before = copy.deepcopy(self.data)
                self.assertIs(catalog.validate(self.data), self.data)
                self.assertIn('["containerSource"]', catalog.generate(self.data))
                self.assertEqual(self.data, before)

    def test_item_container_source_requires_strict_object_identity(self):
        invalid = [None, False, [], "Journal", {}, {"name": "Journal"},
                   {"objectID": 19861}, {"objectID": 19861, "name": " "},
                   {"objectID": 19861, "name": "x" * 501}]
        invalid.extend({"objectID": value, "name": "Journal"}
                       for value in (None, True, False, 0, -1, 19861.0, "19861"))
        invalid.extend({"objectID": 19861, "name": value}
                       for value in (None, True, 19861, [], {}))
        invalid.extend({"objectID": 19861, "name": "Journal", field: value}
                       for field, value in (("npcID", 1), ("itemID", 1), ("containerSource", {}),
                                            ("dropSources", []), ("dungeonKey", "dm"),
                                            ("unexpected", True)))
        for container in invalid:
            with self.subTest(container=container):
                self.data["quests"][0]["start"] = {"itemID": 5791, "containerSource": container}
                before = copy.deepcopy(self.data)
                with self.assertRaises(ValueError):
                    catalog.validate(self.data)
                self.assertEqual(self.data, before)

    def test_item_container_source_is_restricted_to_single_item_start(self):
        container = {"objectID": 19861, "name": "Journal"}
        fixtures = [
            {"start": {"npcID": 234, "containerSource": container}},
            {"start": {"objectID": 234, "containerSource": container}},
            {"start": {"containerSource": container}},
            {"finish": {"itemID": 5791, "containerSource": container}},
            {"startAlternatives": [{"npcID": 234, "name": "One", "containerSource": container},
                                   {"npcID": 235, "name": "Two"}]},
            {"finishAlternatives": [{"objectID": 234, "name": "One", "containerSource": container},
                                    {"objectID": 235, "name": "Two"}]},
            {"start": {"itemID": 5791, "dropSources": [
                {"npcID": 234, "name": "NPC", "locationName": "Zone", "containerSource": container}]}},
        ]
        for fixture in fixtures:
            with self.subTest(fixture=fixture):
                data = copy.deepcopy(self.data)
                quest = data["quests"][0]
                for key in ("start", "finish", "startAlternatives", "finishAlternatives"):
                    quest.pop(key, None)
                quest.update(fixture)
                before = copy.deepcopy(data)
                with self.assertRaises(ValueError):
                    catalog.validate(data)
                self.assertEqual(data, before)

    def test_item_container_source_reuses_location_validation(self):
        invalid = [
            {"mapID": True}, {"mapID": 0}, {"zoneName": " "}, {"zoneName": "x" * 501},
            {"x": 1}, {"x": 1, "y": 2}, {"mapID": 1, "x": True, "y": 2},
            {"mapID": 1, "x": float("nan"), "y": 2}, {"mapID": 1, "x": 2, "y": 101},
            {"reportedLocations": None}, {"reportedLocations": []},
            {"reportedLocations": [{"mapID": 1, "x": 1, "y": 2}]},
            {"reportedLocations": [{"mapID": 1, "x": 1, "y": 2}] * 2},
            {"mapID": 1, "x": 3, "y": 4, "reportedLocations": [
                {"mapID": 1, "x": 1, "y": 2}, {"mapID": 1, "x": 2, "y": 3}]},
        ]
        for fields in invalid:
            with self.subTest(fields=fields):
                self.data["quests"][0]["start"] = {"itemID": 5791, "containerSource": {
                    "objectID": 19861, "name": "Journal", **fields}}
                before = copy.deepcopy(self.data)
                with self.assertRaises(ValueError):
                    catalog.validate(self.data)
                self.assertEqual(self.data, before)

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

    def test_starter_item_requirements_preserve_separate_quest_restrictions(self):
        quest = self.data["quests"][0]
        before = {key: copy.deepcopy(quest.get(key)) for key in ("classes", "minLevel", "requirementsKnown", "requires")}
        quest["start"] = {"itemID": 18469, "itemClasses": ["WARRIOR", "PALADIN"], "itemMinLevel": 54}
        catalog.validate(self.data)
        for key, value in before.items():
            self.assertEqual(quest.get(key), value)
        generated = catalog.generate(self.data)
        self.assertIn('["itemClasses"] = { "WARRIOR", "PALADIN" }', generated)
        self.assertIn('["itemMinLevel"] = 54', generated)

    def test_starter_item_requirements_reject_invalid_types_and_tokens(self):
        invalid = {
            "itemClasses": [None, [], {}, "MAGE", [True], [8], ["mage"], ["MGAE"], ["MAGE", "MAGE"]],
            "itemMinLevel": [None, False, 0, -1, 54.0, "54", [], {}, float("inf")],
        }
        for field, values in invalid.items():
            for value in values:
                with self.subTest(field=field, value=value):
                    data = copy.deepcopy(self.data)
                    data["quests"][0]["start"] = {"itemID": 18469, field: value}
                    with self.assertRaisesRegex(ValueError, "starter item"):
                        catalog.validate(data)

    def test_item_requirements_are_only_valid_on_item_starts(self):
        for field in ("itemClasses", "itemMinLevel"):
            value = ["MAGE"] if field == "itemClasses" else 54
            for key, place in (("start", {"npcID": 234}), ("start", {"objectID": 123}),
                               ("finish", {"itemID": 18469})):
                with self.subTest(field=field, key=key, place=place):
                    data = copy.deepcopy(self.data)
                    data["quests"][0][key] = {**place, field: value}
                    with self.assertRaisesRegex(ValueError, "without starter item"):
                        catalog.validate(data)

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

    def test_alternative_turnins_use_shared_place_rules_without_single_destination(self):
        q = self.data["quests"][0]
        q.pop("finish", None)
        q["finishAlternatives"] = [{"npcID": 8888, "name": "Franclorn", "zoneName": "Blackrock Mountain"},
                                   {"objectID": 8888, "name": "Monument", "mapID": 1, "x": 0, "y": 100}]
        catalog.validate(self.data)
        self.assertIn('["finishAlternatives"]', catalog.generate(self.data))
        self.assertNotIn("finish", q)
        for invalid in (None, True, {}, [], q["finishAlternatives"][:1], q["finishAlternatives"] * 51,
                        [{"npcID": 1, "name": "A"}] * 2,
                        [{"npcID": True, "name": "A"}, {"objectID": 2, "name": "B"}],
                        [{"itemID": 1, "name": "A"}, {"npcID": 2, "name": "B"}],
                        [{"npcID": 1, "objectID": 2, "name": "A"}, {"npcID": 2, "name": "B"}]):
            with self.subTest(invalid=invalid):
                data = copy.deepcopy(self.data)
                data["quests"][0]["finishAlternatives"] = invalid
                with self.assertRaises(ValueError): catalog.validate(data)
        for fields in ({"mapID": True}, {"x": 10}, {"x": 10, "y": 20},
                       {"mapID": 1, "x": float("inf"), "y": 10},
                       {"zoneName": " "}, {"dungeonKey": "missing"}):
            data = copy.deepcopy(self.data)
            data["quests"][0]["finishAlternatives"][0].update(fields)
            with self.subTest(fields=fields), self.assertRaises(ValueError): catalog.validate(data)
        for finish in (None, {"npcID": 8888}):
            data = copy.deepcopy(self.data)
            data["quests"][0]["finish"] = finish
            with self.assertRaisesRegex(ValueError, "single and alternative"):
                catalog.validate(data)


    def test_reported_locations_reject_invalid_outer_and_nested_shapes(self):
        point = {"mapID": 1, "x": 10, "y": 20}
        invalids = [None, False, "points", {}, [], [point], [point] * 101,
                    [point, None], [point, []], [point, "point"], [point, {}],
                    [point, {"mapID": 2, "x": 10}], [point, {"x": 10, "y": 20}],
                    [point, {"mapID": 2, "x": 10, "y": 20, "npcID": 3}],
                    [point, {"mapID": 2, "x": 10, "y": 20, "unexpected": "field"}]]
        for value in invalids:
            data = self.minimal_catalog()
            data["quests"][1]["start"] = {"npcID": 1, "reportedLocations": value}
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "reported location"):
                catalog.validate(data)

    def test_reported_locations_require_clean_map_coordinates_and_optional_zone(self):
        fields = {
            "mapID": [None, False, True, 0, -1, 1.0, "1", {}, float("inf")],
            "x": [None, False, True, -0.1, 100.1, "10", {}, float("inf"), float("nan")],
            "y": [None, False, True, -0.1, 100.1, "20", [], float("inf"), float("nan")],
            "zoneName": [None, False, 1, {}, "", " \t\n", "x" * 501],
        }
        for field, values in fields.items():
            for value in values:
                data = self.minimal_catalog()
                point = {"mapID": 2, "x": 10, "y": 20, field: value}
                data["quests"][1]["finish"] = {"objectID": 1, "reportedLocations": [
                    {"mapID": 1, "x": 0, "y": 100}, point]}
                with self.subTest(field=field, value=value), self.assertRaisesRegex(ValueError, "reported location"):
                    catalog.validate(data)

    def test_reported_locations_reject_duplicate_points_and_missing_primary_point(self):
        for points in ([{"mapID": 1, "x": 10, "y": 20}, {"mapID": 1, "x": 10.0, "y": 20.0}],
                       [{"mapID": 2, "x": 10, "y": 20}, {"mapID": 3, "x": 10, "y": 20}]):
            data = self.minimal_catalog()
            data["quests"][1]["start"] = {"npcID": 1, "mapID": 1, "x": 10, "y": 20,
                                          "reportedLocations": points}
            with self.subTest(points=points), self.assertRaisesRegex(ValueError, "reported location"):
                catalog.validate(data)

    def test_reported_locations_belong_only_to_npc_or_object_endpoints(self):
        points = [{"mapID": 1, "x": 10, "y": 20}, {"mapID": 2, "x": 30, "y": 40}]
        for identity in ({}, {"name": "Unknown giver"}, {"itemID": 10}):
            data = self.minimal_catalog()
            data["quests"][1]["start"] = {**identity, "reportedLocations": points}
            with self.subTest(identity=identity), self.assertRaisesRegex(ValueError, "reported location"):
                catalog.validate(data)
        data = self.minimal_catalog()
        data["quests"][1]["start"] = {"itemID": 10, "dropSources": [
            {"npcID": 1, "name": "Drop NPC", "locationName": "Zone", "reportedLocations": points}]}
        with self.assertRaisesRegex(ValueError, "reported location"):
            catalog.validate(data)

    def test_reported_locations_preserve_candidates_without_changing_quest_requirements(self):
        data = self.minimal_catalog()
        quest = data["quests"][1]
        quest["requirementsKnown"] = False
        quest["classes"] = ["MAGE"]
        quest["start"] = {"npcID": 1, "mapID": 1, "x": 0, "y": 100, "reportedLocations": [
            {"mapID": 1, "x": 0, "y": 100}, {"mapID": 2, "x": 100.0, "y": 0, "zoneName": "x" * 500}]}
        before = copy.deepcopy(data)
        catalog.validate(data)
        generated = catalog.generate(data)
        self.assertEqual(data, before)
        self.assertIn('["reportedLocations"]', generated)
        self.assertIn('["mapID"] = 2', generated)
        quest["start"].pop("x")
        quest["start"].pop("y")
        quest["start"]["mapID"] = 99
        catalog.validate(data)
        quest["finishAlternatives"] = [
            {"objectID": 10, "name": "First", "reportedLocations": quest["start"]["reportedLocations"]},
            {"npcID": 11, "name": "Second"}]
        catalog.validate(data)
        quest["start"]["reportedLocations"] = [{"mapID": 1, "x": i, "y": 0} for i in range(100)]
        catalog.validate(data)

    @staticmethod
    def minimal_catalog():
        return {"schema": 1, "quests": [
            {"id": 1, "name": "Parent", "minLevel": 1, "requirementsKnown": True,
             "source": "https://www.wowhead.com/forever/quest=1"},
            {"id": 2, "name": "Target", "minLevel": 1, "requirementsKnown": True,
             "source": "https://www.wowhead.com/forever/quest=2"},
        ], "dungeons": [{"key": "test", "name": "Test", "minLevel": 1, "maxLevel": 10,
                          "coverage": "partial", "quests": [2]}]}

    def test_requirement_and_story_collections_require_lists(self):
        for field in ("requires", "storyline"):
            for invalid in (None, "", "1", False, 1, {}):
                data = self.minimal_catalog()
                data["quests"][1][field] = invalid
                with self.subTest(field=field, invalid=invalid), self.assertRaises(ValueError):
                    catalog.validate(data)
        for invalid in (None, "", "1", False, 1, {}):
            data = self.minimal_catalog()
            data["dungeons"][0]["quests"] = invalid
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                catalog.validate(data)

    def test_requirement_groups_and_ids_have_explicit_types(self):
        for invalid in (None, False, "ids", [], 1):
            data = self.minimal_catalog()
            data["quests"][1]["requires"] = [invalid]
            with self.subTest(group=invalid), self.assertRaises(ValueError):
                catalog.validate(data)
        for invalid in (None, False, "", "1", {}, 1, []):
            data = self.minimal_catalog()
            data["quests"][1]["requires"] = [{"ids": invalid}]
            with self.subTest(ids=invalid), self.assertRaises(ValueError):
                catalog.validate(data)

    def test_reference_ids_reject_boolean_numeric_aliases_before_membership(self):
        for invalid in (True, False, 1.0, 0, -1, "1", None, {}, []):
            for field in ("requires", "storyline", "dungeon"):
                data = self.minimal_catalog()
                if field == "requires":
                    data["quests"][1][field] = [{"ids": [invalid]}]
                elif field == "storyline":
                    data["quests"][1][field] = [invalid]
                else:
                    data["dungeons"][0]["quests"] = [invalid]
                with self.subTest(field=field, invalid=invalid), self.assertRaises(ValueError):
                    catalog.validate(data)

    def test_display_names_and_dungeon_keys_require_nonblank_strings(self):
        for invalid in (None, False, True, 1, {}, {"bad": "name"}, [], "", " \t\n"):
            for field in ("quest", "dungeon", "key", "name", "dropName"):
                data = self.minimal_catalog()
                if field == "quest":
                    data["quests"][1]["name"] = invalid
                elif field in ("dungeon", "key"):
                    data["dungeons"][0]["key" if field == "key" else "name"] = invalid
                else:
                    data["quests"][1]["start"] = {field: invalid}
                with self.subTest(field=field, invalid=invalid), self.assertRaises(ValueError):
                    catalog.validate(data)

    def test_omitted_unknown_fields_and_legitimate_empty_lists_stay_valid(self):
        data = self.minimal_catalog()
        catalog.validate(data)
        target = data["quests"][1]
        target.update(requires=[], storyline=[], start={}, finish={})
        data["dungeons"][0]["quests"] = []
        catalog.validate(data)
        self.assertIn('["storyline"] = {  }', catalog.generate(data))
        target["requires"] = [{"ids": [1], "mode": "active"}]
        target["storyline"] = [1, 2]
        data["dungeons"][0]["quests"] = [1, 2]
        target["start"] = {"name": "Known giver", "dropName": "Known drop source"}
        catalog.validate(data)


    def test_wing_metadata_requires_a_known_wing_and_instance(self):
        for wing in (None, False, 1, {}, [], "", "north", "LOWER"):
            data = self.minimal_catalog()
            data["dungeons"][0].update(instanceID=229, wing=wing)
            with self.subTest(wing=wing), self.assertRaisesRegex(ValueError, "dungeon wing"):
                catalog.validate(data)
        data = self.minimal_catalog()
        data["dungeons"][0]["wing"] = "lower"
        with self.assertRaisesRegex(ValueError, "dungeon wing"):
            catalog.validate(data)

    def test_shared_instance_names_need_distinct_explicit_wings(self):
        for lower, upper in ((None, None), (None, "upper"), ("lower", "lower")):
            data = self.minimal_catalog()
            first = data["dungeons"][0]
            first["instanceID"] = 229
            second = copy.deepcopy(first)
            second.update(key="second", name="Second wing")
            if lower is not None:
                first["wing"] = lower
            if upper is not None:
                second["wing"] = upper
            data["dungeons"].append(second)
            with self.subTest(wings=(lower, upper)), self.assertRaisesRegex(ValueError, "shared dungeon map"):
                catalog.validate(data)
        first["wing"], second["wing"] = "lower", "upper"
        before = copy.deepcopy(data)
        catalog.validate(data)
        self.assertEqual(data, before)
        self.assertIn('["wing"] = "lower"', catalog.generate(data))
        self.assertIn('["wing"] = "upper"', catalog.generate(data))


    def test_objective_items_preserve_only_informational_facts(self):
        data = self.minimal_catalog()
        quest = data["quests"][0]
        quest["requirementsKnown"] = False
        quest["objectiveItems"] = [{"itemID": 10001, "quantity": 2, "name": "Listed material"},
                                   {"itemID": 10002, "quantity": 1}]
        before = copy.deepcopy(data)
        catalog.validate(data)
        generated = catalog.generate(data)
        self.assertEqual(data, before)
        self.assertIn('["objectiveItems"]', generated)
        self.assertIn('["quantity"] = 2', generated)
        self.assertFalse(quest["requirementsKnown"])
        self.assertNotIn("requires", quest)

    def test_omitted_objective_quantities_are_retained_without_a_default(self):
        data = self.minimal_catalog()
        data["quests"][0]["requirementsKnown"] = False
        data["quests"][0]["objectiveItems"] = [
            {"itemID": 10001, "name": "Known item, unknown count"},
            {"itemID": 10002, "quantity": 2},
            {"itemID": 10003},
        ]
        before = copy.deepcopy(data)
        catalog.validate(data)
        generated = catalog.generate(data)
        self.assertEqual(data, before)
        self.assertEqual(generated.count('["quantity"]'), 1)
        self.assertIn('["quantity"] = 2', generated)
        self.assertNotIn('["quantity"] = 1', generated)
        self.assertFalse(data["quests"][0]["requirementsKnown"])
        self.assertNotIn("requires", data["quests"][0])

    def test_unknown_quantity_does_not_relax_present_values_or_duplicate_identity(self):
        for quantity in (None, False, True, 0, -1, 1.5, "1", float("inf"), 2 ** 53):
            with self.subTest(quantity=quantity):
                data = self.minimal_catalog()
                data["quests"][0]["objectiveItems"] = [{"itemID": 10001, "quantity": quantity}]
                with self.assertRaisesRegex(ValueError, "objective item"):
                    catalog.validate(data)
        data = self.minimal_catalog()
        data["quests"][0]["objectiveItems"] = [{"itemID": 10001}, {"itemID": 10001, "quantity": 2}]
        with self.assertRaisesRegex(ValueError, "Duplicate objective item"):
            catalog.validate(data)

    def test_dungeon_artwork_keeps_exact_source_identity(self):
        data = self.minimal_catalog()
        dungeon = data["dungeons"][0]
        art = {"fileID": 131833, "gameMapID": 36, "loadingScreenID": 142,
               "source": "https://wago.tools/db2/LoadingScreens?build=1.60.1.70425&filter%5BID%5D=exact%3A142"}
        dungeon["art"] = art
        dungeon["instanceID"] = 36
        before = copy.deepcopy(data)
        catalog.validate(data)
        self.assertEqual(data, before)
        self.assertIn('["fileID"] = 131833', catalog.generate(data))
        for field in ("fileID", "gameMapID", "loadingScreenID"):
            for value in (None, False, 0, -1, 1.5, "36", 2 ** 32):
                invalid = copy.deepcopy(data)
                invalid["dungeons"][0]["art"][field] = value
                with self.subTest(field=field, value=value), self.assertRaisesRegex(ValueError, "artwork"):
                    catalog.validate(invalid)
        for value in (None, {}, {**art, "source": "https://example.com"},
                      {**art, "extra": True}, {**art, "gameMapID": 43}):
            invalid = copy.deepcopy(data)
            invalid["dungeons"][0]["art"] = value
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "artwork"):
                catalog.validate(invalid)

    def test_art_preview_dimensions_require_bound_provenance(self):
        data = self.minimal_catalog()
        art = {"fileID": 7963781, "gameMapID": 2891, "loadingScreenID": 1,
               "source": "https://wago.tools/db2/LoadingScreens?build=1.60.1.70425&filter%5BID%5D=exact%3A1",
               "previewWidth": 2992, "previewHeight": 1684,
               "previewSource": "https://wago.tools/files?search=7963781",
               "previewVersion": "1.60.1.69876",
               "previewContentHash": "33f782f04c00ea1c93c01280b09963f8"}
        data["dungeons"][0]["art"] = art
        before = copy.deepcopy(data)
        catalog.validate(data)
        self.assertEqual(data, before)
        self.assertIn('["previewWidth"] = 2992', catalog.generate(data))
        fields = ("previewWidth", "previewHeight", "previewSource", "previewVersion", "previewContentHash")
        for field in fields:
            invalid = copy.deepcopy(data)
            del invalid["dungeons"][0]["art"][field]
            with self.subTest(missing=field), self.assertRaisesRegex(ValueError, "artwork preview"):
                catalog.validate(invalid)
        for field, values in (("previewWidth", (True, 0, -1, 1.5, "2992", 16385)),
                              ("previewHeight", (None, False, 0, float("inf"), 16385)),
                              ("previewSource", ("https://example.com", "https://wago.tools/files?search=7963782")),
                              ("previewVersion", (None, "", "1.60.1", "1.60.1.69876\n")),
                              ("previewContentHash", (None, "a" * 31, "z" * 32, "a" * 32 + "\n"))):
            for value in values:
                invalid = copy.deepcopy(data)
                invalid["dungeons"][0]["art"][field] = value
                with self.subTest(field=field, value=value), self.assertRaisesRegex(ValueError, "artwork preview"):
                    catalog.validate(invalid)

    def test_invalid_objective_items_are_rejected(self):
        invalid = [None, False, {}, [], [None], [False], [1], [[]], [{}],
                   [{"quantity": 1}],
                   [{"itemID": 1, "quantity": 1, "requires": []}],
                   [{"itemID": 1, "quantity": 1}] * 101,
                   [{"itemID": 1, "quantity": 1}, {"itemID": 1, "quantity": 2}]]
        for field in ("itemID", "quantity"):
            for value in (None, False, True, "1", 0, -1, 1.5, float("nan"), float("inf"), 2 ** 53):
                entry = {"itemID": 1, "quantity": 1}
                entry[field] = value
                invalid.append([entry])
        for value in (None, False, 1, "", "   ", "x" * 501):
            invalid.append([{"itemID": 1, "quantity": 1, "name": value}])
        for value in invalid:
            with self.subTest(value=value):
                data = self.minimal_catalog()
                data["quests"][0]["objectiveItems"] = value
                with self.assertRaisesRegex(ValueError, "objective item"):
                    catalog.validate(data)


if __name__ == "__main__":
    unittest.main()
