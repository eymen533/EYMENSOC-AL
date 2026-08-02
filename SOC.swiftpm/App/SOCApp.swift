import SwiftUI

@main
struct SOCApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .preferredColorScheme(.dark)
                #if os(iOS)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                // Prefer landscape in the car; portrait still works on iPad during setup.
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                #endif
        }
    }
}
