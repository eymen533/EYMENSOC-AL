import Combine
import CoreBluetooth
import Foundation

#if canImport(TeslaBLEKeyKit)
import TeslaBLEKeyKit
#endif

/// Coordinates Tesla BLE session lifecycle for SOC.
@MainActor
final class TeslaBLEService: NSObject, ObservableObject {
    @Published private(set) var connectionStatus: ConnectionStatus = .idle
    @Published private(set) var vehicleState: VehicleState = .empty
    @Published private(set) var lastError: String?
    @Published private(set) var isPairingInProgress = false
    @Published private(set) var discoveredName: String?

    private let vehicleStore: VehicleStore
    private var vin: String?
    private var pollTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    #if canImport(TeslaBLEKeyKit)
    private var kitVehicle: TeslaVehicle?
    private var kitConnection: BLEConnection?
    #endif

    /// Fallback scanner when KeyKit path is unavailable (previews / incomplete SPM resolve).
    private var fallbackCentral: CBCentralManager?
    private var fallbackPeripheral: CBPeripheral?

    static let teslaServiceUUID = CBUUID(string: "00000211-B2D1-43F0-9B88-960CEBF8B91E")

    init(vehicleStore: VehicleStore) {
        self.vehicleStore = vehicleStore
        super.init()
    }

    func prepare(vin: String) async {
        self.vin = VINHelper.normalize(vin)
    }

    func connect() async {
        guard let vin else {
            lastError = "VIN tanımlı değil."
            connectionStatus = .error("VIN yok")
            return
        }

        lastError = nil
        connectionStatus = .scanning

        #if canImport(TeslaBLEKeyKit)
        await connectWithKeyKit(vin: vin)
        #else
        startFallbackScan()
        #endif
    }

    func disconnect() async {
        pollTask?.cancel()
        reconnectTask?.cancel()
        pollTask = nil
        reconnectTask = nil

        #if canImport(TeslaBLEKeyKit)
        kitVehicle?.disconnect()
        kitVehicle = nil
        kitConnection = nil
        #endif

        if let fallbackPeripheral {
            fallbackCentral?.cancelPeripheralConnection(fallbackPeripheral)
        }
        fallbackPeripheral = nil
        connectionStatus = .disconnected
    }

    func reconnect() async {
        connectionStatus = .reconnecting
        await disconnect()
        await connect()
    }

    func lockVehicle() async {
        #if canImport(TeslaBLEKeyKit)
        do {
            try await kitVehicle?.lock()
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    func unlockVehicle() async {
        #if canImport(TeslaBLEKeyKit)
        do {
            try await kitVehicle?.unlock()
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    func flashLights() async {
        #if canImport(TeslaBLEKeyKit)
        do {
            try await kitVehicle?.flashLights()
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    func honk() async {
        #if canImport(TeslaBLEKeyKit)
        do {
            try await kitVehicle?.honkHorn()
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    func startPairingScan(vin: String) async {
        isPairingInProgress = true
        await prepare(vin: vin)
        connectionStatus = .scanning

        #if canImport(TeslaBLEKeyKit)
        do {
            let connection = try BLEConnection(vin: vin)
            kitConnection = connection
            try await connection.connect()
            discoveredName = connection.localName
            connectionStatus = .connecting
            try await completeAddKey()
        } catch {
            lastError = error.localizedDescription
            connectionStatus = .error(error.localizedDescription)
            // Keep scanning fallback so UI can still proceed visually while retrying.
            startFallbackScan()
        }
        #else
        startFallbackScan()
        #endif
    }

    func completeAddKey() async throws {
        guard let vin else { throw BLEServiceError.missingVIN }

        #if canImport(TeslaBLEKeyKit)
        let privateKey = try loadOrCreatePrivateKey(for: vin)
        let connection: BLEConnection
        if let kitConnection {
            connection = kitConnection
        } else {
            connection = try BLEConnection(vin: vin)
            try await connection.connect()
            kitConnection = connection
        }

        let pairing = TeslaPairing(connector: connection)
        try await pairing.requestPairing(
            publicKey: privateKey.publicKey,
            role: .owner,
            formFactor: .iosDevice
        )
        discoveredName = connection.localName
        connectionStatus = .connected
        #else
        try await Task.sleep(nanoseconds: 900_000_000)
        connectionStatus = .connected
        #endif

        isPairingInProgress = false
    }

    // MARK: - KeyKit

    #if canImport(TeslaBLEKeyKit)
    private func connectWithKeyKit(vin: String) async {
        do {
            connectionStatus = .connecting
            let privateKey = try loadOrCreatePrivateKey(for: vin)
            let connection = try BLEConnection(vin: vin)
            try await connection.connect()
            discoveredName = connection.localName

            let vehicle = try TeslaVehicle(connector: connection, privateKey: privateKey)
            try await vehicle.connect()
            try await vehicle.startVCSECSession()
            // Vehicle data / climate / drive live on Infotainment domain.
            do {
                try await vehicle.startInfotainmentSession()
            } catch {
                // Car may be asleep; VCSEC still works and polling can wake later.
                lastError = "Infotainment uyuyor: \(error.localizedDescription)"
            }

            kitConnection = connection
            kitVehicle = vehicle
            connectionStatus = .connected
            startPolling()
        } catch {
            lastError = error.localizedDescription
            connectionStatus = .error(error.localizedDescription)
            scheduleReconnect()
        }
    }

    private func loadOrCreatePrivateKey(for vin: String) throws -> TeslaPrivateKey {
        if let raw = KeychainTeslaKeys.loadPrivateKey(forVIN: vin) {
            return try TeslaPrivateKey(rawRepresentation: raw)
        }
        let key = TeslaPrivateKey.generate()
        try KeychainTeslaKeys.savePrivateKey(key.rawRepresentation, forVIN: vin)
        return key
    }

    private func refreshWithKeyKit() async {
        guard let kitVehicle else { return }
        do {
            // Wake lightly via VCSEC status if Infotainment is asleep.
            _ = try? await kitVehicle.vehicleStatus()
            let data = try await kitVehicle.getVehicleData()
            vehicleState = VehicleStateMapper.map(data)
            connectionStatus = .connected
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
    #endif

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                #if canImport(TeslaBLEKeyKit)
                await self?.refreshWithKeyKit()
                #endif
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard let self, !Task.isCancelled else { return }
            if case .connected = self.connectionStatus { return }
            await self.connect()
        }
    }

    // MARK: - Fallback CoreBluetooth

    private func startFallbackScan() {
        if fallbackCentral == nil {
            fallbackCentral = CBCentralManager(delegate: self, queue: .main)
        } else if fallbackCentral?.state == .poweredOn {
            fallbackCentral?.scanForPeripherals(
                withServices: [Self.teslaServiceUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        }
    }
}

extension TeslaBLEService: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            guard central.state == .poweredOn else {
                if central.state == .poweredOff || central.state == .unauthorized {
                    connectionStatus = .error("Bluetooth kullanılamıyor")
                }
                return
            }
            if connectionStatus == .scanning || isPairingInProgress {
                central.scanForPeripherals(
                    withServices: [Self.teslaServiceUUID],
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
                )
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            let name = peripheral.name
                ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
            guard let name else { return }

            let hint = vin.map(VINHelper.bleNameHint(for:))
            let upper = name.uppercased()
            let matches = upper.contains("TESLA")
                || (hint.map { upper.contains($0) } ?? false)
                || (vin.map { upper.contains($0) } ?? false)
            guard matches else { return }

            discoveredName = name
            central.stopScan()
            fallbackPeripheral = peripheral
            peripheral.delegate = self
            connectionStatus = .connecting
            central.connect(peripheral, options: nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectionStatus = .connected
            if isPairingInProgress {
                try? await completeAddKey()
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            lastError = error?.localizedDescription ?? "Bağlantı başarısız"
            connectionStatus = .error(lastError ?? "Bağlantı hatası")
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            connectionStatus = .disconnected
            scheduleReconnect()
        }
    }
}

extension TeslaBLEService: CBPeripheralDelegate {}

enum BLEServiceError: LocalizedError {
    case missingVIN
    case notConnected

    var errorDescription: String? {
        switch self {
        case .missingVIN: return "VIN gerekli"
        case .notConnected: return "Araç bağlı değil"
        }
    }
}
