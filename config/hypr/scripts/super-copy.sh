#!/usr/bin/env bash
set -euo pipefail

active_class=$(hyprctl activewindow -j 2>/dev/null | python3 -c 'import json,sys
try:
 d=json.load(sys.stdin)
 print(d.get("class", ""))
except Exception:
 print("")')

case "$active_class" in
  kitty|Alacritty|foot|org.wezfurlong.wezterm|com.mitchellh.ghostty)
    exec hyprctl dispatch sendshortcut "CTRL SHIFT, C, activewindow"
    ;;
  *)
    exec hyprctl dispatch sendshortcut "CTRL, C, activewindow"
    ;;
esac
