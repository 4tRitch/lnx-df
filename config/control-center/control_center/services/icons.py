import os
import re
from pathlib import Path

ICON_PATH_CACHE: dict[str, str] = {}


def normalize_app_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", (value or "").lower().replace(".desktop", ""))


def data_dirs() -> list[Path]:
    return [Path.home() / ".local/share", *[Path(p) for p in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if p]]


def desktop_entries() -> list[Path]:
    entries = []
    for base in data_dirs():
        app_dir = base / "applications"
        if app_dir.exists():
            entries.extend(app_dir.glob("*.desktop"))
    return entries


def desktop_icon_name(desktop_entry: str, app_name: str) -> str:
    candidates = [desktop_entry, app_name]
    normalized = {normalize_app_key(candidate) for candidate in candidates if candidate}
    for desktop_file in desktop_entries():
        stem = normalize_app_key(desktop_file.stem)
        if normalized and stem not in normalized and not any(key and (key in stem or stem in key) for key in normalized):
            continue
        try:
            text = desktop_file.read_text(errors="ignore")
        except Exception:
            continue
        name_match = re.search(r"^Name=(.+)$", text, re.MULTILINE)
        icon_match = re.search(r"^Icon=(.+)$", text, re.MULTILINE)
        name_key = normalize_app_key(name_match.group(1) if name_match else "")
        if icon_match and (stem in normalized or name_key in normalized or any(key and key in name_key for key in normalized)):
            return icon_match.group(1).strip()
    return app_name.lower() or "application-x-executable"


def resolved_icon_path(icon_name: str) -> str:
    if not icon_name:
        return ""
    expanded = Path(icon_name).expanduser()
    if expanded.is_absolute() and expanded.is_file():
        return str(expanded)
    if icon_name in ICON_PATH_CACHE:
        return ICON_PATH_CACHE[icon_name]
    for base in [Path.home() / ".local/share/icons", Path("/usr/share/icons"), Path("/usr/share/pixmaps")]:
        if not base.exists():
            continue
        for suffix in ("png", "svg", "xpm"):
            direct = base / f"{icon_name}.{suffix}"
            if direct.exists():
                ICON_PATH_CACHE[icon_name] = str(direct)
                return str(direct)
        for suffix in ("png", "svg", "xpm"):
            try:
                match = next(base.glob(f"**/{icon_name}.{suffix}"))
            except StopIteration:
                continue
            except Exception:
                continue
            ICON_PATH_CACHE[icon_name] = str(match)
            return str(match)
    ICON_PATH_CACHE[icon_name] = ""
    return ""
