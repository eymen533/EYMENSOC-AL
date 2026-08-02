import Foundation
import CoreLocation
import Combine

/// Phone GPS for the live map (when-in-use).
@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var lat: Double = 41.025
    @Published var lon: Double = 29.02
    @Published var heading: Double = 0
    @Published var accuracy: Double = -1
    @Published var authorized = false
    @Published var statusText = "Konum bekleniyor"

    private let manager = CLLocationManager()
    private var started = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
        manager.headingFilter = 3
    }

    func start() {
        guard !started else { return }
        started = true
        let st = manager.authorizationStatus
        if st == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        applyAuth(st)
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        started = false
    }

    private func applyAuth(_ st: CLAuthorizationStatus) {
        switch st {
        case .authorizedAlways, .authorizedWhenInUse:
            authorized = true
            statusText = "Telefon GPS"
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        case .denied, .restricted:
            authorized = false
            statusText = "Konum izni yok"
        default:
            authorized = false
            statusText = "Konum izni bekleniyor"
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.applyAuth(manager.authorizationStatus)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.lat = loc.coordinate.latitude
            self.lon = loc.coordinate.longitude
            self.accuracy = loc.horizontalAccuracy
            if loc.course >= 0 { self.heading = loc.course }
            self.statusText = String(format: "GPS %.5f, %.5f", self.lat, self.lon)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let h = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            if h >= 0 { self.heading = h }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.statusText = "GPS hata"
        }
    }
}
