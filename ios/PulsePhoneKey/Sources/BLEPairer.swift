import Foundation
import CoreBluetooth
import Combine

/// Tesla VCSEC BLE pairer for iPad / Swift Playgrounds.
///
/// Important: iOS often delivers the car with an **empty name** while still
/// advertising service `00000211-…`. Matching only on "Tesla"/"S…C" then
/// misses the vehicle and times out — that looked like "hata / bağlanmıyor".
@MainActor
final class BLEPairer: NSObject, ObservableObject {
    @Published var status: String = "Hazır — önce arabayı uyandır"
    @Published var log: [String] = []
    @Published var busy = false
    @Published var waitingForCard = false
    @Published var paired = false
    @Published var lastDetail: String = ""

    private let teslaService = CBUUID(string: VCSECPayload.serviceUUID)
    private let teslaWrite = CBUUID(string: VCSECPayload.writeUUID)
    private let teslaRead = CBUUID(string: VCSECPayload.readUUID)

    private var central: CBCentralManager!
    private var targetNames: Set<String> = []
    private var payload: Data?
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var readChar: CBCharacteristic?

    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var writeContinuation: CheckedContinuation<Void, Error>?
    private var notifyContinuation: CheckedContinuation<Void, Error>?
    private var bluetoothContinuation: CheckedContinuation<Void, Error>?
    private var scanTimeoutTask: Task<Void, Never>?
    private var connecting = false
    private var wrotePayload = false
    private var reconnectAttempts = 0
    private var seenLogBudget = 0

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: true,
        ])
    }

    func appendLog(_ line: String) {
        let stamped = "\(Self.clock()) \(line)"
        log.insert(stamped, at: 0)
        if log.count > 80 { log = Array(log.prefix(80)) }
    }

    func pair(vin: String, publicKey: Data) async {
        busy = true
        paired = false
        waitingForCard = false
        wrotePayload = false
        connecting = false
        reconnectAttempts = 0
        seenLogBudget = 0
        writeChar = nil
        readChar = nil
        defer { busy = false }

        resetContinuations(with: PairError.cancelled)

        let names = VCSECPayload.bleNames(vin: vin)
        targetNames = Set(names)
        payload = VCSECPayload.addKeyRequest(publicKeyUncompressed: publicKey)
        appendLog("VIN \(vin)")
        appendLog("Hedef isim: \(names.joined(separator: ", "))")
        appendLog("Payload \(payload!.count) byte")
        lastDetail = "Log’u açık tut. İsim boş olsa da Tesla servisiyle bağlanır."

        do {
            status = "Bluetooth kontrol…"
            try await waitForPoweredOn(timeout: 12)
            status = "Arabayı uyandır → Tesla aranıyor… (45 sn)"
            try await scanAndConnect(timeout: 45)
            status = "Bildirim açılıyor…"
            try await enableNotify()
            status = "add-key gönderiliyor…"
            try await writePayload()
            wrotePayload = true
            waitingForCard = true
            status = "✓ İstek gitti — Key Card’ı KONSOLA koy → Pair"
            lastDetail = "Uygulamadan çıkma. Kartı iPad’e değil konsola koy."
            appendLog("İstek gönderildi ✓ — kartı konsola koy")
            try? await Task.sleep(nanoseconds: 90_000_000_000)
        } catch {
            let msg = error.localizedDescription
            status = "HATA: \(msg)"
            lastDetail = Self.hint(for: error)
            appendLog("HATA: \(msg)")
        }
    }

    // MARK: - Bluetooth ready

    private func waitForPoweredOn(timeout: TimeInterval) async throws {
        if central.state == .poweredOn { return }
        if central.state == .unauthorized { throw PairError.unauthorized }
        if central.state == .poweredOff { throw PairError.bluetoothOff }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.bluetoothContinuation = cont
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await MainActor.run {
                    guard let self, let b = self.bluetoothContinuation else { return }
                    self.bluetoothContinuation = nil
                    switch self.central.state {
                    case .poweredOn: b.resume()
                    case .unauthorized: b.resume(throwing: PairError.unauthorized)
                    case .poweredOff: b.resume(throwing: PairError.bluetoothOff)
                    default: b.resume(throwing: PairError.bluetoothOff)
                    }
                }
            }
        }
    }

    // MARK: - Scan / connect

    private func scanAndConnect(timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.connectContinuation = cont
            startScan()
            scanTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await MainActor.run {
                    guard let self, let c = self.connectContinuation else { return }
                    self.connectContinuation = nil
                    self.central.stopScan()
                    c.resume(throwing: PairError.timeout)
                }
            }
        }
    }

    private func startScan() {
        central.stopScan()
        appendLog("Tarama: Tesla servisi…")
        central.scanForPeripherals(withServices: [teslaService], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
        ])
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                guard let self, self.connectContinuation != nil, !self.connecting else { return }
                self.appendLog("Tarama: filtresiz (isim/servis)…")
                self.central.stopScan()
                self.central.scanForPeripherals(withServices: nil, options: [
                    CBCentralManagerScanOptionAllowDuplicatesKey: true,
                ])
            }
        }
    }

    private func isTeslaCandidate(name: String, advertisementData: [String: Any]) -> (Bool, String) {
        if targetNames.contains(name) { return (true, "isim-hedef:\(name)") }
        if name.hasPrefix("Tesla") { return (true, "isim-Tesla:\(name)") }
        if name.hasPrefix("S"), name.hasSuffix("C"), name.count == 18 {
            return (true, "isim-S…C:\(name)")
        }
        let svcKeys: [String] = [
            CBAdvertisementDataServiceUUIDsKey,
            CBAdvertisementDataOverflowServiceUUIDsKey,
        ]
        for key in svcKeys {
            if let uuids = advertisementData[key] as? [CBUUID],
               uuids.contains(where: { $0 == teslaService }) {
                return (true, "servis-UUID\(name.isEmpty ? " (isim yok)" : ": \(name)")")
            }
        }
        return (false, "")
    }

    private func finishConnect(success: Bool, error: Error? = nil) {
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil
        central.stopScan()
        guard let c = connectContinuation else { return }
        connectContinuation = nil
        if success { c.resume() }
        else { c.resume(throwing: error ?? PairError.notReady) }
    }

    // MARK: - Notify + write

    private func enableNotify() async throws {
        guard let peripheral, let readChar else {
            appendLog("Read char yok — yine de yazılacak")
            return
        }
        if readChar.isNotifying { return }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.notifyContinuation = cont
            peripheral.setNotifyValue(true, for: readChar)
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    guard let self, let n = self.notifyContinuation else { return }
                    self.notifyContinuation = nil
                    n.resume()
                }
            }
        }
    }

    private func writePayload() async throws {
        guard let peripheral, let writeChar, let payload else {
            throw PairError.notReady
        }
        let mtu = max(20, peripheral.maximumWriteValueLength(for: .withResponse))
        appendLog("MTU yazma: \(mtu) byte")
        var offset = 0
        var part = 0
        while offset < payload.count {
            let end = min(offset + mtu, payload.count)
            let chunk = payload.subdata(in: offset..<end)
            part += 1
            appendLog("TX \(part) \(chunk.count) byte…")
            try await writeChunk(chunk, peripheral: peripheral, characteristic: writeChar)
            offset = end
        }
        appendLog("TX tamam (\(payload.count) byte)")
    }

    private func writeChunk(
        _ data: Data,
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic
    ) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.writeContinuation = cont
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                await MainActor.run {
                    guard let self, let w = self.writeContinuation else { return }
                    self.writeContinuation = nil
                    w.resume(throwing: PairError.writeTimeout)
                }
            }
        }
    }

    private func resetContinuations(with error: Error) {
        connectContinuation?.resume(throwing: error)
        connectContinuation = nil
        writeContinuation?.resume(throwing: error)
        writeContinuation = nil
        notifyContinuation?.resume(throwing: error)
        notifyContinuation = nil
        bluetoothContinuation?.resume(throwing: error)
        bluetoothContinuation = nil
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil
        central?.stopScan()
    }

    private static func clock() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }

    private static func hint(for error: Error) -> String {
        if let e = error as? PairError {
            switch e {
            case .timeout:
                return "Hâlâ bulamadıysa: kapıyı aç, fren bas, Tesla app’i kapat, iPad’i konsola yaklaştır, tekrar Run ▶."
            case .disconnected:
                return "Bağlantı koptu. Uyandırıp hemen tekrar dene."
            case .writeTimeout, .writeFailed:
                return "Yazma bitmedi. Uygulamadan çıkmadan tekrar dene."
            case .unauthorized:
                return "Ayarlar → Swift Playgrounds → Bluetooth: Açık."
            case .notReady:
                return "Servis bulunamadı. Arabayı uyandırıp tekrar dene."
            default:
                return "Log’daki HATA satırını gönder."
            }
        }
        return "Log’daki HATA satırını gönder."
    }

    enum PairError: LocalizedError {
        case timeout, notReady, bluetoothOff, unauthorized, disconnected, writeTimeout, writeFailed, cancelled
        var errorDescription: String? {
            switch self {
            case .timeout: return "Araç bulunamadı (45sn). Uyandır / Tesla app kapat / yaklaş."
            case .notReady: return "BLE servisi/karakteristik yok"
            case .bluetoothOff: return "Bluetooth kapalı veya henüz hazır değil"
            case .unauthorized: return "Bluetooth izni yok (Ayarlar → Playgrounds)"
            case .disconnected: return "GATT bağlantısı koptu"
            case .writeTimeout: return "Yazma zaman aşımı"
            case .writeFailed: return "Yazma başarısız"
            case .cancelled: return "İptal"
            }
        }
    }
}

extension BLEPairer: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                appendLog("Bluetooth açık")
                if let b = bluetoothContinuation {
                    bluetoothContinuation = nil
                    b.resume()
                }
            case .unauthorized:
                appendLog("Bluetooth İZİN YOK")
                status = "Bluetooth izni yok — Ayarlar → Playgrounds"
                bluetoothContinuation?.resume(throwing: PairError.unauthorized)
                bluetoothContinuation = nil
            case .poweredOff:
                appendLog("Bluetooth kapalı")
            default:
                appendLog("Bluetooth state \(central.state.rawValue)")
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? ""
        let adv = advertisementData
        Task { @MainActor in
            guard connectContinuation != nil, !connecting else { return }
            let (match, why) = isTeslaCandidate(name: name, advertisementData: adv)
            if !match {
                // Occasional breadcrumb so we know scan is alive
                if seenLogBudget < 8, RSS.intValue > -75 {
                    seenLogBudget += 1
                    let label = name.isEmpty ? peripheral.identifier.uuidString.prefix(8) : name
                    appendLog("diğer: \(label) (\(RSSI) dBm)")
                }
                return
            }

            connecting = true
            appendLog("Bulundu [\(why)] rssi=\(RSSI)")
            lastDetail = "Bulundu — Ayarlar’dan kaybolması normal."
            self.central.stopScan()
            self.peripheral = peripheral
            peripheral.delegate = self
            let label = name.isEmpty ? "Tesla BLE" : name
            status = "Bağlanıyor: \(label)…"
            // No background notify options — Playgrounds may lack that entitlement.
            self.central.connect(peripheral, options: nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            appendLog("GATT bağlı — tüm servisler…")
            status = "Servisler keşfediliyor…"
            // nil = don't miss service if cache is cold
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            connecting = false
            appendLog("Bağlantı başarısız: \(error?.localizedDescription ?? "?")")
            finishConnect(success: false, error: error ?? PairError.notReady)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            appendLog("GATT koptu: \(error?.localizedDescription ?? "ok")")
            if wrotePayload {
                if waitingForCard {
                    status = "Bağlantı koptu — yine de Key Card’ı konsola dene"
                }
                return
            }
            if connectContinuation != nil {
                if reconnectAttempts < 2 {
                    reconnectAttempts += 1
                    connecting = true
                    appendLog("Yeniden bağlanılıyor (\(reconnectAttempts))…")
                    status = "Kopuk — yeniden bağlanılıyor…"
                    central.connect(peripheral, options: nil)
                    return
                }
                finishConnect(success: false, error: PairError.disconnected)
                return
            }
            if let w = writeContinuation {
                writeContinuation = nil
                w.resume(throwing: PairError.disconnected)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error {
                finishConnect(success: false, error: error)
                return
            }
            let services = peripheral.services ?? []
            appendLog("Servis sayısı: \(services.count)")
            for s in services {
                appendLog(" svc \(s.uuid.uuidString)")
            }
            guard let service = services.first(where: { $0.uuid == teslaService }) else {
                appendLog("Tesla servisi YOK")
                finishConnect(success: false, error: PairError.notReady)
                return
            }
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                finishConnect(success: false, error: error)
                return
            }
            let chars = service.characteristics ?? []
            for c in chars {
                appendLog(" chr \(c.uuid.uuidString)")
            }
            writeChar = chars.first { $0.uuid == teslaWrite }
            readChar = chars.first { $0.uuid == teslaRead }
            if writeChar != nil {
                appendLog("Write/Read hazır")
                finishConnect(success: true)
            } else {
                appendLog("Write characteristic YOK")
                finishConnect(success: false, error: PairError.notReady)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                appendLog("Notify hata: \(error.localizedDescription)")
            } else {
                appendLog("Notify \(characteristic.isNotifying ? "açık" : "kapalı")")
            }
            notifyContinuation?.resume()
            notifyContinuation = nil
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor in
            guard let w = writeContinuation else { return }
            writeContinuation = nil
            if let error {
                appendLog("Write hata: \(error.localizedDescription)")
                w.resume(throwing: error)
            } else {
                appendLog("Write ACK ✓")
                w.resume()
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let data = characteristic.value else { return }
        let hex = data.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            appendLog("RX \(hex.prefix(64))")
            if hex.contains("0801") || hex.contains("2202") {
                waitingForCard = true
                status = "Araç kart bekliyor — konsola Key Card koy"
                lastDetail = "Şimdi kartı konsola koy; ekranda Pair çıkmalı."
            }
            if hex.contains("1a08") || hex.contains("5f0d") {
                paired = true
                status = "Onaylandı — Phone Key eklendi"
                appendLog("Whitelist OK (muhtemel)")
            }
        }
    }
}
