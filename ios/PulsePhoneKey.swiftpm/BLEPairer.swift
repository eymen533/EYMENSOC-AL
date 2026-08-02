import Foundation
import CoreBluetooth

/// Simple, reliable Tesla VCSEC pairer for Swift Playgrounds.
final class BLEPairer: NSObject, ObservableObject {
    static let buildId = "build-41-dash"

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
    /// Live GATT link to the vehicle (true while peripheral connected).
    @Published var linkUp = false
    @Published var linkLabel = "BLE kapali"

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

    // MARK: - Public

    var isLinked: Bool { linkUp || paired || readyForDashboard }

    func keepAliveReconnect() {
        onMain {
            guard let p = self.peripheral else { return }
            guard p.state != .connected else {
                self.linkUp = true
                self.linkLabel = "BLE bagli"
                return
            }
            guard self.reconnectAttempts < 5 else { return }
            self.reconnectAttempts += 1
            self.logLine("reconnect #\(self.reconnectAttempts)")
            self.linkLabel = "Yeniden baglan…"
            self.central?.connect(p, options: nil)
        }
    }

    func start(vin: String, publicKey: Data) {
        onMain {
            self.payload = VCSECPayload.addKeyRequest(publicKeyUncompressed: publicKey)
            self.waitingForCard = false
            self.paired = false
            self.readyForDashboard = false
            self.linkUp = false
            self.linkLabel = "Baglanti yok"
            self.reconnectAttempts = 0
            self.devices = []
            self.peripherals = [:]
            self.chunks = []
            self.writing = false
            self.peripheral = nil
            self.writeChar = nil
            self.logLine("\(Self.buildId) VIN \(vin)")
            self.logLine("hedef \(VCSECPayload.bleNames(vin: vin).joined(separator: ", "))")
            self.logLine("payload \(self.payload?.count ?? 0)b")
            self.step = .scanning
            self.status = "Tarama acik — asagidan 🔑 Tesla satirina DOKUN"
            self.deadline = Date().addingTimeInterval(90)
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
    }

    /// User tapped a device in the list — this is the main connect path.
    func connect(id: UUID) {
        onMain {
            guard let p = self.peripherals[id] else {
                self.fail("Cihaz kayboldu — tekrar tara")
                return
            }
            guard self.payload != nil else {
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
            self.central?.connect(p, options: nil)
        }
    }

    // MARK: - Internals

    private func startScan() {
        guard let central, central.state == .poweredOn else {
            status = "Bluetooth kapali veya izin yok"
            return
        }
        step = .scanning
        central.stopScan()
        // Always unfiltered — show everything, user taps Tesla
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
            step = .waitingCard
            waitingForCard = true
            readyForDashboard = true
            status = "OK — Key Card’i KONSOLA koy, sonra Dashboard ac"
            logLine("TX OK — kart konsola")
            return
        }
        guard !writing else { return }
        let chunk = chunks.removeFirst()
        writing = true
        logLine("TX \(chunk.count)b")
        peripheral.writeValue(chunk, for: writeChar, type: .withResponse)
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
        if log.count > 80 { log = Array(log.prefix(80)) }
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
        // Strong + Tesla-like first
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

        // Auto-connect only for very obvious Tesla ads (optional assist)
        guard step == .scanning else { return }
        let hot = name.contains("🔑") || name.localizedCaseInsensitiveContains("tesla")
        if hot, RSSI.intValue > -60 {
            logLine("auto-tap \(name)")
            connect(id: peripheral.identifier)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        linkUp = true
        linkLabel = "BLE bagli · \(peripheral.name ?? "Tesla")"
        reconnectAttempts = 0
        logLine("GATT OK")
        // Fresh pair path: discover + write. Reconnect after card/done: keep session.
        if step == .connecting || step == .services || step == .writing || step == .scanning {
            step = .services
            status = "GATT bagli — servisler…"
            peripheral.discoverServices(nil)
        } else {
            status = "BLE yeniden baglandi"
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        linkUp = false
        linkLabel = "Baglanti yok"
        if step == .waitingCard || step == .done {
            keepAliveReconnect()
            return
        }
        fail("Connect fail: \(error?.localizedDescription ?? "?")")
        step = .scanning
        startScan()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        linkUp = false
        linkLabel = "Baglanti koptu"
        logLine("disconnect \(error?.localizedDescription ?? "")")
        if step == .waitingCard || step == .done {
            status = "BLE koptu — yeniden baglaniliyor…"
            readyForDashboard = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.beginWrite()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
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
        let hex = data.map { String(format: "%02x", $0) }.joined()
        logLine("RX \(hex.prefix(40))")
        if hex.contains("0801") || hex.contains("2202") {
            waitingForCard = true
            readyForDashboard = true
            step = .waitingCard
            status = "Arac kart bekliyor — KONSOLA Key Card"
        }
        if hex.contains("1a08") || hex.contains("5f0d") {
            paired = true
            readyForDashboard = true
            step = .done
            status = "Phone Key eklendi ✓ — Dashboard ac"
        }
    }
}
