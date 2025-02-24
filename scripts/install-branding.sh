#!/bin/bash
#
# Author     : Anthony Woodward
# Date       : 23 February 2025
# Updated    : 23 February 2025
# Purpose    : Install branding


#Install branding
echo "Installing branding..."

cp ~/ham-scripts-os/logo/ham-scripts_tth_logo.png ~/Pictures

dconf write /org/gnome/desktop/background/picture-uri-dark "'file:///~/Pictures/ham-scripts_tth_logo.png'"
dconf write /org/gnome/desktop/background/picture-uri "'file:///~/Pictures/ham-scripts_tth_logo.png'"
gsettings set org.gnome.desktop.background picture-uri 'file:///~/Pictures/ham-scripts_tth_logo.png'
gsettings set org.gnome.desktop.background picture-uri-dark 'file:///~/Pictures/ham-scripts_tth_logo.png'

echo "Branding installed"
