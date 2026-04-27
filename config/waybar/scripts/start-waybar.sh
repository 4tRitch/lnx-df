#!/usr/bin/env bash
set -euo pipefail

# Waybar needs to own org.kde.StatusNotifierWatcher for tray icons.
# kded6 can grab that name first in this setup, but it does not expose the
# /StatusNotifierWatcher object Waybar expects, so Steam/Vesktop tray icons
# silently disappear. Quit kded6 before starting Waybar so Waybar becomes the
# watcher.
kquitapp6 kded6 >/dev/null 2>&1 || pkill kded6 >/dev/null 2>&1 || true

# Network and Bluetooth are handled by dedicated Waybar modules. If their
# desktop applets are running, they duplicate icons inside the tray and make the
# bar noisy. Keep the tray for real app icons like Vesktop/Steam only.
systemctl --user stop app-blueman@autostart.service >/dev/null 2>&1 || true
pkill -x nm-applet >/dev/null 2>&1 || true
pkill -x blueman-applet >/dev/null 2>&1 || true
pkill -x blueman-tray >/dev/null 2>&1 || true

exec waybar
