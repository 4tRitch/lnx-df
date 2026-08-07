#!/usr/bin/env bash
# agent-status — self-heal heartbeat (runs every status-interval, prints NOTHING).
#
# It lives in status-right only so tmux re-runs it on each refresh; the agent
# state cue is shown by the per-tab state marker (window-status-format), so this script
# stays visually silent and the theme keeps the status-right (RAM/CPU/git).
#
# Self-heal: clears "blocked" on any pane in the window the user is CURRENTLY
# VIEWING. No hook fires when an agent's question/permission is cancelled, so the
# blocked state would otherwise stick forever — once a blocked pane is on-screen,
# the alert is delivered. A window's panes are all on-screen together, so a blocked
# BACKGROUND pane (not the active one) in the viewed window still poisons the tab
# rollup; healing the whole window clears it. (Caveat: a zoomed window shows only
# its active pane, so a zoomed-away blocked pane heals one navigation later.)
set -uo pipefail
command -v tmux >/dev/null 2>&1 || exit 0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

recompute_rollup() {
  local win="$1" worst=idle s
  while read -r s; do
    case "$s" in
      blocked) worst=blocked; break ;;
      working) [ "$worst" = idle ] && worst=working ;;
    esac
  done < <(tmux list-panes -t "$win" -F '#{@agent_state}' 2>/dev/null)
  tmux set -w -t "$win" @win_agent_state "$worst" 2>/dev/null
}

# --- Codex fallback sync ----------------------------------------------------
# Hooks only apply to Codex sessions that loaded/trusted them. Existing panes can
# still be visibly working without @agent_state. Inspect only the live viewport,
# never scrollback, so an old "Working (...)" line cannot revive stale state.
codex_tui_state() {
  local pane="$1" text
  text="$(tmux capture-pane -p -t "$pane" 2>/dev/null || true)"
  if printf '%s\n' "$text" | grep -Eq '(^|[[:space:]])Working \([0-9]'; then
    printf 'working'
  else
    printf 'idle'
  fi
}

while IFS=$'\t' read -r pid cmd wid st; do
  [ "$cmd" = "codex" ] || continue
  desired="$(codex_tui_state "$pid")"

  # Do not erase a real blocked marker just because the visible TUI fallback
  # cannot prove it. Navigation self-heal below owns blocked clearing.
  if [ "$st" = "blocked" ] && [ "$desired" = "idle" ]; then
    continue
  fi

  if [ "$desired" != "$st" ]; then
    # Route fallback transitions through agent-report instead of writing tmux
    # state directly. Otherwise the heartbeat can clear working -> idle before
    # Codex's Stop hook runs, which suppresses the done bell.
    if [ -x "$SCRIPT_DIR/agent-report.sh" ]; then
      AGENT_FALLBACK_SYNC=1 bash "$SCRIPT_DIR/agent-report.sh" "$pid" "$desired" "" >/dev/null 2>&1 || true
    else
      tmux set -p -t "$pid" @agent_state "$desired" 2>/dev/null || true
    fi
    recompute_rollup "$wid"
  fi
done < <(tmux list-panes -a -F '#{pane_id}'$'\t''#{pane_current_command}'$'\t''#{window_id}'$'\t''#{?#{@agent_state},#{@agent_state},idle}' 2>/dev/null)

# --- self-heal: clear blocked on every pane in the window(s) on screen right now ---
# Visibility = window is active AND its session is attached (NOT pane_active): every
# pane of the active window is on-screen, so a blocked background pane has been seen
# too and must be healed or it keeps the tab red.
while IFS=$'\t' read -r pid st vis wid; do
  if [ "$st" = "blocked" ] && [ "$vis" = "1" ]; then
    tmux set -p -t "$pid" @agent_state idle 2>/dev/null
    recompute_rollup "$wid"
  fi
# note: substitute empty @agent_state with "-" so empty fields don't collapse
# (tmux IFS tab-splitting merges consecutive tabs).
done < <(tmux list-panes -a -F '#{pane_id}'$'\t''#{?#{@agent_state},#{@agent_state},-}'$'\t''#{&&:#{window_active},#{session_attached}}'$'\t''#{window_id}' 2>/dev/null)

# No output: the per-tab state marker is the state cue; the theme keeps the status-right.
exit 0
