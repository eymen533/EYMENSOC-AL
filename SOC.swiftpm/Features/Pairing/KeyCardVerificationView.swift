import SwiftUI

struct KeyCardVerificationView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var pulse = false
    @State private var isConfirming = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [
                    Color(red: 0.15, green: 0.28, blue: 0.55).opacity(0.5),
                    .clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 3)
                                .frame(width: 44, height: 44)
                            Circle()
                                .trim(from: 0, to: 1)
                                .stroke(SOCTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 44, height: 44)
                            Text("2/2")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Verify Key Card")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Tap your key card on the console")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(SOCTheme.textSecondary)
                        }
                    }
                    Spacer()
                    CloseButton { appModel.cancelPairing() }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()

                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .stroke(SOCTheme.accent.opacity(0.25), lineWidth: 2)
                            .frame(width: pulse ? 210 : 170, height: pulse ? 210 : 170)
                            .opacity(pulse ? 0 : 1)

                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.14), Color(white: 0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 200, height: 122)
                            .overlay(
                                VStack(spacing: 10) {
                                    Text("TESLA")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .tracking(5)
                                        .foregroundStyle(.white)
                                    Image(systemName: "wave.3.right")
                                        .foregroundStyle(SOCTheme.accent)
                                }
                            )
                            .shadow(color: SOCTheme.accent.opacity(0.25), radius: 24, y: 8)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) {
                            pulse = true
                        }
                    }

                    Text("Place your physical key card on the center console card reader to approve this phone as a key.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(SOCTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SOCTheme.warning)
                    }

                    if let vin = appModel.pairedVIN {
                        Text(vin)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(SOCTheme.textMuted)
                    }
                }

                Spacer()

                Button {
                    Task { await confirm() }
                } label: {
                    HStack(spacing: 10) {
                        if isConfirming {
                            ProgressView().tint(.white)
                        }
                        Text(isConfirming ? "Confirming..." : "I tapped the key card")
                    }
                }
                .buttonStyle(PrimaryGradientButtonStyle(enabled: !isConfirming, isBusy: isConfirming))
                .disabled(isConfirming)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
        .task {
            // Ensure add-key request is on the wire while waiting for the card tap.
            try? await appModel.bleService.completeAddKey()
        }
    }

    private func confirm() async {
        isConfirming = true
        errorMessage = nil
        do {
            try await appModel.bleService.completeAddKey()
            appModel.finishKeyCardStep()
        } catch {
            // Even if a second add-key fails (already pending), allow dashboard entry;
            // normal connect will verify the whitelist.
            appModel.finishKeyCardStep()
        }
        isConfirming = false
    }
}
