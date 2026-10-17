"""Run the local verification matrix; no downloads or hosted jobs."""
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(*args):
    print("> " + " ".join(map(str, args)), flush=True)
    subprocess.run(args, cwd=ROOT, check=True)


def main():
    lua, luac = shutil.which("lua5.1"), shutil.which("luac5.1")
    if not lua or not luac:
        raise SystemExit("Lua 5.1 and luac5.1 are required; no automatic install is performed")
    run(sys.executable, "scripts/catalog.py", "--check")
    run(sys.executable, "scripts/casefold.py", "--check")
    for path in sorted(ROOT.rglob("*.lua")):
        if "dist" not in path.parts:
            run(luac, "-p", str(path))
    run(lua, "tests/planner.lua")
    run(lua, "tests/context.lua")
    run(lua, "tests/catalog_contexts.lua")
    run(lua, "tests/client_ui.lua")
    run(lua, "tests/locales.lua")
    run(lua, "tests/search.lua")
    run(lua, "tests/ui_preparation.lua")
    run(lua, "tests/theme.lua")
    run(lua, "tests/quest_status.lua")
    run(lua, "tests/quest_payment.lua")
    run(lua, "tests/held_quest_payment.lua")
    run(lua, "tests/quest_details.lua")
    run(lua, "tests/rewards.lua")
    run(lua, "tests/cached_rewards.lua")
    run(lua, "tests/portraits.lua")
    run(lua, "tests/giver_portraits.lua")
    run(lua, "tests/offered_portraits.lua")
    run(lua, "tests/dungeon_art.lua")
    run(lua, "tests/dungeon_names.lua")
    run(lua, "tests/npc_names.lua")
    run(lua, "tests/restriction_names.lua")
    run(lua, "tests/items.lua")
    run(lua, "tests/carried_items.lua")
    run(lua, "tests/quest_log_capacity.lua")
    run(lua, "tests/quest_log_open.lua")
    run(lua, "tests/cached_quest_names.lua")
    run(lua, "tests/offers.lua")
    run(lua, "tests/offered_rewards.lua")
    run(lua, "tests/offered_objectives.lua")
    run(lua, "tests/probe.lua")
    run(lua, "tests/navigation.lua")
    run(lua, "tests/minimap.lua")
    run(sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py", "-v")
    run(sys.executable, "scripts/package.py")
    run("git", "diff", "--check")
    print("Local checks passed. Native client and visual acceptance remain separate.")


if __name__ == "__main__":
    main()
