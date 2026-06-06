#!/usr/bin/env bash
set -euo pipefail

if command -v rofi >/dev/null 2>&1; then
  exec rofi -show drun -show-icons
fi

if ! command -v hyprlauncher >/dev/null 2>&1; then
  exec hyprctl notify 1 3500 'rgb(ff6666)' 'hyprlauncher is not installed'
fi

# Fallback only: hyprlauncher currently does not behave like rofi's drun list
# when the search is empty, so prefer rofi whenever it is available.
pkill -x hyprlauncher >/dev/null 2>&1 || true
pkill -f 'hyprlauncher --dmenu' >/dev/null 2>&1 || true

hyprlauncher --daemon >/dev/null 2>&1 &
sleep 0.6

exec hyprlauncher
