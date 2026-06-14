import json
import threading
import time

from control_center.infra.commands import command_output, command_succeeds
from control_center.services.icons import normalize_app_key


def hypr_monitor_width() -> int:
    output = command_output(["hyprctl", "monitors", "-j"], timeout=1.2)
    if not output:
        return 0
    try:
        monitors = json.loads(output)
    except Exception:
        return 0
    if not isinstance(monitors, list) or not monitors:
        return 0
    monitor = next((item for item in monitors if item.get("focused")), monitors[0])
    try:
        return int(monitor.get("width") or 0)
    except Exception:
        return 0


def hypr_clients() -> list[dict[str, object]]:
    output = command_output(["hyprctl", "clients", "-j"], timeout=0.8)
    if not output:
        return []
    try:
        clients = json.loads(output)
    except Exception:
        return []
    return clients if isinstance(clients, list) else []


def find_app_client(app: str, desktop_entry: str = "") -> dict[str, object] | None:
    keys = {normalize_app_key(app), normalize_app_key(desktop_entry)}
    keys = {key for key in keys if key}
    if not keys:
        return None
    scored = []
    for client in hypr_clients():
        values = [
            str(client.get("class") or ""),
            str(client.get("initialClass") or ""),
            str(client.get("title") or ""),
            str(client.get("initialTitle") or ""),
        ]
        client_keys = [normalize_app_key(value) for value in values]
        score = 0
        for key in keys:
            for client_key in client_keys:
                if key == client_key:
                    score = max(score, 4)
                elif key and client_key and (key in client_key or client_key in key):
                    score = max(score, 2)
        if score:
            scored.append((score, int(client.get("focusHistoryID") or 9999), client))
    if not scored:
        return None
    scored.sort(key=lambda row: (-row[0], row[1]))
    return scored[0][2]


def flash_hypr_border(address: str) -> None:
    if not address:
        return
    command_succeeds(["hyprctl", "keyword", "windowrulev2", f"bordercolor rgb(e8c66a) rgb(f5d782) 45deg,address:{address}"], timeout=0.8)
    time.sleep(0.45)
    command_succeeds(["hyprctl", "reload", "config-only"], timeout=1.5)


def focus_app_window(app: str, desktop_entry: str = "") -> bool:
    client = find_app_client(app, desktop_entry)
    if not client:
        return False
    address = str(client.get("address") or "")
    if not address:
        return False
    ok = command_succeeds(["hyprctl", "dispatch", "focuswindow", f"address:{address}"], timeout=1.0)
    threading.Thread(target=flash_hypr_border, args=(address,), daemon=True).start()
    return ok
