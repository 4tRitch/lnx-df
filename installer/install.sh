#!/usr/bin/env bash
set -euo pipefail

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${INSTALLER_DIR}/lib/common.sh"
source "${INSTALLER_DIR}/lib/ui.sh"
source "${INSTALLER_DIR}/lib/components.sh"

summary_label() {
  local tone=$1
  local text=$2
  printf '%s' "$(paint "$tone" "$text")"
}

NON_INTERACTIVE=0
ALL_COMPONENTS=0
CHECKS_ONLY=0
RESUME_REQUESTED=0
STATE_RUN_INITIALIZED=0
SELECTED_COMPONENTS=()
SELECTED_PRESET=
INSTALL_SUCCEEDED_COMPONENTS=()
INSTALL_FAILED_COMPONENTS=()
SKIPPED_STEPS=()

state_resume_conflicts_with_options() {
  (( ALL_COMPONENTS )) || (( CHECKS_ONLY )) || [[ -n ${SELECTED_PRESET} ]] || (( ${#SELECTED_COMPONENTS[@]} > 0 ))
}

finalize_install_state() {
  local exit_code=$1

  if (( ! STATE_RUN_INITIALIZED )); then
    return 0
  fi

  if (( exit_code == 0 )); then
    clear_install_state
    return 0
  fi

  if [[ ${STATE_LAST_STATUS:-idle} != failed ]]; then
    mark_install_state_failed "${STATE_CURRENT_PHASE:-failed}" "${STATE_CURRENT_COMPONENT:-}"
  fi
}

build_pending_install_components() {
  local pending=()
  local component

  for component in "${SELECTED_COMPONENTS[@]}"; do
    if (( RESUME_REQUESTED )) && install_state_has_completed_install "$component"; then
      log "resume: skipping completed install for $(component_label "$component")"
      INSTALL_SUCCEEDED_COMPONENTS+=("$component")
      continue
    fi

    pending+=("$component")
  done

  printf '%s\n' "${pending[@]}"
}

build_pending_check_components() {
  local pending=()
  local component

  for component in "${SELECTED_COMPONENTS[@]}"; do
    if (( RESUME_REQUESTED )) && install_state_has_completed_check "$component"; then
      log "resume: skipping completed check for $(component_label "$component")"
      continue
    fi

    pending+=("$component")
  done

  printf '%s\n' "${pending[@]}"
}

trap 'finalize_install_state "$?"' EXIT

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

show_installer_text() {
  local title=$1
  local content=$2
  ui_show_text "$title" "$content"
}

run_ui_many() {
  local __target=$1
  shift
  local output

  output="$(ui_select_many "$@")" || return 1
  mapfile -t "$__target" <<<"$output"
}

interactive_home_prompt() {
  cat <<'EOF'
Workspace setup

Pick a path.
EOF
}

preset_prompt() {
  local mode_label=$1

  printf '%s\n\nChoose a preset, or use Custom to pick the exact tools.' "$mode_label"
}

component_prompt() {
  local mode_label=$1

  printf '%s\n\nPick the tools you want in this run.' "$mode_label"
}

interactive_action_menu() {
  local action_entries=(
    'install-preset|Install preset|Recommended stack'
    'install-custom|Pick components|Choose exact tools'
    'install-all|Install all|Full workspace bootstrap'
    'checks-preset|Check preset|Validate a stack'
    'checks-custom|Check components|Validate chosen tools'
    'checks-all|Check all|Full validation'
    'uninstall|Open uninstall|Remove linked items'
    'exit|Exit|Return to shell'
  )

  local action
  while true; do
    action="$(ui_select_one "$(interactive_home_prompt)" "${action_entries[@]}")" || return 1

    case "$action" in
      install-preset)
        while true; do
          mapfile -t PRESET_ENTRIES < <(preset_entries)
          SELECTED_PRESET="$(ui_select_one "$(preset_prompt 'Install preset')" "${PRESET_ENTRIES[@]}")" || continue 2
          [[ -n ${SELECTED_PRESET} ]] || continue 2
          if [[ ${SELECTED_PRESET} == custom ]]; then
            mapfile -t AVAILABLE_ENTRIES < <(component_entries)
            if run_ui_many SELECTED_COMPONENTS "$(component_prompt 'Install components')" "${AVAILABLE_ENTRIES[@]}"; then
              break 2
            fi
            continue
          fi
          break 2
        done
        ;;
      install-custom)
        SELECTED_PRESET=custom
        mapfile -t AVAILABLE_ENTRIES < <(component_entries)
        if ! run_ui_many SELECTED_COMPONENTS "$(component_prompt 'Install components')" "${AVAILABLE_ENTRIES[@]}"; then
          continue
        fi
        break
        ;;
      install-all)
        ALL_COMPONENTS=1
        break
        ;;
      checks-preset)
        CHECKS_ONLY=1
        while true; do
          mapfile -t PRESET_ENTRIES < <(preset_entries)
          SELECTED_PRESET="$(ui_select_one "$(preset_prompt 'Check preset')" "${PRESET_ENTRIES[@]}")" || continue 2
          [[ -n ${SELECTED_PRESET} ]] || continue 2
          if [[ ${SELECTED_PRESET} == custom ]]; then
            mapfile -t AVAILABLE_ENTRIES < <(component_entries)
            if run_ui_many SELECTED_COMPONENTS "$(component_prompt 'Check components')" "${AVAILABLE_ENTRIES[@]}"; then
              break 2
            fi
            continue
          fi
          break 2
        done
        ;;
      checks-custom)
        CHECKS_ONLY=1
        SELECTED_PRESET=custom
        mapfile -t AVAILABLE_ENTRIES < <(component_entries)
        if ! run_ui_many SELECTED_COMPONENTS "$(component_prompt 'Check components')" "${AVAILABLE_ENTRIES[@]}"; then
          continue
        fi
        break
        ;;
      checks-all)
        CHECKS_ONLY=1
        ALL_COMPONENTS=1
        break
        ;;
      uninstall)
        exec "${INSTALLER_DIR}/uninstall.sh"
        ;;
      exit|'')
        log "installer cancelled"
        return 1
        ;;
      *)
        warn "unknown installer action: ${action}"
        ;;
    esac
  done

  if ui_confirm 'Run this as a preview only (--dry-run)?'; then
    DRY_RUN=1
  fi

  return 0
}

print_final_summary() {
  local exit_code=$1
  local mode_label='Install'
  local next_steps=()

  if (( CHECKS_ONLY )); then
    mode_label='Checks'
  fi

  printf '\n%s %s summary\n' "$(summary_label soft '[lnx-df]')" "$mode_label"
  printf '%s preset: %s\n' "$(summary_label soft '[lnx-df]')" "${SELECTED_PRESET:-custom/manual}"
  printf '%s components: %s\n' "$(summary_label soft '[lnx-df]')" "$(component_label_list "${SELECTED_COMPONENTS[@]}")"

  if (( ! CHECKS_ONLY )); then
    printf '%s install successes: %d\n' "$(summary_label success '[lnx-df]')" "${#INSTALL_SUCCEEDED_COMPONENTS[@]}"
    if (( ${#INSTALL_SUCCEEDED_COMPONENTS[@]} > 0 )); then
      printf '[lnx-df] installed/already present: %s\n' "$(component_label_list "${INSTALL_SUCCEEDED_COMPONENTS[@]}")"
    fi

    printf '%s install failures: %d\n' "$(summary_label error '[lnx-df]')" "${#INSTALL_FAILED_COMPONENTS[@]}"
    if (( ${#INSTALL_FAILED_COMPONENTS[@]} > 0 )); then
      printf '[lnx-df] failed installs: %s\n' "$(component_label_list "${INSTALL_FAILED_COMPONENTS[@]}")"
      next_steps+=("review the failed install logs and rerun the affected components")
      next_steps+=("resume this run with ./install.sh --resume once the blocking issue is fixed")
    fi
  fi

  printf '%s checks passed: %d\n' "$(summary_label success '[lnx-df]')" "${#CHECK_PASSED_COMPONENTS[@]}"
  if (( ${#CHECK_PASSED_COMPONENTS[@]} > 0 )); then
    printf '[lnx-df] passed checks: %s\n' "$(component_label_list "${CHECK_PASSED_COMPONENTS[@]}")"
  fi

  printf '%s checks failed: %d\n' "$(summary_label error '[lnx-df]')" "${#CHECK_FAILED_COMPONENTS[@]}"
  if (( ${#CHECK_FAILED_COMPONENTS[@]} > 0 )); then
    printf '[lnx-df] failed checks: %s\n' "$(component_label_list "${CHECK_FAILED_COMPONENTS[@]}")"
    next_steps+=("rerun checks with ./install.sh --checks-only and the same preset/components after addressing the failures")
    next_steps+=("or continue the saved run with ./install.sh --resume if you want to keep the previous progress")
  fi

  if (( ${#SKIPPED_STEPS[@]} > 0 )); then
    printf '%s skipped: %s\n' "$(summary_label warning '[lnx-df]')" "$(join_by '; ' "${SKIPPED_STEPS[@]}")"
  fi

  if (( ${#PATH_RELOAD_REQUIRED_DIRS[@]} > 0 )); then
    printf '%s shell reload needed: %s\n' "$(summary_label warning '[lnx-df]')" "$(join_by ', ' "${PATH_RELOAD_REQUIRED_DIRS[@]}")"
    next_steps+=("reload your shell or open a new terminal so those PATH updates apply outside this installer run")
  fi

  if (( ${#PATH_PERSISTENCE_MISSING_DIRS[@]} > 0 )); then
    printf '%s shell config updates needed: %s\n' "$(summary_label warning '[lnx-df]')" "$(join_by ', ' "${PATH_PERSISTENCE_MISSING_DIRS[@]}")"
    next_steps+=("add those directories to ~/.profile, ~/.bashrc, ~/.bash_profile, ~/.zprofile, or ~/.zshrc before relying on them in future shells")
  fi

  if (( DRY_RUN )); then
    next_steps+=("rerun without --dry-run to apply the changes")
  fi

  if (( ${#next_steps[@]} > 0 )); then
    printf '%s next steps:\n' "$(summary_label soft '[lnx-df]')"
    local step
    for step in "${next_steps[@]}"; do
      printf '%s   - %s\n' "$(summary_label soft '[lnx-df]')" "$step"
    done
  fi

  if (( exit_code == 0 )); then
    printf '%s result: success\n' "$(summary_label success '[lnx-df]')"
  else
    printf '%s result: completed with issues\n' "$(summary_label warning '[lnx-df]')"
  fi
}

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --all                Install every supported component
  --preset NAME        Install a preset: basic, dev, gamedev, full, custom
  --component NAME     Install one component; repeat as needed
  --checks-only        Skip installation and run checks only
  --resume             Resume the last interrupted run
  --dry-run            Print actions without changing the system
  --non-interactive    Do not prompt; requires --all, --preset, or --component
  --list-components    Show supported component ids
  --list-presets       Show supported preset ids
  --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      ALL_COMPONENTS=1
      shift
      ;;
    --preset)
      [[ $# -ge 2 ]] || { error "--preset requires a value"; exit 1; }
      SELECTED_PRESET=$2
      shift 2
      ;;
    --component)
      [[ $# -ge 2 ]] || { error "--component requires a value"; exit 1; }
      SELECTED_COMPONENTS+=("$2")
      shift 2
      ;;
    --checks-only)
      CHECKS_ONLY=1
      shift
      ;;
    --resume)
      RESUME_REQUESTED=1
      shift
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
    --list-presets)
      list_presets
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

load_platform_info
log "platform: $(describe_platform)"

if (( RESUME_REQUESTED )) && state_resume_conflicts_with_options; then
  error "--resume cannot be combined with --all, --preset, --component, or --checks-only"
  exit 1
fi

if (( RESUME_REQUESTED )); then
  if ! load_install_state; then
    error "no saved installer state found at ${INSTALL_STATE_FILE}"
    exit 1
  fi

  RESUME_FROM_PHASE=${STATE_CURRENT_PHASE}
  RESUME_FROM_COMPONENT=${STATE_CURRENT_COMPONENT}

  SELECTED_PRESET=${STATE_SELECTED_PRESET}
  SELECTED_COMPONENTS=("${STATE_SELECTED_COMPONENTS[@]}")
  CHECKS_ONLY=${STATE_CHECKS_ONLY}
  ALL_COMPONENTS=${STATE_ALL_COMPONENTS}
  resume_install_state_run
  STATE_RUN_INITIALIZED=1

  log "resuming previous installer run"
  if [[ -n ${RESUME_FROM_COMPONENT} ]]; then
    log "last saved step: ${RESUME_FROM_PHASE} (${RESUME_FROM_COMPONENT})"
  else
    log "last saved step: ${RESUME_FROM_PHASE}"
  fi
fi

if (( ! RESUME_REQUESTED )) && (( ! ALL_COMPONENTS )) && (( ${#SELECTED_COMPONENTS[@]} == 0 )) && [[ -z ${SELECTED_PRESET} ]] && (( ! NON_INTERACTIVE )); then
  ui_prepare_backend
  interactive_action_menu || exit 0
fi

if [[ -n ${SELECTED_PRESET} ]]; then
  if [[ ${SELECTED_PRESET} == custom ]]; then
    :
  else
    mapfile -t PRESET_COMPONENTS < <(preset_components "$SELECTED_PRESET") || exit 1
    SELECTED_COMPONENTS+=("${PRESET_COMPONENTS[@]}")
  fi
fi

if (( ALL_COMPONENTS )); then
  SELECTED_COMPONENTS=("${COMPONENT_IDS[@]}")
elif (( ${#SELECTED_COMPONENTS[@]} == 0 )); then
  if (( NON_INTERACTIVE )); then
    error "--non-interactive requires --all, --preset, or at least one --component"
    exit 1
  fi

  if (( CHECKS_ONLY )); then
    mapfile -t PRESET_ENTRIES < <(preset_entries)
    SELECTED_PRESET="$(ui_select_one "$(preset_prompt 'Check preset')" "${PRESET_ENTRIES[@]}")"

    if [[ -n ${SELECTED_PRESET} && ${SELECTED_PRESET} != custom ]]; then
      mapfile -t SELECTED_COMPONENTS < <(preset_components "$SELECTED_PRESET")
    else
      mapfile -t AVAILABLE_ENTRIES < <(component_entries)
      mapfile -t SELECTED_COMPONENTS < <(ui_select_many "$(component_prompt 'Check components')" "${AVAILABLE_ENTRIES[@]}")
    fi
  else
    mapfile -t PRESET_ENTRIES < <(preset_entries)
    SELECTED_PRESET="$(ui_select_one "$(preset_prompt 'Install preset')" "${PRESET_ENTRIES[@]}")"

    if [[ -n ${SELECTED_PRESET} && ${SELECTED_PRESET} != custom ]]; then
      mapfile -t SELECTED_COMPONENTS < <(preset_components "$SELECTED_PRESET")
    else
      mapfile -t AVAILABLE_ENTRIES < <(component_entries)
      mapfile -t SELECTED_COMPONENTS < <(ui_select_many "$(component_prompt 'Install components')" "${AVAILABLE_ENTRIES[@]}")
    fi
  fi
fi

mapfile -t SELECTED_COMPONENTS < <(normalize_component_list "${SELECTED_COMPONENTS[@]}")

if (( ${#SELECTED_COMPONENTS[@]} == 0 )); then
  log "nothing selected"
  exit 0
fi

if printf '%s\n' "${SELECTED_COMPONENTS[@]}" | grep -qx python; then
  select_python_versions
fi

log "repo root: ${REPO_ROOT}"
log "selected components: ${SELECTED_COMPONENTS[*]}"
if [[ -n ${SELECTED_PRESET} ]]; then
  log "selected preset: ${SELECTED_PRESET}"
fi

if (( ! STATE_RUN_INITIALIZED )); then
  start_install_state_run "$CHECKS_ONLY" "$ALL_COMPONENTS" "$SELECTED_PRESET" "${SELECTED_COMPONENTS[@]}"
  STATE_RUN_INITIALIZED=1
fi

if (( CHECKS_ONLY )); then
  mapfile -t PENDING_CHECK_COMPONENTS < <(build_pending_check_components)

  if (( ${#PENDING_CHECK_COMPONENTS[@]} > 0 )); then
    if ! run_component_checks "${PENDING_CHECK_COMPONENTS[@]}"; then
      mark_install_state_failed checks
    fi
  else
    CHECK_PASSED_COMPONENTS=()
    log "resume: all requested checks were already completed"
  fi

  if (( RESUME_REQUESTED )); then
    local_component=
    for local_component in "${STATE_COMPLETED_CHECK_COMPONENTS[@]}"; do
      if state_array_contains "$local_component" "${SELECTED_COMPONENTS[@]}" && ! state_array_contains "$local_component" "${CHECK_PASSED_COMPONENTS[@]}"; then
        CHECK_PASSED_COMPONENTS+=("$local_component")
      fi
    done
  fi

  EXIT_CODE=0
  if (( ${#CHECK_FAILED_COMPONENTS[@]} > 0 )); then
    EXIT_CODE=1
  fi
  print_final_summary "$EXIT_CODE"
  exit "$EXIT_CODE"
fi

mapfile -t PENDING_INSTALL_COMPONENTS < <(build_pending_install_components)

for component in "${PENDING_INSTALL_COMPONENTS[@]}"; do
  set_install_state_phase install "$component"
  log "installing $(component_label "$component")"
  if install_component "$component"; then
    INSTALL_SUCCEEDED_COMPONENTS+=("$component")
    mark_install_state_install_completed "$component"
  else
    INSTALL_FAILED_COMPONENTS+=("$component")
    mark_install_state_failed install "$component"
  fi
done

EXIT_CODE=0

if (( DRY_RUN )); then
  log "dry-run enabled; skipping post-install checks"
  SKIPPED_STEPS+=("post-install checks")
else
  mapfile -t PENDING_CHECK_COMPONENTS < <(build_pending_check_components)

  if (( ${#PENDING_CHECK_COMPONENTS[@]} > 0 )); then
    if ! run_component_checks "${PENDING_CHECK_COMPONENTS[@]}"; then
      mark_install_state_failed checks
    fi
  else
    CHECK_PASSED_COMPONENTS=()
    log "resume: all requested checks were already completed"
  fi

  if (( RESUME_REQUESTED )); then
    for component in "${STATE_COMPLETED_CHECK_COMPONENTS[@]}"; do
      if state_array_contains "$component" "${SELECTED_COMPONENTS[@]}" && ! state_array_contains "$component" "${CHECK_PASSED_COMPONENTS[@]}"; then
        CHECK_PASSED_COMPONENTS+=("$component")
      fi
    done
  fi
  if (( ${#CHECK_FAILED_COMPONENTS[@]} > 0 )); then
    EXIT_CODE=1
  fi
fi

if (( ${#INSTALL_FAILED_COMPONENTS[@]} > 0 )); then
  EXIT_CODE=1
fi

log "install flow finished"
set_install_state_phase completed
print_final_summary "$EXIT_CODE"
exit "$EXIT_CODE"
