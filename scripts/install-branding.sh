#!/bin/bash
#
# Author     : Anthony Woodward
# Date       : 23 February 2025
# Updated    : 23 February 2025
# Purpose    : Install branding


#Install branding
echo "Installing branding..."

cp ~/ham-scripts-os/logo/ham-scripts_tth_logo.png /usr/share/backgrounds/
cp ~/ham-scripts-os/logo/ham-scripts_tth_logo.png /usr/share/backgrounds/warty-final-ubuntu.png

gsettings set org.gnome.desktop.background picture-uri file:////usr/share/backgrounds/ham-scripts_tth_logo.png

echo "Branding installed"
