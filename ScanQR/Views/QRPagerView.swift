import SwiftUI

struct QRPagerView: View {
    let segments: [QrSegment]
    @State private var index: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            if let seg = currentSegment {
                Image(nsImage: seg.image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(minWidth: 280, idealWidth: 400, maxWidth: .infinity,
                           minHeight: 280, idealHeight: 400, maxHeight: .infinity)
                    .background(Color.white)
                    .padding(8)
            }
            if segments.count > 1 {
                HStack(spacing: 24) {
                    Button {
                        if index > 0 { index -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .disabled(index == 0)

                    Text("\(index + 1)/\(segments.count)")
                        .font(.callout.monospacedDigit())
                        .frame(minWidth: 60)

                    Button {
                        if index < segments.count - 1 { index += 1 }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .disabled(index >= segments.count - 1)
                }
                .padding(.bottom, 4)
            }
        }
        .padding()
    }

    private var currentSegment: QrSegment? {
        guard segments.indices.contains(index) else { return segments.first }
        return segments[index]
    }
}
