#!/bin/bash
set -e
swift build -c release
echo "Build complete. DMG creation requires Xcode .app bundle."
