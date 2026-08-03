import Foundation

/// Plain vehicle fields for HUD — no CryptoKit (safe at app launch).
struct VehicleLiveSnapshot {
    var speedKmh: Double = 0
    var powerKW: Double = 0
    var gear: String = "P"
    var batteryPercent: Double = 0
    var rangeKm: Int = 0
    var odometerKm: Double = 0
    var charging: Bool = false
    var psiFL = 0
    var psiFR = 0
    var psiRL = 0
    var psiRR = 0
    var outdoorC: Int = 0
    var latitude: Double = 0
    var longitude: Double = 0
    var heading: Double = 0
    var destination: String = "—"
    var destLatitude: Double = 0
    var destLongitude: Double = 0
    /// True when car has an active navigation destination (name and/or ETA).
    var routeActive: Bool = false
    var eta: String = "—"
    var energyAtArrival: String = "—"
    var tripDist: String = "—"
    var place: String = "—"
    var mediaTitle: String = "—"
    var mediaArtist: String = "—"
    var mediaAlbum: String = "—"
    var mediaService: String = "—"
    var mediaPlaying: Bool = false
    var mediaProgress: Double = 0
    var mediaVolume: Double = 0.5
    // Closures / doors
    var doorFL = false
    var doorFR = false
    var doorRL = false
    var doorRR = false
    var frunkOpen = false
    var trunkOpen = false
    var chargePortOpen = false
    var locked = false
    var centerDisplay: String = "" // off/dim/on/driving/…
    // Exterior lights (Owner/Dash when available; BLE rarely exposes these)
    var lightParking = false
    var lightLow = false
    var lightHigh = false
    var lightFog = false
    var turnLeft = false
    var turnRight = false
    /// Vehicle-driven theme. nil = infer from display/hour.
    var nightMode: Bool? = nil
    var updated = Date.distantPast
}
