if status is-interactive
  # env STEAM_FORCE_DESKTOPUI_SCALING=1 steam
  set -gx MOZ_ENABLE_WAYLAND 1
  set -gx XDG_DATA_DIRS /var/lib/flatpak/exports/share $HOME/.local/share/flatpak/exports/share $XDG_DATA_DIRS
  set -gx QT_QPA_PLATFORMTHEME qt6ct
  set -gx QT_STYLE_OVERRIDE breeze

  if command -q zoxide
    zoxide init fish | source
  end

  if command -q mise
    mise activate fish | source
  end

  if not set -q SSH_AUTH_SOCK
    eval (ssh-agent -c) >/dev/null
  end

  # Always use Kitty's ssh kitten when inside Kitty — it forwards
  # terminfo (xterm-kitty) + clipboard (OSC 52) + Kitty graphics
  # so image paste into opencode works over SSH. Plain `ssh` drops
  # WAYLAND_DISPLAY and blocks image/png mime.
  #
  # Exception: `enlace` is a Windows 11 host whose login shell is
  # PowerShell, and the kitten's internal `exec` handshake is not
  # valid there (`exec: The term 'exec' is not recognized as a
  # name of a cmdlet...`). For that host only we fall back to plain
  # `command ssh`, which authenticates over key and lands in
  # PowerShell cleanly. Every other host keeps the kitten path.
  if test "$TERM" = "xterm-kitty"
    if command -q kitty
      function ssh --description "kitty +kitten ssh, except for enlace (Windows PowerShell)"
        set -l is_enlace false
        for arg in $argv
          if string match -q -r 'enlace' -- $arg
            set is_enlace true
            break
          end
        end

        if test "$is_enlace" = "true"
          command ssh $argv
        else
          kitty +kitten ssh $argv
        end
      end
    end
  end
end

if test -d $HOME/.opencode/bin
  fish_add_path --path $HOME/.opencode/bin
end

fish_add_path --path $HOME/.local/bin

# mise shims - ensure pnpm/node etc available in non-interactive shells (fish -c)
if test -d $HOME/.local/share/mise/shims
  fish_add_path --path $HOME/.local/share/mise/shims
end

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

# deduplicate and clean inherited PATH pollution (from previous buggy `set -x PATH $PATH /path`)
set -l _clean_path
for _p in $PATH
  # stale npm-global lib path (wrong, should be bin)
  if test "$_p" = "/home/ritch/.local/share/npm-global/lib/node_modules"
    continue
  end
  # bun bin should only be present if directory exists
  if test "$_p" = "/home/ritch/.bun/bin"
    if not test -d "$_p"
      continue
    end
  end
  # old PNPM_HOME without /bin is stale now that pnpm 11.22 expects bin
  if test "$_p" = "/home/ritch/.local/share/pnpm"
    # keep only if bin is not present elsewhere? simpler: skip plain, bin will be added via pnpm section
    continue
  end
  if not contains -- "$_p" $_clean_path
    set -a _clean_path "$_p"
  end
end
set -g PATH $_clean_path
set -e _clean_path
set -e _p
