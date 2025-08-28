#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : Install JS8Call
set -euo pipefail

### ====== USER-TUNABLE SETTINGS (update these for new versions) ==========================
APP_NAME="JS8Call"
APP_ID="js8call"

# Version + .deb URL
VERSION="2.2.0"
DEB_URL="http://files.js8call.com/${VERSION}/js8call_${VERSION}_20.04_amd64.deb"

# Custom icon (PNG) from your repo
ICON_URL="https://raw.githubusercontent.com/thetechnicalham/ham-scripts/main/app-icons/js8call.png"

### ====== LOCATIONS =====================================================================
WORKDIR="${TMPDIR:-/tmp}/install-${APP_ID}"
DEB_PATH="${WORKDIR}/${APP_ID}_${VERSION}_amd64.deb"

DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/${APP_ID}.desktop"

ICON_DIR="${HOME}/.local/share/icons"
ICON_PATH="${ICON_DIR}/${APP_ID}.png"

APP_EXEC="/usr/bin/js8call"

### ====== UTILITIES =====================================================================
have() { command -v "$1" >/dev/null 2>&1; }

install_pkgs() {
  sudo apt-get update -y
  sudo apt-get install -y curl wget ca-certificates libglib2.0-bin
}

download_file() {
  local url="$1" out="$2"
  mkdir -p "$(dirname "$out")"
  echo "Downloading: $url"
  if have wget; then
    wget -O "$out" --content-disposition --no-verbose "$url"
  else
    curl -L -o "$out" "$url"
  fi
}

install_deb() {
  local deb="$1"
  echo "Installing package: $deb"
  sudo apt-get install -y "$deb" || {
    sudo dpkg -i "$deb" || true
    sudo apt-get -f install -y
  }
}

create_icon() {
  mkdir -p "$ICON_DIR"
  download_file "$ICON_URL" "$ICON_PATH"
}

create_desktop_file() {
  mkdir -p "$DESKTOP_DIR"
  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=${APP_NAME}
GenericName=${APP_NAME}
Comment=Weak-signal digital communication (JS8Call)
Exec=${APP_EXEC}
Icon=${ICON_PATH}
Terminal=false
Type=Application
Categories=HamRadio;Network;Utility;
StartupNotify=true
EOF
  update-desktop-database >/dev/null 2>&1 || true
}

pin_to_taskbar() {
  if ! have gsettings; then return 0; fi
  local key="org.gnome.shell favorite-apps"
  local current
  current="$(gsettings get ${key})" || current="[]"
  local new_list
  new_list="$(python3 - "$current" "$(basename "$DESKTOP_FILE")" <<'PY'
import ast, sys
arr_str = sys.argv[1]; target = sys.argv[2]
try: arr = ast.literal_eval(arr_str)
except Exception: arr = []
if not isinstance(arr, list): arr = []
if target not in arr: arr.append(target)
print(str(arr).replace("'", '"'))
PY
)"
  gsettings set ${key} "${new_list}"
}

### ====== MAIN ==========================================================================

install_pkgs
mkdir -p "$WORKDIR"
download_file "$DEB_URL" "$DEB_PATH"
install_deb "$DEB_PATH"

create_icon
create_desktop_file
pin_to_taskbar

echo "✅ ${APP_NAME} ${VERSION} installed."
echo "   Launcher: ${DESKTOP_FILE}"
echo "   Icon:     ${ICON_PATH}"

# --- Ham-Scripts User Config Integration ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$REPO_ROOT/tools/config_integration.sh"
post_install_apply_ham_config