import Foundation
import CoreBluetooth
import CryptoKit

/// Tesla VCSEC pairer + live BLE telemetry session for Xcode native.
final class BLEPairer: NSObject, ObservableObject {
    static let buildId = "xcode-ble-80"

    enum Step: String {
        case idle = "Hazir"
        case scanning = "Taraniyor"
        case connecting = "Baglaniyor"
        case services = "Servisler"
        case writing = "Yaziliyor"
        case waitingCard = "Kart bekle"
        case done = "Tamam"
        case failed = "Hata"
    }

    struct DeviceRow: Identifiable, Equatable {
        let id: UUID
        var name: String
        var rssi: Int
        var label: String { "\(name)  \(rssi) dBm" }
    }

    @Published var step: Step = .idle
    @Published var status: String = "VIN dogrula → Tara → listeden 🔑 Tesla’ya dokun"
    @Published var log: [String] = []
    @Published var devices: [DeviceRow] = []
    @Published var waitingForCard = false
    @Published var paired = false
    @Published var readyForDashboard = false
    @Published var linkUp = false
    @Published var linkLabel = "BLE kapali"
    /// Flat published fields — telemetry is created only on Pair (launch-safe).
    @Published var bleLiveOK = false
    @Published var bleSnapRev = 0
    @Published var bleStatus = "BLE telemetri kapali"
    @Published private(set) var bleSnapshot = VehicleLiveSnapshot()

    /// Lazy: nil until Pair starts — avoids Playgrounds launch crash.
    private var telemetry: BLETelemetry?

    private let serviceUUID = CBUUID(string: "00000211-B2D1-43F0-9B88-960CEBF8B91E")
    private let writeUUID = CBUUID(string: "00000212-B2D1-43F0-9B88-960CEBF8B91E")
    private let readUUID = CBUUID(string: "00000213-B2D1-43F0-9B88-960CEBF8B91E")

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var payload: Data?
    private var chunks: [Data] = []
    private var writing = false
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var deadline: Date?
    private var timer: Timer?
    private var reconnectAttempts = 0
    /// Avoid GATT cancel/connect storms when stalls repeat.
    private var lastGATTBounceAt = Date.distantPast
    private var vin = ""
    private var privateKey: P256.KeyAgreement.PrivateKey?
    private var pairWriteDone = false
    private var resumeTelemetryOnly = false
    /// true = kullanıcı bilinçli olarak yeniden eşleştiriyor (add-key tekrar gönder).
    private var forceRePair = false

    // MARK: - Public

    var isLinked: Bool { linkUp || paired || readyForDashboard }

    /// Disk’te bu VIN için Phone Key daha önce kabul edilmiş mi?
    var hasPersistedPair: Bool { KeyStore.isPaired(vin: vin) || (!vin.isEmpty && KeyStore.isPaired(vin: vin)) }

    static func hasPersistedPair(vin: String) -> Bool { KeyStore.isPaired(vin: vin) }

    func keepAliveReconnect() {
        onMain {
            let maxAttempts = self.resumeTelemetryOnly || self.pairWriteDone || KeyStore.isPaired(vin: self.vin) ? 50 : 8
            if let p = self.peripheral, p.state == .connected {
                self.linkUp = true
                self.linkLabel = self.bleLiveOK ? "BLE LIVE" : "GATT bagli · oturum…"
                self.startTelemetryIfPossible(force: false)
                return
            }

            // Fast path: already-connected Tesla GATT (common when re-entering car).
            if let central = self.central, central.state == .poweredOn {
                let linked = central.retrieveConnectedPeripherals(withServices: [self.serviceUUID])
                if let p = linked.first {
                    self.peripherals[p.identifier] = p
                    self.peripheral = p
                    p.delegate = self
                    self.logLine("keepalive connected-peripheral")
                    self.linkLabel = "Yeniden baglan…"
                    self.status = "BLE yeniden baglaniliyor…"
                    if p.state == .connected {
                        self.linkUp = true
                        p.discoverServices(nil)
                    } else {
                        central.connect(p, options: Self.connectOptions)
                    }
                    return
                }
                if let id = KeyStore.storedPeripheralId(vin: self.vin) {
                    let known = central.retrievePeripherals(withIdentifiers: [id])
                    if let p = known.first {
                        self.peripherals[p.identifier] = p
                        self.peripheral = p
                        p.delegate = self
                    }
                }
            }

            if let p = self.peripheral, self.reconnectAttempts < maxAttempts {
                self.reconnectAttempts += 1
                self.logLine("reconnect #\(self.reconnectAttempts)")
                self.linkLabel = "Yeniden baglan…"
                self.status = "BLE yeniden baglaniliyor…"
                self.central?.connect(p, options: Self.connectOptions)
                return
            }
            // Known peripheral exhausted — rescan (already paired / resume).
            if self.resumeTelemetryOnly || self.pairWriteDone || KeyStore.isPaired(vin: self.vin) {
                self.reconnectAttempts = 0
                self.logLine("rescan after reconnect limit")
                self.step = .scanning
                self.status = "Arac araniyor — otomatik baglanacak"
                self.deadline = Date().addingTimeInterval(120)
                self.startScan()
                self.timer?.invalidate()
                self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                    self?.tick()
                }
            }
        }
    }

    /// İlk eşleştirme: add-key + Key Card (sadece bir kez gerekir).
    func start(vin: String, publicKey: Data) {
        onMain {
            self.resetSessionState(vin: vin, resumeOnly: false)
            self.payload = VCSECPayload.addKeyRequest(publicKeyUncompressed: publicKey)
            self.paired = false
            self.readyForDashboard = false
            self.pairWriteDone = false
            self.resumeTelemetryOnly = false
            self.forceRePair = true
            self.logLine("\(Self.buildId) PAIR VIN \(self.vin)")
            self.logLine("hedef \(VCSECPayload.bleNames(vin: self.vin).joined(separator: ", "))")
            self.logLine("payload \(self.payload?.count ?? 0)b")
            self.ensureTelemetryEngine()
            self.beginScanPhase(message: "Tarama acik — asagidan 🔑 Tesla satirina DOKUN", seconds: 90)
        }
    }

    /// Daha önce pair / Phone Key kabul edilmiş VIN — add-key YOK, sadece bağlan + telemetri.
    func resumeSession(vin: String) {
        onMain {
            let v = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard v.count == 17 else {
                self.fail("VIN 17 karakter olmali")
                return
            }
            guard KeyStore.isPaired(vin: v) || KeyStore.hasPrivateKey(vin: v) else {
                self.fail("Once Pair Vehicle ile eslestir")
                return
            }

            // Already working / reconnecting for this VIN — do not tear the session down.
            if self.vin == v, self.resumeTelemetryOnly {
                if self.bleLiveOK {
                    self.logLine("resume skip — already LIVE")
                    return
                }
                if self.linkUp {
                    self.logLine("resume skip — GATT up, ensure telemetry")
                    self.startTelemetryIfPossible(force: false)
                    return
                }
                if self.step == .connecting || self.step == .scanning || self.step == .services {
                    self.logLine("resume skip — \(self.step.rawValue) in flight")
                    return
                }
            }

            if let key = try? KeyStore.loadOrCreatePrivateKey(forVIN: v) {
                self.privateKey = key
            } else {
                self.fail("Anahtar yuklenemedi")
                return
            }
            // Eski kurulum: key var ama paired bayragi yoksa yine resume dene (add-key yok).
            if !KeyStore.isPaired(vin: v) {
                KeyStore.markPaired(vin: v)
            }
            self.resetSessionState(vin: v, resumeOnly: true)
            self.payload = nil
            self.paired = true
            self.readyForDashboard = true
            self.pairWriteDone = true
            self.resumeTelemetryOnly = true
            self.waitingForCard = false
            self.forceRePair = false
            self.logLine("\(Self.buildId) RESUME VIN \(self.vin) — add-key yok")
            self.ensureTelemetryEngine()

            if self.central == nil {
                self.central = CBCentralManager(delegate: self, queue: .main)
            }

            // Hızlı yol: bilinen peripheral UUID
            if let id = KeyStore.storedPeripheralId(vin: self.vin),
               let central = self.central, central.state == .poweredOn {
                let known = central.retrievePeripherals(withIdentifiers: [id])
                if let p = known.first {
                    self.peripherals[p.identifier] = p
                    self.peripheral = p
                    p.delegate = self
                    self.step = .connecting
                    self.status = "Kayitli araca baglaniyor…"
                    self.linkLabel = "Yeniden baglan…"
                    self.logLine("retrieve \(id.uuidString.prefix(8))")
                    central.connect(p, options: Self.connectOptions)
                    self.timer?.invalidate()
                    self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                        self?.tickResumeConnect()
                    }
                    // Fail over to scan quickly if retrieve hangs.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
                        guard let self, self.step == .connecting, self.peripheral?.state != .connected else { return }
                        self.logLine("retrieve timeout → scan")
                        self.beginScanPhase(message: "Arac araniyor — otomatik baglanacak", seconds: 120)
                    }
                    return
                }
            }
            self.beginScanPhase(message: "Arac araniyor — otomatik baglanacak (yeniden eslestirme yok)", seconds: 120)
        }
    }

    private func resetSessionState(vin: String, resumeOnly: Bool) {
        self.vin = vin.uppercased()
        if !resumeOnly, let key = try? KeyStore.loadOrCreatePrivateKey(forVIN: self.vin) {
            self.privateKey = key
        }
        self.linkUp = false
        self.linkLabel = "Baglanti yok"
        self.reconnectAttempts = 0
        self.devices = []
        self.peripherals = [:]
        self.chunks = []
        self.writing = false
        self.peripheral = nil
        self.writeChar = nil
        self.telemetry?.detach()
        self.telemetry = nil
        self.bleLiveOK = false
        self.bleStatus = "BLE telemetri kapali"
        self.bleSnapRev = 0
        self.bleSnapshot = VehicleLiveSnapshot()
        self.waitingForCard = false
    }

    private func beginScanPhase(message: String, seconds: TimeInterval) {
        self.step = .scanning
        self.status = message
        self.deadline = Date().addingTimeInterval(seconds)
        if self.central == nil {
            self.central = CBCentralManager(delegate: self, queue: .main)
        } else {
            self.startScan()
        }
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tickResumeConnect() {
        guard step == .connecting, let p = peripheral else { return }
        if p.state == .connected { return }
        // Timer only watches; timeout is scheduled in resumeSession (~3.5s).
    }

    func connect(id: UUID) {
        onMain {
            guard let p = self.peripherals[id] else {
                self.fail("Cihaz kayboldu — tekrar tara")
                return
            }
        let canResume = !self.forceRePair && (self.resumeTelemetryOnly || self.pairWriteDone || KeyStore.isPaired(vin: self.vin))
            guard self.payload != nil || canResume else {
                self.fail("Once Tara’ya bas")
                return
            }
            guard self.step == .scanning || self.step == .failed || self.step == .idle else {
                self.logLine("zaten \(self.step.rawValue)")
                return
            }
            self.timer?.invalidate()
            self.central?.stopScan()
            self.peripheral = p
            p.delegate = self
            self.step = .connecting
            self.status = "Baglaniyor: \(p.name ?? id.uuidString.prefix(8).description)…"
            self.logLine("CONNECT \(p.name ?? "?")")
            self.central?.connect(p, options: Self.connectOptions)
        }
    }

    private static var connectOptions: [String: Any] {
        // Ask iOS to bring the link up promptly after a drop.
        [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionNotifyOnNotificationKey: true,
        ]
    }

    private func persistPairSuccess(peripheralId: UUID? = nil) {
        guard !vin.isEmpty else { return }
        KeyStore.markPaired(vin: vin, peripheralId: peripheralId ?? peripheral?.identifier)
        paired = true
        readyForDashboard = true
    }

    // MARK: - Internals

    private func startScan() {
        guard let central, central.state == .poweredOn else {
            status = "Bluetooth kapali veya izin yok"
            return
        }
        step = .scanning
        central.stopScan()

        // Zaten bagli Tesla GATT (araca binince bazen zaten connected)
        let linked = central.retrieveConnectedPeripherals(withServices: [serviceUUID])
        for p in linked {
            let name = p.name ?? ""
            upsertDevice(p, name: name.isEmpty ? "Tesla (bagli)" : name, rssi: -40)
            let resume = !forceRePair && (resumeTelemetryOnly || pairWriteDone || KeyStore.isPaired(vin: vin))
            if resume {
                logLine("connected-peripheral auto \(name)")
                connect(id: p.identifier)
                return
            }
        }

        if let id = KeyStore.storedPeripheralId(vin: vin) {
            for p in central.retrievePeripherals(withIdentifiers: [id]) {
                upsertDevice(p, name: p.name ?? "Tesla", rssi: -50)
                let resume = !forceRePair && (resumeTelemetryOnly || pairWriteDone || KeyStore.isPaired(vin: vin))
                if resume {
                    logLine("stored-peripheral auto \(p.name ?? id.uuidString.prefix(8).description)")
                    connect(id: p.identifier)
                    return
                }
            }
        }

        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
        ])
        logLine("scan on")
    }

    private func tick() {
        guard step == .scanning else { return }
        if let d = deadline, Date() > d {
            central?.stopScan()
            timer?.invalidate()
            step = .failed
            status = "Sure doldu — listeden 🔑 Tesla’ya dokun veya tekrar Tara"
            logLine("timeout devices=\(devices.count)")
            return
        }
        let left = Int(deadline?.timeIntervalSinceNow ?? 0)
        status = "Tarama \(left)sn — 🔑 Tesla’ya DOKUN (\(devices.count) cihaz)"
    }

    private func beginWrite() {
        guard let payload, let peripheral, let writeChar else {
            fail("Write hazir degil")
            return
        }
        guard peripheral.state == .connected else {
            fail("Baglanti koptu")
            return
        }
        step = .writing
        status = "add-key gonderiliyor…"
        let mtu = max(20, peripheral.maximumWriteValueLength(for: .withResponse))
        logLine("MTU \(mtu)")
        chunks = []
        var i = 0
        while i < payload.count {
            let j = min(i + mtu, payload.count)
            chunks.append(payload.subdata(in: i..<j))
            i = j
        }
        writing = false
        writeNext()
    }

    private func writeNext() {
        guard let peripheral, let writeChar else { return }
        if chunks.isEmpty {
            pairWriteDone = true
            step = .waitingCard
            waitingForCard = true
            readyForDashboard = true
            status = "OK — Key Card’i KONSOLA koy · BLE telemetri basliyor"
            logLine("TX OK — kart + telemetry")
            startTelemetryIfPossible()
            return
        }
        guard !writing else { return }
        let chunk = chunks.removeFirst()
        writing = true
        logLine("TX \(chunk.count)b")
        peripheral.writeValue(chunk, for: writeChar, type: .withResponse)
    }

    /// Call when opening Cluster — keeps real telemetry alive after pair.
    func ensureTelemetry() {
        onMain {
            let ok = self.pairWriteDone || self.paired || self.readyForDashboard || KeyStore.isPaired(vin: self.vin)
            guard ok else { return }
            self.ensureTelemetryEngine()
            self.startTelemetryIfPossible(force: true)
        }
    }

    func mediaSetVolume(_ level: Double) {
        onMain { self.telemetry?.setVolume(level) }
    }

    func mediaPlayToggle() {
        onMain { self.telemetry?.mediaPlay() }
    }

    func mediaSkip(_ delta: Int) {
        onMain {
            if delta >= 0 { self.telemetry?.mediaNext() }
            else { self.telemetry?.mediaPrev() }
        }
    }

    private func ensureTelemetryEngine() {
        if telemetry == nil {
            logLine("telemetry engine create")
            telemetry = BLETelemetry()
        }
        let mode = UserDefaults.standard.string(forKey: "pulse_refresh_mode") ?? "Anlık"
        let interval: TimeInterval
        switch mode {
        case "Düşük": interval = 0.28
        case "Performans": interval = 0.045
        default: interval = 0.032 // Anlık — dash-like speed
        }
        telemetry?.applyPollInterval(interval)
        logLine("refresh \(mode) \(interval)s")
    }

    /// Call when Settings refresh mode changes.
    func applyRefreshModeFromSettings() {
        onMain { self.ensureTelemetryEngine() }
    }

    private func startTelemetryIfPossible(force: Bool = false) {
        ensureTelemetryEngine()
        guard let telemetry else { return }
        guard let peripheral, let writeChar, let key = privateKey, !vin.isEmpty else { return }
        guard peripheral.state == .connected else {
            keepAliveReconnect()
            return
        }
        let staleAttach = telemetry.attachedPeripheralId != peripheral.identifier
        let needsAttach = force
            || staleAttach
            || telemetry.phase == .idle
            || telemetry.phase == .error
            || (telemetry.phase == .live && !telemetry.liveOK)
        if !needsAttach {
            linkLabel = telemetry.liveOK ? "BLE LIVE" : "BLE telemetri…"
            return
        }
        let delay: TimeInterval = force || staleAttach ? 0.04 : 0.08
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, let tele = self.telemetry else { return }
            guard let p = self.peripheral, let wc = self.writeChar, let key = self.privateKey,
                  p.state == .connected else { return }
            self.logLine("telemetry attach")
            tele.onUpdate = { [weak self] in
                self?.syncTelemetryPublished()
            }
            tele.onNeedGATTReconnect = { [weak self] in
                guard let self else { return }
                let now = Date()
                guard now.timeIntervalSince(self.lastGATTBounceAt) > 10 else {
                    self.logLine("GATT bounce skipped (cooldown)")
                    return
                }
                self.lastGATTBounceAt = now
                self.logLine("GATT bounce (stall)")
                self.status = "Veri yok — GATT yenileniyor…"
                if let p = self.peripheral {
                    self.central?.cancelPeripheralConnection(p)
                } else {
                    self.keepAliveReconnect()
                }
            }
            tele.attach(vin: self.vin, privateKey: key, peripheral: p, writeChar: wc)
            self.linkLabel = "BLE telemetri…"
            self.syncTelemetryPublished()
        }
    }

    private func syncTelemetryPublished() {
        guard let telemetry else {
            bleLiveOK = false
            bleStatus = "BLE telemetri kapali"
            if !linkUp { linkLabel = "Baglanti yok" }
            return
        }
        bleLiveOK = telemetry.liveOK
        bleStatus = telemetry.status
        bleSnapshot = telemetry.snapshot
        bleSnapRev &+= 1
        if telemetry.liveOK {
            linkLabel = "BLE LIVE"
            persistPairSuccess()
            step = .done
            status = "Phone Key + BLE LIVE ✓"
        } else if telemetry.phase == .waitingKey {
            waitingForCard = true
            linkLabel = "Kart bekle"
            status = "Arac kart bekliyor — KONSOLA Key Card"
        } else if telemetry.phase == .handshake || telemetry.phase == .error {
            // GATT may be up, but session is NOT live — don't look "connected".
            linkLabel = linkUp ? "GATT · oturum kuruluyor" : "Baglanti yok"
            if telemetry.status.contains("tag") || telemetry.status.contains("durdu") {
                status = telemetry.status
            }
        } else if linkUp {
            linkLabel = "GATT bagli · telemetri…"
        }
    }

    private func fail(_ msg: String) {
        timer?.invalidate()
        central?.stopScan()
        linkUp = false
        linkLabel = "Baglanti yok"
        step = .failed
        status = "HATA: \(msg)"
        logLine("ERR \(msg)")
    }

    private func logLine(_ s: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        let line = "\(f.string(from: Date())) \(s)"
        log.insert(line, at: 0)
        if log.count > 120 { log = Array(log.prefix(120)) }
        let lower = s.lowercased()
        if lower.hasPrefix("err") || lower.contains("hata") || lower.contains("fail") {
            PulseDiagLog.shared.error(s)
        } else if lower.contains("disconnect") || lower.contains("koptu") || lower.contains("stall")
                    || lower.contains("bounce") || lower.contains("yenileniyor") {
            PulseDiagLog.shared.warn(s)
        } else {
            PulseDiagLog.shared.ble(s)
        }
    }

    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() }
        else { DispatchQueue.main.async(execute: block) }
    }

    private func upsertDevice(_ p: CBPeripheral, name: String, rssi: Int) {
        peripherals[p.identifier] = p
        let display = name.isEmpty ? String(p.identifier.uuidString.prefix(8)) : name
        if let idx = devices.firstIndex(where: { $0.id == p.identifier }) {
            devices[idx].name = display
            devices[idx].rssi = rssi
        } else {
            devices.append(DeviceRow(id: p.identifier, name: display, rssi: rssi))
        }
        devices.sort { a, b in
            let ascore = score(a.name) + (a.rssi + 100)
            let bscore = score(b.name) + (b.rssi + 100)
            return ascore > bscore
        }
    }

    private func score(_ name: String) -> Int {
        var s = 0
        if name.contains("🔑") { s += 1000 }
        if name.localizedCaseInsensitiveContains("tesla") { s += 500 }
        if name.range(of: #"S[0-9a-fA-F]{16}C"#, options: .regularExpression) != nil { s += 400 }
        return s
    }
}

extension BLEPairer: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logLine("BT \(central.state.rawValue)")
        if central.state == .poweredOn, step == .scanning {
            startScan()
        } else if central.state == .poweredOn, step == .connecting, resumeTelemetryOnly, let p = peripheral {
            central.connect(p, options: Self.connectOptions)
        } else if central.state == .unauthorized {
            fail("Bluetooth izni yok (Capabilities)")
        } else if central.state == .poweredOff, step == .scanning {
            fail("Bluetooth kapali")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? ""
        upsertDevice(peripheral, name: name, rssi: RSSI.intValue)

        guard step == .scanning else { return }
        let names = VCSECPayload.bleNames(vin: vin)
        let hot = name.contains("🔑")
            || name.localizedCaseInsensitiveContains("tesla")
            || names.contains(where: { name.localizedCaseInsensitiveContains($0) })
            || name.range(of: #"S[0-9a-fA-F]{16}C"#, options: .regularExpression) != nil
        let resume = !forceRePair && (resumeTelemetryOnly || pairWriteDone || KeyStore.isPaired(vin: vin))
        // Resume: daha agresif otomatik bağlan; ilk pair: yakın ve Tesla adı
        let rssiOK = resume ? RSSI.intValue > -98 : RSSI.intValue > -60
        if hot, rssiOK {
            logLine("auto-tap \(name) rssi=\(RSSI.intValue) resume=\(resume)")
            connect(id: peripheral.identifier)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        linkUp = true
        // GATT only — not yet authenticated session / LIVE.
        linkLabel = "GATT bagli · oturum…"
        reconnectAttempts = 0
        logLine("GATT OK")
        let skipAddKey = !forceRePair && (resumeTelemetryOnly || pairWriteDone || paired || KeyStore.isPaired(vin: vin))
        if skipAddKey {
            KeyStore.markPaired(vin: vin, peripheralId: peripheral.identifier)
            resumeTelemetryOnly = true
            pairWriteDone = true
            readyForDashboard = true
            status = "GATT bagli — BLE oturum handshake…"
            peripheral.discoverServices(nil)
            return
        }
        if step == .connecting || step == .services || step == .writing || step == .scanning {
            resumeTelemetryOnly = false
            step = .services
            status = "GATT bagli — servisler…"
            peripheral.discoverServices(nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        linkUp = false
        linkLabel = "Baglanti yok"
        if resumeTelemetryOnly || pairWriteDone || KeyStore.isPaired(vin: vin) {
            keepAliveReconnect()
            return
        }
        fail("Connect fail: \(error?.localizedDescription ?? "?")")
        step = .scanning
        startScan()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        linkUp = false
        bleLiveOK = false
        linkLabel = "Baglanti koptu"
        logLine("disconnect \(error?.localizedDescription ?? "")")
        // Tear telemetry so reconnect always re-attaches (was stuck in .live without attach).
        telemetry?.detach()
        syncTelemetryPublished()
        if resumeTelemetryOnly || pairWriteDone || paired || KeyStore.isPaired(vin: vin) {
            status = "BLE koptu — yeniden baglaniliyor…"
            readyForDashboard = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.keepAliveReconnect()
            }
            return
        }
        if step == .writing || step == .services || step == .connecting {
            fail("Baglanti koptu — listeden tekrar dokun")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            fail(error.localizedDescription)
            return
        }
        let services = peripheral.services ?? []
        logLine("services \(services.count)")
        guard let svc = services.first(where: { $0.uuid == serviceUUID }) else {
            logLine("Tesla servisi YOK — baska cihaz, tarama")
            step = .scanning
            startScan()
            return
        }
        peripheral.discoverCharacteristics(nil, for: svc)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            fail(error.localizedDescription)
            return
        }
        writeChar = service.characteristics?.first { $0.uuid == writeUUID }
        if let read = service.characteristics?.first(where: { $0.uuid == readUUID }) {
            peripheral.setNotifyValue(true, for: read)
        }
        guard writeChar != nil else {
            fail("Write karakteristigi yok")
            return
        }
        logLine("chars OK")
        if resumeTelemetryOnly || pairWriteDone || (!forceRePair && KeyStore.isPaired(vin: vin)) {
            // Always force attach after (re)discovery — reconnect used to skip attach.
            startTelemetryIfPossible(force: true)
            if step != .done { step = .waitingCard }
            readyForDashboard = true
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.beginWrite()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if pairWriteDone || resumeTelemetryOnly {
            telemetry?.didWrite(error: error)
            return
        }
        writing = false
        if let error {
            fail("Write: \(error.localizedDescription)")
            return
        }
        logLine("ACK")
        writeNext()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        let teleActive = telemetry.map { $0.phase != .idle } ?? false
        if pairWriteDone || resumeTelemetryOnly || teleActive {
            // Throttled UI updates happen inside telemetry.onUpdate — don't double-publish here.
            telemetry?.onNotify(data)
        } else {
            // Pairing path only: sparse RX logs.
            let hex = data.map { String(format: "%02x", $0) }.joined()
            logLine("RX \(hex.prefix(40))")
            if hex.contains("0801") || hex.contains("2202") {
                waitingForCard = true
                readyForDashboard = true
                if step != .done { step = .waitingCard }
                status = "Arac kart bekliyor — KONSOLA Key Card"
            }
            if hex.contains("1a08") || hex.contains("5f0d") {
                persistPairSuccess(peripheralId: peripheral.identifier)
                step = .done
                status = "Phone Key eklendi ✓ — Dashboard / BLE LIVE"
            }
        }
    }
}
