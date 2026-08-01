import Foundation
import CryptoKit

/// Minimal protobuf writer for Tesla VCSEC add-key-request
/// (same envelope as `tesla-control -ble add-key-request`).
enum VCSECPayload {
    static let serviceUUID = "00000211-B2D1-43F0-9B88-960CEBF8B91E"
    static let writeUUID = "00000212-B2D1-43F0-9B88-960CEBF8B91E"
    static let readUUID = "00000213-B2D1-43F0-9B88-960CEBF8B91E"

    static let roleOwner: UInt64 = 2
    static let formFactorIOS: UInt64 = 6
    static let signaturePresentKey: UInt64 = 2

    static func bleLocalName(vin: String) -> String {
        let digest = Insecure.SHA1.hash(data: Data(vin.uppercased().utf8))
        let hex = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return "S\(hex)C"
    }

    static func bleNames(vin: String) -> [String] {
        let v = vin.uppercased()
        let tail = String(v.suffix(6))
        return [bleLocalName(vin: v), "Tesla \(tail)", "Tesla\(tail)"]
    }

    /// Length-prefixed ToVCSECMessage bytes ready for GATT write.
    static func addKeyRequest(publicKeyUncompressed: Data) -> Data {
        // PublicKey { PublicKeyRaw = 1 }
        let publicKey = field(1, bytes: publicKeyUncompressed)
        // PermissionChange { key = 1, keyRole = 4 }
        let permissionChange = field(1, bytes: publicKey) + field(4, varint: roleOwner)
        // KeyMetadata { keyFormFactor = 1 }
        let metadata = field(1, varint: formFactorIOS)
        // WhitelistOperation { addKey... = 5, metadataForKey = 6 }
        let whitelistOp = field(5, bytes: permissionChange) + field(6, bytes: metadata)
        // UnsignedMessage { WhitelistOperation = 16 }
        let unsigned = field(16, bytes: whitelistOp)
        // SignedMessage { protobufMessageAsBytes = 2, signatureType = 3 }
        let signed = field(2, bytes: unsigned) + field(3, varint: signaturePresentKey)
        // ToVCSECMessage { signedMessage = 1 }
        let envelope = field(1, bytes: signed)
        return prependLength(envelope)
    }

    // MARK: - protobuf helpers

    private static func prependLength(_ message: Data) -> Data {
        var out = Data([UInt8(message.count >> 8), UInt8(message.count & 0xFF)])
        out.append(message)
        return out
    }

    private static func field(_ number: UInt64, varint value: UInt64) -> Data {
        tag(number, wire: 0) + encodeVarint(value)
    }

    private static func field(_ number: UInt64, bytes: Data) -> Data {
        tag(number, wire: 2) + encodeVarint(UInt64(bytes.count)) + bytes
    }

    private static func tag(_ number: UInt64, wire: UInt64) -> Data {
        encodeVarint((number << 3) | wire)
    }

    private static func encodeVarint(_ value: UInt64) -> Data {
        var v = value
        var out = Data()
        repeat {
            var byte = UInt8(v & 0x7F)
            v >>= 7
            if v != 0 { byte |= 0x80 }
            out.append(byte)
        } while v != 0
        return out
    }
}
