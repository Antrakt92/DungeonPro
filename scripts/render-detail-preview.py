"""Render actual UI anchors with offline font metrics and sample reward data."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / "Media/Fonts/NotoSans-Regular.ttf"
# Generous per-capture bound mirroring scripts/check.py: healthy captures finish
# in seconds, so a hung tests/detail_visual.lua child fails cleanly via
# parser.error instead of hanging the preview forever.
CAPTURE_TIMEOUT_SECONDS = 600
# Fail-closed preview bounds: healthy captures use font sizes 11-27,
# widths up to 1920 and texts under 1KB, so these generous caps only reject
# hostile or corrupt snapshots before Pillow allocates a giant font.
MAX_PREVIEW_TEXT_LENGTH = 100000
MAX_PREVIEW_FONT_SIZE = 128
MAX_PREVIEW_WIDTH = 4096
MAX_PREVIEW_EXTENT = 10000
MAX_PREVIEW_OFFSET = 100000
ANCHORS = {
    "TOPLEFT": (0, 0), "TOP": (.5, 0), "TOPRIGHT": (1, 0),
    "LEFT": (0, .5), "CENTER": (.5, .5), "RIGHT": (1, .5),
    "BOTTOMLEFT": (0, 1), "BOTTOM": (.5, 1), "BOTTOMRIGHT": (1, 1),
}


def plain(text: str) -> str:
    text = re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", text)
    return re.sub(r"\|A.*?\|a", "", re.sub(r"\|T.*?\|t", "[coin]", text))


def layout(text: str, size: float, width: float) -> tuple[list[str], float, float]:
    if type(text) is not str or len(text) > MAX_PREVIEW_TEXT_LENGTH:
        raise ValueError("Invalid preview text")
    if (type(size) not in (int, float) or not math.isfinite(float(size)) or
            not 0 < float(size) <= MAX_PREVIEW_FONT_SIZE):
        raise ValueError("Invalid preview font size")
    if (type(width) not in (int, float) or not math.isfinite(float(width)) or
            not 0 < float(width) <= MAX_PREVIEW_WIDTH):
        raise ValueError("Invalid preview width")
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


def capture(lua: str, quest: int, locale: str, metrics_path: Path | None = None, catalog_collapsed: bool = False, detail_tab: str = "quest", overview: str | None = None, ready_quests: tuple[int, ...] = ()) -> dict:
    args = [lua, "tests/detail_visual.lua", "overview:" + overview if overview else str(quest), locale]
    if metrics_path:
        args.append(str(metrics_path))
    if catalog_collapsed:
        if not metrics_path:
            args.append("")
        args.append("collapsed")
    if detail_tab != "quest":
        while len(args) < 6:
            args.append("")
        args.append(detail_tab)
    if overview:
        while len(args) < 7:
            args.append("")
        args.append(",".join(map(str, ready_quests)))
    try:
        completed = subprocess.run(args, cwd=ROOT, check=True, capture_output=True,
                                   encoding="utf-8", timeout=CAPTURE_TIMEOUT_SECONDS)
    except (UnicodeDecodeError, ValueError) as error:
        raise ValueError("Invalid preview snapshot from Lua capture") from error
    try:
        return json.loads(completed.stdout)
    except (json.JSONDecodeError, UnicodeDecodeError, ValueError) as error:
        raise ValueError("Invalid preview snapshot from Lua capture") from error


def capture_error_detail(error) -> str:
    if isinstance(error, subprocess.TimeoutExpired):
        return f"Lua capture timed out after {CAPTURE_TIMEOUT_SECONDS}s: {list(error.cmd or [])!r}"
    detail = (getattr(error, "stderr", None) or "").strip()
    return detail or str(error)


def _preview_number(value, *, minimum, maximum) -> bool:
    return (type(value) in (int, float) and math.isfinite(float(value)) and
            minimum <= float(value) <= maximum)


def _preview_rgba(parts) -> tuple[int, ...]:
    if (type(parts) is not list or not 1 <= len(parts) <= 4 or
            any(type(part) not in (int, float) or not math.isfinite(float(part)) for part in parts)):
        raise ValueError("Invalid preview color")
    return tuple(round(max(0, min(1, float(part))) * 255) for part in (parts + [1] * 4)[:4])


def render(snapshot: dict, target: Path) -> None:
    if (type(snapshot) is not dict or type(snapshot.get("objects")) is not list or
            type(snapshot.get("roles")) is not dict):
        raise ValueError("Invalid preview snapshot")
    roles = snapshot["roles"]
    root = roles.get("frame")
    if type(root) is not int:
        raise ValueError("Invalid preview frame role")
    locale = snapshot.get("locale")
    if type(locale) is not str or not locale:
        raise ValueError("Invalid preview locale")
    if snapshot.get("mode") == "overview":
        dungeon_key = snapshot.get("dungeonKey")
        if type(dungeon_key) is not str or not dungeon_key:
            raise ValueError("Invalid preview dungeon key")
        quest_id = None
    else:
        dungeon_key = None
        quest_id = snapshot.get("questID")
        if type(quest_id) is not int or not 0 < quest_id <= 4294967295:
            raise ValueError("Invalid preview quest identity")
    objects: dict[int, dict] = {}
    for row in snapshot["objects"]:
        if type(row) is not dict or type(row.get("id")) is not int:
            raise ValueError("Invalid preview object")
        objects[row["id"]] = row
    if root not in objects:
        raise ValueError("Invalid preview frame role")
    for key in ("catalogScroll", "questScroll", "detailScroll"):
        scroll = roles.get(key)
        if scroll is not None and type(scroll) is not int:
            raise ValueError("Invalid preview scroll role")
    for row in objects.values():
        raw_width = row.get("width")
        if raw_width is not None and not _preview_number(raw_width, minimum=0, maximum=MAX_PREVIEW_WIDTH):
            raise ValueError("Invalid preview object width")
        raw_height = row.get("height")
        if raw_height is not None and not _preview_number(raw_height, minimum=0, maximum=MAX_PREVIEW_EXTENT):
            raise ValueError("Invalid preview object height")
        text = row.get("text")
        if text is not None and (type(text) is not str or len(text) > MAX_PREVIEW_TEXT_LENGTH):
            raise ValueError("Invalid preview text")
        size = row.get("size")
        if size is not None and (type(size) not in (int, float) or not math.isfinite(float(size)) or
                                 not 0 < float(size) <= MAX_PREVIEW_FONT_SIZE):
            raise ValueError("Invalid preview font size")
        fill = row.get("fill")
        if fill:
            _preview_rgba(fill)
        raw_color = row.get("color")
        if raw_color:
            _preview_rgba(raw_color[:3] if type(raw_color) is list else raw_color)
        for link_field in ("parent", "allPoints"):
            link = row.get(link_field)
            if link is not None and type(link) is not int:
                raise ValueError("Invalid preview object link")
        points = row.get("points")
        if points:
            if type(points) is not list:
                raise ValueError("Invalid preview anchors")
            for point in points:
                if type(point) is not dict:
                    raise ValueError("Invalid preview anchor")
                if (not _preview_number(point.get("x"), minimum=-MAX_PREVIEW_OFFSET, maximum=MAX_PREVIEW_OFFSET) or
                        not _preview_number(point.get("y"), minimum=-MAX_PREVIEW_OFFSET, maximum=MAX_PREVIEW_OFFSET)):
                    raise ValueError("Invalid preview anchor offset")
                relative = point.get("relative")
                if relative is not None and type(relative) is not int:
                    raise ValueError("Invalid preview object link")
    rects: dict[int, tuple[float, float, float, float]] = {root: (0, 0, 1100, 700)}
    resolving: set[int] = set()

    def rect(index: int | None) -> tuple[float, float, float, float]:
        if index is None:
            return 0, 0, 1100, 700
        if type(index) is not int:
            raise ValueError("Invalid preview object link")
        if index in rects:
            return rects[index]
        if index not in objects or index in resolving:
            return 0, 0, 1100, 700
        resolving.add(index)
        row = objects[index]
        link = row.get("allPoints")
        if link is not None and type(link) is not int:
            raise ValueError("Invalid preview object link")
        if link:
            result = rect(link)
        else:
            raw_width = row.get("width")
            if raw_width is None:
                width = 0
            elif _preview_number(raw_width, minimum=0, maximum=MAX_PREVIEW_WIDTH):
                width = raw_width
            else:
                raise ValueError("Invalid preview object width")
            raw_height = row.get("height")
            if raw_height is None:
                height = 0
            elif _preview_number(raw_height, minimum=0, maximum=MAX_PREVIEW_EXTENT):
                height = raw_height
            else:
                raise ValueError("Invalid preview object height")
            if not height:
                text = row.get("text")
                if text:
                    height = layout(text, row.get("size", 14), width or 340)[1]
                else:
                    height = 0
            points = row.get("points")
            if not points:
                points = []
            elif type(points) is not list:
                raise ValueError("Invalid preview anchors")
            locations = []
            for point in points:
                if type(point) is not dict:
                    raise ValueError("Invalid preview anchor")
                offset_x = point.get("x")
                offset_y = point.get("y")
                if (not _preview_number(offset_x, minimum=-MAX_PREVIEW_OFFSET, maximum=MAX_PREVIEW_OFFSET) or
                        not _preview_number(offset_y, minimum=-MAX_PREVIEW_OFFSET, maximum=MAX_PREVIEW_OFFSET)):
                    raise ValueError("Invalid preview anchor offset")
                relative = point.get("relative")
                if relative is not None and type(relative) is not int:
                    raise ValueError("Invalid preview object link")
                parent = row.get("parent")
                if parent is not None and type(parent) is not int:
                    raise ValueError("Invalid preview object link")
                x, y, rw, rh = rect(relative or parent)
                rx, ry = ANCHORS.get(point.get("relativeAnchor"), (0, 0))
                ax, ay = ANCHORS.get(point.get("anchor"), (0, 0))
                locations.append((x + rw * rx + offset_x, y + rh * ry - offset_y, ax, ay))
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
        while index:
            if type(index) is not int:
                raise ValueError("Invalid preview object link")
            if index in visited:
                return None
            if index not in objects:
                raise ValueError("Invalid preview hierarchy")
            visited.add(index)
            row = objects[index]
            if row.get("hidden"):
                return None
            if index in scrolls:
                x, y, w, h = rect(index)
                clip = [max(clip[0], round(x)), max(clip[1], round(y)), min(clip[2], round(x+w)), min(clip[3], round(y+h))]
            if index == root:
                return tuple(clip) if clip[2] > clip[0] and clip[3] > clip[1] else None
            parent = row.get("parent")
            if parent is not None and type(parent) is not int:
                raise ValueError("Invalid preview object link")
            index = parent
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
            paint.rectangle((x, y, x+w, y+h), fill=_preview_rgba(fill))
        if row.get("text"):
            size = row.get("size", 14)
            lines, _, _ = layout(row.get("text"), size, w or 340)
            font = ImageFont.truetype(str(FONT), round(size))
            raw_color = row.get("color") or [.86, .89, .92]
            color = _preview_rgba(raw_color[:3] if type(raw_color) is list else raw_color)[:3]
            for offset, text in enumerate(lines):
                paint.text((x, y+offset*round(size*1.4)), text, font=font, fill=color)
        elif row.get("texture") and w > 0 and h > 0 and w <= 40 and h <= 40:
            paint.rectangle((x, y, x+w, y+h), fill="#365963", outline="#789aa5")
        image.alpha_composite(layer.crop(clip), (clip[0], clip[1]))
    draw = ImageDraw.Draw(image)
    subject = (f"overview {dungeon_key}  |  {locale}  |  actual catalogue, simulated held quest log"
               if snapshot.get("mode") == "overview" else f"quest {quest_id}  |  {locale}  |  sample narrative and rewards")
    draw.text((12, 710), "OFFLINE APPROXIMATION  |  " + subject, font=ImageFont.truetype(str(FONT), 13), fill="#b6c4d0")
    limits = ("Actual Lua anchors + Pillow metrics; artwork unrendered; native fonts, scale, icons and gameplay unverified."
              if snapshot.get("mode") == "overview" else "Actual Lua anchors + Pillow metrics; native rendering, icons and gameplay are unverified.")
    draw.text((12, 729), limits, font=ImageFont.truetype(str(FONT), 12), fill="#91a1b0")
    image.convert("RGB").save(target)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", default=shutil.which("lua5.1") or shutil.which("lua5.1.exe"))
    parser.add_argument("--output", type=Path, default=ROOT / "dist/preview")
    parser.add_argument("--catalog-collapsed", action="store_true", help="Capture the wider quest list with the dungeon catalogue hidden")
    parser.add_argument("--detail-tab", choices=("quest", "sources", "story"), default=None, help="Capture one contextual quest-detail view")
    parser.add_argument("--quest", type=int, action="append", help="Quest ID to capture; repeat for multiple quests (default: 4764 and 4766)")
    parser.add_argument("--overview", metavar="DUNGEON_KEY", help="Capture actual dungeon progress with a simulated held quest log")
    parser.add_argument("--ready-quest", type=int, action="append", default=[], help="Known quest ID simulated as held and ready; overview mode only")
    args = parser.parse_args()
    if args.overview is not None and not args.overview:
        parser.error("--overview requires a nonblank known dungeon key")
    if args.overview and (args.quest or args.detail_tab is not None):
        parser.error("--overview cannot be combined with --quest or --detail-tab")
    if args.ready_quest and not args.overview:
        parser.error("--ready-quest requires --overview")
    if any(q <= 0 or q > 4294967295 for q in args.ready_quest):
        parser.error("--ready-quest IDs must be positive uint32 values")
    if args.quest and any(q <= 0 or q > 4294967295 for q in args.quest):
        parser.error("--quest IDs must be positive uint32 values")
    args.ready_quest = list(dict.fromkeys(args.ready_quest))
    if args.quest:
        args.quest = list(dict.fromkeys(args.quest))
    if not args.lua:
        parser.error("Lua 5.1 is required; pass --lua with the existing executable")
    first_overview = None
    if args.overview:
        try:
            first_overview = capture(args.lua, 0, "enUS", catalog_collapsed=args.catalog_collapsed,
                                     overview=args.overview, ready_quests=tuple(args.ready_quest))
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError) as error:
            parser.error(capture_error_detail(error))

    global Image, ImageDraw, ImageFont
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        raise SystemExit("Optional preview rendering requires Pillow. Use an existing Pillow-enabled Python interpreter; no installation is performed.") from None
    args.output.mkdir(parents=True, exist_ok=True)
    for quest in ([0] if args.overview else args.quest or (4764, 4766)):
        stem = "overview-" + args.overview if args.overview else str(quest)
        for locale in ("enUS", "ruRU"):
            try:
                snapshot = first_overview if args.overview and locale == "enUS" else capture(args.lua, quest, locale, catalog_collapsed=args.catalog_collapsed, detail_tab=args.detail_tab or "quest", overview=args.overview, ready_quests=tuple(args.ready_quest))
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError) as error:
                parser.error(capture_error_detail(error))
            metrics = snapshot.get("metrics")
            if type(metrics) is not dict:
                parser.error("Invalid preview metrics from Lua capture")
            entries = []
            for key, row in metrics.items():
                if type(key) is not str or type(row) is not dict:
                    parser.error("Invalid preview metrics from Lua capture")
                try:
                    _, height, width = layout(row.get("text"), row.get("size"), row.get("width"))
                except ValueError as error:
                    parser.error(str(error))
                entries.append(f"[{lua_quote(key)}]={{height={height},width={width}}}")
            metrics_path = args.output / f"{stem}-{locale}-metrics.lua"
            metrics_path.write_text("return {" + ",".join(entries) + "}", encoding="utf-8")
            try:
                snapshot = capture(args.lua, quest, locale, metrics_path, catalog_collapsed=args.catalog_collapsed, detail_tab=args.detail_tab or "quest", overview=args.overview, ready_quests=tuple(args.ready_quest))
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError) as error:
                parser.error(capture_error_detail(error))
            (args.output / f"{stem}-{locale}.json").write_text(json.dumps(snapshot, ensure_ascii=False, indent=2), encoding="utf-8")
            target = args.output / f"{stem}-{locale}.png"
            try:
                render(snapshot, target)
            except ValueError as error:
                parser.error(str(error))
            print(target)


if __name__ == "__main__":
    main()
