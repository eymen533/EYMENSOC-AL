import Foundation
import Combine

/// In-app diagnostic ring buffer — share when BLE drops / bugs show up.
///
/// HUD root MUST NOT observe this object: publishing on every BLE line
/// re-renders the entire map + Metal tree and can SIGABRT (IOGPUMetalFence).
/// Only DiagLogViewer (Settings → Logları aç) should observe.
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
    /// Cheap count for Settings badge without requiring HUD observation.
    @Published private(set) var entryCount: Int = 0

    private let maxEntries = 400
    private let queue = DispatchQueue(label: "pulse.diaglog", qos: .utility)
    private var pending: [Entry] = []
    private var flushScheduled = false
    /// Cap UI publish rate — Metal crash was from thrashing SwiftUI on every BLE frame.
    private let flushInterval: TimeInterval = 0.8

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
        #if DEBUG
        print("PulseDiag [\(level.rawValue)] \(trimmed)")
        #endif
        queue.async {
            self.pending.append(entry)
            guard !self.flushScheduled else { return }
            self.flushScheduled = true
            self.queue.asyncAfter(deadline: .now() + self.flushInterval) {
                self.flushPending()
            }
        }
    }

    private func flushPending() {
        flushScheduled = false
        guard !pending.isEmpty else { return }
        let batch = pending
        pending.removeAll(keepingCapacity: true)
        DispatchQueue.main.async {
            // Newest first (same order as before).
            var next = batch.reversed() + self.entries
            if next.count > self.maxEntries {
                next = Array(next.prefix(self.maxEntries))
            }
            self.entries = next
            self.entryCount = next.count
        }
    }

    func clear() {
        queue.async {
            self.pending.removeAll()
            DispatchQueue.main.async {
                self.entries = []
                self.entryCount = 0
                // Re-seed after clear (goes through coalesce).
                self.info("Log cleared")
            }
        }
    }

    var exportText: String {
        let header = "Pulse28 diag · \(ISO8601DateFormatter().string(from: Date()))\n"
        let body = entries.reversed().map(\.line).joined(separator: "\n")
        return header + body
    }
}
