"""Generate the offline Unicode search table from reviewed normalized facts."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def unique_fields(pairs):
    fields = {}
    for key, value in pairs:
        if key in fields:
            raise ValueError(f"Duplicate case-fold input key: {key!r}")
        fields[key] = value
    return fields


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


def generate(data):
    if type(data) is not dict:
        raise ValueError("Invalid case-fold document")
    if (data.get("unicodeVersion") != "16.0.0" or
            data.get("source") != "https://www.unicode.org/Public/16.0.0/ucd/CaseFolding.txt"):
        raise ValueError("Unsupported case-fold source")
    license_text = data.get("license")
    if (not isinstance(license_text, str) or "UNICODE LICENSE V3" not in license_text or
            "Copyright" not in license_text or "]]" in license_text):
        raise ValueError("Missing Unicode data license")
    mappings = data.get("mappings")
    if type(mappings) is not dict or not mappings:
        raise ValueError("Missing case-fold mappings")
    rows = []
    for key, value in mappings.items():
        if not isinstance(key, str) or not key.isascii() or not key.isdecimal() or str(int(key)) != key:
            raise ValueError("Invalid case-fold code point")
        point = int(key)
        if not 0 <= point <= 0x10FFFF or 0xD800 <= point <= 0xDFFF:
            raise ValueError("Invalid case-fold code point")
        if type(value) is not str or not value or len(value) > 3 or value == chr(point):
            raise ValueError("Invalid case-fold mapping")
        # Decimal byte escapes work unchanged in the client's Lua 5.1 runtime.
        escaped = "".join("\\%03d" % byte for byte in value.encode("utf-8"))
        rows.append((point, f'    [{point}] = "{escaped}",'))
    header = ("-- Generated from data/search_casefold.json; Unicode 16.0.0 default full case folding.\n"
              "-- Source: https://www.unicode.org/Public/16.0.0/ucd/CaseFolding.txt\n"
              "--[[\n" + license_text.rstrip() + "\n]]\nlocal _, addon = ...\naddon.searchCaseFold = {\n")
    return header + "\n".join(row for _, row in sorted(rows)) + "\n}\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = _load("data/search_casefold.json", ROOT / "data/search_casefold.json")
    try:
        generated = generate(data)
    except ValueError as error:
        raise SystemExit(f"data/search_casefold.json is invalid: {error}") from error
    output = ROOT / "Database/SearchCaseFold.lua"
    if args.check:
        try:
            current = output.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            raise SystemExit("Generated case-fold table differs; run python scripts/casefold.py") from None
        if current != generated:
            raise SystemExit("Generated case-fold table differs; run python scripts/casefold.py")
    else:
        try:
            output.parent.mkdir(exist_ok=True)
            output.write_text(generated, encoding="utf-8")
        except OSError as error:
            raise SystemExit(f"case-fold output is unwritable: {error}") from error
    print(f"Unicode case-fold mappings: {len(data['mappings'])}; valid")


if __name__ == "__main__":
    main()
