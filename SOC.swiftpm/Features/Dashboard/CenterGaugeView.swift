import SwiftUI

struct CenterGaugeView: View {
    let state: VehicleState
    var placeName: String?
    @EnvironmentObject private var appModel: AppModel
    @State private var breathe = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 36)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .scaleEffect(breathe ? 1.04 : 0.98)
                    .opacity(breathe ? 0.35 : 0.7)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(white: 0.10),
                                Color.black
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 160
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                VStack(spacing: 10) {
                    gearRow

                    Text(VehicleStateMapper.formatSpeed(state.speedKph, unit: appModel.unitSystem))
                        .font(.system(size: 92, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.2), value: state.speedKph)

                    Text(appModel.unitSystem.speedLabel)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(SOCTheme.textSecondary)
                }
            }
            .frame(maxWidth: 280, maxHeight: 280)
            .frame(maxWidth: .infinity)
            .onAppear {
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }

            if let place = placeName, !place.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(SOCTheme.textMuted)
                    Text(place)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SOCTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 8)
    }

    private var gearRow: some View {
        HStack(spacing: 16) {
            ForEach(GearPosition.allCases, id: \.self) { gear in
                Text(gear.label)
                    .font(.system(size: 15, weight: gear == state.gear ? .bold : .medium, design: .rounded))
                    .foregroundStyle(gear == state.gear ? .white : SOCTheme.textMuted)
                    .scaleEffect(gear == state.gear ? 1.08 : 1)
            }
        }
    }
}
