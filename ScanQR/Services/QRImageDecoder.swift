import AppKit
import CoreImage

enum QRImageDecoder {
    static func decode(url: URL) -> String? {
        guard let ci = CIImage(contentsOf: url) else {
            guard let img = NSImage(contentsOf: url),
                  let tiff = img.tiffRepresentation,
                  let ci = CIImage(data: tiff) else { return nil }
            return decode(ciImage: ci)
        }
        return decode(ciImage: ci)
    }

    static func decode(ciImage: CIImage) -> String? {
        let options: [String: Any] = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: options)
        guard let features = detector?.features(in: ciImage) as? [CIQRCodeFeature] else { return nil }
        let messages = features.compactMap { $0.messageString }.filter { !$0.isEmpty }
        guard !messages.isEmpty else { return nil }
        return messages.joined()
    }
}
