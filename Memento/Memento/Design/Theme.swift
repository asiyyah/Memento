import SwiftUI

/// Shared colours, type and spacing, so the look can be tuned in one place.
enum Theme {
    static let ink = Color(red: 0.067, green: 0.067, blue: 0.067)
    static let secondaryInk = Color(red: 0.333, green: 0.333, blue: 0.333)
    static let hairline = Color(red: 0.8, green: 0.8, blue: 0.8)
    static let paper = Color.white
    static let blankPrint = Color(red: 0.914, green: 0.914, blue: 0.906)

    static let screenPadding: CGFloat = 24

    enum Fonts {
        static let screenTitle = Font.system(size: 28, weight: .semibold)
        static let button = Font.system(size: 17, weight: .semibold)
        static let caption = Font.system(size: 13)
        static let captionStrong = Font.system(size: 13, weight: .medium)

        /// Stand-in for Caveat until the design fonts are bundled with the app.
        static func handwritten(_ size: CGFloat) -> Font {
            Font.custom("BradleyHandITCTT-Bold", size: size, relativeTo: .title)
        }
    }
}

/// The capsule button used across the app: solid black or outlined.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, outline }

    var kind: Kind = .primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.button)
            .foregroundStyle(kind == .primary ? Color.white : Theme.secondaryInk)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(kind == .primary ? Theme.ink : Color.white, in: Capsule())
            .overlay {
                if kind == .outline {
                    Capsule().strokeBorder(Theme.hairline, lineWidth: 1)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.35)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
