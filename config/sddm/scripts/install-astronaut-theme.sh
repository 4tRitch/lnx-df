#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ASTRONAUT_CONF_DIR="${REPO_ROOT}/config/sddm/astronaut"
THEME_NAME="sddm-astronaut-theme"
THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"
TEMP_DIR="$(mktemp -d)"
CONF_DIR="/etc/sddm.conf.d"
THEME_CONF_FILE="${CONF_DIR}/10-theme.conf"
VKBD_CONF_FILE="${CONF_DIR}/virtualkbd.conf"
THEME_REPO="https://github.com/Keyitdev/sddm-astronaut-theme.git"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

if ! command -v pacman >/dev/null 2>&1; then
  echo "This installer currently expects Arch/pacman." >&2
  exit 1
fi

pacman -S --needed --noconfirm git sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg qt6-5compat

git clone --depth 1 "$THEME_REPO" "$TEMP_DIR/${THEME_NAME}"
rm -rf "$THEME_DIR"
install -d -m 0755 "$THEME_DIR"
cp -a "$TEMP_DIR/${THEME_NAME}/." "$THEME_DIR/"

install -d -m 0755 /usr/share/fonts
if [[ -d "$THEME_DIR/Fonts" ]]; then
  cp -a "$THEME_DIR/Fonts/." /usr/share/fonts/
fi
fc-cache -f >/dev/null 2>&1 || true

install -d -m 0755 "$THEME_DIR/Themes"
install -d -m 0755 "$THEME_DIR/Backgrounds"
install -m 0644 "$ASTRONAUT_CONF_DIR/lnx_df_elegant.conf" "$THEME_DIR/Themes/lnx_df_elegant.conf"
install -m 0644 "$ASTRONAUT_CONF_DIR/lnx_df_elegant_video.conf" "$THEME_DIR/Themes/lnx_df_elegant_video.conf"

if [[ -f "$ASTRONAUT_CONF_DIR/current-wallpaper.jpg" ]]; then
  install -m 0644 "$ASTRONAUT_CONF_DIR/current-wallpaper.jpg" "$THEME_DIR/Backgrounds/current-wallpaper.jpg"
fi

if [[ -f "$ASTRONAUT_CONF_DIR/current-background.mp4" ]]; then
  install -m 0644 "$ASTRONAUT_CONF_DIR/current-background.mp4" "$THEME_DIR/Backgrounds/current-background.mp4"
fi

sed -i 's#^ConfigFile=.*#ConfigFile=Themes/lnx_df_elegant.conf#' "$THEME_DIR/metadata.desktop"

install -d -m 0755 "$CONF_DIR"
cat > "$THEME_CONF_FILE" <<CONF
[Theme]
Current=${THEME_NAME}
CONF

cat > "$VKBD_CONF_FILE" <<CONF
[General]
InputMethod=qtvirtualkeyboard
CONF

echo "Installed ${THEME_NAME} with lnx_df_elegant profile."
echo "Preview with: sddm-greeter-qt6 --test-mode --theme ${THEME_DIR}"
