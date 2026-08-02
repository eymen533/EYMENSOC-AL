import Foundation
import Combine
import SwiftUI

/// Night triad — 5 left slides. No CoreLocation / WebKit (Playgrounds crash-safe).
@MainActor
final class HUDModel: ObservableObject {
    static let slideCount = 5
    static let slideNames = ["Sade", "Lastik", "Rota", "Harita", "Medya"]
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
    @Published var mediaProgress: Double = 0.28
    @Published var mediaVolume: Double = 0.55
    @Published var clock = ""
    @Published var leftSlide = 0
    @Published var leftRailVisible = true
    @Published var mapHeading: Double = -8
    @Published var telemetrySource = "yerel"
    @Published var mapPulse: Double = 0

    private var timer: AnyCancellable?
    private var pollTask: Task<Void, Never>?
    private var phase: Double = 0
    private var leftCool: Date = .distantPast
    private var useVehicleFeed = false

    private let tracks: [(String, String)] = [
        ("Kayıp Kalp", "BLOK3"),
        ("Yıldız Tozu", "Sezen Aksu"),
        ("Gesi Bağları", "Neşet Ertaş"),
        ("Dudu", "Tarkan"),
    ]
    private var trackIndex = 0

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
        leftSlide = 0
        refreshClock()
        start()
    }

    func start() {
        timer?.cancel()
        phase = 0
        timer = Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
        // build-41: Dash Owner API poll (no BLE AES, no MapKit).
        useVehicleFeed = false
        telemetrySource = "baglaniyor"
        startVehiclePoll()
        // Until first live packet: keep dial quiet in P (not fake driving).
        if !useVehicleFeed {
            driving = false
            gear = "P"
            speed = 0
            powerKW = 0
        }
    }

    func stop() {
        timer?.cancel(); timer = nil
        pollTask?.cancel(); pollTask = nil
    }

    func toggleDrive() {
        guard !useVehicleFeed else { return }
        driving.toggle()
        if driving {
            if gear == "P" || gear == "N" { gear = "D" }
        } else {
            gear = "P"
            speed = 0
            powerKW = 0
        }
    }

    func setGear(_ g: String) {
        guard ["P", "R", "N", "D"].contains(g) else { return }
        gear = g
        if useVehicleFeed { return }
        if g == "D" || g == "R" {
            driving = true
        } else {
            driving = false
            speed = 0
            powerKW = 0
        }
    }

    func beginAfterPair() {}

    func togglePlay() { mediaPlaying.toggle() }

    func skipTrack(_ delta: Int) {
        trackIndex = ((trackIndex + delta) % tracks.count + tracks.count) % tracks.count
        mediaTitle = tracks[trackIndex].0
        mediaArtist = tracks[trackIndex].1
        mediaProgress = 0.05
        mediaPlaying = true
    }

    func nudgeVolume(_ delta: Double) {
        mediaVolume = min(1, max(0, mediaVolume + delta))
    }

    func adjustTire(_ corner: String, delta: Int) {
        switch corner {
        case "FL": psiFL = clampPsi(psiFL + delta)
        case "FR": psiFR = clampPsi(psiFR + delta)
        case "RL": psiRL = clampPsi(psiRL + delta)
        case "RR": psiRR = clampPsi(psiRR + delta)
        default: break
        }
    }

    func resetTires() {
        psiFL = 42; psiFR = 42; psiRL = 41; psiRR = 42
    }

    private func clampPsi(_ v: Int) -> Int { min(50, max(28, v)) }

    func nudgeLeft(_ delta: Int) {
        guard Date().timeIntervalSince(leftCool) > 0.18 else { return }
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
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pin = (UserDefaults.standard.string(forKey: "pulse_pin") ?? "428462")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let token = (UserDefaults.standard.string(forKey: "pulse_tesla_token") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty, let root = URL(string: base) else {
            useVehicleFeed = false
            telemetrySource = "demo"
            // No Dash URL → local demo motion so HUD is not dead.
            driving = true
            gear = "D"
            return
        }
        telemetrySource = "baglaniyor"
        pollTask = Task { @MainActor in
            if !token.isEmpty {
                await enableLiveIfNeeded(root: root, pin: pin, token: token)
            }
            while !Task.isCancelled {
                await pullVehicle(root: root, pin: pin)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func enableLiveIfNeeded(root: URL, pin: String, token: String) async {
        let url = root.appendingPathComponent("api/tesla/enable")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(pin, forHTTPHeaderField: "X-Pulse-Pin")
        req.timeoutInterval = 20
        let body: [String: String] = [
            "pin": pin,
            "access_token": token,
            "vin": vin,
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: req)
    }

    private func pullVehicle(root: URL, pin: String) async {
        var comps = URLComponents(url: root.appendingPathComponent("api/vehicle/state"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "pin", value: pin)]
        guard let final = comps?.url else { return }
        var req = URLRequest(url: final)
        req.setValue(pin, forHTTPHeaderField: "X-Pulse-Pin")
        req.timeoutInterval = 12
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return }
            if http.statusCode == 401 {
                useVehicleFeed = false
                telemetrySource = "pin?"
                return
            }
            guard http.statusCode == 200,
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (obj["ok"] as? Bool) == true else {
                useVehicleFeed = false
                telemetrySource = "dash?"
                return
            }
            useVehicleFeed = true
            let src = (obj["source"] as? String) ?? "demo"
            telemetrySource = src == "live" ? "live" : (src == "demo" ? "dash-demo" : "dash")
            if let h = num(obj["heading"]) { mapHeading = h }
            if let sp = num(obj["speed_kmh"]) { speed = sp; driving = sp > 1.5 }
            if let pw = num(obj["power_kw"]) { powerKW = pw }
            if let bat = num(obj["battery_percent"]) { battery = bat }
            if let rng = num(obj["battery_range_km"]) { rangeKm = Int(rng) }
            if let g = obj["gear"] as? String, !g.isEmpty { gear = g }
            if let odo = num(obj["odometer_km"]) { odometer = odo }
            if let st = obj["street"] as? String, !st.isEmpty { place = st }
            if let d = obj["destination"] as? String, !d.isEmpty, d != "--" { destination = d }
            if let a = obj["arrival_time"] as? String, !a.isEmpty, a != "--" { eta = a }
            if let e = obj["energy_at_arrival"] as? String, !e.isEmpty, e != "--" { energyAtArrival = e }
            if let td = obj["trip_distance_km"] as? String, !td.isEmpty, td != "--" { tripDist = td }
            if let mt = obj["media_title"] as? String, !mt.isEmpty { mediaTitle = mt }
            if let ma = obj["media_artist"] as? String, !ma.isEmpty { mediaArtist = ma }
            if let ms = obj["media_service"] as? String, !ms.isEmpty { mediaService = ms }
            if let t = num(obj["tire_fl"]) { psiFL = Int(t) }
            if let t = num(obj["tire_fr"]) { psiFR = Int(t) }
            if let t = num(obj["tire_rl"]) { psiRL = Int(t) }
            if let t = num(obj["tire_rr"]) { psiRR = Int(t) }
            if let temp = num(obj["outside_temp_c"]) { outdoorC = Int(temp) }
        } catch {
            useVehicleFeed = false
            telemetrySource = "offline"
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
        if mediaPlaying {
            mediaProgress = min(1, mediaProgress + 0.002)
            if mediaProgress >= 1 { skipTrack(1) }
        }
        guard !useVehicleFeed else { return }
        if driving {
            let wave = (sin(phase * 0.35) + 1) * 0.5
            let target = gear == "R" ? -(20 + wave * 15) : (48 + wave * 62)
            speed += (target - speed) * 0.12
            powerKW = abs(target - speed) * 1.1 + (driving ? 8 : 0)
            let dKm = abs(speed) / 3600.0 * 0.2
            tripKm += dKm
            odometer += dKm
            tripDist = String(format: "%.1f km", max(0, 13.3 - tripKm))
            eta = clockFmt.string(from: Date().addingTimeInterval(max(60, 900 - tripKm * 40)))
            energyAtArrival = "\(max(5, Int(battery) - Int(tripKm / 3)))%"
            mapHeading = 10 + sin(phase) * 25
        } else {
            speed += (0 - speed) * 0.18
            powerKW += (0 - powerKW) * 0.2
        }
    }
}
