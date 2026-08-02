import Foundation
import Combine
import SwiftUI

/// On-device cluster — night triad (left slides | black dial | 3D map).
@MainActor
final class HUDModel: ObservableObject {
    static let slideCount = 4
    static let slideNames = ["Seyahat", "Lastik", "Harita", "Medya"]

    @Published var speed: Double = 0
    @Published var battery: Double = 69
    @Published var powerKW: Double = 0
    @Published var gear: String = "P"
    @Published var rangeKm: Int = 331
    @Published var odometer: Double = 74_832
    @Published var tripKm: Double = 0
    @Published var psiFL = 42
    @Published var psiFR = 42
    @Published var psiRL = 41
    @Published var psiRR = 42
    @Published var outdoorC: Int = 29
    @Published var night = true
    @Published var vin: String = "XP7YGCEK0PB159959"
    @Published var vinTail: String = "159959"
    @Published var bleOK = false
    @Published var driving = false
    @Published var destination = "Sabiha Gökçen"
    @Published var eta = "19:12"
    @Published var energyAtArrival = "66%"
    @Published var tripDist = "13.3 km"
    @Published var place = "Ertürk Sk. No:29"
    @Published var mediaService = "YouTube Music"
    @Published var mediaTitle = "Kayıp Kalp"
    @Published var mediaArtist = "BLOK3"
    @Published var mediaPlaying = false
    @Published var clock = ""
    @Published var dayName = ""
    @Published var dateLine = ""
    @Published var nextPrayer = "Öğle 13:10"
    /// Screenshot default: media left, map always right
    @Published var leftSlide = 3
    @Published var rightSlide = 2
    @Published var leftRailVisible = true
    @Published var rightRailVisible = false

    private var timer: AnyCancellable?
    private var phase: Double = 0
    private var leftCool: Date = .distantPast
    private var rightCool: Date = .distantPast
    private var leftRailTask: Task<Void, Never>?
    private var rightRailTask: Task<Void, Never>?

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
        night = true
        leftSlide = 3
        rightSlide = 2
        leftRailVisible = true
        if paired {
            energyAtArrival = "\(Int(battery))%"
        }
        refreshClock()
        start()
    }

    func start() {
        timer?.cancel()
        phase = 0
        // ~15 Hz — smooth dial, light on Playgrounds
        timer = Timer.publish(every: 1.0 / 15.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        leftRailTask?.cancel()
        rightRailTask?.cancel()
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

    func nudgeLeft(_ delta: Int) {
        guard Date().timeIntervalSince(leftCool) > 0.28 else { return }
        leftCool = Date()
        leftSlide = ((leftSlide + delta) % Self.slideCount + Self.slideCount) % Self.slideCount
        flashLeftRail()
    }

    func nudgeRight(_ delta: Int) {
        guard Date().timeIntervalSince(rightCool) > 0.28 else { return }
        rightCool = Date()
        rightSlide = ((rightSlide + delta) % Self.slideCount + Self.slideCount) % Self.slideCount
        flashRightRail()
    }

    func setLeft(_ i: Int) {
        leftSlide = ((i % Self.slideCount) + Self.slideCount) % Self.slideCount
        flashLeftRail()
    }

    func setRight(_ i: Int) {
        rightSlide = ((i % Self.slideCount) + Self.slideCount) % Self.slideCount
        flashRightRail()
    }

    private func flashLeftRail() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            leftRailVisible = true
        }
        leftRailTask?.cancel()
        leftRailTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                leftRailVisible = false
            }
        }
    }

    private func flashRightRail() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            rightRailVisible = true
        }
        rightRailTask?.cancel()
        rightRailTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                rightRailVisible = false
            }
        }
    }

    private func refreshClock() {
        let now = Date()
        clock = clockFmt.string(from: now)
        dayName = dayFmt.string(from: now).capitalized
        dateLine = dateFmt.string(from: now)
    }

    private func tick() {
        let dt = 1.0 / 15.0
        phase += dt
        if Int(phase * 15) % 15 == 0 { refreshClock() }

        if driving {
            let wave = (sin(phase * 0.35) + 1) * 0.5
            let target = 40 + wave * 70
            speed += (target - speed) * 0.08
            powerKW = (target - speed) * 1.2 + sin(phase * 2) * 8
            let dKm = speed / 3600.0 * dt
            tripKm += dKm
            odometer += dKm
            tripDist = String(format: "%.1f km", max(0, 13.3 - tripKm))
            let remainMin = max(1, Int(max(0, 18 - tripKm * 1.4)))
            eta = clockFmt.string(from: Date().addingTimeInterval(TimeInterval(remainMin * 60)))
            energyAtArrival = "\(max(5, Int(battery) - Int(tripKm / 3)))%"
            if Int(phase * 5) % 20 == 0 {
                battery = max(5, battery - 0.02)
                rangeKm = Int(battery / 100 * 440)
            }
        } else {
            speed += (0 - speed) * 0.12
            powerKW += (0 - powerKW) * 0.15
        }

        if Int(phase * 5) % 45 == 0 {
            psiFL = 41 + Int.random(in: 0...2)
            psiFR = 41 + Int.random(in: 0...2)
            psiRL = 41 + Int.random(in: 0...2)
            psiRR = 41 + Int.random(in: 0...2)
        }
    }
}
