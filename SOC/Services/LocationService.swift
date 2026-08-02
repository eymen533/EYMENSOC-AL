import Combine
import CoreLocation
import Foundation
import MapKit

@MainActor
final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var heading: CLLocationDirection = 0
    @Published private(set) var placeName: String?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastGeocodeAt: Date?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.headingFilter = 2
        authorizationStatus = manager.authorizationStatus
    }

    func requestAuthorizationIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            start()
        default:
            break
        }
    }

    func start() {
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    private func reverseGeocodeIfNeeded(_ location: CLLocation) {
        if let lastGeocodeAt, Date().timeIntervalSince(lastGeocodeAt) < 20 { return }
        lastGeocodeAt = Date()
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            Task { @MainActor in
                guard let placemark = placemarks?.first else { return }
                let street = [placemark.thoroughfare, placemark.subThoroughfare]
                    .compactMap { $0 }
                    .joined(separator: " ")
                self?.placeName = street.isEmpty ? placemark.locality : street
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                start()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            coordinate = location.coordinate
            reverseGeocodeIfNeeded(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            if newHeading.trueHeading >= 0 {
                heading = newHeading.trueHeading
            } else {
                heading = newHeading.magneticHeading
            }
        }
    }
}
