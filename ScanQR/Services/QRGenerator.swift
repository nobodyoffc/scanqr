import AppKit
import CoreImage

enum QRGenerator {
    static let defaultCapacity = 300
    static let targetPixels: CGFloat = 461

    static func segments(for content: String) -> [QrSegment] {
        let chunks = splitByUTF8Bytes(content, capacity: defaultCapacity)
        let total = chunks.count
        var result: [QrSegment] = []
        for (i, chunk) in chunks.enumerated() {
            guard let image = makeImage(chunk) else { continue }
            result.append(QrSegment(index: i, total: total, payload: chunk, image: image))
        }
        return result
    }

    static func splitByUTF8Bytes(_ content: String, capacity: Int) -> [String] {
        guard !content.isEmpty else { return [] }
        if content.utf8.count <= capacity { return [content] }

        var chunks: [String] = []
        var startIndex = content.startIndex

        while startIndex < content.endIndex {
            var endIndex = startIndex
            var currentBytes = 0
            while endIndex < content.endIndex {
                let ch = content[endIndex]
                let chBytes = String(ch).utf8.count
                if currentBytes + chBytes > capacity { break }
                currentBytes += chBytes
                endIndex = content.index(after: endIndex)
            }
            if endIndex == startIndex {
                endIndex = content.index(after: startIndex)
            }
            chunks.append(String(content[startIndex..<endIndex]))
            startIndex = endIndex
        }
        return chunks
    }

    static func makeImage(_ text: String) -> NSImage? {
        guard let data = text.data(using: .utf8) else { return nil }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ci = filter.outputImage else { return nil }

        let scale = max(1, Int(ceil(targetPixels / ci.extent.width)))
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale)))

        let ctx = CIContext(options: nil)
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}
