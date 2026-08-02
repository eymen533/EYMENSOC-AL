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
}
