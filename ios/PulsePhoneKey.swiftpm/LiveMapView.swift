import SwiftUI
import WebKit

/// Real OSM/Carto map via local Leaflet HTML in WKWebView (no MapKit — Playgrounds-safe).
struct LiveMapView: UIViewRepresentable {
    var lat: Double
    var lon: Double
    var heading: Double
    var follow: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.scrollView.bounces = false
        wv.loadHTMLString(Self.html, baseURL: URL(string: "https://local.pulse"))
        context.coordinator.web = wv
        return wv
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.web = webView
        context.coordinator.push(lat: lat, lon: lon, heading: heading, follow: follow)
    }

    final class Coordinator {
        weak var web: WKWebView?
        private var ready = false
        private var pending: String?

        func push(lat: Double, lon: Double, heading: Double, follow: Bool) {
            let js = String(
                format: "window.setPos && window.setPos(%.6f,%.6f,%.1f,%@);",
                lat, lon, heading, follow ? "true" : "false"
            )
            guard let web else { return }
            web.evaluateJavaScript("window.__pulseReady === true") { [weak self] result, _ in
                let ok = (result as? Bool) == true
                self?.ready = ok
                if ok {
                    web.evaluateJavaScript(js, completionHandler: nil)
                } else {
                    self?.pending = js
                    // Retry shortly while Leaflet boots
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self?.flush()
                    }
                }
            }
        }

        private func flush() {
            guard let web, let pending else { return }
            web.evaluateJavaScript("window.__pulseReady === true") { [weak self] result, _ in
                if (result as? Bool) == true {
                    web.evaluateJavaScript(pending, completionHandler: nil)
                    self?.pending = nil
                }
            }
        }
    }

    private static let html = """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"/>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <style>
      html,body,#m{margin:0;height:100%;width:100%;background:#e8e6e1;overflow:hidden}
      .leaflet-control-attribution{display:none!important}
    </style>
    </head>
    <body>
    <div id="m"></div>
    <script>
      window.__pulseReady = false;
      var map = L.map('m', { zoomControl:false, attributionControl:false, dragging:true }).setView([41.025,29.02], 16);
      L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
        maxZoom: 19, subdomains: 'abcd'
      }).addTo(map);
      var trail = L.polyline([], { color:'#e53935', weight:3.5, opacity:0.9 }).addTo(map);
      var arrowIcon = L.divIcon({
        className: '',
        html: '<div id="nav" style="width:0;height:0;border-left:9px solid transparent;border-right:9px solid transparent;border-bottom:22px solid #e53935;filter:drop-shadow(0 1px 2px rgba(0,0,0,.35));transform:rotate(0deg);transform-origin:50% 70%"></div>',
        iconSize: [18, 22], iconAnchor: [9, 16]
      });
      var marker = L.marker([41.025,29.02], { icon: arrowIcon }).addTo(map);
      window.setPos = function(lat, lon, heading, follow) {
        var ll = L.latLng(lat, lon);
        marker.setLatLng(ll);
        var el = document.getElementById('nav');
        if (el) el.style.transform = 'rotate(' + (heading||0) + 'deg)';
        var pts = trail.getLatLngs();
        if (!pts.length || pts[pts.length-1].distanceTo(ll) > 2) {
          trail.addLatLng(ll);
          if (pts.length > 90) trail.setLatLngs(pts.slice(-90));
        }
        if (follow !== false) map.panTo(ll, { animate: true, duration: 0.35 });
      };
      window.__pulseReady = true;
    </script>
    </body>
    </html>
    """
}
