import SwiftUI

struct ContentView: View {
    @StateObject private var pairer = BLEPairer()
    @State private var vin: String = UserDefaults.standard.string(forKey: "pulse_vin")
        ?? "XP7YGCEK0PB159959"
    @State private var error: String?
    @State private var logOpen = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pulse Phone Key")
                        .font(.largeTitle.bold())

                    Text("ÖNEMLİ: Eşleştir’e basınca hemen kapıyı aç / ekranı uyandır. Tesla uygulamasını kapat.")
                        .font(.subheadline)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.18)))

                    Text("VIN").font(.caption.weight(.semibold))
                    TextField("17 karakter", text: $vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

                    Text("Beklenen: \(VCSECPayload.bleLocalName(vin: normalizedVin)) · Tesla \(String(normalizedVin.suffix(6)))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Button {
                        start()
                    } label: {
                        Text(pairer.busy ? "Aranıyor… kapıyı aç!" : "Bluetooth ile eşleştir (60sn)")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pairer.busy || normalizedVin.count != 17)

                    Text(pairer.status)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(pairer.waitingForCard ? Color.orange.opacity(0.2) : Color.blue.opacity(0.12))
                        )

                    Text(pairer.lastDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !pairer.nearby.isEmpty {
                        DisclosureGroup("Yakında görülen BLE (\(pairer.nearby.count))") {
                            ForEach(pairer.nearby, id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 12, design: .monospaced))
                            }
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
        }
    }

    private var normalizedVin: String {
        vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func start() {
        error = nil
        let v = normalizedVin
        guard v.count == 17 else {
            error = "VIN 17 karakter"
            return
        }
        UserDefaults.standard.set(v, forKey: "pulse_vin")
        do {
            let key = try KeyStore.loadOrCreatePrivateKey(forVIN: v)
            pairer.pair(vin: v, publicKey: KeyStore.publicKeyUncompressed(key))
        } catch {
            self.error = error.localizedDescription
        }
    }
}
