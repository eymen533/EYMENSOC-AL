import SwiftUI

/// Tek uygulama: BLE Pair + native cluster. Canlı telemetri Dash + Tesla Owner API.
struct ContentView: View {
    @StateObject private var ble = BLEPairer()
    @StateObject private var hud = HUDModel()
    @State private var vin = UserDefaults.standard.string(forKey: "pulse_vin") ?? "XP7YGCEK0PB159959"
    @State private var dashURL = UserDefaults.standard.string(forKey: "pulse_dash_url")
        ?? "https://mon-holds-cloud-grateful.trycloudflare.com"
    @State private var pin = UserDefaults.standard.string(forKey: "pulse_pin") ?? "428462"
    @State private var teslaToken = UserDefaults.standard.string(forKey: "pulse_tesla_token") ?? ""
    @State private var teslaVehicleId = UserDefaults.standard.string(forKey: "pulse_tesla_vid") ?? ""
    @State private var liveStatus = ""
    @State private var liveBusy = false
    @State private var showPairFlow = false
    @State private var screen: Screen = .home
    @State private var showSettings = false

    enum Screen { case home, hud }

    var body: some View {
        Group {
            switch screen {
            case .hud:
                NativeHUDView(
                    model: hud,
                    linkLabel: ble.linkLabel,
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
        .onChange(of: ble.linkUp) { _, on in
            if on { hud.bleOK = true }
        }
        .onChange(of: ble.readyForDashboard) { _, on in
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
                    Text("BLE Pair + canlı Cluster (Tesla API)")
                        .foregroundStyle(.white.opacity(0.55))
                    Text(BLEPairer.buildId)
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.35))
                    Text("build-33 · LIVE hız/vites/lastik/harita\nSettings → Tesla token yapıştır")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)

                    if ble.linkUp {
                        Label(ble.linkLabel, systemImage: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(Color(red: 0.3, green: 0.9, blue: 0.65))
                    } else if ble.paired || ble.waitingForCard || ble.readyForDashboard {
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
                        Text("Cluster HUD (canlı)")
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
                Section("Dash (zorunlu · canlı veri)") {
                    TextField("Dash URL", text: $dashURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("PIN", text: $pin)
                        .keyboardType(.numberPad)
                    Text("HUD her saniye /api/vehicle/state çeker. Tunnel URL güncel olsun.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Tesla Owner API · gerçek hız/GPS") {
                    SecureField("Access Token", text: $teslaToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Vehicle ID (bos = VIN’den bul)", text: $teslaVehicleId)
                        .keyboardType(.numberPad)
                    Button {
                        Task { await enableLive() }
                    } label: {
                        if liveBusy {
                            ProgressView()
                        } else {
                            Text("Canlı telemetriyi aç")
                        }
                    }
                    .disabled(liveBusy || teslaToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if !liveStatus.isEmpty {
                        Text(liveStatus)
                            .font(.footnote)
                            .foregroundStyle(liveStatus.contains("✓") ? .green : .orange)
                    }
                    Text("Token: Tesla hesabından Owner/Fleet access token. Kaydedilince Dash LIVE olur; HUD’da alt barda LIVE yazar. D vitesi ve hız arabadan gelir.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Not") {
                    Text("BLE Pair = Phone Key. Canlı hız/vites/lastik/harita = Tesla API (Settings token). Harita Apple MapKit · araç konumu.")
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
        let url = dashURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        UserDefaults.standard.set(url, forKey: "pulse_dash_url")
        UserDefaults.standard.set(pin.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "pulse_pin")
        UserDefaults.standard.set(teslaToken, forKey: "pulse_tesla_token")
        UserDefaults.standard.set(teslaVehicleId, forKey: "pulse_tesla_vid")
    }

    private func enableLive() async {
        save()
        liveBusy = true
        liveStatus = "Baglanıyor…"
        let msg = await hud.enableLiveOnDash(
            token: teslaToken.trimmingCharacters(in: .whitespacesAndNewlines),
            vehicleId: teslaVehicleId.trimmingCharacters(in: .whitespacesAndNewlines),
            pin: pin.trimmingCharacters(in: .whitespacesAndNewlines),
            dashURL: dashURL
        )
        liveStatus = msg
        liveBusy = false
    }

    private func openHUD() {
        hud.configure(
            vin: vinNorm,
            paired: ble.linkUp || ble.paired || ble.readyForDashboard || ble.waitingForCard
        )
        screen = .hud
    }
}
