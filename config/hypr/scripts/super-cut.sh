#!/usr/bin/env bash
set -euo pipefail

exec hyprctl dispatch 'hl.dsp.send_shortcut({mods="CTRL", key="X", window="activewindow"})'
