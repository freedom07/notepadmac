#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="NotepadMac"
VERSION=$(bash "$PROJECT_ROOT/Scripts/version.sh" get)

# Build release app bundle first
echo "=== Building release app bundle ==="
"$PROJECT_ROOT/Scripts/build-app.sh" release

BUILD_DIR="$PROJECT_ROOT/.build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: App bundle not found at $APP_BUNDLE"
    exit 1
fi

echo ""
echo "=== Creating DMG ==="

DMG_NAME="${APP_NAME}-${VERSION}"
DMG_DIR="$BUILD_DIR/dmg"
DMG_PATH="$BUILD_DIR/${DMG_NAME}.dmg"

# Clean up previous DMG artifacts
rm -rf "$DMG_DIR"
rm -f "$DMG_PATH"

# Create DMG staging directory
mkdir -p "$DMG_DIR"
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create Applications symlink for drag-and-drop install
ln -s /Applications "$DMG_DIR/Applications"

# Create a background instructions file
cat > "$DMG_DIR/.background_info" << 'EOF'
Drag NotepadMac to Applications to install.
EOF

# Create DMG using hdiutil
echo "Packaging DMG..."
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

rm -rf "$DMG_DIR"

echo ""
echo "=== Done ==="
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo "DMG created: $DMG_PATH"
echo "Size: $DMG_SIZE"
echo ""
echo "To test: open $DMG_PATH"
