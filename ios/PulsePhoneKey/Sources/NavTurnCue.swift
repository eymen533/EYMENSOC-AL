import SwiftUI

/// Google Live View–style turn guidance: thick 3D blue/white chevrons + dark banner.
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

    private let liveBlue = Color(red: 0.22, green: 0.55, blue: 1.0)
    private let liveBlueHot = Color(red: 0.35, green: 0.68, blue: 1.0)
    private let amber = Color(red: 1.0, green: 0.78, blue: 0.22)

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

    // MARK: - Chip (far) — dark banner + single Live View chevron

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
                        .foregroundStyle(now ? amber : liveBlueHot)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(bannerBackground(corner: 16))
    }

    // MARK: - Hero — 3 chasing 3D chevrons + dark instruction banner

    private var liveViewHero: some View {
        VStack(spacing: 14) {
            // Floating Live View chevrons (blue face + white sides).
            HStack(spacing: now ? -2 : -6) {
                ForEach(0..<3, id: \.self) { i in
                    chaseChevron(index: i)
                }
            }
            .padding(.horizontal, 8)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 6)

            // Dark translucent banner (Live View bottom card).
            HStack(spacing: 12) {
                LiveViewChevron(heading: heading, lit: 1.0, size: 28)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(now ? "ŞİMDİ" : distanceText)
                        .font(.system(size: now ? 26 : 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(now ? turnVerb : (instruction.isEmpty ? turnVerb : instruction))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minWidth: 240, maxWidth: 300)
            .background(bannerBackground(corner: 14))
        }
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private func chaseChevron(index: Int) -> some View {
        let active = chaseIndex == index
        let trail = (chaseIndex - index + 3) % 3
        let lit: Double = {
            if active { return 1.0 }
            if trail == 1 { return 0.55 }
            return 0.22
        }()
        let size: CGFloat = now ? 64 : 56

        return LiveViewChevron(heading: heading, lit: lit, size: size)
            .frame(width: size + 10, height: size + 10)
            .scaleEffect(active ? 1.08 : 0.92)
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

    private func bannerBackground(corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Color.black.opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
    }
}

// MARK: - Heading

private enum TurnHeading {
    case left, right, straight, uturn, arrive
}

// MARK: - Live View 3D chevron (blue face + white extrusion)

/// Blocky Google Live View arrow — vibrant blue front, thick white sides.
private struct LiveViewChevron: View {
    var heading: TurnHeading
    var lit: Double
    var size: CGFloat

    private let face = Color(red: 0.20, green: 0.52, blue: 1.0)
    private let faceLit = Color(red: 0.38, green: 0.70, blue: 1.0)
    private let side = Color.white
    private let sideDim = Color(white: 0.82)

    var body: some View {
        Canvas { ctx, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let depth = max(4, size * 0.14)
            let path = chevronPath(in: CGRect(x: depth, y: depth * 0.35, width: w - depth * 1.4, height: h - depth * 1.2))

            // White extrusion (right + bottom edges) — thick 3D sides.
            var extruded = path
            extruded = extruded.offsetBy(dx: depth * 0.55, dy: depth * 0.75)
            ctx.fill(
                extruded,
                with: .color((lit > 0.5 ? side : sideDim).opacity(0.55 + 0.45 * lit))
            )

            // Blue face
            let faceColor = lit > 0.7 ? faceLit : face
            ctx.fill(path, with: .color(faceColor.opacity(0.35 + 0.65 * lit)))

            // Slight top highlight on face
            ctx.stroke(
                path,
                with: .color(Color.white.opacity(0.35 * lit)),
                lineWidth: 1.2
            )
        }
        .rotationEffect(rotation)
        .shadow(color: face.opacity(0.45 * lit), radius: lit > 0.8 ? 10 : 4, y: 2)
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

    /// Classic Live View chevron pointing right (›››).
    private func chevronPath(in rect: CGRect) -> Path {
        let midY = rect.midY
        let tipX = rect.maxX
        let backX = rect.minX
        let notch = rect.width * 0.38
        var p = Path()
        // Outer arrow head
        p.move(to: CGPoint(x: backX, y: rect.minY))
        p.addLine(to: CGPoint(x: tipX - notch * 0.15, y: midY))
        p.addLine(to: CGPoint(x: backX, y: rect.maxY))
        // Inner cut (makes › shape)
        p.addLine(to: CGPoint(x: backX + notch * 0.42, y: rect.maxY - rect.height * 0.12))
        p.addLine(to: CGPoint(x: tipX - notch, y: midY))
        p.addLine(to: CGPoint(x: backX + notch * 0.42, y: rect.minY + rect.height * 0.12))
        p.closeSubpath()
        return p
    }
}
