import SwiftUI
import UIKit

/// Day HUD — Tesla Model Y tires, fluid carousel, stable drawn map (no MapKit).
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
                RadialGradient(
                    colors: [Color.white.opacity(0.55), .clear],
                    center: .center,
                    startRadius: 40,
                    endRadius: max(geo.size.width, geo.size.height) * 0.55
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

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
            // Warm image decode off the tires-slide path
            _ = ModelYImageData.image
        }
        .onDisappear { model.stop() }
    }

    // MARK: Top

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
                .animation(.easeInOut(duration: 0.25), value: model.clock)

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
                .animation(.easeOut(duration: 0.35), value: model.battery)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: Layout

    private var triad: some View {
        HStack(spacing: 0) {
            side(index: model.leftSlide, rail: model.leftRailVisible, trailingDots: true,
                 onNudge: { model.nudgeLeft($0) }, onDot: { model.setLeft($0) })
                .frame(maxWidth: .infinity)
                .mask(fadeMask(leading: true))

            centerPanel
                .frame(maxWidth: .infinity)
                .zIndex(2)

            side(index: model.rightSlide, rail: model.rightRailVisible, trailingDots: false,
                 onNudge: { model.nudgeRight($0) }, onDot: { model.setRight($0) })
                .frame(maxWidth: .infinity)
                .mask(fadeMask(leading: false))
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
            .frame(height: 250)
        }
        .padding(8)
    }

    private func fadeMask(leading: Bool) -> some View {
        LinearGradient(
            colors: leading
                ? [.white, .white, .white.opacity(0.75), .clear]
                : [.clear, .white.opacity(0.75), .white, .white],
            startPoint: .leading,
            endPoint: .trailing
        )
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

    // MARK: Trip

    private var tripBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            tripRow("Destination", model.destination)
            tripRow("Arrival Time", model.eta)
            tripRow("Energy at Arrival", model.energyAtArrival)
            tripRow("Distance", model.tripDist)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
    }

    private func tripRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(muted)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
                .animation(.easeOut(duration: 0.3), value: value)
        }
    }

    // MARK: Tires + Tesla Model Y photo

    private var tiresBlock: some View {
        GeometryReader { geo in
            let w = min(geo.size.width * 0.94, 320)
            let h = min(geo.size.height * 0.92, 340)
            ZStack {
                Group {
                    if let ui = ModelYImageData.image {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                    } else {
                        ModelYTopView(stroke: ink.opacity(0.7), fill: ink.opacity(0.08))
                    }
                }
                .frame(width: w * 0.48, height: h * 0.78)
                .shadow(color: .black.opacity(0.2), radius: 14, y: 8)

                psiChip("\(model.psiFL)").position(x: w * 0.12, y: h * 0.27)
                psiChip("\(model.psiFR)").position(x: w * 0.88, y: h * 0.27)
                psiChip("\(model.psiRL)").position(x: w * 0.12, y: h * 0.73)
                psiChip("\(model.psiRR)").position(x: w * 0.88, y: h * 0.73)
            }
            .frame(width: w, height: h)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.4), value: model.psiFL)
        }
    }

    private func psiChip(_ v: String) -> some View {
        HStack(spacing: 3) {
            Text(v)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .monospacedDigit()
            Text("psi")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(muted)
        }
        .foregroundStyle(ink.opacity(0.88))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.white.opacity(0.45)))
    }

    // MARK: Map (drawn — fluid, no MapKit crash)

    private var mapBlock: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomTrailing) {
                SoftMapView()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)

                Text("N")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ink.opacity(0.7))
                    .padding(7)
                    .background(Circle().fill(Color.white.opacity(0.92)))
                    .padding(10)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .padding(8)
        }
    }

    // MARK: Media (centered)

    private var mediaBlock: some View {
        VStack(spacing: 12) {
            Text(model.mediaService)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(muted)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.24, blue: 0.28),
                            Color(red: 0.12, green: 0.13, blue: 0.15),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 168)
                .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 34, weight: .light))
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

    // MARK: Center dial

    private var centerPanel: some View {
        VStack(spacing: 14) {
            HStack(spacing: 24) {
                ForEach(["P", "R", "N", "D"], id: \.self) { g in
                    Text(g)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(model.gear == g ? ink : ink.opacity(0.28))
                        .scaleEffect(model.gear == g ? 1.08 : 1)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.gear)
                }
            }
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white, Color(red: 0.94, green: 0.95, blue: 0.97)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.14), radius: 22, y: 10)
                VStack(spacing: 2) {
                    Text("\(Int(model.speed.rounded()))")
                        .font(.system(size: 92, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.12), value: Int(model.speed.rounded()))
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

// MARK: - Soft map (no MapKit)

private struct SoftMapView: View {
    var body: some View {
        Canvas { ctx, size in
            // base
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.93, green: 0.95, blue: 0.90),
                        Color(red: 0.84, green: 0.90, blue: 0.82),
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )

            // parks
            let park = Path(ellipseIn: CGRect(x: size.width * 0.08, y: size.height * 0.12, width: size.width * 0.28, height: size.height * 0.22))
            ctx.fill(park, with: .color(Color(red: 0.72, green: 0.84, blue: 0.68).opacity(0.85)))

            // streets
            var grid = Path()
            let stepX = size.width / 7
            let stepY = size.height / 9
            for i in 1..<7 {
                let x = CGFloat(i) * stepX
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x + size.width * 0.04, y: size.height))
            }
            for j in 1..<9 {
                let y = CGFloat(j) * stepY
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y + 6))
            }
            ctx.stroke(grid, with: .color(.white.opacity(0.75)), lineWidth: 2.2)
            ctx.stroke(grid, with: .color(Color(red: 0.78, green: 0.80, blue: 0.76)), lineWidth: 0.6)

            // main avenue
            var avenue = Path()
            avenue.move(to: CGPoint(x: 0, y: size.height * 0.62))
            avenue.addQuadCurve(
                to: CGPoint(x: size.width, y: size.height * 0.48),
                control: CGPoint(x: size.width * 0.45, y: size.height * 0.7)
            )
            ctx.stroke(avenue, with: .color(.white), lineWidth: 7)
            ctx.stroke(avenue, with: .color(Color(red: 0.86, green: 0.87, blue: 0.84)), lineWidth: 1)

            // route
            var route = Path()
            route.move(to: CGPoint(x: size.width * 0.18, y: size.height * 0.82))
            route.addQuadCurve(
                to: CGPoint(x: size.width * 0.72, y: size.height * 0.34),
                control: CGPoint(x: size.width * 0.55, y: size.height * 0.78)
            )
            ctx.stroke(route, with: .color(Color(red: 0.95, green: 0.25, blue: 0.28).opacity(0.9)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

            // pin
            let px = size.width * 0.72
            let py = size.height * 0.34
            let pin = Path(ellipseIn: CGRect(x: px - 8, y: py - 8, width: 16, height: 16))
            ctx.fill(pin, with: .color(.blue))
            ctx.stroke(pin, with: .color(.white), lineWidth: 2.5)
        }
        .overlay(alignment: .topLeading) {
            Text("İstanbul")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.35))
                .padding(10)
        }
    }
}

// MARK: - Vector fallback Model Y

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

            var glass = Path()
            glass.move(to: P(70, 108)); glass.addLine(to: P(130, 108))
            glass.addLine(to: P(138, 162)); glass.addLine(to: P(62, 162)); glass.closeSubpath()
            ctx.stroke(glass, with: .color(stroke.opacity(0.85)), lineWidth: 1.4)

            for (x, y) in [(30.0, 104.0), (152.0, 104.0), (30.0, 272.0), (152.0, 272.0)] {
                let r = Path(roundedRect: CGRect(x: x * sx, y: y * sy, width: 18 * sx, height: 44 * sy), cornerRadius: 4 * sx)
                ctx.stroke(r, with: .color(stroke), lineWidth: 1.5)
            }
        }
        .aspectRatio(200 / 420, contentMode: .fit)
    }
}

// MARK: - Fluid vertical carousel

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
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 28)).combined(with: .scale(scale: 0.98)),
                            removal: .opacity.combined(with: .offset(y: -22))
                        )
                    )
                    .animation(.spring(response: 0.42, dampingFraction: 0.86), value: index)

                // Flash icon rail
                VStack(spacing: 12) {
                    ForEach(0..<HUDModel.slideCount, id: \.self) { i in
                        Button { onDot(i) } label: {
                            Image(systemName: icons[i])
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(i == index ? Color.white : Color.white.opacity(0.38))
                                .frame(width: 22, height: 22)
                                .scaleEffect(i == index ? 1.2 : 1)
                                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: index)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.72))
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                )
                .opacity(railVisible ? 1 : 0)
                .scaleEffect(railVisible ? 1 : 0.92)
                .allowsHitTesting(railVisible)
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: railVisible)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: dotsTrailing ? .trailing : .leading)
                .padding(dotsTrailing ? .trailing : .leading, 6)

                VStack(spacing: 6) {
                    ForEach(0..<HUDModel.slideCount, id: \.self) { i in
                        Capsule()
                            .fill(i == index ? ink.opacity(0.55) : ink.opacity(0.16))
                            .frame(width: 5, height: i == index ? 14 : 5)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: index)
                    }
                }
                .opacity(railVisible ? 0 : 1)
                .animation(.easeOut(duration: 0.2), value: railVisible)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: dotsTrailing ? .trailing : .leading)
                .padding(dotsTrailing ? .trailing : .leading, 8)

                VStack {
                    Spacer()
                    Text("↕ kaydır")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(muted.opacity(0.6))
                        .padding(.bottom, 6)
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { g in
                        let dy = g.translation.height
                        let vx = g.predictedEndTranslation.height
                        if dy < -30 || vx < -80 { onNudge(1) }
                        else if dy > 30 || vx > 80 { onNudge(-1) }
                    }
            )
        }
        .padding(dotsTrailing ? .leading : .trailing, 8)
    }
}
