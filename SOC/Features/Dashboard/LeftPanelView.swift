import SwiftUI

struct LeftPanelView: View {
    @Binding var mode: LeftPanelMode
    let state: VehicleState
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject private var media = NowPlayingService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 42)

            Group {
                switch mode {
                case .vehicle:
                    vehicleDiagram
                case .media:
                    mediaPanel
                case .trip:
                    tripPanel
                case .controls:
                    controlsPanel
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            batteryFooter
                .padding(.bottom, 18)
                .padding(.leading, 44)
        }
        .padding(.trailing, 8)
    }

    private var vehicleDiagram: some View {
        GeometryReader { geo in
            let carWidth = min(geo.size.width * 0.58, 170)
            let carHeight = carWidth * 1.55

            ZStack {
                Image("TeslaModel3Top")
                    .resizable()
                    .scaledToFit()
                    .frame(width: carWidth, height: carHeight)
                    .shadow(color: .white.opacity(0.08), radius: 18, y: 0)
                    .accessibilityLabel("Tesla Model 3")

                // FL / FR / RL / RR pressure callouts around the real top-down model.
                tireBadge(
                    state.tirePressure.formatted(state.tirePressure.fl),
                    at: CGPoint(x: geo.size.width * 0.14, y: geo.size.height * 0.28)
                )
                tireBadge(
                    state.tirePressure.formatted(state.tirePressure.fr),
                    at: CGPoint(x: geo.size.width * 0.86, y: geo.size.height * 0.28)
                )
                tireBadge(
                    state.tirePressure.formatted(state.tirePressure.rl),
                    at: CGPoint(x: geo.size.width * 0.14, y: geo.size.height * 0.72)
                )
                tireBadge(
                    state.tirePressure.formatted(state.tirePressure.rr),
                    at: CGPoint(x: geo.size.width * 0.86, y: geo.size.height * 0.72)
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .padding(.leading, 28)
        .padding(.top, 12)
    }

    private func tireBadge(_ value: String, at point: CGPoint) -> some View {
        Text("\(value) psi")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(SOCTheme.textSecondary)
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
            .position(point)
    }

    private var mediaPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "music.note.tv")
                    .foregroundStyle(Color.red.opacity(0.85))
                Text(media.track?.sourceName ?? "Media")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SOCTheme.textSecondary)
            }
            .padding(.leading, 44)

            if let track = media.track {
                HStack(alignment: .top, spacing: 12) {
                    Group {
                        if let artwork = track.artwork {
                            Image(uiImage: artwork)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                Color(white: 0.12)
                                Image(systemName: "music.note")
                                    .foregroundStyle(SOCTheme.textMuted)
                            }
                        }
                    }
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(track.artist)
                            .font(.system(size: 13))
                            .foregroundStyle(SOCTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 44)
                .padding(.trailing, 8)
            } else {
                Text("Çalan bir medya yok")
                    .font(.system(size: 14))
                    .foregroundStyle(SOCTheme.textMuted)
                    .padding(.leading, 44)
                    .padding(.top, 24)
            }
        }
        .padding(.top, 24)
    }

    private var tripPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            tripRow("Destination", state.destination ?? "--")
            tripRow(
                "Arrival Time",
                state.arrivalTime.map { Self.timeFormatter.string(from: $0) } ?? "--"
            )
            tripRow(
                "Energy at Arrival",
                state.energyAtArrivalPercent.map { "\($0)%" } ?? "--"
            )
            tripRow(
                "Distance",
                state.distanceToDestinationKm.map {
                    "\(VehicleStateMapper.formatDistance($0, unit: appModel.unitSystem)) \(appModel.unitSystem.distanceLabel)"
                } ?? "--"
            )
        }
        .padding(.leading, 44)
        .padding(.top, 28)
        .padding(.trailing, 12)
    }

    private func tripRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SOCTheme.textMuted)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
    }

    private var controlsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            controlHint("Kilit", state.locked == true ? "Kilitli" : (state.locked == false ? "Açık" : "--"))
            controlHint("Sentry", state.sentryOn == true ? "Açık" : (state.sentryOn == false ? "Kapalı" : "--"))

            HStack(spacing: 10) {
                controlButton("Unlock", systemImage: "lock.open.fill") {
                    Task { await appModel.bleService.unlockVehicle() }
                }
                controlButton("Lock", systemImage: "lock.fill") {
                    Task { await appModel.bleService.lockVehicle() }
                }
            }
            HStack(spacing: 10) {
                controlButton("Flash", systemImage: "headlight.high.beam") {
                    Task { await appModel.bleService.flashLights() }
                }
                controlButton("Honk", systemImage: "speaker.wave.2.fill") {
                    Task { await appModel.bleService.honk() }
                }
            }

            Text("Komutlar BLE oturumu üzerinden çalışır.")
                .font(.system(size: 12))
                .foregroundStyle(SOCTheme.textMuted)
                .padding(.top, 4)
        }
        .padding(.leading, 44)
        .padding(.top, 28)
        .padding(.trailing, 12)
    }

    private func controlButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SOCTheme.surfaceElevated)
                )
        }
        .buttonStyle(.plain)
    }

    private func controlHint(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(SOCTheme.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .fontWeight(.semibold)
        }
        .font(.system(size: 15))
        .padding(.trailing, 16)
    }

    private var batteryFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "battery.75")
                .foregroundStyle(SOCTheme.batteryGreen)
            Text(
                VehicleStateMapper.formatBattery(
                    state.batteryPercent,
                    rangeKm: state.rangeKm,
                    unit: appModel.unitSystem
                )
            )
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .monospacedDigit()
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
