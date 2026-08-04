import SwiftUI
import MapKit
import CoreLocation

/// Apple Maps — car GPS + turn-by-turn follow. No API key.
struct AppleMapPanel: View {
    var lat: Double
    var lon: Double
    var heading: Double
    var destination: String
    var destLat: Double
    var destLon: Double
    var autoZoom: Bool
    var theme: HUDSettings.MapTheme
    /// Close follow like car nav (not whole-route overview).
    var turnByTurn: Bool = true
    @Binding var turnDistanceM: Int
    @Binding var turnInstruction: String
    @Binding var turnSymbol: String

    @State private var routeCoords: [CLLocationCoordinate2D] = []
    @State private var resolvedDest: CLLocationCoordinate2D?
    @State private var lastRouteDestKey = ""
    @State private var lastRerouteOrigin: CLLocationCoordinate2D?
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
            if hasGPS || hasDestCoord || resolvedDest != nil {
                AppleMapLegacyRepresentable(
                    center: hasGPS ? coord : (destCoord ?? coord),
                    heading: hasGPS ? heading : 0,
                    route: routeCoords,
                    destination: destCoord,
                    autoZoom: autoZoom,
                    turnByTurn: turnByTurn && (hasDestCoord || resolvedDest != nil || !routeCoords.isEmpty),
                    dark: theme != .light
                )
            } else {
                Color(red: 0.93, green: 0.94, blue: 0.95)
                Text(nameOK ? "Hedef araniyor…" : "Konum bekleniyor")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.55))
                    .padding(10)
                    .background(Capsule().fill(.white.opacity(0.85)))
            }
        }
        .onAppear { fetchRouteIfNeeded(force: true) }
        .onChangeCompat(of: lat) { _ in maybeRerouteFromMovement() }
        .onChangeCompat(of: lon) { _ in maybeRerouteFromMovement() }
        .onChangeCompat(of: destination) { _ in
            resolvedDest = nil
            lastRouteDestKey = ""
            fetchRouteIfNeeded(force: true)
        }
        .onChangeCompat(of: destLat) { _ in
            lastRouteDestKey = ""
            fetchRouteIfNeeded(force: true)
        }
        .onChangeCompat(of: destLon) { _ in
            lastRouteDestKey = ""
            fetchRouteIfNeeded(force: true)
        }
    }

    private var nameOK: Bool {
        let dest = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        return !dest.isEmpty && dest != "—" && dest != "-" && dest != "--"
    }

    /// Only rebuild directions when destination changes or car drifted far from last origin.
    private func maybeRerouteFromMovement() {
        guard hasGPS, (hasDestCoord || resolvedDest != nil) else { return }
        guard let origin = lastRerouteOrigin else {
            fetchRouteIfNeeded(force: true)
            return
        }
        let moved = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: lat, longitude: lon))
        if moved > 45 {
            fetchRouteIfNeeded(force: true)
        }
    }

    private func fetchRouteIfNeeded(force: Bool) {
        let dest = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameOK = !dest.isEmpty && dest != "—" && dest != "-" && dest != "--"
        guard hasGPS || hasDestCoord || nameOK else {
            routeCoords = []
            resolvedDest = nil
            lastRouteDestKey = ""
            lastRerouteOrigin = nil
            turnDistanceM = 0
            turnInstruction = ""
            turnSymbol = "arrow.up"
            return
        }

        let destKey: String
        if hasDestCoord {
            destKey = String(format: "c:%.5f,%.5f", destLat, destLon)
        } else {
            destKey = "n:\(dest)"
        }
        if !force, destKey == lastRouteDestKey, !routeCoords.isEmpty { return }
        if routeBusy { return }
        lastRouteDestKey = destKey
        routeBusy = true
        if hasGPS { lastRerouteOrigin = coord }

        if hasDestCoord {
            let end = CLLocationCoordinate2D(latitude: destLat, longitude: destLon)
            resolvedDest = end
            if hasGPS {
                calculateRoute(to: end)
            } else {
                routeCoords = [end]
                turnInstruction = nameOK ? dest : "Hedef"
                turnSymbol = "flag.fill"
                turnDistanceM = 0
                routeBusy = false
            }
            return
        }

        guard nameOK else {
            routeBusy = false
            return
        }

        resolveDestination(named: dest) { end in
            if let end {
                self.resolvedDest = end
                if self.hasGPS {
                    self.calculateRoute(to: end)
                } else {
                    self.routeCoords = [end]
                    self.turnInstruction = dest
                    self.turnSymbol = "flag.fill"
                    self.routeBusy = false
                }
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
            let geocoder = CLGeocoder()
            let region = CLCircularRegion(center: coord, radius: 80_000, identifier: "pulse.nav")
            geocoder.geocodeAddressString(queries.first ?? destination, in: region) { marks, _ in
                DispatchQueue.main.async { completion(marks?.first?.location?.coordinate) }
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
        var seen = Set<String>()
        return out.filter { seen.insert($0.lowercased()).inserted }
    }

    private func calculateRoute(to end: CLLocationCoordinate2D) {
        let origin = coord
        let dreq = MKDirections.Request()
        dreq.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        dreq.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        dreq.transportType = .automobile
        dreq.requestsAlternateRoutes = false
        MKDirections(request: dreq).calculate { result, _ in
            DispatchQueue.main.async {
                self.routeBusy = false
                if let route = result?.routes.first {
                    let poly = route.polyline
                    var coords = Array(repeating: CLLocationCoordinate2D(), count: poly.pointCount)
                    poly.getCoordinates(&coords, range: NSRange(location: 0, length: poly.pointCount))
                    // Apple snaps to road network — stitch from live car GPS so the line starts on the car.
                    if let first = coords.first {
                        let gap = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
                            .distance(from: CLLocation(latitude: first.latitude, longitude: first.longitude))
                        if gap > 12 {
                            coords.insert(origin, at: 0)
                        } else {
                            coords[0] = origin
                        }
                    } else {
                        coords = [origin, end]
                    }
                    self.routeCoords = coords
                    self.lastRerouteOrigin = origin
                    Self.applyTurnGuidance(
                        route: route,
                        distanceM: &self.turnDistanceM,
                        instruction: &self.turnInstruction,
                        symbol: &self.turnSymbol
                    )
                } else {
                    self.routeCoords = [origin, end]
                    self.lastRerouteOrigin = origin
                    self.turnDistanceM = Int(
                        CLLocation(latitude: origin.latitude, longitude: origin.longitude)
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
        instruction = shortenInstruction(step.instructions)
        symbol = symbolFor(step.instructions)
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
    var turnByTurn: Bool
    var dark: Bool

    /// Hard clip host — MKMapView metal layer otherwise bleeds under siblings / top bar.
    /// Forces light trait collection so Apple Maps tiles stay bright inside a dark HUD.
    final class ClipHost: UIView {
        var forceLightStyle = true
        override init(frame: CGRect) {
            super.init(frame: frame)
            clipsToBounds = true
            layer.masksToBounds = true
            isOpaque = true
        }
        required init?(coder: NSCoder) { fatalError("init(coder:)") }
        override var traitCollection: UITraitCollection {
            guard forceLightStyle else { return super.traitCollection }
            return UITraitCollection(traitsFrom: [
                super.traitCollection,
                UITraitCollection(userInterfaceStyle: .light)
            ])
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            clipsToBounds = true
            layer.masksToBounds = true
            // Re-assert every layout — iOS sometimes clears this on MKMapView resize.
            subviews.forEach {
                $0.clipsToBounds = true
                $0.layer.masksToBounds = true
                if forceLightStyle {
                    $0.overrideUserInterfaceStyle = .light
                }
            }
        }
    }

    func makeUIView(context: Context) -> UIView {
        let host = ClipHost(frame: .zero)
        let paper = UIColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1)
        host.forceLightStyle = !dark
        host.backgroundColor = dark ? UIColor.black : paper
        host.overrideUserInterfaceStyle = dark ? .dark : .light

        let map = MKMapView(frame: .zero)
        map.translatesAutoresizingMaskIntoConstraints = false
        map.isUserInteractionEnabled = false
        map.isOpaque = true
        map.showsCompass = false
        map.showsTraffic = false
        map.showsPointsOfInterest = true
        map.showsBuildings = false
        map.delegate = context.coordinator
        // Force light tiles even when the HUD prefers dark chrome.
        map.overrideUserInterfaceStyle = dark ? .dark : .light
        if #available(iOS 16.0, *) {
            let cfg = MKStandardMapConfiguration(emphasisStyle: .default)
            cfg.pointOfInterestFilter = .includingAll
            map.preferredConfiguration = cfg
        } else {
            map.mapType = .standard
        }
        map.clipsToBounds = true
        map.layer.masksToBounds = true
        map.backgroundColor = dark ? UIColor.black : paper

        host.addSubview(map)
        NSLayoutConstraint.activate([
            map.topAnchor.constraint(equalTo: host.topAnchor),
            map.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            map.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            map.trailingAnchor.constraint(equalTo: host.trailingAnchor),
        ])

        let car = CarMapAnnotation(coordinate: center)
        car.heading = heading
        map.addAnnotation(car)
        context.coordinator.car = car
        context.coordinator.mapView = map
        return host
    }

    func updateUIView(_ host: UIView, context: Context) {
        host.clipsToBounds = true
        host.layer.masksToBounds = true
        let paper = UIColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1)
        if let clip = host as? ClipHost {
            clip.forceLightStyle = !dark
        }
        host.backgroundColor = dark ? .black : paper
        host.overrideUserInterfaceStyle = dark ? .dark : .light
        guard let map = context.coordinator.mapView ?? host.subviews.compactMap({ $0 as? MKMapView }).first else {
            return
        }
        context.coordinator.mapView = map
        map.clipsToBounds = true
        map.layer.masksToBounds = true
        map.overrideUserInterfaceStyle = dark ? .dark : .light
        map.backgroundColor = dark ? .black : paper
        map.showsBuildings = false
        if #available(iOS 16.0, *) {
            let cfg = MKStandardMapConfiguration(emphasisStyle: .default)
            cfg.pointOfInterestFilter = .includingAll
            map.preferredConfiguration = cfg
        } else {
            map.mapType = .standard
        }
        let c = context.coordinator

        if let car = c.car {
            car.coordinate = center
            car.heading = heading
            // Camera is already heading-up — keep the arrow pointing to the top of the screen.
            // Rotating the annotation by heading again made the car look sideways.
            if let view = map.view(for: car) {
                view.transform = .identity
            }
        }

        if let destination {
            if let dest = c.dest {
                dest.coordinate = destination
            } else {
                let dest = DestMapAnnotation(coordinate: destination)
                map.addAnnotation(dest)
                c.dest = dest
            }
        } else if let dest = c.dest {
            map.removeAnnotation(dest)
            c.dest = nil
        }

        let routeKey = "\(route.count)-\(Int((route.last?.latitude ?? 0) * 1e4))"
        if routeKey != c.lastRouteKey {
            map.removeOverlays(map.overlays)
            if route.count > 1 {
                map.addOverlay(MKPolyline(coordinates: route, count: route.count))
            }
            c.lastRouteKey = routeKey
        }

        guard autoZoom else { return }

        let now = Date()
        let moved: CLLocationDistance = {
            guard let last = c.lastCameraCenter else { return 999 }
            return CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: CLLocation(latitude: center.latitude, longitude: center.longitude))
        }()
        let headingDelta = abs((c.lastHeading ?? 0) - heading)
        if now.timeIntervalSince(c.lastCameraAt) < 0.28, moved < 2.5, headingDelta < 4 {
            return
        }

        let distance: CLLocationDistance = turnByTurn ? 240 : 540
        // Lower pitch = flatter, brighter look (steep 3D looked almost black).
        let pitch: CGFloat = turnByTurn ? 28 : 18
        // Normalize heading so camera faces travel direction (0…360).
        var camHeading = heading.truncatingRemainder(dividingBy: 360)
        if camHeading < 0 { camHeading += 360 }
        let cam = MKMapCamera(
            lookingAtCenter: center,
            fromDistance: distance,
            pitch: pitch,
            heading: camHeading
        )
        map.setCamera(cam, animated: moved > 1)
        c.lastCameraCenter = center
        c.lastHeading = heading
        c.lastCameraAt = now
    }

    func makeCoordinator() -> Coord { Coord() }

    final class Coord: NSObject, MKMapViewDelegate {
        weak var mapView: MKMapView?
        var car: CarMapAnnotation?
        var dest: DestMapAnnotation?
        var lastCameraCenter: CLLocationCoordinate2D?
        var lastHeading: Double?
        var lastCameraAt = Date.distantPast
        var lastRouteKey = ""

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let p = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: p)
                r.strokeColor = UIColor(red: 0.15, green: 0.55, blue: 1.0, alpha: 1)
                r.lineWidth = 8
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
            // Heading-up camera: arrow stays screen-up (travel direction).
            view.transform = .identity
            return view
        }
    }
}
