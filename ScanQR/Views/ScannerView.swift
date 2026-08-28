import SwiftUI
import AVFoundation
import AppKit

struct ScannerView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> PreviewNSView {
        PreviewNSView(previewLayer: previewLayer)
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {}
}

final class PreviewNSView: NSView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        super.init(frame: .zero)
        wantsLayer = true
        let root = CALayer()
        layer = root
        previewLayer.frame = bounds
        root.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
    }
}
