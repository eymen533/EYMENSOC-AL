import SwiftUI
import MapKit

/// Day HUD + classic vertical carousels on both sides (trip · tires · map · media).
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
            SideCarousel(
                index: model.leftSlide,
                dotsTrailing: true,
                ink: ink,
                muted: muted,
                onNudge: { model.nudgeLeft($0) },
                onDot: { model.setLeft($0) }
            ) {
                slideContent(model.leftSlide)
            }
            .frame(maxWidth: .infinity)
            .mask(sideFade(leading: true))

            centerPanel
                .frame(maxWidth: .infinity)
                .zIndex(2)

            SideCarousel(
                index: model.rightSlide,
                dotsTrailing: false,
                ink: ink,
                muted: muted,
                onNudge: { model.nudgeRight($0) },
                onDot: { model.setRight($0) }
            ) {
                slideContent(model.rightSlide)
            }
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
                SideCarousel(
                    index: model.leftSlide,
                    dotsTrailing: true,
                    ink: ink,
                    muted: muted,
                    onNudge: { model.nudgeLeft($0) },
                    onDot: { model.setLeft($0) }
                ) { slideContent(model.leftSlide) }
                .frame(maxWidth: .infinity)

                SideCarousel(
                    index: model.rightSlide,
                    dotsTrailing: false,
                    ink: ink,
                    muted: muted,
                    onNudge: { model.nudgeRight($0) },
                    onDot: { model.setRight($0) }
                ) { slideContent(model.rightSlide) }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 240)
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
        .padding(.horizontal, 8)
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

    private var tiresBlock: some View {
        VStack(spacing: 18) {
            Text("LASTİK")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(muted)
            HStack(spacing: 20) {
                psi("FL", model.psiFL)
                psi("FR", model.psiFR)
            }
            HStack(spacing: 20) {
                psi("RL", model.psiRL)
                psi("RR", model.psiRR)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func psi(_ c: String, _ v: Int) -> some View {
        VStack(spacing: 2) {
            Text(c).font(.system(size: 11, weight: .semibold)).foregroundStyle(muted)
            Text("\(v)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .monospacedDigit()
            Text("psi").font(.system(size: 11)).foregroundStyle(muted)
        }
        .frame(maxWidth: .infinity)
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
        .padding(6)
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
                .frame(maxWidth: 180)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: Center

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

// MARK: - Vertical carousel (Dash-style)

private struct SideCarousel<Content: View>: View {
    let index: Int
    let dotsTrailing: Bool
    let ink: Color
    let muted: Color
    var onNudge: (Int) -> Void
    var onDot: (Int) -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: dotsTrailing ? .trailing : .leading) {
                content()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .id(index)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 18)),
                        removal: .opacity.combined(with: .offset(y: -18))
                    ))
                    .animation(.easeInOut(duration: 0.35), value: index)

                VStack(spacing: 0) {
                    Spacer()
                    Text("↕ kaydır")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(muted.opacity(0.7))
                        .padding(.bottom, 8)
                }
                .allowsHitTesting(false)

                VStack(spacing: 7) {
                    ForEach(0..<HUDModel.slideCount, id: \.self) { i in
                        Button {
                            onDot(i)
                        } label: {
                            Capsule()
                                .fill(i == index ? ink : ink.opacity(0.22))
                                .frame(width: 6, height: i == index ? 16 : 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(dotsTrailing ? .trailing : .leading, 10)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { g in
                        let dy = g.translation.height
                        if dy < -36 { onNudge(1) }      // swipe up → next
                        else if dy > 36 { onNudge(-1) } // swipe down → prev
                    }
            )
        }
        .padding(dotsTrailing ? .leading : .trailing, 12)
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
                    .foregroundStyle(Color.black.opacity(0.45))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(12)
    }
}
