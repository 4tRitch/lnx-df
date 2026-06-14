#!/usr/bin/env bash
set -euo pipefail

# wlogout was removed to avoid AUR. Keep this entrypoint because Hyprland binds Super+Esc to it.
exec "$HOME/.config/hypr/scripts/power-menu-rofi.sh"
