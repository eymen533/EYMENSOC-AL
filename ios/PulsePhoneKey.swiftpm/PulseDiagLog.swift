import Foundation
import Combine

/// In-app diagnostic ring buffer — share when BLE drops / bugs show up.
final class PulseDiagLog: ObservableObject {
    static let shared = PulseDiagLog()

    enum Level: String {
        case info = "I"
        case warn = "W"
        case error = "E"
        case ble = "B"
    }

    struct Entry: Identifiable, Equatable {
        let id: UUID
        let date: Date
        let level: Level
        let message: String

        var line: String {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss.SSS"
            return "\(f.string(from: date)) [\(level.rawValue)] \(message)"
        }
    }

    @Published private(set) var entries: [Entry] = []
    private let maxEntries = 400
    private let lock = NSLock()

    private init() {
        info("PulseDiagLog ready")
    }

    func info(_ msg: String) { append(.info, msg) }
    func warn(_ msg: String) { append(.warn, msg) }
    func error(_ msg: String) { append(.error, msg) }
    func ble(_ msg: String) { append(.ble, msg) }

    func append(_ level: Level, _ msg: String) {
        let trimmed = msg.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entry = Entry(id: UUID(), date: Date(), level: level, message: trimmed)
        DispatchQueue.main.async {
            self.lock.lock()
            self.entries.insert(entry, at: 0)
            if self.entries.count > self.maxEntries {
                self.entries = Array(self.entries.prefix(self.maxEntries))
            }
            self.lock.unlock()
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.entries.removeAll()
            self.info("Log cleared")
        }
    }

    var exportText: String {
        let header = "Pulse28 diag · \(ISO8601DateFormatter().string(from: Date()))\n"
        let body = entries.reversed().map(\.line).joined(separator: "\n")
        return header + body
    }
}
