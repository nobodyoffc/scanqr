# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Build & test

Two build paths exist — keep them in sync when adding files.

**Xcode (primary):**
```bash
xcodebuild -project ScanQR.xcodeproj -scheme ScanQR -configuration Release \
           -destination 'platform=macOS' build
xcodebuild -project ScanQR.xcodeproj -scheme ScanQR \
           -destination 'platform=macOS' test         # runs ScanQRTests
```
Single test: add `-only-testing:ScanQRTests/QRGeneratorTests/testSplitByUTF8Bytes` etc. `swift test` is **not** supported (Xcode project, not SPM).

**Command-Line-Tools-only (`./build.sh`):** compiles `arm64` + `x86_64` with `swiftc`, lipos them, assembles `.app`, and ad-hoc signs with entitlements. Output: `.build/ScanQR.app`. **New `.swift` files under `ScanQR/` must be added to the `SRCS=(...)` array in `build.sh`** in addition to the Xcode project — otherwise the script-built binary silently omits them.

## Architecture

SwiftUI + MVVM with a single `@MainActor` view model (`QrViewModel`) wiring stateless service enums. macOS 13+, universal binary, App Sandbox enabled.

- **`App/`** — `ScanQRApp` (@main) owns `QrViewModel`, routes `scanqr://return[?callback=…]` URLs via `onOpenURL` → `vm.applyReturnMode`. `AppDelegate.applicationWillTerminate` calls `vm.handleWindowClose()` to deliver the pending return result before quit.
- **`ViewModels/QrViewModel`** — the only stateful component. Owns `CameraScanner`, exposes `@Published text/segments/isScanning/toast/returnMode`. Scanner's `onDetect` callback appends decoded text and auto-stops (re-scan to append more).
- **`Services/`** — stateless `enum`s (`QRGenerator`, `QRImageDecoder`, `QRFileSaver`, `ReturnModeResolver`, `Clipboard`, `L10n`) + one class (`CameraScanner`). Services never reach back into the view model; view model calls services and publishes results.
- **`Models/`** — `QrSegment` (one generated page), `AffairHandler` protocol + `NoopAffairHandler` stub.
- **`Views/`** — `ContentView` root; `ScannerView` hosts `AVCaptureVideoPreviewLayer` via NSViewRepresentable; `QRPagerView` paginates segments with chevrons + `i/n` label (not `.page` style — unavailable on macOS 13).

### Two cross-cutting contracts worth knowing before editing

1. **Wire-format compatibility with the Android `QrCodeActivity` generator.** Content >300 UTF-8 bytes splits into multiple QRs; the decoder just concatenates. `QRGenerator.defaultCapacity = 300`, `splitByUTF8Bytes` preserves multibyte boundaries, `inputCorrectionLevel = "M"`, target ≥461 px. Changing any of these breaks Android↔Mac interop — see `MIGRATION.md` for the full Android→Swift method map.

2. **Return-string mode** (`scanqr://return?callback=…`): `ReturnModeResolver.deliver` writes `~/Library/Caches/ScanQR/last_result.txt` (sandbox container path), appends `qr_content=<url-encoded>` to the callback URL and opens it via `NSWorkspace`, prints the content + newline to stdout, then the VM terminates the app. Window-close also triggers delivery via `handleWindowClose`. The "Copy" button re-labels to "Return" in this mode.

### Camera flow

`toggleScanning()` → `CameraScanner.requestAccess()` (async wraps `AVCaptureDevice.authorizationStatus`) → `scanner.setup()` builds `AVCaptureSession` + `AVCaptureMetadataOutput` filtered to `.qr` → `scanner.start()` on a bg queue. **No ZXing, no YUV→RGB** — `AVCaptureMetadataOutput` delivers decoded strings directly. Gallery path uses `CIDetector(ofType: CIDetectorTypeQRCode)` with high accuracy, NSImage TIFF fallback if `CIImage(contentsOf:)` fails.

## Entitlements & signing

`ScanQR/Resources/ScanQR.entitlements`: sandbox, camera, user-selected files (r/o + r/w), pictures r/w (for silent save to `~/Pictures/ScanQR/`). Project defaults to **ad-hoc signing** (`CODE_SIGN_IDENTITY = "-"`) so it builds with no Apple Developer account. `Info.plist` needs `NSCameraUsageDescription`; URL scheme `scanqr` is registered in `CFBundleURLTypes`.

## Affair JSON extension point

`AffairHandler` protocol (`canHandle(String) -> Bool`, `handle(String)`). Default `NoopAffairHandler` substring-matches `"n":"affair"` and logs. Real behavior plugs in via `QrViewModel(affairHandler: …)` — the protocol exists to keep FC-AJDK out of this module.
