#!/usr/bin/env bash
# set-wallpaper.sh — change desktop wallpaper on Ubuntu
# Usage: ./set-wallpaper.sh [/absolute/or/relative/image/path]
set -euo pipefail

IMG_DEFAULT="$HOME/ham-scripts-os/logo/ham-scripts_tth_logo.png"
IMG="${1:-$IMG_DEFAULT}"

if [ ! -f "$IMG" ]; then
  echo "Error: image not found: $IMG" >&2
  exit 1
fi

# Normalize path and build file:// URI
if command -v readlink >/dev/null 2>&1; then
  IMG="$(readlink -f "$IMG")"
fi
URI="file://$IMG"

have() { command -v "$1" >/dev/null 2>&1; }

ok=0

### GNOME/Budgie/Unity/Cosmic (gsettings)
if have gsettings; then
  if gsettings list-schemas | grep -q '^org.gnome.desktop.background$'; then
    gsettings set org.gnome.desktop.background picture-uri "$URI" || true
    # Set the dark-mode variant too if available (GNOME 42+)
    if gsettings list-keys org.gnome.desktop.background | grep -qx 'picture-uri-dark'; then
      gsettings set org.gnome.desktop.background picture-uri-dark "$URI" || true
    fi
    # Options: none, wallpaper, centered, scaled, stretched, zoom, spanned
    gsettings set org.gnome.desktop.background picture-options 'zoom' || true
    echo "GNOME/Budgie/Unity: wallpaper set."
    ok=1
  fi

  # Cinnamon
  if gsettings list-schemas | grep -q '^org.cinnamon.desktop.background$'; then
    gsettings set org.cinnamon.desktop.background picture-uri "$URI" || true
    gsettings set org.cinnamon.desktop.background picture-options 'zoom' || true
    echo "Cinnamon: wallpaper set."
    ok=1
  fi

  # MATE
  if gsettings list-schemas | grep -q '^org.mate.background$'; then
    gsettings set org.mate.background picture-filename "$IMG" || true
    gsettings set org.mate.background picture-options 'zoom' || true
    echo "MATE: wallpaper set."
    ok=1
  fi
fi

### XFCE
if [ $ok -eq 0 ] && have xfconf-query; then
  props="$(xfconf-query -c xfce4-desktop -lv 2>/dev/null | awk '{print $1}' \
          | grep -E '/last-image$|/image-path$|/image-show$|/image-style$' || true)"
  if [ -n "$props" ]; then
    while IFS= read -r p; do
      case "$p" in
        */last-image|*/image-path) xfconf-query -c xfce4-desktop -p "$p" -s "$IMG" ;;
        */image-show)              xfconf-query -c xfce4-desktop -p "$p" -s true   ;;
        */image-style)             xfconf-query -c xfce4-desktop -p "$p" -s 5      ;; # 5 = Zoomed
      esac
    done <<< "$props"
    echo "XFCE: wallpaper set."
    ok=1
  fi
fi

### KDE Plasma 5/6
if [ $ok -eq 0 ] && have qdbus && qdbus org.kde.plasmashell >/dev/null 2>&1; then
  # Escape for JS string
  ESC_URI="$(printf '%s' "$URI" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
  js=$(cat <<JS
var desks = desktops();
for (var i = 0; i < desks.length; i++) {
  var d = desks[i];
  d.wallpaperPlugin = "org.kde.image";
  d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
  d.writeConfig("Image", "$ESC_URI");
}
JS
)
  qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$js"
  echo "KDE Plasma: wallpaper set."
  ok=1
fi

### LXQt / LXDE
if [ $ok -eq 0 ] && have pcmanfm-qt; then
  pcmanfm-qt --set-wallpaper "$IMG" --wallpaper-mode=fit
  echo "LXQt: wallpaper set."
  ok=1
elif [ $ok -eq 0 ] && have pcmanfm; then
  pcmanfm --set-wallpaper "$IMG" --wallpaper-mode=fit
  echo "LXDE: wallpaper set."
  ok=1
fi

### Minimal WMs (fallbacks)
if [ $ok -eq 0 ] && have feh; then
  feh --bg-fill "$IMG"
  echo "feh: wallpaper set."
  ok=1
fi

if [ $ok -eq 0 ] && have nitrogen; then
  nitrogen --save --set-zoom-fill "$IMG"
  echo "Nitrogen: wallpaper set."
  ok=1
fi

if [ $ok -eq 0 ]; then
  echo "Could not detect a supported desktop environment automatically." >&2
  echo "Tip: install 'feh' (sudo apt install feh) and rerun this script." >&2
  exit 2
fi

exit 0
