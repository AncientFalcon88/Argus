import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            AppBackground()
            TabView(selection: $appState.selectedTab) {
                HomeView()
                    .tabItem { Label(AppTab.home.rawValue, systemImage: AppTab.home.symbol) }
                    .tag(AppTab.home)

                DiscoverView()
                    .tabItem { Label(AppTab.discover.rawValue, systemImage: AppTab.discover.symbol) }
                    .tag(AppTab.discover)

                PicksView()
                    .tabItem { Label(AppTab.picks.rawValue, systemImage: AppTab.picks.symbol) }
                    .tag(AppTab.picks)

                ListsView()
                    .tabItem { Label(AppTab.lists.rawValue, systemImage: AppTab.lists.symbol) }
                    .tag(AppTab.lists)

                ProfileView()
                    .tabItem { Label(AppTab.profile.rawValue, systemImage: AppTab.profile.symbol) }
                    .tag(AppTab.profile)
            }
            .tint(.white)
        }
        .preferredColorScheme(.dark)
        .task {
            appState.configure(context: modelContext)
        }
    }
}
