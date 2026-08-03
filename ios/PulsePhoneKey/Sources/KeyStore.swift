import Foundation
import CryptoKit

/// Playgrounds-safe key storage (UserDefaults only — no Keychain).
enum KeyStore {
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

    /// True after Phone Key was accepted once for this VIN — reconnect without add-key.
    static func isPaired(vin: String) -> Bool {
        let v = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard v.count == 17 else { return false }
        return UserDefaults.standard.bool(forKey: pairedKey(v))
    }

    static func markPaired(vin: String, peripheralId: UUID? = nil) {
        let v = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard v.count == 17 else { return }
        UserDefaults.standard.set(true, forKey: pairedKey(v))
        if let peripheralId {
            UserDefaults.standard.set(peripheralId.uuidString, forKey: peripheralKey(v))
        }
    }

    static func clearPaired(vin: String) {
        let v = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !v.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: pairedKey(v))
        UserDefaults.standard.removeObject(forKey: peripheralKey(v))
    }

    static func storedPeripheralId(vin: String) -> UUID? {
        let v = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let s = UserDefaults.standard.string(forKey: peripheralKey(v)) else { return nil }
        return UUID(uuidString: s)
    }

    private static func pairedKey(_ vin: String) -> String { "pulse_ble_paired_\(vin)" }
    private static func peripheralKey(_ vin: String) -> String { "pulse_ble_peripheral_\(vin)" }
}
