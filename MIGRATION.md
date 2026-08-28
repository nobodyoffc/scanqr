# Migration map: `QrCodeActivity.java` → ScanQR (Swift)

One-to-one mapping for reviewers verifying feature parity. Android source: `app/src/main/java/com/fc/freer/qr/QrCodeActivity.java`.

## Lifecycle / setup

| Android | Swift |
|---|---|
| `onCreate` — permission check + `initializeCamera()` with 100ms post-delay | `ContentView.onAppear` → `Task { await vm.toggleScanning() }` is gated on tap; camera is lazily set up the first time the user toggles Scan (`CameraScanner.setup()`), avoiding the Android workaround. |
| `EXTRA_IS_RETURN_STRING` intent extra | URL scheme `scanqr://return?callback=…` parsed by `ReturnModeResolver.parse(_:)`, stored on `QrViewModel.returnMode`. |
| `setStatusBarColor(black)` | N/A — macOS has no status bar. Window chrome follows system appearance. |
| `initializeViews()` + `findViewById` wiring | `ContentView` (SwiftUI) — declarative. |
| `setupButtons()` | Button actions wired directly in `ContentView.buttonsRow`. |
| `setupBackButton()` + `handleBackAction()` | `AppDelegate.applicationWillTerminate` → `vm.handleWindowClose()`. Delivers return result before quit. |
| `OnBackPressedCallback` | Same as above — `handleWindowClose`. |
| `onDestroy` — `cameraProvider.unbindAll()` + executor shutdown | `CameraScanner.stop()` is idempotent; AVCaptureSession is released on vm deinit. |

## Camera

| Android | Swift |
|---|---|
| `REQUIRED_PERMISSIONS` (CAMERA; pre-Q also WRITE_EXTERNAL_STORAGE) | `NSCameraUsageDescription` in `Info.plist`; sandbox entitlements `com.apple.security.device.camera`, `com.apple.security.assets.pictures.read-write`. |
| `allPermissionsGranted()` | `CameraScanner.requestAccess()` (async) wraps `AVCaptureDevice.authorizationStatus` / `requestAccess`. |
| `requestPermissions()` + `onRequestPermissionsResult` | `requestAccess()` returns bool; `permissionDenied` publishes to SwiftUI alert. |
| `showPermissionRationale()` | `.alert(L10n.permissionCameraRationale, isPresented: $vm.permissionDenied)` with "Open System Settings" button that launches `x-apple.systempreferences:…Privacy_Camera`. |
| `initializeCamera()` — `ProcessCameraProvider` | `CameraScanner.setup()` — builds `AVCaptureSession` with `AVCaptureDeviceInput(default: .video)` and `AVCaptureMetadataOutput`. |
| `toggleScanning()` | `QrViewModel.toggleScanning()` (async). |
| `startScanning()` — binds `Preview` + `ImageAnalysis` | `CameraScanner.start()` — session starts on a background queue; `ScannerView` hosts the `AVCaptureVideoPreviewLayer`. |
| `stopScanning()` | `CameraScanner.stop()`. |
| `analyzeImage(ImageProxy)` + `imageProxyToBitmap` + ZXing `MultiFormatReader` | Replaced entirely: `AVCaptureMetadataOutput` delivers decoded `AVMetadataMachineReadableCodeObject`s with `type == .qr` directly. No YUV→RGB, no ZXing. `CameraScanner.isProcessing` guard matches the `isProcessingQRCode` repeat-guard. |

## QR generation

| Android | Swift |
|---|---|
| `generateQRCode()` → `QRCodeGenerator.generateAndShowQRCode` | `QrViewModel.generate()` → `QRGenerator.segments(for:)` → sheet shows `QRPagerView`. |
| `QRCodeGenerator.DEFAULT_CAPACITY = 300` | `QRGenerator.defaultCapacity = 300`. Same semantics. |
| `QRCodeGenerator.splitContent` — UTF-8 byte-safe, grows chunk char-by-char up to 300B | `QRGenerator.splitByUTF8Bytes` — identical algorithm, preserves multibyte boundaries, forces at least one char per chunk. |
| `EncodeHintType.ERROR_CORRECTION = M`, `MARGIN = 2`, `CHARACTER_SET = UTF-8`, 461×461 | `CIQRCodeGenerator` with `inputCorrectionLevel = "M"`, UTF-8 message, upscaled to ≥461 px via `CGAffineTransform(scaleX:y:)` integer factor. Margin is the CI default (includes a quiet zone). |
| `QRPagerAdapter` with ViewPager2 + `i/n` indicator | `QRPagerView` — chevron buttons, `i/n` monospaced label, left/right arrow keyboard shortcuts. (On macOS 13 `.page` style isn't available.) |
| `saveQRCodes(List<Bitmap>)` to MediaStore `DIRECTORY_PICTURES` with `QR_<ms>_<i>.png` | `QRFileSaver.save([QrSegment])` writes to `~/Pictures/ScanQR/QR_<ms>_<i>.png` silently; same filename format. |

## Gallery / file decode

| Android | Swift |
|---|---|
| `openGallery()` → `ACTION_PICK` on MediaStore | `QrViewModel.pickImage()` → `NSOpenPanel` filtered to `png jpeg heic tiff bmp image`. |
| `scanQRFromImage(Uri)` — BitmapFactory + ZXing on RGB_565 pixels | `QRImageDecoder.decode(url:)` — `CIImage(contentsOf:)` + `CIDetector(ofType: CIDetectorTypeQRCode)` with `CIDetectorAccuracyHigh`. Falls back to `NSImage`-loaded tiff bytes if CIImage-from-URL fails. |
| Append decoded text to field | Same: `text += decoded`. |
| Toast on open/decode failure | `showToast(L10n.cannotOpenImage / cannotDecodeImage)`. |

## Text field utilities

| Android | Swift |
|---|---|
| `clearButton` → `qrContentEditText.setText("")` | `QrViewModel.clear()` — also drops generated segments. |
| `copyButton` — `copyToClipboard()` / `returnResult()` depending on `isReturnString` | `QrViewModel.copyOrReturn()` — same branch. |
| `returnResult()` — `setResult(RESULT_OK, intent{qr_content, request_code}); finish()` | `ReturnModeResolver.deliver(content:callback:)` — writes `~/Library/Caches/ScanQR/last_result.txt`, appends `qr_content=…` to the callback URL and opens it, prints to stdout, then `NSApp.terminate(nil)`. |
| `rootLayout.setOnClickListener { clearFocus + hide IME }` | `ZStack` background `.onTapGesture { textFocused = false }`. |
| `TextWatcher.afterTextChanged { if hasFocus stopScanning() }` | `.onChange(of: textFocused)` in `ContentView.textArea` — focus-in during scan stops the camera. |
| `TextWatcher.afterTextChanged { updateDoButtonVisibility() }` | `vm.affairAvailable` computed from `affairHandler.canHandle(text)`, reactive to `@Published text`. |

## Affair JSON side button

| Android | Swift |
|---|---|
| `isValidAffairJson(content)` — quick `"n":"affair"` check then `FcEntity.fromJson(Affair.class)` | `NoopAffairHandler.canHandle(_:)` — substring check only. The full parse would pull in FC-AJDK; kept behind `AffairHandler` protocol. |
| `launchDoAffairActivity()` — Intent to `DoAffairActivity` | `NoopAffairHandler.handle(_:)` — logs only. Inject a custom handler into `QrViewModel(affairHandler:)` to plug in real behavior. |

## Localized strings (Android key → Localizable.strings key, identical)

`menu_qr_code`, `copied_to_clipboard`, `error_creating_qr`, `error_saving_qr`, `qr_saved_count`, `cannot_open_image`, `cannot_decode_image`, `retry_after_authorization`, `permission_camera_rationale`, `return_text`, `scan_qr_code`, `qr_code`, `scan`, `make`, `clear`, `copy`, `save`, `ok`, `cancel`, `done`. Added: `open_system_settings`, `do_affair`, `gallery` (parity for Mac-only UX).

## Explicitly not ported

- `imageProxyToBitmap` YUV→RGB loop — unnecessary; `AVCaptureMetadataOutput` returns decoded strings directly.
- ZXing (`MultiFormatReader`, `HybridBinarizer`, custom `LuminanceSource`) — replaced with Apple detectors (`CIDetectorTypeQRCode` / AVCaptureMetadata).
- `FcEntity.fromJson(Affair.class)` full parse — stubbed behind `AffairHandler` protocol.
- Status bar color forcing — N/A on macOS.
