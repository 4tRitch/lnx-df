#!/usr/bin/env bash
set -euo pipefail

emoji_url='https://www.unicode.org/Public/emoji/latest/emoji-test.txt'
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
data_dir="${script_dir%/scripts}/data"
target="${data_dir}/emoji-test.txt"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
lock_file="${runtime_dir}/lnx-df-emoji-data-update.lock"
stamp_file="${runtime_dir}/lnx-df-emoji-data-updated"

mkdir -p "$data_dir"

# Hyprland exec-once already runs this once per session. The stamp avoids duplicate
# work when the config is reloaded or the script is triggered manually during boot.
if [[ -e "$stamp_file" ]]; then
  exit 0
fi

(
  flock -n 9 || exit 0

  tmp_file="$(mktemp --tmpdir="${data_dir}" emoji-test.XXXXXX)"
  trap 'rm -f "$tmp_file"' EXIT

  if ! curl --fail --silent --show-error --location \
      --connect-timeout 4 --max-time 20 \
      --output "$tmp_file" "$emoji_url"; then
    exit 0
  fi

  if ! grep -q '^# emoji-test.txt' "$tmp_file" || ! grep -q '; fully-qualified' "$tmp_file"; then
    exit 0
  fi

  chmod 0644 "$tmp_file"
  mv "$tmp_file" "$target"
  : > "$stamp_file"
) 9>"$lock_file"
