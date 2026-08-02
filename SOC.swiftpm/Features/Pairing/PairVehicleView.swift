import SwiftUI
import UIKit

struct PairVehicleView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var vin: String = ""
    @State private var isScanning = false
    @State private var statusMessage: String?
    @FocusState private var vinFocused: Bool

    private var isValid: Bool { VINHelper.isValid(vin) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [
                    Color(red: 0.28, green: 0.18, blue: 0.55).opacity(0.45),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 480
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        guideCard
                        vinField
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }

                Button {
                    Task { await startPairing() }
                } label: {
                    HStack(spacing: 10) {
                        if isScanning {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(buttonTitle)
                    }
                }
                .buttonStyle(PrimaryGradientButtonStyle(enabled: isValid && !isScanning, isBusy: isScanning))
                .disabled(!isValid || isScanning)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
        .onAppear {
            if let existing = UIPasteboard.general.string, VINHelper.isValid(existing), vin.isEmpty {
                // Don't auto-fill; Paste affordance is enough.
            }
        }
    }

    private var buttonTitle: String {
        if isScanning { return "Scanning for vehicle..." }
        if isValid { return "Start pairing" }
        return "Enter VIN to start pairing"
    }

    private var header: some View {
        HStack(alignment: .top) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 3)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: 0.5)
                        .stroke(SOCTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 44, height: 44)
                    Text("1/2")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pair Vehicle")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Enter Vehicle VIN")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SOCTheme.textSecondary)
                }
            }

            Spacer()
            CloseButton { appModel.cancelPairing() }
        }
    }

    private var guideCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(SOCTheme.cardGlow.opacity(0.35))
                .blur(radius: 0.5)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.20, green: 0.16, blue: 0.38),
                            Color(red: 0.12, green: 0.10, blue: 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(SOCTheme.cardGlow, lineWidth: 1.2)
                )

            VStack(alignment: .leading, spacing: 10) {
                Text("Tesla App → Service")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))

                Text("MODEL 3")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                HStack {
                    Label("VIN", systemImage: "barcode")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text("•••••••••••••••••")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(SOCTheme.accent.opacity(0.7), lineWidth: 1.5)
                        )
                )
            }
            .padding(18)
        }
        .frame(height: 180)
    }

    private var vinField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VEHICLE IDENTIFICATION NUMBER (VIN)")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(SOCTheme.textMuted)

            HStack(spacing: 10) {
                Image(systemName: "car.fill")
                    .foregroundStyle(SOCTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.06)))

                TextField("5YJ3E1EA1JF000001", text: $vin)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .focused($vinFocused)
                    .onChange(of: vin) { _, newValue in
                        vin = VINHelper.normalize(newValue)
                    }

                if vin.isEmpty {
                    Button("Paste") {
                        if let pasted = UIPasteboard.general.string {
                            vin = VINHelper.normalize(pasted)
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SOCTheme.accent)
                } else {
                    Button {
                        vin = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(SOCTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(SOCTheme.surface)
            )

            HStack(spacing: 6) {
                Text("In the Tesla app, scroll to the bottom and long-press VIN to copy.")
                    .font(.system(size: 12))
                    .foregroundStyle(SOCTheme.textMuted)
                Button("Open Tesla App") {
                    openTeslaApp()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SOCTheme.accent)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SOCTheme.warning)
                    .padding(.top, 4)
            }
        }
    }

    private func startPairing() async {
        guard isValid else { return }
        isScanning = true
        statusMessage = nil
        vinFocused = false

        await appModel.bleService.startPairingScan(vin: vin)

        // Give BLE a moment; pairing request may already have completed inside the service.
        if case .error(let message) = appModel.bleService.connectionStatus {
            statusMessage = message
            isScanning = false
            return
        }

        // Proceed to key-card step once we found/contacted the vehicle or after timeout with VIN saved.
        if appModel.bleService.discoveredName != nil
            || appModel.bleService.connectionStatus == .connected
            || appModel.bleService.connectionStatus == .connecting {
            appModel.completePairing(vin: vin)
        } else {
            // Still allow continuing — vehicle may be nearby but quiet; key-card step retries.
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if case .error(let message) = appModel.bleService.connectionStatus {
                statusMessage = message
                isScanning = false
            } else {
                appModel.completePairing(vin: vin)
            }
        }
        isScanning = false
    }

    private func openTeslaApp() {
        let candidates = [
            "tesla://",
            "https://www.tesla.com/teslaapp"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
    }
}
