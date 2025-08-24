#!/usr/bin/env bash
#
# Author     : Anthony Woodward
# Date       : 23 February 2025
# Updated    : 23 February 2025
# Purpose    : Global functions for install scripts

function exitIfNotRoot() {
  if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    echo "Try running: sudo ./$(basename $0)"
    exit
  fi
}
