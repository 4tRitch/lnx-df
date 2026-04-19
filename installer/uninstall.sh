#!/usr/bin/env bash
set -euo pipefail

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${INSTALLER_DIR}/lib/common.sh"
source "${INSTALLER_DIR}/lib/ui.sh"
source "${INSTALLER_DIR}/lib/components.sh"

NON_INTERACTIVE=0
ALL_COMPONENTS=0
SELECTED_COMPONENTS=()

join_by() {
  local separator=$1
  shift || true
  local first=1
  local item

  for item in "$@"; do
    if (( first )); then
      printf '%s' "$item"
      first=0
    else
      printf '%s%s' "$separator" "$item"
    fi
  done
}

component_label_list() {
  local labels=()
  local component

  for component in "$@"; do
    labels+=("$(component_label "$component")")
  done

  join_by ', ' "${labels[@]}"
}

uninstall_entries() {
  printf '%s|%s|%s\n' all 'All components' 'Attempt uninstall for every supported component'
  uninstall_component_entries
}

uninstall_prompt() {
  cat <<'EOF'
Uninstall workspace pieces

Remove linked configs or user-space tools managed by this installer. System packages stay conservative by design.
EOF
}

usage() {
  cat <<'EOF'
Usage: ./uninstall.sh [options]

Options:
  --all                Attempt uninstall for every supported component
  --component NAME     Uninstall one component; repeat as needed
  --dry-run            Print actions without changing the system
  --non-interactive    Do not prompt; requires --all or --component
  --list-components    Show supported component ids
  --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      ALL_COMPONENTS=1
      shift
      ;;
    --component)
      [[ $# -ge 2 ]] || { error "--component requires a value"; exit 1; }
      SELECTED_COMPONENTS+=("$2")
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --non-interactive)
      NON_INTERACTIVE=1
      shift
      ;;
    --list-components)
      list_components
      exit 0
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      error "unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if (( ALL_COMPONENTS )); then
  SELECTED_COMPONENTS=("${COMPONENT_IDS[@]}")
elif (( ${#SELECTED_COMPONENTS[@]} == 0 )); then
  if (( NON_INTERACTIVE )); then
    error "--non-interactive requires --all or at least one --component"
    exit 1
  fi

  mapfile -t AVAILABLE_ENTRIES < <(uninstall_entries)
  mapfile -t SELECTED_COMPONENTS < <(ui_select_many "$(uninstall_prompt)" "${AVAILABLE_ENTRIES[@]}")
fi

if printf '%s\n' "${SELECTED_COMPONENTS[@]}" | grep -qx all; then
  ALL_COMPONENTS=1
  SELECTED_COMPONENTS=("${COMPONENT_IDS[@]}")
fi

if (( ! ALL_COMPONENTS )); then
  mapfile -t SELECTED_COMPONENTS < <(normalize_component_list "${SELECTED_COMPONENTS[@]}")
fi

if (( ${#SELECTED_COMPONENTS[@]} == 0 )); then
  log "nothing selected"
  exit 0
fi

if (( ! NON_INTERACTIVE )) && ! ui_confirm "Proceed with uninstall for: $(component_label_list "${SELECTED_COMPONENTS[@]}")" cancel; then
  log "uninstall cancelled"
  exit 0
fi

for component in "${SELECTED_COMPONENTS[@]}"; do
  log "uninstalling $(component_label "$component")"
  uninstall_component "$component"
done

log "uninstall flow finished"
