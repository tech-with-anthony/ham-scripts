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
SF_BASE="${WSJTX_SF_BASE:-https://sourceforge.net/projects/wsjt/files}"
UA="${WSJTX_UA:-Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Safari/537.36}"

req curl ar tar

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

resolve_latest_url() {
  # user can pin WSJTX_URL explicitly
  [ -n "${WSJTX_URL:-}" ] && { echo "$WSJTX_URL"; return 0; }

  echo "Discovering latest WSJT-X version from SourceForge…"
  local versions latest_ver ver_page deb_path
  versions="$(curl -fsSL -A "$UA" "$SF_BASE/" | grep -Eo 'wsjtx-[0-9]+(\.[0-9]+){1,2}' | sort -uV)"
  latest_ver="$(printf '%s\n' "$versions" | tail -n1 || true)"
  [ -n "$latest_ver" ] || { echo "Could not detect latest version"; return 1; }

  ver_page="$SF_BASE/${latest_ver}/"
  deb_path="$(curl -fsSL -A "$UA" "$ver_page" \
    | grep -Eo '/projects/wsjt/files/'"${latest_ver}"'/[^"]*wsjtx_[0-9][0-9._-]*_amd64\.deb' \
    | head -n1 || true)"
  [ -n "$deb_path" ] || { echo "No amd64 .deb under $ver_page"; return 1; }

  echo "https://sourceforge.net${deb_path}/download"
}

# ---------- install ----------
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

URL="$(resolve_latest_url)"
echo "Download URL: $URL"
curl -fL -A "$UA" "$URL" -o "$TMPDIR/wsjtx.deb"

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

# icon (if present in .deb; our pin helper will also install repo icon)
if [ -f "$TMPDIR/usr/share/icons/hicolor/256x256/apps/wsjtx.png" ]; then
  install -Dm644 "$TMPDIR/usr/share/icons/hicolor/256x256/apps/wsjtx.png" "$ICON_DIR/wsjtx.png"
fi

# desktop entry + pin
pin_app_taskbar "$APP" "$PRETTY" "$APP"

echo "✓ ${PRETTY} installed at $BIN_DIR/wsjtx"
