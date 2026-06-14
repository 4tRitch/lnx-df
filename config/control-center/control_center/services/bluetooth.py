import time

from control_center.infra.commands import command_output, command_run, command_succeeds, run_detached, shell_output


def bluetooth_status() -> tuple[str, str]:
    powered = shell_output("bluetoothctl show | awk -F': ' '/Powered/ {print $2; exit}'")
    if powered != "yes":
        return "Off", "off"
    connected = shell_output("bluetoothctl devices Connected | sed 's/^Device [^ ]* //' | paste -sd ', ' -", timeout=0.5)
    return (connected or "On"), "on"


def set_bluetooth_enabled(enabled: bool) -> None:
    run_detached(["bluetoothctl", "power", "on" if enabled else "off"])


def bluetooth_info(mac: str) -> dict[str, bool | str]:
    info = command_output(["bluetoothctl", "info", mac], timeout=1.0)
    data: dict[str, bool | str] = {
        "connected": "Connected: yes" in info,
        "paired": "Paired: yes" in info,
        "trusted": "Trusted: yes" in info,
        "name": "",
    }
    for line in info.splitlines():
        stripped = line.strip()
        if stripped.startswith("Name:"):
            data["name"] = stripped.split("Name:", 1)[1].strip()
            break
    return data


def bluetooth_rows(refresh: bool = False) -> list[tuple[str, list[str]]]:
    if bluetooth_status()[1] == "off":
        return []
    if refresh:
        command_succeeds(["bluetoothctl", "scan", "on"], timeout=2.0)
        time.sleep(5)
        command_succeeds(["bluetoothctl", "scan", "off"], timeout=2.0)
    rows = [("󰐥  Scan devices", ["bluetooth-scan"])]
    for line in command_output(["bluetoothctl", "devices"], timeout=2.0).splitlines():
        parts = line.split(maxsplit=2)
        if len(parts) < 3:
            continue
        mac, name = parts[1], parts[2]
        info = bluetooth_info(mac)
        connected = bool(info["connected"])
        paired = bool(info["paired"])
        mark = "* " if connected else "  "
        status = "connected" if connected else ("paired" if paired else "new")
        rows.append((f"󰂯  {mark}{name[:24]} · {status}", ["bluetooth-connect", mac]))
    return rows[:8]


def connect_bluetooth(mac: str) -> tuple[bool, str]:
    info = bluetooth_info(mac)
    if not bool(info["paired"]):
        ok, output = command_run(["bluetoothctl", "pair", mac], timeout=30.0)
        if not ok:
            return False, output or "Pairing failed"
    command_succeeds(["bluetoothctl", "trust", mac], timeout=5.0)
    ok, output = command_run(["bluetoothctl", "connect", mac], timeout=20.0)
    return ok, output
