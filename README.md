# Ham-Scripts

A collection of user-level installer scripts for common ham-radio apps on Linux (Ubuntu/Debian family). The goal is: download → run → get on the air, with sensible desktop integration (app icons, .desktop entries, and GNOME taskbar pinning).

If you hit a snag, please open an Issue describing your distro/version, desktop environment, and the exact error text.

Supported & tested

Ubuntu 24.04 (GNOME Shell)

Debian 12 (GNOME recommended)

# Prerequisites

Before you install anything (manual prerequisites)

Run these once on a fresh system to avoid most “missing package” errors.

1) Base tools
```sudo apt update
sudo apt install -y curl git wget unzip desktop-file-utils xdg-utils jq
```

2) GNOME settings tooling (for pinning / wallpaper; safe to install on Ubuntu GNOME)
```
sudo apt install -y gsettings-desktop-schemas
```

3) Deb installer helpers (lets apt resolve .deb dependencies cleanly)
```
sudo apt install -y gdebi-core
```
4) JS8Spotter’s Linux Python deps (Tk & Pillow’s ImageTk)
```
sudo apt install -y python3 python3-tk python3-pil python3-pil.imagetk sqlite3 tcl tk python3-tk
```
Why #4? Per the JS8Spotter manual, Linux users need Python 3 with Tkinter + Pillow ImageTk to run the program; JS8Spotter talks to a running JS8Call instance over TCP and isn’t a standalone modem. 
[kf7mix.com](https://kf7mix.com/files/js8spotter/JS8Spotter_Manual_v0.7.pdf?utm_source=chatgpt.com)

# Installation

To install:

-Go to releases

-Select the latest release

-copy the ```tar.gz``` file url

-In a Linux terminal run 
```
wget (copied url)
```
-enter
```
tar -xzf ham-scripts-(version number).tar.gz
```
-enter
```
cd ham-scripts/scripts
```
-Finally, enter 
```
./install.sh
``` 

# Contributing

PRs are welcome—add new installers, improve detection, or extend desktop integration. Please keep scripts:

Idempotent (safe to re-run)

Non-interactive (use flags and sane defaults)

Well-logged (echo what you’re doing)
