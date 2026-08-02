import SwiftUI

/// Fixed night triad HUD — no Canvas/MapKit/WebKit/UIImage.
/// Left slides stay in a fixed frame (no layout jump). Center dial always readable.
struct NativeHUDView: View {
    @ObservedObject var model: HUDModel
    var linkLabel: String
    var onBack: () -> Void

    private let ink = Color.white
    private let muted = Color.white.opacity(0.5)
    private let dim = Color.white.opacity(0.22)
    private let accent = Color(red: 0.35, green: 0.85, blue: 0.75)

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= geo.size.height
            let topH: CGFloat = 44
            let botH: CGFloat = 36
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                Group {
                    if wide {
                        HStack(spacing: 0) {
                            leftColumn
                                .frame(width: geo.size.width * 0.30)
                            rail
                                .padding(.horizontal, 4)
                            centerDial
                                .frame(width: geo.size.width * 0.34)
                            mapPanel
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(spacing: 0) {
                            centerDial
                                .frame(height: max(210, geo.size.height * 0.38))
                            HStack(spacing: 0) {
                                leftColumn
                                rail.padding(.horizontal, 4)
                                mapPanel
                            }
                        }
                    }
                }
                .padding(.top, topH)
                .padding(.bottom, botH)

                VStack(spacing: 0) {
                    topBar.frame(height: topH)
                    Spacer()
                    bottomBar.frame(height: botH)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    // MARK: - Bars

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ink)
                    .frame(width: 28, height: 28)
            }
            Text(model.clock.isEmpty ? "--:--" : model.clock)
                .font(.headline.monospacedDigit())
                .foregroundStyle(ink)
            Text("\(model.outdoorC)°")
                .font(.subheadline)
                .foregroundStyle(muted)
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Circle()
                    .fill(model.bleOK ? accent : Color.orange.opacity(0.8))
                    .frame(width: 7, height: 7)
                Text(linkLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(model.bleOK ? accent : muted)
                    .lineLimit(1)
            }
            Button(model.driving ? "DUR" : "SÜR") {
                model.toggleDrive()
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(model.liveLocked ? muted : (model.driving ? Color.orange : accent))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().stroke((model.liveLocked ? muted : (model.driving ? Color.orange : accent)).opacity(0.5), lineWidth: 1))
            .disabled(model.liveLocked)
            Text("\(Int(model.battery))%")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(ink)
        }
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.92))
    }

    private var bottomBar: some View {
        HStack {
            Text("\(Int(model.battery))%  ·  \(model.rangeKm) km")
                .font(.caption.monospacedDigit())
                .foregroundStyle(ink)
            Spacer()
            Text(HUDModel.slideNames[model.leftSlide].uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)
            Spacer()
            Text(model.telemetrySource)
                .font(.caption2.weight(.bold))
                .foregroundStyle(model.isLive ? accent : (model.feedOK ? Color.orange : dim))
            Text(String(format: "ODO %.0f", model.odometer))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(muted)
        }
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.92))
    }

    // MARK: - Rail

    private var rail: some View {
        VStack(spacing: 14) {
            ForEach(0..<HUDModel.slideCount, id: \.self) { i in
                Button { model.setLeft(i) } label: {
                    Image(systemName: HUDModel.slideIcons[i])
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(i == model.leftSlide ? ink : dim)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(i == model.leftSlide ? Color.white.opacity(0.12) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(HUDModel.slideNames[i])
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }

    // MARK: - Left column (fixed box — no jump)

    private var leftColumn: some View {
        ZStack {
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
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 28)
                .onEnded { g in
                    if g.translation.height < -36 { model.nudgeLeft(1) }
                    else if g.translation.height > 36 { model.nudgeLeft(-1) }
                }
        )
    }

    private var simplePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("SADE")
            Text(model.isLive ? "CANLI TESLA" : (model.feedOK ? "Dash verisi" : (model.bleOK ? "Key bağlı" : "Pair / Live")))
                .font(.title2.weight(.semibold))
                .foregroundStyle(ink)
            if !model.vehicleName.isEmpty {
                Text(model.vehicleName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(accent)
            }
            Text("VIN …\(model.vinTail)")
                .font(.footnote.monospaced())
                .foregroundStyle(muted)
            Text(linkLabel)
                .font(.caption)
                .foregroundStyle(model.bleOK ? accent : muted)
            if !model.feedError.isEmpty {
                Text(model.feedError)
                    .font(.caption2)
                    .foregroundStyle(Color.orange)
            }
            Spacer(minLength: 0)
            HStack(spacing: 16) {
                metric("Hız", "\(Int(abs(model.speed).rounded()))", "km/h")
                metric("Güç", String(format: "%.0f", model.powerKW), "kW")
            }
            Text(model.liveLocked ? "Vites/hız arabadan gelir" : "Kaydır ↑↓ · ikonlarla panel")
                .font(.caption2)
                .foregroundStyle(dim)
        }
    }

    private func metric(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(muted)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.title.monospacedDigit().weight(.bold)).foregroundStyle(ink)
                Text(unit).font(.caption).foregroundStyle(muted)
            }
        }
    }

    private var tripPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("ROTA")
            tripRow("Hedef", model.destination)
            tripRow("Varış", model.eta)
            tripRow("Varışta enerji", model.energyAtArrival)
            tripRow("Mesafe", model.tripDist)
            Spacer(minLength: 0)
            Text(model.place)
                .font(.caption)
                .foregroundStyle(muted)
                .lineLimit(2)
        }
    }

    private func tripRow(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(k.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(muted)
            Text(v)
                .font(.title3.weight(.semibold))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }

    private var tiresPanel: some View {
        VStack(spacing: 10) {
            HStack {
                sectionTitle("LASTİK")
                Spacer()
                if model.liveLocked {
                    Text(model.isLive ? "CANLI" : "DASH")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accent)
                } else {
                    Button("Sıfırla") { model.resetTires() }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent)
                }
            }
            Text("MODEL Y")
                .font(.caption.weight(.bold))
                .foregroundStyle(dim)
            Image(systemName: "car.fill")
                .font(.system(size: 48))
                .foregroundStyle(ink.opacity(0.75))
                .rotationEffect(.degrees(90))
                .padding(.vertical, 4)
            HStack {
                tireCell("FL", model.psiFL) { model.adjustTire("FL", delta: $0) }
                Spacer(minLength: 8)
                tireCell("FR", model.psiFR) { model.adjustTire("FR", delta: $0) }
            }
            HStack {
                tireCell("RL", model.psiRL) { model.adjustTire("RL", delta: $0) }
                Spacer(minLength: 8)
                tireCell("RR", model.psiRR) { model.adjustTire("RR", delta: $0) }
            }
            Spacer(minLength: 0)
        }
    }

    private func tireCell(_ corner: String, _ psi: Int, adjust: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 6) {
            Text(corner).font(.caption2.weight(.bold)).foregroundStyle(muted)
            Text("\(psi)")
                .font(.title2.monospacedDigit().weight(.bold))
                .foregroundStyle(psi < 35 || psi > 46 ? Color.orange : ink)
            Text("psi").font(.caption2).foregroundStyle(dim)
            if !model.liveLocked {
                HStack(spacing: 10) {
                    Button { adjust(-1) } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(muted)
                    }
                    .buttonStyle(.plain)
                    Button { adjust(1) } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minWidth: 88)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
    }

    private var mapInfoPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("HARİTA")
            Text(model.place)
                .font(.title3.weight(.semibold))
                .foregroundStyle(ink)
                .lineLimit(3)
            Text(model.destination)
                .font(.subheadline)
                .foregroundStyle(muted)
            Text(model.tripDist)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(ink)
            Text(String(format: "Yön %.0f°", model.mapHeading))
                .font(.caption.monospacedDigit())
                .foregroundStyle(dim)
            Spacer(minLength: 0)
        }
    }

    private var mediaPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(model.mediaService.uppercased())
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.85, green: 0.45, blue: 0.15), Color(red: 0.4, green: 0.15, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.45))
                )
            Text(model.mediaTitle)
                .font(.headline)
                .foregroundStyle(ink)
                .lineLimit(1)
            Text(model.mediaArtist)
                .font(.subheadline)
                .foregroundStyle(muted)
            // Progress
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12)).frame(height: 4)
                    Capsule().fill(accent).frame(width: max(4, g.size.width * model.mediaProgress), height: 4)
                }
            }
            .frame(height: 4)
            // Transport
            HStack(spacing: 22) {
                Button { model.skipTrack(-1) } label: {
                    Image(systemName: "backward.fill").font(.title3).foregroundStyle(ink)
                }
                .buttonStyle(.plain)
                Button { model.togglePlay() } label: {
                    Image(systemName: model.mediaPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(ink)
                }
                .buttonStyle(.plain)
                Button { model.skipTrack(1) } label: {
                    Image(systemName: "forward.fill").font(.title3).foregroundStyle(ink)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            // Volume
            HStack(spacing: 10) {
                Button { model.nudgeVolume(-0.1) } label: {
                    Image(systemName: "speaker.fill").foregroundStyle(muted)
                }
                .buttonStyle(.plain)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12)).frame(height: 4)
                        Capsule().fill(ink.opacity(0.8)).frame(width: max(4, g.size.width * model.mediaVolume), height: 4)
                    }
                }
                .frame(height: 4)
                Button { model.nudgeVolume(0.1) } label: {
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(muted)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t)
            .font(.caption.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(muted)
    }

    // MARK: - Center dial (always centered)

    private var centerDial: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                ForEach(["P", "R", "N", "D"], id: \.self) { g in
                    Button { model.setGear(g) } label: {
                        Text(g)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(model.gear == g ? ink : dim)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.liveLocked)
                }
            }
            ZStack {
                Circle()
                    .fill(Color(white: 0.07))
                    .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1.5))
                Circle()
                    .trim(from: 0, to: min(1, abs(model.speed) / 160))
                    .stroke(accent.opacity(0.85), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(6)
                VStack(spacing: 0) {
                    Text("\(Int(abs(model.speed).rounded()))")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ink)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("km/h")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(muted)
                }
            }
            .frame(width: 196, height: 196)
            Text(String(format: "%+.0f kW", model.powerKW))
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(model.powerKW >= 0 ? accent : Color.orange)
            Text(model.place)
                .font(.caption)
                .foregroundStyle(muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Map panel (no MapKit — GPS + heading)

    private var mapPanel: some View {
        ZStack(alignment: .bottomTrailing) {
            VehicleMapView(lat: model.latitude, lon: model.longitude, heading: model.mapHeading)
            VStack(alignment: .trailing, spacing: 6) {
                Text(model.telemetrySource == "BLE" ? "GPS · BLE" : (model.isLive ? "GPS · LIVE" : "GPS"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.92)))
                Text(model.gear)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.9)))
                Text(model.tripDist)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.9)))
            }
            .padding(10)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .leading) {
            LinearGradient(colors: [Color.black.opacity(0.8), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 36)
                .allowsHitTesting(false)
        }
        .clipped()
    }
}
