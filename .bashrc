#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
. "$HOME/.cargo/env"

export PATH=$PATH:/home/ritch/.spicetify

. "$HOME/.local/share/../bin/env"

# npm global bin for codegraph and other tools
export PATH="$HOME/.local/share/npm-global/bin:$PATH"
