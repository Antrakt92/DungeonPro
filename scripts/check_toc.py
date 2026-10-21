"""Fail when TOC runtime membership drifts in either direction or repeats entries."""
import subprocess
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    toc = (ROOT / "DungeonPro.toc").read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")
    entries = [line.strip().replace("\\", "/") for line in toc.splitlines()
               if line.strip() and not line.startswith("#")]
    duplicates = sorted(name for name, count in Counter(entries).items() if count > 1)
    toc_files = set(entries)
    tracked = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    tracked = {path.replace("\\", "/") for path in tracked}
    runtime = {path for path in tracked
               if path.lower().endswith(".lua") and (path.startswith("Core/") or path.startswith("UI/"))}
    missing = sorted(runtime - toc_files)
    stale = sorted(path for path in toc_files if path.lower().endswith(".lua") and path not in tracked)
    problems = []
    if missing:
        problems.append("Runtime files missing from DungeonPro.toc: " + ", ".join(missing))
    if stale:
        problems.append("TOC entries with no tracked file: " + ", ".join(stale))
    if duplicates:
        problems.append("Duplicate TOC entries: " + ", ".join(duplicates))
    if problems:
        raise SystemExit("; ".join(problems))
    print(f"TOC parity: {len(runtime)} runtime files listed")


if __name__ == "__main__":
    main()
