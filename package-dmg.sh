#!/bin/bash
# Build a shareable ScanQR.dmg that installs on any Mac WITHOUT an Apple ID,
# without notarization, and without an Apple Developer account on the
# receiving machine. Output: .dist/ScanQR.dmg
#
# Signing: uses a local "Developer ID Application" certificate if one exists
# (stable code identity => camera permission survives updates), otherwise
# falls back to ad-hoc signing. Either way the DMG is NOT notarized, so the
# first launch on another Mac needs the one-time Gatekeeper step described in
# the INSTALL.txt that ships inside the DMG.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP_NAME="ScanQR"
VOL_NAME="ScanQR"
DIST_DIR=".dist"
APP="$DIST_DIR/$APP_NAME.app"
DMG="$DIST_DIR/$APP_NAME.dmg"
STAGING="$DIST_DIR/dmg-staging"

echo "==> Building universal app (build.sh)"
./build.sh > /dev/null

echo "==> Staging in $DIST_DIR"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
cp -R ".build/$APP_NAME.app" "$APP"

SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)"

if [ -n "$SIGN_IDENTITY" ]; then
    echo "==> Signing with: $SIGN_IDENTITY"
    codesign --force --deep --sign "$SIGN_IDENTITY" \
        --entitlements ScanQR/Resources/ScanQR.entitlements \
        --timestamp \
        "$APP"
else
    echo "==> No Developer ID certificate found — ad-hoc signing"
    SIGN_IDENTITY="-"
    codesign --force --deep --sign - \
        --entitlements ScanQR/Resources/ScanQR.entitlements \
        "$APP"
fi

echo "==> Verifying signature"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Assembling DMG contents"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

cat > "$STAGING/INSTALL.txt" <<'TXT'
ScanQR — installation
=====================

1. Drag ScanQR.app onto the Applications folder in this window.

2. First launch only: this build is not notarized by Apple, so macOS
   blocks it once.

   macOS 15 Sequoia and newer (incl. macOS 26):
     - Double-click ScanQR in Applications. macOS says it "cannot be
       opened" / "Apple could not verify" — click Done.
     - Open  System Settings > Privacy & Security , scroll to the
       Security section, and click "Open Anyway" next to ScanQR.
     - Confirm with "Open Anyway" and authenticate.

   macOS 14 and older:
     - Right-click (or Control-click) ScanQR in Applications, choose
       Open, then click Open in the dialog.

   Terminal alternative (any version, one command):
     xattr -dr com.apple.quarantine /Applications/ScanQR.app

3. Allow camera access when prompted — it is only used to read QR codes.

No Apple ID and no Apple Developer account are required.


ScanQR — 安装说明
=================

1. 把 ScanQR.app 拖到本窗口中的 Applications 文件夹。

2. 首次运行：该版本未经 Apple 公证，系统会拦截一次。

   macOS 15 及以上（含 macOS 26）：
     - 双击 ScanQR，提示无法打开时点“完成”。
     - 打开“系统设置 > 隐私与安全性”，在“安全性”一栏点击 ScanQR 旁边的
       “仍要打开”，再次确认并输入密码。

   macOS 14 及以下：
     - 在 Applications 里右键点击 ScanQR，选择“打开”，再点“打开”。

   终端命令（任意版本，一条命令搞定）：
     xattr -dr com.apple.quarantine /Applications/ScanQR.app

3. 首次扫码时允许使用摄像头，仅用于识别二维码。

无需 Apple ID，也无需 Apple 开发者账号。
TXT

echo "==> Stripping extended attributes from staging"
xattr -cr "$STAGING"

echo "==> Creating compressed DMG"
rm -f "$DMG"
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGING" \
    -fs HFS+ \
    -ov -format UDZO \
    "$DMG" > /dev/null

if [ "$SIGN_IDENTITY" != "-" ]; then
    echo "==> Signing DMG"
    codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG"
fi

rm -rf "$STAGING"
xattr -cr "$DMG"

echo ""
echo "Done."
echo "  App: $APP"
echo "  DMG: $DMG"
echo ""
echo "Share the DMG. On the other Mac: open it, drag ScanQR to Applications,"
echo "then follow INSTALL.txt for the one-time Gatekeeper approval."
