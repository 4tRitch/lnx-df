#!/usr/bin/env bash
# Cambia (o mueve) al workspace local N del monitor en foco.
# Los workspaces son independientes por monitor con IDs UNICOS:
#   DP-2 (principal) = 1-10  |  HDMI-A-1 (TV) = 11-20
# El waybar muestra numeracion local (1-10) en cada barra via defaultName.
# Uso: ws-goto.sh [--move] N   (0 == 10)
set -euo pipefail

op="workspace"
nums=()
for arg in "$@"; do
  case "$arg" in
    --move) op="movetoworkspace" ;;
    *) nums+=("$arg") ;;
  esac
done

if [ "${#nums[@]}" -ne 1 ]; then
  echo "Uso: ws-goto.sh [--move] N" >&2
  exit 1
fi

local_num="${nums[0]}"
[ "$local_num" = "0" ] && local_num="10"
case "$local_num" in
  '' | *[!0-9]*) echo "N debe ser un número entre 0 y 10" >&2; exit 1 ;;
esac
if [ "$local_num" -lt 1 ] || [ "$local_num" -gt 10 ]; then
  echo "N debe ser un número entre 0 y 10" >&2
  exit 1
fi

# Monitor en foco -> offset de IDs reales
monitor="$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name' | head -1)"
case "$monitor" in
  HDMI-A-1) offset=10 ;;
  *) offset=0 ;;
esac

target=$((local_num + offset))
if [ "$op" = "workspace" ]; then
  hyprctl dispatch "hl.dsp.focus({workspace=$target})"
else
  hyprctl dispatch "hl.dsp.window.move({workspace=$target})"
fi
