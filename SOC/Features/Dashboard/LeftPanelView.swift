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
        ZStack {
            VehicleOutlineView()
                .frame(height: 220)
                .padding(.leading, 28)

            tireLabel(state.tirePressure.formatted(state.tirePressure.fl), alignment: .topLeading)
                .offset(x: 18, y: 42)
            tireLabel(state.tirePressure.formatted(state.tirePressure.fr), alignment: .topTrailing)
                .offset(x: -8, y: 42)
            tireLabel(state.tirePressure.formatted(state.tirePressure.rl), alignment: .bottomLeading)
                .offset(x: 18, y: -38)
            tireLabel(state.tirePressure.formatted(state.tirePressure.rr), alignment: .bottomTrailing)
                .offset(x: -8, y: -38)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private func tireLabel(_ value: String, alignment: Alignment) -> some View {
        Text("\(value) psi")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(SOCTheme.textSecondary)
            .monospacedDigit()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
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

struct VehicleOutlineView: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var path = Path()

            // Simplified top-down sedan silhouette.
            let insetX = w * 0.22
            let top = h * 0.08
            let bottom = h * 0.92

            path.move(to: CGPoint(x: insetX + 18, y: top))
            path.addQuadCurve(
                to: CGPoint(x: w - insetX - 18, y: top),
                control: CGPoint(x: w / 2, y: top - 8)
            )
            path.addLine(to: CGPoint(x: w - insetX, y: h * 0.22))
            path.addLine(to: CGPoint(x: w - insetX + 4, y: h * 0.78))
            path.addLine(to: CGPoint(x: w - insetX - 18, y: bottom))
            path.addQuadCurve(
                to: CGPoint(x: insetX + 18, y: bottom),
                control: CGPoint(x: w / 2, y: bottom + 8)
            )
            path.addLine(to: CGPoint(x: insetX - 4, y: h * 0.78))
            path.addLine(to: CGPoint(x: insetX, y: h * 0.22))
            path.closeSubpath()

            // Cabin
            let cabin = Path(roundedRect: CGRect(
                x: insetX + 16,
                y: h * 0.28,
                width: w - 2 * insetX - 32,
                height: h * 0.34
            ), cornerRadius: 10)

            context.stroke(path, with: .color(.white.opacity(0.55)), lineWidth: 1.6)
            context.stroke(cabin, with: .color(.white.opacity(0.28)), lineWidth: 1)

            // Wheels
            let wheelW: CGFloat = 10
            let wheelH: CGFloat = 22
            let wheelRects = [
                CGRect(x: insetX - 8, y: h * 0.20, width: wheelW, height: wheelH),
                CGRect(x: w - insetX - 2, y: h * 0.20, width: wheelW, height: wheelH),
                CGRect(x: insetX - 8, y: h * 0.68, width: wheelW, height: wheelH),
                CGRect(x: w - insetX - 2, y: h * 0.68, width: wheelW, height: wheelH)
            ]
            for rect in wheelRects {
                context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(.white.opacity(0.35)))
            }
        }
    }
}
