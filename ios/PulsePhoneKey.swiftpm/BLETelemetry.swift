import Foundation
import CoreBluetooth
import CryptoKit

/// Polls real vehicle telemetry over an already-open Tesla BLE GATT link.
@MainActor
final class BLETelemetry: ObservableObject {
    enum Phase: String {
        case idle = "idle"
        case handshake = "handshake"
        case live = "BLE LIVE"
        case waitingKey = "kart bekle"
        case error = "hata"
    }

    @Published var phase: Phase = .idle
    @Published var status = "BLE telemetri kapali"
    @Published var snapshot = TeslaBLESession.Snapshot()
    @Published var liveOK = false

    private var session: TeslaBLESession?
    private var vin = ""
    private weak var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private let rxBuffer = BLEFrameBuffer()
    private var pollTimer: Timer?
    private var writeQueue: [Data] = []
    private var writing = false
    private var awaiting = false
    private var pollIndex = 0
    private var handshakeTries = 0
    private var lastRX = Date.distantPast

    private let pollActions: [() -> Data] = [
        TeslaBLESession.actionGetDrive,
        TeslaBLESession.actionGetCharge,
        TeslaBLESession.actionGetTire,
        TeslaBLESession.actionGetMedia,
        TeslaBLESession.actionGetLocation,
        TeslaBLESession.actionGetClimate,
    ]

    func attach(
        vin: String,
        privateKey: P256.KeyAgreement.PrivateKey,
        peripheral: CBPeripheral,
        writeChar: CBCharacteristic
    ) {
        self.vin = vin.uppercased()
        self.peripheral = peripheral
        self.writeChar = writeChar
        self.session = TeslaBLESession(vin: vin, privateKey: privateKey)
        rxBuffer.reset()
        writeQueue.removeAll()
        writing = false
        awaiting = false
        handshakeTries = 0
        liveOK = false
        phase = .handshake
        status = "BLE handshake…"
        startPolling()
        sendHandshake()
    }

    func detach() {
        pollTimer?.invalidate()
        pollTimer = nil
        session = nil
        peripheral = nil
        writeChar = nil
        liveOK = false
        phase = .idle
        status = "BLE telemetri kapali"
    }

    func onNotify(_ data: Data) {
        lastRX = Date()
        for frame in rxBuffer.append(data) {
            guard let session else { continue }
            let ok = session.handleIncoming(frame)
            status = session.statusText
            if session.infotainmentReady {
                if phase != .live {
                    phase = .live
                    liveOK = true
                    status = "BLE LIVE"
                }
                snapshot = session.snapshot
            } else if session.statusText.contains("whitelist") || session.statusText.contains("kart") {
                phase = .waitingKey
                liveOK = false
            } else if ok {
                snapshot = session.snapshot
                liveOK = true
                phase = .live
            }
            awaiting = false
        }
    }

    func setVolume(_ level: Double) {
        guard let session, session.infotainmentReady else { return }
        let v = Float(min(1, max(0, level)) * 11.0)
        enqueueCommand(domain: .infotainment, command: TeslaBLESession.actionSetVolume(v))
    }

    func volumeDelta(_ step: Int) {
        guard session?.infotainmentReady == true else { return }
        let d = Int32(step >= 0 ? 1 : -1)
        enqueueCommand(domain: .infotainment, command: TeslaBLESession.actionVolumeDelta(d))
    }

    func mediaNext() { enqueueCommand(domain: .infotainment, command: TeslaBLESession.actionMediaNext()) }
    func mediaPrev() { enqueueCommand(domain: .infotainment, command: TeslaBLESession.actionMediaPrev()) }
    func mediaPlay() { enqueueCommand(domain: .infotainment, command: TeslaBLESession.actionMediaPlay()) }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard session != nil, peripheral?.state == .connected else { return }
        if writing || awaiting { return }
        guard let session else { return }

        if !session.infotainmentReady {
            handshakeTries += 1
            if handshakeTries % 4 == 0 {
                // Try wake VCSEC then re-handshake infotainment
                enqueueCommand(domain: .vcsec, command: TeslaBLESession.actionWake(), isPlainUnsigned: true)
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
        phase = .handshake
        enqueueFrame(frame)
    }

    /// VCSEC wake uses unsigned message bytes as protobuf_message_as_bytes but still needs AES once VCSEC session ready.
    /// Bootstrap: first try encrypted if VCSEC session ready; else send a VCSEC handshake.
    private func enqueueCommand(
        domain: TeslaBLESession.Domain,
        command: Data,
        isPlainUnsigned: Bool = false
    ) {
        guard let session else { return }
        if domain == .vcsec && !session.infotainmentReady {
            // Prefer VCSEC handshake then wake
            if isPlainUnsigned {
                let (_, hs) = session.handshakeRequest(domain: .vcsec)
                enqueueFrame(hs)
            }
        }
        do {
            // Ensure domain session: if encrypt fails, handshake that domain
            let frame = try session.encryptCommand(domain: domain, command: command)
            enqueueFrame(frame)
        } catch {
            let (_, hs) = session.handshakeRequest(domain: domain)
            enqueueFrame(hs)
        }
    }

    private func enqueueFrame(_ frame: Data) {
        guard let peripheral, let writeChar else { return }
        let mtu = max(20, peripheral.maximumWriteValueLength(for: .withResponse))
        var i = 0
        while i < frame.count {
            let j = min(i + mtu, frame.count)
            writeQueue.append(frame.subdata(in: i..<j))
            i = j
        }
        awaiting = true
        pumpWrite()
    }

    private func pumpWrite() {
        guard !writing, let peripheral, let writeChar else { return }
        guard peripheral.state == .connected else { return }
        guard !writeQueue.isEmpty else { return }
        writing = true
        let chunk = writeQueue.removeFirst()
        peripheral.writeValue(chunk, for: writeChar, type: .withResponse)
    }

    func didWrite(error: Error?) {
        writing = false
        if let error {
            status = "BLE yazma: \(error.localizedDescription)"
            phase = .error
            writeQueue.removeAll()
            awaiting = false
            return
        }
        pumpWrite()
    }
}
