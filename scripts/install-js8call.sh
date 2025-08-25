#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : Install JS8Call
set -euo pipefail
. "$(dirname "$0")/env.sh"

APP_NAME="js8call"
VERSION="${JS8CALL_VERSION:-2.2.0}"
FILE="js8call_${VERSION}_20.04-Linux-Desktop.x86_64.AppImage"
URL="${JS8CALL_URL:-http://files.js8call.com/${VERSION}/${FILE}}"

req curl

OUT="$BIN_DIR/$APP_NAME"
if [ ! -f "$OUT" ]; then
  echo "Downloading $APP_NAME $VERSION..."
  curl -fL "$URL" -o "$OUT"
  chmod +x "$OUT"
fi

# Try to extract an icon if possible
if "$OUT" --appimage-extract >/dev/null 2>&1; then
  ICON_SRC="squashfs-root/usr/share/icons/hicolor/256x256/apps/js8call.png"
  [ -f "$ICON_SRC" ] && install -Dm644 "$ICON_SRC" "$ICON_DIR/${APP_NAME}.png"
  rm -rf squashfs-root
fi

# Desktop entry (user-level)
cat > "$DESKTOP_DIR/${APP_NAME}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=JS8Call
Exec=$OUT
Icon=${ICON_DIR}/${APP_NAME}.png
Categories=Network;HamRadio;
Terminal=false
EOF

have update-desktop-database && update-desktop-database >/dev/null 2>&1 || true
