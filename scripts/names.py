"""Validate localized titles and typed source labels for the offline name table."""
import argparse
import copy
import datetime
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALES = {"deDE": 3, "frFR": 2, "esES": 6, "itIT": 9, "ptBR": 8,
           "ruRU": 7, "koKR": 1, "zhCN": 4, "zhTW": 10}
ENDPOINT = "https://nether.wowhead.com/forever/tooltip/{kind}/{id}?locale={locale}"
AREA_LOCALE_PATHS = {"deDE": "de", "frFR": "fr", "esES": "es", "itIT": "it", "ptBR": "pt",
                     "ruRU": "ru", "koKR": "ko", "zhCN": "cn", "zhTW": "tw"}
AREA_INDEXES = {locale: f"https://www.wowhead.com/forever/{path}/zones" for locale, path in AREA_LOCALE_PATHS.items()}
ACTIVITY_ENDPOINT = "https://wago.tools/db2/GroupFinderActivity?build=1.60.1.70450&filter%5BMapID%5D=exact%3A189&locale={locale}&page=1"
SCARLET_ACTIVITIES = {"graveyard": 805, "library": 829, "armory": 827, "cathedral": 828}
UNKNOWN = {"unknown", "sconosciuto", "inconnu", "unbekannt", "desconocido", "desconhecido",
           "未知", "未知任务", "未知任務", "알 수 없음"}


def unique_fields(pairs):
    fields = {}
    for key, value in pairs:
        if key in fields:
            raise ValueError(f"Duplicate localized-name input key: {key!r}")
        fields[key] = value
    return fields


MAX_NESTING_DEPTH = 100


def validate_unicode(value):
    stack = [(value, 0)]
    while stack:
        current, depth = stack.pop()
        if isinstance(current, str):
            try:
                current.encode("utf-8")
            except UnicodeEncodeError:
                raise ValueError("Invalid Unicode scalar in localized-name input") from None
        elif isinstance(current, dict):
            if depth > MAX_NESTING_DEPTH:
                raise ValueError("Localized input nested too deeply")
            for key, child in current.items():
                stack.append((key, depth + 1))
                stack.append((child, depth + 1))
        elif isinstance(current, list):
            if depth > MAX_NESTING_DEPTH:
                raise ValueError("Localized input nested too deeply")
            for child in current:
                stack.append((child, depth + 1))


def title(value):
    return (type(value) is str and 0 < len(value) <= 1024 and value.strip() == value and
            bool(value.strip()) and not any(ord(c) < 32 or ord(c) == 127 for c in value) and
            "|" not in value and "<" not in value and ">" not in value)


def catalog_lists(catalog):
    """Fail closed on hostile catalogue shapes before indexing quest/dungeon rows."""
    if (type(catalog) is not dict or type(catalog.get("quests")) is not list or
            type(catalog.get("dungeons")) is not list):
        raise ValueError("Invalid catalogue shape")
    for q in catalog["quests"]:
        if (type(q) is not dict or "id" not in q or "name" not in q or
                type(q["name"]) is not str):
            raise ValueError("Invalid catalogue quest entry")
    for d in catalog["dungeons"]:
        if (type(d) is not dict or "key" not in d or "name" not in d or
                type(d["key"]) is not str or type(d["name"]) is not str):
            raise ValueError("Invalid catalogue dungeon entry")
    return catalog["quests"], catalog["dungeons"]


def validate(data, catalog):
    validate_unicode(data)
    validate_unicode(catalog)
    quest_rows, dungeon_rows = catalog_lists(catalog)
    if (type(data) is not dict or set(data) != {"schema", "checked", "provenance", "locales"} or
            type(data["schema"]) is not int or data["schema"] != 1):
        raise ValueError("Invalid localized-name schema")
    if type(data["checked"]) is not str or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", data["checked"]):
        raise ValueError("Invalid localized-name date")
    datetime.date.fromisoformat(data["checked"])
    provenance = data["provenance"]
    if (type(provenance) is not dict or provenance.get("provider") != "Wowhead" or
            provenance.get("endpoint") != ENDPOINT or provenance.get("extraction") != "name-only" or
            provenance.get("localeIDs") != LOCALES or type(provenance.get("dungeonSources")) is not dict or
            any(type(value) is not int for value in provenance["localeIDs"].values())):
        raise ValueError("Invalid localized-name provenance")
    quests = {str(q["id"]): q for q in quest_rows}
    dungeons = {d["key"]: d for d in dungeon_rows}
    if (type(provenance.get("catalogueQuestCount")) is not int or provenance.get("catalogueQuestCount") != len(quests) or
            type(provenance.get("englishVerifiedCount")) is not int or provenance["englishVerifiedCount"] != len(quests)):
        raise ValueError("Localized-name catalogue coverage changed")
    dungeon_sources = provenance["dungeonSources"]
    for key, zone in dungeon_sources.items():
        if key not in dungeons or type(zone) is not int or not 0 < zone <= 2**53 - 1:
            raise ValueError("Invalid localized dungeon source identity")
    activities = provenance.get("dungeonActivitySources")
    activity_ids = {}
    if any("sm_" + wing in dungeons for wing in SCARLET_ACTIVITIES) and activities is None:
        raise ValueError("Scarlet wing names require typed activity provenance")
    if activities is not None:
        if (type(activities) is not dict or set(activities) != {"provider", "table", "build", "useHotfixes", "checked", "activities"} or
                activities["provider"] != "Wago.tools" or activities["table"] != "GroupFinderActivity" or
                activities["build"] != "1.60.1.70450" or activities["useHotfixes"] is not False or
                activities["checked"] != "2026-10-20" or type(activities["activities"]) is not dict or
                set(activities["activities"]) != {"sm_" + wing for wing in SCARLET_ACTIVITIES}):
            raise ValueError("Invalid localized activity-name provenance")
        activity_ids = activities["activities"]
        for key, identity in activity_ids.items():
            definition = dungeons.get(key)
            if (definition is None or type(identity) is not int or
                    type(definition.get("wing")) is not str or definition.get("wing") not in SCARLET_ACTIVITIES or
                    key != "sm_" + definition["wing"] or identity != SCARLET_ACTIVITIES[definition["wing"]] or
                    definition.get("activityID") != identity or type(definition.get("activityID")) is not int or
                    definition.get("instanceID") != 189 or type(definition.get("instanceID")) is not int or
                    definition.get("complexKey") != "sm" or key in dungeon_sources):
                raise ValueError("Localized activity name does not match typed dungeon identity")
    locales = data["locales"]
    if type(locales) is not dict or set(locales) != set(LOCALES):
        raise ValueError("Invalid localized-name locale coverage")
    for locale, payload in locales.items():
        if type(payload) is not dict or set(payload) != {"quests", "dungeons"}:
            raise ValueError("Invalid localized-name payload")
        for kind, definitions in (("quests", quests), ("dungeons", dungeons)):
            entries = payload[kind]
            if type(entries) is not dict:
                raise ValueError("Invalid localized-name entries")
            for key, entry in entries.items():
                definition = definitions.get(key)
                if definition is None or (kind == "quests" and not re.fullmatch(r"[1-9][0-9]*", key)):
                    raise ValueError("Unknown localized name identity")
                if (type(entry) is not dict or set(entry) != {"source", "name", "url"} or
                        entry["source"] != definition["name"] or not title(entry["source"]) or
                        not title(entry["name"]) or entry["name"] in (entry["source"], "[" + entry["source"] + "]") or
                        entry["name"].strip("[]").casefold() in UNKNOWN):
                    raise ValueError("Invalid localized name or English source mismatch")
                activity = kind == "dungeons" and key in activity_ids
                source_id = key if kind == "quests" else activity_ids.get(key, dungeon_sources.get(key))
                expected = (ACTIVITY_ENDPOINT.format(locale=locale) if activity else
                            ENDPOINT.format(kind="quest" if kind == "quests" else "zone", id=source_id, locale=LOCALES[locale]))
                if source_id is None or entry["url"] != expected:
                    raise ValueError("Invalid localized-name source URL")
    return data


def quoted(value):
    escaped = (value.replace("\\", "\\\\").replace('"', '\\"')
               .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t"))
    # Decimal byte escapes (cf. scripts/catalog.py lua()) for any remaining
    # C0 control or DEL: a hostile title that bypasses validation must still
    # emit a parseable Lua short string, never a raw control byte.
    escaped = "".join("\\%03d" % ord(c) if ord(c) < 32 or ord(c) == 127 else c
                      for c in escaped)
    return '"' + escaped + '"'


def validate_sources(data, catalog):
    """Sparse typed labels never replace quest titles or establish source roles."""
    validate_unicode(data)
    quest_rows, _ = catalog_lists(catalog)
    if (type(data) is not dict or set(data) != {"schema", "checked", "provenance", "locales"} or
            type(data["schema"]) is not int or data["schema"] != 1):
        raise ValueError("Invalid source-name schema")
    if type(data["checked"]) is not str or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", data["checked"]):
        raise ValueError("Invalid source-name date")
    datetime.date.fromisoformat(data["checked"])
    expected = {"provider": "Wowhead", "endpoint": ENDPOINT, "extraction": "name-only", "localeIDs": LOCALES}
    if (data["provenance"] != expected or
            any(type(value) is not int for value in data["provenance"]["localeIDs"].values())):
        raise ValueError("Invalid source-name provenance")
    definitions = {"objects": {}, "npcs": {}}

    def visit(root):
        stack = [(root, 0)]
        while stack:
            value, depth = stack.pop()
            if isinstance(value, dict):
                if depth > MAX_NESTING_DEPTH:
                    raise ValueError("Catalogue extra fields nested too deeply")
                for kind, field, other in (("objects", "objectID", "npcID"), ("npcs", "npcID", "objectID")):
                    identity, name = value.get(field), value.get("name")
                    if (type(identity) is int and 0 < identity <= 4294967295 and title(name) and
                            value.get(other) is None and value.get("itemID") is None and value.get("dropNPCID") is None):
                        definitions[kind].setdefault(str(identity), set()).add(name)
                for child in value.values():
                    stack.append((child, depth + 1))
            elif isinstance(value, list):
                if depth > MAX_NESTING_DEPTH:
                    raise ValueError("Catalogue extra fields nested too deeply")
                for child in value:
                    stack.append((child, depth + 1))

    visit(quest_rows)
    locales = data["locales"]
    if type(locales) is not dict or not set(locales) <= set(LOCALES):
        raise ValueError("Invalid source-name locales")
    for locale, payload in locales.items():
        if type(payload) is not dict or set(payload) != {"objects", "npcs"}:
            raise ValueError("Invalid source-name payload")
        for kind, entries in payload.items():
            if type(entries) is not dict:
                raise ValueError("Invalid source-name entries")
            for key, entry in entries.items():
                if (type(key) is not str or not re.fullmatch(r"[1-9][0-9]*", key) or
                        int(key) > 4294967295 or type(entry) is not dict or set(entry) != {"source", "name", "url"}):
                    raise ValueError("Invalid source-name identity or fields")
                canonical = definitions[kind].get(key)
                if (not title(entry["source"]) or not title(entry["name"]) or
                        len(entry["source"].encode("utf-8")) > 1024 or len(entry["name"].encode("utf-8")) > 1024 or
                        canonical != {entry["source"]}) or (
                        entry["name"].strip("[]").casefold() in UNKNOWN or entry["name"] == "[" + entry["source"] + "]"):
                    raise ValueError("Invalid source-name label or canonical identity")
                url = ENDPOINT.format(kind="object" if kind == "objects" else "npc", id=key, locale=LOCALES[locale])
                if entry["url"] != url:
                    raise ValueError("Invalid source-name URL")
    return data


def validate_areas(data, catalog):
    """A shared text alias requires agreement across every reviewed homonym."""
    validate_unicode(data)
    quest_rows, dungeon_rows = catalog_lists(catalog)
    if (type(data) is not dict or set(data) != {"schema", "checked", "provenance", "sources", "locales"} or
            type(data["schema"]) is not int or data["schema"] != 1):
        raise ValueError("Invalid area-name schema")
    if type(data["checked"]) is not str or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", data["checked"]):
        raise ValueError("Invalid area-name date")
    datetime.date.fromisoformat(data["checked"])
    provenance = data["provenance"]
    if (type(provenance) is not dict or set(provenance) != {"provider", "extraction", "englishIndex", "localeIndexes", "indexRows"} or
            provenance["provider"] != "Wowhead" or provenance["extraction"] != "world-area-name-only" or
            provenance["englishIndex"] != "https://www.wowhead.com/forever/zones" or
            provenance["localeIndexes"] != AREA_INDEXES or type(provenance["indexRows"]) is not int or
            not 0 < provenance["indexRows"] <= 10000):
        raise ValueError("Invalid area-name provenance")
    recorded = set()

    def visit(root):
        stack = [(root, 0)]
        while stack:
            value, depth = stack.pop()
            if isinstance(value, dict):
                if depth > MAX_NESTING_DEPTH:
                    raise ValueError("Catalogue extra fields nested too deeply")
                for field in ("zoneName", "locationName"):
                    if title(value.get(field)):
                        recorded.add(value[field])
                for child in value.values():
                    stack.append((child, depth + 1))
            elif isinstance(value, list):
                if depth > MAX_NESTING_DEPTH:
                    raise ValueError("Catalogue extra fields nested too deeply")
                for child in value:
                    stack.append((child, depth + 1))

    visit(quest_rows)
    sources, seen = data["sources"], set()
    dungeon_names = {d["name"] for d in dungeon_rows}
    if type(sources) is not dict:
        raise ValueError("Invalid area-name sources")
    for source, identities in sources.items():
        if (not title(source) or len(source.encode("utf-8")) > 1024 or source not in recorded or source in dungeon_names or
                type(identities) is not list or not identities or len(identities) > 100 or
                any(type(i) is not int or not 0 < i <= 4294967295 for i in identities) or
                identities != sorted(set(identities)) or seen.intersection(identities)):
            raise ValueError("Invalid area-name source identity")
        seen.update(identities)
    if len(seen) > provenance["indexRows"]:
        raise ValueError("Area-name source count exceeds observed index")
    locales = data["locales"]
    if type(locales) is not dict or not set(locales) <= set(LOCALES):
        raise ValueError("Invalid area-name locales")
    for locale, entries in locales.items():
        if type(entries) is not dict:
            raise ValueError("Invalid area-name entries")
        for source, entry in entries.items():
            fields = {"source", "name", "observations"}
            if (source not in sources or type(entry) is not dict or set(entry) not in (fields, fields | {"caseVariantSelection"}) or
                    entry["source"] != source or not title(entry["name"]) or len(entry["name"].encode("utf-8")) > 1024 or
                    entry["name"] in (source, "[" + source + "]") or entry["name"].strip("[]").casefold() in UNKNOWN):
                raise ValueError("Invalid area-name label")
            case_choice = "caseVariantSelection" in entry
            if case_choice and entry["caseVariantSelection"] is not True:
                raise ValueError("Invalid area-name case selection")
            observations = entry["observations"]
            if (type(observations) is not dict or set(observations) != {str(i) for i in sources[source]} or
                    any(not title(label) or len(label.encode("utf-8")) > 1024 for label in observations.values())):
                raise ValueError("Area-name homonyms require complete matching observations")
            if case_choice:
                # A reviewed display choice keeps every observation, including its original case.
                labels = set(observations.values())
                if (len(labels) < 2 or entry["name"] not in labels or
                        any(len(label) != len(entry["name"]) or label.lower() != entry["name"].lower() for label in labels)):
                    raise ValueError("Area-name case selection requires observed case-only variants")
            elif any(label != entry["name"] for label in observations.values()):
                raise ValueError("Area-name homonyms require complete matching observations")
    return data


def validate_supplement(data, catalog, expected_locales=None):
    validate_unicode(data)
    quest_rows, dungeon_rows = catalog_lists(catalog)
    if (type(data) is not dict or set(data) != {"schema", "provenance", "locales"} or
            type(data["schema"]) is not int or data["schema"] != 1 or
            data["provenance"] != {"provider": "Dungeon Pro", "extraction": "authored-title-translation"}):
        raise ValueError("Invalid authored-title supplement schema or provenance")
    locales = data["locales"]
    if (type(locales) is not dict or not locales or not set(locales) <= set(LOCALES) or
            (expected_locales is not None and set(locales) != set(expected_locales))):
        raise ValueError("Invalid authored-title supplement locale coverage")
    definitions = {"quests": {str(q["id"]): q for q in quest_rows},
                   "dungeons": {d["key"]: d for d in dungeon_rows}}
    for payload in locales.values():
        if type(payload) is not dict or set(payload) != {"quests", "dungeons"}:
            raise ValueError("Invalid authored-title supplement payload")
        for kind, entries in payload.items():
            if type(entries) is not dict:
                raise ValueError("Invalid authored-title supplement entries")
            for key, entry in entries.items():
                definition = definitions[kind].get(key)
                if definition is None or (kind == "quests" and not re.fullmatch(r"[1-9][0-9]*", key)):
                    raise ValueError("Unknown authored-title supplement identity")
                unchanged = type(entry) is dict and entry.get("source") == entry.get("name")
                fields = {"source", "name", "unchangedProperName"} if unchanged else {"source", "name"}
                if (type(entry) is not dict or set(entry) != fields or
                        (unchanged and entry.get("unchangedProperName") is not True) or
                        entry["source"] != definition["name"] or not title(entry["source"]) or
                        not title(entry["name"]) or entry["name"] == "[" + entry["source"] + "]" or
                        entry["name"].strip("[]").casefold() in UNKNOWN):
                    raise ValueError("Invalid authored title or English source mismatch")
    return data


def merge(data, catalog, *supplements):
    """Keep source records authoritative; authored entries fill only absent titles."""
    merged = copy.deepcopy(validate(data, catalog))
    seen_locales = set()
    for supplement in supplements:
        validate_supplement(supplement, catalog)
        for locale, payload in supplement["locales"].items():
            if locale in seen_locales:
                raise ValueError("Overlapping authored-title supplement locale")
            seen_locales.add(locale)
            for kind, entries in payload.items():
                target = merged["locales"][locale][kind]
                if set(target) & set(entries):
                    raise ValueError("Authored title overlaps an existing source translation")
                target.update(copy.deepcopy(entries))
    identities = {"quests": {str(q["id"]) for q in catalog["quests"]},
                  "dungeons": {d["key"] for d in catalog["dungeons"]}}
    for locale, payload in merged["locales"].items():
        for kind, entries in payload.items():
            if set(entries) != identities[kind]:
                missing = sorted(identities[kind] - set(entries))
                raise ValueError(f"Incomplete localized-title coverage: {locale} {kind}: {missing}")
    return merged


def _read(name, path):
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        raise SystemExit(f"{name} is unreadable: {error}") from error


def _load(name, path):
    try:
        return json.loads(_read(name, path), object_pairs_hook=unique_fields)
    except (ValueError, RecursionError) as error:
        raise SystemExit(f"{name} is invalid: {error}") from error


def load_data(root=ROOT):
    def read(name):
        document = _load(f"data/{name}", root / "data" / name)
        validate_unicode(document)
        return document
    data, catalog = read("name_translations.json"), read("catalog.json")
    supplements = read("name_translation_supplements.json")
    italian = read("name_translation_itIT.json")
    validate_supplement(supplements, catalog, set(LOCALES) - {"itIT"})
    validate_supplement(italian, catalog, {"itIT"})
    merged = merge(data, catalog, supplements, italian)
    sources = validate_sources(read("source_name_translations.json"), catalog)
    for locale, payload in sources["locales"].items():
        for kind, entries in payload.items():
            if entries:
                merged["locales"][locale][kind] = copy.deepcopy(entries)
    areas = validate_areas(read("area_name_translations.json"), catalog)
    merged["sourceAreas"] = copy.deepcopy(areas["sources"])
    for locale, entries in areas["locales"].items():
        if entries:
            merged["locales"][locale]["areas"] = copy.deepcopy(entries)
    return merged


def generate(data):
    if type(data) is not dict or type(data.get("locales")) is not dict:
        raise ValueError("Invalid localized-name data")
    locales = data["locales"]
    for locale in LOCALES:
        if (locale not in locales or type(locales[locale]) is not dict or
                "quests" not in locales[locale] or "dungeons" not in locales[locale]):
            raise ValueError("Invalid localized-name locale coverage")
    source_areas = data.get("sourceAreas", {})
    if type(source_areas) is not dict:
        raise ValueError("Invalid localized source areas")
    for source in source_areas:
        if not title(source) or len(source.encode("utf-8")) > 1024:
            raise ValueError("Invalid localized source-area identity")
    for locale in sorted(LOCALES):
        payload = locales[locale]
        for kind in ("quests", "dungeons", "objects", "npcs", "areas"):
            if kind not in payload:
                continue
            entries = payload[kind]
            if type(entries) is not dict:
                raise ValueError("Invalid localized-name entries")
            for key, entry in entries.items():
                if kind in ("dungeons", "areas"):
                    if type(key) is not str:
                        raise ValueError("Invalid localized name identity")
                elif (type(key) is not str or re.fullmatch(r"[1-9][0-9]*", key) is None or
                        int(key) > 2 ** 53 - 1):
                    # Numeric identities are emitted bare and must survive the Lua
                    # 5.1 number round-trip exactly (cf. scripts/catalog.py
                    # integer()); live quest IDs peak near 98824, so the 2**53-1
                    # bound only rejects hostile input.
                    raise ValueError("Invalid localized name identity")
                if (type(entry) is not dict or not title(entry.get("source")) or
                        not title(entry.get("name"))):
                    raise ValueError("Invalid localized name entry")
    lines = ["-- Localized names from public records and authored titles; runtime remains offline.",
             "local _, addon = ...", "addon.sourceAreaNames = {"]
    for source in sorted(data.get("sourceAreas", {})):
        lines.append(f"    [{quoted(source)}] = {{ name = {quoted(source)} }},")
    lines += ["}", "addon.nameTranslations = {}",
             "addon.nameTranslationFactories = { root = addon.nameTranslations, loaders = {"]
    for locale in sorted(LOCALES):
        lines.append(f"    {locale} = function() return {{")
        for kind in ("quests", "dungeons", "objects", "npcs", "areas"):
            if kind not in data["locales"][locale]:
                continue
            lines.append(f"        {kind} = {{")
            entries = data["locales"][locale][kind]
            for key in sorted(entries, key=str if kind in ("dungeons", "areas") else int):
                entry = entries[key]
                index = quoted(key) if kind in ("dungeons", "areas") else key
                lines.append(f"            [{index}] = {{ source = {quoted(entry['source'])}, name = {quoted(entry['name'])} }},")
            lines.append("        },")
        lines.append("    } end,")
    lines += ["} }", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate the saved data and generated bytes without network access")
    args = parser.parse_args()
    try:
        data = load_data()
        content = generate(data)
    except ValueError as error:
        raise SystemExit(f"localized-name input is invalid: {error}") from error
    target = ROOT / "Database/NameTranslations.lua"
    if args.check:
        try:
            current = target.read_bytes()
        except OSError:
            raise SystemExit("Localized-name generated output differs") from None
        if current != content.encode("utf-8"):
            raise SystemExit("Localized-name generated output differs")
    else:
        try:
            target.parent.mkdir(exist_ok=True)
            target.write_bytes(content.encode("utf-8"))
        except OSError as error:
            raise SystemExit(f"localized-name output is unwritable: {error}") from error
    counts = {locale: {kind: len(entries) for kind, entries in payload.items()} for locale, payload in data["locales"].items()}
    print("Localized names valid: " + json.dumps(counts, sort_keys=True))


if __name__ == "__main__":
    main()
