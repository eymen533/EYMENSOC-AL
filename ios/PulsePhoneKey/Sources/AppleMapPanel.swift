import SwiftUI
import MapKit
import CoreLocation

/// Apple Maps — live car GPS + car nav destination route. No API key.
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
    @State private var resolvedDest: CLLocationCoordinate2D?
    @State private var lastRouteKey = ""
    @State private var routeBusy = false

    private var hasGPS: Bool { abs(lat) > 0.0001 || abs(lon) > 0.0001 }
    private var hasDestCoord: Bool { abs(destLat) > 0.0001 || abs(destLon) > 0.0001 }
    private var coord: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    private var destCoord: CLLocationCoordinate2D? {
        if hasDestCoord {
            return CLLocationCoordinate2D(latitude: destLat, longitude: destLon)
        }
        return resolvedDest
    }

    var body: some View {
        ZStack {
            if hasGPS {
                AppleMapLegacyRepresentable(
                    center: coord,
                    heading: heading,
                    route: routeCoords,
                    destination: destCoord,
                    autoZoom: autoZoom,
                    dark: theme == .dark || theme == .auto
                )
            } else {
                Color(red: 0.12, green: 0.13, blue: 0.14)
                Text("Araç GPS bekleniyor")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(10)
                    .background(Capsule().fill(.black.opacity(0.45)))
            }
        }
        .onAppear { fetchRouteIfNeeded(force: true) }
        .onChangeCompat(of: lat) { _ in fetchRouteIfNeeded(force: false) }
        .onChangeCompat(of: lon) { _ in fetchRouteIfNeeded(force: false) }
        .onChangeCompat(of: destination) { _ in
            resolvedDest = nil
            lastRouteKey = ""
            fetchRouteIfNeeded(force: true)
        }
        .onChangeCompat(of: destLat) { _ in
            lastRouteKey = ""
            fetchRouteIfNeeded(force: true)
        }
        .onChangeCompat(of: destLon) { _ in
            lastRouteKey = ""
            fetchRouteIfNeeded(force: true)
        }
    }

    private func fetchRouteIfNeeded(force: Bool) {
        let dest = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameOK = !dest.isEmpty && dest != "—" && dest != "-" && dest != "--"
        guard hasGPS else { return }
        guard hasDestCoord || nameOK else {
            routeCoords = []
            resolvedDest = nil
            lastRouteKey = ""
            turnDistanceM = 0
            turnInstruction = ""
            turnSymbol = "arrow.up"
            return
        }

        let key: String
        if hasDestCoord {
            key = String(format: "c:%.4f,%.4f->%.5f,%.5f", lat, lon, destLat, destLon)
        } else {
            key = String(format: "n:%.3f,%.3f|%@", lat, lon, dest)
        }
        if !force, key == lastRouteKey { return }
        lastRouteKey = key
        if routeBusy { return }
        routeBusy = true

        if hasDestCoord {
            let end = CLLocationCoordinate2D(latitude: destLat, longitude: destLon)
            resolvedDest = end
            calculateRoute(to: end)
            return
        }

        resolveDestination(named: dest) { end in
            if let end {
                self.resolvedDest = end
                self.calculateRoute(to: end)
            } else {
                self.routeBusy = false
                self.routeCoords = []
            }
        }
    }

    private func resolveDestination(named dest: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let queries = Self.destinationQueries(dest)
        searchNext(queries: queries, index: 0, completion: completion)
    }

    private func searchNext(queries: [String], index: Int, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        guard index < queries.count else {
            // Last resort: CLGeocoder
            let geocoder = CLGeocoder()
            let region = CLCircularRegion(
                center: coord,
                radius: 80_000,
                identifier: "pulse.nav"
            )
            geocoder.geocodeAddressString(queries.first ?? destination, in: region) { marks, _ in
                DispatchQueue.main.async {
                    completion(marks?.first?.location?.coordinate)
                }
            }
            return
        }
        let q = queries[index]
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = q
        req.resultTypes = [.address, .pointOfInterest]
        req.region = MKCoordinateRegion(center: coord, latitudinalMeters: 150_000, longitudinalMeters: 150_000)
        MKLocalSearch(request: req).start { response, _ in
            if let end = response?.mapItems.first?.placemark.coordinate {
                DispatchQueue.main.async { completion(end) }
            } else {
                self.searchNext(queries: queries, index: index + 1, completion: completion)
            }
        }
    }

    private static func destinationQueries(_ dest: String) -> [String] {
        var out: [String] = [dest]
        let trimmed = dest
            .replacingOccurrences(of: #"No[:\s]*\d+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != dest { out.append(trimmed) }
        out.append("\(dest), Türkiye")
        if !trimmed.isEmpty { out.append("\(trimmed), Türkiye") }
        // Unique preserve order
        var seen = Set<String>()
        return out.filter { seen.insert($0.lowercased()).inserted }
    }

    private func calculateRoute(to end: CLLocationCoordinate2D) {
        let dreq = MKDirections.Request()
        dreq.source = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        dreq.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        dreq.transportType = .automobile
        dreq.requestsAlternateRoutes = false
        MKDirections(request: dreq).calculate { result, _ in
            DispatchQueue.main.async {
                self.routeBusy = false
                if let route = result?.routes.first {
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
                } else {
                    // Fallback: straight segment so destination is still visible.
                    self.routeCoords = [self.coord, end]
                    self.turnDistanceM = Int(
                        CLLocation(latitude: self.lat, longitude: self.lon)
                            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
                            .rounded()
                    )
                    self.turnInstruction = self.destination
                    self.turnSymbol = "flag.fill"
                }
            }
        }
    }

    private static func applyTurnGuidance(
        route: MKRoute,
        distanceM: inout Int,
        instruction: inout String,
        symbol: inout String
    ) {
        let steps = route.steps.filter { !$0.instructions.isEmpty }
        let step = steps.dropFirst().first ?? steps.first
        guard let step else {
            distanceM = max(0, Int(route.distance.rounded()))
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

final class CarMapAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var heading: CLLocationDirection = 0
    init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
}

final class DestMapAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
}

struct AppleMapLegacyRepresentable: UIViewRepresentable {
    var center: CLLocationCoordinate2D
    var heading: Double
    var route: [CLLocationCoordinate2D]
    var destination: CLLocationCoordinate2D?
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

        let car = CarMapAnnotation(coordinate: center)
        car.heading = heading
        map.addAnnotation(car)
        context.coordinator.car = car
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.overrideUserInterfaceStyle = dark ? .dark : .unspecified
        let coord = context.coordinator
        if let car = coord.car {
            car.coordinate = center
            car.heading = heading
            if let view = map.view(for: car) {
                let angle = CGFloat(heading * .pi / 180)
                UIView.animate(withDuration: 0.15) {
                    view.transform = CGAffineTransform(rotationAngle: angle)
                }
            }
        }

        // Destination pin
        if let destination {
            if let dest = coord.dest {
                dest.coordinate = destination
            } else {
                let dest = DestMapAnnotation(coordinate: destination)
                map.addAnnotation(dest)
                coord.dest = dest
            }
        } else if let dest = coord.dest {
            map.removeAnnotation(dest)
            coord.dest = nil
        }

        // Route overlay
        let routeKey = "\(route.count)-\(route.first?.latitude ?? 0)-\(route.last?.longitude ?? 0)"
        if routeKey != coord.lastRouteKey {
            map.removeOverlays(map.overlays)
            if route.count > 1 {
                let poly = MKPolyline(coordinates: route, count: route.count)
                map.addOverlay(poly)
            }
            coord.lastRouteKey = routeKey
        }

        if autoZoom {
            if route.count > 1 {
                // Show car + route like the in-car map.
                let padding = UIEdgeInsets(top: 40, left: 36, bottom: 40, right: 36)
                map.setVisibleMapRect(
                    MKPolyline(coordinates: route, count: route.count).boundingMapRect,
                    edgePadding: padding,
                    animated: true
                )
                // Keep a mild heading camera when close.
                if route.count < 8 {
                    let cam = MKMapCamera(lookingAtCenter: center, fromDistance: 500, pitch: 45, heading: heading)
                    map.setCamera(cam, animated: true)
                }
            } else {
                let cam = MKMapCamera(
                    lookingAtCenter: center,
                    fromDistance: 420,
                    pitch: 52,
                    heading: heading
                )
                let last = coord.lastCameraCenter
                let jump = last == nil || CLLocation(latitude: last!.latitude, longitude: last!.longitude)
                    .distance(from: CLLocation(latitude: center.latitude, longitude: center.longitude)) > 4
                if jump || abs((coord.lastHeading ?? 0) - heading) > 3 {
                    map.setCamera(cam, animated: true)
                    coord.lastCameraCenter = center
                    coord.lastHeading = heading
                }
            }
        } else {
            let region = MKCoordinateRegion(
                center: center,
                latitudinalMeters: 550,
                longitudinalMeters: 550
            )
            map.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coord { Coord() }

    final class Coord: NSObject, MKMapViewDelegate {
        var car: CarMapAnnotation?
        var dest: DestMapAnnotation?
        var lastCameraCenter: CLLocationCoordinate2D?
        var lastHeading: Double?
        var lastRouteKey = ""

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
            if annotation is DestMapAnnotation {
                let id = "pulse.dest"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                if let marker = view as? MKMarkerAnnotationView {
                    marker.markerTintColor = .systemRed
                    marker.glyphImage = UIImage(systemName: "flag.fill")
                }
                return view
            }
            let id = "pulse.car"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            let cfg = UIImage.SymbolConfiguration(pointSize: 26, weight: .bold)
            view.image = UIImage(systemName: "location.north.fill", withConfiguration: cfg)?
                .withTintColor(.systemRed, renderingMode: .alwaysOriginal)
            view.centerOffset = .zero
            if let car = annotation as? CarMapAnnotation {
                view.transform = CGAffineTransform(rotationAngle: CGFloat(car.heading * .pi / 180))
            }
            return view
        }
    }
}
