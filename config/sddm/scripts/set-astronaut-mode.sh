#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
if [[ -z "$mode" ]]; then
  echo "Usage: $0 static|video" >&2
  exit 1
fi

case "$mode" in
  static) target='Themes/lnx_df_elegant.conf' ;;
  video) target='Themes/lnx_df_elegant_video.conf' ;;
  *) echo "Usage: $0 static|video" >&2; exit 1 ;;
esac

metadata='/usr/share/sddm/themes/sddm-astronaut-theme/metadata.desktop'
if [[ ! -f "$metadata" ]]; then
  echo 'Astronaut theme is not installed yet.' >&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo 'Run with sudo.' >&2
  exit 1
fi

sed -i "s#^ConfigFile=.*#ConfigFile=${target}#" "$metadata"
echo "Astronaut mode set to ${mode}."
