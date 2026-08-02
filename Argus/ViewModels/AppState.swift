import Foundation
import SwiftData
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var syncMessage: String = "Add your API keys in Profile → Settings"
    @Published var isSyncing = false
    @Published var lastError: String?
    @Published var isCertifiedNerd = false

    let api = APIService.shared
    let tmdb = TMDBService.shared

    private var cache: CacheRepository?
    private let enrichment = MetadataEnrichmentService.shared

    func configure(context: ModelContext) {
        cache = CacheRepository(context: context)
    }

    func refreshAccountData() async {
        guard Config.isAPIKeyConfigured else {
            syncMessage = "Please log in to get started"
            return
        }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        do {
            async let resume = api.fetchResumePoints()
            async let watched = api.fetchWatchHistory(perPage: 100)
            async let lists = api.fetchLists()

            let (resumeData, watchedData, listsData) = try await (resume, watched, lists)
            
            var allListItems: [String: [ListItem]] = [:]
            for list in listsData.items {
                do {
                    let itemsResponse = try await api.fetchListItems(listId: list.id, perPage: 1000)
                    allListItems[list.id] = itemsResponse.items
                } catch { }
            }

            let enrichedResume = await enrichment.enrichResumePoints(resumeData.items)
            let enrichedWatched = await enrichment.enrichWatchEntries(watchedData.items)

            if let cache {
                try cache.replaceResumePoints(enrichedResume)
                try cache.replaceWatchHistory(enrichedWatched)
                try cache.replaceLists(listsData.items)
                for (listId, items) in allListItems {
                    try cache.replaceListItems(listId: listId, items: items)
                }
            }

            syncMessage = "Synced \(enrichedResume.count) resume · \(enrichedWatched.count) plays · \(listsData.items.count) lists"
        } catch {
            lastError = error.localizedDescription
            syncMessage = error.localizedDescription
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case discover = "Discover"
    case picks = "Picks"
    case lists = "Lists"
    case profile = "Profile"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: "play.rectangle.fill"
        case .discover: "square.grid.2x2.fill"
        case .picks: "sparkles.rectangle.stack.fill"
        case .lists: "list.bullet.rectangle.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}
