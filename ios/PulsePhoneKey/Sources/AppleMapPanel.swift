import SwiftUI
import MapKit

/// Apple Maps — car GPS + BLE destination. No Google/API key.
/// Uses MKMapView for iOS 16+ (no MapCameraPosition / iOS 17-only APIs).
struct AppleMapPanel: View {
    var lat: Double
    var lon: Double
    var heading: Double
    var destination: String
    var autoZoom: Bool
    var theme: HUDSettings.MapTheme

    @State private var routeCoords: [CLLocationCoordinate2D] = []
    @State private var lastRouteKey = ""

    private var hasGPS: Bool { abs(lat) > 0.0001 || abs(lon) > 0.0001 }
    private var coord: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: hasGPS ? lat : 41.0082, longitude: hasGPS ? lon : 28.9784)
    }

    var body: some View {
        ZStack {
            AppleMapLegacyRepresentable(
                center: coord,
                heading: heading,
                route: routeCoords,
                autoZoom: autoZoom,
                dark: theme == .dark
            )
            if !hasGPS {
                Text("GPS bekleniyor")
                    .font(.caption)
                    .foregroundStyle(.black.opacity(0.45))
                    .padding(8)
                    .background(Capsule().fill(.white.opacity(0.85)))
            }
        }
        .onAppear { fetchRouteIfNeeded() }
        .onChangeCompat(of: lat) { _ in fetchRouteIfNeeded() }
        .onChangeCompat(of: lon) { _ in fetchRouteIfNeeded() }
        .onChangeCompat(of: destination) { _ in fetchRouteIfNeeded() }
    }

    private func fetchRouteIfNeeded() {
        let dest = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasGPS else { return }
        guard !dest.isEmpty, dest != "—", dest != "-", dest != "--" else {
            routeCoords = []
            lastRouteKey = ""
            return
        }
        let key = String(format: "%.4f,%.4f|%@", lat, lon, dest)
        guard key != lastRouteKey else { return }
        lastRouteKey = key

        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = dest
        req.region = MKCoordinateRegion(center: coord, latitudinalMeters: 80_000, longitudinalMeters: 80_000)
        MKLocalSearch(request: req).start { response, _ in
            guard let end = response?.mapItems.first?.placemark.coordinate else { return }
            let dreq = MKDirections.Request()
            dreq.source = MKMapItem(placemark: MKPlacemark(coordinate: self.coord))
            dreq.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
            dreq.transportType = .automobile
            MKDirections(request: dreq).calculate { result, _ in
                DispatchQueue.main.async {
                    if let poly = result?.routes.first?.polyline {
                        var coords = Array(
                            repeating: CLLocationCoordinate2D(),
                            count: poly.pointCount
                        )
                        poly.getCoordinates(&coords, range: NSRange(location: 0, length: poly.pointCount))
                        self.routeCoords = coords
                    }
                }
            }
        }
    }
}

/// MKMapView wrapper — works on iOS 16+.
struct AppleMapLegacyRepresentable: UIViewRepresentable {
    var center: CLLocationCoordinate2D
    var heading: Double
    var route: [CLLocationCoordinate2D]
    var autoZoom: Bool
    var dark: Bool

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.isUserInteractionEnabled = false
        map.showsCompass = false
        map.showsTraffic = false
        map.delegate = context.coordinator
        map.overrideUserInterfaceStyle = dark ? .dark : .unspecified
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.overrideUserInterfaceStyle = dark ? .dark : .unspecified
        if autoZoom {
            let cam = MKMapCamera(
                lookingAtCenter: center,
                fromDistance: 450,
                pitch: 55,
                heading: heading
            )
            map.setCamera(cam, animated: false)
        } else {
            let region = MKCoordinateRegion(
                center: center,
                latitudinalMeters: 600,
                longitudinalMeters: 600
            )
            map.setRegion(region, animated: false)
        }

        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)

        let ann = MKPointAnnotation()
        ann.coordinate = center
        map.addAnnotation(ann)

        if route.count > 1 {
            let poly = MKPolyline(coordinates: route, count: route.count)
            map.addOverlay(poly)
        }
    }

    func makeCoordinator() -> Coord { Coord() }

    final class Coord: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let p = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: p)
                r.strokeColor = UIColor(red: 0.1, green: 0.45, blue: 0.95, alpha: 1)
                r.lineWidth = 5
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            let id = "pulse.car"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            let cfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
            view.image = UIImage(systemName: "location.north.fill", withConfiguration: cfg)?
                .withTintColor(.systemRed, renderingMode: .alwaysOriginal)
            view.centerOffset = CGPoint(x: 0, y: 0)
            return view
        }
    }
}
