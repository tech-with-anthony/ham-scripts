#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : Install JS8Call
set -euo pipefail
. "$(dirname "$0")/env.sh"

APP="js8call"
PRETTY="JS8Call"
VERSION="${JS8CALL_VERSION:-2.2.0}"
FILE="js8call_${VERSION}_20.04-Linux-Desktop.x86_64.AppImage"
URL="${JS8CALL_URL:-http://files.js8call.com/${VERSION}/${FILE}}"

req curl

# ---------- pin helper ----------
pin_app_taskbar() {
  local app="$1" pretty="$2" icon_base="${3:-$1}"
  local desktop="$DESKTOP_DIR/${app}.desktop"
  local icon_src="$REPO_ROOT/app-icons/${icon_base}.png"
  local icon_dst="$ICON_DIR/${app}.png"
  local exe
  exe="$(command -v "$app" 2>/dev/null || true)"
  [ -z "$exe" ] && [ -x "$BIN_DIR/$app" ] && exe="$BIN_DIR/$app"
  [ -z "$exe" ] && exe="$app"

  [ -f "$icon_src" ] && install -Dm644 "$icon_src" "$icon_dst"

  if [ -f "$desktop" ]; then
    sed -i "s|^Exec=.*$|Exec=${exe}|g" "$desktop"
    if grep -q "^Icon=" "$desktop"; then
      sed -i "s|^Icon=.*$|Icon=${icon_dst}|g" "$desktop"
    else
      printf '\nIcon=%s\n' "$icon_dst" >> "$desktop"
    fi
  else
    cat >"$desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${pretty}
Exec=${exe}
Icon=${icon_dst}
Categories=Network;HamRadio;
Terminal=false
EOF
  fi

  local desk="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
  local dlc; dlc="$(printf '%s' "$desk" | tr '[:upper:]' '[:lower:]')"
  local schema key appid="${app}.desktop"
  if echo "$dlc" | grep -q gnome; then schema="org.gnome.shell"; key="favorite-apps"
  elif echo "$dlc" | grep -q cinnamon; then schema="org.cinnamon"; key="favorite-apps"
  else
    echo "info: unsupported desktop '$desk'; created $desktop"
    return 0
  fi
  if command -v gsettings >/dev/null 2>&1 && gsettings list-schemas | grep -q "^$schema$"; then
    local cur new
    cur="$(gsettings get "$schema" "$key")"
    new="$(printf '%s' "$cur" | sed -E 's/^\[|\]$//g')"
    echo "$new" | grep -q "'$appid'" || \
      gsettings set "$schema" "$key" "[$([ -n "$new" ] && echo "$new, ")'${appid}']"
  fi

  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  command -v gtk-update-icon-cache  >/dev/null 2>&1 && gtk-update-icon-cache -f "$(dirname "$(dirname "$ICON_DIR")")" >/dev/null 2>&1 || true
}

# ---------- install ----------
OUT="$BIN_DIR/$APP"
if [ ! -f "$OUT" ]; then
  echo "Downloading ${PRETTY} ${VERSION}…"
  curl -fL "$URL" -o "$OUT"
  chmod +x "$OUT"
fi

# optional icon extraction (best-effort)
if "$OUT" --appimage-extract >/dev/null 2>&1; then
  ICON_SRC="squashfs-root/usr/share/icons/hicolor/256x256/apps/${APP}.png"
  [ -f "$ICON_SRC" ] && install -Dm644 "$ICON_SRC" "$ICON_DIR/${APP}.png"
  rm -rf squashfs-root
fi

# desktop entry (ensured by pin)
pin_app_taskbar "$APP" "$PRETTY" "$APP"

echo "✓ ${PRETTY} installed at $OUT"
