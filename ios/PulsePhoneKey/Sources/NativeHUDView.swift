import SwiftUI
import UIKit

/// Dashla-style HUD — map only on the selected side; tucks under center dial.
struct NativeHUDView: View {
    @ObservedObject var model: HUDModel
    @ObservedObject private var settings = HUDSettings.shared
    @ObservedObject private var art = MediaArtworkStore.shared
    var linkLabel: String
    var onBack: () -> Void
    var onSettings: (() -> Void)? = nil

    @State private var mapExpanded = false

    /// Always black cluster — vehicle day/night theme is ignored (white glare).
    private var night: Bool { true }
    private var ink: Color { .white }
    private var muted: Color { Color.white.opacity(0.55) }
    private var dim: Color { Color.white.opacity(0.22) }
    private var accent: Color { Color(red: 0.20, green: 0.72, blue: 0.62) }
    private var canvas: Color { .black }
    private var dialFill: Color { Color(red: 0.08, green: 0.08, blue: 0.09) }
    private var chipFill: Color { Color.black.opacity(0.72) }
    /// Soft blend into dial — always dark so day mode never paints white bars.
    private var fadeIntoDial: Color { Color.black }

    /// Only the map tucks under the dial. Album art stays compact (no oversize bleed).
    private var leftBleed: Bool { false }
    private var rightBleed: Bool { false }
    private var leftMap: Bool { model.leftSlide == 3 }
    private var rightMap: Bool { model.rightSlide == 3 }
    private var leftWing: Bool { leftMap }
    private var rightWing: Bool { rightMap }
    private var anyBleed: Bool { leftWing || rightWing }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= geo.size.height
            ZStack(alignment: .top) {
                canvas
                    .ignoresSafeArea()

                if mapExpanded {
                    fullscreenMap(geo: geo)
                } else if wide {
                    triadLandscape(geo: geo)
                } else {
                    triadPortrait(geo: geo)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear {
            model.start()
            model.pulseRails()
            model.night = true
            settings.mapTheme = .light
            UserDefaults.standard.set(HUDSettings.MapTheme.light.rawValue, forKey: "pulse_map_theme")
            PhoneLocationStore.shared.start()
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
        // Vehicle day/night ignored — cluster stays black.
    }

    private enum Side { case left, right }

    // MARK: - Triad (map only on the selected side; tucks under dial)

    private func triadLandscape(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height
        let dialW = min(w * 0.34, h * 0.78, 300)
        let cx = w * 0.5
        let cy = h * 0.5
        let sideW = max(140, (w - dialW) / 2)
        let tuck = dialW * 0.30
        let leftW = sideW + (leftMap ? tuck : 0)
        let rightW = sideW + (rightMap ? tuck : 0)
        let showTurn = model.turnDistanceM > 0 || !model.turnInstruction.isEmpty
        let chromeMuted = Color.white.opacity(0.78)

        return ZStack {
            Color.black

            // Left side — map only when left slide is Harita.
            Group {
                if leftMap {
                    panelMap(edge: .trailing, side: .left)
                } else {
                    sideColumn(slide: model.leftSlide, side: .left, showBattery: false)
                }
            }
            .frame(width: leftW, height: h)
            .clipShape(Rectangle())
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .zIndex(leftMap ? 0 : 1)

            // Right side — map only when right slide is Harita.
            Group {
                if rightMap {
                    panelMap(edge: .leading, side: .right)
                } else {
                    sideColumn(slide: model.rightSlide, side: .right, showBattery: false)
                }
            }
            .frame(width: rightW, height: h)
            .clipShape(Rectangle())
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .zIndex(rightMap ? 0 : 1)

            // Opaque plate under dial — hides wing seam.
            Circle()
                .fill(Color.black)
                .frame(width: dialW * 1.06, height: dialW * 1.06)
                .position(x: cx, y: cy)
                .zIndex(4)

            sideRail(selected: model.leftSlide, visible: model.leftRailVisible) { model.setLeft($0) }
                .position(x: max(16, cx - dialW * 0.5 - 14), y: cy)
                .zIndex(7)
            sideRail(selected: model.rightSlide, visible: model.rightRailVisible) { model.setRight($0) }
                .position(x: min(w - 16, cx + dialW * 0.5 + 14), y: cy)
                .zIndex(7)

            dialView(size: dialW)
                .position(x: cx, y: cy)
                .zIndex(10)

            // Turn cues sit on the map side (readable), not across whole screen.
            if showTurn {
                turnBanner
                    .frame(maxWidth: min(300, sideW * 0.95), alignment: .leading)
                    .position(
                        x: rightMap && !leftMap
                            ? (w - rightW * 0.5)
                            : (leftW * 0.5),
                        y: max(72, cy - dialW * 0.38)
                    )
                    .zIndex(12)
            }

            if !isBlank(model.destination) {
                Text(model.destination)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .position(x: cx, y: min(h - 36, cy + dialW * 0.52 + 22))
                    .zIndex(8)
            }

            dialStatusStrip(maxWidth: dialW * 1.05)
                .position(x: cx, y: min(h - 22, cy + dialW * 0.52 + 6))
                .zIndex(8)

            HStack {
                batteryChip
                Spacer()
                Text(odoText)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(chromeMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 8)
            .zIndex(8)

            floatingChrome
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .zIndex(20)
        }
        .frame(width: w, height: h)
        .clipped()
        .ignoresSafeArea()
    }

    /// Map on one side — full height, tucks under dial.
    private func panelMap(edge: MapEdge, side: Side, verticalFromTop: Bool? = nil) -> some View {
        mapSurface(
            edge: edge,
            side: side,
            showTapExpand: true,
            verticalFromTop: verticalFromTop,
            asOverlay: false
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .background(Color(red: 0.93, green: 0.94, blue: 0.95))
    }

    /// Album art same full-height tuck as map.
    private func panelMedia(edge: MapEdge, side: Side, verticalFromTop: Bool? = nil) -> some View {
        mediaSurface(
            edge: edge,
            side: side,
            verticalFromTop: verticalFromTop,
            asOverlay: false
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .background(Color.black)
    }

    @ViewBuilder
    private func bleedSurface(
        slide: Int,
        edge: MapEdge,
        side: Side,
        verticalFromTop: Bool? = nil,
        asOverlay: Bool = false
    ) -> some View {
        if slide == 4 {
            panelMedia(edge: edge, side: side, verticalFromTop: verticalFromTop)
        } else if slide == 3 {
            panelMap(edge: edge, side: side, verticalFromTop: verticalFromTop)
        } else {
            mediaSurface(edge: edge, side: side, verticalFromTop: verticalFromTop, asOverlay: asOverlay)
        }
    }

    private func triadPortrait(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height
        let dialW = min(w * 0.46, h * 0.26, 200)
        let tuck = dialW * 0.26
        let showTurn = model.turnDistanceM > 0 || !model.turnInstruction.isEmpty
        let topChrome: CGFloat = 52
        let wingH = max(96, (h - dialW - topChrome) / 2)
        let cx = w * 0.5
        let cy = topChrome + wingH + dialW * 0.5
        let topWing = leftMap
        let bottomWing = rightMap
        let topH = wingH + (topWing ? tuck : 0)
        let bottomH = wingH + (bottomWing ? tuck : 0)

        return ZStack {
            Color.black

            Group {
                if leftMap {
                    panelMap(edge: .trailing, side: .left, verticalFromTop: false)
                } else {
                    sideColumn(slide: model.leftSlide, side: .left, showBattery: false)
                }
            }
            .frame(width: w, height: topH)
            .clipShape(Rectangle())
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, topChrome)
            .zIndex(topWing ? 0 : 1)

            Group {
                if rightMap {
                    panelMap(edge: .leading, side: .right, verticalFromTop: true)
                } else {
                    sideColumn(slide: model.rightSlide, side: .right, showBattery: false)
                }
            }
            .frame(width: w, height: bottomH)
            .clipShape(Rectangle())
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .zIndex(bottomWing ? 0 : 1)

            Circle()
                .fill(Color.black)
                .frame(width: dialW * 1.08, height: dialW * 1.08)
                .position(x: cx, y: cy)
                .zIndex(4)

            dialView(size: dialW)
                .position(x: cx, y: cy)
                .zIndex(10)

            if showTurn {
                turnBanner
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: topWing ? .top : .bottom)
                    .padding(.top, topWing ? topChrome + 8 : 0)
                    .padding(.bottom, bottomWing && !topWing ? 48 : 0)
                    .zIndex(12)
            }

            if !isBlank(model.destination) {
                Text(model.destination)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .position(x: cx, y: min(h - 44, cy + dialW * 0.55 + 24))
                    .zIndex(8)
            }

            dialStatusStrip(maxWidth: dialW * 1.05)
                .position(x: cx, y: min(h - 32, cy + dialW * 0.55 + 8))
                .zIndex(8)

            batteryChip
                .position(x: 74, y: h - 22)
                .zIndex(8)

            floatingChrome
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .zIndex(20)
        }
        .frame(width: w, height: h)
        .clipped()
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func rightPanel(showTapExpand: Bool) -> some View {
        if model.rightSlide == 3 {
            mapSurface(edge: .leading, side: .right, showTapExpand: showTapExpand, verticalFromTop: nil, asOverlay: false)
        } else if model.rightSlide == 4 {
            mediaSurface(edge: .leading, side: .right, verticalFromTop: nil, asOverlay: false)
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
            .zIndex(10)

            fullscreenCornerCard
                .padding(.top, 48)
                .padding(.trailing, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .zIndex(10)

            if model.turnDistanceM > 0 || !model.turnInstruction.isEmpty {
                turnBanner
                    .padding(.top, 56)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .zIndex(12)
            }

            floatingChrome
                .zIndex(20)
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

    // MARK: - Floating chrome (no solid top bar)

    private var floatingChrome: some View {
        let barInk = Color.white
        let barMuted = Color.white.opacity(0.78)
        return HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(barInk)
                    .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
            }
            Text(model.clock.isEmpty ? "--:--" : model.clock)
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(barInk)
                .shadow(color: .black.opacity(0.75), radius: 3, y: 1)
            Text(BLEPairer.buildId)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color(red: 1.0, green: 0.75, blue: 0.05)))
            Text(model.outdoorC == 0 ? "--°C" : "\(model.outdoorC)°C")
                .font(.body)
                .foregroundStyle(barMuted)
                .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
            Image(systemName: "car.fill")
                .font(.subheadline)
                .foregroundStyle(model.bleOK || model.isLive ? accent : barMuted.opacity(0.5))
                .shadow(color: .black.opacity(0.6), radius: 2, y: 1)

            Spacer(minLength: 6)

            Circle()
                .fill(model.isLive || model.bleOK ? Color.green : Color.orange.opacity(0.7))
                .frame(width: 8, height: 8)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.4)))

            HStack(spacing: 5) {
                Image(systemName: phoneBattIcon)
                    .font(.caption)
                Text("\(model.phoneBattery > 0 ? model.phoneBattery : max(0, Int(model.battery)))%")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
            .foregroundStyle(barInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.4)))

            Button { onSettings?() } label: {
                Image(systemName: "gearshape.fill")
                    .font(.subheadline)
                    .foregroundStyle(barMuted)
                    .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .top)
        // Slim chrome strip — map stays side-only beneath (not full-bleed).
        .background(Color.black.opacity(0.92))
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
            // Full opaque black — blocks MapKit bleed into this panel (including corners).
            Color.black
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
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

    private func mapSurface(
        edge: MapEdge,
        side: Side,
        showTapExpand: Bool,
        verticalFromTop: Bool? = nil,
        asOverlay: Bool = false
    ) -> some View {
        ZStack(alignment: .topLeading) {
            if !asOverlay {
                VehicleMapView(
                    lat: model.latitude,
                    lon: model.longitude,
                    heading: model.mapHeading,
                    destination: routeDestination,
                    destLat: model.destLatitude,
                    destLon: model.destLongitude,
                    apiKey: model.googleMapsKey,
                    turnByTurn: true,
                    turnDistanceM: Binding(get: { model.turnDistanceM }, set: { model.turnDistanceM = $0 }),
                    turnInstruction: Binding(get: { model.turnInstruction }, set: { model.turnInstruction = $0 }),
                    turnSymbol: Binding(get: { model.turnSymbol }, set: { model.turnSymbol = $0 })
                )
            }

            if !mapExpanded {
                if let verticalFromTop {
                    dialFadeVertical(fromTop: verticalFromTop)
                } else {
                    dialFade(edge: edge)
                }
            }

            // Route status when GPS coords missing but destination known.
            if !mapExpanded, !hasMapGPS, !isBlank(model.destination) {
                Text(model.destination)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.55)))
                    .padding(12)
            } else if !mapExpanded, !hasMapGPS, abs(model.destLatitude) < 0.0001, abs(model.destLongitude) < 0.0001 {
                Text("Konum izni / GPS bekleniyor")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
                    .padding(12)
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

    /// Album art fills the panel and tucks under the dial like the map.
    private func mediaSurface(
        edge: MapEdge,
        side: Side,
        verticalFromTop: Bool? = nil,
        asOverlay: Bool = false
    ) -> some View {
        ZStack {
            if !asOverlay {
                AlbumArtFill(image: art.image, url: art.imageURL, loading: art.loading)
            }

            if let verticalFromTop {
                dialFadeVertical(fromTop: verticalFromTop)
            } else {
                dialFade(edge: edge)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.45), .black.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 8) {
                Spacer(minLength: 0)
                mediaServiceHeader
                Text(displayOrDash(model.mediaTitle))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
                Text(displayOrDash(model.mediaArtist))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .allowsHitTesting(false)
        }
        .clipped()
        .contentShape(Rectangle())
        .gesture(sideSwipe(side: side))
        .onTapGesture {
            if side == .left { model.flashLeftRail() }
            else { model.flashRightRail() }
        }
    }

    /// Soft blend into dial — keep light map readable (was over-dark).
    private func dialFade(edge: MapEdge) -> some View {
        let dialSide: UnitPoint = edge == .leading ? .leading : .trailing
        let outerSide: UnitPoint = edge == .leading ? .trailing : .leading
        return LinearGradient(
            colors: [fadeIntoDial.opacity(0.38), fadeIntoDial.opacity(0.08), .clear],
            startPoint: dialSide,
            endPoint: outerSide
        )
        .frame(width: 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge == .leading ? .leading : .trailing)
        .allowsHitTesting(false)
    }

    private func dialFadeVertical(fromTop: Bool) -> some View {
        LinearGradient(
            colors: [fadeIntoDial.opacity(0.38), fadeIntoDial.opacity(0.08), .clear],
            startPoint: fromTop ? .top : .bottom,
            endPoint: fromTop ? .bottom : .top
        )
        .frame(height: 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: fromTop ? .top : .bottom)
        .allowsHitTesting(false)
    }

    private var hasCarGPS: Bool {
        abs(model.latitude) > 0.0001 || abs(model.longitude) > 0.0001
    }

    private var hasMapGPS: Bool {
        hasCarGPS || PhoneLocationStore.shared.hasFix
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
        let style = settings.dialStyle
        // Slightly smaller relative size + light weight = thin but readable on a larger dial.
        let speedFont = compact ? size * 0.36 : size * 0.40
        let ringW: CGFloat = compact ? 2.5 : 3.2
        let accel = CGFloat(min(1, max(0, model.powerKW) / 180.0))
        let regen = CGFloat(min(1, max(0, -model.powerKW) / 70.0))
        let showRing = style != .bare && settings.powerStyle != .off
        // Bare over map/media: light type so it reads as floating 3D.
        let bareLit = style == .bare && (anyBleed || night)
        let dialInk: Color = bareLit ? .white : ink
        let dialMuted: Color = bareLit ? Color.white.opacity(0.78) : muted
        let dialDim: Color = bareLit ? Color.white.opacity(0.30) : dim
        // Raised dark plate — always black cluster (no day-silver).
        let plate: Color = Color(red: 0.12, green: 0.13, blue: 0.15)
        let squareR = size * 0.16

        let content = VStack(spacing: compact ? 0 : 2) {
            HStack(spacing: size * 0.055) {
                ForEach(["P", "R", "N", "D"], id: \.self) { g in
                    Text(g)
                        .font(.system(size: max(12, size * 0.066), weight: .semibold))
                        .foregroundStyle(settings.gearColor(g, active: model.gear == g, ink: dialInk, dim: dialDim))
                        .shadow(color: .black.opacity(0.7), radius: 3, y: 2)
                }
            }
            Text("\(Int(abs(model.speed).rounded()))")
                .font(.system(size: speedFont, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(dialInk)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.85), radius: style == .bare ? 12 : 5, y: style == .bare ? 7 : 3)
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
            Text("km/h")
                .font(.system(size: max(11, size * 0.055), weight: .medium))
                .foregroundStyle(dialMuted)
                .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
            if !compact, settings.liveLocation != .off, !isBlank(model.place) {
                Text(model.place)
                    .font(.system(size: max(11, size * 0.052), weight: .medium))
                    .foregroundStyle(dialMuted)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 8)

        return ZStack {
            // Cast shadow on the wing plane (visible depth cue).
            if !compact {
                Ellipse()
                    .fill(Color.black.opacity(0.70))
                    .frame(width: size * 1.05, height: size * 0.34)
                    .blur(radius: 16)
                    .offset(y: size * 0.42)
                    .allowsHitTesting(false)
                Ellipse()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: size * 0.78, height: size * 0.16)
                    .blur(radius: 5)
                    .offset(y: size * 0.34)
                    .allowsHitTesting(false)
            }

            // Shell / frame by style — extruded bezel (3D thickness).
            switch style {
            case .circle:
                // Extrusion stack (side wall).
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(Color.black.opacity(0.55 - Double(i) * 0.06))
                        .offset(y: CGFloat(i) * 1.4 + 2)
                }
                // Raised face.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(night ? 0.22 : 0.55),
                                plate,
                                Color.black.opacity(night ? 0.55 : 0.22)
                            ],
                            center: UnitPoint(x: 0.36, y: 0.30),
                            startRadius: 2,
                            endRadius: size * 0.58
                        )
                    )
                // Chrome rim.
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(night ? 0.75 : 0.95),
                                Color.white.opacity(0.15),
                                Color.black.opacity(night ? 0.85 : 0.45)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: compact ? 4 : 6
                    )
                    .padding(1)
                Circle()
                    .stroke(Color.white.opacity(night ? 0.18 : 0.35), lineWidth: 1.2)
                    .padding(size * 0.05)
                if showRing {
                    Circle()
                        .trim(from: 0, to: accel)
                        .stroke(
                            (night ? Color.white : Color.black).opacity(0.88),
                            style: StrokeStyle(lineWidth: ringW, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .padding(size * 0.06)
                        .animation(.easeOut(duration: 0.12), value: accel)
                    Circle()
                        .trim(from: 0, to: regen)
                        .stroke(
                            Color(red: 0.18, green: 0.78, blue: 0.40),
                            style: StrokeStyle(lineWidth: ringW, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(x: -1, y: 1)
                        .padding(size * 0.06)
                        .animation(.easeOut(duration: 0.12), value: regen)
                }
            case .square:
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: squareR, style: .continuous)
                        .fill(Color.black.opacity(0.55 - Double(i) * 0.06))
                        .offset(y: CGFloat(i) * 1.4 + 2)
                }
                RoundedRectangle(cornerRadius: squareR, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(night ? 0.28 : 0.7),
                                plate,
                                Color.black.opacity(night ? 0.5 : 0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: squareR, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(night ? 0.75 : 0.95),
                                Color.white.opacity(0.12),
                                Color.black.opacity(night ? 0.85 : 0.45)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: compact ? 4 : 5.5
                    )
                    .padding(1)
                RoundedRectangle(cornerRadius: squareR * 0.85, style: .continuous)
                    .stroke(Color.white.opacity(night ? 0.14 : 0.28), lineWidth: 1.2)
                    .padding(size * 0.05)
                if showRing {
                    Circle()
                        .trim(from: 0, to: accel)
                        .stroke(
                            (night ? Color.white : Color.black).opacity(0.75),
                            style: StrokeStyle(lineWidth: ringW, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .padding(size * 0.1)
                        .animation(.easeOut(duration: 0.12), value: accel)
                    Circle()
                        .trim(from: 0, to: regen)
                        .stroke(
                            Color(red: 0.18, green: 0.78, blue: 0.40),
                            style: StrokeStyle(lineWidth: ringW, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(x: -1, y: 1)
                        .padding(size * 0.1)
                        .animation(.easeOut(duration: 0.12), value: regen)
                }
            case .bare:
                // Floating plate + deep type shadow (still 3D, no hard frame).
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(Color.black.opacity(0.28 - Double(i) * 0.04))
                        .scaleEffect(0.86)
                        .offset(y: CGFloat(i) * 1.6 + 2)
                }
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(night || anyBleed ? 0.14 : 0.4),
                                Color.black.opacity(night || anyBleed ? 0.35 : 0.08)
                            ],
                            center: UnitPoint(x: 0.4, y: 0.32),
                            startRadius: 0,
                            endRadius: size * 0.48
                        )
                    )
                    .scaleEffect(0.84)
            }

            content
        }
        .frame(width: size, height: size)
        // Layered drop shadows — dial clearly in front of left/right wings.
        .compositingGroup()
        .shadow(color: .black.opacity(0.85), radius: compact ? 12 : 26, x: 0, y: compact ? 10 : 18)
        .shadow(color: .black.opacity(0.55), radius: compact ? 5 : 10, x: 0, y: compact ? 4 : 7)
        .shadow(color: Color.white.opacity(night ? 0.18 : 0.35), radius: 1.5, x: -1.5, y: -1.5)
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
                .font(.subheadline.weight(.medium))
                .foregroundStyle(model.bleOK ? accent : muted)
                .multilineTextAlignment(.center)
            Text(model.telemetrySource.uppercased())
                .font(.caption.weight(.bold))
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
                .font(.subheadline)
                .foregroundStyle(muted)
                .multilineTextAlignment(.center)
            Text(v)
                .font(.title2.weight(.medium))
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
            let labelW: CGFloat = min(58, w * 0.24)
            let gap: CGFloat = 10
            // Car sits in the middle; PSI labels stay beside it (never on the body).
            let carW = min(max(44, w - labelW * 2 - gap * 2), h * 0.34)
            let carH = min(h * 0.88, carW * 2.15)
            let labelH = carH * 0.62
            HStack(alignment: .center, spacing: gap) {
                VStack(spacing: 0) {
                    psiLabel(model.psiFL)
                    Spacer(minLength: 0)
                    psiLabel(model.psiRL)
                }
                .frame(width: labelW, height: labelH)

                Image("ModelYTop")
                    .resizable()
                    .scaledToFit()
                    .frame(width: carW, height: carH)
                    .opacity(0.96)
                    .colorMultiply(night ? Color.white : Color(red: 0.15, green: 0.16, blue: 0.18))
                    .accessibilityLabel("Tesla Model Y")

                VStack(spacing: 0) {
                    psiLabel(model.psiFR)
                    Spacer(minLength: 0)
                    psiLabel(model.psiRR)
                }
                .frame(width: labelW, height: labelH)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func psiLabel(_ psi: Int) -> some View {
        Text(psi > 0 ? "\(psi) psi" : "-- psi")
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(ink.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
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
            // Compact album — small cover, title/artist below, light floor reflection.
            let artSize = min(64, max(48, min(geo.size.width * 0.40, geo.size.height * 0.22)))
            VStack(alignment: .center, spacing: 10) {
                mediaServiceHeader
                albumArtWithReflection(size: artSize)
                Text(displayOrDash(model.mediaTitle))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(displayOrDash(model.mediaArtist))
                    .font(.title3)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .frame(maxWidth: min(200, geo.size.width))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func albumArtWithReflection(size: CGFloat) -> some View {
        // ~10% height mirror under the cover.
        let reflectH = size * 0.12
        return VStack(spacing: 0) {
            AlbumArtView(image: art.image, url: art.imageURL, loading: art.loading, size: size)
            AlbumArtView(image: art.image, url: art.imageURL, loading: art.loading, size: size)
                .scaleEffect(x: 1, y: -1)
                .frame(height: reflectH, alignment: .top)
                .clipped()
                .opacity(0.32)
                .mask(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.50),
                            Color.white.opacity(0.08),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
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
                .font(.body.weight(.semibold))
                .foregroundStyle(anyBleed || night ? Color.white : ink)
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
        if s.contains("youtube") { return Color(red: 0.78, green: 0.16, blue: 0.16) }
        if s.contains("spotify") { return Color(red: 0.18, green: 0.72, blue: 0.35) }
        if s.contains("tidal") { return Color(red: 0.12, green: 0.12, blue: 0.14) }
        return Color(red: 0.22, green: 0.55, blue: 0.72)
    }

    private var turnBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: model.turnSymbol.isEmpty ? "arrow.turn.up.right" : model.turnSymbol)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(turnDistanceText)
                    .font(.title.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                if !model.turnInstruction.isEmpty {
                    Text(model.turnInstruction)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
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
