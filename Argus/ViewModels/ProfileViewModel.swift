import Foundation
import SwiftData
import SwiftUI

enum ProfileStatDestination: Hashable {
    case calendar
    case favorites
    case myProgress
    case myStats
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var lastSyncText = "Never synced"
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIService.shared
    private let enrichment = MetadataEnrichmentService.shared
    private let favorites = FavoritesService.shared

    func refresh(context: ModelContext) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let cache = CacheRepository(context: context)
        do {
            if Config.isAPIKeyConfigured {
                async let resume = api.fetchResumePoints()
                async let watched = api.fetchWatchHistory(perPage: 500)
                async let lists = api.fetchLists()
                let (r, w, l) = try await (resume, watched, lists)

                let enrichedResume = await enrichment.enrichResumePoints(r.items)
                let enrichedWatched = await enrichment.enrichWatchEntries(w.items)
                let enrichedLists = await enrichment.enrichLists(l.items)

                try cache.replaceResumePoints(enrichedResume)
                try cache.replaceWatchHistory(enrichedWatched)
                try cache.replaceLists(enrichedLists)
                lastSyncText = "Last sync \(Date.now.formatted(date: .abbreviated, time: .shortened))"
            }

            // Sync favorites (uses PocketBase token, not API key)
            if favorites.isLoggedIn {
                await syncFavorites(context: context)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Favorites Sync

    func syncFavorites(context: ModelContext) async {
        do {
            let remote = try await favorites.fetchMyFavorites()
            let remoteIds = Set(remote.map { $0.id })

            // Fetch all local favorites
            let descriptor = FetchDescriptor<FavoriteItem>()
            let local = (try? context.fetch(descriptor)) ?? []
            let localById = Dictionary(uniqueKeysWithValues: local.compactMap { item -> (String, FavoriteItem)? in
                guard let rid = item.remoteId else { return nil }
                return (rid, item)
            })

            // Upsert remote items into SwiftData
            for apiItem in remote {
                let category = FavoriteCategory.from(apiMediaType: apiItem.mediaType ?? "movie")
                let timePeriod = FavoriteTimePeriod.from(apiPeriod: apiItem.period ?? "all_time")
                // slot in API is 1-based, slotIndex is 0-based
                let slotIndex = max(0, (apiItem.slot ?? 1) - 1)

                if let existing = localById[apiItem.id] {
                    existing.title = apiItem.title ?? ""
                    existing.posterPath = (apiItem.posterPath ?? "").isEmpty ? nil : apiItem.posterPath
                    existing.releaseYear = (apiItem.year ?? "").isEmpty ? nil : apiItem.year
                    existing.reasonText = apiItem.why ?? ""
                    existing.tmdbId = apiItem.tmdbId ?? 0
                    existing.listId = (apiItem.listRef ?? "").isEmpty ? nil : apiItem.listRef
                    existing.category = category
                    existing.timePeriod = timePeriod
                    existing.slotIndex = slotIndex
                } else {
                    let matchingLocal = local.first {
                        $0.category == category &&
                        $0.timePeriod == timePeriod &&
                        $0.slotIndex == slotIndex &&
                        $0.remoteId == nil
                    }
                    if let ml = matchingLocal {
                        ml.remoteId = apiItem.id
                        ml.title = apiItem.title ?? ""
                        ml.posterPath = (apiItem.posterPath ?? "").isEmpty ? nil : apiItem.posterPath
                        ml.releaseYear = (apiItem.year ?? "").isEmpty ? nil : apiItem.year
                        ml.reasonText = apiItem.why ?? ""
                        ml.tmdbId = apiItem.tmdbId ?? 0
                        ml.listId = (apiItem.listRef ?? "").isEmpty ? nil : apiItem.listRef
                    } else {
                        let newItem = FavoriteItem(
                            tmdbId: apiItem.tmdbId ?? 0,
                            listId: (apiItem.listRef ?? "").isEmpty ? nil : apiItem.listRef,
                            remoteId: apiItem.id,
                            category: category,
                            timePeriod: timePeriod,
                            slotIndex: slotIndex,
                            title: apiItem.title ?? "",
                            posterPath: (apiItem.posterPath ?? "").isEmpty ? nil : apiItem.posterPath,
                            releaseYear: (apiItem.year ?? "").isEmpty ? nil : apiItem.year,
                            reasonText: apiItem.why ?? ""
                        )
                        context.insert(newItem)
                    }
                }
            }

            // Remove local items that no longer exist on server (have a remoteId but server deleted them)
            for item in local {
                if let rid = item.remoteId, !remoteIds.contains(rid) {
                    context.delete(item)
                }
            }

            try? context.save()
            print("[Favorites] Synced \(remote.count) favorites from server.")
        } catch {
            print("[Favorites] Sync error: \(error)")
        }
    }
}

private extension APIService {
    func fetchResumePoints() async throws -> PaginatedResponse<ResumePoint> {
        try await fetchResumePoints(query: ResumeQuery())
    }
}

