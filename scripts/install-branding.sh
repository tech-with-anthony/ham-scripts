#!/usr/bin/env bash
#
# Author  : Anthony Woodward
# Date    : 25 August 2025
# Updated : 25 August 2025
# Purpose : Install branding assets (if any)
set -euo pipefail
. "$(dirname "$0")/env.sh"

# Copy any branding assets you keep in repo/branding/ → ~/.local/share/ham-scripts
SRC_DIR="$REPO_ROOT/branding"
DEST_DIR="$DATA_DIR/ham-scripts"

mkdir -p "$DEST_DIR"
if [ -d "$SRC_DIR" ]; then
  cp -r "$SRC_DIR"/. "$DEST_DIR"/ 2>/dev/null || true
  echo "Branding copied to: $DEST_DIR"
else
  echo "No branding/ directory present; skipping."
fi
