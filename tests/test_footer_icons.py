import hashlib
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class FooterIconTests(unittest.TestCase):
    def test_wowhead_texture_is_power_of_two_top_origin_uncompressed_rgba(self):
        data = (ROOT / "Media/Icons/Wowhead.tga").read_bytes()
        self.assertEqual(
            hashlib.sha256(data).hexdigest(),
            "5df37c0fa77dc0f5b1393d3961ac33fd6783776df69a1d8b962fa3c20f115346",
        )
        header = struct.unpack("<BBBHHBHHHHBB", data[:18])
        self.assertEqual(header, (0, 0, 2, 0, 0, 0, 0, 0, 64, 64, 32, 0x28))
        self.assertEqual(len(data), 18 + 64 * 64 * 4)

    def test_source_pixels_are_unchanged_at_top_left_and_padding_is_transparent(self):
        pixels = (ROOT / "Media/Icons/Wowhead.tga").read_bytes()[18:]
        rgba = bytearray()
        for y in range(64):
            for x in range(64):
                pixel = pixels[(y * 64 + x) * 4 : (y * 64 + x + 1) * 4]
                if x < 48 and y < 48:
                    blue, green, red, alpha = pixel
                    rgba.extend((red, green, blue, alpha))
                else:
                    self.assertEqual(pixel, b"\0\0\0\0")
        # Original source image RGBA pixels, independently decoded before TGA conversion.
        self.assertEqual(
            hashlib.sha256(rgba).hexdigest(),
            "57d6c65d3be9caf088f61454ca1be65238487125312ba84b478032d5f6fe64e8",
        )


if __name__ == "__main__":
    unittest.main()
