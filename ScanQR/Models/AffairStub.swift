import Foundation

protocol AffairHandler {
    func canHandle(_ content: String) -> Bool
    func handle(_ content: String)
}

struct NoopAffairHandler: AffairHandler {
    func canHandle(_ content: String) -> Bool {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return content.lowercased().contains("\"n\":\"affair\"")
    }

    func handle(_ content: String) {
        NSLog("AffairHandler stub invoked; content length=\(content.count)")
    }
}
