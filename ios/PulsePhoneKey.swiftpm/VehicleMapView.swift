import SwiftUI

/// Map panel without MapKit (Playgrounds crash). Shows GPS + heading only.
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
                VStack(spacing: 18) {
                    ForEach(0..<5, id: \.self) { row in
                        HStack(spacing: 14) {
                            ForEach(0..<3, id: \.self) { col in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(white: 0.70 - Double((row + col) % 3) * 0.04))
                                    .frame(width: 36 + CGFloat(col) * 10, height: 22 + CGFloat(row % 2) * 8)
                            }
                        }
                    }
                }
                .rotationEffect(.degrees(-6))
                .opacity(0.85)

                if abs(lat) < 0.0001 && abs(lon) < 0.0001 {
                    Text("GPS bekleniyor (BLE)")
                        .font(.caption)
                        .foregroundStyle(.black.opacity(0.45))
                } else {
                    Image(systemName: "location.north.fill")
                        .font(.title)
                        .foregroundStyle(.red)
                        .rotationEffect(.degrees(heading))
                        .shadow(radius: 2)
                    VStack {
                        Spacer()
                        Text(String(format: "%.5f, %.5f", lat, lon))
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
