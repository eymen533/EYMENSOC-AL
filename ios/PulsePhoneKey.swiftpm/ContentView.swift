import SwiftUI

struct ContentView: View {
    @StateObject private var ble = BLEPairer()
    @State private var vin = UserDefaults.standard.string(forKey: "pulse_vin") ?? "XP7YGCEK0PB159959"
    @State private var server = UserDefaults.standard.string(forKey: "pulse_server")
        ?? "https://beach-mobiles-writers-developments.trycloudflare.com"
    @State private var err: String?
    @State private var showDash = false
    @State private var logOpen = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Pulse Phone Key")
                        .font(.largeTitle.bold())
                    Text("SÜRÜM: \(BLEPairer.buildId)")
                        .font(.caption.bold())
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.35)))

                    // Dashboard CTA
                    if ble.readyForDashboard || ble.waitingForCard || ble.paired {
                        Button {
                            save()
                            showDash = true
                        } label: {
                            Text("Dashboard / HUD aç  (PIN 428462)")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }

                    Group {
                        label("Dash server")
                        TextField("https://…", text: $server)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                            .padding(10)
                            .background(fieldBG)
                        Button("Sadece Dashboard aç") {
                            save()
                            showDash = true
                        }
                        .buttonStyle(.bordered)
                    }

                    Divider()

                    Text("PAIR")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    label("VIN")
                    TextField("VIN", text: $vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .padding(10)
                        .background(fieldBG)

                    Text("Beklenen: \(VCSECPayload.bleLocalName(vin: vinNorm))")
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
                        Text("2. Cihaza dokun (🔑 Tesla en üstte)")
                            .font(.headline)
                        ForEach(ble.devices.prefix(16)) { d in
                            Button {
                                ble.connect(id: d.id)
                            } label: {
                                HStack {
                                    Text(d.containsTeslaHint ? "BAĞLAN" : "dene")
                                        .font(.caption.bold())
                                        .padding(6)
                                        .background(d.containsTeslaHint ? Color.orange : Color.gray.opacity(0.3))
                                        .foregroundStyle(d.containsTeslaHint ? .black : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    Text(d.label)
                                        .font(.system(.footnote, design: .monospaced))
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(d.containsTeslaHint ? .orange : .gray)
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
            .navigationDestination(isPresented: $showDash) {
                DashboardView(serverURL: $server, pin: "428462")
            }
            .onChange(of: ble.readyForDashboard) { _, on in
                if on {
                    // Offer dash; auto-open once write succeeded
                    save()
                    showDash = true
                }
            }
        }
    }

    private var vinNorm: String {
        vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var fieldBG: some View {
        RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground))
    }

    private func label(_ t: String) -> some View {
        Text(t).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }

    private func save() {
        UserDefaults.standard.set(vinNorm, forKey: "pulse_vin")
        UserDefaults.standard.set(server.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "pulse_server")
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

private extension BLEPairer.DeviceRow {
    var containsTeslaHint: Bool {
        name.contains("🔑") || name.localizedCaseInsensitiveContains("tesla")
    }
}
