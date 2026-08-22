if status is-interactive
  # env STEAM_FORCE_DESKTOPUI_SCALING=1 steam
  set -gx MOZ_ENABLE_WAYLAND 1
  set -gx XDG_DATA_DIRS /var/lib/flatpak/exports/share $HOME/.local/share/flatpak/exports/share $XDG_DATA_DIRS
  set -gx QT_QPA_PLATFORMTHEME qt6ct
  set -gx QT_STYLE_OVERRIDE breeze

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
if not string match -q -- "$PNPM_HOME/bin" $PATH
  set -gx PATH "$PNPM_HOME/bin" $PATH
end
# pnpm end

# bun
set -gx BUN_INSTALL "$HOME/.bun"
if test -d $BUN_INSTALL/bin
  fish_add_path --path $BUN_INSTALL/bin
end

# homebrew - fish compatible
if test -x /home/linuxbrew/.linuxbrew/bin/brew
  eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)
end

# npm-global bin - only if exists (lib/node_modules is not a bin path)
if test -d /home/ritch/.local/share/npm-global/bin
  fish_add_path --path /home/ritch/.local/share/npm-global/bin
end

# kimi-code
if test -d /home/ritch/.kimi-code/bin
  fish_add_path --path /home/ritch/.kimi-code/bin
end
