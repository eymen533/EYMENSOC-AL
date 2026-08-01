import SwiftUI

/// Native Tesla-style landscape cluster — no WebView.
struct NativeHUDView: View {
    @ObservedObject var model: HUDModel
    var onBack: () -> Void

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                background

                if wide {
                    landscape
                } else {
                    // Prompt rotate on portrait
                    VStack(spacing: 16) {
                        Text("Pulse HUD")
                            .font(.largeTitle.bold())
                        Text("iPad’i yatay çevir")
                            .foregroundStyle(.secondary)
                        Button("Pair’e dön", action: onBack)
                    }
                }
            }
        }
        .preferredColorScheme(model.night ? .dark : .light)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: model.night
                    ? [Color(red: 0.04, green: 0.05, blue: 0.07), Color(red: 0.08, green: 0.10, blue: 0.14)]
                    : [Color(red: 0.92, green: 0.93, blue: 0.95), Color(red: 0.82, green: 0.85, blue: 0.90)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // subtle vignette
            RadialGradient(
                colors: [.clear, Color.black.opacity(model.night ? 0.45 : 0.08)],
                center: .center,
                startRadius: 80,
                endRadius: 700
            )
        }
        .ignoresSafeArea()
    }

    private var landscape: some View {
        HStack(spacing: 0) {
            leftRail
                .frame(width: 150)
            centerStack
                .frame(maxWidth: .infinity)
            rightRail
                .frame(width: 150)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var leftRail: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onBack) {
                Label("Pair", systemImage: "chevron.left")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(accent)

            Spacer()

            psi("FL", model.psiFL)
            psi("RL", model.psiRL)

            Spacer()

            Text("TRIP")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f km", model.tripKm))
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text("ODO \(Int(model.odometer))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var rightRail: some View {
        VStack(alignment: .trailing, spacing: 14) {
            HStack(spacing: 6) {
                Circle()
                    .fill(model.bleOK ? accent : Color.red.opacity(0.8))
                    .frame(width: 8, height: 8)
                Text(model.bleOK ? "PHONE KEY" : "NO KEY")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(model.bleOK ? accent : .red)
            }

            Text("Y …\(model.vinTail)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            psi("FR", model.psiFR)
            psi("RR", model.psiRR)

            Spacer()

            Text("\(model.outdoorC)°")
                .font(.system(size: 22, weight: .medium, design: .rounded))

            Button(model.night ? "Gündüz" : "Gece") {
                model.night.toggle()
            }
            .font(.caption)
        }
    }

    private var centerStack: some View {
        VStack(spacing: 8) {
            gearRow

            SpeedRing(
                speed: model.speed,
                powerKW: model.powerKW,
                accent: accent,
                night: model.night
            )
            .frame(maxHeight: 320)

            HStack(spacing: 28) {
                batteryChip
                Button {
                    model.toggleDrive()
                } label: {
                    Text(model.driving ? "DURDUR" : "SÜR (demo)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .foregroundStyle(.black)

                Text("\(model.rangeKm) km")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var gearRow: some View {
        HStack(spacing: 20) {
            ForEach(["P", "R", "N", "D"], id: \.self) { g in
                Text(g)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(model.gear == g ? accent : Color.secondary.opacity(0.45))
                    .scaleEffect(model.gear == g ? 1.15 : 1)
                    .animation(.easeOut(duration: 0.2), value: model.gear)
            }
        }
    }

    private var batteryChip: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 70, height: 12)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(model.battery > 20 ? accent : Color.red)
                        .frame(width: 70 * model.battery / 100, height: 12)
                }
            Text("\(Int(model.battery))%")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
    }

    private func psi(_ corner: String, _ v: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(corner)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text("\(v)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text("psi")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var accent: Color {
        Color(red: 0.24, green: 0.91, blue: 0.77) // cyan
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
                    .font(.system(size: 88, weight: .bold, design: .rounded))
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
        .padding(12)
    }
}
