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
        try:
            entries = {p.name for p in path.iterdir()}
        except OSError:
            raise ValueError(f"Missing path or incorrect filename case: {name}")
        if part not in entries:
            raise ValueError(f"Missing path or incorrect filename case: {name}")
        path = path / part
    return path


def _read_bytes(path, name):
    try:
        return path.read_bytes()
    except OSError as error:
        raise ValueError(f"Unreadable package input: {name}") from error


def package(root=ROOT, output=None):
    toc_name = f"{ADDON_NAME}.toc"
    toc_bytes = _read_bytes(exact_path(root, toc_name), toc_name)
    toc = toc_bytes.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")
    version_match = re.search(r"^## Version: ([0-9]+\.[0-9]+\.[0-9]+)$", toc, re.MULTILINE)
    if not version_match:
        raise ValueError(f"{toc_name} is missing a valid ## Version: X.Y.Z line")
    version = version_match.group(1)
    names = [toc_name, "README.md", "CHANGELOG.md", "LICENSE"]
    names += ["Media/Fonts/NotoSans-Regular.ttf", "Media/Fonts/OFL.txt", "Media/Fonts/NOTICE.txt"]
    names += ["Media/Icons/Wowhead.tga", "Media/Icons/Language.tga", "Media/Icons/NOTICE.txt"]
    names += [line.strip().replace("\\", "/") for line in toc.splitlines() if line.strip() and not line.strip().startswith("#")]
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
                info.create_system = 0  # Pin host-independent archives on every builder.
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, toc_bytes if name == toc_name else _read_bytes(path, name))
        with zipfile.ZipFile(staged) as archive:
            if archive.testzip() is not None or len(archive.namelist()) != len(set(archive.namelist())) or len(archive.namelist()) != len(names):
                raise ValueError("Package integrity or entry identity failed")
            for name in names:
                if archive.read(f"{ADDON_NAME}/" + name) != _read_bytes(root / name, name):
                    raise ValueError("Package source changed during build")
        # Keep the previous verified archive until its replacement passes every check.
        staged.replace(output)
    finally:
        if staged is not None:
            staged.unlink(missing_ok=True)
    return output, hashlib.sha256(_read_bytes(output, output.name)).hexdigest()


if __name__ == "__main__":
    path, digest = package()
    print(f"Built {path.name}\nSHA256 {digest}")
