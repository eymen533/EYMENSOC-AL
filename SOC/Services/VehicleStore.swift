import Combine
import Foundation
import Security

@MainActor
final class VehicleStore: ObservableObject {
    static let shared = VehicleStore()

    private enum Keys {
        static let pairedVIN = "soc.pairedVIN"
        static let displayName = "soc.displayName"
        static let keyTagPrefix = "com.eymenisin.soc.tesla.key."
    }

    @Published private(set) var pairedVIN: String?
    @Published private(set) var displayName: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.pairedVIN = defaults.string(forKey: Keys.pairedVIN)
        self.displayName = defaults.string(forKey: Keys.displayName)
    }

    func savePairedVIN(_ vin: String, displayName: String? = nil) {
        let normalized = VINHelper.normalize(vin)
        pairedVIN = normalized
        defaults.set(normalized, forKey: Keys.pairedVIN)
        if let displayName {
            self.displayName = displayName
            defaults.set(displayName, forKey: Keys.displayName)
        }
    }

    func clearPairing() {
        if let vin = pairedVIN {
            KeychainTeslaKeys.deletePrivateKey(forVIN: vin)
        }
        pairedVIN = nil
        displayName = nil
        defaults.removeObject(forKey: Keys.pairedVIN)
        defaults.removeObject(forKey: Keys.displayName)
    }

    func keyTag(forVIN vin: String) -> String {
        Keys.keyTagPrefix + VINHelper.normalize(vin)
    }
}

enum VINHelper {
    static func normalize(_ vin: String) -> String {
        vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func isValid(_ vin: String) -> Bool {
        let value = normalize(vin)
        // Tesla VINs are 17 characters; letters I, O, Q are not used.
        guard value.count == 17 else { return false }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHJKLMNPRSTUVWXYZ0123456789")
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// BLE local name / advertisement filter hint derived from VIN suffix.
    static func bleNameHint(for vin: String) -> String {
        let value = normalize(vin)
        guard value.count >= 4 else { return value }
        return String(value.suffix(4))
    }
}

enum KeychainTeslaKeys {
    static func savePrivateKey(_ data: Data, forVIN vin: String) throws {
        let tag = VehicleStore.shared.keyTag(forVIN: vin).data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }

    static func loadPrivateKey(forVIN vin: String) -> Data? {
        let tag = VehicleStore.shared.keyTag(forVIN: vin).data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }

    static func deletePrivateKey(forVIN vin: String) {
        let tag = VehicleStore.shared.keyTag(forVIN: vin).data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum KeychainError: Error {
        case unhandled(OSStatus)
    }
}
