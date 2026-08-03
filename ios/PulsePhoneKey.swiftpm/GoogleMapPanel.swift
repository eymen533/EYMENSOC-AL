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

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.isOpaque = true
        web.clipsToBounds = true
        web.layer.masksToBounds = true
        web.backgroundColor = dark
            ? UIColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 1)
            : UIColor(red: 0.86, green: 0.85, blue: 0.82, alpha: 1)
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.navigationDelegate = context.coordinator
        context.coordinator.webView = web
        context.coordinator.load(
            lat: lat, lon: lon, heading: heading,
            destination: destination, destLat: destLat, destLon: destLon,
            apiKey: apiKey, dark: dark, autoZoom: autoZoom
        )
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.webView = web
        context.coordinator.update(
            lat: lat, lon: lon, heading: heading,
            destination: destination, destLat: destLat, destLon: destLon,
            apiKey: apiKey, dark: dark, autoZoom: autoZoom
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        private var lastLoadKey = ""
        private var lastUpdateKey = ""
        private var pageReady = false
        private var pending: (() -> Void)?

        func load(
            lat: Double, lon: Double, heading: Double,
            destination: String, destLat: Double, destLon: Double,
            apiKey: String, dark: Bool, autoZoom: Bool
        ) {
            let key = "\(apiKey)|dark=\(dark)"
            guard key != lastLoadKey else {
                update(
                    lat: lat, lon: lon, heading: heading,
                    destination: destination, destLat: destLat, destLon: destLon,
                    apiKey: apiKey, dark: dark, autoZoom: autoZoom
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
                    apiKey: apiKey, dark: dark, autoZoom: autoZoom
                )
            }
        }

        func update(
            lat: Double, lon: Double, heading: Double,
            destination: String, destLat: Double, destLon: Double,
            apiKey: String, dark: Bool, autoZoom: Bool
        ) {
            guard pageReady, let web = webView else {
                pending = { [weak self] in
                    self?.update(
                        lat: lat, lon: lon, heading: heading,
                        destination: destination, destLat: destLat, destLon: destLon,
                        apiKey: apiKey, dark: dark, autoZoom: autoZoom
                    )
                }
                return
            }
            let dest = Self.jsEscape(destination)
            let gps = hasGPS(lat, lon)
            let hasDestCoord = abs(destLat) > 0.0001 || abs(destLon) > 0.0001
            let ukey = String(
                format: "%.5f,%.5f,%.0f,%@,%.5f,%.5f,%d",
                lat, lon, heading, destination, destLat, destLon, autoZoom ? 1 : 0
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
              autoZoom: \(autoZoom ? "true" : "false")
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
            let bg = dark ? "#1a1c1e" : "#dbd9d4"
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
                  {elementType:'geometry', stylers:[{color:'#e8e6e1'}]},
                  {elementType:'labels.text.fill', stylers:[{color:'#5a5a5a'}]},
                  {elementType:'labels.text.stroke', stylers:[{color:'#f5f3ef'}]},
                  {featureType:'road', elementType:'geometry', stylers:[{color:'#ffffff'}]},
                  {featureType:'road', elementType:'geometry.stroke', stylers:[{color:'#d0cec9'}]},
                  {featureType:'poi', stylers:[{visibility:'off'}]},
                  {featureType:'transit', stylers:[{visibility:'off'}]},
                  {featureType:'water', elementType:'geometry', stylers:[{color:'#c9d6e0'}]}
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
            let map, marker, destMarker, directionsService, directionsRenderer;
            let lastRouteKey = '';
            function showMsg(t){
              const el=document.getElementById('msg');
              if(el){ el.textContent=t||''; el.style.display=t?'flex':'none'; }
            }
            function blankDest(t){
              const s=(t||'').trim();
              return !s || s==='—' || s==='-' || s==='--';
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
                gestureHandling: 'none',
                keyboardShortcuts: false,
                styles: \(styles)
              });
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
                destMarker.setPosition({ lat: p.destLat, lng: p.destLon });
                destMarker.setMap(map);
              } else {
                destMarker.setMap(null);
              }

              if(!p.hasGPS){
                // No car GPS yet — center on destination pin.
                if(p.hasDestCoord){
                  map.setCenter({ lat: p.destLat, lng: p.destLon });
                  map.setZoom(14);
                }
                return;
              }

              directionsService.route({
                origin: origin,
                destination: target,
                travelMode: google.maps.TravelMode.DRIVING
              }, (result, status) => {
                if(status === 'OK' && result){
                  directionsRenderer.setDirections(result);
                  if(p.autoZoom && result.routes && result.routes[0]){
                    const b = result.routes[0].bounds;
                    if(b) map.fitBounds(b, 48);
                  }
                  // Dest marker from geocoded result when only name was known.
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
              if(!p.hasGPS && !p.hasDestCoord && blankDest(p.destination)){
                showMsg('Araç GPS / rota bekleniyor');
                clearRoute();
                return;
              }
              showMsg(p.hasGPS ? '' : (blankDest(p.destination) && !p.hasDestCoord ? 'GPS bekleniyor' : ''));
              const pos = { lat: p.lat, lng: p.lon };
              if(p.hasGPS){
                marker.setPosition(pos);
                marker.setMap(map);
                const icon = Object.assign({}, marker.getIcon() || {});
                icon.rotation = p.heading || 0;
                marker.setIcon(icon);
                if(!p.autoZoom || blankDest(p.destination) && !p.hasDestCoord){
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
    private var usingPhone: Bool { !hasCarGPS && phone.hasFix }

    private var effectiveTheme: HUDSettings.MapTheme {
        if let forceDark {
            return forceDark ? .dark : .light
        }
        return settings.mapTheme
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
                    autoZoom: settings.autoZoom
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
                    turnDistanceM: $turnDistanceM,
                    turnInstruction: $turnInstruction,
                    turnSymbol: $turnSymbol
                )
            }
        }
        .background(isDark ? Color.black : Color(red: 0.90, green: 0.91, blue: 0.93))
        .clipped()
        .onAppear { phone.start() }
    }
}
