import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("packager", ROOT / "scripts/package.py")
packager = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(packager)


class PackageTests(unittest.TestCase):
    def test_incorrect_filename_case_fails_on_windows_too(self):
        with self.assertRaisesRegex(ValueError, "filename case"):
            packager.exact_path(ROOT, "database/Catalog.lua")

    def test_archive_is_installable_and_contains_only_runtime_and_player_docs(self):
        with tempfile.TemporaryDirectory() as tmp:
            path, _ = packager.package(output=Path(tmp) / "addon.zip")
            with zipfile.ZipFile(path) as archive:
                names = archive.namelist()
                self.assertIn("DungeonPrep/DungeonPrep.toc", names)
                self.assertIn("DungeonPrep/Database/Catalog.lua", names)
                self.assertFalse(any("tests/" in p or "scripts/" in p or "data/" in p for p in names))
                self.assertTrue(all(p.startswith("DungeonPrep/") for p in names))

    def test_build_is_deterministic(self):
        with tempfile.TemporaryDirectory() as tmp:
            _, a = packager.package(output=Path(tmp) / "a.zip")
            _, b = packager.package(output=Path(tmp) / "b.zip")
            self.assertEqual(a, b)


if __name__ == "__main__":
    unittest.main()
