#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASTRONAUT_DIR="${SCRIPT_DIR}/../astronaut"
mkdir -p "$ASTRONAUT_DIR"

wallpaper_path="${1:-}"

if [[ -z "$wallpaper_path" ]]; then
  if command -v awww >/dev/null 2>&1 && pgrep -x awww-daemon >/dev/null 2>&1; then
    wallpaper_path="$(awww query 2>/dev/null | sed -n 's#.*currently displaying: image: ##p' | head -n1)"
  fi
fi

if [[ -z "$wallpaper_path" ]]; then
  echo "Could not detect current wallpaper. Pass a file path explicitly." >&2
  exit 1
fi

if [[ ! -f "$wallpaper_path" ]]; then
  echo "Wallpaper not found: $wallpaper_path" >&2
  exit 1
fi

repo_target="$ASTRONAUT_DIR/current-wallpaper.jpg"

if command -v magick >/dev/null 2>&1; then
  magick "$wallpaper_path" -auto-orient -strip -resize '2560x1440^' -gravity center -extent 2560x1440 -quality 92 "$repo_target"
else
  cp -f "$wallpaper_path" "$repo_target"
fi

installed_dir='/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds'
if [[ -d "$installed_dir" ]] && [[ -w "$installed_dir" ]]; then
  cp -f "$repo_target" "$installed_dir/current-wallpaper.jpg"
fi

echo "Synced wallpaper to $repo_target"
