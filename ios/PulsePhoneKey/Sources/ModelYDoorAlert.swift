import SwiftUI

/// Model Y aperture alert — sits on the dial; doors / frunk / trunk animate open.
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
    @State private var doorAngle: Double = 0

    private let amber = Color(red: 1.0, green: 0.62, blue: 0.18)
    private let amberHot = Color(red: 1.0, green: 0.82, blue: 0.35)
    private let cabin = Color(red: 1.0, green: 0.45, blue: 0.12)

    private let carW: CGFloat = 108
    private let carH: CGFloat = 162

    var body: some View {
        VStack(spacing: 10) {
            carStage
                .frame(width: 150, height: 178)

            VStack(spacing: 3) {
                Text(labels.isEmpty ? "Açık" : labels.joined(separator: " · "))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(amberHot)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .frame(maxWidth: 200)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    amber.opacity(pulse ? 0.75 : 0.4),
                                    Color.white.opacity(0.16),
                                    amber.opacity(0.25),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.4
                        )
                )
                .shadow(color: .black.opacity(0.55), radius: 18, y: 8)
                .shadow(color: amber.opacity(pulse ? 0.35 : 0.15), radius: pulse ? 20 : 10)
        )
        .scaleEffect(appeared ? 1 : 0.82)
        .opacity(appeared ? 1 : 0)
        .onAppear { bootAnimation() }
        .onChangeCompat(of: openSignature) { _ in
            doorAngle = 0
            withAnimation(.spring(response: 0.55, dampingFraction: 0.68)) {
                doorAngle = 1
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Model Y: \(labels.joined(separator: ", ")) açık")
    }

    private func bootAnimation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.76)) {
            appeared = true
        }
        withAnimation(.spring(response: 0.65, dampingFraction: 0.66).delay(0.05)) {
            doorAngle = 1
        }
        withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    private var subtitle: String {
        if labels.count > 1 { return "Açık paneller" }
        if frunkOpen { return "Ön kaput açılıyor" }
        if trunkOpen { return "Bagaj açılıyor" }
        if chargePortOpen { return "Şarj kapağı açık" }
        return "Kapı açılıyor"
    }

    private var openSignature: String {
        [
            doorFL ? "FL" : "", doorFR ? "FR" : "",
            doorRL ? "RL" : "", doorRR ? "RR" : "",
            frunkOpen ? "F" : "", trunkOpen ? "T" : "",
            chargePortOpen ? "C" : "",
        ].joined()
    }

    // MARK: - Car stage

    private var carStage: some View {
        ZStack {
            // Stage glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [amber.opacity(pulse ? 0.35 : 0.16), .clear],
                        center: .center,
                        startRadius: 6,
                        endRadius: 70
                    )
                )
                .frame(width: 130, height: 40)
                .offset(y: 72)
                .blur(radius: 4)

            ZStack {
                // Cabin light leaking from open apertures
                cabinGlow

                // Main body
                Image("ModelYTop")
                    .resizable()
                    .scaledToFit()
                    .frame(width: carW, height: carH)
                    .shadow(color: .black.opacity(0.65), radius: 12, y: 8)

                // Animated doors (image slices that hinge open)
                doorLeaf(open: doorFL, front: true, left: true)
                doorLeaf(open: doorFR, front: true, left: false)
                doorLeaf(open: doorRL, front: false, left: true)
                doorLeaf(open: doorRR, front: false, left: false)

                // Frunk / trunk lids — rotate up/down in 3D
                if frunkOpen { frunkLid }
                if trunkOpen { trunkLid }

                if chargePortOpen {
                    Circle()
                        .fill(amberHot)
                        .frame(width: 9, height: 9)
                        .shadow(color: amber, radius: pulse ? 10 : 5)
                        .offset(x: carW * 0.42, y: -carH * 0.02)
                }
            }
            .rotation3DEffect(.degrees(18), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
            .rotation3DEffect(.degrees(-5), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        }
    }

    @ViewBuilder
    private var cabinGlow: some View {
        if doorFL || doorFR || doorRL || doorRR || frunkOpen || trunkOpen {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(cabin.opacity(pulse ? 0.55 : 0.28))
                .frame(width: carW * 0.42, height: carH * 0.55)
                .blur(radius: 10)
                .opacity(doorAngle)
        }
    }

    /// Door leaf sliced from the Model Y top image, hinged at the body.
    private func doorLeaf(open: Bool, front: Bool, left: Bool) -> some View {
        let doorW = carW * 0.22
        let doorH = carH * (front ? 0.22 : 0.20)
                // Unit-space crop of the car image for this door (from ModelYTop slices).
        let cropX: CGFloat = left ? (front ? 0.019 : 0.019) : (front ? 0.719 : 0.725)
        let cropY: CGFloat = front ? 0.279 : (left ? 0.500 : 0.492)
        let cropW: CGFloat = 0.260
        let cropH: CGFloat = front ? 0.221 : 0.219

        let hingeX = left ? -carW * 0.28 : carW * 0.28
        let hingeY = front ? -carH * 0.08 : carH * 0.12
        let swing = (left ? -1.0 : 1.0) * 58.0 * doorAngle * (open ? 1 : 0)

        return ZStack {
            // Gap / interior when open
            if open {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [cabin.opacity(0.9), Color.black.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: doorW * 0.85, height: doorH)
                    .offset(x: hingeX * 0.92, y: hingeY)
                    .opacity(doorAngle)
                    .shadow(color: cabin.opacity(0.7), radius: 6)
            }

            // Physical door — cropped car paint + glass
            Image("ModelYTop")
                .resizable()
                .scaledToFit()
                .frame(width: carW, height: carH)
                .mask(
                    Rectangle()
                        .frame(width: carW * cropW, height: carH * cropH)
                        .offset(
                            x: (cropX + cropW / 2 - 0.5) * carW,
                            y: (cropY + cropH / 2 - 0.5) * carH
                        )
                )
                .overlay {
                    // Edge highlight on open door
                    if open {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(amberHot.opacity(0.85), lineWidth: 1.2)
                            .frame(width: carW * cropW, height: carH * cropH)
                            .offset(
                                x: (cropX + cropW / 2 - 0.5) * carW,
                                y: (cropY + cropH / 2 - 0.5) * carH
                            )
                            .opacity(doorAngle)
                    }
                }
                .rotationEffect(.degrees(swing), anchor: UnitPoint(
                    x: left ? (cropX + cropW) : cropX,
                    y: cropY + cropH * 0.5
                ))
                .shadow(color: open ? amber.opacity(0.55) : .clear, radius: open ? 8 : 0)
        }
        .animation(.spring(response: 0.62, dampingFraction: 0.68), value: doorAngle)
        .animation(.spring(response: 0.55, dampingFraction: 0.7), value: open)
    }

    private var frunkLid: some View {
        let lidH = carH * 0.20
        return Image("ModelYTop")
            .resizable()
            .scaledToFit()
            .frame(width: carW, height: carH)
            .mask(
                Rectangle()
                    .frame(width: carW * 0.72, height: lidH)
                    .offset(y: -carH * 0.38)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(amberHot.opacity(0.8), lineWidth: 1)
                    .frame(width: carW * 0.72, height: lidH)
                    .offset(y: -carH * 0.38)
                    .opacity(doorAngle)
            }
            .rotation3DEffect(
                .degrees(-72 * doorAngle),
                axis: (x: 1, y: 0, z: 0),
                anchor: UnitPoint(x: 0.5, y: 0.28),
                perspective: 0.45
            )
            .shadow(color: amber.opacity(0.5), radius: 10)
            .animation(.spring(response: 0.7, dampingFraction: 0.65), value: doorAngle)
    }

    private var trunkLid: some View {
        let lidH = carH * 0.22
        return Image("ModelYTop")
            .resizable()
            .scaledToFit()
            .frame(width: carW, height: carH)
            .mask(
                Rectangle()
                    .frame(width: carW * 0.78, height: lidH)
                    .offset(y: carH * 0.36)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(amberHot.opacity(0.8), lineWidth: 1)
                    .frame(width: carW * 0.78, height: lidH)
                    .offset(y: carH * 0.36)
                    .opacity(doorAngle)
            }
            .rotation3DEffect(
                .degrees(75 * doorAngle),
                axis: (x: 1, y: 0, z: 0),
                anchor: UnitPoint(x: 0.5, y: 0.72),
                perspective: 0.45
            )
            .shadow(color: amber.opacity(0.5), radius: 10)
            .animation(.spring(response: 0.7, dampingFraction: 0.65), value: doorAngle)
    }
}
