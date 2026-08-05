import Foundation
import CryptoKit

/// Playgrounds-safe key storage (UserDefaults only — no Keychain).
/// VIN is never baked into source — only what the user enters / scans, stored on-device.
enum KeyStore {
    private static let vinDefaultsKey = "pulse_vin"
    private static let lastPairedVINKey = "pulse_last_paired_vin"

    static func loadOrCreatePrivateKey(forVIN vin: String) throws -> P256.KeyAgreement.PrivateKey {
        let keyName = "pulse.pk.vin." + vin.uppercased()
        if let data = UserDefaults.standard.data(forKey: keyName),
           let existing = try? P256.KeyAgreement.PrivateKey(rawRepresentation: data) {
            return existing
        }
        let key = P256.KeyAgreement.PrivateKey()
        UserDefaults.standard.set(key.rawRepresentation, forKey: keyName)
        return key
    }

    static func publicKeyUncompressed(_ key: P256.KeyAgreement.PrivateKey) -> Data {
        var out = Data([0x04])
        out.append(key.publicKey.rawRepresentation)
        return out
    }

    static func hasPrivateKey(vin: String) -> Bool {
        let v = normalizeVIN(vin)
        guard v.count == 17 else { return false }
        return UserDefaults.standard.data(forKey: "pulse.pk.vin." + v) != nil
    }

    /// True after Phone Key was accepted once for this VIN — reconnect without add-key.
    static func isPaired(vin: String) -> Bool {
        let v = normalizeVIN(vin)
        guard v.count == 17 else { return false }
        return UserDefaults.standard.bool(forKey: pairedKey(v))
    }

    static func markPaired(vin: String, peripheralId: UUID? = nil) {
        let v = normalizeVIN(vin)
        guard v.count == 17 else { return }
        UserDefaults.standard.set(true, forKey: pairedKey(v))
        // Persist VIN on-device only (never in source). Resume uses this next launches.
        saveVIN(v)
        UserDefaults.standard.set(v, forKey: lastPairedVINKey)
        if let peripheralId {
            UserDefaults.standard.set(peripheralId.uuidString, forKey: peripheralKey(v))
        }
    }

    static func clearPaired(vin: String) {
        let v = normalizeVIN(vin)
        guard !v.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: pairedKey(v))
        UserDefaults.standard.removeObject(forKey: peripheralKey(v))
        // Keep saved VIN text so user doesn't re-type; only drop pair flag + BLE peripheral.
    }

    static func storedPeripheralId(vin: String) -> UUID? {
        let v = normalizeVIN(vin)
        guard let s = UserDefaults.standard.string(forKey: peripheralKey(v)) else { return nil }
        return UUID(uuidString: s)
    }

    static func normalizeVIN(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    static func isValidVIN(_ raw: String) -> Bool {
        let v = normalizeVIN(raw)
        guard v.count == 17 else { return false }
        // ISO 3779: letters I, O, Q are not used in VIN.
        return v.range(of: "^[A-HJ-NPR-Z0-9]{17}$", options: .regularExpression) != nil
    }

    static func saveVIN(_ raw: String) {
        let v = normalizeVIN(raw)
        guard v.count == 17 else { return }
        UserDefaults.standard.set(v, forKey: vinDefaultsKey)
    }

    /// On-device VIN only — empty for fresh installs (nothing hardcoded in the app binary).
    static func loadSavedVIN() -> String {
        let ud = UserDefaults.standard
        let candidates = [
            ud.string(forKey: vinDefaultsKey),
            ud.string(forKey: lastPairedVINKey),
            anyPairedVIN(),
        ]
        for c in candidates {
            let v = normalizeVIN(c ?? "")
            if isValidVIN(v) { return v }
        }
        return ""
    }

    /// Find any VIN previously marked paired (survives wiped pulse_vin).
    static func anyPairedVIN() -> String? {
        let prefix = "pulse_ble_paired_"
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
            guard key.hasPrefix(prefix), (value as? Bool) == true else { continue }
            let vin = String(key.dropFirst(prefix.count))
            if isValidVIN(vin) { return vin }
        }
        // Fall back: private key present implies prior setup.
        let pkPrefix = "pulse.pk.vin."
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            guard key.hasPrefix(pkPrefix) else { continue }
            let vin = String(key.dropFirst(pkPrefix.count))
            if isValidVIN(vin) { return vin }
        }
        return nil
    }

    private static func pairedKey(_ vin: String) -> String { "pulse_ble_paired_\(vin)" }
    private static func peripheralKey(_ vin: String) -> String { "pulse_ble_peripheral_\(vin)" }
}
