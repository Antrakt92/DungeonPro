"""Verify the shared multilingual baseline and its separate redistribution notices."""
import hashlib
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / "Media/Fonts/AntraktUISans.ttf"


class FontAssetTests(unittest.TestCase):
    def test_exact_static_font_has_expected_tables_and_no_variable_axes(self):
        data = FONT.read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(), "37190dfd4749516601d23e846f7cbc20243d5791da2b1fda6b3b6a301e94a4d4")
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
        license_text = (ROOT / "Media/Fonts/NotoSans-OFL.txt").read_text(encoding="utf-8")
        notice = (ROOT / "Media/Fonts/NOTICE.txt").read_text(encoding="utf-8")
        self.assertIn("SIL OPEN FONT LICENSE Version 1.1", license_text)
        self.assertIn("Copyright 2018 The Noto Project Authors", license_text)
        self.assertIn("Copyright 2015-2021 Google LLC.", notice)
        self.assertIn("Droid Sans Fallback Legacy", notice)
        self.assertIn("modified font", notice)
        self.assertIn("Apache License 2.0", notice)
        self.assertIn("Apache License", (ROOT / "Media/Fonts/Apache-2.0.txt").read_text(encoding="utf-8"))
        for name in ("Droid-NOTICE.txt", "Droid-README.txt"):
            self.assertGreater((ROOT / "Media/Fonts" / name).stat().st_size, 100)
        self.assertIn("restrictions above do not apply to that font", (ROOT / "LICENSE").read_text(encoding="utf-8"))
        toc = (ROOT / "DungeonPro.toc").read_text(encoding="utf-8")
        self.assertNotIn("AntraktUISans.ttf", toc)

    def test_baseline_cmap_contains_representative_supported_scripts(self):
        data = FONT.read_bytes()
        tables = {tag: offset for tag, _, offset, _ in (
            struct.unpack_from(">4sIII", data, 12 + index * 16)
            for index in range(struct.unpack_from(">H", data, 4)[0]))}
        cmap = tables[b"cmap"]
        offsets = {struct.unpack_from(">HHI", data, cmap + 4 + index * 8)[2]
                   for index in range(struct.unpack_from(">H", data, cmap + 2)[0])}
        covered = set()
        wanted = {ord(char) for char in "AéЖ中體한あ"}
        for offset in offsets:
            base = cmap + offset
            if struct.unpack_from(">H", data, base)[0] != 4:
                continue
            count = struct.unpack_from(">H", data, base + 6)[0] // 2
            ends = base + 14
            starts, deltas = ends + count * 2 + 2, ends + count * 4 + 2
            ranges = ends + count * 6 + 2
            for point in wanted:
                for index in range(count):
                    start = struct.unpack_from(">H", data, starts + index * 2)[0]
                    end = struct.unpack_from(">H", data, ends + index * 2)[0]
                    if start <= point <= end:
                        delta = struct.unpack_from(">h", data, deltas + index * 2)[0]
                        distance = struct.unpack_from(">H", data, ranges + index * 2)[0]
                        glyph = ((point + delta) & 65535) if not distance else struct.unpack_from(
                            ">H", data, ranges + index * 2 + distance + (point - start) * 2)[0]
                        if glyph:
                            covered.add(point)
                        break
        self.assertEqual(covered, wanted)


if __name__ == "__main__":
    unittest.main()
