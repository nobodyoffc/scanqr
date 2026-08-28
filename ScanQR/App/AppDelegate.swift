import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var vm: QrViewModel?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        _ = vm?.handleWindowClose()
    }
}
