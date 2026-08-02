import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var leftMode: LeftPanelMode = .vehicle

    var body: some View {
        let service = appModel.bleService

        GeometryReader { geo in
            let isCompact = geo.size.width < 780
            ZStack {
                Color.black.ignoresSafeArea()

                if isCompact {
                    compactLayout(service: service)
                } else {
                    wideLayout(service: service, size: geo.size)
                }
            }
        }
        .onAppear {
            Task { await service.connect() }
        }
    }

    private func wideLayout(service: TeslaBLEService, size: CGSize) -> some View {
        HStack(spacing: 0) {
            LeftPanelView(mode: $leftMode, state: service.vehicleState)
                .frame(width: size.width * 0.30)

            CenterGaugeView(
                state: service.vehicleState,
                placeName: appModel.locationService.placeName ?? service.vehicleState.destination
            )
            .frame(width: size.width * 0.28)

            RightMapPanelView(
                state: service.vehicleState,
                connectionStatus: service.connectionStatus
            )
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .top) {
            TopStatusBar(
                outsideTemp: service.vehicleState.outsideTempC,
                connectionStatus: service.connectionStatus,
                onReconnect: {
                    Task { await service.reconnect() }
                },
                onSettings: { appModel.openSettings() }
            )
            .padding(.horizontal, 14)
            .padding(.top, 6)
        }
        .overlay(alignment: .leading) {
            ModeRail(selection: $leftMode)
                .padding(.leading, 6)
                .padding(.bottom, 28)
        }
    }

    private func compactLayout(service: TeslaBLEService) -> some View {
        VStack(spacing: 8) {
            TopStatusBar(
                outsideTemp: service.vehicleState.outsideTempC,
                connectionStatus: service.connectionStatus,
                onReconnect: {
                    Task { await service.reconnect() }
                },
                onSettings: { appModel.openSettings() }
            )
            .padding(.horizontal, 12)

            CenterGaugeView(
                state: service.vehicleState,
                placeName: appModel.locationService.placeName ?? service.vehicleState.destination
            )
            .frame(maxHeight: 220)

            HStack(spacing: 8) {
                LeftPanelView(mode: $leftMode, state: service.vehicleState)
                RightMapPanelView(
                    state: service.vehicleState,
                    connectionStatus: service.connectionStatus
                )
            }
        }
        .padding(8)
    }
}

struct TopStatusBar: View {
    let outsideTemp: Double?
    let connectionStatus: ConnectionStatus
    let onReconnect: () -> Void
    let onSettings: () -> Void

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 10) {
                Text(timeLabel(for: context.date))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text(VehicleStateMapper.formatTemp(outsideTemp))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SOCTheme.textSecondary)

                Image(systemName: connectionStatus.isLive ? "car.fill" : "car")
                    .foregroundStyle(connectionStatus.isLive ? SOCTheme.success : SOCTheme.textMuted)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(SOCTheme.textMuted)
                Image(systemName: "plus")
                    .foregroundStyle(SOCTheme.textMuted)

                Spacer()

                statusPill

                if !connectionStatus.isLive {
                    Button(action: onReconnect) {
                        Label("Reconnect", systemImage: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(SOCTheme.surfaceElevated))
                    }
                    .buttonStyle(.plain)
                }

                PhoneBatteryView()

                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(SOCTheme.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func timeLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(connectionStatus.isLive ? SOCTheme.success : Color.red.opacity(0.85))
                .frame(width: 7, height: 7)
            Circle()
                .fill(SOCTheme.warning.opacity(connectionStatus.isLive ? 0.35 : 0.9))
                .frame(width: 7, height: 7)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(SOCTheme.surfaceElevated))
    }
}

struct PhoneBatteryView: View {
    @State private var level: Float = -1

    var body: some View {
        let pct = level < 0 ? "--" : "\(Int((level * 100).rounded()))"
        HStack(spacing: 4) {
            Image(systemName: "battery.100")
                .font(.system(size: 13, weight: .medium))
            Text(pct)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(SOCTheme.textSecondary)
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            level = UIDevice.current.batteryLevel
        }
    }
}

struct ModeRail: View {
    @Binding var selection: LeftPanelMode

    private let items: [(LeftPanelMode, String)] = [
        (.vehicle, "square.dashed"),
        (.controls, "steeringwheel"),
        (.trip, "location.north.line.fill"),
        (.vehicle, "map"),
        (.media, "music.note")
    ]

    var body: some View {
        VStack(spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = item.0
                    }
                } label: {
                    Image(systemName: item.1)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selection == item.0 ? .white : SOCTheme.textMuted)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selection == item.0 ? Color.white.opacity(0.12) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
}
