import AppKit
import AVFoundation
import Combine
import UniformTypeIdentifiers

@MainActor
final class QrViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var isScanning: Bool = false
    @Published var segments: [QrSegment] = []
    @Published var showQRPager: Bool = false
    @Published var toast: String? = nil
    @Published var permissionDenied: Bool = false
    @Published var returnMode: ReturnMode = .normal

    let scanner = CameraScanner()
    let affairHandler: AffairHandler

    private var toastToken: UUID?

    init(affairHandler: AffairHandler = NoopAffairHandler()) {
        self.affairHandler = affairHandler
        scanner.onDetect = { [weak self] decoded in
            guard let self = self else { return }
            self.text += decoded
            self.stopScanning()
            self.showToast(L10n.done)
        }
    }

    var isReturnMode: Bool { returnMode.isReturn }

    var affairAvailable: Bool { affairHandler.canHandle(text) }

    // MARK: - Camera

    func toggleScanning() async {
        if isScanning {
            stopScanning()
            return
        }
        let granted = await CameraScanner.requestAccess()
        guard granted else {
            permissionDenied = true
            return
        }
        do {
            try scanner.setup()
        } catch {
            if let setupError = error as? CameraScanner.SetupError {
                switch setupError {
                case .noDevice:
                    showToast(L10n.cameraNotFound)
                case .cannotAddInput, .cannotAddOutput:
                    showToast(L10n.cameraSessionSetupFailed)
                }
            } else {
                showToast(L10n.cameraSessionSetupFailed)
            }
            return
        }
        scanner.start()
        isScanning = true
    }

    func stopScanning() {
        scanner.stop()
        isScanning = false
    }

    // MARK: - Generation

    func generate() {
        let content = text
        guard !content.isEmpty else {
            showToast(L10n.errorCreatingQR)
            return
        }
        let segs = QRGenerator.segments(for: content)
        guard !segs.isEmpty else {
            showToast(L10n.errorCreatingQR)
            return
        }
        segments = segs
        showQRPager = true
    }

    func save() {
        let result = QRFileSaver.save(segments)
        if result.savedCount > 0 {
            let shortPath = (result.directory.path as NSString).abbreviatingWithTildeInPath
            let countMsg = String(format: L10n.qrSavedCountFormat, result.savedCount)
            showToast("\(countMsg)\n\(shortPath)")
            NSWorkspace.shared.activateFileViewerSelecting([result.directory])
        } else {
            showToast(L10n.errorSavingQR)
        }
    }

    // MARK: - Copy / Return

    func copyOrReturn() {
        guard !text.isEmpty else { return }
        switch returnMode {
        case .normal:
            Clipboard.copy(text)
            showToast(L10n.copiedToClipboard)
        case .returnString(let callback):
            ReturnModeResolver.deliver(content: text, callback: callback)
            NSApp.terminate(nil)
        }
    }

    func clear() {
        text = ""
        segments = []
    }

    // MARK: - Gallery

    func pickImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        var types: [UTType] = [.png, .jpeg, .tiff, .bmp, .image]
        if let heic = UTType("public.heic") { types.insert(heic, at: 3) }
        panel.allowedContentTypes = types
        panel.begin { [weak self] resp in
            guard resp == .OK, let url = panel.url else { return }
            Task { @MainActor in self?.decodeImage(at: url) }
        }
    }

    private func decodeImage(at url: URL) {
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            showToast(L10n.cannotOpenImage); return
        }
        guard let decoded = QRImageDecoder.decode(url: url), !decoded.isEmpty else {
            showToast(L10n.cannotDecodeImage); return
        }
        text += decoded
    }

    // MARK: - Affair stub

    func handleAffair() {
        guard affairHandler.canHandle(text) else { return }
        affairHandler.handle(text)
    }

    // MARK: - Toast

    func showToast(_ message: String) {
        let token = UUID()
        toastToken = token
        toast = message
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard let self = self, self.toastToken == token else { return }
            self.toast = nil
        }
    }

    // MARK: - Lifecycle

    /// Called from AppDelegate before terminate. Returns true if result was delivered.
    @discardableResult
    func handleWindowClose() -> Bool {
        if case .returnString(let callback) = returnMode, !text.isEmpty {
            ReturnModeResolver.deliver(content: text, callback: callback)
            return true
        }
        return false
    }

    func applyReturnMode(from url: URL) {
        if let mode = ReturnModeResolver.parse(url) {
            returnMode = mode
        }
    }
}
