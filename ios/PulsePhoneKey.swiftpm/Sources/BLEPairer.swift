import Foundation
import CoreBluetooth
import Combine

/// Tesla VCSEC BLE pairer for iPad / Swift Playgrounds.
///
/// Do NOT create `CBCentralManager` at init — if Playgrounds dropped the
/// Bluetooth usage description, iOS **kills** the app (looks like a crash).
@MainActor
final class BLEPairer: NSObject, ObservableObject {
    @Published var status: String = "Hazır"
    @Published var log: [String] = []
    @Published var busy = false
    @Published var waitingForCard = false
    @Published var paired = false
    @Published var lastDetail: String = ""
    /// False when Info.plist lacks NSBluetoothAlwaysUsageDescription (Playgrounds).
    @Published private(set) var bluetoothPrivacyOK: Bool = false

    private let teslaService = CBUUID(string: VCSECPayload.serviceUUID)
    private let teslaWrite = CBUUID(string: VCSECPayload.writeUUID)
    private let teslaRead = CBUUID(string: VCSECPayload.readUUID)

    private var central: CBCentralManager?
    private var targetNames: Set<String> = []
    private var payload: Data?
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var readChar: CBCharacteristic?

    private var connectGate = OnceGate()
    private var writeGate = OnceGate()
    private var notifyGate = OnceGate()
    private var bluetoothGate = OnceGate()
    private var scanTimeoutTask: Task<Void, Never>?
    private var connecting = false
    private var wrotePayload = false
    private var reconnectAttempts = 0
    private var seenLogBudget = 0

    override init() {
        super.init()
        refreshPrivacyFlag()
        if bluetoothPrivacyOK {
            status = "Hazır — önce arabayı uyandır"
            lastDetail = "Bluetooth izin metni OK."
        } else {
            status = "ÖNCE AYAR: Bluetooth izin metni yok"
            lastDetail = Self.privacyFixSteps
            appendLog("NSBluetoothAlwaysUsageDescription YOK — Run çökmesin diye BLE açılmadı")
        }
    }

    func refreshPrivacyFlag() {
        let key = Bundle.main.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") as? String
        bluetoothPrivacyOK = !(key ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static let privacyFixSteps = """
    Playgrounds → sol üstte PulsePhoneKey → App Settings → Capabilities → + → Bluetooth \
    (veya Privacy — Bluetooth Always Usage Description). \
    Metin: Tesla Phone Key eşleşmesi için Bluetooth gerekir. \
    Sonra Package.swift içinde additionalInfoPlistContentFilePath: \"Info.plist\" satırı duruyor mu bak. \
    Kaydet → Run ▶
    """

    func appendLog(_ line: String) {
        let stamped = "\(Self.clock()) \(line)"
        log.insert(stamped, at: 0)
        if log.count > 80 { log = Array(log.prefix(80)) }
    }

    func pair(vin: String, publicKey: Data) async {
        refreshPrivacyFlag()
        guard bluetoothPrivacyOK else {
            status = "ÖNCE AYAR: Bluetooth izin metni yok"
            lastDetail = Self.privacyFixSteps
            appendLog("BLE başlatılmadı — izin metni eksik (bu çökme nedeniydi)")
            return
        }

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

        cancelPending(reason: "yeni deneme")

        let names = VCSECPayload.bleNames(vin: vin)
        targetNames = Set(names)
        payload = VCSECPayload.addKeyRequest(publicKeyUncompressed: publicKey)
        appendLog("VIN \(vin)")
        appendLog("Hedef: \(names.joined(separator: ", "))")
        appendLog("Payload \(payload!.count) byte")

        do {
            status = "Bluetooth açılıyor…"
            try ensureCentral()
            try await waitForPoweredOn(timeout: 15)
            status = "Tesla aranıyor… (45 sn) — uygulamadan çıkma"
            try await scanAndConnect(timeout: 45)
            status = "Bildirim…"
            try await enableNotify()
            status = "add-key gönderiliyor…"
            try await writePayload()
            wrotePayload = true
            waitingForCard = true
            status = "✓ İstek gitti — Key Card’ı KONSOLA koy → Pair"
            lastDetail = "Uygulamadan çıkma."
            appendLog("İstek gönderildi ✓")
            try? await Task.sleep(nanoseconds: 90_000_000_000)
        } catch {
            status = "HATA: \(error.localizedDescription)"
            lastDetail = Self.hint(for: error)
            appendLog("HATA: \(error.localizedDescription)")
        }
    }

    // MARK: - Central lifecycle

    private func ensureCentral() throws {
        if central != nil { return }
        // Second check right before alloc — missing key = iOS kills process.
        refreshPrivacyFlag()
        guard bluetoothPrivacyOK else { throw PairError.missingPrivacyString }
        let mgr = CBCentralManager(delegate: self, queue: .main, options: [
            CBCentralManagerOptionShowPowerAlertKey: true,
        ])
        central = mgr
        appendLog("CBCentralManager oluşturuldu")
    }

    private func waitForPoweredOn(timeout: TimeInterval) async throws {
        guard let central else { throw PairError.notReady }
        if central.state == .poweredOn { return }
        if central.state == .unauthorized { throw PairError.unauthorized }
        if central.state == .poweredOff { throw PairError.bluetoothOff }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            bluetoothGate.arm(cont)
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await MainActor.run {
                    guard let self, let c = self.central else { return }
                    switch c.state {
                    case .poweredOn: self.bluetoothGate.resumeOk()
                    case .unauthorized: self.bluetoothGate.resumeError(PairError.unauthorized)
                    default: self.bluetoothGate.resumeError(PairError.bluetoothOff)
                    }
                }
            }
        }
    }

    private func scanAndConnect(timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connectGate.arm(cont)
            startScan()
            scanTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await MainActor.run {
                    self?.central?.stopScan()
                    self?.connectGate.resumeError(PairError.timeout)
                }
            }
        }
    }

    private func startScan() {
        guard let central else { return }
        central.stopScan()
        appendLog("Tarama: Tesla servisi…")
        central.scanForPeripherals(withServices: [teslaService], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
        ])
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                guard let self, self.connectGate.isArmed, !self.connecting, let central = self.central else { return }
                self.appendLog("Tarama: filtresiz…")
                central.stopScan()
                central.scanForPeripherals(withServices: nil, options: [
                    CBCentralManagerScanOptionAllowDuplicatesKey: true,
                ])
            }
        }
    }

    private func isTeslaCandidate(name: String, advertisementData: [String: Any]) -> (Bool, String) {
        if targetNames.contains(name) { return (true, "isim:\(name)") }
        if name.hasPrefix("Tesla") { return (true, "Tesla:\(name)") }
        if name.hasPrefix("S"), name.hasSuffix("C"), name.count == 18 { return (true, "S…C:\(name)") }
        for key in [CBAdvertisementDataServiceUUIDsKey, CBAdvertisementDataOverflowServiceUUIDsKey] {
            if let uuids = advertisementData[key] as? [CBUUID], uuids.contains(where: { $0 == teslaService }) {
                return (true, "servis-UUID\(name.isEmpty ? " (isim yok)" : " \(name)")")
            }
        }
        return (false, "")
    }

    private func finishConnect(success: Bool, error: Error? = nil) {
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil
        central?.stopScan()
        if success { connectGate.resumeOk() }
        else { connectGate.resumeError(error ?? PairError.notReady) }
    }

    private func enableNotify() async throws {
        guard let peripheral, let readChar else {
            appendLog("Read yok — yazmaya geç")
            return
        }
        if readChar.isNotifying { return }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            notifyGate.arm(cont)
            peripheral.setNotifyValue(true, for: readChar)
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run { self?.notifyGate.resumeOk() }
            }
        }
    }

    private func writePayload() async throws {
        guard let peripheral, let writeChar, let payload else { throw PairError.notReady }
        guard peripheral.state == .connected else { throw PairError.disconnected }
        let mtu = max(20, peripheral.maximumWriteValueLength(for: .withResponse))
        appendLog("MTU \(mtu)")
        var offset = 0
        var part = 0
        while offset < payload.count {
            let end = min(offset + mtu, payload.count)
            let chunk = payload.subdata(in: offset..<end)
            part += 1
            appendLog("TX \(part) \(chunk.count)b")
            try await writeChunk(chunk, peripheral: peripheral, characteristic: writeChar)
            offset = end
        }
        appendLog("TX tamam")
    }

    private func writeChunk(_ data: Data, peripheral: CBPeripheral, characteristic: CBCharacteristic) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            writeGate.arm(cont)
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                await MainActor.run { self?.writeGate.resumeError(PairError.writeTimeout) }
            }
        }
    }

    private func cancelPending(reason: String) {
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil
        central?.stopScan()
        connectGate.resumeError(PairError.cancelled)
        writeGate.resumeError(PairError.cancelled)
        notifyGate.resumeError(PairError.cancelled)
        bluetoothGate.resumeError(PairError.cancelled)
        appendLog("reset (\(reason))")
    }

    private static func clock() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }

    private static func hint(for error: Error) -> String {
        if let e = error as? PairError {
            switch e {
            case .missingPrivacyString: return Self.privacyFixSteps
            case .timeout: return "Kapı aç, Tesla app kapat, iPad’i yaklaştır, tekrar."
            case .unauthorized: return "Ayarlar → Playgrounds → Bluetooth Açık"
            case .disconnected: return "Kopuk — uyandırıp tekrar"
            default: return "Log’daki HATA satırını gönder"
            }
        }
        return "Log’daki HATA satırını gönder"
    }

    enum PairError: LocalizedError {
        case timeout, notReady, bluetoothOff, unauthorized, disconnected
        case writeTimeout, writeFailed, cancelled, missingPrivacyString
        var errorDescription: String? {
            switch self {
            case .timeout: return "Araç bulunamadı (45sn)"
            case .notReady: return "BLE servisi yok"
            case .bluetoothOff: return "Bluetooth kapalı"
            case .unauthorized: return "Bluetooth izni yok"
            case .disconnected: return "GATT koptu"
            case .writeTimeout: return "Yazma zaman aşımı"
            case .writeFailed: return "Yazma başarısız"
            case .cancelled: return "İptal"
            case .missingPrivacyString: return "Bluetooth izin metni eksik (App Settings)"
            }
        }
    }
}

/// Resume-once gate — prevents "Swift continuation resumed twice" crashes.
@MainActor
final class OnceGate {
    private var cont: CheckedContinuation<Void, Error>?
    var isArmed: Bool { cont != nil }

    func arm(_ c: CheckedContinuation<Void, Error>) {
        cont?.resume(throwing: BLEPairer.PairError.cancelled)
        cont = c
    }

    func resumeOk() {
        guard let c = cont else { return }
        cont = nil
        c.resume()
    }

    func resumeError(_ error: Error) {
        guard let c = cont else { return }
        cont = nil
        c.resume(throwing: error)
    }
}

extension BLEPairer: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                appendLog("Bluetooth açık")
                bluetoothGate.resumeOk()
            case .unauthorized:
                appendLog("Bluetooth İZİN YOK")
                status = "Bluetooth izni yok"
                bluetoothGate.resumeError(PairError.unauthorized)
            case .poweredOff:
                appendLog("Bluetooth kapalı")
            default:
                appendLog("BT state \(central.state.rawValue)")
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
            guard connectGate.isArmed, !connecting else { return }
            let (match, why) = isTeslaCandidate(name: name, advertisementData: adv)
            if !match {
                if seenLogBudget < 8, RSS.intValue > -75 {
                    seenLogBudget += 1
                    let label = name.isEmpty ? String(peripheral.identifier.uuidString.prefix(8)) : name
                    appendLog("diğer: \(label) (\(RSSI))")
                }
                return
            }
            connecting = true
            appendLog("Bulundu [\(why)] \(RSSI) dBm")
            lastDetail = "Bulundu — Ayarlar listesinden kaybolması normal"
            self.central?.stopScan()
            self.peripheral = peripheral
            peripheral.delegate = self
            status = "Bağlanıyor: \(name.isEmpty ? "Tesla BLE" : name)…"
            self.central?.connect(peripheral, options: nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            appendLog("GATT bağlı")
            status = "Servisler…"
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connecting = false
            appendLog("Bağlantı fail: \(error?.localizedDescription ?? "?")")
            finishConnect(success: false, error: error ?? PairError.notReady)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            appendLog("GATT koptu: \(error?.localizedDescription ?? "ok")")
            if wrotePayload {
                if waitingForCard { status = "Kopuk — yine de kartı konsola dene" }
                return
            }
            if connectGate.isArmed {
                if reconnectAttempts < 2 {
                    reconnectAttempts += 1
                    connecting = true
                    appendLog("Reconnect \(reconnectAttempts)")
                    central.connect(peripheral, options: nil)
                    return
                }
                finishConnect(success: false, error: PairError.disconnected)
                return
            }
            writeGate.resumeError(PairError.disconnected)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error { finishConnect(success: false, error: error); return }
            let services = peripheral.services ?? []
            appendLog("Servis: \(services.count)")
            guard let service = services.first(where: { $0.uuid == teslaService }) else {
                appendLog("Tesla servisi YOK")
                finishConnect(success: false, error: PairError.notReady)
                return
            }
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if let error { finishConnect(success: false, error: error); return }
            let chars = service.characteristics ?? []
            writeChar = chars.first { $0.uuid == teslaWrite }
            readChar = chars.first { $0.uuid == teslaRead }
            if writeChar != nil {
                appendLog("Write hazır")
                finishConnect(success: true)
            } else {
                appendLog("Write YOK")
                finishConnect(success: false, error: PairError.notReady)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let error { appendLog("Notify hata: \(error.localizedDescription)") }
            else { appendLog("Notify \(characteristic.isNotifying ? "on" : "off")") }
            notifyGate.resumeOk()
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let error {
                appendLog("Write hata: \(error.localizedDescription)")
                writeGate.resumeError(error)
            } else {
                appendLog("Write ACK ✓")
                writeGate.resumeOk()
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        let hex = data.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            appendLog("RX \(hex.prefix(64))")
            if hex.contains("0801") || hex.contains("2202") {
                waitingForCard = true
                status = "Araç kart bekliyor — konsola Key Card koy"
            }
            if hex.contains("1a08") || hex.contains("5f0d") {
                paired = true
                status = "Onaylandı — Phone Key eklendi"
            }
        }
    }
}
