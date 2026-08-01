import SwiftUI
import UIKit

/// Competitor-style Pair Vehicle flow (Before You Start → VIN → Scan/Card).
struct PairingFlowView: View {
    @ObservedObject var ble: BLEPairer
    @Binding var vin: String
    var onClose: () -> Void
    var onFinished: () -> Void

    @State private var page: Page = .beforeStart
    @State private var err: String?

    enum Page { case beforeStart, enterVIN, scanning, placeCard, done }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch page {
            case .beforeStart: beforeStart
            case .enterVIN: enterVIN
            case .scanning: scanning
            case .placeCard: placeCard
            case .done: donePage
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: ble.step) { _, step in
            switch step {
            case .waitingCard: page = .placeCard
            case .done:
                page = .done
            case .failed:
                if page == .scanning { err = ble.status }
            default: break
            }
        }
        .onChange(of: ble.waitingForCard) { _, on in
            if on { page = .placeCard }
        }
        .onChange(of: ble.paired) { _, on in
            if on { page = .done }
        }
        .onChange(of: ble.readyForDashboard) { _, on in
            if on, ble.step == .waitingCard || ble.step == .done {
                // Keep user on placeCard until they confirm, unless fully paired
                if ble.paired { page = .done }
            }
        }
    }

    // MARK: - Before You Start

    private var beforeStart: some View {
        VStack(spacing: 0) {
            topBar(showProgress: false)
            ScrollView {
                VStack(spacing: 22) {
                    ZStack {
                        Circle().fill(Color(red: 0.12, green: 0.18, blue: 0.35)).frame(width: 64, height: 64)
                        Image(systemName: "info")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 8)

                    Text("Before You Start")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Please confirm the following before starting setup.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Model S and Model X built before 2021 do not support this protocol.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.7), lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.12))))
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 0) {
                        stepRow(1, "Complete the first-time setup while inside the vehicle and keep it in Park.")
                        Divider().background(Color.white.opacity(0.1))
                        VStack(alignment: .leading, spacing: 12) {
                            stepRow(2, "Have your physical key card ready for verification.")
                            keyCardGraphic
                                .padding(.leading, 44)
                                .padding(.bottom, 16)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color(red: 0.08, green: 0.11, blue: 0.22)))
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 100)
            }
            bottomCTA("I am ready to begin") { page = .enterVIN }
        }
    }

    // MARK: - Enter VIN

    private var enterVIN: some View {
        VStack(spacing: 0) {
            topBar(showProgress: true, fraction: "1/2", title: "Pair Vehicle", subtitle: "Enter Vehicle VIN")
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    teslaAppHintCard
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    Text("VEHICLE IDENTIFICATION NUMBER (VIN)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.horizontal, 24)

                    HStack(spacing: 10) {
                        Image(systemName: "car.fill")
                            .foregroundStyle(.white.opacity(0.5))
                        TextField("17-character VIN", text: $vin)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.white)
                        if !vin.isEmpty {
                            Button {
                                vin = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                        }
                        Button("Paste") {
                            if let s = UIPasteboard.general.string {
                                vin = s.filter { $0.isLetter || $0.isNumber }.uppercased()
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.45, green: 0.55, blue: 1))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .padding(.horizontal, 20)

                    Text("In the Tesla app, scroll to the bottom and long-press VIN to copy.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.horizontal, 24)

                    Button("Open Tesla App") {
                        if let url = URL(string: "tesla://") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.45, green: 0.55, blue: 1))
                    .padding(.horizontal, 24)

                    if let err {
                        Text(err).foregroundStyle(.red).font(.footnote).padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 100)
            }
            bottomCTA(vinNorm.count == 17 ? "Start pairing" : "Enter VIN to start pairing", enabled: vinNorm.count == 17) {
                startScan()
            }
        }
    }

    // MARK: - Scanning

    private var scanning: some View {
        VStack(spacing: 0) {
            topBar(showProgress: true, fraction: "1/2", title: "Pair Vehicle", subtitle: "Enter Vehicle VIN")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    teslaAppHintCard.padding(.horizontal, 20).padding(.top, 8)

                    HStack {
                        Image(systemName: "car.fill").foregroundStyle(.white.opacity(0.5))
                        Text(vinNorm)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .padding(.horizontal, 20)

                    Text(ble.status)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 24)

                    if !ble.devices.isEmpty {
                        Text("Tap your vehicle")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                        ForEach(ble.devices.prefix(12)) { d in
                            let hot = d.name.contains("🔑") || d.name.localizedCaseInsensitiveContains("tesla")
                            Button {
                                ble.connect(id: d.id)
                            } label: {
                                HStack {
                                    Image(systemName: hot ? "key.fill" : "wave.3.right")
                                    Text(d.label)
                                        .font(.system(.footnote, design: .monospaced))
                                    Spacer()
                                    if hot {
                                        Text("Connect")
                                            .font(.caption.bold())
                                    }
                                }
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(hot ? Color(red: 0.25, green: 0.2, blue: 0.55) : Color.white.opacity(0.06))
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    if let err {
                        Text(err).foregroundStyle(.orange).font(.footnote).padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 100)
            }
            bottomCTA("Scanning for vehicle…", enabled: false, spinning: true) {}
        }
    }

    // MARK: - Place card

    private var placeCard: some View {
        VStack(spacing: 0) {
            topBar(showProgress: true, fraction: "2/2", title: "Pair Vehicle", subtitle: "Verify with Key Card")
            Spacer()
            VStack(spacing: 20) {
                keyCardGraphic.scaleEffect(1.2)
                Text("Place Key Card on console")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Put your Key Card on the center console reader (not on the iPad). Confirm Pair on the car screen.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Text(ble.status)
                    .font(.footnote)
                    .foregroundStyle(Color(red: 0.45, green: 0.9, blue: 1))
                    .padding(.top, 8)
            }
            Spacer()
            bottomCTA("Open HUD") {
                onFinished()
            }
        }
    }

    private var donePage: some View {
        VStack(spacing: 24) {
            topBar(showProgress: false)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color(red: 0.3, green: 0.9, blue: 0.6))
            Text("Phone Key added")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text("Your vehicle accepted the key. Open the cluster HUD to continue.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            bottomCTA("Open HUD") { onFinished() }
        }
    }

    // MARK: - Pieces

    private var vinNorm: String {
        vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func startScan() {
        err = nil
        guard vinNorm.count == 17 else {
            err = "VIN must be 17 characters"
            return
        }
        UserDefaults.standard.set(vinNorm, forKey: "pulse_vin")
        do {
            let key = try KeyStore.loadOrCreatePrivateKey(forVIN: vinNorm)
            page = .scanning
            ble.start(vin: vinNorm, publicKey: KeyStore.publicKeyUncompressed(key))
        } catch {
            err = error.localizedDescription
        }
    }

    private func topBar(showProgress: Bool, fraction: String = "1/2", title: String = "", subtitle: String = "") -> some View {
        HStack(alignment: .top) {
            if showProgress {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: fraction.hasPrefix("2") ? 1 : 0.5)
                        .stroke(Color(red: 0.45, green: 0.4, blue: 1), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(fraction)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else {
                Spacer(minLength: 40)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func bottomCTA(_ title: String, enabled: Bool = true, spinning: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if spinning { ProgressView().tint(.white) }
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Capsule().fill(
                    enabled
                        ? LinearGradient(
                            colors: [Color(red: 0.45, green: 0.35, blue: 0.95), Color(red: 0.25, green: 0.45, blue: 0.98)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.12)], startPoint: .leading, endPoint: .trailing)
                )
            )
        }
        .disabled(!enabled)
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
        .background(
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 40)
                .offset(y: -40),
            alignment: .top
        )
    }

    private func stepRow(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(n)")
                .font(.caption.bold())
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.12)))
                .foregroundStyle(.white)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 4)
        }
        .padding(16)
    }

    private var keyCardGraphic: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black)
            .frame(width: 160, height: 100)
            .overlay(
                Text("T E S L A")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.85))
            )
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
    }

    private var teslaAppHintCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.25, blue: 0.55).opacity(0.5),
                            Color(red: 0.45, green: 0.2, blue: 0.45).opacity(0.45),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.1, green: 0.11, blue: 0.14))
                .padding(3)
            VStack(alignment: .leading, spacing: 10) {
                Text("MODEL Y")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Software")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VIN")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                        Text(vinNorm.isEmpty ? "XP7YGCEK0······" : String(vinNorm.prefix(11)) + "······")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "viewfinder")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
                )
            }
            .padding(18)
        }
        .frame(height: 180)
    }
}
