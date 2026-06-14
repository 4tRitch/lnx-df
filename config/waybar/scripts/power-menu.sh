#!/usr/bin/env bash
set -euo pipefail

status() {
  python3 -c 'import json; print(json.dumps({"text":"⏻","tooltip":"Power menu\nClick: logout, shutdown or reboot","class":"power"}))'
}

menu_rofi_fallback() {
  local rows selection action

  rows="$(
    printf '󰍃  logout\tlogout\n'
    printf '󰜉  reboot\treboot\n'
    printf '  shutdown\tshutdown\n'
  )"

  selection="$(printf '%s' "$rows" | cut -f1 | rofi -dmenu -i -p 'power' || true)"

  [[ -z "$selection" ]] && exit 0

  action="$(printf '%s' "$rows" | awk -F'\t' -v label="$selection" '$1 == label {print $2; exit}')"

  case "$action" in
    logout) ~/.config/hypr/scripts/shutdown-menu.sh logout ;;
    reboot) ~/.config/hypr/scripts/shutdown-menu.sh reboot ;;
    shutdown) ~/.config/hypr/scripts/shutdown-menu.sh shutdown ;;
  esac
}

menu() {
  exec ~/.config/hypr/scripts/power-menu-rofi.sh
}

case "${1:---status}" in
  --status) status ;;
  --menu) menu ;;
  --menu-rofi-fallback) menu_rofi_fallback ;;
  *) status ;;
esac
