#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : User-level WSJT-X installer (auto-detect latest amd64 .deb from SourceForge)
set -euo pipefail
. "$(dirname "$0")/env.sh"

APP_NAME="wsjtx"
SF_BASE="${WSJTX_SF_BASE:-https://sourceforge.net/projects/wsjt/files}"
UA="${WSJTX_UA:-Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Safari/537.36}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

req curl
req ar
req tar

resolve_latest_url() {
  # If user pinned a URL, just use it.
  if [ -n "${WSJTX_URL:-}" ]; then
    echo "$WSJTX_URL"
    return 0
  fi

  echo "Discovering latest WSJT-X version from SourceForge..."
  # 1) Get versions (wsjtx-x.y[.z]) and pick the newest with sort -V
  local versions
  versions="$(curl -fsSL -A "$UA" "$SF_BASE/" \
    | grep -Eo 'wsjtx-[0-9]+(\.[0-9]+){1,2}' \
    | sort -uV)"
  local latest_ver
  latest_ver="$(printf '%s\n' "$versions" | tail -n1 || true)"
  if [ -z "$latest_ver" ]; then
    echo "Could not detect latest version from $SF_BASE" >&2
    return 1
  fi
  echo "Latest version: $latest_ver"

  # 2) Open that version folder and find the amd64 .deb
  local ver_page="$SF_BASE/${latest_ver}/"
  local deb_path
  deb_path="$(curl -fsSL -A "$UA" "$ver_page" \
    | grep -Eo '/projects/wsjt/files/'"${latest_ver}"'/[^"]*wsjtx_[0-9][0-9._-]*_amd64\.deb' \
    | head -n1 || true)"

  if [ -z "$deb_path" ]; then
    echo "Could not find amd64 .deb under $ver_page" >&2
    return 1
  fi

  # 3) Build final download URL (SourceForge expects /download suffix)
  echo "https://sourceforge.net${deb_path}/download"
}

main() {
  echo "Resolving latest WSJT-X .deb URL..."
  local url
  if ! url="$(resolve_latest_url)"; then
    echo "Falling back: set WSJTX_URL to a valid .deb if auto-detect fails." >&2
    exit 1
  fi
  echo "Download URL: $url"

  echo "Downloading WSJT-X .deb package..."
  curl -fL -A "$UA" "$url" -o "$TMPDIR/wsjtx.deb"

  echo "Extracting .deb..."
  ( cd "$TMPDIR" && ar x wsjtx.deb )

  # Extract data tarball (handles data.tar.xz or data.tar.zst or data.tar.gz)
  local data_tar
  data_tar="$(ls "$TMPDIR"/data.tar.* 2>/dev/null | head -n1 || true)"
  if [ -z "$data_tar" ]; then
    echo "Could not locate data.tar.* inside the .deb" >&2
    exit 1
  fi
  case "$data_tar" in
    *.tar.xz) tar -xJf "$data_tar" -C "$TMPDIR" ;;
    *.tar.gz) tar -xzf "$data_tar" -C "$TMPDIR" ;;
    *.tar.zst)
      req unzstd
      unzstd -c "$data_tar" | tar -xf - -C "$TMPDIR"
      ;;
    *) tar -xf "$data_tar" -C "$TMPDIR" ;;
  esac

  # Install binary to ~/.local/bin
  if [ -x "$TMPDIR/usr/bin/wsjtx" ]; then
    install -Dm755 "$TMPDIR/usr/bin/wsjtx" "$BIN_DIR/wsjtx"
  else
    echo "wsjtx binary not found in package." >&2
    exit 1
  fi

  # Optional icon
  if [ -f "$TMPDIR/usr/share/icons/hicolor/256x256/apps/wsjtx.png" ]; then
    install -Dm644 "$TMPDIR/usr/share/icons/hicolor/256x256/apps/wsjtx.png" "$ICON_DIR/wsjtx.png"
  fi

  # Desktop entry
  cat > "$DESKTOP_DIR/${APP_NAME}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=WSJT-X
Exec=$BIN_DIR/wsjtx
Icon=$ICON_DIR/wsjtx.png
Categories=Network;HamRadio;
Terminal=false
EOF

  have update-desktop-database && update-desktop-database >/dev/null 2>&1 || true
  echo "✓ WSJT-X installed to $BIN_DIR/wsjtx"
}

main "$@"
