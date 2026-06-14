#!/usr/bin/env bash
set -euo pipefail

# Compatibility entrypoint: Hyprland still binds Super+Esc through the old
# rofi-named script, but the power menu is now a GTK layer-shell overlay so
# selected icons can switch between white and black correctly.
exec python3 "$HOME/.config/hypr/scripts/power-menu-gtk.py"
