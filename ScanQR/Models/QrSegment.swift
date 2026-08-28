import AppKit

struct QrSegment: Identifiable {
    let id = UUID()
    let index: Int
    let total: Int
    let payload: String
    let image: NSImage
}

struct SaveResult {
    let savedCount: Int
    let directory: URL
    let firstError: Error?
}
