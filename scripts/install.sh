#!/usr/bin/env bash
#
# Author     : Anthony Woodward
# Date       : 19 February 2025
# Updated    : 21 February 2025
# Purpose    : Create master install command

sudo -u $SUDO_USER ./install-branding.sh

./functions.sh

exitIfNotRoot

sudo -u $SUDO_USER ./install-js8call.sh
sudo -u $SUDO_USER ./install-wine.sh
./install-wsjtx.sh
./install-js8spotter.sh

cp ~/ham-scripts-os/scripts/post-install-steps.txt ~/Desktop

dialog ==textbox post-install-steps.txt 115 74