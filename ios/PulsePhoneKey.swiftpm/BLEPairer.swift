import Foundation
import CoreBluetooth

/// Tesla VCSEC BLE pairer — aggressive scan for Playgrounds / iPad.
final class BLEPairer: NSObject, ObservableObject {
    static let buildId = "build-7-emoji"

    @Published var status: String = "Hazir"
    @Published var log: [String] = []
    @Published var busy = false
    @Published var waitingForCard = false
    @Published var paired = false
    @Published var lastDetail: String = "\(BLEPairer.buildId) — eslemeden once kapıyı aç."
    @Published var nearby: [String] = []

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

    private enum Phase {
        case idle, scanning, connecting, discovering, writing, waitingCard
    }

    func appendLog(_ line: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        let stamped = "\(f.string(from: Date())) \(line)"
        // Already on main from CB queue; keep UI updates immediate
        if Thread.isMainThread {
            log.insert(stamped, at: 0)
            if log.count > 100 { log = Array(log.prefix(100)) }
        } else {
            DispatchQueue.main.async {
                self.log.insert(stamped, at: 0)
                if self.log.count > 100 { self.log = Array(self.log.prefix(100)) }
            }
        }
    }

    func pair(vin: String, publicKey: Data) {
        let work = { self.startPair(vin: vin, publicKey: publicKey) }
        if Thread.isMainThread { work() }
        else { DispatchQueue.main.async(execute: work) }
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
        peripheralCache.removeAll()

        targetNames = Set(VCSECPayload.bleNames(vin: vin))
        payload = VCSECPayload.addKeyRequest(publicKeyUncompressed: publicKey)
        appendLog("\(Self.buildId)")
        appendLog("VIN \(vin)")
        appendLog("Hedef \(targetNames.sorted().joined(separator: ", "))")
        appendLog("Payload \(payload?.count ?? 0) byte")

        status = "[\(Self.buildId)] SIMDI kapıyı aç — tarama"
        lastDetail = "🔑 Tesla … görünürse hemen bağlanır (emoji OK)"

        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main, options: [
                CBCentralManagerOptionShowPowerAlertKey: true,
            ])
            appendLog("Central oluşturuldu")
        } else {
            beginScanning()
        }
    }

    private func beginScanning() {
        guard let central else { return }
        guard central.state == .poweredOn else {
            status = "Bluetooth kapalı veya izin yok"
            lastDetail = "Ayarlar → Playgrounds → Bluetooth açık"
            busy = false
            phase = .idle
            appendLog("BT not powered: \(central.state.rawValue)")
            return
        }

        let connected = central.retrieveConnectedPeripherals(withServices: [teslaService])
        if let p = connected.first {
            appendLog("Zaten bağlı peripheral")
            connect(to: p, why: "retrieveConnected")
            return
        }

        phase = .scanning
        connecting = false
        scanDeadline = Date().addingTimeInterval(60)
        status = "[\(Self.buildId)] Tesla aranıyor… KAPİYİ AÇ"
        restartScanBurst()

        cleanupTimers()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.scanTick()
        }
    }

    private func restartScanBurst() {
        guard let central, phase == .scanning else { return }
        central.stopScan()
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
        ])
        appendLog("Tarama burst (filtresiz)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.phase == .scanning, let central = self.central else { return }
            central.stopScan()
            central.scanForPeripherals(withServices: [self.teslaService], options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: true,
            ])
            self.appendLog("Tarama burst (servis)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, self.phase == .scanning, let central = self.central else { return }
                central.stopScan()
                central.scanForPeripherals(withServices: nil, options: [
                    CBCentralManagerScanOptionAllowDuplicatesKey: true,
                ])
            }
        }
    }

    private func scanTick() {
        guard phase == .scanning else { return }

        // Rescue: connect to any cached peripheral whose name looks like Tesla
        for (id, p) in peripheralCache {
            let n = p.name ?? nearbyMap[id] ?? ""
            if Self.nameLooksLikeTesla(n) {
                appendLog("Tick kurtarma: \(n)")
                connect(to: p, why: "tick:\(n)")
                return
            }
        }

        if let deadline = scanDeadline, Date() > deadline {
            central?.stopScan()
            cleanupTimers()
            let near = nearby.prefix(8).joined(separator: " | ")
            let sawTesla = nearby.contains { Self.nameLooksLikeTesla($0) }
            status = "HATA: Araç bulunamadı"
            if sawTesla {
                lastDetail = "⚠️ 🔑 Tesla görüldü ama bağlanılmadı. ESKİ sürüm olabilir — projeyi sil, build-7 zip’i yeniden aç. Görülen: \(near)"
            } else if near.isEmpty {
                lastDetail = "Hiç BLE yok. Bluetooth izni / iPad BT kontrol et."
            } else {
                lastDetail = "Görülenler: \(near)"
            }
            busy = false
            phase = .idle
            appendLog("Timeout. nearby=\(nearby.count) sawTesla=\(sawTesla)")
            return
        }
        let left = Int(scanDeadline?.timeIntervalSinceNow ?? 0)
        status = "[\(Self.buildId)] Aranıyor… \(left)sn — KAPİYİ AÇ"
        restartScanBurst()
    }

    private func cleanupTimers() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    /// "🔑 Tesla 🍃", "Tesla 159959", "Sc23…C", etc.
    static func nameLooksLikeTesla(_ raw: String) -> Bool {
        let n = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty { return false }
        let upper = n.uppercased()
        if upper.contains("TESLA") { return true }
        // letters only
        let letters = String(upper.unicodeScalars.filter { CharacterSet.letters.contains($0) })
        if letters.contains("TESLA") { return true }
        let compact = String(upper.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
        if compact.range(of: #"S[0-9A-F]{16}C"#, options: .regularExpression) != nil { return true }
        return false
    }

    private func isTesla(name: String, adv: [String: Any]) -> (Bool, String) {
        if Self.nameLooksLikeTesla(name) {
            return (true, "name:\(name)")
        }
        for t in targetNames {
            if name.localizedCaseInsensitiveContains(t) { return (true, "hedef:\(name)") }
        }
        for key in [CBAdvertisementDataServiceUUIDsKey, CBAdvertisementDataOverflowServiceUUIDsKey] {
            if let uuids = adv[key] as? [CBUUID], uuids.contains(where: { $0 == teslaService }) {
                return (true, "svc")
            }
        }
        return (false, "")
    }

    private func connect(to peripheral: CBPeripheral, why: String) {
        guard phase == .scanning || phase == .idle else { return }
        guard !connecting else { return }
        guard let central else { return }
        connecting = true
        phase = .connecting
        cleanupTimers()
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        let label = peripheral.name ?? why
        status = "Bağlanıyor: \(label)…"
        appendLog("EŞLEŞTİ [\(why)]")
        lastDetail = "Bağlanıyor — Ayarlar listesinden kaybolması normal"
        central.connect(peripheral, options: nil)
    }

    private func beginWrite() {
        guard let payload, let peripheral, let writeChar else {
            fail("Write hazır değil")
            return
        }
        guard peripheral.state == .connected else {
            fail("Bağlantı yok")
            return
        }
        phase = .writing
        status = "add-key gönderiliyor…"
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
            status = "OK: İstek gitti — Key Card KONSOLA → Pair"
            lastDetail = "Kartı iPad'e değil konsola koy."
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
            if busy, phase == .scanning || phase == .idle {
                beginScanning()
            }
        case .unauthorized:
            fail("Bluetooth izni yok")
        case .poweredOff:
            if busy { fail("Bluetooth kapalı") }
        default:
            break
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
        let id = peripheral.identifier
        peripheralCache[id] = peripheral

        let label = name.isEmpty ? String(id.uuidString.prefix(8)) : name
        let line = "\(label) \(RSSI)dBm"
        nearbyMap[id] = line
        nearby = nearbyMap.values.sorted()

        if !seenIds.contains(id) {
            seenIds.insert(id)
            appendLog("görüldü: \(line)")
        }

        guard phase == .scanning, !connecting else { return }

        // Fast path: any "Tesla" in the name (emoji OK)
        if Self.nameLooksLikeTesla(name) {
            connect(to: peripheral, why: "FAST:\(name)")
            return
        }

        let (match, why) = isTesla(name: name, adv: advertisementData)
        if match {
            connect(to: peripheral, why: why)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        phase = .discovering
        status = "Servisler…"
        appendLog("GATT bağlı")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        fail("Bağlantı fail: \(error?.localizedDescription ?? "?")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        appendLog("GATT koptu \(error?.localizedDescription ?? "")")
        if phase == .waitingCard {
            status = "Kopuk — yine de kartı konsola dene"
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
        appendLog("Servis sayısı \(services.count)")
        for s in services {
            appendLog(" svc \(s.uuid.uuidString)")
        }
        guard let service = services.first(where: { $0.uuid == teslaService }) else {
            appendLog("Tesla GATT servisi yok — tarama devam")
            connecting = false
            phase = .scanning
            busy = true
            scanDeadline = Date().addingTimeInterval(45)
            // Don't keep wrong peripheral
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
        appendLog("Write hazır")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
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
            status = "Araç kart bekliyor — konsola Key Card"
        }
        if hex.contains("1a08") || hex.contains("5f0d") {
            paired = true
            status = "Onaylandı — Phone Key eklendi"
        }
    }
}
