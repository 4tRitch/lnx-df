typeset -g ZSH_SHARED_CONFIG_ROOT="${ZSH_SHARED_CONFIG_ROOT:-/home/at_ritch/lnx-df/config}"

if [[ ! -d $ZSH_SHARED_CONFIG_ROOT ]]; then
  for candidate in \
    "/home/at_ritch/lnx-df/config" \
    "$HOME/.config"; do
    if [[ -d $candidate ]]; then
      ZSH_SHARED_CONFIG_ROOT=$candidate
      break
    fi
  done
fi

typeset -g DCONF="$ZSH_SHARED_CONFIG_ROOT"
typeset -g DEVD="${DEVD:-/home/at_ritch/dev}"
typeset -g DFL="${DFL:-/home/at_ritch/lnx-df}"
typeset -g ZSH_IS_ROOT=0

if (( EUID == 0 )); then
  ZSH_IS_ROOT=1
  DEVD=/home/at_ritch/dev
  DFL=/home/at_ritch/lnx-df
fi

typeset -g ZINIT_HOME="${ZINIT_HOME:-${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git}"
