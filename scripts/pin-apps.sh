#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : Apply icons to apps and add to taskbar/favorites
set -euo pipefail

USER_APPS_DIR="$HOME/.local/share/applications"
ICON_BASE="$HOME/.local/share/icons/hicolor"
ICON_DIR_256="$ICON_BASE/256x256/apps"
REPO_ROOT="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
APPICONS_DIR="$REPO_ROOT/app-icons"

mkdir -p "$USER_APPS_DIR" "$ICON_DIR_256"

# name→pretty label mapping; add more as you add PNGs
declare -A NAMES=(
  [js8call]="JS8Call"
  [wsjtx]="WSJT-X"
  [js8spotter]="JS8Spotter"
)

# find a binary in PATH or ~/.local/bin
bin_of(){ command -v "$1" 2>/dev/null || [ -x "$HOME/.local/bin/$1" ] && echo "$HOME/.local/bin/$1" || true; }

# install one icon + desktop + favorite
handle_app() {
  local base="$1" pretty="${NAMES[$1]:-$1}"
  local png="$APPICONS_DIR/${base}.png"
  local dest_png="$ICON_DIR_256/${base}.png"
  local exe desktop

  [ -f "$png" ] || { echo "skip: $png not found"; return 0; }
  install -Dm644 "$png" "$dest_png"

  exe="$(bin_of "$base")"
  [ -n "${exe:-}" ] || { echo "warn: binary '$base' not found; desktop will point to name"; exe="$base"; }

  desktop="$USER_APPS_DIR/${base}.desktop"
  if [ -f "$desktop" ]; then
    sed -i "s|^Exec=.*$|Exec=${exe}|g" "$desktop"
    if grep -q "^Icon=" "$desktop"; then
      sed -i "s|^Icon=.*$|Icon=${dest_png}|g" "$desktop"
    else
      printf '\nIcon=%s\n' "$dest_png" >> "$desktop"
    fi
  else
    cat >"$desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${pretty}
Exec=${exe}
Icon=${dest_png}
Categories=Network;HamRadio;
Terminal=false
EOF
  fi

  # pin to favorites (GNOME/Cinnamon)
  local desk="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
  local dlc="$(printf '%s' "$desk" | tr '[:upper:]' '[:lower:]')"
  local schema key
  if echo "$dlc" | grep -q gnome; then schema="org.gnome.shell"; key="favorite-apps"
  elif echo "$dlc" | grep -q cinnamon; then schema="org.cinnamon"; key="favorite-apps"
  else
    echo "info: unsupported desktop '$desk'; pinned desktop file created at $desktop"
    return 0
  fi
  if command -v gsettings >/dev/null 2>&1 && gsettings list-schemas | grep -q "^$schema$"; then
    local cur new appid="${base}.desktop"
    cur="$(gsettings get "$schema" "$key")"
    new="$(printf '%s' "$cur" | sed -E 's/^\[|\]$//g')"
    echo "$new" | grep -q "'$appid'" || gsettings set "$schema" "$key" "[$([ -n "$new" ] && echo "$new, ")'${appid}']"
  fi
}

# run for known names that have PNGs; add any others you put in app-icons/
for base in "${!NAMES[@]}"; do handle_app "$base"; done

# refresh caches
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$USER_APPS_DIR" >/dev/null 2>&1 || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -f "$ICON_BASE" >/dev/null 2>&1 || true

echo "Done. If icons still look stale: GNOME Xorg → Alt+F2, r, Enter; Wayland → log out/in."
