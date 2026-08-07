import SwiftUI

/// Turn guidance — photoreal volumetric plaque (R1–R10). Default R9. Compact size.
struct NavTurnCue: View {
    var distanceM: Int
    var instruction: String
    var symbol: String
    var style: Style = .chip

    enum Style {
        case chip
        case mapHero
    }

    @ObservedObject private var settings = HUDSettings.shared
    @State private var pulse = false

    private var sym: String { symbol.isEmpty ? "arrow.turn.up.right" : symbol }
    private var imminent: Bool { distanceM > 0 && distanceM <= 55 }
    private var approaching: Bool { distanceM > 0 && distanceM <= 120 }
    private var now: Bool { distanceM > 0 && distanceM <= 28 }

    private var heading: TurnHeading {
        let s = sym.lowercased()
        if s.contains("uturn") || s.contains("u.turn") { return .uturn }
        if s.contains("left") { return .left }
        if s.contains("right") { return .right }
        if s.contains("flag") || s.contains("arrive") { return .arrive }
        return .straight
    }

    /// Forces SwiftUI to swap the Image when settings change.
    private var plaqueAsset: String { settings.turnCueStyle.assetName }

    var body: some View {
        Group {
            switch style {
            case .chip:
                chipBody
            case .mapHero:
                if imminent {
                    heroBody
                } else {
                    chipBody
                }
            }
        }
        .id(plaqueAsset) // re-render when style changes in Settings
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onChangeCompat(of: settings.turnCueStyle) { _ in
            pulse = false
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - Chip (far) — compact plaque

    private var chipBody: some View {
        HStack(spacing: 10) {
            plaqueImage(width: approaching ? 52 : 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(distanceText)
                    .font(approaching ? .title3.weight(.bold).monospacedDigit() : .headline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                if !instruction.isEmpty {
                    Text(instruction)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .lineLimit(2)
                }
                if imminent {
                    Text(now ? "ŞİMDİ DÖN" : "DÖNÜŞE HAZIRLAN")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Color(red: 1.0, green: 0.92, blue: 0.25))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
    }

    // MARK: - Hero (imminent) — smaller than before

    private var heroBody: some View {
        VStack(spacing: 8) {
            plaqueImage(width: now ? 148 : 128)
                .scaleEffect(pulse ? 1.04 : 0.98)
                .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
                .shadow(
                    color: Color(red: 1.0, green: 0.9, blue: 0.2).opacity(pulse ? 0.28 : 0.1),
                    radius: pulse ? 12 : 6
                )

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(now ? "ŞİMDİ" : distanceText)
                        .font(.system(size: now ? 20 : 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(now ? turnVerb : (instruction.isEmpty ? turnVerb : instruction))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.95))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: 200)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.62))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
            )
        }
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    // MARK: - Plaque

    private func plaqueImage(width: CGFloat) -> some View {
        Image(plaqueAsset)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .scaleEffect(x: heading == .left ? -1 : 1, y: 1)
            .rotationEffect(plaqueRotation)
            .accessibilityLabel(turnVerb)
    }

    private var plaqueRotation: Angle {
        switch heading {
        case .right, .left: return .degrees(0)
        case .straight, .arrive: return .degrees(-90)
        case .uturn: return .degrees(180)
        }
    }

    private var turnVerb: String {
        switch heading {
        case .left: return "SOLA DÖN"
        case .right: return "SAĞA DÖN"
        case .uturn: return "U DÖNÜŞÜ"
        case .arrive: return "HEDEF"
        case .straight: return "DÜZ DEVAM"
        }
    }

    private var distanceText: String {
        if distanceM >= 1000 { return String(format: "%.1f km", Double(distanceM) / 1000.0) }
        return "\(max(0, distanceM)) m"
    }
}

private enum TurnHeading {
    case left, right, straight, uturn, arrive
}
