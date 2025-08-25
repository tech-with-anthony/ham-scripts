#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : Set wallpaper
set -euo pipefail
. "$(dirname "$0")/env.sh"

SRC_LOGO="$REPO_ROOT/logo/ham-scripts_logo.png"
WALLPAPER_DIR="$DATA_DIR/backgrounds"
DEST_LOGO="$WALLPAPER_DIR/ham-scripts_logo.png"

mkdir -p "$WALLPAPER_DIR"

if [ ! -f "$SRC_LOGO" ]; then
  echo "⚠ Branding logo not found: $SRC_LOGO"
  exit 1
fi

# Copy into ~/.local/share/backgrounds
install -Dm644 "$SRC_LOGO" "$DEST_LOGO"
echo "✓ Copied logo to $DEST_LOGO"

# Detect desktop environment
desk="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
desk_lc="$(printf '%s' "$desk" | tr '[:upper:]' '[:lower:]')"

set_gnome_bg() {
  gsettings set org.gnome.desktop.background picture-uri "file://$DEST_LOGO"
  gsettings set org.gnome.desktop.background picture-uri-dark "file://$DEST_LOGO" || true
  echo "✓ Set GNOME background"
}

set_cinnamon_bg() {
  gsettings set org.cinnamon.desktop.background picture-uri "file://$DEST_LOGO"
  echo "✓ Set Cinnamon background"
}

set_xfce_bg() {
  if command -v xfconf-query >/dev/null 2>&1; then
    for prop in $(xfconf-query -c xfce4-desktop -l | grep last-image); do
      xfconf-query -c xfce4-desktop -p "$prop" -s "$DEST_LOGO"
    done
    echo "✓ Set XFCE background"
  else
    echo "⚠ xfconf-query not available; cannot set XFCE wallpaper automatically."
  fi
}

if echo "$desk_lc" | grep -q "gnome"; then
  set_gnome_bg
elif echo "$desk_lc" | grep -q "cinnamon"; then
  set_cinnamon_bg
elif echo "$desk_lc" | grep -q "xfce"; then
  set_xfce_bg
else
  echo "⚠ Unsupported desktop environment: $desk"
  echo "Set $DEST_LOGO as your wallpaper manually."
fi
