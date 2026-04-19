typeset -g ZSH_CAN_LOAD_ZINIT=0
typeset -g ZSH_COMPINIT_DUMP="${XDG_CACHE_HOME:-${HOME}/.cache}/zsh/zcompdump"

mkdir -p "${ZSH_COMPINIT_DUMP:h}"
autoload -Uz compinit

if [[ -r "${ZINIT_HOME}/zinit.zsh" ]]; then
  ZSH_CAN_LOAD_ZINIT=1
  source "${ZINIT_HOME}/zinit.zsh"
fi

if [[ $ZSH_CAN_LOAD_ZINIT -eq 1 ]]; then
  source "${DCONF}/zsh/plugins.zsh"
fi

compinit -C -d "${ZSH_COMPINIT_DUMP}"

source "${DCONF}/zsh/aliases.zsh"
source "${DCONF}/zsh/items-list.zsh"
source "${DCONF}/zsh/git.zsh"
source "${DCONF}/zsh/powerline.zsh"

if [[ $ZSH_IS_ROOT -eq 0 ]]; then
  source "${DCONF}/zsh/env.zsh"
fi
