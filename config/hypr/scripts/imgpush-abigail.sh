#!/usr/bin/env bash
# imgpush binding helper — run from Hyprland SUPER+ALT+V
# Copies local clipboard image to abigail:/tmp and shows the path in a Kitty popup.
# No notification, no clipboard clobber.
set -euo pipefail

if ! command -v fish >/dev/null 2>&1; then
  echo "fish not found" >&2
  exit 1
fi

# Run the fish function and capture output
result=$(fish -c 'imgpush abigail' 2>&1)
status=$?

if [ $status -ne 0 ]; then
  # Show error in a small kitty window
  kitty --title "imgpush — error" --hold sh -c "printf '%s\n' \"$result\"; printf '\nPress Enter to close...'; read -r" &
  exit 0
fi

# Show success in a small kitty window with the path (copy manually if needed)
# The window stays open until Enter
kitty --title "imgpush → abigail" sh -c "printf 'Pushed to abigail:\n%s\n\nPegá ese path en opencode (Abigail).\n\nPress Enter to close...' \"$result\"; read -r" &

# Also print to stdout for hyprland exec log
printf '%s\n' "$result"
