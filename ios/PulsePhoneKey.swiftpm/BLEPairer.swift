import Foundation
import CoreBluetooth

/// Tesla VCSEC BLE pairer — aggressive scan for Playgrounds / iPad.
final class BLEPairer: NSObject, ObservableObject {
    @Published var status: String = "Hazir"
    @Published var log: [String] = []
    @Published var busy = false
    @Published var waitingForCard = false
    @Published var paired = false
    @Published var lastDetail: String = "Eslemeden hemen once kapıyı aç / ekranı uyandır."
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

    private enum Phase {
        case idle, scanning, connecting, discovering, writing, waitingCard
    }

    func appendLog(_ line: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        let stamped = "\(f.string(from: Date())) \(line)"
        DispatchQueue.main.async {
            self.log.insert(stamped, at: 0)
            if self.log.count > 100 { self.log = Array(self.log.prefix(100)) }
        }
    }

    func pair(vin: String, publicKey: Data) {
        DispatchQueue.main.async {
            self.startPair(vin: vin, publicKey: publicKey)
        }
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

        targetNames = Set(VCSECPayload.bleNames(vin: vin))
        payload = VCSECPayload.addKeyRequest(publicKeyUncompressed: publicKey)
        appendLog("VIN \(vin)")
        appendLog("Hedef \(targetNames.sorted().joined(separator: ", "))")
        appendLog("Payload \(payload?.count ?? 0) byte")

        status = "SIMDI kapıyı aç / ekranı uyandır — tarama başlıyor"
        lastDetail = "Tarama 60 sn. Tesla uygulamasını tamamen kapat. iPad konsola yakın."

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
            lastDetail = "Ayarlar → Playgrounds → Bluetooth açık olsun"
            busy = false
            phase = .idle
            appendLog("BT not powered: \(central.state.rawValue)")
            return
        }

        // Already connected to Tesla service in this app?
        let connected = central.retrieveConnectedPeripherals(withServices: [teslaService])
        if let p = connected.first {
            appendLog("Zaten bağlı peripheral var — bağlanıyor")
            connecting = true
            phase = .connecting
            peripheral = p
            p.delegate = self
            if p.state == .connected {
                phase = .discovering
                status = "Servisler…"
                p.discoverServices(nil)
            } else {
                central.connect(p, options: nil)
            }
            return
        }

        phase = .scanning
        connecting = false
        scanDeadline = Date().addingTimeInterval(60)
        status = "Tesla aranıyor… KAPİYİ AÇ / EKRANI UYANDIR"
        restartScanBurst()

        cleanupTimers()
        // Every 5s: refresh status + restart scan (cars appear briefly when waking)
        tickTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.scanTick()
        }
    }

    private func restartScanBurst() {
        guard let central, phase == .scanning else { return }
        central.stopScan()
        // Unfiltered first — many Teslas omit service UUID in adv
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
        ])
        appendLog("Tarama burst (filtresiz)")
        // Also service-filtered pass after 1s (some stacks need it)
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
        if let deadline = scanDeadline, Date() > deadline {
            central?.stopScan()
            cleanupTimers()
            let near = nearby.prefix(8).joined(separator: " | ")
            status = "HATA: Araç bulunamadı"
            lastDetail = near.isEmpty
                ? "Hiç BLE cihazı görülmedi. Playgrounds Bluetooth izni / iPad BT kontrol et. Arabayı uyandırıp tekrar."
                : "Görülenler: \(near). Hedef \(targetNames.first ?? "S…C") yoksa araç uykuda veya yanlış VIN."
            busy = false
            phase = .idle
            appendLog("Timeout. nearby=\(nearby.count)")
            return
        }
        let left = Int(scanDeadline?.timeIntervalSinceNow ?? 0)
        status = "Aranıyor… \(left)sn — KAPİYİ AÇ / FREN / EKRAN"
        restartScanBurst()
    }

    private func cleanupTimers() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func isTesla(name: String, adv: [String: Any]) -> (Bool, String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = n.uppercased()
        // Strip emoji / symbols — car often advertises as "🔑 Tesla 🍃"
        let alnum = String(upper.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == " "
        })
        let compact = alnum.replacingOccurrences(of: " ", with: "")

        for t in targetNames {
            let tu = t.uppercased()
            if n == t || upper == tu || alnum.contains(tu) || compact.contains(tu.replacingOccurrences(of: " ", with: "")) {
                return (true, "hedef:\(n)")
            }
        }
        // Official / phone-key style names: "🔑 Tesla 🍃", "Tesla 159959", etc.
        if upper.contains("TESLA") || alnum.contains("TESLA") {
            return (true, "Tesla-emoji:\(n)")
        }
        // S + 16 hex + C anywhere in the cleaned string
        if let sc = compact.range(of: #"S[0-9A-F]{16}C"#, options: .regularExpression) {
            return (true, "S…C:\(compact[sc])")
        }
        if upper.count == 18, upper.hasPrefix("S"), upper.hasSuffix("C") {
            let mid = upper.dropFirst().dropLast()
            if mid.count == 16, mid.allSatisfy(\.isHexDigit) {
                return (true, "S…C:\(n)")
            }
        }
        for key in [CBAdvertisementDataServiceUUIDsKey, CBAdvertisementDataOverflowServiceUUIDsKey] {
            if let uuids = adv[key] as? [CBUUID], uuids.contains(where: { $0 == teslaService }) {
                return (true, "svc\(n.isEmpty ? "" : ":"+n)")
            }
        }
        return (false, "")
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
            lastDetail = "Kartı iPad'e değil konsola koy. Uygulamada kal."
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
        let label = name.isEmpty ? String(id.uuidString.prefix(8)) : name
        let line = "\(label) \(RSSI)dBm"

        // Always track nearby (so timeout tells us if scan works)
        if nearbyMap[id] == nil || (RSSI.intValue > -70) {
            nearbyMap[id] = line
            nearby = nearbyMap.values.sorted()
        }
        if !seenIds.contains(id) {
            seenIds.insert(id)
            appendLog("görüldü: \(line)")
        }

        guard phase == .scanning, !connecting else { return }
        let (match, why) = isTesla(name: name, adv: advertisementData)
        guard match else { return }

        connecting = true
        phase = .connecting
        cleanupTimers()
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        status = "Bağlanıyor: \(name.isEmpty ? "Tesla BLE" : name)…"
        appendLog("EŞLEŞTİ [\(why)] \(RSSI) dBm")
        lastDetail = "Ayarlar'dan kaybolması normal"
        central.connect(peripheral, options: nil)
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
        guard let service = services.first(where: { $0.uuid == teslaService }) else {
            // Not the Tesla — resume scanning if possible
            appendLog("Tesla servisi yok — taramaya dön")
            connecting = false
            phase = .scanning
            busy = true
            scanDeadline = Date().addingTimeInterval(40)
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
