"""Fail when a tracked runtime Lua file is missing from the TOC."""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    toc = (ROOT / "DungeonPro.toc").read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")
    toc_files = {line.strip().replace("\\", "/") for line in toc.splitlines() if line.strip() and not line.startswith("#")}
    tracked = subprocess.run(
        ["git", "ls-files", "--", "Core", "UI"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    runtime = {path.replace("\\", "/") for path in tracked if path.lower().endswith(".lua")}
    missing = sorted(runtime - toc_files)
    if missing:
        raise SystemExit("Runtime files missing from DungeonPro.toc: " + ", ".join(missing))
    print(f"TOC parity: {len(runtime)} runtime files listed")


if __name__ == "__main__":
    main()
