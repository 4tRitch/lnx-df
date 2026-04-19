# It doesn't a plugin but works with zsh
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# Cargo(Rustlang) enviroment
if [[ -f ${HOME}/.cargo/env ]]; then
  . "${HOME}/.cargo/env"
fi

if [[ -d ${HOME}/.dotnet ]]; then
  export PATH="${HOME}/.dotnet:${HOME}/.dotnet/tools:$PATH"
fi

export PATH="$HOME/.local/bin:$PATH"
