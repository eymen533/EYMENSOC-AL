import SwiftUI

/// Compact door / frunk / trunk status icons under the dial (no 3D).
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
    private let amberHot = Color(red: 1.0, green: 0.82, blue: 0.35)

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ForEach(activeIconNames, id: \.self) { name in
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(amber.opacity(pulse ? 0.7 : 0.35), lineWidth: 1.2)
                        )
                        .shadow(color: amber.opacity(pulse ? 0.35 : 0.12), radius: pulse ? 10 : 5)
                }
            }

            Text(labels.isEmpty ? "Açık" : labels.joined(separator: " · "))
                .font(.caption.weight(.bold))
                .foregroundStyle(amberHot)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .scaleEffect(appeared ? 1 : 0.88)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { pulse = true }
        }
        .onChangeCompat(of: openSignature) { _ in
            appeared = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { appeared = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Model Y: \(labels.joined(separator: ", ")) açık")
    }

    private var iconSize: CGFloat {
        activeIconNames.count >= 3 ? 56 : (activeIconNames.count == 2 ? 64 : 78)
    }

    /// Asset names for currently open apertures.
    private var activeIconNames: [String] {
        var names: [String] = []
        let onlyBothFront = doorFL && doorFR && !doorRL && !doorRR && !frunkOpen && !trunkOpen && !chargePortOpen
        if onlyBothFront {
            names.append("DoorIconFrontBoth")
        } else {
            if doorFL { names.append("DoorIconFL") }
            if doorFR { names.append("DoorIconFR") }
            if doorRL { names.append("DoorIconRL") }
            if doorRR { names.append("DoorIconRR") }
        }
        if trunkOpen { names.append("DoorIconTrunk") }
        if frunkOpen { names.append("DoorIconFrunk") }
        if chargePortOpen { names.append("DoorIconCharge") }
        return names
    }

    private var openSignature: String {
        [
            doorFL ? "FL" : "", doorFR ? "FR" : "",
            doorRL ? "RL" : "", doorRR ? "RR" : "",
            frunkOpen ? "F" : "", trunkOpen ? "T" : "",
            chargePortOpen ? "C" : "",
        ].joined()
    }
}
