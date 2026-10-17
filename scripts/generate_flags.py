"""Draw the addon's small language flags without third-party assets or packages."""
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALES = ("enUS", "ruRU", "deDE", "frFR", "esES", "itIT", "ptBR", "koKR", "zhCN", "zhTW")
WHITE, RED, BLUE = (255, 255, 255), (213, 32, 48), (27, 60, 133)


class Canvas:
    # Draw at twice the display resolution, then antialias into power-of-two TGA.
    def __init__(self, color):
        self.pixels = [color] * (256 * 128)

    def polygon(self, points, color):
        points = [(x * 256, y * 128) for x, y in points]
        for y in range(max(0, int(min(p[1] for p in points))), min(128, math.ceil(max(p[1] for p in points)))):
            crossings = []
            for a, b in zip(points, points[1:] + points[:1]):
                if (a[1] <= y + .5 < b[1]) or (b[1] <= y + .5 < a[1]):
                    crossings.append(a[0] + (y + .5 - a[1]) * (b[0] - a[0]) / (b[1] - a[1]))
            crossings.sort()
            for left, right in zip(crossings[::2], crossings[1::2]):
                for x in range(max(0, math.ceil(left - .5)), min(256, math.ceil(right - .5))):
                    self.pixels[y * 256 + x] = color

    def rect(self, x1, y1, x2, y2, color):
        self.polygon([(x1, y1), (x2, y1), (x2, y2), (x1, y2)], color)

    def ellipse(self, x, y, rx, ry, color):
        self.polygon([(x + rx * math.cos(a * math.tau / 96), y + ry * math.sin(a * math.tau / 96)) for a in range(96)], color)

    def star(self, x, y, rx, ry, color, tips=5, rotation=-math.pi / 2, inner=.4):
        self.polygon([(x + rx * (1 if i % 2 == 0 else inner) * math.cos(rotation + math.pi * i / tips),
                       y + ry * (1 if i % 2 == 0 else inner) * math.sin(rotation + math.pi * i / tips)) for i in range(tips * 2)], color)

    def tga(self):
        result = bytearray(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, 128, 64, 32, 0x28))
        for y in range(64):
            for x in range(128):
                samples = [self.pixels[(y * 2 + dy) * 256 + x * 2 + dx] for dy in (0, 1) for dx in (0, 1)]
                r, g, b = (sum(p[k] for p in samples) // 4 for k in range(3))
                result.extend((b, g, r, 255))
        return bytes(result)


def draw(locale):
    c = Canvas(WHITE)
    gold, green = (255, 211, 44), (0, 143, 77)
    if locale == "enUS":
        for i in range(0, 13, 2):
            c.rect(0, i / 13, 1, (i + 1) / 13, (178, 34, 52))
        c.rect(0, 0, .45, 7 / 13, (60, 59, 110))
        for row in range(9):
            count = 6 if row % 2 == 0 else 5
            for col in range(count):
                c.star(.038 + col * .075 + (0 if count == 6 else .0375), .033 + row * .059, .014, .023, WHITE)
    elif locale in ("ruRU", "deDE", "esES"):
        colors = {"ruRU": (WHITE, (0, 57, 166), RED), "deDE": ((20, 20, 20), RED, gold), "esES": ((170, 21, 27), gold, (170, 21, 27))}[locale]
        edges = (0, .25, .75, 1) if locale == "esES" else (0, 1 / 3, 2 / 3, 1)
        for i, color in enumerate(colors):
            c.rect(0, edges[i], 1, edges[i + 1], color)
        if locale == "esES":
            # Simplified shield and crown remain identifiable at 24-pixel width.
            c.rect(.235, .41, .325, .61, RED)
            c.rect(.28, .41, .325, .50, WHITE)
            c.rect(.225, .37, .335, .41, gold)
            c.rect(.21, .43, .225, .61, WHITE)
            c.rect(.34, .43, .355, .61, WHITE)
    elif locale in ("frFR", "itIT"):
        c.rect(0, 0, 1 / 3, 1, BLUE if locale == "frFR" else green)
        c.rect(2 / 3, 0, 1, 1, RED)
    elif locale == "ptBR":
        c.rect(0, 0, 1, 1, (0, 156, 59))
        c.polygon([(.5, .12), (.91, .5), (.5, .88), (.09, .5)], gold)
        c.ellipse(.5, .5, .185, .275, (0, 39, 118))
        c.polygon([(.32, .39), (.41, .39), (.60, .49), (.68, .57), (.67, .63), (.57, .54), (.4, .45), (.32, .45)], WHITE)
        for x, y in ((.4, .57), (.46, .66), (.54, .65), (.59, .58), (.53, .73), (.42, .48)):
            c.star(x, y, .008, .013, WHITE)
    elif locale == "zhCN":
        c.rect(0, 0, 1, 1, (222, 41, 16))
        c.star(.16, .25, .09, .135, gold)
        for x, y in ((.31, .10), (.37, .22), (.37, .38), (.30, .48)):
            angle = math.atan2((.25 - y) * 2 / 3, .16 - x)
            c.star(x, y, .03, .045, gold, rotation=angle)
    elif locale == "zhTW":
        c.rect(0, 0, 1, 1, (254, 0, 0))
        c.rect(0, 0, .5, .5, (0, 0, 149))
        c.star(.25, .25, .116, .174, WHITE, tips=12, inner=.61)
        c.ellipse(.25, .25, .080, .12, (0, 0, 149))
        c.ellipse(.25, .25, .068, .102, WHITE)
    elif locale == "koKR":
        c.ellipse(.5, .5, .167, .25, (205, 46, 58))
        c.polygon([(.333, .5), (.667, .5), (.667, .76), (.333, .76)], WHITE)
        # Taegeuk lower half and the two opposing lobes.
        for i in range(48):
            a, b = math.pi * i / 48, math.pi * (i + 1) / 48
            c.polygon([(.5, .5), (.5 + .167 * math.cos(a), .5 + .25 * math.sin(a)), (.5 + .167 * math.cos(b), .5 + .25 * math.sin(b))], (0, 71, 160))
        c.ellipse(.417, .5, .0835, .125, (205, 46, 58))
        c.ellipse(.583, .5, .0835, .125, (0, 71, 160))
        # Geon, gon, gam and ri trigrams, rotated around the central emblem.
        for cx, cy, angle, broken in ((.25, .23, -.65, ()), (.75, .77, -.65, (0, 1, 2)), (.75, .23, .65, (0, 2)), (.25, .77, .65, (1,))):
            def point(x, y):
                return cx + x * math.cos(angle) - y * math.sin(angle) * 2 / 3, cy + x * math.sin(angle) * 1.5 + y * math.cos(angle)
            for row in range(3):
                sections = ((-.085, -.014), (.014, .085)) if row in broken else ((-.085, .085),)
                for left, right in sections:
                    top = (row - 1) * .045 - .013
                    c.polygon([point(left, top), point(right, top), point(right, top + .026), point(left, top + .026)], (16, 16, 16))
    else:
        raise ValueError(locale)
    return c.tga()


if __name__ == "__main__":
    directory = ROOT / "Media/Flags"
    directory.mkdir(parents=True, exist_ok=True)
    for locale in LOCALES:
        (directory / (locale + ".tga")).write_bytes(draw(locale))
    print("Generated 10 language flag textures")
