import SwiftUI
import MapKit
import UIKit

/// Day HUD + carousels + Model Y tires + flashing icon rails.
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
                    colors: [Color.white.opacity(0.65), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: max(geo.size.width, geo.size.height) * 0.5
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    Group {
                        if wide { triad } else { portraitStack }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .preferredColorScheme(.light)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            model.night = false
            model.start()
            model.beginAfterPair()
        }
        .onDisappear { model.stop() }
    }

    // MARK: Top

    private var topBar: some View {
        HStack(spacing: 12) {
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

            Text(model.clock.isEmpty ? "—" : model.clock)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink)

            HStack(spacing: 5) {
                Text("🕌").font(.system(size: 12))
                Text(model.nextPrayer).font(.system(size: 12, weight: .medium))
            }
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

            Spacer(minLength: 8)

            Button { model.toggleDrive() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("HUD")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ink.opacity(0.7))
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                Image(systemName: "battery.50")
                Text("\(Int(model.battery))%")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ink.opacity(0.75))

            Image(systemName: "gearshape")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ink.opacity(0.55))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: Triad

    private var triad: some View {
        HStack(spacing: 0) {
            side(
                index: model.leftSlide,
                railVisible: model.leftRailVisible,
                dotsTrailing: true,
                onNudge: { model.nudgeLeft($0) },
                onDot: { model.setLeft($0) }
            )
            .frame(maxWidth: .infinity)
            .mask(sideFade(leading: true))

            centerPanel
                .frame(maxWidth: .infinity)
                .zIndex(2)

            side(
                index: model.rightSlide,
                railVisible: model.rightRailVisible,
                dotsTrailing: false,
                onNudge: { model.nudgeRight($0) },
                onDot: { model.setRight($0) }
            )
            .frame(maxWidth: .infinity)
            .mask(sideFade(leading: false))
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 10)
    }

    private var portraitStack: some View {
        VStack(spacing: 10) {
            centerPanel.frame(maxHeight: .infinity)
            HStack(spacing: 8) {
                side(
                    index: model.leftSlide,
                    railVisible: model.leftRailVisible,
                    dotsTrailing: true,
                    onNudge: { model.nudgeLeft($0) },
                    onDot: { model.setLeft($0) }
                )
                .frame(maxWidth: .infinity)

                side(
                    index: model.rightSlide,
                    railVisible: model.rightRailVisible,
                    dotsTrailing: false,
                    onNudge: { model.nudgeRight($0) },
                    onDot: { model.setRight($0) }
                )
                .frame(maxWidth: .infinity)
            }
            .frame(height: 260)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    private func side(
        index: Int,
        railVisible: Bool,
        dotsTrailing: Bool,
        onNudge: @escaping (Int) -> Void,
        onDot: @escaping (Int) -> Void
    ) -> some View {
        SideCarousel(
            index: index,
            railVisible: railVisible,
            dotsTrailing: dotsTrailing,
            ink: ink,
            muted: muted,
            onNudge: onNudge,
            onDot: onDot
        ) {
            slideContent(index)
        }
    }

    private func sideFade(leading: Bool) -> some View {
        LinearGradient(
            colors: leading
                ? [.white, .white, .white.opacity(0.7), .clear]
                : [.clear, .white.opacity(0.7), .white, .white],
            startPoint: .leading,
            endPoint: .trailing
        )
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

    // MARK: Slides

    private var tripBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                .tracking(1)
                .foregroundStyle(muted)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
        }
    }

    /// Photoreal Model Y + corner PSI (classic Dash tires slide).
    private var tiresBlock: some View {
        GeometryReader { geo in
            let w = min(geo.size.width * 0.92, 300.0)
            let h = min(geo.size.height * 0.9, 320.0)
            ZStack {
                ModelYPhoto()
                    .frame(width: w * 0.46, height: h * 0.72)
                    .shadow(color: .black.opacity(0.22), radius: 12, y: 6)

                psiTag("\(model.psiFL)", unit: true)
                    .position(x: w * 0.12, y: h * 0.28)
                psiTag("\(model.psiFR)", unit: true)
                    .position(x: w * 0.88, y: h * 0.28)
                psiTag("\(model.psiRL)", unit: true)
                    .position(x: w * 0.12, y: h * 0.72)
                psiTag("\(model.psiRR)", unit: true)
                    .position(x: w * 0.88, y: h * 0.72)
            }
            .frame(width: w, height: h)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func psiTag(_ value: String, unit: Bool) -> some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .monospacedDigit()
            if unit {
                Text("psi")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(muted)
            }
        }
        .foregroundStyle(ink.opacity(0.85))
    }

    private var mapBlock: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(initialPosition: .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 41.0215, longitude: 29.0210),
                    span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
                )
            ))
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .including([.publicTransport]), showsTraffic: false))
            .disabled(true)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .colorScheme(.light)

            Text("N")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(ink.opacity(0.7))
                .padding(6)
                .background(Circle().fill(Color.white.opacity(0.85)))
                .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
    }

    /// Centered media (was too left-aligned).
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
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
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
            .padding(.top, 2)
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
            DaySpeedDial(speed: model.speed)
                .frame(maxWidth: 280, maxHeight: 280)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Model Y photo from Resources/

private struct ModelYPhoto: View {
    var body: some View {
        Group {
            if let ui = Self.load() {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
            } else {
                // Fallback silhouette if resource missing
                Image(systemName: "car.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.black.opacity(0.35))
                    .padding(20)
            }
        }
    }

    private static func load() -> UIImage? {
        if let url = Bundle.module.url(forResource: "model-y-top", withExtension: "png"),
           let img = UIImage(contentsOfFile: url.path) {
            return img
        }
        // Playgrounds sometimes flattens Resources/
        if let url = Bundle.main.url(forResource: "model-y-top", withExtension: "png"),
           let img = UIImage(contentsOfFile: url.path) {
            return img
        }
        return nil
    }
}

// MARK: - Vertical carousel + flash icon rail

private struct SideCarousel<Content: View>: View {
    let index: Int
    let railVisible: Bool
    let dotsTrailing: Bool
    let ink: Color
    let muted: Color
    var onNudge: (Int) -> Void
    var onDot: (Int) -> Void
    @ViewBuilder var content: () -> Content

    /// Icons matching classic Dash select-rail (trip / tires / map / media)
    private let icons = ["square.dashed", "circle.grid.cross", "map", "music.note"]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                content()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .id(index)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: index)

                // Flash rail — appears ~1s then fades (classic Dash)
                VStack(spacing: 12) {
                    ForEach(0..<HUDModel.slideCount, id: \.self) { i in
                        Button { onDot(i) } label: {
                            Image(systemName: icons[i])
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(i == index ? Color.white : Color.white.opacity(0.38))
                                .frame(width: 22, height: 22)
                                .scaleEffect(i == index ? 1.18 : 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(
                    Capsule()
                        .fill(Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.72))
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                )
                .opacity(railVisible ? 1 : 0)
                .allowsHitTesting(railVisible)
                .animation(.easeOut(duration: 0.28), value: railVisible)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: dotsTrailing ? .trailing : .leading)
                .padding(dotsTrailing ? .trailing : .leading, 6)

                // Persistent small dots (secondary)
                VStack(spacing: 6) {
                    ForEach(0..<HUDModel.slideCount, id: \.self) { i in
                        Capsule()
                            .fill(i == index ? ink.opacity(0.55) : ink.opacity(0.15))
                            .frame(width: 5, height: i == index ? 12 : 5)
                    }
                }
                .opacity(railVisible ? 0 : 0.9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: dotsTrailing ? .trailing : .leading)
                .padding(dotsTrailing ? .trailing : .leading, 8)
                .allowsHitTesting(false)

                VStack {
                    Spacer()
                    Text("↕ kaydır")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(muted.opacity(0.65))
                        .padding(.bottom, 6)
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { g in
                        let dy = g.translation.height
                        if dy < -36 { onNudge(1) }
                        else if dy > 36 { onNudge(-1) }
                    }
            )
        }
        .padding(dotsTrailing ? .leading : .trailing, 10)
    }
}

struct DaySpeedDial: View {
    let speed: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.94, green: 0.95, blue: 0.97)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.14), radius: 22, y: 10)

            VStack(spacing: 2) {
                Text("\(Int(speed.rounded()))")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.07, green: 0.07, blue: 0.08))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("km/h")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.45))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(12)
    }
}
