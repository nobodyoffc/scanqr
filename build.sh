#!/bin/bash
# Build ScanQR.app without Xcode — Command Line Tools only.
# Produces a universal (arm64 + x86_64) ad-hoc signed .app in .build/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP_NAME="ScanQR"
BUNDLE_ID="com.scanqr.app"
DEPLOYMENT="13.0"
BUILD_DIR=".build"
APP="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

SDK="$(xcrun --sdk macosx --show-sdk-path)"

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS" "$RES/en.lproj"

SRCS=(
    ScanQR/App/ScanQRApp.swift
    ScanQR/App/AppDelegate.swift
    ScanQR/Views/ContentView.swift
    ScanQR/Views/ScannerView.swift
    ScanQR/Views/QRPagerView.swift
    ScanQR/Views/ToastView.swift
    ScanQR/ViewModels/QrViewModel.swift
    ScanQR/Services/CameraScanner.swift
    ScanQR/Services/QRGenerator.swift
    ScanQR/Services/QRImageDecoder.swift
    ScanQR/Services/Clipboard.swift
    ScanQR/Services/QRFileSaver.swift
    ScanQR/Services/ReturnMode.swift
    ScanQR/Services/Localization.swift
    ScanQR/Models/AffairStub.swift
    ScanQR/Models/QrSegment.swift
)

echo "==> Compiling arm64"
swiftc -O -swift-version 5 -module-name "$APP_NAME" \
    -target "arm64-apple-macosx$DEPLOYMENT" \
    -sdk "$SDK" \
    -o "$BUILD_DIR/$APP_NAME-arm64" \
    "${SRCS[@]}"

echo "==> Compiling x86_64"
swiftc -O -swift-version 5 -module-name "$APP_NAME" \
    -target "x86_64-apple-macosx$DEPLOYMENT" \
    -sdk "$SDK" \
    -o "$BUILD_DIR/$APP_NAME-x86_64" \
    "${SRCS[@]}"

echo "==> Creating universal binary"
lipo -create \
    "$BUILD_DIR/$APP_NAME-arm64" \
    "$BUILD_DIR/$APP_NAME-x86_64" \
    -output "$MACOS/$APP_NAME"
chmod +x "$MACOS/$APP_NAME"

echo "==> Assembling Info.plist"
sed -e "s|\$(EXECUTABLE_NAME)|$APP_NAME|g" \
    -e "s|\$(PRODUCT_BUNDLE_IDENTIFIER)|$BUNDLE_ID|g" \
    -e "s|\$(PRODUCT_NAME)|$APP_NAME|g" \
    -e "s|\$(MACOSX_DEPLOYMENT_TARGET)|$DEPLOYMENT|g" \
    ScanQR/Resources/Info.plist > "$CONTENTS/Info.plist"

echo "==> Copying resources"
cp ScanQR/Resources/en.lproj/Localizable.strings "$RES/en.lproj/"
cp ScanQR/Resources/AppIcon.icns "$RES/"

echo "==> Stripping extended attributes"
xattr -cr "$APP"

echo "==> Ad-hoc codesigning with entitlements"
codesign --force --sign - \
    --entitlements ScanQR/Resources/ScanQR.entitlements \
    "$APP"

echo ""
echo "Built: $APP"
echo "Run with:  open \"$APP\""
