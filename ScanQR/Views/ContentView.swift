import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var vm: QrViewModel
    @FocusState private var textFocused: Bool

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { textFocused = false }

            VStack(spacing: 12) {
                scanArea
                textArea
                buttonsRow
                if vm.affairAvailable {
                    Button {
                        vm.handleAffair()
                    } label: {
                        Label(L10n.doAffair, systemImage: "wand.and.rays")
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .frame(minWidth: 420, minHeight: 780)

            if let msg = vm.toast {
                VStack {
                    Spacer()
                    ToastView(text: msg)
                        .padding(.bottom, 32)
                }
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.2), value: vm.toast)
            }
        }
        .alert(L10n.permissionCameraRationale, isPresented: $vm.permissionDenied) {
            Button(L10n.ok) { vm.permissionDenied = false }
            Button(L10n.openSystemSettings) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
                vm.permissionDenied = false
            }
        }
        .sheet(isPresented: $vm.showQRPager) {
            VStack(spacing: 0) {
                QRPagerView(segments: vm.segments)
                Divider()
                HStack {
                    Button(L10n.save) { vm.save() }
                    Spacer()
                    Button(L10n.ok) { vm.showQRPager = false }
                        .keyboardShortcut(.defaultAction)
                }
                .padding(12)
            }
            .frame(minWidth: 440, minHeight: 540)
        }
    }

    @ViewBuilder
    private var scanArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.secondary.opacity(0.4),
                                      style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                )

            if vm.isScanning {
                ScannerView(previewLayer: vm.scanner.previewLayer)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .foregroundColor(.secondary)
                    Text(L10n.scanQrCode).foregroundColor(.secondary)
                }
            }
        }
        .frame(minHeight: 280, idealHeight: 320)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            textFocused = false
            Task { await vm.toggleScanning() }
        }
    }

    @ViewBuilder
    private var textArea: some View {
        TextEditor(text: $vm.text)
            .font(.body.monospaced())
            .frame(minHeight: 120, idealHeight: 150)
            .scrollContentBackground(.hidden)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.3))
            )
            .focused($textFocused)
            .onChange(of: textFocused) { focused in
                if focused && vm.isScanning {
                    vm.stopScanning()
                }
            }
    }

    @ViewBuilder
    private var buttonsRow: some View {
        HStack(spacing: 8) {
            pill(title: L10n.make, system: "qrcode") {
                vm.generate()
            }
            pill(title: L10n.gallery, system: "photo") {
                vm.pickImage()
            }
            pill(title: L10n.clear, system: "trash") {
                vm.clear()
            }
            pill(title: vm.isReturnMode ? L10n.returnText : L10n.copy,
                 system: vm.isReturnMode ? "arrow.uturn.backward" : "doc.on.doc") {
                vm.copyOrReturn()
            }
            pill(title: L10n.scan,
                 system: vm.isScanning ? "stop.circle" : "camera") {
                Task { await vm.toggleScanning() }
            }
        }
    }

    private func pill(title: String, system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: system).font(.system(size: 18))
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
    }
}
