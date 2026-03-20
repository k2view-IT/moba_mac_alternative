#!/usr/bin/env bash
# build-dmg.sh — MobaAlt Distribution Pipeline
#
# Steps:
#   1. Archive the app with xcodebuild
#   2. Export the archive to an .app bundle
#   3. Create a DMG with create-dmg
#   4. Codesign the DMG with Developer ID
#   5. Notarize the DMG with Apple's notarytool
#   6. Staple the notarization ticket to the DMG
#
# Prerequisites:
#   - Xcode command line tools + full Xcode.app installed
#   - create-dmg installed: brew install create-dmg
#   - Valid Apple Developer ID Application certificate in Keychain
#   - Notarization credentials stored via: xcrun notarytool store-credentials
#
# TODO: Fill in TEAM_ID and KEYCHAIN_PROFILE before running for the first time.

set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────

APP_NAME="MobaAlt"
SCHEME="MobaAlt"
CONFIGURATION="Release"

ARCHIVE_PATH="build/${APP_NAME}.xcarchive"
EXPORT_PATH="build/export"
APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
DMG_PATH="build/${APP_NAME}.dmg"

# TODO: Replace with your Apple Developer Team ID (e.g. "XXXXXXXXXX")
TEAM_ID="REPLACE_WITH_YOUR_TEAM_ID"

# TODO: Replace with the keychain profile name you created with:
#   xcrun notarytool store-credentials --apple-id you@example.com --team-id XXXXXXXXXX
KEYCHAIN_PROFILE="REPLACE_WITH_YOUR_KEYCHAIN_PROFILE"

DEVELOPER_ID="Developer ID Application: REPLACE_WITH_YOUR_NAME (${TEAM_ID})"

# ─── Step 1: Archive ─────────────────────────────────────────────────────────

echo "==> Step 1: Archiving ${APP_NAME}…"
xcodebuild archive \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="${TEAM_ID}"

echo "    Archive complete: ${ARCHIVE_PATH}"

# ─── Step 2: Export Archive ──────────────────────────────────────────────────

echo "==> Step 2: Exporting archive to .app…"
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist ExportOptions.plist

echo "    Export complete: ${APP_PATH}"

# ─── Step 3: Create DMG ──────────────────────────────────────────────────────

echo "==> Step 3: Creating DMG…"
if [ -f "${DMG_PATH}" ]; then
    rm "${DMG_PATH}"
fi

create-dmg \
    --volname "${APP_NAME}" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 150 190 \
    --app-drop-link 450 190 \
    "${DMG_PATH}" \
    "${APP_PATH}"

echo "    DMG created: ${DMG_PATH}"

# ─── Step 4: Sign DMG ────────────────────────────────────────────────────────

echo "==> Step 4: Signing DMG…"
codesign \
    --sign "${DEVELOPER_ID}" \
    --timestamp \
    "${DMG_PATH}"

echo "    DMG signed."

# ─── Step 5: Notarize ────────────────────────────────────────────────────────

echo "==> Step 5: Notarizing (this may take a few minutes)…"
xcrun notarytool submit "${DMG_PATH}" \
    --keychain-profile "${KEYCHAIN_PROFILE}" \
    --wait

echo "    Notarization complete."

# ─── Step 6: Staple ──────────────────────────────────────────────────────────

echo "==> Step 6: Stapling notarization ticket…"
xcrun stapler staple "${DMG_PATH}"

echo ""
echo "Distribution build complete: ${DMG_PATH}"
