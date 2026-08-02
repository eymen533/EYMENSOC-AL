import Foundation
import Combine
import SwiftUI

/// On-device cluster state matching classic Dash fields — no WebView.
@MainActor
final class HUDModel: ObservableObject {
    @Published var speed: Double = 0
    @Published var battery: Double = 68
    @Published var powerKW: Double = 0
    @Published var gear: String = "P"
    @Published var rangeKm: Int = 328
    @Published var odometer: Double = 74_832
    @Published var tripKm: Double = 0
    @Published var psiFL = 42
    @Published var psiFR = 42
    @Published var psiRL = 42
    @Published var psiRR = 42
    @Published var outdoorC: Int = 29
    @Published var night = true
    @Published var vin: String = "XP7YGCEK0PB159959"
    @Published var vinTail: String = "159959"
    @Published var bleOK = false
    @Published var bleLabel = "BLE"
    @Published var driving = false
    @Published var destination = "—"
    @Published var eta = "—"
    @Published var energyAtArrival = "—"
    @Published var tripDist = "—"
    @Published var place = "—"
    @Published var mediaTitle = "—"
    @Published var mediaArtist = "—"
    @Published var clock = ""
    @Published var dayName = ""
    @Published var dateLine = ""
    @Published var nextPrayer = "Öğle —"
    @Published var leftSlide = 0   // 0 trip, 1 tires
    @Published var rightSlide = 0  // 0 map, 1 media

    private var timer: AnyCancellable?
    private var phase: Double = 0

    private let clockFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm"
        return f
    }()
    private let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "EEEE"
        return f
    }()
    private let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    func configure(vin raw: String, paired: Bool) {
        let v = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        vin = v
        vinTail = String(v.suffix(6))
        bleOK = paired
        bleLabel = paired ? "GATT · KEY" : "BLE"
        if paired {
            destination = "Sabiha Gökçen"
            energyAtArrival = "\(Int(battery))%"
            place = "Konum · telefon"
            mediaTitle = "Pulse"
            mediaArtist = "Phone Key"
        }
        refreshClock()
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
        } else {
            gear = "P"
            speed = 0
            powerKW = 0
        }
    }

    func beginAfterPair() {
        if bleOK, !driving { toggleDrive() }
    }

    func cycleLeft() { leftSlide = (leftSlide + 1) % 2 }
    func cycleRight() { rightSlide = (rightSlide + 1) % 2 }

    private func refreshClock() {
        let now = Date()
        clock = clockFmt.string(from: now)
        dayName = dayFmt.string(from: now).capitalized
        dateLine = dateFmt.string(from: now)
        nextPrayer = "Öğle 13:10"
    }

    private func tick() {
        phase += 1.0 / 30.0
        if Int(phase * 30) % 30 == 0 { refreshClock() }

        if driving {
            let wave = (sin(phase * 0.35) + 1) * 0.5
            let target = 40 + wave * 70
            speed += (target - speed) * 0.04
            powerKW = (target - speed) * 1.2 + sin(phase * 2) * 8
            let dKm = speed / 3600.0 / 30.0
            tripKm += dKm
            odometer += dKm
            tripDist = String(format: "%.1f km", tripKm)
            let remainMin = max(1, Int(max(0, 18 - tripKm * 1.4)))
            eta = clockFmt.string(from: Date().addingTimeInterval(TimeInterval(remainMin * 60)))
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
