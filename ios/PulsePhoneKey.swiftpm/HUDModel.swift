import Foundation
import Combine
import SwiftUI

/// Night triad — 5 left slides. No CoreLocation / WebKit (Playgrounds crash-safe).
@MainActor
final class HUDModel: ObservableObject {
    static let slideCount = 5
    static let slideNames = ["Sade", "Lastik", "Rota", "Harita", "Medya"]
    /// Safe SF Symbols only
    static let slideIcons = ["square", "car.fill", "flag.fill", "map", "music.note"]

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
    @Published var leftSlide = 4
    @Published var leftRailVisible = true
    @Published var mapHeading: Double = -8
    @Published var telemetrySource = "yerel"
    @Published var mapPulse: Double = 0

    private var timer: AnyCancellable?
    private var pollTask: Task<Void, Never>?
    private var phase: Double = 0
    private var leftCool: Date = .distantPast
    private var useVehicleFeed = false

    private let clockFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm"
        return f
    }()

    func configure(vin raw: String, paired: Bool) {
        vin = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        vinTail = String(vin.suffix(6))
        bleOK = paired
        night = true
        leftSlide = 4
        refreshClock()
        start()
    }

    func start() {
        timer?.cancel()
        phase = 0
        timer = Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
        startVehiclePoll()
    }

    func stop() {
        timer?.cancel(); timer = nil
        pollTask?.cancel(); pollTask = nil
    }

    func toggleDrive() {
        guard !useVehicleFeed else { return }
        driving.toggle()
        gear = driving ? "D" : "P"
        if !driving { speed = 0; powerKW = 0 }
    }

    func beginAfterPair() {}
    func togglePlay() { mediaPlaying.toggle() }

    func nudgeLeft(_ delta: Int) {
        guard Date().timeIntervalSince(leftCool) > 0.22 else { return }
        leftCool = Date()
        leftSlide = ((leftSlide + delta) % Self.slideCount + Self.slideCount) % Self.slideCount
        leftRailVisible = true
    }

    func nudgeRight(_ delta: Int) { nudgeLeft(delta) }

    func setLeft(_ i: Int) {
        leftSlide = ((i % Self.slideCount) + Self.slideCount) % Self.slideCount
        leftRailVisible = true
    }

    func setRight(_ i: Int) { setLeft(i) }

    private func startVehiclePoll() {
        pollTask?.cancel()
        let base = (UserDefaults.standard.string(forKey: "pulse_dash_url") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let pin = (UserDefaults.standard.string(forKey: "pulse_pin") ?? "428462")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty, let root = URL(string: base) else {
            useVehicleFeed = false
            telemetrySource = "demo"
            return
        }
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                await pullVehicle(root: root, pin: pin)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func pullVehicle(root: URL, pin: String) async {
        var comps = URLComponents(url: root.appendingPathComponent("api/vehicle/state"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "pin", value: pin)]
        guard let final = comps?.url else { return }
        do {
            let (data, resp) = try await URLSession.shared.data(from: final)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (obj["ok"] as? Bool) == true else {
                useVehicleFeed = false
                telemetrySource = "demo"
                return
            }
            useVehicleFeed = true
            let src = (obj["source"] as? String) ?? "demo"
            telemetrySource = src == "live" ? "live" : "dash"
            if let h = num(obj["heading"]) { mapHeading = h }
            if let sp = num(obj["speed_kmh"]) { speed = sp; driving = sp > 1.5 }
            if let bat = num(obj["battery_percent"]) { battery = bat }
            if let rng = num(obj["battery_range_km"]) { rangeKm = Int(rng) }
            if let g = obj["gear"] as? String, !g.isEmpty { gear = g }
            if let odo = num(obj["odometer_km"]) { odometer = odo }
            if let st = obj["street"] as? String, !st.isEmpty { place = st }
            if let d = obj["destination"] as? String, !d.isEmpty, d != "--" { destination = d }
            if let a = obj["arrival_time"] as? String, !a.isEmpty, a != "--" { eta = a }
            if let e = obj["energy_at_arrival"] as? String, !e.isEmpty, e != "--" { energyAtArrival = e }
            if let td = obj["trip_distance_km"] as? String, !td.isEmpty, td != "--" { tripDist = td }
            if let mt = obj["media_title"] as? String { mediaTitle = mt }
            if let ma = obj["media_artist"] as? String { mediaArtist = ma }
            if let ms = obj["media_service"] as? String { mediaService = ms }
            if let t = num(obj["tire_fl"]) { psiFL = Int(t) }
            if let t = num(obj["tire_fr"]) { psiFR = Int(t) }
            if let t = num(obj["tire_rl"]) { psiRL = Int(t) }
            if let t = num(obj["tire_rr"]) { psiRR = Int(t) }
            if let temp = num(obj["outside_temp_c"]) { outdoorC = Int(temp) }
        } catch {
            useVehicleFeed = false
            telemetrySource = "demo"
        }
    }

    private func num(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String { return Double(s) }
        return nil
    }

    private func refreshClock() { clock = clockFmt.string(from: Date()) }

    private func tick() {
        phase += 0.2
        mapPulse = phase
        if Int(phase * 5) % 5 == 0 { refreshClock() }
        guard !useVehicleFeed else { return }
        if driving {
            let wave = (sin(phase * 0.35) + 1) * 0.5
            let target = 40 + wave * 70
            speed += (target - speed) * 0.1
            powerKW = (target - speed) * 1.2
            let dKm = speed / 3600.0 * 0.2
            tripKm += dKm
            odometer += dKm
            tripDist = String(format: "%.1f km", max(0, 13.3 - tripKm))
            eta = clockFmt.string(from: Date().addingTimeInterval(900))
            energyAtArrival = "\(max(5, Int(battery) - Int(tripKm / 3)))%"
            mapHeading = 10 + sin(phase) * 25
        } else {
            speed += (0 - speed) * 0.15
            powerKW += (0 - powerKW) * 0.2
        }
    }
}
