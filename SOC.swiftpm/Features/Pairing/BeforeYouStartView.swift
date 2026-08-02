import SwiftUI

struct BeforeYouStartView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    CloseButton {
                        if appModel.pairedVIN != nil {
                            appModel.route = .dashboard
                        }
                    }
                    .opacity(appModel.pairedVIN == nil ? 0 : 1)
                    .disabled(appModel.pairedVIN == nil)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(SOCTheme.surfaceElevated)
                                    .frame(width: 54, height: 54)
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(SOCTheme.accent)
                            }

                            Text("Before You Start")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Please confirm the following before starting setup.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(SOCTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        warningBanner

                        stepsCard

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 22)
                }

                Button("I am ready to begin") {
                    appModel.beginPairing()
                }
                .buttonStyle(PrimaryGradientButtonStyle())
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            }
        }
    }

    private var background: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [
                    Color(red: 0.18, green: 0.22, blue: 0.45).opacity(0.55),
                    .clear
                ],
                center: .top,
                startRadius: 20,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    private var warningBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SOCTheme.warning)
                .font(.system(size: 18))
            Text("Model S and Model X built before 2021 do not support this protocol.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 1.0, green: 0.92, blue: 0.72))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SOCTheme.warningBackground)
        )
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepRow(
                number: 1,
                text: "Complete the first-time setup while inside the vehicle and keep it in Park."
            )
            stepRow(
                number: 2,
                text: "Have your physical key card ready for verification."
            )

            keyCardIllustration
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SOCTheme.surface)
        )
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(SOCTheme.accent.opacity(0.85)))

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SOCTheme.textPrimary.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var keyCardIllustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.12), Color(white: 0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 180, height: 110)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 16, y: 8)

            VStack(spacing: 10) {
                Text("TESLA")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.9))
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 70, height: 4)
            }
        }
        .padding(.vertical, 8)
    }
}
