import SwiftUI

/// Dashla-style night triad HUD — left slides / center dial / Apple Maps · araç GPS/rota.
struct NativeHUDView: View {
    @ObservedObject var model: HUDModel
    @ObservedObject private var settings = HUDSettings.shared
    var linkLabel: String
    var onBack: () -> Void

    private let ink = Color.white
    private let muted = Color.white.opacity(0.55)
    private let dim = Color.white.opacity(0.22)
    private let accent = Color(red: 0.35, green: 0.85, blue: 0.75)

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= geo.size.height
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                Group {
                    if wide {
                        HStack(spacing: 0) {
                            leftColumn
                                .frame(width: geo.size.width * 0.28)
                            rail
                                .padding(.leading, 2)
                            centerDial
                                .frame(width: geo.size.width * 0.30)
                            mapPanel
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(spacing: 0) {
                            centerDial
                                .frame(height: max(220, geo.size.height * 0.40))
                            HStack(spacing: 0) {
                                leftColumn
                                rail.padding(.horizontal, 2)
                                mapPanel
                            }
                        }
                    }
                }
                .padding(.top, 40)
                .ignoresSafeArea(edges: .bottom)

                topBar
                    .frame(height: 40)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    // MARK: - Top bar (Dashla-like)

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ink)
            }
            Text(model.clock.isEmpty ? "--:--" : model.clock)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(ink)
            Text(model.outdoorC == 0 ? "--°C" : "\(model.outdoorC)°C")
                .font(.subheadline)
                .foregroundStyle(muted)
            Image(systemName: "car.fill")
                .font(.caption)
                .foregroundStyle(model.bleOK ? accent : dim)
            Spacer(minLength: 6)
            if !model.feedError.isEmpty || (!model.isLive && model.bleOK) {
                Label("Reconnect", systemImage: "arrow.clockwise")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            HStack(spacing: 5) {
                Image(systemName: "battery.100")
                    .font(.caption2)
                Text("\(max(0, Int(model.battery)))")
                    .font(.caption.monospacedDigit().weight(.semibold))
            }
            .foregroundStyle(ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.10)))
            Image(systemName: "gearshape.fill")
                .font(.caption)
                .foregroundStyle(muted)
        }
        .padding(.horizontal, 14)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.92), Color.black.opacity(0.35), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Rail

    private var rail: some View {
        VStack(spacing: 16) {
            ForEach(0..<HUDModel.slideCount, id: \.self) { i in
                Button { model.setLeft(i) } label: {
                    Image(systemName: HUDModel.slideIcons[i])
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(i == model.leftSlide ? ink : dim)
                        .frame(width: 26, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(i == model.leftSlide ? ink.opacity(0.7) : .clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }

    // MARK: - Left

    private var leftColumn: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black
            Group {
                switch model.leftSlide {
                case 1: tiresPanel
                case 2: tripPanel
                case 3: mapInfoPanel
                case 4: mediaPanel
                default: simplePanel
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 44)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            batteryChip
                .padding(.leading, 16)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .gesture(
            DragGesture(minimumDistance: 28)
                .onEnded { g in
                    if g.translation.height < -36 { model.nudgeLeft(1) }
                    else if g.translation.height > 36 { model.nudgeLeft(-1) }
                }
        )
    }

    private var batteryChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "battery.100")
                .foregroundStyle(Color(red: 0.35, green: 0.85, blue: 0.45))
            Text(battText)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(ink)
        }
    }

    private var battText: String {
        let pct = Int(model.battery)
        let rng = model.rangeKm
        if pct <= 0 && rng <= 0 { return "--% / --km" }
        return "\(max(0, pct))% / \(max(0, rng))km"
    }

    private var simplePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(displayOrDash(model.place))
                .font(.title3.weight(.semibold))
                .foregroundStyle(ink)
                .lineLimit(2)
            Text(linkLabel)
                .font(.caption)
                .foregroundStyle(model.bleOK ? accent : muted)
            Text(model.telemetrySource.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(model.isLive ? accent : muted)
            Spacer(minLength: 0)
        }
    }

    private var tripPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            tripRow("Destination", displayOrDash(model.destination))
            tripRow("Arrival Time", displayOrDash(model.eta))
            tripRow("Energy at Arrival", displayOrDash(model.energyAtArrival))
            tripRow("Distance", displayOrDash(model.tripDist))
            Spacer(minLength: 0)
        }
    }

    private func tripRow(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(k)
                .font(.caption)
                .foregroundStyle(muted)
            Text(v)
                .font(.title3.weight(.medium))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var tiresPanel: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack {
                Image("ModelYTop")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: min(h * 0.78, 240))
                    .opacity(0.92)
                    .colorMultiply(Color.white)
                    .accessibilityLabel("Tesla Model Y")

                VStack {
                    HStack {
                        psiLabel(model.psiFL)
                        Spacer()
                        psiLabel(model.psiFR)
                    }
                    .padding(.top, h * 0.16)
                    Spacer()
                    HStack {
                        psiLabel(model.psiRL)
                        Spacer()
                        psiLabel(model.psiRR)
                    }
                    .padding(.bottom, h * 0.14)
                }
                .padding(.horizontal, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func psiLabel(_ psi: Int) -> some View {
        Text(psi > 0 ? "\(psi) psi" : "-- psi")
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(ink.opacity(0.85))
    }

    private var mapInfoPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Map")
                .font(.caption)
                .foregroundStyle(muted)
            Text(displayOrDash(model.place))
                .font(.title3.weight(.semibold))
                .foregroundStyle(ink)
            Text(displayOrDash(model.destination))
                .font(.subheadline)
                .foregroundStyle(muted)
            Text(String(format: "%.5f, %.5f", model.latitude, model.longitude))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(dim)
            Spacer(minLength: 0)
        }
    }

    private var mediaPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(displayOrDash(model.mediaService))
                .font(.caption.weight(.semibold))
                .foregroundStyle(muted)
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.9, green: 0.35, blue: 0.2), Color(red: 0.45, green: 0.12, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
                .overlay(Image(systemName: "music.note").font(.largeTitle).foregroundStyle(.white.opacity(0.4)))
            Text(displayOrDash(model.mediaTitle))
                .font(.headline)
                .foregroundStyle(ink)
                .lineLimit(1)
            Text(displayOrDash(model.mediaArtist))
                .font(.subheadline)
                .foregroundStyle(muted)
            HStack(spacing: 20) {
                Button { model.skipTrack(-1) } label: {
                    Image(systemName: "backward.fill").foregroundStyle(ink)
                }
                .buttonStyle(.plain)
                Button { model.togglePlay() } label: {
                    Image(systemName: model.mediaPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(ink)
                }
                .buttonStyle(.plain)
                Button { model.skipTrack(1) } label: {
                    Image(systemName: "forward.fill").foregroundStyle(ink)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Center dial

    private var centerDial: some View {
        let dialSize: CGFloat = settings.speedStyle == .compact ? 168 : 210
        let speedFont: CGFloat = settings.speedStyle == .compact ? 64 : 84
        return VStack(spacing: 8) {
            Spacer(minLength: 8)
            if settings.liveLocation == .top, !isBlank(model.place) {
                locationChip
            }
            if settings.powerStyle == .top {
                Text(String(format: "%+.0f kW", model.powerKW))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(model.powerKW >= 0 ? accent : Color.orange)
            }
            HStack(spacing: 18) {
                ForEach(["P", "R", "N", "D"], id: \.self) { g in
                    Text(g)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(settings.gearColor(g, active: model.gear == g, ink: ink, dim: dim))
                        .frame(width: 26)
                }
            }
            ZStack {
                Circle()
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.6), radius: 18, x: -10, y: 0)
                if settings.powerStyle == .ring {
                    Circle()
                        .trim(from: 0, to: min(1, abs(model.powerKW) / 220))
                        .stroke(
                            AngularGradient(
                                colors: settings.speedColor == .multicolor
                                    ? [.cyan, .green, .yellow, .orange, .red]
                                    : [accent, accent],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .padding(5)
                }
                VStack(spacing: 2) {
                    Text("\(Int(abs(model.speed).rounded()))")
                        .font(.system(size: speedFont, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ink)
                        .minimumScaleFactor(0.45)
                        .lineLimit(1)
                    Text("km/h")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(muted)
                }
            }
            .frame(width: dialSize, height: dialSize)
            if settings.liveLocation == .bottom, !isBlank(model.place) {
                locationChip
            }
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [.black, .black, Color.black.opacity(0.15)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private var locationChip: some View {
        Label(model.place, systemImage: "mappin.and.ellipse")
            .font(.caption)
            .foregroundStyle(muted)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 8)
    }

    // MARK: - Google Map

    private var mapPanel: some View {
        ZStack(alignment: .bottomTrailing) {
            VehicleMapView(
                lat: model.latitude,
                lon: model.longitude,
                heading: model.mapHeading,
                destination: routeDestination,
                apiKey: model.googleMapsKey
            )
            VStack(alignment: .trailing, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 36, height: 36)
                    Text("N")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.black.opacity(0.75))
                        .offset(y: -8)
                    Image(systemName: "location.north.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .rotationEffect(.degrees(model.mapHeading))
                }
                Text(odoText)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.black.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.9)))
            }
            .padding(12)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .leading) {
            LinearGradient(
                colors: [Color.black.opacity(0.95), Color.black.opacity(0.35), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 48)
            .allowsHitTesting(false)
        }
        .clipped()
    }

    private var routeDestination: String {
        let d = model.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        if isBlank(d) { return "" }
        return d
    }

    private var odoText: String {
        model.odometer > 0 ? String(format: "ODO %.0fkm", model.odometer) : "ODO --km"
    }

    private func isBlank(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty || t == "—" || t == "-" || t == "--"
    }

    private func displayOrDash(_ s: String) -> String {
        isBlank(s) ? "--" : s
    }
}
