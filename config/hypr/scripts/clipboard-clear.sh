#!/usr/bin/env bash
set -euo pipefail

notify_ok() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a 'Clipboard' 'Clipboard cleared' 'Se limpió todo el historial de clipse.'
    return
  fi

  hyprctl notify 1 2500 'rgb(a6e3a1)' 'Clipboard history cleared'
}

notify_error() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a 'Clipboard' 'Clipboard error' 'clipse no está instalado.'
    return
  fi

  hyprctl notify 1 3500 'rgb(ff6666)' 'clipse is not installed'
}

if ! command -v clipse >/dev/null 2>&1; then
  notify_error
  exit 1
fi

clipse -clear-all >/dev/null 2>&1
notify_ok
