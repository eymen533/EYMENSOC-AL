import MapKit
import SwiftUI

struct RightMapPanelView: View {
    let state: VehicleState
    let connectionStatus: ConnectionStatus
    @EnvironmentObject private var appModel: AppModel
    @State private var mapAppeared = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppleMapView(
                coordinate: appModel.locationService.coordinate,
                heading: appModel.locationService.heading,
                pitch: 60,
                altitude: 480
            )
            .opacity(mapAppeared ? 1 : 0)
            .animation(.easeOut(duration: 0.55), value: mapAppeared)

            // Soft vignette so odo/compass stay readable over Apple Maps tiles.
            LinearGradient(
                colors: [.black.opacity(0.5), .clear, .clear, .black.opacity(0.4)],
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
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.trailing, 10)
                    .padding(.bottom, 14)
            }
        }
        .onAppear { mapAppeared = true }
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
}
