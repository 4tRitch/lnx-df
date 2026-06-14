from control_center.infra.commands import command_output, command_run, run_detached
from control_center.utils import split_nmcli_line


def wifi_device_status() -> tuple[str, str, str]:
    output = command_output(["nmcli", "-t", "-e", "yes", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"], timeout=1.0)
    for line in output.splitlines():
        parts = split_nmcli_line(line)
        if len(parts) >= 4 and parts[1] == "wifi":
            return parts[0], parts[2], parts[3]
    return "", "", ""


def active_wifi_ssid() -> str:
    output = command_output(["nmcli", "-t", "-e", "yes", "-f", "ACTIVE,SSID", "device", "wifi", "list", "--rescan", "no"], timeout=1.0)
    for line in output.splitlines():
        parts = split_nmcli_line(line)
        if len(parts) >= 2 and parts[0] == "yes" and parts[1]:
            return parts[1]
    return ""


def wifi_status() -> tuple[str, str]:
    radio = command_output(["nmcli", "radio", "wifi"], timeout=0.8)
    _device, device_state, connection = wifi_device_status()
    if radio == "disabled" or device_state in {"unavailable", "unmanaged"}:
        return "Off", "off"
    if device_state == "connected" and connection and connection != "--":
        return active_wifi_ssid() or connection, "on"
    if radio == "enabled" or device_state:
        return "On", "on"
    return "Off", "off"


def set_wifi_enabled(enabled: bool) -> None:
    run_detached(["nmcli", "radio", "wifi", "on" if enabled else "off"])


def wifi_rows(refresh: bool = False) -> list[tuple[str, list[str]]]:
    if wifi_status()[1] == "off":
        return []
    rows = read_wifi_rows(timeout=1.2)
    if not refresh:
        return [("󰐥  Scan networks", ["wifi-scan"]), *rows]
    refreshed = read_wifi_rows(timeout=8.0, rescan="yes") or rows
    return [("󰐥  Scan networks", ["wifi-scan"]), *refreshed]


def read_wifi_rows(timeout: float, rescan: str = "no") -> list[tuple[str, list[str]]]:
    rows = []
    output = command_output(["nmcli", "-t", "-e", "yes", "-f", "IN-USE,SSID,SECURITY,SIGNAL", "device", "wifi", "list", "--rescan", rescan], timeout=timeout)
    seen = set()
    for line in output.splitlines():
        parts = split_nmcli_line(line)
        if len(parts) < 4:
            continue
        active, ssid, security, signal = parts[0], parts[1], parts[2], parts[3]
        if not ssid or ssid in seen:
            continue
        seen.add(ssid)
        mark = "* " if active == "*" else "  "
        lock = " " if security and security != "--" else ""
        rows.append((f"󰤨  {mark}{lock}{ssid[:24]} · {signal}%", ["wifi-connect", ssid, security]))
    if not rows:
        current, state = wifi_status()
        if state == "on" and current not in {"On", "Off"}:
            rows.append((f"󰤨  * {current[:28]} · connected", []))
    return rows[:8]


def connect_wifi(ssid: str, password: str | None = None) -> tuple[bool, str]:
    command = ["nmcli", "device", "wifi", "connect", ssid]
    if password:
        command.extend(["password", password])
    return command_run(command, timeout=18.0)
