import SwiftUI

/// Turn guidance — gray sign board + white-face / neon-yellow 3D chevrons (1→2→3).
struct NavTurnCue: View {
    var distanceM: Int
    var instruction: String
    var symbol: String
    var style: Style = .chip

    enum Style {
        case chip
        case mapHero
    }

    @State private var chaseIndex = 0
    @State private var chaseTick: Timer?

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

    /// Neon yellow rim / extrusion.
    private let neonYellow = Color(red: 1.0, green: 0.92, blue: 0.15)
    private let neonYellowHot = Color(red: 1.0, green: 0.98, blue: 0.45)
    private let grayBoard = Color(red: 0.42, green: 0.43, blue: 0.45)

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
        .onAppear { if imminent { startChase() } }
        .onDisappear { chaseTick?.invalidate(); chaseTick = nil }
        .onChangeCompat(of: imminent) { hot in
            if hot { startChase() } else { chaseTick?.invalidate(); chaseTick = nil }
        }
        .onChangeCompat(of: sym) { _ in
            if imminent { startChase() }
        }
    }

    private func startChase() {
        chaseTick?.invalidate()
        chaseIndex = 0
        chaseTick = Timer.scheduledTimer(withTimeInterval: 0.34, repeats: true) { _ in
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
        HStack(spacing: 12) {
            LiveViewChevron(heading: heading, lit: 1.0, size: approaching ? 40 : 34)
                .frame(width: approaching ? 48 : 40, height: approaching ? 48 : 40)

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
                        .foregroundStyle(neonYellowHot)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(graySign(corner: 16))
    }

    // MARK: - Hero: gray board + white/neon-yellow chevrons

    private var liveViewHero: some View {
        VStack(spacing: 0) {
            // Three Live View chevrons on gray plate.
            HStack(spacing: now ? 4 : 0) {
                ForEach(0..<3, id: \.self) { i in
                    chaseChevron(index: i)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 1)
                .padding(.horizontal, 14)

            HStack(spacing: 12) {
                LiveViewChevron(heading: heading, lit: 1.0, size: 26)
                    .frame(width: 32, height: 32)

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
        }
        .frame(minWidth: 250, maxWidth: 310)
        .background(graySign(corner: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(neonYellow.opacity(0.55), lineWidth: 1.4)
        )
        .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
        .shadow(color: neonYellow.opacity(0.25), radius: 12, y: 0)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private func chaseChevron(index: Int) -> some View {
        let active = chaseIndex == index
        let trail = (chaseIndex - index + 3) % 3
        let lit: Double = {
            if active { return 1.0 }
            if trail == 1 { return 0.5 }
            return 0.2
        }()
        let size: CGFloat = now ? 62 : 54

        return LiveViewChevron(heading: heading, lit: lit, size: size)
            .frame(width: size + 8, height: size + 8)
            .scaleEffect(active ? 1.1 : 0.9)
            .opacity(0.35 + 0.65 * lit)
            .animation(.easeOut(duration: 0.18), value: chaseIndex)
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

    /// Gray sign / tabela behind arrows.
    private func graySign(corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        grayBoard.opacity(0.94),
                        Color(red: 0.28, green: 0.29, blue: 0.31).opacity(0.92),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
    }
}

// MARK: - Heading

private enum TurnHeading {
    case left, right, straight, uturn, arrive
}

// MARK: - 3D chevron — white face + neon yellow sides/border

/// Live View block arrow: solid white front, thick neon-yellow extrusion + rim.
private struct LiveViewChevron: View {
    var heading: TurnHeading
    var lit: Double
    var size: CGFloat

    private let face = Color.white
    private let neon = Color(red: 1.0, green: 0.90, blue: 0.12)
    private let neonDim = Color(red: 0.85, green: 0.72, blue: 0.08)

    var body: some View {
        Canvas { ctx, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let depth = max(5, size * 0.16)
            let path = chevronPath(in: CGRect(x: depth, y: depth * 0.35, width: w - depth * 1.4, height: h - depth * 1.2))

            // Neon-yellow 3D extrusion (sides).
            var extruded = path
            extruded = extruded.offsetBy(dx: depth * 0.55, dy: depth * 0.75)
            let sideColor = (lit > 0.55 ? neon : neonDim).opacity(0.55 + 0.45 * lit)
            ctx.fill(extruded, with: .color(sideColor))

            // White face
            ctx.fill(path, with: .color(face.opacity(0.4 + 0.6 * lit)))

            // Neon-yellow rim around white face
            ctx.stroke(
                path,
                with: .color(neon.opacity(0.55 + 0.45 * lit)),
                lineWidth: max(2.5, size * 0.055)
            )
        }
        .rotationEffect(rotation)
        .shadow(color: neon.opacity(0.55 * lit), radius: lit > 0.8 ? 12 : 5, y: 1)
    }

    private var rotation: Angle {
        switch heading {
        case .right: return .degrees(0)
        case .left: return .degrees(180)
        case .straight: return .degrees(-90)
        case .uturn: return .degrees(90)
        case .arrive: return .degrees(-90)
        }
    }

    private func chevronPath(in rect: CGRect) -> Path {
        let midY = rect.midY
        let tipX = rect.maxX
        let backX = rect.minX
        let notch = rect.width * 0.38
        var p = Path()
        p.move(to: CGPoint(x: backX, y: rect.minY))
        p.addLine(to: CGPoint(x: tipX - notch * 0.15, y: midY))
        p.addLine(to: CGPoint(x: backX, y: rect.maxY))
        p.addLine(to: CGPoint(x: backX + notch * 0.42, y: rect.maxY - rect.height * 0.12))
        p.addLine(to: CGPoint(x: tipX - notch, y: midY))
        p.addLine(to: CGPoint(x: backX + notch * 0.42, y: rect.minY + rect.height * 0.12))
        p.closeSubpath()
        return p
    }
}
