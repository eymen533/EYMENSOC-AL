import Foundation
import Combine
import SwiftUI

/// Night triad HUD — live map coords + optional Dash vehicle feed.
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
    @Published var leftSlide = 3
    @Published var rightSlide = 2
    @Published var leftRailVisible = true
    @Published var rightRailVisible = false

    /// Live map
    @Published var mapLat: Double = 41.025
    @Published var mapLon: Double = 29.02
    @Published var mapHeading: Double = 0
    @Published var mapSource = "Telefon GPS"
    @Published var telemetrySource = "yerel demo"
    @Published var followMap = true

    let location = LocationProvider()

    private var timer: AnyCancellable?
    private var locBag: AnyCancellable?
    private var pollTask: Task<Void, Never>?
    private var phase: Double = 0
    private var leftCool: Date = .distantPast
    private var rightCool: Date = .distantPast
    private var leftRailTask: Task<Void, Never>?
    private var rightRailTask: Task<Void, Never>?
    private var useVehicleFeed = false

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
        location.start()
        locBag?.cancel()
        locBag = location.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncPhoneGPS()
            }
        syncPhoneGPS()

        timer = Timer.publish(every: 1.0 / 15.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }

        startVehiclePoll()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        locBag?.cancel()
        locBag = nil
        pollTask?.cancel()
        pollTask = nil
        leftRailTask?.cancel()
        rightRailTask?.cancel()
        location.stop()
    }

    func toggleDrive() {
        // Local demo drive only when vehicle feed is off
        guard !useVehicleFeed else { return }
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

    private func syncPhoneGPS() {
        // Prefer phone GPS for map unless Dash vehicle feed provides coords
        if useVehicleFeed { return }
        mapLat = location.lat
        mapLon = location.lon
        mapHeading = location.heading
        mapSource = location.authorized ? "Telefon GPS" : location.statusText
    }

    private func startVehiclePoll() {
        pollTask?.cancel()
        let base = (UserDefaults.standard.string(forKey: "pulse_dash_url") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let pin = (UserDefaults.standard.string(forKey: "pulse_pin") ?? "428462")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty, let root = URL(string: base) else {
            useVehicleFeed = false
            telemetrySource = "yerel demo · harita GPS"
            return
        }
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                await self.pullVehicle(root: root, pin: pin)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    private func pullVehicle(root: URL, pin: String) async {
        var url = root.appendingPathComponent("api/vehicle/state")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "pin", value: pin)]
        guard let final = comps?.url else { return }
        do {
            let (data, resp) = try await URLSession.shared.data(from: final)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (obj["ok"] as? Bool) == true
            else {
                useVehicleFeed = false
                telemetrySource = "Dash baglanti yok · GPS"
                syncPhoneGPS()
                return
            }
            useVehicleFeed = true
            let src = (obj["source"] as? String) ?? "demo"
            telemetrySource = src == "live" ? "Tesla API (canli)" : "Dash demo rota"
            if let lat = Self.num(obj["latitude"]), let lon = Self.num(obj["longitude"]) {
                mapLat = lat
                mapLon = lon
                mapSource = src == "live" ? "Arac GPS" : "Dash demo"
            }
            if let h = Self.num(obj["heading"]) { mapHeading = h }
            if let sp = Self.num(obj["speed_kmh"]) {
                speed = sp
                driving = sp > 1.5
            }
            if let bat = Self.num(obj["battery_percent"]) { battery = bat }
            if let rng = Self.num(obj["battery_range_km"]) { rangeKm = Int(rng) }
            if let g = obj["gear"] as? String, !g.isEmpty { gear = g }
            if let odo = Self.num(obj["odometer_km"]) { odometer = odo }
            if let st = obj["street"] as? String, !st.isEmpty { place = st }
            if let d = obj["destination"] as? String, !d.isEmpty, d != "--" { destination = d }
            if let a = obj["arrival_time"] as? String, !a.isEmpty, a != "--" { eta = a }
            if let e = obj["energy_at_arrival"] as? String, !e.isEmpty, e != "--" { energyAtArrival = e }
            if let td = obj["trip_distance_km"] as? String, !td.isEmpty, td != "--" {
                tripDist = td
            } else if let td = Self.num(obj["trip_distance_km"]) {
                tripDist = String(format: "%.1f km", td)
            }
            if let mt = obj["media_title"] as? String { mediaTitle = mt }
            if let ma = obj["media_artist"] as? String { mediaArtist = ma }
            if let ms = obj["media_service"] as? String { mediaService = ms }
            if let t = Self.num(obj["tire_fl"]) { psiFL = Int(t) }
            if let t = Self.num(obj["tire_fr"]) { psiFR = Int(t) }
            if let t = Self.num(obj["tire_rl"]) { psiRL = Int(t) }
            if let t = Self.num(obj["tire_rr"]) { psiRR = Int(t) }
            if let temp = Self.num(obj["outside_temp_c"]) { outdoorC = Int(temp) }
        } catch {
            useVehicleFeed = false
            telemetrySource = "Dash yok · GPS"
            syncPhoneGPS()
        }
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

    private static func num(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String { return Double(s) }
        return nil
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

        // Local sine demo only when not fed by Dash
        guard !useVehicleFeed else { return }

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
