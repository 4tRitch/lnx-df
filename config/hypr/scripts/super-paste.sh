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
    exec hyprctl dispatch 'hl.dsp.send_shortcut({mods="CTRL SHIFT", key="V", window="activewindow"})'
    ;;
  *)
    exec hyprctl dispatch 'hl.dsp.send_shortcut({mods="CTRL", key="V", window="activewindow"})'
    ;;
esac
