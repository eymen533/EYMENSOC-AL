import Foundation
import CoreBluetooth
import CryptoKit

/// Polls vehicle telemetry on an open Tesla BLE GATT link.
/// Pipelines requests (does not wait for each notify) for Dashla-like speed.
final class BLETelemetry {
    enum Phase: String {
        case idle = "idle"
        case handshake = "handshake"
        case live = "BLE LIVE"
        case waitingKey = "kart bekle"
        case error = "hata"
    }

    private(set) var phase: Phase = .idle
    private(set) var status = "BLE telemetri kapali"
    private(set) var snapshot = VehicleLiveSnapshot()
    private(set) var liveOK = false

    /// Fired on main when snapshot / phase changes.
    var onUpdate: (() -> Void)?

    private var session: TeslaBLESession?
    private var vin = ""
    private weak var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private let rxBuffer = BLEFrameBuffer()
    private var pollTimer: Timer?
    private var writeQueue: [Data] = []
    private var writing = false
    private var inFlight = 0
    private var lastNotifyAt = Date.distantPast
    private var pollIndex = 0
    private var handshakeTries = 0
    private var useWithoutResponse = false
    /// Seconds between BLE polls. Performance ≈ 0.10, Low ≈ 0.45
    var pollIntervalSeconds: TimeInterval = 0.10
    /// Max overlapping requests before we pause (avoids flooding).
    private let maxInFlight = 2

    /// Drive+Location dominate; occasional media/charge/tire/climate.
    private let pollActions: [() -> Data] = [
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetDrive,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetMedia,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetCharge,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetTire,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetClimate,
    ]

    func attach(
        vin: String,
        privateKey: P256.KeyAgreement.PrivateKey,
        peripheral: CBPeripheral,
        writeChar: CBCharacteristic
    ) {
        detach()
        self.vin = vin.uppercased()
        self.peripheral = peripheral
        self.writeChar = writeChar
        self.session = TeslaBLESession(vin: vin, privateKey: privateKey)
        self.useWithoutResponse = writeChar.properties.contains(.writeWithoutResponse)
        rxBuffer.reset()
        writeQueue.removeAll()
        writing = false
        inFlight = 0
        handshakeTries = 0
        liveOK = false
        phase = .handshake
        status = "BLE handshake…"
        notify()
        startPolling()
        sendHandshake()
    }

    func detach() {
        pollTimer?.invalidate()
        pollTimer = nil
        session = nil
        peripheral = nil
        writeChar = nil
        writeQueue.removeAll()
        writing = false
        inFlight = 0
        liveOK = false
        phase = .idle
        status = "BLE telemetri kapali"
    }

    func onNotify(_ data: Data) {
        guard session != nil else { return }
        for frame in rxBuffer.append(data) {
            guard let session else { continue }
            _ = session.handleIncoming(frame)
            status = session.statusText
            if session.infotainmentReady {
                phase = .live
                if session.hasVehicleData {
                    liveOK = true
                    status = "BLE LIVE"
                    snapshot = session.snapshot
                } else {
                    status = "BLE oturum OK — araç verisi…"
                }
            } else if session.statusText.contains("whitelist") || session.statusText.contains("kart") {
                phase = .waitingKey
                liveOK = false
            }
            inFlight = max(0, inFlight - 1)
            notify()
        }
    }

    func setVolume(_ level: Double) {
        guard let session, session.infotainmentReady else { return }
        let v = Float(min(1, max(0, level)) * 11.0)
        enqueueCommand(domain: .infotainment, command: TeslaBLESession.actionSetVolume(v))
    }

    func mediaNext() { enqueueCommand(domain: .infotainment, command: TeslaBLESession.actionMediaNext()) }
    func mediaPrev() { enqueueCommand(domain: .infotainment, command: TeslaBLESession.actionMediaPrev()) }
    func mediaPlay() { enqueueCommand(domain: .infotainment, command: TeslaBLESession.actionMediaPlay()) }

    func applyPollInterval(_ seconds: TimeInterval) {
        pollIntervalSeconds = max(0.08, min(3.0, seconds))
        if pollTimer != nil { startPolling() }
    }

    private func startPolling() {
        pollTimer?.invalidate()
        let t = Timer(timeInterval: pollIntervalSeconds, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    private func tick() {
        guard session != nil, peripheral?.state == .connected else { return }
        // Pipeline: only pause if writes busy or too many unanswered.
        if writing || !writeQueue.isEmpty { return }
        if inFlight >= maxInFlight { return }
        guard let session else { return }

        if !session.infotainmentReady {
            handshakeTries += 1
            if handshakeTries % 4 == 0 {
                enqueueCommand(domain: .vcsec, command: TeslaBLESession.actionWake(), preferHandshakeFirst: true)
            }
            sendHandshake()
            return
        }

        let action = pollActions[pollIndex % pollActions.count]()
        pollIndex += 1
        enqueueCommand(domain: .infotainment, command: action)
    }

    private func sendHandshake() {
        guard let session else { return }
        let (_, frame) = session.handshakeRequest(domain: .infotainment)
        status = "BLE handshake…"
        if phase != .waitingKey { phase = .handshake }
        notify()
        enqueueFrame(frame)
    }

    private func enqueueCommand(
        domain: TeslaBLESession.Domain,
        command: Data,
        preferHandshakeFirst: Bool = false
    ) {
        guard let session else { return }
        if preferHandshakeFirst {
            let (_, hs) = session.handshakeRequest(domain: domain)
            enqueueFrame(hs)
            return
        }
        do {
            let frame = try session.encryptCommand(domain: domain, command: command)
            enqueueFrame(frame)
        } catch {
            let (_, hs) = session.handshakeRequest(domain: domain)
            enqueueFrame(hs)
        }
    }

    private func enqueueFrame(_ frame: Data) {
        guard let peripheral, let writeChar else { return }
        guard peripheral.state == .connected else { return }
        let writeType: CBCharacteristicWriteType = useWithoutResponse ? .withoutResponse : .withResponse
        let mtu = max(20, peripheral.maximumWriteValueLength(for: writeType))
        var i = 0
        while i < frame.count {
            let j = min(i + mtu, frame.count)
            writeQueue.append(frame.subdata(in: i..<j))
            i = j
        }
        inFlight += 1
        pumpWrite()
    }

    private func pumpWrite() {
        guard !writing, let peripheral, let writeChar else { return }
        guard peripheral.state == .connected else { return }
        guard !writeQueue.isEmpty else { return }
        writing = true
        let chunk = writeQueue.removeFirst()
        let type: CBCharacteristicWriteType = useWithoutResponse ? .withoutResponse : .withResponse
        peripheral.writeValue(chunk, for: writeChar, type: type)
        if useWithoutResponse {
            // didWrite is not called for withoutResponse — continue immediately.
            writing = false
            if writeQueue.isEmpty {
                // Small yield so radio can breathe; next timer tick continues.
            } else {
                DispatchQueue.main.async { [weak self] in self?.pumpWrite() }
            }
        }
    }

    func didWrite(error: Error?) {
        writing = false
        if let error {
            status = "BLE yazma: \(error.localizedDescription)"
            phase = .error
            writeQueue.removeAll()
            inFlight = 0
            notify()
            return
        }
        pumpWrite()
    }

    private func notify() {
        if Thread.isMainThread {
            onUpdate?()
        } else {
            DispatchQueue.main.async { [weak self] in self?.onUpdate?() }
        }
    }
}
