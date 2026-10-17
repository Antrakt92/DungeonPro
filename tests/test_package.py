import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

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
                self.assertIn("DungeonPro/DungeonPro.toc", names)
                self.assertIn("DungeonPro/Database/Catalog.lua", names)
                for resource in ("NotoSans-Regular.ttf", "OFL.txt", "NOTICE.txt"):
                    self.assertIn("DungeonPro/Media/Fonts/" + resource, names)
                for resource in ("Wowhead.tga", "NOTICE.txt"):
                    name = "Media/Icons/" + resource
                    self.assertIn("DungeonPro/" + name, names)
                    self.assertEqual(archive.read("DungeonPro/" + name), (ROOT / name).read_bytes())
                self.assertFalse(any("tests/" in p or "scripts/" in p or "data/" in p for p in names))
                self.assertTrue(all(p.startswith("DungeonPro/") for p in names))

    def test_default_archive_name_and_required_toc_follow_the_new_addon_identifier(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "DungeonPro.toc").write_text("## Version: 1.2.3\nCore.lua\n", encoding="utf-8")
            for name in ("README.md", "CHANGELOG.md", "LICENSE", "Core.lua"):
                (root / name).write_text("fixture\n", encoding="utf-8")
            media = root / "Media" / "Fonts"
            media.mkdir(parents=True)
            for name in ("NotoSans-Regular.ttf", "OFL.txt", "NOTICE.txt"):
                (media / name).write_bytes(b"fixture")
            icons = root / "Media" / "Icons"
            icons.mkdir()
            for name in ("Wowhead.tga", "NOTICE.txt"):
                (icons / name).write_bytes(b"fixture")
            flags = root / "Media" / "Flags"
            flags.mkdir()
            for locale in ("enUS", "ruRU", "deDE", "frFR", "esES", "itIT", "ptBR", "koKR", "zhCN", "zhTW"):
                (flags / (locale + ".tga")).write_bytes(b"fixture")
            (flags / "NOTICE.txt").write_text("fixture\n", encoding="utf-8")
            path, _ = packager.package(root=root)
            self.assertEqual(path, root / "dist" / "DungeonPro-1.2.3-Forever-dev.zip")
            with zipfile.ZipFile(path) as archive:
                self.assertIn("DungeonPro/DungeonPro.toc", archive.namelist())
            (root / "DungeonPro.toc").rename(root / "DungeonPrep.toc")
            with self.assertRaisesRegex(ValueError, "DungeonPro.toc"):
                packager.package(root=root)

    def test_build_is_deterministic(self):
        with tempfile.TemporaryDirectory() as tmp:
            _, a = packager.package(output=Path(tmp) / "a.zip")
            _, b = packager.package(output=Path(tmp) / "b.zip")
            self.assertEqual(a, b)

    def test_failed_rebuild_preserves_previous_archive_and_removes_temporary_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "addon.zip"
            packager.package(output=output)
            original = output.read_bytes()
            native = packager.exact_path
            def missing_last(root, name):
                if name == "Core/Events.lua":
                    raise ValueError("Missing payload")
                return native(root, name)
            with mock.patch.object(packager, "exact_path", side_effect=missing_last):
                with self.assertRaisesRegex(ValueError, "Missing payload"):
                    packager.package(output=output)
            self.assertEqual(output.read_bytes(), original)
            self.assertEqual(list(Path(tmp).iterdir()), [output])

    def test_failed_archive_verification_never_publishes_an_unverified_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "addon.zip"
            with zipfile.ZipFile(output, "w") as previous:
                previous.writestr("previous.txt", "previous verified build")
            original = output.read_bytes()
            with mock.patch.object(zipfile.ZipFile, "testzip", return_value="corrupt-entry"):
                with self.assertRaises((AssertionError, ValueError)):
                    packager.package(output=output)
            self.assertEqual(output.read_bytes(), original)
            self.assertEqual(list(Path(tmp).iterdir()), [output])

    def test_missing_icon_or_attribution_preserves_previous_verified_archive(self):
        for missing in ("Media/Icons/Wowhead.tga", "Media/Icons/NOTICE.txt"):
            with self.subTest(missing=missing), tempfile.TemporaryDirectory() as tmp:
                output = Path(tmp) / "addon.zip"
                packager.package(output=output)
                original = output.read_bytes()
                native = packager.exact_path

                def omitted(root, name):
                    if name == missing:
                        raise ValueError("Missing icon resource")
                    return native(root, name)

                with mock.patch.object(packager, "exact_path", side_effect=omitted):
                    with self.assertRaisesRegex(ValueError, "Missing icon resource"):
                        packager.package(output=output)
                self.assertEqual(output.read_bytes(), original)
                self.assertEqual(list(Path(tmp).iterdir()), [output])

    def test_failed_final_replace_preserves_previous_archive_and_cleans_staging(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "addon.zip"
            packager.package(output=output)
            original = output.read_bytes()
            with mock.patch.object(Path, "replace", side_effect=PermissionError("archive is open")):
                with self.assertRaisesRegex(PermissionError, "archive is open"):
                    packager.package(output=output)
            self.assertEqual(output.read_bytes(), original)
            self.assertEqual(list(Path(tmp).iterdir()), [output])

    def test_failed_first_build_leaves_no_installable_or_temporary_archive(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "addon.zip"
            with mock.patch.object(zipfile.ZipFile, "testzip", return_value="corrupt-entry"):
                with self.assertRaisesRegex(ValueError, "integrity"):
                    packager.package(output=output)
            self.assertEqual(list(Path(tmp).iterdir()), [])


if __name__ == "__main__":
    unittest.main()
