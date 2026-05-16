if status is-interactive
  # env STEAM_FORCE_DESKTOPUI_SCALING=1 steam
  set -Ux MOZ_ENABLE_WAYLAND 1
  set -Ux XDG_DATA_DIRS /var/lib/flatpak/exports/share $HOME/.local/share/flatpak/exports/share $XDG_DATA_DIRS
set -Ux QT_QPA_PLATFORMTHEME qt6ct
set -Ux QT_STYLE_OVERRIDE breeze

  if command -q zoxide
    zoxide init fish | source
  end

  if not set -q SSH_AUTH_SOCK
    eval (ssh-agent -c) >/dev/null
  end
end

if test -d $HOME/.opencode/bin
  fish_add_path --path $HOME/.opencode/bin
end

fish_add_path --path $HOME/.local/bin

if test -f $HOME/.cargo/env.fish
  source $HOME/.cargo/env.fish
end

if test -d $HOME/.dotnet
  fish_add_path --path $HOME/.dotnet $HOME/.dotnet/tools
end

# pnpm
set -gx PNPM_HOME "/home/ritch/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
set -x PATH $PATH /home/ritch/.local/share/npm-global/lib/node_modules
set -x PATH $PATH /home/ritch/.local/share/pnpm/bin
