import SwiftUI

/// Thin green “charging” light line across the top of the HUD.
struct ChargingTopRibbon: View {
    @State private var pulse = false
    @State private var sweep: CGFloat = -0.35

    private let green = Color(red: 0.22, green: 0.92, blue: 0.48)
    private let greenDeep = Color(red: 0.08, green: 0.62, blue: 0.32)

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    Capsule()
                        .fill(green.opacity(pulse ? 0.45 : 0.22))
                        .frame(height: 10)
                        .blur(radius: 8)
                        .padding(.horizontal, 40)
                        .padding(.top, 2)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    greenDeep.opacity(0.15),
                                    green,
                                    Color.white.opacity(0.95),
                                    green,
                                    greenDeep.opacity(0.15),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 3.5)
                        .shadow(color: green.opacity(pulse ? 0.9 : 0.5), radius: pulse ? 10 : 5)
                        .padding(.horizontal, 28)
                        .padding(.top, 6)
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.85), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 64, height: 3.5)
                                .offset(x: sweep * geo.size.width * 0.55)
                                .padding(.top, 6)
                                .allowsHitTesting(false)
                        }

                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("ŞARJ")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.1)
                    }
                    .foregroundStyle(green)
                    .shadow(color: green.opacity(0.7), radius: 6)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
                    .padding(.top, 14)
                }
                Spacer(minLength: 0)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                sweep = 0.35
            }
        }
        .accessibilityLabel("Şarj oluyor")
    }
}
