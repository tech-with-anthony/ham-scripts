#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : Pin installed apps to desktop environment favorites (if supported)
set -euo pipefail

# Apps to pin: command -> Pretty Name
declare -A APPS=(
  [js8call]="JS8Call"
  [wsjtx]="WSJT-X"
  [js8spotter]="JS8Spotter"
)

USER_APPS_DIR="$HOME/.local/share/applications"
ICON_BASE="$HOME/.local/share/icons/hicolor"
ICON_DIR_256="$ICON_BASE/256x256/apps"
REPO_ROOT="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FALLBACK_LOGO="$REPO_ROOT/logo/ham-scripts_logo.png"

mkdir -p "$USER_APPS_DIR" "$ICON_DIR_256"

find_bin() {
  local app="$1"
  local exe
  exe="$(command -v "$app" || true)"
  [ -z "$exe" ] && [ -x "$HOME/.local/bin/$app" ] && exe="$HOME/.local/bin/$app"
  printf '%s' "${exe:-}"
}

# Try hard to put a 256x256 PNG at $ICON_DIR_256/APP.png
ensure_icon() {
  local app="$1"
  local target="$ICON_DIR_256/${app}.png"
  [ -f "$target" ] && { echo "$target"; return 0; }

  # 1) Look in system icon theme and pixmaps
  for p in \
    "/usr/share/icons/hicolor/256x256/apps/${app}.png" \
    "/usr/share/pixmaps/${app}.png" \
    "/usr/share/icons/hicolor/128x128/apps/${app}.png" \
    "/usr/share/pixmaps/${app}.xpm"
  do
    [ -f "$p" ] && { install -Dm644 "$p" "$target"; echo "$target"; return 0; }
  done

  # 2) Try to extract from AppImage if the app is an AppImage
  local exe; exe="$(find_bin "$app")"
  if [ -n "$exe" ] && [[ "$exe" == *.AppImage ]]; then
    tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' RETURN
    if "$exe" --appimage-extract >/dev/null 2>&1; then
      if [ -f "squashfs-root/usr/share/icons/hicolor/256x256/apps/${app}.png" ]; then
        install -Dm644 "squashfs-root/usr/share/icons/hicolor/256x256/apps/${app}.png" "$target"
        rm -rf squashfs-root
        echo "$target"; return 0
      fi
      rm -rf squashfs-root
    fi
  fi

  # 3) Last resort: use your repo logo
  if [ -f "$FALLBACK_LOGO" ]; then
    install -Dm644 "$FALLBACK_LOGO" "$target"
    echo "$target"; return 0
  fi

  # Fail (no icon)
  echo ""
  return 1
}

# Create or update a .desktop file; set themed Icon=APP
ensure_desktop() {
  local app="$1" name="$2"
  local exe icon desktop
  exe="$(find_bin "$app")"
  [ -z "$exe" ] && { echo "warn: $app binary not found; skipping"; return 1; }

  icon="$(ensure_icon "$app" || true)"
  desktop="$USER_APPS_DIR/${app}.desktop"

  if [ -f "$desktop" ]; then
    # Update Exec and Icon line to ensure correctness
    grep -q "^Exec=${exe}$" "$desktop" 2>/dev/null || sed -i "s|^Exec=.*$|Exec=${exe}|g" "$desktop"
    if grep -q "^Icon=" "$desktop"; then
      sed -i "s|^Icon=.*$|Icon=${app}|g" "$desktop"
    else
      printf '\nIcon=%s\n' "${app}" >> "$desktop"
    fi
  else
    cat >"$desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
Exec=${exe}
Icon=${app}
Categories=Network;HamRadio;
Terminal=false
EOF
  fi
  echo "$desktop"
}

# Add APP.desktop to favorites if missing
add_to_favorites() {
  local app="$1" schema="$2" key="$3"
  local app_id="${app}.desktop"

  command -v gsettings >/dev/null 2>&1 || { echo "gsettings not found; skipping favorites"; return 1; }
  gsettings list-schemas | grep -q "^${schema}$" || { echo "schema ${schema} missing; skipping"; return 1; }

  local current new
  current="$(gsettings get "$schema" "$key")"
  new="$(printf '%s' "$current" | sed -E 's/^\[|\]$//g')"

  if printf '%s' "$new" | grep -q "'${app_id}'"; then
    echo "already pinned: ${app_id}"
    return 0
  fi
  [ -z "$new" ] && new="'${app_id}'" || new="${new}, '${app_id}'"
  echo "pinning: ${app_id}"
  gsettings set "$schema" "$key" "[$new]"
}

# Detect desktop
desk="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
desk_lc="$(printf '%s' "$desk" | tr '[:upper:]' '[:lower:]')"

changed=0
for app in "${!APPS[@]}"; do
  # Make sure desktop + icon are in place
  ensure_desktop "$app" "${APPS[$app]}" || continue
  changed=1

  # Pin
  if echo "$desk_lc" | grep -q "gnome"; then
    add_to_favorites "$app" "org.gnome.shell" "favorite-apps"
  elif echo "$desk_lc" | grep -q "cinnamon"; then
    add_to_favorites "$app" "org.cinnamon" "favorite-apps"
  else
    echo "unsupported desktop: $desk"
    echo "pin manually using: $USER_APPS_DIR/${app}.desktop"
  fi
done

# Refresh caches so icons show up immediately
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f "$ICON_BASE" >/dev/null 2>&1 || true
fi

[ "$changed" -eq 1 ] && echo "Done." || echo "Nothing changed."
