#!/usr/bin/env bash
set -euo pipefail

status() {
  local powered connected_count connected_names text tooltip class

  powered="$((bluetoothctl show 2>/dev/null || true) | awk -F': ' '/Powered/ {print $2; exit}')"

  if [[ "$powered" != "yes" ]]; then
    python3 -c 'import json; print(json.dumps({"text":"[󰂲]","tooltip":"Bluetooth: off","class":"off"}))'
    return
  fi

  connected_names="$(bluetoothctl devices Connected 2>/dev/null | sed 's/^Device [^ ]* //' || true)"
  connected_count="$(printf '%s\n' "$connected_names" | sed '/^$/d' | wc -l)"

  text="[󰂯 ${connected_count}]"
  class="on"
  tooltip="Bluetooth: on"

  if [[ "$connected_count" -gt 0 ]]; then
    class="connected"
    tooltip="Bluetooth connected:\n${connected_names}"
  fi

  python3 - "$text" "$tooltip" "$class" <<'PY'
import json
import sys

print(json.dumps({"text": sys.argv[1], "tooltip": sys.argv[2], "class": sys.argv[3]}))
PY
}

scan_devices() {
  command -v rfkill >/dev/null 2>&1 && rfkill unblock bluetooth >/dev/null 2>&1 || true
  bluetoothctl power on >/dev/null 2>&1 || true
  bluetoothctl scan on >/dev/null 2>&1 &
  local scan_pid=$!
  sleep 8
  kill "$scan_pid" >/dev/null 2>&1 || true
  bluetoothctl scan off >/dev/null 2>&1 || true
}

notify() {
  local title="$1" message="$2"

  command -v notify-send >/dev/null 2>&1 && notify-send "$title" "$message" || true
}

is_powered_on() {
  [[ "$((bluetoothctl show 2>/dev/null || true) | awk -F': ' '/Powered/ {print $2; exit}')" == "yes" ]]
}

set_power() {
  local power="$1"

  if [[ "$power" == "on" ]]; then
    command -v rfkill >/dev/null 2>&1 && rfkill unblock bluetooth >/dev/null 2>&1 || true
    sleep 0.5

    for _ in {1..5}; do
      if bluetoothctl power on >/dev/null 2>&1 || is_powered_on; then
        exit 0
      fi
      sleep 0.5
    done

    notify "Bluetooth" "No pude prender Bluetooth. Revisá si hay bloqueo físico o permisos de rfkill."
    exit 0
  fi

  bluetoothctl power off >/dev/null 2>&1 || true
}

menu() {
  local rows selection mac connected action powered power_label power_value

  powered="$((bluetoothctl show 2>/dev/null || true) | awk -F': ' '/Powered/ {print $2; exit}')"

  if [[ "$powered" == "yes" ]]; then
    power_label="󰂲  turn bluetooth off"
    power_value="off"
  else
    power_label="󰂯  turn bluetooth on"
    power_value="on"
  fi

  rows="$(
    printf '%s\tpower\t%s\n' "$power_label" "$power_value"
    printf '󰐥  scan new devices\tscan\tscan\n'
    (bluetoothctl devices 2>/dev/null || true) | while read -r _ mac name; do
      [[ -z "${mac:-}" || -z "${name:-}" ]] && continue
      connected="$((bluetoothctl info "$mac" 2>/dev/null || true) | awk -F': ' '/Connected/ {print $2; exit}')"
      if [[ "$connected" == "yes" ]]; then
        printf '󰂱  %s  · connected\tdevice\t%s\n' "$name" "$mac"
      else
        printf '󰂯  %s\tdevice\t%s\n' "$name" "$mac"
      fi
    done
  )"

  selection="$(printf '%s' "$rows" | cut -f1 | rofi -dmenu -i -p 'bluetooth' || true)"
  [[ -z "$selection" ]] && exit 0

  action="$(printf '%s' "$rows" | awk -F'\t' -v label="$selection" '$1 == label {print $2; exit}')"
  mac="$(printf '%s' "$rows" | awk -F'\t' -v label="$selection" '$1 == label {print $3; exit}')"

  if [[ "$action" == "power" ]]; then
    set_power "$mac"
    exit 0
  fi

  if [[ "$action" == "scan" ]]; then
    scan_devices
    exec "$0" --menu
  fi

  [[ -z "$mac" ]] && exit 0

  connected="$((bluetoothctl info "$mac" 2>/dev/null || true) | awk -F': ' '/Connected/ {print $2; exit}')"
  if [[ "$connected" == "yes" ]]; then
    bluetoothctl disconnect "$mac"
  else
    bluetoothctl connect "$mac"
  fi
}

case "${1:---status}" in
  --status) status ;;
  --menu) menu ;;
  --power-on) set_power on ;;
  --power-off) set_power off ;;
  *) status ;;
esac
