#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : User-level WSJT-X installer (auto-detect latest amd64 .deb from SourceForge)
set -euo pipefail
. "$(dirname "$0")/env.sh"

APP="wsjtx"
PRETTY="WSJT-X"

# Fixed .deb URL (2.7.0 amd64)
URL="${WSJTX_URL:-https://sourceforge.net/projects/wsjt/files/wsjtx-2.7.0/wsjtx_2.7.0_amd64.deb/download}"

req curl ar tar

# ---------- helper: ensure icon + desktop + pin ----------
pin_app_taskbar() {
  local app="$1" pretty="$2" icon_base="${3:-$1}"
  local desktop="$DESKTOP_DIR/${app}.desktop"
  local icon_src icon_dst="$ICON_DIR/${app}.png"

  icon_src="$(find_repo_icon "$icon_base" || true)"
  if [ -n "${icon_src:-}" ]; then
    install -Dm644 "$icon_src" "$icon_dst"
  else
    echo "warn: no repo icon found for ${icon_base}"
  fi

  local exe
  exe="$(command -v "$app" 2>/dev/null || true)"
  [ -z "$exe" ] && [ -x "$BIN_DIR/$app" ] && exe="$BIN_DIR/$app"
  [ -z "$exe" ] && exe="$app"

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
  local dlc schema key appid="${app}.desktop"
  dlc="$(printf '%s' "$desk" | tr '[:upper:]' '[:lower:]')"
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

echo "Downloading ${PRETTY} package…"
curl -fL "$URL" -o "$TMPDIR/wsjtx.deb"

( cd "$TMPDIR" && ar x wsjtx.deb )

data_tar="$(ls "$TMPDIR"/data.tar.* 2>/dev/null | head -n1 || true)"
[ -n "$data_tar" ] || { echo "data.tar.* not found in package"; exit 1; }

case "$data_tar" in
  *.tar.xz) tar -xJf "$data_tar" -C "$TMPDIR" ;;
  *.tar.gz) tar -xzf "$data_tar" -C "$TMPDIR" ;;
  *.tar.zst)
    req unzstd
    unzstd -c "$data_tar" | tar -xf - -C "$TMPDIR"
    ;;
  *) tar -xf "$data_tar" -C "$TMPDIR" ;;
esac

[ -x "$TMPDIR/usr/bin/wsjtx" ] || { echo "wsjtx binary missing in package"; exit 1; }
install -Dm755 "$TMPDIR/usr/bin/wsjtx" "$BIN_DIR/wsjtx"

# if .deb shipped an icon, keep it
if [ -f "$TMPDIR/usr/share/icons/hicolor/256x256/apps/wsjtx.png" ]; then
  install -Dm644 "$TMPDIR/usr/share/icons/hicolor/256x256/apps/wsjtx.png" "$ICON_DIR/wsjtx.png"
fi

pin_app_taskbar "$APP" "$PRETTY" "$APP"
echo "✓ ${PRETTY} installed at $BIN_DIR/wsjtx"