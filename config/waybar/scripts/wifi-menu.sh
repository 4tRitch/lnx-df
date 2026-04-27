#!/usr/bin/env bash
set -euo pipefail

notify() {
  local title="$1" message="$2"

  command -v notify-send >/dev/null 2>&1 && notify-send "$title" "$message" || true
}

require_tools() {
  if ! command -v nmcli >/dev/null 2>&1; then
    notify "WiFi" "nmcli no está instalado"
    exit 1
  fi

  if ! command -v rofi >/dev/null 2>&1; then
    notify "WiFi" "rofi no está instalado"
    exit 1
  fi
}

wifi_device() {
  nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null \
    | awk -F: '$2 == "wifi" {print $1; exit}'
}

disconnect_wifi() {
  local device

  device="$(wifi_device)"
  [[ -n "$device" ]] && nmcli device disconnect "$device" >/dev/null 2>&1 || true
}

connect_wifi() {
  local ssid="$1" password

  if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
    exit 0
  fi

  password="$(rofi -dmenu -password -p "wifi password" || true)"
  [[ -z "$password" ]] && exit 0

  if ! nmcli device wifi connect "$ssid" password "$password" >/dev/null 2>&1; then
    notify "WiFi" "No pude conectar a $ssid"
  fi
}

network_rows() {
  python3 <<'PY'
import subprocess

def split_escaped(line: str):
    fields = []
    current = []
    escaped = False

    for char in line:
        if escaped:
            current.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            fields.append("".join(current))
            current = []
        else:
            current.append(char)

    fields.append("".join(current))
    return fields

try:
    output = subprocess.check_output(
        ["nmcli", "-t", "-e", "yes", "-f", "IN-USE,SSID,SECURITY,SIGNAL", "device", "wifi", "list"],
        text=True,
        stderr=subprocess.DEVNULL,
    )
except Exception:
    output = ""

seen = set()
for line in output.splitlines():
    fields = split_escaped(line)
    if len(fields) < 4:
        continue

    active, ssid, security, signal = fields[:4]
    ssid = ssid.strip()
    if not ssid or ssid in seen:
        continue

    seen.add(ssid)
    locked = " 󰌾" if security.strip() else ""
    if active.strip() == "*":
        print(f"󰤨  {ssid}{locked}  · connected\tdisconnect\t{ssid}")
    else:
        print(f"󰤨  {ssid}{locked}  · {signal.strip()}%\tconnect\t{ssid}")
PY
}

menu() {
  require_tools

  local rows selection action value wifi_state power_label power_value

  wifi_state="$(nmcli radio wifi 2>/dev/null || true)"

  if [[ "$wifi_state" == "enabled" ]]; then
    power_label="󰤭  turn wifi off"
    power_value="off"
  else
    power_label="󰤨  turn wifi on"
    power_value="on"
  fi

  rows="$({
    printf '%s\tpower\t%s\n' "$power_label" "$power_value"
    printf '󰐥  scan networks\tscan\tscan\n'
    network_rows
  })"

  selection="$(printf '%s' "$rows" | cut -f1 | rofi -dmenu -i -p 'wifi' || true)"
  [[ -z "$selection" ]] && exit 0

  action="$(printf '%s' "$rows" | awk -F'\t' -v label="$selection" '$1 == label {print $2; exit}')"
  value="$(printf '%s' "$rows" | awk -F'\t' -v label="$selection" '$1 == label {print $3; exit}')"

  case "$action" in
    power)
      nmcli radio wifi "$value"
      ;;
    scan)
      nmcli device wifi rescan >/dev/null 2>&1 || true
      exec "$0" --menu
      ;;
    disconnect)
      disconnect_wifi
      ;;
    connect)
      [[ -n "$value" ]] && connect_wifi "$value"
      ;;
  esac
}

case "${1:---menu}" in
  --menu) menu ;;
  *) menu ;;
esac
