#!/usr/bin/env bash
# install.sh
# Copies HarbourMaster.app to /Applications (builds first if needed).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$SCRIPT_DIR/HarbourMaster.app"

# Build if the bundle doesn't exist yet
if [[ ! -d "$BUNDLE_DIR" ]]; then
    echo "==> Bundle not found — building first…"
    bash "$SCRIPT_DIR/build.sh"
fi

DEST="/Applications/HarbourMaster.app"

echo "==> Installing to ${DEST}…"

# Remove previous installation if present
if [[ -d "$DEST" ]]; then
    echo "    Removing existing installation…"
    rm -rf "$DEST"
fi

cp -R "$BUNDLE_DIR" "$DEST"

echo ""
echo "✓  Installed: ${DEST}"
echo ""
echo "You can now launch HarbourMaster from /Applications"
echo "or run:  open '/Applications/HarbourMaster.app'"
