import SwiftUI

/// Screenshot night triad: left slides (5) | black dial | live map.
/// Vertical swipe / icon rail switches: Sade · Lastik · Rota · Harita · Medya
struct NativeHUDView: View {
    @ObservedObject var model: HUDModel
    var onBack: () -> Void

    private let ink = Color.white
    private let muted = Color.white.opacity(0.48)
    private let bg = Color(red: 0.027, green: 0.031, blue: 0.039)

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= geo.size.height * 0.9
            ZStack {
                bg.ignoresSafeArea()
                if wide { landscape(geo.size) } else { portrait(geo.size) }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .preferredColorScheme(.dark)
        .onAppear { model.night = true; model.start() }
        .onDisappear { model.stop() }
    }

    // MARK: Landscape — map bleeds from right under dial (screenshot style)

    private func landscape(_ size: CGSize) -> some View {
        let dial = min(size.height * 0.56, size.width * 0.28, 260)
        let leftW = size.width * 0.30
        let mapW = size.width - leftW - dial * 0.55

        return ZStack {
            // Full-bleed map on right half
            HStack(spacing: 0) {
                bg.frame(width: size.width * 0.42)
                SoftMapView(heading: model.mapHeading, pulsePhase: model.mapPulse)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea()

            // Dark veil left → dial
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [bg, bg, bg.opacity(0.75), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: size.width * 0.58)
                Spacer(minLength: 0)
            }
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                HStack(alignment: .center, spacing: 0) {
                    // Left slide content
                    slideStack
                        .frame(width: leftW)
                        .frame(maxHeight: .infinity)
                        .padding(.leading, 8)

                    // Icon rail (always visible)
                    rail
                        .padding(.trailing, 4)

                    // Center dial overlapping map
                    VStack(spacing: 8) {
                        centerDial(size: dial)
                        HStack(spacing: 5) {
                            Image(systemName: "mappin")
                                .font(.system(size: 11, weight: .semibold))
                            Text(model.place)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(ink.opacity(0.85))
                    }
                    .frame(width: dial + 8)
                    .zIndex(3)

                    Spacer(minLength: 0)
                        .frame(width: max(0, mapW - dial * 0.45))
                }
                .frame(maxHeight: .infinity)

                bottomBar
            }

            // Compass on map
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    compass.padding(.trailing, 16).padding(.bottom, 34)
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func portrait(_ size: CGSize) -> some View {
        let dial = min(size.width * 0.42, 200)
        return VStack(spacing: 0) {
            topBar
            HStack(spacing: 6) {
                slideStack.frame(maxWidth: .infinity)
                rail
                centerDial(size: dial).frame(width: dial)
            }
            .frame(height: size.height * 0.42)
            SoftMapView(heading: model.mapHeading, pulsePhase: model.mapPulse)
            .frame(maxHeight: .infinity)
            .clipped()
            bottomBar
        }
    }

    // MARK: Top

    private var topBar: some View {
        HStack(spacing: 10) {
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
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(muted)
            Image(systemName: "video.slash").font(.system(size: 12)).foregroundStyle(muted)
            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 12)).foregroundStyle(muted)
            Image(systemName: "plus").font(.system(size: 13, weight: .semibold)).foregroundStyle(muted)

            Spacer()

            Text(model.telemetrySource)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(muted)

            Button { model.toggleDrive() } label: {
                Label(model.driving ? "Suruyor" : "Reconnect", systemImage: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.85))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Text("\(Int(model.battery))")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(ink.opacity(0.8))
            Image(systemName: "gearshape").font(.system(size: 13)).foregroundStyle(muted)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
    }

    // MARK: Vertical slides

    private var slideStack: some View {
        ZStack {
            slideContent(model.leftSlide)
                .id(model.leftSlide)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: model.leftSlide)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 18)
                .onEnded { g in
                    if g.translation.height < -28 || g.predictedEndTranslation.height < -70 {
                        model.nudgeLeft(1)
                    } else if g.translation.height > 28 || g.predictedEndTranslation.height > 70 {
                        model.nudgeLeft(-1)
                    }
                }
        )
    }

    private var rail: some View {
        VStack(spacing: 14) {
            ForEach(0..<HUDModel.slideCount, id: \.self) { i in
                Button { model.setLeft(i) } label: {
                    Image(systemName: HUDModel.slideIcons[i])
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(i == model.leftSlide ? Color.white : Color.white.opacity(0.30))
                        .frame(width: 22, height: 22)
                        .scaleEffect(i == model.leftSlide ? 1.18 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.45))
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: model.leftSlide)
    }

    @ViewBuilder
    private func slideContent(_ index: Int) -> some View {
        switch index {
        case 1: tiresBlock
        case 2: tripBlock
        case 3: mapInfoBlock
        case 4: mediaBlock
        default: simpleBlock
        }
    }

    /// Sade — minimal clean left
    private var simpleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PULSE")
                .font(.system(size: 13, weight: .bold))
                .tracking(2)
                .foregroundStyle(muted)
            Text(model.bleOK ? "Anahtar hazir" : "Hazir")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(ink)
            Text("…\(model.vinTail)")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(muted)
            Spacer()
            Text("kaydir · 5 ekran")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(muted.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }

    private var tripBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            tripRow("Destination", model.destination)
            tripRow("Arrival Time", model.eta)
            tripRow("Energy at Arrival", model.energyAtArrival)
            tripRow("Distance", model.tripDist)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private func tripRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(muted)
            Text(value.isEmpty ? "--" : value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    /// Tesla Model Y top-down + PSI (classic look)
    private var tiresBlock: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            let carW = min(w * 0.46, 110)
            let carH = min(h * 0.82, 240)
            ZStack {
                TeslaTopView()
                    .frame(width: carW, height: carH)
                    .shadow(color: .white.opacity(0.08), radius: 8)

                psiLabel(model.psiFL).position(x: w * 0.08, y: h * 0.28)
                psiLabel(model.psiFR).position(x: w * 0.92, y: h * 0.28)
                psiLabel(model.psiRL).position(x: w * 0.08, y: h * 0.72)
                psiLabel(model.psiRR).position(x: w * 0.92, y: h * 0.72)
            }
            .frame(width: w, height: h)
        }
    }

    private func psiLabel(_ v: Int) -> some View {
        Text("\(v) psi")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(ink.opacity(0.9))
    }

    private var mapInfoBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Harita")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(muted)
            Text(model.place)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ink)
                .lineLimit(2)
            Text(model.destination)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(muted)
            Text(String(format: "Yon %.0f°", model.mapHeading))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ink.opacity(0.85))
            Spacer()
            Text("Sagda SoftMap")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(muted.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.vertical, 14)
    }

    private var mediaBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.mediaService)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(muted)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.88, green: 0.48, blue: 0.20),
                            Color(red: 0.28, green: 0.10, blue: 0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(1.15, contentMode: .fit)
                .frame(maxWidth: 132)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)

            Text(model.mediaTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(model.mediaArtist)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(muted)

            Button { model.togglePlay() } label: {
                Image(systemName: model.mediaPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(ink.opacity(0.85))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }

    // MARK: Dial

    private func centerDial(size: CGFloat) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 18) {
                ForEach(["P", "R", "N", "D"], id: \.self) { g in
                    Text(g)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(model.gear == g ? Color.white : Color.white.opacity(0.28))
                }
            }
            ZStack {
                Circle()
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                VStack(spacing: 0) {
                    Text("\(Int(model.speed.rounded()))")
                        .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("km/h")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }
            .frame(width: size * 0.92, height: size * 0.92)

            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: size * 0.58, height: 2.5)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: size * 0.58 * CGFloat(min(1, abs(model.powerKW) / 80)), height: 2.5)
                }
        }
    }

    private var bottomBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "battery.100.bolt")
                    .foregroundStyle(Color(red: 0.35, green: 0.85, blue: 0.45))
                Text("\(Int(model.battery))% / \(model.rangeKm)km")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ink.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(HUDModel.slideNames[model.leftSlide])
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(muted)

            Text(String(format: "ODO %.0fkm", model.odometer))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 28)
    }

    private var compass: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.92)).frame(width: 30, height: 30)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            Text("N").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.black.opacity(0.75))
        }
    }
}

// MARK: - Tesla Model Y / 3 top-down wireframe (classic)

private struct TeslaTopView: View {
    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 220
            let sy = size.height / 460
            func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
            let stroke = Color.white.opacity(0.88)
            let thin = Color.white.opacity(0.55)

            // Body silhouette — Model Y proportions
            var body = Path()
            body.move(to: P(78, 40))
            body.addCurve(to: P(110, 12), control1: P(78, 22), control2: P(92, 12))
            body.addCurve(to: P(142, 40), control1: P(128, 12), control2: P(142, 22))
            body.addLine(to: P(158, 78))
            body.addLine(to: P(168, 128))
            body.addLine(to: P(168, 300))
            body.addLine(to: P(158, 360))
            body.addLine(to: P(142, 420))
            body.addCurve(to: P(110, 448), control1: P(142, 438), control2: P(128, 448))
            body.addCurve(to: P(78, 420), control1: P(92, 448), control2: P(78, 438))
            body.addLine(to: P(62, 360))
            body.addLine(to: P(52, 300))
            body.addLine(to: P(52, 128))
            body.addLine(to: P(62, 78))
            body.closeSubpath()
            ctx.fill(body, with: .color(Color.white.opacity(0.05)))
            ctx.stroke(body, with: .color(stroke), lineWidth: 1.7)

            // Glass / roof
            var roof = Path()
            roof.move(to: P(76, 118))
            roof.addLine(to: P(144, 118))
            roof.addLine(to: P(152, 175))
            roof.addLine(to: P(68, 175))
            roof.closeSubpath()
            ctx.stroke(roof, with: .color(thin), lineWidth: 1.2)

            var rearGlass = Path()
            rearGlass.move(to: P(80, 300))
            rearGlass.addLine(to: P(140, 300))
            rearGlass.addLine(to: P(148, 348))
            rearGlass.addLine(to: P(72, 348))
            rearGlass.closeSubpath()
            ctx.stroke(rearGlass, with: .color(thin), lineWidth: 1.1)

            // Center spine
            var mid = Path()
            mid.move(to: P(110, 48)); mid.addLine(to: P(110, 430))
            ctx.stroke(mid, with: .color(Color.white.opacity(0.22)), lineWidth: 1)

            // Side mirrors
            ctx.stroke(
                Path(ellipseIn: CGRect(x: 38 * sx, y: 150 * sy, width: 14 * sx, height: 10 * sy)),
                with: .color(stroke), lineWidth: 1.2
            )
            ctx.stroke(
                Path(ellipseIn: CGRect(x: 168 * sx, y: 150 * sy, width: 14 * sx, height: 10 * sy)),
                with: .color(stroke), lineWidth: 1.2
            )

            // Wheels
            for (x, y) in [(30.0, 112.0), (162.0, 112.0), (30.0, 300.0), (162.0, 300.0)] {
                let r = Path(roundedRect: CGRect(x: x * sx, y: y * sy, width: 28 * sx, height: 52 * sy), cornerRadius: 5 * sx)
                ctx.fill(r, with: .color(Color.white.opacity(0.04)))
                ctx.stroke(r, with: .color(stroke), lineWidth: 1.5)
            }
        }
        .aspectRatio(220 / 460, contentMode: .fit)
    }
}
