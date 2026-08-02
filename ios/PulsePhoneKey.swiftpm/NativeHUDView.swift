import SwiftUI
import MapKit

/// Day-mode Dash HUD reference: media | white speed dial | map — native, no WebView.
struct NativeHUDView: View {
    @ObservedObject var model: HUDModel
    var onBack: () -> Void

    private let bg = Color(red: 0.875, green: 0.890, blue: 0.910) // #dfe3e8
    private let ink = Color(red: 0.110, green: 0.110, blue: 0.118) // #1c1c1e
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
            model.leftSlide = 0
            model.start()
            model.beginAfterPair()
        }
        .onDisappear { model.stop() }
    }

    // MARK: Top bar (reference)

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(control)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(model.dayName)
                    .font(.system(size: 12, weight: .semibold))
                Text(model.dateLine)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(ink.opacity(0.85))

            Text(model.clock.isEmpty ? "—" : model.clock)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink)

            HStack(spacing: 5) {
                Text("🕌")
                    .font(.system(size: 12))
                Text(model.nextPrayer)
                    .font(.system(size: 12, weight: .medium))
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
            leftPanel
                .frame(maxWidth: .infinity)
                .mask(sideFade(leading: true))
            centerPanel
                .frame(maxWidth: .infinity)
                .zIndex(2)
            rightPanel
                .frame(maxWidth: .infinity)
                .mask(sideFade(leading: false))
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 10)
    }

    private var portraitStack: some View {
        VStack(spacing: 10) {
            centerPanel.frame(maxHeight: .infinity)
            HStack(spacing: 10) {
                leftPanel.frame(maxWidth: .infinity)
                rightPanel.frame(maxWidth: .infinity)
            }
            .frame(height: 220)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
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

    // MARK: Left — Apple Music (default)

    private var leftPanel: some View {
        VStack {
            Spacer(minLength: 0)
            Group {
                switch model.leftSlide {
                case 1: tripBlock
                case 2: tiresBlock
                default: mediaBlock
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20).onEnded { g in
                    if abs(g.translation.height) > 28 { model.cycleLeft() }
                }
            )
            Spacer(minLength: 0)
            dots(active: model.leftSlide, count: 3)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 22)
                .padding(.bottom, 6)
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
    }

    private var mediaBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                .frame(maxWidth: 200)
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.white.opacity(0.35))
                }

            Text(model.mediaTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ink)
            Text(model.mediaArtist)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(muted)

            HStack(spacing: 28) {
                Button { } label: {
                    Image(systemName: "backward.fill")
                }
                Button { model.togglePlay() } label: {
                    Image(systemName: model.mediaPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                }
                Button { } label: {
                    Image(systemName: "forward.fill")
                }
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(control)
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tripBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            tripRow("Destination", model.destination)
            tripRow("Arrival Time", model.eta)
            tripRow("Energy at Arrival", model.energyAtArrival)
            tripRow("Distance", model.tripDist)
        }
    }

    private func tripRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(muted)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
        }
    }

    private var tiresBlock: some View {
        VStack(spacing: 14) {
            Text("LASTİK")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(muted)
            HStack {
                psi("FL", model.psiFL)
                psi("FR", model.psiFR)
            }
            HStack {
                psi("RL", model.psiRL)
                psi("RR", model.psiRR)
            }
        }
    }

    private func psi(_ c: String, _ v: Int) -> some View {
        VStack(spacing: 2) {
            Text(c).font(.system(size: 10, weight: .semibold)).foregroundStyle(muted)
            Text("\(v)").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(ink)
            Text("psi").font(.system(size: 10)).foregroundStyle(muted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Center — white speed dial

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

    // MARK: Right — map

    private var rightPanel: some View {
        VStack {
            Spacer(minLength: 0)
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
            .frame(maxWidth: .infinity)
            .frame(minHeight: 260, maxHeight: 340)
            .padding(.leading, 8)
            .padding(.trailing, 14)
            Spacer(minLength: 0)
        }
    }

    private func dots(active: Int, count: Int) -> some View {
        VStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == active ? ink : ink.opacity(0.22))
                    .frame(width: 6, height: i == active ? 14 : 6)
            }
        }
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
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)

            Circle()
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
                .padding(1)

            VStack(spacing: 2) {
                Text("\(Int(speed.rounded()))")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.07, green: 0.07, blue: 0.08))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("km/h")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.45))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(12)
    }
}
