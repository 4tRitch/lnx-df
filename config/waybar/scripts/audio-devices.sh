#!/usr/bin/env bash
set -euo pipefail

PREF_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/audio-preferences.env"

ensure_pulse() {
  for _ in {1..20}; do
    if pactl info >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  return 1
}

save_preference() {
  local key="$1" value="$2" sink source source_volume

  sink=""
  source=""
  source_volume=""

  if [[ -f "$PREF_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$PREF_FILE"
    sink="${PREFERRED_SINK:-}"
    source="${PREFERRED_SOURCE:-}"
    source_volume="${PREFERRED_SOURCE_VOLUME:-}"
  fi

  case "$key" in
    sink) sink="$value" ;;
    source) source="$value" ;;
  esac

  {
    printf 'PREFERRED_SINK=%q\n' "$sink"
    printf 'PREFERRED_SOURCE=%q\n' "$source"
    [[ -n "$source_volume" ]] && printf 'PREFERRED_SOURCE_VOLUME=%q\n' "$source_volume"
  } > "$PREF_FILE"
}

move_sink_inputs() {
  local sink="$1"
  pactl list short sink-inputs 2>/dev/null | cut -f1 | while read -r input; do
    [[ -n "$input" ]] && pactl move-sink-input "$input" "$sink" >/dev/null 2>&1 || true
  done
}

move_source_outputs() {
  local source="$1"
  pactl list short source-outputs 2>/dev/null | cut -f1 | while read -r output; do
    [[ -n "$output" ]] && pactl move-source-output "$output" "$source" >/dev/null 2>&1 || true
  done
}

set_sink() {
  local sink="$1"
  pactl set-default-sink "$sink"
  move_sink_inputs "$sink"
  save_preference sink "$sink"
}

set_source() {
  local source="$1"
  pactl set-default-source "$source"
  if [[ -f "$PREF_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$PREF_FILE"
    if [[ -n "${PREFERRED_SOURCE_VOLUME:-}" ]]; then
      pactl set-source-volume "$source" "$PREFERRED_SOURCE_VOLUME" >/dev/null 2>&1 || true
    fi
  fi
  move_source_outputs "$source"
  save_preference source "$source"
}

restore() {
  ensure_pulse || exit 0

  if [[ -f "$PREF_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$PREF_FILE"
  fi

  if [[ -n "${PREFERRED_SINK:-}" ]]; then
    pactl set-default-sink "$PREFERRED_SINK" >/dev/null 2>&1 || true
    move_sink_inputs "$PREFERRED_SINK"
  fi

  if [[ -n "${PREFERRED_SOURCE:-}" ]]; then
    pactl set-default-source "$PREFERRED_SOURCE" >/dev/null 2>&1 || true
    if [[ -n "${PREFERRED_SOURCE_VOLUME:-}" ]]; then
      pactl set-source-volume "$PREFERRED_SOURCE" "$PREFERRED_SOURCE_VOLUME" >/dev/null 2>&1 || true
    fi
    move_source_outputs "$PREFERRED_SOURCE"
  fi
}

list_sinks() {
  local default_sink
  default_sink="$(pactl get-default-sink 2>/dev/null || true)"

  pactl list sinks | awk -v default_sink="$default_sink" '
    /^Sink #/ { name=""; desc="" }
    /^[[:space:]]*Name:/ { name=$2 }
    /^[[:space:]]*Description:/ {
      sub(/^[[:space:]]*Description: /, "")
      desc=$0
      marker=(name == default_sink ? "*" : " ")
      printf "  %s %s\toutput\t%s\n", marker, desc, name
    }
  '
}

list_sources() {
  local default_source
  default_source="$(pactl get-default-source 2>/dev/null || true)"

  pactl list sources | awk -v default_source="$default_source" '
    /^Source #/ { name=""; desc=""; monitor=0 }
    /^[[:space:]]*Name:/ { name=$2; monitor=(name ~ /\.monitor$/) }
    /^[[:space:]]*Description:/ {
      sub(/^[[:space:]]*Description: /, "")
      desc=$0
      if (!monitor) {
        marker=(name == default_source ? "*" : " ")
        printf "  %s %s\tinput\t%s\n", marker, desc, name
      }
    }
  '
}

menu() {
  ensure_pulse || exit 0

  local rows selection kind node
  rows="$(list_sinks; list_sources)"

  selection="$(printf '%s\n' "$rows" | cut -f1 | rofi -dmenu -i -p 'audio device' || true)"
  [[ -z "$selection" ]] && exit 0

  kind="$(printf '%s\n' "$rows" | awk -F'\t' -v label="$selection" '$1 == label {print $2; exit}')"
  node="$(printf '%s\n' "$rows" | awk -F'\t' -v label="$selection" '$1 == label {print $3; exit}')"

  case "$kind" in
    output) set_sink "$node" ;;
    input) set_source "$node" ;;
  esac
}

case "${1:---menu}" in
  --menu) menu ;;
  --restore) restore ;;
  *) menu ;;
esac
