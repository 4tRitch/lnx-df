# Corne + Vial setup

Commands used to make the Corne visible to Vial on this system.

## Apply Vial udev permissions

Run from fish:

```fish
./corne/vial-udev.fish
```

Or paste the commands manually:

```fish
printf '%s\n' 'KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", GROUP="ritch", TAG+="uaccess", TAG+="udev-acl"' | sudo tee /etc/udev/rules.d/59-vial.rules >/dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Then unplug/reconnect the Corne and verify:

```fish
eza -lg /dev/hidraw*
```

The Corne devices should show group `ritch` and `crw-rw----` permissions, for example:

```text
crw-rw----@ 243,7 root ritch /dev/hidraw7
crw-rw----@ 243,8 root ritch /dev/hidraw8
crw-rw----@ 243,9 root ritch /dev/hidraw9
```

## Launch Vial

```fish
~/Apps/Vial-v0.7.5-x86_64.AppImage
```

The same launcher is also available through Rofi as `Vial`.
