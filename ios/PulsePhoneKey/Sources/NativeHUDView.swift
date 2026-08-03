import SwiftUI
import UIKit

/// Dashla-style night triad — left + right swipeable panels, rails peek then hide.
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
                            sideColumn(slide: model.leftSlide, side: .left, showBattery: true)
                                .frame(width: geo.size.width * 0.24)
                            sideRail(selected: model.leftSlide, visible: model.leftRailVisible) { model.setLeft($0) }
                            centerDial
                                .frame(width: geo.size.width * 0.38)
                            sideRail(selected: model.rightSlide, visible: model.rightRailVisible) { model.setRight($0) }
                            sideColumn(slide: model.rightSlide, side: .right, showBattery: false)
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(spacing: 0) {
                            centerDial
                                .frame(height: max(220, geo.size.height * 0.40))
                            HStack(spacing: 0) {
                                sideColumn(slide: model.leftSlide, side: .left, showBattery: true)
                                sideRail(selected: model.leftSlide, visible: model.leftRailVisible) { model.setLeft($0) }
                                sideColumn(slide: model.rightSlide, side: .right, showBattery: false)
                                sideRail(selected: model.rightSlide, visible: model.rightRailVisible) { model.setRight($0) }
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
            model.pulseRails()
            UIApplication.shared.isIdleTimerDisabled = true
            MediaArtworkStore.shared.resolve(title: model.mediaTitle, artist: model.mediaArtist, album: model.mediaAlbum)
        }
        .onDisappear {
            model.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChangeCompat(of: model.mediaTitle) { _ in
            MediaArtworkStore.shared.resolve(title: model.mediaTitle, artist: model.mediaArtist, album: model.mediaAlbum)
        }
        .onChangeCompat(of: model.mediaArtist) { _ in
            MediaArtworkStore.shared.resolve(title: model.mediaTitle, artist: model.mediaArtist, album: model.mediaAlbum)
        }
        .onChangeCompat(of: model.mediaAlbum) { _ in
            MediaArtworkStore.shared.resolve(title: model.mediaTitle, artist: model.mediaArtist, album: model.mediaAlbum)
        }
    }

    private enum Side { case left, right }

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

    // MARK: - Rails (peek 2–3s then hide)

    private func sideRail(selected: Int, visible: Bool, onSelect: @escaping (Int) -> Void) -> some View {
        ZStack {
            // Always-tappable strip — tap to re-show rail when hidden.
            Color.clear
                .frame(width: 30)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { onSelect(selected) }

            VStack(spacing: 16) {
                ForEach(0..<HUDModel.slideCount, id: \.self) { i in
                    Button { onSelect(i) } label: {
                        Image(systemName: HUDModel.slideIcons[i])
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(i == selected ? ink : dim)
                            .frame(width: 26, height: 26)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(i == selected ? ink.opacity(0.7) : .clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .animation(.easeOut(duration: 0.3), value: visible)
        }
        .frame(width: 34)
    }

    // MARK: - Side columns

    private func sideColumn(slide: Int, side: Side, showBattery: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.black
            slideContent(slide, side: side)
                .padding(.horizontal, slide == 3 ? 0 : 16)
                .padding(.top, slide == 3 ? 0 : 8)
                .padding(.bottom, showBattery && slide != 3 ? 44 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if showBattery {
                batteryChip
                    .padding(.leading, 16)
                    .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { g in
                    let vertical = abs(g.translation.height) > abs(g.translation.width)
                    guard vertical else { return }
                    if side == .left {
                        if g.translation.height < -30 { model.nudgeLeft(1) }
                        else if g.translation.height > 30 { model.nudgeLeft(-1) }
                        else { model.flashLeftRail() }
                    } else {
                        if g.translation.height < -30 { model.nudgeRight(1) }
                        else if g.translation.height > 30 { model.nudgeRight(-1) }
                        else { model.flashRightRail() }
                    }
                }
        )
        .onTapGesture {
            if side == .left { model.flashLeftRail() }
            else { model.flashRightRail() }
        }
    }

    @ViewBuilder
    private func slideContent(_ slide: Int, side: Side) -> some View {
        switch slide {
        case 1: tiresPanel
        case 2: tripPanel
        case 3: mapPanel(edge: side == .left ? .trailing : .leading)
        case 4: mediaPanel
        default: simplePanel
        }
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

    private var mediaPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            mediaServiceHeader
            AlbumArtView(image: art.image, url: art.imageURL, loading: art.loading, size: 132)
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

    // MARK: - Center dial

    private var centerDial: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let dialSize: CGFloat = settings.speedStyle == .compact
                ? min(side * 0.78, 240)
                : min(side * 0.92, 320)
            let speedFont: CGFloat = settings.speedStyle == .compact
                ? dialSize * 0.42
                : dialSize * 0.48
            VStack(spacing: 6) {
                Spacer(minLength: 2)
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
                        .stroke(Color.white.opacity(0.14), lineWidth: 2)
                    Circle()
                        .fill(Color.black)
                        .padding(4)
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
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .padding(8)
                    }
                    VStack(spacing: 0) {
                        HStack(spacing: dialSize * 0.07) {
                            ForEach(["P", "R", "N", "D"], id: \.self) { g in
                                Text(g)
                                    .font(.system(size: max(14, dialSize * 0.07), weight: .bold))
                                    .foregroundStyle(settings.gearColor(g, active: model.gear == g, ink: ink, dim: dim))
                            }
                        }
                        .padding(.bottom, 4)
                        Text("\(Int(abs(model.speed).rounded()))")
                            .font(.system(size: speedFont, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(ink)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text("km/h")
                            .font(.system(size: max(12, dialSize * 0.055), weight: .medium))
                            .foregroundStyle(muted)
                    }
                }
                .frame(width: dialSize, height: dialSize)
                if settings.liveLocation == .bottom, !isBlank(model.place) {
                    locationChip
                }
                Spacer(minLength: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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

    // MARK: - Map slide (usable on left or right)

    private enum MapEdge { case leading, trailing }

    private func mapPanel(edge: MapEdge) -> some View {
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
                    .padding(.leading, edge == .leading ? 52 : 12)
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
                colors: edge == .leading
                    ? [Color.black.opacity(0.95), Color.black.opacity(0.35), .clear]
                    : [.clear, Color.black.opacity(0.35), Color.black.opacity(0.95)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 48)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge == .leading ? .leading : .trailing)
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
