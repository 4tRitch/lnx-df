#!/usr/bin/env python3
from __future__ import annotations

import argparse
import fcntl
import json
import math
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
gi.require_version("GtkLayerShell", "0.1")

from gi.repository import Gio, Gdk, GdkPixbuf, GLib, Gtk, GtkLayerShell, Pango  # noqa: E402


MAX_CLIPBOARD_ITEMS = 20
MAX_EMOJI_VISIBLE = 2400
MAX_IMAGE_PREVIEWS = 36
MAX_COMPATIBLE_VARIANT_EMOJI_VERSION = 16.0
IMAGE_PREVIEW_WIDTH = 112
IMAGE_PREVIEW_HEIGHT = 63
SCRIPT_DIR = Path(__file__).resolve().parent
EMOJI_DATA_FILE = SCRIPT_DIR.parent / "data" / "emoji-test.txt"
APP_LOCK = None
CLIPBOARD_IMAGE_RE = re.compile(
    r"\[\[\s*binary data\s+(?P<size>.+?)\s+"
    r"(?P<format>png|jpg|jpeg|webp|bmp|gif)\s+"
    r"(?P<dimensions>\d+x\d+)",
    re.IGNORECASE,
)
CSS = """
window {
  background-color: transparent;
}

.background-hit-area {
  background-color: rgba(0, 0, 0, 0.01);
}

.picker-panel {
  min-width: 760px;
  min-height: 540px;
  padding: 18px;
  border-radius: 28px;
  border: 1px solid rgba(255, 255, 255, 0.18);
  background-color: rgba(20, 20, 20, 0.28);
  box-shadow: inset 0 1px rgba(255, 255, 255, 0.12);
  color: rgba(255, 255, 255, 0.92);
}

.picker-panel.clipboard-panel {
  min-height: 500px;
}

.search-entry {
  min-height: 42px;
  padding: 0 16px;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.18);
  background-color: rgba(20, 20, 20, 0.28);
  color: rgba(255, 255, 255, 0.92);
  font-family: "Inter", sans-serif;
  font-size: 14px;
  box-shadow: inset 0 1px rgba(255, 255, 255, 0.10);
}

.search-entry:focus {
  border-color: rgba(255, 255, 255, 0.32);
  background-color: rgba(20, 20, 20, 0.34);
}

.content-frame {
  margin-top: 12px;
  border-radius: 24px;
  border: 1px solid rgba(255, 255, 255, 0.13);
  background-color: rgba(20, 20, 20, 0.20);
}

.content-frame.clipboard-frame {
  margin-top: 0;
}

.content-scroller,
.content-scroller viewport,
.clipboard-list,
.emoji-flow,
.emoji-shell {
  background-color: transparent;
}

.clipboard-list {
  padding-right: 14px;
  padding-bottom: 14px;
}

.clipboard-scroller {
  margin-top: 0;
}

.clipboard-row {
  margin: 5px 6px;
  padding: 10px 12px;
  border-radius: 18px;
  border: 1px solid transparent;
  background-color: transparent;
  transition: none;
}

.clipboard-row:hover {
  border-color: rgba(255, 255, 255, 0.24);
  background-color: rgba(255, 255, 255, 0.12);
}

.clipboard-row:selected {
  border-color: rgba(255, 255, 255, 0.16);
  background-color: rgba(255, 255, 255, 0.08);
}

.clipboard-preview {
  min-width: 112px;
  min-height: 63px;
  border-radius: 16px;
}

.clipboard-primary {
  color: rgba(255, 255, 255, 0.92);
  font-family: "Inter", sans-serif;
  font-size: 14px;
  font-weight: 700;
}

.clipboard-secondary {
  color: rgba(255, 255, 255, 0.60);
  font-family: "Inter", sans-serif;
  font-size: 12px;
  font-weight: 600;
}

.clipboard-delete-button {
  min-width: 38px;
  min-height: 38px;
  margin-left: 8px;
  padding: 0;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.12);
  background-color: rgba(255, 255, 255, 0.06);
  color: rgba(255, 255, 255, 0.78);
  font-size: 16px;
  font-weight: 800;
  box-shadow: none;
}

.clipboard-delete-button:hover,
.clipboard-delete-button:focus {
  border-color: rgba(255, 255, 255, 0.26);
  background-color: rgba(255, 255, 255, 0.14);
  color: rgba(255, 255, 255, 0.95);
}

.empty-label {
  color: rgba(255, 255, 255, 0.60);
  font-family: "Inter", sans-serif;
  font-size: 15px;
  font-weight: 700;
}

.emoji-button {
  min-width: 56px;
  min-height: 52px;
  margin: 4px;
  padding: 0;
  border-radius: 18px;
  border: 1px solid transparent;
  background-color: rgba(20, 20, 20, 0.24);
  color: rgba(255, 255, 255, 0.92);
  font-family: "Noto Color Emoji", "Apple Color Emoji", "Segoe UI Emoji", sans-serif;
  font-size: 28px;
  box-shadow: none;
}

.emoji-glyph {
  color: rgba(255, 255, 255, 0.92);
  font-family: "Noto Color Emoji", "Apple Color Emoji", "Segoe UI Emoji", sans-serif;
  font-size: 28px;
}

.emoji-variant-dot {
  min-width: 7px;
  min-height: 7px;
  margin-right: 9px;
  margin-bottom: 7px;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.56);
  background-color: rgba(130, 180, 255, 0.90);
}

.emoji-button:hover,
.emoji-button:focus {
  border-color: rgba(255, 255, 255, 0.28);
  background-color: rgba(255, 255, 255, 0.16);
}

scrollbar {
  background-color: transparent;
  border: none;
  box-shadow: none;
  opacity: 0;
  min-width: 0;
  min-height: 0;
}

scrollbar trough,
scrollbar contents {
  background-color: transparent;
  border: none;
  box-shadow: none;
}

scrollbar slider {
  min-width: 0;
  min-height: 0;
  border-radius: 999px;
  background-color: transparent;
  border: none;
  box-shadow: none;
}

.category-bar {
  margin: 10px 52px 0 52px;
  padding: 6px;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.16);
  background-color: rgba(255, 255, 255, 0.08);
  box-shadow:
    inset 0 1px rgba(255, 255, 255, 0.16),
    0 18px 36px rgba(0, 0, 0, 0.24);
}

.category-button {
  min-width: 42px;
  min-height: 38px;
  padding: 0 8px;
  border-radius: 999px;
  border: 1px solid transparent;
  background-color: transparent;
  color: rgba(255, 255, 255, 0.78);
  font-family: "Noto Color Emoji", "Apple Color Emoji", "Segoe UI Emoji", sans-serif;
  font-size: 18px;
  box-shadow: none;
}

.category-button:hover,
.category-button.selected-category {
  border-color: rgba(255, 255, 255, 0.20);
  background-color: rgba(255, 255, 255, 0.15);
  color: rgba(255, 255, 255, 0.96);
}

.category-button:disabled {
  opacity: 0.30;
  color: rgba(255, 255, 255, 0.34);
}

popover.variant-popover {
  border-radius: 22px;
  border: 1px solid rgba(255, 255, 255, 0.18);
  background-color: rgba(20, 20, 20, 0.86);
  box-shadow: 0 18px 42px rgba(0, 0, 0, 0.42);
}

.variant-box {
  padding: 10px;
  border-radius: 20px;
  background-color: rgba(20, 20, 20, 0.86);
}

.variant-flow {
  background-color: transparent;
}

.variant-button {
  min-width: 54px;
  min-height: 50px;
  margin: 2px;
  padding: 0;
  border-radius: 16px;
  border: 1px solid transparent;
  background-color: rgba(255, 255, 255, 0.07);
  color: rgba(255, 255, 255, 0.94);
  font-family: "Noto Color Emoji", "Apple Color Emoji", "Segoe UI Emoji", sans-serif;
  font-size: 28px;
}

.variant-button:hover,
.variant-button:focus {
  border-color: rgba(255, 255, 255, 0.30);
  background-color: rgba(255, 255, 255, 0.16);
}
"""


@dataclass(frozen=True)
class ClipboardItem:
    raw: str
    preview: str
    search_text: str
    is_image: bool
    image_meta: str


@dataclass(frozen=True)
class EmojiItem:
    value: str
    name: str
    search_text: str
    group: str = ""
    subgroup: str = ""
    emoji_version: float = 0.0
    variants: tuple["EmojiVariant", ...] = ()


@dataclass(frozen=True)
class EmojiVariant:
    value: str
    name: str
    emoji_version: float = 0.0


def run_capture(command: list[str], *, input_bytes: bytes | None = None) -> bytes:
    completed = subprocess.run(
        command,
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if completed.returncode != 0:
        return b""
    return completed.stdout


def copy_bytes_to_clipboard(data: bytes) -> bool:
    completed = subprocess.run(
        ["wl-copy"],
        input=data,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return completed.returncode == 0


def copy_text_to_clipboard(text: str) -> bool:
    return copy_bytes_to_clipboard(text.encode("utf-8"))


def target_window_selector() -> str:
    output = run_capture(["hyprctl", "activewindow", "-j"])
    if not output:
        return ""
    try:
        window = json.loads(output.decode("utf-8", errors="replace"))
    except json.JSONDecodeError:
        return ""

    address = window.get("address")
    if not isinstance(address, str) or not address:
        return ""
    return f"address:{address}"


def paste_to_window(selector: str) -> bool:
    if not selector:
        return False

    subprocess.run(
        ["hyprctl", "dispatch", "focuswindow", selector],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    time.sleep(0.04)
    completed = subprocess.run(
        ["hyprctl", "dispatch", "sendshortcut", f"CTRL,V,{selector}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return completed.returncode == 0


def acquire_app_lock(mode: str):
    runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
    lock_path = runtime_dir / f"lnx-df-{mode}-picker.lock"
    lock_file = lock_path.open("w", encoding="utf-8")
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        lock_file.close()
        return None

    lock_file.seek(0)
    lock_file.truncate()
    lock_file.write(f"{os.getpid()}\n")
    lock_file.flush()
    return lock_file


def display_size() -> tuple[int, int]:
    display = Gdk.Display.get_default()
    if display is not None:
        monitor = display.get_primary_monitor()
        if monitor is None:
            monitor = display.get_monitor_at_point(0, 0)
        if monitor is None and display.get_n_monitors() > 0:
            monitor = display.get_monitor(0)
        if monitor is not None:
            geometry = monitor.get_geometry()
            return geometry.width, geometry.height

    screen = Gdk.Screen.get_default()
    if screen is not None:
        return screen.width(), screen.height()

    return 1920, 1080


def shorten(text: str, limit: int) -> str:
    clean = " ".join(text.replace("\x00", "").split())
    if len(clean) <= limit:
        return clean
    return f"{clean[: limit - 1].rstrip()}…"


def load_clipboard_items() -> list[ClipboardItem]:
    output = run_capture(["cliphist", "list"]).decode("utf-8", errors="replace")
    items: list[ClipboardItem] = []
    lines = [line for line in output.splitlines() if line.strip()]

    if len(lines) > MAX_CLIPBOARD_ITEMS:
        subprocess.run(
            ["cliphist", "delete"],
            input=("\n".join(lines[MAX_CLIPBOARD_ITEMS:]) + "\n").encode("utf-8"),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )

    for line in lines[:MAX_CLIPBOARD_ITEMS]:
        _, _, preview = line.partition("\t")
        image_match = CLIPBOARD_IMAGE_RE.search(preview)
        is_image = image_match is not None
        if image_match is not None:
            image_meta = (
                f"{image_match.group('format').upper()} · "
                f"{image_match.group('dimensions')} · "
                f"{image_match.group('size').strip()}"
            )
            label = "Image"
        else:
            image_meta = ""
            label = shorten(preview, 180)

        search_text = f"{preview} {image_meta}".casefold()
        items.append(
            ClipboardItem(
                raw=line,
                preview=label,
                search_text=search_text,
                is_image=is_image,
                image_meta=image_meta,
            ),
        )

    return items


@lru_cache(maxsize=80)
def load_image_preview(raw: str) -> GdkPixbuf.Pixbuf | None:
    decoded = run_capture(["cliphist", "decode"], input_bytes=f"{raw}\n".encode("utf-8"))
    if not decoded:
        return None

    loader = GdkPixbuf.PixbufLoader()
    try:
        loader.write(decoded)
        loader.close()
    except GLib.Error:
        return None

    pixbuf = loader.get_pixbuf()
    if pixbuf is None:
        return None

    width = pixbuf.get_width()
    height = pixbuf.get_height()
    if width <= 0 or height <= 0:
        return None

    scale = max(IMAGE_PREVIEW_WIDTH / width, IMAGE_PREVIEW_HEIGHT / height)
    scaled_width = max(IMAGE_PREVIEW_WIDTH, math.ceil(width * scale))
    scaled_height = max(IMAGE_PREVIEW_HEIGHT, math.ceil(height * scale))
    scaled = pixbuf.scale_simple(scaled_width, scaled_height, GdkPixbuf.InterpType.BILINEAR)
    if scaled is None:
        return None

    crop_x = max(0, (scaled_width - IMAGE_PREVIEW_WIDTH) // 2)
    crop_y = max(0, (scaled_height - IMAGE_PREVIEW_HEIGHT) // 2)
    return GdkPixbuf.Pixbuf.new_subpixbuf(
        scaled,
        crop_x,
        crop_y,
        IMAGE_PREVIEW_WIDTH,
        IMAGE_PREVIEW_HEIGHT,
    ).copy()


def decode_clipboard_item(item: ClipboardItem) -> bytes:
    return run_capture(["cliphist", "decode"], input_bytes=f"{item.raw}\n".encode("utf-8"))


def delete_clipboard_item(item: ClipboardItem) -> bool:
    completed = subprocess.run(
        ["cliphist", "delete"],
        input=f"{item.raw}\n".encode("utf-8"),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return completed.returncode == 0


class ImagePreview(Gtk.DrawingArea):
    def __init__(self) -> None:
        super().__init__()
        self.pixbuf: GdkPixbuf.Pixbuf | None = None
        self.set_size_request(IMAGE_PREVIEW_WIDTH, IMAGE_PREVIEW_HEIGHT)
        self.get_style_context().add_class("clipboard-preview")
        self.connect("draw", self.on_draw)

    def set_pixbuf(self, pixbuf: GdkPixbuf.Pixbuf) -> None:
        self.pixbuf = pixbuf
        self.queue_draw()

    def on_draw(self, _widget: Gtk.Widget, cr) -> bool:
        width = self.get_allocated_width()
        height = self.get_allocated_height()
        radius = 14

        cr.new_path()
        cr.arc(width - radius, radius, radius, -math.pi / 2, 0)
        cr.arc(width - radius, height - radius, radius, 0, math.pi / 2)
        cr.arc(radius, height - radius, radius, math.pi / 2, math.pi)
        cr.arc(radius, radius, radius, math.pi, 3 * math.pi / 2)
        cr.close_path()

        cr.set_source_rgba(0.08, 0.08, 0.08, 0.38)
        cr.fill_preserve()

        cr.save()
        cr.clip()
        if self.pixbuf is not None:
            x = max(0, (width - self.pixbuf.get_width()) // 2)
            y = max(0, (height - self.pixbuf.get_height()) // 2)
            Gdk.cairo_set_source_pixbuf(cr, self.pixbuf, x, y)
            cr.paint()
        cr.restore()

        cr.new_path()
        cr.arc(width - radius, radius, radius, -math.pi / 2, 0)
        cr.arc(width - radius, height - radius, radius, 0, math.pi / 2)
        cr.arc(radius, height - radius, radius, math.pi / 2, math.pi)
        cr.arc(radius, radius, radius, math.pi, 3 * math.pi / 2)
        cr.close_path()
        cr.set_line_width(1.2)
        cr.set_source_rgba(0.86, 0.88, 0.90, 0.34)
        cr.stroke()

        return False


SKIN_TONE_NAME_RE = re.compile(
    r"(?:: |, )(light|medium-light|medium|medium-dark|dark) skin tone",
    re.IGNORECASE,
)
HAND_GESTURE_NAME_RE = re.compile(
    r"(^|[\s-])(hands?|handshake|thumbs?|fingers?|fist|palm|clapping|clap|gesture|salute|pinched|pinching)([\s-]|$)",
    re.IGNORECASE,
)
EMOJI_CATEGORY_ICONS = {
    "Smileys & Emotion": "😀",
    "People & Body": "👋",
    "Animals & Nature": "🐻",
    "Food & Drink": "🍔",
    "Travel & Places": "✈️",
    "Activities": "⚽",
    "Objects": "💡",
    "Symbols": "❤️",
    "Flags": "🏳️",
}


def emoji_search_aliases(name: str, group: str, subgroup: str) -> str:
    lowered_name = name.casefold()
    aliases: list[str] = []

    if any(word in lowered_name for word in ("grinning", "smiling", "smile", "laugh", "joy", "beaming")):
        aliases.extend(["happy", "feliz", "alegria", "alegría", "smile", "sonrisa"])
    if any(word in lowered_name for word in ("cry", "tear", "sad", "frown", "disappointed")):
        aliases.extend(["sad", "triste", "llorar", "cry"])
    if "heart" in lowered_name:
        aliases.extend(["love", "amor", "corazon", "corazón"])
    if any(word in lowered_name for word in ("angry", "rage", "pouting")):
        aliases.extend(["angry", "enojado", "enojo"])
    if any(word in lowered_name for word in ("thumbs up", "+1", "ok hand", "check mark")):
        aliases.extend(["ok", "yes", "si", "sí", "bien"])
    if any(word in lowered_name for word in ("thumbs down", "cross mark")):
        aliases.extend(["no", "bad", "mal"])
    if "fire" in lowered_name:
        aliases.extend(["lit", "fuego"])
    if "party" in lowered_name:
        aliases.extend(["celebrate", "fiesta"])
    if "face" in lowered_name:
        aliases.append("cara")
    if "cat" in lowered_name:
        aliases.append("gato")
    if "dog" in lowered_name:
        aliases.append("perro")
    if "flag" in lowered_name:
        aliases.append("bandera")

    return " ".join(aliases)


def parse_emoji_version(version: str) -> float:
    try:
        return float(version.removeprefix("E"))
    except ValueError:
        return 0.0


def emoji_base_name(name: str) -> str:
    base = name.replace(": ", ", ")
    base = SKIN_TONE_NAME_RE.sub("", base)
    base = re.sub(r"\s+,", ",", base)
    base = re.sub(r",\s+", ", ", base)
    base = re.sub(r"\s{2,}", " ", base)
    return base.strip(" ,")


def is_skin_tone_variant(name: str) -> bool:
    return bool(SKIN_TONE_NAME_RE.search(name))


def is_compatible_variant(item: EmojiItem) -> bool:
    return item.emoji_version <= MAX_COMPATIBLE_VARIANT_EMOJI_VERSION


def emoji_group_key(name: str) -> str:
    return emoji_base_name(name).casefold()


def parse_emoji_test_line(line: str, group: str, subgroup: str) -> EmojiItem | None:
    if "#" not in line or ";" not in line:
        return None

    left, comment = line.split("#", 1)
    codepoints, status = left.split(";", 1)
    if status.strip() != "fully-qualified":
        return None

    comment_parts = comment.strip().split(maxsplit=2)
    if len(comment_parts) < 3:
        return None

    value = comment_parts[0]
    emoji_version = comment_parts[1]
    emoji_version_number = parse_emoji_version(emoji_version)
    name = comment_parts[2]
    base_name = emoji_base_name(name)
    search_text = " ".join(
        (
            value,
            name,
            base_name,
            group,
            subgroup,
            emoji_version,
            codepoints.strip(),
            emoji_search_aliases(base_name, group, subgroup),
        ),
    ).casefold()
    return EmojiItem(
        value=value,
        name=name.title(),
        search_text=search_text,
        group=group,
        subgroup=subgroup,
        emoji_version=emoji_version_number,
    )


def group_skin_tone_variants(items: list[EmojiItem]) -> tuple[EmojiItem, ...]:
    groups: dict[str, list[EmojiItem]] = {}
    order: list[str] = []

    for item in items:
        key = emoji_group_key(item.name)
        if key not in groups:
            groups[key] = []
            order.append(key)
        groups[key].append(item)

    grouped: list[EmojiItem] = []
    for key in order:
        group_items = groups[key]
        base_item = next((item for item in group_items if not is_skin_tone_variant(item.name)), group_items[0])
        variant_items = [
            base_item,
            *[
                item
                for item in group_items
                if item.value != base_item.value and is_compatible_variant(item)
            ],
        ]
        variants = tuple(
            EmojiVariant(value=item.value, name=item.name, emoji_version=item.emoji_version)
            for item in variant_items
        )
        search_text = " ".join({key, *(item.search_text for item in group_items)}).casefold()
        grouped.append(
            EmojiItem(
                value=base_item.value,
                name=emoji_base_name(base_item.name).title(),
                search_text=search_text,
                group=base_item.group,
                subgroup=base_item.subgroup,
                emoji_version=base_item.emoji_version,
                variants=variants if len(variants) > 1 else (),
            ),
        )

    return tuple(grouped)


@lru_cache(maxsize=1)
def load_emoji_items() -> tuple[EmojiItem, ...]:
    items: list[EmojiItem] = []
    seen: set[str] = set()
    group = ""
    subgroup = ""

    if not EMOJI_DATA_FILE.exists():
        fallback = (
            ("😀", "Grinning Face"),
            ("😃", "Grinning Face With Big Eyes"),
            ("😄", "Grinning Face With Smiling Eyes"),
            ("😁", "Beaming Face With Smiling Eyes"),
            ("😂", "Face With Tears Of Joy"),
            ("❤️", "Red Heart"),
        )
        return tuple(
            EmojiItem(value=value, name=name, search_text=f"{value} {name} happy smile love".casefold())
            for value, name in fallback
        )

    for raw_line in EMOJI_DATA_FILE.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("# group:"):
            group = line.partition(":")[2].strip()
            continue
        if line.startswith("# subgroup:"):
            subgroup = line.partition(":")[2].strip()
            continue
        if line.startswith("#"):
            continue

        item = parse_emoji_test_line(line, group, subgroup)
        if item is None or item.value in seen:
            continue
        seen.add(item.value)
        items.append(item)

    return group_skin_tone_variants(items)


def emoji_match_rank(item: EmojiItem, query: str) -> tuple[int, int, str]:
    name = item.name.casefold()
    subgroup = item.subgroup.casefold()
    group = item.group.casefold()

    if query in {"hand", "hands"}:
        is_hand_group = subgroup.startswith("hand-") or subgroup == "hands"
        is_hand_gesture_name = HAND_GESTURE_NAME_RE.search(name) is not None
        if is_hand_group and is_hand_gesture_name:
            return (0, len(name), name)
        if is_hand_group:
            return (1, len(name), name)
        if "person-gesture" in subgroup and is_hand_gesture_name:
            return (2, len(name), name)
        if is_hand_gesture_name:
            return (3, len(name), name)
        if "hand" in name:
            return (4, len(name), name)

    if name == query:
        return (0, len(name), name)
    if name.startswith(query):
        return (1, len(name), name)
    if f" {query}" in name:
        return (2, len(name), name)
    if subgroup.startswith(query) or group.startswith(query):
        return (3, len(name), name)
    return (4, len(name), name)


class DesktopPicker(Gtk.Application):
    def __init__(self, mode: str) -> None:
        super().__init__(
            application_id=f"dev.ritch.DesktopPicker.{mode}",
            flags=Gio.ApplicationFlags.NON_UNIQUE,
        )
        self.mode = mode
        self.window: Gtk.ApplicationWindow | None = None
        self.hit_window: Gtk.ApplicationWindow | None = None
        self.panel_window: Gtk.ApplicationWindow | None = None
        self.search_entry: Gtk.SearchEntry | None = None
        self.clipboard_list: Gtk.ListBox | None = None
        self.emoji_flow: Gtk.FlowBox | None = None
        self.category_buttons: list[tuple[str, Gtk.Button]] = []
        self.clipboard_items: list[ClipboardItem] = []
        self.emoji_items: tuple[EmojiItem, ...] = ()
        self.selected_emoji_group = "Smileys & Emotion"
        self.target_selector = target_window_selector()
        self.preview_queue: list[tuple[ClipboardItem, ImagePreview]] = []
        self.emoji_refresh_source = 0
        self.variant_popover: Gtk.Popover | None = None

    def do_activate(self) -> None:
        self.install_css()
        display_width, display_height = display_size()
        self.panel_window = self.build_layer_window(
            title=f"{self.mode}-picker-panel",
            namespace=f"lnx-df-{self.mode}-panel",
            width=display_width,
            height=display_height,
            keyboard_mode=GtkLayerShell.KeyboardMode.EXCLUSIVE,
            layer=GtkLayerShell.Layer.OVERLAY,
            anchor_all=True,
        )
        self.window = self.panel_window
        self.panel_window.add(self.build_overlay())
        self.panel_window.connect("key-press-event", self.on_key_pressed)

        self.panel_window.show_all()

        if self.search_entry is not None:
            self.search_entry.grab_focus()

        if self.preview_queue:
            GLib.idle_add(self.load_next_image_preview)

    def build_layer_window(
        self,
        *,
        title: str,
        namespace: str,
        width: int,
        height: int,
        keyboard_mode: GtkLayerShell.KeyboardMode,
        layer: GtkLayerShell.Layer,
        anchor_all: bool,
    ) -> Gtk.ApplicationWindow:
        window = Gtk.ApplicationWindow(application=self)
        window.set_title(title)
        window.set_decorated(False)
        window.set_resizable(False)
        window.set_app_paintable(True)
        window.set_default_size(width, height)

        screen = window.get_screen()
        visual = screen.get_rgba_visual()
        if visual is not None:
            window.set_visual(visual)

        GtkLayerShell.init_for_window(window)
        GtkLayerShell.set_namespace(window, namespace)
        GtkLayerShell.set_layer(window, layer)
        GtkLayerShell.set_keyboard_mode(window, keyboard_mode)
        GtkLayerShell.set_exclusive_zone(window, -1)

        if anchor_all:
            for edge in (
                GtkLayerShell.Edge.TOP,
                GtkLayerShell.Edge.RIGHT,
                GtkLayerShell.Edge.BOTTOM,
                GtkLayerShell.Edge.LEFT,
            ):
                GtkLayerShell.set_anchor(window, edge, True)

        return window

    def install_css(self) -> None:
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS.encode("utf-8"))
        screen = Gdk.Screen.get_default()
        if screen is None:
            return
        Gtk.StyleContext.add_provider_for_screen(
            screen,
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

    def build_overlay(self) -> Gtk.Widget:
        overlay = Gtk.Overlay()
        display_width, display_height = display_size()
        overlay.set_size_request(display_width, display_height)
        overlay.set_hexpand(True)
        overlay.set_vexpand(True)

        hit_area = Gtk.EventBox()
        hit_area.set_visible_window(True)
        hit_area.get_style_context().add_class("background-hit-area")
        hit_area.set_hexpand(True)
        hit_area.set_vexpand(True)
        hit_area.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        hit_area.connect("button-press-event", self.on_background_clicked)
        hit_area.add(Gtk.Box())

        panel = self.build_panel()
        panel.set_halign(Gtk.Align.CENTER)
        panel.set_valign(Gtk.Align.CENTER)

        overlay.add(hit_area)
        overlay.add_overlay(panel)
        overlay.set_overlay_pass_through(panel, False)

        return overlay

    def build_panel(self) -> Gtk.Widget:
        panel_shell = Gtk.EventBox()
        panel_shell.set_visible_window(True)
        panel_shell.get_style_context().add_class("picker-panel")
        if self.mode == "clipboard":
            panel_shell.get_style_context().add_class("clipboard-panel")
        panel_shell.set_size_request(760, 540)
        panel_shell.set_halign(Gtk.Align.CENTER)
        panel_shell.set_valign(Gtk.Align.CENTER)

        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        panel.set_margin_top(18)
        panel.set_margin_bottom(18)
        panel.set_margin_start(18)
        panel.set_margin_end(18)

        if self.mode == "clipboard":
            content = self.build_clipboard_content()
        else:
            placeholder = "Search emoji"
            content = self.build_emoji_content()

        if self.mode == "emoji":
            self.search_entry = Gtk.SearchEntry()
            self.search_entry.get_style_context().add_class("search-entry")
            self.search_entry.set_placeholder_text(placeholder)
            self.search_entry.connect("search-changed", self.on_search_changed)
            panel.pack_start(self.search_entry, False, False, 0)

        if self.mode == "clipboard":
            panel.pack_start(content, True, True, 0)
            panel_shell.add(panel)
            return panel_shell

        frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        frame.get_style_context().add_class("content-frame")
        frame.pack_start(content, True, True, 0)
        panel.pack_start(frame, True, True, 0)

        panel_shell.add(panel)
        return panel_shell

    def build_clipboard_content(self) -> Gtk.Widget:
        self.clipboard_items = load_clipboard_items()
        if not self.clipboard_items:
            return self.build_empty_label("Clipboard history is empty")

        self.clipboard_list = Gtk.ListBox()
        self.clipboard_list.get_style_context().add_class("clipboard-list")
        self.clipboard_list.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.clipboard_list.set_activate_on_single_click(True)
        self.clipboard_list.set_filter_func(self.filter_clipboard_row)
        self.clipboard_list.connect("row-activated", self.on_clipboard_row_activated)

        for item in self.clipboard_items:
            self.clipboard_list.add(self.build_clipboard_row(item))

        scrolled = Gtk.ScrolledWindow()
        scrolled.get_style_context().add_class("content-scroller")
        scrolled.get_style_context().add_class("clipboard-scroller")
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_overlay_scrolling(True)
        scrolled.set_max_content_height(420)
        scrolled.set_propagate_natural_height(False)
        scrolled.set_margin_top(8)
        scrolled.set_margin_bottom(8)
        scrolled.set_margin_start(8)
        scrolled.set_margin_end(8)
        scrolled.add(self.clipboard_list)
        return scrolled

    def build_clipboard_row(self, item: ClipboardItem) -> Gtk.ListBoxRow:
        row = Gtk.ListBoxRow()
        row.item = item  # type: ignore[attr-defined]
        row.get_style_context().add_class("clipboard-row")

        content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
        content.set_margin_top(4)
        content.set_margin_bottom(4)

        preview = self.build_clipboard_preview(item)
        if preview is not None:
            content.pack_start(preview, False, False, 0)

        text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        text_box.set_valign(Gtk.Align.CENTER)

        primary_text = "Image" if item.is_image else item.preview
        secondary_text = item.image_meta if item.is_image else ""

        primary = Gtk.Label(label=primary_text)
        primary.get_style_context().add_class("clipboard-primary")
        primary.set_xalign(0)
        primary.set_ellipsize(Pango.EllipsizeMode.END)

        text_box.pack_start(primary, False, False, 0)
        if secondary_text:
            secondary = Gtk.Label(label=secondary_text)
            secondary.get_style_context().add_class("clipboard-secondary")
            secondary.set_xalign(0)
            secondary.set_ellipsize(Pango.EllipsizeMode.END)
            text_box.pack_start(secondary, False, False, 0)
        content.pack_start(text_box, True, True, 0)

        delete_button = Gtk.Button(label="×")
        delete_button.get_style_context().add_class("clipboard-delete-button")
        delete_button.set_tooltip_text("Delete item")
        delete_button.set_valign(Gtk.Align.CENTER)
        delete_button.connect("clicked", self.on_clipboard_delete_clicked, item, row)
        content.pack_end(delete_button, False, False, 0)

        row.add(content)
        return row

    def build_clipboard_preview(self, item: ClipboardItem) -> Gtk.Widget | None:
        if not item.is_image:
            return None

        preview = ImagePreview()
        if len(self.preview_queue) < MAX_IMAGE_PREVIEWS:
            self.preview_queue.append((item, preview))
        return preview

    def load_next_image_preview(self) -> bool:
        if not self.preview_queue:
            return False

        item, wrapper = self.preview_queue.pop(0)
        pixbuf = load_image_preview(item.raw)
        if pixbuf is not None:
            wrapper.set_pixbuf(pixbuf)

        return bool(self.preview_queue)

    def build_emoji_content(self) -> Gtk.Widget:
        self.emoji_items = load_emoji_items()
        groups = {item.group for item in self.emoji_items}
        if self.selected_emoji_group not in groups:
            self.selected_emoji_group = next(iter(groups), "")

        self.emoji_flow = Gtk.FlowBox()
        self.emoji_flow.get_style_context().add_class("emoji-flow")
        self.emoji_flow.set_selection_mode(Gtk.SelectionMode.NONE)
        self.emoji_flow.set_max_children_per_line(10)
        self.emoji_flow.set_min_children_per_line(5)
        self.emoji_flow.set_column_spacing(6)
        self.emoji_flow.set_row_spacing(8)
        self.emoji_flow.set_halign(Gtk.Align.CENTER)
        self.emoji_flow.set_valign(Gtk.Align.START)
        self.emoji_flow.set_vexpand(False)
        self.rebuild_emoji_flow()

        scrolled = Gtk.ScrolledWindow()
        scrolled.get_style_context().add_class("content-scroller")
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_overlay_scrolling(True)
        scrolled.set_margin_top(8)
        scrolled.set_margin_bottom(8)
        scrolled.set_margin_start(8)
        scrolled.set_margin_end(8)
        scrolled.add(self.emoji_flow)

        shell = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        shell.get_style_context().add_class("emoji-shell")
        shell.pack_start(scrolled, True, True, 0)
        shell.pack_start(self.build_category_bar(), False, False, 0)
        return shell

    def build_category_bar(self) -> Gtk.Widget:
        bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        bar.get_style_context().add_class("category-bar")
        bar.set_halign(Gtk.Align.CENTER)

        self.category_buttons = []
        ordered_groups: list[str] = []
        seen: set[str] = set()
        for item in self.emoji_items:
            if item.group and item.group not in seen:
                seen.add(item.group)
                ordered_groups.append(item.group)

        for group in ordered_groups:
            button = Gtk.Button(label=EMOJI_CATEGORY_ICONS.get(group, "•"))
            button.get_style_context().add_class("category-button")
            button.set_tooltip_text(group)
            button.connect("clicked", self.on_category_clicked, group)
            bar.pack_start(button, False, False, 0)
            self.category_buttons.append((group, button))

        self.update_category_styles()
        return bar

    def rebuild_emoji_flow(self) -> bool:
        self.emoji_refresh_source = 0
        if self.emoji_flow is None:
            return False

        for child in self.emoji_flow.get_children():
            self.emoji_flow.remove(child)

        query = self.active_query()
        source_items = self.emoji_items
        if query:
            matching_groups = self.matching_emoji_groups(query)
            if matching_groups and self.selected_emoji_group not in matching_groups:
                self.selected_emoji_group = matching_groups[0]
                self.update_category_styles()
            source_items = tuple(
                sorted(
                    (
                        item
                        for item in self.emoji_items
                        if item.group == self.selected_emoji_group and query in item.search_text
                    ),
                    key=lambda item: emoji_match_rank(item, query),
                ),
            )
        elif self.selected_emoji_group:
            source_items = tuple(item for item in self.emoji_items if item.group == self.selected_emoji_group)

        visible = 0
        for item in source_items:
            if query and query not in item.search_text:
                continue

            self.emoji_flow.add(self.build_emoji_button(item))
            visible += 1
            if visible >= MAX_EMOJI_VISIBLE:
                break

        self.emoji_flow.show_all()
        return False

    def build_emoji_button(self, item: EmojiItem) -> Gtk.Button:
        button = Gtk.Button()
        button.item = item  # type: ignore[attr-defined]
        button.get_style_context().add_class("emoji-button")
        button.set_size_request(56, 52)
        button.set_halign(Gtk.Align.CENTER)
        button.set_valign(Gtk.Align.START)
        button.set_hexpand(False)
        button.set_vexpand(False)
        button.set_tooltip_text(item.name)

        overlay = Gtk.Overlay()
        glyph = Gtk.Label(label=item.value)
        glyph.get_style_context().add_class("emoji-glyph")
        glyph.set_halign(Gtk.Align.CENTER)
        glyph.set_valign(Gtk.Align.CENTER)
        overlay.add(glyph)

        if item.variants:
            dot = Gtk.Box()
            dot.get_style_context().add_class("emoji-variant-dot")
            dot.set_halign(Gtk.Align.END)
            dot.set_valign(Gtk.Align.END)
            overlay.add_overlay(dot)

        button.add(overlay)
        button.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        button.connect("button-press-event", self.on_emoji_button_pressed, item)
        button.connect("clicked", self.on_emoji_clicked)
        return button

    def on_emoji_button_pressed(
        self,
        button: Gtk.Button,
        event: Gdk.EventButton,
        item: EmojiItem,
    ) -> bool:
        if event.button != 3 or not item.variants:
            return False

        self.show_variant_popover(button, item)
        return True

    def show_variant_popover(self, button: Gtk.Button, item: EmojiItem) -> None:
        if self.variant_popover is not None:
            self.variant_popover.popdown()
            self.variant_popover.destroy()
            self.variant_popover = None

        popover = Gtk.Popover.new(button)
        popover.get_style_context().add_class("variant-popover")
        popover.set_position(Gtk.PositionType.TOP)

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        outer.get_style_context().add_class("variant-box")

        flow = Gtk.FlowBox()
        flow.get_style_context().add_class("variant-flow")
        flow.set_selection_mode(Gtk.SelectionMode.NONE)
        flow.set_max_children_per_line(8)
        flow.set_min_children_per_line(3)
        flow.set_column_spacing(6)
        flow.set_row_spacing(6)
        for variant in item.variants:
            variant_button = Gtk.Button(label=variant.value)
            variant_button.get_style_context().add_class("variant-button")
            variant_button.set_tooltip_text(variant.name)
            variant_button.connect("clicked", self.on_emoji_variant_clicked, variant)
            flow.add(variant_button)

        outer.pack_start(flow, False, False, 0)

        popover.add(outer)
        popover.show_all()
        popover.popup()
        self.variant_popover = popover

    def on_emoji_variant_clicked(self, _button: Gtk.Button, variant: EmojiVariant) -> None:
        self.copy_emoji_and_paste(variant.value)

    def build_empty_label(self, text: str) -> Gtk.Widget:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        box.set_halign(Gtk.Align.CENTER)
        box.set_valign(Gtk.Align.CENTER)
        label = Gtk.Label(label=text)
        label.get_style_context().add_class("empty-label")
        box.pack_start(label, True, True, 0)
        return box

    def on_search_changed(self, entry: Gtk.SearchEntry) -> None:
        if self.clipboard_list is not None:
            self.clipboard_list.invalidate_filter()
        if self.emoji_flow is not None:
            query = self.active_query()
            matching_groups = self.matching_emoji_groups(query)
            if query and matching_groups and self.selected_emoji_group not in matching_groups:
                self.selected_emoji_group = matching_groups[0]
            self.update_category_styles()
            if self.emoji_refresh_source:
                GLib.source_remove(self.emoji_refresh_source)
            self.emoji_refresh_source = GLib.timeout_add(70, self.rebuild_emoji_flow)

    def on_category_clicked(self, _button: Gtk.Button, group: str) -> None:
        self.selected_emoji_group = group
        self.update_category_styles()
        if self.emoji_flow is not None:
            self.rebuild_emoji_flow()

    def update_category_styles(self) -> None:
        query = self.active_query()
        matching_groups = set(self.matching_emoji_groups(query)) if query else set()
        for group, button in self.category_buttons:
            button.set_sensitive(not query or group in matching_groups)
            style = button.get_style_context()
            if group == self.selected_emoji_group:
                style.add_class("selected-category")
            else:
                style.remove_class("selected-category")

    def matching_emoji_groups(self, query: str) -> list[str]:
        if not query:
            return []

        groups: list[str] = []
        seen: set[str] = set()
        for item in self.emoji_items:
            if query in item.search_text and item.group not in seen:
                seen.add(item.group)
                groups.append(item.group)
        return groups

    def active_query(self) -> str:
        if self.search_entry is None:
            return ""
        return self.search_entry.get_text().strip().casefold()

    def filter_clipboard_row(self, row: Gtk.ListBoxRow) -> bool:
        query = self.active_query()
        if not query:
            return True
        item: ClipboardItem = row.item  # type: ignore[attr-defined]
        return query in item.search_text

    def on_clipboard_row_activated(self, _listbox: Gtk.ListBox, row: Gtk.ListBoxRow) -> None:
        item: ClipboardItem = row.item  # type: ignore[attr-defined]
        decoded = decode_clipboard_item(item)
        if decoded and copy_bytes_to_clipboard(decoded):
            self.quit()

    def on_clipboard_delete_clicked(
        self,
        _button: Gtk.Button,
        item: ClipboardItem,
        row: Gtk.ListBoxRow,
    ) -> None:
        if not delete_clipboard_item(item):
            return
        if self.clipboard_list is not None:
            self.clipboard_list.remove(row)
        self.clipboard_items = [candidate for candidate in self.clipboard_items if candidate.raw != item.raw]

    def on_emoji_clicked(self, button: Gtk.Button) -> None:
        item: EmojiItem = button.item  # type: ignore[attr-defined]
        self.copy_emoji_and_paste(item.value)

    def copy_emoji_and_paste(self, value: str) -> None:
        if not copy_text_to_clipboard(value):
            return
        paste_to_window(self.target_selector)
        self.quit()

    def on_background_clicked(self, *_args: object) -> bool:
        self.quit()
        return True

    def on_key_pressed(self, _window: Gtk.ApplicationWindow, event: Gdk.EventKey) -> bool:
        key = Gdk.keyval_name(event.keyval)
        if key in {"Escape", "q", "Q"}:
            self.quit()
            return True

        if key in {"Return", "KP_Enter"} and self.mode == "clipboard" and self.clipboard_list is not None:
            row = self.clipboard_list.get_selected_row()
            if row is not None:
                self.on_clipboard_row_activated(self.clipboard_list, row)
                return True

        return False


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Beautiful clipboard and emoji picker")
    parser.add_argument("mode", choices=("clipboard", "emoji"))
    return parser.parse_args()


def main() -> int:
    global APP_LOCK
    args = parse_args()
    APP_LOCK = acquire_app_lock(args.mode)
    if APP_LOCK is None:
        return 0
    return DesktopPicker(args.mode).run([sys.argv[0]])


if __name__ == "__main__":
    raise SystemExit(main())
