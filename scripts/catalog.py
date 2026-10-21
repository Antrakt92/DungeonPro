"""Validate reviewed quest facts and generate the offline Lua catalogue."""
from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
FACTIONS = frozenset({"Alliance", "Horde", "Neutral"})
CLASSES = frozenset({
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN",
    "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER",
})
QUEST_FIELDS = frozenset({
    "id", "name", "level", "minLevel", "requirementsKnown", "source", "factions", "classes", "races",
    "start", "finish", "startAlternatives", "finishAlternatives", "startsInside", "repeatable", "requiredMoney",
    "objectiveItems", "objectiveKills", "objectiveObjects", "objectiveEvents", "objectiveItemSources", "providedItems",
    "requires", "storyline", "storylineGroups", "storylineEvidence", "completionQuests",
})
DUNGEON_FIELDS = frozenset({
    "key", "name", "minLevel", "maxLevel", "coverage", "quests", "source", "instanceID", "wing", "entrance", "art",
    "activityID", "complexKey", "sharedQuests", "levelScope", "classicQuests", "classicSource",
})
SCARLET_WINGS = frozenset({"graveyard", "library", "armory", "cathedral"})
COMPLEX_FIELDS = frozenset({"activityID", "complexKey", "sharedQuests", "levelScope", "classicQuests", "classicSource"})
SCARLET_CLASSIC_SOURCE = "https://www.wowhead.com/classic/guide/classic-wow-scarlet-monastery-dungeon-quests"
PLACE_FIELDS = frozenset({
    "name", "npcID", "objectID", "itemID", "mapID", "x", "y", "zoneName", "locationName",
    "dungeonKey", "reportedLocations", "creatureDisplayID", "portraitSource", "dropNPCID", "dropName",
    "dropSources", "containerSource", "itemClasses", "itemMinLevel", "source", "summonItem",
})


def integer(value):
    return type(value) is int and 0 < value <= 2 ** 53 - 1


def unique_fields(pairs):
    fields = {}
    for key, value in pairs:
        if key in fields:
            raise ValueError(f"Duplicate catalogue key: {key!r}")
        fields[key] = value
    return fields


def validate_unicode(value):
    if isinstance(value, str):
        try:
            value.encode("utf-8")
        except UnicodeEncodeError:
            raise ValueError("Invalid Unicode scalar in catalogue") from None
    elif isinstance(value, dict):
        for key, child in value.items():
            validate_unicode(key)
            validate_unicode(child)
    elif isinstance(value, list):
        for child in value:
            validate_unicode(child)


def nonempty_string(value):
    return type(value) is str and bool(value.strip())


def web_source(value):
    if (type(value) is not str or not 1 <= len(value) <= 2048 or
            re.search(r"[\s\x00-\x1f\x7f-\x9f]", value)):
        return False
    try:
        source = urlsplit(value)
        source.port  # Reading the property validates bracketed hosts and port syntax/range.
        return (source.scheme in {"http", "https"} and bool(source.hostname) and
                source.username is None and source.password is None)
    except ValueError:
        return False


def validate_named_facts(quest, field, identity, maximum, label, *, required_name=False, utf8_name=False):
    if field not in quest:
        return
    rows = quest[field]
    if type(rows) is not list or not 1 <= len(rows) <= 100:
        raise ValueError(f"Invalid {label} list: {quest['id']}")
    seen = set()
    for row in rows:
        if (type(row) is not dict or set(row) - {identity, "quantity", "name"} or
                not integer(row.get(identity)) or row[identity] > maximum or
                ("quantity" in row and (not integer(row["quantity"]) or row["quantity"] > 2 ** 53 - 1))):
            raise ValueError(f"Invalid {label} identity/quantity: {quest['id']}")
        if required_name or "name" in row:
            name = row.get("name")
            try:
                valid = nonempty_string(name) and len(name.encode("utf-8") if utf8_name else name) <= 500
            except UnicodeEncodeError:
                valid = False
            if not valid:
                raise ValueError(f"Invalid {label} name: {quest['id']}")
        if row[identity] in seen:
            raise ValueError(f"Duplicate {label}: {quest['id']}")
        seen.add(row[identity])


def objective_item_source_places(quest):
    if "objectiveItemSources" not in quest:
        return []
    rows = quest["objectiveItemSources"]
    if type(rows) is not list or not 1 <= len(rows) <= 100:
        raise ValueError(f"Invalid objective item sources: {quest['id']}")
    objective_ids = {row["itemID"] for row in quest.get("objectiveItems", [])}
    seen_items, places = set(), []
    for row in rows:
        if (type(row) is not dict or set(row) != {"itemID", "containerSources"} or
                not integer(row.get("itemID")) or row["itemID"] > 2 ** 53 - 1 or
                row["itemID"] not in objective_ids or row["itemID"] in seen_items):
            raise ValueError(f"Invalid objective item source binding: {quest['id']}")
        seen_items.add(row["itemID"])
        containers = row["containerSources"]
        if type(containers) is not list or not 1 <= len(containers) <= 100:
            raise ValueError(f"Invalid objective item containers: {quest['id']}")
        seen_objects = set()
        for place in containers:
            if (type(place) is not dict or
                    set(place) - {"objectID", "name", "source", "zoneName", "mapID", "x", "y"} or
                    not integer(place.get("objectID")) or place["objectID"] > 2 ** 32 - 1 or
                    place["objectID"] in seen_objects):
                raise ValueError(f"Invalid objective item container identity: {quest['id']}")
            seen_objects.add(place["objectID"])
            try:
                valid_name = nonempty_string(place.get("name")) and len(place["name"].encode("utf-8")) <= 500
            except UnicodeEncodeError:
                valid_name = False
            source = place.get("source")
            if (not valid_name or not web_source(source) or not re.fullmatch(
                    rf"https://www\.wowhead\.com/forever/object={place['objectID']}(?:/[^\s/?#]+)?", source)):
                raise ValueError(f"Invalid objective item container name/source: {quest['id']}")
            places.append(("objectiveItemContainer", place))
    return places


def validate(data):
    if type(data.get("schema")) is not int or data["schema"] != 1:
        raise ValueError("Unsupported catalogue schema")
    quests = {}
    for q in data["quests"]:
        if set(q) - QUEST_FIELDS:
            raise ValueError("Unknown quest fields")
        if not integer(q["id"]) or q["id"] in quests:
            raise ValueError("Invalid or duplicate quest ID")
        quests[q["id"]] = q
        if not nonempty_string(q.get("name")) or not integer(q.get("minLevel")):
            raise ValueError(f"Missing quest name/level: {q['id']}")
        if "level" in q and not integer(q["level"]):
            raise ValueError(f"Invalid quest level: {q['id']}")
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
        if "repeatable" in q and type(q["repeatable"]) is not bool:
            raise ValueError(f"Invalid repeatable flag: {q['id']}")
        if "requiredMoney" in q and (not integer(q["requiredMoney"]) or q["requiredMoney"] > 2 ** 53 - 1):
            raise ValueError(f"Invalid required money: {q['id']}")
        validate_named_facts(q, "objectiveItems", "itemID", 2 ** 53 - 1, "objective item")
        validate_named_facts(q, "objectiveKills", "npcID", 2 ** 32 - 1, "objective kill",
                             required_name=True, utf8_name=True)
        validate_named_facts(q, "objectiveObjects", "objectID", 2 ** 32 - 1, "objective object",
                             required_name=True, utf8_name=True)
        validate_named_facts(q, "objectiveEvents", "npcID", 2 ** 32 - 1, "objective event",
                             required_name=True, utf8_name=True)
        validate_named_facts(q, "providedItems", "itemID", 2 ** 32 - 1, "provided item",
                             required_name=True, utf8_name=True)
        source = q.get("source")
        if not web_source(source) or not re.fullmatch(
            rf"https://www\.wowhead\.com/forever/quest={q['id']}(?:/[^\s/?#]+)?", source
        ):
            raise ValueError(f"Missing or mismatched Forever source: {q['id']}")
        places = [(key, q.get(key)) for key in ("start", "finish")]
        places.extend(objective_item_source_places(q))
        for single, key, kind in (("start", "startAlternatives", "starting"),
                                  ("finish", "finishAlternatives", "turn-in")):
            if key not in q:
                continue
            alternatives = q[key]
            if type(alternatives) is not list or not 2 <= len(alternatives) <= 100:
                raise ValueError(f"Invalid alternative {kind} points: {q['id']}")
            if single in q:
                raise ValueError(f"Ambiguous single and alternative {single}s: {q['id']}")
            identities = set()
            for p in alternatives:
                if (type(p) is not dict or
                    sum(field in p for field in ("npcID", "objectID", "itemID")) != 1 or
                    "itemID" in p or type(p.get("name")) is not str or not p["name"].strip()):
                    raise ValueError(f"Invalid alternative {kind} identity: {q['id']}")
                field = "npcID" if "npcID" in p else "objectID"
                if not integer(p[field]):
                    raise ValueError(f"Invalid alternative {kind} identity: {q['id']}")
                identity = (field, p[field])
                if identity in identities:
                    raise ValueError(f"Duplicate alternative {kind} identity: {q['id']}")
                identities.add(identity)
            places.extend((key, p) for p in alternatives)
        for key, p in places:
            if p is None:
                continue
            if type(p) is not dict:
                raise ValueError(f"Invalid quest {key} place: {q['id']}")
            if set(p) - PLACE_FIELDS:
                raise ValueError(f"Unknown quest {key} place fields: {q['id']}")
            if "source" in p and not web_source(p["source"]):
                raise ValueError(f"Invalid place source: {q['id']}")
            if "summonItem" in p:
                tool = p["summonItem"]
                if (key not in {"start", "finish"} or not integer(p.get("objectID")) or p["objectID"] > 2 ** 32 - 1 or
                        {"mapID", "x", "y", "reportedLocations"}.intersection(p) or
                        type(tool) is not dict or set(tool) != {"itemID", "name"} or
                        not integer(tool.get("itemID")) or tool["itemID"] > 2 ** 32 - 1):
                    raise ValueError(f"Invalid summoned object source: {q['id']}")
                name = tool["name"]
                try:
                    valid_name = nonempty_string(name) and len(name.encode("utf-8")) <= 500
                except UnicodeEncodeError:
                    valid_name = False
                if not valid_name:
                    raise ValueError(f"Invalid summoned object tool name: {q['id']}")
            if "containerSource" in p:
                container = p["containerSource"]
                if (key != "start" or "itemID" not in p or type(container) is not dict or
                    set(container) - {"objectID", "name", "zoneName", "mapID", "x", "y", "reportedLocations"} or
                    not integer(container.get("objectID")) or not nonempty_string(container.get("name")) or
                    len(container["name"]) > 500):
                    raise ValueError(f"Invalid starter item container source: {q['id']}")
                places.append(("containerSource", container))
            for field in ("name", "dropName"):
                if field in p and not nonempty_string(p[field]):
                    raise ValueError(f"Invalid place {field}: {q['id']}")
            if "zoneName" in p and (type(p["zoneName"]) is not str or
                                    not p["zoneName"].strip() or len(p["zoneName"]) > 500):
                raise ValueError(f"Invalid place zone name: {q['id']}")
            for identity in ("npcID", "objectID", "itemID", "dropNPCID"):
                if identity in p and not integer(p[identity]):
                    raise ValueError(f"Invalid {identity} entity ID: {q['id']}")
            if sum(identity in p for identity in ("npcID", "objectID", "itemID")) > 1:
                raise ValueError(f"Ambiguous quest place identity: {q['id']}")
            portrait_fields = {"creatureDisplayID", "portraitSource"}
            if portrait_fields.intersection(p):
                npc_id, display_id, source = p.get("npcID"), p.get("creatureDisplayID"), p.get("portraitSource")
                if (not portrait_fields.issubset(p) or not integer(npc_id) or npc_id > 2 ** 32 - 1 or
                        not integer(display_id) or display_id > 2 ** 32 - 1 or not web_source(source) or
                        not re.fullmatch(
                            rf"https://www\.wowhead\.com/forever/npc={npc_id}(?:/[^\s/?#]+)?", source)):
                    raise ValueError(f"Invalid sourced giver portrait: {q['id']}")
            if "dropNPCID" in p and "itemID" not in p:
                raise ValueError(f"Item drop source without starter item: {q['id']}")
            if "itemClasses" in p or "itemMinLevel" in p:
                if key != "start" or "itemID" not in p:
                    raise ValueError(f"Item requirements without starter item: {q['id']}")
            if "itemClasses" in p:
                classes = p["itemClasses"]
                if (type(classes) is not list or not classes or
                    any(type(value) is not str or value not in CLASSES for value in classes)):
                    raise ValueError(f"Invalid starter item classes: {q['id']}")
                if len(classes) != len(set(classes)):
                    raise ValueError(f"Duplicate starter item classes: {q['id']}")
            if "itemMinLevel" in p and not integer(p["itemMinLevel"]):
                raise ValueError(f"Invalid starter item minimum level: {q['id']}")
            if "dungeonKey" in p and (type(p["dungeonKey"]) is not str or not p["dungeonKey"]):
                raise ValueError(f"Invalid pickup dungeon: {q['id']}")
            if "dropSources" in p:
                drops = p["dropSources"]
                if "itemID" not in p or type(drops) is not list or not 1 <= len(drops) <= 100:
                    raise ValueError(f"Invalid item drop sources: {q['id']}")
                seen_drops = set()
                for drop in drops:
                    if type(drop) is dict and portrait_fields.intersection(drop):
                        raise ValueError(f"Giver portrait on an item drop source: {q['id']}")
                    if type(drop) is dict and "containerSource" in drop:
                        raise ValueError(f"Invalid container source on item drop: {q['id']}")
                    if (type(drop) is not dict or not integer(drop.get("npcID")) or
                        set(drop) - {"npcID", "name", "locationName", "zoneName", "mapID", "x", "y", "reportedLocations"} or
                        not nonempty_string(drop.get("name")) or not nonempty_string(drop.get("locationName"))):
                        raise ValueError(f"Invalid item drop identity: {q['id']}")
                    if drop["npcID"] in seen_drops:
                        raise ValueError(f"Duplicate item drop source: {q['id']}")
                    seen_drops.add(drop["npcID"])
                    places.append(("dropSource", drop))
            if "mapID" in p and not integer(p["mapID"]):
                raise ValueError("Invalid map ID")
            if ("x" in p) != ("y" in p):
                raise ValueError("Both coordinates are required")
            for axis in ("x", "y"):
                if axis in p:
                    v = p[axis]
                    if type(v) not in (int, float) or not math.isfinite(v) or not 0 <= v <= 100 or "mapID" not in p:
                        raise ValueError("Invalid coordinate")
            if "reportedLocations" in p:
                points = p["reportedLocations"]
                if ("itemID" in p or not any(field in p for field in ("npcID", "objectID")) or
                    type(points) is not list or not 2 <= len(points) <= 100):
                    raise ValueError(f"Invalid reported locations: {q['id']}")
                seen_points = set()
                for point in points:
                    if (type(point) is not dict or not {"mapID", "x", "y"}.issubset(point) or
                        set(point) - {"mapID", "x", "y", "zoneName"} or not integer(point["mapID"])):
                        raise ValueError(f"Invalid reported location identity: {q['id']}")
                    for axis in ("x", "y"):
                        value = point[axis]
                        if type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= 100:
                            raise ValueError(f"Invalid reported location coordinate: {q['id']}")
                    if "zoneName" in point and (not nonempty_string(point["zoneName"]) or len(point["zoneName"]) > 500):
                        raise ValueError(f"Invalid reported location zone name: {q['id']}")
                    triple = (point["mapID"], point["x"], point["y"])
                    if triple in seen_points:
                        raise ValueError(f"Duplicate reported location: {q['id']}")
                    seen_points.add(triple)
                if all(field in p for field in ("mapID", "x", "y")) and (p["mapID"], p["x"], p["y"]) not in seen_points:
                    raise ValueError(f"Primary point missing from reported locations: {q['id']}")
    for q in quests.values():
        if "storylineEvidence" in q and not web_source(q["storylineEvidence"]):
            raise ValueError(f"Invalid storyline evidence: {q['id']}")
        for field in ("requires", "storyline"):
            if field in q and type(q[field]) is not list:
                raise ValueError(f"Invalid {field} list: {q['id']}")
        if "storylineGroups" in q:
            groups = q["storylineGroups"]
            if "storyline" in q:
                raise ValueError("Ambiguous ordered and grouped storyline")
            if type(groups) is not list or not 1 <= len(groups) <= 100:
                raise ValueError("Invalid storyline groups")
            seen_story = set()
            for group in groups:
                if type(group) is not list or not 1 <= len(group) <= 100:
                    raise ValueError("Invalid storyline group")
                for qid in group:
                    if not integer(qid) or qid not in quests:
                        raise ValueError("Missing or invalid grouped storyline quest")
                    if qid in seen_story:
                        raise ValueError("Duplicate grouped storyline quest")
                    seen_story.add(qid)
        if "storyline" in q and not 1 <= len(q["storyline"]) <= 100:
            raise ValueError(f"Invalid storyline length: {q['id']}")
        if any(not integer(qid) for qid in q.get("storyline", [])):
            raise ValueError("Invalid storyline quest ID")
        if "storyline" in q and len(q["storyline"]) != len(set(q["storyline"])):
            raise ValueError(f"Duplicate storyline quest: {q['id']}")
        if any(qid not in quests for qid in q.get("storyline", [])):
            raise ValueError("Missing storyline quest")
        if "completionQuests" in q:
            related = q["completionQuests"]
            if type(related) is not list or len(related) > 100:
                raise ValueError(f"Invalid completion quest links: {q['id']}")
            seen_related = set()
            for entry in related:
                if (type(entry) is not dict or set(entry) - {"id", "itemID"} or
                        not integer(entry.get("id")) or not integer(entry.get("itemID"))):
                    raise ValueError(f"Invalid completion quest link: {q['id']}")
                qid = entry["id"]
                if qid == q["id"] or qid in seen_related:
                    raise ValueError(f"Duplicate or self-referencing completion quest: {q['id']}")
                if qid not in quests:
                    raise ValueError(f"Missing completion quest definition: {q['id']}")
                seen_related.add(qid)
        for g in q.get("requires", []):
            if (type(g) is not dict or set(g) - {"ids", "mode"} or type(g.get("ids")) is not list or not g["ids"] or
                g.get("mode", "completed") not in ("completed", "active")):
                raise ValueError("Invalid requirement group")
            if any(not integer(parent) for parent in g["ids"]):
                raise ValueError("Invalid prerequisite quest ID")
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
    keys, instance_wings, scarlet = set(), {}, []
    for d in data["dungeons"]:
        if set(d) - DUNGEON_FIELDS:
            raise ValueError("Unknown dungeon fields")
        if not nonempty_string(d.get("key")) or not nonempty_string(d.get("name")):
            raise ValueError("Invalid dungeon key/name")
        if d["key"] in keys:
            raise ValueError("Duplicate dungeon")
        keys.add(d["key"])
        if ("instanceID" in d and not integer(d["instanceID"])) or not integer(d["minLevel"]) or not integer(d["maxLevel"]) or d["maxLevel"] < d["minLevel"]:
            raise ValueError("Invalid dungeon identity/levels")
        if "wing" in d and (type(d["wing"]) is not str or
                d["wing"] not in ({"lower", "upper"} | SCARLET_WINGS) or "instanceID" not in d):
            raise ValueError("Invalid dungeon wing")
        if d.get("instanceID") == 189:
            if (d.get("wing") not in SCARLET_WINGS or d.get("key") != "sm_" + d["wing"] or
                    d.get("complexKey") != "sm" or d.get("levelScope") != "complex" or
                    not integer(d.get("activityID")) or d["activityID"] > 4294967295):
                raise ValueError("Invalid Scarlet wing identity/complex metadata")
            shared = d.get("sharedQuests")
            if (type(shared) is not list or not 1 <= len(shared) <= 100 or
                    any(not integer(qid) or qid not in quests for qid in shared) or
                    len(shared) != len(set(shared))):
                raise ValueError("Invalid Scarlet shared discovery list")
            if (type(d.get("quests")) is not list or
                    any(not integer(qid) or qid not in shared for qid in d["quests"])):
                raise ValueError("Scarlet wing roots must belong to shared discovery")
            if "classicQuests" in d or "classicSource" in d:
                classic = d.get("classicQuests")
                if (type(classic) is not list or not 1 <= len(classic) <= 100 or
                        any(not integer(qid) or qid not in d["quests"] or qid not in shared for qid in classic) or
                        len(classic) != len(set(classic)) or
                        type(d.get("classicSource")) is not str or d["classicSource"] != SCARLET_CLASSIC_SOURCE or
                        d.get("coverage") != "partial"):
                    raise ValueError("Invalid Scarlet Classic wing membership provenance")
            scarlet.append(d)
        elif set(d) & COMPLEX_FIELDS or d.get("wing") in SCARLET_WINGS:
            raise ValueError("Scarlet metadata on unrelated dungeon")
        if "entrance" in d:
            entrance = d["entrance"]
            required = {"mapID", "x", "y", "source"}
            if (type(entrance) is not dict or not required <= set(entrance) or
                    set(entrance) - required - {"gameMapID", "scope", "kind"} or
                    not integer(entrance.get("mapID")) or entrance["mapID"] > 2 ** 53 - 1 or
                    ("scope" in entrance and entrance["scope"] != "shared") or
                    ("kind" in entrance and entrance["kind"] != "approach") or
                    ("wing" in d and entrance.get("scope") != "shared") or
                    ("instanceID" in d and entrance.get("gameMapID") != d["instanceID"]) or
                    ("gameMapID" in entrance and (not integer(entrance["gameMapID"]) or
                     entrance["gameMapID"] > 2 ** 53 - 1 or entrance["gameMapID"] != d.get("instanceID")))):
                raise ValueError("Invalid dungeon entrance identity/source")
            if d.get("instanceID") == 189 and entrance.get("kind") != "approach":
                raise ValueError("Scarlet entrance must be a shared complex approach")
            source = entrance["source"]
            if type(source) is not str or len(source) > 2048:
                raise ValueError("Invalid dungeon entrance identity/source")
            instance_source = ("gameMapID" in entrance and
                             source == f"https://phylactery.io/instance/{entrance['gameMapID']}")
            reviewed_source = type(source) is str and re.fullmatch(
                r"https://(?:wowhandbook\.com/zones/dungeons/[a-z0-9-]+/|"
                r"(?:www\.)?warcrafttavern\.com/forever/guides/[a-z0-9-]+/|"
                r"www\.wowhead\.com/forever/(?:zone=[1-9][0-9]*(?:/[a-z0-9-]+)?|guide/[a-z0-9-]+))", source)
            if not instance_source and not reviewed_source:
                raise ValueError("Invalid dungeon entrance identity/source")
            for field in ("x", "y"):
                value = entrance[field]
                if type(value) not in (int, float) or not 0 <= value <= 100 or not math.isfinite(value):
                    raise ValueError("Invalid dungeon entrance coordinate")
        if "art" in d:
            art = d["art"]
            identity_fields = {"fileID", "gameMapID", "loadingScreenID", "source"}
            preview_fields = {"previewWidth", "previewHeight", "previewSource", "previewVersion", "previewContentHash"}
            if (type(art) is not dict or not identity_fields <= set(art) or set(art) - identity_fields - preview_fields or
                    any(not integer(art.get(field)) or art[field] > 4294967295
                        for field in ("fileID", "gameMapID", "loadingScreenID")) or
                    art.get("source") != "https://wago.tools/db2/LoadingScreens?build=1.60.1.70425&filter%5BID%5D=exact%3A" + str(art.get("loadingScreenID")) or
                    ("instanceID" in d and d["instanceID"] != art["gameMapID"])):
                raise ValueError("Invalid dungeon artwork identity/source")
            if set(art) & preview_fields:
                if (not preview_fields <= set(art) or
                        any(not integer(art.get(field)) or art[field] > 16384
                            for field in ("previewWidth", "previewHeight")) or
                        art.get("previewSource") != "https://wago.tools/files?search=" + str(art["fileID"]) or
                        type(art.get("previewVersion")) is not str or
                        re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+", art["previewVersion"]) is None or
                        type(art.get("previewContentHash")) is not str or
                        re.fullmatch(r"[0-9a-f]{32}", art["previewContentHash"]) is None):
                    raise ValueError("Invalid dungeon artwork preview provenance")
        if "instanceID" in d:
            wings = instance_wings.setdefault(d["instanceID"], set())
            wing = d.get("wing")
            if wings and (wing is None or None in wings or wing in wings):
                raise ValueError("Ambiguous shared dungeon map")
            wings.add(wing)
        if d.get("coverage") not in ("pending", "partial", "reviewed"):
            raise ValueError("Explicit dungeon coverage needed")
        if type(d.get("quests")) is not list:
            raise ValueError("Invalid dungeon quest list")
        if any(not integer(qid) for qid in d["quests"]):
            raise ValueError("Invalid dungeon quest ID")
        if any(qid not in quests for qid in d["quests"]):
            raise ValueError("Dungeon references a missing quest")
        if len(d["quests"]) != len(set(d["quests"])):
            raise ValueError("Duplicate dungeon quest")
        if d["coverage"] == "reviewed" and not d["quests"]:
            raise ValueError("Empty dungeon cannot claim reviewed coverage")
    if scarlet:
        if (len(scarlet) != 4 or {d["wing"] for d in scarlet} != SCARLET_WINGS or "sm" in keys or
                len({d["activityID"] for d in scarlet}) != 4):
            raise ValueError("Scarlet complex requires exactly four distinct canonical wings")
        shared, band = scarlet[0]["sharedQuests"], (scarlet[0]["minLevel"], scarlet[0]["maxLevel"])
        if any(d["sharedQuests"] != shared or (d["minLevel"], d["maxLevel"]) != band for d in scarlet):
            raise ValueError("Inconsistent Scarlet shared discovery/complex level band")
    for q in quests.values():
        places = [q.get(field) for field in ("start", "finish")]
        places.extend(q.get("startAlternatives", []))
        places.extend(q.get("finishAlternatives", []))
        for place in places:
            if place and "dungeonKey" in place and place["dungeonKey"] not in keys:
                raise ValueError(f"Missing pickup dungeon: {q['id']}")
    validate_unicode(data)
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
        if isinstance(value, int) and abs(value) > 2 ** 53 - 1:
            raise ValueError("Lua integer exceeds exact numeric range")
        if isinstance(value, float) and not math.isfinite(value):
            raise ValueError("Lua numbers must be finite")
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
    data = json.loads((ROOT / "data/catalog.json").read_text(encoding="utf-8"),
                      object_pairs_hook=unique_fields)
    content = generate(data)
    target = ROOT / "Database/Catalog.lua"
    if args.check:
        if not target.exists() or target.read_text(encoding="utf-8") != content:
            raise SystemExit("Generated catalogue differs; run python scripts/catalog.py")
    else:
        target.parent.mkdir(exist_ok=True)
        target.write_bytes(content.encode("utf-8"))
    print(f"Catalogue: {len(data['dungeons'])} dungeons, {len(data['quests'])} quests; valid")


if __name__ == "__main__":
    main()
