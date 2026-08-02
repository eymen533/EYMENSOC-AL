import Foundation
import Combine
import SwiftUI

/// Night triad — live Tesla telemetry via Dash `/api/vehicle/state`.
/// Local demo only when Dash unreachable. No CoreLocation / WebKit.
@MainActor
final class HUDModel: ObservableObject {
    static let slideCount = 5
    static let slideNames = ["Sade", "Lastik", "Rota", "Harita", "Medya"]
    static let slideIcons = ["square", "car.fill", "flag.fill", "map", "music.note"]

    @Published var speed: Double = 0
    @Published var battery: Double = 0
    @Published var powerKW: Double = 0
    @Published var gear: String = "P"
    @Published var rangeKm: Int = 0
    @Published var odometer: Double = 0
    @Published var tripKm: Double = 0
    @Published var psiFL = 0
    @Published var psiFR = 0
    @Published var psiRL = 0
    @Published var psiRR = 0
    @Published var outdoorC: Int = 0
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
    @Published var mediaService = "—"
    @Published var mediaTitle = "—"
    @Published var mediaArtist = "—"
    @Published var mediaPlaying = false
    @Published var mediaProgress: Double = 0
    @Published var mediaVolume: Double = 0.5
    @Published var clock = ""
    @Published var leftSlide = 0
    @Published var leftRailVisible = true
    @Published var mapHeading: Double = 0
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var telemetrySource = "baglaniyor"
    @Published var feedOK = false
    @Published var isLive = false
    @Published var vehicleName = ""
    @Published var feedError = ""
    @Published var mapPulse: Double = 0
    @Published var charging = false

    private var timer: AnyCancellable?
    private var pollTask: Task<Void, Never>?
    private var phase: Double = 0
    private var leftCool: Date = .distantPast
    private var useVehicleFeed = false
    private var localDemo = false

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

    var liveLocked: Bool { isLive || useVehicleFeed }

    func configure(vin raw: String, paired: Bool) {
        vin = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        vinTail = String(vin.suffix(6))
        bleOK = paired
        night = true
        leftSlide = 0
        feedOK = false
        isLive = false
        useVehicleFeed = false
        localDemo = false
        telemetrySource = "baglaniyor"
        feedError = ""
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
        // Live / dash feed: car controls gear — HUD is read-only
        guard !liveLocked else { return }
        localDemo = true
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
        guard !liveLocked else { return }
        localDemo = true
        gear = g
        if g == "D" || g == "R" {
            driving = true
        } else {
            driving = false
            speed = 0
            powerKW = 0
        }
    }

    func beginAfterPair() {}

    func togglePlay() {
        guard !isLive else { return }
        mediaPlaying.toggle()
    }

    func skipTrack(_ delta: Int) {
        guard !isLive else { return }
        trackIndex = ((trackIndex + delta) % tracks.count + tracks.count) % tracks.count
        mediaTitle = tracks[trackIndex].0
        mediaArtist = tracks[trackIndex].1
        mediaProgress = 0.05
        mediaPlaying = true
    }

    func nudgeVolume(_ delta: Double) {
        guard !isLive else { return }
        mediaVolume = min(1, max(0, mediaVolume + delta))
    }

    func adjustTire(_ corner: String, delta: Int) {
        guard !liveLocked else { return }
        switch corner {
        case "FL": psiFL = clampPsi(psiFL + delta)
        case "FR": psiFR = clampPsi(psiFR + delta)
        case "RL": psiRL = clampPsi(psiRL + delta)
        case "RR": psiRR = clampPsi(psiRR + delta)
        default: break
        }
    }

    func resetTires() {
        guard !liveLocked else { return }
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

    func enableLiveOnDash(token: String, vehicleId: String, pin: String, dashURL: String) async -> String {
        let base = dashURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let root = URL(string: base) else { return "Dash URL gecersiz" }
        var req = URLRequest(url: root.appendingPathComponent("api/tesla/enable"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(pin, forHTTPHeaderField: "X-Pulse-Pin")
        let body: [String: Any] = [
            "pin": pin,
            "access_token": token,
            "vehicle_id": vehicleId,
            "vin": vin,
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if code == 200, (obj?["ok"] as? Bool) == true {
                isLive = true
                feedOK = true
                telemetrySource = "live"
                if let n = obj?["vehicle_name"] as? String { vehicleName = n }
                return "Canli baglandi ✓"
            }
            return (obj?["error"] as? String) ?? "Canli acilamadi (\(code))"
        } catch {
            return error.localizedDescription
        }
    }

    private func startVehiclePoll() {
        pollTask?.cancel()
        let base = (UserDefaults.standard.string(forKey: "pulse_dash_url") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pin = (UserDefaults.standard.string(forKey: "pulse_pin") ?? "428462")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty, let root = URL(string: base) else {
            useVehicleFeed = false
            feedOK = false
            isLive = false
            localDemo = true
            telemetrySource = "demo"
            feedError = "Settings → Dash URL gir"
            seedLocalDemo()
            return
        }
        pollTask = Task { @MainActor in
            var fails = 0
            while !Task.isCancelled {
                let ok = await pullVehicle(root: root, pin: pin)
                if ok {
                    fails = 0
                } else {
                    fails += 1
                    if fails >= 3 && !useVehicleFeed {
                        localDemo = true
                        telemetrySource = "demo"
                        feedError = "Dash’e ulasilamadi — Settings URL/PIN"
                        if speed == 0 && battery == 0 { seedLocalDemo() }
                    }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func seedLocalDemo() {
        battery = 69
        rangeKm = 331
        odometer = 74_832
        psiFL = 42; psiFR = 42; psiRL = 41; psiRR = 42
        outdoorC = 28
        place = "Konum yok"
        destination = "—"
        eta = "—"
        energyAtArrival = "—"
        tripDist = "—"
        mediaTitle = "—"
        mediaArtist = "—"
        mediaService = "—"
        latitude = 41.0082
        longitude = 28.9784
    }

    @discardableResult
    private func pullVehicle(root: URL, pin: String) async -> Bool {
        var comps = URLComponents(url: root.appendingPathComponent("api/vehicle/state"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "pin", value: pin)]
        guard let final = comps?.url else { return false }
        do {
            var req = URLRequest(url: final, timeoutInterval: 8)
            req.setValue(pin, forHTTPHeaderField: "X-Pulse-Pin")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (obj["ok"] as? Bool) == true else {
                feedOK = false
                return false
            }
            useVehicleFeed = true
            feedOK = true
            feedError = ""
            localDemo = false
            let src = ((obj["source"] as? String) ?? "demo").lower()
            isLive = src == "live"
            telemetrySource = isLive ? "LIVE" : "dash"
            if let n = obj["vehicle_name"] as? String, !n.isEmpty { vehicleName = n }

            if let lat = num(obj["latitude"]) { latitude = lat }
            if let lon = num(obj["longitude"]) { longitude = lon }
            if let h = num(obj["heading"]) { mapHeading = h }
            if let sp = num(obj["speed_kmh"]) {
                speed = sp
                driving = abs(sp) > 1.5 || (obj["gear"] as? String) == "D" || (obj["gear"] as? String) == "R"
            }
            if let pw = num(obj["power_kw"]) { powerKW = pw }
            if let bat = num(obj["battery_percent"]) { battery = bat }
            if let rng = num(obj["battery_range_km"]) { rangeKm = Int(rng) }
            if let g = obj["gear"] as? String, !g.isEmpty { gear = g }
            if let odo = num(obj["odometer_km"]) { odometer = odo }
            if let st = obj["street"] as? String, !st.isEmpty, st != "--" { place = st }
            if let d = obj["destination"] as? String, !d.isEmpty, d != "--" { destination = d }
            if let a = obj["arrival_time"] as? String, !a.isEmpty, a != "--" { eta = a }
            if let e = obj["energy_at_arrival"] as? String, !e.isEmpty, e != "--" { energyAtArrival = e }
            if let td = obj["trip_distance_km"] as? String, !td.isEmpty, td != "--" { tripDist = td }
            if let mt = obj["media_title"] as? String { mediaTitle = mt }
            if let ma = obj["media_artist"] as? String { mediaArtist = ma }
            if let ms = obj["media_service"] as? String { mediaService = ms }
            if let mp = num(obj["media_progress"]) { mediaProgress = mp }
            if let t = num(obj["tire_fl"]) { psiFL = Int(t.rounded()) }
            if let t = num(obj["tire_fr"]) { psiFR = Int(t.rounded()) }
            if let t = num(obj["tire_rl"]) { psiRL = Int(t.rounded()) }
            if let t = num(obj["tire_rr"]) { psiRR = Int(t.rounded()) }
            if let temp = num(obj["outside_temp_c"]) { outdoorC = Int(temp.rounded()) }
            if let ch = obj["charging"] as? Bool { charging = ch }
            return true
        } catch {
            feedOK = false
            return false
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
        // Never animate over live / dash feed
        guard !useVehicleFeed else { return }
        guard localDemo else { return }
        if mediaPlaying {
            mediaProgress = min(1, mediaProgress + 0.002)
            if mediaProgress >= 1 { skipTrack(1) }
        }
        if driving {
            let wave = (sin(phase * 0.35) + 1) * 0.5
            let target = gear == "R" ? -(20 + wave * 15) : (48 + wave * 62)
            speed += (target - speed) * 0.12
            powerKW = abs(target - speed) * 1.1 + 8
            let dKm = abs(speed) / 3600.0 * 0.2
            tripKm += dKm
            odometer += dKm
            mapHeading = 10 + sin(phase) * 25
        } else {
            speed += (0 - speed) * 0.18
            powerKW += (0 - powerKW) * 0.2
        }
    }
}
