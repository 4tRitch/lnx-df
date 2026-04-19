#!/usr/bin/env bash

UI_TITLE='lnx-df'
UI_MENU_TITLE='lnx-df'
UI_SUBTITLE='Workspace installer'
UI_HINT='Up/Down, Enter, Esc, Ctrl+C.'
UI_GUM_ACCENT=252
UI_GUM_MUTED=245
UI_GUM_BORDER=240
UI_GUM_SELECTED=255

ui_gum_path() {
  if command_exists gum; then
    command -v gum
    return 0
  fi

  local candidate
  local candidates=(
    "$(install_user_bin_dir)/gum"
    "${INSTALL_USER_HOME}/go/bin/gum"
    "/home/linuxbrew/.linuxbrew/bin/gum"
    "/usr/local/bin/gum"
    "/usr/bin/gum"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -x ${candidate} ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

ui_has_gum() {
  ui_gum_path >/dev/null 2>&1
}

ui_run_gum() {
  local gum_cmd
  gum_cmd="$(ui_gum_path)" || return 1
  "$gum_cmd" "$@"
}

ui_wants_gum_backend() {
  case "${LNX_DF_UI_MODE:-auto}" in
    auto|gum|'') return 0 ;;
    *) return 1 ;;
  esac
}

ui_gum_release_arch() {
  local machine
  machine="$(uname -m 2>/dev/null || true)"

  case "$machine" in
    x86_64|amd64) printf 'x86_64\n' ;;
    aarch64|arm64) printf 'arm64\n' ;;
    armv7l|armv7) printf 'armv7\n' ;;
    i386|i686) printf 'i386\n' ;;
    *) return 1 ;;
  esac
}

install_gum_binary_release() {
  require_install_user_context 'gum installation' || return 1

  if (( DRY_RUN )); then
    log "dry-run: install gum binary to $(install_user_bin_dir)/gum"
    return 0
  fi

  if ! command_exists curl; then
    install_package_key curl-runtime || return 1
  fi

  if ! command_exists tar; then
    warn "tar is required to install gum binary"
    return 1
  fi

  local arch
  arch="$(ui_gum_release_arch 2>/dev/null || true)"
  if [[ -z ${arch} ]]; then
    warn "unsupported architecture for gum binary install: $(uname -m 2>/dev/null || printf 'unknown')"
    return 1
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local version_url="https://github.com/charmbracelet/gum/releases/latest"
  local release_url
  local version
  local archive_name
  local archive_path
  local extract_dir
  local extracted_gum=

  release_url="$(curl --connect-timeout 15 --max-time 60 -fsSLI -o /dev/null -w '%{url_effective}' "$version_url" 2>/dev/null || true)"
  version="${release_url##*/}"
  if [[ -z ${version} || ${version} == latest ]]; then
    warn "failed to resolve latest gum release"
    rm -rf "$tmp_dir"
    return 1
  fi

  archive_name="gum_${version#v}_Linux_${arch}.tar.gz"
  archive_path="${tmp_dir}/${archive_name}"
  extract_dir="${tmp_dir}/extract"

  if ! curl_download "https://github.com/charmbracelet/gum/releases/download/${version}/${archive_name}" "$archive_path"; then
    rm -rf "$tmp_dir"
    return 1
  fi

  run_cmd mkdir -p "$extract_dir"
  run_cmd tar -xzf "$archive_path" -C "$extract_dir" || {
    run_cmd rm -rf "$tmp_dir"
    return 1
  }

  local candidate
  for candidate in "${extract_dir}/gum" "${extract_dir}"/*/gum "${extract_dir}"/*/*/gum; do
    if [[ -x ${candidate} ]]; then
      extracted_gum=$candidate
      break
    fi
  done

  if [[ -z ${extracted_gum} ]]; then
    warn "downloaded gum archive did not contain the gum binary"
    run_cmd rm -rf "$tmp_dir"
    return 1
  fi

  if [[ -n ${SUDO_USER:-} ]]; then
    HOME="$INSTALL_USER_HOME" sudo -u "$SUDO_USER" mkdir -p "$(install_user_bin_dir)"
    HOME="$INSTALL_USER_HOME" sudo -u "$SUDO_USER" install -m 0755 "$extracted_gum" "$(install_user_bin_dir)/gum" || {
      run_cmd rm -rf "$tmp_dir"
      return 1
    }
  else
    ensure_parent_dir "$(install_user_bin_dir)/gum"
    run_cmd install -m 0755 "$extracted_gum" "$(install_user_bin_dir)/gum" || {
      run_cmd rm -rf "$tmp_dir"
      return 1
    }
  fi

  run_cmd rm -rf "$tmp_dir"
  prepend_path_once "$(install_user_bin_dir)"
  ensure_user_tool_path_persisted "$(install_user_bin_dir)" || true

  if ! ui_has_gum; then
    warn "gum binary install completed but gum is still unavailable"
    return 1
  fi

  return 0
}

install_gum_for_ui() {
  if ui_has_gum; then
    return 0
  fi

  log "bootstrapping gum for interactive UI"

  if install_gum_binary_release; then
    return 0
  fi

  if (( EUID == 0 )); then
    if install_package_key_first_available gum-ui 2>/dev/null; then
      return 0
    fi
  elif command_exists sudo && sudo -n true >/dev/null 2>&1; then
    if install_package_key_first_available gum-ui 2>/dev/null; then
      return 0
    fi
  fi

  return 1
}

ui_prepare_backend() {
  if ! ui_wants_gum_backend; then
    return 0
  fi

  if ui_has_gum; then
    return 0
  fi

  if ! ui_has_tty; then
    return 0
  fi

  if ! install_gum_for_ui; then
    warn "gum bootstrap failed; falling back to plain UI"
    return 0
  fi
}

ui_backend() {
  case "${LNX_DF_UI_MODE:-auto}" in
    gum|whiptail|dialog|plain)
      if [[ ${LNX_DF_UI_MODE} == gum ]] && ! ui_has_gum; then
        printf 'plain\n'
      else
        printf '%s\n' "${LNX_DF_UI_MODE}"
      fi
      ;;
    auto|'')
      if ui_has_gum; then
        printf 'gum\n'
      else
        printf 'plain\n'
      fi
      ;;
    *)
      printf 'plain\n'
      ;;
  esac
}

ui_trim() {
  local value=$1

  value=${value#"${value%%[![:space:]]*}"}
  value=${value%"${value##*[![:space:]]}"}
  printf '%s' "$value"
}

ui_option_text() {
  local label=$1
  local description=$2

  if [[ -n $description ]]; then
    printf '%s  %s' "$label" "$description"
  else
    printf '%s' "$label"
  fi
}

ui_plain_banner() {
  local prompt=$1

  printf '\nlnx-df\n' >&2
  printf '%s\n' "$UI_SUBTITLE" >&2
  printf '\n%s\n' "$prompt" >&2
}

ui_plain_footer() {
  local message=$1

  [[ -n $message ]] || return 0
  printf '\n%s\n' "$message" >&2
}

ui_has_tty() {
  [[ -r /dev/tty && -w /dev/tty ]]
}

ui_plain_read_key() {
  local key=
  local rest=

  if ! IFS= read -rsn1 key </dev/tty; then
    return 1
  fi

  if [[ -z $key ]]; then
    REPLY=$'\n'
    return 0
  fi

  if [[ $key == $'\e' ]]; then
    if IFS= read -rsn2 -t 0.05 rest </dev/tty; then
      key+="$rest"
    fi
  fi

  REPLY=$key
}

ui_plain_render_menu() {
  local prompt=$1
  local selected_index=$2
  shift 2
  local entries=("$@")
  local entry_index=0
  local entry
  local id
  local label
  local description

  ui_plain_banner "$prompt"
  printf '\nUse Up/Down and Enter to select, Esc to cancel.\n' >&2

  for entry in "${entries[@]}"; do
    IFS='|' read -r id label description _ <<<"$entry"
    if (( entry_index == selected_index )); then
      printf '  > %2d  %-14s %-18s %s\n' "$((entry_index + 1))" "$id" "$label" "$description" >&2
    else
      printf '    %2d  %-14s %-18s %s\n' "$((entry_index + 1))" "$id" "$label" "$description" >&2
    fi
    entry_index=$((entry_index + 1))
  done

  printf '\nSelection > ' >&2
}

ui_plain_redraw_menu_options() {
  local selected_index=$1
  shift
  local entries=("$@")
  local entry_index=0
  local entry
  local id
  local label
  local description
  local lines_up=$((${#entries[@]} + 1))

  printf '\033[%dA' "$lines_up" >&2

  for entry in "${entries[@]}"; do
    IFS='|' read -r id label description _ <<<"$entry"
    printf '\r\033[2K' >&2
    if (( entry_index == selected_index )); then
      printf '  > %2d  %-14s %-18s %s\n' "$((entry_index + 1))" "$id" "$label" "$description" >&2
    else
      printf '    %2d  %-14s %-18s %s\n' "$((entry_index + 1))" "$id" "$label" "$description" >&2
    fi
    entry_index=$((entry_index + 1))
  done

  printf '\r\033[2K\n' >&2
  printf '\r\033[2KSelection > ' >&2
}

ui_plain_select_one_interactive() {
  local prompt=$1
  shift
  local entries=("$@")
  local selected_index=0
  local key
  local answer
  local normalized
  local first_render=1

  while true; do
    if (( first_render )); then
      printf '\033[H\033[J\033[?25l' >&2
      ui_plain_render_menu "$prompt" "$selected_index" "${entries[@]}"
      first_render=0
    else
      ui_plain_redraw_menu_options "$selected_index" "${entries[@]}"
    fi

    if ! ui_plain_read_key; then
      printf '\033[?25h\n' >&2
      return 1
    fi
    key=$REPLY

    case "$key" in
      $'\e')
        printf '\033[?25h\n' >&2
        return 1
        ;;
      $'\e[A'|$'\e[D')
        if (( selected_index > 0 )); then
          selected_index=$((selected_index - 1))
        else
          selected_index=$((${#entries[@]} - 1))
        fi
        ;;
      $'\e[B'|$'\e[C')
        selected_index=$(((selected_index + 1) % ${#entries[@]}))
        ;;
      $'\n'|$'\r')
        printf '\033[?25h\n' >&2
        printf '%s\n' "${entries[$selected_index]%%|*}"
        return 0
        ;;
      [[:print:]])
        answer=$key
        if IFS= read -r normalized </dev/tty; then
          answer+="$normalized"
        fi
        answer=$(ui_trim "$answer")

        if [[ $answer =~ ^[0-9]+$ ]]; then
          local idx=$((answer - 1))
          if (( idx >= 0 && idx < ${#entries[@]} )); then
            printf '%s\n' "${entries[$idx]%%|*}"
            printf '\033[?25h\n' >&2
            return 0
          fi
        fi

        for entry in "${entries[@]}"; do
          if [[ ${entry%%|*} == "$answer" ]]; then
            printf '\033[?25h\n' >&2
            printf '%s\n' "${entry%%|*}"
            return 0
          fi
        done

        for entry in "${entries[@]}"; do
          IFS='|' read -r id label description _ <<<"$entry"
          if [[ $id == "$answer" || $(ui_option_text "$label" "$description") == "$answer" ]]; then
            printf '\033[?25h\n' >&2
            printf '%s\n' "$id"
            return 0
          fi
        done

        warn "unknown selection: ${answer}"
        ;;
      *)
        answer=$key
        if IFS= read -r normalized </dev/tty; then
          answer+="$normalized"
        fi
        answer=$(ui_trim "$answer")
        printf '\033[?25h\n' >&2
        printf '%s\n' "$answer"
        return 0
        ;;
    esac
  done
}

ui_plain_select_one_line() {
  local prompt=$1
  shift
  local entries=("$@")

  ui_plain_banner "$prompt"
  printf '\nAvailable\n' >&2
  ui_show_plain_options "${entries[@]}"
  ui_plain_footer 'Choose one item. Use the number for speed, or type the id directly. Esc cancels.'
  printf '\nChoice > ' >&2

  local answer
  if ! read -r answer </dev/tty; then
    return 1
  fi

  if [[ -z $answer ]]; then
    return 0
  fi

  if [[ $answer =~ ^[0-9]+$ ]]; then
    local idx=$((answer - 1))
    if (( idx >= 0 && idx < ${#entries[@]} )); then
      printf '%s\n' "${entries[$idx]%%|*}"
    fi
    return 0
  fi

  printf '%s\n' "$answer"
}

ui_plain_select_many_line() {
  local prompt=$1
  shift
  local entries=("$@")

  ui_plain_banner "$prompt"
  printf '\nAvailable\n' >&2
  ui_show_plain_options "${entries[@]}"
  ui_plain_footer 'Choose one or more items. Use numbers or ids separated by commas, or type all. Esc cancels.'
  printf '\nSelection > ' >&2

  local answer=

  if ui_has_tty; then
    local key

    if ! ui_plain_read_key; then
      return 1
    fi

    case "$REPLY" in
      $'\e') return 1 ;;
      $'\n'|$'\r') return 0 ;;
      *)
        answer=$REPLY
        if IFS= read -r key; then
          answer+="$key"
        fi
        ;;
    esac
  else
    if ! read -r answer </dev/tty; then
      return 1
    fi
  fi

  if [[ -z $answer ]]; then
    return 0
  fi

  if [[ $answer == all ]]; then
    for entry in "${entries[@]}"; do
      printf '%s\n' "${entry%%|*}"
    done
    return 0
  fi

  local token
  IFS=',' read -r -a token_list <<<"$answer"
  for token in "${token_list[@]}"; do
    token="$(ui_trim "$token")"
    if [[ $token =~ ^[0-9]+$ ]]; then
      local idx=$((token - 1))
      if (( idx >= 0 && idx < ${#entries[@]} )); then
        printf '%s\n' "${entries[$idx]%%|*}"
      fi
      continue
    fi

    printf '%s\n' "$token"
  done
}

ui_plain_render_many_menu() {
  local prompt=$1
  local selected_index=$2
  local checked_name=$3
  shift 3
  local entries=("$@")
  local -n checked_ref="$checked_name"
  local entry_index=0
  local entry
  local id
  local label
  local description
  local mark

  ui_plain_banner "$prompt"
  printf '\nUse Up/Down to move, Space to toggle, Enter to confirm, Esc to cancel.\n' >&2

  for entry in "${entries[@]}"; do
    IFS='|' read -r id label description _ <<<"$entry"
    mark='[ ]'
    if [[ ${checked_ref[$entry_index]:-0} -eq 1 ]]; then
      mark='[x]'
    fi

    if (( entry_index == selected_index )); then
      printf '  > %s %2d  %-14s %-18s %s\n' "$mark" "$((entry_index + 1))" "$id" "$label" "$description" >&2
    else
      printf '    %s %2d  %-14s %-18s %s\n' "$mark" "$((entry_index + 1))" "$id" "$label" "$description" >&2
    fi
    entry_index=$((entry_index + 1))
  done

  printf '\nSelection > ' >&2
}

ui_plain_redraw_many_menu() {
  local selected_index=$1
  local checked_name=$2
  shift 2
  local entries=("$@")
  local -n checked_ref="$checked_name"
  local entry_index=0
  local entry
  local id
  local label
  local description
  local mark
  local lines_up=$((${#entries[@]} + 1))

  printf '\033[%dA' "$lines_up" >&2

  for entry in "${entries[@]}"; do
    IFS='|' read -r id label description _ <<<"$entry"
    mark='[ ]'
    if [[ ${checked_ref[$entry_index]:-0} -eq 1 ]]; then
      mark='[x]'
    fi

    printf '\r\033[2K' >&2
    if (( entry_index == selected_index )); then
      printf '  > %s %2d  %-14s %-18s %s\n' "$mark" "$((entry_index + 1))" "$id" "$label" "$description" >&2
    else
      printf '    %s %2d  %-14s %-18s %s\n' "$mark" "$((entry_index + 1))" "$id" "$label" "$description" >&2
    fi
    entry_index=$((entry_index + 1))
  done

  printf '\r\033[2K\n' >&2
  printf '\r\033[2KSelection > ' >&2
}

ui_plain_select_many_interactive() {
  local prompt=$1
  shift
  local entries=("$@")
  local selected_index=0
  local first_render=1
  local key
  local idx
  local checked=()

  for ((idx=0; idx<${#entries[@]}; idx++)); do
    checked+=(0)
  done

  while true; do
    if (( first_render )); then
      printf '\033[H\033[J\033[?25l' >&2
      ui_plain_render_many_menu "$prompt" "$selected_index" checked "${entries[@]}"
      first_render=0
    else
      ui_plain_redraw_many_menu "$selected_index" checked "${entries[@]}"
    fi

    if ! ui_plain_read_key; then
      printf '\033[?25h\n' >&2
      return 1
    fi
    key=$REPLY

    case "$key" in
      $'\e')
        printf '\033[?25h\n' >&2
        return 1
        ;;
      $'\e[A'|$'\e[D')
        if (( selected_index > 0 )); then
          selected_index=$((selected_index - 1))
        else
          selected_index=$((${#entries[@]} - 1))
        fi
        ;;
      $'\e[B'|$'\e[C')
        selected_index=$(((selected_index + 1) % ${#entries[@]}))
        ;;
      ' ')
        if [[ ${checked[$selected_index]} -eq 1 ]]; then
          checked[$selected_index]=0
        else
          checked[$selected_index]=1
        fi
        ;;
      $'\n'|$'\r')
        printf '\033[?25h\n' >&2
        for idx in "${!entries[@]}"; do
          if [[ ${checked[$idx]} -eq 1 ]]; then
            printf '%s\n' "${entries[$idx]%%|*}"
          fi
        done
        return 0
        ;;
    esac
  done
}

ui_gum_header() {
  local prompt=$1
  printf '%s\n%s\n\n%s\n%s' \
    "$(ui_run_gum style --bold --foreground "$UI_GUM_SELECTED" 'lnx-df')" \
    "$(ui_run_gum style --foreground "$UI_GUM_MUTED" "$UI_SUBTITLE")" \
    "$(ui_run_gum style --bold --foreground "$UI_GUM_ACCENT" "$prompt")" \
    "$(ui_run_gum style --foreground "$UI_GUM_MUTED" "$UI_HINT")"
}

ui_gum_option_text() {
  local id=$1
  local label=$2
  local description=$3

  if [[ -n $description ]]; then
    printf '%-14s %-18s %s' "$id" "$label" "$description"
  else
    printf '%-14s %s' "$id" "$label"
  fi
}

ui_gum_choose() {
  local prompt=$1
  shift
  local choose_args=(
    --header "$(ui_gum_header "$prompt")"
    --cursor '› '
    --cursor.foreground "$UI_GUM_SELECTED"
    --header.foreground "$UI_GUM_ACCENT"
  )

  ui_run_gum choose "${choose_args[@]}" "$@"
}

ui_show_plain_options() {
  local entries=("$@")
  local index=1
  local entry
  local id
  local label
  local description

  for entry in "${entries[@]}"; do
    IFS='|' read -r id label description _ <<<"$entry"
    printf '  %2d  %-14s %-18s %s\n' "$index" "$id" "$label" "$description" >&2
    index=$((index + 1))
  done
}

ui_select_many() {
  local prompt=$1
  shift
  local entries=("$@")

  if (( ${#entries[@]} == 0 )); then
    return 0
  fi

  local backend
  backend="$(ui_backend)"

  if [[ $backend == gum ]]; then
    local options=()
    local entry
    for entry in "${entries[@]}"; do
      IFS='|' read -r id label description _ <<<"$entry"
      options+=("$(ui_gum_option_text "$id" "$label" "$description")")
    done

    local result
    result="$(ui_gum_choose "$prompt" --no-limit "${options[@]}")" || return 1
    while IFS= read -r line; do
      [[ -n $line ]] || continue
      local entry_index
      for entry_index in "${!options[@]}"; do
        if [[ ${options[$entry_index]} == "$line" ]]; then
          printf '%s\n' "${entries[$entry_index]%%|*}"
          break
        fi
      done
    done <<<"$result"
    return 0
  fi

  if [[ $backend == whiptail ]]; then
    local args=()
    local entry
    for entry in "${entries[@]}"; do
      IFS='|' read -r id label description _ <<<"$entry"
      args+=("$id" "$(ui_option_text "$label" "$description")" OFF)
    done

    local result
    result="$(whiptail --title "$UI_TITLE" --backtitle "$UI_SUBTITLE" --checklist "$prompt\n\nCLI stays available in --help and README." 22 90 14 "${args[@]}" 3>&1 1>&2 2>&3)" || return 1
    result=${result//\"/}
    for id in $result; do
      printf '%s\n' "$id"
    done
    return 0
  fi

  if [[ $backend == dialog ]]; then
    local tmp
    tmp=$(mktemp)
    local args=()
    local entry
    for entry in "${entries[@]}"; do
      IFS='|' read -r id label description _ <<<"$entry"
      args+=("$id" "$(ui_option_text "$label" "$description")" off)
    done

    dialog --backtitle "$UI_SUBTITLE" --stdout --title "$UI_TITLE" --checklist "$prompt\n\nCLI stays available in --help and README." 22 90 14 "${args[@]}" >"$tmp" || {
      rm -f "$tmp"
      return 1
    }

    local result
    result=$(<"$tmp")
    rm -f "$tmp"
    result=${result//\"/}
    for id in $result; do
      printf '%s\n' "$id"
    done
    return 0
  fi

  if ui_has_tty; then
    ui_plain_select_many_interactive "$prompt" "${entries[@]}"
  else
    ui_plain_select_many_line "$prompt" "${entries[@]}"
  fi
}

ui_select_one() {
  local prompt=$1
  shift
  local entries=("$@")

  if (( ${#entries[@]} == 0 )); then
    return 0
  fi

  local backend
  backend="$(ui_backend)"

  if [[ $backend == gum ]]; then
    local options=()
    local entry
    for entry in "${entries[@]}"; do
      IFS='|' read -r id label description _ <<<"$entry"
      options+=("$(ui_gum_option_text "$id" "$label" "$description")")
    done

    local result
    result="$(ui_gum_choose "$prompt" "${options[@]}")" || return 1
    if [[ -n $result ]]; then
      local entry_index
      for entry_index in "${!options[@]}"; do
        if [[ ${options[$entry_index]} == "$result" ]]; then
          printf '%s\n' "${entries[$entry_index]%%|*}"
          break
        fi
      done
    fi
    return 0
  fi

  if [[ $backend == whiptail ]]; then
    local args=()
    local entry
    for entry in "${entries[@]}"; do
      IFS='|' read -r id label description _ <<<"$entry"
      args+=("$id" "$(ui_option_text "$label" "$description")")
    done

    whiptail --title "$UI_TITLE" --backtitle "$UI_SUBTITLE" --menu "$prompt\n\nCLI stays available in --help and README." 22 90 14 "${args[@]}" 3>&1 1>&2 2>&3
    return $?
  fi

  if [[ $backend == dialog ]]; then
    local args=()
    local entry
    for entry in "${entries[@]}"; do
      IFS='|' read -r id label description _ <<<"$entry"
      args+=("$id" "$(ui_option_text "$label" "$description")")
    done

    dialog --backtitle "$UI_SUBTITLE" --stdout --title "$UI_TITLE" --menu "$prompt\n\nCLI stays available in --help and README." 22 90 14 "${args[@]}"
    return $?
  fi

  if ui_has_tty; then
    ui_plain_select_one_interactive "$prompt" "${entries[@]}"
  else
    ui_plain_select_one_line "$prompt" "${entries[@]}"
  fi
}

ui_confirm() {
  local prompt=$1
  local negative_label=${2:-no}

  local backend
  backend="$(ui_backend)"

  if [[ $backend == gum ]]; then
    local result
    result="$(ui_gum_choose "$prompt" "$negative_label" 'yes')" || return 1
    [[ $result == yes ]]
    return $?
  fi

  if [[ $backend == whiptail ]]; then
    whiptail --title "$UI_TITLE" --backtitle "$UI_SUBTITLE" --yesno "$prompt" 11 72
    return $?
  fi

  if [[ $backend == dialog ]]; then
    dialog --backtitle "$UI_SUBTITLE" --stdout --title "$UI_TITLE" --yesno "$prompt" 11 72
    return $?
  fi

  ui_plain_banner "$prompt"
  ui_plain_footer 'y/yes confirms. Enter or Esc skips. Anything else skips.'
  printf '\nConfirm > ' >&2

  if ! ui_has_tty; then
    local answer
    if ! read -r answer; then
      return 1
    fi
    [[ $answer =~ ^[Yy]([Ee][Ss])?$ ]]
    return $?
  fi

  local key
  local answer=

  if ! ui_plain_read_key; then
    return 1
  fi
  key=$REPLY

    case "$key" in
      $'\e') return 1 ;;
      $'\n'|$'\r') return 1 ;;
      [[:print:]])
        answer=$key
        if IFS= read -r key </dev/tty; then
          answer+="$key"
        fi
      [[ $answer =~ ^[Yy]([Ee][Ss])?$ ]]
      return $?
      ;;
    *) return 1 ;;
  esac
}

ui_show_text() {
  local title=$1
  local body=$2

  local backend
  backend="$(ui_backend)"

  if [[ $backend == gum ]]; then
    printf '\n%s\n' "$(ui_run_gum style --bold --foreground "$UI_GUM_SELECTED" 'lnx-df')"
    printf '%s\n' "$(ui_run_gum style --foreground "$UI_GUM_MUTED" "$UI_SUBTITLE")"
    printf '\n%s\n' "$(ui_run_gum style --bold --foreground "$UI_GUM_ACCENT" "$title")"
    printf '%s\n\n' "$body"
    printf '\n'
    return 0
  fi

  if [[ $backend == whiptail ]]; then
    whiptail --title "$title" --backtitle "$UI_SUBTITLE" --msgbox "$body" 22 90
    return $?
  fi

  if [[ $backend == dialog ]]; then
    dialog --backtitle "$UI_SUBTITLE" --stdout --title "$title" --msgbox "$body" 22 90
    return $?
  fi

  ui_plain_banner "$title"
  printf '\n%s\n' "$body"
}
