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
                format: "%.5f,%.5f,%.0f,%@,%.5f,%.5f,%d,%@,%d",
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
              if(!directionsService || !target){
                clearRoute();
                return;
              }
              const routeKey = p.hasDestCoord
                ? ('c:' + p.destLat.toFixed(5) + ',' + p.destLon.toFixed(5))
                : ('n:' + String(target));
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
              if(!p.hasGPS && !p.hasDestCoord && blankDest(p.destination)){
                showMsg('Araç GPS / rota bekleniyor');
                clearRoute();
                return;
              }
              showMsg(p.hasGPS ? '' : (blankDest(p.destination) && !p.hasDestCoord ? 'GPS bekleniyor' : ''));
              const pos = { lat: p.lat, lng: p.lon };
              const follow = p.autoZoom && Date.now() > userControlUntil;
              if(p.hasGPS){
                marker.setPosition(pos);
                marker.setMap(map);
                const icon = Object.assign({}, marker.getIcon() || {});
                icon.rotation = 0;
                marker.setIcon(icon);
                if(follow && blankDest(p.destination) && !p.hasDestCoord){
                  map.setCenter(pos);
                  map.setZoom(17);
                  if(map.setTilt) map.setTilt(45);
                  if(map.setHeading) map.setHeading(p.heading || 0);
                }
              } else {
                marker.setMap(null);
              }
              drawRoute(pos, p);
            };
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
@MainActor
final class PhoneLocationStore: NSObject, ObservableObject {
    static let shared = PhoneLocationStore()

    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var heading: Double = 0
    @Published var hasFix = false
    @Published var status = "Konum…"

    private let manager = CLLocationManager()
    private var started = false

    func start() {
        if started {
            resumeIfNeeded()
            return
        }
        started = true
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 4
        manager.headingFilter = 3
        manager.activityType = .automotiveNavigation
        requestAndStart()
    }

    private func resumeIfNeeded() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
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
        case .denied, .restricted:
            status = "Konum izni yok (Ayarlar)"
        @unknown default:
            status = "Konum bilinmiyor"
        }
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
            self.latitude = loc.coordinate.latitude
            self.longitude = loc.coordinate.longitude
            self.hasFix = true
            self.status = "Telefon GPS"
            if loc.course >= 0 {
                self.heading = loc.course
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let h = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        guard h >= 0 else { return }
        Task { @MainActor in
            self.heading = h
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

/// Vehicle nav map — Apple Maps or Google Maps (Settings). Car destination → Directions route.
/// Falls back to phone GPS when the vehicle is not connected (Dashla-style).
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
    /// When set, overrides settings map theme (vehicle day/night).
    var forceDark: Bool? = nil
    @ObservedObject private var settings = HUDSettings.shared
    @ObservedObject private var phone = PhoneLocationStore.shared

    private var hasCarGPS: Bool { abs(lat) > 0.0001 || abs(lon) > 0.0001 }

    /// Prefer car GPS; otherwise phone location so the map always shows.
    private var mapLat: Double { hasCarGPS ? lat : phone.latitude }
    private var mapLon: Double { hasCarGPS ? lon : phone.longitude }
    private var mapHeading: Double { hasCarGPS ? heading : phone.heading }

    private var effectiveTheme: HUDSettings.MapTheme {
        // Light map tiles — cluster chrome stays black separately.
        .light
    }

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
        .onAppear { phone.start() }
    }
}
