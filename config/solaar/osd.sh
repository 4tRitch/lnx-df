#!/usr/bin/env bash
set -u

APP_NAME="Solaar"
VOLUME_REPLACE_ID=9910
MIC_REPLACE_ID=9911
PLAYER_REPLACE_ID=9912
FN_REPLACE_ID=9913
MAX_VOLUME=150

have() {
  command -v "$1" >/dev/null 2>&1
}

ensure_swayosd_server() {
  have swayosd-server || return 1
  pgrep -x swayosd-server >/dev/null 2>&1 && return 0
  nohup swayosd-server >/dev/null 2>&1 &
  sleep 0.15
  pgrep -x swayosd-server >/dev/null 2>&1
}

notify_progress() {
  local replace_id="$1"
  local icon="$2"
  local title="$3"
  local body="$4"
  local value="$5"

  notify-send \
    -a "$APP_NAME" \
    -r "$replace_id" \
    -h "string:x-canonical-private-synchronous:$replace_id" \
    -h "int:value:$value" \
    -i "$icon" \
    "$title" "$body"
}

notify_state() {
  local replace_id="$1"
  local icon="$2"
  local title="$3"
  local body="$4"

  notify-send \
    -a "$APP_NAME" \
    -r "$replace_id" \
    -h "string:x-canonical-private-synchronous:$replace_id" \
    -i "$icon" \
    "$title" "$body"
}

wpctl_percent() {
  local target="$1"
  local volume
  volume="$(wpctl get-volume "$target" 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i ~ /^[0-9.]+$/) { print $i; exit }}')"
  awk -v value="$volume" 'BEGIN {
    if (value == "") value = 0
    pct = int((value * 100) + 0.5)
    if (pct < 0) pct = 0
    if (pct > 150) pct = 150
    print pct
  }'
}

wpctl_is_muted() {
  local target="$1"
  wpctl get-volume "$target" 2>/dev/null | grep -q '\[MUTED\]'
}

show_output_volume_fallback() {
  local percent
  percent="$(wpctl_percent '@DEFAULT_AUDIO_SINK@')"

  if wpctl_is_muted '@DEFAULT_AUDIO_SINK@'; then
    notify_progress "$VOLUME_REPLACE_ID" "audio-volume-muted-symbolic" "Volumen" "Mute" 0
  else
    notify_progress "$VOLUME_REPLACE_ID" "audio-volume-high-symbolic" "Volumen" "${percent}%" "$percent"
  fi
}

show_input_volume_fallback() {
  local percent
  percent="$(wpctl_percent '@DEFAULT_AUDIO_SOURCE@')"

  if wpctl_is_muted '@DEFAULT_AUDIO_SOURCE@'; then
    notify_state "$MIC_REPLACE_ID" "microphone-disabled-symbolic" "Micrófono" "Silenciado"
  else
    notify_progress "$MIC_REPLACE_ID" "microphone-sensitivity-high-symbolic" "Micrófono" "Activo (${percent}%)" "$percent"
  fi
}

show_input_volume_osd() {
  if wpctl_is_muted '@DEFAULT_AUDIO_SOURCE@'; then
    swayosd-client       --custom-icon microphone-disabled-symbolic       --custom-message 'Micrófono silenciado' >/dev/null 2>&1
  else
    swayosd-client       --custom-icon microphone-sensitivity-high-symbolic       --custom-message 'Micrófono activado' >/dev/null 2>&1
  fi
}

volume_up() {
  if have swayosd-client && ensure_swayosd_server && swayosd-client --max-volume "$MAX_VOLUME" --output-volume +2 >/dev/null 2>&1; then
    return 0
  fi

  wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 0.02+
  show_output_volume_fallback
}

volume_down() {
  if have swayosd-client && ensure_swayosd_server && swayosd-client --max-volume "$MAX_VOLUME" --output-volume -2 >/dev/null 2>&1; then
    return 0
  fi

  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.02-
  show_output_volume_fallback
}

volume_mute_toggle() {
  if have swayosd-client && ensure_swayosd_server && swayosd-client --max-volume "$MAX_VOLUME" --output-volume mute-toggle >/dev/null 2>&1; then
    return 0
  fi

  wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
  show_output_volume_fallback
}

mic_mute_toggle() {
  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

  if have swayosd-client && ensure_swayosd_server; then
    show_input_volume_osd
    return 0
  fi

  show_input_volume_fallback
}

player_play_pause() {
  if have swayosd-client && ensure_swayosd_server && swayosd-client --playerctl play-pause >/dev/null 2>&1; then
    return 0
  fi

  playerctl play-pause
  local status
  status="$(playerctl status 2>/dev/null || true)"
  case "$status" in
    Playing) notify_state "$PLAYER_REPLACE_ID" "media-playback-start-symbolic" "Reproducción" "Playing" ;;
    Paused) notify_state "$PLAYER_REPLACE_ID" "media-playback-pause-symbolic" "Reproducción" "Paused" ;;
    *) playerctl metadata --format '{{artist}} — {{title}}' 2>/dev/null | xargs -r -I{} notify_state "$PLAYER_REPLACE_ID" "multimedia-player-symbolic" "Reproducción" '{}' ;;
  esac
}

fn_swap_message() {
  local icon="$1"
  local body="$2"
  if have swayosd-client && ensure_swayosd_server && swayosd-client --custom-icon "$icon" --custom-message "$body" >/dev/null 2>&1; then
    return 0
  fi

  notify_state "$FN_REPLACE_ID" "$icon" "Fn keys" "$body"
}

case "${1:-}" in
  volume-up) volume_up ;;
  volume-down) volume_down ;;
  volume-mute-toggle) volume_mute_toggle ;;
  mic-mute-toggle) mic_mute_toggle ;;
  play-pause) player_play_pause ;;
  fn-swap-message)
    shift
    fn_swap_message "$1" "$2"
    ;;
  *)
    echo "Usage: $0 {volume-up|volume-down|volume-mute-toggle|mic-mute-toggle|play-pause|fn-swap-message <text>}" >&2
    exit 1
    ;;
esac
