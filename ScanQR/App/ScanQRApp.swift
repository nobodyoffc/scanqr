import SwiftUI

@main
struct ScanQRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var vm = QrViewModel()

    var body: some Scene {
        WindowGroup(L10n.menuQrCode) {
            ContentView(vm: vm)
                .onAppear { appDelegate.vm = vm }
                .onOpenURL { url in
                    vm.applyReturnMode(from: url)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .frame(minWidth: 420, minHeight: 780)
        }
        .defaultSize(width: 440, height: 820)
        .windowResizability(.contentMinSize)
    }
}
