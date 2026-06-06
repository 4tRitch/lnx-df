#!/usr/bin/env bash
set -euo pipefail

video_path="${1:-}"
if [[ -z "$video_path" ]]; then
  echo "Usage: $0 /path/to/video.mp4" >&2
  exit 1
fi

if [[ ! -f "$video_path" ]]; then
  echo "Video not found: $video_path" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASTRONAUT_DIR="${SCRIPT_DIR}/../astronaut"
mkdir -p "$ASTRONAUT_DIR"
cp -f "$video_path" "$ASTRONAUT_DIR/current-background.mp4"

installed_target='/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/current-background.mp4'
if [[ -d /usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds ]] && [[ -w /usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds ]]; then
  cp -f "$video_path" "$installed_target"
fi

echo "Synced video to ${ASTRONAUT_DIR}/current-background.mp4"
