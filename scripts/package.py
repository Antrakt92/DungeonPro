"""Build a deterministic, TOC-driven development ZIP without publishing."""
from __future__ import annotations

import hashlib
import re
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
ADDON_NAME = "DungeonPro"


def exact_path(root, name):
    path = root
    for part in PurePosixPath(name).parts:
        if part not in {p.name for p in path.iterdir()}:
            raise ValueError(f"Missing path or incorrect filename case: {name}")
        path = path / part
    return path


def package(root=ROOT, output=None):
    toc_name = f"{ADDON_NAME}.toc"
    toc = exact_path(root, toc_name).read_text(encoding="utf-8")
    version = re.search(r"^## Version: ([0-9]+\.[0-9]+\.[0-9]+)$", toc, re.MULTILINE).group(1)
    names = [toc_name, "README.md", "CHANGELOG.md", "LICENSE"]
    names += [line.strip().replace("\\", "/") for line in toc.splitlines() if line.strip() and not line.startswith("#")]
    output = output or root / "dist" / f"{ADDON_NAME}-{version}-Forever-dev.zip"
    output.parent.mkdir(parents=True, exist_ok=True)
    staged = None
    try:
        with tempfile.NamedTemporaryFile(prefix=".DungeonPro-", suffix=".zip", dir=output.parent, delete=False) as handle:
            staged = Path(handle.name)
        with zipfile.ZipFile(staged, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for name in names:
                if PurePosixPath(name).is_absolute() or ".." in PurePosixPath(name).parts:
                    raise ValueError("Package path escapes project")
                path = exact_path(root, name)
                if not path.resolve().is_relative_to(root.resolve()):
                    raise ValueError("Package path escapes project")
                info = zipfile.ZipInfo(f"{ADDON_NAME}/" + name, (2026, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, path.read_bytes())
        with zipfile.ZipFile(staged) as archive:
            if archive.testzip() is not None or len(archive.namelist()) != len(set(archive.namelist())) or len(archive.namelist()) != len(names):
                raise ValueError("Package integrity or entry identity failed")
            for name in names:
                if archive.read(f"{ADDON_NAME}/" + name) != (root / name).read_bytes():
                    raise ValueError("Package source changed during build")
        # Keep the previous verified archive until its replacement passes every check.
        staged.replace(output)
    finally:
        if staged is not None:
            staged.unlink(missing_ok=True)
    return output, hashlib.sha256(output.read_bytes()).hexdigest()


if __name__ == "__main__":
    path, digest = package()
    print(f"Built {path.name}\nSHA256 {digest}")
