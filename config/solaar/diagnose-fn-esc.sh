#!/usr/bin/env bash
set -euo pipefail

DEVICE="MX Keys Mini for Business"
DURATION="${1:-12}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

read_state() {
  timeout 6s solaar config "$DEVICE" fn-swap 2>/dev/null | awk -F ' = ' '/^fn-swap/ {print $2; exit}'
}

printf '=== Fn+Esc diagnosis ===\n'
printf 'Duration: %ss\n\n' "$DURATION"

printf 'State before: %s\n' "$(read_state || echo unknown)"
printf 'Using devices: event8 event10 event11\n\n'

printf 'Press Fn+Esc TWO times now...\n\n'

sudo -v

for ev in 8 10 11; do
  timeout "$DURATION" sudo evtest "/dev/input/event${ev}" > "$TMPDIR/event${ev}.log" 2>&1 &
  pids+=("$!")
done

wait || true

printf '\nState after: %s\n\n' "$(read_state || echo unknown)"

for ev in 8 10 11; do
  printf '%s\n' "--- event${ev} ---"
  grep -E 'Event: time|KEY_|MSC_SCAN|SW_|SYN_' "$TMPDIR/event${ev}.log" || true
  printf '\n'
done
