import AVFoundation
import AppKit
import Vision
import os

final class CameraScanner: NSObject, AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    let previewLayer: AVCaptureVideoPreviewLayer
    private let metadataQueue = DispatchQueue(label: "scanqr.metadata")
    private let videoQueue = DispatchQueue(label: "scanqr.video")
    private var isProcessing = false
    private var didConfigure = false
    private var frameCounter = 0
    private let log = Logger(subsystem: "com.scanqr.app", category: "scanner")

    var onDetect: ((String) -> Void)?

    override init() {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init()
        previewLayer.videoGravity = .resizeAspectFill
    }

    enum SetupError: Error {
        case noDevice
        case cannotAddInput
        case cannotAddOutput
    }

    func setup() throws {
        guard !didConfigure else { return }
        log.info("setup: begin")
        session.beginConfiguration()

        var deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .externalUnknown
        ]
        if #available(macOS 14.0, *) {
            deviceTypes.append(.continuityCamera)
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        let defaultBuiltIn = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
        let defaultExternal = AVCaptureDevice.default(.externalUnknown, for: .video, position: .unspecified)
        let defaultContinuity: AVCaptureDevice?
        if #available(macOS 14.0, *) {
            defaultContinuity = AVCaptureDevice.default(.continuityCamera, for: .video, position: .unspecified)
        } else {
            defaultContinuity = nil
        }
        let device = discovery.devices.first
            ?? defaultBuiltIn
            ?? defaultExternal
            ?? defaultContinuity
            ?? AVCaptureDevice.default(for: .video)
        let discoveredNames = discovery.devices.map(\.localizedName)
        log.info("setup: discovery devices=\(discoveredNames, privacy: .public)")
        guard let device else {
            session.commitConfiguration()
            log.error("setup: no default video device")
            throw SetupError.noDevice
        }
        log.info("setup: device=\(device.localizedName, privacy: .public)")

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            log.error("setup: cannot add input")
            throw SetupError.cannotAddInput
        }
        session.addInput(input)

        // Primary path: AVCaptureMetadataOutput (fast, dedicated QR hardware path).
        let metaOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metaOutput) else {
            session.commitConfiguration()
            log.error("setup: cannot add metadata output")
            throw SetupError.cannotAddOutput
        }
        session.addOutput(metaOutput)
        metaOutput.setMetadataObjectsDelegate(self, queue: metadataQueue)

        // Fallback path: AVCaptureVideoDataOutput → Vision VNDetectBarcodesRequest.
        // On some Mac camera formats AVCaptureMetadataOutput never emits .qr even when
        // the hardware supports it; Vision works off raw frames so it always sees the QR.
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            log.info("setup: video data output attached (Vision fallback enabled)")
        } else {
            log.error("setup: cannot add video data output — Vision fallback disabled")
        }

        session.commitConfiguration()

        let available = metaOutput.availableMetadataObjectTypes
        log.info("setup: availableMetadataObjectTypes=\(available.map { $0.rawValue }, privacy: .public)")
        if available.contains(.qr) {
            metaOutput.metadataObjectTypes = [.qr]
            log.info("setup: metadataObjectTypes set to [.qr]")
        } else {
            log.warning("setup: .qr NOT in availableMetadataObjectTypes — relying on Vision fallback")
        }

        didConfigure = true
        log.info("setup: done")
    }

    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    func start() {
        isProcessing = false
        frameCounter = 0
        guard !session.isRunning else {
            log.info("start: session already running")
            return
        }
        log.info("start: starting session")
        DispatchQueue.global(qos: .userInitiated).async { [session, log] in
            session.startRunning()
            log.info("start: session.isRunning=\(session.isRunning)")
        }
    }

    func stop() {
        guard session.isRunning else { return }
        log.info("stop: stopping session")
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.stopRunning()
        }
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        log.info("metadataOutput: \(metadataObjects.count) objects")
        guard !isProcessing else { return }
        for obj in metadataObjects {
            if let qr = obj as? AVMetadataMachineReadableCodeObject,
               qr.type == .qr,
               let s = qr.stringValue,
               !s.isEmpty {
                log.info("metadataOutput: QR hit via AVCaptureMetadataOutput")
                deliver(s)
                return
            }
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate (Vision fallback)

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard !isProcessing else { return }
        frameCounter += 1
        // Run Vision on every 3rd frame to keep CPU reasonable (~10 fps at 30 fps capture).
        guard frameCounter % 3 == 0 else { return }
        if frameCounter == 3 { log.info("captureOutput: first frame reached Vision path") }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            log.error("Vision perform failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard let results = request.results, !results.isEmpty else { return }
        log.info("Vision: \(results.count) barcode(s) detected")
        if let payload = results.compactMap({ $0.payloadStringValue }).first(where: { !$0.isEmpty }) {
            log.info("Vision: QR hit")
            deliver(payload)
        }
    }

    private func deliver(_ s: String) {
        isProcessing = true
        DispatchQueue.main.async { [weak self] in
            self?.onDetect?(s)
        }
    }
}
