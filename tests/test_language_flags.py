"""Check shipped language textures and their installable resource boundary."""
import importlib.util
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALES = ("enUS", "ruRU", "deDE", "frFR", "esES", "itIT", "ptBR", "koKR", "zhCN", "zhTW")


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class LanguageFlagsTests(unittest.TestCase):
    def test_all_ten_flags_are_distinct_client_readable_rgba_textures(self):
        textures = set()
        for locale in LOCALES:
            data = (ROOT / "Media/Flags" / (locale + ".tga")).read_bytes()
            self.assertEqual(struct.unpack("<BBBHHBHHHHBB", data[:18]),
                             (0, 0, 2, 0, 0, 0, 0, 0, 128, 64, 32, 0x28))
            self.assertEqual(len(data), 18 + 128 * 64 * 4)
            self.assertEqual(set(data[21::4]), {255})
            textures.add(data)
        self.assertEqual(len(textures), 10)

    def test_original_artwork_rebuilds_without_generated_drift(self):
        generator = module("flag_generator", "scripts/generate_flags.py")
        for locale in LOCALES:
            self.assertEqual(generator.draw(locale), (ROOT / "Media/Flags" / (locale + ".tga")).read_bytes())

    def test_horizontal_and_vertical_tricolours_keep_their_orientation(self):
        def pixel(locale, x, y):
            data = (ROOT / "Media/Flags" / (locale + ".tga")).read_bytes()
            start = 18 + (y * 128 + x) * 4
            b, g, r, a = data[start:start + 4]
            return r, g, b
        self.assertEqual(pixel("ruRU", 64, 5), (255, 255, 255))
        self.assertEqual(pixel("ruRU", 64, 32), (0, 57, 166))
        self.assertEqual(pixel("deDE", 64, 5), (20, 20, 20))
        self.assertEqual(pixel("frFR", 5, 32), (27, 60, 133))
        self.assertEqual(pixel("frFR", 64, 32), (255, 255, 255))
        self.assertEqual(pixel("itIT", 5, 32), (0, 143, 77))

    def test_archive_contains_each_texture_and_notice_as_exact_source_bytes(self):
        packager = module("flag_packager", "scripts/package.py")
        with tempfile.TemporaryDirectory() as tmp:
            path, _ = packager.package(output=Path(tmp) / "addon.zip")
            with zipfile.ZipFile(path) as archive:
                for name in [locale + ".tga" for locale in LOCALES] + ["NOTICE.txt"]:
                    source = ROOT / "Media/Flags" / name
                    self.assertEqual(archive.read("DungeonPro/Media/Flags/" + name), source.read_bytes())

    def test_missing_flag_keeps_previous_verified_archive(self):
        packager = module("flag_failure_packager", "scripts/package.py")
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "addon.zip"
            packager.package(output=output)
            previous = output.read_bytes()
            real = packager.exact_path
            def missing(root, name):
                if name == "Media/Flags/zhTW.tga":
                    raise ValueError("Missing flag")
                return real(root, name)
            packager.exact_path = missing
            with self.assertRaisesRegex(ValueError, "Missing flag"):
                packager.package(output=output)
            self.assertEqual(output.read_bytes(), previous)


if __name__ == "__main__":
    unittest.main()
