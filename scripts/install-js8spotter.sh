#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : Install JS8Spotter
set -euo pipefail
. "$(dirname "$0")/env.sh"

APP="js8spotter"
PRETTY="JS8Spotter"

# Accepts "1.17" and converts to 117 for ZIP name
VERSION="${JS8SPOTTER_VERSION:-1.17}"
VER_NODOT="${VERSION//./}"
BASE_URL="${JS8SPOTTER_BASE_URL:-https://kf7mix.com/files/js8spotter}"
FILE="${JS8SPOTTER_FILE:-js8spotter-${VER_NODOT}.zip}"
URL="${JS8SPOTTER_URL:-$BASE_URL/$FILE}"

req curl unzip

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
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading ${PRETTY} ${VERSION}…"
curl -fL "$URL" -o "$TMPDIR/$FILE"
unzip -q "$TMPDIR/$FILE" -d "$TMPDIR/extracted"

CAND="$(find "$TMPDIR/extracted" -type f \( -name '*.AppImage' -o -name "$APP" -o -name "$APP.sh" -o -iname 'JS8Spotter*' \) | head -n1 || true)"
[ -n "$CAND" ] || { echo "No executable found in archive"; exit 1; }

install -Dm755 "$CAND" "$BIN_DIR/$APP"

# desktop entry + pin
pin_app_taskbar "$APP" "$PRETTY" "$APP"

echo "✓ ${PRETTY} installed at $BIN_DIR/$APP"