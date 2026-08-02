import Foundation
import Combine
import SwiftUI

/// On-device cluster — day HUD + classic 4-slide side carousels (trip/tires/map/media).
@MainActor
final class HUDModel: ObservableObject {
    static let slideCount = 4
    static let slideNames = ["Seyahat", "Lastik", "Harita", "Medya"]

    @Published var speed: Double = 0
    @Published var battery: Double = 50
    @Published var powerKW: Double = 0
    @Published var gear: String = "P"
    @Published var rangeKm: Int = 240
    @Published var odometer: Double = 74_832
    @Published var tripKm: Double = 0
    @Published var psiFL = 42
    @Published var psiFR = 42
    @Published var psiRL = 41
    @Published var psiRR = 42
    @Published var outdoorC: Int = 28
    @Published var night = false
    @Published var vin: String = "XP7YGCEK0PB159959"
    @Published var vinTail: String = "159959"
    @Published var bleOK = false
    @Published var driving = false
    @Published var destination = "Sabiha Gökçen"
    @Published var eta = "—"
    @Published var energyAtArrival = "66%"
    @Published var tripDist = "13.3 km"
    @Published var place = "İstanbul"
    @Published var mediaService = "Apple Music"
    @Published var mediaTitle = "Holocene"
    @Published var mediaArtist = "Bon Iver"
    @Published var mediaPlaying = false
    @Published var clock = ""
    @Published var dayName = ""
    @Published var dateLine = ""
    @Published var nextPrayer = "Öğle 13:10"
    /// Same order as Dash: 0 trip, 1 tires, 2 map, 3 media
    @Published var leftSlide = 0
    @Published var rightSlide = 2

    private var timer: AnyCancellable?
    private var phase: Double = 0
    private var leftCool: Date = .distantPast
    private var rightCool: Date = .distantPast

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
        night = false
        leftSlide = 0
        rightSlide = 2
        if paired {
            energyAtArrival = "\(Int(battery))%"
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
        gear = driving ? "D" : "P"
        if !driving {
            speed = 0
            powerKW = 0
        }
    }

    func beginAfterPair() {}

    func togglePlay() { mediaPlaying.toggle() }

    /// delta +1 = swipe up (next), -1 = swipe down (prev)
    func nudgeLeft(_ delta: Int) {
        guard Date().timeIntervalSince(leftCool) > 0.28 else { return }
        leftCool = Date()
        leftSlide = ((leftSlide + delta) % Self.slideCount + Self.slideCount) % Self.slideCount
    }

    func nudgeRight(_ delta: Int) {
        guard Date().timeIntervalSince(rightCool) > 0.28 else { return }
        rightCool = Date()
        rightSlide = ((rightSlide + delta) % Self.slideCount + Self.slideCount) % Self.slideCount
    }

    func setLeft(_ i: Int) { leftSlide = ((i % Self.slideCount) + Self.slideCount) % Self.slideCount }
    func setRight(_ i: Int) { rightSlide = ((i % Self.slideCount) + Self.slideCount) % Self.slideCount }

    private func refreshClock() {
        let now = Date()
        clock = clockFmt.string(from: now)
        dayName = dayFmt.string(from: now).capitalized
        dateLine = dateFmt.string(from: now)
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
            tripDist = String(format: "%.1f km", max(0, 13.3 - tripKm))
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
