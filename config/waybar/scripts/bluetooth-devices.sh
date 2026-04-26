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
  bluetoothctl power on >/dev/null 2>&1 || true
  bluetoothctl scan on >/dev/null 2>&1 &
  local scan_pid=$!
  sleep 8
  kill "$scan_pid" >/dev/null 2>&1 || true
  bluetoothctl scan off >/dev/null 2>&1 || true
}

menu() {
  local rows selection mac connected action

  rows="$(
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
  *) status ;;
esac
