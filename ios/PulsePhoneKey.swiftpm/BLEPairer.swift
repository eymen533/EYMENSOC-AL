import Foundation
import CoreBluetooth

/// Tesla VCSEC BLE pairer — connect by 🔑 / any Tesla-like name / manual tap.
final class BLEPairer: NSObject, ObservableObject {
    static let buildId = "build-9-hud"

    @Published var status: String = "Hazir"
    @Published var log: [String] = []
    @Published var busy = false
    @Published var waitingForCard = false
    @Published var paired = false
    @Published var lastDetail: String = "\(BLEPairer.buildId)"
    @Published var nearby: [String] = []
    /// Tappable rows: id.uuidString → label
    @Published var candidates: [(id: UUID, label: String)] = []

    private let teslaService = CBUUID(string: VCSECPayload.serviceUUID)
    private let teslaWrite = CBUUID(string: VCSECPayload.writeUUID)
    private let teslaRead = CBUUID(string: VCSECPayload.readUUID)

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var payload: Data?
    private var targetNames: Set<String> = []
    private var writeQueue: [Data] = []
    private var writing = false
    private var connecting = false
    private var phase: Phase = .idle
    private var scanDeadline: Date?
    private var tickTimer: Timer?
    private var seenIds = Set<UUID>()
    private var nearbyMap: [UUID: String] = [:]
    private var peripheralCache: [UUID: CBPeripheral] = [:]
    private var nameCache: [UUID: String] = [:]

    private enum Phase {
        case idle, scanning, connecting, discovering, writing, waitingCard
    }

    func appendLog(_ line: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        let stamped = "\(f.string(from: Date())) \(line)"
        let apply = {
            self.log.insert(stamped, at: 0)
            if self.log.count > 120 { self.log = Array(self.log.prefix(120)) }
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    func pair(vin: String, publicKey: Data) {
        let work = { self.startPair(vin: vin, publicKey: publicKey) }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    /// Manual: user taps a row (e.g. 🔑 Tesla …)
    func connectCandidate(id: UUID) {
        guard let p = peripheralCache[id] else {
            appendLog("Aday yok \(id)")
            return
        }
        if payload == nil {
            status = "Once Eslestir'e bas (payload yok)"
            return
        }
        busy = true
        connecting = false
        // Allow tap after timeout / during scan
        if phase == .idle || phase == .scanning {
            phase = .scanning
        }
        connect(to: p, why: "MANUAL:\(nameCache[id] ?? id.uuidString)")
    }

    private func startPair(vin: String, publicKey: Data) {
        cleanupTimers()
        connecting = false
        writing = false
        writeQueue = []
        writeChar = nil
        waitingForCard = false
        paired = false
        busy = true
        phase = .scanning
        seenIds.removeAll()
        nearbyMap.removeAll()
        nearby = []
        candidates = []
        // keep peripheralCache across? clear for fresh scan
        peripheralCache.removeAll()
        nameCache.removeAll()

        targetNames = Set(VCSECPayload.bleNames(vin: vin))
        payload = VCSECPayload.addKeyRequest(publicKeyUncompressed: publicKey)
        appendLog(Self.buildId)
        appendLog("VIN \(vin)")
        appendLog("Hedef \(targetNames.sorted().joined(separator: ", "))")
        appendLog("Payload \(payload?.count ?? 0) byte")

        status = "[\(Self.buildId)] Tarama — 🔑 gorunce baglanir / listeden dokun"
        lastDetail = "Otomatik yetmezse asagidaki 🔑 satirina DOKUN"

        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main, options: [
                CBCentralManagerOptionShowPowerAlertKey: true,
            ])
            appendLog("Central olusturuldu")
        } else {
            beginScanning()
        }
    }

    private func beginScanning() {
        guard let central else { return }
        guard central.state == .poweredOn else {
            status = "Bluetooth kapali / izin yok"
            busy = false
            phase = .idle
            return
        }

        let connected = central.retrieveConnectedPeripherals(withServices: [teslaService])
        if let p = connected.first {
            connect(to: p, why: "retrieveConnected")
            return
        }

        phase = .scanning
        connecting = false
        scanDeadline = Date().addingTimeInterval(75)
        // Stay on unfiltered scan — don't bounce stop/start so hard
        central.stopScan()
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
        ])
        appendLog("Tarama acik (filtresiz, surekli)")

        cleanupTimers()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            self?.scanTick()
        }
    }

    private func scanTick() {
        guard phase == .scanning else { return }

        // Auto-rescue from cache
        for (id, p) in peripheralCache {
            let n = nameCache[id] ?? p.name ?? ""
            if Self.shouldConnect(name: n) {
                appendLog("Tick auto: \(n)")
                connect(to: p, why: "tick:\(n)")
                return
            }
        }

        if let deadline = scanDeadline, Date() > deadline {
            central?.stopScan()
            cleanupTimers()
            let keys = candidates.map(\.label).joined(separator: " | ")
            status = "HATA: Otomatik baglanamadi"
            lastDetail = keys.isEmpty
                ? "Aday yok. Kapıyı acip tekrar dene."
                : "Asagidan 🔑 satirina DOKUN: \(keys)"
            busy = false
            phase = .idle
            appendLog("Timeout. candidates=\(candidates.count)")
            return
        }
        let left = Int(scanDeadline?.timeIntervalSinceNow ?? 0)
        status = "[\(Self.buildId)] Araniyor \(left)sn — 🔑 gorursen listeden dokun"
        // Soft resync scan without killing too often
        if left % 12 < 4, let central {
            central.stopScan()
            central.scanForPeripherals(withServices: nil, options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: true,
            ])
        }
    }

    private func cleanupTimers() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    /// Nuclear matching — emoji key OR any tesla-like letters OR S…C
    static func shouldConnect(name: String) -> Bool {
        let n = name
        if n.isEmpty { return false }
        // Phone-key style advertisement from Tesla / Tesla app
        if n.contains("🔑") { return true }
        if n.contains("\u{1F511}") { return true }

        let folded = n.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        if folded.contains("tesla") { return true }

        // Letters only (unicode), then fold
        let letterOnly = String(n.unicodeScalars.filter { CharacterSet.letters.contains($0) })
        let foldedLetters = letterOnly.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        if foldedLetters.contains("tesla") { return true }

        // Raw lowercased ASCII extract
        let ascii = String(n.unicodeScalars.filter { (48...57).contains(Int($0.value)) || (65...90).contains(Int($0.value)) || (97...122).contains(Int($0.value)) })
        if ascii.lowercased().contains("tesla") { return true }

        let compact = String(n.uppercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
        if compact.range(of: #"S[0-9A-F]{16}C"#, options: .regularExpression) != nil { return true }

        return false
    }

    private func publishCandidates() {
        candidates = nameCache.compactMap { id, name in
            guard Self.shouldConnect(name: name) || name.contains("🔑") else { return nil }
            let rssi = nearbyMap[id] ?? name
            return (id, rssi)
        }
        .sorted { $0.label < $1.label }
    }

    private func connect(to peripheral: CBPeripheral, why: String) {
        guard phase == .scanning || phase == .idle else {
            appendLog("connect skip phase=\(phase)")
            return
        }
        guard !connecting else { return }
        guard let central else { return }
        connecting = true
        phase = .connecting
        cleanupTimers()
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        let label = peripheral.name ?? nameCache[peripheral.identifier] ?? why
        status = "Baglaniyor: \(label)…"
        appendLog("ESLESTI [\(why)]")
        lastDetail = "Baglaniyor…"
        central.connect(peripheral, options: nil)
    }

    private func beginWrite() {
        guard let payload, let peripheral, let writeChar else {
            fail("Write hazir degil")
            return
        }
        guard peripheral.state == .connected else {
            fail("Baglanti yok")
            return
        }
        phase = .writing
        status = "add-key gonderiliyor…"
        let mtu = max(20, peripheral.maximumWriteValueLength(for: .withResponse))
        appendLog("MTU \(mtu)")
        writeQueue = []
        var offset = 0
        while offset < payload.count {
            let end = min(offset + mtu, payload.count)
            writeQueue.append(payload.subdata(in: offset..<end))
            offset = end
        }
        writing = false
        sendNextChunk()
    }

    private func sendNextChunk() {
        guard !writing else { return }
        guard let peripheral, let writeChar else { return }
        if writeQueue.isEmpty {
            phase = .waitingCard
            waitingForCard = true
            busy = false
            cleanupTimers()
            status = "OK: Istek gitti — Key Card KONSOLA → Pair"
            lastDetail = "Karti konsola koy"
            appendLog("TX tamam")
            return
        }
        let chunk = writeQueue.removeFirst()
        writing = true
        appendLog("TX \(chunk.count)b")
        peripheral.writeValue(chunk, for: writeChar, type: .withResponse)
    }

    private func fail(_ message: String) {
        cleanupTimers()
        central?.stopScan()
        status = "HATA: \(message)"
        busy = false
        phase = .idle
        connecting = false
        appendLog("HATA \(message)")
    }
}

extension BLEPairer: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        appendLog("BT state \(central.state.rawValue)")
        switch central.state {
        case .poweredOn:
            if busy, phase == .scanning || phase == .idle { beginScanning() }
        case .unauthorized: fail("Bluetooth izni yok")
        case .poweredOff: if busy { fail("Bluetooth kapali") }
        default: break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = [peripheral.name, advName].compactMap { $0 }.first { !$0.isEmpty } ?? ""
        let id = peripheral.identifier

        peripheralCache[id] = peripheral
        if !name.isEmpty {
            nameCache[id] = name
        }

        let label = nameCache[id] ?? (name.isEmpty ? String(id.uuidString.prefix(8)) : name)
        let line = "\(label) \(RSSI)dBm"
        nearbyMap[id] = line
        nearby = nearbyMap.values.sorted()
        publishCandidates()

        if !seenIds.contains(id) {
            seenIds.insert(id)
            appendLog("goruldu: \(line)")
        } else if Self.shouldConnect(name: label), phase == .scanning, !connecting {
            // Name may appear on a later advertisement — connect then
            appendLog("isim guncellendi: \(label)")
        }

        // Service UUID in adv → always connect
        var hasSvc = false
        for key in [CBAdvertisementDataServiceUUIDsKey, CBAdvertisementDataOverflowServiceUUIDsKey] {
            if let uuids = advertisementData[key] as? [CBUUID], uuids.contains(where: { $0 == teslaService }) {
                hasSvc = true
            }
        }

        guard phase == .scanning, !connecting else { return }

        let checkName = nameCache[id] ?? name
        if hasSvc {
            connect(to: peripheral, why: "SVC:\(checkName)")
            return
        }
        if Self.shouldConnect(name: checkName) {
            connect(to: peripheral, why: "AUTO:\(checkName)")
            return
        }
        // Also match target VIN names as substring of checkName
        for t in targetNames where checkName.localizedCaseInsensitiveContains(t) {
            connect(to: peripheral, why: "VIN:\(checkName)")
            return
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        phase = .discovering
        status = "Servisler…"
        appendLog("GATT bagli")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connecting = false
        fail("Baglanti fail: \(error?.localizedDescription ?? "?")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        appendLog("GATT koptu \(error?.localizedDescription ?? "")")
        if phase == .waitingCard {
            status = "Kopuk — yine de karti konsola dene"
            return
        }
        if busy, phase != .idle, phase != .waitingCard {
            fail("GATT koptu")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            fail("Servis: \(error.localizedDescription)")
            return
        }
        let services = peripheral.services ?? []
        appendLog("Servis sayisi \(services.count)")
        for s in services { appendLog(" svc \(s.uuid.uuidString)") }

        guard let service = services.first(where: { $0.uuid == teslaService }) else {
            appendLog("Tesla GATT yok — yanlis cihaz, tarama devam")
            connecting = false
            phase = .scanning
            busy = true
            scanDeadline = Date().addingTimeInterval(50)
            beginScanning()
            return
        }
        appendLog("Servis OK")
        peripheral.discoverCharacteristics(nil, for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            fail("Karakteristik: \(error.localizedDescription)")
            return
        }
        writeChar = service.characteristics?.first { $0.uuid == teslaWrite }
        if let read = service.characteristics?.first(where: { $0.uuid == teslaRead }) {
            peripheral.setNotifyValue(true, for: read)
        }
        guard writeChar != nil else {
            fail("Write karakteristik yok")
            return
        }
        appendLog("Write hazir")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.beginWrite()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        writing = false
        if let error {
            fail("Write: \(error.localizedDescription)")
            return
        }
        appendLog("Write ACK")
        sendNextChunk()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        let hex = data.map { String(format: "%02x", $0) }.joined()
        appendLog("RX \(hex.prefix(48))")
        if hex.contains("0801") || hex.contains("2202") {
            waitingForCard = true
            status = "Arac kart bekliyor — konsola Key Card"
        }
        if hex.contains("1a08") || hex.contains("5f0d") {
            paired = true
            status = "Onaylandi — Phone Key eklendi"
        }
    }
}
