typeset -g LNX_DF_CONFIG_ROOT="${LNX_DF_CONFIG_ROOT:-${${(%):-%N}:A:h}}"
typeset -g LNX_DF_REPO="${LNX_DF_REPO:-${LNX_DF_CONFIG_ROOT:h}}"

source "${LNX_DF_CONFIG_ROOT}/zsh/bootstrap.zsh"
source "${DCONF}/zsh/root-safe.zsh"
 # source "${DCONF}/zsh/psdk.zsh" # Only Uncomment if you have de SDK's





# opencode
if [[ -d ${HOME}/.opencode/bin ]]; then
  export PATH=${HOME}/.opencode/bin:$PATH
fi
