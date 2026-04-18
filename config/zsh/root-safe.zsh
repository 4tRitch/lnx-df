typeset -g ZSH_CAN_LOAD_ZINIT=0

if [[ -r "${ZINIT_HOME}/zinit.zsh" ]]; then
  ZSH_CAN_LOAD_ZINIT=1
  source "${ZINIT_HOME}/zinit.zsh"
fi

if [[ $ZSH_CAN_LOAD_ZINIT -eq 1 ]]; then
  source "${DCONF}/zsh/plugins.zsh"
else
  autoload -Uz compinit
  compinit
fi

source "${DCONF}/zsh/aliases.zsh"
source "${DCONF}/zsh/git.zsh"
source "${DCONF}/zsh/powerline.zsh"

if [[ $ZSH_IS_ROOT -eq 0 ]]; then
  source "${DCONF}/zsh/env.zsh"
fi
