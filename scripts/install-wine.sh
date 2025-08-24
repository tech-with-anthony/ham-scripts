#!/usr/bin/env bash
#
# Author     : Anthony Woodward
# Date       : 23 February 2025
# Updated    : 23 February 2025
# Purpose    : Install Wine and Winetricks

cd

#Update sources
echo "Updating sources..."
sudo apt update

#Install wine
echo "Installing wine..."

# Check for an existing i386 architecture
ARCH_OUT=$(dpkg --print-foreign-architectures | grep i386)
[ $? -ne 0 ] && dpkg --add-architecture i386

#if [ ! -e "/etc/apt/keyrings/winehq-archive.key" ]; then
#  echo "Adding apt keys for official wine repo"
#  mkdir -pm755 /etc/apt/keyrings
#  wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
#  wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/$(lsb_release -sc)/winehq-$(lsb_release -sc).sources
#  apt update
# apt install --install-recommends winehq-stable
#fi

apt install \
  wine \
  winetricks \
  exe-thumbnailer \
  -y

dialog --textbox wine.txt 15 74
tput sgr 0 && clear


#Install Winetricks
#echo "Installing winetricks..."
#cd ${HOME}/Downloads
#wget  https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
#chmod +x winetricks
#sudo mv winetricks /usr/local/bin/


#Install some tricks
#echo "Installing some tricks..."
#should see mono install after running next command
#WINEARCH=win32 WINEPREFIX=$HOME/.wine/ winetricks -q vb6run
#vcrun20215 probably already installed
#WINEARCH=win32 WINEPREFIX=$HOME/.wine/ winetricks -q vcrun2015
#dotnet461 takes a LONG time to install
#WINEARCH=win32 WINEPREFIX=$HOME/.wine/ winetricks -q dotnet461
#WINEARCH=win32 WINEPREFIX=$HOME/.wine/ winetricks sound=alsa

cd ~/vara-scripts/scripts