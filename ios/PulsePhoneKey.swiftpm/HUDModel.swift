import Foundation
import Combine
import SwiftUI
import UIKit

/// Night triad — prefers real BLE vehicle-command telemetry; Dash/API fallback.
/// Map uses phone GPS when the car is offline (Dashla-style).
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
    @Published var doorFL = false
    @Published var doorFR = false
    @Published var doorRL = false
    @Published var doorRR = false
    @Published var frunkOpen = false
    @Published var trunkOpen = false
    @Published var chargePortOpen = false
    @Published var locked = false
    @Published var lightParking = false
    @Published var lightLow = false
    @Published var lightHigh = false
    @Published var lightFog = false
    @Published var turnLeft = false
    @Published var turnRight = false
    @Published var vin: String = ""
    @Published var vinTail: String = ""
    @Published var bleOK = false
    @Published var driving = false
    @Published var destination = "—"
    @Published var destLatitude: Double = 0
    @Published var destLongitude: Double = 0
    @Published var eta = "—"
    @Published var energyAtArrival = "—"
    @Published var tripDist = "—"
    @Published var place = "—"
    @Published var mediaService = "—"
    @Published var mediaTitle = "—"
    @Published var mediaArtist = "—"
    @Published var mediaAlbum = "—"
    @Published var mediaPlaying = false
    @Published var mediaProgress: Double = 0
    @Published var mediaVolume: Double = 0.5
    @Published var clock = ""
    @Published var leftSlide = 4
    @Published var rightSlide = 3
    @Published var leftRailVisible = false
    @Published var rightRailVisible = false
    @Published var mapHeading: Double = 0
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var turnDistanceM: Int = 0
    @Published var turnInstruction: String = ""
    @Published var turnSymbol: String = "arrow.up"
    @Published var telemetrySource = "baglaniyor"
    @Published var feedOK = false
    @Published var isLive = false
    @Published var vehicleName = ""
    @Published var feedError = ""
    @Published var mapPulse: Double = 0
    @Published var charging = false
    @Published var googleMapsKey: String = ""
    @Published var phoneBattery: Int = 0

    private var timer: AnyCancellable?
    private var pollTask: Task<Void, Never>?
    private var phase: Double = 0
    private var leftCool: Date = .distantPast
    private var rightCool: Date = .distantPast
    private var leftRailHideTask: Task<Void, Never>?
    private var rightRailHideTask: Task<Void, Never>?
    private var useVehicleFeed = false
    private var useBLE = false
    private var localDemo = false
    /// Rail icons stay visible this long, then fade (Dashla-like).
    private let railVisibleSeconds: UInt64 = 2_500_000_000

    /// Optional BLE media / volume actuators (wired from ContentView).
    var bleSetVolume: ((Double) -> Void)?
    var bleMediaPlay: (() -> Void)?
    var bleMediaSkip: ((Int) -> Void)?

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

    var liveLocked: Bool { isLive || useVehicleFeed || useBLE }

    func configure(vin raw: String, paired: Bool) {
        vin = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        vinTail = String(vin.suffix(6))
        bleOK = paired
        night = true
        leftSlide = 4 // Medya
        rightSlide = 3 // Harita
        leftRailVisible = false
        rightRailVisible = false
        feedOK = false
        isLive = false
        useVehicleFeed = false
        useBLE = false
        // NEVER fake-drive after pair — wait for real BLE / LIVE API.
        localDemo = false
        telemetrySource = paired ? "BLE bekleniyor" : "baglaniyor"
        feedError = paired ? "Key Card + araç uyanık olmalı" : ""
        speed = 0
        powerKW = 0
        gear = "—"
        driving = false
        battery = 0
        rangeKm = 0
        psiFL = 0; psiFR = 0; psiRL = 0; psiRR = 0
        doorFL = false; doorFR = false; doorRL = false; doorRR = false
        frunkOpen = false; trunkOpen = false; chargePortOpen = false; locked = false
        lightParking = false; lightLow = false; lightHigh = false; lightFog = false
        turnLeft = false; turnRight = false
        destination = "—"; destLatitude = 0; destLongitude = 0
        eta = "—"; energyAtArrival = "—"; tripDist = "—"
        place = "—"
        mediaTitle = "—"; mediaArtist = "—"; mediaAlbum = "—"; mediaService = "—"
        mediaPlaying = false
        latitude = 0; longitude = 0
        turnDistanceM = 0; turnInstruction = ""; turnSymbol = "arrow.up"
        googleMapsKey = (UserDefaults.standard.string(forKey: "pulse_google_maps_key") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        UIDevice.current.isBatteryMonitoringEnabled = true
        refreshClock()
        start()
    }

    func reloadMapsKey() {
        googleMapsKey = (UserDefaults.standard.string(forKey: "pulse_google_maps_key") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Apply real signed BLE `getVehicleData` snapshot (highest priority).
    func applyBLE(_ s: VehicleLiveSnapshot, linkOK: Bool) {
        guard linkOK else { return }
        useBLE = true
        feedOK = true
        isLive = true
        localDemo = false
        useVehicleFeed = false
        bleOK = true
        telemetrySource = "BLE"
        feedError = ""
        // Always mirror car — including 0 speed / P gear.
        speed = s.speedKmh
        powerKW = s.powerKW
        gear = s.gear.isEmpty ? "—" : s.gear
        driving = abs(s.speedKmh) > 1.5 || s.gear == "D" || s.gear == "R"
        battery = s.batteryPercent
        rangeKm = s.rangeKm
        if s.odometerKm > 0 { odometer = s.odometerKm }
        charging = s.charging
        psiFL = s.psiFL
        psiFR = s.psiFR
        psiRL = s.psiRL
        psiRR = s.psiRR
        outdoorC = s.outdoorC
        doorFL = s.doorFL
        doorFR = s.doorFR
        doorRL = s.doorRL
        doorRR = s.doorRR
        frunkOpen = s.frunkOpen
        trunkOpen = s.trunkOpen
        chargePortOpen = s.chargePortOpen
        locked = s.locked
        if s.lightParking || s.lightLow || s.lightHigh || s.lightFog {
            lightParking = s.lightParking
            lightLow = s.lightLow
            lightHigh = s.lightHigh
            lightFog = s.lightFog
        }
        turnLeft = s.turnLeft
        turnRight = s.turnRight
        // Cluster is always black — ignore vehicle day/night theme (causes white bars).
        night = true
        HUDSettings.shared.mapTheme = .dark
        if abs(s.latitude) > 0.0001 || abs(s.longitude) > 0.0001 {
            latitude = s.latitude
            longitude = s.longitude
        }
        mapHeading = s.heading
        if s.routeActive {
            if !s.destination.isEmpty, s.destination != "—", s.destination != "-", s.destination != "--" {
                destination = s.destination
            }
            if abs(s.destLatitude) > 0.0001 || abs(s.destLongitude) > 0.0001 {
                destLatitude = s.destLatitude
                destLongitude = s.destLongitude
            }
            if !s.eta.isEmpty, s.eta != "—" { eta = s.eta }
            if !s.energyAtArrival.isEmpty, s.energyAtArrival != "—" { energyAtArrival = s.energyAtArrival }
            if !s.tripDist.isEmpty, s.tripDist != "—" { tripDist = s.tripDist }
        } else {
            // Nav ended / not set — clear so map doesn't keep a stale pin.
            destination = "—"
            destLatitude = 0
            destLongitude = 0
            eta = "—"
            energyAtArrival = "—"
            tripDist = "—"
            turnDistanceM = 0
            turnInstruction = ""
            turnSymbol = "arrow.up"
        }
        if !s.place.isEmpty, s.place != "—" { place = s.place }
        mediaTitle = s.mediaTitle
        mediaArtist = s.mediaArtist
        mediaAlbum = s.mediaAlbum
        if !s.mediaService.isEmpty, s.mediaService != "—" {
            mediaService = s.mediaService
        }
        mediaPlaying = s.mediaPlaying
        mediaVolume = s.mediaVolume
        mediaProgress = s.mediaProgress
        MediaArtworkStore.shared.resolve(title: mediaTitle, artist: mediaArtist, album: mediaAlbum)
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
        leftRailHideTask?.cancel(); leftRailHideTask = nil
        rightRailHideTask?.cancel(); rightRailHideTask = nil
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
        if useBLE {
            bleMediaPlay?()
            mediaPlaying.toggle()
            return
        }
        guard !isLive else { return }
        mediaPlaying.toggle()
    }

    func skipTrack(_ delta: Int) {
        if useBLE {
            bleMediaSkip?(delta)
            return
        }
        guard !isLive else { return }
        trackIndex = ((trackIndex + delta) % tracks.count + tracks.count) % tracks.count
        mediaTitle = tracks[trackIndex].0
        mediaArtist = tracks[trackIndex].1
        mediaProgress = 0.05
        mediaPlaying = true
    }

    func nudgeVolume(_ delta: Double) {
        mediaVolume = min(1, max(0, mediaVolume + delta))
        if useBLE {
            // Prefer step commands on car; also push absolute as fallback via closure.
            bleSetVolume?(mediaVolume)
            return
        }
        guard !isLive else { return }
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
        flashLeftRail()
    }

    func nudgeRight(_ delta: Int) {
        guard Date().timeIntervalSince(rightCool) > 0.18 else { return }
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

    /// Call when HUD opens — both rails peek for ~2.5s then hide.
    func pulseRails() {
        flashLeftRail()
        flashRightRail()
    }

    func flashLeftRail() {
        leftRailVisible = true
        leftRailHideTask?.cancel()
        leftRailHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: railVisibleSeconds)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) { leftRailVisible = false }
        }
    }

    func flashRightRail() {
        rightRailVisible = true
        rightRailHideTask?.cancel()
        rightRailHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: railVisibleSeconds)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) { rightRailVisible = false }
        }
    }

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
        // Paired BLE path: do not fall back to fake demo numbers.
        if bleOK {
            localDemo = false
            if !useBLE {
                telemetrySource = "BLE bekleniyor"
            }
        }
        guard !base.isEmpty, let root = URL(string: base) else {
            useVehicleFeed = false
            if !bleOK {
                feedOK = false
                telemetrySource = "BLE / Settings"
                feedError = "Pair yap veya Settings → token"
            }
            return
        }
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                _ = await pullVehicle(root: root, pin: pin)
                // Never seed fake demo — wait for BLE LIVE or Owner API live.
                let mode = UserDefaults.standard.string(forKey: "pulse_refresh_mode") ?? "Performans"
                let nanos: UInt64 = (mode == "Düşük") ? 800_000_000 : 150_000_000
                try? await Task.sleep(nanoseconds: nanos)
            }
        }
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
                if !useBLE { feedOK = false }
                return false
            }
            // Real BLE session wins over Dash / Owner API.
            if useBLE { return true }
            let src = ((obj["source"] as? String) ?? "demo").lowercased()
            // Ignore server simulator / fake dash when we expect real car data.
            guard src == "live" else { return false }
            useVehicleFeed = true
            feedOK = true
            feedError = ""
            localDemo = false
            isLive = true
            telemetrySource = "LIVE"
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
            if let dlat = num(obj["destination_lat"]) { destLatitude = dlat }
            if let dlon = num(obj["destination_lon"]) { destLongitude = dlon }
            if let a = obj["arrival_time"] as? String, !a.isEmpty, a != "--" { eta = a }
            if let e = obj["energy_at_arrival"] as? String, !e.isEmpty, e != "--" { energyAtArrival = e }
            if let td = obj["trip_distance_km"] as? String, !td.isEmpty, td != "--" { tripDist = td }
            if let mt = obj["media_title"] as? String { mediaTitle = mt }
            if let ma = obj["media_artist"] as? String { mediaArtist = ma }
            if let ms = obj["media_service"] as? String { mediaService = ms }
            if let mp = num(obj["media_progress"]) { mediaProgress = mp }
            MediaArtworkStore.shared.resolve(title: mediaTitle, artist: mediaArtist, album: mediaAlbum)
            if let t = num(obj["tire_fl"]) { psiFL = Int(t.rounded()) }
            if let t = num(obj["tire_fr"]) { psiFR = Int(t.rounded()) }
            if let t = num(obj["tire_rl"]) { psiRL = Int(t.rounded()) }
            if let t = num(obj["tire_rr"]) { psiRR = Int(t.rounded()) }
            if let temp = num(obj["outside_temp_c"]) { outdoorC = Int(temp.rounded()) }
            if let ch = obj["charging"] as? Bool { charging = ch }
            if let v = obj["door_fl"] as? Bool { doorFL = v }
            if let v = obj["door_fr"] as? Bool { doorFR = v }
            if let v = obj["door_rl"] as? Bool { doorRL = v }
            if let v = obj["door_rr"] as? Bool { doorRR = v }
            if let v = obj["frunk_open"] as? Bool { frunkOpen = v }
            if let v = obj["trunk_open"] as? Bool { trunkOpen = v }
            if let v = obj["charge_port_open"] as? Bool { chargePortOpen = v }
            if let v = obj["locked"] as? Bool { locked = v }
            if let v = obj["light_parking"] as? Bool { lightParking = v }
            if let v = obj["light_low"] as? Bool { lightLow = v }
            if let v = obj["light_high"] as? Bool { lightHigh = v }
            if let v = obj["light_fog"] as? Bool { lightFog = v }
            if let v = obj["turn_left"] as? Bool { turnLeft = v }
            if let v = obj["turn_right"] as? Bool { turnRight = v }
            // Always black cluster — do not follow dash ui_theme day/night.
            night = true
            HUDSettings.shared.mapTheme = .dark
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

    /// Open door / hatch labels for dial strip (Turkish short).
    var openDoorLabels: [String] {
        var out: [String] = []
        if doorFL { out.append("Sol ön") }
        if doorFR { out.append("Sağ ön") }
        if doorRL { out.append("Sol arka") }
        if doorRR { out.append("Sağ arka") }
        if frunkOpen { out.append("Frunk") }
        if trunkOpen { out.append("Bagaj") }
        if chargePortOpen { out.append("Şarj kapağı") }
        return out
    }

    var anyLightOn: Bool { lightParking || lightLow || lightHigh || lightFog || turnLeft || turnRight }

    private func refreshClock() { clock = clockFmt.string(from: Date()) }

    private func refreshPhoneBattery() {
        let lvl = UIDevice.current.batteryLevel
        if lvl >= 0 { phoneBattery = Int((lvl * 100).rounded()) }
    }

    private func tick() {
        phase += 0.2
        mapPulse = phase
        if Int(phase * 5) % 5 == 0 {
            refreshClock()
            refreshPhoneBattery()
        }
        // Never animate over BLE / live / dash feed
        guard !useBLE && !useVehicleFeed else { return }
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
