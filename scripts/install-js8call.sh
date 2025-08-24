#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 24 August 2025
# Updated : 24 August 2025
# Purpose : Install JS8Call

VERSION="${VERSION:-2.2.0}"
FILE="${FILE:-js8call_${VERSION}_20.04-Linux-Desktop.x86_64.AppImage}"
URL="${URL:-http://files.js8call.com/${VERSION}/${FILE}}"


echo "Installing JS8Call dependencies..."
apt install \
  libqt5serialport5 \
  libqt5multimedia5-plugins \
  libqt5widgets5 \
  libqt5multimediawidgets5 \
  libqt5core5a \
  libqt5gui5 \
  libqt5multimedia5 \
  libqt5network5 \
  libqt5printsupport5 \
  libqt5serialport5 \
  libqt5widgets5 \
  libdouble-conversion3 \
  libpcre2-16-0 \
  qttranslations5-l10n \
  libmd4c0 \
  libqt5dbus5 \
  libxcb-xinerama0 \
  libxcb-xinput0 \
  libqt5svg5 \
  qt5-gtk-platformtheme \
  libqt5multimediagsttools5 \
  libgfortran5 \
  -y

# --- Config ---
APP_NAME="JS8Call"
APP_BIN_NAME="js8call"
APPIMAGE_NAME="js8call-${VERSION}.AppImage"
SYSTEM_INSTALL_DIR="/opt/js8call"
USER_INSTALL_DIR="${HOME}/.local/opt/js8call"
USER_BIN_DIR="${HOME}/.local/bin"
DESKTOP_FILE="${HOME}/.local/share/applications/${APP_BIN_NAME}.desktop"
ICON_TARGET="${HOME}/.local/share/icons/${APP_BIN_NAME}.png"

# --- Helpers ---
have() { command -v "$1" >/dev/null 2>&1; }
can_sudo() { sudo -n true >/dev/null 2>&1; }
msg() { printf "\033[1;32m%s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$*"; }
err() { printf "\033[1;31m%s\033[0m\n" "$*" >&2; }
die() { err "$@"; exit 1; }

# --- Basic checks ---
ARCH="$(uname -m || true)"
case "$ARCH" in
  x86_64|amd64) : ;;
  *) warn "This AppImage is built for x86_64, but your arch is '$ARCH'. It may not run."; sleep 1 ;;
esac

if ! have curl && ! have wget; then
  die "Need 'curl' or 'wget' to download ${APP_NAME}."
fi

# Install libfuse2 on Debian/Ubuntu if available (AppImages often require it)
if have apt-get && ! dpkg -s libfuse2 >/dev/null 2>&1; then
  if can_sudo; then
    msg "Installing libfuse2 (required by many AppImages)..."
    sudo apt-get update -y || true
    sudo apt-get install -y libfuse2 || warn "Couldn't install libfuse2 automatically. You may need to install it manually."
  else
    warn "libfuse2 may be required. If the AppImage fails to run, install it with: sudo apt-get install -y libfuse2"
  fi
fi

# --- Decide install location ---
INSTALL_DIR="$USER_INSTALL_DIR"
BIN_LINK="${USER_BIN_DIR}/${APP_BIN_NAME}"

if can_sudo; then
  INSTALL_DIR="$SYSTEM_INSTALL_DIR"
  BIN_LINK="/usr/local/bin/${APP_BIN_NAME}"
fi

# --- Create dirs ---
mkdir -p "$INSTALL_DIR"
mkdir -p "$(dirname "$BIN_LINK")"
mkdir -p "$(dirname "$DESKTOP_FILE")"
mkdir -p "$(dirname "$ICON_TARGET")"

# --- Download ---
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
OUT="${TMP_DIR}/${APPIMAGE_NAME}"

msg "Downloading ${APP_NAME} ${VERSION}..."
if have curl; then
  curl -fL "$URL" -o "$OUT"
else
  wget -O "$OUT" "$URL"
fi

# Sanity check
[ -s "$OUT" ] || die "Download failed or empty file from: $URL"

# --- Install AppImage ---
chmod +x "$OUT"

if [ "$INSTALL_DIR" = "$SYSTEM_INSTALL_DIR" ]; then
  msg "Installing to ${INSTALL_DIR} (sudo)..."
  sudo mkdir -p "$INSTALL_DIR"
  sudo cp -f "$OUT" "${INSTALL_DIR}/${APPIMAGE_NAME}"
  sudo ln -sfn "${INSTALL_DIR}/${APPIMAGE_NAME}" "${INSTALL_DIR}/js8call.AppImage"
  sudo chmod 0755 "${INSTALL_DIR}/${APPIMAGE_NAME}" "${INSTALL_DIR}/js8call.AppImage"
else
  msg "Installing to ${INSTALL_DIR} (user)..."
  cp -f "$OUT" "${INSTALL_DIR}/${APPIMAGE_NAME}"
  ln -sfn "${INSTALL_DIR}/${APPIMAGE_NAME}" "${INSTALL_DIR}/js8call.AppImage"
  chmod 0755 "${INSTALL_DIR}/${APPIMAGE_NAME}" "${INSTALL_DIR}/js8call.AppImage"
fi

APPIMAGE_PATH="${INSTALL_DIR}/js8call.AppImage"

# --- Create command symlink ---
if [ "$INSTALL_DIR" = "$SYSTEM_INSTALL_DIR" ]; then
  if can_sudo; then
    sudo ln -sfn "$APPIMAGE_PATH" "$BIN_LINK"
  fi
else
  ln -sfn "$APPIMAGE_PATH" "$BIN_LINK"
  case ":$PATH:" in
    *":${USER_BIN_DIR}:"*) : ;;
    *)
      warn "Your PATH doesn't include ${USER_BIN_DIR}. Consider adding this to your shell rc:"
      echo 'export PATH="$HOME/.local/bin:$PATH"'
      ;;
  esac
fi

# --- Try to extract an icon from the AppImage (optional but nice) ---
extract_icon() {
  local tmp="$TMP_DIR/extract"
  mkdir -p "$tmp"
  ( cd "$tmp" && "$APPIMAGE_PATH" --appimage-extract >/dev/null 2>&1 || true )
  local icon
  # Prefer a larger icon if present
  for size in 512 256 128 64 48 32 24 16; do
    icon="$(find "$tmp/squashfs-root" -type f -path "*/icons/hicolor/${size}x${size}/apps/*.png" | head -n 1 || true)"
    [ -n "${icon:-}" ] && break
  done
  # Fallback: any app icon PNG embedded
  if [ -z "${icon:-}" ]; then
    icon="$(find "$tmp/squashfs-root" -type f -name '*js8call*.png' | head -n 1 || true)"
  fi
  if [ -n "${icon:-}" ]; then
    cp -f "$icon" "$ICON_TARGET"
    msg "Icon extracted to ${ICON_TARGET}"
    return 0
  fi
  return 1
}
extract_icon || warn "Could not auto-extract an icon from the AppImage (continuing)."

# --- Desktop launcher (user scope) ---
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=${APP_NAME}
Comment=Amateur Radio weak-signal communications (JS8)
Exec=${BIN_LINK} %U
Icon=${ICON_TARGET}
Terminal=false
Categories=Network;HamRadio;Utility;
StartupWMClass=js8call
EOF

# Try to refresh desktop/icon caches (best effort)
have update-desktop-database && update-desktop-database "$(dirname "$DESKTOP_FILE")" || true
have gtk-update-icon-cache && gtk-update-icon-cache -q "$(dirname "$ICON_TARGET")/.." || true

# --- Final check ---
if "$APPIMAGE_PATH" --appimage-version >/dev/null 2>&1; then
  msg "${APP_NAME} ${VERSION} installed. Launch with: ${APP_BIN_NAME}"
else
  warn "Installed, but a quick run test failed. If you see a 'FUSE' related error, install libfuse2 (Debian/Ubuntu) and try again."
fi

# --- Summary ---
echo
msg "Done!"
echo "Binary symlink : $BIN_LINK"
echo "AppImage path  : $APPIMAGE_PATH"
echo "Launcher       : $DESKTOP_FILE"
[ -f "$ICON_TARGET" ] && echo "Icon           : $ICON_TARGET"