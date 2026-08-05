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
    /// Recent AES request tags — late/duplicate notifies still decrypt after next poll.
    private var recentRequestTags: [Data] = []
    private let maxRecentRequestTags = 8
    /// Per-domain pending handshake UUIDs — avoids VCSEC/infotainment challenge mixups.
    private var pendingHandshakeUUID: [Domain: Data] = [:]
    private var lastHandshakeUUID: [Domain: Data] = [:]
    /// Consecutive session-tag failures (triggers full domain reset).
    private var sessionTagFails = 0
    /// Drive ticks without nav proof — keep sticky dest until this crosses threshold.
    private var routeInactiveStreak = 0
    /// Consecutive AES decrypt misses (orphan replies) — soft, no session wipe.
    private(set) var consecutiveDecryptMisses = 0

    var snapshot = Snapshot()
    var infotainmentReady: Bool { isReady(.infotainment) }
    /// True after at least one decrypted VehicleData payload.
    private(set) var hasVehicleData = false
    var statusText: String = "BLE session yok"
    /// True when last commit failed due to HMAC challenge/tag mismatch.
    private(set) var lastSessionTagInvalid = false
    /// True when last AES response decrypt failed (counter/epoch drift).
    private(set) var lastDecryptFailed = false
    /// True when decrypt failed but was treated as orphan (do not reset session).
    private(set) var lastDecryptWasOrphan = false

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
        lastSessionTagInvalid = false
        lastDecryptFailed = false
        pendingHandshakeUUID[domain] = uuid
        lastHandshakeUUID[domain] = uuid
        // SessionInfoRequest { public_key = 1 }
        let sir = ProtoWire.fieldBytes(1, publicKey)
        // RoutableMessage
        let toDest = ProtoWire.fieldVarint(1, domain.rawValue) // Destination.domain
        let fromDest = ProtoWire.fieldBytes(2, routingAddress) // Destination.routing_address
        var msg = Data()
        msg.append(ProtoWire.fieldBytes(6, toDest)) // to_destination
        msg.append(ProtoWire.fieldBytes(7, fromDest)) // from_destination
        msg.append(ProtoWire.fieldBytes(14, sir)) // session_info_request
        // Tesla echoes this into response request_uuid (field 50) — that is the HMAC challenge.
        msg.append(ProtoWire.fieldBytes(51, uuid)) // uuid
        return (uuid, ProtoWire.prependLength(msg))
    }

    /// Drop crypto state for a domain so the next handshake can rebuild cleanly.
    func resetDomain(_ domain: Domain) {
        domains[domain] = DomainState()
        pendingHandshakeUUID[domain] = nil
        if domain == .infotainment {
            hasVehicleData = false
        }
    }

    func resetAllDomains() {
        resetDomain(.vcsec)
        resetDomain(.infotainment)
        sessionTagFails = 0
        statusText = "Oturum sifirlandi — handshake…"
    }

    @discardableResult
    func handleIncoming(_ frame: Data) -> Bool {
        lastDecryptFailed = false
        lastDecryptWasOrphan = false
        lastSessionTagInvalid = false
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
            // Challenge MUST be the UUID of the SessionInfoRequest that elicited this reply.
            // Prefer response.request_uuid (field 50); fall back to the pending UUID for this domain.
            let challenge: Data = {
                if let requestUUID, requestUUID.count == 16 { return requestUUID }
                if let pending = pendingHandshakeUUID[fromDomain], pending.count == 16 { return pending }
                if let last = lastHandshakeUUID[fromDomain], last.count == 16 { return last }
                return lastRequestUUID
            }()
            _ = commitSessionInfo(
                info,
                tag: sessionInfoTag,
                domain: fromDomain,
                challenge: challenge
            )
            pendingHandshakeUUID[fromDomain] = nil
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
                consecutiveDecryptMisses = 0
                lastDecryptFailed = false
                lastDecryptWasOrphan = false
            } catch {
                // Late/duplicate notify for an older request — ignore without killing the session.
                consecutiveDecryptMisses += 1
                lastDecryptWasOrphan = true
                lastDecryptFailed = consecutiveDecryptMisses >= 6
                statusText = lastDecryptFailed
                    ? "Decrypt fail"
                    : "BLE LIVE"
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
            // Vehicle may send full 32-byte HMAC or a truncated tag — compare prefix when shorter.
            let ok: Bool = {
                if expected.count == tag.count { return constantTimeEqual(expected, tag) }
                if tag.count > 0, tag.count < expected.count {
                    return constantTimeEqual(Data(expected.prefix(tag.count)), tag)
                }
                return false
            }()
            guard ok else {
                lastSessionTagInvalid = true
                sessionTagFails += 1
                statusText = "Session tag gecersiz"
                // Stale / mismatched challenge — clear this domain so we can re-handshake cleanly.
                domains[domain] = DomainState()
                return false
            }
        }

        lastSessionTagInvalid = false
        sessionTagFails = 0
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
        recentRequestTags.insert(tag, at: 0)
        if recentRequestTags.count > maxRecentRequestTags {
            recentRequestTags = Array(recentRequestTags.prefix(maxRecentRequestTags))
        }

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
        // Try current + recent request tags (out-of-order / late BLE notifies).
        var tags = recentRequestTags
        if !lastRequestTag.isEmpty, tags.first != lastRequestTag {
            tags.insert(lastRequestTag, at: 0)
        }
        if tags.isEmpty, !lastRequestTag.isEmpty {
            tags = [lastRequestTag]
        }

        var lastError: Error = SessionError.notReady
        for reqTag in tags {
            do {
                return try decryptResponse(
                    domain: domain,
                    key: key,
                    nonce: nonce,
                    ciphertext: ciphertext,
                    tag: tag,
                    counter: counter,
                    flags: flags,
                    fault: fault,
                    requestTag: reqTag
                )
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func decryptResponse(
        domain: Domain,
        key: SymmetricKey,
        nonce: Data,
        ciphertext: Data,
        tag: Data,
        counter: UInt32,
        flags: UInt32,
        fault: UInt32,
        requestTag: Data
    ) throws -> Data {
        var requestHash = Data([SignatureType.aesGcmPersonalized.rawValue])
        requestHash.append(requestTag)
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
    /// Drive + Location in one round-trip (faster HUD / map).
    static func actionGetDriveAndLocation() -> Data { Data(hex: "12060a0422003a00") }
    /// Charge + Climate + Drive + Location — battery/temp/GPS in one reply.
    static func actionGetDriveBundle() -> Data { Data(hex: "120a0a0812001a0022003a00") }
    static func actionGetCharge() -> Data { Data(hex: "12040a021200") }
    static func actionGetTire() -> Data { Data(hex: "12040a027200") }
    /// GetMediaState (15) + GetMediaDetailState (16) — source string / album.
    static func actionGetMedia() -> Data { Data(hex: "12070a057a00820100") }
    static func actionGetLocation() -> Data { Data(hex: "12040a023a00") }
    static func actionGetClimate() -> Data { Data(hex: "12040a021a00") }
    /// GetClosuresState (8) — doors / frunk / trunk / locked / display.
    static func actionGetClosures() -> Data { Data(hex: "12040a024200") }
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
            case 9: parseClosures(f.bytes)
            case 19: parseTires(f.bytes)
            case 20: parseMedia(f.bytes)
            case 21: parseMediaDetail(f.bytes)
            default: break
            }
        }
        snapshot.updated = Date()
    }

    private func parseDrive(_ data: Data) {
        var sawDestName = false
        var sawETA = false
        var sawMiles = false
        var pendingLat: Double?
        var pendingLon: Double?

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
            case 103: // power kW int32
                snapshot.powerKW = Double(Int32(truncatingIfNeeded: f.varint))
            case 105: // odometer hundredths of mile
                let miles = Double(Int32(truncatingIfNeeded: f.varint)) / 100.0
                snapshot.odometerKm = miles * 1.60934
            case 106: // speed_float mph
                if let fl = ProtoWire.float32(f.bytes) {
                    snapshot.speedKmh = Double(fl) * 1.60934
                }
            case 7: // active_route_destination
                if let s = String(data: f.bytes, encoding: .utf8) {
                    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty {
                        snapshot.destination = t
                        sawDestName = true
                    }
                }
            case 8: // minutes to arrival float
                if let mins = ProtoWire.float32(f.bytes) {
                    let m = Int(mins.rounded())
                    if m >= 0 {
                        snapshot.eta = String(format: "%d dk", m)
                        sawETA = true
                    }
                }
            case 9: // miles to arrival
                if let mi = ProtoWire.float32(f.bytes) {
                    snapshot.tripDist = String(format: "%.1f km", Double(mi) * 1.60934)
                    if mi > 0.01 { sawMiles = true }
                }
            case 11: // energy at arrival
                if let e = ProtoWire.float32(f.bytes) {
                    snapshot.energyAtArrival = String(format: "%.0f%%", e)
                    sawETA = true
                }
            case 12: // active_route_coordinates LatLong { lat=1 float, lon=2 float }
                for sf in ProtoWire.parseFields(f.bytes) {
                    switch sf.number {
                    case 1:
                        if let v = Self.readCoord(sf) { pendingLat = v }
                    case 2:
                        if let v = Self.readCoord(sf) { pendingLon = v }
                    default: break
                    }
                }
            default: break
            }
        }

        // Sticky nav — Tesla often omits dest fields on some Drive ticks; don't wipe the route.
        let hasPendingCoords: Bool = {
            guard let dLat = pendingLat, let dLon = pendingLon else { return false }
            return abs(dLat) <= 90 && abs(dLon) <= 180
                && (abs(dLat) > 0.0001 || abs(dLon) > 0.0001)
        }()
        let routeProof = sawDestName || sawETA || sawMiles || hasPendingCoords
        if routeProof {
            routeInactiveStreak = 0
            snapshot.routeActive = true
            if let dLat = pendingLat, let dLon = pendingLon,
               abs(dLat) <= 90, abs(dLon) <= 180,
               abs(dLat) > 0.0001 || abs(dLon) > 0.0001 {
                snapshot.destLatitude = dLat
                snapshot.destLongitude = dLon
            }
            if !sawDestName {
                let cur = snapshot.destination.trimmingCharacters(in: .whitespacesAndNewlines)
                if cur.isEmpty || cur == "—" || cur == "-" || cur == "--",
                   abs(snapshot.destLatitude) > 0.0001 || abs(snapshot.destLongitude) > 0.0001 {
                    snapshot.destination = String(
                        format: "%.4f, %.4f",
                        snapshot.destLatitude,
                        snapshot.destLongitude
                    )
                }
            }
        } else {
            routeInactiveStreak += 1
            // Keep last destination/coords for several Drive ticks so the map route doesn't vanish.
            let destOK: Bool = {
                let d = snapshot.destination.trimmingCharacters(in: .whitespacesAndNewlines)
                return !d.isEmpty && d != "—" && d != "-" && d != "--"
            }()
            let keepSticky = routeInactiveStreak < 14
                && (abs(snapshot.destLatitude) > 0.0001 || abs(snapshot.destLongitude) > 0.0001 || destOK)
            if keepSticky {
                snapshot.routeActive = true
            } else {
                snapshot.routeActive = false
                snapshot.destination = "—"
                snapshot.destLatitude = 0
                snapshot.destLongitude = 0
                snapshot.eta = "—"
                snapshot.energyAtArrival = "—"
                snapshot.tripDist = "—"
            }
        }
    }

    private func parseCharge(_ data: Data) {
        for f in ProtoWire.parseFields(data) {
            switch f.number {
            case 1: // charging_state
                break
            case 4: // some firmwares use short ChargeState ids
                if f.varint > 0, f.varint <= 100 { snapshot.batteryPercent = Double(f.varint) }
            case 5:
                if let mi = ProtoWire.float32(f.bytes), mi > 0.5 {
                    snapshot.rangeKm = Int((Double(mi) * 1.60934).rounded())
                }
            case 30:
                if f.varint > 0 { snapshot.batteryPercent = Double(f.varint) }
            case 111, 112, 113: // battery_range / est / ideal (miles)
                if let mi = ProtoWire.float32(f.bytes), mi > 0.5 {
                    let km = Int((Double(mi) * 1.60934).rounded())
                    if km > snapshot.rangeKm { snapshot.rangeKm = km }
                }
            case 114: // battery_level
                if f.varint > 0 { snapshot.batteryPercent = Double(f.varint) }
            case 115: // usable_battery_level
                if f.varint > 0 { snapshot.batteryPercent = Double(f.varint) }
            case 122: // charger_power
                if f.varint > 0 { snapshot.charging = true }
            case 127: // charge_port_door_open
                snapshot.chargePortOpen = f.varint != 0
            default: break
            }
        }
    }

    private func parseClosures(_ data: Data) {
        for f in ProtoWire.parseFields(data) {
            switch f.number {
            case 101: snapshot.doorFL = f.varint != 0
            case 102: snapshot.doorRL = f.varint != 0
            case 103: snapshot.doorFR = f.varint != 0
            case 104: snapshot.doorRR = f.varint != 0
            case 105: snapshot.frunkOpen = f.varint != 0
            case 106: snapshot.trunkOpen = f.varint != 0
            case 113: snapshot.locked = f.varint != 0
            case 15: // center_display_state oneof
                let name = Self.displayStateName(f.bytes)
                if !name.isEmpty {
                    snapshot.centerDisplay = name
                    // Dim / lock / sentry / off → night cluster; driving/on → hour heuristic.
                    switch name {
                    case "off", "dim", "lock", "sentry":
                        snapshot.nightMode = true
                    case "driving", "on", "entertainment", "accessory", "charging", "dog":
                        let h = Calendar.current.component(.hour, from: Date())
                        snapshot.nightMode = (h < 6 || h >= 19)
                    default:
                        break
                    }
                }
            default: break
            }
        }
        // Ambient fallback when display not present.
        if snapshot.nightMode == nil {
            let h = Calendar.current.component(.hour, from: Date())
            snapshot.nightMode = (h < 6 || h >= 19)
        }
    }

    private static func displayStateName(_ data: Data) -> String {
        for f in ProtoWire.parseFields(data) {
            switch f.number {
            case 1: return "off"
            case 2: return "dim"
            case 3: return "accessory"
            case 4: return "on"
            case 5: return "driving"
            case 6: return "charging"
            case 7: return "lock"
            case 8: return "sentry"
            case 9: return "dog"
            case 10: return "entertainment"
            default: break
            }
        }
        return ""
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
        var latPlain: Double?
        var lonPlain: Double?
        var latNative: Double?
        var lonNative: Double?
        var latGeo: Double?
        var lonGeo: Double?
        var headingVal: Double?
        var placeVal: String?

        for f in ProtoWire.parseFields(data) {
            switch f.number {
            case 101: // latitude float
                if let v = Self.readCoord(f) { latPlain = v }
            case 102:
                if let v = Self.readCoord(f) { lonPlain = v }
            case 106: // native_latitude (preferred — matches car map)
                if let v = Self.readCoord(f) { latNative = v }
            case 107:
                if let v = Self.readCoord(f) { lonNative = v }
            case 114: // geo / raw GPS
                if let v = Self.readCoord(f) { latGeo = v }
            case 115:
                if let v = Self.readCoord(f) { lonGeo = v }
            case 103:
                // Tesla heading is degrees; accept varint or float wire forms.
                if f.wire == 0 {
                    headingVal = Double(f.varint)
                } else if let v = Self.readCoord(f) {
                    headingVal = v
                }
            case 116:
                if let v = Self.readCoord(f) { headingVal = v }
            case 113:
                if let s = String(data: f.bytes, encoding: .utf8), !s.isEmpty {
                    placeVal = s
                }
            default: break
            }
        }

        // Prefer WGS84 GPS for Apple Maps (plain / geo). Native can be a local datum.
        let lat = latPlain ?? latGeo ?? latNative
        let lon = lonPlain ?? lonGeo ?? lonNative
        if let lat, let lon, abs(lat) <= 90, abs(lon) <= 180, (abs(lat) > 0.0001 || abs(lon) > 0.0001) {
            snapshot.latitude = lat
            snapshot.longitude = lon
        }
        if let headingVal {
            var h = headingVal.truncatingRemainder(dividingBy: 360)
            if h < 0 { h += 360 }
            snapshot.heading = h
        }
        if let placeVal { snapshot.place = placeVal }
    }

    private static func readCoord(_ f: ProtoWire.Field) -> Double? {
        if f.wire == 5, let fl = ProtoWire.float32(f.bytes) { return Double(fl) }
        if f.bytes.count >= 8, let d = ProtoWire.double64(f.bytes) { return d }
        if f.bytes.count >= 4, let fl = ProtoWire.float32(f.bytes) { return Double(fl) }
        return nil
    }

    private func parseClimate(_ data: Data) {
        for f in ProtoWire.parseFields(data) {
            switch f.number {
            case 102: // outside_temp_celsius
                if let t = ProtoWire.float32(f.bytes) {
                    snapshot.outdoorC = Int(t.rounded())
                }
            case 101: // inside_temp — fallback display if outside missing
                if snapshot.outdoorC == 0, let t = ProtoWire.float32(f.bytes) {
                    snapshot.outdoorC = Int(t.rounded())
                }
            default: break
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
