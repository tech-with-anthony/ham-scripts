#!/bin/env bash
## From chatgpt to install device rules for ham radios for consitency in software across multiple radios, starts

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

echo "Setting up udev rules for radio devices..."

# Step 1: Install necessary packages only if they are not already installed
function check_and_install_package {
    PACKAGE_NAME=$1
    dpkg -l | grep -qw "$PACKAGE_NAME" || {
        echo "$PACKAGE_NAME is not installed. Installing..."
        apt update
        apt install -y "$PACKAGE_NAME"
    }
}

# Check and install udev package
check_and_install_package "udev"

# Step 2: Create the directory for custom udev rules
echo "Creating udev rules directory if it doesn't exist..."
mkdir -p /etc/udev/rules.d

# Step 3: Create the script that generates rules for serial devices (CAT control)
echo "Creating the autogen-radio.sh script..."
cat << 'EOF' > /usr/local/bin/autogen-radio.sh
#!/bin/bash

SERIAL="$1"
DEVNAME="$2"
RULES_DIR="/etc/udev/rules.d"
CUSTOM_RULE="$RULES_DIR/10-radio-${SERIAL}.rules"

# Exit if rule already exists
[ -f "$CUSTOM_RULE" ] && exit 0

# Generate a friendly name based on serial number and vendor/product IDs
VENDOR_ID=$(udevadm info --query=property --name=$DEVNAME | grep "ID_VENDOR_ID" | cut -d'=' -f2)
MODEL_ID=$(udevadm info --query=property --name=$DEVNAME | grep "ID_MODEL_ID" | cut -d'=' -f2)
SERIAL=$(udevadm info --query=property --name=$DEVNAME | grep "ID_SERIAL" | cut -d'=' -f2)

# Enhanced error handling: check if required properties are available
if [ -z "$VENDOR_ID" ]; then
  echo "Error: VENDOR_ID not found for device $DEVNAME"
  exit 1
fi
if [ -z "$MODEL_ID" ]; then
  echo "Error: MODEL_ID not found for device $DEVNAME"
  exit 1
fi
if [ -z "$SERIAL" ]; then
  echo "Warning: SERIAL not found for device $DEVNAME. Falling back to MODEL_ID and VENDOR_ID."
  SERIAL="fallback-${VENDOR_ID}-${MODEL_ID}"
fi

# Create a unique name based on vendor, model, and serial
FRIENDLY_NAME="radio-${VENDOR_ID}-${MODEL_ID}-${SERIAL}"

# Write udev rule for tty interface (CAT control device)
echo "# Auto-generated rule for $SERIAL" > "$CUSTOM_RULE"
echo "SUBSYSTEM==\"tty\", ENV{ID_SERIAL}==\"$SERIAL\", SYMLINK+=\"$FRIENDLY_NAME\"" >> "$CUSTOM_RULE"

# Reload udev rules
udevadm control --reload-rules
udevadm trigger
EOF

chmod +x /usr/local/bin/autogen-radio.sh

# Step 4: Create the script for audio devices
echo "Creating the autogen-radio-audio.sh script..."
cat << 'EOF' > /usr/local/bin/autogen-radio-audio.sh
#!/bin/bash

SERIAL="$1"
DEVNAME="$2"
RULES_DIR="/etc/udev/rules.d"
CUSTOM_RULE="$RULES_DIR/10-radio-audio-${SERIAL}.rules"

# Exit if rule already exists
[ -f "$CUSTOM_RULE" ] && exit 0

# Generate a friendly name based on serial number and vendor/product IDs
VENDOR_ID=$(udevadm info --query=property --name=$DEVNAME | grep "ID_VENDOR_ID" | cut -d'=' -f2)
MODEL_ID=$(udevadm info --query=property --name=$DEVNAME | grep "ID_MODEL_ID" | cut -d'=' -f2)
SERIAL=$(udevadm info --query=property --name=$DEVNAME | grep "ID_SERIAL" | cut -d'=' -f2)

# Enhanced error handling: check if required properties are available
if [ -z "$VENDOR_ID" ]; then
  echo "Error: VENDOR_ID not found for device $DEVNAME"
  exit 1
fi
if [ -z "$MODEL_ID" ]; then
  echo "Error: MODEL_ID not found for device $DEVNAME"
  exit 1
fi
if [ -z "$SERIAL" ]; then
  echo "Warning: SERIAL not found for device $DEVNAME. Falling back to MODEL_ID and VENDOR_ID."
  SERIAL="fallback-${VENDOR_ID}-${MODEL_ID}"
fi

# Create a unique name based on vendor, model, and serial
FRIENDLY_NAME="audio-${VENDOR_ID}-${MODEL_ID}-${SERIAL}"

# Write udev rule for audio interface
echo "# Auto-generated rule for audio $SERIAL" > "$CUSTOM_RULE"
echo "SUBSYSTEM==\"sound\", ENV{ID_SERIAL}==\"$SERIAL\", SYMLINK+=\"$FRIENDLY_NAME\"" >> "$CUSTOM_RULE"

# Reload udev rules
udevadm control --reload-rules
udevadm trigger
EOF

chmod +x /usr/local/bin/autogen-radio-audio.sh

# Step 5: Create udev rules for triggering the scripts
echo "Creating udev rules to trigger the scripts..."

# udev rule for serial devices (first time)
cat << 'EOF' > /etc/udev/rules.d/98-autogen-radio.rules
SUBSYSTEM=="tty", ACTION=="add", ENV{ID_SERIAL}!="", RUN+="/usr/local/bin/autogen-radio.sh $env{ID_SERIAL} $env{DEVNAME}"
EOF

# udev rule for audio devices (first time)
cat << 'EOF' > /etc/udev/rules.d/97-autogen-radio-audio.rules
SUBSYSTEM=="sound", ACTION=="add", ENV{ID_SERIAL}!="", RUN+="/usr/local/bin/autogen-radio-audio.sh $env{ID_SERIAL} $env{DEVNAME}"
EOF

# Step 6: Reload udev rules and trigger them
echo "Reloading udev rules and triggering..."
udevadm control --reload-rules
udevadm trigger

echo "Setup complete! Devices should now create persistent symlinks based on vendor, model, and serial information."
echo "You can now use these symlinks for your applications (e.g., WSJT-X, FLDigi, etc.)."
