#!/usr/bin/env bash
# Alterna el foco entre monitores (Super+Tab).
set -euo pipefail

cur="$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name' | head -1)"
other="$(hyprctl monitors -j | jq -r --arg cur "$cur" '[.[] | select(.name != $cur) | .name] | .[0]')"

if [ -n "$other" ] && [ "$other" != "null" ]; then
  hyprctl dispatch focusmonitor "$other"
fi