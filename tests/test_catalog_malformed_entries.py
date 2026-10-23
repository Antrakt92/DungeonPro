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


if __name__ == "__main__":
    unittest.main()
