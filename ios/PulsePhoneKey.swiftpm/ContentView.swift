import SwiftUI

struct ContentView: View {
    @StateObject private var pairer = BLEPairer()
    @State private var vin: String = UserDefaults.standard.string(forKey: "pulse_vin")
        ?? "XP7YGCEK0PB159959"
    @State private var serverURL: String = UserDefaults.standard.string(forKey: "pulse_server")
        ?? "https://beach-mobiles-writers-developments.trycloudflare.com"
    @State private var error: String?
    @State private var logOpen = false
    @State private var showDash = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pulse Phone Key")
                        .font(.largeTitle.bold())

                    Text("SÜRÜM: \(BLEPairer.buildId)")
                        .font(.caption.weight(.bold))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.3)))

                    if pairDone {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Anahtar eklendi / istek gitti ✓")
                                .font(.headline)
                            Text("Dashboard ayrı ekran — aşağıdan aç (PIN: 428462)")
                                .font(.subheadline)
                            Button {
                                saveServer()
                                showDash = true
                            } label: {
                                Text("Pulse Dashboard / HUD aç")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .font(.headline)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.green.opacity(0.18)))
                    }

                    Text("Server (Dash)").font(.caption.weight(.semibold))
                    TextField("https://….trycloudflare.com", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

                    Button {
                        saveServer()
                        showDash = true
                    } label: {
                        Text("Dashboard’u şimdi aç (Pair’siz)")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)

                    Divider()

                    Text("1) Tarama  2) Turuncu 🔑  3) Kart konsola  4) Dashboard")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("VIN").font(.caption.weight(.semibold))
                    TextField("17 karakter", text: $vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

                    Button {
                        start()
                    } label: {
                        Text(pairer.busy ? "Taraniyor… turuncu 🔑’ye dokun" : "1. Taramayi baslat")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(normalizedVin.count != 17)

                    Text(pairer.status)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.12)))

                    Text(pairer.lastDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !pairer.candidates.isEmpty {
                        Text("2. TURUNCUYA DOKUN")
                            .font(.headline)
                        ForEach(pairer.candidates, id: \.id) { c in
                            Button {
                                pairer.connectCandidate(id: c.id)
                            } label: {
                                Text("BAĞLAN → \(c.label)")
                                    .font(.system(.body, design: .monospaced).weight(.semibold))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                    }

                    DisclosureGroup("Yakında BLE (\(pairer.nearby.count))") {
                        ForEach(pairer.nearby, id: \.self) { line in
                            Text(line).font(.system(size: 12, design: .monospaced))
                        }
                    }

                    DisclosureGroup("Log", isExpanded: $logOpen) {
                        ForEach(Array(pairer.log.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if let error {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showDash) {
                DashboardView(serverURL: serverURL, pinHint: "428462")
            }
            .onChange(of: pairer.waitingForCard) { _, on in
                if on { maybeOfferDash() }
            }
            .onChange(of: pairer.paired) { _, on in
                if on { maybeOfferDash() }
            }
            .onChange(of: pairer.status) { _, s in
                let u = s.uppercased()
                if u.contains("OK:") || u.contains("EKLENDI") || u.contains("ONAYLANDI") || u.contains("TX TAMAM") {
                    maybeOfferDash()
                }
            }
        }
    }

    private var pairDone: Bool {
        pairer.waitingForCard || pairer.paired
            || pairer.status.uppercased().contains("OK:")
            || pairer.status.localizedCaseInsensitiveContains("eklendi")
            || pairer.status.localizedCaseInsensitiveContains("onaylandi")
            || pairer.status.localizedCaseInsensitiveContains("istek gitti")
    }

    private var normalizedVin: String {
        vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func saveServer() {
        UserDefaults.standard.set(serverURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "pulse_server")
    }

    private func maybeOfferDash() {
        // Don't auto-push (user may still place card); green button appears via pairDone
    }

    private func start() {
        error = nil
        let v = normalizedVin
        guard v.count == 17 else {
            error = "VIN 17 karakter"
            return
        }
        UserDefaults.standard.set(v, forKey: "pulse_vin")
        saveServer()
        do {
            let key = try KeyStore.loadOrCreatePrivateKey(forVIN: v)
            pairer.pair(vin: v, publicKey: KeyStore.publicKeyUncompressed(key))
        } catch {
            self.error = error.localizedDescription
        }
    }
}
