#!/usr/bin/env bash
set -euo pipefail

if ! command -v wlogout >/dev/null 2>&1; then
  exec ~/.config/waybar/scripts/power-menu.sh --menu-rofi-fallback
fi

monitor_json="$(hyprctl monitors -j 2>/dev/null || printf '[]')"
width="$(printf '%s' "$monitor_json" | jq -r 'first(.[] | select(.focused == true) | .width) // 1920' 2>/dev/null)"
height="$(printf '%s' "$monitor_json" | jq -r 'first(.[] | select(.focused == true) | .height) // 1080' 2>/dev/null)"

button_size=148
gap=18
count=4
panel_width=$((button_size * count + gap * (count - 1)))
panel_height=$button_size
margin_left=$(((width - panel_width) / 2))
margin_right=$margin_left
margin_top=$(((height - panel_height) / 2))
margin_bottom=$margin_top

(( margin_left < 40 )) && margin_left=40
(( margin_right < 40 )) && margin_right=40
(( margin_top < 80 )) && margin_top=80
(( margin_bottom < 80 )) && margin_bottom=80

exec wlogout \
  --layout "$HOME/.config/wlogout/layout" \
  --css "$HOME/.config/wlogout/style.css" \
  --buttons-per-row 4 \
  --column-spacing "$gap" \
  --row-spacing "$gap" \
  --margin-left "$margin_left" \
  --margin-right "$margin_right" \
  --margin-top "$margin_top" \
  --margin-bottom "$margin_bottom" \
  --protocol layer-shell \
  --no-span
