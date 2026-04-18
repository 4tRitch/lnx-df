source "${HOME}/lnx-df/config/zsh/bootstrap.zsh"
source "${DCONF}/zsh/root-safe.zsh"
# source "${DCONF}/zsh/psdk.zsh" # Only Uncomment if you have de SDK's





# opencode
if [[ -d /home/at_ritch/.opencode/bin ]]; then
  export PATH=/home/at_ritch/.opencode/bin:$PATH
fi
