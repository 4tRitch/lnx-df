# lnx-df Installer

The installer is a small modular Bash entrypoint for setting up this repo's dotfiles and a practical developer toolchain.

## Architecture

- `install.sh`: CLI entrypoint. Parses flags, exposes the same workflows in the interactive TUI, runs installs, then runs checks and a final summary.
- `uninstall.sh`: CLI entrypoint for selective uninstall of repo-managed and user-space tools.
- `lib/common.sh`: shared platform detection, package-manager helpers, dry-run support, symlink helpers, npm helpers, and small utility functions.
- `lib/components.sh`: component registry, preset definitions, package mappings, install logic, check logic, and uninstall behavior.
- `lib/ui.sh`: shared interactive selectors with a compact palette-style flow across `gum`, `whiptail`, `dialog`, and plain stdin fallback.

## Components

Current component ids:

- `dotfiles`
- `zsh`
- `kitty`
- `nerd-fonts`
- `tmux`
- `nvim`
- `gcc`
- `cmake`
- `python`
- `nodejs`
- `pnpm`
- `rust`
- `go`
- `dotnet`
- `tauri`
- `godot`
- `opencode`
- `gentle-ai`
- `codex`
- `claude-code`
- `qwen-cli`

`nerd-fonts` installs the CaskaydiaCove Nerd Font used by the Kitty config and useful for Neovim icon glyphs.

## Presets

- `basic`: shell, dotfiles, terminal, editor, Nerd Font, Python, Node.js, pnpm
- `dev`: general development stack, CLIs, Tauri deps, Nerd Font
- `gamedev`: dev stack plus Godot, Nerd Font
- `full`: every supported component
- `custom`: interactive component selection

List them from the CLI:

```bash
./install.sh --list-components
./install.sh --list-presets
```

## Distro Support

Supported package-manager families:

- Debian-like: `apt`
- Arch-like: `pacman`
- Fedora-like: `dnf`

Arch notes:

- The installer uses `pacman` first.
- If a requested package is missing from configured `pacman` repos and `paru` is already installed, it will use `paru` for that package.
- The installer does not bootstrap `paru` automatically.
- AUR installs are skipped when running the installer as root.

Some components also use language-native installers or upstream install scripts when that is the simplest supported path, for example `rustup`, `go install`, npm global packages, or the local `.NET` installer.

## Usage

Run from the repo root:

```bash
./install.sh
```

With no flags, the installer opens a more app-like interactive flow. `gum` is the premium path and gets the polished panel-style UI with arrow-key navigation, `Enter` to confirm, and `Esc` to back out. Otherwise the installer falls back to a clean plain-text UI by default; single-select menus still support arrow-key navigation in a TTY, while typed ids/numbers remain available as a fallback. `whiptail` and `dialog` are still supported, but only when explicitly forced through `LNX_DF_UI_MODE`, because their terminal color themes can vary wildly across systems.

If you do not have `gum`, install it to get the best-looking installer experience.

If you want to test or force a specific renderer while keeping the same shell implementation, set `LNX_DF_UI_MODE` to `gum`, `plain`, `whiptail`, or `dialog`.

Non-interactive examples:

```bash
./install.sh --preset basic --non-interactive
./install.sh --component dotfiles --component nvim --component nerd-fonts --non-interactive
./install.sh --all --non-interactive
LNX_DF_UI_MODE=plain ./install.sh
```

## Dry Run

Use `--dry-run` to print commands without applying package installs, symlinks, or tool installs.

```bash
./install.sh --preset dev --non-interactive --dry-run
```

This is intended for previewing actions and package resolution before making changes.

## Checks Only

Use `--checks-only` to validate selected components without installing anything:

```bash
./install.sh --preset basic --non-interactive --checks-only
./install.sh --component nodejs --component go --checks-only --non-interactive
```

Checks verify command presence and, for a few key tools, pragmatic minimum versions:

- `node`: `>= 18.0.0`
- `go`: `>= 1.22.0`
- `cargo`: `>= 1.75.0`
- `nvim`: `>= 0.9.0`

If a version cannot be parsed reliably, the check falls back to presence-only instead of failing on formatting differences.

Checks also surface when a tool only became visible because the installer activated user-space PATH entries like `~/.local/bin`, `~/.cargo/bin`, or `~/.dotnet` for the current process. The final summary calls out when you only need to reload your shell versus when you still need to add a PATH entry to your shell startup files.

## Nerd Fonts Behavior

`nerd-fonts` tries the simplest safe route in this order:

1. Reuse an already installed CaskaydiaCove Nerd Font.
2. On Arch, install `ttf-cascadia-code-nerd` through `pacman` or `paru` when available.
3. Otherwise, download the official `CascadiaCode.zip` Nerd Fonts release into `~/.local/share/fonts/NerdFonts/CaskaydiaCove` and refresh the font cache when `fc-cache` is available.

## Uninstall Philosophy

Uninstall is intentionally conservative.

- Repo-managed symlinks can be removed.
- User-space tools installed by npm, cargo, or `go install` may be removed when the installer can do so safely.
- System packages are not aggressively removed, because they may be shared with other work.
- Font and package-manager installs are treated as non-destructive by default.

Use:

```bash
./uninstall.sh --list-components
./uninstall.sh --component dotfiles
./uninstall.sh --all --non-interactive --dry-run
LNX_DF_UI_MODE=plain ./uninstall.sh
```
