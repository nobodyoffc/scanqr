# ScanQR

A standalone native macOS QR code scanner and generator. No Android, no JVM, no ZXing. Swift + SwiftUI + AVFoundation + Core Image.

This is a port of the Android `QrCodeActivity` (in the Freer project). Wire-format compatible with the Android generator: content over 300 UTF-8 bytes is split into multiple QRs, and the reader just concatenates decoded text in sequence — no framing protocol.

## Requirements

- macOS 13 Ventura or newer (Apple Silicon or Intel; universal binary)
- Xcode 15 or newer
- Swift 5.9+

## Build & Run

```bash
open ScanQR.xcodeproj
```

Then press ⌘R. The default scheme produces a universal `.app` (arm64 + x86_64) in `$(DERIVED_DATA)/Build/Products/Debug/ScanQR.app`.

From CLI (requires full Xcode, not just Command Line Tools):

```bash
xcodebuild -project ScanQR.xcodeproj -scheme ScanQR -configuration Release \
           -destination 'platform=macOS' build
```

## Code signing

The project is configured for **ad-hoc signing** (`CODE_SIGN_IDENTITY = "-"`) so it builds out of the box with no Apple Developer account. To ship:

1. Set `DEVELOPMENT_TEAM` in the `ScanQR` target's build settings to your Team ID.
2. Set `CODE_SIGN_IDENTITY` to `Apple Development` (debug) / `Developer ID Application` (distribution).
3. For notarization, archive → Organizer → Distribute App → Developer ID → upload for notarization.

## Entitlements

`ScanQR/Resources/ScanQR.entitlements`:

| Entitlement | Purpose |
|---|---|
| `com.apple.security.app-sandbox` | App Sandbox |
| `com.apple.security.device.camera` | Live QR scanning |
| `com.apple.security.files.user-selected.read-only` | "Gallery" file picker |
| `com.apple.security.files.user-selected.read-write` | Future file exports |
| `com.apple.security.assets.pictures.read-write` | Silent save to `~/Pictures/ScanQR/` |

## Features

- **Live scan** — AVCaptureMetadataOutput; one-tap toggle; appends decoded string to the text field and stops automatically. Re-scan to append more.
- **Generate** — CIQRCodeGenerator, EC level M, margin as emitted, scaled to ≥461 px with nearest-neighbor. Content over 300 UTF-8 bytes is split into paged QRs; each page shown with a `i/n` indicator.
- **Save** — writes all pages as `QR_<epochMillis>_<index>.png` to `~/Pictures/ScanQR/` silently; in-app toast reports count.
- **Gallery** — NSOpenPanel (PNG, JPEG, HEIC, TIFF, BMP); decoded with `CIDetectorTypeQRCode`.
- **Clear / Copy** — standard, uses `NSPasteboard.general`.
- **Return-string mode** — see below.
- **Affair JSON** — stub via `AffairHandler` protocol; shows a "Do affair" button when the text contains `"n":"affair"`. Wire your handler by injecting into `QrViewModel(affairHandler:)`.

## Return-string mode

Launch ScanQR from another app via URL scheme to get a value back:

```bash
# Fire-and-forget: user scans/types, clicks Return, result goes to stdout +
# ~/Library/Caches/ScanQR/last_result.txt
open "scanqr://return"

# With callback: after Return, ScanQR opens your callback URL with
# ?qr_content=<url-encoded> appended, then quits.
open "scanqr://return?callback=myapp%3A%2F%2Fgot"
```

Behavior:
- In return mode the "Copy" button is replaced by "Return".
- Closing the window with non-empty content also delivers the result (via `applicationWillTerminate`).
- The result is always written to `~/Library/Caches/ScanQR/last_result.txt` (container path under sandbox) and printed to stdout with a trailing newline.
- The callback URL is opened with `NSWorkspace.shared.open`; append-style parameter merging preserves any existing query on your callback.

## Tests

`swift test` is **not** supported (this is an Xcode project, not SPM). Run tests from Xcode (⌘U) or via:

```bash
xcodebuild -project ScanQR.xcodeproj -scheme ScanQR \
           -destination 'platform=macOS' test
```

Test coverage:
- `QRGeneratorTests` — UTF-8-boundary-safe chunking, capacity edge cases, multibyte-codepoint non-split, concatenation invariant.
- `QRImageDecoderTests` — round-trip generate→decode, Unicode payload round-trip, blank-image rejection.

## Project layout

```
ScanQR.xcodeproj/
ScanQR/
├─ App/              ScanQRApp (@main), AppDelegate
├─ Views/            ContentView, ScannerView, QRPagerView, ToastView
├─ ViewModels/       QrViewModel
├─ Services/         CameraScanner, QRGenerator, QRImageDecoder, QRFileSaver,
│                    ReturnMode, Clipboard, Localization
├─ Models/           AffairStub, QrSegment
└─ Resources/        Info.plist, ScanQR.entitlements, Assets.xcassets,
                     en.lproj/Localizable.strings
ScanQRTests/
├─ QRGeneratorTests.swift
└─ QRImageDecoderTests.swift
MIGRATION.md          — mapping from Android QrCodeActivity methods to Swift.
```

See `MIGRATION.md` for a one-to-one map of Android methods to Swift equivalents.
