typeset -g ZSH_BOOTSTRAP_FILE="${${(%):-%N}:A}"
typeset -g ZSH_SHARED_CONFIG_ROOT="${ZSH_SHARED_CONFIG_ROOT:-${ZSH_BOOTSTRAP_FILE:h:h}}"
typeset -g DFL="${DFL:-${ZSH_SHARED_CONFIG_ROOT:h}}"

if [[ ! -d $ZSH_SHARED_CONFIG_ROOT ]]; then
  for candidate in \
    "${DFL}/config" \
    "$HOME/.config"; do
    if [[ -d $candidate ]]; then
      ZSH_SHARED_CONFIG_ROOT=$candidate
      break
    fi
  done
fi

typeset -g DCONF="$ZSH_SHARED_CONFIG_ROOT"
typeset -g DEVD="${DEVD:-${HOME}/dev}"
typeset -g ZSH_IS_ROOT=0

if (( EUID == 0 )); then
  ZSH_IS_ROOT=1
  DEVD=${DEVD:-${HOME}/dev}
fi

typeset -g ZINIT_HOME="${ZINIT_HOME:-${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git}"
