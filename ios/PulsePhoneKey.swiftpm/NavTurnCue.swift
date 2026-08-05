import SwiftUI

/// Map-integrated turn guidance — elegant far away, illuminated when the turn is due.
struct NavTurnCue: View {
    var distanceM: Int
    var instruction: String
    var symbol: String
    /// Compact chip vs large map-center cue.
    var style: Style = .chip

    enum Style {
        case chip
        case mapHero
    }

    @State private var pulse = false
    @State private var sweep = false

    private var sym: String { symbol.isEmpty ? "arrow.turn.up.right" : symbol }
    private var imminent: Bool { distanceM > 0 && distanceM <= 55 }
    private var approaching: Bool { distanceM > 0 && distanceM <= 120 }
    private var now: Bool { distanceM > 0 && distanceM <= 28 }

    private let ice = Color(red: 0.72, green: 0.95, blue: 1.0)
    private let teal = Color(red: 0.18, green: 0.86, blue: 0.78)
    private let amber = Color(red: 1.0, green: 0.78, blue: 0.28)

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
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                sweep = true
            }
        }
    }

    // MARK: - Chip (always / far)

    private var chipBody: some View {
        HStack(spacing: approaching ? 14 : 12) {
            arrowGlyph(size: approaching ? 30 : 24, heavy: approaching)
                .frame(width: approaching ? 44 : 36, height: approaching ? 44 : 36)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .overlay(
                            Circle()
                                .stroke(
                                    (imminent ? amber : teal).opacity(approaching ? 0.75 : 0.35),
                                    lineWidth: approaching ? 1.6 : 1
                                )
                        )
                        .shadow(color: (imminent ? amber : teal).opacity(approaching ? 0.55 : 0.2), radius: approaching ? 10 : 4)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(distanceText)
                    .font(approaching ? .title2.weight(.bold).monospacedDigit() : .title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                if !instruction.isEmpty {
                    Text(instruction)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .lineLimit(2)
                }
                if imminent {
                    Text(now ? "ŞİMDİ DÖN" : "DÖNÜŞE HAZIRLAN")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(now ? amber : ice)
                        .tracking(0.6)
                }
            }
        }
        .padding(.horizontal, approaching ? 16 : 14)
        .padding(.vertical, approaching ? 12 : 10)
        .background(glassBackground(corner: 16, hot: approaching))
    }

    // MARK: - Hero (on map when turn is due)

    private var heroBody: some View {
        VStack(spacing: 14) {
            ZStack {
                // Soft bloom into the map.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (now ? amber : teal).opacity(pulse ? 0.38 : 0.18),
                                (now ? amber : teal).opacity(0.08),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 110
                        )
                    )
                    .frame(width: 210, height: 210)
                    .scaleEffect(pulse ? 1.06 : 0.94)

                // Concentric light rings.
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(
                            (now ? amber : ice).opacity(pulse ? 0.45 - Double(i) * 0.12 : 0.22 - Double(i) * 0.06),
                            lineWidth: 1.4
                        )
                        .frame(width: CGFloat(88 + i * 28), height: CGFloat(88 + i * 28))
                        .scaleEffect(pulse ? 1.04 : 0.96)
                }

                // Glass disc + arrow.
                Circle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .frame(width: 96, height: 96)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.65),
                                        (now ? amber : teal).opacity(0.7),
                                        .white.opacity(0.15),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: UnitPoint(x: sweep ? 1 : 0.2, y: sweep ? 1 : 0.3)
                                ),
                                lineWidth: 2.2
                            )
                    )
                    .shadow(color: (now ? amber : teal).opacity(pulse ? 0.65 : 0.35), radius: pulse ? 22 : 12)
                    .overlay(
                        arrowGlyph(size: 44, heavy: true)
                    )
            }

            VStack(spacing: 4) {
                Text(now ? "ŞİMDİ" : distanceText)
                    .font(.system(size: now ? 28 : 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 4, y: 2)

                Text(now ? turnVerb : (instruction.isEmpty ? "Dönüş" : instruction))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)

                if !now, !instruction.isEmpty {
                    Text("DÖNÜŞ")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(amber)
                        .tracking(1.2)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(glassBackground(corner: 14, hot: true))
        }
        .frame(maxWidth: 260)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }

    private var turnVerb: String {
        let s = sym.lowercased()
        if s.contains("left") { return "SOLA DÖN" }
        if s.contains("right") { return "SAĞA DÖN" }
        if s.contains("uturn") { return "U DÖNÜŞÜ" }
        if s.contains("flag") { return "HEDEF" }
        return instruction.isEmpty ? "DÖN" : instruction.uppercased()
    }

    private var distanceText: String {
        if distanceM >= 1000 { return String(format: "%.1f km", Double(distanceM) / 1000.0) }
        return "\(max(0, distanceM)) m"
    }

    private func arrowGlyph(size: CGFloat, heavy: Bool) -> some View {
        ZStack {
            Image(systemName: sym)
                .font(.system(size: size, weight: .black))
                .foregroundStyle((now ? amber : ice).opacity(0.35))
                .blur(radius: heavy ? 8 : 4)
                .scaleEffect(pulse && heavy ? 1.08 : 1.0)
            Image(systemName: sym)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: now
                            ? [amber, .white, amber.opacity(0.85)]
                            : [ice, .white, teal],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: (now ? amber : teal).opacity(0.8), radius: heavy ? 10 : 5)
        }
    }

    private func glassBackground(corner: CGFloat, hot: Bool) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color.black.opacity(hot ? 0.42 : 0.32))
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.45),
                                (imminent ? amber : teal).opacity(hot ? 0.55 : 0.22),
                                .white.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: hot ? 1.4 : 1
                    )
            )
            .shadow(color: (imminent ? amber : teal).opacity(hot ? 0.35 : 0.12), radius: hot ? 14 : 6, y: 3)
    }
}
