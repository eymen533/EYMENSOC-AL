import Foundation
import CryptoKit
import Security

enum KeyStore {
    private static let service = "com.teslapulse.phonekey"

    static func loadOrCreatePrivateKey(forVIN vin: String) throws -> P256.KeyAgreement.PrivateKey {
        let account = "vin." + vin.uppercased()
        if let existing = try load(account: account) {
            return existing
        }
        // Playgrounds Keychain can fail on first run — fall back to UserDefaults.
        if let fallback = loadFallback(account: account) {
            return fallback
        }
        let key = P256.KeyAgreement.PrivateKey()
        do {
            try save(key, account: account)
        } catch {
            saveFallback(key, account: account)
        }
        return key
    }

    static func publicKeyUncompressed(_ key: P256.KeyAgreement.PrivateKey) -> Data {
        let raw = key.publicKey.rawRepresentation // 64 bytes X||Y on Apple
        var out = Data([0x04])
        out.append(raw)
        return out
    }

    private static func load(account: String) throws -> P256.KeyAgreement.PrivateKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeyStoreError.keychain(status)
        }
        return try P256.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    private static func save(_ key: P256.KeyAgreement.PrivateKey, account: String) throws {
        let data = key.rawRepresentation
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeyStoreError.keychain(status) }
    }

    private static func fallbackKey(_ account: String) -> String {
        "pulse.pk.\(account)"
    }

    private static func loadFallback(account: String) -> P256.KeyAgreement.PrivateKey? {
        guard let data = UserDefaults.standard.data(forKey: fallbackKey(account)) else { return nil }
        return try? P256.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    private static func saveFallback(_ key: P256.KeyAgreement.PrivateKey, account: String) {
        UserDefaults.standard.set(key.rawRepresentation, forKey: fallbackKey(account))
    }

    enum KeyStoreError: Error {
        case keychain(OSStatus)
    }
}
