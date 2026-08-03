import SwiftUI

/// Tek uygulama: BLE Pair + gerçek BLE cluster telemetrisi (+ Dash yedek).
struct ContentView: View {
    @StateObject private var ble = BLEPairer()
    @StateObject private var hud = HUDModel()
    @ObservedObject private var hudSettings = HUDSettings.shared
    @State private var vin = Self.loadStoredVIN()
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
    /// Force home UI refresh when KeyStore paired flag changes.
    @State private var pairEpoch = 0

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
            if on {
                hud.bleOK = true
                pairEpoch &+= 1
            }
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
            // Closures only; telemetry engine still created at Pair / Resume, not here.
            let pairer = ble
            hud.bleSetVolume = { level in pairer.mediaSetVolume(level) }
            hud.bleMediaPlay = { pairer.mediaPlayToggle() }
            hud.bleMediaSkip = { delta in pairer.mediaSkip(delta) }
            // Dashla-style: start phone GPS early so map works without car.
            PhoneLocationStore.shared.start()
            // Bir kez eşleşmişse arka planda otomatik bağlanmayı başlat.
            if alreadyPaired, !ble.linkUp, !ble.bleLiveOK, vinNorm.count == 17 {
                ble.resumeSession(vin: vinNorm)
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
                    Text("xcode-ble-24 · panel harita · anlık BLE")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)

                    if ble.linkUp {
                        Label(ble.linkLabel, systemImage: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(Color(red: 0.3, green: 0.9, blue: 0.65))
                    } else if alreadyPaired {
                        Label("Phone Key kayıtlı — araca otomatik bağlanır", systemImage: "checkmark.seal.fill")
                            .font(.footnote)
                            .foregroundStyle(Color(red: 0.3, green: 0.9, blue: 0.65))
                            .multilineTextAlignment(.center)
                    } else if ble.paired || ble.waitingForCard || ble.readyForDashboard {
                        Label("Key session ready", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Color(red: 0.3, green: 0.9, blue: 0.65))
                    }

                    Spacer()

                    if alreadyPaired {
                        Button {
                            connectAndOpenHUD()
                        } label: {
                            Label(
                                ble.bleLiveOK ? "Cluster HUD (BLE LIVE)" : "Araca bağlan · Cluster",
                                systemImage: "antenna.radiowaves.left.and.right"
                            )
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
                            showPairFlow = true
                        } label: {
                            Text("Yeniden eşleştir")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(.white.opacity(0.85))
                                .background(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                        }
                    } else {
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
                            Text("Cluster HUD")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundStyle(.white)
                                .background(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
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
                    Text(alreadyPaired
                        ? "Phone Key bu VIN için kayıtlı. Araca her bindiğinde add-key yok — otomatik BLE bağlanır. Key Card konsolda olmalı."
                        : "İlk seferde Pair Vehicle: add-key + Key Card. Sonrasında otomatik bağlanır.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if alreadyPaired {
                        Button("Eşleşmeyi unut (yeniden peynir gerekir)", role: .destructive) {
                            KeyStore.clearPaired(vin: vinNorm)
                            pairEpoch &+= 1
                        }
                    }
                }
                Section("Bağlantı hızı") {
                    Picker("Refresh", selection: $hudSettings.refreshMode) {
                        ForEach(HUDSettings.RefreshMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text({
                        switch hudSettings.refreshMode {
                        case .instant: return "Anlık: maksimum BLE hızı (~20 Hz), en canlı hız/GPS."
                        case .performance: return "Performans: hızlı BLE, dengeli pil."
                        case .low: return "Düşük: daha az pil, daha seyrek güncelleme."
                        }
                    }())
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
                Section("Harita") {
                    Picker("Sağlayıcı", selection: $hudSettings.mapsProvider) {
                        ForEach(HUDSettings.MapsProvider.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(hudSettings.mapsProvider == .google
                        ? "Google Maps: araçta seçilen destinasyon Directions ile rotaya dönüşür. Maps JavaScript + Directions API key gerekir."
                        : "Apple Maps: API key yok. Konum/hedef arabadan (BLE); rota Apple Directions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if hudSettings.mapsProvider == .google {
                        SecureField("Google Maps API key", text: $googleMapsKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Toggle("Auto Zoom (rota sığdır)", isOn: $hudSettings.autoZoom)
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

    private var alreadyPaired: Bool {
        _ = pairEpoch
        return KeyStore.isPaired(vin: vinNorm) || KeyStore.hasPrivateKey(vin: vinNorm)
    }

    /// Never ship with a baked-in VIN — empty until user pastes from Tesla app.
    private static func loadStoredVIN() -> String {
        let key = "pulse_vin"
        let raw = (UserDefaults.standard.string(forKey: key) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        // Strip previously hardcoded sample VIN if still in defaults.
        let sample = "XP7YGCEK0PB159959"
        if raw.isEmpty || raw == sample {
            UserDefaults.standard.removeObject(forKey: key)
            return ""
        }
        return raw
    }

    private func save() {
        if vinNorm.count == 17 {
            UserDefaults.standard.set(vinNorm, forKey: "pulse_vin")
        } else if vinNorm.isEmpty {
            UserDefaults.standard.removeObject(forKey: "pulse_vin")
        }
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

    private func connectAndOpenHUD() {
        save()
        if alreadyPaired, vinNorm.count == 17, !ble.bleLiveOK {
            ble.resumeSession(vin: vinNorm)
        }
        openHUD()
    }

    private func openHUD() {
        let paired = alreadyPaired || ble.linkUp || ble.paired || ble.readyForDashboard || ble.waitingForCard || ble.bleLiveOK
        hud.configure(vin: vinNorm, paired: paired)
        if alreadyPaired, !ble.linkUp, !ble.bleLiveOK, vinNorm.count == 17 {
            ble.resumeSession(vin: vinNorm)
        }
        ble.ensureTelemetry()
        if ble.bleLiveOK {
            hud.applyBLE(ble.bleSnapshot, linkOK: true)
        }
        screen = .hud
    }
}
