import SwiftUI

/// Tek uygulama: BLE Pair + native cluster. WebView / uzak Dash yok.
struct ContentView: View {
    @StateObject private var ble = BLEPairer()
    @StateObject private var hud = HUDModel()
    @State private var vin = UserDefaults.standard.string(forKey: "pulse_vin") ?? "XP7YGCEK0PB159959"
    @State private var showPairFlow = false
    @State private var screen: Screen = .home
    @State private var showSettings = false

    enum Screen { case home, hud }

    var body: some View {
        Group {
            switch screen {
            case .hud:
                NativeHUDView(model: hud, onBack: { screen = .home })
            case .home:
                home
            }
        }
        .fullScreenCover(isPresented: $showPairFlow) {
            PairingFlowView(
                ble: ble,
                vin: $vin,
                onClose: { showPairFlow = false },
                onFinished: {
                    showPairFlow = false
                    save()
                    openHUD()
                }
            )
        }
        .sheet(isPresented: $showSettings) {
            settingsSheet
        }
        .onChange(of: ble.paired) { _, on in
            if on { hud.bleOK = true }
        }
    }

    private var home: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.06, blue: 0.09), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 22) {
                    Spacer()
                    Text("PULSE")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Tek uygulama · BLE Pair + klasik Cluster")
                        .foregroundStyle(.white.opacity(0.55))
                    Text(BLEPairer.buildId)
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.35))
                    Text("Sade HUD · seyahat / lastik / harita / medya · WebView yok")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)

                    if ble.paired || ble.waitingForCard || ble.readyForDashboard {
                        Label("Key session ready", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Color(red: 0.3, green: 0.9, blue: 0.65))
                    }

                    Spacer()

                    Button {
                        save()
                        showPairFlow = true
                    } label: {
                        Label("Pair Vehicle", systemImage: "key.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .foregroundStyle(.white)
                            .background(
                                Capsule().fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.2, green: 0.75, blue: 0.65),
                                            Color(red: 0.15, green: 0.45, blue: 0.9),
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            )
                    }

                    Button {
                        save()
                        openHUD()
                    } label: {
                        Text("Cluster HUD (uygulama ici)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundStyle(.white)
                            .background(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }

                    Spacer().frame(height: 36)
                }
                .padding(.horizontal, 28)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Pulse")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Button {
                            save()
                            showPairFlow = true
                        } label: {
                            Label("Pair", systemImage: "plus.viewfinder")
                        }
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("VIN") {
                    TextField("VIN", text: $vin)
                        .textInputAutocapitalization(.characters)
                }
                Section {
                    Text("Pair Bluetooth ile bu cihazda yapilir. Cluster da ayni uygulamada acilir — Safari / WebView kullanilmaz.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save()
                        showSettings = false
                    }
                }
            }
        }
    }

    private var vinNorm: String {
        vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func save() {
        UserDefaults.standard.set(vinNorm, forKey: "pulse_vin")
    }

    private func openHUD() {
        hud.configure(vin: vinNorm, paired: ble.paired || ble.readyForDashboard || ble.waitingForCard)
        screen = .hud
    }
}
