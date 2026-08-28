import XCTest
@testable import ScanQR

final class QRGeneratorTests: XCTestCase {
    func testEmptyContentProducesNoChunks() {
        XCTAssertTrue(QRGenerator.splitByUTF8Bytes("", capacity: 300).isEmpty)
    }

    func testShortAsciiIsOneChunk() {
        let s = "hello world"
        XCTAssertEqual(QRGenerator.splitByUTF8Bytes(s, capacity: 300), [s])
    }

    func testExactlyAtCapacityIsOneChunk() {
        let s = String(repeating: "a", count: 300)
        XCTAssertEqual(QRGenerator.splitByUTF8Bytes(s, capacity: 300), [s])
    }

    func testOneByteOverflowSplitsIntoTwo() {
        let s = String(repeating: "a", count: 301)
        let parts = QRGenerator.splitByUTF8Bytes(s, capacity: 300)
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts[0].utf8.count, 300)
        XCTAssertEqual(parts[1].utf8.count, 1)
        XCTAssertEqual(parts.joined(), s)
    }

    func testMultibyteCodepointIsNeverSplit() {
        // 😀 is 4 UTF-8 bytes. 75×4 = 300 bytes; 76th emoji spills to a 2nd chunk.
        let s = String(repeating: "😀", count: 76)
        let parts = QRGenerator.splitByUTF8Bytes(s, capacity: 300)
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts[0], String(repeating: "😀", count: 75))
        XCTAssertEqual(parts[1], "😀")
        XCTAssertEqual(parts.joined(), s)
    }

    func testChunksConcatenateToOriginal() {
        let s = String(repeating: "abcdé", count: 200) // mix ASCII + multibyte
        let parts = QRGenerator.splitByUTF8Bytes(s, capacity: 300)
        XCTAssertGreaterThan(parts.count, 1)
        for p in parts { XCTAssertLessThanOrEqual(p.utf8.count, 300) }
        XCTAssertEqual(parts.joined(), s)
    }

    func testSegmentsProducesImagesForLongContent() {
        let s = String(repeating: "a", count: 650)
        let segs = QRGenerator.segments(for: s)
        XCTAssertEqual(segs.count, 3)
        XCTAssertEqual(segs.first?.total, 3)
        XCTAssertEqual(segs.map { $0.payload }.joined(), s)
    }
}
