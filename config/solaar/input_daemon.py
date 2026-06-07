#!/usr/bin/env python3
"""
Daemon that listens to Logitech MX Keys Mini Consumer Control events
and executes commands for media keys, since the kernel maps them to
invalid keycodes and Solaar rules don't trigger on hid-generic devices.

Listens on /dev/input/event10 (Consumer Control).
"""

import os
import sys
import subprocess
import struct
import select
import fcntl

# Keycodes observed from the Consumer Control device for MX Keys Mini
# These are the raw keycodes the kernel emits for the diverted keys
KEY_VOLUME_UP   = 289   # Volume Up
KEY_VOLUME_DOWN = 290   # Volume Down
KEY_MUTE_SOUND  = 294   # Mute Sound (observed)
KEY_PLAY_PAUSE  = 298   # Play/Pause
KEY_MUTE_MIC    = 306   # Mute Microphone (observed)
KEY_SCREENSHOT  = 302   # Screen Capture (observed)
KEY_DICTATION   = 308   # Dictation / Fn swap toggle

# Map keycode -> command to execute
KEY_MAP = {
    KEY_VOLUME_UP:   ["/home/ritch/.config/solaar/osd.sh", "volume-up"],
    KEY_VOLUME_DOWN: ["/home/ritch/.config/solaar/osd.sh", "volume-down"],
    KEY_MUTE_SOUND:  ["/home/ritch/.config/solaar/osd.sh", "volume-mute-toggle"],
    KEY_PLAY_PAUSE:  ["/home/ritch/.config/solaar/osd.sh", "play-pause"],
    KEY_MUTE_MIC:    ["/home/ritch/.config/solaar/mic-toggle-notify.sh"],
    KEY_SCREENSHOT:  ["flameshot", "gui"],
    KEY_DICTATION:   ["/usr/bin/true"],
}

EV_KEY = 1
EV_SYN = 0

INPUT_EVENT_FORMAT = "llHHi"
INPUT_EVENT_SIZE = struct.calcsize(INPUT_EVENT_FORMAT)

def find_consumer_control_device():
    """Find the Logitech Consumer Control input device."""
    for dev_name in ["/dev/input/event10", "/dev/input/event9", "/dev/input/event11"]:
        if os.path.exists(dev_name):
            try:
                with open(dev_name, "rb") as f:
                    # Read device name
                    buf = bytearray(256)
                    fcntl.ioctl(f.fileno(), 0x80064506, buf)  # EVIOCGNAME
                    name = buf.decode("utf-8", errors="replace").strip("\x00")
                    if "Consumer Control" in name and "Logitech" in name:
                        return dev_name
            except Exception:
                continue
    return None

def main():
    dev_path = find_consumer_control_device()
    if not dev_path:
        print("Logitech Consumer Control device not found", file=sys.stderr)
        sys.exit(1)

    print(f"Listening on {dev_path}", file=sys.stderr)

    with open(dev_path, "rb") as dev:
        pressed_keys = set()

        while True:
            r, _, _ = select.select([dev], [], [], 1.0)
            if not r:
                continue

            data = dev.read(INPUT_EVENT_SIZE)
            if len(data) < INPUT_EVENT_SIZE:
                continue

            sec, usec, type, code, value = struct.unpack(INPUT_EVENT_FORMAT, data)

            if type == EV_KEY and code in KEY_MAP:
                if value == 1 and code not in pressed_keys:  # Key press
                    pressed_keys.add(code)
                    cmd = KEY_MAP[code]
                    try:
                        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    except Exception as e:
                        print(f"Failed to run {cmd}: {e}", file=sys.stderr)
                elif value == 0 and code in pressed_keys:  # Key release
                    pressed_keys.discard(code)

            elif type == EV_SYN:
                pass  # Ignore SYN events

if __name__ == "__main__":
    main()
