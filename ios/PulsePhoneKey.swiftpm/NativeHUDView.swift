import SwiftUI

/// Ultra-stable night HUD — NO Canvas, TimelineView, MapKit, WebKit, UIImage.
/// 5 left slides + dial + simple map panel. BLE link status from pairer.
struct NativeHUDView: View {
    @ObservedObject var model: HUDModel
    var linkLabel: String
    var onBack: () -> Void

    private let ink = Color.white
    private let muted = Color.white.opacity(0.45)
    private let bg = Color.black

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                bg.ignoresSafeArea()
                if wide {
                    HStack(spacing: 0) {
                        leftPane.frame(width: geo.size.width * 0.32)
                        rail
                        centerPane.frame(width: geo.size.width * 0.30)
                        simpleMap.frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        centerPane.frame(height: geo.size.height * 0.35)
                        HStack(spacing: 0) {
                            leftPane
                            rail
                            simpleMap
                        }
                    }
                }
                VStack {
                    topBar
                    Spacer()
                    bottomBar
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left").foregroundStyle(muted)
            }
            Text(model.clock.isEmpty ? "--:--" : model.clock)
                .font(.headline.monospacedDigit())
                .foregroundStyle(ink)
            Text("\(model.outdoorC)°C").font(.subheadline).foregroundStyle(muted)
            Spacer()
            Text(linkLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(model.bleOK ? Color.green : muted)
            Button(model.driving ? "Dur" : "Sur") { model.toggleDrive() }
                .font(.caption.weight(.semibold))
                .foregroundStyle(ink)
            Text("\(Int(model.battery))%").font(.caption.monospacedDigit()).foregroundStyle(ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.55))
    }

    private var bottomBar: some View {
        HStack {
            Text("\(Int(model.battery))% / \(model.rangeKm)km")
                .font(.caption.monospacedDigit())
                .foregroundStyle(ink)
            Spacer()
            Text(HUDModel.slideNames[model.leftSlide])
                .font(.caption2.weight(.semibold))
                .foregroundStyle(muted)
            Spacer()
            Text(String(format: "ODO %.0f", model.odometer))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.55))
    }

    private var rail: some View {
        VStack(spacing: 12) {
            ForEach(0..<HUDModel.slideCount, id: \.self) { i in
                Button { model.setLeft(i) } label: {
                    Image(systemName: HUDModel.slideIcons[i])
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(i == model.leftSlide ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 7)
        .background(Capsule().fill(Color.white.opacity(0.08)))
    }

    private var leftPane: some View {
        Group {
            switch model.leftSlide {
            case 1: tires
            case 2: trip
            case 3: mapInfo
            case 4: media
            default: simple
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { g in
                    if g.translation.height < -30 { model.nudgeLeft(1) }
                    else if g.translation.height > 30 { model.nudgeLeft(-1) }
                }
        )
    }

    private var simple: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SADE").font(.caption).foregroundStyle(muted)
            Text(model.bleOK ? "Araca bagli" : "Pair gerekli")
                .font(.title3.weight(.semibold)).foregroundStyle(ink)
            Text("…\(model.vinTail)").font(.footnote.monospaced()).foregroundStyle(muted)
            Text(linkLabel).font(.caption2).foregroundStyle(muted)
        }
    }

    private var trip: some View {
        VStack(alignment: .leading, spacing: 10) {
            row("Destination", model.destination)
            row("Arrival Time", model.eta)
            row("Energy", model.energyAtArrival)
            row("Distance", model.tripDist)
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.caption2).foregroundStyle(muted)
            Text(v).font(.headline).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private var tires: some View {
        VStack(spacing: 14) {
            Text("MODEL Y").font(.caption.weight(.bold)).foregroundStyle(muted)
            Image(systemName: "car.fill")
                .font(.system(size: 56))
                .foregroundStyle(ink.opacity(0.7))
                .rotationEffect(.degrees(90))
            HStack {
                Text("\(model.psiFL) psi").foregroundStyle(ink)
                Spacer()
                Text("\(model.psiFR) psi").foregroundStyle(ink)
            }
            .font(.subheadline.monospacedDigit())
            HStack {
                Text("\(model.psiRL) psi").foregroundStyle(ink)
                Spacer()
                Text("\(model.psiRR) psi").foregroundStyle(ink)
            }
            .font(.subheadline.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }

    private var mapInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HARITA").font(.caption).foregroundStyle(muted)
            Text(model.place).font(.headline).foregroundStyle(ink)
            Text(model.destination).font(.subheadline).foregroundStyle(muted)
            Text(model.tripDist).font(.title2.weight(.bold)).foregroundStyle(ink)
        }
    }

    private var media: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.mediaService).font(.caption).foregroundStyle(muted)
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.75, green: 0.4, blue: 0.15))
                .frame(width: 100, height: 100)
                .overlay(Image(systemName: "music.note").foregroundStyle(.white.opacity(0.4)))
            Text(model.mediaTitle).font(.headline).foregroundStyle(ink)
            Text(model.mediaArtist).font(.subheadline).foregroundStyle(muted)
            Button { model.togglePlay() } label: {
                Image(systemName: model.mediaPlaying ? "pause.fill" : "play.fill")
                    .foregroundStyle(ink)
            }
            .buttonStyle(.plain)
        }
    }

    private var centerPane: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                ForEach(["P", "R", "N", "D"], id: \.self) { g in
                    Text(g)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(model.gear == g ? ink : ink.opacity(0.25))
                }
            }
            ZStack {
                Circle().fill(Color(white: 0.06))
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                VStack(spacing: 0) {
                    Text("\(Int(model.speed.rounded()))")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ink)
                    Text("km/h").font(.caption).foregroundStyle(muted)
                }
            }
            .frame(width: 180, height: 180)
            Text(model.place)
                .font(.caption)
                .foregroundStyle(muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Plain SwiftUI shapes only — no Canvas.
    private var simpleMap: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(red: 0.88, green: 0.87, blue: 0.84)
            VStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { i in
                    Rectangle()
                        .fill(Color(white: 0.72 - Double(i % 3) * 0.04))
                        .frame(width: 40 + CGFloat(i % 3) * 18, height: 28 + CGFloat(i % 2) * 12)
                        .rotationEffect(.degrees(-8))
                        .offset(x: CGFloat((i % 3) - 1) * 36, y: CGFloat(i) * 8 - 40)
                }
            }
            Image(systemName: "location.north.fill")
                .font(.title)
                .foregroundStyle(Color.red)
                .offset(y: -30)
            Text("N")
                .font(.caption.weight(.bold))
                .foregroundStyle(.black.opacity(0.7))
                .padding(8)
                .background(Circle().fill(Color.white.opacity(0.9)))
                .padding(10)
        }
        .overlay(alignment: .leading) {
            LinearGradient(colors: [Color.black.opacity(0.75), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 40)
        }
    }
}
