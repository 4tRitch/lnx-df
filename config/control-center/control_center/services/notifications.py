import json
import time

from control_center.config import NOTIFICATION_HISTORY
from control_center.infra.commands import command_output, command_succeeds
from control_center.services.icons import desktop_icon_name, normalize_app_key


def notification_count() -> int:
    raw = command_output(["swaync-client", "-c", "-sw"], timeout=0.5)
    try:
        return max(0, int(raw))
    except Exception:
        return 0


def notification_dnd() -> bool:
    return command_output(["swaync-client", "-D", "-sw"], timeout=0.5).lower() == "true"


def read_notification_history(count: int, limit: int = 3) -> list[dict[str, str | int]]:
    if count <= 0 or not NOTIFICATION_HISTORY.exists():
        return []
    entries: list[dict[str, str | int]] = []
    try:
        lines = NOTIFICATION_HISTORY.read_text(errors="ignore").splitlines()
    except Exception:
        return []
    for line in lines[-80:]:
        try:
            item = json.loads(line)
        except Exception:
            continue
        if not isinstance(item, dict):
            continue
        summary = str(item.get("summary") or "").strip()
        body = str(item.get("body") or "").strip()
        app = str(item.get("app") or "").strip()
        if summary or body or app:
            entries.append(item)
    return list(reversed(entries[-min(max(limit, count), len(entries)):]))


def notification_status() -> dict[str, bool | int | list[dict[str, str | int]]]:
    count = notification_count()
    return {
        "count": count,
        "dnd": notification_dnd(),
        "items": read_notification_history(count, limit=8),
    }


def clear_notification_history() -> None:
    try:
        NOTIFICATION_HISTORY.parent.mkdir(parents=True, exist_ok=True)
        NOTIFICATION_HISTORY.write_text("")
    except Exception:
        pass


def notification_groups(items: list[dict[str, str | int]], count: int) -> list[dict[str, object]]:
    grouped: dict[str, dict[str, object]] = {}
    order = []
    for item in items:
        app = str(item.get("app") or item.get("desktop_entry") or "Notification").strip()
        desktop_entry = str(item.get("desktop_entry") or "").strip()
        key = normalize_app_key(desktop_entry or app) or "notification"
        if key not in grouped:
            grouped[key] = {
                "key": key,
                "app": app,
                "desktop_entry": desktop_entry,
                "icon": desktop_icon_name(desktop_entry, app),
                "items": [],
            }
            order.append(key)
        grouped[key]["items"].append(item)
    groups = [grouped[key] for key in order]
    missing = max(0, count - len(items))
    if missing:
        groups.append({
            "key": "pending",
            "app": "Notifications",
            "desktop_entry": "",
            "icon": "dialog-information",
            "items": [{"summary": f"{missing} notification{'s' if missing != 1 else ''} waiting", "body": "", "app": "Notifications", "time": ""}],
        })
    return groups


def close_notification(notification_id: object) -> bool:
    try:
        nid = int(str(notification_id))
    except Exception:
        return False
    return command_succeeds(["busctl", "--user", "call", "org.erikreider.swaync", "/org/erikreider/swaync/cc", "org.erikreider.swaync.cc", "CloseNotification", "u", str(nid)], timeout=1.0)


def close_notifications(items: list[dict[str, str | int]]) -> None:
    for item in items:
        close_notification(item.get("id", ""))


def remove_notifications_from_history(ids: set[str]) -> None:
    if not ids or not NOTIFICATION_HISTORY.exists():
        return
    try:
        lines = NOTIFICATION_HISTORY.read_text(errors="ignore").splitlines()
    except Exception:
        return
    kept = []
    for line in lines:
        try:
            item = json.loads(line)
        except Exception:
            kept.append(line)
            continue
        if str(item.get("id", "")) not in ids:
            kept.append(line)
    try:
        NOTIFICATION_HISTORY.write_text("\n".join(kept) + ("\n" if kept else ""))
    except Exception:
        pass


def relative_notification_time(raw: object) -> str:
    try:
        timestamp = int(str(raw))
    except Exception:
        return ""
    delta = max(0, int(time.time()) - timestamp)
    if delta < 60:
        return "now"
    minutes = delta // 60
    if minutes < 60:
        return f"{minutes} min"
    hours = minutes // 60
    if hours < 24:
        return f"{hours} hr"
    return f"{hours // 24} d"
