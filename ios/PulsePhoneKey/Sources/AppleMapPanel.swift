import SwiftUI
import MapKit

/// Apple Maps — car GPS + BLE destination coords/name. No Google/API key.
/// Uses MKMapView for iOS 16+ (no MapCameraPosition / iOS 17-only APIs).
struct AppleMapPanel: View {
    var lat: Double
    var lon: Double
    var heading: Double
    var destination: String
    var destLat: Double
    var destLon: Double
    var autoZoom: Bool
    var theme: HUDSettings.MapTheme
    @Binding var turnDistanceM: Int
    @Binding var turnInstruction: String
    @Binding var turnSymbol: String

    @State private var routeCoords: [CLLocationCoordinate2D] = []
    @State private var lastRouteKey = ""

    private var hasGPS: Bool { abs(lat) > 0.0001 || abs(lon) > 0.0001 }
    private var hasDestCoord: Bool { abs(destLat) > 0.0001 || abs(destLon) > 0.0001 }
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
                dark: theme == .dark || theme == .auto
            )
            if !hasGPS {
                Text("GPS bekleniyor")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(8)
                    .background(Capsule().fill(.black.opacity(0.55)))
            }
        }
        .onAppear { fetchRouteIfNeeded() }
        .onChangeCompat(of: lat) { _ in fetchRouteIfNeeded() }
        .onChangeCompat(of: lon) { _ in fetchRouteIfNeeded() }
        .onChangeCompat(of: destination) { _ in fetchRouteIfNeeded() }
        .onChangeCompat(of: destLat) { _ in fetchRouteIfNeeded() }
        .onChangeCompat(of: destLon) { _ in fetchRouteIfNeeded() }
    }

    private func fetchRouteIfNeeded() {
        let dest = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameOK = !dest.isEmpty && dest != "—" && dest != "-" && dest != "--"
        guard hasGPS else { return }
        guard hasDestCoord || nameOK else {
            routeCoords = []
            lastRouteKey = ""
            turnDistanceM = 0
            turnInstruction = ""
            turnSymbol = "arrow.up"
            return
        }
        let key: String
        if hasDestCoord {
            key = String(format: "%.4f,%.4f->%.4f,%.4f", lat, lon, destLat, destLon)
        } else {
            key = String(format: "%.4f,%.4f|%@", lat, lon, dest)
        }
        guard key != lastRouteKey else { return }
        lastRouteKey = key

        if hasDestCoord {
            calculateRoute(to: CLLocationCoordinate2D(latitude: destLat, longitude: destLon))
            return
        }

        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = dest
        req.region = MKCoordinateRegion(center: coord, latitudinalMeters: 120_000, longitudinalMeters: 120_000)
        MKLocalSearch(request: req).start { response, _ in
            guard let end = response?.mapItems.first?.placemark.coordinate else { return }
            self.calculateRoute(to: end)
        }
    }

    private func calculateRoute(to end: CLLocationCoordinate2D) {
        let dreq = MKDirections.Request()
        dreq.source = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        dreq.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        dreq.transportType = .automobile
        dreq.requestsAlternateRoutes = false
        MKDirections(request: dreq).calculate { result, _ in
            DispatchQueue.main.async {
                guard let route = result?.routes.first else { return }
                let poly = route.polyline
                var coords = Array(
                    repeating: CLLocationCoordinate2D(),
                    count: poly.pointCount
                )
                poly.getCoordinates(&coords, range: NSRange(location: 0, length: poly.pointCount))
                self.routeCoords = coords
                Self.applyTurnGuidance(
                    route: route,
                    distanceM: &self.turnDistanceM,
                    instruction: &self.turnInstruction,
                    symbol: &self.turnSymbol
                )
            }
        }
    }

    private static func applyTurnGuidance(
        route: MKRoute,
        distanceM: inout Int,
        instruction: inout String,
        symbol: inout String
    ) {
        // Skip the first "depart" step when possible.
        let steps = route.steps.filter { !$0.instructions.isEmpty }
        let step = steps.dropFirst().first ?? steps.first
        guard let step else {
            distanceM = 0
            instruction = ""
            symbol = "arrow.up"
            return
        }
        distanceM = max(0, Int(step.distance.rounded()))
        let raw = step.instructions
        instruction = shortenInstruction(raw)
        symbol = symbolFor(raw)
    }

    private static func shortenInstruction(_ raw: String) -> String {
        // "Turn right onto Erturk Cd" → "onto Erturk Cd"
        let lower = raw.lowercased()
        if let r = lower.range(of: " onto ") {
            let idx = raw.index(raw.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: r.lowerBound))
            return String(raw[idx...]).trimmingCharacters(in: .whitespaces)
        }
        if let r = lower.range(of: " on ") {
            let idx = raw.index(raw.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: r.lowerBound))
            return String(raw[idx...]).trimmingCharacters(in: .whitespaces)
        }
        return raw
    }

    private static func symbolFor(_ raw: String) -> String {
        let l = raw.lowercased()
        if l.contains("u-turn") || l.contains("u turn") { return "arrow.uturn.left" }
        if l.contains("keep left") || l.contains("bear left") { return "arrow.up.left" }
        if l.contains("keep right") || l.contains("bear right") { return "arrow.up.right" }
        if l.contains("left") { return "arrow.turn.up.left" }
        if l.contains("right") { return "arrow.turn.up.right" }
        if l.contains("arrive") || l.contains("destination") { return "flag.fill" }
        return "arrow.up"
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
        map.showsPointsOfInterest = true
        map.delegate = context.coordinator
        map.overrideUserInterfaceStyle = dark ? .dark : .unspecified
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.overrideUserInterfaceStyle = dark ? .dark : .unspecified
        if autoZoom {
            let cam = MKMapCamera(
                lookingAtCenter: center,
                fromDistance: 520,
                pitch: 48,
                heading: heading
            )
            map.setCamera(cam, animated: true)
        } else {
            let region = MKCoordinateRegion(
                center: center,
                latitudinalMeters: 700,
                longitudinalMeters: 700
            )
            map.setRegion(region, animated: true)
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
                r.strokeColor = UIColor(red: 0.15, green: 0.55, blue: 1.0, alpha: 1)
                r.lineWidth = 7
                r.lineCap = .round
                r.lineJoin = .round
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
            let cfg = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
            view.image = UIImage(systemName: "location.north.fill", withConfiguration: cfg)?
                .withTintColor(.systemRed, renderingMode: .alwaysOriginal)
            view.centerOffset = CGPoint(x: 0, y: 0)
            return view
        }
    }
}
