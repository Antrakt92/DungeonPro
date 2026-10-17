"""Verify the neutral globe resource, reproducibility, and installable boundary."""
import importlib.util
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class LanguageIconTests(unittest.TestCase):
    def test_globe_is_power_of_two_rgba_with_transparent_background_and_smooth_edges(self):
        data = (ROOT / "Media/Icons/Language.tga").read_bytes()
        self.assertEqual(struct.unpack("<BBBHHBHHHHBB", data[:18]),
                         (0, 0, 2, 0, 0, 0, 0, 0, 64, 64, 32, 0x28))
        self.assertEqual(len(data), 18 + 64 * 64 * 4)
        alpha = list(data[21::4])
        self.assertIn(0, alpha)
        self.assertIn(255, alpha)
        self.assertTrue(any(0 < value < 255 for value in alpha))
        for x in range(64):
            self.assertEqual(alpha[x], 0)
            self.assertEqual(alpha[63 * 64 + x], 0)
        for y in range(64):
            self.assertEqual(alpha[y * 64], 0)
            self.assertEqual(alpha[y * 64 + 63], 0)
        # A readable outline, meridians and equator remain distinct from open cells.
        for x, y in ((32, 6), (6, 32), (58, 32), (20, 32), (44, 32), (32, 58)):
            self.assertGreater(alpha[y * 64 + x], 127)
        for x, y in ((25, 20), (38, 20), (25, 43), (38, 43)):
            self.assertEqual(alpha[y * 64 + x], 0)

    def test_original_globe_rebuilds_without_generated_drift(self):
        generator = module("language_icon_generator", "scripts/generate_language_icon.py")
        self.assertEqual(generator.draw(), (ROOT / "Media/Icons/Language.tga").read_bytes())

    def test_archive_contains_exact_globe_and_notice_without_national_flags(self):
        packager = module("language_icon_packager", "scripts/package.py")
        with tempfile.TemporaryDirectory() as tmp:
            path, _ = packager.package(output=Path(tmp) / "addon.zip")
            with zipfile.ZipFile(path) as archive:
                for name in ("Language.tga", "NOTICE.txt"):
                    source = ROOT / "Media/Icons" / name
                    self.assertEqual(archive.read("DungeonPro/Media/Icons/" + name), source.read_bytes())
                self.assertFalse(any("Media/Flags/" in name for name in archive.namelist()))
        self.assertFalse((ROOT / "Media/Flags").exists())
        self.assertFalse((ROOT / "scripts/generate_flags.py").exists())

    def test_missing_globe_keeps_previous_verified_archive_and_cleans_staging(self):
        packager = module("language_icon_failure_packager", "scripts/package.py")
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "addon.zip"
            packager.package(output=output)
            previous = output.read_bytes()
            real = packager.exact_path

            def missing(root, name):
                if name == "Media/Icons/Language.tga":
                    raise ValueError("Missing language icon")
                return real(root, name)

            packager.exact_path = missing
            with self.assertRaisesRegex(ValueError, "Missing language icon"):
                packager.package(output=output)
            self.assertEqual(output.read_bytes(), previous)
            self.assertEqual(list(Path(tmp).iterdir()), [output])


if __name__ == "__main__":
    unittest.main()
