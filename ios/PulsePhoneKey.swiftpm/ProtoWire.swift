import Foundation

/// Minimal protobuf wire helpers (encode + scan). Tesla BLE only needs a subset.
enum ProtoWire {
    static func encodeVarint(_ value: UInt64) -> Data {
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

    static func tag(_ field: UInt64, wire: UInt64) -> Data {
        encodeVarint((field << 3) | wire)
    }

    static func fieldVarint(_ field: UInt64, _ value: UInt64) -> Data {
        tag(field, wire: 0) + encodeVarint(value)
    }

    static func fieldBytes(_ field: UInt64, _ bytes: Data) -> Data {
        tag(field, wire: 2) + encodeVarint(UInt64(bytes.count)) + bytes
    }

    static func fieldFixed32(_ field: UInt64, _ value: UInt32) -> Data {
        var le = value.littleEndian
        return tag(field, wire: 5) + Data(bytes: &le, count: 4)
    }

    static func prependLength(_ message: Data) -> Data {
        var out = Data([UInt8(message.count >> 8), UInt8(message.count & 0xFF)])
        out.append(message)
        return out
    }

    struct Field {
        let number: UInt64
        let wire: UInt64
        let bytes: Data
        let varint: UInt64
        let fixed32: UInt32
    }

    static func parseFields(_ data: Data) -> [Field] {
        var out: [Field] = []
        var i = 0
        while i < data.count {
            guard let (key, ni) = readVarint(data, i) else { break }
            i = ni
            let number = key >> 3
            let wire = key & 0x7
            switch wire {
            case 0:
                guard let (v, nj) = readVarint(data, i) else { return out }
                i = nj
                out.append(Field(number: number, wire: wire, bytes: Data(), varint: v, fixed32: 0))
            case 1:
                guard i + 8 <= data.count else { return out }
                out.append(Field(number: number, wire: wire, bytes: data.subdata(in: i..<(i + 8)), varint: 0, fixed32: 0))
                i += 8
            case 2:
                guard let (len, nj) = readVarint(data, i), Int(len) >= 0, nj + Int(len) <= data.count else { return out }
                i = nj
                let end = i + Int(len)
                out.append(Field(number: number, wire: wire, bytes: data.subdata(in: i..<end), varint: 0, fixed32: 0))
                i = end
            case 5:
                guard i + 4 <= data.count else { return out }
                let slice = data.subdata(in: i..<(i + 4))
                let v = u32LE(slice)
                out.append(Field(number: number, wire: wire, bytes: slice, varint: 0, fixed32: v))
                i += 4
            default:
                return out
            }
        }
        return out
    }

    static func readVarint(_ data: Data, _ start: Int) -> (UInt64, Int)? {
        var result: UInt64 = 0
        var shift = 0
        var i = start
        while i < data.count {
            let b = data[i]
            i += 1
            result |= UInt64(b & 0x7F) << shift
            if b & 0x80 == 0 { return (result, i) }
            shift += 7
            if shift > 63 { return nil }
        }
        return nil
    }

    /// Copy-based loads — never `load(as:)` on possibly unaligned Data (ARM crash).
    static func float32(_ data: Data) -> Float? {
        guard data.count >= 4 else { return nil }
        var bits: UInt32 = 0
        _ = withUnsafeMutableBytes(of: &bits) { dest in
            data.copyBytes(to: dest, from: 0..<4)
        }
        return Float(bitPattern: UInt32(littleEndian: bits))
    }

    static func double64(_ data: Data) -> Double? {
        guard data.count >= 8 else { return nil }
        var bits: UInt64 = 0
        _ = withUnsafeMutableBytes(of: &bits) { dest in
            data.copyBytes(to: dest, from: 0..<8)
        }
        return Double(bitPattern: UInt64(littleEndian: bits))
    }

    private static func u32LE(_ data: Data) -> UInt32 {
        guard data.count >= 4 else { return 0 }
        var bits: UInt32 = 0
        _ = withUnsafeMutableBytes(of: &bits) { dest in
            data.copyBytes(to: dest, from: 0..<4)
        }
        return UInt32(littleEndian: bits)
    }
}

/// Length-prefixed BLE frame reassembly (2-byte big-endian length).
final class BLEFrameBuffer {
    private var buf = Data()

    func append(_ chunk: Data) -> [Data] {
        buf.append(chunk)
        var frames: [Data] = []
        while buf.count >= 2 {
            let len = Int(buf[0]) << 8 | Int(buf[1])
            guard len >= 0, len < 1_000_000 else {
                buf.removeAll(keepingCapacity: false)
                break
            }
            if buf.count < 2 + len { break }
            frames.append(buf.subdata(in: 2..<(2 + len)))
            buf.removeSubrange(0..<(2 + len))
        }
        return frames
    }

    func reset() { buf.removeAll(keepingCapacity: false) }
}
