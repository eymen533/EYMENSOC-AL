import SwiftUI

/// Dashla-style night triad HUD — left media / center dial / Apple Maps + turn guidance.
struct NativeHUDView: View {
    @ObservedObject var model: HUDModel
    @ObservedObject private var settings = HUDSettings.shared
    @ObservedObject private var art = MediaArtworkStore.shared
    var linkLabel: String
    var onBack: () -> Void
    var onSettings: (() -> Void)? = nil

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
                                .frame(width: geo.size.width * 0.27)
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
                .padding(.top, 36)
                .ignoresSafeArea(edges: .bottom)

                topBar
                    .frame(height: 36)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear {
            model.start()
            MediaArtworkStore.shared.resolve(title: model.mediaTitle, artist: model.mediaArtist)
        }
        .onDisappear { model.stop() }
        .onChangeCompat(of: model.mediaTitle) { _ in
            MediaArtworkStore.shared.resolve(title: model.mediaTitle, artist: model.mediaArtist)
        }
        .onChangeCompat(of: model.mediaArtist) { _ in
            MediaArtworkStore.shared.resolve(title: model.mediaTitle, artist: model.mediaArtist)
        }
    }

    // MARK: - Top bar

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
                .foregroundStyle(model.bleOK || model.isLive ? accent : dim)
            Spacer(minLength: 6)

            HStack(spacing: 6) {
                Circle()
                    .fill(model.isLive || model.bleOK ? Color.green : Color.orange.opacity(0.7))
                    .frame(width: 7, height: 7)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.10)))

            HStack(spacing: 5) {
                Image(systemName: phoneBattIcon)
                    .font(.caption2)
                Text("\(model.phoneBattery > 0 ? model.phoneBattery : max(0, Int(model.battery)))%")
                    .font(.caption.monospacedDigit().weight(.semibold))
            }
            .foregroundStyle(ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.10)))

            Button {
                onSettings?()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.caption)
                    .foregroundStyle(muted)
            }
            .buttonStyle(.plain)
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

    private var phoneBattIcon: String {
        let p = model.phoneBattery > 0 ? model.phoneBattery : Int(model.battery)
        if p >= 75 { return "battery.100" }
        if p >= 45 { return "battery.75" }
        if p >= 20 { return "battery.50" }
        return "battery.25"
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
            Image(systemName: model.charging ? "bolt.fill" : "battery.100")
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
        VStack(alignment: .leading, spacing: 12) {
            mediaServiceHeader
            AlbumArtView(image: art.image, size: 128)
            Text(displayOrDash(model.mediaTitle))
                .font(.title3.weight(.semibold))
                .foregroundStyle(ink)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Text(displayOrDash(model.mediaArtist))
                .font(.subheadline)
                .foregroundStyle(muted)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private var mediaServiceHeader: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(serviceAccent)
                    .frame(width: 22, height: 22)
                Image(systemName: serviceIcon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(displayOrDash(model.mediaService))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ink)
                .lineLimit(1)
        }
    }

    private var serviceIcon: String {
        let s = model.mediaService.lowercased()
        if s.contains("youtube") { return "play.rectangle.fill" }
        if s.contains("spotify") { return "music.note.list" }
        if s.contains("tidal") { return "waveform" }
        if s.contains("bluetooth") { return "wave.3.right" }
        return "music.note"
    }

    private var serviceAccent: Color {
        let s = model.mediaService.lowercased()
        if s.contains("youtube") { return Color(red: 0.90, green: 0.18, blue: 0.18) }
        if s.contains("spotify") { return Color(red: 0.18, green: 0.72, blue: 0.35) }
        if s.contains("tidal") { return Color(red: 0.05, green: 0.05, blue: 0.08) }
        return Color(red: 0.55, green: 0.35, blue: 0.95)
    }

    // MARK: - Center dial (gears inside ring — Dashla screenshot)

    private var centerDial: some View {
        let dialSize: CGFloat = settings.speedStyle == .compact ? 168 : 220
        let speedFont: CGFloat = settings.speedStyle == .compact ? 64 : 88
        return VStack(spacing: 6) {
            Spacer(minLength: 4)
            if settings.liveLocation == .top, !isBlank(model.place) {
                locationChip
            }
            if settings.powerStyle == .top {
                Text(String(format: "%+.0f kW", model.powerKW))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(model.powerKW >= 0 ? accent : Color.orange)
            }
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                Circle()
                    .fill(Color.black)
                    .padding(3)
                    .shadow(color: .black.opacity(0.55), radius: 16, x: -8, y: 0)
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
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .padding(7)
                }
                VStack(spacing: 2) {
                    HStack(spacing: 14) {
                        ForEach(["P", "R", "N", "D"], id: \.self) { g in
                            Text(g)
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(settings.gearColor(g, active: model.gear == g, ink: ink, dim: dim))
                        }
                    }
                    .padding(.bottom, 2)
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
            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [.black, .black, Color.black.opacity(0.12)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private var locationChip: some View {
        Label(model.place, systemImage: "mappin")
            .font(.caption)
            .foregroundStyle(muted)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 8)
    }

    // MARK: - Map

    private var mapPanel: some View {
        ZStack(alignment: .topLeading) {
            VehicleMapView(
                lat: model.latitude,
                lon: model.longitude,
                heading: model.mapHeading,
                destination: routeDestination,
                destLat: model.destLatitude,
                destLon: model.destLongitude,
                turnDistanceM: Binding(
                    get: { model.turnDistanceM },
                    set: { model.turnDistanceM = $0 }
                ),
                turnInstruction: Binding(
                    get: { model.turnInstruction },
                    set: { model.turnInstruction = $0 }
                ),
                turnSymbol: Binding(
                    get: { model.turnSymbol },
                    set: { model.turnSymbol = $0 }
                )
            )

            if model.turnDistanceM > 0 || !model.turnInstruction.isEmpty {
                turnBanner
                    .padding(.leading, 52)
                    .padding(.top, 10)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
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
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.black.opacity(0.45)))
                    }
                    .padding(12)
                }
            }
            .allowsHitTesting(false)

            LinearGradient(
                colors: [Color.black.opacity(0.95), Color.black.opacity(0.35), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 48)
            .frame(maxHeight: .infinity, alignment: .leading)
            .allowsHitTesting(false)
        }
        .clipped()
    }

    private var turnBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: model.turnSymbol.isEmpty ? "arrow.turn.up.right" : model.turnSymbol)
                .font(.title2.weight(.bold))
                .foregroundStyle(ink)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(turnDistanceText)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(ink)
                if !model.turnInstruction.isEmpty {
                    Text(model.turnInstruction)
                        .font(.caption)
                        .foregroundStyle(muted)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.72))
        )
        .allowsHitTesting(false)
    }

    private var turnDistanceText: String {
        let m = model.turnDistanceM
        if m >= 1000 {
            return String(format: "%.1f km", Double(m) / 1000.0)
        }
        return "\(m) m"
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
