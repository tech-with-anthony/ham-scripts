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
VER="2.7.0"
TGZ_URL="${WSJTX_TGZ_URL:-https://downloads.sourceforge.net/project/wsjt/wsjtx-${VER}/wsjtx-${VER}.tgz}"

req curl tar

PREFIX_OPT="$PREFIX/opt"
APPDIR="$PREFIX_OPT/wsjtx-$VER"          # ~/.local/opt/wsjtx-2.7.0
BINDST="$BIN_DIR/$APP"                   # ~/.local/bin/wsjtx

# --- helper from env.sh expected: find_repo_icon ---
pin_app_taskbar() {
  local app="$1" pretty="$2" icon_base="${3:-$1}"
  local desktop="$DESKTOP_DIR/${app}.desktop"
  local icon_src icon_dst="$ICON_DIR/${app}.png"

  icon_src="$(find_repo_icon "$icon_base" || true)"
  [ -n "${icon_src:-}" ] && install -Dm644 "$icon_src" "$icon_dst" || echo "warn: no repo icon for $icon_base"

  # Exec points to our wrapper/symlink in ~/.local/bin
  local exe="$BINDST"

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

  # Pin to GNOME/Cinnamon favorites
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
    echo "$new" | grep -q "'$appid'" || gsettings set "$schema" "$key" "[$([ -n "$new" ] && echo "$new, ")'${appid}']"
  fi

  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  command -v gtk-update-icon-cache  >/dev/null 2>&1 && gtk-update-icon-cache -f "$(dirname "$(dirname "$ICON_DIR")")" >/dev/null 2>&1 || true
}

# --- install from tarball ---
TMPDIR="$(mktemp -d)"; trap 'rm -rf "$TMPDIR"' EXIT
echo "Downloading ${PRETTY} ${VER} tarball…"
curl -fL "$TGZ_URL" -o "$TMPDIR/wsjtx.tgz"

mkdir -p "$PREFIX_OPT"
tar -xzf "$TMPDIR/wsjtx.tgz" -C "$PREFIX_OPT"
# tarball usually extracts to wsjtx-${VER}/* with bin/ and share/
# Ensure predictable path name (some tarballs include architecture suffixes)
if [ ! -d "$APPDIR" ]; then
  # try to detect actual dir
  realdir="$(find "$PREFIX_OPT" -maxdepth 1 -type d -name "wsjtx-${VER}*" | head -n1 || true)"
  [ -n "$realdir" ] && mv -f "$realdir" "$APPDIR"
fi

# sanity: must have a binary
[ -x "$APPDIR/bin/wsjtx" ] || { echo "wsjtx binary not found inside tarball"; exit 1; }

# link into ~/.local/bin
mkdir -p "$BIN_DIR"
ln -sf "$APPDIR/bin/wsjtx" "$BINDST"

# (Optional) Ensure data dir is in expected place alongside (the tarball ships share/wsjtx)
[ -d "$APPDIR/share/wsjtx" ] || echo "warn: wsjtx share dir not found; resources may be missing"

# (Optional) suggest runtime deps if missing
missing=$(ldd "$APPDIR/bin/wsjtx" | awk '/not found/{print $1}')
if [ -n "$missing" ]; then
  echo "⚠ Missing runtime libs:"
  echo "$missing"
  echo "On Debian/Ubuntu you may need: sudo apt-get install -y libqt5widgets5 libqt5network5 libqt5multimedia5 libfftw3-3 libgfortran5 libhamlib4"
fi

pin_app_taskbar "$APP" "$PRETTY" "$APP"
echo "✓ ${PRETTY} ${VER} installed at $APPDIR and linked to $BINDST"