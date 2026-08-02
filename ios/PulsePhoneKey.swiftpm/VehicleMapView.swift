import SwiftUI
import MapKit
import UIKit

/// Real Apple Maps imagery via MKMapSnapshotter (no interactive Map / no CoreLocation).
/// Safer on Swift Playgrounds than MapKit `Map` view.
struct VehicleMapView: View {
    var lat: Double
    var lon: Double
    var heading: Double

    @State private var image: UIImage?
    @State private var lastKey = ""

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.86, green: 0.85, blue: 0.82)
                if abs(lat) < 0.0001 && abs(lon) < 0.0001 {
                    Text("Arac konumu bekleniyor")
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
        let w = max(120, size.width)
        let h = max(120, size.height)
        // Quantize so we don't snapshot every tiny GPS jitter
        let key = String(format: "%.4f,%.4f,%.0fx%.0f", lat, lon, w, h)
        guard key != lastKey else { return }
        lastKey = key

        let opts = MKMapSnapshotter.Options()
        opts.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )
        opts.size = CGSize(width: w * 2, height: h * 2) // retina-ish
        opts.mapType = .standard
        opts.showsBuildings = true
        opts.pointOfInterestFilter = .excludingAll

        MKMapSnapshotter(options: opts).start { snap, _ in
            DispatchQueue.main.async {
                self.image = snap?.image
            }
        }
    }
}
