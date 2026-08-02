import SwiftUI

/// Playgrounds-safe map panel: no MapKit, no AsyncImage, no network.
/// Shows heading + coordinates only (crash-prone tile fetch removed).
struct VehicleMapView: View {
    var lat: Double
    var lon: Double
    var heading: Double

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
                // Soft grid — pure SwiftUI shapes
                Path { p in
                    let step: CGFloat = 28
                    var x: CGFloat = 0
                    while x < geo.size.width {
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: geo.size.height))
                        x += step
                    }
                    var y: CGFloat = 0
                    while y < geo.size.height {
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                        y += step
                    }
                }
                .stroke(Color.black.opacity(0.06), lineWidth: 1)

                if abs(lat) < 0.0001 && abs(lon) < 0.0001 {
                    Text("Arac konumu bekleniyor")
                        .font(.caption)
                        .foregroundStyle(.black.opacity(0.45))
                } else {
                    Image(systemName: "location.north.fill")
                        .font(.title)
                        .foregroundStyle(.red)
                        .rotationEffect(.degrees(heading))
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
}
