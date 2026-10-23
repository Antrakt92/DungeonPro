"""Fail-closed regression: malformed catalog entries must raise ValueError.

Covers: quests [None]/[{"name":"x"}]/"x", dungeons ["x"]/[{}],
truncated catalog {} and non-list quest/dungeon values. Before the fix
these surfaced as TypeError/KeyError; the contract is ValueError only.
"""
import copy
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("catalog_malformed", ROOT / "scripts/catalog.py")
catalog = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(catalog)


def minimal_catalog():
    return {"schema": 1, "quests": [
        {"id": 1, "name": "Parent", "minLevel": 1, "requirementsKnown": True,
         "source": "https://www.wowhead.com/forever/quest=1"},
        {"id": 2, "name": "Target", "minLevel": 1, "requirementsKnown": True,
         "source": "https://www.wowhead.com/forever/quest=2"},
    ], "dungeons": [{"key": "test", "name": "Test", "minLevel": 1, "maxLevel": 10,
                      "coverage": "partial", "quests": [2]}]}


class MalformedCatalogEntriesTests(unittest.TestCase):
    def assertFailClosed(self, mutate):
        data = minimal_catalog()
        mutate(data)
        with self.assertRaises(ValueError):
            catalog.validate(data)
        # And validate must never leak TypeError/KeyError for these shapes.
        try:
            catalog.validate(copy.deepcopy(data))
        except ValueError:
            pass
        except (TypeError, KeyError) as error:
            self.fail(f"fail-open {type(error).__name__}: {error}")
        else:
            self.fail("expected ValueError")

    def test_quest_entries_must_be_dicts(self):
        for bad in (None, "x", 1, True, [], ["x"]):
            with self.subTest(bad=repr(bad)):
                self.assertFailClosed(lambda data, bad=bad: data["quests"].__setitem__(0, bad))

    def test_quest_entry_missing_id(self):
        self.assertFailClosed(lambda data: data["quests"].__setitem__(0, {"name": "x"}))

    def test_quests_container_must_be_list(self):
        for bad in ("x", None, {}, 1):
            with self.subTest(bad=repr(bad)):
                self.assertFailClosed(lambda data, bad=bad: data.update(quests=bad))

    def test_dungeon_entries_must_be_dicts(self):
        for bad in ("x", None, 1, [], ["x"]):
            with self.subTest(bad=repr(bad)):
                self.assertFailClosed(lambda data, bad=bad: data["dungeons"].__setitem__(0, bad))

    def test_dungeon_entry_missing_levels(self):
        self.assertFailClosed(lambda data: data["dungeons"].__setitem__(0, {}))
        self.assertFailClosed(lambda data: data["dungeons"].__setitem__(
            0, {"key": "test", "name": "Test", "coverage": "partial", "quests": []}))

    def test_dungeons_container_must_be_list(self):
        for bad in ("x", None, {}, 1):
            with self.subTest(bad=repr(bad)):
                self.assertFailClosed(lambda data, bad=bad: data.update(dungeons=bad))

    def test_truncated_catalog_is_value_error(self):
        for data in ({"schema": 1}, {}):
            with self.subTest(data=data):
                with self.assertRaises(ValueError):
                    catalog.validate(copy.deepcopy(data))
                try:
                    catalog.validate(copy.deepcopy(data))
                except ValueError:
                    pass
                except (TypeError, KeyError, AttributeError) as error:
                    self.fail(f"fail-open {type(error).__name__}: {error}")
                else:
                    self.fail("expected ValueError")

    def test_non_dict_catalog_is_value_error(self):
        for data in (None, "x", 1, True, [], [{"schema": 1}]):
            with self.subTest(data=repr(data)):
                with self.assertRaises(ValueError):
                    catalog.validate(copy.deepcopy(data))

    def test_valid_catalog_still_passes(self):
        catalog.validate(minimal_catalog())

    def _large_quest_pool(self, count, start=3):
        pool = []
        for quest_id in range(start, start + count):
            pool.append({"id": quest_id, "name": f"Q{quest_id}", "minLevel": 1,
                         "requirementsKnown": True,
                         "source": f"https://www.wowhead.com/forever/quest={quest_id}"})
        return pool

    def test_dungeon_quest_list_capped_at_runtime_limit(self):
        # Runtime refuses dungeon quest lists above 100 (SearchRelations
        # array cap); the validator must match. 100 still passes.
        data = minimal_catalog()
        data["quests"].extend(self._large_quest_pool(110))
        data["dungeons"][0]["quests"] = [q["id"] for q in data["quests"][:100]]
        catalog.validate(data)
        data["dungeons"][0]["quests"] = [q["id"] for q in data["quests"][:101]]
        with self.assertRaises(ValueError):
            catalog.validate(data)

    def test_requirement_group_ids_capped_at_runtime_budget(self):
        # Runtime caps traversal at 80 nodes / 320 edges; sibling list
        # guards cap at 100. A 500-id group must fail closed.
        data = minimal_catalog()
        data["quests"].extend(self._large_quest_pool(500))
        data["quests"][1]["requires"] = [
            {"ids": [q["id"] for q in data["quests"] if q["id"] != 2]}]
        with self.assertRaises(ValueError):
            catalog.validate(data)
        try:
            catalog.validate(copy.deepcopy(data))
        except ValueError:
            pass
        except (TypeError, KeyError) as error:
            self.fail(f"fail-open {type(error).__name__}: {error}")
        else:
            self.fail("expected ValueError")

    def test_restriction_lists_capped_by_token_set_size(self):
        # factions/classes cannot outgrow their token sets (3/13); races
        # use the 100-entry consistency cap. Real data peaks at 2/2/4.
        data = minimal_catalog()
        data["quests"][1]["factions"] = ["Alliance", "Horde", "Neutral", "Alliance"]
        with self.assertRaises(ValueError):
            catalog.validate(data)
        data = minimal_catalog()
        data["quests"][1]["classes"] = ["MAGE"] * 14
        with self.assertRaises(ValueError):
            catalog.validate(data)
        data = minimal_catalog()
        data["quests"][1]["races"] = list(range(1, 102))
        with self.assertRaises(ValueError):
            catalog.validate(data)

    def test_deep_reverse_chain_raises_value_error_not_recursion_error(self):
        # A reverse-ordered requires chain (1->2->...->N) recursed N deep
        # under the old recursive visit, leaking bare RecursionError (a
        # RuntimeError, not ValueError). The iterative walk must raise
        # ValueError; chains deeper than the runtime cap of 50 fail closed.
        size = 1500
        quests = []
        for quest_id in range(1, size + 1):
            quest = {"id": quest_id, "name": f"Q{quest_id}", "minLevel": 1,
                     "requirementsKnown": True,
                     "source": f"https://www.wowhead.com/forever/quest={quest_id}"}
            if quest_id < size:
                quest["requires"] = [{"ids": [quest_id + 1]}]
            quests.append(quest)
        data = {"schema": 1, "quests": quests,
                "dungeons": [{"key": "test", "name": "Test", "minLevel": 1,
                              "maxLevel": 10, "coverage": "partial",
                              "quests": [1]}]}
        try:
            catalog.validate(copy.deepcopy(data))
        except ValueError:
            pass
        except RecursionError as error:
            self.fail(f"fail-open RecursionError: {error}")
        else:
            self.fail("expected ValueError")

    def test_chain_beyond_runtime_depth_cap_is_rejected(self):
        # Runtime caps traversal depth at 50; depths 0..50 pass, depth 51
        # fails closed with ValueError (not RecursionError).
        def chain(size):
            quests = []
            for quest_id in range(1, size + 1):
                quest = {"id": quest_id, "name": f"Q{quest_id}", "minLevel": 1,
                         "requirementsKnown": True,
                         "source": f"https://www.wowhead.com/forever/quest={quest_id}"}
                if quest_id < size:
                    quest["requires"] = [{"ids": [quest_id + 1]}]
                quests.append(quest)
            return {"schema": 1, "quests": quests,
                    "dungeons": [{"key": "test", "name": "Test", "minLevel": 1,
                                  "maxLevel": 10, "coverage": "partial",
                                  "quests": [1]}]}
        catalog.validate(chain(51))  # depths 0..50
        with self.assertRaises(ValueError):
            catalog.validate(chain(52))  # reaches depth 51

    def test_deeply_nested_extra_field_raises_value_error(self):
        # Hostile {"schema":1,"quests":[],"dungeons":[],"evil":<3000-deep>}
        # recursed unbounded under the old recursive validate_unicode,
        # leaking bare RecursionError (a RuntimeError, not ValueError).
        # The iterative walk with MAX_NESTING_DEPTH=100 must raise
        # ValueError. No deepcopy here: copy.deepcopy itself recurses.
        deep = 0
        for _ in range(3000):
            deep = {"x": deep}
        data = {"schema": 1, "quests": [], "dungeons": [], "evil": deep}
        try:
            catalog.validate(data)
        except ValueError:
            pass
        except RecursionError as error:
            self.fail(f"fail-open RecursionError: {error}")
        else:
            self.fail("expected ValueError")
        # Defense in depth: the iterative walker itself caps depth even
        # when called directly (e.g. on valid-shaped but hostile nests).
        try:
            catalog.validate_unicode(deep)
        except ValueError:
            pass
        except RecursionError as error:
            self.fail(f"fail-open RecursionError: {error}")
        else:
            self.fail("expected ValueError")

    def test_unknown_top_level_field_rejected(self):
        # Live data/catalog.json carries exactly {schema, checked, quests,
        # dungeons}, so the top-level key set is closed. A hostile nested
        # list under an unknown key is rejected by the whitelist (the
        # walker depth cap is covered by the deep-extra-field test).
        self.assertFailClosed(lambda data: data.update(evil=1))
        deep = 0
        for _ in range(101):
            deep = [deep]
        data = minimal_catalog()
        data["nested"] = deep
        with self.assertRaises(ValueError):
            catalog.validate(data)

    def test_requires_group_count_capped(self):
        # Sibling list guards cap at 100; an empty requires list was already
        # rejected. Exactly 100 groups pass, 101 fail closed.
        data = minimal_catalog()
        data["quests"][1]["requires"] = [{"ids": [1]}] * 100
        catalog.validate(data)
        data["quests"][1]["requires"] = [{"ids": [1]}] * 101
        with self.assertRaises(ValueError):
            catalog.validate(data)

    def test_requirement_group_ids_boundary_100_passes(self):
        # Inner ids already capped at 1..100; exactly 100 passes.
        data = minimal_catalog()
        data["quests"].extend(self._large_quest_pool(100))
        data["quests"][1]["requires"] = [
            {"ids": [q["id"] for q in data["quests"] if q["id"] != 2][:100]}]
        catalog.validate(data)

    def test_top_level_lists_capped(self):
        # Real data holds 577 quests / 32 dungeons; the generous 10000 cap
        # only rejects absurd payloads. 10001 quests fail closed.
        data = minimal_catalog()
        data["quests"].extend(self._large_quest_pool(10001))
        with self.assertRaises(ValueError):
            catalog.validate(data)

    def test_true_cycle_keeps_cycle_message(self):
        data = minimal_catalog()
        data["quests"][0]["requires"] = [{"ids": [2]}]
        data["quests"][1]["requires"] = [{"ids": [1]}]
        with self.assertRaisesRegex(ValueError, "cycle"):
            catalog.validate(data)


if __name__ == "__main__":
    unittest.main()
