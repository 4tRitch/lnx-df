#!/usr/bin/env bash
set -euo pipefail

status() {
  python3 -c 'import json; print(json.dumps({"text":"⏻","tooltip":"Power menu\nClick: shutdown or reboot","class":"power"}))'
}

menu() {
  local rows selection action

  rows="$(
    printf '󰜉  reboot\treboot\n'
    printf '  shutdown\tshutdown\n'
  )"

  selection="$(printf '%s' "$rows" | cut -f1 | rofi -dmenu -i -p 'power' || true)"
  [[ -z "$selection" ]] && exit 0

  action="$(printf '%s' "$rows" | awk -F'\t' -v label="$selection" '$1 == label {print $2; exit}')"

  case "$action" in
    reboot) systemctl reboot ;;
    shutdown) systemctl poweroff ;;
  esac
}

case "${1:---status}" in
  --status) status ;;
  --menu) menu ;;
  *) status ;;
esac
