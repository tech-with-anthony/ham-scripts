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
