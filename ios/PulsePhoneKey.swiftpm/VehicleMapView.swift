import SwiftUI
import MapKit
import UIKit

/// Apple Maps imagery via MKMapSnapshotter (no interactive Map / no CoreLocation).
/// Falls back to a plain panel if snapshot fails — never crashes the HUD.
struct VehicleMapView: View {
    var lat: Double
    var lon: Double
    var heading: Double

    @State private var image: UIImage?
    @State private var lastKey = ""
    @State private var failed = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.86, green: 0.85, blue: 0.82)
                if abs(lat) < 0.0001 && abs(lon) < 0.0001 {
                    Text("GPS bekleniyor (BLE)")
                        .font(.caption)
                        .foregroundStyle(.black.opacity(0.45))
                } else if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                    Image(systemName: "location.north.fill")
                        .font(.title)
                        .foregroundStyle(.red)
                        .rotationEffect(.degrees(heading))
                        .shadow(radius: 2)
                } else if failed {
                    VStack(spacing: 6) {
                        Text("Apple Maps")
                            .font(.caption.weight(.semibold))
                        Text(String(format: "%.5f, %.5f", lat, lon))
                            .font(.caption2.monospacedDigit())
                    }
                    .foregroundStyle(.black.opacity(0.55))
                } else {
                    ProgressView()
                }
            }
            .onAppear { refresh(size: geo.size) }
            .onChange(of: lat) { _, _ in refresh(size: geo.size) }
            .onChange(of: lon) { _, _ in refresh(size: geo.size) }
            .onChange(of: geo.size) { _, new in refresh(size: new) }
        }
        .clipped()
    }

    private func refresh(size: CGSize) {
        guard abs(lat) > 0.0001 || abs(lon) > 0.0001 else { return }
        let w = max(160, size.width)
        let h = max(160, size.height)
        // Quantize — avoid snapshot spam
        let key = String(format: "%.4f,%.4f,%.0fx%.0f", lat, lon, w, h)
        guard key != lastKey else { return }
        lastKey = key
        failed = false

        let opts = MKMapSnapshotter.Options()
        opts.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            latitudinalMeters: 450,
            longitudinalMeters: 450
        )
        opts.size = CGSize(width: min(w * 2, 800), height: min(h * 2, 800))
        opts.mapType = .standard
        opts.showsBuildings = true
        opts.pointOfInterestFilter = .excludingAll

        MKMapSnapshotter(options: opts).start { snap, error in
            DispatchQueue.main.async {
                if let img = snap?.image {
                    self.image = img
                    self.failed = false
                } else {
                    self.failed = true
                    _ = error // swallow — show coords fallback
                }
            }
        }
    }
}
