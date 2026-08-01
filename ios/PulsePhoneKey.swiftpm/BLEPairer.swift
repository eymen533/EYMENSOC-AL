import Foundation
import CoreBluetooth

/// Simple Tesla VCSEC BLE pairer — avoids async continuation misuse crashes.
final class BLEPairer: NSObject, ObservableObject {
    @Published var status: String = "Hazir"
    @Published var log: [String] = []
    @Published var busy = false
    @Published var waitingForCard = false
    @Published var paired = false
    @Published var lastDetail: String = "Capabilities → Bluetooth Always ekli olmali."

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
    private var scanTimer: Timer?
    private var phase: Phase = .idle

    private enum Phase {
        case idle, scanning, connecting, discovering, writing, waitingCard
    }

    func appendLog(_ line: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        let stamped = "\(f.string(from: Date())) \(line)"
        DispatchQueue.main.async {
            self.log.insert(stamped, at: 0)
            if self.log.count > 80 { self.log = Array(self.log.prefix(80)) }
        }
    }

    func pair(vin: String, publicKey: Data) {
        DispatchQueue.main.async {
            self.startPair(vin: vin, publicKey: publicKey)
        }
    }

    private func startPair(vin: String, publicKey: Data) {
        stopScanTimer()
        connecting = false
        writing = false
        writeQueue = []
        writeChar = nil
        waitingForCard = false
        paired = false
        busy = true
        phase = .scanning

        targetNames = Set(VCSECPayload.bleNames(vin: vin))
        payload = VCSECPayload.addKeyRequest(publicKeyUncompressed: publicKey)
        appendLog("VIN \(vin)")
        appendLog("Hedef \(targetNames.sorted().joined(separator: ", "))")
        appendLog("Payload \(payload?.count ?? 0) byte")

        status = "Bluetooth hazirlaniyor…"
        if central == nil {
            // Requires Package.swift capabilities: .bluetoothAlways(...)
            central = CBCentralManager(delegate: self, queue: .main, options: [
                CBCentralManagerOptionShowPowerAlertKey: true,
            ])
            appendLog("Central olusturuldu")
        } else {
            bluetoothReady()
        }
    }

    private func bluetoothReady() {
        guard let central, central.state == .poweredOn else {
            status = "Bluetooth kapali veya izin yok"
            lastDetail = "Ayarlar → Playgrounds → Bluetooth Acik"
            busy = false
            phase = .idle
            return
        }
        status = "Tesla araniyor… (45 sn)"
        lastDetail = "Arabayi uyandir, Tesla app kapat, uygulamadan cikma"
        phase = .scanning
        connecting = false
        central.stopScan()
        central.scanForPeripherals(withServices: [teslaService], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
        ])
        // Unfiltered after 2.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self, self.phase == .scanning, let central = self.central else { return }
            self.appendLog("Filtresiz tarama")
            central.stopScan()
            central.scanForPeripherals(withServices: nil, options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: true,
            ])
        }
        stopScanTimer()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: false) { [weak self] _ in
            guard let self, self.phase == .scanning else { return }
            self.central?.stopScan()
            self.status = "HATA: Arac bulunamadi (45sn)"
            self.lastDetail = "Kapi ac / ekran uyandir / yaklas / tekrar"
            self.busy = false
            self.phase = .idle
            self.appendLog("Timeout")
        }
    }

    private func stopScanTimer() {
        scanTimer?.invalidate()
        scanTimer = nil
    }

    private func isTesla(_ name: String, adv: [String: Any]) -> Bool {
        if targetNames.contains(name) { return true }
        if name.hasPrefix("Tesla") { return true }
        if name.hasPrefix("S"), name.hasSuffix("C"), name.count == 18 { return true }
        for key in [CBAdvertisementDataServiceUUIDsKey, CBAdvertisementDataOverflowServiceUUIDsKey] {
            if let uuids = adv[key] as? [CBUUID], uuids.contains(where: { $0 == teslaService }) {
                return true
            }
        }
        return false
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
            status = "OK: Istek gitti — Key Card KONSOLA → Pair"
            lastDetail = "Kart iPad'e degil konsola. Uygulamada kal."
            appendLog("TX tamam — karti konsola koy")
            return
        }
        let chunk = writeQueue.removeFirst()
        writing = true
        appendLog("TX \(chunk.count) byte")
        peripheral.writeValue(chunk, for: writeChar, type: .withResponse)
    }

    private func fail(_ message: String) {
        stopScanTimer()
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
            if phase == .scanning || busy {
                bluetoothReady()
            }
        case .unauthorized:
            fail("Bluetooth izni yok (Capabilities / Ayarlar)")
        case .poweredOff:
            if busy { fail("Bluetooth kapali") }
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
        guard phase == .scanning, !connecting else { return }
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? ""
        guard isTesla(name, adv: advertisementData) else { return }

        connecting = true
        phase = .connecting
        stopScanTimer()
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        let label = name.isEmpty ? "Tesla BLE" : name
        status = "Baglaniyor: \(label)…"
        appendLog("Bulundu \(label) \(RSSI) dBm")
        lastDetail = "Ayarlar'dan kaybolmasi normal"
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        phase = .discovering
        status = "Servisler…"
        appendLog("GATT bagli")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
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
        guard let service = peripheral.services?.first(where: { $0.uuid == teslaService }) else {
            fail("Tesla servisi yok")
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
        // Short delay so notify can settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
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
