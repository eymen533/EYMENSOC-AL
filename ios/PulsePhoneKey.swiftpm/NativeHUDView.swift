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

    // MARK: - Landscape (reference screens)

    private func landscape(_ size: CGSize) -> some View {
        let dial: CGFloat = min(size.height * 0.62, size.width * 0.34, 300)
        return ZStack {
            // Map occupies right ~58%, bleeds under dial
            HStack(spacing: 0) {
                bg.frame(width: size.width * 0.38)
                IsoMapView(heading: model.driving ? 18 : -8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea()

            // Soft dark fade into map under dial
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [bg, bg.opacity(0.92), bg.opacity(0.35), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: size.width * 0.55)
                Spacer(minLength: 0)
            }
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                HStack(alignment: .center, spacing: 0) {
                    leftColumn
                        .frame(width: size.width * 0.34)
                        .padding(.leading, 10)

                    centerDial(size: dial)
                        .frame(width: dial + 24)
                        .zIndex(2)

                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)

                bottomBar
            }
            .padding(.bottom, 6)

            // Compass over map
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    compass
                        .padding(.trailing, 18)
                        .padding(.bottom, 36)
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func portrait(_ size: CGSize) -> some View {
        VStack(spacing: 0) {
            topBar
            centerDial(size: min(size.width * 0.55, 220))
                .padding(.vertical, 8)
            HStack(spacing: 0) {
                leftColumn
                IsoMapView(heading: -8)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(6)
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
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Left column + rail

    private var leftColumn: some View {
        HStack(alignment: .center, spacing: 8) {
            ZStack {
                leftSlide
                    .id(model.leftSlide)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 24)),
                            removal: .opacity.combined(with: .offset(y: -18))
                        )
                    )
                    .animation(.spring(response: 0.42, dampingFraction: 0.86), value: model.leftSlide)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { g in
                        if g.translation.height < -30 { model.nudgeLeft(1) }
                        else if g.translation.height > 30 { model.nudgeLeft(-1) }
                    }
            )

            iconRail
        }
    }

    private var iconRail: some View {
        let icons = ["flag", "car.side", "map", "music.note"]
        return VStack(spacing: 14) {
            ForEach(0..<HUDModel.slideCount, id: \.self) { i in
                Button { model.setLeft(i) } label: {
                    Image(systemName: icons[i])
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(i == model.leftSlide ? Color.white : Color.white.opacity(0.32))
                        .frame(width: 22, height: 22)
                        .scaleEffect(i == model.leftSlide ? 1.15 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(model.leftRailVisible ? 0.55 : 0.22))
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
        .opacity(model.leftRailVisible ? 1 : 0.85)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.leftRailVisible)
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
        VStack(alignment: .leading, spacing: 18) {
            tripRow("Destination", model.destination)
            tripRow("Arrival Time", model.eta)
            tripRow("Energy at Arrival", model.energyAtArrival)
            tripRow("Distance", model.tripDist)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 8)
        .padding(.top, 20)
    }

    private func tripRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(muted)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
                .animation(.easeOut(duration: 0.25), value: value)
        }
    }

    private var tiresBlock: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                ModelYWireView()
                    .frame(width: min(w * 0.42, 120), height: min(h * 0.78, 260))
                    .foregroundStyle(Color.white.opacity(0.85))

                psi(model.psiFL).position(x: w * 0.08, y: h * 0.28)
                psi(model.psiFR).position(x: w * 0.92, y: h * 0.28)
                psi(model.psiRL).position(x: w * 0.08, y: h * 0.72)
                psi(model.psiRR).position(x: w * 0.92, y: h * 0.72)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        VStack(alignment: .leading, spacing: 14) {
            Label(model.place, systemImage: "mappin.and.ellipse")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ink)
            Text(model.destination)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(muted)
            Text(model.tripDist)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
            Text("ETA \(model.eta)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(muted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 8)
        .padding(.top, 24)
    }

    private var mediaBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.mediaService)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(muted)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                .aspectRatio(1.15, contentMode: .fit)
                .frame(maxWidth: 168)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.white.opacity(0.45))
                        .scaleEffect(model.mediaPlaying ? 1.08 : 1)
                        .animation(
                            model.mediaPlaying
                                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                : .default,
                            value: model.mediaPlaying
                        )
                }
                .shadow(color: .black.opacity(0.35), radius: 12, y: 6)

            Text(model.mediaTitle)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(ink)
            Text(model.mediaArtist)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(muted)

            Button { model.togglePlay() } label: {
                Image(systemName: model.mediaPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ink.opacity(0.8))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, 8)
        .padding(.top, 12)
    }

    // MARK: - Center dial

    private func centerDial(size: CGFloat) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 22) {
                ForEach(["P", "R", "N", "D"], id: \.self) { g in
                    Text(g)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(model.gear == g ? Color.white : Color.white.opacity(0.28))
                        .scaleEffect(model.gear == g ? 1.06 : 1)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.gear)
                }
            }

            ZStack {
                Circle()
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.55), radius: 28, y: 10)
                    .overlay(
                        Circle().stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.14), Color.white.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.2
                        )
                    )

                VStack(spacing: 2) {
                    Text("\(Int(model.speed.rounded()))")
                        .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .animation(.easeOut(duration: 0.1), value: Int(model.speed.rounded()))
                    Text("km/h")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }
            .frame(width: size, height: size)

            // Power / regen bar
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: size * 0.72, height: 3)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: size * 0.72 * CGFloat(min(1, abs(model.powerKW) / 80)), height: 3)
                }
        }
    }

    // MARK: - Bottom

    private var bottomBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: "battery.100.bolt")
                    .foregroundStyle(Color(red: 0.35, green: 0.85, blue: 0.45))
                Text("\(Int(model.battery))% / \(model.rangeKm)km")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ink.opacity(0.9))
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "mappin")
                    .font(.system(size: 11, weight: .semibold))
                Text(model.place)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(ink.opacity(0.85))

            Spacer()

            Text(String(format: "ODO %.0fkm", model.odometer))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink.opacity(0.7))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    private var compass: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 34, height: 34)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            Text("N")
                .font(.system(size: 11, weight: .bold))
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

                // Soft left fade so dial blends
                ctx.fill(
                    Path(CGRect(x: 0, y: 0, width: size.width * 0.28, height: size.height)),
                    with: .linearGradient(
                        Gradient(colors: [Color.black.opacity(0.55), .clear]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width * 0.28, y: 0)
                    )
                )
            }
            .overlay {
                GeometryReader { g in
                    let labels = ["ZEYNEP SK.", "ITIR 1. SK.", "MEVLANA 1. SK.", "URTHANE CD."]
                    ForEach(Array(labels.enumerated()), id: \.offset) { i, name in
                        Text(name)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.32))
                            .position(
                                x: g.size.width * (0.22 + CGFloat(i) * 0.17),
                                y: g.size.height * (0.32 + CGFloat(i % 3) * 0.17)
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
