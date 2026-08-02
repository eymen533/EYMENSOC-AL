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
    var eta: String = "—"
    var energyAtArrival: String = "—"
    var tripDist: String = "—"
    var place: String = "—"
    var mediaTitle: String = "—"
    var mediaArtist: String = "—"
    var mediaService: String = "—"
    var mediaPlaying: Bool = false
    var mediaProgress: Double = 0
    var mediaVolume: Double = 0.5
    var updated = Date.distantPast
}
