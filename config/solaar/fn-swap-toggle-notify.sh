#!/usr/bin/env bash
set -u

DEVICE="MX Keys Mini for Business"
OSD_SCRIPT="/home/ritch/.config/solaar/osd.sh"

read_state() {
  timeout 6s solaar config "$DEVICE" fn-swap 2>/dev/null | awk -F ' = ' '/^fn-swap/ {print $2; exit}'
}

show_state() {
  local state="$1"
  if [[ "$state" == "True" ]]; then
    exec "$OSD_SCRIPT" fn-swap-message preferences-desktop-keyboard-shortcuts-symbolic "Modo multimedia"
  elif [[ "$state" == "False" ]]; then
    exec "$OSD_SCRIPT" fn-swap-message input-keyboard-symbolic "Modo F1-F12"
  else
    exec "$OSD_SCRIPT" fn-swap-message input-keyboard-symbolic "Fn swap: estado desconocido"
  fi
}

before="$(read_state)"
if [[ "$before" == "True" ]]; then
  target=false
else
  target=true
fi

# Solaar aplica el cambio pero puede terminar con exit 1 por un bug de GLib/Gio.
# Lo importante es leer el estado real después del intento.
timeout 8s solaar config "$DEVICE" fn-swap "$target" >/dev/null 2>&1 || true
sleep 0.3
after="$(read_state)"

if [[ -n "$after" ]]; then
  show_state "$after"
fi

show_state "$before"
