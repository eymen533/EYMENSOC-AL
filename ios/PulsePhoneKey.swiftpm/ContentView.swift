import SwiftUI

/// Pair (real BLE) → Real Dash HUD (same web cluster, auto PIN — not fake gauges).
struct ContentView: View {
    @StateObject private var ble = BLEPairer()
    @State private var vin = UserDefaults.standard.string(forKey: "pulse_vin") ?? "XP7YGCEK0PB159959"
    @State private var server = UserDefaults.standard.string(forKey: "pulse_server")
        ?? "https://beach-mobiles-writers-developments.trycloudflare.com"
    @State private var pin = UserDefaults.standard.string(forKey: "pulse_pin") ?? "428462"
    @State private var err: String?
    @State private var logOpen = false
    @State private var screen: Screen = .pair

    enum Screen { case pair, hud }

    var body: some View {
        Group {
            switch screen {
            case .hud:
                RealHUDView(
                    server: server,
                    pin: pin,
                    vin: vinNorm,
                    onBack: { screen = .pair }
                )
            case .pair:
                pairScreen
            }
        }
        .onChange(of: ble.readyForDashboard) { _, on in
            if on { openHUD() }
        }
        .onChange(of: ble.paired) { _, on in
            if on { openHUD() }
        }
    }

    private var pairScreen: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Pulse")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("SÜRÜM: \(BLEPairer.buildId) · gerçek Dash HUD")
                        .font(.caption.bold())
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.35)))

                    Text("Sahte gösterge yok. Pair sonrası eski Tesla Pulse cluster açılır (canlı).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Group {
                        fieldLabel("Dash server")
                        TextField("https://….trycloudflare.com", text: $server)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                            .padding(10)
                            .background(fieldBG)

                        fieldLabel("PIN")
                        TextField("PIN", text: $pin)
                            .keyboardType(.numberPad)
                            .padding(10)
                            .background(fieldBG)
                    }

                    Button {
                        save()
                        openHUD()
                    } label: {
                        Text("Gerçek HUD’u aç")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)

                    Divider()

                    fieldLabel("VIN")
                    TextField("VIN", text: $vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .padding(10)
                        .background(fieldBG)

                    Text("BLE: \(VCSECPayload.bleLocalName(vin: vinNorm))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Button { startPair() } label: {
                        Text(ble.step == .scanning ? "Taranıyor…" : "1. BLE Pair taraması")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vinNorm.count != 17)

                    Text(ble.status)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.12)))

                    if !ble.devices.isEmpty {
                        Text("2. 🔑 Tesla’ya dokun → kart konsola")
                            .font(.headline)
                        ForEach(ble.devices.prefix(16)) { d in
                            let hot = d.name.contains("🔑") || d.name.localizedCaseInsensitiveContains("tesla")
                            Button { ble.connect(id: d.id) } label: {
                                HStack {
                                    Text(hot ? "BAĞLAN" : "dene")
                                        .font(.caption.bold())
                                        .padding(6)
                                        .background(hot ? Color.orange : Color.gray.opacity(0.35))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    Text(d.label)
                                        .font(.system(.footnote, design: .monospaced))
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(12)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(hot ? .orange : .gray)
                        }
                    }

                    DisclosureGroup("Log", isExpanded: $logOpen) {
                        ForEach(Array(ble.log.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if let err {
                        Text(err).foregroundStyle(.red).font(.footnote)
                    }
                }
                .padding(18)
            }
        }
    }

    private var vinNorm: String {
        vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var fieldBG: some View {
        RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground))
    }

    private func fieldLabel(_ t: String) -> some View {
        Text(t).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }

    private func save() {
        UserDefaults.standard.set(vinNorm, forKey: "pulse_vin")
        UserDefaults.standard.set(PulseSession.normalizeServer(server), forKey: "pulse_server")
        UserDefaults.standard.set(pin, forKey: "pulse_pin")
        server = PulseSession.normalizeServer(server)
    }

    private func openHUD() {
        save()
        screen = .hud
    }

    private func startPair() {
        err = nil
        guard vinNorm.count == 17 else {
            err = "VIN 17 karakter"
            return
        }
        save()
        do {
            let key = try KeyStore.loadOrCreatePrivateKey(forVIN: vinNorm)
            ble.start(vin: vinNorm, publicKey: KeyStore.publicKeyUncompressed(key))
        } catch {
            err = error.localizedDescription
        }
    }
}
