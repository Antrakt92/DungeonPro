"""Render actual UI anchors with offline font metrics and sample reward data."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / "Media/Fonts/NotoSans-Regular.ttf"
ANCHORS = {
    "TOPLEFT": (0, 0), "TOP": (.5, 0), "TOPRIGHT": (1, 0),
    "LEFT": (0, .5), "CENTER": (.5, .5), "RIGHT": (1, .5),
    "BOTTOMLEFT": (0, 1), "BOTTOM": (.5, 1), "BOTTOMRIGHT": (1, 1),
}


def plain(text: str) -> str:
    text = re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", text)
    return re.sub(r"\|A.*?\|a", "", re.sub(r"\|T.*?\|t", "[coin]", text))


def layout(text: str, size: float, width: float) -> tuple[list[str], float, float]:
    font = ImageFont.truetype(str(FONT), max(1, round(size)))
    lines: list[str] = []
    for paragraph in plain(text).split("\n"):
        line = ""
        for word in paragraph.split(" "):
            candidate = f"{line} {word}" if line else word
            if line and font.getlength(candidate) > max(1, width):
                lines.append(line)
                line = word
            else:
                line = candidate
        lines.append(line)
    line_height = max(1, round(size * 1.4))
    return lines, len(lines) * line_height, max((font.getlength(line) for line in lines), default=0)


def lua_quote(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\r", "\\r").replace("\n", "\\n").replace("\t", "\\t") + '"'


def capture(lua: str, quest: int, locale: str, metrics_path: Path | None = None) -> dict:
    args = [lua, "tests/detail_visual.lua", str(quest), locale]
    if metrics_path:
        args.append(str(metrics_path))
    completed = subprocess.run(args, cwd=ROOT, check=True, capture_output=True, encoding="utf-8")
    return json.loads(completed.stdout)


def render(snapshot: dict, target: Path) -> None:
    objects = {row["id"]: row for row in snapshot["objects"]}
    roles = snapshot["roles"]
    root = roles["frame"]
    rects: dict[int, tuple[float, float, float, float]] = {root: (0, 0, 1100, 700)}
    resolving: set[int] = set()

    def rect(index: int | None) -> tuple[float, float, float, float]:
        if index in rects:
            return rects[index]
        if index not in objects or index in resolving:
            return 0, 0, 1100, 700
        resolving.add(index)
        row = objects[index]
        if row.get("allPoints"):
            result = rect(row["allPoints"])
        else:
            width = row.get("width") or 0
            height = row.get("height") or (layout(row.get("text", ""), row.get("size", 14), width or 340)[1] if row.get("text") else 0)
            points = row.get("points") or []
            locations = []
            for point in points:
                x, y, rw, rh = rect(point.get("relative") or row.get("parent"))
                rx, ry = ANCHORS.get(point.get("relativeAnchor"), (0, 0))
                ax, ay = ANCHORS.get(point.get("anchor"), (0, 0))
                locations.append((x + rw * rx + point["x"], y + rh * ry - point["y"], ax, ay))
            if len(locations) > 1:
                first, last = locations[0], locations[-1]
                if not width and last[2] != first[2]:
                    width = (last[0] - first[0]) / (last[2] - first[2])
                if not height and last[3] != first[3]:
                    height = (last[1] - first[1]) / (last[3] - first[3])
            if locations:
                x, y, ax, ay = locations[0]
                result = x - width * ax, y - height * ay, width, height
            else:
                x, y, _, _ = rect(row.get("parent"))
                result = x, y, width, height
        resolving.remove(index)
        rects[index] = result
        return result

    scrolls = {roles[key] for key in ("catalogScroll", "questScroll", "detailScroll") if roles.get(key)}

    def visible_clip(index: int) -> tuple[int, int, int, int] | None:
        clip = [0, 0, 1100, 700]
        visited = set()
        while index and index not in visited:
            visited.add(index)
            row = objects[index]
            if row.get("hidden"):
                return None
            if index in scrolls:
                x, y, w, h = rect(index)
                clip = [max(clip[0], round(x)), max(clip[1], round(y)), min(clip[2], round(x+w)), min(clip[3], round(y+h))]
            if index == root:
                return tuple(clip) if clip[2] > clip[0] and clip[3] > clip[1] else None
            index = row.get("parent")
        return None

    image = Image.new("RGBA", (1100, 748), "#0b1017")
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((0, 0, 1099, 699), radius=8, fill="#0b1017", outline="#355063", width=2)
    for index in scrolls:
        x, y, w, h = rect(index)
        draw.rectangle((x, y, x+w, y+h), fill="#0e151e", outline="#263849")
    for index, row in sorted(objects.items(), key=lambda pair: bool(pair[1].get("text"))):
        clip = visible_clip(index)
        if not clip:
            continue
        x, y, w, h = rect(index)
        layer = Image.new("RGBA", image.size)
        paint = ImageDraw.Draw(layer)
        fill = row.get("fill")
        if fill and w > 0 and h > 0:
            color = tuple(round(max(0, min(1, part))*255) for part in (fill + [1])[:4])
            paint.rectangle((x, y, x+w, y+h), fill=color)
        if row.get("text"):
            size = row.get("size", 14)
            lines, _, _ = layout(row["text"], size, w or 340)
            font = ImageFont.truetype(str(FONT), round(size))
            color = tuple(round(max(0, min(1, part))*255) for part in (row.get("color") or [.86, .89, .92])[:3])
            for offset, text in enumerate(lines):
                paint.text((x, y+offset*round(size*1.4)), text, font=font, fill=color)
        elif row.get("texture") and w > 0 and h > 0 and w <= 40 and h <= 40:
            paint.rectangle((x, y, x+w, y+h), fill="#365963", outline="#789aa5")
        image.alpha_composite(layer.crop(clip), (clip[0], clip[1]))
    draw = ImageDraw.Draw(image)
    draw.text((12, 710), f"OFFLINE APPROXIMATION  |  quest {snapshot['questID']}  |  {snapshot['locale']}  |  sample narrative and rewards", font=ImageFont.truetype(str(FONT), 13), fill="#b6c4d0")
    draw.text((12, 729), "Actual Lua anchors + Pillow metrics; native rendering, icons and gameplay are unverified.", font=ImageFont.truetype(str(FONT), 12), fill="#91a1b0")
    image.convert("RGB").save(target)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", default=shutil.which("lua5.1") or shutil.which("lua5.1.exe"))
    parser.add_argument("--output", type=Path, default=ROOT / "dist/preview")
    args = parser.parse_args()
    global Image, ImageDraw, ImageFont
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        raise SystemExit("Optional preview rendering requires Pillow. Use an existing Pillow-enabled Python interpreter; no installation is performed.") from None
    if not args.lua:
        parser.error("Lua 5.1 is required; pass --lua with the existing executable")
    args.output.mkdir(parents=True, exist_ok=True)
    for quest in (4764, 4766):
        for locale in ("enUS", "ruRU"):
            snapshot = capture(args.lua, quest, locale)
            entries = []
            for key, row in snapshot["metrics"].items():
                _, height, width = layout(row["text"], row["size"], row["width"])
                entries.append(f"[{lua_quote(key)}]={{height={height},width={width}}}")
            metrics_path = args.output / f"{quest}-{locale}-metrics.lua"
            metrics_path.write_text("return {" + ",".join(entries) + "}", encoding="utf-8")
            snapshot = capture(args.lua, quest, locale, metrics_path)
            (args.output / f"{quest}-{locale}.json").write_text(json.dumps(snapshot, ensure_ascii=False, indent=2), encoding="utf-8")
            target = args.output / f"{quest}-{locale}.png"
            render(snapshot, target)
            print(target)


if __name__ == "__main__":
    main()
