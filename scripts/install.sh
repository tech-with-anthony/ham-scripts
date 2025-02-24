#!/bin/bash
#
# Author     : Anthony Woodward
# Date       : 19 February 2025
# Updated    : 21 February 2025
# Purpose    : Create master install command

sudo -u $SUDO_USER ./install-branding.sh

./functions.sh

exitIfNotRoot

sudo -u $SUDO_USER ./install-wine.sh
sudo -u $SUDO_USER ./install-vara-hf.sh
sudo -u $SUDO_USER ./install-vara-fm.sh
sudo -u $SUDO_USER ./install-varac.sh
sudo -u $SUDO_USER ./install-winlink.sh
./install-wsjtx.sh
./install-js8spotter.sh

dialog ==textbox post-install-steps.txt 115 74

cp ~/ham-scripts-os/scripts/post-install-steps.txt ~/Desktop