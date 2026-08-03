import SwiftUI
import WebKit

/// Google Maps (JS) panel — 3D tilt, vehicle marker, route polyline when destination exists.
/// Uses Maps JavaScript API + Directions. No CocoaPods/SPM binary required (build-safe).
struct GoogleMapPanel: UIViewRepresentable {
    var lat: Double
    var lon: Double
    var heading: Double
    var destination: String
    var apiKey: String

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.isOpaque = false
        web.backgroundColor = UIColor(red: 0.86, green: 0.85, blue: 0.82, alpha: 1)
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.navigationDelegate = context.coordinator
        context.coordinator.webView = web
        context.coordinator.load(lat: lat, lon: lon, heading: heading, destination: destination, apiKey: apiKey)
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.webView = web
        context.coordinator.update(lat: lat, lon: lon, heading: heading, destination: destination, apiKey: apiKey)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        private var lastLoadKey = ""
        private var lastUpdateKey = ""
        private var pageReady = false

        func load(lat: Double, lon: Double, heading: Double, destination: String, apiKey: String) {
            let key = "\(apiKey)|\(hasGPS(lat, lon))"
            guard key != lastLoadKey else {
                update(lat: lat, lon: lon, heading: heading, destination: destination, apiKey: apiKey)
                return
            }
            lastLoadKey = key
            pageReady = false
            let html = Self.html(apiKey: apiKey)
            webView?.loadHTMLString(html, baseURL: URL(string: "https://local.pulse.maps/"))
            // First update after load finishes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.pageReady = true
                self?.update(lat: lat, lon: lon, heading: heading, destination: destination, apiKey: apiKey)
            }
        }

        func update(lat: Double, lon: Double, heading: Double, destination: String, apiKey: String) {
            guard pageReady, let web = webView else { return }
            let dest = destination
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: " ")
            let gps = hasGPS(lat, lon)
            let ukey = String(format: "%.5f,%.5f,%.0f,%@", lat, lon, heading, dest)
            guard ukey != lastUpdateKey else { return }
            lastUpdateKey = ukey
            let js = """
            window.pulseUpdate({
              lat: \(gps ? lat : 41.0082),
              lon: \(gps ? lon : 28.9784),
              heading: \(heading),
              hasGPS: \(gps ? "true" : "false"),
              destination: '\(dest)'
            });
            """
            web.evaluateJavaScript(js, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageReady = true
        }

        private func hasGPS(_ lat: Double, _ lon: Double) -> Bool {
            abs(lat) > 0.0001 || abs(lon) > 0.0001
        }

        private static func html(apiKey: String) -> String {
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let keyJS = key.isEmpty ? "" : key
            return """
            <!DOCTYPE html>
            <html>
            <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"/>
            <style>
              html,body,#map{margin:0;padding:0;width:100%;height:100%;background:#dbd9d4;overflow:hidden}
              #msg{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;
                font:14px -apple-system,BlinkMacSystemFont,sans-serif;color:rgba(0,0,0,.45);z-index:2;pointer-events:none}
            </style>
            </head>
            <body>
            <div id="msg">Google Maps…</div>
            <div id="map"></div>
            <script>
            let map, marker, routeLine, directionsService, directionsRenderer;
            let lastDest = '';
            function showMsg(t){ const el=document.getElementById('msg'); if(el){ el.textContent=t||''; el.style.display=t?'flex':'none'; } }
            function init(){
              if(!window.google || !google.maps){ showMsg('Google Maps API key gerekli (Settings)'); return; }
              showMsg('');
              map = new google.maps.Map(document.getElementById('map'), {
                center: {lat:41.0082, lng:28.9784},
                zoom: 17,
                tilt: 67.5,
                heading: 0,
                mapTypeId: 'roadmap',
                disableDefaultUI: true,
                gestureHandling: 'none',
                keyboardShortcuts: false,
                styles: [
                  {elementType:'geometry', stylers:[{color:'#e8e6e1'}]},
                  {elementType:'labels.text.fill', stylers:[{color:'#5a5a5a'}]},
                  {elementType:'labels.text.stroke', stylers:[{color:'#f5f3ef'}]},
                  {featureType:'road', elementType:'geometry', stylers:[{color:'#ffffff'}]},
                  {featureType:'road', elementType:'geometry.stroke', stylers:[{color:'#d0cec9'}]},
                  {featureType:'poi', stylers:[{visibility:'off'}]},
                  {featureType:'transit', stylers:[{visibility:'off'}]},
                  {featureType:'water', elementType:'geometry', stylers:[{color:'#c9d6e0'}]}
                ]
              });
              directionsService = new google.maps.DirectionsService();
              directionsRenderer = new google.maps.DirectionsRenderer({
                map: map,
                suppressMarkers: true,
                preserveViewport: false,
                polylineOptions: {
                  strokeColor: '#1a73e8',
                  strokeOpacity: 0.95,
                  strokeWeight: 6
                }
              });
              const icon = {
                path: google.maps.SymbolPath.FORWARD_CLOSED_ARROW,
                scale: 7,
                fillColor: '#e53935',
                fillOpacity: 1,
                strokeColor: '#ffffff',
                strokeWeight: 1.5,
                rotation: 0
              };
              marker = new google.maps.Marker({ map: map, icon: icon, zIndex: 10 });
            }
            function clearRoute(){
              if(directionsRenderer) directionsRenderer.set('directions', null);
              lastDest = '';
            }
            function drawRoute(origin, destText){
              if(!directionsService || !destText || destText === '—' || destText === '-' || destText === '--'){
                clearRoute();
                return;
              }
              if(destText === lastDest) return;
              lastDest = destText;
              directionsService.route({
                origin: origin,
                destination: destText,
                travelMode: google.maps.TravelMode.DRIVING
              }, (result, status) => {
                if(status === 'OK' && result){
                  directionsRenderer.setDirections(result);
                } else {
                  // Keep last good route; don't flash errors on HUD.
                }
              });
            }
            window.pulseUpdate = function(p){
              if(!map || !marker) return;
              showMsg(p.hasGPS ? '' : 'GPS bekleniyor');
              const pos = { lat: p.lat, lng: p.lon };
              marker.setPosition(pos);
              const icon = Object.assign({}, marker.getIcon() || {});
              icon.rotation = p.heading || 0;
              marker.setIcon(icon);
              map.setCenter(pos);
              map.setZoom(17);
              if(map.setTilt) map.setTilt(67.5);
              if(map.setHeading) map.setHeading(p.heading || 0);
              if(p.hasGPS) drawRoute(pos, (p.destination||'').trim());
            };
            </script>
            \(keyJS.isEmpty
                ? "<script>document.getElementById('msg').textContent='Settings → Google Maps API key';</script>"
                : "<script src=\"https://maps.googleapis.com/maps/api/js?key=\(keyJS)&callback=init\" async defer></script>")
            </body>
            </html>
            """
        }
    }
}

/// Vehicle nav on Apple Maps — uses car GPS + destination from BLE. No API key.
struct VehicleMapView: View {
    var lat: Double
    var lon: Double
    var heading: Double
    var destination: String = ""
    var destLat: Double = 0
    var destLon: Double = 0
    var apiKey: String = "" // ignored — kept for call-site compatibility
    @Binding var turnDistanceM: Int
    @Binding var turnInstruction: String
    @Binding var turnSymbol: String
    @ObservedObject private var settings = HUDSettings.shared

    var body: some View {
        AppleMapPanel(
            lat: lat,
            lon: lon,
            heading: heading,
            destination: destination,
            destLat: destLat,
            destLon: destLon,
            autoZoom: settings.autoZoom,
            theme: settings.mapTheme,
            turnDistanceM: $turnDistanceM,
            turnInstruction: $turnInstruction,
            turnSymbol: $turnSymbol
        )
        .background(Color.black)
    }
}
