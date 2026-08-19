#!/usr/bin/env bash
# Mueve la ventana en foco al monitor vecino en la dirección pedida.
# No hace nada si no hay monitor en esa dirección.
# Uso: move-window-dir.sh left|right
set -euo pipefail
dir="${1:-right}"

case "$dir" in
  right)
    # Nota: jq 1.8.2 no resuelve $var.campo si la variable se liga tras un pipe previo;
    # se liga el array y se accede por índice ($f[0].x).
    expr='[.[] | select(.focused == true)] as $f | ([.[] | select(.x > $f[0].x)] | sort_by(.x) | .[0] | .name)'
    ;;
  left)
    expr='[.[] | select(.focused == true)] as $f | ([.[] | select(.x < $f[0].x)] | sort_by(.x) | reverse | .[0] | .name)'
    ;;
  *)
    echo "Uso: move-window-dir.sh left|right" >&2
    exit 1
    ;;
esac

target="$(hyprctl monitors -j | jq -r "$expr")"
if [ -n "$target" ] && [ "$target" != "null" ]; then
  hyprctl dispatch movewindow "mon:$target"
  hyprctl dispatch focusmonitor "$target"
fi