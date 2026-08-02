import SwiftUI

/// App shell: top bar Pair Vehicle + real Dash HUD.
struct ContentView: View {
    /// Live Dash tunnel (quick tunnels rotate — update Settings if HUD fails).
    static let defaultServer = "https://leadership-disabled-buyers-spaces.trycloudflare.com"
    private static let staleServerMarkers = [
        "beach-mobiles-writers-developments.trycloudflare.com",
    ]

    @StateObject private var ble = BLEPairer()
    @State private var vin = UserDefaults.standard.string(forKey: "pulse_vin") ?? "XP7YGCEK0PB159959"
    @State private var server = ContentView.migratedServer()
    @State private var pin = UserDefaults.standard.string(forKey: "pulse_pin") ?? "428462"
    @State private var showPairFlow = false
    @State private var screen: Screen = .home
    @State private var showSettings = false
    @State private var serverTest: String?

    enum Screen { case home, hud }

    var body: some View {
        Group {
            switch screen {
            case .hud:
                RealHUDView(
                    server: server,
                    pin: pin,
                    vin: vinNorm,
                    onBack: { screen = .home }
                )
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
                    screen = .hud
                }
            )
        }
        .sheet(isPresented: $showSettings) {
            settingsSheet
        }
        .onChange(of: ble.paired) { _, on in
            if on {
                // Stay in flow until user taps Open HUD
            }
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

                VStack(spacing: 24) {
                    Spacer()
                    Text("PULSE")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("iPhone uygulaması · BLE Phone Key + Cluster")
                        .foregroundStyle(.white.opacity(0.55))
                    Text(BLEPairer.buildId)
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.35))
                    Text("Safari degil — Ana Ekran uygulamasi")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))

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
                                            Color(red: 0.45, green: 0.35, blue: 0.95),
                                            Color(red: 0.25, green: 0.45, blue: 0.98),
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            )
                    }

                    Button {
                        save()
                        screen = .hud
                    } label: {
                        Text("Open Cluster HUD")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundStyle(.white)
                            .background(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }

                    Spacer().frame(height: 40)
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
                        Button {
                            showSettings = true
                        } label: {
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
                Section {
                    TextField("https://…", text: $server)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Sunucu baglantisini test et") {
                        Task { await testServer() }
                    }
                    if let serverTest {
                        Text(serverTest)
                            .font(.footnote)
                            .foregroundStyle(serverTest.contains("OK") ? .green : .red)
                    }
                } header: {
                    Text("Dash server")
                } footer: {
                    Text("Baglanti hatasi aliyorsan URL eski demektir. Varsayilani kullan veya guncel tunnel adresini yapistir.")
                }
                Section("PIN") {
                    TextField("PIN", text: $pin)
                        .keyboardType(.numberPad)
                }
                Section("VIN") {
                    TextField("VIN", text: $vin)
                        .textInputAutocapitalization(.characters)
                }
                Section {
                    Button("Varsayilan sunucuya don") {
                        server = Self.defaultServer
                        serverTest = nil
                        save()
                    }
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
        UserDefaults.standard.set(PulseSession.normalizeServer(server), forKey: "pulse_server")
        UserDefaults.standard.set(pin, forKey: "pulse_pin")
        server = PulseSession.normalizeServer(server)
    }

    /// Replace dead quick-tunnel URLs so old installs stop showing baglanti hatasi.
    private static func migratedServer() -> String {
        let raw = UserDefaults.standard.string(forKey: "pulse_server") ?? defaultServer
        let normalized = PulseSession.normalizeServer(raw)
        for marker in staleServerMarkers where normalized.contains(marker) {
            UserDefaults.standard.set(defaultServer, forKey: "pulse_server")
            return defaultServer
        }
        return normalized.isEmpty ? defaultServer : normalized
    }

    private func testServer() async {
        serverTest = "Test ediliyor…"
        save()
        do {
            _ = try await PulseSession.ping(server: server, pin: pin)
            serverTest = "OK — sunucu ulasilabilir"
        } catch {
            serverTest = error.localizedDescription
        }
    }
}
