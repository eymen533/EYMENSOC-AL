import SwiftUI

/// Tek uygulama: BLE Pair + gerçek BLE cluster telemetrisi (+ Dash yedek).
struct ContentView: View {
    @StateObject private var ble = BLEPairer()
    @StateObject private var hud = HUDModel()
    @ObservedObject private var hudSettings = HUDSettings.shared
    @State private var vin = UserDefaults.standard.string(forKey: "pulse_vin") ?? "XP7YGCEK0PB159959"
    @State private var dashURL = UserDefaults.standard.string(forKey: "pulse_dash_url")
        ?? "https://mon-holds-cloud-grateful.trycloudflare.com"
    @State private var pin = UserDefaults.standard.string(forKey: "pulse_pin") ?? "428462"
    @State private var teslaToken = UserDefaults.standard.string(forKey: "pulse_tesla_token") ?? ""
    @State private var teslaVehicleId = UserDefaults.standard.string(forKey: "pulse_tesla_vid") ?? ""
    @State private var googleMapsKey = UserDefaults.standard.string(forKey: "pulse_google_maps_key") ?? ""
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
                    onBack: { screen = .home },
                    onSettings: { showSettings = true }
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
        .onChangeCompat(of: ble.paired) { on in
            if on { hud.bleOK = true }
        }
        .onChangeCompat(of: ble.linkUp) { on in
            if on { hud.bleOK = true }
        }
        .onChangeCompat(of: ble.readyForDashboard) { on in
            if on { hud.bleOK = true }
        }
        .onChangeCompat(of: ble.bleSnapRev) { _ in
            if ble.bleLiveOK {
                hud.bleOK = true
                hud.applyBLE(ble.bleSnapshot, linkOK: true)
            }
        }
        .onChangeCompat(of: ble.bleLiveOK) { ok in
            if ok {
                hud.bleOK = true
                hud.applyBLE(ble.bleSnapshot, linkOK: true)
            }
        }
        .onAppear {
            // Closures only; telemetry engine still created at Pair, not here.
            let pairer = ble
            hud.bleSetVolume = { level in pairer.mediaSetVolume(level) }
            hud.bleMediaPlay = { pairer.mediaPlayToggle() }
            hud.bleMediaSkip = { delta in pairer.mediaSkip(delta) }
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
                    Text("Xcode native · gerçek BLE Cluster")
                        .foregroundStyle(.white.opacity(0.55))
                    Text(BLEPairer.buildId)
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.35))
                    Text("xcode-ble-7 · hızlı BLE · ekran uyanık · büyük hız")
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
                        Text(ble.bleLiveOK ? "Cluster HUD (BLE LIVE)" : "Cluster HUD")
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
                Section("BLE telemetri (asıl kaynak)") {
                    Text(ble.bleStatus)
                        .font(.footnote)
                    Text("Pair sonrası araçla imzalı BLE oturumu açılır: hız, vites, lastik, batarya, medya, GPS. Key Card konsolda olmalı.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Bağlantı hızı") {
                    Picker("Refresh", selection: $hudSettings.refreshMode) {
                        ForEach(HUDSettings.RefreshMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(hudSettings.refreshMode == .performance
                         ? "Performans: daha hızlı BLE/Dash verisi (telefon ısınabilir)."
                         : "Düşük: daha az pil, daha seyrek güncelleme.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Dashboard Style") {
                    Picker("Speedometer", selection: $hudSettings.speedStyle) {
                        ForEach(HUDSettings.SpeedStyle.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Speed color", selection: $hudSettings.speedColor) {
                        ForEach(HUDSettings.SpeedColor.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Gear multicolor (P/R/N/D)", isOn: $hudSettings.gearMulticolor)
                    Picker("Motor power", selection: $hudSettings.powerStyle) {
                        ForEach(HUDSettings.PowerStyle.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Live location", selection: $hudSettings.liveLocation) {
                        ForEach(HUDSettings.LiveLocation.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Maps (araç GPS)") {
                    Text("Apple Maps — API key yok. Konum/hedef arabadan (BLE) gelir; rota Apple Directions ile çizilir.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Toggle("Auto Zoom", isOn: $hudSettings.autoZoom)
                    Picker("Theme", selection: $hudSettings.mapTheme) {
                        ForEach(HUDSettings.MapTheme.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Dash (yedek)") {
                    TextField("Dash URL", text: $dashURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("PIN", text: $pin)
                        .keyboardType(.numberPad)
                    Text("BLE yoksa yedek olarak /api/vehicle/state.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Tesla Owner API (opsiyonel yedek)") {
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
                            Text("Dash üzerinden API yedek aç")
                        }
                    }
                    .disabled(liveBusy || teslaToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if !liveStatus.isEmpty {
                        Text(liveStatus)
                            .font(.footnote)
                            .foregroundStyle(liveStatus.contains("✓") ? .green : .orange)
                    }
                }
                Section("Not") {
                    Text("Model Y lastik görseli · Apple/Google harita · Performans=hızlı veri. iOS 16+.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save()
                        ble.applyRefreshModeFromSettings()
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
        UserDefaults.standard.set(
            googleMapsKey.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: "pulse_google_maps_key"
        )
        hud.reloadMapsKey()
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
        let paired = ble.linkUp || ble.paired || ble.readyForDashboard || ble.waitingForCard || ble.bleLiveOK
        hud.configure(vin: vinNorm, paired: paired)
        ble.ensureTelemetry()
        if ble.bleLiveOK {
            hud.applyBLE(ble.bleSnapshot, linkOK: true)
        }
        screen = .hud
    }
}
