import Foundation
import CoreBluetooth
import CryptoKit
import UIKit

/// Polls vehicle telemetry on an open Tesla BLE GATT link.
/// Reliability first (withResponse) + event-driven poll after each reply for speed.
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
    /// Soft recovery exhausted — ask pairer to bounce GATT.
    var onNeedGATTReconnect: (() -> Void)?

    private(set) var attachedPeripheralId: UUID?

    private let uiPushIntervalSeconds: TimeInterval = 0.06

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
    private var lastLiveDataAt = Date.distantPast
    private var pollIndex = 0
    private var handshakeTries = 0
    /// Always withResponse — withoutResponse desynced counters and killed data after a while.
    private let useWithoutResponse = false
    private var handshakeCooldownUntil = Date.distantPast
    private var lastTagFailAt = Date.distantPast
    private var stallRecoveryAt = Date.distantPast
    private var stallRecoveries = 0
    var pollIntervalSeconds: TimeInterval = 0.05
    private let maxInFlight = 1

    /// Drive/GPS heavy — speed feels live; secondary fields update slower.
    private let pollActions: [() -> Data] = [
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetDrive,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetLocation,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetDrive,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetMedia,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetCharge,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetTire,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetClimate,
        TeslaBLESession.actionGetDriveAndLocation,
        TeslaBLESession.actionGetClosures,
        TeslaBLESession.actionGetDriveAndLocation,
    ]

    func attach(
        vin: String,
        privateKey: P256.KeyAgreement.PrivateKey,
        peripheral: CBPeripheral,
        writeChar: CBCharacteristic
    ) {
        detachKeepingCallbacks()
        self.vin = vin.uppercased()
        self.peripheral = peripheral
        self.writeChar = writeChar
        self.attachedPeripheralId = peripheral.identifier
        self.session = TeslaBLESession(vin: vin, privateKey: privateKey)
        rxBuffer.reset()
        writeQueue.removeAll()
        writing = false
        inFlight = 0
        handshakeTries = 0
        stallRecoveries = 0
        liveOK = false
        phase = .handshake
        status = "BLE handshake…"
        lastNotifyAt = Date()
        lastLiveDataAt = .distantPast
        notify(force: true)
        startPolling()
        sendHandshake()
    }

    func detach() {
        onUpdate = nil
        onNeedGATTReconnect = nil
        detachKeepingCallbacks()
    }

    private func detachKeepingCallbacks() {
        pollTimer?.invalidate()
        pollTimer = nil
        session = nil
        peripheral = nil
        writeChar = nil
        attachedPeripheralId = nil
        writeQueue.removeAll()
        writing = false
        inFlight = 0
        liveOK = false
        phase = .idle
        status = "BLE telemetri kapali"
    }

    func onNotify(_ data: Data) {
        guard session != nil else { return }
        var gotLiveFrame = false
        for frame in rxBuffer.append(data) {
            guard let session else { continue }
            _ = session.handleIncoming(frame)
            status = session.statusText
            if session.lastSessionTagInvalid || session.lastDecryptFailed {
                handleCryptoFailure(session, reason: session.lastDecryptFailed ? "decrypt" : "tag")
            } else if session.infotainmentReady {
                phase = .live
                if session.hasVehicleData {
                    liveOK = true
                    stallRecoveries = 0
                    status = "BLE LIVE"
                    snapshot = session.snapshot
                    lastLiveDataAt = Date()
                    gotLiveFrame = true
                } else if !liveOK {
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
        // Event-driven next poll — much faster than waiting for timer alone.
        if inFlight == 0, writeQueue.isEmpty, (gotLiveFrame || phase == .live || phase == .handshake) {
            DispatchQueue.main.async { [weak self] in self?.tick() }
        }
    }

    private func handleCryptoFailure(_ session: TeslaBLESession, reason: String) {
        liveOK = false
        phase = .handshake
        status = reason == "decrypt"
            ? "Decrypt fail — oturum yenileniyor…"
            : "Session tag gecersiz — yeniden handshake…"
        let now = Date()
        if now.timeIntervalSince(lastTagFailAt) > 1.2 {
            lastTagFailAt = now
            session.resetAllDomains()
            writeQueue.removeAll()
            writing = false
            inFlight = 0
            handshakeCooldownUntil = now.addingTimeInterval(0.35)
            stallRecoveries += 1
            if stallRecoveries >= 3 {
                stallRecoveries = 0
                status = "Oturum kilitlendi — GATT yenileniyor…"
                notify(force: true)
                onNeedGATTReconnect?()
            }
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
        pollIntervalSeconds = max(0.04, min(3.0, seconds))
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
        guard let session, let peripheral, peripheral.state == .connected else { return }

        if writing, Date().timeIntervalSince(writeStarted) > 1.4 {
            writing = false
            writeQueue.removeAll()
        }
        if inFlight > 0, Date().timeIntervalSince(lastNotifyAt) > 2.2 {
            inFlight = 0
            writing = false
            writeQueue.removeAll()
        }

        // LIVE stall → soft re-handshake; after repeats request GATT bounce.
        if liveOK, Date().timeIntervalSince(lastLiveDataAt) > 4.0,
           Date().timeIntervalSince(stallRecoveryAt) > 5.0 {
            stallRecoveryAt = Date()
            stallRecoveries += 1
            liveOK = false
            phase = .handshake
            session.resetDomain(.infotainment)
            status = "Veri durdu — oturum yenileniyor…"
            writeQueue.removeAll()
            writing = false
            inFlight = 0
            handshakeCooldownUntil = Date()
            notify(force: true)
            if stallRecoveries >= 3 {
                stallRecoveries = 0
                status = "Veri yok — GATT yenileniyor…"
                onNeedGATTReconnect?()
                return
            }
        }

        if writing || !writeQueue.isEmpty { return }
        if inFlight >= maxInFlight { return }

        if !session.infotainmentReady {
            if Date() < handshakeCooldownUntil { return }
            handshakeTries += 1
            if handshakeTries % 8 == 0, inFlight == 0, writeQueue.isEmpty {
                enqueueCommand(domain: .vcsec, command: TeslaBLESession.actionWake(), preferHandshakeFirst: true)
                handshakeCooldownUntil = Date().addingTimeInterval(0.5)
                return
            }
            sendHandshake()
            handshakeCooldownUntil = Date().addingTimeInterval(0.28)
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
        let writeType: CBCharacteristicWriteType = .withResponse
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
        peripheral.writeValue(chunk, for: writeChar, type: .withResponse)
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
        if !force, now.timeIntervalSince(lastUIPush) < uiPushIntervalSeconds { return }
        lastUIPush = now
        if Thread.isMainThread {
            onUpdate?()
        } else {
            DispatchQueue.main.async { [weak self] in self?.onUpdate?() }
        }
    }
}
