import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("catalog", ROOT / "scripts/catalog.py")
catalog = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(catalog)


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads((ROOT / "data/catalog.json").read_text(encoding="utf-8"))

    def test_required_money_is_optional_copper_amount_without_mutation_or_role_promotion(self):
        quest = next(q for q in self.data["quests"] if q["id"] == 2945)
        quest.pop("requiredMoney", None)
        original = copy.deepcopy(quest)
        baseline = catalog.generate(self.data)
        quest["requiredMoney"] = 300  # Explicit source3silver, normalized offline to copper.
        before = copy.deepcopy(self.data)
        generated = catalog.generate(self.data)
        self.assertEqual(self.data, before)
        self.assertIn('["requiredMoney"] = 300', generated)
        for field in ("requires", "requirementsKnown", "start", "finish", "source", "providedItems"):
            self.assertEqual(quest.get(field), original.get(field))
        self.assertNotIn("quantity", quest["providedItems"][0])
        del quest["requiredMoney"]
        self.assertEqual(quest, original)
        self.assertEqual(catalog.generate(self.data), baseline)

    def test_required_money_rejects_unknown_zero_alias_and_unbounded_values(self):
        for value in (None, False, True, 0, -1, 1.0, 1.5, "300", {}, [], float("nan"), float("inf"), 2 ** 53):
            with self.subTest(value=repr(value)):
                self.data["quests"][0]["requiredMoney"] = value
                with self.assertRaisesRegex(ValueError, "required money"):
                    catalog.validate(self.data)

    def test_required_money_accepts_exact_positive_copper_boundaries(self):
        for amount in (1, 100, 300, 2 ** 53 - 1):
            with self.subTest(amount=amount):
                self.data["quests"][0]["requiredMoney"] = amount
                before = copy.deepcopy(self.data)
                catalog.validate(self.data)
                self.assertEqual(self.data, before)

    def test_objective_events_preserve_unknown_task_count_and_independent_roles(self):
        quest = next(q for q in self.data["quests"] if q["id"] == 95647)
        quest.pop("objectiveEvents", None)
        original = copy.deepcopy(quest)
        baseline = catalog.generate(self.data)
        quest["objectiveEvents"] = [{"npcID": 262681, "name": "Learn what happened to Ardin Grassman"}]
        # A typed event credit does not deduplicate or infer another independently listed role.
        quest["objectiveKills"] = [{"npcID": 262681, "name": "Separate proven slain row", "quantity": 2}]
        quest["objectiveObjects"] = [{"objectID": 262681, "name": "Separate object task"}]
        quest["objectiveItems"] = [{"itemID": 262681, "name": "Separate item", "quantity": 3}]
        before = copy.deepcopy(self.data)
        generated = catalog.generate(self.data)
        self.assertEqual(self.data, before)
        self.assertIn('["objectiveEvents"]', generated)
        self.assertNotIn("quantity", quest["objectiveEvents"][0])
        for field in ("requires", "requirementsKnown", "start", "finish", "source", "factions", "races"):
            self.assertEqual(quest.get(field), original.get(field))
        self.assertIsNone(quest.get("finish"))
        for field in ("objectiveEvents", "objectiveKills", "objectiveObjects", "objectiveItems"):
            del quest[field]
        self.assertEqual(quest, original)
        self.assertEqual(catalog.generate(self.data), baseline)

    def test_objective_events_reject_untyped_roles_keys_and_invalid_containers(self):
        valid = {"npcID": 262681, "name": "Learn what happened"}
        for rows in (None, {}, [], [None], [False], [1], ["Event"], [valid] * 101,
                     [{"itemID": 1, "name": "Item"}], [{"objectID": 1, "name": "Object"}],
                     *[[{**valid, key: 1}] for key in ("itemID", "objectID", "mapID", "x", "action", "required", "creatureDisplayID", "dropNPCID")]):
            with self.subTest(rows=rows):
                self.data["quests"][0]["objectiveEvents"] = rows
                with self.assertRaisesRegex(ValueError, "objective event"):
                    catalog.validate(self.data)
        self.data["quests"][0]["objectiveEvents"] = [{"npcID": i + 1, "name": "Event"} for i in range(100)]
        catalog.validate(self.data)

    def test_objective_events_reject_alias_ids_and_present_invalid_counts(self):
        for field, maximum in (("npcID", 2 ** 32 - 1), ("quantity", 2 ** 53 - 1)):
            for value in (None, False, True, 0, -1, 1.0, 1.5, "1", float("nan"), float("inf"), maximum + 1):
                with self.subTest(field=field, value=repr(value)):
                    self.data["quests"][0]["objectiveEvents"] = [{"npcID": 1, "name": "Event", field: value}]
                    with self.assertRaisesRegex(ValueError, "objective event"):
                        catalog.validate(self.data)
        self.data["quests"][0]["objectiveEvents"] = [{"npcID": 2 ** 32 - 1, "name": "Event", "quantity": 2 ** 53 - 1}]
        catalog.validate(self.data)

    def test_objective_events_require_bounded_labels_and_unique_event_identity(self):
        for name in (None, False, 1, "", " \t\n", "x" * 501, "中" * 167, "😀" * 126, "\ud800"):
            with self.subTest(name=repr(name)):
                self.data["quests"][0]["objectiveEvents"] = [{"npcID": 1, "name": name}]
                with self.assertRaisesRegex(ValueError, "objective event name"):
                    catalog.validate(self.data)
        self.data["quests"][0]["objectiveEvents"] = [{"npcID": 1}]
        with self.assertRaisesRegex(ValueError, "objective event name"):
            catalog.validate(self.data)
        for name in ("x" * 500, "中" * 166, "Ж" * 250, "😀" * 125):
            self.data["quests"][0]["objectiveEvents"] = [{"npcID": 1, "name": name}]
            catalog.validate(self.data)
        self.data["quests"][0]["objectiveEvents"] = [{"npcID": 1, "name": "Event A"}, {"npcID": 1, "name": "Event B"}]
        with self.assertRaisesRegex(ValueError, "Duplicate objective event"):
            catalog.validate(self.data)

    def test_objective_objects_preserve_typed_partial_tasks_and_unknown_quantities(self):
        quest = next(q for q in self.data["quests"] if q["id"] == 5382)
        # Exercise the optional-absent input independently of current catalogue coverage.
        quest.pop("objectiveObjects", None)
        original = copy.deepcopy(quest)
        quest["objectiveObjects"] = [
            {"objectID": 176544, "name": "Remains of Eva Sarkhoff Burned"},
            {"objectID": 176545, "name": "Remains of Lucien Sarkhoff Burned"},
        ]
        # Equal numeric IDs in other roles are distinct identities, not duplicate objects.
        quest["objectiveItems"] = [{"itemID": 176544, "name": "Separate item", "quantity": 2}]
        before = copy.deepcopy(self.data)
        generated = catalog.generate(self.data)
        self.assertEqual(self.data, before)
        self.assertIn('["objectiveObjects"]', generated)
        self.assertTrue(all("quantity" not in row for row in quest["objectiveObjects"]))
        self.assertEqual(quest["objectiveKills"], original["objectiveKills"])
        for field in ("requires", "requirementsKnown", "start", "finish", "source"):
            self.assertEqual(quest.get(field), original.get(field))
        del quest["objectiveObjects"]
        del quest["objectiveItems"]
        self.assertEqual(quest, original)

    def test_objective_objects_reject_nonobject_roles_and_invalid_lists(self):
        valid = {"objectID": 176544, "name": "Remains burned"}
        for rows in (None, {}, [], [None], [False], [1], ["Object"], [valid] * 101,
                     [{"npcID": 176544, "name": "NPC"}], [{"itemID": 176544, "name": "Item"}],
                     [{**valid, "npcID": 1}], [{**valid, "mapID": 1}],
                     [{**valid, "action": "click"}], [{**valid, "required": True}],
                     [{**valid, "creatureDisplayID": 1}]):
            with self.subTest(rows=rows):
                self.data["quests"][0]["objectiveObjects"] = rows
                with self.assertRaisesRegex(ValueError, "objective object"):
                    catalog.validate(self.data)
        self.data["quests"][0]["objectiveObjects"] = [
            {"objectID": i + 1, "name": "Object task"} for i in range(100)]
        catalog.validate(self.data)

    def test_objective_objects_reject_invalid_ids_and_present_unknown_quantities(self):
        for field, values in (("objectID", (None, False, True, 0, -1, 1.0, 1.5, "1",
                                           float("nan"), float("inf"), 2 ** 32)),
                              ("quantity", (None, False, True, 0, -1, 1.0, 1.5, "1",
                                            float("nan"), float("inf"), 2 ** 53))):
            for value in values:
                with self.subTest(field=field, value=repr(value)):
                    self.data["quests"][0]["objectiveObjects"] = [
                        {"objectID": 1, "name": "Object task", field: value}]
                    with self.assertRaisesRegex(ValueError, "objective object"):
                        catalog.validate(self.data)
        self.data["quests"][0]["objectiveObjects"] = [
            {"objectID": 2 ** 32 - 1, "name": "Object task", "quantity": 2 ** 53 - 1}]
        catalog.validate(self.data)

    def test_objective_objects_require_unique_identity_and_utf8_bounded_labels(self):
        for name in (None, False, 1, "", " \t\n", "x" * 501, "中" * 167, "😀" * 126, "\ud800"):
            with self.subTest(name=repr(name)):
                self.data["quests"][0]["objectiveObjects"] = [{"objectID": 1, "name": name}]
                with self.assertRaisesRegex(ValueError, "objective object name"):
                    catalog.validate(self.data)
        self.data["quests"][0]["objectiveObjects"] = [{"objectID": 1}]
        with self.assertRaisesRegex(ValueError, "objective object name"):
            catalog.validate(self.data)
        for name in ("x" * 500, "中" * 166, "Ж" * 250, "😀" * 125):
            self.data["quests"][0]["objectiveObjects"] = [{"objectID": 1, "name": name}]
            catalog.validate(self.data)
        self.data["quests"][0]["objectiveObjects"] = [
            {"objectID": 1, "name": "First label"}, {"objectID": 1, "name": "Second label"}]
        with self.assertRaisesRegex(ValueError, "Duplicate objective object"):
            catalog.validate(self.data)

    def test_generated_data_matches(self):
        self.assertEqual(catalog.generate(self.data), (ROOT / "Database/Catalog.lua").read_text(encoding="utf-8"))

    def test_duplicate_json_fields_fail_before_replacing_generated_catalogue(self):
        # Even equal values or JSON-escaped spellings are ambiguous source facts.
        original = json.dumps(self.data)
        documents = (
            original.replace('"schema": 1', '"schema": 1, "schema": 1', 1),
            original.replace('"requirementsKnown": false',
                             '"requirementsKnown": true, "requirementsKnown": false', 1),
            original.replace('"name": ', '"na\\u006de": "Shadowed name", "name": ', 1),
        )
        for index, document in enumerate(documents):
            for check in (False, True):
                with self.subTest(case=index, check=check), tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    (root / "data").mkdir()
                    (root / "Database").mkdir()
                    (root / "data/catalog.json").write_text(document, encoding="utf-8")
                    target = root / "Database/Catalog.lua"
                    target.write_bytes(b"existing generated catalogue\n")
                    arguments = ["catalog.py"] + (["--check"] if check else [])
                    with patch.object(catalog, "ROOT", root), patch("sys.argv", arguments):
                        with self.assertRaisesRegex(ValueError, "Duplicate catalogue key"):
                            catalog.main()
                    self.assertEqual(target.read_bytes(), b"existing generated catalogue\n")

    def test_objective_kills_preserve_sourced_counts_without_requirement_inference(self):
        data = copy.deepcopy(self.data)
        quest = data["quests"][0]
        quest["objectiveKills"] = [{"npcID": 11318, "name": "Ragefire Trogg", "quantity": 8},
                                   {"npcID": 11519, "name": "Bazzalan"}]
        before = copy.deepcopy(data)
        catalog.validate(data)
        generated = catalog.generate(data)
        self.assertEqual(before, data)
        self.assertIn('["objectiveKills"]', generated)
        self.assertEqual(quest["objectiveKills"][1], {"npcID": 11519, "name": "Bazzalan"})
        self.assertEqual(quest.get("requires"), self.data["quests"][0].get("requires"))
        self.assertEqual(quest["requirementsKnown"], self.data["quests"][0]["requirementsKnown"])

    def test_objective_kills_reject_invalid_lists_and_non_npc_roles(self):
        for kills in (None, {}, [], [None], [1], [True], ["NPC"],
                      [{"npcID": 1, "name": "A"}] * 101,
                      [{"itemID": 1, "name": "A"}], [{"objectID": 1, "name": "A"}],
                      [{"npcID": 1, "name": "A", "itemID": 2}],
                      [{"npcID": 1, "name": "A", "mapID": 1}],
                      [{"npcID": 1, "name": "A", "sharedQuantity": 8}],
                      [{"npcID": 1, "name": "A", "creatureDisplayID": 1}]):
            with self.subTest(kills=kills):
                self.data["quests"][0]["objectiveKills"] = kills
                with self.assertRaisesRegex(ValueError, "objective kill"):
                    catalog.validate(self.data)

    def test_objective_kills_require_strict_bounded_identity_and_optional_explicit_quantity(self):
        for field, values in (("npcID", (None, False, True, 0, -1, 1.0, 1.5, "1", 2 ** 32)),
                              ("quantity", (None, False, True, 0, -1, 1.0, 1.5, "1",
                                            float("nan"), float("inf"), 2 ** 53))):
            for value in values:
                with self.subTest(field=field, value=value):
                    kill = {"npcID": 1, "name": "A", field: value}
                    self.data["quests"][0]["objectiveKills"] = [kill]
                    with self.assertRaisesRegex(ValueError, "objective kill"):
                        catalog.validate(self.data)
        self.data["quests"][0]["objectiveKills"] = [
            {"npcID": 2 ** 32 - 1, "name": "A", "quantity": 2 ** 53 - 1}]
        catalog.validate(self.data)

    def test_objective_kills_require_names_and_unique_npc_identity(self):
        for name in (None, False, 1, "", " \t\n", "x" * 501):
            with self.subTest(name=name):
                self.data["quests"][0]["objectiveKills"] = [{"npcID": 1, "name": name}]
                with self.assertRaisesRegex(ValueError, "objective kill name"):
                    catalog.validate(self.data)
        self.data["quests"][0]["objectiveKills"] = [
            {"npcID": 1, "name": "A"}, {"npcID": 1, "name": "Different label", "quantity": 8}]
        with self.assertRaisesRegex(ValueError, "Duplicate objective kill"):
            catalog.validate(self.data)

    def test_objective_kill_name_budget_matches_utf8_runtime_bytes(self):
        for name in ("x" * 500, "中" * 166, "Ж" * 250, "😀" * 125):
            with self.subTest(valid_bytes=len(name.encode("utf-8"))):
                self.data["quests"][0]["objectiveKills"] = [{"npcID": 1, "name": name}]
                catalog.validate(self.data)
        for name in ("x" * 501, "中" * 167, "Ж" * 251, "😀" * 126, "\ud800"):
            with self.subTest(invalid_name=repr(name)):
                self.data["quests"][0]["objectiveKills"] = [{"npcID": 1, "name": name}]
                with self.assertRaisesRegex(ValueError, "objective kill name"):
                    catalog.validate(self.data)

    def test_provided_items_preserve_unknown_counts_and_independent_roles(self):
        data = copy.deepcopy(self.data)
        quest = data["quests"][0]
        quest["providedItems"] = [{"itemID": 13523, "name": "Blood of Innocents"},
                                  {"itemID": 18746, "name": "Divination Scryer", "quantity": 2}]
        quest["objectiveItems"] = [{"itemID": 13523, "quantity": 8}]
        before = copy.deepcopy(data)
        catalog.validate(data)
        generated = catalog.generate(data)
        self.assertIn('["providedItems"]', generated)
        self.assertEqual(data, before)
        self.assertNotIn("quantity", quest["providedItems"][0])
        self.assertEqual(quest.get("requires"), self.data["quests"][0].get("requires"))
        self.assertEqual(quest["requirementsKnown"], self.data["quests"][0]["requirementsKnown"])

    def test_provided_items_require_distinct_typed_bounded_rows(self):
        valid = {"itemID": 13523, "name": "Blood of Innocents"}
        invalid = [None, {}, [], [None], [True], [valid] * 101, [valid, valid],
                   [{"npcID": 13523, "name": "NPC"}], [{"objectID": 13523, "name": "Object"}],
                   [{**valid, "required": True}], [{**valid, "objectID": 1}],
                   [{**valid, "classes": ["MAGE"]}]]
        for value in invalid:
            with self.subTest(value=value):
                self.data["quests"][0]["providedItems"] = value
                with self.assertRaisesRegex(ValueError, "provided item"):
                    catalog.validate(self.data)
        self.data["quests"][0]["providedItems"] = [
            {"itemID": i + 1, "name": "Provided"} for i in range(100)]
        catalog.validate(self.data)

    def test_provided_items_reject_invalid_identity_name_and_present_quantity(self):
        for field, values in (("itemID", (None, True, False, 0, -1, 1.0, 1.5, "1", 2 ** 32)),
                              ("name", (None, True, 1, "", " \n\t", "x" * 501, "中" * 167, "\ud800")),
                              ("quantity", (None, True, False, 0, -1, 1.0, 1.5, "1",
                                            float("inf"), float("nan"), 2 ** 53))):
            for value in values:
                with self.subTest(field=field, value=repr(value)):
                    self.data["quests"][0]["providedItems"] = [{"itemID": 1, "name": "Provided", field: value}]
                    with self.assertRaisesRegex(ValueError, "provided item"):
                        catalog.validate(self.data)
        self.data["quests"][0]["providedItems"] = [
            {"itemID": 2 ** 32 - 1, "name": "中" * 166, "quantity": 2 ** 53 - 1}]
        catalog.validate(self.data)

    def test_giver_portrait_requires_a_typed_npc_and_matching_forever_source(self):
        valid = {"npcID": 234, "name": "Gryan", "creatureDisplayID": 1690,
                 "portraitSource": "https://www.wowhead.com/forever/npc=234/gryan-stoutmantle"}
        self.data["quests"][0]["start"] = valid.copy()
        catalog.validate(self.data)
        self.assertIn('["creatureDisplayID"] = 1690', catalog.generate(self.data))
        for field, value in (("creatureDisplayID", None), ("creatureDisplayID", True),
                             ("creatureDisplayID", 0), ("creatureDisplayID", 1.5),
                             ("creatureDisplayID", 2 ** 32), ("creatureDisplayID", "1690"),
                             ("portraitSource", None), ("portraitSource", True),
                             ("portraitSource", "https://www.wowhead.com/forever/npc=235"),
                             ("portraitSource", "https://www.wowhead.com/classic/npc=234"),
                             ("portraitSource", "https://www.wowhead.com/forever/quest=234"),
                             ("portraitSource", "https://www.wowhead.com/forever/npc=234/one/two"),
                             ("portraitSource", "https://www.wowhead.com/forever/npc=234#model")):
            with self.subTest(field=field, value=value):
                self.data["quests"][0]["start"] = {**valid, field: value}
                with self.assertRaisesRegex(ValueError, "giver portrait"):
                    catalog.validate(self.data)
        for omitted in ("creatureDisplayID", "portraitSource", "npcID"):
            place = valid.copy()
            del place[omitted]
            self.data["quests"][0]["start"] = place
            with self.subTest(omitted=omitted), self.assertRaisesRegex(ValueError, "giver portrait"):
                catalog.validate(self.data)

    def test_giver_portraits_do_not_promote_objects_items_or_drop_creatures_to_givers(self):
        portrait = {"creatureDisplayID": 1690, "portraitSource": "https://www.wowhead.com/forever/npc=234"}
        for place in ({"objectID": 234}, {"itemID": 234}, {"itemID": 234, "dropNPCID": 234},
                      {"itemID": 234, "dropSources": [{"npcID": 234, "name": "NPC", "locationName": "Zone", **portrait}]}):
            self.data["quests"][0]["start"] = {"name": "Starter", **place, **(portrait if "dropSources" not in place else {})}
            with self.subTest(place=place), self.assertRaisesRegex(ValueError, "portrait"):
                catalog.validate(self.data)

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

    def test_item_drop_locations_preserve_source_roles_and_raw_area_labels(self):
        quest = self.data["quests"][0]
        facts = {key: copy.deepcopy(quest.get(key)) for key in ("requires", "requirementsKnown", "classes")}
        for location in (
            {"mapID": 1426},
            {"mapID": 1426, "x": 0, "y": 100},
            {"mapID": 1426, "x": 77.8, "y": 62.4, "zoneName": "Dun Morogh",
             "reportedLocations": [{"mapID": 1426, "x": 77.8, "y": 62.4},
                                   {"mapID": 1426, "x": 77.8, "y": 62.6}]},
            {"reportedLocations": [{"mapID": 1426, "x": 1, "y": 2},
                                   {"mapID": 1427, "x": 1, "y": 2}]},
        ):
            with self.subTest(location=location):
                quest["start"] = {"itemID": 274268, "name": "Map", "dropSources": [
                    {"npcID": 6124, "name": "Captain Beld", "locationName": "Broad source label", **location}]}
                before = copy.deepcopy(self.data)
                catalog.generate(self.data)
                self.assertEqual(self.data, before)
                self.assertEqual({key: quest.get(key) for key in facts}, facts)
                self.assertNotIn("mapID", quest["start"])
                self.assertNotIn("npcID", quest["start"])

    def test_item_drop_locations_reject_invalid_maps_coordinates_and_reports(self):
        point = {"mapID": 1426, "x": 77.8, "y": 62.4}
        invalid = [{"mapID": value} for value in (None, True, 0, -1, 1426.0, "1426")]
        invalid += [{"mapID": 1426, "x": value, "y": 10}
                    for value in (None, True, -0.1, 100.1, "10", float("inf"), float("nan"))]
        invalid += [{"x": 10, "y": 20}, {"mapID": 1426, "x": 10}, {"zoneName": " "}]
        invalid += [{"reportedLocations": value} for value in
                    (None, [], [point], [point] * 101, [point, point], [point, None],
                     [point, {"mapID": 1426, "x": 1}],
                     [point, {"mapID": True, "x": 1, "y": 2}],
                     [point, {"mapID": 1426, "x": 1, "y": 101}],
                     [point, {"mapID": 1426, "x": 1, "y": 2, "itemID": 1}])]
        invalid += [{"mapID": 1426, "x": 20, "y": 30,
                     "reportedLocations": [point, {"mapID": 1426, "x": 1, "y": 2}]}]
        for location in invalid:
            with self.subTest(location=location):
                self.data["quests"][0]["start"] = {"itemID": 274268, "dropSources": [
                    {"npcID": 6124, "name": "Captain Beld", "locationName": "Dun Morogh", **location}]}
                with self.assertRaises(ValueError):
                    catalog.validate(self.data)

    def test_item_drop_sources_reject_other_entity_and_nested_acquisition_roles(self):
        for key, value in (("objectID", 1), ("itemID", 1), ("dropNPCID", 1),
                           ("containerSource", {}), ("dropSources", []), ("dungeonKey", "dm"),
                           ("creatureDisplayID", 1), ("portraitSource", "source"), ("unexpected", True)):
            with self.subTest(key=key):
                self.data["quests"][0]["start"] = {"itemID": 274268, "dropSources": [
                    {"npcID": 6124, "name": "Captain Beld", "locationName": "Dun Morogh", key: value}]}
                with self.assertRaises(ValueError):
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



class ObjectiveAcquisitionTests(unittest.TestCase):
    def fixture(self):
        data=json.loads((ROOT/"data/catalog.json").read_text(encoding="utf-8"))
        quest=next(q for q in data["quests"] if q["id"]==1221)
        quest["objectiveItemSources"]=[{"itemID":5880,"containerSources":[{
            "objectID":21277,"name":"Crate with Holes","source":"https://www.wowhead.com/forever/object=21277/crate-with-holes",
            "zoneName":"The Barrens","mapID":1413,"x":62.3,"y":37.6}]}]
        return data,quest,quest["objectiveItemSources"][0],quest["objectiveItemSources"][0]["containerSources"][0]

    def test_acquisition_three_exact_sources_generate_and_reverse_without_role_changes(self):
        baseline=json.loads((ROOT/"data/catalog.json").read_text(encoding="utf-8")); original=copy.deepcopy(baseline)
        data,quest,_,_=self.fixture()
        for item,obj,name in [(5897,21530,"Snufflenose Owner's Manual"),(6684,68865,"Snufflenose Command Sticks")]:
            quest["objectiveItemSources"].append({"itemID":item,"containerSources":[{"objectID":obj,"name":name,
              "source":f"https://www.wowhead.com/forever/object={obj}","mapID":1413,"x":62.3,"y":37.6}]})
        saved=copy.deepcopy(data); generated=catalog.generate(data)
        self.assertEqual(data,saved); self.assertIn('["objectiveItemSources"]',generated)
        self.assertEqual(generated.count('["x"] = 62.3'),catalog.generate(baseline).count('["x"] = 62.3')+3)
        self.assertEqual(next(q for q in data["quests"]if q["id"]==1221)["objectiveItems"],next(q for q in baseline["quests"]if q["id"]==1221)["objectiveItems"])
        self.assertEqual(catalog.generate(data),generated)
        del quest["objectiveItemSources"]
        self.assertEqual(data,original);self.assertEqual(catalog.generate(data),catalog.generate(baseline))

    def test_acquisition_optional_absence_and_identity_only_source(self):
        data,quest,_,place=self.fixture()
        for key in ["mapID","x","y","zoneName"]:del place[key]
        catalog.validate(data)
        del quest["objectiveItemSources"];catalog.validate(data)

    def test_acquisition_rejects_bad_outer_lists(self):
        for value in [None,True,{},[],"x",[{}]*101]:
            with self.subTest(value=repr(value)):
                data,q,_,_=self.fixture();q["objectiveItemSources"]=value
                with self.assertRaises(ValueError):catalog.validate(data)

    def test_acquisition_rejects_invalid_or_orphan_item_binding(self):
        for value in [None,True,0,-1,1.5,"5880",[],{},2**53,999999]:
            with self.subTest(value=repr(value)):
                data,_,entry,_=self.fixture();entry["itemID"]=value
                with self.assertRaises(ValueError):catalog.validate(data)
        data,q,_,_=self.fixture();q.pop("objectiveItems")
        with self.assertRaises(ValueError):catalog.validate(data)

    def test_acquisition_rejects_duplicate_items_and_empty_containers(self):
        data,q,entry,_=self.fixture();q["objectiveItemSources"].append(copy.deepcopy(entry))
        with self.assertRaises(ValueError):catalog.validate(data)
        for value in [None,{},[],False,[{}]*101]:
            data,_,entry,_=self.fixture();entry["containerSources"]=value
            with self.assertRaises(ValueError):catalog.validate(data)

    def test_acquisition_rejects_unknown_role_or_quantity_keys(self):
        for key in ["providedItems","quantity","npcID","creatureDisplayID","requires","requirementsKnown","itemID","reportedLocations"]:
            data,_,_,place=self.fixture();place[key]=1
            with self.subTest(key=key),self.assertRaises(ValueError):catalog.validate(data)
        data,_,entry,_=self.fixture();entry["quantity"]=1
        with self.assertRaises(ValueError):catalog.validate(data)

    def test_acquisition_rejects_wrong_entity_link_and_invalid_names(self):
        for value in [None,1,"https://www.wowhead.com/forever/npc=21277","https://www.wowhead.com/classic/object=21277","https://www.wowhead.com/forever/object=21278","https://www.wowhead.com/forever/object=21277#x","x"*2049]:
            data,_,_,place=self.fixture();place["source"]=value
            with self.subTest(value=repr(value)),self.assertRaises(ValueError):catalog.validate(data)
        for value in [None,1,"","  ","a"*501,"\ud800"]:
            data,_,_,place=self.fixture();place["name"]=value
            with self.subTest(value=repr(value)),self.assertRaises(ValueError):catalog.validate(data)

    def test_acquisition_rejects_bad_and_duplicate_object_ids(self):
        for value in [None,True,0,-1,1.5,"21277",{},2**32]:
            data,_,_,place=self.fixture();place["objectID"]=value
            with self.subTest(value=repr(value)),self.assertRaises(ValueError):catalog.validate(data)
        data,_,entry,place=self.fixture();entry["containerSources"].append(copy.deepcopy(place))
        with self.assertRaises(ValueError):catalog.validate(data)

    def test_acquisition_reuses_existing_paired_percent_place_validation(self):
        for key,value in [("mapID",True),("mapID",0),("mapID",1.5),("x",float("nan")),("y",float("inf")),("x",False),("x",-1),("y",100.1),("zoneName",False)]:
            data,_,_,place=self.fixture();place[key]=value
            with self.subTest(key=key,value=repr(value)),self.assertRaises(ValueError):catalog.validate(data)
        for key in ["mapID","x","y"]:
            data,_,_,place=self.fixture();del place[key]
            with self.subTest(missing=key),self.assertRaises(ValueError):catalog.validate(data)
        for x,y in [(0,100),(100,0),(62.3,37.6)]:
            data,_,_,place=self.fixture();place["x"],place["y"]=x,y;catalog.validate(data)

if __name__ == "__main__":
    unittest.main()
