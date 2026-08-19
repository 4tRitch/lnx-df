#!/usr/bin/env bash
# Cicla entre los workspaces del monitor en foco (wrap local por monitor:
# DP-2: 1 <-> 10 | HDMI-A-1: 11 <-> 20).
# Uso: ws-cycle.sh next|prev
set -euo pipefail
dir="${1:-next}"

monitor="$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name' | head -1)"
case "$monitor" in
  HDMI-A-1) first=11 ;;
  *) first=1 ;;
esac
last=$((first + 9))

cur="$(hyprctl activeworkspace -j | jq -r '.id')"
if ! [[ "$cur" =~ ^[0-9]+$ ]] || [ "$cur" -lt "$first" ] || [ "$cur" -gt "$last" ]; then
  exit 0
fi

if [ "$dir" = "prev" ]; then
  rel=$((cur - 1 < first ? last : cur - 1))
else
  rel=$((cur + 1 > last ? first : cur + 1))
fi
hyprctl dispatch workspace "$rel"
