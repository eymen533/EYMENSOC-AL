import SwiftUI
import CryptoKit

struct ContentView: View {
    @StateObject private var pairer = BLEPairer()
    @State private var vin: String = UserDefaults.standard.string(forKey: "pulse_vin")
        ?? "XP7YGCEK0PB159959"
    @State private var error: String?
    @State private var logOpen = true
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Pulse Phone Key")
                        .font(.largeTitle.bold())

                    if !pairer.bluetoothPrivacyOK {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Çökme engellendi")
                                .font(.headline)
                            Text("iOS, Bluetooth izin yazısı olmadan uygulamayı öldürüyor. Playgrounds bazen Info.plist’i yok sayıyor — elle ekle:")
                                .font(.subheadline)
                            Text("1) Sol üstte PulsePhoneKey / App Settings\n2) Capabilities → +\n3) Bluetooth seç\n4) Açıklama: Tesla Phone Key eşleşmesi için Bluetooth gerekir\n5) Run ▶ tekrar")
                                .font(.footnote)
                            Button("İzin kontrolünü yenile") {
                                pairer.refreshPrivacyFlag()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.14)))
                    }

                    Text("Swift Playgrounds · gerçek BLE Pair")
                        .foregroundStyle(.secondary)

                    Group {
                        Text("VIN").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        TextField("17 karakter", text: $vin)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                    }

                    Button {
                        Task { await start() }
                    } label: {
                        Text(pairer.busy ? "Çalışıyor… çıkma" : "Bluetooth ile eşleştir")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(pairer.busy || normalizedVin.count != 17 || !pairer.bluetoothPrivacyOK)

                    Text(pairer.status)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(pairer.paired ? Color.green.opacity(0.22)
                                      : pairer.waitingForCard ? Color.orange.opacity(0.18)
                                      : Color.blue.opacity(0.12))
                        )

                    if !pairer.lastDetail.isEmpty {
                        Text(pairer.lastDetail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text("Beklenen BLE: \(VCSECPayload.bleLocalName(vin: normalizedVin)) · Tesla \(String(normalizedVin.suffix(6)))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)

                    DisclosureGroup("Log", isExpanded: $logOpen) {
                        ForEach(Array(pairer.log.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if let error {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }
                }
                .padding(sizeClass == .regular ? 28 : 16)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { pairer.refreshPrivacyFlag() }
        }
    }

    private var normalizedVin: String {
        vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func start() async {
        error = nil
        let v = normalizedVin
        guard v.count == 17 else {
            error = "VIN 17 karakter olmalı"
            return
        }
        UserDefaults.standard.set(v, forKey: "pulse_vin")
        do {
            let key = try KeyStore.loadOrCreatePrivateKey(forVIN: v)
            let pub = KeyStore.publicKeyUncompressed(key)
            await pairer.pair(vin: v, publicKey: pub)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
