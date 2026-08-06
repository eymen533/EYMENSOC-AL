import SwiftUI

/// Map-integrated turn guidance — chip far away; Live-View style triple glow arrows when due.
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
    @State private var sweep = false
    /// 0…2 — which of the three arrows is lit (chase).
    @State private var chaseIndex = 0
    @State private var chaseTick: Timer?

    private var sym: String { symbol.isEmpty ? "arrow.turn.up.right" : symbol }
    private var imminent: Bool { distanceM > 0 && distanceM <= 55 }
    private var approaching: Bool { distanceM > 0 && distanceM <= 120 }
    private var now: Bool { distanceM > 0 && distanceM <= 28 }

    private let ice = Color(red: 0.72, green: 0.95, blue: 1.0)
    private let teal = Color(red: 0.18, green: 0.86, blue: 0.78)
    private let amber = Color(red: 1.0, green: 0.78, blue: 0.28)
    private let glowCyan = Color(red: 0.35, green: 0.92, blue: 1.0)

    var body: some View {
        Group {
            switch style {
            case .chip:
                chipBody
            case .mapHero:
                if imminent {
                    liveViewHero
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
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            pulse = true
        }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            sweep = true
        }
        if imminent { startChase() }
    }

    private func startChase() {
        chaseTick?.invalidate()
        chaseIndex = 0
        // Sequential light-up: 1 → 2 → 3 → repeat (Google Live View feel).
        chaseTick = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.18)) {
                    chaseIndex = (chaseIndex + 1) % 3
                }
            }
        }
        if let t = chaseTick {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    // MARK: - Chip (far)

    private var chipBody: some View {
        HStack(spacing: approaching ? 14 : 12) {
            arrowGlyph(size: approaching ? 30 : 24, heavy: approaching, lit: true)
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

    // MARK: - Live View hero (3 chasing glow arrows)

    private var liveViewHero: some View {
        VStack(spacing: 16) {
            // Soft map bloom
            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                (now ? amber : glowCyan).opacity(pulse ? 0.42 : 0.22),
                                (now ? amber : glowCyan).opacity(0.08),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 130
                        )
                    )
                    .frame(width: 280, height: 160)
                    .blur(radius: 6)

                // Three arrows side-by-side — light up in sequence.
                HStack(spacing: now ? 18 : 14) {
                    ForEach(0..<3, id: \.self) { i in
                        chaseArrow(index: i)
                    }
                }
                .padding(.horizontal, 10)
            }

            VStack(spacing: 5) {
                Text(now ? "ŞİMDİ" : distanceText)
                    .font(.system(size: now ? 30 : 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 4, y: 2)

                Text(now ? turnVerb : (instruction.isEmpty ? "Dönüş" : instruction))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(now ? "DÖN" : "DÖNÜŞE YAKLAŞ")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(now ? amber : glowCyan)
                    .tracking(1.4)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(glassBackground(corner: 16, hot: true))
        }
        .frame(maxWidth: 300)
        .transition(.scale(scale: 0.88).combined(with: .opacity))
    }

    /// One of three Live-View chevrons — glows when `chaseIndex` hits it (and stays brighter if already passed in cycle).
    private func chaseArrow(index: Int) -> some View {
        let active = chaseIndex == index
        // Trailing glow: previous arrow fades, next is dim — chase feels directional.
        let trail = (chaseIndex - index + 3) % 3
        let intensity: Double = {
            if active { return 1.0 }
            if trail == 1 { return 0.45 }
            return 0.18
        }()
        let accent = now ? amber : glowCyan
        let size: CGFloat = now ? 52 : 46

        return ZStack {
            // Outer glow bloom
            Image(systemName: sym)
                .font(.system(size: size, weight: .black))
                .foregroundStyle(accent.opacity(0.55 * intensity))
                .blur(radius: active ? 14 : 8)
                .scaleEffect(active ? 1.18 : 1.0)

            // Mid glow
            Image(systemName: sym)
                .font(.system(size: size, weight: .heavy))
                .foregroundStyle(accent.opacity(0.75 * intensity))
                .blur(radius: active ? 6 : 3)
                .scaleEffect(active ? 1.08 : 1.0)

            // Core arrow
            Image(systemName: sym)
                .font(.system(size: size * 0.92, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: active
                            ? [.white, accent, .white.opacity(0.9)]
                            : [Color.white.opacity(0.35 + 0.4 * intensity), accent.opacity(0.5 + 0.4 * intensity)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: accent.opacity(active ? 0.95 : 0.25), radius: active ? 16 : 4)
                .scaleEffect(active ? 1.1 : 0.94)
        }
        .frame(width: size + 18, height: size + 18)
        .opacity(0.35 + 0.65 * intensity)
        .animation(.easeOut(duration: 0.18), value: chaseIndex)
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
                .shadow(color: (now ? amber : teal).opacity(lit ? 0.8 : 0.4), radius: heavy ? 10 : 5)
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
