#!/bin/bash
set -euo pipefail

VERSION="${1:-0.1.0}"
BUILD_DIR="$(pwd)/.build-app"
APP_NAME="Beads"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
SIGN_TOOL="Beads/.build/artifacts/sparkle/Sparkle/bin/sign_update"
SIGN_IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Bailey Wickham (Q9D9H424KQ)}"

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

# Embed Sparkle.framework
SPARKLE_FRAMEWORK="Beads/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
mkdir -p "${APP_BUNDLE}/Contents/Frameworks"
cp -R "${SPARKLE_FRAMEWORK}" "${APP_BUNDLE}/Contents/Frameworks/"

# Fix rpath so the binary finds Sparkle.framework in Contents/Frameworks/
install_name_tool -add_rpath @executable_path/../Frameworks "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Code sign (inside-out: nested bundles first, then framework, then app)
codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" \
    "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc"
codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" \
    "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"
codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" \
    "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" \
    "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework"
codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" \
    "${APP_BUNDLE}"

echo "==> App bundle created at ${APP_BUNDLE}"

# Create DMG with Applications symlink for drag-to-install
DMG_NAME="${APP_NAME}-${VERSION}-macOS.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
DMG_TEMP="${BUILD_DIR}/${APP_NAME}-temp.dmg"

echo "==> Creating DMG..."
rm -f "${DMG_TEMP}" "${DMG_PATH}"

# Create a writable DMG, mount it, copy app + symlink, then convert to compressed
hdiutil detach "/Volumes/${APP_NAME}" 2>/dev/null || true
hdiutil create -size 50m -fs HFS+ -volname "${APP_NAME}" "${DMG_TEMP}"
hdiutil attach "${DMG_TEMP}" -nobrowse -mountpoint "/Volumes/${APP_NAME}"
cp -R "${APP_BUNDLE}" "/Volumes/${APP_NAME}/"
ln -s /Applications "/Volumes/${APP_NAME}/Applications"
hdiutil detach "/Volumes/${APP_NAME}"
hdiutil convert "${DMG_TEMP}" -format UDZO -o "${DMG_PATH}"
rm -f "${DMG_TEMP}"

echo "==> DMG created at ${DMG_PATH}"

# Create zip for GitHub release (Sparkle updates use this)
# Use ditto to preserve macOS metadata required for notarization
ZIP_NAME="${APP_NAME}-${VERSION}-macOS.zip"
ZIP_PATH="${BUILD_DIR}/${ZIP_NAME}"
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

echo "==> Zip created at ${ZIP_PATH}"

# Notarize the DMG
if [ -n "${NOTARY_PASSWORD:-}" ]; then
    echo "==> Notarizing DMG..."
    xcrun notarytool submit "${DMG_PATH}" \
        --apple-id "${APPLE_ID}" \
        --team-id "${APPLE_TEAM_ID}" \
        --password "${NOTARY_PASSWORD}" \
        --wait
    xcrun stapler staple "${DMG_PATH}"
    echo "==> DMG notarized and stapled"

    echo "==> Notarizing zip..."
    xcrun notarytool submit "${ZIP_PATH}" \
        --apple-id "${APPLE_ID}" \
        --team-id "${APPLE_TEAM_ID}" \
        --password "${NOTARY_PASSWORD}" \
        --wait
    # Note: stapler cannot staple zip files, only .app/.dmg/.pkg
    echo "==> Zip notarized"
else
    echo "==> NOTARY_PASSWORD not set, skipping notarization"
fi

# Sign zip for Sparkle auto-updates
if [ -n "${SPARKLE_SIGNING_KEY:-}" ]; then
    echo "==> Signing zip for Sparkle updates..."
    SIGNATURE=$(echo "${SPARKLE_SIGNING_KEY}" | "${SIGN_TOOL}" --ed-key-file - -p "${ZIP_PATH}")
    ZIP_SIZE=$(wc -c < "${ZIP_PATH}" | tr -d ' ')
    echo "==> Sparkle signature: ${SIGNATURE}"
    echo "==> Zip size: ${ZIP_SIZE}"

    # Generate appcast item XML
    PUB_DATE=$(date -R)
    APPCAST_ITEM="${BUILD_DIR}/appcast-item.xml"
    cat > "${APPCAST_ITEM}" <<XMLEOF
        <item>
            <title>Version ${VERSION}</title>
            <sparkle:version>${VERSION}</sparkle:version>
            <pubDate>${PUB_DATE}</pubDate>
            <enclosure url="https://github.com/baileywickham/beads-ui/releases/download/v${VERSION}/${ZIP_NAME}" length="${ZIP_SIZE}" type="application/octet-stream" sparkle:edSignature="${SIGNATURE}" />
            <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
        </item>
XMLEOF
    echo "==> Appcast item written to ${APPCAST_ITEM}"
else
    echo "==> SPARKLE_SIGNING_KEY not set, skipping Sparkle signing"
fi

echo "==> Done!"
