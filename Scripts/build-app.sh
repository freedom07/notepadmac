#!/bin/bash
set -e

# Build configuration (default: debug)
CONFIG="${1:-debug}"
BUILD_FLAGS=""
if [ "$CONFIG" = "release" ]; then
    BUILD_FLAGS="-c release"
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/.build/$CONFIG"
SWIFT_TARGET="NotepadNext"
APP_NAME="NotepadMac"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building $APP_NAME ($CONFIG)..."
swift build $BUILD_FLAGS

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy executable (Swift target name → app display name)
cp "$BUILD_DIR/$SWIFT_TARGET" "$MACOS/$APP_NAME"

# Read version from Version.swift
APP_VERSION=$(bash "$PROJECT_ROOT/Scripts/version.sh" get)

# Create Info.plist
sed "s/\${APP_VERSION}/$APP_VERSION/g" > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>NotepadMac</string>
    <key>CFBundleDisplayName</key>
    <string>NotepadMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.notepadmac.app</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>NotepadMac</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Text Document</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Default</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.plain-text</string>
                <string>public.source-code</string>
                <string>public.script</string>
                <string>public.shell-script</string>
                <string>public.python-script</string>
                <string>public.ruby-script</string>
                <string>public.xml</string>
                <string>public.json</string>
                <string>public.yaml</string>
                <string>com.netscape.javascript-source</string>
                <string>public.css</string>
                <string>public.html</string>
            </array>
        </dict>
    </array>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>NotepadMac needs access to send Apple Events.</string>
</dict>
</plist>
PLIST

# Copy resources if they exist
if [ -d "$PROJECT_ROOT/Resources" ]; then
    cp -R "$PROJECT_ROOT/Resources/"* "$RESOURCES/" 2>/dev/null || true
fi

# Copy app icon
if [ -f "$PROJECT_ROOT/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
    echo "Using custom app icon"
else
    echo "Warning: No AppIcon.icns found in Resources/"
fi

echo ""
echo "✅ $APP_BUNDLE created successfully!"
echo ""
echo "Run with:"
echo "  open $APP_BUNDLE"
