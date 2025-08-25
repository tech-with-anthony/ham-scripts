#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : Pin installed apps to desktop environment favorites (if supported)
set -euo pipefail

declare -A APPS=(
  [js8call]="JS8Call"
  [wsjtx]="WSJT-X"
  [js8spotter]="JS8Spotter"
)

USER_APPS_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
mkdir -p "$USER_APPS_DIR" "$ICON_DIR"

# Return: path to binary or empty
find_bin() {
  local app="$1"
  local exe
  exe="$(command -v "$app" || true)"
  [ -z "$exe" ] && [ -x "$HOME/.local/bin/$app" ] && exe="$HOME/.local/bin/$app"
  printf '%s' "${exe:-}"
}

# ensure/create minimal .desktop; update Exec/Icon if changed
ensure_desktop() {
  local app="$1" name="$2"
  local desktop="$USER_APPS_DIR/${app}.desktop"
  local exe icon
  exe="$(find_bin "$app")"
  if [ -z "$exe" ]; then
    echo "warn: $app binary not found; skipping"
    return 1
  fi
  icon="$ICON_DIR/${app}.png"
  [ -f "$icon" ] || icon=""   # only set if exists

  if [ -f "$desktop" ]; then
    # update fields if stale
    grep -q "^Exec=${exe}$" "$desktop" 2>/dev/null || \
      sed -i "s|^Exec=.*$|Exec=${exe}|g" "$desktop"
    if [ -n "$icon" ]; then
      if grep -q "^Icon=" "$desktop"; then
        grep -q "^Icon=${icon}$" "$desktop" || sed -i "s|^Icon=.*$|Icon=${icon}|g" "$desktop"
      else
        printf '\nIcon=%s\n' "$icon" >> "$desktop"
      fi
    fi
  else
    cat >"$desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
Exec=${exe}
$( [ -n "$icon" ] && echo "Icon=${icon}" )
Categories=Network;HamRadio;
Terminal=false
EOF
  fi

  # validate Exec
  if ! grep -q "^Exec=${exe}$" "$desktop"; then
    echo "warn: ${desktop} Exec mismatch; check file"
  fi
  echo "$desktop"
}

# Add APP.desktop to gsettings favorites if missing
add_to_favorites() {
  local app="$1" schema="$2" key="$3"
  local app_id="${app}.desktop"

  command -v gsettings >/dev/null 2>&1 || { echo "gsettings not found; skipping favorites"; return 1; }
  gsettings list-schemas | grep -q "^${schema}$" || { echo "schema ${schema} missing; skipping"; return 1; }

  local current new
  current="$(gsettings get "$schema" "$key")"   # e.g. ['app1.desktop', 'app2.desktop']
  # normalize inside of []
  new="$(printf '%s' "$current" | sed -E 's/^\[|\]$//g')"

  if printf '%s' "$new" | grep -q "'${app_id}'"; then
    echo "already pinned: ${app_id}"
    return 0
  fi

  if [ -z "$new" ]; then
    new="'${app_id}'"
  else
    new="${new}, '${app_id}'"
  fi

  echo "pinning: ${app_id}"
  gsettings set "$schema" "$key" "[$new]"
}

# Which desktop?
desk="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
desk_lc="$(printf '%s' "$desk" | tr '[:upper:]' '[:lower:]')"

pinned_any=0
for app in "${!APPS[@]}"; do
  ensure_desktop "$app" "${APPS[$app]}" || continue

  if echo "$desk_lc" | grep -q "gnome"; then
    add_to_favorites "$app" "org.gnome.shell" "favorite-apps" && pinned_any=1
  elif echo "$desk_lc" | grep -q "cinnamon"; then
    add_to_favorites "$app" "org.cinnamon" "favorite-apps" && pinned_any=1
  else
    echo "unsupported desktop: $desk"
    echo "pin manually using: $USER_APPS_DIR/${app}.desktop"
  fi
done

# Refresh app cache if available
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
fi

[ "$pinned_any" -eq 1 ] && echo "Done." || echo "Nothing changed."
