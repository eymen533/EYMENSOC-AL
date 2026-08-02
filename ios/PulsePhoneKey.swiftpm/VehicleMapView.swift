import SwiftUI

/// Crash-safe map for Swift Playgrounds: OSM raster tile via AsyncImage.
/// No MapKit / MKMapSnapshotter / CoreLocation / WebKit.
struct VehicleMapView: View {
    var lat: Double
    var lon: Double
    var heading: Double

    private let zoom = 15

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.78, green: 0.82, blue: 0.78),
                        Color(red: 0.88, green: 0.90, blue: 0.86),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if abs(lat) < 0.0001 && abs(lon) < 0.0001 {
                    Text("Arac konumu bekleniyor")
                        .font(.caption)
                        .foregroundStyle(.black.opacity(0.45))
                } else {
                    tileStack
                    Image(systemName: "location.north.fill")
                        .font(.title)
                        .foregroundStyle(.red)
                        .rotationEffect(.degrees(heading))
                        .shadow(radius: 2)
                    VStack {
                        Spacer()
                        Text(String(format: "%.4f, %.4f", lat, lon))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.black.opacity(0.55))
                            .padding(6)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
    }

    @ViewBuilder
    private var tileStack: some View {
        if let url = tileURL(lat: lat, lon: lon, z: zoom) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    Color(red: 0.82, green: 0.85, blue: 0.80)
                default:
                    ProgressView()
                }
            }
        }
    }

    private func tileURL(lat: Double, lon: Double, z: Int) -> URL? {
        let n = pow(2.0, Double(z))
        let x = Int(floor((lon + 180.0) / 360.0 * n))
        let latRad = lat * .pi / 180.0
        let y = Int(floor((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / .pi) / 2.0 * n))
        // OpenStreetMap standard tile (Playgrounds ATS allows https)
        return URL(string: "https://tile.openstreetmap.org/\(z)/\(x)/\(y).png")
    }
}
