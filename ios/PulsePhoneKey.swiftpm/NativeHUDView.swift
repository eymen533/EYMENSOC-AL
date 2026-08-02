import SwiftUI
import MapKit

/// Classic v14 Dash look — native SwiftUI, no WebView.
struct NativeHUDView: View {
    @ObservedObject var model: HUDModel
    var onBack: () -> Void

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= geo.size.height * 0.95
            ZStack {
                Color(red: 0.027, green: 0.031, blue: 0.039).ignoresSafeArea()
                RadialGradient(
                    colors: [Color(red: 0.07, green: 0.08, blue: 0.11), .clear],
                    center: .center,
                    startRadius: 40,
                    endRadius: max(geo.size.width, geo.size.height) * 0.55
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    if wide {
                        triad.frame(maxHeight: .infinity)
                    } else {
                        portraitStack.frame(maxHeight: .infinity)
                    }
                    bottomBar
                }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            model.night = true
            model.start()
            model.beginAfterPair()
        }
        .onDisappear { model.stop() }
    }

    private var cyan: Color { Color(red: 0.2, green: 0.9, blue: 0.75) }
    private var muted: Color { Color.white.opacity(0.48) }

    // MARK: - Top / bottom (classic Dash)

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(cyan)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(model.dayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(muted)
                Text(model.dateLine)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(muted)
            }
            Text(model.clock.isEmpty ? "—" : model.clock)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(model.nextPrayer)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.06)))
            Text("\(model.outdoorC)°C")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(muted)

            Spacer(minLength: 8)

            Text(model.bleOK ? model.bleLabel : "NO KEY")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(model.bleOK ? .black : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(model.bleOK ? cyan : Color.red.opacity(0.85)))

            Text("…\(model.vinTail)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(muted)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var bottomBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "battery.75")
                    .foregroundStyle(cyan)
                Text("\(Int(model.battery))% / \(model.rangeKm) km")
                    .foregroundStyle(cyan)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.red.opacity(0.85))
                Text(model.place)
                    .foregroundStyle(muted)
            }
            Spacer()
            Text("ODO \(odoText)km")
                .foregroundStyle(muted)
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var odoText: String {
        let n = Int(model.odometer)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    // MARK: - Triad (classic soft sides, center proud)

    private var triad: some View {
        HStack(spacing: 0) {
            leftPanel
                .frame(maxWidth: .infinity)
                .mask(
                    LinearGradient(
                        colors: [.white, .white, .white.opacity(0.55), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            centerPanel
                .frame(maxWidth: .infinity)
                .zIndex(2)
            rightPanel
                .frame(maxWidth: .infinity)
                .mask(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.55), .white, .white],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.horizontal, 4)
    }

    private var portraitStack: some View {
        VStack(spacing: 8) {
            centerPanel.frame(maxHeight: .infinity)
            HStack(spacing: 8) {
                leftPanel.frame(maxWidth: .infinity)
                rightPanel.frame(maxWidth: .infinity)
            }
            .frame(height: 210)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Left (trip / tires — swipe)

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            Group {
                if model.leftSlide == 0 { tripBlock } else { tiresBlock }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24).onEnded { g in
                    if abs(g.translation.height) > 28 { model.cycleLeft() }
                }
            )
            Spacer(minLength: 0)
            dots(active: model.leftSlide, count: 2)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 18)
                .padding(.bottom, 8)
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
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
                .tracking(1.1)
                .foregroundStyle(muted)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var tiresBlock: some View {
        VStack(spacing: 16) {
            Text("LASTİK")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(muted)
            HStack(spacing: 18) {
                psi("FL", model.psiFL)
                psi("FR", model.psiFR)
            }
            HStack(spacing: 18) {
                psi("RL", model.psiRL)
                psi("RR", model.psiRR)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func psi(_ c: String, _ v: Int) -> some View {
        VStack(spacing: 2) {
            Text(c).font(.system(size: 10, weight: .semibold)).foregroundStyle(muted)
            Text("\(v)").font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
            Text("psi").font(.system(size: 10)).foregroundStyle(muted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Center (classic speed dial)

    private var centerPanel: some View {
        VStack(spacing: 10) {
            gearRow
            telltales
            ClassicSpeedDial(speed: model.speed, powerKW: model.powerKW)
                .frame(maxWidth: 300, maxHeight: 260)
            if !model.bleOK {
                Text("Pair Vehicle → sonra cluster")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(muted)
            }
            Button(model.driving ? "Durdur" : "Sür") {
                model.toggleDrive()
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(muted)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var gearRow: some View {
        HStack(spacing: 22) {
            ForEach(["P", "R", "N", "D"], id: \.self) { g in
                Text(g)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(model.gear == g ? Color.white : Color.white.opacity(0.28))
                    .shadow(color: model.gear == g ? .white.opacity(0.35) : .clear, radius: 8)
            }
        }
    }

    private var telltales: some View {
        HStack(spacing: 14) {
            Image(systemName: "p.circle.fill").foregroundStyle(model.gear == "P" ? cyan : muted.opacity(0.35))
            Image(systemName: "steeringwheel").foregroundStyle(model.driving ? cyan : muted.opacity(0.35))
            Image(systemName: "car.side").foregroundStyle(model.bleOK ? cyan : muted.opacity(0.35))
            Image(systemName: "headlight.high").foregroundStyle(muted.opacity(0.35))
        }
        .font(.system(size: 14, weight: .semibold))
    }

    // MARK: - Right (map / media)

    private var rightPanel: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Group {
                if model.rightSlide == 0 { mapBlock } else { mediaBlock }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24).onEnded { g in
                    if abs(g.translation.height) > 28 { model.cycleRight() }
                }
            )
            Spacer(minLength: 0)
            dots(active: model.rightSlide, count: 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 18)
                .padding(.bottom, 8)
        }
        .padding(.trailing, 14)
    }

    private var mapBlock: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(initialPosition: .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            ))
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
            .disabled(true)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .colorScheme(.dark)

            Text("N")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(6)
                .background(Circle().fill(Color.black.opacity(0.45)))
                .padding(8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .padding(.leading, 10)
    }

    private var mediaBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MEDYA")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(muted)
            Text(model.mediaTitle)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text(model.mediaArtist)
                .font(.system(size: 14))
                .foregroundStyle(muted)
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    Capsule().fill(cyan).frame(width: 90, height: 4)
                }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 16)
    }

    private func dots(active: Int, count: Int) -> some View {
        VStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == active ? Color.white : Color.white.opacity(0.28))
                    .frame(width: 6, height: i == active ? 14 : 6)
            }
        }
    }
}

/// Dark circular dial like classic v14 cluster (not the teal demo ring).
struct ClassicSpeedDial: View {
    let speed: Double
    let powerKW: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.14, green: 0.15, blue: 0.18),
                            Color(red: 0.05, green: 0.055, blue: 0.07),
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 160
                    )
                )
                .shadow(color: .black.opacity(0.55), radius: 28, y: 10)

            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 10)
                .padding(10)

            Circle()
                .trim(from: 0, to: min(1, speed / 220))
                .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(14)
                .animation(.easeOut(duration: 0.12), value: speed)

            VStack(spacing: 2) {
                Text("\(Int(speed.rounded()))")
                    .font(.system(size: 92, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("km/h")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(8)
    }
}
