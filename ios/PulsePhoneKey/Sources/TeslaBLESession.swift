import Foundation
import CryptoKit

/// Real Tesla vehicle-command BLE session (ECDH → AES-GCM personalized).
/// Protocol: https://github.com/teslamotors/vehicle-command/blob/main/pkg/protocol/protocol.md
final class TeslaBLESession {
    enum Domain: UInt64 {
        case vcsec = 2
        case infotainment = 3
    }

    enum Tag: UInt8 {
        case signatureType = 0
        case domain = 1
        case personalization = 2
        case epoch = 3
        case expiresAt = 4
        case counter = 5
        case challenge = 6
        case flags = 7
        case requestHash = 8
        case fault = 9
        case end = 255
    }

    enum SignatureType: UInt8 {
        case aesGcmPersonalized = 5
        case hmac = 6
        case hmacPersonalized = 8
        case aesGcmResponse = 9
    }

    typealias Snapshot = VehicleLiveSnapshot

    private struct DomainState {
        var counter: UInt32 = 0
        var epoch: Data = Data()
        var delta: Int = 0 // wall - vehicleClock
        var sharedKey: SymmetricKey?
        var sessionInfoKey: SymmetricKey?
        var ready = false
        var lastClock: UInt32 = 0
        var whitelistOK = false
    }

    private let vin: String
    private let privateKey: P256.KeyAgreement.PrivateKey
    private let publicKey: Data
    private let routingAddress: Data
    private var domains: [Domain: DomainState] = [
        .vcsec: DomainState(),
        .infotainment: DomainState(),
    ]

    /// Last outbound request tag (for response decrypt request_hash).
    private(set) var lastRequestTag: Data = Data()
    private(set) var lastRequestUUID: Data = Data()
    private(set) var lastRequestDomain: Domain = .infotainment
    private(set) var lastWasAES = false

    var snapshot = Snapshot()
    var infotainmentReady: Bool { isReady(.infotainment) }
    /// True after at least one decrypted VehicleData payload.
    private(set) var hasVehicleData = false
    var statusText: String = "BLE session yok"

    func isReady(_ domain: Domain) -> Bool {
        guard let s = domains[domain] else { return false }
        return s.ready && s.whitelistOK && s.sharedKey != nil
    }

    init(vin: String, privateKey: P256.KeyAgreement.PrivateKey) {
        self.vin = vin.uppercased()
        self.privateKey = privateKey
        self.publicKey = KeyStore.publicKeyUncompressed(privateKey)
        self.routingAddress = Self.randomBytes(16)
    }

    // MARK: - Handshake

    func handshakeRequest(domain: Domain) -> (uuid: Data, frame: Data) {
        let uuid = randomBytes(16)
        lastRequestUUID = uuid
        lastRequestDomain = domain
        lastWasAES = false
        // SessionInfoRequest { public_key = 1 }
        let sir = ProtoWire.fieldBytes(1, publicKey)
        // RoutableMessage
        let toDest = ProtoWire.fieldVarint(1, domain.rawValue) // Destination.domain
        let fromDest = ProtoWire.fieldBytes(2, routingAddress) // Destination.routing_address
        var msg = Data()
        msg.append(ProtoWire.fieldBytes(6, toDest)) // to_destination
        msg.append(ProtoWire.fieldBytes(7, fromDest)) // from_destination
        msg.append(ProtoWire.fieldBytes(14, sir)) // session_info_request
        msg.append(ProtoWire.fieldBytes(51, uuid)) // uuid
        return (uuid, ProtoWire.prependLength(msg))
    }

    @discardableResult
    func handleIncoming(_ frame: Data) -> Bool {
        let fields = ProtoWire.parseFields(frame)
        var sessionInfoBytes: Data?
        var sessionInfoTag: Data?
        var protobufBytes: Data?
        var aesRespNonce: Data?
        var aesRespTag: Data?
        var aesRespCounter: UInt32 = 0
        var hasAESResp = false
        var flags: UInt32 = 0
        var fault: UInt32 = 0
        var fromDomain: Domain = lastRequestDomain
        var requestUUID: Data?

        for f in fields {
            switch f.number {
            case 7: // from_destination
                for sf in ProtoWire.parseFields(f.bytes) where sf.number == 1 {
                    if let d = Domain(rawValue: sf.varint) { fromDomain = d }
                }
            case 10: // protobuf_message_as_bytes
                protobufBytes = f.bytes
            case 12: // signedMessageStatus
                for sf in ProtoWire.parseFields(f.bytes) where sf.number == 2 {
                    fault = UInt32(sf.varint)
                }
            case 13: // signature_data
                for sf in ProtoWire.parseFields(f.bytes) {
                    if sf.number == 6 { // session_info_tag
                        for tf in ProtoWire.parseFields(sf.bytes) where tf.number == 1 {
                            sessionInfoTag = tf.bytes
                        }
                    } else if sf.number == 9 { // AES_GCM_Response_data
                        hasAESResp = true
                        for tf in ProtoWire.parseFields(sf.bytes) {
                            if tf.number == 1 { aesRespNonce = tf.bytes }
                            if tf.number == 2 { aesRespCounter = UInt32(tf.varint) }
                            if tf.number == 3 { aesRespTag = tf.bytes }
                        }
                    }
                }
            case 15: // session_info (bytes)
                sessionInfoBytes = f.bytes
            case 50:
                requestUUID = f.bytes
            case 52:
                flags = UInt32(f.varint)
            default:
                break
            }
        }

        if let info = sessionInfoBytes {
            _ = commitSessionInfo(
                info,
                tag: sessionInfoTag,
                domain: fromDomain,
                challenge: lastRequestUUID
            )
        }

        if fault != 0 {
            statusText = "BLE fault \(fault)"
            // Often includes fresh session_info — already committed above
            return false
        }

        guard var payload = protobufBytes else { return sessionInfoBytes != nil }

        if hasAESResp,
           let nonce = aesRespNonce,
           let tag = aesRespTag,
           let state = domains[fromDomain],
           let key = state.sharedKey {
            do {
                let plain = try decryptResponse(
                    domain: fromDomain,
                    key: key,
                    nonce: nonce,
                    ciphertext: payload,
                    tag: tag,
                    counter: aesRespCounter,
                    flags: flags,
                    fault: fault
                )
                payload = plain
            } catch {
                statusText = "Decrypt fail"
                return false
            }
        }

        if fromDomain == .infotainment {
            parseInfotainmentResponse(payload)
            hasVehicleData = true
            statusText = "BLE LIVE"
            return true
        }
        return sessionInfoBytes != nil || requestUUID != nil
    }

    private func commitSessionInfo(
        _ infoBytes: Data,
        tag: Data?,
        domain: Domain,
        challenge: Data
    ) -> Bool {
        var counter: UInt32 = 0
        var publicKeyData = Data()
        var epoch = Data()
        var clock: UInt32 = 0
        var status: UInt64 = 0

        for f in ProtoWire.parseFields(infoBytes) {
            switch f.number {
            case 1: counter = UInt32(f.varint)
            case 2: publicKeyData = f.bytes
            case 3: epoch = f.bytes
            case 4: clock = f.fixed32
            case 5: status = f.varint
            default: break
            }
        }
        guard publicKeyData.count == 65, publicKeyData[0] == 0x04, epoch.count == 16 else {
            statusText = "SessionInfo bozuk"
            return false
        }

        guard let vehiclePub = try? P256.KeyAgreement.PublicKey(x963Representation: publicKeyData) else {
            statusText = "Arac pubkey hatali"
            return false
        }
        guard let shared = try? privateKey.sharedSecretFromKeyAgreement(with: vehiclePub) else {
            statusText = "ECDH fail"
            return false
        }
        let sharedKeyData = shared.withUnsafeBytes { buf -> Data in
            let x = Data(buf)
            let digest = Insecure.SHA1.hash(data: x)
            return Data(digest.prefix(16))
        }
        let sharedKey = SymmetricKey(data: sharedKeyData)
        let sessionInfoKey = HMAC<SHA256>.authenticationCode(
            for: Data("session info".utf8),
            using: sharedKey
        )
        let sik = SymmetricKey(data: Data(sessionInfoKey))

        // Authenticate session info tag when present
        if let tag, !tag.isEmpty {
            var meta = Data()
            meta.append(contentsOf: [Tag.signatureType.rawValue, 1, SignatureType.hmac.rawValue])
            let vinData = Data(vin.utf8)
            meta.append(contentsOf: [Tag.personalization.rawValue, UInt8(vinData.count)])
            meta.append(vinData)
            meta.append(contentsOf: [Tag.challenge.rawValue, UInt8(challenge.count)])
            meta.append(challenge)
            meta.append(Tag.end.rawValue)
            let expected = Data(HMAC<SHA256>.authenticationCode(for: meta + infoBytes, using: sik))
            guard constantTimeEqual(expected, tag) else {
                statusText = "Session tag gecersiz"
                return false
            }
        }

        var state = domains[domain] ?? DomainState()
        let sameEpoch = state.epoch == epoch && !state.epoch.isEmpty
        if sameEpoch, clock < state.lastClock {
            return false
        }
        state.counter = sameEpoch ? max(state.counter, counter) : counter
        state.epoch = epoch
        state.delta = Int(Date().timeIntervalSince1970) - Int(clock)
        state.lastClock = clock
        state.sharedKey = sharedKey
        state.sessionInfoKey = sik
        state.whitelistOK = (status == 0) // SESSION_INFO_STATUS_OK
        state.ready = true
        domains[domain] = state

        if status != 0 {
            statusText = "Key whitelist degil — kart konsola"
            return false
        }
        statusText = domain == .infotainment ? "Infotainment OK" : "VCSEC OK"
        return true
    }

    // MARK: - Encrypted command

    /// Returns length-prefixed RoutableMessage for an application protobuf `command`.
    func encryptCommand(domain: Domain, command: Data) throws -> Data {
        guard var state = domains[domain], state.ready, let key = state.sharedKey, state.whitelistOK else {
            throw SessionError.notReady
        }
        state.counter &+= 1
        let counter = state.counter
        let expires = UInt32(Int(Date().timeIntervalSince1970) - state.delta + 30)
        let nonce = randomBytes(12)
        let flags: UInt32 = 1 << 1 // FLAG_ENCRYPT_RESPONSE
        domains[domain] = state

        var meta = Data()
        meta.append(contentsOf: [Tag.signatureType.rawValue, 1, SignatureType.aesGcmPersonalized.rawValue])
        meta.append(contentsOf: [Tag.domain.rawValue, 1, UInt8(domain.rawValue)])
        let vinData = Data(vin.utf8)
        meta.append(contentsOf: [Tag.personalization.rawValue, UInt8(vinData.count)])
        meta.append(vinData)
        meta.append(contentsOf: [Tag.epoch.rawValue, UInt8(state.epoch.count)])
        meta.append(state.epoch)
        meta.append(contentsOf: [Tag.expiresAt.rawValue, 4])
        meta.append(be32(expires))
        meta.append(contentsOf: [Tag.counter.rawValue, 4])
        meta.append(be32(counter))
        meta.append(contentsOf: [Tag.flags.rawValue, 4])
        meta.append(be32(flags))
        meta.append(Tag.end.rawValue)

        let aad = Data(SHA256.hash(data: meta))
        let sealed = try AES.GCM.seal(
            command,
            using: key,
            nonce: try AES.GCM.Nonce(data: nonce),
            authenticating: aad
        )
        let ciphertext = sealed.ciphertext
        let tag = sealed.tag
        lastRequestTag = tag
        lastWasAES = true
        lastRequestDomain = domain

        // AES_GCM_Personalized_Signature_Data
        var aes = Data()
        aes.append(ProtoWire.fieldBytes(1, state.epoch))
        aes.append(ProtoWire.fieldBytes(2, nonce))
        aes.append(ProtoWire.fieldVarint(3, UInt64(counter)))
        aes.append(ProtoWire.fieldFixed32(4, expires))
        aes.append(ProtoWire.fieldBytes(5, tag))

        var signer = ProtoWire.fieldBytes(1, publicKey) // KeyIdentity.public_key
        var sigData = Data()
        sigData.append(ProtoWire.fieldBytes(1, signer)) // signer_identity
        sigData.append(ProtoWire.fieldBytes(5, aes)) // AES_GCM_Personalized_data

        let uuid = randomBytes(16)
        lastRequestUUID = uuid

        let toDest = ProtoWire.fieldVarint(1, domain.rawValue)
        let fromDest = ProtoWire.fieldBytes(2, routingAddress)
        var msg = Data()
        msg.append(ProtoWire.fieldBytes(6, toDest))
        msg.append(ProtoWire.fieldBytes(7, fromDest))
        msg.append(ProtoWire.fieldBytes(10, ciphertext))
        msg.append(ProtoWire.fieldBytes(13, sigData))
        msg.append(ProtoWire.fieldBytes(51, uuid))
        msg.append(ProtoWire.fieldVarint(52, UInt64(flags)))
        return ProtoWire.prependLength(msg)
    }

    private func decryptResponse(
        domain: Domain,
        key: SymmetricKey,
        nonce: Data,
        ciphertext: Data,
        tag: Data,
        counter: UInt32,
        flags: UInt32,
        fault: UInt32
    ) throws -> Data {
        var requestHash = Data([SignatureType.aesGcmPersonalized.rawValue])
        requestHash.append(lastRequestTag)
        if requestHash.count < 17 {
            requestHash.append(Data(count: 17 - requestHash.count))
        } else if requestHash.count > 17 {
            requestHash = Data(requestHash.prefix(17))
        }

        var meta = Data()
        meta.append(contentsOf: [Tag.signatureType.rawValue, 1, SignatureType.aesGcmResponse.rawValue])
        meta.append(contentsOf: [Tag.domain.rawValue, 1, UInt8(domain.rawValue)])
        let vinData = Data(vin.utf8)
        meta.append(contentsOf: [Tag.personalization.rawValue, UInt8(vinData.count)])
        meta.append(vinData)
        meta.append(contentsOf: [Tag.counter.rawValue, 4])
        meta.append(be32(counter))
        meta.append(contentsOf: [Tag.flags.rawValue, 4])
        meta.append(be32(flags))
        meta.append(contentsOf: [Tag.requestHash.rawValue, 17])
        meta.append(requestHash)
        meta.append(contentsOf: [Tag.fault.rawValue, 4])
        meta.append(be32(fault))
        meta.append(Tag.end.rawValue)

        let aad = Data(SHA256.hash(data: meta))
        let box = try AES.GCM.SealedBox(
            nonce: try AES.GCM.Nonce(data: nonce),
            ciphertext: ciphertext,
            tag: tag
        )
        return try AES.GCM.open(box, using: key, authenticating: aad)
    }

    // MARK: - Action payloads (CarServer.Action)

    static func actionGetDrive() -> Data { Data(hex: "12040a022200") }
    static func actionGetCharge() -> Data { Data(hex: "12040a021200") }
    static func actionGetTire() -> Data { Data(hex: "12040a027200") }
    /// GetMediaState (15) + GetMediaDetailState (16) — source string / album.
    static func actionGetMedia() -> Data { Data(hex: "12070a057a00820100") }
    static func actionGetLocation() -> Data { Data(hex: "12040a023a00") }
    static func actionGetClimate() -> Data { Data(hex: "12040a021a00") }
    static func actionWake() -> Data { Data(hex: "101e") } // VCSEC UnsignedMessage RKE wake
    static func actionMediaNext() -> Data { Data(hex: "12039a0100") }
    static func actionMediaPrev() -> Data { Data(hex: "1203a20100") }
    static func actionMediaPlay() -> Data { Data(hex: "12027a00") }

    /// Absolute media volume 0…11 (Tesla vehicle-command scale).
    static func actionSetVolume(_ absolute: Float) -> Data {
        var bits = absolute.bitPattern.littleEndian
        let floatBytes = Data(bytes: &bits, count: 4)
        let vol = Data([0x1d]) + floatBytes // field 3 fixed32 float
        let vaInner = Data([0x82, 0x01]) + ProtoWire.encodeVarint(UInt64(vol.count)) + vol
        return ProtoWire.fieldBytes(2, vaInner)
    }

    /// Volume step (±1) via MediaUpdateVolume.volume_delta (protobuf sint32).
    static func actionVolumeDelta(_ delta: Int32) -> Data {
        let zig = UInt32(bitPattern: (delta << 1) ^ (delta >> 31))
        let vol = ProtoWire.fieldVarint(1, UInt64(zig))
        let vaInner = Data([0x82, 0x01]) + ProtoWire.encodeVarint(UInt64(vol.count)) + vol
        return ProtoWire.fieldBytes(2, vaInner)
    }

    // MARK: - Parse VehicleData / Response

    private func parseInfotainmentResponse(_ data: Data) {
        // car_server.Response field 2 = vehicleData
        for f in ProtoWire.parseFields(data) where f.number == 2 {
            parseVehicleData(f.bytes)
        }
    }

    private func parseVehicleData(_ data: Data) {
        for f in ProtoWire.parseFields(data) {
            switch f.number {
            case 3: parseCharge(f.bytes)
            case 4: parseClimate(f.bytes)
            case 5: parseDrive(f.bytes)
            case 8: parseLocation(f.bytes)
            case 19: parseTires(f.bytes)
            case 20: parseMedia(f.bytes)
            case 21: parseMediaDetail(f.bytes)
            default: break
            }
        }
        snapshot.updated = Date()
    }

    private func parseDrive(_ data: Data) {
        for f in ProtoWire.parseFields(data) {
            switch f.number {
            case 1: // shift_state
                for sf in ProtoWire.parseFields(f.bytes) {
                    switch sf.number {
                    case 2: snapshot.gear = "P"
                    case 3: snapshot.gear = "R"
                    case 4: snapshot.gear = "N"
                    case 5: snapshot.gear = "D"
                    default: break
                    }
                }
            case 102: // speed mph uint32
                snapshot.speedKmh = Double(f.varint) * 1.60934
            case 103: // power kW int32 (as varint zigzag? actually int32 varint)
                snapshot.powerKW = Double(Int32(truncatingIfNeeded: f.varint))
            case 105: // odometer hundredths of mile
                let miles = Double(Int32(truncatingIfNeeded: f.varint)) / 100.0
                snapshot.odometerKm = miles * 1.60934
            case 106: // speed_float mph
                if let fl = ProtoWire.float32(f.bytes) {
                    snapshot.speedKmh = Double(fl) * 1.60934
                }
            case 7:
                if let s = String(data: f.bytes, encoding: .utf8), !s.isEmpty {
                    snapshot.destination = s
                }
            case 8: // minutes to arrival float
                if let mins = ProtoWire.float32(f.bytes) {
                    let m = Int(mins.rounded())
                    snapshot.eta = String(format: "%d dk", m)
                }
            case 9: // miles to arrival
                if let mi = ProtoWire.float32(f.bytes) {
                    snapshot.tripDist = String(format: "%.1f km", Double(mi) * 1.60934)
                }
            case 11: // energy at arrival
                if let e = ProtoWire.float32(f.bytes) {
                    snapshot.energyAtArrival = String(format: "%.0f%%", e)
                }
            case 12: // active_route_coordinates LatLong { lat=1, lon=2 }
                for sf in ProtoWire.parseFields(f.bytes) {
                    switch sf.number {
                    case 1:
                        if let fl = ProtoWire.float32(sf.bytes) { snapshot.destLatitude = Double(fl) }
                        else if let d = ProtoWire.double64(sf.bytes) { snapshot.destLatitude = d }
                    case 2:
                        if let fl = ProtoWire.float32(sf.bytes) { snapshot.destLongitude = Double(fl) }
                        else if let d = ProtoWire.double64(sf.bytes) { snapshot.destLongitude = d }
                    default: break
                    }
                }
            default: break
            }
        }
    }

    private func parseCharge(_ data: Data) {
        for f in ProtoWire.parseFields(data) {
            switch f.number {
            case 1: // charging_state enum/message — treat non-idle as charging loosely via battery fields
                break
            case 111: // battery_range miles float
                if let mi = ProtoWire.float32(f.bytes) {
                    snapshot.rangeKm = Int((Double(mi) * 1.60934).rounded())
                }
            case 114: // battery_level
                snapshot.batteryPercent = Double(f.varint)
            case 115: // usable_battery_level
                if f.varint > 0 { snapshot.batteryPercent = Double(f.varint) }
            case 122: // charger_power
                if f.varint > 0 { snapshot.charging = true }
            default: break
            }
        }
    }

    private func parseTires(_ data: Data) {
        // Tesla TPMS over BLE is typically bar (float)
        func psi(_ bar: Float) -> Int { Int((Double(bar) * 14.5038).rounded()) }
        for f in ProtoWire.parseFields(data) {
            guard let bar = ProtoWire.float32(f.bytes) else { continue }
            switch f.number {
            case 2: snapshot.psiFL = psi(bar)
            case 3: snapshot.psiFR = psi(bar)
            case 4: snapshot.psiRL = psi(bar)
            case 5: snapshot.psiRR = psi(bar)
            default: break
            }
        }
    }

    private func parseMedia(_ data: Data) {
        var vol: Float = 0
        var volMax: Float = 10
        for f in ProtoWire.parseFields(data) {
            switch f.number {
            case 3:
                if let s = String(data: f.bytes, encoding: .utf8), !s.isEmpty {
                    snapshot.mediaArtist = s
                }
            case 4:
                if let s = String(data: f.bytes, encoding: .utf8), !s.isEmpty {
                    snapshot.mediaTitle = s
                }
            case 5:
                if let v = ProtoWire.float32(f.bytes) { vol = v }
            case 7:
                if let v = ProtoWire.float32(f.bytes), v > 0 { volMax = v }
            case 8: // MediaSourceType enum (varint)
                let name = Self.mediaSourceName(f.varint)
                if !name.isEmpty { snapshot.mediaService = name }
            case 9:
                // MediaPlaybackStatus: 0 unknown, 1 stopped, 2 playing, 3 paused
                snapshot.mediaPlaying = (f.varint == 2)
            default: break
            }
        }
        if volMax > 0 { snapshot.mediaVolume = min(1, max(0, Double(vol / volMax))) }
    }

    private func parseMediaDetail(_ data: Data) {
        for f in ProtoWire.parseFields(data) {
            switch f.number {
            case 2: // duration ms
                break
            case 3: // elapsed ms
                if f.varint > 0 {
                    // progress filled when duration known elsewhere; keep elapsed hint
                }
            case 4: // now_playing_source_string — e.g. "YouTube Music"
                if let s = String(data: f.bytes, encoding: .utf8), !s.isEmpty {
                    snapshot.mediaService = s
                }
            case 5:
                if let s = String(data: f.bytes, encoding: .utf8), !s.isEmpty {
                    snapshot.mediaAlbum = s
                }
            case 6:
                if let s = String(data: f.bytes, encoding: .utf8), !s.isEmpty,
                   snapshot.mediaTitle == "—" || snapshot.mediaTitle.isEmpty {
                    snapshot.mediaTitle = s
                }
            default: break
            }
        }
    }

    private static func mediaSourceName(_ v: UInt64) -> String {
        switch v {
        case 1: return "AM"
        case 2: return "FM"
        case 3, 19: return "SiriusXM"
        case 6: return "Files"
        case 7: return "iPod"
        case 8: return "Bluetooth"
        case 9: return "AUX"
        case 12: return "Spotify"
        case 17: return "TuneIn"
        case 20: return "Tidal"
        case 21, 22: return "QQ Music"
        case 26: return "NetEase"
        default: return ""
        }
    }

    private func parseLocation(_ data: Data) {
        for f in ProtoWire.parseFields(data) {
            switch f.number {
            case 101, 106, 114, 122: // latitude variants
                if let d = ProtoWire.double64(f.bytes) { snapshot.latitude = d }
                else if let fl = ProtoWire.float32(f.bytes) { snapshot.latitude = Double(fl) }
            case 102, 107, 115, 123:
                if let d = ProtoWire.double64(f.bytes) { snapshot.longitude = d }
                else if let fl = ProtoWire.float32(f.bytes) { snapshot.longitude = Double(fl) }
            case 103: // heading uint32?
                snapshot.heading = Double(f.varint)
            case 116:
                if let d = ProtoWire.double64(f.bytes) { snapshot.heading = d }
                else if let fl = ProtoWire.float32(f.bytes) { snapshot.heading = Double(fl) }
            case 113:
                if let s = String(data: f.bytes, encoding: .utf8), !s.isEmpty {
                    snapshot.place = s
                }
            default: break
            }
        }
    }

    private func parseClimate(_ data: Data) {
        for f in ProtoWire.parseFields(data) where f.number == 102 {
            if let t = ProtoWire.float32(f.bytes) {
                snapshot.outdoorC = Int(t.rounded())
            }
        }
    }

    // MARK: - Utils

    enum SessionError: Error { case notReady }

    private func randomBytes(_ n: Int) -> Data { Self.randomBytes(n) }

    /// Avoid SecRandomCopyBytes (extra Security linkage) — UUID entropy is enough here.
    private static func randomBytes(_ n: Int) -> Data {
        var out = Data()
        out.reserveCapacity(n)
        while out.count < n {
            var u = UUID().uuid
            withUnsafeBytes(of: &u) { out.append(contentsOf: $0) }
        }
        return Data(out.prefix(n))
    }

    private func be32(_ v: UInt32) -> Data {
        var be = v.bigEndian
        return Data(bytes: &be, count: 4)
    }

    private func constantTimeEqual(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count { diff |= a[i] ^ b[i] }
        return diff == 0
    }
}

private extension Data {
    init(hex: String) {
        var d = Data()
        var s = hex
        while s.count >= 2 {
            let b = s.prefix(2)
            s.removeFirst(2)
            if let v = UInt8(b, radix: 16) { d.append(v) }
            else { break }
        }
        self = d
    }
}
