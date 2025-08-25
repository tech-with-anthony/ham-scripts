#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : User-level WSJT-X installer (auto-detect latest amd64 .deb from SourceForge)
set -euo pipefail

### ====== USER-TUNABLE SETTINGS (update these for new versions) ==========================
APP_NAME="WSJT-X"
APP_ID="wsjtx"                               # used for filenames: wsjtx.desktop, icon name, etc.

# VERSION + .deb download URL (change these for new releases)
VERSION="2.7.0"
DEB_URL="https://sourceforge.net/projects/wsjt/files/wsjtx-${VERSION}/wsjtx_${VERSION}_amd64.deb"

# Custom icon (PNG) — update URL or branch/path if you move it
ICON_URL="https://raw.githubusercontent.com/thetechnicalham/ham-scripts/main/app-icons/wsjtx.png"

### ====== LOCATIONS (rarely change) =====================================================
WORKDIR="${TMPDIR:-/tmp}/install-${APP_ID}"
DEB_PATH="${WORKDIR}/${APP_ID}_${VERSION}_amd64.deb"

# Put the desktop file & icon in the user's local directories so they're easy to override
DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/${APP_ID}.desktop"

ICON_DIR="${HOME}/.local/share/icons"
ICON_PATH="${ICON_DIR}/${APP_ID}.png"

# Expected executable after installation (from the .deb)
APP_EXEC="/usr/bin/wsjtx"

### ====== Install dependencies ==========================================================
sudo apt install \
  libqt5serialport5 \
  libqt5multimedia5-plugins \
  libqt5widgets5 \
  libqt5multimediawidgets5 \
  libqt5core5a \
  libqt5gui5 \
  libqt5multimedia5 \
  libqt5network5 \
  libqt5printsupport5 \
  libqt5serialport5 \
  libqt5widgets5 \
  libdouble-conversion3 \
  libpcre2-16-0 \
  qttranslations5-l10n \
  libmd4c0 \
  libqt5dbus5 \
  libxcb-xinerama0 \
  libxcb-xinput0 \
  libqt5svg5 \
  qt5-gtk-platformtheme \
  libqt5multimediagsttools5 \
  libgfortran5 \
  -y

### ====== UTIL FUNCTIONS ================================================================
have() { command -v "$1" >/dev/null 2>&1; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Re-running with sudo..."
    exec sudo -E bash "$0" "$@"
  fi
}

install_pkgs() {
  # Minimal tools to download/install and manipulate favorites
  sudo apt-get update -y
  sudo apt-get install -y curl wget ca-certificates libglib2.0-bin # libglib2.0-bin provides gsettings
}

download_file() {
  local url="$1" out="$2"
  mkdir -p "$(dirname "$out")"
  echo "Downloading: $url"
  # Use wget first (handles SourceForge redirects well); fallback to curl
  if have wget; then
    wget -O "$out" --content-disposition --no-verbose "$url"
  else
    curl -L -o "$out" "$url"
  fi
}

install_deb() {
  local deb="$1"
  echo "Installing package: $deb"
  # Use apt to resolve dependencies from a local .deb
  sudo apt-get install -y "$deb" || {
    # Fallback to dpkg + fix
    sudo dpkg -i "$deb" || true
    sudo apt-get -f install -y
  }
}

create_icon() {
  mkdir -p "$ICON_DIR"
  echo "Placing icon at: $ICON_PATH"
  download_file "$ICON_URL" "$ICON_PATH"
}

create_desktop_file() {
  mkdir -p "$DESKTOP_DIR"
  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=${APP_NAME}
GenericName=${APP_NAME}
Comment=Weak-signal digital communication
Exec=${APP_EXEC}
Icon=${ICON_PATH}
Terminal=false
Type=Application
Categories=AudioVideo;HamRadio;Network;Utility;
StartupNotify=true
EOF
  echo "Created launcher: $DESKTOP_FILE"
  # Ensure it shows up in app grid
  update-desktop-database >/dev/null 2>&1 || true
}

pin_to_taskbar() {
  if ! have gsettings; then
    echo "gsettings not found; cannot pin to GNOME taskbar automatically."
    return 0
  fi

  # Read current favorites as a GNOME array. We'll append our desktop if missing.
  local key="org.gnome.shell favorite-apps"
  local current
  current="$(gsettings get ${key})" || current="[]"

  # Use Python to treat the GNOME array as a Python list and merge safely.
  # This avoids fragile sed/awk quoting issues.
  local new_list
  new_list="$(python3 - "$current" "$(basename "$DESKTOP_FILE")" <<'PY'
import ast, sys
arr_str = sys.argv[1]
target = sys.argv[2]
try:
    arr = ast.literal_eval(arr_str)
    if not isinstance(arr, list):
        arr = []
except Exception:
    arr = []
if target not in arr:
    arr.append(target)
print(str(arr).replace("'", '"'))  # gsettings accepts either, but double quotes look nicer
PY
)"
  echo "Setting GNOME favorites to include: $(basename "$DESKTOP_FILE")"
  gsettings set ${key} "${new_list}"
}

### ====== MAIN ==========================================================================

# 1) Ensure required tools
install_pkgs

# 2) Download .deb + install
mkdir -p "$WORKDIR"
download_file "$DEB_URL" "$DEB_PATH"
install_deb "$DEB_PATH"

# 3) Drop icon + desktop launcher
create_icon
create_desktop_file

# 4) Pin to taskbar (GNOME favorites)
pin_to_taskbar

echo
echo "✅ ${APP_NAME} ${VERSION} installed."
echo "   Launcher: ${DESKTOP_FILE}"
echo "   Icon:     ${ICON_PATH}"
echo "   If you update variables at the top (VERSION/DEB_URL/ICON_URL), re-run this script for future releases."
