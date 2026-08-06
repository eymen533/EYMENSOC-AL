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

    /// Push HUD ASAP when speed changes; otherwise light throttle.
    private let uiPushIntervalSeconds: TimeInterval = 0.018

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
    private var lastPublishedSpeed: Double = -1
    private var lastPublishedSpeedInt: Int = -1
    private var pollIndex = 0
    private var handshakeTries = 0
    /// Always withResponse — withoutResponse desynced counters and killed data after a while.
    private let useWithoutResponse = false
    private var handshakeCooldownUntil = Date.distantPast
    private var lastTagFailAt = Date.distantPast
    private var stallRecoveryAt = Date.distantPast
    private var stallRecoveries = 0
    /// Quiet crypto nudge before a declared stall (no HUD flip, no WARN spam).
    private var quietNudgeAt = Date.distantPast
    private var lastHeartbeatLogAt = Date.distantPast
    private var orphanStreak = 0
    var pollIntervalSeconds: TimeInterval = 0.035
    private let maxInFlight = 1

    /// Nearly pure Drive poll — speed tracks the car like the dash.

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
        quietNudgeAt = .distantPast
        lastHeartbeatLogAt = .distantPast
        orphanStreak = 0
        liveOK = false
        lastPublishedSpeed = -1
        lastPublishedSpeedInt = -1
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
        var speedMoved = false
        for frame in rxBuffer.append(data) {
            guard let session else { continue }
            _ = session.handleIncoming(frame)
            status = session.statusText
            if session.lastSessionTagInvalid {
                handleCryptoFailure(session, reason: "tag")
            } else if session.lastDecryptFailed {
                // Hard decrypt streak — soft re-handshake, don't spam GATT.
                handleCryptoFailure(session, reason: "decrypt")
            } else if session.lastDecryptWasOrphan {
                // Late reply for an older request — ignore; keep LIVE if we already have data.
                orphanStreak += 1
                if session.hasVehicleData {
                    liveOK = true
                    phase = .live
                    status = "BLE LIVE"
                }
                // Orphan flood usually means counter desync (large Location/Charge) —
                // quiet reset before a full stall declaration.
                if orphanStreak >= 10, Date().timeIntervalSince(lastLiveDataAt) > 2.0 {
                    softRecoverInfotainment(
                        session,
                        reason: "orphan-streak",
                        declareStall: false,
                        flipLiveOff: false
                    )
                }
            } else if session.infotainmentReady {
                phase = .live
                if session.hasVehicleData {
                    liveOK = true
                    stallRecoveries = 0
                    orphanStreak = 0
                    let bat = Int(session.snapshot.batteryPercent.rounded())
                    let rng = session.snapshot.rangeKm
                    let dest = session.snapshot.routeActive
                    let temp = session.snapshot.outdoorC
                    let tempMark = session.snapshot.outdoorValid ? "\(temp)°" : "--°"
                    // First LIVE, bat/temp arrival, or ~10s heartbeat (matches diag screen cadence).
                    let batArrived = bat > 0 && Int(snapshot.batteryPercent.rounded()) == 0
                    let tempArrived = session.snapshot.outdoorValid && !snapshot.outdoorValid
                    let firstLive = lastHeartbeatLogAt == .distantPast
                    let heartbeatDue = Date().timeIntervalSince(lastHeartbeatLogAt) >= 10.0
                    if firstLive || batArrived || tempArrived || heartbeatDue {
                        lastHeartbeatLogAt = Date()
                        PulseDiagLog.shared.info(
                            "BLE LIVE · bat=\(bat)% rng=\(rng)km route=\(dest ? "on" : "off") temp=\(tempMark)"
                        )
                    }
                    // Surface Charge/Climate parse hints (empty fields / denied).
                    let st = session.statusText
                    if st.contains("Charge fields") || st.contains("Climate fields") || st.hasPrefix("BLE:") {
                        PulseDiagLog.shared.warn(st)
                    }
                    status = "BLE LIVE"
                    let next = session.snapshot
                    let speedInt = Int(abs(next.speedKmh).rounded())
                    if lastPublishedSpeedInt >= 0, speedInt != lastPublishedSpeedInt {
                        speedMoved = true
                    } else if lastPublishedSpeed >= 0, abs(next.speedKmh - lastPublishedSpeed) >= 0.2 {
                        speedMoved = true
                    }
                    lastPublishedSpeed = next.speedKmh
                    lastPublishedSpeedInt = speedInt
                    snapshot = next
                    lastLiveDataAt = Date()
                    gotLiveFrame = true
                    if !speedMoved { speedMoved = true }
                } else if !liveOK {
                    status = "BLE oturum OK — araç verisi…"
                }
            } else if session.statusText.contains("whitelist") || session.statusText.contains("kart") {
                phase = .waitingKey
                liveOK = false
            }
            inFlight = max(0, inFlight - 1)
            lastNotifyAt = Date()
            notify(force: speedMoved)
        }
        // Slight delay before next poll — reduces late-reply decrypt races.
        if inFlight == 0, writeQueue.isEmpty, (gotLiveFrame || phase == .live || phase == .handshake) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.055) { [weak self] in
                self?.tick()
            }
        }
    }

    private func handleCryptoFailure(_ session: TeslaBLESession, reason: String) {
        let now = Date()
        // Debounce — do not flip LIVE off / reset on every orphan decrypt.
        guard now.timeIntervalSince(lastTagFailAt) > 2.5 else { return }
        lastTagFailAt = now

        let msg = reason == "decrypt"
            ? "Decrypt fail — soft handshake…"
            : "Session tag gecersiz — soft handshake…"
        PulseDiagLog.shared.warn(msg)

        // Soft: reset only infotainment crypto, keep VCSEC, keep last snapshot in HUD.
        // Keep liveOK so the dial does not flicker on a single crypto blip.
        softRecoverInfotainment(
            session,
            reason: reason,
            declareStall: false,
            flipLiveOff: false,
            statusOverride: msg
        )
        // Don't count soft decrypt as a hard stall unless live data is already stale.
        if Date().timeIntervalSince(lastLiveDataAt) > 4 {
            stallRecoveries += 1
        }

        if stallRecoveries >= 5 {
            stallRecoveries = 0
            liveOK = false
            status = "Oturum kilitlendi — GATT yenileniyor…"
            PulseDiagLog.shared.error(status)
            onNeedGATTReconnect?()
        }
    }

    /// Reset infotainment crypto and clear the write pipeline without dropping the GATT link.
    private func softRecoverInfotainment(
        _ session: TeslaBLESession,
        reason: String,
        declareStall: Bool,
        flipLiveOff: Bool,
        statusOverride: String? = nil
    ) {
        let now = Date()
        guard now.timeIntervalSince(stallRecoveryAt) > 2.0 || declareStall else { return }
        stallRecoveryAt = now
        quietNudgeAt = now
        orphanStreak = 0
        if flipLiveOff { liveOK = false }
        phase = .handshake
        session.resetDomain(.infotainment)
        writeQueue.removeAll()
        writing = false
        inFlight = 0
        handshakeCooldownUntil = now.addingTimeInterval(declareStall ? 0.05 : 0.2)
        if let statusOverride {
            status = statusOverride
        } else if declareStall {
            status = "Veri durdu — oturum yenileniyor…"
        } else {
            // Keep BLE LIVE label in pairer while crypto rebuilds underneath.
            status = liveOK ? "BLE LIVE" : "BLE handshake…"
        }
        if declareStall {
            PulseDiagLog.shared.warn("\(status) (stall #\(stallRecoveries)) [\(reason)]")
        } else if reason == "orphan-streak" || reason == "quiet-nudge" {
            PulseDiagLog.shared.ble("soft recover · \(reason)")
        }
        notify(force: true)
    }

    func setVolume(_ level: Double) {
        // Never interrupt an in-flight telemetry round-trip (desyncs AES tags).
        guard inFlight == 0, writeQueue.isEmpty else { return }
        guard let session, session.infotainmentReady else { return }
        let v = Float(min(1, max(0, level)) * 11.0)
        enqueueCommand(domain: .infotainment, command: TeslaBLESession.actionSetVolume(v))
    }

    func mediaNext() { enqueueMedia(TeslaBLESession.actionMediaNext()) }
    func mediaPrev() { enqueueMedia(TeslaBLESession.actionMediaPrev()) }
    func mediaPlay() { enqueueMedia(TeslaBLESession.actionMediaPlay()) }

    private func enqueueMedia(_ command: Data) {
        guard inFlight == 0, writeQueue.isEmpty else { return }
        enqueueCommand(domain: .infotainment, command: command)
    }

    func applyPollInterval(_ seconds: TimeInterval) {
        pollIntervalSeconds = max(0.03, min(3.0, seconds))
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

        if writing, Date().timeIntervalSince(writeStarted) > 1.1 {
            writing = false
            writeQueue.removeAll()
        }
        if inFlight > 0, Date().timeIntervalSince(lastNotifyAt) > 3.2 {
            inFlight = 0
            writing = false
            writeQueue.removeAll()
        }

        let silence = Date().timeIntervalSince(lastLiveDataAt)

        // Quiet nudge before a declared stall — rebuild crypto, keep LIVE HUD.
        if liveOK, silence > 3.8, silence < 7.5,
           Date().timeIntervalSince(quietNudgeAt) > 4.5 {
            softRecoverInfotainment(
                session,
                reason: "quiet-nudge",
                declareStall: false,
                flipLiveOff: false
            )
        }

        // Declared stall → soft re-handshake; keep liveOK on early stalls (no HUD flicker).
        if liveOK, silence > 7.5,
           Date().timeIntervalSince(stallRecoveryAt) > 5.0 {
            stallRecoveries += 1
            let flip = stallRecoveries >= 3
            softRecoverInfotainment(
                session,
                reason: String(format: "silence=%.1fs", silence),
                declareStall: true,
                flipLiveOff: flip
            )
            if stallRecoveries >= 4 {
                stallRecoveries = 0
                liveOK = false
                status = "Veri yok — GATT yenileniyor…"
                PulseDiagLog.shared.error(status)
                onNeedGATTReconnect?()
                return
            }
        }

        if writing || !writeQueue.isEmpty { return }
        if inFlight >= maxInFlight { return }

        if !session.infotainmentReady {
            if Date() < handshakeCooldownUntil { return }
            handshakeTries += 1
            // Every few tries: VCSEC handshake + real wake (car may be asleep).
            if handshakeTries % 6 == 0, inFlight == 0, writeQueue.isEmpty {
                if session.isReady(.vcsec) {
                    enqueueCommand(domain: .vcsec, command: TeslaBLESession.actionWake())
                } else {
                    let (_, hs) = session.handshakeRequest(domain: .vcsec)
                    enqueueFrame(hs)
                }
                handshakeCooldownUntil = Date().addingTimeInterval(0.4)
                return
            }
            sendHandshake()
            handshakeCooldownUntil = Date().addingTimeInterval(0.22)
            return
        }

        let action = nextPollAction()
        enqueueCommand(domain: .infotainment, command: action)
    }

    /// One StateCategory per request — Tesla rejects multi-category GetVehicleData.
    /// Drive-heavy; Charge/Climate less often so large replies don't desync AES tags.
    private func nextPollAction() -> Data {
        pollIndex += 1
        let i = pollIndex
        // Drive-heavy; Location sparse enough to avoid AES orphan stalls on route=on.
        if i % 10 == 3 { return TeslaBLESession.actionGetCharge() }
        if i % 12 == 5 { return TeslaBLESession.actionGetClimate() }
        // ~every 6th poll → Location (ble-84 was every 4th — still stalled with route active).
        if i % 6 == 1 { return TeslaBLESession.actionGetLocation() }
        if i % 15 == 0 { return TeslaBLESession.actionGetClosures() }
        if i % 22 == 0 { return TeslaBLESession.actionGetMedia() }
        if i % 28 == 0 { return TeslaBLESession.actionGetMediaDetail() }
        if i % 35 == 0 { return TeslaBLESession.actionGetTire() }
        return TeslaBLESession.actionGetDrive()
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
