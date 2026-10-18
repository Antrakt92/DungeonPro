import copy
import importlib.util
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("summon_catalog", ROOT / "scripts/catalog.py")
catalog = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(catalog)


class SummonedObjectSourceTests(unittest.TestCase):
    def fixture(self, field="start"):
        endpoint = {"objectID": 112877, "name": "Talvash's Scrying Bowl",
                    "summonItem": {"itemID": 7667, "name": "Talvash's Phial of Scrying"}}
        quest = {"id": 2204, "name": "Restoring the Necklace", "minLevel": 37,
                 "requirementsKnown": False, field: endpoint,
                 "source": "https://www.wowhead.com/forever/quest=2204"}
        data = {"schema": 1, "quests": [quest], "dungeons": [{"key": "test", "name": "Test",
                "minLevel": 35, "maxLevel": 47, "coverage": "partial", "quests": [2204]}]}
        return data, quest, endpoint

    def test_start_and_finish_serialize_distinct_object_and_tool_without_changing_quest_roles(self):
        lua = shutil.which("lua5.1")
        self.assertIsNotNone(lua, "Lua5.1 is required by the local gate")
        for field in ("start", "finish"):
            data, _, _ = self.fixture(field)
            before = copy.deepcopy(data)
            generated = catalog.generate(data)
            self.assertEqual(data, before)
            script = "local addon={}\nassert(loadstring([==[" + generated + "]==]))('DungeonPro',addon)\n"
            script += ("local q=addon.quests[2204]; local p=q." + field + "; "
                       "assert(p.objectID==112877 and p.itemID==nil); "
                       "assert(p.summonItem.itemID==7667 and p.summonItem.name==\"Talvash's Phial of Scrying\"); "
                       "assert(q.requirementsKnown==false and q.objectiveItems==nil and q.providedItems==nil "
                       "and q.requires==nil and addon.dungeons[1].quests[1]==2204)\n")
            result = subprocess.run([lua, "-"], input=script, text=True, encoding="utf-8",
                                    capture_output=True, cwd=ROOT)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_invalid_tool_values_and_unverified_extra_roles_are_rejected(self):
        invalid = [None, False, [], {}, {"itemID": 7667}, {"name": "Phial"}]
        invalid += [{"itemID": value, "name": "Phial"} for value in
                    (None, True, False, 0, -1, 7667.0, "7667", 2 ** 32, float("inf"), float("nan"))]
        invalid += [{"itemID": 7667, "name": value} for value in
                    (None, False, 5, "", "  ", "a" * 501, "碗" * 167, "bad\ud800name")]
        for key, value in (("quantity", 1), ("spellID", 9489), ("required", True),
                           ("mapID", 1418), ("charges", 5), ("provided", True)):
            invalid.append({"itemID": 7667, "name": "Phial", key: value})
        for value in invalid:
            data, _, endpoint = self.fixture()
            endpoint["summonItem"] = value
            with self.subTest(value=repr(value)), self.assertRaises(ValueError):
                catalog.validate(data)
        for value in (1, 2 ** 32 - 1):
            data, _, endpoint = self.fixture()
            endpoint["summonItem"] = {"itemID": value, "name": "碗" * 166}
            catalog.validate(data)

    def test_relation_is_limited_to_object_endpoints_without_a_fabricated_fixed_route(self):
        for value in (None, True, False, 0, -1, 112877.0, "112877", 2 ** 32):
            data, _, endpoint = self.fixture()
            endpoint["objectID"] = value
            with self.subTest(objectID=value), self.assertRaises(ValueError):
                catalog.validate(data)
        data, _, endpoint = self.fixture()
        endpoint["objectID"] = 2 ** 32 - 1
        catalog.validate(data)
        for identity in ("npcID", "itemID"):
            data, _, endpoint = self.fixture()
            endpoint[identity] = endpoint.pop("objectID")
            with self.subTest(identity=identity), self.assertRaises(ValueError):
                catalog.validate(data)
        for field in ("startAlternatives", "finishAlternatives"):
            data, quest, endpoint = self.fixture()
            quest.pop("start")
            quest[field] = [endpoint]
            with self.subTest(field=field), self.assertRaises(ValueError):
                catalog.validate(data)
        for field, value in (("mapID", 1418), ("x", 53), ("y", 34.1),
                             ("reportedLocations", [{"mapID": 1418, "x": 53, "y": 34.1}])):
            data, _, endpoint = self.fixture()
            endpoint[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                catalog.validate(data)
        data, _, endpoint = self.fixture()
        endpoint.pop("summonItem")
        catalog.validate(data)
        self.assertNotIn("summonItem", endpoint, "Missing source proof must not synthesize a tool relation")
        data, _, endpoint = self.fixture()
        endpoint.update(mapID=1418, x=53, y=34.1, reportedLocations=[
            {"mapID": 1418, "x": 53, "y": 34.1}, {"mapID": 1418, "x": 53, "y": 34.2}])
        with self.assertRaises(ValueError):
            catalog.validate(data)
        endpoint.pop("summonItem")
        catalog.validate(data)  # The same complete route is valid for an ordinary object.


if __name__ == "__main__":
    unittest.main()
