import SwiftUI

/// Single-app Tesla cluster — SwiftUI only, no WKWebView / no remote Dash.
struct NativeHUDView: View {
    @ObservedObject var model: HUDModel
    var onBack: () -> Void

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= geo.size.height
            ZStack {
                background
                VStack(spacing: 0) {
                    topBar
                    if wide {
                        landscape
                    } else {
                        portrait
                    }
                    bottomBar
                }
            }
        }
        .preferredColorScheme(model.night ? .dark : .light)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            model.start()
            model.beginAfterPair()
        }
        .onDisappear { model.stop() }
    }

    private var accent: Color { Color(red: 0.24, green: 0.91, blue: 0.77) }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: model.night
                    ? [Color(red: 0.04, green: 0.05, blue: 0.07), Color.black]
                    : [Color(red: 0.92, green: 0.93, blue: 0.95), Color(red: 0.82, green: 0.85, blue: 0.90)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [.clear, Color.black.opacity(model.night ? 0.4 : 0.06)],
                center: .center,
                startRadius: 60,
                endRadius: 640
            )
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Label("Pair", systemImage: "chevron.left")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(accent)

            Text(model.clock.isEmpty ? "—" : model.clock)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(model.bleOK ? accent : Color.red.opacity(0.85))
                    .frame(width: 8, height: 8)
                Text(model.bleOK ? "PHONE KEY" : "NO KEY")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(model.bleOK ? accent : .red)
            }

            Text("…\(model.vinTail)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("\(model.outdoorC)°")
                .font(.system(size: 13, weight: .medium, design: .rounded))

            Button(model.night ? "Gunduz" : "Gece") { model.night.toggle() }
                .font(.caption2)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var bottomBar: some View {
        HStack {
            Text("\(Int(model.battery))% / \(model.rangeKm) km")
                .foregroundStyle(accent)
            Spacer()
            Text(model.place)
                .foregroundStyle(.secondary)
            Spacer()
            Text("ODO \(Int(model.odometer).formatted())")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var landscape: some View {
        HStack(alignment: .center, spacing: 8) {
            sideTrip
                .frame(maxWidth: .infinity)
            centerStack
                .frame(maxWidth: .infinity)
            sideBattery
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
    }

    private var portrait: some View {
        VStack(spacing: 10) {
            centerStack
                .frame(maxHeight: .infinity)
            HStack(alignment: .top, spacing: 12) {
                sideTrip.frame(maxWidth: .infinity)
                sideBattery.frame(maxWidth: .infinity)
            }
            .frame(maxHeight: 200)
        }
        .padding(.horizontal, 12)
    }

    private var sideTrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SEYAHAT")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            row("Hedef", model.destination)
            row("Varis", model.eta)
            row("Varista enerji", model.energyAtArrival)
            row("Mesafe", model.tripDist)
            Divider().opacity(0.25)
            Text("LASTIK")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            HStack {
                psi("FL", model.psiFL)
                psi("FR", model.psiFR)
                psi("RL", model.psiRL)
                psi("RR", model.psiRR)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }

    private var sideBattery: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text("BATARYA")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            Text("\(Int(model.battery))%")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .monospacedDigit()
            Text("\(model.rangeKm) km menzil")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Text(String(format: "%+.0f kW", model.powerKW))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(model.powerKW < 0 ? Color.red.opacity(0.9) : accent)
            Divider().opacity(0.25)
            Text("MEDYA")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            Text(model.mediaTitle)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Text(model.mediaArtist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
            Spacer(minLength: 0)
        }
        .padding(12)
    }

    private var centerStack: some View {
        VStack(spacing: 10) {
            gearRow
            SpeedRing(speed: model.speed, powerKW: model.powerKW, accent: accent, night: model.night)
                .frame(maxWidth: 320, maxHeight: 300)
            Button {
                model.toggleDrive()
            } label: {
                Text(model.driving ? "DURDUR" : "SÜR (cihaz ici)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .foregroundStyle(.black)
            Text(model.bleOK ? "Veriler bu uygulamada · WebView yok" : "Once Pair Vehicle yap")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var gearRow: some View {
        HStack(spacing: 22) {
            ForEach(["P", "R", "N", "D"], id: \.self) { g in
                Text(g)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(model.gear == g ? accent : Color.secondary.opacity(0.4))
                    .scaleEffect(model.gear == g ? 1.12 : 1)
                    .animation(.easeOut(duration: 0.2), value: model.gear)
            }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(.secondary)
            Spacer()
            Text(v).fontWeight(.semibold)
        }
        .font(.system(size: 13, design: .rounded))
    }

    private func psi(_ corner: String, _ v: Int) -> some View {
        VStack(spacing: 2) {
            Text(corner)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text("\(v)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("psi")
                .font(.system(size: 8, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SpeedRing: View {
    let speed: Double
    let powerKW: Double
    let accent: Color
    let night: Bool

    private var progress: Double { min(1, max(0, speed / 220)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 18)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [accent.opacity(0.3), accent, powerKW < 0 ? Color.red : accent],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.12), value: speed)

            VStack(spacing: 2) {
                Text("\(Int(speed.rounded()))")
                    .font(.system(size: 84, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("km/h")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(String(format: "%+.0f kW", powerKW))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(powerKW < 0 ? Color.red.opacity(0.9) : accent)
            }
        }
        .padding(10)
    }
}
