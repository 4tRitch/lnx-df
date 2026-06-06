#!/usr/bin/env bash
set -euo pipefail

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
meta_dir="${data_home}/lnx-df-webapps/entries"

notify() {
  local title="$1" message="$2"
  command -v notify-send >/dev/null 2>&1 && notify-send "$title" "$message" || true
}

default_browser_command() {
  local desktop_file candidate

  if ! command -v xdg-settings >/dev/null 2>&1; then
    return 1
  fi

  desktop_file="$(xdg-settings get default-web-browser 2>/dev/null || true)"

  case "$desktop_file" in
    brave-browser.desktop) candidate="brave" ;;
    google-chrome.desktop|google-chrome-stable.desktop) candidate="google-chrome-stable" ;;
    chromium.desktop|org.chromium.Chromium.desktop) candidate="chromium" ;;
    microsoft-edge.desktop|microsoft-edge-stable.desktop) candidate="microsoft-edge-stable" ;;
    vivaldi.desktop|vivaldi-stable.desktop) candidate="vivaldi-stable" ;;
    *) return 1 ;;
  esac

  command -v "$candidate" >/dev/null 2>&1 || return 1
  printf '%s\n' "$candidate"
}

browser_command() {
  local candidate

  if [[ -n ${LNX_DF_WEBAPP_BROWSER:-} ]] && command -v "${LNX_DF_WEBAPP_BROWSER}" >/dev/null 2>&1; then
    printf '%s\n' "${LNX_DF_WEBAPP_BROWSER}"
    return 0
  fi

  if candidate="$(default_browser_command)"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  for candidate in brave chromium google-chrome-stable google-chrome microsoft-edge-stable vivaldi-stable firefox; do
    if command -v "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

launch() {
  local app_id="$1" meta_file browser

  meta_file="${meta_dir}/${app_id}.conf"
  [[ -f "$meta_file" ]] || {
    notify "WebApp" "No existe la definición para ${app_id}"
    exit 1
  }

  # shellcheck disable=SC1090
  source "$meta_file"

  browser="$(browser_command)" || {
    notify "WebApp" "No encontré un navegador compatible"
    exit 1
  }

  case "$browser" in
    brave|chromium|google-chrome-stable|google-chrome|microsoft-edge-stable|vivaldi-stable)
      exec "$browser" --new-window --class "$CLASS" "--app=$URL"
      ;;
    firefox)
      exec "$browser" --new-window "$URL"
      ;;
    *)
      exec "$browser" "$URL"
      ;;
  esac
}

main() {
  local app_id=

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id)
        [[ $# -ge 2 ]] || { echo "--id requiere un valor" >&2; exit 1; }
        app_id="$2"
        shift 2
        ;;
      *)
        echo "Uso: $0 --id APP_ID" >&2
        exit 1
        ;;
    esac
  done

  [[ -n "$app_id" ]] || { echo "Falta --id" >&2; exit 1; }
  launch "$app_id"
}

main "$@"
