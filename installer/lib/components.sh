#!/usr/bin/env bash

COMPONENT_IDS=(
  dotfiles
  kitty
  nerd-fonts
  tmux
  nvim
  gcc
  cmake
  python
  nodejs
  pnpm
  rust
  go
  dotnet
  tauri
  godot
  opencode
  gentle-ai
  codex
  claude-code
  qwen-cli
)

PRESET_IDS=(
  basic
  dev
  gamedev
  full
  custom
)

BASIC_PRESET_COMPONENTS=(dotfiles kitty nerd-fonts tmux nvim python nodejs pnpm)
DEV_PRESET_COMPONENTS=(dotfiles kitty nerd-fonts tmux nvim gcc cmake python nodejs pnpm rust go dotnet tauri opencode gentle-ai codex claude-code qwen-cli)
GAMEDEV_PRESET_COMPONENTS=(dotfiles kitty nerd-fonts tmux nvim gcc cmake python nodejs pnpm rust go dotnet tauri godot)
FULL_PRESET_COMPONENTS=("${COMPONENT_IDS[@]}")

PYTHON_SELECTION=()
CHECK_PASSED_COMPONENTS=()
CHECK_FAILED_COMPONENTS=()

component_label() {
  case "$1" in
    dotfiles) printf 'Dotfiles' ;;
    zsh) printf 'Zsh' ;;
    kitty) printf 'Kitty' ;;
    nerd-fonts) printf 'Nerd Fonts' ;;
    tmux) printf 'Tmux' ;;
    nvim) printf 'Neovim' ;;
    gcc) printf 'GCC toolchain' ;;
    cmake) printf 'CMake' ;;
    python) printf 'Python' ;;
    nodejs) printf 'Node.js' ;;
    pnpm) printf 'pnpm' ;;
    rust) printf 'Rust' ;;
    go) printf 'Go' ;;
    dotnet) printf '.NET SDK' ;;
    tauri) printf 'Tauri' ;;
    godot) printf 'Godot' ;;
    opencode) printf 'OpenCode' ;;
    gentle-ai) printf 'Gentle AI' ;;
    codex) printf 'Codex' ;;
    claude-code) printf 'Claude Code' ;;
    qwen-cli) printf 'Qwen Code' ;;
    *) printf '%s' "$1" ;;
  esac
}

component_description() {
  case "$1" in
    dotfiles) printf 'repo configs' ;;
    zsh) printf 'shell' ;;
    kitty) printf 'terminal' ;;
    nerd-fonts) printf 'Nerd Font' ;;
    tmux) printf 'tmux config' ;;
    nvim) printf 'Neovim config' ;;
    gcc) printf 'toolchain' ;;
    cmake) printf 'build system' ;;
    python) printf 'Python + venv' ;;
    nodejs) printf 'Node.js + npm' ;;
    pnpm) printf 'pnpm' ;;
    rust) printf 'rustup + cargo' ;;
    go) printf 'Go toolchain' ;;
    dotnet) printf '.NET SDK' ;;
    tauri) printf 'Tauri deps' ;;
    godot) printf 'Godot' ;;
    opencode) printf 'OpenCode CLI' ;;
    gentle-ai) printf 'gentle-ai' ;;
    codex) printf 'Codex CLI' ;;
    claude-code) printf 'Claude Code CLI' ;;
    qwen-cli) printf 'Qwen Code CLI' ;;
    *) printf 'No description available' ;;
  esac
}

component_uninstall_mode() {
  case "$1" in
    dotfiles|rust|tauri|opencode|gentle-ai|codex|claude-code|qwen-cli)
      printf 'full'
      ;;
    *)
      printf 'conservative'
      ;;
  esac
}

component_uninstall_description() {
  local base_description
  base_description="$(component_description "$1")"

  case "$(component_uninstall_mode "$1")" in
    full) printf '%s • removes managed files' "$base_description" ;;
    conservative) printf '%s • keep system packages' "$base_description" ;;
    *) printf '%s' "$base_description" ;;
  esac
}

preset_label() {
  case "$1" in
    basic) printf 'Basic' ;;
    dev) printf 'Dev' ;;
    gamedev) printf 'Game Dev' ;;
    full) printf 'Full' ;;
    custom) printf 'Custom' ;;
    *) printf '%s' "$1" ;;
  esac
}

preset_description() {
  case "$1" in
    basic) printf 'Core workspace' ;;
    dev) printf 'Dev stack' ;;
    gamedev) printf 'Dev + Godot' ;;
    full) printf 'All components' ;;
    custom) printf 'Manual pick' ;;
    *) printf 'No description available' ;;
  esac
}

component_entries() {
  local id
  for id in "${COMPONENT_IDS[@]}"; do
    printf '%s|%s|%s\n' "$id" "$(component_label "$id")" "$(component_description "$id")"
  done
}

uninstall_component_entries() {
  local id
  for id in "${COMPONENT_IDS[@]}"; do
    printf '%s|%s|%s\n' "$id" "$(component_label "$id")" "$(component_uninstall_description "$id")"
  done
}

preset_entries() {
  local id
  for id in "${PRESET_IDS[@]}"; do
    printf '%s|%s|%s\n' "$id" "$(preset_label "$id")" "$(preset_description "$id")"
  done
}

list_components() {
  local id
  for id in "${COMPONENT_IDS[@]}"; do
    printf '%-14s %s\n' "$id" "$(component_description "$id")"
  done
}

list_presets() {
  local id
  for id in "${PRESET_IDS[@]}"; do
    printf '%-14s %s\n' "$id" "$(preset_description "$id")"
  done
}

preset_components() {
  case "$1" in
    basic) printf '%s\n' "${BASIC_PRESET_COMPONENTS[@]}" ;;
    dev) printf '%s\n' "${DEV_PRESET_COMPONENTS[@]}" ;;
    gamedev) printf '%s\n' "${GAMEDEV_PRESET_COMPONENTS[@]}" ;;
    full) printf '%s\n' "${FULL_PRESET_COMPONENTS[@]}" ;;
    custom) return 0 ;;
    *) warn "unknown preset: $1"; return 1 ;;
  esac
}

is_known_component() {
  local component
  for component in "${COMPONENT_IDS[@]}"; do
    [[ $component == "$1" ]] && return 0
  done

  return 1
}

normalize_component_list() {
  local seen=' '
  local component
  for component in "$@"; do
    if ! is_known_component "$component"; then
      warn "unknown component: ${component}"
      continue
    fi

    if [[ $seen != *" ${component} "* ]]; then
      printf '%s\n' "$component"
      seen+="${component} "
    fi
  done
}

select_python_versions() {
  local entries=("system|System Python|Install the distro default Python, pip, and venv tooling")
  local versions=(3.10 3.11 3.12 3.13)
  local version

  load_platform_info

  for version in "${versions[@]}"; do
    case "${PACKAGE_MANAGER}" in
      apt)
        if command_exists "python${version}" || apt_has_package "python${version}"; then
          entries+=("${version}|Python ${version}|Install interpreter and venv package when available")
        fi
        ;;
      *) ;;
    esac
  done

  local selected=()
  if (( NON_INTERACTIVE )); then
    selected=(system)
    if (( ALL_COMPONENTS )) && [[ ${PACKAGE_MANAGER} == apt ]]; then
      for version in "${versions[@]}"; do
        if apt_has_package "python${version}"; then
          selected+=("${version}")
        fi
      done
    fi
  else
    mapfile -t selected < <(ui_select_many "python versions" "${entries[@]}")
  fi

  if (( ${#selected[@]} == 0 )); then
    selected=(system)
  fi

  PYTHON_SELECTION=("${selected[@]}")
}

packages_for_key() {
  local key=$1

  load_platform_info

  case "$key" in
    zsh)
      printf 'zsh\n'
      ;;
    kitty)
      printf 'kitty\n'
      ;;
    nerd-fonts)
      case "${PACKAGE_MANAGER}" in
        pacman) printf 'ttf-cascadia-code-nerd\n' ;;
      esac
      ;;
    tmux)
      case "${PACKAGE_MANAGER}" in
        pacman) printf 'tmux\ninetutils\n' ;;
        *) printf 'tmux\n' ;;
      esac
      ;;
    nvim)
      printf 'neovim\n'
      ;;
    gcc)
      case "${PACKAGE_MANAGER}" in
        apt) printf 'build-essential\ngcc\ng++\n' ;;
        pacman) printf 'base-devel\ngcc\n' ;;
        dnf) printf 'gcc\ngcc-c++\nmake\n' ;;
      esac
      ;;
    cmake)
      printf 'cmake\n'
      ;;
    python-system)
      case "${PACKAGE_MANAGER}" in
        apt) printf 'python3\npython3-pip\npython3-venv\n' ;;
        pacman) printf 'python\npython-pip\npython-virtualenv\n' ;;
        dnf) printf 'python3\npython3-pip\npython3-virtualenv\n' ;;
      esac
      ;;
    nodejs)
      case "${PACKAGE_MANAGER}" in
        apt) printf 'nodejs\nnpm\n' ;;
        pacman) printf 'nodejs\nnpm\n' ;;
        dnf) printf 'nodejs\nnpm\n' ;;
      esac
      ;;
    curl-runtime)
      case "${PACKAGE_MANAGER}" in
        apt) printf 'curl\nca-certificates\n' ;;
        pacman) printf 'curl\nca-certificates\n' ;;
        dnf) printf 'curl\nca-certificates\n' ;;
      esac
      ;;
    go)
      case "${PACKAGE_MANAGER}" in
        apt) printf 'golang-go\n' ;;
        pacman) printf 'go\n' ;;
        dnf) printf 'golang\n' ;;
      esac
      ;;
    gum-ui)
      case "${PACKAGE_MANAGER}" in
        apt) printf 'gum\n' ;;
        pacman) printf 'gum\n' ;;
        dnf) printf 'gum\n' ;;
      esac
      ;;
    unzip-runtime)
      case "${PACKAGE_MANAGER}" in
        apt) printf 'unzip\n' ;;
        pacman) printf 'unzip\n' ;;
        dnf) printf 'unzip\n' ;;
      esac
      ;;
    tauri-deps)
      case "${PACKAGE_MANAGER}" in
        apt) printf 'build-essential\ncurl\nwget\nfile\nlibssl-dev\nlibayatana-appindicator3-dev\nlibrsvg2-dev\nlibxdo-dev\nlibwebkit2gtk-4.1-dev\n' ;;
        pacman) printf 'base-devel\ncurl\nwget\nfile\nopenssl\nwebkit2gtk-4.1\nlibayatana-appindicator\nlibrsvg\nxdotool\n' ;;
        dnf) printf 'gcc\ngcc-c++\nmake\ncurl\nwget\nfile\nopenssl-devel\nlibappindicator-gtk3\nlibrsvg2-devel\nxdotool\nwebkit2gtk4.1-devel\n' ;;
      esac
      ;;
    godot)
      case "${PACKAGE_MANAGER}" in
        apt) printf 'godot4\ngodot3\ngodot\n' ;;
        pacman) printf 'godot\n' ;;
        dnf) printf 'godot\n' ;;
      esac
      ;;
    *)
      warn "unknown package key: ${key}"
      return 1
      ;;
  esac
}

install_package_key() {
  local key=$1
  local packages=()

  mapfile -t packages < <(packages_for_key "$key")
  if (( ${#packages[@]} == 0 )); then
    warn "no packages mapped for ${key} on $(describe_platform)"
    return 1
  fi

  install_system_packages "${packages[@]}"
}

install_package_key_first_available() {
  local key=$1
  local packages=()

  mapfile -t packages < <(packages_for_key "$key")
  if (( ${#packages[@]} == 0 )); then
    warn "no packages mapped for ${key} on $(describe_platform)"
    return 1
  fi

  install_first_available_system_package "${packages[@]}"
}

check_symlink_target() {
  local target=$1
  local expected=$2

  local current desired
  current="$(readlink -f "$target" 2>/dev/null || true)"
  desired="$(readlink -f "$expected" 2>/dev/null || true)"

  if [[ -n $current && -n $desired && $current == "$desired" ]]; then
    log "check passed: ${target}"
    return 0
  fi

  if [[ ! -L $target ]]; then
    warn "missing symlink: ${target}"
    return 1
  fi

  warn "symlink points elsewhere: ${target} -> ${current:-unknown}; expected ${desired:-$expected}"
  return 1
}

check_command_component() {
  local command_name=$1
  local label=${2:-$1}

  if command_exists "$command_name"; then
    log "check passed: ${label}"
    note_command_path_status "$command_name" "$label"
    return 0
  fi

  warn "check failed: ${label} command not found"
  return 1
}

check_native_command_component() {
  local command_name=$1
  local label=${2:-$1}

  if native_command_exists "$command_name"; then
    log "check passed: ${label}"
    note_command_path_status "$command_name" "$label"
    return 0
  fi

  if is_wsl_environment && command_exists "$command_name"; then
    warn "check failed: ${label} resolves outside WSL; install a native WSL copy"
    return 1
  fi

  warn "check failed: ${label} command not found"
  return 1
}

check_file_component() {
  local path=$1
  local label=$2

  if [[ -e $path ]]; then
    log "check passed: ${label}"
    return 0
  fi

  warn "check failed: ${label} missing at ${path}"
  return 1
}

check_command_min_version() {
  local command_name=$1
  local label=$2
  local minimum=$3
  shift 3
  local version_args=("$@")

  if ! command_exists "$command_name"; then
    warn "check failed: ${label} command not found"
    return 1
  fi

  local output
  output="$("$command_name" "${version_args[@]}" 2>/dev/null || true)"
  output=${output%%$'\n'*}

  local current
  if ! current="$(extract_semver "$output")"; then
    log "check passed: ${label} (version unavailable)"
    note_command_path_status "$command_name" "$label"
    return 0
  fi

  if version_gte "$current" "$minimum"; then
    log "check passed: ${label} ${current} >= ${minimum}"
    note_command_path_status "$command_name" "$label"
    return 0
  fi

  warn "check failed: ${label} ${current} is below required ${minimum}"
  return 1
}

have_caskaydia_nerd_font() {
  if command_exists fc-match; then
    local match
    match="$(fc-match 'CaskaydiaCove Nerd Font' 2>/dev/null || true)"
    [[ $match == *Caskaydia* || $match == *CaskaydiaCoveNerdFont* ]]
    return $?
  fi

  [[ -d ${HOME}/.local/share/fonts/NerdFonts/CaskaydiaCove ]]
}

install_component() {
  case "$1" in
    dotfiles) install_dotfiles ;;
    zsh) install_zsh ;;
    kitty) install_kitty ;;
    nerd-fonts) install_nerd_fonts ;;
    tmux) install_tmux ;;
    nvim) install_nvim ;;
    gcc) install_gcc ;;
    cmake) install_cmake ;;
    python) install_python ;;
    nodejs) install_nodejs ;;
    pnpm) install_pnpm ;;
    rust) install_rust ;;
    go) install_go ;;
    dotnet) install_dotnet ;;
    tauri) install_tauri ;;
    godot) install_godot ;;
    opencode) install_opencode ;;
    gentle-ai) install_gentle_ai ;;
    codex) install_codex ;;
    claude-code) install_claude_code ;;
    qwen-cli) install_qwen_cli ;;
    *) warn "unknown component: $1" ; return 1 ;;
  esac
}

check_component() {
  case "$1" in
    dotfiles) check_dotfiles ;;
    zsh) check_zsh ;;
    kitty) check_command_component kitty Kitty ;;
    nerd-fonts) check_nerd_fonts ;;
    tmux) check_tmux ;;
    nvim) check_nvim ;;
    gcc) check_gcc ;;
    cmake) check_command_component cmake CMake ;;
    python) check_python ;;
    nodejs) check_nodejs ;;
    pnpm) check_command_component pnpm pnpm ;;
    rust) check_rust ;;
    go) check_go ;;
    dotnet) check_dotnet ;;
    tauri) check_tauri ;;
    godot) check_godot ;;
    opencode) check_native_command_component opencode OpenCode ;;
    gentle-ai) check_command_component gentle-ai 'Gentle AI' ;;
    codex) check_native_command_component codex Codex ;;
    claude-code) check_native_command_component claude 'Claude Code' ;;
    qwen-cli) check_native_command_component qwen 'Qwen Code' ;;
    *) warn "unknown component: $1" ; return 1 ;;
  esac
}

run_component_checks() {
  local failures=0
  local component

  CHECK_PASSED_COMPONENTS=()
  CHECK_FAILED_COMPONENTS=()

  for component in "$@"; do
    set_install_state_phase check "$component"
    log "checking $(component_label "$component")"
    if ! check_component "$component"; then
      failures=$((failures + 1))
      CHECK_FAILED_COMPONENTS+=("$component")
      mark_install_state_failed check "$component"
    else
      CHECK_PASSED_COMPONENTS+=("$component")
      mark_install_state_check_completed "$component"
    fi
  done

  if (( failures > 0 )); then
    warn "${failures} component check(s) failed"
    return 1
  fi

  log "all component checks passed"
}

uninstall_component() {
  case "$1" in
    dotfiles) uninstall_dotfiles ;;
    rust) uninstall_rust ;;
    opencode) npm_global_uninstall opencode-ai && remove_native_command_link opencode ;;
    gentle-ai) uninstall_gentle_ai ;;
    codex) npm_global_uninstall @openai/codex && remove_native_command_link codex ;;
    claude-code) npm_global_uninstall @anthropic-ai/claude-code && remove_native_command_link claude ;;
    qwen-cli) npm_global_uninstall @qwen-code/qwen-code && remove_native_command_link qwen ;;
    tauri) uninstall_tauri ;;
    *) log "skip uninstall for $1: system-managed or intentionally non-destructive" ;;
  esac
}

install_dotfiles() {
  remove_repo_symlink "${HOME}/.zshrc"
  ensure_symlink "${CONFIG_ROOT}/autostart" "${HOME}/.config/autostart"
  remove_repo_symlink "${HOME}/.config/zsh"
  ensure_symlink "${CONFIG_ROOT}/nvim" "${HOME}/.config/nvim"

  remove_repo_symlink "${HOME}/.config/kitty"
  ensure_symlink "${CONFIG_ROOT}/kitty/kitty.conf" "${HOME}/.config/kitty/kitty.conf"
  ensure_symlink "${CONFIG_ROOT}/kitty/themes" "${HOME}/.config/kitty/themes"

  remove_repo_symlink "${HOME}/.config/tmux"
  ensure_symlink "${CONFIG_ROOT}/tmux/tmux.conf" "${HOME}/.config/tmux/tmux.conf"
  ensure_symlink "${HOME}/.config/tmux/tmux.conf" "${HOME}/.tmux.conf"

  install_arch_aur_guard
}

uninstall_dotfiles() {
  remove_repo_symlink "${INSTALL_USER_HOME}/.zshrc"
  remove_repo_symlink "${INSTALL_USER_HOME}/.config/autostart"
  remove_repo_symlink "${INSTALL_USER_HOME}/.config/zsh"
  remove_repo_symlink "${INSTALL_USER_HOME}/.config/nvim"
  remove_repo_symlink "${INSTALL_USER_HOME}/.config/kitty/kitty.conf"
  remove_repo_symlink "${INSTALL_USER_HOME}/.config/kitty/themes"
  remove_repo_symlink "${INSTALL_USER_HOME}/.tmux.conf"
  remove_repo_symlink "${INSTALL_USER_HOME}/.config/tmux/tmux.conf"
  remove_repo_symlink "${INSTALL_USER_HOME}/.config/kitty"
  remove_repo_symlink "${INSTALL_USER_HOME}/.config/tmux"
  uninstall_arch_aur_guard
}

arch_aur_guard_helpers() {
  printf '%s\n' yay paru pikaur trizen aurman
}

arch_aur_guard_wrapper_present() {
  local wrapper=$1
  local path="/usr/local/bin/${wrapper}"

  [[ -x $path ]] || return 1

  if grep -Fq 'lnx-df managed AUR guard' "$path" 2>/dev/null; then
    return 0
  fi

  case "$wrapper" in
    makepkg) grep -Fq 'makepkg install mode is disabled by local AUR guard' "$path" 2>/dev/null ;;
    *) grep -Fq 'AUR helpers are intentionally blocked' "$path" 2>/dev/null ;;
  esac
}

write_arch_aur_guard_scripts() {
  local target_dir=$1

  cat >"${target_dir}/makepkg" <<'EOF'
#!/usr/bin/env bash
# lnx-df managed AUR guard
for arg in "$@"; do
  if [[ "$arg" == "--install" || ( "$arg" == -[^-]* && "$arg" == *i* ) ]]; then
    cat >&2 <<MSG
BLOCKED: makepkg install mode is disabled by local AUR guard.
Reason: this machine blocks accidental AUR-style builds/installs.
Build-only use is still allowed via /usr/bin/makepkg without -i/--install.
MSG
    exit 126
  fi
done
exec /usr/bin/makepkg "$@"
EOF

  local helper
  for helper in $(arch_aur_guard_helpers); do
    cat >"${target_dir}/${helper}" <<'EOF'
#!/usr/bin/env bash
# lnx-df managed AUR guard
cmd="$(basename "$0")"
cat >&2 <<MSG
BLOCKED: '$cmd' is disabled on this machine.
Reason: AUR helpers are intentionally blocked to reduce supply-chain attack surface.
Use official repos, Flatpak, or Homebrew instead.
MSG
exit 126
EOF
  done
}

install_arch_aur_guard() {
  load_platform_info
  [[ ${PACKAGE_MANAGER} == pacman ]] || return 0

  local sudo_cmd
  if ! sudo_cmd="$(sudo_prefix)"; then
    warn "sudo is required to install Arch AUR guard wrappers"
    return 1
  fi

  if (( DRY_RUN )); then
    log "dry-run: install lnx-df AUR guard wrappers into /usr/local/bin"
    return 0
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  write_arch_aur_guard_scripts "$tmp_dir"

  local wrapper
  for wrapper in makepkg $(arch_aur_guard_helpers); do
    if [[ -n $sudo_cmd ]]; then
      run_cmd "$sudo_cmd" install -Dm755 "${tmp_dir}/${wrapper}" "/usr/local/bin/${wrapper}"
    else
      run_cmd install -Dm755 "${tmp_dir}/${wrapper}" "/usr/local/bin/${wrapper}"
    fi
  done

  rm -rf "$tmp_dir"
}

check_arch_aur_guard() {
  load_platform_info
  [[ ${PACKAGE_MANAGER} == pacman ]] || return 0

  local failures=0
  local wrapper
  for wrapper in makepkg $(arch_aur_guard_helpers); do
    if arch_aur_guard_wrapper_present "$wrapper"; then
      log "check passed: AUR guard wrapper ${wrapper}"
    else
      warn "check failed: AUR guard wrapper missing for ${wrapper}"
      failures=$((failures + 1))
    fi
  done

  (( failures == 0 ))
}

uninstall_arch_aur_guard() {
  load_platform_info
  [[ ${PACKAGE_MANAGER} == pacman ]] || return 0

  local sudo_cmd
  if ! sudo_cmd="$(sudo_prefix)"; then
    warn "sudo is required to remove Arch AUR guard wrappers"
    return 1
  fi

  local wrapper
  for wrapper in makepkg $(arch_aur_guard_helpers); do
    if [[ -e /usr/local/bin/${wrapper} ]] && grep -Fq 'lnx-df managed AUR guard' "/usr/local/bin/${wrapper}" 2>/dev/null; then
      if [[ -n $sudo_cmd ]]; then
        run_cmd "$sudo_cmd" rm -f "/usr/local/bin/${wrapper}"
      else
        run_cmd rm -f "/usr/local/bin/${wrapper}"
      fi
    else
      log "skip AUR guard removal for ${wrapper}: not managed by lnx-df"
    fi
  done
}

install_zsh() {
  if command_exists zsh; then
    log "zsh already installed"
  else
    install_package_key zsh || return 1
  fi

  set_default_shell_to_zsh
}

install_kitty() {
  if command_exists kitty; then
    log "kitty already installed"
    return 0
  fi

  install_package_key kitty
}

install_nerd_fonts() {
  if have_caskaydia_nerd_font; then
    log "CaskaydiaCove Nerd Font already installed"
    return 0
  fi

  if have_pacman; then
    install_package_key nerd-fonts || true
    if have_caskaydia_nerd_font; then
      return 0
    fi
  fi

  if ! command_exists curl; then
    install_package_key curl-runtime || return 1
  fi

  if ! command_exists unzip; then
    install_package_key unzip-runtime || return 1
  fi

  local font_root="${HOME}/.local/share/fonts/NerdFonts/CaskaydiaCove"

  if (( DRY_RUN )); then
    log "dry-run: install CaskaydiaCove Nerd Font into ${font_root}"
    log "dry-run: refresh font cache for ${font_root}"
    return 0
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local archive_path="${tmp_dir}/CascadiaCode.zip"

  curl_download https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip "$archive_path" || {
    run_cmd rm -rf "$tmp_dir"
    return 1
  }

  run_cmd mkdir -p "$font_root"
  run_cmd unzip -oq "$archive_path" -d "$font_root"
  run_cmd rm -rf "$tmp_dir"

  if command_exists fc-cache; then
    run_cmd fc-cache -f "$font_root"
  else
    warn "fc-cache not found; font install completed but cache was not refreshed"
  fi
}

install_tmux() {
  if command_exists tmux && command_exists hostname; then
    log "tmux runtime already installed"
  else
    install_package_key tmux || return 1
  fi

  install_tmux_plugin_manager || return 1
  install_tmux_plugins
}

install_nvim() {
  if command_exists nvim; then
    log "nvim already installed"
    return 0
  fi

  install_package_key nvim
}

install_gcc() {
  if command_exists gcc && command_exists g++; then
    log "gcc and g++ already installed"
    return 0
  fi

  install_package_key gcc
}

install_cmake() {
  if command_exists cmake; then
    log "cmake already installed"
    return 0
  fi

  install_package_key cmake
}

install_python() {
  if (( ${#PYTHON_SELECTION[@]} == 0 )); then
    select_python_versions
  fi

  local packages=()
  local choice
  local unsupported_versions=0
  local system_packages=()

  for choice in "${PYTHON_SELECTION[@]}"; do
    case "$choice" in
      system)
        mapfile -t system_packages < <(packages_for_key python-system)
        packages+=("${system_packages[@]}")
        ;;
      3.*)
        if have_apt; then
          packages+=("python${choice}" "python${choice}-venv")
        else
          warn "python ${choice} selection is only supported automatically on apt-based systems; skipping"
          unsupported_versions=1
        fi
        ;;
      *)
        warn "unknown python selection: ${choice}"
        ;;
    esac
  done

  if (( ${#packages[@]} > 0 )); then
    install_system_packages "${packages[@]}" || return 1
  fi

  if (( unsupported_versions )) && (( ${#packages[@]} == 0 )); then
    return 1
  fi
}

install_nodejs() {
  if is_wsl_environment; then
    if native_command_exists node && native_command_exists npm; then
      log "node and npm already installed in WSL"
      return 0
    fi
  elif command_exists node && command_exists npm; then
    log "node and npm already installed"
    return 0
  fi

  install_package_key nodejs

  if is_wsl_environment && (! native_command_exists node || ! native_command_exists npm); then
    warn "nodejs install completed but native WSL node/npm are still unavailable"
    return 1
  fi
}

install_pnpm() {
  if command_exists pnpm; then
    log "pnpm already installed"
    return 0
  fi

  if ! command_exists node; then
    install_nodejs || return 1
  fi

  if command_exists corepack; then
    run_cmd corepack enable
    run_cmd corepack prepare pnpm@latest --activate
    return 0
  fi

  npm_global_install pnpm pnpm
}

install_rust() {
  require_install_user_context 'Rust installation' || return 1

  if command_exists rustup || command_exists cargo || [[ -x ${INSTALL_USER_HOME}/.cargo/bin/cargo ]]; then
    activate_rust_environment
    log "rust toolchain already installed"
    return 0
  fi

  if ! command_exists curl; then
    install_package_key curl-runtime || return 1
  fi

  local tmp_script
  tmp_script="$(mktemp)"

  curl_download https://sh.rustup.rs "$tmp_script" || {
    rm -f "$tmp_script"
    return 1
  }

  if (( DRY_RUN )); then
    if (( NON_INTERACTIVE )); then
      log "dry-run: sh ${tmp_script} -y"
    else
      log "dry-run: sh ${tmp_script}"
    fi
    rm -f "$tmp_script"
    return 0
  fi

  if (( NON_INTERACTIVE )); then
    run_as_install_user env HOME="${INSTALL_USER_HOME}" sh "$tmp_script" -y || {
      rm -f "$tmp_script"
      return 1
    }
  else
    log "launching interactive rustup installer"
    run_as_install_user env HOME="${INSTALL_USER_HOME}" sh "$tmp_script" || {
      rm -f "$tmp_script"
      return 1
    }
  fi

  rm -f "$tmp_script"
  activate_rust_environment
  ensure_user_tool_path_persisted "${INSTALL_USER_HOME}/.cargo/bin" || true

  if ! command_exists rustup; then
    warn "rust install completed but rustup is still unavailable in this shell"
    return 1
  fi

  local cargo_cmd
  if ! cargo_cmd="$(cargo_bin 2>/dev/null)"; then
    warn "rust install completed but cargo is still unavailable in this shell"
    return 1
  fi

  local rustc_cmd
  rustc_cmd="$(command -v rustc 2>/dev/null || true)"
  if [[ -z ${rustc_cmd} && -x ${INSTALL_USER_HOME}/.cargo/bin/rustc ]]; then
    rustc_cmd="${INSTALL_USER_HOME}/.cargo/bin/rustc"
  fi

  if [[ -z ${rustc_cmd} ]]; then
    warn "rust install completed but rustc is still unavailable in this shell"
    return 1
  fi
}

install_go() {
  if command_exists go; then
    log "go already installed"
    return 0
  fi

  install_package_key go
}

install_dotnet() {
  if command_exists dotnet || [[ -x ${HOME}/.dotnet/dotnet ]]; then
    activate_dotnet_environment
    log ".NET already installed"
    return 0
  fi

  local tmp_script
  tmp_script="$(mktemp)"
  curl_download https://dot.net/v1/dotnet-install.sh "$tmp_script" || {
    rm -f "$tmp_script"
    return 1
  }

  run_cmd bash "$tmp_script" --channel 8.0 --install-dir "${HOME}/.dotnet"
  run_cmd rm -f "$tmp_script"

  activate_dotnet_environment

  if ! command_exists dotnet && [[ ! -x ${HOME}/.dotnet/dotnet ]]; then
    warn ".NET install completed but dotnet is still unavailable in this shell"
    return 1
  fi
}

install_tauri() {
  install_rust || return 1
  install_nodejs || return 1
  activate_rust_environment

  install_package_key tauri-deps || true

  local tauri_cmd
  tauri_cmd="$(command -v tauri 2>/dev/null || true)"
  if [[ -z ${tauri_cmd} && -x ${INSTALL_USER_HOME}/.cargo/bin/tauri ]]; then
    tauri_cmd="${INSTALL_USER_HOME}/.cargo/bin/tauri"
  fi

  if [[ -n ${tauri_cmd} ]]; then
    log "tauri already installed"
    note_command_path_status tauri Tauri
    return 0
  fi

  local cargo_cmd
  if ! cargo_cmd="$(cargo_bin)"; then
    warn "cargo is required for tauri-cli"
    return 1
  fi

  run_cmd "$cargo_cmd" install tauri-cli --locked

  if [[ ! -x ${INSTALL_USER_HOME}/.cargo/bin/tauri ]]; then
    warn "tauri-cli metadata exists but tauri binary is missing; retrying with --force"
    run_cmd "$cargo_cmd" install tauri-cli --locked --force
  fi

  if [[ -x ${INSTALL_USER_HOME}/.cargo/bin/tauri ]]; then
    ensure_user_tool_path_persisted "${INSTALL_USER_HOME}/.cargo/bin" || true
    note_command_path_status tauri Tauri
    return 0
  fi

  warn "tauri-cli install completed but tauri is still unavailable in this shell"
  return 1
}

install_godot() {
  if command_exists godot4 || command_exists godot3 || command_exists godot; then
    log "godot already installed"
    return 0
  fi

  if install_package_key_first_available godot; then
    return 0
  fi

  install_snap_package godot --classic
}

install_opencode() {
  install_nodejs || return 1
  npm_global_install opencode-ai opencode
}

install_gentle_ai() {
  if command_exists gentle-ai; then
    log "gentle-ai already installed"
    return 0
  fi

  install_go || return 1
  require_install_user_context 'gentle-ai installation' || return 1

  local gobin
  gobin="$(install_user_bin_dir)"

  if (( DRY_RUN )); then
    :
  elif [[ -n ${SUDO_USER:-} ]]; then
    HOME="$INSTALL_USER_HOME" sudo -u "$SUDO_USER" mkdir -p "$gobin"
  else
    ensure_parent_dir "${gobin}/gentle-ai"
  fi

  if (( DRY_RUN )); then
    log "dry-run: GOBIN=${gobin} go install github.com/gentleman-programming/gentle-ai/cmd/gentle-ai@latest"
    return 0
  fi

  run_as_install_user env PATH="${gobin}:${PATH}" GOBIN="${gobin}" go install github.com/gentleman-programming/gentle-ai/cmd/gentle-ai@latest
  ensure_user_tool_path_persisted "$gobin" || true
}

install_codex() {
  install_nodejs || return 1
  npm_global_install @openai/codex codex
}

install_claude_code() {
  install_nodejs || return 1
  npm_global_install @anthropic-ai/claude-code claude
}

install_qwen_cli() {
  install_nodejs || return 1
  npm_global_install @qwen-code/qwen-code qwen
}

check_dotfiles() {
  local failures=0

  check_symlink_target "${HOME}/.config/autostart" "${CONFIG_ROOT}/autostart" || failures=$((failures + 1))
  check_symlink_target "${HOME}/.config/nvim" "${CONFIG_ROOT}/nvim" || failures=$((failures + 1))
  check_symlink_target "${HOME}/.config/kitty/kitty.conf" "${CONFIG_ROOT}/kitty/kitty.conf" || failures=$((failures + 1))
  check_symlink_target "${HOME}/.config/kitty/themes" "${CONFIG_ROOT}/kitty/themes" || failures=$((failures + 1))
  check_symlink_target "${HOME}/.config/tmux/tmux.conf" "${CONFIG_ROOT}/tmux/tmux.conf" || failures=$((failures + 1))
  check_symlink_target "${HOME}/.tmux.conf" "${HOME}/.config/tmux/tmux.conf" || failures=$((failures + 1))
  check_arch_aur_guard || failures=$((failures + 1))

  (( failures == 0 ))
}

check_tmux() {
  local failures=0
  check_command_component tmux Tmux || failures=$((failures + 1))
  check_command_component hostname Hostname || failures=$((failures + 1))
  check_symlink_target "${HOME}/.config/tmux/tmux.conf" "${CONFIG_ROOT}/tmux/tmux.conf" || failures=$((failures + 1))
  check_symlink_target "${HOME}/.tmux.conf" "${HOME}/.config/tmux/tmux.conf" || failures=$((failures + 1))

  if [[ -x ${HOME}/.tmux/plugins/tpm/tpm ]]; then
    log "check passed: Tmux Plugin Manager is installed"
  else
    warn "check failed: Tmux Plugin Manager is missing at ${HOME}/.tmux/plugins/tpm/tpm"
    failures=$((failures + 1))
  fi

  if [[ -d ${HOME}/.tmux/plugins/tmux-resurrect ]]; then
    log "check passed: tmux-resurrect is installed"
  else
    warn "check failed: tmux-resurrect is missing at ${HOME}/.tmux/plugins/tmux-resurrect"
    failures=$((failures + 1))
  fi

  if [[ -d ${HOME}/.tmux/plugins/tmux-continuum ]]; then
    log "check passed: tmux-continuum is installed"
  else
    warn "check failed: tmux-continuum is missing at ${HOME}/.tmux/plugins/tmux-continuum"
    failures=$((failures + 1))
  fi

  (( failures == 0 ))
}

tmux_plugin_manager_dir() {
  printf '%s\n' "${INSTALL_USER_HOME}/.tmux/plugins/tpm"
}

install_tmux_plugin_manager() {
  local tpm_dir
  local tpm_parent

  require_install_user_context "tmux plugin manager install" || return 0

  tpm_dir="$(tmux_plugin_manager_dir)"
  tpm_parent="$(dirname "$tpm_dir")"

  if [[ -x ${tpm_dir}/tpm ]]; then
    log "Tmux Plugin Manager already installed"
    return 0
  fi

  if ! command_exists git; then
    warn "git is required to install Tmux Plugin Manager automatically"
    return 1
  fi

  run_as_install_user mkdir -p "$tpm_parent"
  run_as_install_user git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
}

install_tmux_plugins() {
  local tpm_dir
  local tmux_conf

  require_install_user_context "tmux plugin install" || return 0

  tpm_dir="$(tmux_plugin_manager_dir)"
  tmux_conf="${INSTALL_USER_HOME}/.tmux.conf"

  if [[ ! -x ${tpm_dir}/bin/install_plugins ]]; then
    warn "Tmux Plugin Manager install script is missing at ${tpm_dir}/bin/install_plugins"
    return 1
  fi

  if [[ ! -r ${tmux_conf} ]]; then
    warn "tmux config is missing at ${tmux_conf}; skipping tmux plugin installation"
    return 0
  fi

  run_as_install_user env HOME="$INSTALL_USER_HOME" tmux start-server \; set-environment -g TMUX_PLUGIN_MANAGER_PATH "${INSTALL_USER_HOME}/.tmux/plugins/" || return 1
  run_as_install_user env HOME="$INSTALL_USER_HOME" "${tpm_dir}/bin/install_plugins"
}

check_zsh() {
  local failures=0

  check_command_component zsh Zsh || failures=$((failures + 1))

  if default_shell_is_zsh; then
    log "check passed: zsh is the default shell"
  elif (( EUID == 0 )) || is_wsl_environment || is_container_environment || ! command_exists chsh; then
    warn "check skipped: default shell is not zsh, and automatic shell switching is unsupported in this context"
  else
    warn "check failed: default shell is not zsh; run chsh -s \"$(command -v zsh)\" manually if the installer could not change it"
    failures=$((failures + 1))
  fi

  (( failures == 0 ))
}

set_default_shell_to_zsh() {
  local zsh_path

  zsh_path="$(command -v zsh 2>/dev/null || true)"
  if [[ -z $zsh_path ]]; then
    warn "zsh was not found after installation; skipping default-shell change"
    return 0
  fi

  if default_shell_is_zsh; then
    log "zsh is already the default shell"
    return 0
  fi

  if (( EUID == 0 )); then
    warn "zsh is installed, but this installer is running as root so it will not change the user's login shell; run chsh -s \"${zsh_path}\" manually as the target user"
    return 0
  fi

  if is_wsl_environment; then
    warn "zsh is installed, but this looks like WSL so the installer will not change the login shell automatically; run chsh -s \"${zsh_path}\" manually if desired"
    return 0
  fi

  if is_container_environment; then
    warn "zsh is installed, but this looks like a container so the installer will not change the login shell automatically; run chsh -s \"${zsh_path}\" manually if desired"
    return 0
  fi

  if ! command_exists chsh; then
    warn "zsh is installed, but chsh is unavailable; run chsh -s \"${zsh_path}\" manually to make it the default shell"
    return 0
  fi

  if [[ ! -r /etc/shells ]] || ! grep -Fxq -- "$zsh_path" /etc/shells 2>/dev/null; then
    warn "zsh is installed, but ${zsh_path} is not listed in /etc/shells; add it there first or set the login shell manually with chsh"
    return 0
  fi

  if ! ui_has_tty; then
    warn "zsh is installed, but no interactive tty is available for chsh; run chsh -s \"${zsh_path}\" manually after entering your password"
    return 0
  fi

  if (( DRY_RUN )); then
    log "dry-run: chsh -s ${zsh_path}"
    return 0
  fi

  if chsh -s "$zsh_path"; then
    log "default shell changed to zsh"
  else
    warn "automatic shell change failed; run chsh -s \"${zsh_path}\" manually after entering your password"
  fi
}

check_nvim() {
  local failures=0
  check_command_min_version nvim Neovim 0.9.0 --version || failures=$((failures + 1))
  check_symlink_target "${HOME}/.config/nvim" "${CONFIG_ROOT}/nvim" || failures=$((failures + 1))
  (( failures == 0 ))
}

check_gcc() {
  local failures=0
  check_command_component gcc GCC || failures=$((failures + 1))
  check_command_component g++ 'G++' || failures=$((failures + 1))
  (( failures == 0 ))
}

check_python() {
  local failures=0

  if command_exists python3 || command_exists python; then
    log "check passed: Python interpreter"
  else
    warn "check failed: Python interpreter not found"
    failures=$((failures + 1))
  fi

  if command_exists pip3 || command_exists pip; then
    log "check passed: Python package manager"
  else
    warn "check failed: pip not found"
    failures=$((failures + 1))
  fi

  (( failures == 0 ))
}

check_nodejs() {
  local failures=0

  if is_wsl_environment; then
    local node_cmd
    if node_cmd="$(native_node_command 2>/dev/null)"; then
      check_command_min_version "$node_cmd" Node.js 18.0.0 --version || failures=$((failures + 1))
    else
      warn "check failed: Node.js not found inside WSL"
      failures=$((failures + 1))
    fi

    check_native_command_component npm npm || failures=$((failures + 1))
    (( failures == 0 ))
    return 0
  fi

  check_command_min_version node Node.js 18.0.0 --version || failures=$((failures + 1))
  check_command_component npm npm || failures=$((failures + 1))
  (( failures == 0 ))
}

check_rust() {
  local failures=0

  activate_rust_environment

  if command_exists rustup || [[ -x ${INSTALL_USER_HOME}/.cargo/bin/rustup ]]; then
    log "check passed: rustup"
    note_command_path_status rustup rustup
  else
    warn "check failed: rustup not found"
    failures=$((failures + 1))
  fi

  local cargo_cmd
  if cargo_cmd="$(cargo_bin 2>/dev/null)"; then
    check_command_min_version "$cargo_cmd" cargo 1.75.0 --version || failures=$((failures + 1))
  else
    warn "check failed: cargo not found"
    failures=$((failures + 1))
  fi

  local rustc_cmd
  rustc_cmd="$(command -v rustc 2>/dev/null || true)"
  if [[ -z ${rustc_cmd} && -x ${INSTALL_USER_HOME}/.cargo/bin/rustc ]]; then
    rustc_cmd="${INSTALL_USER_HOME}/.cargo/bin/rustc"
  fi

  if [[ -n ${rustc_cmd} ]]; then
    check_command_min_version "$rustc_cmd" Rust 1.75.0 --version || failures=$((failures + 1))
  else
    warn "check failed: rustc not found"
    failures=$((failures + 1))
  fi

  (( failures == 0 ))
}

check_go() {
  check_command_min_version go Go 1.22.0 version
}

check_nerd_fonts() {
  if have_caskaydia_nerd_font; then
    log "check passed: Nerd Fonts"
    return 0
  fi

  warn "check failed: CaskaydiaCove Nerd Font not found"
  return 1
}

check_dotnet() {
  activate_dotnet_environment

  if command_exists dotnet || [[ -x ${HOME}/.dotnet/dotnet ]]; then
    log "check passed: .NET SDK"
    note_command_path_status dotnet '.NET SDK'
    return 0
  fi

  warn "check failed: dotnet not found"
  return 1
}

check_tauri() {
  local failures=0
  check_rust || failures=$((failures + 1))
  check_nodejs || failures=$((failures + 1))

  activate_rust_environment

  local tauri_cmd
  tauri_cmd="$(command -v tauri 2>/dev/null || true)"
  if [[ -z ${tauri_cmd} && -x ${INSTALL_USER_HOME}/.cargo/bin/tauri ]]; then
    tauri_cmd="${INSTALL_USER_HOME}/.cargo/bin/tauri"
  fi

  if [[ -n ${tauri_cmd} ]]; then
    log "check passed: Tauri"
    note_command_path_status tauri Tauri
  else
    warn "check failed: Tauri command not found"
    failures=$((failures + 1))
  fi

  (( failures == 0 ))
}

check_godot() {
  if command_exists godot4 || command_exists godot3 || command_exists godot; then
    log "check passed: Godot"
    return 0
  fi

  warn "check failed: Godot not found"
  return 1
}

uninstall_gentle_ai() {
  local binary_path="$(install_user_bin_dir)/gentle-ai"

  if [[ ! -e ${binary_path} ]]; then
    log "skip gentle-ai uninstall: ${binary_path} not present"
    return 0
  fi

  remove_install_user_file "${binary_path}"
}

uninstall_rust() {
  require_install_user_context 'Rust uninstall' || return 1

  local rustup_cmd=
  local cargo_home="${INSTALL_USER_HOME}/.cargo"
  local rustup_home="${INSTALL_USER_HOME}/.rustup"

  if [[ -x ${cargo_home}/bin/rustup ]]; then
    rustup_cmd="${cargo_home}/bin/rustup"
  elif native_command_exists rustup; then
    rustup_cmd="$(native_command_path rustup 2>/dev/null || true)"
  fi

  if [[ -n ${rustup_cmd} ]]; then
    if (( DRY_RUN )); then
      log "dry-run: ${rustup_cmd} self uninstall -y"
    else
      run_as_install_user env HOME="${INSTALL_USER_HOME}" PATH="${cargo_home}/bin:${PATH}" "$rustup_cmd" self uninstall -y || return 1
    fi
  elif [[ ! -d ${cargo_home} && ! -d ${rustup_home} ]]; then
    log "skip rust uninstall: no user-scoped rustup installation found"
    return 0
  fi

  remove_install_user_file "${cargo_home}/env"

  if [[ -d ${cargo_home} || -L ${cargo_home} ]]; then
    if (( DRY_RUN )); then
      log "dry-run: rm -rf ${cargo_home}"
    elif [[ -n ${SUDO_USER:-} ]]; then
      HOME="$INSTALL_USER_HOME" sudo -u "$SUDO_USER" rm -rf "$cargo_home"
    else
      rm -rf "$cargo_home"
    fi
  fi

  if [[ -d ${rustup_home} || -L ${rustup_home} ]]; then
    if (( DRY_RUN )); then
      log "dry-run: rm -rf ${rustup_home}"
    elif [[ -n ${SUDO_USER:-} ]]; then
      HOME="$INSTALL_USER_HOME" sudo -u "$SUDO_USER" rm -rf "$rustup_home"
    else
      rm -rf "$rustup_home"
    fi
  fi
}

uninstall_tauri() {
  local cargo_cmd
  if ! cargo_cmd="$(cargo_bin)"; then
    log "skip tauri uninstall: cargo not installed"
    return 0
  fi

  run_cmd "$cargo_cmd" uninstall tauri-cli
}
