import Foundation
import Combine
import SwiftUI

/// Live cluster state — runs natively (no WebView). Demo drive after Pair.
@MainActor
final class HUDModel: ObservableObject {
    @Published var speed: Double = 0
    @Published var battery: Double = 78
    @Published var powerKW: Double = 0
    @Published var gear: String = "P"
    @Published var rangeKm: Int = 342
    @Published var odometer: Double = 12840
    @Published var tripKm: Double = 0
    @Published var psiFL = 42
    @Published var psiFR = 42
    @Published var psiRL = 42
    @Published var psiRR = 42
    @Published var outdoorC: Int = 24
    @Published var night = true
    @Published var vinTail: String = "159959"
    @Published var bleOK = false
    @Published var driving = false

    private var timer: AnyCancellable?
    private var t0 = Date()
    private var phase: Double = 0

    func configure(vin: String, paired: Bool) {
        vinTail = String(vin.suffix(6))
        bleOK = paired
        start()
    }

    func start() {
        timer?.cancel()
        t0 = Date()
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
        } else {
            gear = "P"
            speed = 0
            powerKW = 0
        }
    }

    private func tick() {
        phase += 1.0 / 30.0
        if driving {
            // Smooth demo speed profile
            let wave = (sin(phase * 0.35) + 1) * 0.5
            let target = 40 + wave * 70
            speed += (target - speed) * 0.04
            powerKW = (target - speed) * 1.2 + sin(phase * 2) * 8
            tripKm += speed / 3600.0 / 30.0 * 30 // km per tick approx
            odometer += speed / 3600.0 / 30.0 * 30
            if phase.truncatingRemainder(dividingBy: 8) < 0.05 {
                battery = max(5, battery - 0.01)
                rangeKm = Int(battery / 100 * 440)
            }
        } else {
            speed += (0 - speed) * 0.08
            powerKW += (0 - powerKW) * 0.1
        }
        // Slight PSI jitter
        if Int(phase * 10) % 90 == 0 {
            psiFL = 41 + Int.random(in: 0...2)
            psiFR = 41 + Int.random(in: 0...2)
            psiRL = 41 + Int.random(in: 0...2)
            psiRR = 41 + Int.random(in: 0...2)
        }
    }
}
