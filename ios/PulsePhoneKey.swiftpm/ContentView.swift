import SwiftUI

/// Root: Pair flow → native HUD (no WebView).
struct ContentView: View {
    @StateObject private var ble = BLEPairer()
    @StateObject private var hud = HUDModel()
    @State private var vin = UserDefaults.standard.string(forKey: "pulse_vin") ?? "XP7YGCEK0PB159959"
    @State private var err: String?
    @State private var logOpen = false
    @State private var screen: Screen = .pair

    enum Screen { case pair, hud }

    var body: some View {
        Group {
            switch screen {
            case .hud:
                NativeHUDView(model: hud) {
                    screen = .pair
                }
                .onAppear {
                    hud.configure(vin: vinNorm, paired: ble.paired || ble.waitingForCard || ble.readyForDashboard)
                    hud.start()
                }
            case .pair:
                pairScreen
            }
        }
        .animation(.easeInOut(duration: 0.25), value: screen)
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
                    Text("SÜRÜM: \(BLEPairer.buildId) · native HUD")
                        .font(.caption.bold())
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.35)))

                    Text("WebView yok — Pair sonrası cluster uygulama içi açılır.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        openHUD()
                    } label: {
                        Text("Native HUD’u aç")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)

                    if ble.readyForDashboard || ble.waitingForCard || ble.paired {
                        Text("Pair OK — HUD’a geçiliyor…")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }

                    Divider()

                    Text("VIN").font(.caption.weight(.semibold))
                    TextField("VIN", text: $vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))

                    Text("BLE: \(VCSECPayload.bleLocalName(vin: vinNorm))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Button {
                        startPair()
                    } label: {
                        Text(ble.step == .scanning ? "Taranıyor…" : "1. Taramayı başlat")
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
                        Text("2. 🔑 Tesla satırına dokun")
                            .font(.headline)
                        ForEach(ble.devices.prefix(16)) { d in
                            let hot = d.name.contains("🔑") || d.name.localizedCaseInsensitiveContains("tesla")
                            Button {
                                ble.connect(id: d.id)
                            } label: {
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

    private func openHUD() {
        UserDefaults.standard.set(vinNorm, forKey: "pulse_vin")
        hud.configure(vin: vinNorm, paired: ble.paired || ble.waitingForCard || ble.readyForDashboard)
        screen = .hud
    }

    private func startPair() {
        err = nil
        guard vinNorm.count == 17 else {
            err = "VIN 17 karakter"
            return
        }
        UserDefaults.standard.set(vinNorm, forKey: "pulse_vin")
        do {
            let key = try KeyStore.loadOrCreatePrivateKey(forVIN: vinNorm)
            ble.start(vin: vinNorm, publicKey: KeyStore.publicKeyUncompressed(key))
        } catch {
            err = error.localizedDescription
        }
    }
}
