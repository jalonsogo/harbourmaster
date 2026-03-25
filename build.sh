#!/usr/bin/env bash
# build.sh
# Builds HarbourMaster in release mode and assembles a proper .app bundle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="HarbourMaster"
BUNDLE_DIR="$SCRIPT_DIR/${APP_NAME}.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Building ${APP_NAME} (release)…"
swift build -c release 2>&1

# Locate the compiled binary (works for both Intel and Apple Silicon)
BINARY="$(swift build -c release --show-bin-path 2>/dev/null)/${APP_NAME}"

if [[ ! -f "$BINARY" ]]; then
    echo "ERROR: Binary not found at $BINARY" >&2
    exit 1
fi

echo "==> Assembling ${APP_NAME}.app bundle…"

# Clean any previous bundle
rm -rf "$BUNDLE_DIR"

# Create directory structure
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary
cp "$BINARY" "$MACOS_DIR/${APP_NAME}"

# Copy Info.plist
cp "$SCRIPT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

# Create PkgInfo (required by macOS for .app bundles)
printf "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo ""
echo "✓  Built:  ${BUNDLE_DIR}"
echo ""
echo "To run:    open '${BUNDLE_DIR}'"
echo "To install: ./install.sh"
