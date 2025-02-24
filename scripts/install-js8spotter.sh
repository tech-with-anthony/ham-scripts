#!/bin/bash
#
# Author  : Anthony Woodward
# Date    : 23 February 2025
# Updated : 23 February 2025
# Purpose : Install JS8Spotter


# Variables
WORK_DIR="$INSTALL_DIR/js8spotter-114b"
DESKTOP_FILE="$INSTALL_DIR/Desktop/JS8Spotter.desktop"
JS8_URL="https://kf7mix.com/files/js8spotter/js8spotter-114b.zip"
ZIP_FILE="$INSTALL_DIR/js8spotter-114b.zip"

# Ensure required directories exist
echo "Ensuring directories exist..."
mkdir -p "$INSTALL_DIR/Desktop" || { echo "Failed to create desktop directory. Exiting."; exit 1; }
mkdir -p "$WORK_DIR" || { echo "Failed to create working directory. Exiting."; exit 1; }

# Update package list
echo "Updating package list..."
if ! sudo apt-get update; then
    echo "Failed to update package list. Exiting."
    exit 1
fi

# Install dependencies
echo "Installing required dependencies..."
if ! sudo apt install -y python3-tk python3-pil python3-pil.imagetk python3-requests python3-tksnack unzip wget; then
    echo "Failed to install dependencies. Exiting."
    exit 1
fi

# Download JS8Spotter
echo "Downloading JS8Spotter package..."
if ! wget -q -O "$ZIP_FILE" "$JS8_URL"; then
    echo "Failed to download JS8Spotter package. Exiting."
    exit 1
fi

# Extract the package
echo "Extracting JS8Spotter package..."
if ! unzip -o "$ZIP_FILE" -d "$INSTALL_DIR"; then
    echo "Failed to extract JS8Spotter package. Exiting."
    rm "$ZIP_FILE"
    exit 1
fi
#rm "$ZIP_FILE"

# Create desktop shortcut
echo "Creating desktop shortcut..."
cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Name=JS8Spotter
Comment=JS8Spotter Application
Exec=python3 $HOME/js8spotter-114b/js8spotter.py
Icon=$HOME/js8spotter-114b/js8spotter.ico
Path=$HOME/js8spotter-114b
Terminal=false
Type=Application
EOF

# Set permissions
echo "Setting permissions..."
chmod +x "$WORK_DIR/js8spotter.py"
chmod +x "$DESKTOP_FILE"

# Allow launching if gio is available
if command -v gio &>/dev/null; then
    echo "Allowing launching for desktop shortcut..."
    gio set "$DESKTOP_FILE" metadata::trusted true
else
    echo "gio command not found. Skipping 'Allow Launching' setup."
fi

# Adjust permissions for /etc/skel during Cubic install
if [ "$INSTALL_DIR" = "/etc/skel" ]; then
    echo "Adjusting permissions for Cubic environment..."
    chown -R root:root "$WORK_DIR"
    chmod -R 755 "$WORK_DIR"
    chown root:root "$DESKTOP_FILE"
    chmod 755 "$DESKTOP_FILE"
fi

# Verify installation
if [ -f "$WORK_DIR/js8spotter.py" ]; then
    echo "JS8Spotter installed successfully in $INSTALL_DIR."
else
    echo "JS8Spotter installation failed. Please check for errors."
    exit 1
fi

echo "Installation complete! You can launch JS8Spotter from the desktop shortcut."