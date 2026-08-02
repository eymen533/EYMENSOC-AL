import SwiftUI

/// Stable day HUD — no MapKit, no Bundle resources, no giant base64 (Playgrounds crash fixes).
struct NativeHUDView: View {
    @ObservedObject var model: HUDModel
    var onBack: () -> Void

    private let bg = Color(red: 0.875, green: 0.890, blue: 0.910)
    private let ink = Color(red: 0.110, green: 0.110, blue: 0.118)
    private let muted = Color(red: 0.110, green: 0.110, blue: 0.118).opacity(0.48)
    private let control = Color(red: 0.45, green: 0.55, blue: 0.68)

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= geo.size.height * 0.95
            ZStack {
                bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    Group {
                        if wide { triad } else { portraitStack }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .preferredColorScheme(.light)
        .statusBarHidden(true)
        .onAppear {
            model.night = false
            model.start()
        }
        .onDisappear { model.stop() }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(control)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(model.dayName).font(.system(size: 12, weight: .semibold))
                Text(model.dateLine).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(ink.opacity(0.85))

            Text(model.clock.isEmpty ? "--:--" : model.clock)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink)

            Text("🕌 \(model.nextPrayer)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ink.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.55)))

            Text("\(model.outdoorC)°C")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ink.opacity(0.8))

            Text(model.bleOK ? "HUD HAZIR" : "HUD")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(muted)

            Spacer(minLength: 4)

            Button { model.toggleDrive() } label: {
                Text("HUD")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.7))
            }
            .buttonStyle(.plain)

            Text("\(Int(model.battery))%")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ink.opacity(0.75))
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var triad: some View {
        HStack(spacing: 0) {
            side(index: model.leftSlide, rail: model.leftRailVisible, trailingDots: true,
                 onNudge: { model.nudgeLeft($0) }, onDot: { model.setLeft($0) })
                .frame(maxWidth: .infinity)
            centerPanel.frame(maxWidth: .infinity).zIndex(2)
            side(index: model.rightSlide, rail: model.rightRailVisible, trailingDots: false,
                 onNudge: { model.nudgeRight($0) }, onDot: { model.setRight($0) })
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 8)
    }

    private var portraitStack: some View {
        VStack(spacing: 8) {
            centerPanel.frame(maxHeight: .infinity)
            HStack(spacing: 8) {
                side(index: model.leftSlide, rail: model.leftRailVisible, trailingDots: true,
                     onNudge: { model.nudgeLeft($0) }, onDot: { model.setLeft($0) })
                side(index: model.rightSlide, rail: model.rightRailVisible, trailingDots: false,
                     onNudge: { model.nudgeRight($0) }, onDot: { model.setRight($0) })
            }
            .frame(height: 240)
        }
        .padding(8)
    }

    private func side(
        index: Int,
        rail: Bool,
        trailingDots: Bool,
        onNudge: @escaping (Int) -> Void,
        onDot: @escaping (Int) -> Void
    ) -> some View {
        SideCarousel(
            index: index,
            railVisible: rail,
            dotsTrailing: trailingDots,
            ink: ink,
            muted: muted,
            onNudge: onNudge,
            onDot: onDot
        ) {
            slideContent(index)
        }
    }

    @ViewBuilder
    private func slideContent(_ index: Int) -> some View {
        switch index {
        case 1: tiresBlock
        case 2: mapBlock
        case 3: mediaBlock
        default: tripBlock
        }
    }

    private var tripBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            tripRow("Destination", model.destination)
            tripRow("Arrival Time", model.eta)
            tripRow("Energy at Arrival", model.energyAtArrival)
            tripRow("Distance", model.tripDist)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    private func tripRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(muted)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
        }
    }

    private var tiresBlock: some View {
        GeometryReader { geo in
            let w = min(geo.size.width * 0.92, 300)
            let h = min(geo.size.height * 0.9, 320)
            ZStack {
                ModelYTopView(stroke: ink.opacity(0.75), fill: ink.opacity(0.06))
                    .frame(width: w * 0.42, height: h * 0.75)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)

                psiText("\(model.psiFL)").position(x: w * 0.14, y: h * 0.28)
                psiText("\(model.psiFR)").position(x: w * 0.86, y: h * 0.28)
                psiText("\(model.psiRL)").position(x: w * 0.14, y: h * 0.72)
                psiText("\(model.psiRR)").position(x: w * 0.86, y: h * 0.72)
            }
            .frame(width: w, height: h)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func psiText(_ v: String) -> some View {
        HStack(spacing: 2) {
            Text(v).font(.system(size: 16, weight: .medium, design: .rounded)).monospacedDigit()
            Text("psi").font(.system(size: 11)).foregroundStyle(muted)
        }
        .foregroundStyle(ink.opacity(0.85))
    }

    /// Drawn map panel — MapKit removed (Playgrounds crash source).
    private var mapBlock: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.90, green: 0.93, blue: 0.88),
                            Color(red: 0.82, green: 0.88, blue: 0.80),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Canvas { ctx, size in
                        var path = Path()
                        let step: CGFloat = 28
                        var x: CGFloat = 0
                        while x < size.width {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                            x += step
                        }
                        var y: CGFloat = 0
                        while y < size.height {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                            y += step
                        }
                        ctx.stroke(path, with: .color(.white.opacity(0.55)), lineWidth: 1.2)
                        var route = Path()
                        route.move(to: CGPoint(x: size.width * 0.2, y: size.height * 0.8))
                        route.addQuadCurve(
                            to: CGPoint(x: size.width * 0.7, y: size.height * 0.35),
                            control: CGPoint(x: size.width * 0.55, y: size.height * 0.75)
                        )
                        ctx.stroke(route, with: .color(.red.opacity(0.75)), lineWidth: 3)
                        let pin = Path(ellipseIn: CGRect(
                            x: size.width * 0.68 - 7,
                            y: size.height * 0.36 - 7,
                            width: 14,
                            height: 14
                        ))
                        ctx.fill(pin, with: .color(.blue))
                    }
                }

            Text("N")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(ink.opacity(0.7))
                .padding(6)
                .background(Circle().fill(Color.white.opacity(0.9)))
                .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
    }

    private var mediaBlock: some View {
        VStack(spacing: 12) {
            Text(model.mediaService)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(muted)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.18, green: 0.19, blue: 0.22))
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 160)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.white.opacity(0.35))
                }

            Text(model.mediaTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ink)
            Text(model.mediaArtist)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(muted)

            HStack(spacing: 28) {
                Image(systemName: "backward.fill")
                Button { model.togglePlay() } label: {
                    Image(systemName: model.mediaPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
                Image(systemName: "forward.fill")
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(control)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
    }

    private var centerPanel: some View {
        VStack(spacing: 14) {
            HStack(spacing: 24) {
                ForEach(["P", "R", "N", "D"], id: \.self) { g in
                    Text(g)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(model.gear == g ? ink : ink.opacity(0.28))
                }
            }
            ZStack {
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.14), radius: 20, y: 8)
                VStack(spacing: 2) {
                    Text("\(Int(model.speed.rounded()))")
                        .font(.system(size: 92, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                        .monospacedDigit()
                    Text("km/h")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(muted)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 280, maxHeight: 280)
            .padding(12)
        }
    }
}

// MARK: - Top-down Model Y (vector — no image assets)

struct ModelYTopView: View {
    var stroke: Color
    var fill: Color

    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 200
            let sy = size.height / 420
            func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }

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

            ctx.fill(body, with: .color(fill))
            ctx.stroke(body, with: .color(stroke), lineWidth: 1.8)

            // glass
            var glass = Path()
            glass.move(to: P(70, 108)); glass.addLine(to: P(130, 108))
            glass.addLine(to: P(138, 162)); glass.addLine(to: P(62, 162)); glass.closeSubpath()
            ctx.stroke(glass, with: .color(stroke.opacity(0.85)), lineWidth: 1.4)

            var roof = Path()
            roof.move(to: P(72, 172)); roof.addLine(to: P(128, 172))
            roof.addLine(to: P(130, 228)); roof.addLine(to: P(70, 228)); roof.closeSubpath()
            ctx.stroke(roof, with: .color(stroke.opacity(0.7)), lineWidth: 1.2)

            // wheels
            let wheels: [(CGFloat, CGFloat)] = [(30, 104), (152, 104), (30, 272), (152, 272)]
            for (x, y) in wheels {
                let r = Path(roundedRect: CGRect(x: x * sx, y: y * sy, width: 18 * sx, height: 44 * sy), cornerRadius: 4 * sx)
                ctx.stroke(r, with: .color(stroke), lineWidth: 1.6)
            }
        }
        .aspectRatio(200 / 420, contentMode: .fit)
    }
}

// MARK: - Carousel + flash rail

private struct SideCarousel<Content: View>: View {
    let index: Int
    let railVisible: Bool
    let dotsTrailing: Bool
    let ink: Color
    let muted: Color
    var onNudge: (Int) -> Void
    var onDot: (Int) -> Void
    @ViewBuilder var content: () -> Content

    private let icons = ["flag", "circle.grid.2x2", "map", "music.note"]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                content()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .id(index)
                    .animation(.easeInOut(duration: 0.25), value: index)

                VStack(spacing: 12) {
                    ForEach(0..<HUDModel.slideCount, id: \.self) { i in
                        Button { onDot(i) } label: {
                            Image(systemName: icons[i])
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(i == index ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(Capsule().fill(Color.black.opacity(0.72)))
                .opacity(railVisible ? 1 : 0)
                .allowsHitTesting(railVisible)
                .animation(.easeOut(duration: 0.25), value: railVisible)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: dotsTrailing ? .trailing : .leading)
                .padding(dotsTrailing ? .trailing : .leading, 6)

                VStack(spacing: 6) {
                    ForEach(0..<HUDModel.slideCount, id: \.self) { i in
                        Capsule()
                            .fill(i == index ? ink.opacity(0.5) : ink.opacity(0.15))
                            .frame(width: 5, height: i == index ? 12 : 5)
                    }
                }
                .opacity(railVisible ? 0 : 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: dotsTrailing ? .trailing : .leading)
                .padding(dotsTrailing ? .trailing : .leading, 8)

                VStack {
                    Spacer()
                    Text("kaydir")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(muted.opacity(0.65))
                        .padding(.bottom, 6)
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { g in
                        if g.translation.height < -36 { onNudge(1) }
                        else if g.translation.height > 36 { onNudge(-1) }
                    }
            )
        }
        .padding(dotsTrailing ? .leading : .trailing, 8)
    }
}
