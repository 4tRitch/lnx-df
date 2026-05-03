#!/usr/bin/env bash
set -euo pipefail

keyboard_info() {
  hyprctl -j devices | python3 -c '
import json
import sys

data = json.load(sys.stdin)
keyboards = data.get("keyboards", [])
main = next((kb for kb in keyboards if kb.get("main") and not kb.get("name", "").startswith("hl-virtual-keyboard-fcitx5")), None)
if not main:
    filtered = [kb for kb in keyboards if not kb.get("name", "").startswith(("hl-virtual-keyboard-fcitx5", "power-button", "video-bus", "eee-pc-wmi-hotkeys"))]
    main = filtered[0] if filtered else None
if not main:
    main = keyboards[0] if keyboards else {}

print("\t".join([
    main.get("name", ""),
    str(main.get("active_layout_index", 0)),
    main.get("active_keymap", ""),
    main.get("layout", ""),
    main.get("variant", ""),
]))
'
}

ime_status() {
  if ! command -v fcitx5-remote >/dev/null 2>&1; then
    printf 'missing\n'
    return
  fi

  case "$(fcitx5-remote 2>/dev/null || true)" in
    2) printf 'active\n' ;;
    1) printf 'inactive\n' ;;
    0) printf 'offline\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

ime_name() {
  if ! command -v fcitx5-remote >/dev/null 2>&1; then
    printf 'missing\n'
    return
  fi

  fcitx5-remote -n 2>/dev/null || printf 'unknown\n'
}

ime_badge() {
  local ime name
  ime="$(ime_status)"
  name="$(ime_name)"

  case "$ime:$name" in
    active:*mozc*|active:*Mozc*|active:*keyboard-jp*) printf 'あ\n' ;;
    active:*) printf 'ON\n' ;;
    inactive:*|offline:*|unknown:*) printf 'A\n' ;;
    missing:*) printf '--\n' ;;
    *) printf '?\n' ;;
  esac
}

current_mode() {
  local ime name
  ime="$(ime_status)"
  name="$(ime_name)"

  case "$ime:$name" in
    active:*mozc*|active:*Mozc*|active:*keyboard-jp*) printf 'ja\n' ;;
    *) printf 'en\n' ;;
  esac
}

status() {
  local name index keymap layout variant text class tooltip ime ime_label mode
  IFS=$'\t' read -r name index keymap layout variant <<< "$(keyboard_info)"
  ime="$(ime_status)"
  ime_label="$(ime_badge)"
  mode="$(current_mode)"

  text='[EN]'
  class='en'

  if [[ "$mode" == 'ja' ]]; then
    text="[JA ${ime_label}]"
    class='jp'
  fi

  tooltip="$(printf 'Keyboard: %s\nPhysical layout: %s\nIME: %s\nClick: choose mode\nRight/Middle click: toggle IME\nDefault: English International' "$text" "$keymap" "$ime")"

  python3 - "$text" "$tooltip" "$class" <<'PY'
import json
import sys

print(json.dumps({"text": sys.argv[1], "tooltip": sys.argv[2], "class": sys.argv[3]}))
PY
}

set_english() {
  command -v fcitx5-remote >/dev/null 2>&1 || exit 0
  fcitx5-remote -s keyboard-us >/dev/null 2>&1 || true
  fcitx5-remote -c >/dev/null 2>&1 || true
}

set_japanese() {
  command -v fcitx5-remote >/dev/null 2>&1 || exit 0
  fcitx5-remote -s mozc >/dev/null 2>&1 || true
  fcitx5-remote -o >/dev/null 2>&1 || true
}

ime_toggle() {
  case "$(current_mode)" in
    ja) set_english ;;
    *) set_japanese ;;
  esac
}

menu() {
  local rows selection target ime mode

  ime="$(ime_status)"
  mode="$(current_mode)"

  rows="$(
    if [[ "$mode" == 'en' ]]; then
      printf '⌨  * English International\ten\n'
      printf 'あ  Japanese IME\tja\n'
    else
      printf '⌨  English International\ten\n'
      printf 'あ  * Japanese IME\tja\n'
    fi
    if [[ "$ime" != 'missing' ]]; then
      printf '󰌌  Toggle IME\time-toggle\n'
    fi
  )"

  selection="$(printf '%s' "$rows" | cut -f1 | rofi -dmenu -i -p 'keyboard' || true)"
  [[ -z "$selection" ]] && exit 0

  target="$(printf '%s' "$rows" | awk -F'\t' -v label="$selection" '$1 == label {print $2; exit}')"
  [[ -z "$target" ]] && exit 0

  if [[ "$target" == 'ime-toggle' ]]; then
    ime_toggle
    exit 0
  fi

  case "$target" in
    en) set_english ;;
    ja) set_japanese ;;
  esac
}

case "${1:---status}" in
  --status) status ;;
  --menu) menu ;;
  --cycle) ime_toggle ;;
  --ime-toggle) ime_toggle ;;
  --set-en) set_english ;;
  --set-jp) set_japanese ;;
  *) status ;;
esac
