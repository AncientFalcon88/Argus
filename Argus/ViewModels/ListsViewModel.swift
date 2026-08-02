import Foundation
import SwiftData
import SwiftUI

enum SortOption: String, CaseIterable {
    case defaultSort = "Default"
    case random = "Random"
    case topRated = "Top Rated"
    case newest = "Newest" 
    case oldest = "Oldest" 
    case titleAZ = "Title A \u{2192} Z"
    case titleZA = "Title Z \u{2192} A"
    
    var icon: String {
        switch self {
        case .defaultSort: return "list.bullet"
        case .random: return "dice"
        case .topRated: return "star.fill"
        case .newest: return "sparkles"
        case .oldest: return "clock"
        case .titleAZ: return "arrow.up"
        case .titleZA: return "arrow.down"
        }
    }
}

@MainActor
final class ListsViewModel: ObservableObject {
    @Published var pmdbRatings: [Int: Int] = [:]
    @Published var cleanPosters: [Int: URL] = [:]
    @Published var itemLogos: [Int: URL] = [:]
    @Published var lists: [MediaList] = []
    var filteredMyLists: [MediaList] {
        if searchText.isEmpty { return lists }
        return lists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    @Published var discoverLists: [MediaList] = []
    @Published var selectedList: MediaList?
    @Published var listItems: [ListItem] = []
    private var originalListItems: [ListItem] = []
    @Published var isLoading = true
    @Published var isDiscoverLoading = true
    @Published var errorMessage: String?
    @Published var newListName = ""
    @Published var searchText = ""

    private let api = APIService.shared
    private let enrichment = MetadataEnrichmentService.shared
    private var cache: CacheRepository?
    private var searchTask: Task<Void, Never>?

    func configure(context: ModelContext) {
        cache = CacheRepository(context: context)
        loadFromCache()
    }

    func loadFromCache() {
        guard let cache else { return }
        do {
            let cached = try cache.cachedLists()
            if !cached.isEmpty {
                lists = cached.map {
                    var list = MediaList(
                        id: $0.remoteId,
                        name: $0.name,
                        description: $0.listDescription,
                        isPublic: $0.isPublic,
                        type: .custom,
                        itemCount: $0.itemCount,
                        createdAt: nil,
                        updatedAt: nil
                    )
                    list.previewPosters = $0.posterURLs.compactMap { URL(string: $0) }
                    return list
                }
                isLoading = false // Instantly dismiss skeletons if cache exists
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh(showLoading: Bool = false) async {
        guard Config.isAPIKeyConfigured else {
            errorMessage = "Please log in to get started"
            return
        }
        if lists.isEmpty || showLoading { isLoading = true }
        if discoverLists.isEmpty || showLoading { isDiscoverLoading = true }
        errorMessage = nil

        // ── Discover lists (PocketBase, no API key needed) ──
        Task {
            do {
                let res = try await (searchText.isEmpty ? api.fetchDiscoverLists() : api.searchLists(query: searchText))
                await MainActor.run {
                    self.discoverLists = res.items
                    self.isDiscoverLoading = false
                }
                let enriched = await enrichDiscoverLists(res.items)
                await MainActor.run { self.discoverLists = enriched }
            } catch {
                await MainActor.run {
                    self.isDiscoverLoading = false
                    if !(error is CancellationError) { self.errorMessage = error.localizedDescription }
                }
            }
        }

        // ── My Lists (external API, requires API key) ──
        do {
            let listsRes = try await api.fetchLists()

            var combinedLists: [MediaList] = listsRes.items

            // Cache for offline use
            if let cache { try? cache.replaceLists(listsRes.items) }

            // Cache watchlist ID to avoid repeated fetches
            if let watchlist = listsRes.items.first(where: { $0.type == .watchlist }) {
                cachedWatchlistId = watchlist.id
            }

            // Append any saved public lists that aren't already in the user's lists
            if let cache {
                let saved = (try? cache.savedPublicLists()) ?? []
                let existingIds = Set(combinedLists.map { $0.id })
                let savedMediaLists: [MediaList] = saved.compactMap { savedList in
                    guard !existingIds.contains(savedList.remoteId) else { return nil }
                    var list = MediaList(
                        id: savedList.remoteId,
                        name: savedList.name,
                        description: savedList.listDescription,
                        isPublic: true,
                        type: .custom,
                        itemCount: savedList.itemCount,
                        createdAt: nil,
                        updatedAt: nil,
                        creatorName: savedList.creatorName
                    )
                    list.previewPosters = savedList.posterURLs.compactMap { URL(string: $0) }
                    return list
                }
                combinedLists.append(contentsOf: savedMediaLists)
            }

            // Show immediately (raw, no posters yet)
            self.lists = sortedLists(combinedLists)
            isLoading = false

            // Enrich posters in background without blocking the UI
            Task {
                let enriched = await MetadataEnrichmentService.shared.enrichLists(listsRes.items)
                await MainActor.run {
                    // Merge enriched versions into existing list, preserving order
                    let enrichedById = Dictionary(uniqueKeysWithValues: enriched.map { ($0.id, $0) })
                    self.lists = self.lists.map { enrichedById[$0.id] ?? $0 }
                    
                    // Update cache with the fully enriched lists so other views (like Favorites) get the posters and counts
                    if let cache = self.cache {
                        try? cache.replaceLists(enriched)
                    }
                }
            }

        } catch is CancellationError {
            isLoading = false
        } catch {
            // fetchLists failed — keep whatever was loaded from cache, just hide the spinner
            isLoading = false
            print("[Lists] fetchLists error: \(error)")
        }
    }


    private func sortedLists(_ input: [MediaList]) -> [MediaList] {
        input.sorted { a, b in
            let wa = a.type == .watchlist || a.name.lowercased() == "my watchlist"
            let wb = b.type == .watchlist || b.name.lowercased() == "my watchlist"
            if wa && !wb { return true }
            if wb && !wa { return false }
            return (a.createdAt ?? "") < (b.createdAt ?? "")
        }
    }
    
    @Published var isSearching = false
    
    func performSearch() {
        searchTask?.cancel()
        
        guard !searchText.isEmpty else {
            // Optional: reset to default discover lists here if needed, 
            // or just trigger the default fetch
            searchTask = Task {
                self.isSearching = true
                defer { self.isSearching = false }
                do {
                    let res = try await api.fetchDiscoverLists()
                    self.discoverLists = await enrichDiscoverLists(res.items)
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
            return
        }
        
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                guard !Task.isCancelled else { return }
                
                await MainActor.run { self.isSearching = true }
                defer { Task { @MainActor in self.isSearching = false } }
                
                let res = try await api.searchLists(query: searchText)
                self.discoverLists = await enrichDiscoverLists(res.items)
                
            } catch is CancellationError {
                return
            } catch let urlError as URLError where urlError.code == .cancelled {
                return
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }
    
    private func enrichDiscoverLists(_ lists: [MediaList]) async -> [MediaList] {
        var enrichedLists = lists
        await withTaskGroup(of: (Int, [URL?]).self) { group in
            for i in 0..<enrichedLists.count {
                let previewItems = enrichedLists[i].previewItems
                if !previewItems.isEmpty {
                    group.addTask {
                        let enrichedItems = await MetadataEnrichmentService.shared.enrichListItems(previewItems)
                        return (i, enrichedItems.prefix(6).map { $0.posterURL })
                    }
                }
            }
            
            for await (index, posters) in group {
                enrichedLists[index].previewPosters = posters
            }
        }
        return enrichedLists
    }

    func loadItems(for list: MediaList) async {
        selectedList = list
        isLoading = true
        defer { isLoading = false }
        do {
            var allItems: [ListItem] = []
            var page = 1
            
            // Loop aggressively until we've pulled down the entire list, bypassing backend perPage limits
            while true {
                let response = try await api.fetchListItems(listId: list.id, page: page, perPage: 1000)
                allItems.append(contentsOf: response.items)
                
                if response.items.count < 1000 {
                    break
                }
                page += 1
            }
            
            let enriched = await enrichment.enrichListItems(allItems)
            
            // Pre-fetch ALL metadata (ratings, logos, posters) before showing the UI to guarantee zero pop-in delay.
            await fetchRichMetadata(for: enriched)
            
            listItems = enriched
            originalListItems = enriched
            fetchWatchlist()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sortListItems(by option: SortOption) {
        listItems = sortItems(originalListItems, by: option)
    }

    private func sortItems(_ items: [ListItem], by option: SortOption) -> [ListItem] {
        switch option {
        case .defaultSort: return items
        case .random: return items.shuffled()
        case .topRated: return items.sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
        case .newest:
            return items.sorted { ($0.year ?? "") > ($1.year ?? "") }
        case .oldest:
            return items.sorted { ($0.year ?? "") < ($1.year ?? "") }
        case .titleAZ: return items.sorted { ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "") == .orderedAscending }
        case .titleZA: return items.sorted { ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "") == .orderedDescending }
        }
    }
    
    private func fetchRichMetadata(for items: [ListItem]) async {
        let tmdbItems = items.map { $0.toMediaItem() }
        let (newRatings, newPosters, newLogos) = await MetadataEnrichmentService.shared.fetchRichMetadata(
            for: tmdbItems,
            pmdbRatings: pmdbRatings,
            cleanPosters: cleanPosters,
            itemLogos: itemLogos
        )
        
        await MainActor.run {
            for (k, v) in newRatings { self.pmdbRatings[k] = v }
            for (k, v) in newPosters { self.cleanPosters[k] = v }
            for (k, v) in newLogos { self.itemLogos[k] = v }
        }
    }

    func createList() async {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            _ = try await api.createList(CreateListRequest(name: name, description: nil, isPublic: true, type: .custom))
            newListName = ""
            await refresh()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteList(_ list: MediaList) async {
        do {
            try await api.deleteList(id: list.id)
            if selectedList?.id == list.id {
                selectedList = nil
                listItems = []
            }
            await refresh()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeItem(_ item: ListItem) async {
        guard let listId = selectedList?.id, let list = selectedList else { return }
        do {
            try await api.removeListItem(listId: listId, itemId: item.id)
            await loadItems(for: list)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Save/Unsave Public Lists
    
    func isListSaved(listId: String) -> Bool {
        guard let cache else { return false }
        return (try? cache.isPublicListSaved(id: listId)) ?? false
    }
    
    func addList(list: MediaList) {
        Task {
            guard let cache else { return }
            cache.savePublicList(list)
            await refresh()
        }
    }

    // MARK: - Ratings
    func removeList(listId: String) {
        Task {
            guard let cache else { return }
            cache.removePublicList(id: listId)
            await refresh()
        }
    }
    // MARK: - Watchlist (cached ID to avoid re-fetching)
    private var cachedWatchlistId: String?
    @Published var watchlistedItemIds: Set<Int> = []

    func isInWatchlist(_ item: ListItem) -> Bool {
        watchlistedItemIds.contains(item.tmdbId)
    }

    func fetchWatchlist() {
        Task {
            do {
                let watchlistId: String
                if let cached = cachedWatchlistId {
                    watchlistId = cached
                } else {
                    let response = try await APIService.shared.fetchLists(perPage: 50)
                    guard let wl = response.items.first(where: { $0.type == .watchlist }) else { return }
                    cachedWatchlistId = wl.id
                    watchlistId = wl.id
                }
                var allItems: [ListItem] = []
                var page = 1
                while true {
                    let items = try await APIService.shared.fetchListItems(listId: watchlistId, page: page, perPage: 1000)
                    allItems.append(contentsOf: items.items)
                    if items.items.count < 1000 { break }
                    page += 1
                }
                await MainActor.run { self.watchlistedItemIds = Set(allItems.compactMap { $0.tmdbId }) }
            } catch { print("Failed to fetch watchlist: \(error)") }
        }
    }

    func addToWatchlist(_ item: ListItem) {
        Task {
            do {
                let watchlistId: String
                if let cached = cachedWatchlistId {
                    watchlistId = cached
                } else {
                    let response = try await APIService.shared.fetchLists(perPage: 50)
                    guard let wl = response.items.first(where: { $0.type == .watchlist }) else { return }
                    cachedWatchlistId = wl.id
                    watchlistId = wl.id
                }
                _ = try await APIService.shared.addListItem(
                    listId: watchlistId,
                    request: AddListItemRequest(tmdbId: item.tmdbId, mediaType: item.mediaType)
                )
                watchlistedItemIds.insert(item.tmdbId)
            } catch { print("Failed to add to watchlist: \(error)") }
        }
    }

    func removeFromWatchlist(_ item: ListItem) {
        Task {
            do {
                let watchlistId: String
                if let cached = cachedWatchlistId {
                    watchlistId = cached
                } else {
                    let response = try await APIService.shared.fetchLists(perPage: 50)
                    guard let wl = response.items.first(where: { $0.type == .watchlist }) else { return }
                    cachedWatchlistId = wl.id
                    watchlistId = wl.id
                }
                var listItemIdToRemove: String? = nil
                var page = 1
                while true {
                    let items = try await APIService.shared.fetchListItems(listId: watchlistId, page: page, perPage: 1000)
                    if let found = items.items.first(where: { $0.tmdbId == item.tmdbId }) {
                        listItemIdToRemove = found.id
                        break
                    }
                    if items.items.count < 1000 { break }
                    page += 1
                }
                guard let itemId = listItemIdToRemove else { return }
                try await APIService.shared.removeListItem(listId: watchlistId, itemId: itemId)
                watchlistedItemIds.remove(item.tmdbId)
                if selectedList?.id == watchlistId {
                    await loadItems(for: selectedList!)
                }
            } catch { print("Failed to remove from watchlist: \(error)") }
        }
    }
}
