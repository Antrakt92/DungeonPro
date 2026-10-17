"""Verify the exact unmodified static font and its separate redistribution notices."""
import hashlib
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / "Media/Fonts/NotoSans-Regular.ttf"


class FontAssetTests(unittest.TestCase):
    def test_exact_static_font_has_expected_tables_and_no_variable_axes(self):
        data = FONT.read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(), "b85c38ecea8a7cfb39c24e395a4007474fa5a4fc864f6ee33309eb4948d232d5")
        self.assertEqual(data[:4], b"\x00\x01\x00\x00")
        tables = {}
        for index in range(struct.unpack_from(">H", data, 4)[0]):
            tag, _, offset, length = struct.unpack_from(">4sIII", data, 12 + index * 16)
            self.assertLessEqual(offset + length, len(data))
            tables[tag] = (offset, length)
        self.assertNotIn(b"fvar", tables)
        for tag in (b"glyf", b"loca", b"cmap", b"name", b"head", b"fpgm", b"prep", b"cvt "):
            self.assertIn(tag, tables)

    def test_font_license_and_copyright_remain_separate_from_project_restrictions(self):
        license_text = (ROOT / "Media/Fonts/OFL.txt").read_text(encoding="utf-8")
        notice = (ROOT / "Media/Fonts/NOTICE.txt").read_text(encoding="utf-8")
        self.assertIn("SIL OPEN FONT LICENSE Version 1.1", license_text)
        self.assertIn("Copyright 2018 The Noto Project Authors", license_text)
        self.assertIn("Copyright 2015-2021 Google LLC.", notice)
        self.assertIn("ffebf8c1ee449e544955a7e813c54f9b73848eac", notice)
        self.assertIn("restrictions above do not apply to that font", (ROOT / "LICENSE").read_text(encoding="utf-8"))
        toc = (ROOT / "DungeonPro.toc").read_text(encoding="utf-8")
        self.assertNotIn("NotoSans-Regular.ttf", toc)


if __name__ == "__main__":
    unittest.main()
