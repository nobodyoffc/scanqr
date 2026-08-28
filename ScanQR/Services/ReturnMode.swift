import AppKit

enum ReturnMode: Equatable {
    case normal
    case returnString(callback: URL?)

    var isReturn: Bool {
        if case .returnString = self { return true }
        return false
    }
}

enum ReturnModeResolver {
    static func parse(_ url: URL) -> ReturnMode? {
        guard url.scheme?.lowercased() == "scanqr",
              url.host?.lowercased() == "return" else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let callback = items.first(where: { $0.name == "callback" })?.value
            .flatMap { URL(string: $0) }
        return .returnString(callback: callback)
    }

    /// Writes the result to Caches/ScanQR/last_result.txt, prints to stdout,
    /// and opens the callback URL (if provided) with `qr_content` appended.
    static func deliver(content: String, callback: URL?) {
        let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let appDir = cacheRoot.appendingPathComponent("ScanQR", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        let resultFile = appDir.appendingPathComponent("last_result.txt")
        try? content.write(to: resultFile, atomically: true, encoding: .utf8)

        if let callback = callback,
           var comps = URLComponents(url: callback, resolvingAgainstBaseURL: false) {
            var items = comps.queryItems ?? []
            items.append(URLQueryItem(name: "qr_content", value: content))
            comps.queryItems = items
            if let cbUrl = comps.url {
                NSWorkspace.shared.open(cbUrl)
            }
        }

        FileHandle.standardOutput.write(Data(content.utf8))
        FileHandle.standardOutput.write(Data([0x0A]))
    }
}
