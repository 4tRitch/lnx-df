#!/usr/bin/env fish
# Configure udev permissions so Vial can access the Corne via hidraw.
# This is fish-compatible; do not use Bash heredocs in fish.

printf '%s\n' 'KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", GROUP="ritch", TAG+="uaccess", TAG+="udev-acl"' | sudo tee /etc/udev/rules.d/59-vial.rules >/dev/null

sudo udevadm control --reload-rules
sudo udevadm trigger

echo 'Unplug and reconnect the Corne, then verify permissions with:'
echo 'eza -lg /dev/hidraw*'
echo 'Expected for the Corne hidraw devices: root ritch with crw-rw---- permissions.'
