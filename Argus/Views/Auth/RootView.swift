import SwiftUI

/// Root router that shows LoginView when logged out, ContentView when logged in.
struct RootView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if settings.isLoggedIn {
            ContentView()
                .transition(.opacity)
        } else {
            LoginView()
                .transition(.opacity)
        }
    }
}
