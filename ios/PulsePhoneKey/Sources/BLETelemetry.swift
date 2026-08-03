import Foundation
import CoreBluetooth
import CryptoKit

/// Polls vehicle telemetry on an open Tesla BLE GATT link.
/// Stable pipeline — avoids flooding that freezes the GATT link after a while.
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

    /// Fired on main when snapshot / phase changes (throttled).
    var onUpdate: (() -> Void)?

    private var session: TeslaBLESession?
    private var vin = ""
    private weak var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private let rxBuffer = BLEFrameBuffer()
    private var pollTimer: Timer?
    private var writeQueue: [Data] = []
    private var writing = false
    private var writeStarted = Date.distantPast
    private var inFlight = 0
    private var lastNotifyAt = Date.distantPast
    private var lastUIPush = Date.distantPast
    private var pollIndex = 0
    private var handshakeTries = 0
    private var useWithoutResponse = false
    /// Performance ≈ 0.14s — fast but not radio-flooding.
    var pollIntervalSeconds: TimeInterval = 0.14
    private let maxInFlight = 1

    private let pollActions: [() -> Data] = [
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetDrive,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetMedia,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetCharge,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetTire,
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
        // Prefer withResponse for stability — withoutResponse floods freeze many phones.
        self.useWithoutResponse = false
        rxBuffer.reset()
        writeQueue.removeAll()
        writing = false
        inFlight = 0
        handshakeTries = 0
        liveOK = false
        phase = .handshake
        status = "BLE handshake…"
        notify(force: true)
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
            lastNotifyAt = Date()
            notify(force: false)
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
        pollIntervalSeconds = max(0.12, min(3.0, seconds))
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

        // Recover stuck write / unanswered requests (prevents permanent freeze).
        if writing, Date().timeIntervalSince(writeStarted) > 1.0 {
            writing = false
            writeQueue.removeAll()
        }
        if inFlight > 0, Date().timeIntervalSince(lastNotifyAt) > 1.6 {
            inFlight = 0
            writeQueue.removeAll()
            writing = false
        }

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
        notify(force: true)
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
        writeStarted = Date()
        let chunk = writeQueue.removeFirst()
        let type: CBCharacteristicWriteType = useWithoutResponse ? .withoutResponse : .withResponse
        peripheral.writeValue(chunk, for: writeChar, type: type)
        if useWithoutResponse {
            writing = false
            if !writeQueue.isEmpty {
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
            notify(force: true)
            return
        }
        pumpWrite()
    }

    private func notify(force: Bool) {
        let now = Date()
        // Throttle UI to ~7Hz — constant @Published storms freeze SwiftUI/MapKit.
        if !force, now.timeIntervalSince(lastUIPush) < 0.14 { return }
        lastUIPush = now
        if Thread.isMainThread {
            onUpdate?()
        } else {
            DispatchQueue.main.async { [weak self] in self?.onUpdate?() }
        }
    }
}
