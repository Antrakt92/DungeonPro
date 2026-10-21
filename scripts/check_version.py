"""Fail when the addon version drifts across TOC, Namespace and CHANGELOG."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

TOC_PATTERN = r"^## Version: (?P<version>[0-9]+\.[0-9]+\.[0-9]+)$"
# Parse the literal assignment; never import Lua to read the version.
NAMESPACE_PATTERN = r"^addon\.version = [\"'](?P<version>[0-9]+\.[0-9]+\.[0-9]+)[\"']$"
CHANGELOG_PATTERN = r"^## (?P<version>[0-9]+\.[0-9]+\.[0-9]+) - "


def _single_version(name, pattern, text):
    """Exactly one candidate may exist; 0 is "not found", >1 is "ambiguous".

    A duplicated assignment whose later line drifts would otherwise resolve to
    the first match and pass. CHANGELOG history headings are the deliberate
    exception (see main): older releases legitimately repeat the heading form.
    """
    found = re.findall(pattern, text, re.MULTILINE)
    if not found:
        raise SystemExit(f"Version not found in: {name}")
    if len(found) > 1:
        raise SystemExit(f"Ambiguous version in {name}: " + ", ".join(sorted(set(found))))
    return found[0]


def main():
    toc = (ROOT / "DungeonPro.toc").read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")
    namespace = (ROOT / "Core" / "Namespace.lua").read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")
    changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")
    versions = {
        "DungeonPro.toc ## Version": _single_version("DungeonPro.toc ## Version", TOC_PATTERN, toc),
        "Core/Namespace.lua addon.version": _single_version(
            "Core/Namespace.lua addon.version", NAMESPACE_PATTERN, namespace),
    }
    # Top heading wins by construction: re.search returns the first match, and
    # older release headings below it are history, not ambiguity.
    top = re.search(CHANGELOG_PATTERN, changelog, re.MULTILINE)
    if not top:
        raise SystemExit("Version not found in: CHANGELOG.md top heading")
    versions["CHANGELOG.md top heading"] = top.group("version")
    if len(set(versions.values())) != 1:
        detail = ", ".join(f"{name} is {version}" for name, version in sorted(versions.items()))
        raise SystemExit("Version drift: " + detail)
    print(f"Version sync: {next(iter(versions.values()))}")


if __name__ == "__main__":
    main()
