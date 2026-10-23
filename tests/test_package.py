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

    def test_nested_path_under_file_fails_with_value_error(self):
        with self.assertRaisesRegex(ValueError, "filename case"):
            packager.exact_path(ROOT, "README.md/evil.lua")

    def test_archive_is_installable_and_contains_only_runtime_and_player_docs(self):
        with tempfile.TemporaryDirectory() as tmp:
            path, _ = packager.package(output=Path(tmp) / "addon.zip")
            with zipfile.ZipFile(path) as archive:
                names = archive.namelist()
                self.assertIn("DungeonPro/DungeonPro.toc", names)
                self.assertIn("DungeonPro/Database/Catalog.lua", names)
                for resource in ("NotoSans-Regular.ttf", "OFL.txt", "NOTICE.txt"):
                    self.assertIn("DungeonPro/Media/Fonts/" + resource, names)
                for resource in ("Wowhead.tga", "Language.tga", "NOTICE.txt"):
                    name = "Media/Icons/" + resource
                    self.assertIn("DungeonPro/" + name, names)
                    self.assertEqual(archive.read("DungeonPro/" + name), (ROOT / name).read_bytes())
                self.assertFalse(any("tests/" in p or "scripts/" in p or "data/" in p or "Media/Flags/" in p for p in names))
                self.assertTrue(all(p.startswith("DungeonPro/") for p in names))
                for info in archive.infolist():
                    self.assertEqual(info.create_system, 0, f"host-independent archive: {info.filename}")

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
            for name in ("Wowhead.tga", "Language.tga", "NOTICE.txt"):
                (icons / name).write_bytes(b"fixture")
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

    def test_archive_pins_create_system_zero_even_for_foreign_host_defaults(self):
        native = zipfile.ZipInfo

        class ForeignHostZipInfo(native):
            def __init__(self, filename, date_time=(2026, 1, 1, 0, 0, 0)):
                super().__init__(filename, date_time)
                self.create_system = 3  # Simulate a Unix builder on any host.

        with mock.patch.object(zipfile, "ZipInfo", ForeignHostZipInfo):
            with tempfile.TemporaryDirectory() as tmp:
                path, _ = packager.package(output=Path(tmp) / "addon.zip")
                with zipfile.ZipFile(path) as archive:
                    infos = archive.infolist()
        self.assertTrue(infos, "expected a non-empty installable archive")
        for info in infos:
            self.assertEqual(info.create_system, 0, f"host-independent archive: {info.filename}")

    def test_packager_references_zipinfo_by_attribute(self):
        # The foreign-host test above patches zipfile.ZipInfo on the module. If
        # the packager ever switched to `from zipfile import ZipInfo`, that
        # patch would silently stop applying while the test stayed green. Pin
        # the attribute reference form so the pin cannot be neutered.
        source = (ROOT / "scripts" / "package.py").read_text(encoding="utf-8")
        self.assertIn("zipfile.ZipInfo", source)
        self.assertNotRegex(source, r"(?m)^\s*from\s+zipfile\s+import\s+.*\bZipInfo\b")

    def test_toc_changes_during_build_cannot_publish_inconsistent_membership_or_version(self):
        for mutation in ("append", "remove", "version"):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                toc = root / "DungeonPro.toc"
                original_toc = "## Version: 1.2.3\nCore.lua\n"
                toc.write_text(original_toc, encoding="utf-8")
                for name in ("README.md", "CHANGELOG.md", "LICENSE", "Core.lua", "Extra.lua",
                             "Media/Fonts/NotoSans-Regular.ttf", "Media/Fonts/OFL.txt", "Media/Fonts/NOTICE.txt",
                             "Media/Icons/Wowhead.tga", "Media/Icons/Language.tga", "Media/Icons/NOTICE.txt"):
                    path = root / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(b"fixture")
                output = root / "dist" / "addon.zip"
                packager.package(root=root, output=output)
                previous = output.read_bytes()
                native, reads, changed = packager.exact_path, 0, False

                def mutate_before_toc_archive_read(base, name):
                    nonlocal reads, changed
                    if name == "DungeonPro.toc":
                        reads += 1
                        if reads == 2:
                            changed = True
                            replacement = (original_toc + "Extra.lua\n" if mutation == "append" else
                                           "## Version: 1.2.3\n" if mutation == "remove" else
                                           original_toc.replace("1.2.3", "1.2.4"))
                            toc.write_text(replacement, encoding="utf-8")
                    return native(base, name)

                with mock.patch.object(packager, "exact_path", side_effect=mutate_before_toc_archive_read):
                    with self.assertRaisesRegex(ValueError, "source changed"):
                        packager.package(root=root, output=output)
                self.assertTrue(changed, "exercise the parse-to-archive TOC mutation")
                self.assertEqual(output.read_bytes(), previous)
                self.assertEqual(list(output.parent.iterdir()), [output])

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
        for missing in ("Media/Icons/Wowhead.tga", "Media/Icons/Language.tga", "Media/Icons/NOTICE.txt"):
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

    def test_indented_toc_comment_is_ignored_not_packaged(self):
        # The comment filter consumes stripped lines, so it must test the
        # stripped value: "  # indented note" is a comment, not a phantom
        # entry that would fail filename-case resolution.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "DungeonPro.toc").write_text(
                "## Version: 1.2.3\n  # indented note\n# full comment\nCore.lua\n", encoding="utf-8")
            for name in ("README.md", "CHANGELOG.md", "LICENSE", "Core.lua"):
                (root / name).write_text("fixture\n", encoding="utf-8")
            media = root / "Media" / "Fonts"
            media.mkdir(parents=True)
            for name in ("NotoSans-Regular.ttf", "OFL.txt", "NOTICE.txt"):
                (media / name).write_bytes(b"fixture")
            icons = root / "Media" / "Icons"
            icons.mkdir()
            for name in ("Wowhead.tga", "Language.tga", "NOTICE.txt"):
                (icons / name).write_bytes(b"fixture")
            path, _ = packager.package(root=root, output=root / "dist" / "addon.zip")
            with zipfile.ZipFile(path) as archive:
                self.assertFalse(any("indented" in name for name in archive.namelist()))

    def test_missing_toc_version_fails_with_value_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "DungeonPro.toc").write_text("Core.lua\n", encoding="utf-8")
            for name in ("README.md", "CHANGELOG.md", "LICENSE", "Core.lua"):
                (root / name).write_text("fixture\n", encoding="utf-8")
            media = root / "Media" / "Fonts"
            media.mkdir(parents=True)
            for name in ("NotoSans-Regular.ttf", "OFL.txt", "NOTICE.txt"):
                (media / name).write_bytes(b"fixture")
            icons = root / "Media" / "Icons"
            icons.mkdir()
            for name in ("Wowhead.tga", "Language.tga", "NOTICE.txt"):
                (icons / name).write_bytes(b"fixture")
            with self.assertRaisesRegex(ValueError, "Version"):
                packager.package(root=root, output=root / "dist" / "addon.zip")

    def test_failed_first_build_leaves_no_installable_or_temporary_archive(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "addon.zip"
            with mock.patch.object(zipfile.ZipFile, "testzip", return_value="corrupt-entry"):
                with self.assertRaisesRegex(ValueError, "integrity"):
                    packager.package(output=output)
            self.assertEqual(list(Path(tmp).iterdir()), [])

    def test_unreadable_package_input_fails_with_value_error(self):
        # An input that exact_path resolves but read_bytes cannot serve
        # (permissions, transient I/O) must fail as ValueError naming the
        # entry, never as an escaped OSError traceback.
        for unreadable in ("toc", "payload", "reread", "digest"):
            with self.subTest(unreadable=unreadable), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                (root / "DungeonPro.toc").write_text("## Version: 1.2.3\nCore.lua\n", encoding="utf-8")
                for name in ("README.md", "CHANGELOG.md", "LICENSE", "Core.lua"):
                    (root / name).write_text("fixture\n", encoding="utf-8")
                (root / "Media" / "Fonts").mkdir(parents=True)
                for name in ("NotoSans-Regular.ttf", "OFL.txt", "NOTICE.txt"):
                    (root / "Media" / "Fonts" / name).write_bytes(b"fixture")
                (root / "Media" / "Icons").mkdir()
                for name in ("Wowhead.tga", "Language.tga", "NOTICE.txt"):
                    (root / "Media" / "Icons" / name).write_bytes(b"fixture")
                native = Path.read_bytes
                reads = []

                def gated(self):
                    reads.append(str(self))
                    if unreadable == "toc" and self.name == "DungeonPro.toc":
                        raise PermissionError("denied")
                    if unreadable == "payload" and self.name == "Core.lua":
                        raise PermissionError("denied")
                    if unreadable == "reread" and self.name == "Core.lua" and len(
                            [seen for seen in reads if seen.endswith("Core.lua")]) > 1:
                        raise PermissionError("denied")
                    if unreadable == "digest" and self.suffix == ".zip":
                        raise PermissionError("denied")
                    return native(self)

                with mock.patch.object(Path, "read_bytes", gated):
                    with self.assertRaisesRegex(ValueError, "Unreadable package input"):
                        packager.package(root=root, output=root / "dist" / "addon.zip")

    def test_undecodable_toc_fails_with_value_error(self):
        # A TOC that exact_path resolves but utf-8 cannot decode must fail as
        # ValueError naming the entry (the file's "Unreadable package input"
        # idiom), never as an escaped UnicodeDecodeError traceback, and must
        # publish no archive.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "DungeonPro.toc").write_bytes(b"\xff\xfe invalid \x00 bytes")
            for name in ("README.md", "CHANGELOG.md", "LICENSE", "Core.lua"):
                (root / name).write_text("fixture\n", encoding="utf-8")
            (root / "Media" / "Fonts").mkdir(parents=True)
            for name in ("NotoSans-Regular.ttf", "OFL.txt", "NOTICE.txt"):
                (root / "Media" / "Fonts" / name).write_bytes(b"fixture")
            (root / "Media" / "Icons").mkdir()
            for name in ("Wowhead.tga", "Language.tga", "NOTICE.txt"):
                (root / "Media" / "Icons" / name).write_bytes(b"fixture")
            output = root / "dist" / "addon.zip"
            with self.assertRaisesRegex(ValueError, "Unreadable package input: DungeonPro.toc"):
                packager.package(root=root, output=output)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
