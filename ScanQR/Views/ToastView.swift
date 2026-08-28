import SwiftUI

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.85))
            )
            .shadow(radius: 8, x: 0, y: 4)
            .transition(.opacity)
    }
}
