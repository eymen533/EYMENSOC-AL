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
                    Text("Swift Playgrounds · gerçek BLE Pair. Ayarlar’da S…C kaybolması bağlanınca normaldir.")
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
                        Text(pairer.busy ? "Çalışıyor… uygulamadan çıkma" : "Bluetooth ile eşleştir")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(pairer.busy || normalizedVin.count != 17)

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

                    VStack(alignment: .leading, spacing: 10) {
                        step(1, "Arabayı uyandır + Tesla uygulamasını kapat", on: true)
                        step(2, "Eşleştir → Log’da “İstek gönderildi ✓” bekle", on: pairer.waitingForCard || pairer.paired)
                        step(3, "Key Card → konsol (iPad değil) → Pair", on: pairer.waitingForCard || pairer.paired)
                    }

                    DisclosureGroup("Takılınca oku") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Bluetooth Ayarları’nda Tesla / S…C bir an görünüp gitmesi = çoğu zaman bağlandı, kayboldu değil.")
                            Text("• Pair / Confirm ancak “İstek gönderildi ✓” sonrası Key Card konsola konunca çıkar.")
                            Text("• Araç uykudaysa S…C hiç gelmez — kapıyı aç / ekranı uyandır.")
                            Text("• Resmi Tesla uygulaması BLE’yi tutuyorsa kapat (app switcher’dan sil).")
                            Text("• Playgrounds’ta üstteki Run ▶ kullan; yan önizleme BLE için güvenilmez.")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }

                    if let error {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }

                    Text("Beklenen BLE adı: \(VCSECPayload.bleLocalName(vin: normalizedVin)) · Tesla \(String(normalizedVin.suffix(6)))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)

                    DisclosureGroup("Log (HATA satırını oku)", isExpanded: .constant(true)) {
                        ForEach(Array(pairer.log.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(sizeClass == .regular ? 28 : 16)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var normalizedVin: String {
        vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func step(_ n: Int, _ text: String, on: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.caption.bold())
                .frame(width: 26, height: 26)
                .background(Circle().fill(on ? Color.green : Color.secondary.opacity(0.3)))
                .foregroundStyle(on ? .black : .primary)
            Text(text).font(.subheadline).foregroundStyle(on ? .primary : .secondary)
        }
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
