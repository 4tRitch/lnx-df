#!/usr/bin/env bash
set -euo pipefail

theme_dir='/usr/share/sddm/themes/sddm-astronaut-theme'
if [[ ! -d "$theme_dir" ]]; then
  echo 'Astronaut theme is not installed yet. Run the install script first.' >&2
  exit 1
fi

exec sddm-greeter-qt6 --test-mode --theme "$theme_dir"
