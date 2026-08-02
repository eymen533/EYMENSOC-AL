import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch appModel.route {
            case .dashboard:
                DashboardView()
                    .transition(.opacity)

            case .beforeYouStart:
                BeforeYouStartView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))

            case .pairVIN:
                PairVehicleView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))

            case .waitingForKeyCard:
                KeyCardVerificationView()
                    .transition(.opacity)

            case .settings:
                SettingsView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: appModel.route)
        .onAppear {
            appModel.locationService.requestAuthorizationIfNeeded()
            appModel.mediaService.start()
        }
    }
}
