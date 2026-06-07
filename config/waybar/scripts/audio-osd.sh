#!/usr/bin/env bash
set -euo pipefail

target="${1:-output}"
action="${2:-}"
step="2%"

notify() {
  local title="$1"
  local body="$2"
  local value="${3:-}"
  if command -v notify-send >/dev/null 2>&1; then
    if [[ -n "$value" ]]; then
      notify-send -a 'Audio' -h 'string:x-canonical-private-synchronous:audio-osd' -h "int:value:${value}" "$title" "$body" >/dev/null 2>&1 || true
    else
      notify-send -a 'Audio' -h 'string:x-canonical-private-synchronous:audio-osd' "$title" "$body" >/dev/null 2>&1 || true
    fi
  fi
}

show_osd() {
  local kind="$1"
  local muted="$2"
  local percent="$3"
  local icon message

  if [[ "$kind" == "input" ]]; then
    if [[ "$muted" == "yes" ]]; then
      icon="microphone-sensitivity-muted-symbolic"
      message="Mic muted"
    else
      icon="microphone-sensitivity-high-symbolic"
      message="Mic unmuted"
    fi
  else
    if [[ "$muted" == "yes" ]]; then
      icon="audio-volume-muted-symbolic"
      message="Audio muted ${percent}%"
    elif (( percent >= 67 )); then
      icon="audio-volume-high-symbolic"
      message="Volume ${percent}%"
    elif (( percent >= 34 )); then
      icon="audio-volume-medium-symbolic"
      message="Volume ${percent}%"
    elif (( percent > 0 )); then
      icon="audio-volume-low-symbolic"
      message="Volume ${percent}%"
    else
      icon="audio-volume-muted-symbolic"
      message="Volume 0%"
    fi
  fi

  if command -v swayosd-client >/dev/null 2>&1; then
    if [[ "$kind" == "input" ]]; then
      swayosd-client \
        --custom-icon "$icon" \
        --custom-message "$message" >/dev/null 2>&1 || true
    else
      swayosd-client \
        --custom-icon "$icon" \
        --custom-progress "$(awk -v p="$percent" 'BEGIN { printf "%.2f", p / 100 }')" \
        --custom-progress-text "$message" >/dev/null 2>&1 || true
    fi
  else
    notify "$message" "" "$percent"
  fi
}

percent_from_pactl() {
  local kind="$1"
  if [[ "$kind" == "input" ]]; then
    pactl get-source-volume @DEFAULT_SOURCE@
  else
    pactl get-sink-volume @DEFAULT_SINK@
  fi | awk 'match($0, /[0-9]+%/) { value = substr($0, RSTART, RLENGTH); sub(/%/, "", value); print value; exit }'
}

mute_from_pactl() {
  local kind="$1"
  if [[ "$kind" == "input" ]]; then
    pactl get-source-mute @DEFAULT_SOURCE@
  else
    pactl get-sink-mute @DEFAULT_SINK@
  fi | awk '{ print $2 }'
}

case "$target:$action" in
  output:raise)
    wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
    wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ "$step"+
    ;;
  output:lower)
    wpctl set-volume @DEFAULT_AUDIO_SINK@ "$step"-
    ;;
  output:mute)
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    ;;
  input:mute)
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    ;;
  *)
    echo "Usage: $0 {output raise|output lower|output mute|input mute}" >&2
    exit 2
    ;;
esac

# Give PipeWire/Pulse a tiny moment to publish the new state before reading it.
sleep 0.03
percent="$(percent_from_pactl "$target")"
muted="$(mute_from_pactl "$target")"
show_osd "$target" "$muted" "${percent:-0}"
