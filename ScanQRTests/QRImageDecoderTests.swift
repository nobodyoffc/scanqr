import XCTest
import AppKit
@testable import ScanQR

final class QRImageDecoderTests: XCTestCase {
    func testRoundTripSimpleString() throws {
        let message = "https://example.com/test?x=1"
        guard let img = QRGenerator.makeImage(message) else {
            return XCTFail("QR generation failed")
        }
        let url = try writePNG(img, name: "roundtrip")
        defer { try? FileManager.default.removeItem(at: url) }

        let decoded = QRImageDecoder.decode(url: url)
        XCTAssertEqual(decoded, message)
    }

    func testRoundTripUnicodeString() throws {
        let message = "混合文字🎉 1234"
        guard let img = QRGenerator.makeImage(message) else {
            return XCTFail("QR generation failed")
        }
        let url = try writePNG(img, name: "unicode")
        defer { try? FileManager.default.removeItem(at: url) }

        let decoded = QRImageDecoder.decode(url: url)
        XCTAssertEqual(decoded, message)
    }

    func testDecodeBlankImageReturnsNil() throws {
        let size = NSSize(width: 64, height: 64)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        img.unlockFocus()
        let url = try writePNG(img, name: "blank")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertNil(QRImageDecoder.decode(url: url))
    }

    private func writePNG(_ img: NSImage, name: String) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("scanqr-\(name)-\(UUID().uuidString).png")
        guard let data = img.pngData() else {
            throw NSError(domain: "Test", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "pngData failed"])
        }
        try data.write(to: tmp)
        return tmp
    }
}
