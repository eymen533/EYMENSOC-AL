import SwiftUI
import WebKit
import CoreLocation
import Combine

/// Google Maps (JS) — car GPS marker + Directions route from vehicle destination.
struct GoogleMapPanel: UIViewRepresentable {
    var lat: Double
    var lon: Double
    var heading: Double
    var destination: String
    var destLat: Double
    var destLon: Double
    var apiKey: String
    var dark: Bool
    var autoZoom: Bool
    var imagery: HUDSettings.MapImagery = .standard
    var showsTraffic: Bool = true
    var onUserTap: (() -> Void)? = nil
    var onVerticalNudge: ((Int) -> Void)? = nil

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.userContentController.add(context.coordinator, name: "pulseMap")
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.isOpaque = true
        web.clipsToBounds = true
        web.layer.masksToBounds = true
        web.backgroundColor = dark
            ? UIColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 1)
            : UIColor(red: 0.86, green: 0.85, blue: 0.82, alpha: 1)
        // Page itself shouldn't scroll; Google Maps handles 2-finger gestures (cooperative).
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.isUserInteractionEnabled = true
        web.navigationDelegate = context.coordinator
        context.coordinator.webView = web
        context.coordinator.onUserTap = onUserTap
        context.coordinator.onVerticalNudge = onVerticalNudge
        context.coordinator.load(
            lat: lat, lon: lon, heading: heading,
            destination: destination, destLat: destLat, destLon: destLon,
            apiKey: apiKey, dark: dark, autoZoom: autoZoom,
            imagery: imagery, showsTraffic: showsTraffic
        )

        let oneFingerVertical = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleOneFingerVertical(_:))
        )
        oneFingerVertical.maximumNumberOfTouches = 1
        oneFingerVertical.delegate = context.coordinator
        web.addGestureRecognizer(oneFingerVertical)

        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.webView = web
        context.coordinator.onUserTap = onUserTap
        context.coordinator.onVerticalNudge = onVerticalNudge
        context.coordinator.update(
            lat: lat, lon: lon, heading: heading,
            destination: destination, destLat: destLat, destLon: destLon,
            apiKey: apiKey, dark: dark, autoZoom: autoZoom,
            imagery: imagery, showsTraffic: showsTraffic
        )
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "pulseMap")
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, UIGestureRecognizerDelegate {
        weak var webView: WKWebView?
        var onUserTap: (() -> Void)?
        var onVerticalNudge: ((Int) -> Void)?
        private var lastLoadKey = ""
        private var lastUpdateKey = ""
        private var pageReady = false
        private var pending: (() -> Void)?
        private var verticalConsumed = false

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
            return abs(v.y) > abs(v.x) * 1.25
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "pulseMap" else { return }
            let body = (message.body as? String) ?? ""
            if body == "tap" {
                DispatchQueue.main.async { self.onUserTap?() }
            }
        }

        func load(
            lat: Double, lon: Double, heading: Double,
            destination: String, destLat: Double, destLon: Double,
            apiKey: String, dark: Bool, autoZoom: Bool,
            imagery: HUDSettings.MapImagery, showsTraffic: Bool
        ) {
            let key = "\(apiKey)|dark=\(dark)"
            guard key != lastLoadKey else {
                update(
                    lat: lat, lon: lon, heading: heading,
                    destination: destination, destLat: destLat, destLon: destLon,
                    apiKey: apiKey, dark: dark, autoZoom: autoZoom,
                    imagery: imagery, showsTraffic: showsTraffic
                )
                return
            }
            lastLoadKey = key
            pageReady = false
            lastUpdateKey = ""
            let html = Self.html(apiKey: apiKey, dark: dark)
            webView?.loadHTMLString(html, baseURL: URL(string: "https://local.pulse.maps/"))
            pending = { [weak self] in
                self?.update(
                    lat: lat, lon: lon, heading: heading,
                    destination: destination, destLat: destLat, destLon: destLon,
                    apiKey: apiKey, dark: dark, autoZoom: autoZoom,
                    imagery: imagery, showsTraffic: showsTraffic
                )
            }
        }

        func update(
            lat: Double, lon: Double, heading: Double,
            destination: String, destLat: Double, destLon: Double,
            apiKey: String, dark: Bool, autoZoom: Bool,
            imagery: HUDSettings.MapImagery, showsTraffic: Bool
        ) {
            guard pageReady, let web = webView else {
                pending = { [weak self] in
                    self?.update(
                        lat: lat, lon: lon, heading: heading,
                        destination: destination, destLat: destLat, destLon: destLon,
                        apiKey: apiKey, dark: dark, autoZoom: autoZoom,
                        imagery: imagery, showsTraffic: showsTraffic
                    )
                }
                return
            }
            let dest = Self.jsEscape(destination)
            let gps = hasGPS(lat, lon)
            let hasDestCoord = abs(destLat) > 0.0001 || abs(destLon) > 0.0001
            let mapType: String = {
                switch imagery {
                case .standard: return "roadmap"
                case .hybrid: return "hybrid"
                case .satellite: return "satellite"
                }
            }()
            let ukey = String(
                format: "%.6f,%.6f,%.1f,%@,%.5f,%.5f,%d,%@,%d",
                lat, lon, heading, destination, destLat, destLon,
                autoZoom ? 1 : 0, mapType, showsTraffic ? 1 : 0
            )
            guard ukey != lastUpdateKey else { return }
            lastUpdateKey = ukey

            let fallbackLat = hasDestCoord ? destLat : 41.0082
            let fallbackLon = hasDestCoord ? destLon : 28.9784
            let js = """
            window.pulseUpdate({
              lat: \(gps ? lat : fallbackLat),
              lon: \(gps ? lon : fallbackLon),
              heading: \(heading),
              hasGPS: \(gps ? "true" : "false"),
              destination: '\(dest)',
              destLat: \(hasDestCoord ? destLat : 0),
              destLon: \(hasDestCoord ? destLon : 0),
              hasDestCoord: \(hasDestCoord ? "true" : "false"),
              autoZoom: \(autoZoom ? "true" : "false"),
              mapType: '\(mapType)',
              traffic: \(showsTraffic ? "true" : "false")
            });
            """
            web.evaluateJavaScript(js, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageReady = true
            pending?()
            pending = nil
        }

        private func hasGPS(_ lat: Double, _ lon: Double) -> Bool {
            abs(lat) > 0.0001 || abs(lon) > 0.0001
        }

        private static func jsEscape(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
        }

        private static func html(apiKey: String, dark: Bool) -> String {
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let keyJS = key.isEmpty ? "" : key
            let bg = dark ? "#1a1c1e" : "#f2f0eb"
            let msgColor = dark ? "rgba(255,255,255,.55)" : "rgba(0,0,0,.45)"
            let styles: String
            if dark {
                styles = """
                [
                  {elementType:'geometry', stylers:[{color:'#1d1f21'}]},
                  {elementType:'labels.text.fill', stylers:[{color:'#8a8f96'}]},
                  {elementType:'labels.text.stroke', stylers:[{color:'#1d1f21'}]},
                  {featureType:'road', elementType:'geometry', stylers:[{color:'#2a2e33'}]},
                  {featureType:'road', elementType:'geometry.stroke', stylers:[{color:'#1a1c1e'}]},
                  {featureType:'poi', stylers:[{visibility:'off'}]},
                  {featureType:'transit', stylers:[{visibility:'off'}]},
                  {featureType:'water', elementType:'geometry', stylers:[{color:'#0e2a3a'}]}
                ]
                """
            } else {
                styles = """
                [
                  {elementType:'geometry', stylers:[{color:'#f2f0eb'}]},
                  {elementType:'labels.text.fill', stylers:[{color:'#3d3d3d'}]},
                  {elementType:'labels.text.stroke', stylers:[{color:'#ffffff'}]},
                  {featureType:'road', elementType:'geometry', stylers:[{color:'#ffffff'}]},
                  {featureType:'road', elementType:'geometry.stroke', stylers:[{color:'#cfcbc4'}]},
                  {featureType:'road.highway', elementType:'geometry', stylers:[{color:'#f7e7a1'}]},
                  {featureType:'poi', stylers:[{visibility:'simplified'}]},
                  {featureType:'transit', stylers:[{visibility:'off'}]},
                  {featureType:'water', elementType:'geometry', stylers:[{color:'#a8c8e0'}]},
                  {featureType:'landscape.man_made', elementType:'geometry', stylers:[{color:'#ebe8e2'}]},
                  {featureType:'landscape.natural', elementType:'geometry', stylers:[{color:'#e4efd8'}]}
                ]
                """
            }
            return """
            <!DOCTYPE html>
            <html>
            <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"/>
            <style>
              html,body,#map{margin:0;padding:0;width:100%;height:100%;background:\(bg);overflow:hidden}
              #msg{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;
                font:14px -apple-system,BlinkMacSystemFont,sans-serif;color:\(msgColor);z-index:2;pointer-events:none;
                text-align:center;padding:16px}
            </style>
            </head>
            <body>
            <div id="msg">Google Maps…</div>
            <div id="map"></div>
            <script>
            let map, marker, destMarker, directionsService, directionsRenderer, trafficLayer;
            let lastRouteKey = '';
            let userControlUntil = 0;
            function showMsg(t){
              const el=document.getElementById('msg');
              if(el){ el.textContent=t||''; el.style.display=t?'flex':'none'; }
            }
            function blankDest(t){
              const s=(t||'').trim();
              return !s || s==='—' || s==='-' || s==='--';
            }
            function postTap(){
              try { window.webkit.messageHandlers.pulseMap.postMessage('tap'); } catch(e) {}
            }
            function markUserControl(){
              userControlUntil = Date.now() + 10000;
            }
            function init(){
              if(!window.google || !google.maps){
                showMsg('Google Maps API key gerekli (Ayarlar)');
                return;
              }
              showMsg('');
              map = new google.maps.Map(document.getElementById('map'), {
                center: {lat:41.0082, lng:28.9784},
                zoom: 16,
                tilt: 45,
                heading: 0,
                mapTypeId: 'roadmap',
                disableDefaultUI: true,
                gestureHandling: 'cooperative',
                keyboardShortcuts: false,
                styles: \(styles)
              });
              trafficLayer = new google.maps.TrafficLayer();
              trafficLayer.setMap(map);
              directionsService = new google.maps.DirectionsService();
              directionsRenderer = new google.maps.DirectionsRenderer({
                map: map,
                suppressMarkers: true,
                preserveViewport: true,
                polylineOptions: {
                  strokeColor: '#1a73e8',
                  strokeOpacity: 0.95,
                  strokeWeight: 6
                }
              });
              marker = new google.maps.Marker({
                map: map,
                icon: {
                  path: google.maps.SymbolPath.FORWARD_CLOSED_ARROW,
                  scale: 7,
                  fillColor: '#e53935',
                  fillOpacity: 1,
                  strokeColor: '#ffffff',
                  strokeWeight: 1.5,
                  rotation: 0
                },
                zIndex: 10
              });
              destMarker = new google.maps.Marker({
                map: null,
                icon: {
                  path: google.maps.SymbolPath.CIRCLE,
                  scale: 8,
                  fillColor: '#1a73e8',
                  fillOpacity: 1,
                  strokeColor: '#ffffff',
                  strokeWeight: 2
                },
                zIndex: 9
              });
              map.addListener('click', postTap);
              map.addListener('dragstart', markUserControl);
              map.addListener('zoom_changed', markUserControl);
            }
            function clearRoute(){
              if(directionsRenderer) directionsRenderer.set('directions', null);
              if(destMarker) destMarker.setMap(null);
              lastRouteKey = '';
            }
            function destTarget(p){
              if(p.hasDestCoord) return { lat: p.destLat, lng: p.destLon };
              if(!blankDest(p.destination)) return p.destination.trim();
              return null;
            }
            function drawRoute(origin, p){
              const target = destTarget(p);
              // Nav cancelled in car → clear polyline + pin immediately.
              if(!directionsService || !target || (!p.hasDestCoord && blankDest(p.destination))){
                clearRoute();
                return;
              }
              const routeKey = p.hasDestCoord
                ? ('c:' + p.destLat.toFixed(5) + ',' + p.destLon.toFixed(5))
                : ('n:' + String(target));
              // New destination → force redraw even if a prior request is mid-flight.
              if(routeKey === lastRouteKey) return;
              lastRouteKey = routeKey;
              if(p.hasDestCoord){
                destMarker.setPosition({lat:p.destLat, lng:p.destLon});
                destMarker.setMap(map);
              }
              directionsService.route({
                origin: origin,
                destination: target,
                travelMode: google.maps.TravelMode.DRIVING
              }, (result, status) => {
                if(status === 'OK' && result){
                  directionsRenderer.setDirections(result);
                  if(p.autoZoom && Date.now() > userControlUntil && result.routes && result.routes[0]){
                    const b = result.routes[0].bounds;
                    if(b) map.fitBounds(b, 48);
                  }
                  if(!p.hasDestCoord && result.routes[0] && result.routes[0].legs[0]){
                    const end = result.routes[0].legs[0].end_location;
                    destMarker.setPosition(end);
                    destMarker.setMap(map);
                  }
                }
              });
            }
            window.pulseUpdate = function(p){
              if(!map || !marker) return;
              if(p.mapType) map.setMapTypeId(p.mapType);
              if(trafficLayer){
                trafficLayer.setMap(p.traffic ? map : null);
              }
              // Car stopped navigation — drop route before anything else.
              if(!p.hasDestCoord && blankDest(p.destination)){
                clearRoute();
                if(!p.hasGPS){
                  showMsg('Araç GPS / rota bekleniyor');
                  return;
                }
                showMsg('');
              }
              if(!p.hasGPS && !p.hasDestCoord && blankDest(p.destination)){
                showMsg('Araç GPS / rota bekleniyor');
                clearRoute();
                return;
              }
              showMsg(p.hasGPS ? '' : (blankDest(p.destination) && !p.hasDestCoord ? 'GPS bekleniyor' : ''));
              const pos = { lat: p.lat, lng: p.lon };
              const follow = p.autoZoom && Date.now() > userControlUntil;
              if(p.hasGPS){
                targetPos = pos;
                targetHeading = p.heading || 0;
                wantFollow = follow && blankDest(p.destination) && !p.hasDestCoord;
                marker.setMap(map);
                if(!smoothBoot){
                  smoothPos = { lat: pos.lat, lng: pos.lng };
                  smoothHeading = targetHeading;
                  smoothBoot = true;
                  marker.setPosition(smoothPos);
                  if(wantFollow){
                    map.setCenter(smoothPos);
                    map.setZoom(17);
                    if(map.setTilt) map.setTilt(45);
                    if(map.setHeading) map.setHeading(smoothHeading);
                  }
                }
              } else {
                marker.setMap(null);
                smoothBoot = false;
              }
              drawRoute(pos, p);
            };
            function shortestDelta(a,b){
              let d = (b - a) % 360;
              if(d > 180) d -= 360;
              if(d < -180) d += 360;
              return d;
            }
            function tickSmooth(){
              if(smoothBoot && targetPos){
                const a = 0.16;
                smoothPos.lat += (targetPos.lat - smoothPos.lat) * a;
                smoothPos.lng += (targetPos.lng - smoothPos.lng) * a;
                smoothHeading += shortestDelta(smoothHeading, targetHeading) * Math.min(0.28, a + 0.08);
                if(smoothHeading < 0) smoothHeading += 360;
                if(smoothHeading >= 360) smoothHeading -= 360;
                marker.setPosition(smoothPos);
                const icon = Object.assign({}, marker.getIcon() || {});
                icon.rotation = 0;
                marker.setIcon(icon);
                if(wantFollow && Date.now() > userControlUntil){
                  map.setCenter(smoothPos);
                  if(map.setHeading) map.setHeading(smoothHeading);
                  if(map.setTilt) map.setTilt(45);
                }
              }
              requestAnimationFrame(tickSmooth);
            }
            let targetPos = null, smoothPos = {lat:0,lng:0}, smoothHeading = 0, targetHeading = 0;
            let smoothBoot = false, wantFollow = false;
            requestAnimationFrame(tickSmooth);
            </script>
            \(keyJS.isEmpty
                ? "<script>document.getElementById('msg').textContent='Ayarlar → Google Maps API key';</script>"
                : "<script src=\"https://maps.googleapis.com/maps/api/js?key=\(keyJS)&callback=init\" async defer></script>")
            </body>
            </html>
            """
        }
    }
}

/// Phone GPS — Dashla-style map works even when the car is not connected.
/// Publishes dead-reckoned + lerped coords so the map path isn't "tick-tick" jumps.
@MainActor
final class PhoneLocationStore: NSObject, ObservableObject {
    static let shared = PhoneLocationStore()

    /// Smoothed position for the map (not raw GPS samples).
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var heading: Double = 0
    @Published var hasFix = false
    @Published var status = "Konum…"

    private let manager = CLLocationManager()
    private var started = false
    private var rawLat = 0.0
    private var rawLon = 0.0
    private var rawHeading = -1.0
    private var speedMps = 0.0
    private var lastFixAt = Date.distantPast
    private var tick: AnyCancellable?
    private var displayLat = 0.0
    private var displayLon = 0.0
    private var displayHeading = 0.0
    private var displayBooted = false

    func start() {
        if started {
            resumeIfNeeded()
            return
        }
        started = true
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        // Every fix — we smooth in software instead of waiting for 1.5 m jumps.
        manager.distanceFilter = kCLDistanceFilterNone
        manager.headingFilter = 1
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        requestAndStart()
    }

    private func resumeIfNeeded() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
            ensureTick()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            status = "Konum izni yok"
        }
    }

    private func requestAndStart() {
        switch manager.authorizationStatus {
        case .notDetermined:
            status = "Konum izni isteniyor…"
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            status = "Telefon GPS…"
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
            ensureTick()
        case .denied, .restricted:
            status = "Konum izni yok (Ayarlar)"
        @unknown default:
            status = "Konum bilinmiyor"
        }
    }

    private func ingest(_ loc: CLLocation) {
        // Drop useless / wild samples.
        guard loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= 55 else { return }
        rawLat = loc.coordinate.latitude
        rawLon = loc.coordinate.longitude
        lastFixAt = Date()
        if loc.speed >= 0 { speedMps = loc.speed }
        if loc.course >= 0 { rawHeading = loc.course }
        if !hasFix {
            displayLat = rawLat
            displayLon = rawLon
            displayHeading = rawHeading >= 0 ? rawHeading : 0
            displayBooted = true
            publishDisplay(force: true)
            hasFix = true
            status = "Telefon GPS"
        }
        ensureTick()
    }

    private func ingestHeading(_ h: Double) {
        guard h >= 0 else { return }
        // Prefer course-over-ground while moving; compass when nearly stopped.
        if speedMps < 1.2 {
            rawHeading = h
        }
        ensureTick()
    }

    private func ensureTick() {
        guard tick == nil else { return }
        tick = Timer.publish(every: 1.0 / 20.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tickSmooth() }
    }

    private func tickSmooth() {
        guard hasFix else { return }
        let age = min(1.15, max(0, Date().timeIntervalSince(lastFixAt)))
        // Dead-reckon briefly between GPS samples (greatly reduces stutter).
        var predLat = rawLat
        var predLon = rawLon
        if rawHeading >= 0, speedMps > 0.4, age > 0 {
            let dist = speedMps * age
            let rad = rawHeading * .pi / 180
            let dLat = (dist * cos(rad)) / 111_320.0
            let cosLat = max(0.2, cos(predLat * .pi / 180))
            let dLon = (dist * sin(rad)) / (111_320.0 * cosLat)
            predLat += dLat
            predLon += dLon
        }
        let targetH = rawHeading >= 0 ? rawHeading : displayHeading
        if !displayBooted {
            displayLat = predLat
            displayLon = predLon
            displayHeading = targetH
            displayBooted = true
            publishDisplay(force: true)
            return
        }
        // Faster catch-up when prediction is far (tunnel exit / first fixes).
        let errM = CLLocation(latitude: displayLat, longitude: displayLon)
            .distance(from: CLLocation(latitude: predLat, longitude: predLon))
        let a = errM > 35 ? 0.45 : (errM > 12 ? 0.28 : 0.18)
        displayLat += (predLat - displayLat) * a
        displayLon += (predLon - displayLon) * a
        displayHeading = lerpHeading(displayHeading, targetH, t: min(0.35, a + 0.08))
        publishDisplay(force: false)
    }

    private func publishDisplay(force: Bool) {
        let moved = CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: displayLat, longitude: displayLon))
        let hDelta = abs(shortestHeadingDelta(heading, displayHeading))
        guard force || moved >= 0.35 || hDelta >= 0.9 || !hasFix else { return }
        latitude = displayLat
        longitude = displayLon
        heading = displayHeading
    }

    private func lerpHeading(_ from: Double, _ to: Double, t: Double) -> Double {
        let d = shortestHeadingDelta(from, to)
        var out = from + d * t
        out = out.truncatingRemainder(dividingBy: 360)
        if out < 0 { out += 360 }
        return out
    }

    private func shortestHeadingDelta(_ from: Double, _ to: Double) -> Double {
        var d = (to - from).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }
}

extension PhoneLocationStore: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.requestAndStart()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.ingest(loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let h = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            self.ingestHeading(h)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if !self.hasFix {
                self.status = "Konum alinamadi"
            }
        }
    }
}

/// Smooths sparse BLE vehicle GPS between Location polls (dead-reckon + lerp).
@MainActor
final class VehicleLocationStore: ObservableObject {
    static let shared = VehicleLocationStore()

    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var heading: Double = 0
    @Published var hasFix = false

    private var rawLat = 0.0
    private var rawLon = 0.0
    private var rawHeading = -1.0
    private var speedMps = 0.0
    private var lastFixAt = Date.distantPast
    private var displayLat = 0.0
    private var displayLon = 0.0
    private var displayHeading = 0.0
    private var displayBooted = false
    private var tick: AnyCancellable?

    func ingest(lat: Double, lon: Double, heading: Double, speedKmh: Double = -1) {
        guard abs(lat) > 0.0001 || abs(lon) > 0.0001 else { return }
        rawLat = lat
        rawLon = lon
        lastFixAt = Date()
        if speedKmh >= 0 { speedMps = speedKmh / 3.6 }
        if heading >= 0 {
            var h = heading.truncatingRemainder(dividingBy: 360)
            if h < 0 { h += 360 }
            rawHeading = h
        }
        if !hasFix || !displayBooted {
            displayLat = rawLat
            displayLon = rawLon
            displayHeading = rawHeading >= 0 ? rawHeading : 0
            displayBooted = true
            latitude = displayLat
            longitude = displayLon
            self.heading = displayHeading
            hasFix = true
        } else {
            let jump = CLLocation(latitude: displayLat, longitude: displayLon)
                .distance(from: CLLocation(latitude: rawLat, longitude: rawLon))
            if jump > 90 {
                displayLat = rawLat
                displayLon = rawLon
                if rawHeading >= 0 { displayHeading = rawHeading }
                latitude = displayLat
                longitude = displayLon
                self.heading = displayHeading
            }
        }
        ensureTick()
    }

    private func ensureTick() {
        guard tick == nil else { return }
        tick = Timer.publish(every: 1.0 / 20.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tickSmooth() }
    }

    private func tickSmooth() {
        guard hasFix else { return }
        let age = min(1.6, max(0, Date().timeIntervalSince(lastFixAt)))
        var predLat = rawLat
        var predLon = rawLon
        if rawHeading >= 0, speedMps > 0.5, age > 0 {
            let dist = speedMps * age
            let rad = rawHeading * .pi / 180
            let dLat = (dist * cos(rad)) / 111_320.0
            let cosLat = max(0.2, cos(predLat * .pi / 180))
            let dLon = (dist * sin(rad)) / (111_320.0 * cosLat)
            predLat += dLat
            predLon += dLon
        }
        let targetH = rawHeading >= 0 ? rawHeading : displayHeading
        let errM = CLLocation(latitude: displayLat, longitude: displayLon)
            .distance(from: CLLocation(latitude: predLat, longitude: predLon))
        let a = errM > 40 ? 0.42 : (errM > 15 ? 0.26 : 0.16)
        displayLat += (predLat - displayLat) * a
        displayLon += (predLon - displayLon) * a
        displayHeading = lerpHeading(displayHeading, targetH, t: min(0.32, a + 0.06))

        let moved = CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: displayLat, longitude: displayLon))
        let hDelta = abs(shortestHeadingDelta(heading, displayHeading))
        guard moved >= 0.4 || hDelta >= 1.0 else { return }
        latitude = displayLat
        longitude = displayLon
        heading = displayHeading
    }

    private func lerpHeading(_ from: Double, _ to: Double, t: Double) -> Double {
        let d = shortestHeadingDelta(from, to)
        var out = from + d * t
        out = out.truncatingRemainder(dividingBy: 360)
        if out < 0 { out += 360 }
        return out
    }

    private func shortestHeadingDelta(_ from: Double, _ to: Double) -> Double {
        var d = (to - from).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }
}

/// Vehicle nav map — Apple / Google. Prefer BLE vehicle GPS; phone is fallback.
struct VehicleMapView: View {
    var lat: Double
    var lon: Double
    var heading: Double
    var destination: String = ""
    var destLat: Double = 0
    var destLon: Double = 0
    var apiKey: String = ""
    var turnByTurn: Bool = true
    var onUserTap: (() -> Void)? = nil
    var onVerticalNudge: ((Int) -> Void)? = nil
    @Binding var turnDistanceM: Int
    @Binding var turnInstruction: String
    @Binding var turnSymbol: String
    var forceDark: Bool? = nil
    @ObservedObject private var settings = HUDSettings.shared
    @ObservedObject private var phone = PhoneLocationStore.shared
    @ObservedObject private var vehicle = VehicleLocationStore.shared

    private var mapLat: Double {
        switch settings.mapGPSSource {
        case .vehicle:
            return vehicle.hasFix ? vehicle.latitude : lat
        case .phone:
            return phone.hasFix ? phone.latitude : (vehicle.hasFix ? vehicle.latitude : lat)
        case .auto:
            if vehicle.hasFix { return vehicle.latitude }
            if abs(lat) > 0.0001 || abs(lon) > 0.0001 { return lat }
            return phone.latitude
        }
    }
    private var mapLon: Double {
        switch settings.mapGPSSource {
        case .vehicle:
            return vehicle.hasFix ? vehicle.longitude : lon
        case .phone:
            return phone.hasFix ? phone.longitude : (vehicle.hasFix ? vehicle.longitude : lon)
        case .auto:
            if vehicle.hasFix { return vehicle.longitude }
            if abs(lat) > 0.0001 || abs(lon) > 0.0001 { return lon }
            return phone.longitude
        }
    }
    private var mapHeading: Double {
        switch settings.mapGPSSource {
        case .vehicle:
            if vehicle.hasFix, vehicle.heading >= 0 { return vehicle.heading }
            return heading
        case .phone:
            if phone.hasFix, phone.heading >= 0 { return phone.heading }
            if vehicle.hasFix, vehicle.heading >= 0 { return vehicle.heading }
            return heading
        case .auto:
            if vehicle.hasFix, vehicle.heading >= 0 { return vehicle.heading }
            if heading >= 0 { return heading }
            return phone.heading
        }
    }

    private var effectiveTheme: HUDSettings.MapTheme { .light }
    private var isDark: Bool { effectiveTheme != .light }

    private var resolvedKey: String {
        let k = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !k.isEmpty { return k }
        return (UserDefaults.standard.string(forKey: "pulse_google_maps_key") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            switch settings.mapsProvider {
            case .google:
                GoogleMapPanel(
                    lat: mapLat,
                    lon: mapLon,
                    heading: mapHeading,
                    destination: destination,
                    destLat: destLat,
                    destLon: destLon,
                    apiKey: resolvedKey,
                    dark: isDark,
                    autoZoom: settings.autoZoom,
                    imagery: settings.mapImagery,
                    showsTraffic: settings.mapShowsTraffic,
                    onUserTap: onUserTap,
                    onVerticalNudge: onVerticalNudge
                )
            case .apple:
                AppleMapPanel(
                    lat: mapLat,
                    lon: mapLon,
                    heading: mapHeading,
                    destination: destination,
                    destLat: destLat,
                    destLon: destLon,
                    autoZoom: settings.autoZoom,
                    theme: effectiveTheme,
                    turnByTurn: turnByTurn,
                    imagery: settings.mapImagery,
                    showsTraffic: settings.mapShowsTraffic,
                    onUserTap: onUserTap,
                    onVerticalNudge: onVerticalNudge,
                    turnDistanceM: $turnDistanceM,
                    turnInstruction: $turnInstruction,
                    turnSymbol: $turnSymbol
                )
            }
        }
        .background(isDark ? Color.black : Color(red: 0.95, green: 0.96, blue: 0.97))
        .preferredColorScheme(isDark ? .dark : .light)
        .clipped()
        .onAppear {
            phone.start()
            if abs(lat) > 0.0001 || abs(lon) > 0.0001 {
                vehicle.ingest(lat: lat, lon: lon, heading: heading)
            }
        }
        .onChangeCompat(of: lat) { _ in
            vehicle.ingest(lat: lat, lon: lon, heading: heading)
        }
        .onChangeCompat(of: lon) { _ in
            vehicle.ingest(lat: lat, lon: lon, heading: heading)
        }
        .onChangeCompat(of: heading) { _ in
            vehicle.ingest(lat: lat, lon: lon, heading: heading)
        }
    }
}
