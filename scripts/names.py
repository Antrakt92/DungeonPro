"""Validate title-only source data and generate the offline localized name table."""
import argparse
import datetime
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALES = {"deDE": 3, "frFR": 2, "esES": 6, "itIT": 9, "ptBR": 8,
           "ruRU": 7, "koKR": 1, "zhCN": 4, "zhTW": 10}
ENDPOINT = "https://nether.wowhead.com/forever/tooltip/{kind}/{id}?locale={locale}"
UNKNOWN = {"unknown", "sconosciuto", "inconnu", "unbekannt", "desconocido", "desconhecido",
           "未知", "未知任务", "未知任務", "알 수 없음"}


def title(value):
    return (type(value) is str and 0 < len(value) <= 1024 and value.strip() == value and
            bool(value.strip()) and not any(ord(c) < 32 or ord(c) == 127 for c in value) and
            "|" not in value and "<" not in value and ">" not in value)


def validate(data, catalog):
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
    quests = {str(q["id"]): q for q in catalog["quests"]}
    dungeons = {d["key"]: d for d in catalog["dungeons"]}
    if (type(provenance.get("catalogueQuestCount")) is not int or provenance.get("catalogueQuestCount") != len(quests) or
            type(provenance.get("englishVerifiedCount")) is not int or provenance["englishVerifiedCount"] != len(quests)):
        raise ValueError("Localized-name catalogue coverage changed")
    dungeon_sources = provenance["dungeonSources"]
    for key, zone in dungeon_sources.items():
        if key not in dungeons or type(zone) is not int or not 0 < zone <= 2**53 - 1:
            raise ValueError("Invalid localized dungeon source identity")
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
                source_id = key if kind == "quests" else dungeon_sources.get(key)
                expected = ENDPOINT.format(kind="quest" if kind == "quests" else "zone", id=source_id, locale=LOCALES[locale])
                if source_id is None or entry["url"] != expected:
                    raise ValueError("Invalid localized-name source URL")
    return data


def quoted(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def generate(data):
    lines = ["-- Localized titles from public quest and zone records; runtime remains offline.",
             "local _, addon = ...", "addon.nameTranslations = {"]
    for locale in sorted(LOCALES):
        lines.append(f"    {locale} = {{")
        for kind in ("quests", "dungeons"):
            lines.append(f"        {kind} = {{")
            entries = data["locales"][locale][kind]
            for key in sorted(entries, key=int if kind == "quests" else str):
                entry = entries[key]
                index = key if kind == "quests" else quoted(key)
                lines.append(f"            [{index}] = {{ source = {quoted(entry['source'])}, name = {quoted(entry['name'])} }},")
            lines.append("        },")
        lines.append("    },")
    lines += ["}", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate the saved data and generated bytes without network access")
    args = parser.parse_args()
    data = json.loads((ROOT / "data/name_translations.json").read_text(encoding="utf-8"))
    catalog = json.loads((ROOT / "data/catalog.json").read_text(encoding="utf-8"))
    content = generate(validate(data, catalog))
    target = ROOT / "Database/NameTranslations.lua"
    if args.check:
        if not target.exists() or target.read_bytes() != content.encode("utf-8"):
            raise SystemExit("Localized-name generated output differs")
    else:
        target.write_text(content, encoding="utf-8", newline="\n")
    counts = {locale: {kind: len(entries) for kind, entries in payload.items()} for locale, payload in data["locales"].items()}
    print("Localized names valid: " + json.dumps(counts, sort_keys=True))


if __name__ == "__main__":
    main()
