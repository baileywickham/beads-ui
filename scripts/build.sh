#!/bin/bash
set -euo pipefail

VERSION="${1:-0.1.0}"
BUILD_DIR="$(pwd)/.build-app"
APP_NAME="Beads"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "==> Building ${APP_NAME} v${VERSION}..."

# Clean
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Build release binary
cd Beads
swift build -c release
cd ..

# Create app bundle structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "Beads/.build/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist with version injected
sed "s/0.1.0/${VERSION}/g" Beads/Beads/Info.plist > "${APP_BUNDLE}/Contents/Info.plist"

# Copy resources if they exist
if [ -d "Beads/Beads/Assets.xcassets" ]; then
    cp -r Beads/Beads/Assets.xcassets "${APP_BUNDLE}/Contents/Resources/" 2>/dev/null || true
fi

# Ad-hoc sign (allows running without developer certificate)
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> App bundle created at ${APP_BUNDLE}"

# Create DMG
DMG_NAME="${APP_NAME}-${VERSION}-macOS.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"

echo "==> Creating DMG..."
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${APP_BUNDLE}" \
    -ov -format UDZO \
    "${DMG_PATH}"

echo "==> DMG created at ${DMG_PATH}"

# Also create a zip for GitHub release
ZIP_NAME="${APP_NAME}-${VERSION}-macOS.zip"
ZIP_PATH="${BUILD_DIR}/${ZIP_NAME}"
cd "${BUILD_DIR}"
zip -ry "${ZIP_NAME}" "${APP_NAME}.app"
cd ..

echo "==> Zip created at ${ZIP_PATH}"
echo "==> Done!"
