#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 26 August 2025
# Updated : 26 August 2025
# Purpose : Common helpers to install & apply the Ham-Scripts configuration
# Source this from any install-*.sh

set -euo pipefail

REPO_DIR_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="${REPO_DIR:-$REPO_DIR_DEFAULT}"
CONFIG_APP_INSTALLER="$REPO_DIR/install-setup-config-app.sh"

ensure_config_app_installed() {
  if ! command -v ham-scripts-config >/dev/null 2>&1; then
    if [[ -x "$CONFIG_APP_INSTALLER" ]]; then
      echo "[ham-scripts] Installing config app..."
      (cd "$REPO_DIR" && sudo "$CONFIG_APP_INSTALLER")
    else
      echo "[ham-scripts] ERROR: missing $CONFIG_APP_INSTALLER" >&2
      return 1
    fi
  fi
}

# Apply canonical config to all supported apps. Behavior:
# - If ~/.config/ham-scripts/config.yaml exists, apply silently
# - Otherwise, show GUI (or CLI if headless)
post_install_apply_ham_config() {
  ensure_config_app_installed || return 0
  if [[ -f "$HOME/.config/ham-scripts/config.yaml" ]]; then
    echo "[ham-scripts] Applying existing station config..."
    ham-scripts-config --apply || true
  else
    if [[ "${HAM_SCRIPTS_HEADLESS:-0}" == "1" ]]; then
      echo "[ham-scripts] HEADLESS=1 and no canonical config present; skipping UI."
    else
      echo "[ham-scripts] Launching config UI so you can save callsign/grid..."
      ham-scripts-config || true
    fi
  fi
}

