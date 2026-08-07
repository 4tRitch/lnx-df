#!/usr/bin/env bash
set -euo pipefail

exec hyprctl dispatch sendshortcut "CTRL, X, activewindow"
