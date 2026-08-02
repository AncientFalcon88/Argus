import Foundation
import SwiftUI
import Combine
import SwiftData

@MainActor
final class MediaDetailViewModel: ObservableObject {
    let route: MediaDetailRoute

    @Published var detail: MediaDetailInfo?
    @Published var selectedSeason = 1
    @Published var episodes: [EpisodeDisplay] = []
    @Published var selectedCommunityTab: CommunityDataTab
    @Published var dedupedCommunityRatings: [CommunityRatingSummary] = []
    
    var totalCommunityVotes: Int {
        dedupedCommunityRatings.reduce(0) { $0 + $1.voteCount }
    }
    
    @Published var myRatings: [Rating] = []
    /// IDs of ratings submitted this session — used as fallback when API doesn't return is_owner
    private var sessionSubmittedRatingIds: Set<String> = []
    @Published var recommendations: [TMDBMediaItem] = []
    @Published var collectionMovies: [TMDBMediaItem] = []
    @Published var pmdbAverageRating: Int?
    @Published var pmdbRatings: [Int: Int] = [:]
    @Published var cleanPosters: [Int: URL] = [:]
    @Published var itemLogos: [Int: URL] = [:]
    @Published var resumePoint: ResumePoint?
    @Published var trailerURL: URL?
    struct LocalEpisodeRating: Hashable, Identifiable {
        let id: String
        let score: Int
        let label: String?
        let userId: String?
        let username: String?
        var voteCount: Int
        var userVote: Int
        let isOwner: Bool
        let avatarUrl: URL?
        let createdAt: String?
        
        var dateString: String? {
            guard let createdAt = createdAt else { return nil }
            // API typically returns "2026-06-04 12:34:56.000Z"
            let prefix = String(createdAt.prefix(10))
            let parts = prefix.split(separator: "-")
            if parts.count == 3 {
                return "\(parts[2])/\(parts[1])/\(parts[0])"
            }
            return prefix
        }
    }
    @Published var seasonEpisodeRatings: [Int: [LocalEpisodeRating]] = [:]
    @Published var episodeRatingSummaries: [Int: EpisodeRatingSummary] = [:]
    @Published var skips: [SkipTimestamp] = []
    // Episode-keyed skip data loaded when opening the sheet
    @Published var episodeSkips: [SkipTimestamp] = []   // all submissions for current sheet episode
    @Published var myEpisodeSkip: SkipTimestamp? = nil  // user's own submission
    @Published var isLoadingSkipSheet: Bool = false
    @Published var skipSubmitError: String? = nil
    @Published var skipSubmitSuccess: Bool = false
    
    // MARK: - Skips UI State
    @Published var showSkipSheet: Bool = false
    @Published var selectedSkipEpisode: EpisodeDisplay? = nil
    
    // MARK: - Highlights UI State
    @Published var highlights: [Highlight] = []
    @Published var episodeHighlights: [Highlight] = []
    @Published var myEpisodeHighlight: Highlight? = nil
    @Published var isLoadingHighlightSheet: Bool = false
    @Published var showHighlightSheet: Bool = false
    @Published var selectedHighlightEpisode: Int? = nil
    @Published var highlightSubmitError: String? = nil
    @Published var highlightSubmitSuccess: Bool = false
    
    var seasonEpisodeHighlights: [Int: [Highlight]] {
        var dict: [Int: [Highlight]] = [:]
        for highlight in highlights {
            guard let ep = highlight.episode else { continue }  // skip if no episode (movie highlights)
            dict[ep, default: []].append(highlight)
        }
        return dict
    }
    
    // MARK: - Season Mapping State
    @Published var seasonMappings: [AnimeSeasonMapping] = []
    @Published var showSeasonMappingSheet: Bool = false
    @Published var seasonMappingSubmitError: String? = nil
    @Published var seasonMappingSubmitSuccess: Bool = false
    @Published var isLoadingSeasonMappings: Bool = false
    @Published var editingSeasonMapping: AnimeSeasonMapping? = nil
    
    var isAnime: Bool {
        guard let d = detail else { return false }
        let hasAnimation = d.genres.contains("Animation")
        let isJapan = d.originalLanguage == "ja" || (d.originCountry?.contains("JP") == true)
        return hasAnimation && isJapan
    }
    
    @Published var mappings: [ExternalMapping] = []
    @Published var watchedEpisodeKeys: Set<String> = []
    @Published var watchHistoryItems: [WatchEntry] = []
    /// Deduped count of unique (season, episode) pairs watched for this TV show.
    @Published var watchedEpisodePairCount: Int = 0
    /// Total non-special episode count from TMDB for this TV show.
    @Published var totalEpisodeCount: Int = 0
    @Published var userLists: [MediaList] = []
    @Published var containedListItems: [String: String] = [:] // [ListID: ItemID]
    @Published var isInList = false
    @Published var isLoading = false
    @Published var isLoadingEpisodes = false
    @Published var errorMessage: String?
    @Published var actionMessage: String?
    @Published var showListPicker = false
    // External IDs Sheet
    @Published var showExternalIDSheet = false
    @Published var selectedExternalIDType: ExternalIDType = .imdb
    @Published var externalIDSubmitError: String? = nil
    @Published var externalIDSubmitSuccess = false
    @Published var editingMappingId: String? = nil
    
    // Community Rating Form
    @Published var showCommunityRatingSheet = false
    @Published var editingCommunityRating: CommunityRatingSummary? = nil
    @Published var communityRatingSubmitSuccess = false
    @Published var communityRatingSubmitError: String? = nil
    @Published var targetScrollEpisode: Int?

    private let api = APIService.shared
    private let tmdb = TMDBService.shared
    private var cancellables = Set<AnyCancellable>()
    private var hasLoaded = false

    init(route: MediaDetailRoute) {
        self.route = route
        self.selectedSeason = route.season ?? 1
        self.selectedCommunityTab = .ratings
        
        NotificationCenter.default.publisher(for: .watchStateDidChange)
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    if self.route.mediaType == .tv {
                        await self.loadEpisodeWatchedKeys()
                    } else {
                        await self.loadWatchedState()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private var localContext: ModelContext?

    func loadCachedState(context: ModelContext) {
        self.localContext = context
        let tmdbId = route.tmdbId
        let mediaType = route.mediaType.rawValue
        let descriptor = FetchDescriptor<CachedWatchEntry>(predicate: #Predicate { $0.tmdbId == tmdbId && $0.mediaType == mediaType })
        if let cached = try? context.fetch(descriptor), !cached.isEmpty {
            if route.mediaType == .movie {
                watchedEpisodeKeys = ["movie"]
            } else {
                var keys = Set<String>()
                var uniquePairs = Set<String>()
                for entry in cached {
                    if let s = entry.season, let e = entry.episode {
                        keys.insert(episodeKey(season: s, episode: e))
                        if s > 0 && e > 0 {
                            uniquePairs.insert("s\(s)-e\(e)")
                        }
                    }
                }
                watchedEpisodeKeys = keys
                watchedEpisodePairCount = uniquePairs.count
            }
        }
        
        let listDescriptor = FetchDescriptor<CachedMediaList>()
        if let cachedLists = try? context.fetch(listDescriptor), !cachedLists.isEmpty {
            userLists = cachedLists.map { $0.toMediaList() }
        }
        
        let listItemsDescriptor = FetchDescriptor<CachedListItem>(predicate: #Predicate { $0.tmdbId == tmdbId })
        if let cachedListItems = try? context.fetch(listItemsDescriptor), !cachedListItems.isEmpty {
            isInList = true
            var foundItems: [String: String] = [:]
            for item in cachedListItems {
                foundItems[item.listId] = item.id
            }
            containedListItems = foundItems
        }
    }

    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let detailTask = tmdb.fetchDetailInfo(tmdbId: route.tmdbId, mediaType: route.mediaType)
            async let recommendationsTask = tmdb.fetchRecommendations(
                tmdbId: route.tmdbId,
                mediaType: route.mediaType
            )
            async let communityTask: Void = fetchCommunityData()

            let info = try await detailTask
            await communityTask // Wait for community data to finish before rendering

            if info.mediaType == .tv {
                totalEpisodeCount = info.seasons
                    .filter { $0.seasonNumber > 0 }
                    .reduce(0) { $0 + $1.episodeCount }
            }

            do {
                let recs = try await recommendationsTask
                // Pre-fetch rich metadata for recommendations (ratings, logos, textless posters)
                await fetchRichMetadata(for: recs)
                recommendations = recs
            } catch {
                recommendations = []
            }
            
            if info.mediaType == .tv {
                if route.season == nil { 
                    selectedSeason = info.seasons.first(where: { $0.seasonNumber > 0 })?.seasonNumber ?? info.seasons.first?.seasonNumber ?? 1 
                }
            }
            
            await self.loadRating(for: self.route.tmdbId, mediaType: self.route.mediaType, isHero: true)
            
            // Load real season mappings for anime shows
            if isAnime {
                await loadSeasonMappings()
            }

            // Assign detail LAST so the UI renders fully populated without popping
            detail = info

            // Fetch collection movies if this is part of a franchise
            if let collId = info.collectionId {
                Task {
                    do {
                        let collection = try await TMDBService.shared.fetchCollection(id: collId)
                        let parts = (collection.parts ?? [])
                            .map { $0.mediaItem(defaultKind: .movie) }
                            .filter { $0.tmdbId != info.tmdbId } // exclude current film
                            .sorted { ($0.releaseDate ?? "") < ($1.releaseDate ?? "") }
                        await MainActor.run { self.collectionMovies = parts }
                    } catch { /* silently skip if unavailable */ }
                }
            }
            
            if info.mediaType == .tv {
                updateTargetScrollEpisode(for: info)
                await loadEpisodes()
                if Config.isAPIKeyConfigured {
                    await loadCommunityData()
                }
                
                // Retrigger scroll if target is set
                let current = targetScrollEpisode
                targetScrollEpisode = nil
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    targetScrollEpisode = current
                }
            } else {
                if Config.isAPIKeyConfigured {
                    await loadCommunityData()
                }
            }
            
            await fetchTrailer()
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func fetchTrailer() async {
        do {
            if let extIds = try? await TMDBService.shared.fetchExternalIDs(tmdbId: route.tmdbId, mediaType: route.mediaType),
               let fetchedImdb = extIds.imdb_id, !fetchedImdb.isEmpty {
                let typeString = route.mediaType == .movie ? "movie" : "series"
                if let url = URL(string: "https://trailerio.cc/meta/\(typeString)/\(fetchedImdb).json") {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let meta = json["meta"] as? [String: Any],
                       let links = meta["links"] as? [[String: Any]] {
                        
                        let bestLink = links.first { dict in
                            let prov = (dict["provider"] as? String ?? "").lowercased()
                            let trailers = dict["trailers"] as? String ?? ""
                            return prov.contains("720p") && trailers.contains(".mp4")
                        } ?? links.first { dict in
                            let prov = (dict["provider"] as? String ?? "").lowercased()
                            let trailers = dict["trailers"] as? String ?? ""
                            return prov.contains("1080p") && trailers.contains(".mp4")
                        } ?? links.first { dict in
                            let trailers = dict["trailers"] as? String ?? ""
                            return trailers.contains(".mp4")
                        } ?? links.first
                        
                        if let bestLink = bestLink, let urlString = bestLink["trailers"] as? String {
                            await MainActor.run {
                                self.trailerURL = URL(string: urlString)
                            }
                        }
                    }
                }
            }
        } catch {
            // Silently fail if trailer is unavailable
        }
    }

    func seasonDidChange() async {
        if let detail = detail {
            updateTargetScrollEpisode(for: detail, targetSeasonOnly: selectedSeason)
        }
        
        await loadEpisodes()
        if Config.isAPIKeyConfigured {
            await loadCommunityData()
        }
    }

    private func updateTargetScrollEpisode(for info: MediaDetailInfo, targetSeasonOnly: Int? = nil) {
        var targetSeason: Int?
        var targetEpisode: Int?
        
        let effectiveTargetSeason = targetSeasonOnly ?? route.season
        
        if let effectiveTargetSeason = effectiveTargetSeason {
            if let rp = resumePoint, rp.season == effectiveTargetSeason, let e = rp.episode, rp.progressFraction < 0.95 {
                targetSeason = effectiveTargetSeason
                targetEpisode = e
            } else if let re = route.episode, targetSeasonOnly == nil {
                targetSeason = effectiveTargetSeason
                targetEpisode = re
            } else {
                if let season = info.seasons.first(where: { $0.seasonNumber == effectiveTargetSeason }) {
                    var maxWatched = 0
                    for epNum in 1...season.episodeCount {
                        let key = episodeKey(season: season.seasonNumber, episode: epNum)
                        if watchedEpisodeKeys.contains(key) {
                            maxWatched = max(maxWatched, epNum)
                        }
                    }
                    targetEpisode = (maxWatched > 0 && maxWatched < season.episodeCount) ? maxWatched + 1 : 1
                }
                targetSeason = effectiveTargetSeason
            }
        } else {
            if let rp = resumePoint, let s = rp.season, let e = rp.episode {
                if rp.progressFraction < 0.95 {
                    targetSeason = s
                    targetEpisode = e
                }
            }
            
            if targetSeason == nil || targetEpisode == nil {
                let regularSeasons = info.seasons.filter { $0.seasonNumber > 0 }.sorted { $0.seasonNumber < $1.seasonNumber }
                for season in regularSeasons {
                    var maxWatched = 0
                    for epNum in 1...season.episodeCount {
                        let key = episodeKey(season: season.seasonNumber, episode: epNum)
                        if watchedEpisodeKeys.contains(key) {
                            maxWatched = max(maxWatched, epNum)
                        }
                    }
                    if maxWatched < season.episodeCount {
                        targetSeason = season.seasonNumber
                        targetEpisode = maxWatched == 0 ? 1 : maxWatched + 1
                        break
                    }
                }
                // Fallback if they watched absolutely everything
                if targetSeason == nil {
                    if let lastSeason = regularSeasons.last {
                        targetSeason = lastSeason.seasonNumber
                        targetEpisode = 1
                    }
                }
            }
        }
        
        if let s = targetSeason, let e = targetEpisode {
            if route.season == nil && selectedSeason != s {
                selectedSeason = s
            }
            if selectedSeason == s {
                targetScrollEpisode = e
            }
        }
    }

    func loadEpisodes() async {
        guard route.mediaType == .tv else { return }
        isLoadingEpisodes = true
        defer { isLoadingEpisodes = false }
        do {
            episodes = try await tmdb.fetchSeasonEpisodes(tmdbId: route.tmdbId, season: selectedSeason)
        } catch {
            episodes = []
        }
    }


    func toggleWatched(episode: Int) {
        guard Config.isAPIKeyConfigured else {
            errorMessage = "Please log in to continue"
            return
        }
        let key = episodeKey(season: selectedSeason, episode: episode)
        let pairKey = "s\(selectedSeason)-e\(episode)"

        if watchedEpisodeKeys.contains(key) {
            // UNMARK
            guard let entry = watchHistoryItems.first(where: {
                $0.tmdbId == route.tmdbId &&
                $0.season == selectedSeason &&
                $0.episode == episode
            }) else { return }

            let alreadyCounted = watchedEpisodeKeys.contains { $0.hasSuffix("-\(pairKey)") }
            
            // Optimistic update
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                watchedEpisodeKeys.remove(key)
                watchHistoryItems.removeAll { $0.id == entry.id }
                
                let stillHasPair = watchedEpisodeKeys.contains { $0.hasSuffix("-\(pairKey)") }
                if alreadyCounted && !stillHasPair {
                    watchedEpisodePairCount = max(0, watchedEpisodePairCount - 1)
                }
            }

            Task {
                do {
                    try await api.deleteWatchEntry(id: entry.id)
                    await MainActor.run { actionMessage = "Removed from watched" }
                } catch {
                    // Rollback
                    await MainActor.run {
                        withAnimation {
                            watchedEpisodeKeys.insert(key)
                            watchHistoryItems.append(entry)
                            let stillHasPair = watchedEpisodeKeys.contains { $0.hasSuffix("-\(pairKey)") }
                            if alreadyCounted && !stillHasPair {
                                watchedEpisodePairCount += 1
                            }
                        }
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            // MARK
            let alreadyCounted = watchedEpisodeKeys.contains { $0.hasSuffix("-\(pairKey)") }

            // Optimistic update
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                watchedEpisodeKeys.insert(key)
                if !alreadyCounted { watchedEpisodePairCount += 1 }
            }

            Task {
                do {
                    _ = try await api.markAsWatched(MarkWatchedRequest(
                        tmdbId: route.tmdbId,
                        mediaType: .tv,
                        season: selectedSeason,
                        episode: episode
                    ))
                    await MainActor.run { actionMessage = "Marked as watched" }
                    // Reload in background to fetch the newly created entry's ID for potential future toggles
                    await loadEpisodeWatchedKeys()
                } catch {
                    await MainActor.run {
                        withAnimation {
                            watchedEpisodeKeys.remove(key)
                            if !alreadyCounted { watchedEpisodePairCount = max(0, watchedEpisodePairCount - 1) }
                        }
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    func markEpisodeRewatched(episode: Int?, watchedAt: Date? = nil) {
        guard Config.isAPIKeyConfigured else {
            errorMessage = "Please log in to continue"
            return
        }
        
        let dateString: String?
        if let date = watchedAt {
            let formatter = ISO8601DateFormatter()
            dateString = formatter.string(from: date)
        } else {
            dateString = nil
        }
        
        Task {
            do {
                _ = try await api.markAsWatched(MarkWatchedRequest(
                    tmdbId: route.tmdbId,
                    mediaType: route.mediaType,
                    season: route.mediaType == .movie ? nil : selectedSeason,
                    episode: episode,
                    watchedAt: dateString
                ))
                await MainActor.run { actionMessage = "Marked as rewatched" }
                await loadEpisodeWatchedKeys()
                // Update history
                await loadWatchedState()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    func markEpisodeRewatchedAsync(episode: Int?, watchedAt: Date? = nil) async {
        guard Config.isAPIKeyConfigured else {
            await MainActor.run { errorMessage = "Please log in to continue" }
            return
        }
        
        let formatter = ISO8601DateFormatter()
        let dateString: String?
        if let date = watchedAt {
            dateString = formatter.string(from: date)
        } else {
            dateString = formatter.string(from: Date())
        }
        
        let req = MarkWatchedRequest(
            tmdbId: route.tmdbId,
            mediaType: route.mediaType,
            season: route.mediaType == .movie ? nil : selectedSeason,
            episode: episode,
            watchedAt: dateString
        )
        
        do {
            let response = try await api.markAsWatched(req)
            
            // OPTIMISTIC UPDATE: The server save succeeded.
            // The server's GET endpoint ignores tmdb_id/media_type filters and has
            // race conditions, so we insert the new entry directly into local state
            // instead of depending on a refetch to find it.
            let newEntry = WatchEntry(
                id: response.id ?? UUID().uuidString,
                tmdbId: route.tmdbId,
                mediaType: route.mediaType,
                season: route.mediaType == .movie ? nil : selectedSeason,
                episode: episode,
                watchedAt: dateString,
                title: detail?.title,
                name: detail?.title,
                posterPath: detail?.posterPath
            )
            
            await MainActor.run {
                // Prepend the new entry so it appears at the top of the plays list
                watchHistoryItems.insert(newEntry, at: 0)
                // For movies, mark as watched
                if route.mediaType == .movie {
                    watchedEpisodeKeys.insert("movie")
                }
                actionMessage = "Play logged"
            }
            
            // Also refresh episode watched keys for TV shows
            if route.mediaType == .tv {
                await loadEpisodeWatchedKeys()
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }


    func editWatchDate(id: String, newDate: Date) async {
        guard Config.isAPIKeyConfigured else { return }
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: newDate)
        
        do {
            _ = try await api.editWatchDate(id: id, request: EditWatchDateRequest(watchedAt: dateString))
            // Directly update the local entry — server ignores tmdb_id filter so
            // loadWatchedState can't find this entry to reflect the new date.
            await MainActor.run {
                if let idx = watchHistoryItems.firstIndex(where: { $0.id == id }) {
                    let old = watchHistoryItems[idx]
                    watchHistoryItems[idx] = WatchEntry(
                        id: old.id,
                        tmdbId: old.tmdbId,
                        mediaType: old.mediaType,
                        season: old.season,
                        episode: old.episode,
                        watchedAt: dateString,
                        title: old.title,
                        name: old.name,
                        posterPath: old.posterPath,
                        backdropPath: old.backdropPath,
                        episodeName: old.episodeName,
                        episodeStillPath: old.episodeStillPath
                    )
                }
                actionMessage = "Play date updated"
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    func deleteWatchEntry(id: String) async {
        guard Config.isAPIKeyConfigured else { return }
        do {
            try await api.deleteWatchEntry(id: id)
            // Directly remove from local state
            await MainActor.run {
                watchHistoryItems.removeAll { $0.id == id }
                // If no movie plays remain, mark as unwatched
                if route.mediaType == .movie && !watchHistoryItems.contains(where: { $0.mediaType == .movie }) {
                    watchedEpisodeKeys.remove("movie")
                }
                actionMessage = "Play deleted"
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    // MARK: - Bulk Episode Actions

    func markSeasonWatched() async {
        guard Config.isAPIKeyConfigured else { return }
        let targetSeason = selectedSeason
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = formatter.string(from: now)
        
        guard let episodes = try? await tmdb.fetchSeasonEpisodes(tmdbId: route.tmdbId, season: targetSeason) else { return }
        let sortedEpisodes = episodes.filter { $0.episodeNumber > 0 }.sorted { $0.episodeNumber < $1.episodeNumber }
        
        // Optimistic UI update
        for ep in sortedEpisodes {
            watchedEpisodeKeys.insert(episodeKey(season: targetSeason, episode: ep.episodeNumber))
            
            let fakeItem = WatchEntry(
                id: UUID().uuidString,
                tmdbId: route.tmdbId,
                mediaType: .tv,
                season: targetSeason,
                episode: ep.episodeNumber,
                watchedAt: dateString,
                title: nil,
                name: nil,
                posterPath: nil
            )
            watchHistoryItems.append(fakeItem)
        }
        
        let pairsCount = Set(watchedEpisodeKeys.compactMap { key -> String? in
            guard let dashRange = key.range(of: "-s") else { return nil }
            return String(key[dashRange.upperBound...])
        })
        watchedEpisodePairCount = pairsCount.count
        
        Task {
            for ep in sortedEpisodes {
                _ = try? await api.markAsWatched(MarkWatchedRequest(
                    tmdbId: route.tmdbId, mediaType: .tv, season: targetSeason, episode: ep.episodeNumber, watchedAt: dateString
                ), notify: false)
            }
            await MainActor.run { 
                actionMessage = "Marked season as watched"
                NotificationCenter.default.post(name: .watchStateDidChange, object: nil)
            }
            await loadEpisodeWatchedKeys()
        }
    }

    func markSeasonUnwatched() async {
        guard Config.isAPIKeyConfigured else { return }
        let targetSeason = selectedSeason
        try? await api.bulkDeleteWatchHistory(query: WatchedBulkDeleteQuery(
            tmdbId: route.tmdbId, mediaType: .tv, season: targetSeason, episode: nil
        ))
        await MainActor.run { actionMessage = "Marked season as unwatched" }
        await loadEpisodeWatchedKeys()
    }

    func markPreviousWatched(upTo episode: Int) async {
        guard Config.isAPIKeyConfigured else { return }
        guard let detail = detail else { return }
        let currentSeason = selectedSeason
        
        var episodeTargets: [(season: Int, episode: Int)] = []
        
        await withTaskGroup(of: [(Int, Int)].self) { group in
            for season in detail.seasons where currentSeason == 0 ? season.seasonNumber == 0 : (season.seasonNumber > 0 && season.seasonNumber <= currentSeason) {
                let sNumber = season.seasonNumber
                group.addTask { [tmdb, route] in
                    guard let episodes = try? await tmdb.fetchSeasonEpisodes(tmdbId: route.tmdbId, season: sNumber) else { return [] }
                    var targets: [(Int, Int)] = []
                    for ep in episodes where ep.episodeNumber > 0 {
                        if sNumber < currentSeason {
                            targets.append((sNumber, ep.episodeNumber))
                        } else if sNumber == currentSeason && ep.episodeNumber < episode {
                            targets.append((sNumber, ep.episodeNumber))
                        }
                    }
                    return targets
                }
            }
            for await targets in group {
                episodeTargets.append(contentsOf: targets)
            }
        }
        
        episodeTargets.sort {
            if $0.season == $1.season {
                return $0.episode < $1.episode
            }
            return $0.season < $1.season
        }
        
        // Optimistic UI update
        for target in episodeTargets {
            watchedEpisodeKeys.insert(episodeKey(season: target.season, episode: target.episode))
        }
        
        Task {
            for target in episodeTargets {
                _ = try? await api.markAsWatched(MarkWatchedRequest(
                    tmdbId: route.tmdbId, mediaType: .tv, season: target.season, episode: target.episode
                ))
            }
            await MainActor.run { actionMessage = "Marked previous as watched" }
            await loadEpisodeWatchedKeys()
        }
    }

    func markPreviousUnwatched(upTo episode: Int) async {
        guard Config.isAPIKeyConfigured else { return }
        guard let detail = detail else { return }
        let currentSeason = selectedSeason
        
        await withTaskGroup(of: Void.self) { group in
            for season in detail.seasons where season.seasonNumber > 0 && season.seasonNumber < currentSeason {
                let sNumber = season.seasonNumber
                group.addTask { [api, route] in
                    try? await api.bulkDeleteWatchHistory(query: WatchedBulkDeleteQuery(
                        tmdbId: route.tmdbId, mediaType: .tv, season: sNumber, episode: nil
                    ))
                }
            }
            for ep in 1..<episode {
                group.addTask { [api, route] in
                    try? await api.bulkDeleteWatchHistory(query: WatchedBulkDeleteQuery(
                        tmdbId: route.tmdbId, mediaType: .tv, season: currentSeason, episode: ep
                    ))
                }
            }
        }
        await MainActor.run { actionMessage = "Marked previous as unwatched" }
        await loadEpisodeWatchedKeys()
    }

    func removeWatchProgress() async {
        guard Config.isAPIKeyConfigured else { return }
        guard let resumeId = resumePoint?.id else { return }
        try? await api.deleteResumePoint(id: resumeId)
        await MainActor.run {
            resumePoint = nil
            actionMessage = "Removed watch progress"
        }
    }

    func fetchShowIsWatched() async -> Bool {
        guard Config.isAPIKeyConfigured else { return false }
        do {
            let response = try await api.fetchWatchHistory(perPage: 500)
            return response.items.contains { entry in
                entry.tmdbId == route.tmdbId && entry.mediaType == route.mediaType
            }
        } catch {
            return false
        }
    }

    func unmarkShowWatched() async throws {
        // Optimistic UI Update
        watchedEpisodeKeys = []
        watchHistoryItems = []
        watchedEpisodePairCount = 0
        actionMessage = "Removed watch mark"

        Task {
            if route.mediaType == .movie {
                try? await api.bulkDeleteWatchHistory(query: WatchedBulkDeleteQuery(
                    tmdbId: route.tmdbId,
                    mediaType: .movie,
                    season: nil,
                    episode: nil
                ))
                await loadWatchedState()
            } else if let detail = detail {
                await withTaskGroup(of: Void.self) { group in
                    for season in detail.seasons where season.seasonNumber > 0 {
                        let seasonNumber = season.seasonNumber
                        group.addTask { [api, route] in
                            try? await api.bulkDeleteWatchHistory(query: WatchedBulkDeleteQuery(
                                tmdbId: route.tmdbId,
                                mediaType: route.mediaType,
                                season: seasonNumber,
                                episode: nil
                            ))
                        }
                    }
                }
                await loadEpisodeWatchedKeys()
            }
        }
    }

    func markMovieWatched() async throws {
        _ = try await api.markAsWatched(MarkWatchedRequest(
            tmdbId: route.tmdbId,
            mediaType: .movie
        ))
        watchedEpisodeKeys.insert("movie")
        actionMessage = "Marked as watched"
        await loadWatchedState()
    }

    func markAllTVEpisodesWatched() async throws {
        guard let detail, route.mediaType == .tv else { return }

        let oldKeys = watchedEpisodeKeys
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = formatter.string(from: now)

        // Optimistic UI update instantly!
        for season in detail.seasons where season.seasonNumber > 0 {
            if season.episodeCount > 0 {
                for ep in 1...season.episodeCount {
                    let key = episodeKey(season: season.seasonNumber, episode: ep)
                    if !watchedEpisodeKeys.contains(key) {
                        watchedEpisodeKeys.insert(key)
                        
                        let fakeItem = WatchEntry(
                            id: UUID().uuidString,
                            tmdbId: route.tmdbId,
                            mediaType: .tv,
                            season: season.seasonNumber,
                            episode: ep,
                            watchedAt: dateString,
                            title: detail.title,
                            name: detail.title,
                            posterPath: detail.posterPath
                        )
                        watchHistoryItems.append(fakeItem)
                    }
                }
            }
        }
        
        // Recount unique pairs after optimistic update
        let pairsCount = Set(watchedEpisodeKeys.compactMap { key -> String? in
            guard let dashRange = key.range(of: "-s") else { return nil }
            return String(key[dashRange.upperBound...])
        })
        watchedEpisodePairCount = pairsCount.count

        Task {
            var episodeTargets: [(season: Int, episode: Int)] = []
            await withTaskGroup(of: [(Int, Int)].self) { group in
                let tmdbConcurrency = 10
                var tmdbActive = 0
                
                for season in detail.seasons where season.seasonNumber > 0 {
                    if tmdbActive >= tmdbConcurrency {
                        _ = await group.next()
                        tmdbActive -= 1
                    }
                    tmdbActive += 1
                    
                    let seasonNumber = season.seasonNumber
                    group.addTask { [tmdb, route] in
                        var retries = 3
                        while retries > 0 {
                            if let episodes = try? await tmdb.fetchSeasonEpisodes(
                                tmdbId: route.tmdbId,
                                season: seasonNumber
                            ) {
                                return episodes
                                    .filter { $0.episodeNumber > 0 }
                                    .map { (seasonNumber, $0.episodeNumber) }
                            }
                            retries -= 1
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                        }
                        return []
                    }
                }
                for await pairs in group {
                    episodeTargets.append(contentsOf: pairs)
                }
            }

            episodeTargets.sort {
                if $0.season == $1.season {
                    return $0.episode < $1.episode
                }
                return $0.season < $1.season
            }

            let unwatchedTargets = episodeTargets.filter { !oldKeys.contains(self.episodeKey(season: $0.season, episode: $0.episode)) }
            guard !unwatchedTargets.isEmpty else { return }

            await withTaskGroup(of: Void.self) { group in
                let maxConcurrency = 3
                var activeTasks = 0
                
                for (index, target) in unwatchedTargets.enumerated() {
                    if activeTasks >= maxConcurrency {
                        _ = await group.next()
                        activeTasks -= 1
                    }
                    activeTasks += 1
                    
                    let targetDate = now.addingTimeInterval(Double(index) * 0.001)
                    let targetDateString = formatter.string(from: targetDate)
                    
                    group.addTask {
                        var retries = 5
                        while retries > 0 {
                            do {
                                _ = try await self.api.markAsWatched(MarkWatchedRequest(
                                    tmdbId: self.route.tmdbId,
                                    mediaType: .tv,
                                    season: target.season,
                                    episode: target.episode,
                                    watchedAt: targetDateString
                                ), notify: false)
                                break // Success, exit retry loop
                            } catch {
                                retries -= 1
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                            }
                        }
                    }
                }
            }
            await MainActor.run { 
                actionMessage = "Marked show as watched"
                NotificationCenter.default.post(name: .watchStateDidChange, object: nil)
            }
            await loadEpisodeWatchedKeys()
        }
        // Recount unique pairs after bulk mark
        let pairs = Set(watchedEpisodeKeys.compactMap { key -> String? in
            // keys are "tmdbId-s1-e1" — extract the "s1-e1" suffix
            guard let dashRange = key.range(of: "-s") else { return nil }
            return String(key[dashRange.lowerBound...].dropFirst(1)) // "s1-e1"
        })
        watchedEpisodePairCount = pairs.count
        actionMessage = "Marked all episodes as watched"
    }

    func reloadEpisodeWatchedKeys() async {
        await loadEpisodeWatchedKeys()
    }

    func reloadEpisodeRatings() async {
        await fetchEpisodeRatings(tmdbId: route.tmdbId, season: selectedSeason)
    }

    func loadEpisodeWatchedKeys() async {
        guard route.mediaType == .tv else { return }
        guard Config.isAPIKeyConfigured else {
            watchedEpisodeKeys = []
            watchHistoryItems = []
            watchedEpisodePairCount = 0
            return
        }

        do {
            var allItems: [WatchEntry] = []
            // Fetch first page
            let firstResponse = try await api.fetchWatchHistory(
                page: 1,
                perPage: 500,
                tmdbId: route.tmdbId,
                mediaType: .tv
            )
            allItems.append(contentsOf: firstResponse.items)
            let totalPages = firstResponse.pages ?? 1
            
            // Fetch remaining pages concurrently
            if totalPages > 1 {
                let extraItems = try await withThrowingTaskGroup(of: [WatchEntry].self) { group in
                    for page in 2...totalPages {
                        group.addTask {
                            let response = try await self.api.fetchWatchHistory(
                                page: page,
                                perPage: 500,
                                tmdbId: self.route.tmdbId,
                                mediaType: .tv
                            )
                            return response.items
                        }
                    }
                    var collected: [WatchEntry] = []
                    for try await items in group {
                        collected.append(contentsOf: items)
                    }
                    return collected
                }
                allItems.append(contentsOf: extraItems)
            }
            let relevantItems = allItems.filter { $0.tmdbId == route.tmdbId }
            watchHistoryItems = relevantItems
            // Full key (with tmdbId prefix) used for per-card lookup in the episode grid
            watchedEpisodeKeys = Set(relevantItems.compactMap { entry -> String? in
                guard let season = entry.season, let episode = entry.episode else { return nil }
                return "\(entry.tmdbId)-s\(season)-e\(episode)"
            })
            // Plain (season, episode) dedup — used ONLY for the isWatched threshold comparison
            let uniquePairs = Set(relevantItems.compactMap { entry -> String? in
                guard let season = entry.season, let episode = entry.episode,
                      season > 0, episode > 0 else { return nil }
                return "s\(season)-e\(episode)"
            })
            watchedEpisodePairCount = uniquePairs.count
        } catch {
            watchedEpisodeKeys = []
            watchHistoryItems = []
            watchedEpisodePairCount = 0
        }
    }

    func addToList(_ list: MediaList) async {
        guard Config.isAPIKeyConfigured else { return }
        do {
            _ = try await api.addListItem(
                listId: list.id,
                request: AddListItemRequest(tmdbId: route.tmdbId, mediaType: route.mediaType)
            )
            actionMessage = "Added to \(list.name)"
            // Reload silently to fetch the new listItem.id
            await loadLists()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func removeFromList(listId: String, itemId: String, listName: String) async {
        guard Config.isAPIKeyConfigured else { return }
        do {
            try await api.removeListItem(listId: listId, itemId: itemId)
            actionMessage = "Removed from \(listName)"
            // Reload silently to clear it out
            await loadLists()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Context Menu Condition Helpers
    
    func isCurrentSeasonFullyWatched() -> Bool {
        guard !episodes.isEmpty else { return false }
        return episodes.allSatisfy { watchedEpisodeKeys.contains(episodeKey(season: selectedSeason, episode: $0.episodeNumber)) }
    }

    func isCurrentSeasonFullyUnwatched() -> Bool {
        guard !episodes.isEmpty else { return false }
        return episodes.allSatisfy { !watchedEpisodeKeys.contains(episodeKey(season: selectedSeason, episode: $0.episodeNumber)) }
    }

    func hasUnwatchedPreviousEpisodes(upTo episode: Int) -> Bool {
        guard let detail = detail else { return true }
        
        for season in detail.seasons where season.seasonNumber > 0 && season.seasonNumber < selectedSeason {
            let sNum = season.seasonNumber
            let epCount = season.episodeCount
            if epCount > 0 {
                for ep in 1...epCount {
                    if !watchedEpisodeKeys.contains(episodeKey(season: sNum, episode: ep)) {
                        return true
                    }
                }
            }
        }
        
        for ep in 1..<episode {
            if !watchedEpisodeKeys.contains(episodeKey(season: selectedSeason, episode: ep)) {
                return true
            }
        }
        
        return false
    }

    func hasWatchedPreviousEpisodes(upTo episode: Int) -> Bool {
        guard let detail = detail else { return false }
        
        for season in detail.seasons where season.seasonNumber > 0 && season.seasonNumber < selectedSeason {
            let sNum = season.seasonNumber
            let epCount = season.episodeCount
            if epCount > 0 {
                for ep in 1...epCount {
                    if watchedEpisodeKeys.contains(episodeKey(season: sNum, episode: ep)) {
                        return true
                    }
                }
            }
        }
        
        for ep in 1..<episode {
            if watchedEpisodeKeys.contains(episodeKey(season: selectedSeason, episode: ep)) {
                return true
            }
        }
        
        return false
    }

    func episodeKey(season: Int, episode: Int) -> String {
        "\(route.tmdbId)-s\(season)-e\(episode)"
    }

    func loadCommunityRatings() async {
        guard Config.isAPIKeyConfigured else {
            dedupedCommunityRatings = []
            return
        }
        do {
            let response = try await api.fetchRatings(tmdbId: route.tmdbId, mediaType: route.mediaType)
            dedupedCommunityRatings = CommunityRatingSummary.dedupe(from: response.items)
        } catch {
            print("[Ratings] Error: \(error)")
            dedupedCommunityRatings = []
        }
    }

    func loadMyRatings() async {
        guard Config.isAPIKeyConfigured else { myRatings = []; return }
        do {
            let response = try await api.fetchRatings(tmdbId: route.tmdbId, mediaType: route.mediaType)
            // Show ratings where API confirms ownership OR we submitted them this session
            let settingsName = SettingsStore.shared.contributorName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            myRatings = response.items.filter { rating in
                rating.isOwner == true || 
                sessionSubmittedRatingIds.contains(rating.id) ||
                (!settingsName.isEmpty && (
                    rating.userId?.lowercased() == settingsName || 
                    rating.username?.lowercased() == settingsName ||
                    rating.contributor?.lowercased() == settingsName
                ))
            }
        } catch {
            myRatings = []
        }
    }

    func deleteMyRating(id: String) async {
        sessionSubmittedRatingIds.remove(id)
        myRatings.removeAll { $0.id == id }
        do {
            try await api.deleteRating(id: id)
            await loadCommunityRatings()
        } catch {
            await loadMyRatings()
        }
    }

    // MARK: - Anime Season Mappings

    func loadSeasonMappings() async {
        await MainActor.run { isLoadingSeasonMappings = true }
        defer { Task { @MainActor in isLoadingSeasonMappings = false } }
        do {
            let response = try await api.fetchAnimeSeasons(tmdbId: route.tmdbId)
            var mappings = response.all
            
            // Fetch votes for each mapping
            mappings = await withTaskGroup(of: (Int, (Int, Int)).self) { group in
                for (index, mapping) in mappings.enumerated() {
                    let actualId = mapping.serverId ?? mapping.chunks.first?.id
                    if let id = actualId {
                        group.addTask {
                            let votes = (try? await self.api.fetchAnimeSeasonVotes(itemId: id)) ?? (0, 0)
                            return (index, votes)
                        }
                    }
                }
                
                var updatedMappings = mappings
                for await (index, votes) in group {
                    updatedMappings[index].voteCount = votes.0
                    updatedMappings[index].userVote = votes.1
                }
                return updatedMappings
            }
            
            let finalMappings = mappings
            await MainActor.run { seasonMappings = finalMappings }
        } catch {
            print("[SeasonMappings] Failed to load: \(error)")
        }
    }

    func submitSeasonMapping(
        seasonNumber: Int,
        seasonName: String?,
        chunks: [AnimeSeasonChunkInput]
    ) async {
        guard Config.isAPIKeyConfigured else { return }
        await MainActor.run {
            seasonMappingSubmitError = nil
            seasonMappingSubmitSuccess = false
        }
        do {
            let request = SubmitAnimeSeasonRequest(
                tmdbId: route.tmdbId,
                seasonNumber: seasonNumber,
                seasonName: seasonName.flatMap { $0.isEmpty ? nil : $0 },
                chunks: chunks
            )
            _ = try await api.submitAnimeSeason(request)
            await loadSeasonMappings()
            await MainActor.run { seasonMappingSubmitSuccess = true }
        } catch {
            await MainActor.run {
                seasonMappingSubmitError = "Failed to submit: \(error.localizedDescription)"
            }
        }
    }

    func deleteAnimeSeasonMapping(tmdbId: Int, seasonNumber: Int) async {
        guard Config.isAPIKeyConfigured else { return }
        do {
            try await api.deleteAnimeSeasonMapping(tmdbId: tmdbId, seasonNumber: seasonNumber)
            await loadSeasonMappings()
        } catch {
            print("[SeasonMappings] Failed to delete: \(error)")
        }
    }

    func voteOnSeasonMapping(mapping: AnimeSeasonMapping, vote: VoteValue) async {
        let actualId = mapping.serverId ?? mapping.chunks.first?.id
        guard Config.isAPIKeyConfigured, let serverVoteId = actualId else { return }
        
        let oldVote = mapping.userVote
        let oldVoteCount = mapping.voteCount ?? 0
        
        // Optimistic update
        await MainActor.run {
            if let index = seasonMappings.firstIndex(where: { $0.id == mapping.id }) {
                var updated = seasonMappings[index]
                
                let newVoteInt: Int
                switch vote {
                case .up: newVoteInt = 1
                case .down: newVoteInt = -1
                case .remove: newVoteInt = 0
                }
                
                let voteDiff = newVoteInt - (oldVote ?? 0)
                updated.userVote = vote == .remove ? nil : newVoteInt
                updated.voteCount = oldVoteCount + voteDiff
                seasonMappings[index] = updated
            }
        }
        
        do {
            if vote == .remove {
                try await api.removeAnimeSeasonVote(itemId: serverVoteId)
            } else {
                _ = try await api.voteOnAnimeSeason(itemId: serverVoteId, vote: vote)
            }
        } catch {
            // Revert on failure
            await MainActor.run {
                if let index = seasonMappings.firstIndex(where: { $0.id == mapping.id }) {
                    var reverted = seasonMappings[index]
                    reverted.userVote = oldVote
                    reverted.voteCount = oldVoteCount
                    seasonMappings[index] = reverted
                }
            }
            print("[SeasonMappings] Failed to vote: \(error)")
        }
    }

    private func loadCommunityData() async {
        let mediaType = route.mediaType
        let eps = mediaType == .tv ? await MainActor.run { episodes.map { $0.episodeNumber } } : []
        let currentSeason = await MainActor.run { selectedSeason }
        let tmdbId = route.tmdbId

        Task {
            do {
                let initialMappings = try await api.fetchMappings(tmdbId: tmdbId, mediaType: mediaType).all
                
                // Fetch votes concurrently
                let finalMappings = await withTaskGroup(of: (String, (voteCount: Int, userVote: Int)?).self) { group in
                    for mapping in initialMappings {
                        group.addTask {
                            do {
                                let votes = try await self.api.fetchMappingVotes(itemId: mapping.id, all: true)
                                return (mapping.id, votes)
                            } catch {
                                print("[Mappings] Fetch mapping votes failed for \(mapping.id): \(error)")
                                return (mapping.id, nil)
                            }
                        }
                    }
                    var voteMap: [String: Int] = [:]
                    var userVoteMap: [String: Int] = [:]
                    for await (id, votes) in group {
                        if let v = votes {
                            voteMap[id] = v.voteCount
                            userVoteMap[id] = v.userVote
                        }
                    }
                    return initialMappings.map {
                        var m = $0
                        m.voteCount = voteMap[m.id] ?? m.voteCount ?? 0
                        m.userVote = userVoteMap[m.id] ?? m.userVote ?? 0
                        return m
                    }
                }
                
                await MainActor.run { self.mappings = finalMappings }
            } catch {
                await MainActor.run { self.mappings = [] }
            }
        }

        Task {
            await fetchEpisodeRatings(tmdbId: tmdbId, season: currentSeason)
        }

        Task {
            let fetchedHighlights: [Highlight]
            if mediaType == .tv {
                let initialRes = try? await self.api.fetchHighlights(tmdbId: tmdbId, mediaType: .tv, season: currentSeason)
                let initialHighlights = initialRes?.all.filter { $0.season == currentSeason } ?? []

                if initialHighlights.count < 30 {
                    fetchedHighlights = initialHighlights
                } else {
                    fetchedHighlights = await withTaskGroup(of: [Highlight].self) { group in
                        for ep in eps {
                            group.addTask {
                                let res = try? await self.api.fetchHighlights(tmdbId: tmdbId, mediaType: .tv, season: currentSeason, episode: ep)
                                return res?.all.filter { $0.season == currentSeason } ?? []
                            }
                        }
                        var results: [Highlight] = []
                        for await h in group { results.append(contentsOf: h) }
                        return results
                    }
                }
            } else {
                let res = try? await self.api.fetchHighlights(tmdbId: tmdbId, mediaType: .movie)
                fetchedHighlights = res?.all ?? []
            }

            await MainActor.run {
                self.highlights = fetchedHighlights
            }
        }

        Task {
            await loadSkipsForSeason()
        }
    }

    func reloadMappings() async {
        let tmdbId = route.tmdbId
        let mediaType = route.mediaType
        do {
            let initialMappings = try await api.fetchMappings(tmdbId: tmdbId, mediaType: mediaType).all
            
            // Fetch votes concurrently
            let finalMappings = await withTaskGroup(of: (String, (voteCount: Int, userVote: Int)?).self) { group in
                for mapping in initialMappings {
                    group.addTask {
                        do {
                            let votes = try await self.api.fetchMappingVotes(itemId: mapping.id, all: true)
                            return (mapping.id, votes)
                        } catch {
                            print("[Mappings] Fetch mapping votes failed for \(mapping.id): \(error)")
                            return (mapping.id, nil)
                        }
                    }
                }
                var voteMap: [String: Int] = [:]
                var userVoteMap: [String: Int] = [:]
                for await (id, votes) in group {
                    if let v = votes {
                        voteMap[id] = v.voteCount
                        userVoteMap[id] = v.userVote
                    }
                }
                return initialMappings.map {
                    var m = $0
                    m.voteCount = voteMap[m.id] ?? m.voteCount ?? 0
                    m.userVote = userVoteMap[m.id] ?? m.userVote ?? 0
                    return m
                }
            }
            
            await MainActor.run { self.mappings = finalMappings }
        } catch {
            // silently ignore reload errors
        }
    }
    
    func deleteMapping(id: String) async {
        guard Config.isAPIKeyConfigured else { return }
        do {
            try await api.deleteMapping(id: id)
            await reloadMappings()
        } catch {
            print("[Mappings] Failed to delete mapping: \(error)")
        }
    }


    func startEditingMapping(_ mapping: ExternalMapping) {
        self.selectedExternalIDType = mapping.idType
        self.editingMappingId = mapping.id
    }

    func submitExternalID(idType: ExternalIDType, idValue: String) async {
        guard Config.isAPIKeyConfigured else { return }
        await MainActor.run { externalIDSubmitError = nil; externalIDSubmitSuccess = false }
        do {
            let userId = UserDefaults.standard.string(forKey: "publicmetadb.user.id") ?? ""
            let contributor = SettingsStore.shared.contributorName
            let request = PocketBaseMappingRequest(
                tmdb_id: route.tmdbId,
                media_type: route.mediaType.rawValue,
                id_type: idType.rawValue,
                id_value: idValue,
                user: userId,
                contributor: contributor,
                votes: PocketBaseMappingRequest.VotesDict(up: [], down: []),
                userVote: 0
            )
            _ = try await api.createMappingDirect(request)
            await reloadMappings()
            await MainActor.run {
                externalIDSubmitSuccess = true
                selectedExternalIDType = .imdb
                editingMappingId = nil
            }
        } catch {
            await MainActor.run { externalIDSubmitError = "Failed to submit: \(error.localizedDescription)" }
        }
    }
    
    func updateExternalID(id: String, idType: ExternalIDType, idValue: String) async {
        guard Config.isAPIKeyConfigured else { return }
        await MainActor.run { externalIDSubmitError = nil; externalIDSubmitSuccess = false }
        do {
            _ = try await api.updateMappingDirect(id: id, idType: idType.rawValue, idValue: idValue)
            await reloadMappings()
            await MainActor.run {
                externalIDSubmitSuccess = true
                selectedExternalIDType = .imdb
                editingMappingId = nil
            }
        } catch {
            await MainActor.run { externalIDSubmitError = "Failed to update: \(error.localizedDescription)" }
        }
    }

    private func fetchEpisodeRatings(tmdbId: Int, season: Int) async {
        guard route.mediaType == .tv, Config.isAPIKeyConfigured else {
            episodeRatingSummaries = [:]
            return
        }
        
        do {
            let data = try await api.batchGetEpisodeRatingsData(tmdbId: tmdbId, mediaType: .tv, season: season)
            
            if let str = String(data: data, encoding: .utf8) {
                print("[EpisodeRatings DEBUG] raw batch data: \(str.prefix(1000))")
            }
            
            
            var summaries: [Int: EpisodeRatingSummary] = [:]
            var rawRatings: [Int: [LocalEpisodeRating]] = [:]
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                var itemsToProcess: [(String, [String: Any])] = []
                
                if let episodesDict = json["episodes"] as? [String: Any] {
                    for (k, v) in episodesDict {
                        if let dict = v as? [String: Any] {
                            itemsToProcess.append((k, dict))
                        }
                    }
                } else if let episodesArray = json["episodes"] as? [[String: Any]] {
                    for dict in episodesArray {
                        if let epNum = dict["episode"] as? Int {
                            itemsToProcess.append(("\(epNum)", dict))
                        } else if let epStr = dict["episode"] as? String {
                            itemsToProcess.append((epStr, dict))
                        }
                    }
                }
                
                for (epStr, entry) in itemsToProcess {
                    guard let ep = Int(epStr) else { continue }
                    
                    let rawTotal: Int? = (entry["total"] as? Int) ?? (entry["count"] as? Int) ?? (entry["total"] as? NSNumber)?.intValue ?? Int("\(entry["total"] ?? "")")
                    
                    if let ratingsList = entry["ratings"] as? [[String: Any]] {
                        
                        var episodeScores: [Int] = []
                        
                        let parsedRatings = ratingsList.compactMap { r -> LocalEpisodeRating? in
                            let scoreRaw = r["score"]
                            guard let score = (scoreRaw as? Int) ?? (scoreRaw as? NSNumber)?.intValue ?? Int("\(scoreRaw ?? "")") else { return nil }
                            
                            episodeScores.append(score)
                            
                            let rId = (r["id"] as? String) ?? UUID().uuidString
                            let label = r["label"] as? String
                            let uId = r["user"] as? String
                            let username = (r["username"] as? String) ?? (r["contributor"] as? String)
                            let contributor = (r["contributor"] as? String) ?? ""
                            let avatar = r["avatar"] as? String
                            let created = (r["created_at"] as? String) ?? (r["created"] as? String)
                            
                            let voteCountRaw = r["vote_count"]
                            let voteCount = (voteCountRaw as? Int) ?? (voteCountRaw as? NSNumber)?.intValue ?? 0
                            
                            let cleanContributor = contributor.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            let cleanSettings = SettingsStore.shared.contributorName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            let isMatch = (cleanContributor == cleanSettings && !cleanSettings.isEmpty)
                            
                            var avatarUrl: URL? = nil
                            if let uId = uId, let avatar = avatar, !avatar.isEmpty {
                                avatarUrl = URL(string: "https://api.publicmetadb.com/api/files/users/\(uId)/\(avatar)")
                            }
                            
                            return LocalEpisodeRating(
                                id: rId,
                                score: score,
                                label: label,
                                userId: uId,
                                username: username,
                                voteCount: voteCount,
                                userVote: 0,
                                isOwner: isMatch,
                                avatarUrl: avatarUrl,
                                createdAt: created
                            )
                        }
                        
                        rawRatings[ep] = parsedRatings
                        
                        if !episodeScores.isEmpty {
                            let computedAvg = Double(episodeScores.reduce(0, +)) / Double(episodeScores.count)
                            let total = rawTotal ?? episodeScores.count
                            summaries[ep] = EpisodeRatingSummary(average: computedAvg, total: total)
                        } else if let avgRaw = entry["average"], let total = rawTotal {
                            // Fallback if ratings are empty but backend provides average
                            let avg: Double? = (avgRaw as? Double) ?? (avgRaw as? NSNumber)?.doubleValue ?? Double("\(avgRaw)")
                            if let avg = avg {
                                summaries[ep] = EpisodeRatingSummary(average: avg, total: total)
                            }
                        }
                    }
                }
            }
            
            print("[EpisodeRatings DEBUG] Finished parsing. Summaries count: \(summaries.count), Raw count: \(rawRatings.count)")
            
            DispatchQueue.main.async {
                self.episodeRatingSummaries = summaries
                self.seasonEpisodeRatings = rawRatings
            }
        } catch {
            print("[EpisodeRatings DEBUG] Error fetching batch ratings: \(error)")
            DispatchQueue.main.async {
                self.episodeRatingSummaries = [:]
                self.seasonEpisodeRatings = [:]
            }
        }
    }

    func submitCommunityRating(score: Int, label: String?) async {
        await MainActor.run { communityRatingSubmitError = nil }
        let request = CreateRatingRequest(
            tmdbId: route.tmdbId,
            mediaType: route.mediaType,
            score: score,
            label: label
        )
        do {
            let normalizedNew = (label ?? "overall").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let existingRating = myRatings.first {
                ($0.label ?? "overall").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedNew
            }
            
            let response: APIActionResponse
            if let existingId = existingRating?.id {
                try? await api.deleteRating(id: existingId)
                response = try await api.createRating(request)
            } else {
                response = try await api.createRating(request)
            }
            
            // Immediately add to myRatings so the section appears without waiting for reload
            let tempRating = Rating(
                id: response.id ?? existingRating?.id ?? UUID().uuidString,
                tmdbId: route.tmdbId,
                mediaType: route.mediaType,
                score: score,
                label: label,
                createdAt: existingRating?.createdAt ?? ISO8601DateFormatter().string(from: Date()),
                isOwner: true,
                userId: existingRating?.userId,
                username: existingRating?.username,
                contributor: existingRating?.contributor
            )
            await MainActor.run {
                sessionSubmittedRatingIds.insert(tempRating.id)
                // Replace existing entry for same label, or append
                myRatings.removeAll {
                    ($0.label ?? "overall").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedNew
                }
                myRatings.append(tempRating)
            }
            // Reload community grid so vote count and average update
            await loadCommunityRatings()
            // Sync myRatings from server (picks up real ID if API returned it)
            await loadMyRatings()
            await MainActor.run {
                communityRatingSubmitSuccess = true
            }
        } catch {
            await MainActor.run {
                communityRatingSubmitError = error.localizedDescription
            }
        }
    }

    func submitEpisodeRating(episode: Int, score: Int, label: String?) async {
        guard Config.isAPIKeyConfigured else { return }
        
        do {
            _ = try await api.createEpisodeRating(CreateEpisodeRatingRequest(
                tmdbId: route.tmdbId,
                mediaType: .tv,
                season: selectedSeason,
                episode: episode,
                score: score,
                label: label?.isEmpty == false ? label : nil
            ))
            
            await fetchEpisodeRatings(tmdbId: route.tmdbId, season: selectedSeason)
            await MainActor.run { actionMessage = "Rating submitted successfully" }
        } catch {
            await MainActor.run { errorMessage = "Failed to submit rating: \(error.localizedDescription)" }
        }
    }
    
    func voteOnEpisodeRating(ratingId: String, vote: VoteValue) async {
        guard Config.isAPIKeyConfigured else { return }
        
        // Optimistically update local state so the UI reflects the change immediately
        await MainActor.run {
            var updated = false
            for (ep, ratings) in seasonEpisodeRatings {
                if let idx = ratings.firstIndex(where: { $0.id == ratingId }) {
                    var rating = ratings[idx]
                    
                    let oldVote = rating.userVote
                    var newCount = rating.voteCount
                    
                    // Remove old vote impact
                    if oldVote == 1 { newCount -= 1 }
                    else if oldVote == -1 { newCount += 1 }
                    
                    // Add new vote impact
                    let newVoteInt: Int
                    switch vote {
                    case .up: newVoteInt = 1; newCount += 1
                    case .down: newVoteInt = -1; newCount -= 1
                    case .remove: newVoteInt = 0
                    }
                    
                    rating.userVote = newVoteInt
                    rating.voteCount = newCount
                    
                    var newRatings = ratings
                    newRatings[idx] = rating
                    seasonEpisodeRatings[ep] = newRatings
                    updated = true
                    break
                }
            }
            if updated {
                objectWillChange.send()
            }
        }
        
        do {
            _ = try await api.voteOnEpisodeRating(itemId: ratingId, vote: vote)
            // We don't refetch here because the endpoint doesn't return updated vote counts!
        } catch {
            print("[Ratings] Failed to vote: \(error)")
        }
    }
    
    func deleteEpisodeRating(ratingId: String) async {
        guard Config.isAPIKeyConfigured else { return }
        do {
            try await api.deleteEpisodeRating(id: ratingId)
            await fetchEpisodeRatings(tmdbId: route.tmdbId, season: selectedSeason)
        } catch {
            print("[Ratings] Failed to delete: \(error)")
        }
    }

    @MainActor
    private func loadSkipsForSeason() async {
        if route.mediaType == .tv {
            let eps = episodes.map { $0.episodeNumber }
            let currentSeason = selectedSeason
            let tmdbId = route.tmdbId
            
            let initialRes = try? await self.api.fetchSkips(tmdbId: tmdbId, mediaType: .tv, season: currentSeason)
            let initialSkips = initialRes?.allSkips.filter { $0.season == currentSeason } ?? []
            
            if initialSkips.count < 30 {
                self.skips = initialSkips
                return
            }
            
            let fetchedSkips = await withTaskGroup(of: [SkipTimestamp].self) { group in
                for ep in eps {
                    group.addTask {
                        let res = try? await self.api.fetchSkips(tmdbId: tmdbId, mediaType: .tv, season: currentSeason, episode: ep)
                        return res?.allSkips.filter { $0.season == currentSeason } ?? []
                    }
                }
                var results: [SkipTimestamp] = []
                for await s in group { results.append(contentsOf: s) }
                return results
            }
            self.skips = fetchedSkips
        } else {
            do {
                let response = try await api.fetchSkips(
                    tmdbId: route.tmdbId,
                    mediaType: route.mediaType,
                    season: nil
                )
                self.skips = response.allSkips
            } catch {
                self.skips = []
            }
        }
    }

    /// Called when opening the SkipSubmissionSheet — loads all submissions and the user's own.
    func loadSkipsForSheet(episodeNumber: Int?) async {
        let cleanSettings = SettingsStore.shared.contributorName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Use already-loaded skips (pre-fetched with the page), filtered for this episode
        let cached = skips.filter { s in
            if let ep = episodeNumber { return s.episode == ep }
            return true  // movies: no episode filter
        }

        // Build preliminary from cache — no network call, instant display
        let preliminary = cached.map { skip -> SkipTimestamp in
            var s = skip
            let cleanContributor = skip.contributor?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            s.isOwner = (cleanContributor == cleanSettings && !cleanSettings.isEmpty)
            return s
        }

        await MainActor.run {
            episodeSkips = preliminary
            myEpisodeSkip = preliminary.first(where: { $0.isOwner })
            isLoadingSkipSheet = false
        }

        // Fetch votes for all skips in parallel in the background
        let enriched: [SkipTimestamp] = await withTaskGroup(of: SkipTimestamp.self) { group in
            for skip in preliminary {
                group.addTask {
                    var s = skip
                    if let votes = try? await self.api.fetchSkipVotes(itemId: skip.id, all: true) {
                        s.voteCount = votes.votes?.reduce(0, { $0 + ($1.vote == .up ? 1 : $1.vote == .down ? -1 : 0) }) ?? 0
                        s.userVote = votes.vote.map { $0.vote == .up ? 1 : $0.vote == .down ? -1 : 0 } ?? 0
                    }
                    return s
                }
            }
            var results: [SkipTimestamp] = []
            for await result in group { results.append(result) }
            return results.sorted { a, b in
                (preliminary.firstIndex(where: { $0.id == a.id }) ?? 0) <
                (preliminary.firstIndex(where: { $0.id == b.id }) ?? 0)
            }
        }

        await MainActor.run {
            episodeSkips = enriched
            myEpisodeSkip = enriched.first(where: { $0.isOwner })
        }
    }

    func submitSkip(episodeNumber: Int?, introStartMs: Int?, introEndMs: Int?, creditsStartMs: Int?, creditsEndMs: Int?, source: SkipSource) async {
        guard Config.isAPIKeyConfigured else { return }
        await MainActor.run { skipSubmitError = nil; skipSubmitSuccess = false }
        do {
            let request = CreateSkipRequest(
                tmdbId: route.tmdbId,
                mediaType: route.mediaType,
                season: route.mediaType == .tv ? selectedSeason : nil,
                episode: episodeNumber,
                source: source,
                introStartMs: introStartMs == 0 ? 1 : introStartMs,
                introEndMs: introEndMs == 0 ? 1 : introEndMs,
                creditsStartMs: creditsStartMs == 0 ? 1 : creditsStartMs,
                creditsEndMs: creditsEndMs == 0 ? 1 : creditsEndMs
            )
            _ = try await api.createSkip(request)
            // Reload season-level skips for the progress bars
            await loadSkipsForSeason()
            await loadSkipsForSheet(episodeNumber: episodeNumber)
            await MainActor.run { skipSubmitSuccess = true }
        } catch {
            await MainActor.run { skipSubmitError = "Failed to submit: \(error.localizedDescription)" }
        }
    }

    func deleteSkip(id: String, episodeNumber: Int?) async {
        guard Config.isAPIKeyConfigured else { return }
        do {
            try await api.deleteSkip(id: id)
            await loadSkipsForSeason()
            await loadSkipsForSheet(episodeNumber: episodeNumber)
        } catch {
            print("[Skips] Failed to delete: \(error)")
        }
    }

    func voteOnSkip(skipId: String, vote: VoteValue) async {
        guard Config.isAPIKeyConfigured else { return }
        // Optimistic update
        await MainActor.run {
            if let idx = episodeSkips.firstIndex(where: { $0.id == skipId }) {
                var s = episodeSkips[idx]
                let oldVote = s.userVote
                var count = s.voteCount
                if oldVote == 1 { count -= 1 } else if oldVote == -1 { count += 1 }
                switch vote {
                case .up: s.userVote = 1; count += 1
                case .down: s.userVote = -1; count -= 1
                case .remove: s.userVote = 0
                }
                s.voteCount = count
                episodeSkips[idx] = s
                objectWillChange.send()
            }
        }
        do {
            _ = try await api.voteOnSkip(itemId: skipId, vote: vote)
        } catch {
            print("[Skips] Failed to vote: \(error)")
        }
    }

    private func loadWatchedState() async {
        do {
            var allItems: [WatchEntry] = []
            // Fetch first page
            let firstResponse = try await api.fetchWatchHistory(page: 1, perPage: 500, tmdbId: route.tmdbId, mediaType: route.mediaType)
            allItems.append(contentsOf: firstResponse.items)
            let totalPages = firstResponse.pages ?? 1
            
            // Fetch remaining pages concurrently
            if totalPages > 1 {
                let extraItems = try await withThrowingTaskGroup(of: [WatchEntry].self) { group in
                    for page in 2...totalPages {
                        group.addTask {
                            let response = try await self.api.fetchWatchHistory(
                                page: page, perPage: 500, tmdbId: self.route.tmdbId, mediaType: self.route.mediaType
                            )
                            return response.items
                        }
                    }
                    var collected: [WatchEntry] = []
                    for try await items in group {
                        collected.append(contentsOf: items)
                    }
                    return collected
                }
                allItems.append(contentsOf: extraItems)
            }
            
            let fetchedItems = allItems.filter { $0.tmdbId == route.tmdbId }
            let isWatched = fetchedItems.contains { entry in
                entry.mediaType == route.mediaType
            }
            
            await MainActor.run {
                // Only update if we got actual results; don't wipe optimistic updates
                // if the server returns nothing for this tmdbId
                if !fetchedItems.isEmpty {
                    watchHistoryItems = fetchedItems
                    if route.mediaType == .movie {
                        if isWatched {
                            watchedEpisodeKeys = ["movie"]
                        } else {
                            watchedEpisodeKeys = []
                        }
                    }
                }
                // If fetchedItems is empty but we have locally-added items, keep them
            }
        } catch {
            print("[Watched] Failed to fetch watch history: \(error)")
            // Don't clear on error — preserve any optimistic local state
        }
    }


    private func loadLists() async {
        do {
            let response = try await api.fetchLists(perPage: 50)
            let lists = response.items
            userLists = lists
            
            let targetId = route.tmdbId
            var foundItems: [String: String] = [:]
            var allListItems: [String: [ListItem]] = [:]
            
            await withTaskGroup(of: (String, [ListItem]?).self) { group in
                for list in lists {
                    group.addTask {
                        do {
                            let itemsResponse = try await self.api.fetchListItems(listId: list.id, page: 1, perPage: 1000)
                            return (list.id, itemsResponse.items)
                        } catch {}
                        return (list.id, nil)
                    }
                }
                
                for await (listId, items) in group {
                    if let items = items {
                        allListItems[listId] = items
                        if let targetItem = items.first(where: { $0.tmdbId == targetId }) {
                            foundItems[listId] = targetItem.id
                        }
                    }
                }
            }
            
            if let context = localContext {
                let cache = CacheRepository(context: context)
                for (listId, items) in allListItems {
                    try? cache.replaceListItems(listId: listId, items: items)
                }
            }
            
            containedListItems = foundItems
            isInList = !foundItems.isEmpty
        } catch {
            userLists = []
        }
    }

    private func loadResumePoint() async {
        guard Config.isAPIKeyConfigured else { return }
        do {
            let query = ResumeQuery(tmdbId: route.tmdbId, mediaType: route.mediaType, perPage: 1)
            let response = try await api.fetchResumePoints(query: query)
            self.resumePoint = response.items.first
        } catch {
            self.resumePoint = nil
        }
    }
    // MARK: - Highlights Actions
    
    func loadHighlightsForSheet(episodeNumber: Int?) async {
        await MainActor.run {
            highlightSubmitError = nil
            highlightSubmitSuccess = false
        }
        
        let cleanSettings = SettingsStore.shared.contributorName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Use already-loaded highlights (pre-fetched with the page), filtered for this episode
        let cached = highlights.filter { h in
            if let ep = episodeNumber { return h.episode == ep }
            return true  // movies: no episode filter
        }
        
        // Build preliminary from cache — no network call, instant display
        var preliminary = cached.map { h -> Highlight in
            var h = h
            let cleanContributor = h.contributor?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            h.isOwner = (cleanContributor == cleanSettings && !cleanSettings.isEmpty)
            return h
        }
        
        // Sort immediately so the list is correct from the first frame
        preliminary = preliminary.sorted { $0.highlightStartMs < $1.highlightStartMs }
        
        await MainActor.run {
            episodeHighlights = preliminary
            myEpisodeHighlight = preliminary.first(where: { $0.isOwner == true })
            isLoadingHighlightSheet = false
        }
        
        // Enrich with votes in parallel in the background
        let enriched: [Highlight] = await withTaskGroup(of: Highlight.self) { group in
            for h in preliminary {
                group.addTask {
                    var highlight = h
                    if let votes = try? await self.api.fetchHighlightVotes(itemId: h.id, all: true) {
                        highlight.voteCount = votes.votes?.reduce(0) { $0 + ($1.vote == .up ? 1 : $1.vote == .down ? -1 : 0) } ?? 0
                        highlight.userVote = votes.vote.map { $0.vote == .up ? 1 : $0.vote == .down ? -1 : 0 } ?? 0
                    }
                    return highlight
                }
            }
            var results: [Highlight] = []
            for await r in group { results.append(r) }
            // Preserve original order
            return results.sorted { a, b in
                (preliminary.firstIndex(where: { $0.id == a.id }) ?? 0) <
                (preliminary.firstIndex(where: { $0.id == b.id }) ?? 0)
            }
        }
        
        await MainActor.run {
            episodeHighlights = enriched
            myEpisodeHighlight = enriched.first(where: { $0.isOwner == true })
        }
    }
    
    func submitHighlight(episodeNumber: Int?, startMs: Int, endMs: Int, description: String?) async {
        guard Config.isAPIKeyConfigured else { return }
        await MainActor.run { highlightSubmitError = nil; highlightSubmitSuccess = false }
        do {
            let safeStart = startMs == 0 ? 1 : startMs
            let safeEnd = endMs == 0 ? safeStart : endMs
            
            let request = CreateHighlightRequest(
                tmdbId: route.tmdbId,
                mediaType: route.mediaType,
                season: route.mediaType == .tv ? selectedSeason : nil,
                episode: episodeNumber,
                highlightStartMs: safeStart,
                highlightEndMs: safeEnd,
                description: description?.isEmpty == false ? description : nil
            )
            _ = try await api.createHighlight(request)
            
            // Reload just this episode's highlights to avoid pulling the whole season
            let reloaded = try await api.fetchHighlights(tmdbId: route.tmdbId, mediaType: route.mediaType, season: route.mediaType == .tv ? selectedSeason : nil, episode: episodeNumber)
            let filtered = reloaded.all.filter { $0.season == selectedSeason }
            await MainActor.run {
                highlights.removeAll(where: { $0.episode == episodeNumber })
                highlights.append(contentsOf: filtered)
            }
            await loadHighlightsForSheet(episodeNumber: episodeNumber)
            await MainActor.run { highlightSubmitSuccess = true }
        } catch {
            await MainActor.run { highlightSubmitError = "Failed to submit: \(error.localizedDescription)" }
        }
    }
    
    func voteOnMapping(mappingId: String, vote: VoteValue) async {
        guard Config.isAPIKeyConfigured else { return }
        do {
            if vote == .remove {
                try await api.removeMappingVote(itemId: mappingId)
            } else {
                _ = try await api.voteOnMapping(itemId: mappingId, vote: vote)
            }
            // Optimistically update the UI since fetching votes manually might not be supported
            await MainActor.run {
                if let idx = mappings.firstIndex(where: { $0.id == mappingId }) {
                    let oldUserVote = mappings[idx].userVote ?? 0
                    let currentCount = mappings[idx].voteCount ?? 0
                    
                    // Revert old vote
                    var newCount = currentCount - oldUserVote
                    
                    // Apply new vote
                    let newVoteValue = (vote == .up) ? 1 : (vote == .down) ? -1 : 0
                    newCount += newVoteValue
                    
                    mappings[idx].userVote = newVoteValue
                    mappings[idx].voteCount = newCount
                }
            }
        } catch {
            print("[Mappings] Failed to vote: \(error)")
        }
    }
    
    func updateHighlight(id: String, episodeNumber: Int?, startMs: Int, endMs: Int, description: String?) async {
        guard Config.isAPIKeyConfigured else { return }
        await MainActor.run { highlightSubmitError = nil; highlightSubmitSuccess = false }
        do {
            let safeStart = startMs == 0 ? 1 : startMs
            let safeEnd = endMs == 0 ? safeStart : endMs
            
            let request = CreateHighlightRequest(
                tmdbId: route.tmdbId,
                mediaType: route.mediaType,
                season: route.mediaType == .tv ? selectedSeason : nil,
                episode: episodeNumber,
                highlightStartMs: safeStart,
                highlightEndMs: safeEnd,
                description: description?.isEmpty == false ? description : nil
            )
            // Server has no update endpoint — delete old and recreate
            try? await api.deleteHighlight(id: id)
            _ = try await api.createHighlight(request)
            
            // Reload just this episode's highlights to avoid pulling the whole season
            let reloaded = try await api.fetchHighlights(tmdbId: route.tmdbId, mediaType: route.mediaType, season: route.mediaType == .tv ? selectedSeason : nil, episode: episodeNumber)
            let filtered = reloaded.all.filter { $0.season == selectedSeason }
            await MainActor.run {
                highlights.removeAll(where: { $0.episode == episodeNumber })
                highlights.append(contentsOf: filtered)
            }
            await loadHighlightsForSheet(episodeNumber: episodeNumber)
            await MainActor.run { highlightSubmitSuccess = true }
        } catch {
            print("[Highlights] updateHighlight error: \(error)")
            await MainActor.run { highlightSubmitError = "Failed to update: \(error.localizedDescription)" }
        }
    }
    
    func voteOnHighlight(highlightId: String, vote: VoteValue) async {
        guard Config.isAPIKeyConfigured else { return }
        // Optimistic update
        await MainActor.run {
            if let idx = episodeHighlights.firstIndex(where: { $0.id == highlightId }) {
                var h = episodeHighlights[idx]
                let oldVote = h.userVote ?? 0
                var count = h.voteCount ?? 0
                if oldVote == 1 { count -= 1 } else if oldVote == -1 { count += 1 }
                switch vote {
                case .up: h.userVote = 1; count += 1
                case .down: h.userVote = -1; count -= 1
                case .remove: h.userVote = 0
                }
                h.voteCount = count
                episodeHighlights[idx] = h
                objectWillChange.send()
            }
        }
        do {
            _ = try await api.voteOnHighlight(itemId: highlightId, vote: vote)
        } catch {
            print("[Highlights] Failed to vote: \(error)")
        }
    }
    
    func deleteHighlight(id: String, episodeNumber: Int?) async {
        guard Config.isAPIKeyConfigured else { return }
        // Optimistic removal from UI
        await MainActor.run {
            episodeHighlights.removeAll(where: { $0.id == id })
            highlights.removeAll(where: { $0.id == id })
            if myEpisodeHighlight?.id == id { myEpisodeHighlight = nil }
        }
        do {
            try await api.deleteHighlight(id: id)
            // Reload just this episode's highlights
            let reloaded = try await api.fetchHighlights(tmdbId: route.tmdbId, mediaType: route.mediaType, season: route.mediaType == .tv ? selectedSeason : nil, episode: episodeNumber)
            let filtered = reloaded.all.filter { $0.season == selectedSeason }
            await MainActor.run {
                highlights.removeAll(where: { $0.episode == episodeNumber })
                highlights.append(contentsOf: filtered)
            }
            await loadHighlightsForSheet(episodeNumber: episodeNumber)
        } catch {
            print("[Highlights] Failed to delete: \(error)")
        }
    }
    
    // MARK: - Ratings
    private func fetchRichMetadata(for items: [TMDBMediaItem]) async {
        let (newRatings, newPosters, newLogos) = await MetadataEnrichmentService.shared.fetchRichMetadata(
            for: items,
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

    private func fetchCommunityData() async {
        if Config.isAPIKeyConfigured {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadCommunityRatings() }
                group.addTask { await self.loadMyRatings() }
                group.addTask { await self.loadLists() }
                group.addTask { await self.loadResumePoint() }
                if self.route.mediaType == .tv {
                    group.addTask { await self.loadEpisodeWatchedKeys() }
                } else {
                    group.addTask { await self.loadWatchedState() }
                }
            }
        } else {
            await loadCommunityRatings()
            await loadMyRatings()
        }
    }

    func loadRating(for tmdbId: Int, mediaType: MediaType, isHero: Bool = false) async {
        if !isHero {
            guard pmdbRatings[tmdbId] == nil else { return } // Already fetched or in progress
        }
        
        do {
            let response = try await api.fetchRatings(tmdbId: tmdbId, mediaType: mediaType)
            let avg = response.average
            await MainActor.run {
                let roundedAvg = avg != nil ? Int(avg!.rounded()) : -1
                if isHero {
                    if roundedAvg != -1 {
                        self.pmdbAverageRating = roundedAvg
                    }
                } else {
                    self.pmdbRatings[tmdbId] = roundedAvg
                }
            }
        } catch {
            await MainActor.run {
                if !isHero {
                    self.pmdbRatings[tmdbId] = -1
                }
            }
        }
    }
}
