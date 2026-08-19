import SwiftUI

@main
struct AimHubApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .active:
                        appState.sceneDidBecomeActive()
                    case .background, .inactive:
                        appState.sceneDidEnterBackground()
                    @unknown default:
                        break
                    }
                }
        }
    }
}