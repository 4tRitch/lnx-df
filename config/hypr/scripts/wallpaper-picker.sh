#!/usr/bin/env bash
set -euo pipefail

wallpaper_dir="${WALLPAPER_DIR:-/home/ritch/Pictures/wallpapers}"

if command -v awww >/dev/null 2>&1 && command -v awww-daemon >/dev/null 2>&1; then
  wallpaper_client="awww"
  wallpaper_daemon="awww-daemon"
elif command -v swww >/dev/null 2>&1 && command -v swww-daemon >/dev/null 2>&1; then
  wallpaper_client="swww"
  wallpaper_daemon="swww-daemon"
else
  notify-send "Wallpaper" "Instalá awww o swww para cambiar wallpapers" 2>/dev/null || true
  exit 1
fi

if ! command -v rofi >/dev/null 2>&1; then
  notify-send "Wallpaper" "rofi no está instalado" 2>/dev/null || true
  exit 1
fi

if [ ! -d "$wallpaper_dir" ]; then
  notify-send "Wallpaper" "No existe $wallpaper_dir" 2>/dev/null || true
  exit 1
fi

mapfile -t wallpapers < <(
  find "$wallpaper_dir" -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) \
    2>/dev/null | sort
)

if [ "${#wallpapers[@]}" -eq 0 ]; then
  notify-send "Wallpaper" "No encontré imágenes en $wallpaper_dir" 2>/dev/null || true
  exit 0
fi

selected_index="$({
  for wallpaper in "${wallpapers[@]}"; do
    label="${wallpaper#$HOME/}"
    printf '%s\0icon\x1f%s\n' "$label" "$wallpaper"
  done
} | rofi \
  -dmenu \
  -i \
  -show-icons \
  -format i \
  -p "Wallpaper" \
  -theme-str 'window { width: 920px; }' \
  -theme-str 'listview { lines: 5; fixed-height: true; }' \
  -theme-str 'element { padding: 8px; spacing: 14px; }' \
  -theme-str 'element-icon { size: 140px; border-radius: 8px; }' \
  -theme-str 'element-text { vertical-align: 0.5; }')"

[ -n "$selected_index" ] || exit 0
selected="${wallpapers[$selected_index]}"

if ! pgrep -x "$wallpaper_daemon" >/dev/null 2>&1; then
  "$wallpaper_daemon" >/dev/null 2>&1 &
  sleep 0.2
fi

cursor_pos="$(hyprctl cursorpos 2>/dev/null | tr -d ' ')"
transition_args=(--transition-type grow --transition-duration 0.7)

if [ -n "$cursor_pos" ]; then
  transition_args+=(--transition-pos "$cursor_pos")
fi

"$wallpaper_client" img "$selected" "${transition_args[@]}"

if [ -x "$HOME/.config/sddm/scripts/sync-current-wallpaper.sh" ]; then
  "$HOME/.config/sddm/scripts/sync-current-wallpaper.sh" "$selected" >/dev/null 2>&1 || true
fi
