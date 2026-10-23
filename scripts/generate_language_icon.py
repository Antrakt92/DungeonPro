"""Draw the neutral language globe with Python's standard library only."""
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIZE, SAMPLES = 64, 4
COLOR = (232, 232, 220)


def draw():
    """Return an antialiased 64 x 64 RGBA TGA with a transparent background."""
    data = bytearray(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28))
    for y in range(SIZE):
        for x in range(SIZE):
            covered = 0
            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    dx = x + (sx + .5) / SAMPLES - SIZE / 2
                    dy = y + (sy + .5) / SAMPLES - SIZE / 2
                    radius = math.hypot(dx, dy)
                    outline = abs(radius - 26) <= 1.75
                    meridian = abs(math.hypot(dx / 12, dy / 26) - 1) * 12 <= 1.4
                    equator = abs(dy) <= 1.5
                    if outline or (radius <= 26 and (meridian or equator)):
                        covered += 1
            alpha = round(255 * covered / (SAMPLES * SAMPLES))
            r, g, b = COLOR if alpha else (0, 0, 0)
            data.extend((b, g, r, alpha))
    return bytes(data)


if __name__ == "__main__":
    try:
        output = ROOT / "Media/Icons/Language.tga"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(draw())
    except OSError as error:
        raise SystemExit(f"language icon output is unwritable: {error}") from error
    print("Generated neutral language globe")
