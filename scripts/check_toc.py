"""Fail when TOC runtime membership drifts in either direction or repeats entries."""
import subprocess
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Live TOC enumeration shows the only non-Core/UI runtime files are
# Locales/Strings.lua, Locales/Translations.lua, Database/Catalog.lua,
# Database/NameTranslations.lua and Database/SearchCaseFold.lua. The scope
# names their directories rather than pinning the five files, so a sixth file
# in either directory is covered without a script change.
RUNTIME_DIRS = ("Core/", "UI/", "Database/", "Locales/")

# Canonical UI load order, matching DungeonPro.toc. Only relative order among
# entries present in the TOC is asserted, so minimal fixtures keep passing.
# Load-bearing pins: Language before Window (Window reads localized strings
# at build) and QuestNavigation/QuestHistory/PreparationOverview before
# Window (Window mixes their views).
CANONICAL_UI_ORDER = (
    "UI/TooltipLease.lua",
    "UI/Theme.lua",
    "UI/Language.lua",
    "UI/QuestStatus.lua",
    "UI/QuestListRewards.lua",
    "UI/RewardCache.lua",
    "UI/QuestNavigation.lua",
    "UI/QuestHistory.lua",
    "UI/DungeonMap.lua",
    "UI/PreparationOverview.lua",
    "UI/Window.lua",
    "UI/Navigation.lua",
    "UI/Minimap.lua",
)


def _check_ui_order(entries):
    positions = {}
    for index, entry in enumerate(entries):
        lowered = entry.lower()
        if lowered not in positions:
            positions[lowered] = index
    canonical = [name.lower() for name in CANONICAL_UI_ORDER]
    present = [name for name in canonical if name in positions]
    for first in range(len(present)):
        for second in range(first + 1, len(present)):
            if positions[present[first]] > positions[present[second]]:
                raise SystemExit(
                    "TOC order violation: "
                    f"{present[first]} must load before {present[second]} "
                    "(see CANONICAL_UI_ORDER in scripts/check_toc.py)")


def _tracked(root):
    out = subprocess.run(
        ["git", "ls-files", "--", *RUNTIME_DIRS],
        cwd=root, capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    return {path.replace("\\", "/") for path in out}


def _untracked(root):
    # The real "forgot to git-add" hole: files on disk but not yet tracked.
    # The pathspec keeps unrelated WIP elsewhere in the tree out of scope.
    out = subprocess.run(
        ["git", "ls-files", "--others", "--exclude-standard",
         "--", *RUNTIME_DIRS],
        cwd=root, capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    return {path.replace("\\", "/") for path in out}


def main():
    toc = (ROOT / "DungeonPro.toc").read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")
    entries = [line.strip().replace("\\", "/") for line in toc.splitlines()
               if line.strip() and not line.startswith("#")]
    # Case-fold for comparison (Windows checkout); originals stay in messages.
    folded = Counter(entry.lower() for entry in entries)
    duplicates = sorted(entry for entry in entries if folded[entry.lower()] > 1)
    toc_files = {entry.lower() for entry in entries}
    tracked = _tracked(ROOT)
    tracked_files = {path.lower() for path in tracked}
    runtime = {path for path in tracked | _untracked(ROOT)
               if path.lower().endswith(".lua") and path.startswith(RUNTIME_DIRS)}
    missing = sorted(path for path in runtime if path.lower() not in toc_files)
    stale = sorted(path for path in entries if path.lower().endswith(".lua") and path.lower() not in tracked_files)
    problems = []
    if missing:
        problems.append("Runtime files missing from DungeonPro.toc: " + ", ".join(missing))
    if stale:
        problems.append("TOC entries with no tracked file: " + ", ".join(stale))
    if duplicates:
        problems.append("Duplicate TOC entries: " + ", ".join(duplicates))
    try:
        _check_ui_order(entries)
    except SystemExit as order:
        problems.append(str(order))
    if problems:
        raise SystemExit("; ".join(problems))
    print(f"TOC parity: {len(runtime)} runtime files listed")


if __name__ == "__main__":
    main()
