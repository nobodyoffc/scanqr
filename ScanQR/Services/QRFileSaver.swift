import AppKit

enum QRFileSaver {
    static var defaultDirectory: URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        return downloads.appendingPathComponent("ScanQR", isDirectory: true)
    }

    static func save(_ segments: [QrSegment]) -> SaveResult {
        let fm = FileManager.default
        let dir = defaultDirectory
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return SaveResult(savedCount: 0, directory: dir, firstError: error)
        }

        let epoch = Int(Date().timeIntervalSince1970 * 1000)
        var saved = 0
        var firstError: Error?
        for (i, seg) in segments.enumerated() {
            let name = "QR_\(epoch)_\(i).png"
            let url = dir.appendingPathComponent(name)
            guard let data = seg.image.pngData() else {
                if firstError == nil {
                    firstError = NSError(domain: "ScanQR", code: -1,
                                         userInfo: [NSLocalizedDescriptionKey: "PNG encoding failed"])
                }
                continue
            }
            do {
                try data.write(to: url, options: .atomic)
                saved += 1
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        return SaveResult(savedCount: saved, directory: dir, firstError: firstError)
    }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
