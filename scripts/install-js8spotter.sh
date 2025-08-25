#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : Install JS8Spotter
set -euo pipefail
. "$(dirname "$0")/env.sh"

APP_NAME="js8spotter"

# Change this later as needed (accepts "1.17" style and converts to 117)
VERSION="${JS8SPOTTER_VERSION:-1.17}"
VER_NODOT="${VERSION//./}"
BASE_URL="${JS8SPOTTER_BASE_URL:-https://kf7mix.com/files/js8spotter}"
FILE="${JS8SPOTTER_FILE:-js8spotter-${VER_NODOT}.zip}"
URL="${JS8SPOTTER_URL:-$BASE_URL/$FILE}"

req curl
req unzip

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading JS8Spotter $VERSION..."
curl -fL "$URL" -o "$TMPDIR/$FILE"

echo "Extracting..."
unzip -q "$TMPDIR/$FILE" -d "$TMPDIR/extracted"

# Prefer an AppImage; otherwise take a plausible executable
BIN_CANDIDATE="$(find "$TMPDIR/extracted" -type f \( -name '*.AppImage' -o -name "$APP_NAME" -o -name "$APP_NAME.sh" -o -name 'JS8Spotter*' \) | head -n1 || true)"
if [ -z "${BIN_CANDIDATE:-}" ]; then
  echo "Could not find an AppImage or executable inside the ZIP. Contents were:" >&2
  find "$TMPDIR/extracted" -maxdepth 2 -type f -printf '  %P\n' >&2
  exit 1
fi

install -Dm755 "$BIN_CANDIDATE" "$BIN_DIR/$APP_NAME"

# Try to find an icon inside the archive (best-effort)
ICON_SRC="$(find "$TMPDIR/extracted" -type f -iname '*js8spotter*.png' -o -iname 'icon*.png' | head -n1 || true)"
if [ -n "${ICON_SRC:-}" ]; then
  install -Dm644 "$ICON_SRC" "$ICON_DIR/${APP_NAME}.png"
fi

# Desktop entry (user-level)
cat > "$DESKTOP_DIR/${APP_NAME}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=JS8Spotter
Exec=$BIN_DIR/$APP_NAME
Icon=${ICON_DIR}/${APP_NAME}.png
Categories=Network;HamRadio;
Terminal=false
EOF

have update-desktop-database && update-desktop-database >/dev/null 2>&1 || true

echo "✓ JS8Spotter $VERSION installed to $BIN_DIR/$APP_NAME"
