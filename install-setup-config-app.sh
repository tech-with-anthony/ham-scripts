#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 26 August 2025
# Updated : 26 August 2025
# Purpose : Install launcher + deps for the Ham‑Scripts User Configuration App
# - Ensures python3 + Tk + PyYAML (optional) are present

set -euo pipefail

APP_NAME="Ham-Scripts Config"
WRAP_BIN="/usr/local/bin/ham-scripts-config"
DESKTOP_FILE="/usr/share/applications/ham-scripts-config.desktop"
REPO_DIR="${REPO_DIR:-$PWD}"
SCRIPT_REL="tools/ham_config.py"
SCRIPT_PATH="$REPO_DIR/$SCRIPT_REL"

if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "Error: couldn't find $SCRIPT_REL relative to $REPO_DIR" >&2
  exit 1
fi

# Try to install deps on Debian/Ubuntu
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y python3 python3-tk || true
  sudo apt-get install -y python3-yaml || true
fi

# Wrapper
sudo tee "$WRAP_BIN" >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_PATH_PLACEHOLDER="REPLACEME"
exec python3 "$SCRIPT_PATH_PLACEHOLDER"
EOF
sudo sed -i "s|REPLACEME|$SCRIPT_PATH|" "$WRAP_BIN"
sudo chmod +x "$WRAP_BIN"

# Icon (optional). Use repo icon if present
ICON_PATH="$REPO_DIR/app-icons/ham-scripts.png"
if [[ ! -f "$ICON_PATH" ]]; then
  ICON_PATH="$REPO_DIR/logo/ham-scripts_logo.png"
fi

# Desktop entry
sudo tee "$DESKTOP_FILE" >/dev/null <<EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
Comment=Configure ham‑radio identity for Ham‑Scripts
Exec=$WRAP_BIN
Icon=$ICON_PATH
Terminal=false
Categories=HamRadio;Utility;Settings;
EOF

update-desktop-database >/dev/null 2>&1 || true

echo "Installed: $WRAP_BIN"
echo "Launcher: $DESKTOP_FILE"
echo "Run: ham-scripts-config"