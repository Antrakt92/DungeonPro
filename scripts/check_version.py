"""Fail when the addon version drifts across TOC, Namespace and CHANGELOG."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    toc = (ROOT / "DungeonPro.toc").read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")
    namespace = (ROOT / "Core" / "Namespace.lua").read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")
    changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")
    found = {
        "DungeonPro.toc ## Version": re.search(r"^## Version: (?P<version>[0-9]+\.[0-9]+\.[0-9]+)$", toc, re.MULTILINE),
        # Parse the literal assignment; never import Lua to read the version.
        "Core/Namespace.lua addon.version": re.search(
            r"^addon\.version = [\"'](?P<version>[0-9]+\.[0-9]+\.[0-9]+)[\"']$", namespace, re.MULTILINE),
        "CHANGELOG.md top heading": re.search(r"^## (?P<version>[0-9]+\.[0-9]+\.[0-9]+) - ", changelog, re.MULTILINE),
    }
    versions = {name: match.group("version") for name, match in found.items() if match}
    unreadable = sorted(set(found) - set(versions))
    if unreadable:
        raise SystemExit("Version not found in: " + ", ".join(unreadable))
    if len(set(versions.values())) != 1:
        detail = ", ".join(f"{name} is {version}" for name, version in sorted(versions.items()))
        raise SystemExit("Version drift: " + detail)
    print(f"Version sync: {next(iter(versions.values()))}")


if __name__ == "__main__":
    main()
