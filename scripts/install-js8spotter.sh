#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : Install JS8Spotter
set -euo pipefail

### ====== USER-TUNABLE SETTINGS (update these for new versions) ==========================
APP_NAME="JS8Spotter"
APP_ID="js8spotter"

# Version + ZIP download URL (update these for new releases)
VERSION="1.14b"
ZIP_URL="https://kf7mix.com/files/js8spotter/js8spotter-${VERSION}.zip"

# Custom icon (PNG) from your repo — update path/branch if you move it
ICON_URL="https://raw.githubusercontent.com/thetechnicalham/ham-scripts/main/app-icons/js8spotter.png"

### ====== LOCATIONS (usually leave alone) ===============================================
WORKDIR="${TMPDIR:-/tmp}/install-${APP_ID}"
ZIP_PATH="${WORKDIR}/${APP_ID}-${VERSION}.zip"
EXTRACT_DIR="${WORKDIR}/extracted"

INSTALL_DIR="/opt/${APP_ID}-${VERSION}"      # versioned install dir
SYMLINK_BIN="/usr/local/bin/${APP_ID}"       # stable command for Exec= and PATH
DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/${APP_ID}.desktop"
ICON_DIR="${HOME}/.local/share/icons"
ICON_PATH="${ICON_DIR}/${APP_ID}.png"

### ====== UTILITIES =====================================================================
have() { command -v "$1" >/dev/null 2>&1; }

install_pkgs() {
  sudo apt-get update -y
  sudo apt-get install -y curl wget ca-certificates unzip libglib2.0-bin
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

create_icon() {
  mkdir -p "$ICON_DIR"
  echo "Placing icon at: $ICON_PATH"
  download_file "$ICON_URL" "$ICON_PATH"
}

detect_main_executable() {
  # Heuristics to find the thing to run inside $INSTALL_DIR
  # Order: AppImage > native executable/script > Python script
  local candidate

  # 1) AppImage
  candidate="$(find "$INSTALL_DIR" -type f -iname '*js8spotter*.AppImage' -print -quit || true)"
  if [ -n "${candidate:-}" ]; then
    echo "$candidate"
    return 0
  fi

  # 2) Executable files with a relevant name
  candidate="$(find "$INSTALL_DIR" -type f -iname '*js8spotter*' -perm -u+x -print -quit || true)"
  if [ -n "${candidate:-}" ]; then
    echo "$candidate"
    return 0
  fi

  # 3) Shell launchers
  candidate="$(find "$INSTALL_DIR" -type f \( -iname '*.sh' -o -iname '*run*' \) -perm -u+x -print | grep -i js8spotter | head -n1 || true)"
  if [ -n "${candidate:-}" ]; then
    echo "$candidate"
    return 0
  fi

  # 4) Python script fallback
  candidate="$(find "$INSTALL_DIR" -type f -iname '*js8spotter*.py' -print -quit || true)"
  if [ -n "${candidate:-}" ]; then
    echo "python3::${candidate}"
    return 0
  fi

  # 5) Last resort: any AppImage / any executable file
  candidate="$(find "$INSTALL_DIR" -type f -iname '*.AppImage' -print -quit || true)"
  if [ -n "${candidate:-}" ]; then
    echo "$candidate"
    return 0
  fi
  candidate="$(find "$INSTALL_DIR" -type f -perm -u+x -print -quit || true)"
  if [ -n "${candidate:-}" ]; then
    echo "$candidate"
    return 0
  fi

  echo ""
  return 1
}

create_wrapper() {
  local target="$1"
  sudo tee "$SYMLINK_BIN" >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail
APPDIR="${INSTALL_DIR}"
cd "\$APPDIR"

TARGET="$target"

if [[ "\$TARGET" == python3::* ]]; then
  exec python3 "\${TARGET#python3::}" "\$@"
else
  # Ensure executable bit (especially for AppImages or shipped binaries)
  chmod +x "\$TARGET" || true
  exec "\$TARGET" "\$@"
fi
EOF
  sudo chmod +x "$SYMLINK_BIN"
  echo "Created launcher wrapper: $SYMLINK_BIN"
}

create_desktop_file() {
  mkdir -p "$DESKTOP_DIR"
  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=${APP_NAME}
GenericName=${APP_NAME}
Comment=JS8Call companion spotting utility
Exec=${SYMLINK_BIN}
Icon=${ICON_PATH}
Terminal=false
Type=Application
Categories=HamRadio;Network;Utility;
StartupNotify=true
EOF
  echo "Created launcher: $DESKTOP_FILE"
  update-desktop-database >/dev/null 2>&1 || true
}

pin_to_taskbar() {
  if ! have gsettings; then
    echo "gsettings not found; cannot pin to GNOME taskbar automatically."
    return 0
  fi
  local key="org.gnome.shell favorite-apps"
  local current
  current="$(gsettings get ${key})" || current="[]"

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
print(str(arr).replace("'", '"'))
PY
)"
  echo "Setting GNOME favorites to include: $(basename "$DESKTOP_FILE")"
  gsettings set ${key} "${new_list}"
}

### ====== MAIN ==========================================================================

# 1) Tools
install_pkgs

# 2) Download ZIP
mkdir -p "$WORKDIR"
download_file "$ZIP_URL" "$ZIP_PATH"

# 3) Extract
rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"
unzip -q "$ZIP_PATH" -d "$EXTRACT_DIR"

# 4) Move to /opt/<app>-<version>
sudo rm -rf "$INSTALL_DIR"
# If the ZIP contains a single top-level dir, move that; else move all contents
if [ "$(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1 ]; then
  top="$(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d)"
  sudo mv "$top" "$INSTALL_DIR"
else
  sudo mkdir -p "$INSTALL_DIR"
  sudo mv "$EXTRACT_DIR"/* "$INSTALL_DIR"/
fi

# 5) Detect main executable and create wrapper
main_exec="$(detect_main_executable || true)"
if [ -z "${main_exec:-}" ]; then
  echo "WARNING: Could not detect the main executable automatically in: $INSTALL_DIR"
  echo "You can edit the wrapper at: $SYMLINK_BIN after we create it with a placeholder."
  # create a placeholder wrapper that opens the install dir
  sudo tee "$SYMLINK_BIN" >/dev/null <<EOF
#!/usr/bin/env bash
cd "${INSTALL_DIR}"
echo "Could not auto-detect JS8Spotter executable. Please edit ${SYMLINK_BIN} to launch the correct file."
ls -la
EOF
  sudo chmod +x "$SYMLINK_BIN"
else
  create_wrapper "$main_exec"
fi

# 6) Icon + desktop entry
create_icon
create_desktop_file

# 7) Pin to taskbar
pin_to_taskbar

echo
echo "✅ ${APP_NAME} ${VERSION} installed to ${INSTALL_DIR}"
echo "   Command: ${SYMLINK_BIN}"
echo "   Launcher: ${DESKTOP_FILE}"
echo "   Icon: ${ICON_PATH}"
echo "   If a different file should be launched, edit ${SYMLINK_BIN} to point at it."
echo "   To update later, change VERSION and ZIP_URL at the top, then re-run this script."