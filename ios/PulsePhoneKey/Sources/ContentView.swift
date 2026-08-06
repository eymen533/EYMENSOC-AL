import SwiftUI

/// Tek uygulama: BLE Pair + gerçek BLE cluster telemetrisi (+ Dash yedek).
struct ContentView: View {
    @StateObject private var ble = BLEPairer()
    @StateObject private var hud = HUDModel()
    @ObservedObject private var hudSettings = HUDSettings.shared
    @State private var showVINScanner = false
    @State private var showRePairConfirm = false
    @State private var vin = KeyStore.loadSavedVIN()
    @State private var logCopiedFlash = false
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
    /// Snapshot only — do not observe PulseDiagLog from the HUD root (Metal crash).
    @State private var diagEntryCount = 0
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
                .onAppear { diagEntryCount = PulseDiagLog.shared.entryCount }
        }
        .sheet(isPresented: $showVINScanner) {
            VINScannerSheet(vin: $vin)
        }
        .confirmationDialog(
            "Yeniden eşleştirme Key Card ister. Genelde gerekmez — sadece anahtar silindiyse.",
            isPresented: $showRePairConfirm,
            titleVisibility: .visible
        ) {
            Button("Yeniden eşleştir", role: .destructive) {
                save()
                showPairFlow = true
            }
            Button("Vazgeç", role: .cancel) {}
        }
        .onChangeCompat(of: ble.paired) { on in
            if on {
                hud.bleOK = true
                KeyStore.saveVIN(vinNorm)
                pairEpoch &+= 1
                PulseDiagLog.shared.info("Pair OK — VIN saklandı (cihazda), tekrar pair gerekmez")
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
            // Restore on-device VIN (never from source). Then auto-resume if paired once.
            if vinNorm.count != 17, let recovered = KeyStore.anyPairedVIN() {
                vin = recovered
                KeyStore.saveVIN(recovered)
                PulseDiagLog.shared.info("VIN cihazdan geri yüklendi")
            }
            if alreadyPaired, vinNorm.count == 17, !ble.linkUp, !ble.bleLiveOK {
                ble.resumeSession(vin: vinNorm)
                PulseDiagLog.shared.ble("Auto-resume after prior pair")
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

                VStack(spacing: 18) {
                    Spacer()
                    Text("PULSE 30")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(BLEPairer.buildId)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(Color(red: 1.0, green: 0.75, blue: 0.05))
                        )
                    Text("Tam ekran kanat · 3D kadran · Ayarlar→Şekil")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Pulse28 ikonunu aç")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.2))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

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
                            showRePairConfirm = true
                        } label: {
                            Text("Yeniden eşleştir (gerekirse)")
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
                        if alreadyPaired {
                            Button {
                                showRePairConfirm = true
                            } label: {
                                Label("Pair", systemImage: "plus.viewfinder")
                            }
                        } else {
                            Button {
                                save()
                                showPairFlow = true
                            } label: {
                                Label("Pair", systemImage: "plus.viewfinder")
                            }
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
                Section("VIN (sadece bu telefonda saklanır)") {
                    HStack(spacing: 10) {
                        TextField("17 karakter VIN", text: $vin)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                        Button {
                            showVINScanner = true
                        } label: {
                            Image(systemName: "camera.viewfinder")
                        }
                        .accessibilityLabel("Kameradan VIN oku")
                    }
                    Text(alreadyPaired
                        ? "Bu VIN için Phone Key kayıtlı. Tekrar pair gerekmez — Cluster ile bağlanır."
                        : "VIN kodu uygulama kaynak koduna yazılmaz; sen girince veya kameradan okutunca telefonda kalır.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if vinNorm.count == 17 {
                        Button("VIN’i bu telefona kaydet") {
                            KeyStore.saveVIN(vinNorm)
                            save()
                        }
                    }
                }
                Section("BLE telemetri (asıl kaynak)") {
                    Text(ble.bleStatus)
                        .font(.footnote)
                    Text(ble.bleLiveOK
                        ? "Durum: BLE LIVE — hız/GPS anlık geliyor."
                        : (ble.linkUp
                           ? "Durum: GATT bağlı ama oturum henüz LIVE değil (handshake)."
                           : "Durum: araç bağlantısı yok."))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(ble.bleLiveOK ? Color.green : .secondary)
                    Text(alreadyPaired
                        ? "Phone Key bu VIN için kayıtlı. Araca her bindiğinde add-key yok — otomatik BLE bağlanır. Key Card konsolda olmalı."
                        : "İlk seferde Pair Vehicle: add-key + Key Card. Sonrasında otomatik bağlanır.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if alreadyPaired {
                        Button("Eşleşmeyi unut (yeniden pair gerekir)", role: .destructive) {
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
                        case .instant: return "Anlık: hızlı BLE yazma + drive/GPS ağırlıklı poll."
                        case .performance: return "Performans: hızlı BLE, dengeli pil."
                        case .low: return "Düşük: daha az pil, daha seyrek güncelleme."
                        }
                    }())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Kadran") {
                    ForEach(HUDSettings.DialStyle.allCases) { style in
                        Button {
                            hudSettings.dialStyle = style
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: hudSettings.dialStyle == style ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(hudSettings.dialStyle == style ? Color.cyan : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(style.rawValue)
                                        .foregroundStyle(.primary)
                                        .font(.body.weight(hudSettings.dialStyle == style ? .semibold : .regular))
                                    Text(style.blurb)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
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
                    Picker("Konum kaynağı", selection: $hudSettings.mapGPSSource) {
                        ForEach(HUDSettings.MapGPSSource.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text({
                        switch hudSettings.mapGPSSource {
                        case .vehicle: return "Araç GPS: BLE araç konumu (önerilen) — telefon GPS yok sayılır."
                        case .phone: return "Telefon GPS: iPhone konumu (araç dışı deneme)."
                        case .auto: return "Otomatik: araç GPS varsa onu, yoksa telefonu kullanır."
                        }
                    }())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(hudSettings.mapsProvider == .google
                        ? "Google Maps: araç destinasyonu Directions rotası. API key gerekir."
                        : "Apple Maps: araç destinasyonu Directions rotası; rota bitince temizlenir.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if hudSettings.mapsProvider == .google {
                        SecureField("Google Maps API key", text: $googleMapsKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Toggle("Auto Zoom (rota sığdır)", isOn: $hudSettings.autoZoom)
                    Text("Cluster siyah kalır; harita açık/aydınlık tema ile okunur.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Hata / bağlantı logları") {
                    Text("Kopma veya garip davranış olunca buradaki logları kopyalayıp paylaş — teşhis için.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    NavigationLink {
                        DiagLogViewer()
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Logları aç")
                            Spacer()
                            Text("\(diagEntryCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Logları panoya kopyala") {
                        let log = PulseDiagLog.shared
                        UIPasteboard.general.string = {
                            let header = "Pulse28 \(BLEPairer.buildId) · \(ISO8601DateFormatter().string(from: Date()))\n"
                            return header + log.entries.reversed().map(\.line).joined(separator: "\n")
                        }()
                        PulseDiagLog.shared.info("Log copied to clipboard (\(log.entryCount) lines)")
                        diagEntryCount = PulseDiagLog.shared.entryCount
                        logCopiedFlash = true
                    }
                    if logCopiedFlash {
                        Text("Kopyalandı — buraya yapıştırıp paylaşabilirsin.")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                    Button("Logları temizle", role: .destructive) {
                        PulseDiagLog.shared.clear()
                        diagEntryCount = 0
                    }
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
        let v = vinNorm
        if KeyStore.isPaired(vin: v) || KeyStore.hasPrivateKey(vin: v) { return true }
        // VIN alanı boşsa ama cihazda eski pair varsa yine paired say.
        if let other = KeyStore.anyPairedVIN(), KeyStore.isPaired(vin: other) || KeyStore.hasPrivateKey(vin: other) {
            return true
        }
        return false
    }

    private func save() {
        if KeyStore.isValidVIN(vinNorm) {
            KeyStore.saveVIN(vinNorm)
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
        openHUD()
    }

    private func openHUD() {
        // Ensure VIN is recovered before resume.
        if vinNorm.count != 17, let recovered = KeyStore.anyPairedVIN() {
            vin = recovered
        }
        save()
        let paired = alreadyPaired || ble.linkUp || ble.paired || ble.readyForDashboard || ble.waitingForCard || ble.bleLiveOK
        hud.configure(vin: vinNorm, paired: paired)
        if paired, vinNorm.count == 17, !ble.bleLiveOK {
            ble.resumeSession(vin: vinNorm)
        }
        ble.ensureTelemetry()
        if ble.bleLiveOK {
            hud.applyBLE(ble.bleSnapshot, linkOK: true)
        }
        screen = .hud
    }
}

/// Settings → diagnostic log list with level colors.
struct DiagLogViewer: View {
    @ObservedObject private var log = PulseDiagLog.shared

    var body: some View {
        List {
            ForEach(log.entries) { e in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(e.level.rawValue)
                            .font(.caption2.weight(.bold).monospaced())
                            .foregroundStyle(color(for: e.level))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(color(for: e.level).opacity(0.18)))
                        Spacer()
                        Text(time(e.date))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(e.message)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }
        }
        .navigationTitle("Hata logları")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Kopyala") {
                    UIPasteboard.general.string =
                        "Pulse28 \(BLEPairer.buildId)\n"
                        + log.entries.reversed().map(\.line).joined(separator: "\n")
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("Temizle", role: .destructive) { log.clear() }
            }
        }
    }

    private func color(for level: PulseDiagLog.Level) -> Color {
        switch level {
        case .info: return .secondary
        case .warn: return .orange
        case .error: return .red
        case .ble: return Color(red: 0.25, green: 0.7, blue: 0.95)
        }
    }

    private func time(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: d)
    }
}
