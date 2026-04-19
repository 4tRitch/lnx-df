#!/usr/bin/env bash

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${COMMON_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${INSTALLER_ROOT}/.." && pwd)"
CONFIG_ROOT="${REPO_ROOT}/config"

DRY_RUN=${DRY_RUN:-0}
APT_UPDATED=0
PACMAN_UPDATED=0
DNF_UPDATED=0
ORIGINAL_PATH=${PATH:-}
USER_TOOL_PATHS=(
  "${HOME}/.local/bin"
  "${HOME}/.cargo/bin"
  "${HOME}/.dotnet"
  "${HOME}/.dotnet/tools"
)
PATH_RELOAD_REQUIRED_DIRS=()
PATH_PERSISTENCE_MISSING_DIRS=()
PATH_NOTICE_KEYS=' '

DISTRO_ID=
DISTRO_NAME=
DISTRO_FAMILY=
PACKAGE_MANAGER=

path_contains_entry() {
  local path_entry=$1
  local path_value=${2:-$PATH}

  [[ :${path_value}: == *":${path_entry}:"* ]]
}

known_user_tool_path() {
  local path_entry=$1
  local known_path

  for known_path in "${USER_TOOL_PATHS[@]}"; do
    [[ $known_path == "$path_entry" ]] && return 0
  done

  return 1
}

shell_config_candidates() {
  printf '%s\n' \
    "${HOME}/.profile" \
    "${HOME}/.bash_profile" \
    "${HOME}/.bashrc" \
    "${HOME}/.zprofile" \
    "${HOME}/.zshrc"
}

path_reference_variants() {
  local path_entry=$1

  printf '%s\n' "$path_entry"

  if [[ $path_entry == "${HOME}"* ]]; then
    printf '%s\n' "~${path_entry#${HOME}}"
    printf '%s\n' "\$HOME${path_entry#${HOME}}"
    printf '%s\n' "\${HOME}${path_entry#${HOME}}"
  fi
}

shell_config_references_path() {
  local path_entry=$1
  local config_file
  local variant

  while IFS= read -r config_file; do
    [[ -r $config_file ]] || continue

    while IFS= read -r variant; do
      [[ -n $variant ]] || continue
      if grep -Fq -- "$variant" "$config_file"; then
        return 0
      fi
    done < <(path_reference_variants "$path_entry")
  done < <(shell_config_candidates)

  return 1
}

record_path_notice() {
  local bucket_name=$1
  local path_entry=$2
  local key=" ${bucket_name}:${path_entry} "

  if [[ $PATH_NOTICE_KEYS == *"${key}"* ]]; then
    return 0
  fi

  PATH_NOTICE_KEYS+="${bucket_name}:${path_entry} "
  eval "${bucket_name}+=(\"${path_entry}\")"
}

note_command_path_status() {
  local command_name=$1
  local label=${2:-$1}

  if ! command_exists "$command_name"; then
    return 0
  fi

  local command_path
  command_path="$(command -v "$command_name" 2>/dev/null || true)"
  [[ -n $command_path ]] || return 0

  local path_entry
  path_entry="$(dirname "$command_path")"

  if ! known_user_tool_path "$path_entry"; then
    return 0
  fi

  if path_contains_entry "$path_entry" "$ORIGINAL_PATH"; then
    return 0
  fi

  if shell_config_references_path "$path_entry"; then
    warn "${label} is available in this installer run via ${path_entry}; reload your shell or open a new terminal to use it normally"
    record_path_notice PATH_RELOAD_REQUIRED_DIRS "$path_entry"
    return 0
  fi

  warn "${label} is available in this installer run via ${path_entry}, but that path was not found in common shell startup files"
  warn "future shells may still miss ${label} until you add ${path_entry} to ~/.profile, ~/.bashrc, ~/.bash_profile, ~/.zprofile, or ~/.zshrc"
  record_path_notice PATH_PERSISTENCE_MISSING_DIRS "$path_entry"
}

prepend_path_once() {
  local path_entry=$1

  [[ -d ${path_entry} ]] || return 0
  path_contains_entry "$path_entry" && return 0

  PATH="${path_entry}:${PATH}"
}

activate_user_tool_paths() {
  prepend_path_once "${HOME}/.local/bin"
  prepend_path_once "${HOME}/.cargo/bin"
  prepend_path_once "${HOME}/.dotnet"
  prepend_path_once "${HOME}/.dotnet/tools"
}

activate_user_tool_paths

is_wsl_environment() {
  [[ -n ${WSL_INTEROP:-} || -n ${WSL_DISTRO_NAME:-} ]] && return 0

  if [[ -r /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    return 0
  fi

  return 1
}

is_container_environment() {
  [[ -f /.dockerenv || -f /run/.containerenv ]] && return 0

  if [[ -r /proc/1/cgroup ]] && grep -Eq '(docker|containerd|podman|lxc)' /proc/1/cgroup 2>/dev/null; then
    return 0
  fi

  return 1
}

current_login_shell() {
  local username=${SUDO_USER:-${USER:-}}
  local passwd_entry=
  local getent_cmd=

  if [[ -z $username ]]; then
    username="$(id -un 2>/dev/null || true)"
  fi

  getent_cmd="$(command -v getent 2>/dev/null || true)"
  if [[ -n $username && -n $getent_cmd ]]; then
    passwd_entry="$(getent passwd "$username" 2>/dev/null || true)"
  fi

  if [[ -z $passwd_entry && -n $username && -r /etc/passwd ]]; then
    passwd_entry="$(awk -F: -v user="$username" '$1 == user { print; exit }' /etc/passwd)"
  fi

  [[ -n $passwd_entry ]] || return 1
  printf '%s\n' "${passwd_entry##*:}"
}

resolved_shell_path() {
  local shell_path=$1

  [[ -n $shell_path ]] || return 1

  if command_exists readlink; then
    readlink -f "$shell_path" 2>/dev/null || printf '%s\n' "$shell_path"
  else
    printf '%s\n' "$shell_path"
  fi
}

default_shell_is_zsh() {
  local current_shell
  local zsh_path
  local resolved_current_shell
  local resolved_zsh_path

  current_shell="$(current_login_shell 2>/dev/null || true)"
  zsh_path="$(command -v zsh 2>/dev/null || true)"

  [[ -n $current_shell && -n $zsh_path ]] || return 1
  resolved_current_shell="$(resolved_shell_path "$current_shell")"
  resolved_zsh_path="$(resolved_shell_path "$zsh_path")"
  [[ $resolved_current_shell == "$resolved_zsh_path" ]]
}

supports_color() {
  [[ -t 1 || -t 2 ]] && [[ ${TERM:-dumb} != dumb ]]
}

color_value() {
  case "$1" in
    reset) printf '\033[0m' ;;
    dim) printf '\033[38;5;245m' ;;
    soft) printf '\033[38;5;250m' ;;
    success) printf '\033[38;5;46m' ;;
    warning) printf '\033[38;5;226m' ;;
    error) printf '\033[38;5;196m' ;;
    info) printf '\033[38;5;255m' ;;
    *) return 1 ;;
  esac
}

paint() {
  local tone=$1
  shift

  if supports_color; then
    printf '%b%s%b' "$(color_value "$tone")" "$*" "$(color_value reset)"
  else
    printf '%s' "$*"
  fi
}

log() {
  printf '%s %s\n' "$(paint soft '[lnx-df]')" "$*"
}

warn() {
  printf '%s %s\n' "$(paint warning '[lnx-df] warning:')" "$*" >&2
}

error() {
  printf '%s %s\n' "$(paint error '[lnx-df] error:')" "$*" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

extract_semver() {
  local input=$1

  if [[ $input =~ ([0-9]+(\.[0-9]+){0,2}) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

version_gte() {
  local current=$1
  local minimum=$2
  local current_parts=()
  local minimum_parts=()
  local idx

  IFS='.' read -r -a current_parts <<<"$current"
  IFS='.' read -r -a minimum_parts <<<"$minimum"

  for idx in 0 1 2; do
    local current_part=${current_parts[$idx]:-0}
    local minimum_part=${minimum_parts[$idx]:-0}

    if (( current_part > minimum_part )); then
      return 0
    fi

    if (( current_part < minimum_part )); then
      return 1
    fi
  done

  return 0
}

load_platform_info() {
  if [[ -n ${DISTRO_ID} ]]; then
    return 0
  fi

  if [[ -r /etc/os-release ]]; then
    DISTRO_ID=
    DISTRO_NAME=
    DISTRO_FAMILY=

    . /etc/os-release

    DISTRO_ID=${ID:-unknown}
    DISTRO_NAME=${PRETTY_NAME:-${NAME:-$DISTRO_ID}}

    case "${ID:-}" in
      ubuntu|pop|debian)
        DISTRO_FAMILY=debian
        ;;
      arch|manjaro|endeavouros)
        DISTRO_FAMILY=arch
        ;;
      fedora)
        DISTRO_FAMILY=fedora
        ;;
      *)
        case " ${ID_LIKE:-} " in
          *" debian "*) DISTRO_FAMILY=debian ;;
          *" arch "*) DISTRO_FAMILY=arch ;;
          *" fedora "*|*" rhel "*) DISTRO_FAMILY=fedora ;;
          *) DISTRO_FAMILY=${ID:-unknown} ;;
        esac
        ;;
    esac
  else
    DISTRO_ID=unknown
    DISTRO_NAME=unknown
    DISTRO_FAMILY=unknown
  fi

  case "${DISTRO_FAMILY}" in
    debian)
      if command_exists apt-get && command_exists apt-cache; then
        PACKAGE_MANAGER=apt
      fi
      ;;
    arch)
      if command_exists pacman; then
        PACKAGE_MANAGER=pacman
      fi
      ;;
    fedora)
      if command_exists dnf; then
        PACKAGE_MANAGER=dnf
      fi
      ;;
  esac

  if [[ -z ${PACKAGE_MANAGER} ]]; then
    if command_exists apt-get && command_exists apt-cache; then
      PACKAGE_MANAGER=apt
    elif command_exists pacman; then
      PACKAGE_MANAGER=pacman
    elif command_exists dnf; then
      PACKAGE_MANAGER=dnf
    else
      PACKAGE_MANAGER=unknown
    fi
  fi
}

run_cmd() {
  if (( DRY_RUN )); then
    printf '[lnx-df] dry-run:'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

sudo_prefix() {
  if (( EUID == 0 )); then
    printf '%s\n' ''
    return 0
  fi

  if command_exists sudo; then
    printf 'sudo'
    return 0
  fi

  return 1
}

is_debian_like() {
  load_platform_info
  [[ ${DISTRO_FAMILY} == debian ]]
}

have_apt() {
  load_platform_info
  [[ ${PACKAGE_MANAGER} == apt ]]
}

have_pacman() {
  load_platform_info
  [[ ${PACKAGE_MANAGER} == pacman ]]
}

have_dnf() {
  load_platform_info
  [[ ${PACKAGE_MANAGER} == dnf ]]
}

have_snap() {
  command_exists snap
}

apt_update_once() {
  if (( APT_UPDATED )); then
    return 0
  fi

  local sudo_cmd
  if ! sudo_cmd="$(sudo_prefix)"; then
    warn "sudo is required for apt installs"
    return 1
  fi

  if (( DRY_RUN )); then
    if [[ -n $sudo_cmd ]]; then
      log "dry-run: ${sudo_cmd} apt-get update"
    else
      log "dry-run: apt-get update"
    fi
    APT_UPDATED=1
    return 0
  fi

  if [[ -n $sudo_cmd ]]; then
    "${sudo_cmd}" apt-get update
  else
    apt-get update
  fi
  APT_UPDATED=1
}

apt_has_package() {
  apt-cache show "$1" >/dev/null 2>&1
}

pacman_has_package() {
  pacman -Si "$1" >/dev/null 2>&1
}

paru_has_package() {
  command_exists paru && paru -Si "$1" >/dev/null 2>&1
}

dnf_has_package() {
  dnf info "$1" >/dev/null 2>&1
}

package_manager_label() {
  load_platform_info
  printf '%s\n' "${PACKAGE_MANAGER}"
}

describe_platform() {
  load_platform_info
  printf '%s (%s/%s)\n' "${DISTRO_NAME}" "${DISTRO_ID}" "${PACKAGE_MANAGER}"
}

install_apt_packages() {
  if ! have_apt; then
    warn "apt is not available on this system; skipping: $*"
    return 1
  fi

  local filtered=()
  local pkg
  for pkg in "$@"; do
    if apt_has_package "$pkg"; then
      filtered+=("$pkg")
    else
      warn "package not available in apt repos: ${pkg}"
    fi
  done

  if (( ${#filtered[@]} == 0 )); then
    warn "no apt packages were available to install"
    return 1
  fi

  local sudo_cmd
  if ! sudo_cmd="$(sudo_prefix)"; then
    warn "sudo is required for apt installs"
    return 1
  fi

  apt_update_once || return 1

  if [[ -n $sudo_cmd ]]; then
    run_cmd "${sudo_cmd}" apt-get install -y "${filtered[@]}"
  else
    run_cmd apt-get install -y "${filtered[@]}"
  fi
}

pacman_update_once() {
  if (( PACMAN_UPDATED )); then
    return 0
  fi

  local sudo_cmd
  if ! sudo_cmd="$(sudo_prefix)"; then
    warn "sudo is required for pacman installs"
    return 1
  fi

  if (( DRY_RUN )); then
    if [[ -n $sudo_cmd ]]; then
      log "dry-run: ${sudo_cmd} pacman -Sy"
    else
      log "dry-run: pacman -Sy"
    fi
    PACMAN_UPDATED=1
    return 0
  fi

  if [[ -n $sudo_cmd ]]; then
    "${sudo_cmd}" pacman -Sy
  else
    pacman -Sy
  fi
  PACMAN_UPDATED=1
}

dnf_update_once() {
  if (( DNF_UPDATED )); then
    return 0
  fi

  local sudo_cmd
  if ! sudo_cmd="$(sudo_prefix)"; then
    warn "sudo is required for dnf installs"
    return 1
  fi

  if (( DRY_RUN )); then
    if [[ -n $sudo_cmd ]]; then
      log "dry-run: ${sudo_cmd} dnf makecache"
    else
      log "dry-run: dnf makecache"
    fi
    DNF_UPDATED=1
    return 0
  fi

  if [[ -n $sudo_cmd ]]; then
    "${sudo_cmd}" dnf makecache
  else
    dnf makecache
  fi
  DNF_UPDATED=1
}

install_pacman_packages() {
  if ! have_pacman; then
    warn "pacman is not available on this system; skipping: $*"
    return 1
  fi

  local pacman_filtered=()
  local aur_filtered=()
  local pkg
  for pkg in "$@"; do
    if pacman_has_package "$pkg"; then
      pacman_filtered+=("$pkg")
    elif (( EUID == 0 )); then
      warn "package not available in pacman repos and AUR lookup is skipped as root: ${pkg}"
    elif command_exists paru && paru_has_package "$pkg"; then
      aur_filtered+=("$pkg")
    elif command_exists paru; then
      warn "package not available in pacman repos or AUR via paru: ${pkg}"
    else
      warn "package not available in pacman repos and paru is not installed: ${pkg}"
    fi
  done

  if (( ${#pacman_filtered[@]} == 0 )) && (( ${#aur_filtered[@]} == 0 )); then
    warn "no pacman or AUR packages were available to install"
    return 1
  fi

  if (( ${#pacman_filtered[@]} > 0 )); then
    local sudo_cmd
    if ! sudo_cmd="$(sudo_prefix)"; then
      warn "sudo is required for pacman installs"
      return 1
    fi

    pacman_update_once || return 1

    if [[ -n $sudo_cmd ]]; then
      run_cmd "${sudo_cmd}" pacman -S --needed --noconfirm "${pacman_filtered[@]}"
    else
      run_cmd pacman -S --needed --noconfirm "${pacman_filtered[@]}"
    fi
  fi

  if (( ${#aur_filtered[@]} > 0 )); then
    run_cmd paru -S --needed --noconfirm "${aur_filtered[@]}"
  fi
}

install_dnf_packages() {
  if ! have_dnf; then
    warn "dnf is not available on this system; skipping: $*"
    return 1
  fi

  local filtered=()
  local pkg
  for pkg in "$@"; do
    if dnf_has_package "$pkg"; then
      filtered+=("$pkg")
    else
      warn "package not available in dnf repos: ${pkg}"
    fi
  done

  if (( ${#filtered[@]} == 0 )); then
    warn "no dnf packages were available to install"
    return 1
  fi

  local sudo_cmd
  if ! sudo_cmd="$(sudo_prefix)"; then
    warn "sudo is required for dnf installs"
    return 1
  fi

  dnf_update_once || return 1

  if [[ -n $sudo_cmd ]]; then
    run_cmd "${sudo_cmd}" dnf install -y "${filtered[@]}"
  else
    run_cmd dnf install -y "${filtered[@]}"
  fi
}

install_system_packages() {
  load_platform_info

  case "${PACKAGE_MANAGER}" in
    apt) install_apt_packages "$@" ;;
    pacman) install_pacman_packages "$@" ;;
    dnf) install_dnf_packages "$@" ;;
    *)
      warn "no supported package manager found; skipping: $*"
      return 1
      ;;
  esac
}

system_package_available() {
  load_platform_info

  case "${PACKAGE_MANAGER}" in
    apt) apt_has_package "$1" ;;
    pacman) pacman_has_package "$1" ;;
    dnf) dnf_has_package "$1" ;;
    *) return 1 ;;
  esac
}

install_first_available_system_package() {
  local pkg
  for pkg in "$@"; do
    if system_package_available "$pkg"; then
      install_system_packages "$pkg"
      return $?
    fi
  done

  warn "none of these packages are available via $(package_manager_label): $*"
  return 1
}

install_snap_package() {
  local package_name=$1
  shift || true

  if ! have_snap; then
    warn "snap is not available; skipping ${package_name}"
    return 1
  fi

  local sudo_cmd
  if ! sudo_cmd="$(sudo_prefix)"; then
    warn "sudo is required for snap installs"
    return 1
  fi

  if [[ -n $sudo_cmd ]]; then
    run_cmd "${sudo_cmd}" snap install "$package_name" "$@"
  else
    run_cmd snap install "$package_name" "$@"
  fi
}

backup_path() {
  local target=$1
  local backup="${target}.lnx-df.bak.$(date +%Y%m%d%H%M%S)"

  if (( DRY_RUN )); then
    log "dry-run: mv ${target} ${backup}"
    return 0
  fi

  mv "$target" "$backup"
  log "backed up ${target} -> ${backup}"
}

ensure_parent_dir() {
  local target=$1
  local parent
  parent="$(dirname "$target")"

  if [[ -d $parent ]]; then
    return 0
  fi

  run_cmd mkdir -p "$parent"
}

ensure_symlink() {
  local source=$1
  local target=$2

  if [[ ! -e $source ]]; then
    warn "source does not exist, skipping link: ${source}"
    return 1
  fi

  ensure_parent_dir "$target"

  if [[ -L $target ]]; then
    local current
    current="$(readlink -f "$target" 2>/dev/null || true)"
    local desired
    desired="$(readlink -f "$source" 2>/dev/null || true)"

    if [[ -n $current && -n $desired && $current == "$desired" ]]; then
      log "link already correct: ${target}"
      return 0
    fi

    backup_path "$target"
  elif [[ -e $target ]]; then
    backup_path "$target"
  fi

  run_cmd ln -s "$source" "$target"
  if (( DRY_RUN )); then
    log "would link ${target} -> ${source}"
  else
    log "linked ${target} -> ${source}"
  fi
}

remove_repo_symlink() {
  local target=$1

  if [[ ! -L $target ]]; then
    log "skip ${target}: not a symlink"
    return 0
  fi

  local current
  current="$(readlink -f "$target" 2>/dev/null || true)"
  if [[ -z $current || $current != ${REPO_ROOT}* ]]; then
    log "skip ${target}: symlink is not managed by this repo"
    return 0
  fi

  run_cmd rm "$target"
  if (( DRY_RUN )); then
    log "would remove ${target}"
  else
    log "removed ${target}"
  fi
}

npm_global_install() {
  local package_name=$1
  local command_name=$2

  if command_exists "$command_name"; then
    log "${command_name} already available"
    return 0
  fi

  if ! command_exists npm; then
    warn "npm is required to install ${package_name}"
    return 1
  fi

  run_cmd npm install -g "$package_name"
}

npm_global_uninstall() {
  local package_name=$1

  if ! command_exists npm; then
    log "skip npm uninstall for ${package_name}: npm not installed"
    return 0
  fi

  run_cmd npm uninstall -g "$package_name"
}

cargo_bin() {
  if command_exists cargo; then
    command -v cargo
    return 0
  fi

  if [[ -x ${HOME}/.cargo/bin/cargo ]]; then
    printf '%s\n' "${HOME}/.cargo/bin/cargo"
    return 0
  fi

  return 1
}

curl_download() {
  local url=$1
  local destination=$2

  if ! command_exists curl; then
    warn "curl is required: ${url}"
    return 1
  fi

  run_cmd curl -fsSL "$url" -o "$destination"
}
