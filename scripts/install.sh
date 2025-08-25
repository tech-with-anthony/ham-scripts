#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : Master user-level install (no sudo)
set -euo pipefail

# refuse root
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
  echo "Don't run install.sh as root. This is a user-level installer." >&2
  exit 1
fi

. "./scripts/env.sh"

# optional apt update before doing anything else
if command -v apt-get >/dev/null 2>&1; then
  echo "Running apt-get update (requires sudo)..."
  if sudo -n true 2>/dev/null; then
    sudo apt-get update -y
  else
    echo "You may be prompted for your password..."
    sudo apt-get update -y
  fi
fi

# PATH tip
if ! echo ":$PATH:" | grep -q ":$BIN_DIR:"; then
  echo 'Tip: add to PATH for future shells:'
  echo '  echo '\''export PATH="$HOME/.local/bin:$PATH"'\'' >> ~/.bashrc'
fi

run() {
  local file="$1"
  if [[ ! -x "$file" ]]; then
    echo "skip: $file (not found or not executable)"; return 0
  fi
  echo "→ $file"
  NO_SUDO=1 PREFIX="$PREFIX" BIN_DIR="$BIN_DIR" DESKTOP_DIR="$DESKTOP_DIR" ICON_DIR="$ICON_DIR" DATA_DIR="$DATA_DIR" SHARE_DIR="$SHARE_DIR" \
    bash "$file" || { echo "warn: $file failed; continuing"; return 0; }
  echo "✓ $file"
}

run "./scripts/install-branding.sh"
run "./scripts/install-js8call.sh"
run "./scripts/install-wine.sh"
run "./scripts/install-wsjtx.sh"
run "./scripts/install-js8spotter.sh"
run "./scripts/pin-apps.sh"

# show post-install notes if present
[ -f "scripts/post-install-steps.txt" ] && cp -f "scripts/post-install-steps.txt" "$HOME/Desktop/" 2>/dev/null || true
if command -v dialog >/dev/null 2>&1 && [ -f "scripts/post-install-steps.txt" ]; then
  dialog --textbox "scripts/post-install-steps.txt" 115 74
else
  [ -f "scripts/post-install-steps.txt" ] && { echo; echo "Post-install steps:"; cat scripts/post-install-steps.txt; }
fi

echo "Done. For this session: export PATH=\"$BIN_DIR:\$PATH\""
