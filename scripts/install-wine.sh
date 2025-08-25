#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : System-level Wine installer + user-level prefix bootstrap
# Uses sudo to install packages; initializes a per-user prefix in ~/.local/share/wine/default
set -euo pipefail
. "$(dirname "$0")/env.sh"

# --- config ---
AUTO_YES="${AUTO_YES:-1}"          # set to 1 to auto-confirm
WINEPREFIX_DIR="${DATA_DIR}/wine/default"

confirm() {
  if [[ "$AUTO_YES" == "1" ]]; then return 0; fi
  read -r -p "${1:-Proceed?} [y/N] " ans
  [[ "${ans:-N}" =~ ^[Yy]$ ]]
}

need_sudo() {
  if command -v sudo >/dev/null 2>&1; then
    if sudo -n true 2>/dev/null; then return 0; fi
    echo "This step needs sudo privileges to install Wine system packages."
    confirm "Allow sudo now?" || { echo "Cancelled."; exit 1; }
    return 0
  fi
  echo "sudo not found; cannot install system packages." >&2
  exit 1
}

detect_distro() {
  . /etc/os-release 2>/dev/null || true
  echo "${ID_LIKE:-}${ID:+ $ID}" | tr '[:upper:]' '[:lower:]'
}

install_wine() {
  local fam; fam="$(detect_distro)"
  need_sudo

  if [[ "$fam" =~ debian|ubuntu|mint ]]; then
    echo "Detected Debian/Ubuntu family."
    sudo dpkg --add-architecture i386 || true
    sudo apt-get update -y
    sudo apt-get install -y --no-install-recommends \
      wine wine64 wine32 winetricks
  elif [[ "$fam" =~ fedora|rhel|centos ]]; then
    echo "Detected Fedora/RHEL family."
    sudo dnf install -y wine winetricks || sudo dnf install -y wine
  elif [[ "$fam" =~ arch|manjaro ]]; then
    echo "Detected Arch/Manjaro family."
    sudo pacman -Sy --needed --noconfirm wine winetricks || sudo pacman -Sy --needed --noconfirm wine
  elif [[ "$fam" =~ suse|opensuse ]]; then
    echo "Detected openSUSE family."
    sudo zypper --non-interactive install wine winetricks || sudo zypper --non-interactive install wine
  else
    echo "Unknown distro (ID/ID_LIKE: ${fam})."
    echo "Please install Wine and Winetricks manually, then re-run this script to set up the user prefix."
    exit 1
  fi
}

bootstrap_prefix() {
  mkdir -p "$WINEPREFIX_DIR"
  export WINEPREFIX="$WINEPREFIX_DIR"
  export WINEDEBUG="-all"

  echo "Initializing user Wine prefix at: $WINEPREFIX"
  # Try to initialize quietly; if this fails (e.g., no X display), skip without failing the whole script
  if command -v wineboot >/dev/null 2>&1; then
    if wineboot -u >/dev/null 2>&1; then
      echo "Wine prefix initialized."
    else
      echo "Could not initialize Wine prefix (no GUI/display?). You can run 'wineboot -u' later." >&2
    fi
  else
    echo "wineboot not found on PATH after install." >&2
  fi
}

main() {
  echo "=== Wine Installer ==="
  echo "This will install Wine system-wide (uses sudo) and create a per-user prefix:"
  echo "  Prefix: $WINEPREFIX_DIR"
  confirm "Proceed with Wine install?" || { echo "Cancelled."; exit 1; }

  install_wine
  bootstrap_prefix

  echo "✓ Wine installation step completed."
  echo "User prefix: $WINEPREFIX_DIR"
}

main "$@"
