import SwiftUI

/// Animated Model Y figure under the dial — shows which door / frunk / trunk is open.
struct ModelYDoorAlert: View {
    var doorFL: Bool
    var doorFR: Bool
    var doorRL: Bool
    var doorRR: Bool
    var frunkOpen: Bool
    var trunkOpen: Bool
    var chargePortOpen: Bool
    var labels: [String]

    @State private var appeared = false
    @State private var pulse = false

    private let amber = Color(red: 1.0, green: 0.62, blue: 0.18)
    private let amberHot = Color(red: 1.0, green: 0.78, blue: 0.32)

    var body: some View {
        VStack(spacing: 8) {
            figure
                .frame(width: 118, height: 132)

            VStack(spacing: 2) {
                Text(labels.isEmpty ? "Açık" : labels.joined(separator: " · "))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(amberHot)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .frame(maxWidth: 200)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.42, green: 0.28, blue: 0.72).opacity(0.42),
                                    Color(red: 0.18, green: 0.12, blue: 0.32).opacity(0.38),
                                    Color.black.opacity(0.28),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.72, green: 0.55, blue: 1.0).opacity(pulse ? 0.65 : 0.35),
                                    Color.white.opacity(0.18),
                                    amber.opacity(0.25),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: Color(red: 0.55, green: 0.35, blue: 0.95).opacity(pulse ? 0.35 : 0.16), radius: pulse ? 16 : 8, y: 4)
        )
        .scaleEffect(appeared ? 1 : 0.78)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 22)
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onChangeCompat(of: openSignature) { _ in
            // Re-pop when a new aperture opens.
            appeared = false
            withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Model Y: \(labels.joined(separator: ", ")) açık")
    }

    private var subtitle: String {
        if labels.count > 1 { return "Açık paneller" }
        if frunkOpen { return "Ön kaput açık" }
        if trunkOpen { return "Bagaj açık" }
        if chargePortOpen { return "Şarj kapağı açık" }
        return "Kapı açık"
    }

    private var openSignature: String {
        [
            doorFL ? "FL" : "",
            doorFR ? "FR" : "",
            doorRL ? "RL" : "",
            doorRR ? "RR" : "",
            frunkOpen ? "F" : "",
            trunkOpen ? "T" : "",
            chargePortOpen ? "C" : "",
        ].joined()
    }

    private var figure: some View {
        ZStack {
            // Soft “stage” under the car — 3D presence.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            amber.opacity(pulse ? 0.42 : 0.22),
                            Color.white.opacity(0.06),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 52
                    )
                )
                .frame(width: 108, height: 36)
                .blur(radius: 6)
                .offset(y: 54)

            // Floor reflection of the body.
            Image("ModelYTop")
                .resizable()
                .scaledToFit()
                .frame(width: 78, height: 116)
                .colorMultiply(Color(red: 0.85, green: 0.88, blue: 0.92))
                .opacity(0.28)
                .scaleEffect(y: -0.22, anchor: .bottom)
                .offset(y: 58)
                .blur(radius: 1.2)
                .mask(
                    LinearGradient(
                        colors: [.white.opacity(0.55), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            ZStack {
                Image("ModelYTop")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 78, height: 116)
                    .colorMultiply(Color(red: 0.92, green: 0.94, blue: 0.97))
                    .shadow(color: .black.opacity(0.55), radius: 10, y: 8)
                    .shadow(color: amber.opacity(0.25), radius: 12, y: 2)

                // Hinged door overlays — swing out when open.
                doorWing(open: doorFL && appeared, front: true, left: true)
                doorWing(open: doorFR && appeared, front: true, left: false)
                doorWing(open: doorRL && appeared, front: false, left: true)
                doorWing(open: doorRR && appeared, front: false, left: false)

                if frunkOpen {
                    hatchBar(y: -48, openUp: true)
                }
                if trunkOpen {
                    hatchBar(y: 50, openUp: false)
                }
                if chargePortOpen {
                    Circle()
                        .fill(amberHot)
                        .frame(width: 8, height: 8)
                        .shadow(color: amber, radius: pulse ? 8 : 4)
                        .offset(x: 34, y: -6)
                        .opacity(appeared ? 1 : 0)
                }
            }
            .rotation3DEffect(
                .degrees(appeared ? 16 : 26),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.55
            )
            .rotation3DEffect(
                .degrees(appeared ? -6 : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.65
            )
            .offset(y: appeared ? -2 : 6)
        }
    }

    private func doorWing(open: Bool, front: Bool, left: Bool) -> some View {
        let w: CGFloat = 11
        let h: CGFloat = front ? 24 : 22
        let x: CGFloat = left ? -34 : 34
        let y: CGFloat = front ? -14 : 16
        let angle: Double = {
            guard open else { return 0 }
            // Top-down: left doors swing out (CCW), right doors CW.
            return left ? -38 : 38
        }()
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(
                LinearGradient(
                    colors: open
                        ? [amberHot, amber.opacity(0.85)]
                        : [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(open ? amberHot.opacity(0.9) : Color.white.opacity(0.12), lineWidth: open ? 1.2 : 0.6)
            )
            .frame(width: w, height: h)
            .shadow(color: open ? amber.opacity(pulse ? 0.85 : 0.45) : .clear, radius: open ? 8 : 0)
            .offset(x: x, y: y)
            .rotationEffect(
                .degrees(angle),
                anchor: left ? .trailing : .leading
            )
            .animation(.spring(response: 0.55, dampingFraction: 0.72), value: open)
    }

    private func hatchBar(y: CGFloat, openUp: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [amberHot, amber],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 36, height: 8)
            .shadow(color: amber.opacity(pulse ? 0.9 : 0.45), radius: 8)
            .offset(y: y + (appeared ? (openUp ? -10 : 10) : 0))
            .rotation3DEffect(
                .degrees(appeared ? (openUp ? -42 : 42) : 0),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.6
            )
            .animation(.spring(response: 0.55, dampingFraction: 0.7), value: appeared)
    }
}
