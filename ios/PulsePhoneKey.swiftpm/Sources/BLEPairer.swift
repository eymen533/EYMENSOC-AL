import Foundation
import CoreBluetooth
import Combine

/// Robust Tesla VCSEC BLE pairer for iPad / Swift Playgrounds.
///
/// Critical: writes use `.withResponse` and wait for each ACK before the next
/// chunk. Flooding writes (sleep-only) drops bytes → car never shows Pair.
@MainActor
final class BLEPairer: NSObject, ObservableObject {
    @Published var status: String = "Hazır — önce arabayı uyandır"
    @Published var log: [String] = []
    @Published var busy = false
    @Published var waitingForCard = false
    @Published var paired = false
    @Published var lastDetail: String = ""

    private var central: CBCentralManager!
    private var targetNames: Set<String> = []
    private var payload: Data?
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var readChar: CBCharacteristic?

    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var writeContinuation: CheckedContinuation<Void, Error>?
    private var notifyContinuation: CheckedContinuation<Void, Error>?
    private var scanTimeoutTask: Task<Void, Never>?
    private var connecting = false
    private var wrotePayload = false
    private var reconnectAttempts = 0

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: true,
        ])
    }

    func appendLog(_ line: String) {
        let stamped = "\(Self.clock()) \(line)"
        log.insert(stamped, at: 0)
        if log.count > 60 { log = Array(log.prefix(60)) }
    }

    func pair(vin: String, publicKey: Data) async {
        busy = true
        paired = false
        waitingForCard = false
        wrotePayload = false
        connecting = false
        reconnectAttempts = 0
        writeChar = nil
        readChar = nil
        defer { busy = false }

        resetContinuations(with: PairError.cancelled)

        let names = VCSECPayload.bleNames(vin: vin)
        targetNames = Set(names)
        payload = VCSECPayload.addKeyRequest(publicKeyUncompressed: publicKey)
        appendLog("Hedef: \(names.joined(separator: ", "))")
        appendLog("Payload \(payload!.count) byte")
        lastDetail = "S…C listede kaybolursa normal — bağlanınca gizlenir."

        guard central.state == .poweredOn else {
            status = "Bluetooth kapalı — Ayarlar’dan aç"
            appendLog("Bluetooth state: \(central.state.rawValue)")
            return
        }

        // Wake tip first — advertising stops when the car sleeps.
        status = "Arabayı uyandır (kapı/ekran) → Tesla aranıyor…"
        do {
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
            // Stay connected so the car can reply WAIT / OK.
            try? await Task.sleep(nanoseconds: 90_000_000_000)
        } catch {
            status = "Hata: \(error.localizedDescription)"
            lastDetail = Self.hint(for: error)
            appendLog(error.localizedDescription)
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
        let service = CBUUID(string: VCSECPayload.serviceUUID)
        appendLog("Tarama (servis filtresi)…")
        central.scanForPeripherals(withServices: [service], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
        ])
        // Many cars omit service UUID in advertisement — open scan after 2s.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                guard let self, self.connectContinuation != nil, !self.connecting else { return }
                self.appendLog("Filtresiz tarama…")
                self.central.stopScan()
                self.central.scanForPeripherals(withServices: nil, options: [
                    CBCentralManagerScanOptionAllowDuplicatesKey: true,
                ])
            }
        }
    }

    private func finishConnect(success: Bool, error: Error? = nil) {
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil
        central.stopScan()
        guard let c = connectContinuation else { return }
        connectContinuation = nil
        if success {
            c.resume()
        } else {
            c.resume(throwing: error ?? PairError.notReady)
        }
    }

    // MARK: - Notify + write

    private func enableNotify() async throws {
        guard let peripheral, let readChar else {
            // Notify is helpful but not strictly required for add-key.
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
                    // Proceed even if notify ACK is slow.
                    n.resume()
                }
            }
        }
    }

    private func writePayload() async throws {
        guard let peripheral, let writeChar, let payload else {
            throw PairError.notReady
        }
        // Prefer one shot when MTU allows (Android path). Else chunk with ACK.
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
                return "Kapıyı aç / ekranı uyandır. Tesla uygulamasını kapat. iPad’i direksiyona yakın tut."
            case .disconnected:
                return "Bağlantı koptu. Arabayı uyandırıp tekrar dene. Ayarlar’da S…C kaybolması bağlanınca normal."
            case .writeTimeout, .writeFailed:
                return "Yazma tamamlanmadı. Playgrounds’ta Run ▶ ile çalıştır; uygulamadan çıkma."
            default:
                return "Tekrar dene. Log’a bak."
            }
        }
        return error.localizedDescription
    }

    enum PairError: LocalizedError {
        case timeout, notReady, bluetoothOff, disconnected, writeTimeout, writeFailed, cancelled
        var errorDescription: String? {
            switch self {
            case .timeout:
                return "Araç bulunamadı (BLE). Uyandır / yakınlaş."
            case .notReady:
                return "BLE hazır değil (servis/karakteristik)."
            case .bluetoothOff:
                return "Bluetooth kapalı"
            case .disconnected:
                return "GATT bağlantısı koptu"
            case .writeTimeout:
                return "Yazma zaman aşımı"
            case .writeFailed:
                return "Yazma başarısız"
            case .cancelled:
                return "İptal"
            }
        }
    }
}

extension BLEPairer: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn: appendLog("Bluetooth açık")
            case .unauthorized: status = "Bluetooth izni yok — Ayarlar → Playgrounds"
            case .poweredOff: status = "Bluetooth kapalı"
            default: appendLog("Bluetooth state \(central.state.rawValue)")
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
        Task { @MainActor in
            guard connectContinuation != nil, !connecting else { return }
            let match = targetNames.contains(name)
                || name.hasPrefix("Tesla")
                || (name.hasPrefix("S") && name.hasSuffix("C") && name.count == 18)
            guard match else { return }

            connecting = true
            appendLog("Bulundu: \(name) (\(RSSI) dBm)")
            lastDetail = "\(name) bulundu — Ayarlar’dan kaybolması normal."
            self.central.stopScan()
            self.peripheral = peripheral
            peripheral.delegate = self
            status = "Bağlanıyor: \(name)…"
            self.central.connect(peripheral, options: [
                CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            ])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            appendLog("GATT bağlı — servisler…")
            status = "Servisler keşfediliyor…"
            peripheral.discoverServices([CBUUID(string: VCSECPayload.serviceUUID)])
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
                // After add-key, some cars drop the link; Pair UI can still appear.
                if waitingForCard {
                    status = "Bağlantı koptu — yine de Key Card’ı konsola dene"
                }
                return
            }
            if connectContinuation != nil {
                // Still in handshake — one automatic reconnect.
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
            if writeContinuation != nil {
                let w = writeContinuation
                writeContinuation = nil
                w?.resume(throwing: PairError.disconnected)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error {
                finishConnect(success: false, error: error)
                return
            }
            guard let service = peripheral.services?.first(where: {
                $0.uuid == CBUUID(string: VCSECPayload.serviceUUID)
            }) else {
                appendLog("Tesla servisi yok")
                finishConnect(success: false, error: PairError.notReady)
                return
            }
            appendLog("Servis OK — karakteristikler…")
            peripheral.discoverCharacteristics(
                [
                    CBUUID(string: VCSECPayload.writeUUID),
                    CBUUID(string: VCSECPayload.readUUID),
                ],
                for: service
            )
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
            writeChar = service.characteristics?.first {
                $0.uuid == CBUUID(string: VCSECPayload.writeUUID)
            }
            readChar = service.characteristics?.first {
                $0.uuid == CBUUID(string: VCSECPayload.readUUID)
            }
            if writeChar != nil {
                appendLog("Write/Read karakteristik hazır")
                finishConnect(success: true)
            } else {
                appendLog("Write characteristic yok")
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
            // WAIT / card present signals commonly seen on VCSEC
            if hex.contains("0801") || hex.contains("2202") {
                waitingForCard = true
                status = "Araç kart bekliyor — konsola Key Card koy"
                lastDetail = "Şimdi kartı konsol okuyucuya koy; ekranda Pair çıkmalı."
            }
            if hex.contains("1a08") || hex.contains("5f0d") {
                paired = true
                status = "Onaylandı — Phone Key eklendi"
                appendLog("Whitelist OK (muhtemel)")
            }
        }
    }
}
