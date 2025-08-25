#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : Shared environment + helpers for user-level installers (no sudo)
set -euo pipefail

# ---------- Paths ----------
# repo root (parent of this file's dir)
export REPO_ROOT="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# XDG-style user locations
export PREFIX="${PREFIX:-$HOME/.local}"
export BIN_DIR="${BIN_DIR:-$PREFIX/bin}"
export DESKTOP_DIR="${DESKTOP_DIR:-$PREFIX/share/applications}"
export ICON_DIR="${ICON_DIR:-$PREFIX/share/icons/hicolor/256x256/apps}"
export SHARE_DIR="${SHARE_DIR:-$PREFIX/share}"
export DATA_DIR="${DATA_DIR:-$HOME/.local/share}"

# default to “no sudo” for sub-installers
export NO_SUDO="${NO_SUDO:-1}"

# ensure dirs exist
mkdir -p "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR" "$SHARE_DIR" "$DATA_DIR"

# ---------- Helpers ----------
have() { command -v "$1" >/dev/null 2>&1; }

msg()  { printf "\033[1;32m%s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$*" >&2; }
err()  { printf "\033[1;31m%s\033[0m\n" "$*" >&2; }
die()  { err "$@"; exit 1; }

# find an icon PNG in the repo for a given app id (e.g., "wsjtx")
# echoes absolute path if found, empty otherwise
find_repo_icon() {
  local app="$1"
  local base="$REPO_ROOT"
  # candidate folders (add/remove as needed)
  local -a dirs=("$base/app-icons" "$base/logo" "$base/icons")
  # candidate filenames (case/format variants)
  local -a names=(
    "${app}.png" "${app}.PNG"                               # exact
    "$(echo "$app" | tr '[:lower:]' '[:upper:]').png"       # UPPER
    "$(echo "$app" | tr '[:upper:]' '[:lower:]').png"       # lower
    "${app}-icon.png" "${app}_icon.png"                     # suffix
    "JS8Call.png" "WSJTX.png" "JS8Spotter.png"              # common titles
    "ham-scripts_${app}.png"                                # prefixed
  )
  local d n
  for d in "${dirs[@]}"; do
    for n in "${names[@]}"; do
      if [ -f "$d/$n" ]; then
        printf '%s\n' "$d/$n"
        return 0
      fi
    done
  done
  # final fallback: project logo if present
  [ -f "$base/logo/ham-scripts_logo.png" ] && printf '%s\n' "$base/logo/ham-scripts_logo.png" || printf ''
}


# require a command to exist, otherwise instruct user to install it once
req() {
  local c
  for c in "$@"; do
    have "$c" || die "Missing dependency: '$c'. Install it once with your package manager."
  done
}

# refuse root for user-level scripts
ensure_not_root() {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    die "Don't run this as root. These installers target \$HOME/.local."
  fi
}

# ensure ~/.local/bin in PATH (print hint; don't mutate current shell)
path_hint() {
  if ! printf '%s' ":$PATH:" | grep -q ":$BIN_DIR:"; then
    warn "Tip: add to PATH for future shells:"
    echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
  fi
}
