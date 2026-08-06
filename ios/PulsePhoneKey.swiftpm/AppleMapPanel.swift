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
    var imagery: HUDSettings.MapImagery = .standard
    var showsTraffic: Bool = true
    var onUserTap: (() -> Void)? = nil
    /// One-finger vertical swipe → panel slide nudge (+1 up / -1 down).
    var onVerticalNudge: ((Int) -> Void)? = nil
    @Binding var turnDistanceM: Int
    @Binding var turnInstruction: String
    @Binding var turnSymbol: String

    @State private var routeCoords: [CLLocationCoordinate2D] = []
    @State private var resolvedDest: CLLocationCoordinate2D?
    @State private var lastRouteDestKey = ""
    @State private var lastRerouteOrigin: CLLocationCoordinate2D?
    @State private var routeBusy = false
    /// Distance-to-next-turn at last MKDirections result; live GPS subtracts from this.
    @State private var guidanceBaseM: Int = 0
    @State private var guidanceAt: CLLocationCoordinate2D?

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
                    dark: theme != .light,
                    imagery: imagery,
                    showsTraffic: showsTraffic,
                    onUserTap: onUserTap,
                    onVerticalNudge: onVerticalNudge
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
        .onChangeCompat(of: lat) { _ in
            maybeRerouteFromMovement()
            updateLiveTurnDistance()
            if hasGPS, (hasDestCoord || resolvedDest != nil), routeCoords.count < 2 {
                fetchRouteIfNeeded(force: true)
            }
        }
        .onChangeCompat(of: lon) { _ in
            maybeRerouteFromMovement()
            updateLiveTurnDistance()
            if hasGPS, (hasDestCoord || resolvedDest != nil), routeCoords.count < 2 {
                fetchRouteIfNeeded(force: true)
            }
        }
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
        // Recalc when approaching the maneuver or after meaningful travel.
        if turnDistanceM > 0, turnDistanceM < 35, moved > 8 {
            fetchRouteIfNeeded(force: true)
        } else if moved > 40 {
            fetchRouteIfNeeded(force: true)
        }
    }

    /// Count down meters to the next turn between full MKDirections refreshes.
    private func updateLiveTurnDistance() {
        guard hasGPS, guidanceBaseM > 0, let at = guidanceAt else { return }
        let moved = CLLocation(latitude: at.latitude, longitude: at.longitude)
            .distance(from: CLLocation(latitude: lat, longitude: lon))
        let next = max(0, guidanceBaseM - Int(moved.rounded()))
        if abs(next - turnDistanceM) >= 5 || next == 0 {
            turnDistanceM = next
        }
        if next <= 12 {
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
            routeCoords = []
            resolvedDest = nil
            lastRouteDestKey = ""
            lastRerouteOrigin = nil
            guidanceBaseM = 0
            guidanceAt = nil
            turnDistanceM = 0
            turnInstruction = ""
            turnSymbol = "arrow.up"
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
                    self.guidanceBaseM = self.turnDistanceM
                    self.guidanceAt = origin
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
                    self.guidanceBaseM = self.turnDistanceM
                    self.guidanceAt = origin
                }
            }
        }
    }

    /// Skip "continue / head / düz devam" filler steps; sum distance to the next real turn.
    private static func applyTurnGuidance(
        route: MKRoute,
        distanceM: inout Int,
        instruction: inout String,
        symbol: inout String
    ) {
        let steps = route.steps.filter { !$0.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !steps.isEmpty else {
            distanceM = max(0, Int(route.distance.rounded()))
            instruction = ""
            symbol = "arrow.up"
            return
        }

        var metersBefore: CLLocationDistance = 0
        var chosen: MKRoute.Step?
        for (idx, step) in steps.enumerated() {
            // First step is often "Depart" / "Head" — still accumulate its length toward the turn.
            if idx == 0, !isManeuverStep(step.instructions) {
                metersBefore += step.distance
                continue
            }
            if isManeuverStep(step.instructions) {
                chosen = step
                break
            }
            metersBefore += step.distance
        }

        if let step = chosen {
            // Distance until the maneuver = filler steps + the maneuver step itself
            // (MapKit step.distance is length of that segment, ending at/after the turn).
            distanceM = max(0, Int((metersBefore + step.distance).rounded()))
            instruction = shortenInstruction(step.instructions)
            symbol = symbolFor(step.instructions)
            return
        }

        // No explicit turn left — show remaining route with straight.
        let rest = steps.dropFirst()
        let sum = rest.reduce(CLLocationDistance(0)) { $0 + $1.distance }
        distanceM = max(0, Int((sum > 1 ? sum : route.distance).rounded()))
        if let last = steps.last {
            instruction = shortenInstruction(last.instructions)
            symbol = symbolFor(last.instructions)
        } else {
            instruction = ""
            symbol = "arrow.up"
        }
    }

    /// True for left/right/keep/arrive/roundabout — false for continue/straight filler.
    private static func isManeuverStep(_ raw: String) -> Bool {
        let l = raw.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "tr_TR"))
        if l.contains("u-turn") || l.contains("u turn") || l.contains("u-donus") || l.contains("u donus") {
            return true
        }
        if l.contains("roundabout") || l.contains("traffic circle") || l.contains("doner kavsak") {
            return true
        }
        if l.contains("keep left") || l.contains("keep right") || l.contains("bear left") || l.contains("bear right") {
            return true
        }
        if l.contains("arrive") || l.contains("destination") || l.contains("varis") || l.contains("hedefe") {
            return true
        }
        if l.contains("exit") || l.contains("ramp") || l.contains("cikis") {
            return true
        }
        // Turn left / right (EN + TR).
        if l.contains("turn left") || l.contains("turn right") { return true }
        if l.contains("sola") || l.contains("saga") { return true }
        if (l.contains("left") || l.contains("right") || l.contains("sol") || l.contains("sag"))
            && (l.contains("turn") || l.contains("don") || l.contains("keep") || l.contains("bear")) {
            return true
        }
        if l.contains("turn") || (l.contains("don") && !l.contains("devam")) { return true }
        return false
    }

    private static func shortenInstruction(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        // Keep the maneuver verb; only trim long "onto …" street tails.
        if let r = lower.range(of: " onto ") {
            let verb = String(trimmed[..<trimmed.index(trimmed.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: r.lowerBound))])
                .trimmingCharacters(in: .whitespaces)
            var street = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: r.upperBound))...])
                .trimmingCharacters(in: .whitespaces)
            if street.count > 28 { street = String(street.prefix(26)) + "…" }
            if verb.isEmpty { return street }
            return "\(verb) · \(street)"
        }
        if trimmed.count > 42 {
            return String(trimmed.prefix(40)) + "…"
        }
        return trimmed
    }

    private static func symbolFor(_ raw: String) -> String {
        let l = raw.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "tr_TR"))
        if l.contains("u-turn") || l.contains("u turn") || l.contains("u donus") { return "arrow.uturn.left" }
        if l.contains("keep left") || l.contains("bear left") { return "arrow.up.left" }
        if l.contains("keep right") || l.contains("bear right") { return "arrow.up.right" }
        if l.contains("roundabout") || l.contains("doner kavsak") { return "arrow.triangle.2.circlepath" }
        if l.contains("sola") || l.contains("turn left") || (l.contains("left") && l.contains("turn")) {
            return "arrow.turn.up.left"
        }
        if l.contains("saga") || l.contains("turn right") || (l.contains("right") && l.contains("turn")) {
            return "arrow.turn.up.right"
        }
        if l.contains("left") || l.contains("sol") { return "arrow.turn.up.left" }
        if l.contains("right") || l.contains("sag") { return "arrow.turn.up.right" }
        if l.contains("arrive") || l.contains("destination") || l.contains("varis") || l.contains("hedef") {
            return "flag.fill"
        }
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
    var imagery: HUDSettings.MapImagery
    var showsTraffic: Bool
    var onUserTap: (() -> Void)?
    var onVerticalNudge: ((Int) -> Void)?

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
        map.isUserInteractionEnabled = true
        map.isZoomEnabled = true
        // One-finger pan off — panel swipe needs the finger; look around with two fingers.
        map.isScrollEnabled = false
        map.isRotateEnabled = true
        map.isPitchEnabled = true
        map.isOpaque = true
        map.showsCompass = false
        map.showsTraffic = showsTraffic
        map.showsPointsOfInterest = true
        map.showsBuildings = true
        map.delegate = context.coordinator
        map.overrideUserInterfaceStyle = dark ? .dark : .light
        Self.applyImagery(imagery, to: map, dark: dark)
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
        context.coordinator.onUserTap = onUserTap
        context.coordinator.onVerticalNudge = onVerticalNudge

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coord.handleTap(_:)))
        tap.numberOfTapsRequired = 1
        tap.cancelsTouchesInView = false
        map.addGestureRecognizer(tap)
        context.coordinator.tapRecognizer = tap

        let twoFingerPan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coord.handleTwoFingerPan(_:))
        )
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        twoFingerPan.delegate = context.coordinator
        map.addGestureRecognizer(twoFingerPan)

        let oneFingerVertical = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coord.handleOneFingerVertical(_:))
        )
        oneFingerVertical.maximumNumberOfTouches = 1
        oneFingerVertical.delegate = context.coordinator
        map.addGestureRecognizer(oneFingerVertical)

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
        context.coordinator.onUserTap = onUserTap
        context.coordinator.onVerticalNudge = onVerticalNudge
        map.delegate = context.coordinator
        map.clipsToBounds = true
        map.layer.masksToBounds = true
        map.overrideUserInterfaceStyle = dark ? .dark : .light
        map.backgroundColor = dark ? .black : paper
        map.showsBuildings = true
        map.showsTraffic = showsTraffic
        map.isUserInteractionEnabled = true
        map.isZoomEnabled = true
        map.isScrollEnabled = false
        if context.coordinator.lastImagery != imagery || context.coordinator.lastDark != dark {
            Self.applyImagery(imagery, to: map, dark: dark)
            context.coordinator.lastImagery = imagery
            context.coordinator.lastDark = dark
        }
        let c = context.coordinator

        // Feed smooth follow targets — camera ticks on CADisplayLink (no jump/setCamera stutter).
        c.wantCenter = center
        c.wantHeading = heading
        c.followAutoZoom = autoZoom
        c.followTurnByTurn = turnByTurn
        c.ensureDisplayLink()

        if let car = c.car {
            // Instant snap only before smooth loop boots; otherwise tick owns the car.
            if c.smoothLat == nil {
                car.coordinate = center
                car.heading = heading
            }
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
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coord) {
        coordinator.displayLink?.invalidate()
        coordinator.displayLink = nil
    }

    static func applyImagery(_ imagery: HUDSettings.MapImagery, to map: MKMapView, dark: Bool) {
        if #available(iOS 16.0, *) {
            switch imagery {
            case .standard:
                let cfg = MKStandardMapConfiguration(emphasisStyle: .default)
                cfg.pointOfInterestFilter = .includingAll
                map.preferredConfiguration = cfg
            case .hybrid:
                let cfg = MKHybridMapConfiguration(elevationStyle: .realistic)
                cfg.pointOfInterestFilter = .includingAll
                map.preferredConfiguration = cfg
            case .satellite:
                map.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
            }
        } else {
            switch imagery {
            case .standard: map.mapType = .standard
            case .hybrid: map.mapType = .hybrid
            case .satellite: map.mapType = .satellite
            }
        }
        map.overrideUserInterfaceStyle = dark ? .dark : .light
    }

    func makeCoordinator() -> Coord { Coord() }

    final class Coord: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        weak var mapView: MKMapView?
        weak var tapRecognizer: UITapGestureRecognizer?
        var car: CarMapAnnotation?
        var dest: DestMapAnnotation?
        var lastCameraCenter: CLLocationCoordinate2D?
        var lastHeading: Double?
        var lastCameraAt = Date.distantPast
        var lastRouteKey = ""
        var lastImagery: HUDSettings.MapImagery = .standard
        var lastDark = false
        var userControlUntil = Date.distantPast
        var onUserTap: (() -> Void)?
        var onVerticalNudge: ((Int) -> Void)?
        private var verticalConsumed = false

        // Smooth follow (CADisplayLink) — avoids tick-tick camera jumps.
        var wantCenter: CLLocationCoordinate2D?
        var wantHeading: Double = 0
        var followAutoZoom = true
        var followTurnByTurn = true
        var smoothLat: Double?
        var smoothLon: Double?
        var smoothHeading: Double?
        var displayLink: CADisplayLink?

        func ensureDisplayLink() {
            guard displayLink == nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(tickCamera))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        @objc private func tickCamera() {
            guard let want = wantCenter, let map = mapView else { return }
            guard followAutoZoom, Date() >= userControlUntil else { return }

            if smoothLat == nil || smoothLon == nil {
                smoothLat = want.latitude
                smoothLon = want.longitude
                smoothHeading = wantHeading
            } else {
                let err = CLLocation(latitude: smoothLat!, longitude: smoothLon!)
                    .distance(from: CLLocation(latitude: want.latitude, longitude: want.longitude))
                let a = err > 40 ? 0.40 : (err > 14 ? 0.26 : 0.16)
                smoothLat! += (want.latitude - smoothLat!) * a
                smoothLon! += (want.longitude - smoothLon!) * a
                var d = (wantHeading - (smoothHeading ?? wantHeading)).truncatingRemainder(dividingBy: 360)
                if d > 180 { d -= 360 }
                if d < -180 { d += 360 }
                smoothHeading = (smoothHeading ?? wantHeading) + d * min(0.32, a + 0.08)
                var h = smoothHeading!.truncatingRemainder(dividingBy: 360)
                if h < 0 { h += 360 }
                smoothHeading = h
            }

            let center = CLLocationCoordinate2D(latitude: smoothLat!, longitude: smoothLon!)
            if let car {
                car.coordinate = center
                car.heading = smoothHeading ?? wantHeading
                if let view = map.view(for: car) {
                    view.transform = .identity
                }
            }

            let distance: CLLocationDistance = followTurnByTurn ? 320 : 560
            let pitch: CGFloat = followTurnByTurn ? 38 : 28
            var camHeading = (smoothHeading ?? wantHeading).truncatingRemainder(dividingBy: 360)
            if camHeading < 0 { camHeading += 360 }
            let cam = MKMapCamera(
                lookingAtCenter: center,
                fromDistance: distance,
                pitch: pitch,
                heading: camHeading
            )
            map.camera = cam
            lastCameraCenter = center
            lastHeading = camHeading
            lastCameraAt = Date()
        }

        @objc func handleTap(_ gr: UITapGestureRecognizer) {
            guard gr.state == .ended else { return }
            onUserTap?()
        }

        /// Look around with two fingers (1-finger scroll stays off for panel swipes).
        @objc func handleTwoFingerPan(_ gr: UIPanGestureRecognizer) {
            guard let map = mapView, gr.numberOfTouches >= 2 else { return }
            let translation = gr.translation(in: map)
            switch gr.state {
            case .changed:
                let centerPt = map.convert(map.centerCoordinate, toPointTo: map)
                let newPt = CGPoint(x: centerPt.x - translation.x, y: centerPt.y - translation.y)
                map.centerCoordinate = map.convert(newPt, toCoordinateFrom: map)
                gr.setTranslation(.zero, in: map)
                userControlUntil = Date().addingTimeInterval(12)
            case .ended, .cancelled:
                userControlUntil = Date().addingTimeInterval(12)
            default:
                break
            }
        }

        /// One-finger vertical → change HUD side panel (Harita / Lastik / …).
        @objc func handleOneFingerVertical(_ gr: UIPanGestureRecognizer) {
            let t = gr.translation(in: gr.view)
            switch gr.state {
            case .began:
                verticalConsumed = false
            case .changed, .ended:
                guard !verticalConsumed else { return }
                guard abs(t.y) > abs(t.x) * 1.4, abs(t.y) > 36 else { return }
                verticalConsumed = true
                let delta = t.y < 0 ? 1 : -1
                DispatchQueue.main.async { self.onVerticalNudge?(delta) }
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  pan.maximumNumberOfTouches == 1,
                  let view = pan.view else { return true }
            let v = pan.velocity(in: view)
            // Only claim 1-finger pans that are clearly vertical.
            return abs(v.y) > abs(v.x) * 1.25
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            // Let pinch-zoom run alongside two-finger pan.
            true
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // Detect finger-driven camera changes (pinch / 2-finger pan / rotate).
            guard let gestures = mapView.subviews.first?.gestureRecognizers else { return }
            for g in gestures {
                if g.state == .began || g.state == .changed {
                    userControlUntil = Date().addingTimeInterval(10)
                    return
                }
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let p = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: p)
                // Bright nav blue on light tiles — readable under dial frost.
                r.strokeColor = UIColor(red: 0.05, green: 0.45, blue: 0.98, alpha: 1)
                r.lineWidth = 11
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
