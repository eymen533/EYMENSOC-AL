import Foundation
import CoreBluetooth
import Combine

@MainActor
final class BLEPairer: NSObject, ObservableObject {
    @Published var status: String = "Hazır"
    @Published var log: [String] = []
    @Published var busy = false
    @Published var waitingForCard = false
    @Published var paired = false

    private var central: CBCentralManager!
    private var targetNames: Set<String> = []
    private var payload: Data?
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var scanTimeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func appendLog(_ line: String) {
        log.insert(line, at: 0)
        if log.count > 40 { log = Array(log.prefix(40)) }
    }

    func pair(vin: String, publicKey: Data) async {
        busy = true
        paired = false
        waitingForCard = false
        defer { busy = false }

        let names = VCSECPayload.bleNames(vin: vin)
        targetNames = Set(names)
        payload = VCSECPayload.addKeyRequest(publicKeyUncompressed: publicKey)
        appendLog("Hedef: \(names.joined(separator: ", "))")
        appendLog("Payload \(payload!.count) byte")

        guard central.state == .poweredOn else {
            status = "Bluetooth kapalı — Ayarlar’dan aç"
            appendLog("Bluetooth state: \(central.state.rawValue)")
            return
        }

        status = "Tesla aranıyor…"
        do {
            try await scanAndConnect(timeout: 25)
            status = "add-key gönderiliyor…"
            try await writePayload()
            waitingForCard = true
            status = "Key Card’ı KONSOLA koy → Pair / Confirm"
            appendLog("İstek gönderildi — kartı konsola koy")
        } catch {
            status = "Hata: \(error.localizedDescription)"
            appendLog(error.localizedDescription)
        }
    }

    private func scanAndConnect(timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.connectContinuation = cont
            let service = CBUUID(string: VCSECPayload.serviceUUID)
            central.scanForPeripherals(withServices: [service], options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false,
            ])
            // Also scan without filter — some firmwares omit service in adv
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.central.scanForPeripherals(withServices: nil, options: nil)
            }
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

    private func writePayload() async throws {
        guard let peripheral, let writeChar, let payload else {
            throw PairError.notReady
        }
        let mtu = max(20, peripheral.maximumWriteValueLength(for: .withResponse))
        var offset = 0
        while offset < payload.count {
            let end = min(offset + mtu, payload.count)
            let chunk = payload.subdata(in: offset..<end)
            peripheral.writeValue(chunk, for: writeChar, type: .withResponse)
            offset = end
            try await Task.sleep(nanoseconds: 40_000_000)
        }
    }

    enum PairError: LocalizedError {
        case timeout, notReady, bluetoothOff
        var errorDescription: String? {
            switch self {
            case .timeout: return "Araç bulunamadı (BLE). Yakınlaş / arabayı uyandır."
            case .notReady: return "BLE hazır değil"
            case .bluetoothOff: return "Bluetooth kapalı"
            }
        }
    }
}

extension BLEPairer: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            if central.state == .poweredOn {
                appendLog("Bluetooth açık")
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
            let match = targetNames.contains(name)
                || name.hasPrefix("Tesla")
                || (name.hasPrefix("S") && name.hasSuffix("C") && name.count == 18)
            guard match else { return }
            appendLog("Bulundu: \(name) (\(RSSI) dBm)")
            self.central.stopScan()
            scanTimeoutTask?.cancel()
            self.peripheral = peripheral
            peripheral.delegate = self
            self.central.connect(peripheral, options: nil)
            status = "Bağlanıyor: \(name)…"
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([CBUUID(string: VCSECPayload.serviceUUID)])
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectContinuation?.resume(throwing: error ?? PairError.notReady)
            connectContinuation = nil
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: {
            $0.uuid == CBUUID(string: VCSECPayload.serviceUUID)
        }) else {
            Task { @MainActor in
                connectContinuation?.resume(throwing: PairError.notReady)
                connectContinuation = nil
            }
            return
        }
        peripheral.discoverCharacteristics(
            [
                CBUUID(string: VCSECPayload.writeUUID),
                CBUUID(string: VCSECPayload.readUUID),
            ],
            for: service
        )
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { @MainActor in
            writeChar = service.characteristics?.first {
                $0.uuid == CBUUID(string: VCSECPayload.writeUUID)
            }
            if let read = service.characteristics?.first(where: {
                $0.uuid == CBUUID(string: VCSECPayload.readUUID)
            }) {
                peripheral.setNotifyValue(true, for: read)
            }
            if writeChar != nil {
                connectContinuation?.resume()
            } else {
                connectContinuation?.resume(throwing: PairError.notReady)
            }
            connectContinuation = nil
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
            appendLog("RX \(hex.prefix(48))…")
            if hex.contains("0801") || hex.contains("2202") {
                waitingForCard = true
                status = "Araç kart bekliyor — konsola Key Card koy"
            }
            if hex.contains("1a08") || hex.contains("5f0d") {
                paired = true
                status = "Onaylandı — Phone Key eklendi"
                appendLog("Whitelist OK (muhtemel)")
            }
        }
    }
}
