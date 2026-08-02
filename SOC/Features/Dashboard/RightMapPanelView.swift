import MapKit
import SwiftUI

struct RightMapPanelView: View {
    let state: VehicleState
    let connectionStatus: ConnectionStatus
    @EnvironmentObject private var appModel: AppModel
    @State private var position: MapCameraPosition = .automatic
    @State private var mapAppeared = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            map
                .clipShape(Rectangle())
                .opacity(mapAppeared ? 1 : 0)
                .animation(.easeOut(duration: 0.6), value: mapAppeared)

            LinearGradient(
                colors: [.black.opacity(0.55), .clear, .black.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    Spacer()
                    compass
                }
                Text(VehicleStateMapper.formatOdometer(state.odometerKm, unit: appModel.unitSystem))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.trailing, 10)
                    .padding(.bottom, 14)
            }
        }
        .onAppear {
            mapAppeared = true
            updateCamera()
        }
        .onChange(of: appModel.locationService.coordinate?.latitude) { _, _ in
            updateCamera()
        }
        .onChange(of: appModel.locationService.heading) { _, _ in
            updateCamera()
        }
    }

    @ViewBuilder
    private var map: some View {
        Map(position: $position) {
            if let coordinate = appModel.locationService.coordinate {
                Annotation("", coordinate: coordinate) {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(SOCTheme.mapArrow)
                        .rotationEffect(.degrees(appModel.locationService.heading))
                        .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                }
            }
        }
        .mapStyle(.standard(
            elevation: .realistic,
            pointsOfInterest: .excludingAll,
            showsTraffic: false
        ))
        .colorScheme(.dark)
        .disabled(true)
    }

    private var compass: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.55))
                .frame(width: 42, height: 42)
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .frame(width: 42, height: 42)
            VStack(spacing: 1) {
                Text("N")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.red)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-appModel.locationService.heading))
            }
        }
        .padding(.trailing, 12)
        .padding(.bottom, 28)
    }

    private func updateCamera() {
        guard let coordinate = appModel.locationService.coordinate else {
            // Istanbul-ish fallback so the map isn't empty during setup.
            position = .camera(
                MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
                    distance: 650,
                    heading: 0,
                    pitch: 60
                )
            )
            return
        }

        position = .camera(
            MapCamera(
                centerCoordinate: coordinate,
                distance: 520,
                heading: appModel.locationService.heading,
                pitch: 62
            )
        )
    }
}
