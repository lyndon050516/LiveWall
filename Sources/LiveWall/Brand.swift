import SwiftUI

enum Brand {
    static let indigo = Color(red: 0x5B / 255, green: 0x5B / 255, blue: 0xE6 / 255)
    static let cyan = Color(red: 0x6F / 255, green: 0xE7 / 255, blue: 0xDD / 255)

    static let gradient = LinearGradient(
        colors: [indigo, cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing)

    static let windowBackground = Color(red: 0.07, green: 0.07, blue: 0.09)
}

struct PrimaryGradientButton: ButtonStyle {
    var size: Font = .system(size: 13, weight: .semibold)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Brand.gradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
