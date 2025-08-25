#!/usr/bin/env bash
set -euo pipefail

declare -A APPS=(
  [js8call]="JS8Call"
  [wsjtx]="WSJT-X"
  [js8spotter]="JS8Spotter"
)

USER_APPS_DIR="$HOME/.local/share/applications"
ICON_BASE="$HOME/.local/share/icons/hicolor"
ICON_DIR_256="$ICON_BASE/256x256/apps"
ICON_DIR_SCAL="$ICON_BASE/scalable/apps"
REPO_ROOT="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FALLBACK_LOGO="$REPO_ROOT/logo/ham-scripts_logo.png"

mkdir -p "$USER_APPS_DIR" "$ICON_DIR_256" "$ICON_DIR_SCAL"

find_bin() {
  local app="$1" exe=""
  exe="$(command -v "$app" || true)"
  [ -z "$exe" ] && [ -x "$HOME/.local/bin/$app" ] && exe="$HOME/.local/bin/$app"
  printf '%s' "${exe:-}"
}

# Ensure we have a usable icon file on disk; return absolute path.
ensure_icon_file() {
  local app="$1"
  local t_png="$ICON_DIR_256/${app}.png"
  local t_svg="$ICON_DIR_SCAL/${app}.svg"

  # Already cached in user theme?
  [ -f "$t_png" ] && { printf '%s' "$t_png"; return 0; }
  [ -f "$t_svg" ] && { printf '%s' "$t_svg"; return 0; }

  # 1) System icons (if present)
  for p in \
    "/usr/share/icons/hicolor/256x256/apps/${app}.png" \
    "/usr/share/icons/hicolor/scalable/apps/${app}.svg" \
    "/usr/share/pixmaps/${app}.png" \
    "/usr/share/pixmaps/${app}.xpm" \
    "/usr/share/icons/hicolor/128x128/apps/${app}.png"
  do
    if [ -f "$p" ]; then
      case "$p" in
        *.svg) install -Dm644 "$p" "$t_svg"; printf '%s' "$t_svg"; return 0 ;;
        *)     install -Dm644 "$p" "$t_png"; printf '%s' "$t_png"; return 0 ;;
      esac
    fi
  done

  # 2) Try extracting from AppImage (if the app itself is an AppImage)
  local exe; exe="$(find_bin "$app")"
  if [ -n "$exe" ] && [[ "$exe" == *.AppImage ]]; then
    tmpdir="$(mktemp -d)"; pushd "$tmpdir" >/dev/null
    if "$exe" --appimage-extract >/dev/null 2>&1; then
      if [ -f "squashfs-root/usr/share/icons/hicolor/256x256/apps/${app}.png" ]; then
        install -Dm644 "squashfs-root/usr/share/icons/hicolor/256x256/apps/${app}.png" "$t_png"
        popd >/dev/null; rm -rf "$tmpdir"; printf '%s' "$t_png"; return 0
      fi
      if [ -f "squashfs-root/usr/share/icons/hicolor/scalable/apps/${app}.svg" ]; then
        install -Dm644 "squashfs-root/usr/share/icons/hicolor/scalable/apps/${app}.svg" "$t_svg"
        popd >/dev/null; rm -rf "$tmpdir"; printf '%s' "$t_svg"; return 0
      fi
    fi
    popd >/dev/null; rm -rf "$tmpdir"
  fi

  # 3) Fallback to your repo logo (copy as PNG name)
  if [ -f "$FALLBACK_LOGO" ]; then
    install -Dm644 "$FALLBACK_LOGO" "$t_png"
    printf '%s' "$t_png"; return 0
  fi

  printf ''  # no icon
  return 1
}

ensure_desktop() {
  local app="$1" name="$2"
  local exe icon desktop
  exe="$(find_bin "$app")"
  [ -z "$exe" ] && { echo "warn: $app not found; skipping"; return 1; }
  icon="$(ensure_icon_file "$app" || true)"
  desktop="$USER_APPS_DIR/${app}.desktop"

  if [ -f "$desktop" ]; then
    # Force absolute Exec & Icon path to avoid theme lookup issues
    grep -q "^Exec=${exe}$" "$desktop" 2>/dev/null || sed -i "s|^Exec=.*$|Exec=${exe}|g" "$desktop"
    if [ -n "$icon" ]; then
      if grep -q "^Icon=" "$desktop"; then
        sed -i "s|^Icon=.*$|Icon=${icon}|g" "$desktop"
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

  echo "$desktop"
}

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

# Desktop detection
desk="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
desk_lc="$(printf '%s' "$desk" | tr '[:upper:]' '[:lower:]')"

changed=0
for app in "${!APPS[@]}"; do
  ensure_desktop "$app" "${APPS[$app]}" || continue
  changed=1
  if echo "$desk_lc" | grep -q "gnome"; then
    add_to_favorites "$app" "org.gnome.shell" "favorite-apps"
  elif echo "$desk_lc" | grep -q "cinnamon"; then
    add_to_favorites "$app" "org.cinnamon" "favorite-apps"
  else
    echo "unsupported desktop: $desk"
    echo "pin manually using: $USER_APPS_DIR/${app}.desktop"
  fi
done

# Refresh desktop/ICON caches (best-effort)
command -v update-desktop-database >/dev/null 2>&1 && \
  update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

# Some systems require this only if the theme has an index; still harmless:
command -v gtk-update-icon-cache >/dev/null 2>&1 && \
  gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true

echo "$([ "$changed" -eq 1 ] && echo 'Done.' || echo 'Nothing changed.')"
