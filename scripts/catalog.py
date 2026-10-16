"""Validate reviewed quest facts and generate the offline Lua catalogue."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FACTIONS = frozenset({"Alliance", "Horde", "Neutral"})
CLASSES = frozenset({
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN",
    "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER",
})


def integer(value):
    return type(value) is int and value > 0


def validate(data):
    if data.get("schema") != 1:
        raise ValueError("Unsupported catalogue schema")
    quests = {}
    for q in data["quests"]:
        if not integer(q["id"]) or q["id"] in quests:
            raise ValueError("Invalid or duplicate quest ID")
        quests[q["id"]] = q
        if not q.get("name") or not integer(q.get("minLevel")):
            raise ValueError(f"Missing quest name/level: {q['id']}")
        if type(q.get("requirementsKnown")) is not bool:
            raise ValueError(f"Explicit requirements evidence needed: {q['id']}")
        for field, tokens in (("factions", FACTIONS), ("classes", CLASSES), ("races", None)):
            if field not in q:
                continue
            values = q[field]
            # Omit unrestricted fields; an empty Lua restriction blocks everyone.
            if type(values) is not list or not values:
                raise ValueError(f"Invalid {field} restriction: {q['id']}")
            for value in values:
                if (tokens is None and not integer(value)) or (
                    tokens is not None and (type(value) is not str or value not in tokens)
                ):
                    raise ValueError(f"Invalid {field} restriction: {q['id']}")
            if len(values) != len(set(values)):
                raise ValueError(f"Duplicate {field} restriction: {q['id']}")
        if "startsInside" in q and type(q["startsInside"]) is not bool:
            raise ValueError(f"Invalid startsInside flag: {q['id']}")
        if not q.get("source", "").startswith("https://www.wowhead.com/forever/"):
            raise ValueError(f"Missing Forever source: {q['id']}")
        for key in ("start", "finish"):
            p = q.get(key)
            if p is None:
                continue
            if type(p) is not dict:
                raise ValueError(f"Invalid quest {key} place: {q['id']}")
            for identity in ("npcID", "objectID"):
                if identity in p and not integer(p[identity]):
                    raise ValueError(f"Invalid {identity} entity ID: {q['id']}")
            if "npcID" in p and "objectID" in p:
                raise ValueError(f"Ambiguous quest place identity: {q['id']}")
            if "mapID" in p and not integer(p["mapID"]):
                raise ValueError("Invalid map ID")
            if ("x" in p) != ("y" in p):
                raise ValueError("Both coordinates are required")
            for axis in ("x", "y"):
                if axis in p:
                    v = p[axis]
                    if type(v) not in (int, float) or not math.isfinite(v) or not 0 <= v <= 100 or "mapID" not in p:
                        raise ValueError("Invalid coordinate")
    for q in quests.values():
        if any(qid not in quests for qid in q.get("storyline", [])):
            raise ValueError("Missing storyline quest")
        for g in q.get("requires", []):
            if not g.get("ids") or g.get("mode", "completed") not in ("completed", "active"):
                raise ValueError("Invalid requirement group")
            if len(g["ids"]) != len(set(g["ids"])):
                raise ValueError("Duplicate requirement")
            if any(parent not in quests for parent in g["ids"]):
                raise ValueError(f"Missing prerequisite definition: {q['id']}")
    visiting, visited = set(), set()

    def visit(qid):
        if qid in visiting:
            raise ValueError("Quest dependency cycle")
        if qid in visited:
            return
        visiting.add(qid)
        for g in quests[qid].get("requires", []):
            for parent in g["ids"]:
                visit(parent)
        visiting.remove(qid)
        visited.add(qid)

    for qid in quests:
        visit(qid)
    keys = set()
    for d in data["dungeons"]:
        if d["key"] in keys:
            raise ValueError("Duplicate dungeon")
        keys.add(d["key"])
        if ("instanceID" in d and not integer(d["instanceID"])) or not integer(d["minLevel"]) or not integer(d["maxLevel"]) or d["maxLevel"] < d["minLevel"]:
            raise ValueError("Invalid dungeon identity/levels")
        if d.get("coverage") not in ("pending", "partial", "reviewed"):
            raise ValueError("Explicit dungeon coverage needed")
        if any(qid not in quests for qid in d["quests"]):
            raise ValueError("Dungeon references a missing quest")
        if len(d["quests"]) != len(set(d["quests"])):
            raise ValueError("Duplicate dungeon quest")
        if d["coverage"] == "reviewed" and not d["quests"]:
            raise ValueError("Empty dungeon cannot claim reviewed coverage")
    return data


def lua(value):
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t") + '"'
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        return "{ " + ", ".join(map(lua, value)) + " }"
    return "{ " + ", ".join("[" + lua(k) + "] = " + lua(v) for k, v in sorted(value.items())) + " }"


def generate(data):
    validate(data)
    lines = ["-- Generated from data/catalog.json; do not edit this file.", "local _, addon = ...", "addon.quests = {"]
    for q in sorted(data["quests"], key=lambda q: q["id"]):
        lines.append(f"    [{q['id']}] = {lua(q)},")
    lines += ["}", "addon.dungeons = {"]
    for d in sorted(data["dungeons"], key=lambda d: (d["minLevel"], d["key"])):
        lines.append("    " + lua(d) + ",")
    return "\n".join(lines + ["}", ""])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = json.loads((ROOT / "data/catalog.json").read_text(encoding="utf-8"))
    content = generate(data)
    target = ROOT / "Database/Catalog.lua"
    if args.check:
        if not target.exists() or target.read_text(encoding="utf-8") != content:
            raise SystemExit("Generated catalogue differs; run python scripts/catalog.py")
    else:
        target.parent.mkdir(exist_ok=True)
        target.write_text(content, encoding="utf-8", newline="\n")
    print(f"Catalogue: {len(data['dungeons'])} dungeons, {len(data['quests'])} quests; valid")


if __name__ == "__main__":
    main()
