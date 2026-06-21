#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
state_dir="${cache_home}/lnx-df"
state_file="${state_dir}/spicetify-applied.state"
spotify_root="${SPICETIFY_SPOTIFY_PATH:-${data_home}/spotify-launcher/install/usr/share/spotify}"

if [[ ! -d "${spotify_root}/Apps" && -d /opt/spotify/Apps ]]; then
  spotify_root="/opt/spotify"
fi

spotify_apps="${spotify_root}/Apps"
spotify_xpui="${spotify_apps}/xpui.spa"
spotify_xpui_dir="${spotify_apps}/xpui"

mkdir -p "$state_dir"

cleanup_stale_spotify_singleton() {
  local user_data="${cache_home}/spotify"
  [[ -e "${user_data}/SingletonLock" || -L "${user_data}/SingletonLock" ]] || return 0
  pgrep -x spotify >/dev/null 2>&1 && return 0

  rm -f \
    "${user_data}/SingletonLock" \
    "${user_data}/SingletonSocket" \
    "${user_data}/SingletonCookie"
}

apply_spicetify_if_needed() {
  command -v spicetify >/dev/null 2>&1 || return 0
  [[ -d "$spotify_apps" ]] || return 0

  spicetify config \
    spotify_path "${spotify_root%/}/" \
    prefs_path "${config_home}/spotify/prefs" \
    current_theme marketplace \
    custom_apps marketplace \
    inject_css 1 \
    replace_colors 1 \
    inject_theme_js 1 \
    expose_apis 1 \
    experimental_features 1 \
    home_config 1 >/dev/null 2>&1 || true

  local spotify_stamp spicetify_version desired_state current_state
  spotify_stamp="missing"
  if [[ -e "$spotify_xpui" ]]; then
    spotify_stamp="$(stat -c '%Y:%s' "$spotify_xpui" 2>/dev/null || printf missing)"
  elif [[ -d "$spotify_xpui_dir" ]]; then
    spotify_stamp="$(
      find "$spotify_xpui_dir" -maxdepth 1 -printf '%T@:%s:%p\n' 2>/dev/null |
        sort |
        sha256sum |
        awk '{print $1}'
    )"
  fi
  spicetify_version="$(spicetify -v 2>/dev/null || printf unknown)"
  desired_state="${spotify_root}|${spotify_stamp}|${spicetify_version}|marketplace"
  current_state=""
  [[ -f "$state_file" ]] && current_state="$(<"$state_file")"

  if [[ "$desired_state" != "$current_state" ]]; then
    spicetify backup apply -q >/dev/null 2>&1 || spicetify apply -q >/dev/null 2>&1 || true
    printf '%s\n' "$desired_state" > "$state_file"
  fi
}

cleanup_stale_spotify_singleton
apply_spicetify_if_needed
exec spotify-launcher "$@"
