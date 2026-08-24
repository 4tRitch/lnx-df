#!/usr/bin/env bash
# imgpush binding helper — run from Hyprland SUPER+ALT+V
# Copies local clipboard image to abigail:/tmp and copies the path to clipboard
# so you can paste directly in opencode (Abigail). No popup, no notification.
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

# Copy path to clipboard so you can paste directly in opencode (Abigail)
printf '%s' "$result" | wl-copy

# No popup needed — path is now in clipboard, just paste in opencode
