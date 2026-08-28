#!/bin/bash
# Build a distributable ScanQR.app: Developer ID signed, hardened runtime,
# notarized by Apple, and stapled. Output in .release/.
#
# One-time setup (stores Apple ID + app-specific password in Keychain):
#   xcrun notarytool store-credentials scanqr-notary \
#       --apple-id changyong_liu_cn@hotmail.com \
#       --team-id 5768V787GP \
#       --password <APP_SPECIFIC_PASSWORD_FROM_APPLEID.APPLE.COM>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

SIGN_IDENTITY="Developer ID Application: CHANGYONG LIU (5768V787GP)"
KEYCHAIN_PROFILE="scanqr-notary"
APP_NAME="ScanQR"
BUILD_DIR=".release"
APP="$BUILD_DIR/$APP_NAME.app"
ZIP="$BUILD_DIR/$APP_NAME.zip"
DMG="$BUILD_DIR/$APP_NAME.dmg"
DMG_STAGING="$BUILD_DIR/dmg-staging"

echo "==> Compiling (reusing build.sh)"
./build.sh > /dev/null

echo "==> Staging bundle in $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cp -R ".build/$APP_NAME.app" "$APP"

echo "==> Re-signing with Developer ID + hardened runtime + secure timestamp"
codesign --force --sign "$SIGN_IDENTITY" \
    --entitlements ScanQR/Resources/ScanQR.entitlements \
    --options runtime \
    --timestamp \
    "$APP"

echo "==> Verifying signature"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Zipping for notary submission"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Submitting to Apple Notary Service (this can take a few minutes)"
xcrun notarytool submit "$ZIP" --keychain-profile "$KEYCHAIN_PROFILE" --wait

echo "==> Stapling notarization ticket into the bundle"
xcrun stapler staple "$APP"

echo "==> Gatekeeper assessment"
spctl --assess --verbose=4 --type execute "$APP"

echo "==> Rebuilding final distributable zip with stapled bundle"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Staging DMG contents (app + /Applications alias)"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

echo "==> Creating compressed DMG"
rm -f "$DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG"

echo "==> Signing DMG"
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG"

echo "==> Notarizing DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$KEYCHAIN_PROFILE" --wait

echo "==> Stapling DMG"
xcrun stapler staple "$DMG"

echo "==> Final Gatekeeper assessment on DMG"
spctl --assess --verbose=4 --type open --context context:primary-signature "$DMG"

rm -rf "$DMG_STAGING"

echo ""
echo "Done."
echo "  App: $APP"
echo "  Zip: $ZIP  (for updaters / CI)"
echo "  DMG: $DMG  (share this — double-click, drag to Applications)"
