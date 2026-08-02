import SwiftUI

/// Minimal stable HUD — no MapKit, no UIImage/base64, no Canvas, no fancy effects.
struct NativeHUDView: View {
    @ObservedObject var model: HUDModel
    var onBack: () -> Void

    private let bg = Color(red: 0.88, green: 0.89, blue: 0.91)
    private let ink = Color(red: 0.11, green: 0.11, blue: 0.12)
    private let muted = Color.black.opacity(0.45)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                HStack(spacing: 0) {
                    panel(side: .left)
                    center
                    panel(side: .right)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            model.night = false
            model.start()
        }
        .onDisappear { model.stop() }
    }

    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(ink.opacity(0.7))
            }
            Text(model.clock.isEmpty ? "--:--" : model.clock)
                .font(.headline.monospacedDigit())
                .foregroundStyle(ink)
            Text(model.bleOK ? "HUD HAZIR" : "HUD")
                .font(.caption.weight(.semibold))
                .foregroundStyle(muted)
            Spacer()
            Button("Sur") { model.toggleDrive() }
                .font(.caption.weight(.semibold))
            Text("\(Int(model.battery))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private enum Side { case left, right }

    private func panel(side: Side) -> some View {
        let index = side == .left ? model.leftSlide : model.rightSlide
        return VStack(spacing: 8) {
            Spacer(minLength: 0)
            slide(index)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 6) {
                ForEach(0..<HUDModel.slideCount, id: \.self) { i in
                    Circle()
                        .fill(i == index ? ink : ink.opacity(0.2))
                        .frame(width: 6, height: 6)
                        .onTapGesture {
                            if side == .left { model.setLeft(i) } else { model.setRight(i) }
                        }
                }
            }
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { g in
                    let up = g.translation.height < -40
                    let down = g.translation.height > 40
                    if side == .left {
                        if up { model.nudgeLeft(1) }
                        if down { model.nudgeLeft(-1) }
                    } else {
                        if up { model.nudgeRight(1) }
                        if down { model.nudgeRight(-1) }
                    }
                }
        )
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func slide(_ index: Int) -> some View {
        switch index {
        case 1: tires
        case 2: map
        case 3: media
        default: trip
        }
    }

    private var trip: some View {
        VStack(alignment: .leading, spacing: 12) {
            row("Destination", model.destination)
            row("Arrival Time", model.eta)
            row("Energy at Arrival", model.energyAtArrival)
            row("Distance", model.tripDist)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
    }

    private func row(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(muted)
            Text(v)
                .font(.title3.weight(.semibold))
                .foregroundStyle(ink)
        }
    }

    /// Simple Tesla label + PSI — no photo decode (crash-safe).
    private var tires: some View {
        VStack(spacing: 16) {
            Text("MODEL Y")
                .font(.caption.weight(.bold))
                .foregroundStyle(muted)
            Image(systemName: "car.fill")
                .font(.system(size: 64))
                .foregroundStyle(ink.opacity(0.55))
                .rotationEffect(.degrees(90))
            HStack {
                psi("FL", model.psiFL)
                psi("FR", model.psiFR)
            }
            HStack {
                psi("RL", model.psiRL)
                psi("RR", model.psiRR)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func psi(_ c: String, _ v: Int) -> some View {
        VStack(spacing: 2) {
            Text(c).font(.caption2).foregroundStyle(muted)
            Text("\(v)").font(.title2.weight(.bold).monospacedDigit()).foregroundStyle(ink)
            Text("psi").font(.caption2).foregroundStyle(muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var map: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.86, green: 0.90, blue: 0.84))
            VStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(ink.opacity(0.35))
                Text("Harita")
                    .font(.headline)
                    .foregroundStyle(ink.opacity(0.7))
                Text(model.place)
                    .font(.subheadline)
                    .foregroundStyle(muted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var media: some View {
        VStack(spacing: 10) {
            Text(model.mediaService)
                .font(.caption)
                .foregroundStyle(muted)
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.2, green: 0.21, blue: 0.24))
                .frame(width: 120, height: 120)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.4))
                }
            Text(model.mediaTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(ink)
            Text(model.mediaArtist)
                .font(.subheadline)
                .foregroundStyle(muted)
            Button {
                model.togglePlay()
            } label: {
                Image(systemName: model.mediaPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(ink.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var center: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                ForEach(["P", "R", "N", "D"], id: \.self) { g in
                    Text(g)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(model.gear == g ? ink : ink.opacity(0.25))
                }
            }
            ZStack {
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                VStack(spacing: 2) {
                    Text("\(Int(model.speed.rounded()))")
                        .font(.system(size: 84, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ink)
                    Text("km/h")
                        .font(.subheadline)
                        .foregroundStyle(muted)
                }
            }
            .frame(width: 240, height: 240)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
