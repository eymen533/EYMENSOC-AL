import SwiftUI
import UIKit

/// Dashla-style HUD — each Harita panel is its own map, tucked under the dial with soft blur.
struct NativeHUDView: View {
    @ObservedObject var model: HUDModel
    @ObservedObject private var settings = HUDSettings.shared
    @ObservedObject private var art = MediaArtworkStore.shared
    var linkLabel: String
    var onBack: () -> Void
    var onSettings: (() -> Void)? = nil

    @State private var mapExpanded = false
    /// Map type / traffic icons — flash on tap, then auto-hide.
    @State private var mapChromeVisible = false
    @State private var mapChromeHideToken = 0

    /// Always black cluster — vehicle day/night theme is ignored (white glare).
    private var night: Bool { true }
    private var ink: Color { .white }
    private var muted: Color { Color.white.opacity(0.55) }
    private var dim: Color { Color.white.opacity(0.22) }
    private var accent: Color { Color(red: 0.20, green: 0.72, blue: 0.62) }
    private var dialGlow: Color { Color(red: 1.0, green: 0.82, blue: 0.12) }
    private var canvas: Color { .black }
    private var dialFill: Color { Color(red: 0.08, green: 0.08, blue: 0.09) }
    private var chipFill: Color { Color.black.opacity(0.72) }
    /// Soft blend into dial — always dark so day mode never paints white bars.
    private var fadeIntoDial: Color { Color.black }

    /// Album art stays compact (no oversize bleed). Map stays inside its panel.
    private var leftBleed: Bool { false }
    private var rightBleed: Bool { false }
    private var leftMap: Bool { model.leftSlide == 3 }
    private var rightMap: Bool { model.rightSlide == 3 }
    private var leftWing: Bool { leftMap }
    private var rightWing: Bool { rightMap }
    private var anyBleed: Bool { leftWing || rightWing }
    private var anyApertureOpen: Bool {
        model.doorFL || model.doorFR || model.doorRL || model.doorRR
            || model.frunkOpen || model.trunkOpen || model.chargePortOpen
    }
    /// Close enough that the illuminated map hero cue should take over.
    private var turnImminent: Bool {
        model.turnDistanceM > 0 && model.turnDistanceM <= 55
    }

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

    // MARK: - Triad

    private func triadLandscape(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height
        let dialW = min(w * 0.40, h * 0.88, 340)
        let cx = w * 0.5
        let cy = h * 0.5
        let sideW = max(140, (w - dialW) / 2)
        // Map only: extend under the dial; non-map panels stay flush with dial edge.
        let tuck = dialW * 0.55
        let leftW = sideW + (leftMap ? tuck : 0)
        let rightW = sideW + (rightMap ? tuck : 0)
        let showTurn = (leftMap || rightMap)
            && (model.turnDistanceM > 0 || !model.turnInstruction.isEmpty)
        let chromeMuted = Color.white.opacity(0.78)
        let cluster = Color(red: 0.07, green: 0.07, blue: 0.08)

        return ZStack {
            cluster.zIndex(0)

            Group {
                if leftMap {
                    panelMap(edge: .trailing, side: .left)
                        .id("hud-map-left")
                } else {
                    sideColumn(slide: model.leftSlide, side: .left, showBattery: false)
                }
            }
            .frame(width: leftW, height: h)
            .clipShape(Rectangle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .zIndex(leftMap ? 0 : 1)

            Group {
                if rightMap {
                    panelMap(edge: .leading, side: .right)
                        .id("hud-map-right")
                } else {
                    sideColumn(slide: model.rightSlide, side: .right, showBattery: false)
                }
            }
            .frame(width: rightW, height: h)
            .clipShape(Rectangle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .zIndex(rightMap ? 0 : 1)

            // Soft frost bloom under dial (no second MKMapView).
            if leftMap || rightMap {
                underDialFrost(dialW: dialW, cx: cx, cy: cy)
                    .zIndex(3)
            }

            // Dial plate — slightly translucent so tucked map reads through.
            Circle()
                .fill(cluster.opacity(leftMap || rightMap ? 0.88 : 1))
                .frame(width: dialW * 1.02, height: dialW * 1.02)
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

            if showTurn {
                // Below top chrome (phone battery %) — don't overlap.
                let bannerX: CGFloat = {
                    if leftMap && rightMap { return sideW * 0.48 }
                    if rightMap && !leftMap { return w - sideW * 0.48 }
                    return sideW * 0.48
                }()
                let bannerY = max(102, min(cy - dialW * 0.42, h * 0.30))
                // Far / mid: glass chip. Near turn: hero cue sits mid-map.
                if turnImminent {
                    NavTurnCue(
                        distanceM: model.turnDistanceM,
                        instruction: model.turnInstruction,
                        symbol: model.turnSymbol,
                        style: .mapHero
                    )
                    .position(
                        x: rightMap && !leftMap ? (w - sideW * 0.5) : (sideW * 0.5),
                        y: h * 0.52
                    )
                    .zIndex(12)
                } else {
                    NavTurnCue(
                        distanceM: model.turnDistanceM,
                        instruction: model.turnInstruction,
                        symbol: model.turnSymbol,
                        style: .chip
                    )
                    .frame(maxWidth: min(280, sideW * 0.92), alignment: .leading)
                    .position(x: bannerX, y: bannerY)
                    .zIndex(8)
                }
            }

            // Door/frunk status fills the dial — compact label under dial only.
            if anyApertureOpen {
                Text(model.openDoorLabels.isEmpty ? "Açık" : model.openDoorLabels.joined(separator: " · "))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.35))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .position(x: cx, y: cy + dialW * 0.56)
                    .zIndex(11)
                    .transition(.opacity)
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
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(chromeMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 8)
            .zIndex(8)

            dashlaChrome(leftMap: leftMap, rightMap: rightMap)
                .zIndex(20)

            if model.charging {
                ChargingTopRibbon()
                    .zIndex(22)
            }
        }
        .frame(width: w, height: h)
        .clipped()
        .ignoresSafeArea()
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: anyApertureOpen)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: turnImminent)
        .animation(.easeInOut(duration: 0.35), value: model.charging)
    }

    /// Map panel — tucks under dial; dial-facing edge gets soft Material blur.
    private func panelMap(edge: MapEdge, side: Side, verticalFromTop: Bool? = nil) -> some View {
        ZStack {
            mapSurface(
                edge: edge,
                side: side,
                showTapExpand: true,
                verticalFromTop: verticalFromTop,
                asOverlay: false
            )

            // Soft blur of the map itself on the dial-facing edge (Material frosts content below).
            mapUnderDialBlur(edge: edge, verticalFromTop: verticalFromTop)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .background(Color(red: 0.93, green: 0.94, blue: 0.95))
    }

    /// Frost strip on the dial-facing edge — light blur, no second map instance.
    @ViewBuilder
    private func mapUnderDialBlur(edge: MapEdge, verticalFromTop: Bool?) -> some View {
        let band: CGFloat = 56
        let frost = Rectangle()
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .light)
            .overlay(Color.black.opacity(0.06))
            .allowsHitTesting(false)

        if let fromTop = verticalFromTop {
            VStack(spacing: 0) {
                if !fromTop { Spacer(minLength: 0) }
                frost
                    .frame(height: band)
                    .mask(
                        LinearGradient(
                            colors: fromTop
                                ? [.clear, .white.opacity(0.35), .white.opacity(0.7)]
                                : [.white.opacity(0.7), .white.opacity(0.35), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                if fromTop { Spacer(minLength: 0) }
            }
            .allowsHitTesting(false)
        } else {
            HStack(spacing: 0) {
                if edge == .trailing { Spacer(minLength: 0) }
                frost
                    .frame(width: band)
                    .mask(
                        LinearGradient(
                            colors: edge == .leading
                                ? [.white.opacity(0.7), .white.opacity(0.35), .clear]
                                : [.clear, .white.opacity(0.35), .white.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                if edge == .leading { Spacer(minLength: 0) }
            }
            .allowsHitTesting(false)
        }
    }

    /// Soft radial frost behind the dial plate — kept light so map stays readable.
    private func underDialFrost(dialW: CGFloat, cx: CGFloat, cy: CGFloat) -> some View {
        Circle()
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .frame(width: dialW * 1.18, height: dialW * 1.18)
            .mask(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.55),
                        Color.white.opacity(0.18),
                        .clear
                    ],
                    center: .center,
                    startRadius: dialW * 0.28,
                    endRadius: dialW * 0.58
                )
            )
            .overlay(
                Circle()
                    .fill(Color.black.opacity(0.10))
                    .frame(width: dialW * 1.04, height: dialW * 1.04)
            )
            .position(x: cx, y: cy)
            .allowsHitTesting(false)
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
        let dialW = min(w * 0.52, h * 0.30, 230)
        let tuck = dialW * 0.55
        let showTurn = (leftMap || rightMap)
            && (model.turnDistanceM > 0 || !model.turnInstruction.isEmpty)
        // Room for two-row top chrome (clock row + centered place).
        let topChrome: CGFloat = 56
        let wingH = max(96, (h - dialW - topChrome) / 2)
        let cx = w * 0.5
        let cy = topChrome + wingH + dialW * 0.5
        let topWing = leftMap
        let bottomWing = rightMap
        let topH = wingH + (topWing ? tuck : 0)
        let bottomH = wingH + (bottomWing ? tuck : 0)
        let cluster = Color(red: 0.07, green: 0.07, blue: 0.08)

        return ZStack {
            cluster

            Group {
                if leftMap {
                    panelMap(edge: .trailing, side: .left, verticalFromTop: false)
                        .id("hud-map-top")
                } else {
                    sideColumn(
                        slide: model.leftSlide,
                        side: .left,
                        showBattery: false,
                        portraitAligned: true
                    )
                }
            }
            .frame(width: w, height: topH)
            .clipShape(Rectangle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, topChrome)
            .zIndex(topWing ? 0 : 1)

            Group {
                if rightMap {
                    panelMap(edge: .leading, side: .right, verticalFromTop: true)
                        .id("hud-map-bottom")
                } else {
                    sideColumn(
                        slide: model.rightSlide,
                        side: .right,
                        showBattery: false,
                        portraitAligned: true
                    )
                }
            }
            .frame(width: w, height: bottomH)
            .clipShape(Rectangle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .zIndex(bottomWing ? 0 : 1)

            if topWing || bottomWing {
                underDialFrost(dialW: dialW, cx: cx, cy: cy)
                    .zIndex(3)
            }

            Circle()
                .fill(cluster.opacity(topWing || bottomWing ? 0.88 : 1))
                .frame(width: dialW * 1.02, height: dialW * 1.02)
                .position(x: cx, y: cy)
                .zIndex(4)

            dialView(size: dialW)
                .position(x: cx, y: cy)
                .zIndex(10)

            if showTurn {
                if turnImminent {
                    NavTurnCue(
                        distanceM: model.turnDistanceM,
                        instruction: model.turnInstruction,
                        symbol: model.turnSymbol,
                        style: .mapHero
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.top, topWing ? 40 : 0)
                    .zIndex(12)
                } else {
                    NavTurnCue(
                        distanceM: model.turnDistanceM,
                        instruction: model.turnInstruction,
                        symbol: model.turnSymbol,
                        style: .chip
                    )
                    .frame(maxWidth: min(w - 28, 320), alignment: .leading)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: topWing ? .topLeading : .bottomLeading)
                    .padding(.top, topWing ? topChrome + 52 : 0)
                    .padding(.bottom, bottomWing && !topWing ? 56 : 0)
                    .zIndex(8)
                }
            }

            if anyApertureOpen {
                Text(model.openDoorLabels.isEmpty ? "Açık" : model.openDoorLabels.joined(separator: " · "))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.35))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .position(x: cx, y: cy + dialW * 0.56)
                    .zIndex(11)
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
                .position(x: 90, y: h - 28)
                .zIndex(8)

            Text(odoText)
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.78))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.45)))
                .position(x: w - 90, y: h - 28)
                .zIndex(8)

            dashlaChrome(leftMap: leftMap, rightMap: rightMap, portrait: true)
                .zIndex(20)

            if model.charging {
                ChargingTopRibbon()
                    .zIndex(22)
            }
        }
        .frame(width: w, height: h)
        .clipped()
        .ignoresSafeArea()
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: anyApertureOpen)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: turnImminent)
        .animation(.easeInOut(duration: 0.35), value: model.charging)
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

            if anyApertureOpen {
                Text(model.openDoorLabels.isEmpty ? "Açık" : model.openDoorLabels.joined(separator: " · "))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.35))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .position(x: geo.size.width * 0.5, y: 48 + dialSize * 1.05)
                    .zIndex(11)
            }

            if model.turnDistanceM > 0 || !model.turnInstruction.isEmpty {
                Group {
                    if turnImminent {
                        NavTurnCue(
                            distanceM: model.turnDistanceM,
                            instruction: model.turnInstruction,
                            symbol: model.turnSymbol,
                            style: .mapHero
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else {
                        NavTurnCue(
                            distanceM: model.turnDistanceM,
                            instruction: model.turnInstruction,
                            symbol: model.turnSymbol,
                            style: .chip
                        )
                        .padding(.bottom, 28)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .zIndex(12)
            }

            dashlaChrome(leftMap: false, rightMap: true)
                .zIndex(20)

            if model.charging {
                ChargingTopRibbon()
                    .zIndex(22)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: anyApertureOpen)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: turnImminent)
        .animation(.easeInOut(duration: 0.35), value: model.charging)
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
        HStack(spacing: 12) {
            AlbumArtView(image: art.image, url: art.imageURL, loading: art.loading, size: 92)
            VStack(alignment: .leading, spacing: 4) {
                Text(displayOrDash(model.mediaTitle))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                Text(displayOrDash(model.mediaArtist))
                    .font(.caption)
                    .foregroundStyle(muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: 180, alignment: .leading)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(chipFill))
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

    // MARK: - Dashla chrome (no solid top bar — texts float into panels/map)

    @ViewBuilder
    private func dashlaChrome(leftMap: Bool, rightMap: Bool, portrait: Bool = false) -> some View {
        let inkOnDark = Color.white
        let mutedOnDark = Color.white.opacity(0.78)
        let mapInk = Color.white
        let mapMuted = Color.white.opacity(0.9)

        if portrait {
            portraitTopChrome(
                leftMap: leftMap,
                rightMap: rightMap,
                inkOnDark: inkOnDark,
                mutedOnDark: mutedOnDark,
                mapInk: mapInk,
                mapMuted: mapMuted
            )
        } else {
            landscapeTopChrome(
                leftMap: leftMap,
                rightMap: rightMap,
                inkOnDark: inkOnDark,
                mutedOnDark: mutedOnDark,
                mapInk: mapInk,
                mapMuted: mapMuted
            )
        }
    }

    /// Portrait: row 1 = controls, row 2 = centered place — never squeeze clock into a vertical stack.
    private func portraitTopChrome(
        leftMap: Bool,
        rightMap: Bool,
        inkOnDark: Color,
        mutedOnDark: Color,
        mapInk: Color,
        mapMuted: Color
    ) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(inkOnDark)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Text(model.clock.isEmpty ? "--:--" : model.clock)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(inkOnDark)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Text(model.outdoorValid ? "\(model.outdoorC)°C" : "--°C")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(mutedOnDark)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Image(systemName: "car.fill")
                    .font(.caption)
                    .foregroundStyle(model.bleOK || model.isLive ? accent : mutedOnDark.opacity(0.55))

                Spacer(minLength: 6)

                HStack(spacing: 6) {
                    Circle()
                        .fill(model.isLive || model.bleOK ? Color.green : Color.orange.opacity(0.75))
                        .frame(width: 7, height: 7)
                    Image(systemName: phoneBattIcon)
                        .font(.caption2)
                    Text("\(model.phoneBattery > 0 ? model.phoneBattery : max(0, Int(model.battery)))%")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Button { onSettings?() } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.caption)
                            .foregroundStyle(mapMuted)
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(mapInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.42)))
            }

            if settings.liveLocation != .off, !isBlank(model.place) {
                Text(model.place)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.50)))
                    .frame(maxWidth: 260)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
    }

    private func landscapeTopChrome(
        leftMap: Bool,
        rightMap: Bool,
        inkOnDark: Color,
        mutedOnDark: Color,
        mapInk: Color,
        mapMuted: Color
    ) -> some View {
        ZStack(alignment: .top) {
            if settings.liveLocation != .off, !isBlank(model.place) {
                Text(model.place)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.black.opacity(0.50)))
                    .frame(maxWidth: 280)
                    .padding(.top, 10)
            }

            HStack(alignment: .top, spacing: 0) {
                HStack(spacing: 8) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(inkOnDark)
                    }
                    Text(model.clock.isEmpty ? "--:--" : model.clock)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(inkOnDark)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Text(model.outdoorValid ? "\(model.outdoorC)°C" : "--°C")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(mutedOnDark)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Image(systemName: "car.fill")
                        .font(.body)
                        .foregroundStyle(model.bleOK || model.isLive ? accent : mutedOnDark.opacity(0.55))
                }
                .padding(.horizontal, leftMap ? 10 : 0)
                .padding(.vertical, leftMap ? 6 : 0)
                .background(
                    Group {
                        if leftMap {
                            Capsule().fill(Color.black.opacity(0.45))
                        }
                    }
                )
                .shadow(color: .black.opacity(leftMap ? 0 : 0.55), radius: 3, y: 1)

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    Circle()
                        .fill(model.isLive || model.bleOK ? Color.green : Color.orange.opacity(0.75))
                        .frame(width: 8, height: 8)
                    HStack(spacing: 5) {
                        Image(systemName: phoneBattIcon)
                            .font(.subheadline)
                        Text("\(model.phoneBattery > 0 ? model.phoneBattery : max(0, Int(model.battery)))%")
                            .font(.body.monospacedDigit().weight(.semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundStyle(mapInk)
                    Button { onSettings?() } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.subheadline)
                            .foregroundStyle(mapMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.black.opacity(rightMap ? 0.42 : 0.35)))
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
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

    private func sideColumn(
        slide: Int,
        side: Side,
        showBattery: Bool,
        portraitAligned: Bool = false
    ) -> some View {
        // Landscape: clear the vertical selection rail (~34pt near dial).
        // Keep outer/inner padding balanced so content sits mid-wing (not flush to screen edge).
        let lead: CGFloat = portraitAligned ? 18 : (side == .right ? 36 : 20)
        let trail: CGFloat = portraitAligned ? 18 : (side == .left ? 36 : 20)
        return ZStack(alignment: .bottomLeading) {
            // Flat cluster — no inset card / rounded layer.
            Color(red: 0.07, green: 0.07, blue: 0.08)
            Group {
                switch slide {
                case 1: tiresPanel(side: side)
                case 2: tripPanel
                case 3: mapInfoPanel
                case 4: mediaPanel
                default: simplePanel
                }
            }
            .padding(.leading, lead)
            .padding(.trailing, trail)
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
                    onUserTap: { flashMapChrome() },
                    onVerticalNudge: { delta in
                        if side == .left {
                            model.nudgeLeft(delta)
                            model.flashLeftRail()
                        } else {
                            model.nudgeRight(delta)
                            model.flashRightRail()
                        }
                    },
                    turnDistanceM: Binding(get: { model.turnDistanceM }, set: { model.turnDistanceM = $0 }),
                    turnInstruction: Binding(get: { model.turnInstruction }, set: { model.turnInstruction = $0 }),
                    turnSymbol: Binding(get: { model.turnSymbol }, set: { model.turnSymbol = $0 })
                )
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
                    .allowsHitTesting(false)
            } else if !mapExpanded, !hasMapGPS, abs(model.destLatitude) < 0.0001, abs(model.destLongitude) < 0.0001 {
                Text("Konum izni / GPS bekleniyor")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
                    .padding(12)
                    .allowsHitTesting(false)
            }

            // Small transparent map controls — right edge; flash on tap then fade.
            if mapChromeVisible {
                mapChromeRail(showExpand: showTapExpand && !mapExpanded)
                    .padding(.trailing, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .zIndex(5)
            }
        }
        .clipped()
        .animation(.easeOut(duration: 0.22), value: mapChromeVisible)
    }

    private func flashMapChrome() {
        mapChromeHideToken &+= 1
        let token = mapChromeHideToken
        withAnimation(.easeOut(duration: 0.18)) { mapChromeVisible = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard token == mapChromeHideToken else { return }
            withAnimation(.easeOut(duration: 0.28)) { mapChromeVisible = false }
        }
    }

    /// Compact translucent map / satellite / traffic / expand icons.
    private func mapChromeRail(showExpand: Bool) -> some View {
        VStack(spacing: 8) {
            ForEach(HUDSettings.MapImagery.allCases) { kind in
                mapChromeButton(
                    systemName: kind.systemImage,
                    selected: settings.mapImagery == kind
                ) {
                    settings.mapImagery = kind
                    flashMapChrome()
                }
            }
            mapChromeButton(
                systemName: "car.fill",
                selected: settings.mapShowsTraffic
            ) {
                settings.mapShowsTraffic.toggle()
                flashMapChrome()
            }
            if showExpand {
                mapChromeButton(systemName: "arrow.up.left.and.arrow.down.right", selected: false) {
                    withAnimation(.easeInOut(duration: 0.28)) { mapExpanded = true }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.28))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
        )
    }

    private func mapChromeButton(
        systemName: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? Color.white : Color.white.opacity(0.72))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(selected ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    /// Album art fills the panel and tucks under the dial like the map.
    /// Album art panel — cover + reflection + title/artist/controls, centered in the wing.
    private func mediaSurface(
        edge: MapEdge,
        side: Side,
        verticalFromTop: Bool? = nil,
        asOverlay: Bool = false
    ) -> some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.06)

            if let verticalFromTop {
                dialFadeVertical(fromTop: verticalFromTop)
            } else {
                dialFade(edge: edge)
            }

            GeometryReader { geo in
                // Album is the hero of the media wing — keep it large.
                let artSize = min(268, max(180, min(geo.size.width * 0.86, geo.size.height * 0.58)))
                VStack(alignment: .center, spacing: 10) {
                    Spacer(minLength: 4)
                    if !asOverlay {
                        styledMediaBlock(artSize: artSize, lightInk: true)
                    } else {
                        mediaMetaStack(lightInk: true)
                        mediaTransportControls
                    }
                    Spacer(minLength: 6)
                }
                .frame(maxWidth: min(340, geo.size.width * 0.96))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.leading, side == .left ? 6 : 12)
                .padding(.trailing, side == .left ? 12 : 6)
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .gesture(sideSwipe(side: side))
        .onTapGesture {
            if side == .left { model.flashLeftRail() }
            else { model.flashRightRail() }
        }
    }

    /// Soft blend into dial — wider, gentler for color unity with cluster panel.
    private func dialFade(edge: MapEdge) -> some View {
        let dialSide: UnitPoint = edge == .leading ? .leading : .trailing
        let outerSide: UnitPoint = edge == .leading ? .trailing : .leading
        return LinearGradient(
            colors: [fadeIntoDial.opacity(0.22), fadeIntoDial.opacity(0.06), .clear],
            startPoint: dialSide,
            endPoint: outerSide
        )
        .frame(width: 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge == .leading ? .leading : .trailing)
        .allowsHitTesting(false)
    }

    private func dialFadeVertical(fromTop: Bool) -> some View {
        LinearGradient(
            colors: [fadeIntoDial.opacity(0.22), fadeIntoDial.opacity(0.06), .clear],
            startPoint: fromTop ? .top : .bottom,
            endPoint: fromTop ? .bottom : .top
        )
        .frame(height: 24)
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
        // Tesla cluster: large thin digits — slight bump for readability.
        let speedFont = compact ? size * 0.44 : size * 0.52
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
        let statusAsset = DialVehicleStatus.assetName(
            doorFL: model.doorFL,
            doorFR: model.doorFR,
            doorRL: model.doorRL,
            doorRR: model.doorRR,
            frunkOpen: model.frunkOpen,
            trunkOpen: model.trunkOpen,
            chargePortOpen: model.chargePortOpen
        )

        // When doors/frunk/trunk are open, park speed and fill the dial with vehicle status.
        if let statusAsset {
            return AnyView(
                ZStack {
                    Image(statusAsset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                    Circle()
                        .stroke(dialGlow.opacity(0.95), lineWidth: compact ? 1.0 : 1.25)
                        .shadow(color: dialGlow.opacity(0.95), radius: compact ? 2.2 : 3.2)
                        .shadow(color: dialGlow.opacity(0.45), radius: compact ? 5 : 7)
                        .padding(0.5)
                    // Gear row stays readable over the status art.
                    VStack {
                        HStack(spacing: size * 0.055) {
                            ForEach(["P", "R", "N", "D"], id: \.self) { g in
                                Text(g)
                                    .font(.system(size: max(11, size * 0.06), weight: .semibold))
                                    .foregroundStyle(settings.gearColor(g, active: model.gear == g, ink: .white, dim: Color.white.opacity(0.35)))
                                    .shadow(color: .black.opacity(0.85), radius: 3, y: 1)
                            }
                        }
                        .padding(.top, size * 0.08)
                        Spacer(minLength: 0)
                    }
                }
                .frame(width: size, height: size)
                .compositingGroup()
                .shadow(color: .black.opacity(0.28), radius: compact ? 3 : 5, x: 0, y: compact ? 2 : 3)
                .shadow(color: dialGlow.opacity(0.35), radius: compact ? 3 : 5)
                .animation(.easeInOut(duration: 0.25), value: statusAsset)
            )
        }

        let content = VStack(spacing: compact ? 0 : 2) {
            HStack(spacing: size * 0.055) {
                ForEach(["P", "R", "N", "D"], id: \.self) { g in
                    Text(g)
                        .font(.system(size: max(12, size * 0.066), weight: .semibold))
                        .foregroundStyle(settings.gearColor(g, active: model.gear == g, ink: dialInk, dim: dialDim))
                        .shadow(color: .black.opacity(0.7), radius: 3, y: 2)
                }
            }
            // Keep gears clear of the top power/regen rim.
            .padding(.top, size * 0.085)
            DialSpeedDigits(
                target: model.speed,
                fontSize: speedFont * 1.15,
                ink: dialInk,
                bare: style == .bare
            )
            Text("km/h")
                .font(.system(size: max(11, size * 0.048), weight: .regular))
                .foregroundStyle(dialMuted)
                .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
        }
        .padding(.horizontal, 8)

        return AnyView(ZStack {
            // Shell / frame by style — extruded bezel (3D thickness).
            switch style {
            case .circle:
                // Extrusion stack (side wall).
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(Color.black.opacity(0.42 - Double(i) * 0.06))
                        .offset(y: CGFloat(i) * 1.1 + 1)
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
                // Thin yellow boundary + glow (replaces heavy drop shadow on map).
                Circle()
                    .stroke(dialGlow.opacity(0.95), lineWidth: compact ? 1.0 : 1.25)
                    .shadow(color: dialGlow.opacity(0.95), radius: compact ? 2.2 : 3.2)
                    .shadow(color: dialGlow.opacity(0.45), radius: compact ? 5 : 7)
                    .padding(0.5)
                Circle()
                    .stroke(Color.white.opacity(night ? 0.14 : 0.28), lineWidth: 0.8)
                    .padding(size * 0.045)
                if showRing {
                    // Outer-top rim only — clear of P/R/N/D gear row.
                    Circle()
                        .trim(from: 0.02, to: 0.02 + accel * 0.22)
                        .stroke(
                            (night ? Color.white : Color.black).opacity(0.88),
                            style: StrokeStyle(lineWidth: ringW, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .padding(size * 0.018)
                        .animation(.easeOut(duration: 0.12), value: accel)
                    Circle()
                        .trim(from: 0.02, to: 0.02 + regen * 0.22)
                        .stroke(
                            Color(red: 0.18, green: 0.78, blue: 0.40),
                            style: StrokeStyle(lineWidth: ringW, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(x: -1, y: 1)
                        .padding(size * 0.018)
                        .animation(.easeOut(duration: 0.12), value: regen)
                }


            case .arc:
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.black.opacity(0.35 - Double(i) * 0.08))
                        .offset(y: CGFloat(i) * 1.0 + 1)
                }
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(night ? 0.16 : 0.4),
                                plate,
                                Color.black.opacity(0.45)
                            ],
                            center: UnitPoint(x: 0.4, y: 0.32),
                            startRadius: 2,
                            endRadius: size * 0.58
                        )
                    )
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .padding(size * 0.02)
                if showRing {
                    Circle()
                        .trim(from: 0.08, to: 0.08 + accel * 0.84)
                        .stroke(
                            (night ? Color.white : Color.black).opacity(0.9),
                            style: StrokeStyle(lineWidth: ringW + 0.8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(90))
                        .padding(size * 0.05)
                        .animation(.easeOut(duration: 0.12), value: accel)
                    Circle()
                        .trim(from: 0.08, to: 0.08 + regen * 0.84)
                        .stroke(
                            Color(red: 0.18, green: 0.78, blue: 0.40),
                            style: StrokeStyle(lineWidth: ringW + 0.8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(90))
                        .scaleEffect(x: -1, y: 1)
                        .padding(size * 0.05)
                        .animation(.easeOut(duration: 0.12), value: regen)
                }


            case .sport:
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(Color.black.opacity(0.42 - Double(i) * 0.06))
                        .offset(y: CGFloat(i) * 1.1 + 1)
                }
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.28, blue: 0.18).opacity(night ? 0.28 : 0.16),
                                plate,
                                Color.black.opacity(0.55)
                            ],
                            center: UnitPoint(x: 0.38, y: 0.30),
                            startRadius: 2,
                            endRadius: size * 0.58
                        )
                    )
                Circle()
                    .stroke(Color(red: 1.0, green: 0.28, blue: 0.18).opacity(0.95), lineWidth: compact ? 1.6 : 2.1)
                    .shadow(color: Color(red: 1.0, green: 0.28, blue: 0.18).opacity(0.7), radius: compact ? 4 : 7)
                    .padding(0.5)
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
                    .padding(size * 0.05)
                if showRing {
                    Circle()
                        .trim(from: 0.02, to: 0.02 + accel * 0.22)
                        .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: ringW, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(size * 0.018)
                        .animation(.easeOut(duration: 0.12), value: accel)
                    Circle()
                        .trim(from: 0.02, to: 0.02 + regen * 0.22)
                        .stroke(Color(red: 0.18, green: 0.78, blue: 0.40), style: StrokeStyle(lineWidth: ringW, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(x: -1, y: 1)
                        .padding(size * 0.018)
                        .animation(.easeOut(duration: 0.12), value: regen)
                }


            case .capsule:
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(Color.black.opacity(0.42 - Double(i) * 0.06))
                        .frame(width: size * 0.72, height: size)
                        .offset(y: CGFloat(i) * 1.1 + 1)
                }
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(night ? 0.22 : 0.55),
                                plate,
                                Color.black.opacity(night ? 0.5 : 0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.72, height: size)
                Capsule()
                    .stroke(dialGlow.opacity(0.95), lineWidth: compact ? 1.0 : 1.25)
                    .shadow(color: dialGlow.opacity(0.9), radius: compact ? 2.2 : 3.2)
                    .frame(width: size * 0.72, height: size)
                if showRing {
                    Capsule()
                        .trim(from: 0, to: accel)
                        .stroke((night ? Color.white : Color.black).opacity(0.8), style: StrokeStyle(lineWidth: ringW, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: size * 0.72, height: size)
                        .padding(size * 0.08)
                        .animation(.easeOut(duration: 0.12), value: accel)
                }


            case .dual:
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(Color.black.opacity(0.42 - Double(i) * 0.06))
                        .offset(y: CGFloat(i) * 1.1 + 1)
                }
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.49, green: 0.36, blue: 1.0).opacity(night ? 0.22 : 0.12),
                                plate,
                                Color.black.opacity(0.5)
                            ],
                            center: UnitPoint(x: 0.38, y: 0.3),
                            startRadius: 2,
                            endRadius: size * 0.58
                        )
                    )
                Circle()
                    .stroke(Color.white.opacity(0.95), lineWidth: compact ? 1.4 : 1.8)
                    .padding(size * 0.01)
                Circle()
                    .stroke(Color(red: 0.49, green: 0.36, blue: 1.0).opacity(0.95), lineWidth: compact ? 2.0 : 2.6)
                    .shadow(color: Color(red: 0.49, green: 0.36, blue: 1.0).opacity(0.55), radius: 6)
                    .padding(size * 0.055)
                if showRing {
                    Circle()
                        .trim(from: 0.02, to: 0.02 + accel * 0.22)
                        .stroke((night ? Color.white : Color.black).opacity(0.88), style: StrokeStyle(lineWidth: ringW, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(size * 0.04)
                        .animation(.easeOut(duration: 0.12), value: accel)
                    Circle()
                        .trim(from: 0.02, to: 0.02 + regen * 0.22)
                        .stroke(Color(red: 0.18, green: 0.78, blue: 0.40), style: StrokeStyle(lineWidth: ringW, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(x: -1, y: 1)
                        .padding(size * 0.04)
                        .animation(.easeOut(duration: 0.12), value: regen)
                }

            case .neon:
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color(red: 0.0, green: 0.90, blue: 1.0).opacity(0.12 - Double(i) * 0.03))
                        .blur(radius: CGFloat(6 + i * 4))
                        .scaleEffect(1.02 + CGFloat(i) * 0.04)
                }
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.0, green: 0.90, blue: 1.0).opacity(night ? 0.22 : 0.14),
                                plate,
                                Color.black.opacity(0.55)
                            ],
                            center: UnitPoint(x: 0.4, y: 0.32),
                            startRadius: 2,
                            endRadius: size * 0.58
                        )
                    )
                Circle()
                    .stroke(Color(red: 0.0, green: 0.90, blue: 1.0).opacity(0.95), lineWidth: compact ? 1.6 : 2.0)
                    .shadow(color: Color(red: 0.0, green: 0.90, blue: 1.0).opacity(0.9), radius: compact ? 5 : 8)
                    .shadow(color: Color(red: 0.0, green: 0.90, blue: 1.0).opacity(0.45), radius: compact ? 10 : 14)
                    .padding(0.5)
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                    .padding(size * 0.05)
                if showRing {
                    Circle()
                        .trim(from: 0.02, to: 0.02 + accel * 0.22)
                        .stroke(
                            Color(red: 0.0, green: 0.90, blue: 1.0).opacity(0.95),
                            style: StrokeStyle(lineWidth: ringW, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .padding(size * 0.018)
                        .animation(.easeOut(duration: 0.12), value: accel)
                    Circle()
                        .trim(from: 0.02, to: 0.02 + regen * 0.22)
                        .stroke(
                            Color(red: 0.18, green: 0.78, blue: 0.40),
                            style: StrokeStyle(lineWidth: ringW, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(x: -1, y: 1)
                        .padding(size * 0.018)
                        .animation(.easeOut(duration: 0.12), value: regen)
                }

            case .bare:
                // Floating plate — thin yellow rim for 3D edge without map-darkening shadow.
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.black.opacity(0.18 - Double(i) * 0.04))
                        .scaleEffect(0.86)
                        .offset(y: CGFloat(i) * 1.2 + 1)
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
                Circle()
                    .stroke(dialGlow.opacity(0.9), lineWidth: 1.1)
                    .shadow(color: dialGlow.opacity(0.85), radius: 3)
                    .shadow(color: dialGlow.opacity(0.4), radius: 6)
                    .scaleEffect(0.86)
            }

            content
        }
        .frame(width: size, height: size)
        // Soft local depth only — no large black bloom over the map.
        .compositingGroup()
        .shadow(color: .black.opacity(0.28), radius: compact ? 3 : 5, x: 0, y: compact ? 2 : 3)
        .shadow(color: dialGlow.opacity(0.35), radius: compact ? 3 : 5)
        )
    }

    /// Lights / lock under the dial (doors/frunk fill the dial face when open).
    @ViewBuilder
    private func dialStatusStrip(maxWidth: CGFloat) -> some View {
        let showLights = model.anyLightOn
        if !showLights && !model.locked {
            EmptyView()
        } else {
            VStack(spacing: 6) {
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
                if model.locked, !showLights {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                        Text("Kilitli")
                    }
                    .font(.caption2)
                    .foregroundStyle(muted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: maxWidth)
            .background(Capsule().fill(chipFill))
        }
    }

    // MARK: - Panels

    private var batteryChip: some View {
        HStack(spacing: 8) {
            Image(systemName: model.charging ? "bolt.fill" : "battery.100")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(red: 0.25, green: 0.78, blue: 0.40))
            Text(battText)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.black.opacity(0.50)))
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
            let labelW: CGFloat = min(52, w * 0.20)
            let gap: CGFloat = 8
            // Larger Model Y top-down; PSI labels stay beside the body.
            let carW = min(max(56, w - labelW * 2 - gap * 2), h * 0.46)
            let carH = min(h * 0.92, carW * 2.15)
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
            let artSize = min(250, max(170, min(geo.size.width * 0.82, geo.size.height * 0.56)))
            VStack(alignment: .center, spacing: 10) {
                styledMediaBlock(artSize: artSize, lightInk: anyBleed || night)
            }
            .frame(maxWidth: min(320, geo.size.width * 0.95))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 8)
        }
    }

    private var mediaTransportControls: some View {
        HStack(spacing: 22) {
            Button { model.skipTrack(-1) } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { model.togglePlay() } label: {
                Image(systemName: model.mediaPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.white.opacity(0.14)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)

            Button { model.skipTrack(1) } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    /// Styled album + meta based on Settings → Medya (A1–A10).
    @ViewBuilder
    private func styledMediaBlock(artSize: CGFloat, lightInk: Bool) -> some View {
        let style = settings.mediaArtStyle
        switch style {
        case .cinematic:
            cinematicMediaBlock(artSize: artSize)
        case .sideBySide:
            sideBySideMediaBlock(artSize: artSize * 0.72)
        case .magazine:
            magazineMediaBlock(artSize: artSize)
        case .sourceBar:
            VStack(spacing: 8) {
                mediaSourceBanner
                styledAlbumArt(size: artSize, style: style)
                mediaMetaStack(lightInk: lightInk, style: style)
                mediaTransportControls
            }
        case .polaroid:
            VStack(spacing: 10) {
                styledAlbumArt(size: artSize, style: style)
                mediaTransportControls
            }
        default:
            VStack(spacing: 8) {
                styledAlbumArt(size: artSize, style: style)
                if style == .waveform {
                    mediaWaveformBar(width: artSize)
                }
                mediaMetaStack(lightInk: lightInk, style: style)
                mediaTransportControls
            }
        }
    }

    private func mediaMetaStack(lightInk: Bool, style: HUDSettings.MediaArtStyle? = nil) -> some View {
        let s = style ?? settings.mediaArtStyle
        let titleColor: Color = {
            switch s {
            case .neon: return Color(red: 1.0, green: 0.45, blue: 0.85)
            case .vinyl, .tiltFloat: return .white
            case .polaroid: return Color(red: 0.12, green: 0.12, blue: 0.14)
            default: return lightInk ? .white : ink
            }
        }()
        let artistColor: Color = {
            switch s {
            case .neon: return Color(red: 0.45, green: 0.95, blue: 1.0).opacity(0.9)
            case .polaroid: return Color.black.opacity(0.55)
            default: return Color.white.opacity(0.72)
            }
        }()
        return VStack(spacing: 4) {
            Text(displayOrDash(model.mediaTitle))
                .font(.title2.weight(.bold))
                .foregroundStyle(titleColor)
                .shadow(color: s == .neon ? Color(red: 1.0, green: 0.3, blue: 0.7).opacity(0.7) : .clear, radius: 8)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Text(displayOrDash(model.mediaArtist))
                .font(.body)
                .foregroundStyle(artistColor)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
    }

    private func cinematicMediaBlock(artSize: CGFloat) -> some View {
        let h = artSize * 1.35
        return VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                AlbumArtView(image: art.image, url: art.imageURL, loading: art.loading, size: artSize)
                    .frame(width: artSize, height: h)
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        mediaSourceBadge(onCover: true)
                            .padding(.top, 10)
                            .padding(.leading, 10)
                    }
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .clear, Color.black.opacity(0.75), Color.black.opacity(0.92)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayOrDash(model.mediaTitle))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            Text(displayOrDash(model.mediaArtist))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
            }
            mediaTransportControls
        }
    }

    private func sideBySideMediaBlock(artSize: CGFloat) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                styledAlbumArt(size: artSize, style: .sideBySide)
                VStack(alignment: .leading, spacing: 8) {
                    Text(displayOrDash(model.mediaTitle))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    Text(displayOrDash(model.mediaArtist))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(Color.cyan.opacity(0.85), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                }
                Spacer(minLength: 0)
            }
            mediaTransportControls
        }
    }

    private func magazineMediaBlock(artSize: CGFloat) -> some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                AlbumArtView(image: art.image, url: art.imageURL, loading: art.loading, size: artSize)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        mediaSourceBadge(onCover: true)
                            .padding(10)
                    }
                    .overlay(alignment: .bottom) {
                        HStack(spacing: 6) {
                            Text(displayOrDash(model.mediaTitle))
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                            Text("·")
                                .font(.caption.weight(.bold))
                            Text(displayOrDash(model.mediaArtist))
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.88))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            mediaTransportControls
        }
    }

    private var mediaSourceBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: serviceIcon)
                .font(.system(size: 14, weight: .bold))
            Text(mediaSourceLabel)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(serviceAccent.opacity(0.95))
                .shadow(color: serviceAccent.opacity(0.45), radius: 8)
        )
    }

    private func mediaWaveformBar(width: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<18, id: \.self) { i in
                let h = 4 + CGFloat((i * 7) % 11)
                Capsule()
                    .fill(Color.cyan.opacity(0.75))
                    .frame(width: 3, height: h)
            }
        }
        .frame(width: width, height: 18)
    }

    @ViewBuilder
    private func styledAlbumArt(size: CGFloat, style: HUDSettings.MediaArtStyle) -> some View {
        let corner: CGFloat = style == .polaroid ? 4 : 10
        let cover = AlbumArtView(image: art.image, url: art.imageURL, loading: art.loading, size: size)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(alignment: style == .waveform ? .top : .topLeading) {
                mediaSourceBadge(onCover: true)
                    .padding(.top, 8)
                    .padding(.leading, style == .waveform ? 0 : 8)
            }

        switch style {
        case .glass, .sourceBar, .sideBySide:
            VStack(spacing: 0) {
                cover
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .stroke(Color(red: 0.4, green: 0.9, blue: 1.0).opacity(style == .glass ? 0.55 : 0.25), lineWidth: 1.4)
                    )
                    .shadow(color: Color(red: 0.3, green: 0.85, blue: 1.0).opacity(style == .glass ? 0.35 : 0.15), radius: 14)
                if style == .glass {
                    albumReflection(size: size, height: size * 0.30, corner: corner)
                }
            }
        case .vinyl:
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.15), Color.black],
                            center: .center,
                            startRadius: 4,
                            endRadius: size * 0.42
                        )
                    )
                    .frame(width: size * 0.88, height: size * 0.88)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            .frame(width: size * 0.22, height: size * 0.22)
                    )
                    .offset(x: size * 0.28)
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                cover
                    .rotationEffect(.degrees(-3))
                    .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.15).opacity(0.35), radius: 12)
            }
            .frame(width: size * 1.2, height: size)
        case .neon:
            cover
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(Color(red: 1.0, green: 0.3, blue: 0.85), lineWidth: 2)
                        .padding(2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: corner + 2, style: .continuous)
                        .stroke(Color(red: 0.3, green: 0.95, blue: 1.0), lineWidth: 2)
                        .padding(-2)
                )
                .shadow(color: Color(red: 1.0, green: 0.2, blue: 0.8).opacity(0.45), radius: 12)
                .shadow(color: Color(red: 0.2, green: 0.9, blue: 1.0).opacity(0.35), radius: 18)
        case .polaroid:
            VStack(spacing: 0) {
                cover
                    .padding(10)
                    .padding(.bottom, 0)
                mediaMetaStack(lightInk: false, style: .polaroid)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
                    .padding(.top, 8)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
        case .waveform, .magazine, .cinematic:
            cover
        case .tiltFloat:
            cover
                .rotationEffect(.degrees(-8))
                .shadow(color: .black.opacity(0.55), radius: 16, y: 10)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
        }
    }

    private func albumReflection(size: CGFloat, height: CGFloat, corner: CGFloat) -> some View {
        AlbumArtView(image: art.image, url: art.imageURL, loading: art.loading, size: size)
            .scaleEffect(x: 1, y: -1)
            .frame(height: height, alignment: .top)
            .clipped()
            .opacity(0.40)
            .mask(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.85),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0.06),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .allowsHitTesting(false)
    }

    /// Source chip — sits on top of the album cover (Spotify / YouTube Music / …).
    private func mediaSourceBadge(onCover: Bool) -> some View {
        let label = mediaSourceLabel
        return HStack(spacing: 5) {
            Image(systemName: serviceIcon)
                .font(.system(size: 11, weight: .bold))
            Text(label)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(serviceAccent.opacity(onCover ? 0.95 : 0.88))
                .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.8))
                .shadow(color: serviceAccent.opacity(0.5), radius: 6)
        )
        .zIndex(5)
    }

    /// Prefer a readable source name even when BLE only sent an enum / empty.
    private var mediaSourceLabel: String {
        let s = model.mediaService.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isBlank(s) { return s }
        if !isBlank(model.mediaTitle) || !isBlank(model.mediaArtist) { return "Medya" }
        return "Medya"
    }

    private var mediaServiceHeader: some View {
        mediaSourceBadge(onCover: false)
    }

    private var serviceIcon: String {
        let s = model.mediaService.lowercased()
        if s.contains("youtube") { return "play.rectangle.fill" }
        if s.contains("spotify") { return "music.note.list" }
        if s.contains("tidal") { return "waveform" }
        if s.contains("apple") { return "applelogo" }
        if s.contains("bluetooth") { return "wave.3.right" }
        return "music.note"
    }

    private var serviceAccent: Color {
        let s = model.mediaService.lowercased()
        if s.contains("youtube") { return Color(red: 0.95, green: 0.15, blue: 0.2) }
        if s.contains("spotify") { return Color(red: 0.15, green: 0.75, blue: 0.4) }
        if s.contains("tidal") { return Color(red: 0.1, green: 0.1, blue: 0.12) }
        if s.contains("apple") { return Color(red: 0.95, green: 0.3, blue: 0.45) }
        if s.contains("bluetooth") { return Color(red: 0.25, green: 0.55, blue: 0.95) }
        return Color(red: 0.35, green: 0.4, blue: 0.5)
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

/// Local-only speed tick — does NOT publish into HUDModel (avoids Metal SIGABRT from 60Hz rebuilds).
private struct DialSpeedDigits: View {
    let target: Double
    let fontSize: CGFloat
    let ink: Color
    let bare: Bool

    @State private var shown: Double = 0
    @State private var booted = false

    /// Shared publisher — one timer for the dial, not a new one every body pass.
    private static let ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Text("\(Int(abs(shown).rounded()))")
            .font(.system(size: fontSize, weight: .thin, design: .default))
            .monospacedDigit()
            .foregroundStyle(ink)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .tracking(-fontSize * 0.04)
            .transaction { $0.animation = nil }
            .shadow(color: .black.opacity(0.85), radius: bare ? 12 : 5, y: bare ? 7 : 3)
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
            .onAppear {
                if !booted {
                    shown = target
                    booted = true
                }
            }
            .onReceive(Self.ticker) { _ in
                stepTowardTarget()
            }
    }

    private func stepTowardTarget() {
        let gap = target - shown
        let absGap = abs(gap)
        guard absGap >= 0.45 else {
            if shown != target { shown = target }
            return
        }
        let steps: Double
        if absGap > 28 { steps = 4 }
        else if absGap > 14 { steps = 2 }
        else { steps = 1 }
        let move = min(absGap, steps)
        shown = shown + (gap > 0 ? move : -move)
    }
}

/// Thin green “charging” light line across the top of the HUD.
private struct ChargingTopRibbon: View {
    @State private var pulse = false
    @State private var sweep: CGFloat = -0.35

    private let green = Color(red: 0.22, green: 0.92, blue: 0.48)
    private let greenDeep = Color(red: 0.08, green: 0.62, blue: 0.32)

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    Capsule()
                        .fill(green.opacity(pulse ? 0.45 : 0.22))
                        .frame(height: 10)
                        .blur(radius: 8)
                        .padding(.horizontal, 40)
                        .padding(.top, 2)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    greenDeep.opacity(0.15),
                                    green,
                                    Color.white.opacity(0.95),
                                    green,
                                    greenDeep.opacity(0.15),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 3.5)
                        .shadow(color: green.opacity(pulse ? 0.9 : 0.5), radius: pulse ? 10 : 5)
                        .padding(.horizontal, 28)
                        .padding(.top, 6)
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.85), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 64, height: 3.5)
                                .offset(x: sweep * geo.size.width * 0.55)
                                .padding(.top, 6)
                                .allowsHitTesting(false)
                        }

                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("ŞARJ")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.1)
                    }
                    .foregroundStyle(green)
                    .shadow(color: green.opacity(0.7), radius: 6)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
                    .padding(.top, 14)
                }
                Spacer(minLength: 0)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                sweep = 0.35
            }
        }
        .accessibilityLabel("Şarj oluyor")
    }
}
