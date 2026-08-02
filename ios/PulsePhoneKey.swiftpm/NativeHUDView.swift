import SwiftUI

/// Night triad HUD matching Tesla Pulse screenshots:
/// dark left content | black speed dial | light 3D map.
/// Crash-safe: no MapKit, no UIImage/base64, no Bundle resources.
struct NativeHUDView: View {
    @ObservedObject var model: HUDModel
    var onBack: () -> Void

    private let ink = Color.white
    private let muted = Color.white.opacity(0.48)
    private let bg = Color(red: 0.027, green: 0.031, blue: 0.039)

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= geo.size.height * 0.92
            ZStack {
                bg.ignoresSafeArea()

                if wide {
                    landscape(geo.size)
                } else {
                    portrait(geo.size)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            model.night = true
            model.start()
        }
        .onDisappear { model.stop() }
    }

    // MARK: - Landscape (tight triad — no empty gap)

    private func landscape(_ size: CGSize) -> some View {
        // Dial sized to center column; map stays in right third only
        let dial = min(size.height * 0.52, size.width * 0.26, 240)
        let sideW = (size.width - dial) / 2

        return VStack(spacing: 0) {
            topBar
            HStack(spacing: 0) {
                // LEFT ~1/3
                leftColumn
                    .frame(width: sideW)
                    .frame(maxHeight: .infinity)
                    .background(bg)

                // CENTER dial — no Spacer, no gap
                centerDial(size: dial)
                    .frame(width: dial)
                    .frame(maxHeight: .infinity)
                    .background(
                        // Soft blend under dial into map
                        LinearGradient(
                            colors: [bg, bg.opacity(0.85), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .zIndex(2)

                // RIGHT map ~1/3 (not full-bleed)
                ZStack(alignment: .bottomTrailing) {
                    IsoMapView(heading: model.driving ? 12 : -6)
                    compass
                        .padding(10)
                }
                .frame(width: sideW)
                .frame(maxHeight: .infinity)
                .clipped()
                .mask(
                    LinearGradient(
                        colors: [.clear, .black, .black],
                        startPoint: .leading,
                        endPoint: UnitPoint(x: 0.18, y: 0.5)
                    )
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomBar
        }
    }

    private func portrait(_ size: CGSize) -> some View {
        let dial = min(size.width * 0.42, 200)
        return VStack(spacing: 0) {
            topBar
            centerDial(size: dial)
                .padding(.vertical, 4)
            HStack(spacing: 0) {
                leftColumn
                    .frame(maxWidth: .infinity)
                IsoMapView(heading: -6)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }
            .frame(maxHeight: .infinity)
            bottomBar
        }
    }

    // MARK: - Top

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(muted)
            }
            Text(model.clock.isEmpty ? "--:--" : model.clock)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink)
            Text("\(model.outdoorC)°C")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(muted)

            Image(systemName: "bell.slash")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(muted)
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(muted)
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(muted)

            Spacer()

            Button { model.toggleDrive() } label: {
                Label(model.driving ? "Suruyor" : "Reconnect", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                Image(systemName: "battery.50")
                Text("\(Int(model.battery))")
                    .monospacedDigit()
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ink.opacity(0.8))

            Image(systemName: "gearshape")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 36)
    }

    // MARK: - Left column + rail

    private var leftColumn: some View {
        HStack(alignment: .center, spacing: 4) {
            ZStack {
                leftSlide
                    .id(model.leftSlide)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 16)),
                            removal: .opacity.combined(with: .offset(y: -12))
                        )
                    )
                    .animation(.spring(response: 0.38, dampingFraction: 0.88), value: model.leftSlide)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.leading, 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { g in
                        if g.translation.height < -30 { model.nudgeLeft(1) }
                        else if g.translation.height > 30 { model.nudgeLeft(-1) }
                    }
            )

            iconRail
                .padding(.trailing, 2)
        }
    }

    private var iconRail: some View {
        // Avoid rare SF Symbols that may be missing in Playgrounds
        let icons = ["flag", "circle.grid.2x2", "map", "music.note"]
        return VStack(spacing: 12) {
            ForEach(0..<HUDModel.slideCount, id: \.self) { i in
                Button { model.setLeft(i) } label: {
                    Image(systemName: icons[i])
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(i == model.leftSlide ? Color.white : Color.white.opacity(0.32))
                        .frame(width: 20, height: 20)
                        .scaleEffect(i == model.leftSlide ? 1.12 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 7)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.35))
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: model.leftSlide)
    }

    @ViewBuilder
    private var leftSlide: some View {
        switch model.leftSlide {
        case 1: tiresBlock
        case 2: mapTeaser
        case 3: mediaBlock
        default: tripBlock
        }
    }

    private var tripBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            tripRow("Destination", model.destination)
            tripRow("Arrival Time", model.eta)
            tripRow("Energy at Arrival", model.energyAtArrival)
            tripRow("Distance", model.tripDist)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func tripRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(muted)
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .animation(.easeOut(duration: 0.25), value: value)
        }
    }

    private var tiresBlock: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            let carW = min(w * 0.38, 96)
            let carH = min(h * 0.72, 200)
            ZStack {
                ModelYWireView()
                    .frame(width: carW, height: carH)

                psi(model.psiFL).position(x: w * 0.10, y: h * 0.30)
                psi(model.psiFR).position(x: w * 0.90, y: h * 0.30)
                psi(model.psiRL).position(x: w * 0.10, y: h * 0.70)
                psi(model.psiRR).position(x: w * 0.90, y: h * 0.70)
            }
            .frame(width: w, height: h)
        }
    }

    private func psi(_ v: Int) -> some View {
        Text("\(v) psi")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(ink.opacity(0.85))
    }

    /// Left "map" slide — short nav cue; full map stays on the right.
    private var mapTeaser: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(model.place, systemImage: "mappin.and.ellipse")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(model.destination)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(muted)
            Text(model.tripDist)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
            Text("ETA \(model.eta)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediaBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.mediaService)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(muted)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.85, green: 0.45, blue: 0.18),
                            Color(red: 0.35, green: 0.12, blue: 0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(1.1, contentMode: .fit)
                .frame(maxWidth: 120)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.white.opacity(0.45))
                }

            Text(model.mediaTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(model.mediaArtist)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(muted)

            Button { model.togglePlay() } label: {
                Image(systemName: model.mediaPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(ink.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Center dial

    private func centerDial(size: CGFloat) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                ForEach(["P", "R", "N", "D"], id: \.self) { g in
                    Text(g)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(model.gear == g ? Color.white : Color.white.opacity(0.28))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.gear)
                }
            }

            ZStack {
                Circle()
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.45), radius: 16, y: 6)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )

                VStack(spacing: 0) {
                    Text("\(Int(model.speed.rounded()))")
                        .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .animation(.easeOut(duration: 0.1), value: Int(model.speed.rounded()))
                    Text("km/h")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }
            .frame(width: size * 0.92, height: size * 0.92)

            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: size * 0.62, height: 2.5)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: size * 0.62 * CGFloat(min(1, abs(model.powerKW) / 80)), height: 2.5)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom

    private var bottomBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Image(systemName: "battery.100.bolt")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.35, green: 0.85, blue: 0.45))
                Text("\(Int(model.battery))% / \(model.rangeKm)km")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ink.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Image(systemName: "mappin")
                    .font(.system(size: 10, weight: .semibold))
                Text(model.place)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(ink.opacity(0.85))
            .frame(maxWidth: .infinity)

            Text(String(format: "ODO %.0fkm", model.odometer))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
    }

    private var compass: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            Text("N")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.75))
        }
    }
}

// MARK: - Isometric soft map (animated, no MapKit)

private struct IsoMapView: View {
    var heading: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 18.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let drift = CGFloat(t.truncatingRemainder(dividingBy: 16) / 16)
            let pulse = 0.9 + 0.1 * sin(t * 2.2)

            Canvas { ctx, size in
                // Ground
                ctx.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(red: 0.90, green: 0.89, blue: 0.86))
                )

                // Subtle parallax grid (streets)
                let ox = drift * 36
                let oy = drift * 18
                var streets = Path()
                for i in -2..<14 {
                    let x = CGFloat(i) * 48 - ox
                    streets.move(to: CGPoint(x: x, y: 0))
                    streets.addLine(to: CGPoint(x: x + size.height * 0.55, y: size.height))
                }
                for j in -2..<12 {
                    let y = CGFloat(j) * 42 - oy
                    streets.move(to: CGPoint(x: 0, y: y))
                    streets.addLine(to: CGPoint(x: size.width, y: y + 10))
                }
                ctx.stroke(streets, with: .color(Color.white.opacity(0.85)), lineWidth: 10)
                ctx.stroke(streets, with: .color(Color(red: 0.82, green: 0.81, blue: 0.78)), lineWidth: 1)

                // Isometric building blocks
                let blocks: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
                    (0.18, 0.22, 0.12, 0.10, 0.14),
                    (0.42, 0.18, 0.16, 0.12, 0.20),
                    (0.68, 0.28, 0.14, 0.11, 0.16),
                    (0.22, 0.48, 0.13, 0.10, 0.18),
                    (0.52, 0.52, 0.18, 0.14, 0.22),
                    (0.78, 0.55, 0.12, 0.10, 0.15),
                    (0.35, 0.72, 0.15, 0.11, 0.17),
                    (0.62, 0.78, 0.14, 0.10, 0.19),
                ]
                for b in blocks {
                    let cx = size.width * b.0 + sin(t * 0.3 + b.0) * 2
                    let cy = size.height * b.1 - drift * 10
                    drawBuilding(ctx: ctx, x: cx, y: cy, w: size.width * b.2, d: size.width * b.3, h: size.height * b.4)
                }

                // Red nav chevron (near bottom-center of map)
                let ax = size.width * (0.40 + CGFloat(heading) * 0.001)
                let ay = size.height * 0.72
                var arrow = Path()
                arrow.move(to: CGPoint(x: ax, y: ay - 16 * pulse))
                arrow.addLine(to: CGPoint(x: ax + 12, y: ay + 10))
                arrow.addLine(to: CGPoint(x: ax, y: ay + 4))
                arrow.addLine(to: CGPoint(x: ax - 12, y: ay + 10))
                arrow.closeSubpath()
                ctx.fill(arrow, with: .color(Color(red: 0.92, green: 0.18, blue: 0.18)))
                ctx.stroke(arrow, with: .color(.white.opacity(0.9)), lineWidth: 1.2)

                // Thin left blend into dial
                ctx.fill(
                    Path(CGRect(x: 0, y: 0, width: size.width * 0.12, height: size.height)),
                    with: .linearGradient(
                        Gradient(colors: [Color.black.opacity(0.35), .clear]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width * 0.12, y: 0)
                    )
                )
            }
            .overlay {
                GeometryReader { g in
                    let labels = ["ZEYNEP SK.", "ITIR 1. SK.", "MEVLANA SK."]
                    ForEach(Array(labels.enumerated()), id: \.offset) { i, name in
                        Text(name)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.30))
                            .position(
                                x: g.size.width * (0.28 + CGFloat(i) * 0.22),
                                y: g.size.height * (0.28 + CGFloat(i) * 0.2)
                            )
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }

    private func drawBuilding(ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, d: CGFloat, h: CGFloat) {
        // Simple isometric prism
        let top = Path { p in
            p.move(to: CGPoint(x: x, y: y - h))
            p.addLine(to: CGPoint(x: x + w, y: y - h - d * 0.35))
            p.addLine(to: CGPoint(x: x + w + d * 0.55, y: y - h + d * 0.15))
            p.addLine(to: CGPoint(x: x + d * 0.55, y: y - h + d * 0.5))
            p.closeSubpath()
        }
        let left = Path { p in
            p.move(to: CGPoint(x: x, y: y - h))
            p.addLine(to: CGPoint(x: x + d * 0.55, y: y - h + d * 0.5))
            p.addLine(to: CGPoint(x: x + d * 0.55, y: y + d * 0.5))
            p.addLine(to: CGPoint(x: x, y: y))
            p.closeSubpath()
        }
        let right = Path { p in
            p.move(to: CGPoint(x: x + d * 0.55, y: y - h + d * 0.5))
            p.addLine(to: CGPoint(x: x + w + d * 0.55, y: y - h + d * 0.15))
            p.addLine(to: CGPoint(x: x + w + d * 0.55, y: y + d * 0.15))
            p.addLine(to: CGPoint(x: x + d * 0.55, y: y + d * 0.5))
            p.closeSubpath()
        }
        ctx.fill(top, with: .color(Color(red: 0.78, green: 0.78, blue: 0.76)))
        ctx.fill(left, with: .color(Color(red: 0.70, green: 0.70, blue: 0.68)))
        ctx.fill(right, with: .color(Color(red: 0.62, green: 0.62, blue: 0.60)))
        ctx.stroke(top, with: .color(Color.white.opacity(0.35)), lineWidth: 0.6)
    }
}

// MARK: - Wireframe Model Y (top-down, screenshot style)

private struct ModelYWireView: View {
    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 200
            let sy = size.height / 420
            func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
            let stroke = Color.white.opacity(0.85)

            var body = Path()
            body.move(to: P(72, 34))
            body.addCurve(to: P(100, 10), control1: P(72, 18), control2: P(84, 10))
            body.addCurve(to: P(128, 34), control1: P(116, 10), control2: P(128, 18))
            body.addLine(to: P(142, 72))
            body.addLine(to: P(152, 118))
            body.addLine(to: P(152, 268))
            body.addLine(to: P(142, 328))
            body.addLine(to: P(128, 386))
            body.addCurve(to: P(100, 410), control1: P(128, 402), control2: P(116, 410))
            body.addCurve(to: P(72, 386), control1: P(84, 410), control2: P(72, 402))
            body.addLine(to: P(58, 328))
            body.addLine(to: P(48, 268))
            body.addLine(to: P(48, 118))
            body.addLine(to: P(58, 72))
            body.closeSubpath()
            ctx.fill(body, with: .color(Color.white.opacity(0.06)))
            ctx.stroke(body, with: .color(stroke), lineWidth: 1.6)

            var glass = Path()
            glass.move(to: P(70, 108)); glass.addLine(to: P(130, 108))
            glass.addLine(to: P(138, 162)); glass.addLine(to: P(62, 162)); glass.closeSubpath()
            ctx.stroke(glass, with: .color(stroke.opacity(0.75)), lineWidth: 1.2)

            // Center line
            var mid = Path()
            mid.move(to: P(100, 40)); mid.addLine(to: P(100, 390))
            ctx.stroke(mid, with: .color(stroke.opacity(0.25)), lineWidth: 1)

            for (x, y) in [(28.0, 100.0), (154.0, 100.0), (28.0, 268.0), (154.0, 268.0)] {
                let r = Path(roundedRect: CGRect(x: x * sx, y: y * sy, width: 18 * sx, height: 46 * sy), cornerRadius: 4 * sx)
                ctx.stroke(r, with: .color(stroke), lineWidth: 1.4)
            }
        }
        .aspectRatio(200 / 420, contentMode: .fit)
    }
}
