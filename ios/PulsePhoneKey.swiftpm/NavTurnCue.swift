import SwiftUI

/// Turn guidance — photoreal volumetric plaque (R1–R10 styles). Default R9 raised yellow.
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
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - Chip (far)

    private var chipBody: some View {
        HStack(spacing: 12) {
            plaqueImage(width: approaching ? 72 : 60)
            VStack(alignment: .leading, spacing: 2) {
                Text(distanceText)
                    .font(approaching ? .title2.weight(.bold).monospacedDigit() : .title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                if !instruction.isEmpty {
                    Text(instruction)
                        .font(.caption.weight(.semibold))
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
    }

    // MARK: - Hero (imminent)

    private var heroBody: some View {
        VStack(spacing: 12) {
            plaqueImage(width: now ? 280 : 250)
                .scaleEffect(pulse ? 1.03 : 0.98)
                .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
                .shadow(
                    color: Color(red: 1.0, green: 0.9, blue: 0.2).opacity(pulse ? 0.35 : 0.12),
                    radius: pulse ? 18 : 8
                )

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(now ? "ŞİMDİ" : distanceText)
                        .font(.system(size: now ? 26 : 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(now ? turnVerb : (instruction.isEmpty ? turnVerb : instruction))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.95))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minWidth: 240, maxWidth: 300)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.62))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
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
