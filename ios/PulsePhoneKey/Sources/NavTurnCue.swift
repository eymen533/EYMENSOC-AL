import SwiftUI

/// Map turn guidance — road-sign board + neon chase arrows (1→2→3).
struct NavTurnCue: View {
    var distanceM: Int
    var instruction: String
    var symbol: String
    var style: Style = .chip

    enum Style {
        case chip
        case mapHero
    }

    @State private var pulse = false
    /// 0…2 — which of the three arrows is lit (chase).
    @State private var chaseIndex = 0
    @State private var chaseTick: Timer?

    private var sym: String { symbol.isEmpty ? "arrow.turn.up.right" : symbol }
    private var imminent: Bool { distanceM > 0 && distanceM <= 55 }
    private var approaching: Bool { distanceM > 0 && distanceM <= 120 }
    private var now: Bool { distanceM > 0 && distanceM <= 28 }

    private let ice = Color(red: 0.75, green: 0.96, blue: 1.0)
    private let teal = Color(red: 0.20, green: 0.90, blue: 0.82)
    private let amber = Color(red: 1.0, green: 0.78, blue: 0.22)
    private let neonCyan = Color(red: 0.25, green: 0.95, blue: 1.0)

    var body: some View {
        Group {
            switch style {
            case .chip:
                chipBody
            case .mapHero:
                if imminent {
                    signHero
                } else {
                    chipBody
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { startAnimations() }
        .onDisappear { chaseTick?.invalidate(); chaseTick = nil }
        .onChangeCompat(of: imminent) { hot in
            if hot { startChase() } else { chaseTick?.invalidate(); chaseTick = nil }
        }
        .onChangeCompat(of: sym) { _ in
            if imminent { startChase() }
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            pulse = true
        }
        if imminent { startChase() }
    }

    private func startChase() {
        chaseTick?.invalidate()
        chaseIndex = 0
        // Sequential light-up: 1 → 2 → 3 → repeat (turn-signal feel).
        chaseTick = Timer.scheduledTimer(withTimeInterval: 0.32, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.16)) {
                    chaseIndex = (chaseIndex + 1) % 3
                }
            }
        }
        if let t = chaseTick {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    // MARK: - Chip (far) — compact sign board

    private var chipBody: some View {
        HStack(spacing: approaching ? 14 : 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(signFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .frame(width: approaching ? 52 : 44, height: approaching ? 52 : 44)
                arrowGlyph(size: approaching ? 28 : 22, heavy: approaching, lit: true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(distanceText)
                    .font(approaching ? .title2.weight(.bold).monospacedDigit() : .title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                if !instruction.isEmpty {
                    Text(instruction)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.88))
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
        .background(signBoard(corner: 18, hot: approaching))
    }

    // MARK: - Hero: road-sign plate + neon chase arrows

    private var signHero: some View {
        VStack(spacing: 0) {
            // Arrow row on solid sign face (readable over bright map).
            HStack(spacing: now ? 16 : 12) {
                ForEach(0..<3, id: \.self) { i in
                    chaseArrow(index: i)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 1)
                .padding(.horizontal, 16)

            VStack(spacing: 4) {
                Text(now ? "ŞİMDİ" : distanceText)
                    .font(.system(size: now ? 28 : 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text(now ? turnVerb : (instruction.isEmpty ? "Dönüş" : instruction))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(now ? "DÖN" : "DÖNÜŞE YAKLAŞ")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(now ? amber : neonCyan)
                    .tracking(1.6)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 240, maxWidth: 300)
        .background(signBoard(corner: 22, hot: true))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            (now ? amber : neonCyan).opacity(0.65),
                            Color.white.opacity(0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.6
                )
        )
        .shadow(color: .black.opacity(0.55), radius: 18, y: 8)
        .shadow(color: (now ? amber : neonCyan).opacity(0.35), radius: 16, y: 2)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    /// One of three neon chevrons — chase lights the path like a turn signal.
    private func chaseArrow(index: Int) -> some View {
        let active = chaseIndex == index
        let trail = (chaseIndex - index + 3) % 3
        let intensity: Double = {
            if active { return 1.0 }
            if trail == 1 { return 0.42 }
            return 0.16
        }()
        let accent = now ? amber : neonCyan
        let size: CGFloat = now ? 48 : 42

        return ZStack {
            // Soft neon bloom (kept small so it stays on the board).
            Image(systemName: sym)
                .font(.system(size: size, weight: .black))
                .foregroundStyle(accent.opacity(0.7 * intensity))
                .blur(radius: active ? 10 : 5)
                .scaleEffect(active ? 1.12 : 1.0)

            Image(systemName: sym)
                .font(.system(size: size * 0.94, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: active
                            ? [.white, accent, .white.opacity(0.95)]
                            : [Color.white.opacity(0.28 + 0.45 * intensity), accent.opacity(0.45 + 0.45 * intensity)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: accent.opacity(active ? 0.95 : 0.3), radius: active ? 12 : 3)
                .scaleEffect(active ? 1.08 : 0.94)
        }
        .frame(width: size + 14, height: size + 14)
        .opacity(0.4 + 0.6 * intensity)
        .animation(.easeOut(duration: 0.16), value: chaseIndex)
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

    private func arrowGlyph(size: CGFloat, heavy: Bool, lit: Bool) -> some View {
        let accent = now ? amber : neonCyan
        return ZStack {
            Image(systemName: sym)
                .font(.system(size: size, weight: .black))
                .foregroundStyle(accent.opacity(0.45))
                .blur(radius: heavy ? 6 : 3)
                .scaleEffect(pulse && heavy ? 1.06 : 1.0)
            Image(systemName: sym)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: now
                            ? [amber, .white, amber.opacity(0.9)]
                            : [ice, .white, teal],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: accent.opacity(lit ? 0.85 : 0.4), radius: heavy ? 8 : 4)
        }
    }

    /// Semi-transparent dark-gray road-sign plate (readable on light maps).
    private var signFill: Color {
        Color(red: 0.12, green: 0.13, blue: 0.15).opacity(0.82)
    }

    private func signBoard(corner: CGFloat, hot: Bool) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.19, blue: 0.21).opacity(hot ? 0.92 : 0.86),
                        Color(red: 0.08, green: 0.09, blue: 0.10).opacity(hot ? 0.88 : 0.80),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(hot ? 0.28 : 0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: hot ? 16 : 8, y: 4)
    }
}
