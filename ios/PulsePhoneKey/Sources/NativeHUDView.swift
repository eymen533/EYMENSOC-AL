import SwiftUI
import UIKit

/// Dashla-style HUD — map tucks under center dial; both sides pick map/tires/trip/music.
struct NativeHUDView: View {
    @ObservedObject var model: HUDModel
    @ObservedObject private var settings = HUDSettings.shared
    @ObservedObject private var art = MediaArtworkStore.shared
    var linkLabel: String
    var onBack: () -> Void
    var onSettings: (() -> Void)? = nil

    @State private var mapExpanded = false

    private var night: Bool { model.night }
    private var ink: Color { night ? .white : Color(red: 0.08, green: 0.09, blue: 0.11) }
    private var muted: Color { night ? Color.white.opacity(0.55) : Color.black.opacity(0.45) }
    private var dim: Color { night ? Color.white.opacity(0.22) : Color.black.opacity(0.18) }
    private var accent: Color { Color(red: 0.20, green: 0.72, blue: 0.62) }
    private var canvas: Color {
        night ? .black : Color(red: 0.90, green: 0.91, blue: 0.93)
    }
    private var dialFill: Color {
        night ? .black : Color(red: 0.97, green: 0.97, blue: 0.98)
    }
    private var chipFill: Color {
        night ? Color.black.opacity(0.72) : Color.white.opacity(0.88)
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= geo.size.height
            ZStack(alignment: .top) {
                canvas.ignoresSafeArea()

                if mapExpanded {
                    fullscreenMap(geo: geo)
                } else if wide {
                    triadLandscape(geo: geo)
                } else {
                    triadPortrait(geo: geo)
                }

                topBar
                    .frame(height: 36)
            }
        }
        .preferredColorScheme(night ? .dark : .light)
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
        .onChangeCompat(of: model.night) { n in
            settings.mapTheme = n ? .dark : .light
        }
    }

    private enum Side { case left, right }

    // MARK: - Triad (Dashla overlap — dial dead-center)

    private func triadLandscape(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height
        // Smaller dial — leaves vertical room for side panels without clipping.
        let dialW = min(w * 0.30, h * 0.54)
        let cx = w * 0.5
        let cy = h * 0.50
        let topPad: CGFloat = 40
        let gap: CGFloat = 14
        // Hard clear zone for tires/media — never under dial.
        let sideW = max(140, (w - dialW) / 2 - gap)
        // Map still tucks under dial; non-map panels stay in clear column.
        let mapW = sideW + dialW * 0.36
        let rightIsMap = model.rightSlide == 3
        let leftIsMap = model.leftSlide == 3
        return ZStack {
            HStack(spacing: 0) {
                Group {
                    if leftIsMap {
                        mapSurface(edge: .trailing, side: .left, showTapExpand: true)
                            .frame(maxHeight: .infinity)
                    } else {
                        sideColumn(slide: model.leftSlide, side: .left, showBattery: true)
                            .frame(maxHeight: min(h - topPad - 24, dialW * 1.15))
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                }
                .frame(width: leftIsMap ? mapW : sideW)

                Spacer(minLength: 0)

                Group {
                    if rightIsMap {
                        mapSurface(edge: .leading, side: .right, showTapExpand: true)
                            .frame(maxHeight: .infinity)
                    } else {
                        sideColumn(slide: model.rightSlide, side: .right, showBattery: false)
                            .frame(maxHeight: min(h - topPad - 24, dialW * 1.15))
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                }
                .frame(width: rightIsMap ? mapW : sideW)
            }
            .padding(.top, topPad)
            .padding(.bottom, 12)

            sideRail(selected: model.leftSlide, visible: model.leftRailVisible) { model.setLeft($0) }
                .position(x: max(16, cx - dialW * 0.5 - 18), y: cy)
            sideRail(selected: model.rightSlide, visible: model.rightRailVisible) { model.setRight($0) }
                .position(x: min(w - 16, cx + dialW * 0.5 + 18), y: cy)

            dialView(size: dialW)
                .position(x: cx, y: cy)

            dialStatusStrip(maxWidth: dialW * 1.05)
                .position(x: cx, y: min(h - 22, cy + dialW * 0.5 + 18))
        }
    }

    private func triadPortrait(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height
        let dialW = min(w * 0.58, h * 0.34)
        let cx = w * 0.5
        let cy = h * 0.36
        return ZStack {
            VStack(spacing: 8) {
                sideColumn(slide: model.leftSlide, side: .left, showBattery: false)
                    .frame(height: max(140, (h - dialW) * 0.36))
                Spacer(minLength: dialW * 0.2)
                rightPanel(showTapExpand: true)
                    .frame(maxHeight: .infinity)
            }
            .padding(.top, 36)
            .padding(.horizontal, 8)

            dialView(size: dialW)
                .position(x: cx, y: cy)

            dialStatusStrip(maxWidth: dialW * 1.1)
                .position(x: cx, y: cy + dialW * 0.5 + 16)

            batteryChip
                .position(x: 70, y: h - 28)
        }
    }

    @ViewBuilder
    private func rightPanel(showTapExpand: Bool) -> some View {
        if model.rightSlide == 3 {
            mapSurface(edge: .leading, side: .right, showTapExpand: showTapExpand)
        } else {
            sideColumn(slide: model.rightSlide, side: .right, showBattery: false)
        }
    }

    // MARK: - Fullscreen map

    private func fullscreenMap(geo: GeometryProxy) -> some View {
        let dialSize = min(188, geo.size.width * 0.28)
        return ZStack(alignment: .top) {
            mapSurface(edge: .leading, side: .right, showTapExpand: false)
                .ignoresSafeArea()

            Button {
                withAnimation(.easeInOut(duration: 0.28)) { mapExpanded = false }
            } label: {
                dialView(size: dialSize, compact: true)
            }
            .buttonStyle(.plain)
            .padding(.top, 48)
            .padding(.leading, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            fullscreenCornerCard
                .padding(.top, 48)
                .padding(.trailing, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            if model.turnDistanceM > 0 || !model.turnInstruction.isEmpty {
                turnBanner
                    .padding(.top, 56)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private var fullscreenCornerCard: some View {
        let slide = model.rightSlide == 3 ? model.leftSlide : model.rightSlide
        switch slide {
        case 1: miniTiresCard
        case 2: miniTripCard
        case 4: miniMediaCard
        default: miniSimpleCard
        }
    }

    private var miniSimpleCard: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(displayOrDash(model.place))
                .font(.caption.weight(.semibold))
                .foregroundStyle(ink)
                .lineLimit(2)
            Text(linkLabel)
                .font(.caption2)
                .foregroundStyle(muted)
        }
        .padding(10)
        .frame(maxWidth: 160, alignment: .trailing)
        .background(RoundedRectangle(cornerRadius: 12).fill(chipFill))
    }

    private var miniTripCard: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(displayOrDash(model.destination))
                .font(.caption.weight(.semibold))
                .foregroundStyle(ink)
                .lineLimit(1)
            Text(displayOrDash(model.eta))
                .font(.caption2)
                .foregroundStyle(muted)
            Text(displayOrDash(model.tripDist))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(muted)
        }
        .padding(10)
        .frame(maxWidth: 170, alignment: .trailing)
        .background(RoundedRectangle(cornerRadius: 12).fill(chipFill))
    }

    private var miniMediaCard: some View {
        HStack(spacing: 10) {
            AlbumArtView(image: art.image, url: art.imageURL, loading: art.loading, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayOrDash(model.mediaTitle))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                Text(displayOrDash(model.mediaArtist))
                    .font(.caption2)
                    .foregroundStyle(muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: 140, alignment: .leading)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(chipFill))
    }

    private var miniTiresCard: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Lastik")
                .font(.caption2)
                .foregroundStyle(muted)
            HStack(spacing: 10) {
                Text(psi(model.psiFL))
                Text(psi(model.psiFR))
            }
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(ink)
            HStack(spacing: 10) {
                Text(psi(model.psiRL))
                Text(psi(model.psiRR))
            }
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(ink)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(chipFill))
    }

    private func psi(_ v: Int) -> String { v > 0 ? "\(v)" : "--" }

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

            Circle()
                .fill(model.isLive || model.bleOK ? Color.green : Color.orange.opacity(0.7))
                .frame(width: 7, height: 7)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(night ? Color.white.opacity(0.10) : Color.black.opacity(0.08)))

            HStack(spacing: 5) {
                Image(systemName: phoneBattIcon)
                    .font(.caption2)
                Text("\(model.phoneBattery > 0 ? model.phoneBattery : max(0, Int(model.battery)))%")
                    .font(.caption.monospacedDigit().weight(.semibold))
            }
            .foregroundStyle(ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(night ? Color.white.opacity(0.10) : Color.black.opacity(0.08)))

            Button { onSettings?() } label: {
                Image(systemName: "gearshape.fill")
                    .font(.caption)
                    .foregroundStyle(muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .background(
            LinearGradient(
                colors: night
                    ? [Color.black.opacity(0.92), Color.black.opacity(0.35), .clear]
                    : [canvas.opacity(0.96), canvas.opacity(0.55), .clear],
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

    // MARK: - Rails

    private func sideRail(selected: Int, visible: Bool, onSelect: @escaping (Int) -> Void) -> some View {
        ZStack {
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
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .animation(.easeOut(duration: 0.3), value: visible)
        }
        .frame(width: 34)
    }

    // MARK: - Side columns

    private func sideColumn(slide: Int, side: Side, showBattery: Bool) -> some View {
        // Keep content clear of the vertical selection rail (~34pt near dial).
        let railClear: CGFloat = 36
        return ZStack(alignment: .bottomLeading) {
            Color.clear.opacity(0.001)
            Group {
                switch slide {
                case 1: tiresPanel(side: side)
                case 2: tripPanel
                case 3: mapInfoPanel
                case 4: mediaPanel
                default: simplePanel
                }
            }
            .padding(.leading, side == .right ? railClear : 10)
            .padding(.trailing, side == .left ? railClear : 10)
            .padding(.top, 8)
            .padding(.bottom, showBattery ? 44 : 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            if showBattery {
                batteryChip
                    .padding(.leading, 16)
                    .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .gesture(sideSwipe(side: side))
        .onTapGesture {
            if side == .left { model.flashLeftRail() }
            else { model.flashRightRail() }
        }
    }

    private func sideSwipe(side: Side) -> some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { g in
                guard abs(g.translation.height) > abs(g.translation.width) else { return }
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
    }

    // MARK: - Map surface

    private func mapSurface(edge: MapEdge, side: Side, showTapExpand: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            VehicleMapView(
                lat: model.latitude,
                lon: model.longitude,
                heading: model.mapHeading,
                destination: routeDestination,
                destLat: model.destLatitude,
                destLon: model.destLongitude,
                turnByTurn: true,
                turnDistanceM: Binding(get: { model.turnDistanceM }, set: { model.turnDistanceM = $0 }),
                turnInstruction: Binding(get: { model.turnInstruction }, set: { model.turnInstruction = $0 }),
                turnSymbol: Binding(get: { model.turnSymbol }, set: { model.turnSymbol = $0 }),
                forceDark: night
            )

            // Soft fade into dial (Dashla tuck).
            if !mapExpanded {
                LinearGradient(
                    colors: edge == .leading
                        ? [canvas.opacity(0.95), canvas.opacity(0.35), .clear]
                        : [.clear, canvas.opacity(0.35), canvas.opacity(0.95)],
                    startPoint: edge == .leading ? .leading : .trailing,
                    endPoint: edge == .leading ? .trailing : .leading
                )
                .frame(width: 56)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge == .leading ? .leading : .trailing)
                .allowsHitTesting(false)
            }

            if !mapExpanded, model.turnDistanceM > 0 || !model.turnInstruction.isEmpty {
                turnBanner
                    .padding(.leading, edge == .leading ? 20 : 12)
                    .padding(.top, 10)
            }

            if !mapExpanded {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) {
                            compassBadge
                            Text(odoText)
                                .font(.caption2.monospacedDigit().weight(.semibold))
                                .foregroundStyle(night ? .white.opacity(0.9) : ink.opacity(0.85))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(chipFill))
                        }
                        .padding(12)
                    }
                }
                .allowsHitTesting(false)
            }

            if showTapExpand {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.28)) { mapExpanded = true }
                    }
                    .gesture(sideSwipe(side: side))
            }
        }
        .clipped()
    }

    private var compassBadge: some View {
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
    }

    private enum MapEdge { case leading, trailing }

    // MARK: - Dial + status under dial

    private func dialView(size: CGFloat, compact: Bool = false) -> some View {
        let speedFont = compact ? size * 0.40 : size * 0.46
        let ringW: CGFloat = compact ? 2.5 : 3.5
        let accel = CGFloat(min(1, max(0, model.powerKW) / 180.0))
        let regen = CGFloat(min(1, max(0, -model.powerKW) / 70.0))
        return ZStack {
            Circle()
                .fill(dialFill)
                .shadow(color: .black.opacity(night ? 0.65 : 0.18), radius: compact ? 10 : 22, x: 0, y: 0)
            Circle()
                .stroke(ink.opacity(0.16), lineWidth: compact ? 1.5 : 2)

            Circle()
                .trim(from: 0, to: accel)
                .stroke(
                    (night ? Color.white : Color.black).opacity(0.88),
                    style: StrokeStyle(lineWidth: ringW, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(3)
                .animation(.easeOut(duration: 0.12), value: accel)

            Circle()
                .trim(from: 0, to: regen)
                .stroke(
                    Color(red: 0.18, green: 0.78, blue: 0.40),
                    style: StrokeStyle(lineWidth: ringW, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .scaleEffect(x: -1, y: 1)
                .padding(3)
                .animation(.easeOut(duration: 0.12), value: regen)

            VStack(spacing: compact ? 0 : 2) {
                HStack(spacing: size * 0.06) {
                    ForEach(["P", "R", "N", "D"], id: \.self) { g in
                        Text(g)
                            .font(.system(size: max(11, size * 0.065), weight: .bold))
                            .foregroundStyle(settings.gearColor(g, active: model.gear == g, ink: ink, dim: dim))
                    }
                }
                Text("\(Int(abs(model.speed).rounded()))")
                    .font(.system(size: speedFont, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("km/h")
                    .font(.system(size: max(10, size * 0.05), weight: .medium))
                    .foregroundStyle(muted)
                if !compact, settings.liveLocation != .off, !isBlank(model.place) {
                    Text(model.place)
                        .font(.system(size: max(9, size * 0.045)))
                        .foregroundStyle(muted)
                        .lineLimit(1)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(width: size, height: size)
    }

    /// Doors + lights under the dial (only when relevant).
    @ViewBuilder
    private func dialStatusStrip(maxWidth: CGFloat) -> some View {
        let doors = model.openDoorLabels
        let showLights = model.anyLightOn
        if doors.isEmpty && !showLights && !model.locked {
            EmptyView()
        } else {
            VStack(spacing: 4) {
                if !doors.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "door.left.hand.open")
                            .font(.caption2.weight(.bold))
                        Text(doors.joined(separator: " · "))
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.2))
                }
                if showLights {
                    HStack(spacing: 10) {
                        if model.turnLeft {
                            Image(systemName: "arrowtriangle.left.fill")
                                .foregroundStyle(Color(red: 0.25, green: 0.85, blue: 0.4))
                        }
                        if model.lightParking {
                            Image(systemName: "light.min")
                                .foregroundStyle(muted)
                        }
                        if model.lightLow {
                            Image(systemName: "headlight.low.beam.fill")
                                .foregroundStyle(ink.opacity(0.85))
                        }
                        if model.lightHigh {
                            Image(systemName: "headlight.high.beam.fill")
                                .foregroundStyle(Color(red: 0.35, green: 0.65, blue: 1.0))
                        }
                        if model.lightFog {
                            Image(systemName: "headlight.fog.fill")
                                .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.25))
                        }
                        if model.turnRight {
                            Image(systemName: "arrowtriangle.right.fill")
                                .foregroundStyle(Color(red: 0.25, green: 0.85, blue: 0.4))
                        }
                    }
                    .font(.caption)
                }
                if model.locked, doors.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                        Text("Kilitli")
                    }
                    .font(.caption2)
                    .foregroundStyle(muted)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: maxWidth)
            .background(Capsule().fill(chipFill))
        }
    }

    // MARK: - Panels

    private var batteryChip: some View {
        HStack(spacing: 6) {
            Image(systemName: model.charging ? "bolt.fill" : "battery.100")
                .foregroundStyle(Color(red: 0.25, green: 0.78, blue: 0.40))
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
        VStack(alignment: .center, spacing: 12) {
            Text(displayOrDash(model.place))
                .font(.title3.weight(.semibold))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(linkLabel)
                .font(.caption)
                .foregroundStyle(model.bleOK ? accent : muted)
                .multilineTextAlignment(.center)
            Text(model.telemetrySource.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(model.isLive ? accent : muted)
        }
        .frame(maxWidth: 220)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var tripPanel: some View {
        VStack(alignment: .center, spacing: 16) {
            tripRow("Destination", displayOrDash(model.destination))
            tripRow("Arrival Time", displayOrDash(model.eta))
            tripRow("Energy at Arrival", displayOrDash(model.energyAtArrival))
            tripRow("Distance", displayOrDash(model.tripDist))
        }
        .frame(maxWidth: 220)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func tripRow(_ k: String, _ v: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(k)
                .font(.caption)
                .foregroundStyle(muted)
                .multilineTextAlignment(.center)
            Text(v)
                .font(.title3.weight(.medium))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func tiresPanel(side: Side) -> some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let h = max(1, geo.size.height)
            let carW = min(w * 0.92, h * 0.42)
            let carH = min(h * 0.82, carW * 2.05)
            ZStack {
                Image("ModelYTop")
                    .resizable()
                    .scaledToFit()
                    .frame(width: carW, height: carH)
                    .opacity(0.96)
                    .colorMultiply(night ? Color.white : Color(red: 0.15, green: 0.16, blue: 0.18))
                    .accessibilityLabel("Tesla Model Y")

                VStack {
                    HStack {
                        psiLabel(model.psiFL)
                        Spacer(minLength: 4)
                        psiLabel(model.psiFR)
                    }
                    .padding(.top, carH * 0.12)
                    Spacer(minLength: 0)
                    HStack {
                        psiLabel(model.psiRL)
                        Spacer(minLength: 4)
                        psiLabel(model.psiRR)
                    }
                    .padding(.bottom, carH * 0.10)
                }
                .frame(width: carW, height: carH)
            }
            .frame(width: carW, height: carH)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func psiLabel(_ psi: Int) -> some View {
        Text(psi > 0 ? "\(psi) psi" : "-- psi")
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(ink.opacity(0.85))
    }

    private var mapInfoPanel: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("Map").font(.caption).foregroundStyle(muted)
            Text(displayOrDash(model.place))
                .font(.title3.weight(.semibold))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(displayOrDash(model.destination))
                .font(.subheadline)
                .foregroundStyle(muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(String(format: "%.5f, %.5f", model.latitude, model.longitude))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(dim)
        }
        .frame(maxWidth: 220)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var mediaPanel: some View {
        GeometryReader { geo in
            let artSize = min(112, max(72, min(geo.size.width * 0.72, geo.size.height * 0.42)))
            VStack(alignment: .center, spacing: 10) {
                mediaServiceHeader
                AlbumArtView(image: art.image, url: art.imageURL, loading: art.loading, size: artSize)
                Text(displayOrDash(model.mediaTitle))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(displayOrDash(model.mediaArtist))
                    .font(.subheadline)
                    .foregroundStyle(muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .frame(maxWidth: min(200, geo.size.width))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(chipFill))
        .allowsHitTesting(false)
    }

    private var turnDistanceText: String {
        let m = model.turnDistanceM
        if m >= 1000 { return String(format: "%.1f km", Double(m) / 1000.0) }
        return "\(m) m"
    }

    private var routeDestination: String {
        let d = model.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        return isBlank(d) ? "" : d
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
