import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var confirmUnpair = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.12, green: 0.14, blue: 0.28).opacity(0.7), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 480
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    CloseButton { appModel.closeSettings() }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                List {
                    Section("Vehicle") {
                        LabeledContent("VIN") {
                            Text(appModel.pairedVIN ?? "--")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(SOCTheme.textSecondary)
                        }
                        LabeledContent("Connection") {
                            Text(appModel.bleService.connectionStatus.title)
                                .foregroundStyle(
                                    appModel.bleService.connectionStatus.isLive
                                    ? SOCTheme.success
                                    : SOCTheme.textSecondary
                                )
                        }
                        Button("Reconnect") {
                            Task { await appModel.bleService.reconnect() }
                        }
                    }

                    Section("Units") {
                        Picker("Distance / Speed", selection: $appModel.unitSystem) {
                            Text("Metric (km)").tag(UnitSystem.metric)
                            Text("Imperial (mi)").tag(UnitSystem.imperial)
                        }
                    }

                    Section("Pairing") {
                        Button("Pair another vehicle") {
                            appModel.beginPairing()
                        }
                        Button("Remove vehicle key", role: .destructive) {
                            confirmUnpair = true
                        }
                    }

                    Section("About") {
                        LabeledContent("App", value: "SOC")
                        LabeledContent("Mode", value: "Personal BLE")
                        Text("Bu uygulama yalnızca kişisel kullanım içindir. Tesla Fleet API kullanmaz; araçla Bluetooth üzerinden konuşur.")
                            .font(.footnote)
                            .foregroundStyle(SOCTheme.textMuted)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
        .confirmationDialog(
            "Bu telefondaki anahtar silinsin mi?",
            isPresented: $confirmUnpair,
            titleVisibility: .visible
        ) {
            Button("Anahtarı sil", role: .destructive) {
                Task { await appModel.unpair() }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Araç konsolundan da bu telefon anahtarını kaldırmanız gerekebilir.")
        }
    }
}
