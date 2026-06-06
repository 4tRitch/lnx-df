#!/usr/bin/env bash
set -euo pipefail

action="${1:-logout}"

run_hyprshutdown() {
  local label="$1"
  shift

  if command -v hyprshutdown >/dev/null 2>&1; then
    exec hyprshutdown --top-label "$label" "$@"
  fi
}

case "$action" in
  logout)
    run_hyprshutdown 'Good night.'
    exec hyprctl dispatch exit
    ;;
  reboot)
    run_hyprshutdown 'Restarting.' --post-cmd 'systemctl reboot'
    exec systemctl reboot
    ;;
  shutdown)
    run_hyprshutdown 'Shutting down.' --post-cmd 'systemctl poweroff'
    exec systemctl poweroff
    ;;
  *)
    hyprctl notify 1 3500 'rgb(ffcc66)' "Unknown shutdown action: $action"
    exit 1
    ;;
esac
