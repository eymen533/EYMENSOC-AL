import SwiftUI

enum SOCTheme {
    static let background = Color.black
    static let surface = Color(red: 0.09, green: 0.09, blue: 0.10)
    static let surfaceElevated = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.62)
    static let textMuted = Color(white: 0.42)
    static let accent = Color(red: 0.35, green: 0.45, blue: 1.0)
    static let accentDeep = Color(red: 0.45, green: 0.28, blue: 0.95)
    static let warning = Color(red: 1.0, green: 0.78, blue: 0.22)
    static let warningBackground = Color(red: 0.28, green: 0.18, blue: 0.05)
    static let success = Color(red: 0.30, green: 0.85, blue: 0.45)
    static let mapArrow = Color(red: 0.95, green: 0.22, blue: 0.22)
    static let batteryGreen = Color(red: 0.25, green: 0.82, blue: 0.40)

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentDeep],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var cardGlow: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.45, green: 0.55, blue: 1.0).opacity(0.85),
                Color(red: 0.95, green: 0.35, blue: 0.70).opacity(0.75)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct PrimaryGradientButtonStyle: ButtonStyle {
    var enabled: Bool = true
    var isBusy: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(enabled ? 1 : 0.55))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule()
                    .fill(SOCTheme.primaryGradient)
                    .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.35)
            )
            .scaleEffect(configuration.isPressed && enabled ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SOCTheme.textSecondary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(SOCTheme.surfaceElevated))
        }
        .buttonStyle(.plain)
    }
}
