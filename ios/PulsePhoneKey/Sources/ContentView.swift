import SwiftUI
import CryptoKit

struct ContentView: View {
    @StateObject private var pairer = BLEPairer()
    @State private var vin: String = UserDefaults.standard.string(forKey: "pulse_vin") ?? ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pulse Phone Key")
                        .font(.largeTitle.bold())
                    Text("iPhone Bluetooth ile araca add-key-request gönderir. Sonra Key Card’ı konsola koy.")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("VIN").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        TextField("17 karakter", text: $vin)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    }

                    Button {
                        Task { await start() }
                    } label: {
                        Text(pairer.busy ? "Çalışıyor…" : "Bluetooth ile eşleştir")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pairer.busy || vin.trimmingCharacters(in: .whitespaces).count != 17)

                    Text(pairer.status)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(pairer.paired ? Color.green.opacity(0.2) : Color.blue.opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 8) {
                        step(1, "Bluetooth izni ver, Tesla’yı bekle", on: true)
                        step(2, "Key Card → konsol okuyucu (telefona değil)", on: pairer.waitingForCard || pairer.paired)
                        step(3, "Araç ekranında Pair / Confirm", on: pairer.paired)
                    }

                    if let error {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }

                    DisclosureGroup("Log") {
                        ForEach(Array(pairer.log.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Link("Xcode kurulumu / README", destination: URL(string: "https://github.com/eymen533/EYMENSOC-AL")!)
                        .font(.footnote)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func step(_ n: Int, _ text: String, on: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(on ? Color.green : Color.secondary.opacity(0.3)))
                .foregroundStyle(on ? .black : .primary)
            Text(text).font(.subheadline).foregroundStyle(on ? .primary : .secondary)
        }
    }

    private func start() async {
        error = nil
        let v = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
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
