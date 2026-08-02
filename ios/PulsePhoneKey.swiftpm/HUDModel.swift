import Foundation
import Combine
import SwiftUI

/// On-device cluster state — no WebView, no remote Dash server.
/// After BLE Pair, the same app drives the gauges (demo telemetry until live BLE stream exists).
@MainActor
final class HUDModel: ObservableObject {
    @Published var speed: Double = 0
    @Published var battery: Double = 78
    @Published var powerKW: Double = 0
    @Published var gear: String = "P"
    @Published var rangeKm: Int = 342
    @Published var odometer: Double = 74_832
    @Published var tripKm: Double = 0
    @Published var psiFL = 42
    @Published var psiFR = 42
    @Published var psiRL = 42
    @Published var psiRR = 42
    @Published var outdoorC: Int = 24
    @Published var night = true
    @Published var vin: String = "XP7YGCEK0PB159959"
    @Published var vinTail: String = "159959"
    @Published var bleOK = false
    @Published var driving = false
    @Published var destination = "—"
    @Published var eta = "—"
    @Published var energyAtArrival = "—"
    @Published var tripDist = "—"
    @Published var place = "—"
    @Published var mediaTitle = "Pulse"
    @Published var mediaArtist = "Phone Key bagli"
    @Published var clock = ""

    private var timer: AnyCancellable?
    private var phase: Double = 0
    private let clockFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm"
        return f
    }()

    func configure(vin raw: String, paired: Bool) {
        let v = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        vin = v
        vinTail = String(v.suffix(6))
        bleOK = paired
        if paired {
            destination = "Sabiha Gokcen"
            eta = "—"
            energyAtArrival = "\(Int(battery))%"
            tripDist = "—"
            place = "Konum · telefon"
            mediaArtist = "Key session hazir"
        }
        start()
    }

    func start() {
        timer?.cancel()
        phase = 0
        timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func toggleDrive() {
        driving.toggle()
        if driving {
            gear = "D"
            mediaTitle = "Surus"
            mediaArtist = "Demo telemetri · cihazda"
        } else {
            gear = "P"
            speed = 0
            powerKW = 0
            mediaTitle = "Park"
            mediaArtist = bleOK ? "Key session hazir" : "Pair gerekli"
        }
    }

    /// Auto-start demo motion when opening HUD after a successful pair.
    func beginAfterPair() {
        if bleOK, !driving {
            toggleDrive()
        }
    }

    private func tick() {
        phase += 1.0 / 30.0
        if Int(phase * 30) % 30 == 0 {
            clock = clockFmt.string(from: Date())
        }

        if driving {
            let wave = (sin(phase * 0.35) + 1) * 0.5
            let target = 40 + wave * 70
            speed += (target - speed) * 0.04
            powerKW = (target - speed) * 1.2 + sin(phase * 2) * 8
            // km per second ≈ speed/3600; tick is 1/30 s
            let dKm = speed / 3600.0 / 30.0
            tripKm += dKm
            odometer += dKm
            tripDist = String(format: "%.1f km", tripKm)
            let remainMin = max(1, Int(max(0, 18 - tripKm * 1.4)))
            let arrive = Date().addingTimeInterval(TimeInterval(remainMin * 60))
            eta = clockFmt.string(from: arrive)
            energyAtArrival = "\(max(5, Int(battery) - Int(tripKm / 3)))%"
            if Int(phase * 10) % 80 == 0 {
                battery = max(5, battery - 0.02)
                rangeKm = Int(battery / 100 * 440)
            }
        } else {
            speed += (0 - speed) * 0.08
            powerKW += (0 - powerKW) * 0.1
        }

        if Int(phase * 10) % 90 == 0 {
            psiFL = 41 + Int.random(in: 0...2)
            psiFR = 41 + Int.random(in: 0...2)
            psiRL = 41 + Int.random(in: 0...2)
            psiRR = 41 + Int.random(in: 0...2)
        }
    }
}
