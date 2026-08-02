import Foundation
import SwiftData
import SwiftUI
import Combine

struct UpcomingEpisode: Identifiable, Equatable {
    var id: Int { showId }
    let showId: Int
    let showName: String
    let episodeLabel: String   // e.g. "S2 E5"
    let episodeName: String    // e.g. "Episode 1163"
    let airDate: Date
    let airtimeDate: Date? // Exact timestamp from TVMaze
    let backdropPath: String?
    let episodeStillPath: String?
    let networkName: String? // e.g. "KRY" or "Netflix"
    let absoluteEpisodeNumber: Int?
    var countdownLabel: String // e.g. "IN 2D", "TOMORROW", "IN 45M"
    var logoPath: String?
    var textlessBackdropPath: String?
    
    var logoURL: URL? {
        logoPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") }
    }
    var cleanBackdropURL: URL? {
        textlessBackdropPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") }
    }
    
    var backdropURL: URL? {
        if let still = episodeStillPath, !still.isEmpty {
            return URL(string: "https://image.tmdb.org/t/p/w500\(still)")
        }
        if let p = backdropPath, !p.isEmpty {
            return URL(string: "https://image.tmdb.org/t/p/w780\(p)")
        }
        return nil
    }
    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEE • d MMM"
        return f.string(from: airDate)
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var resumePoints: [ResumePoint] = []
    @Published var continueWatching: [ContinueWatchingItem] = []
    @Published var watchHistory: [WatchEntry] = []
    @Published var watchHistoryPage: Int = 1
    @Published var watchHistoryHasMore: Bool = true
    @Published var isLoadingMoreWatchHistory: Bool = false
    
    @Published var recentLists: [MediaList] = []
    @Published var recentSkips: [RecentSkip] = []
    @Published var recentRatings: [RecentRating] = []
    @Published var recentHighlights: [RecentHighlight] = []
    @Published var upcomingEpisodes: [UpcomingEpisode] = []
    @Published var upcomingLoaded: Bool = false
    @Published var heroItems: [HeroCarouselItem] = []
    
    @Published var trendingMovies: [TMDBMediaItem] = []
    @Published var trendingTVs: [TMDBMediaItem] = []
    @Published var pmdbRatings: [Int: Int] = [:]
    @Published var cleanPosters: [Int: URL] = [:]
    @Published var itemLogos: [Int: URL] = [:]
    @Published var hasLoadedData: Bool = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Per-section loading flags — each flips false the moment its data is ready
    @Published var isLoadingHero: Bool = true
    @Published var isLoadingContinueWatching: Bool = true
    @Published var isLoadingUpcoming: Bool = true
    @Published var isLoadingWatchHistory: Bool = true
    @Published var isLoadingTrending: Bool = true
    @Published var isLoadingRecentLists: Bool = true
    @Published var isLoadingRecentSkips: Bool = true
    @Published var isLoadingRecentRatings: Bool = true
    @Published var isLoadingRecentHighlights: Bool = true
    
    @Published var historyLogos: [Int: URL] = [:]
    @Published var historyCleanBackdrops: [Int: URL] = [:]

    private let api = APIService.shared
    private let enrichment = MetadataEnrichmentService.shared
    private var cache: CacheRepository?
    private var isConfigured = false
    private var cancellables = Set<AnyCancellable>()

    func configure(context: ModelContext) {
        guard !isConfigured else { return }  // only run once — tab switches must not reset data
        isConfigured = true
        cache = CacheRepository(context: context)
        loadFromCache()
        
        NotificationCenter.default.publisher(for: .watchStateDidChange)
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.refreshData(showLoadingState: false)
                }
            }
            .store(in: &cancellables)
    }

    func loadFromCache() {
        guard let cache else { return }
        do {
            resumePoints = try cache.cachedResumePoints().map { cached in
                ResumePoint(
                    id: cached.remoteId,
                    tmdbId: cached.tmdbId,
                    mediaType: MediaType(rawValue: cached.mediaType) ?? .movie,
                    season: cached.season,
                    episode: cached.episode,
                    positionMs: cached.positionMs,
                    runtimeMs: cached.runtimeMs,
                    progress: cached.progress,
                    title: cached.title,
                    posterPath: cached.posterPath,
                    backdropPath: nil,
                    createdAt: nil,
                    updatedAt: cached.updatedAtString  // real API timestamp, enables stable sort
                )
            }
            watchHistory = try cache.cachedWatchEntries().map { cached in
                WatchEntry(
                    id: cached.remoteId,
                    tmdbId: cached.tmdbId,
                    mediaType: MediaType(rawValue: cached.mediaType) ?? .movie,
                    season: cached.season,
                    episode: cached.episode,
                    watchedAt: cached.watchedAt,
                    title: cached.title,
                    posterPath: cached.posterPath,
                    backdropPath: cached.backdropPath
                )
            }
            // Don't rebuild CW from stale cache — fetchContinueWatching() will populate it fresh from /watched
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func enrichCachedIfNeeded() async {
        guard Config.isAPIKeyConfigured || !Config.tmdbAPIKey.isEmpty else { return }
        _ = continueWatching.contains {
            TMDBIDResolver.needsMetadata(title: $0.title, posterPath: $0.posterPath, backdropPath: $0.backdropPath, tmdbId: $0.tmdbId)
        }
        let needsHistory = watchHistory.contains {
            TMDBIDResolver.needsMetadata(title: $0.title, posterPath: $0.posterPath, backdropPath: $0.backdropPath, tmdbId: $0.tmdbId)
        }
        guard needsHistory else { return }

        async let enrichedHistory = enrichment.enrichWatchEntries(watchHistory)
        let historyEnriched = await enrichedHistory
        watchHistory = historyEnriched
        if let cache {
            try? cache.replaceWatchHistory(historyEnriched)
        }
    }

    func refreshData(showLoadingState: Bool = true) async {
        guard Config.isAPIKeyConfigured else {
            errorMessage = "Please log in to get started"
            return
        }
        if showLoadingState {
            isLoading = true
            isLoadingHero = true
            isLoadingContinueWatching = true
            isLoadingUpcoming = true
            isLoadingWatchHistory = true
            isLoadingTrending = true
            isLoadingRecentLists = true
            isLoadingRecentSkips = true
            isLoadingRecentRatings = true
            isLoadingRecentHighlights = true
            errorMessage = nil
        }
        defer { if showLoadingState { isLoading = false } }

        do {
            // ── Phase 1: fire all independent API calls at once ──────────────
            async let watched        = api.fetchWatchHistory(perPage: 999999)
            async let recentUpdatesReq = api.fetchRecentUpdates()
            async let discoverListsReq = api.fetchDiscoverLists(page: 1, perPage: 3)
            // Fetch the full watched list (500 items) needed by CW + Upcoming
            let pmdbToken = Config.apiKey
            async let watchedFullData: Data? = {
                guard !pmdbToken.isEmpty else { return nil }
                return await self.fetchAllWatchedHistory(pmdbToken: pmdbToken)
            }()
            // Fetch resume points at the same time
            async let resumeData: Data? = {
                guard !pmdbToken.isEmpty,
                      let url = URL(string: "https://publicmetadb.com/api/external/resume?perPage=50") else { return nil }
                var req = URLRequest(url: url)
                req.setValue("Bearer \(pmdbToken)", forHTTPHeaderField: "Authorization")
                return try? await URLSession.shared.data(for: req).0
            }()

            let (watchedData, updatesData, discoverListsData, sharedWatchedRaw, sharedResumeRaw) =
                try await (watched, recentUpdatesReq, discoverListsReq, watchedFullData, resumeData)

            // ── Phase 2: UI-visible data first ───────────────────────────────
            var allWatchEntries: [WatchEntry] = watchedData.items
            if let raw = sharedWatchedRaw,
               let json = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] {
                let items = (json["items"] as? [[String: Any]]) ?? (json["data"] as? [[String: Any]]) ?? []
                if let data = try? JSONSerialization.data(withJSONObject: items),
                   let decoded = try? JSONDecoder().decode([WatchEntry].self, from: data) {
                    allWatchEntries = decoded
                }
            }
            
            var enrichedWatched = await enrichment.enrichWatchEntries(allWatchEntries)

            var enrichedLists = discoverListsData.items
            for i in 0..<enrichedLists.count {
                enrichedLists[i].previewItems = await enrichment.enrichListItems(enrichedLists[i].previewItems)
                enrichedLists[i].previewPosters = enrichedLists[i].previewItems.compactMap { $0.posterURL }
            }

            let tmdbKey = Config.tmdbAPIKey
            if !tmdbKey.isEmpty {
                await withTaskGroup(of: (Int, String?, String?, String?).self) { group in
                    for i in 0..<min(enrichedWatched.count, 100) {
                        let entry = enrichedWatched[i]
                        group.addTask {
                            var epName: String?
                            var epStill: String?
                            var backdrop: String?
                            if entry.mediaType == .tv,
                               let season = entry.season,
                               let episode = entry.episode {
                                let urlStr = "https://api.themoviedb.org/3/tv/\(entry.tmdbId)/season/\(season)/episode/\(episode)?api_key=\(tmdbKey)"
                                if let url = URL(string: urlStr),
                                   let (data, _) = try? await URLSession.shared.data(from: url) {
                                    struct EpDetail: Codable { let name: String?; let still_path: String? }
                                    if let ep = try? JSONDecoder().decode(EpDetail.self, from: data) {
                                        epName = ep.name; epStill = ep.still_path
                                    }
                                }
                            } else if entry.mediaType == .movie {
                                let urlStr = "https://api.themoviedb.org/3/movie/\(entry.tmdbId)?api_key=\(tmdbKey)"
                                if let url = URL(string: urlStr),
                                   let (data, _) = try? await URLSession.shared.data(from: url) {
                                    struct MovieDetail: Codable { let backdrop_path: String? }
                                    if let movie = try? JSONDecoder().decode(MovieDetail.self, from: data) {
                                        backdrop = movie.backdrop_path
                                    }
                                }
                            }
                            return (i, epName, epStill, backdrop)
                        }
                    }
                    for await (index, epName, epStill, backdrop) in group {
                        if let n = epName { enrichedWatched[index].episodeName = n }
                        if let s = epStill { enrichedWatched[index].episodeStillPath = s }
                        if let b = backdrop { enrichedWatched[index].backdropPath = b }
                    }
                }
            }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.watchHistory = enrichedWatched
                    self.watchHistoryPage = watchedData.page ?? 1
                    self.watchHistoryHasMore = (watchedData.page ?? 1) < (watchedData.pages ?? 1)
                    self.isLoadingWatchHistory = false
                    
                    self.recentSkips      = Array(updatesData.skips.prefix(8))
                    self.isLoadingRecentSkips = false
                    
                    self.recentRatings    = Array(updatesData.ratings.prefix(8))
                    self.isLoadingRecentRatings = false
                    
                    self.recentHighlights = Array(updatesData.highlights.prefix(8))
                    self.isLoadingRecentHighlights = false
            
            Task { await self.enrichHistoryImages(entries: enrichedWatched) }
                    self.recentLists      = Array(enrichedLists.prefix(3))
                    self.isLoadingRecentLists = false
                }
            }

            if let cache { try cache.replaceWatchHistory(enrichedWatched) }

            // ── Phase 3: CW + Upcoming + Hero all in parallel ────────────────
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.fetchContinueWatching(watchedRaw: sharedWatchedRaw, resumeRaw: sharedResumeRaw) }
                group.addTask { await self.fetchUpcoming(watchedRaw: sharedWatchedRaw) }
                group.addTask { await self.fetchHeroWatchlist(watchedRaw: sharedWatchedRaw) }
                group.addTask { 
                    await TrendingManager.shared.fetchTrendingIfNeeded()
                    let movies = await TrendingManager.shared.trendingMovies
                    let tvs = await TrendingManager.shared.trendingTVs
                    
                    let (newRatings, newPosters, newLogos) = await MetadataEnrichmentService.shared.fetchRichMetadata(
                        for: movies + tvs,
                        pmdbRatings: [:],
                        cleanPosters: [:],
                        itemLogos: [:]
                    )

                    await MainActor.run {
                        self.trendingMovies = movies
                        self.trendingTVs = tvs
                        self.isLoadingTrending = false
                        for (k, v) in newRatings { self.pmdbRatings[k] = v }
                        for (k, v) in newPosters { self.cleanPosters[k] = v }
                        for (k, v) in newLogos { self.itemLogos[k] = v }
                    }
                }
            }

            try Task.checkCancellation()

            // Pre-fetch dynamic colors for home items to hold loading view
            if UserDefaults.standard.string(forKey: "posterGlassStyle") == "dynamic" {
                let allItems = self.trendingMovies + self.trendingTVs
                let urlsToFetch = allItems.compactMap { item -> URL? in
                    return self.cleanPosters[item.tmdbId] ?? item.posterURL
                }
                await prefetchDynamicColors(for: urlsToFetch)
            }

            await MainActor.run { hasLoadedData = true }
        } catch {
            if error is CancellationError { return }
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreWatchHistory() async {
        guard watchHistoryHasMore, !isLoadingMoreWatchHistory else { return }
        await MainActor.run { isLoadingMoreWatchHistory = true }
        defer { Task { @MainActor in self.isLoadingMoreWatchHistory = false } }
        
        do {
            let nextPage = watchHistoryPage + 1
            let response = try await api.fetchWatchHistory(page: nextPage, perPage: 100)
            let enrichedWatched = await enrichment.enrichWatchEntries(response.items)
            
            // Note: In a complete implementation we might also fetch episode names/stills here
            // like in refreshData, but basic enrichment is fine for older history scrolling.
            
            await MainActor.run {
                self.watchHistory.append(contentsOf: enrichedWatched)
                self.watchHistoryPage = response.page ?? 1
                self.watchHistoryHasMore = (response.page ?? 1) < (response.pages ?? 1)
            }
        } catch {
            print("[HomeViewModel] loadMoreWatchHistory error: \(error)")
        }
    }

    func markWatched(_ entry: WatchEntry) async {
        do {
            _ = try await api.markAsWatched(MarkWatchedRequest(
                tmdbId: entry.tmdbId,
                mediaType: entry.mediaType,
                season: entry.season,
                episode: entry.episode
            ))
            try? await Task.sleep(nanoseconds: 500_000_000)
            await refreshData(showLoadingState: false)
        } catch {
            if error is CancellationError { return }
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            errorMessage = error.localizedDescription
        }
    }

    func removeFromWatched(_ entry: WatchEntry) async {
        try? await Task.sleep(nanoseconds: 500_000_000)
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.watchHistory.removeAll { $0.id == entry.id }
            }
        }
        if let cache {
            try? cache.replaceWatchHistory(watchHistory)
        }
        do {
            try await api.deleteWatchEntry(id: entry.id)
        } catch {
            if error is CancellationError { return }
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            // Re-insert on failure and surface the error
            watchHistory.insert(entry, at: 0)
            if let cache {
                try? cache.replaceWatchHistory(watchHistory)
            }
            errorMessage = error.localizedDescription
        }
    }

    func fetchContinueWatching(watchedRaw: Data? = nil, resumeRaw: Data? = nil) async {
        let pmdbToken = Config.apiKey
        let tmdbKey = Config.tmdbAPIKey
        guard !pmdbToken.isEmpty else { return }

        // ── Use pre-fetched data if provided, otherwise fetch now ──
        struct HistoryEntry: Codable {
            let id: String?
            let tmdbId: Int?
            let mediaType: String?
            let season: Int?
            let episode: Int?
            let watchedAt: String?
        }
        struct HistoryWrapper: Codable {
            let items: [HistoryEntry]?
            var all: [HistoryEntry] { items ?? [] }
        }
        struct LocalResumePoint: Decodable {
            let id: String?
            let tmdbId: Int?
            let mediaType: String?
            let season: Int?
            let episode: Int?
            let positionMs: Int?
            let runtimeMs: Int?
            let progress: Double?
            let updatedAt: String?
            enum CodingKeys: String, CodingKey {
                case id, season, episode, progress
                case tmdbId = "tmdb_id"
                case mediaType = "media_type"
                case positionMs = "position_ms"
                case runtimeMs = "runtime_ms"
                case updatedAt = "updatedAt"
                case updated_at, updated
            }
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                id        = try c.decodeIfPresent(String.self, forKey: .id)
                tmdbId    = try c.decodeIfPresent(Int.self,    forKey: .tmdbId)
                mediaType = try c.decodeIfPresent(String.self, forKey: .mediaType)
                season    = try c.decodeIfPresent(Int.self,    forKey: .season)
                episode   = try c.decodeIfPresent(Int.self,    forKey: .episode)
                positionMs = try c.decodeIfPresent(Int.self,   forKey: .positionMs)
                runtimeMs  = try c.decodeIfPresent(Int.self,   forKey: .runtimeMs)
                progress   = try c.decodeIfPresent(Double.self, forKey: .progress)
                updatedAt  = try c.decodeIfPresent(String.self, forKey: .updatedAt)
                    ?? c.decodeIfPresent(String.self, forKey: .updated_at)
                    ?? c.decodeIfPresent(String.self, forKey: .updated)
            }
        }

        // Resolve watched + resume data (use pre-fetched or fetch fresh in parallel)
        let data: Data
        let resData: Data?
        if let preWatched = watchedRaw {
            data = preWatched
            resData = resumeRaw
        } else {
            // Fetch both in parallel as fallback
            async let watchFetch: Data? = {
                return await self.fetchAllWatchedHistory(pmdbToken: pmdbToken)
            }()
            async let resumeFetch: Data? = {
                guard let url = URL(string: "https://publicmetadb.com/api/external/resume?perPage=50") else { return nil }
                var req = URLRequest(url: url); req.setValue("Bearer \(pmdbToken)", forHTTPHeaderField: "Authorization")
                return try? await URLSession.shared.data(for: req).0
            }()
            guard let wd = await watchFetch else { return }
            data = wd
            resData = await resumeFetch
        }

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        guard let wrapper = try? dec.decode(HistoryWrapper.self, from: data) else { return }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var resumeByTmdbId: [Int: LocalResumePoint] = [:]
        if let resData {
            struct ResumeWrapper: Decodable { let items: [LocalResumePoint]? }
            if let resWrapper = try? JSONDecoder().decode(ResumeWrapper.self, from: resData), let items = resWrapper.items {
                for point in items { if let tmdbId = point.tmdbId { resumeByTmdbId[tmdbId] = point } }
            }
        }

        // Combine wrapper.all and resumeByTmdbId to ensure movies are included
        var allEntries = wrapper.all
        for (tmdbId, point) in resumeByTmdbId {
            if !allEntries.contains(where: { $0.tmdbId == tmdbId }) {
                allEntries.append(HistoryEntry(
                    id: point.id,
                    tmdbId: point.tmdbId,
                    mediaType: point.mediaType,
                    season: point.season,
                    episode: point.episode,
                    watchedAt: point.updatedAt
                ))
            }
        }

        // Sort by watchedAt descending, tmdbId as stable tiebreaker using string comparison
        let sorted = allEntries.sorted { a, b in
            let da = a.watchedAt ?? ""
            let db = b.watchedAt ?? ""
            if da != db { return da > db }
            return (a.tmdbId ?? 0) > (b.tmdbId ?? 0)
        }

        // One entry per show/movie — the most recent watched
        var seen = Set<Int>()
        let deduped = sorted.filter { entry in
            guard let id = entry.tmdbId else { return false }
            return seen.insert(id).inserted
        }

        print("[CW] Unique media from history/resume: \(deduped.count)")

        let validEntries = deduped.filter { entry in
            guard let mediaType = entry.mediaType else { return false }
            if mediaType == "movie" {
                if let tmdbId = entry.tmdbId, let resume = resumeByTmdbId[tmdbId] {
                    let p = resume.progress ?? 0
                    let frac = p > 1.0 ? p / 100.0 : p
                    return frac > 0 && frac < 1.0
                }
                return false
            } else if mediaType == "tv" {
                guard let season = entry.season, let episode = entry.episode else { return false }
                return season >= 0 && episode >= 0
            }
            return false
        }

        let sortedEntries = validEntries.sorted { a, b in
            return (a.watchedAt ?? "") > (b.watchedAt ?? "")
        }

        // Process in batches with no practical limit (999999) as requested
        var finalItems: [ContinueWatchingItem] = []
        var processedCount = 0
        let batchSize = 25
        let localResumeByTmdbId = resumeByTmdbId
        
        while processedCount < sortedEntries.count && finalItems.count < 999999 {
            let endIndex = min(processedCount + batchSize, sortedEntries.count)
            let batch = Array(sortedEntries[processedCount..<endIndex])
            var batchOrderedItems: [ContinueWatchingItem?] = Array(repeating: nil, count: batch.count)
            
            await withTaskGroup(of: (Int, ContinueWatchingItem?).self) { group in
                for (index, entry) in batch.enumerated() {
                group.addTask {
                    guard let tmdbId = entry.tmdbId,
                          let mediaTypeStr = entry.mediaType else { return (index, nil) }
                    
                    let mediaType = MediaType(rawValue: mediaTypeStr) ?? .tv
                    let isoFormatter = ISO8601DateFormatter()
                    
                    if mediaType == .movie {
                        guard let movieURL = URL(string: "https://api.themoviedb.org/3/movie/\(tmdbId)?api_key=\(tmdbKey)&append_to_response=images&include_image_language=en,null") else { return (index, nil) }
                        guard let (movieData, _) = try? await URLSession.shared.data(from: movieURL) else { return (index, nil) }
                        struct TMDBImage: Codable { let filePath: String?; let iso6391: String? }
                        struct TMDBImages: Codable { let logos: [TMDBImage]?; let backdrops: [TMDBImage]? }
                        struct TMDBMovie: Codable {
                            let title: String?
                            let backdropPath: String?
                            let posterPath: String?
                            let runtime: Int?
                            let images: TMDBImages?
                        }
                        let dec = JSONDecoder()
                        dec.keyDecodingStrategy = .convertFromSnakeCase
                        guard let movie = try? dec.decode(TMDBMovie.self, from: movieData) else { return (index, nil) }
                        
                        let resume = localResumeByTmdbId[tmdbId]
                        let rawProgress = resume?.progress ?? 0.0
                        let progressFraction = rawProgress > 1.0 ? (rawProgress / 100.0) : rawProgress
                        
                        var item = ContinueWatchingItem(
                            id: "cw-\(tmdbId)-movie",
                            tmdbId: tmdbId,
                            mediaType: .movie,
                            season: 1,
                            episode: 1,
                            title: movie.title ?? "Unknown Movie",
                            posterPath: movie.posterPath,
                            progress: progressFraction,
                            sortDate: isoFormatter.date(from: entry.watchedAt ?? "") ?? .distantPast
                        )
                        item.backdropPath = movie.backdropPath
                        
                        // Extract logo and clean backdrop
                        if let images = movie.images {
                            let enLogos = images.logos?.filter { $0.iso6391 == "en" && ($0.filePath?.hasSuffix(".svg") == false) } ?? []
                            let anyLogos = images.logos?.filter { $0.filePath?.hasSuffix(".svg") == false } ?? []
                            item.logoPath = enLogos.first?.filePath ?? anyLogos.first?.filePath
                            
                            let cleanBackdrops = images.backdrops?.filter { $0.iso6391 == nil || $0.iso6391 == "" } ?? []
                            item.cleanBackdropPath = cleanBackdrops.first?.filePath
                        }
                        item.episodeName = ""
                        item.watchedAt = entry.watchedAt
                        item.isNext = false
                        
                        item.runtime = movie.runtime
                        item.resumeUpdatedAt = resume?.updatedAt
                        item.resumeId = resume?.id
                        
                        return (index, item)
                    }
                    
                    // Fetch show details
                    guard let showURL = URL(string:
                        "https://api.themoviedb.org/3/tv/\(tmdbId)?api_key=\(tmdbKey)")
                    else { return (index, nil) }
                    guard let (showData, _) = try? await URLSession.shared.data(from: showURL)
                    else { return (index, nil) }
                    
                    struct TMDBShow: Codable {
                        let name: String?
                        let backdropPath: String?
                        let posterPath: String?
                        let runtime: Int?
                        struct SeasonTemp: Codable {
                            let seasonNumber: Int?
                            let episodeCount: Int?
                        }
                        let seasons: [SeasonTemp]?
                    }
                    let dec = JSONDecoder()
                    dec.keyDecodingStrategy = .convertFromSnakeCase
                    guard let show = try? dec.decode(TMDBShow.self, from: showData)
                    else { return (index, nil) }
                    
                    // Calculate the specific NEXT episode, accounting for season rollovers
                    let watchedSeason = entry.season ?? 1
                    let watchedEpisode = entry.episode ?? 0
                    var nextSeason = watchedSeason
                    var nextEpisode = watchedEpisode + 1
                    var isFinished = false
                    
                    if let seasons = show.seasons {
                        if let currentSeason = seasons.first(where: { $0.seasonNumber == watchedSeason }),
                           let epCount = currentSeason.episodeCount {
                            if watchedEpisode >= epCount {
                                // Rollover!
                                nextSeason = watchedSeason + 1
                                nextEpisode = 1
                                
                                if !seasons.contains(where: { $0.seasonNumber == nextSeason }) {
                                    isFinished = true
                                }
                            }
                        }
                    }
                    
                    let resume = localResumeByTmdbId[tmdbId]
                    let rawProgress = resume?.progress ?? 0.0
                    let progressFraction = rawProgress > 1.0 ? (rawProgress / 100.0) : rawProgress
                    
                    if isFinished && progressFraction == 0 {
                        // Completely caught up and no episode in progress
                        return (index, nil)
                    }
                    var episodeName = "Episode \(nextEpisode)"  // fallback
                    var episodeRuntime: Int? = nil
                    var episodeStillPath: String? = nil
                    
                    let resumeUpdatedAt = resume?.updatedAt
                    
                    let targetSeason = progressFraction > 0 ? (resume?.season ?? nextSeason) : nextSeason
                    let targetEpisode = progressFraction > 0 ? (resume?.episode ?? (entry.episode ?? 1)) : nextEpisode

                    // Combine show + episode into ONE call using append_to_response
                    if let epURL = URL(string:
                        "https://api.themoviedb.org/3/tv/\(tmdbId)/season/\(targetSeason)/episode/\(targetEpisode)?api_key=\(tmdbKey)") {
                        if let (epData, _) = try? await URLSession.shared.data(from: epURL) {
                            struct TMDBEpisode: Codable {
                                let name: String?
                                let runtime: Int?
                                let stillPath: String?
                            }
                            let epDec = JSONDecoder()
                            epDec.keyDecodingStrategy = .convertFromSnakeCase
                            if let ep = try? epDec.decode(TMDBEpisode.self, from: epData) {
                                if let name = ep.name, !name.isEmpty { episodeName = name }
                                if let runtime = ep.runtime { episodeRuntime = runtime }
                                episodeStillPath = ep.stillPath
                            }
                        }
                    }
                    
                    var item = ContinueWatchingItem(
                        id: "cw-\(tmdbId)-\(targetSeason)-\(targetEpisode)",
                        tmdbId: tmdbId,
                        mediaType: mediaType,
                        season: targetSeason,
                        episode: targetEpisode,
                        title: show.name ?? "Unknown",
                        posterPath: show.posterPath,
                        progress: progressFraction,
                        sortDate: isoFormatter.date(from: entry.watchedAt ?? "") ?? .distantPast
                    )
                    item.backdropPath = show.backdropPath
                    item.episodeName = episodeName
                    item.watchedAt = entry.watchedAt
                    item.isNext = progressFraction == 0
                    
                    let displayRuntime = episodeRuntime ?? show.runtime
                    item.runtime = displayRuntime
                    
                    item.episodeStillPath = episodeStillPath
                    item.resumeUpdatedAt = resumeUpdatedAt
                    item.resumeId = resume?.id
                    
                    return (index, item)
                }
            }
            
            for await (index, item) in group {
                batchOrderedItems[index] = item
            }
        } // End of withTaskGroup
        
            finalItems.append(contentsOf: batchOrderedItems.compactMap { $0 })
            processedCount += batchSize
        } // End of while loop
        
        finalItems = Array(finalItems.prefix(999999))

        finalItems.sort { a, b in
            let aInProgress = a.progress > 0 && a.progress < 1.0
            let bInProgress = b.progress > 0 && b.progress < 1.0
            
            if aInProgress && !bInProgress { return true }
            if !aInProgress && bInProgress { return false }
            
            let dateA = a.latestInteractionDate
            let dateB = b.latestInteractionDate
            return dateA > dateB
        }
        print("[CW] Assigning \(finalItems.count) items to continueWatching")
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.continueWatching = finalItems
                self.isLoadingContinueWatching = false
            }
        }
    }

    func fetchUpcoming(watchedRaw: Data? = nil) async {
        let pmdbToken = Config.apiKey
        let tmdbKey = Config.tmdbAPIKey
        
        guard !pmdbToken.isEmpty, !tmdbKey.isEmpty else {
            print("[Upcoming] Missing tokens — pmdb:\(!pmdbToken.isEmpty) tmdb:\(!tmdbKey.isEmpty)")
            await MainActor.run { upcomingLoaded = true; isLoadingUpcoming = false }
            return
        }
        
        // Use pre-fetched watched data if available, otherwise fetch fresh
        let data: Data
        if let preWatched = watchedRaw {
            data = preWatched
        } else {
            guard let fetchedData = await self.fetchAllWatchedHistory(pmdbToken: pmdbToken) else {
                await MainActor.run { upcomingLoaded = true }
                return
            }
            data = fetchedData
        }

        struct WatchEntry: Codable {
            let tmdbId: Int?
            let mediaType: String?
        }
        struct WatchWrapper: Codable {
            let items: [WatchEntry]?
            let data: [WatchEntry]?
            var all: [WatchEntry] { items ?? data ?? [] }
        }

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        guard let wrapper = try? dec.decode(WatchWrapper.self, from: data) else {
            await MainActor.run { upcomingLoaded = true }
            return
        }

        // Get unique TV show IDs from watch history (preserve order, recent first)
        var seen = Set<Int>()
        var uniqueShowIds = [Int]()
        for item in wrapper.all where item.mediaType == "tv" {
            if let id = item.tmdbId, !seen.contains(id) {
                seen.insert(id)
                uniqueShowIds.append(id)
            }
        }
        
        // Also add Favorite shows so they get checked for upcoming episodes
        let favShowIds = await MainActor.run {
            let favs = (try? cache?.cachedFavorites()) ?? []
            return favs.filter { $0.category == .shows }.map { $0.tmdbId }
        }
        for id in favShowIds {
            if !seen.contains(id) {
                seen.insert(id)
                uniqueShowIds.append(id)
            }
        }
        
        let showIds = Array(uniqueShowIds.prefix(250))

        print("[Upcoming] Found \(showIds.count) unique TV shows in history & favorites")
        
        var results: [UpcomingEpisode] = []
        let today = Calendar.current.startOfDay(for: Date())
        
        await withTaskGroup(of: UpcomingEpisode?.self) { group in
            for showId in showIds {
                group.addTask {
                    guard let url = URL(string: "https://api.themoviedb.org/3/tv/\(showId)?api_key=\(tmdbKey)&append_to_response=images&include_image_language=en,null") else { return nil }
                    guard let (showData, _) = try? await URLSession.shared.data(from: url) else { return nil }
                    
                    struct NextEp: Codable {
                        let seasonNumber: Int?
                        let episodeNumber: Int?
                        let name: String?
                        let airDate: String?
                        let stillPath: String?
                    }
                    struct TMDBSeason: Codable {
                        let seasonNumber: Int?
                    }
                    struct TMDBImage: Codable { let filePath: String?; let iso6391: String? }
                    struct TMDBImages: Codable { let logos: [TMDBImage]?; let backdrops: [TMDBImage]? }
                    struct ShowDetail: Codable {
                        let name: String?
                        let backdropPath: String?
                        let nextEpisodeToAir: NextEp?
                        let seasons: [TMDBSeason]?
                        let images: TMDBImages?
                    }
                    struct ExternalIDs: Codable {
                        let tvdbId: Int?
                        let imdbId: String?
                    }
                    
                    let d = JSONDecoder()
                    d.keyDecodingStrategy = .convertFromSnakeCase
                    guard let show = try? d.decode(ShowDetail.self, from: showData) else { return nil }
                    
                    var bestNext: NextEp? = show.nextEpisodeToAir
                    
                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd"
                    
                    // Check for upcoming specials
                    if let seasons = show.seasons, seasons.contains(where: { $0.seasonNumber == 0 }) {
                        if let s0Url = URL(string: "https://api.themoviedb.org/3/tv/\(showId)/season/0?api_key=\(tmdbKey)"),
                           let (s0Data, _) = try? await URLSession.shared.data(from: s0Url) {
                            
                            struct TMDBSeasonDetail: Codable {
                                let episodes: [NextEp]?
                            }
                            if let s0Detail = try? d.decode(TMDBSeasonDetail.self, from: s0Data), let episodes = s0Detail.episodes {
                                // Find earliest special airing >= today (or up to 2 days ago)
                                let upcomingSpecials = episodes.compactMap { ep -> (NextEp, Date)? in
                                    guard let ad = ep.airDate, !ad.isEmpty, let date = df.date(from: ad) else { return nil }
                                    let daysSinceAir = Calendar.current.dateComponents([.day], from: date, to: today).day ?? 0
                                    if daysSinceAir > 2 { return nil }
                                    return (ep, date)
                                }.sorted { $0.1 < $1.1 }
                                
                                if let firstSpecial = upcomingSpecials.first {
                                    // Replace bestNext if bestNext is nil, or if the special airs earlier
                                    if let bn = bestNext, let bnDateStr = bn.airDate, let bnDate = df.date(from: bnDateStr) {
                                        if firstSpecial.1 < bnDate {
                                            bestNext = firstSpecial.0
                                        }
                                    } else {
                                        bestNext = firstSpecial.0
                                    }
                                }
                            }
                        }
                    }
                    
                    guard let next = bestNext, let airStr = next.airDate, !airStr.isEmpty else { return nil }
                    guard let airDate = df.date(from: airStr) else { return nil }
                    
                    // Allow TMDB airDates up to 2 days in the past to account for timezone differences
                    let daysSinceAir = Calendar.current.dateComponents([.day], from: airDate, to: today).day ?? 0
                    if daysSinceAir > 2 { return nil }
                          
                    var finalSeason = next.seasonNumber ?? 1
                    var finalEpisode = next.episodeNumber ?? 1
                    var finalEpisodeName = next.name ?? "Episode \(finalEpisode)"
                    var finalAirDate = airDate
                    var finalStillPath = next.stillPath
                    
                    let dfForMaze = DateFormatter()
                    dfForMaze.dateFormat = "yyyy-MM-dd"
                    let airDateStrForMaze = dfForMaze.string(from: finalAirDate)
                    
                    let tvMazeData = await self.fetchTVMazeAirtimeDate(showId: showId, season: finalSeason, episode: finalEpisode, airDateStr: airDateStrForMaze)
                    var airtimeDate = tvMazeData.airtimeDate
                    var networkName = tvMazeData.networkName
                    var absoluteEpisodeNumber = tvMazeData.absoluteEpisode
                    
                    var iterations = 0
                    while iterations < 2 {
                        var timeHasPassed = false
                        if let exactDate = airtimeDate {
                            if exactDate.timeIntervalSinceNow < 0 { timeHasPassed = true }
                        } else {
                            if finalAirDate < today { timeHasPassed = true }
                        }
                        
                        if !timeHasPassed { break }
                        
                        let s = finalSeason
                        let e = finalEpisode + 1
                        if let nextEpUrl = URL(string: "https://api.themoviedb.org/3/tv/\(showId)/season/\(s)/episode/\(e)?api_key=\(tmdbKey)"),
                           let (nextEpData, _) = try? await URLSession.shared.data(from: nextEpUrl) {
                            struct TMDBEpisode: Codable {
                                let seasonNumber: Int?
                                let episodeNumber: Int?
                                let name: String?
                                let airDate: String?
                                let stillPath: String?
                            }
                            if let nextEp = try? d.decode(TMDBEpisode.self, from: nextEpData),
                               let newAirStr = nextEp.airDate, !newAirStr.isEmpty,
                               let newAirDate = df.date(from: newAirStr) {
                                
                                finalSeason = nextEp.seasonNumber ?? s
                                finalEpisode = nextEp.episodeNumber ?? e
                                finalEpisodeName = nextEp.name ?? "Episode \(finalEpisode)"
                                finalAirDate = newAirDate
                                finalStillPath = nextEp.stillPath
                                
                                // Refetch exact time for the advanced episode
                                let newAirDateStr = df.string(from: newAirDate)
                                let newTvMazeData = await self.fetchTVMazeAirtimeDate(showId: showId, season: finalSeason, episode: finalEpisode, airDateStr: newAirDateStr)
                                airtimeDate = newTvMazeData.airtimeDate
                                absoluteEpisodeNumber = newTvMazeData.absoluteEpisode
                                if let newNet = newTvMazeData.networkName { networkName = newNet }
                                
                            } else {
                                return nil
                            }
                        } else {
                            return nil
                        }
                        
                        iterations += 1
                    }
                    
                    // Final safety check if it's still in the past after advancing
                    if let exactDate = airtimeDate {
                        if exactDate.timeIntervalSinceNow < 0 { return nil }
                    } else {
                        if finalAirDate < today { return nil }
                    }
                    
                    var countdown = ""
                    if let exactDate = airtimeDate {
                        let timeInterval = exactDate.timeIntervalSinceNow
                        if timeInterval < 3600 {
                            let minutes = max(0, Int(timeInterval / 60))
                            countdown = "IN \(minutes)m"
                        } else if timeInterval < 86400 {
                            // Under 24 hours, show h
                            let hours = max(0, Int(timeInterval / 3600))
                            countdown = "IN \(hours)h"
                        } else {
                            let startOfToday = Calendar.current.startOfDay(for: Date())
                            let startOfAir = Calendar.current.startOfDay(for: exactDate)
                            let days = Calendar.current.dateComponents([.day], from: startOfToday, to: startOfAir).day ?? 0
                            countdown = days <= 0 ? "TODAY" : days == 1 ? "TOMORROW" : "IN \(days)D"
                        }
                    } else {
                        // Fallback to TMDB dates
                        if finalAirDate < today { return nil }
                        let days = Calendar.current.dateComponents([.day], from: today, to: finalAirDate).day ?? 0
                        countdown = days <= 0 ? "TODAY" : days == 1 ? "TOMORROW" : "IN \(days)D"
                    }
                    
                    let showNameVal = show.name ?? "Unknown"
                    
                    // Schedule Push Notification
                    if let exactAirtime = airtimeDate {
                        if exactAirtime.timeIntervalSinceNow > 0 {
                            NotificationService.shared.scheduleEpisodeNotification(
                                showId: showId,
                                showTitle: showNameVal,
                                season: finalSeason,
                                episode: finalEpisode,
                                absoluteEpisode: absoluteEpisodeNumber,
                                episodeTitle: finalEpisodeName,
                                network: networkName,
                                airDate: exactAirtime,
                                isExactTime: true
                            )
                        }
                    } else {
                        // Schedule for 9:00 AM today for imprecise dates
                        if let nineAM = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: finalAirDate),
                           nineAM.timeIntervalSinceNow > 0 {
                            NotificationService.shared.scheduleEpisodeNotification(
                                showId: showId,
                                showTitle: showNameVal,
                                season: finalSeason,
                                episode: finalEpisode,
                                absoluteEpisode: absoluteEpisodeNumber,
                                episodeTitle: finalEpisodeName,
                                network: networkName,
                                airDate: nineAM,
                                isExactTime: false
                            )
                        }
                    }
                    
                    return UpcomingEpisode(
                        showId: showId,
                        showName: showNameVal,
                        episodeLabel: "S\(finalSeason) • E\(finalEpisode)",
                        episodeName: finalEpisodeName,
                        airDate: finalAirDate,
                        airtimeDate: airtimeDate,
                        backdropPath: show.backdropPath,
                        episodeStillPath: finalStillPath,
                        networkName: networkName,
                        absoluteEpisodeNumber: absoluteEpisodeNumber,
                        countdownLabel: countdown,
                        logoPath: {
                            let enLogos = show.images?.logos?.filter { $0.iso6391 == "en" && ($0.filePath?.hasSuffix(".svg") == false) } ?? []
                            let anyLogos = show.images?.logos?.filter { $0.filePath?.hasSuffix(".svg") == false } ?? []
                            return enLogos.first?.filePath ?? anyLogos.first?.filePath
                        }(),
                        textlessBackdropPath: {
                            let cleanBackdrops = show.images?.backdrops?.filter { $0.iso6391 == nil || $0.iso6391 == "" } ?? []
                            return cleanBackdrops.first?.filePath
                        }()
                    )
                }
            }
            for await result in group {
                if let ep = result { results.append(ep) }
            }
        }
        
        let sorted = results.sorted { ep1, ep2 in
            // For items without an exact airtime, default to the very end of the day (23:59:59)
            // so they sort *after* exact imminent airtimes like "45m" or "3h" on the same day.
            let time1 = ep1.airtimeDate ?? Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: ep1.airDate) ?? ep1.airDate
            let time2 = ep2.airtimeDate ?? Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: ep2.airDate) ?? ep2.airDate
            return time1 < time2
        }
        print("[Upcoming] Found \(sorted.count) real upcoming episodes")
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.upcomingEpisodes = sorted
                self.upcomingLoaded = true
                self.isLoadingUpcoming = false
            }
        }
    }

    func refreshCountdowns() {
        let today = Date()
        var updated = false
        var newEpisodes = upcomingEpisodes
        
        for i in (0..<newEpisodes.count).reversed() {
            var ep = newEpisodes[i]
            if let exactDate = ep.airtimeDate {
                let timeInterval = exactDate.timeIntervalSinceNow
                if timeInterval < 0 {
                    newEpisodes.remove(at: i)
                    updated = true
                    continue
                }
                
                var newCountdown = ""
                if timeInterval < 3600 {
                    let minutes = max(0, Int(timeInterval / 60))
                    newCountdown = "IN \(minutes)m"
                } else if timeInterval < 86400 {
                    let hours = max(0, Int(timeInterval / 3600))
                    newCountdown = "IN \(hours)h"
                } else {
                    let startOfToday = Calendar.current.startOfDay(for: today)
                    let startOfAir = Calendar.current.startOfDay(for: exactDate)
                    let days = Calendar.current.dateComponents([.day], from: startOfToday, to: startOfAir).day ?? 0
                    newCountdown = days <= 0 ? "TODAY" : days == 1 ? "TOMORROW" : "IN \(days)D"
                }
                
                if ep.countdownLabel != newCountdown {
                    ep.countdownLabel = newCountdown
                    newEpisodes[i] = ep
                    updated = true
                }
            } else {
                // For TMDB fallback, check if it's past today
                let startOfToday = Calendar.current.startOfDay(for: today)
                if ep.airDate < startOfToday {
                    newEpisodes.remove(at: i)
                    updated = true
                }
            }
        }
        
        if updated {
            self.upcomingEpisodes = newEpisodes
        }
    }

    func fetchHeroWatchlist(watchedRaw: Data?) async {
        let pmdbToken = Config.apiKey
        let tmdbKey = Config.tmdbAPIKey
        guard !pmdbToken.isEmpty, !tmdbKey.isEmpty else { return }
        
        do {
            let listsReq = try await api.fetchLists()
            guard let watchlist = listsReq.items.first(where: { $0.name.lowercased() == "my watchlist" || $0.type == .watchlist }) else { return }
            
            let listItemsReq = try await api.fetchListItems(listId: watchlist.id, page: 1, perPage: 1000)
            
            // Parse full watched history to reliably exclude ALL watched items
            var allWatchedTmdbIds = Set<Int>()
            if let raw = watchedRaw,
               let json = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] {
                let items = (json["items"] as? [[String: Any]]) ?? (json["data"] as? [[String: Any]]) ?? []
                for item in items {
                    if let tmdbId = item["tmdb_id"] as? Int {
                        allWatchedTmdbIds.insert(tmdbId)
                    }
                }
            }
            
            // Exclude anything in full watchHistory or continueWatching
            let excludedIds = allWatchedTmdbIds.union(self.continueWatching.map { $0.tmdbId })
            
            var seenIds = Set<Int>()
            let unwatchedItems = listItemsReq.items.filter { item in
                guard !excludedIds.contains(item.tmdbId), !seenIds.contains(item.tmdbId) else { return false }
                seenIds.insert(item.tmdbId)
                return true
            }
            
            var heroResults: [HeroCarouselItem] = []
            
            await withTaskGroup(of: HeroCarouselItem?.self) { group in
                for item in unwatchedItems.prefix(200) { // Cap to avoid runaway TMDB calls
                    group.addTask {
                        let tmdbId = item.tmdbId
                        let type = item.mediaType
                        

                        struct TMDBImage: Codable { let file_path: String?; let iso_639_1: String? }
                        struct TMDBImages: Codable { let logos: [TMDBImage]?; let posters: [TMDBImage]? }
                        
                        // For ratings
                        struct USRating: Codable { let rating: String?; let certification: String? }
                        struct ReleaseDatesResult: Codable { let iso_3166_1: String?; let release_dates: [USRating]? }
                        struct ReleaseDates: Codable { let results: [ReleaseDatesResult]? }
                        
                        struct ContentRatingResult: Codable { let iso_3166_1: String?; let rating: String? }
                        struct ContentRatings: Codable { let results: [ContentRatingResult]? }
                        
                        struct TMDBDetail: Codable {
                            let title: String?
                            let name: String?
                            let overview: String?
                            let poster_path: String?
                            let backdrop_path: String?
                            let runtime: Int?
                            let episode_run_time: [Int]?
                            let vote_average: Double?
                            let images: TMDBImages?
                            let release_dates: ReleaseDates? // Movie
                            let content_ratings: ContentRatings? // TV
                            let first_air_date: String?
                            let release_date: String?
                        }
                        
                        let urlStr = "https://api.themoviedb.org/3/\(type.rawValue)/\(tmdbId)?api_key=\(tmdbKey)&append_to_response=images,content_ratings,release_dates&include_image_language=en,null"
                        
                        var detail: TMDBDetail? = nil
                        if let url = URL(string: urlStr),
                           let (data, _) = try? await URLSession.shared.data(from: url) {
                            detail = try? JSONDecoder().decode(TMDBDetail.self, from: data)
                        }
                        
                        let title = detail?.title ?? detail?.name ?? item.title ?? "Unknown"
                        let overview = detail?.overview ?? ""
                        let poster = detail?.poster_path ?? item.posterPath
                        let backdrop = detail?.backdrop_path
                        let voteAverage = detail?.vote_average ?? item.voteAverage
                        let runtime = detail?.runtime ?? detail?.episode_run_time?.first
                        
                        var contentRating: String? = nil
                        if type == .movie {
                            if let results = detail?.release_dates?.results {
                                if let us = results.first(where: { $0.iso_3166_1 == "US" }), let rd = us.release_dates?.first {
                                    contentRating = rd.certification
                                }
                            }
                        } else {
                            if let results = detail?.content_ratings?.results {
                                if let us = results.first(where: { $0.iso_3166_1 == "US" }) {
                                    contentRating = us.rating
                                }
                            }
                        }
                        if let cr = contentRating, cr.isEmpty { contentRating = nil }
                        
                        let rawYear = detail?.release_date ?? detail?.first_air_date ?? item.year
                        let year = rawYear.map { String($0.prefix(4)) }
                        
                        var textlessPoster: String? = nil
                        if let posters = detail?.images?.posters {
                            if let textless = posters.first(where: { $0.iso_639_1 == nil || $0.iso_639_1 == "xx" }) {
                                textlessPoster = textless.file_path
                            }
                        }
                        
                        var logoPath: String? = nil
                        if let logos = detail?.images?.logos {
                            let enLogos = logos.filter { $0.iso_639_1 == "en" && ($0.file_path?.hasSuffix(".svg") == false) }
                            let anyLogos = logos.filter { $0.file_path?.hasSuffix(".svg") == false }
                            logoPath = enLogos.first?.file_path ?? anyLogos.first?.file_path
                        }
                        
                        var communityRatings: [CommunityRatingSummary]? = nil
                        var pmdbAverageRating: Int? = nil
                        if let ratingsResponse = try? await self.api.fetchRatings(tmdbId: tmdbId, mediaType: type) {
                            communityRatings = CommunityRatingSummary.dedupe(from: ratingsResponse.items)
                            if let avg = ratingsResponse.average {
                                pmdbAverageRating = Int(avg.rounded())
                            }
                        }
                        
                        // Fetch Trailer from Trailerio
                        var imdbId: String? = nil
                        var trailerURL: URL? = nil
                        if let extIds = try? await TMDBService.shared.fetchExternalIDs(tmdbId: tmdbId, mediaType: type),
                           let fetchedImdb = extIds.imdb_id, !fetchedImdb.isEmpty {
                            imdbId = fetchedImdb
                            
                            // Trailerio call
                            let typeString = type == .movie ? "movie" : "series"
                            if let url = URL(string: "https://trailerio.cc/meta/\(typeString)/\(fetchedImdb).json") {
                                do {
                                    let (data, _) = try await URLSession.shared.data(from: url)
                                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                       let meta = json["meta"] as? [String: Any],
                                       let links = meta["links"] as? [[String: Any]] {
                                        // Prioritize 720p mp4 for faster loading without buffering
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
                                            trailerURL = URL(string: urlString)
                                        }
                                    }
                                } catch {
                                    print("[Hero] Error fetching trailerio: \(error)")
                                }
                            }
                        }
                        
                        return HeroCarouselItem(
                            id: "hero-\(tmdbId)",
                            tmdbId: tmdbId,
                            mediaType: type,
                            title: title,
                            overview: overview,
                            posterPath: poster,
                            textlessPosterPath: textlessPoster,
                            backdropPath: backdrop,
                            logoPath: logoPath,
                            year: year,
                            runtime: runtime,
                            voteAverage: voteAverage,
                            pmdbAverageRating: pmdbAverageRating,
                            contentRating: contentRating,
                            communityRatings: communityRatings,
                            imdbId: imdbId,
                            trailerURL: trailerURL
                        )
                    }
                }
                for await result in group {
                    if let result = result {
                        heroResults.append(result)
                    }
                }
            }
            
            let finalResults = heroResults.shuffled() // Randomize order as requested
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.heroItems = finalResults
                    self.isLoadingHero = false
                }
            }
            
        } catch {
            print("[Hero] Error fetching hero items: \(error)")
            await MainActor.run { self.isLoadingHero = false }
        }
    }
    
    func markUnwatched(item: ContinueWatchingItem) async {
        if item.progress > 0 {
            do {
                if let resumeId = item.resumeId {
                    try await api.deleteResumePoint(id: resumeId)
                } else {
                    try await api.deleteResumePoint(id: item.id)
                }
            } catch {
                print("[CW] Failed to delete resume point: \(error)")
            }
        }
        
        do {
            try await api.bulkDeleteWatchHistory(query: WatchedBulkDeleteQuery(
                tmdbId: item.tmdbId,
                mediaType: item.mediaType,
                season: item.season,
                episode: item.episode
            ))
        } catch {
            print("[CW] Failed to bulk delete watch history: \(error)")
        }
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        await refreshData(showLoadingState: false)
    }
    
    func revertToPreviousEpisode(item: ContinueWatchingItem) async {
        guard item.mediaType == .tv else { return }
        
        if let latestEntry = watchHistory.filter({ $0.tmdbId == item.tmdbId && $0.mediaType == .tv }).sorted(by: { 
            ($0.watchedAt ?? "") > ($1.watchedAt ?? "") 
        }).first {
            do {
                try await api.deleteWatchEntry(id: latestEntry.id)
                try? await Task.sleep(nanoseconds: 500_000_000)
                await refreshData(showLoadingState: false)
            } catch {
                print("[CW] Failed to revert previous episode: \(error)")
            }
        }
    }

    func removeWatchProgress(item: ContinueWatchingItem) async {
        if item.progress > 0 {
            do {
                if let resumeId = item.resumeId {
                    try await api.deleteResumePoint(id: resumeId)
                } else {
                    try await api.deleteResumePoint(id: item.id)
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
                await refreshData(showLoadingState: false)
            } catch {
                print("[CW] Failed to remove watch progress: \(error)")
            }
        }
    }
    func markNextEpisodeWatched(item: ContinueWatchingItem) async {
        let pmdbToken = Config.apiKey
        guard !pmdbToken.isEmpty else { return }
        
        guard let url = URL(string: "https://publicmetadb.com/api/external/watched") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(pmdbToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "tmdb_id": item.tmdbId,
            "media_type": "tv",
            "season": item.season ?? 1,
            "episode": item.episode ?? 1
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return }
        req.httpBody = httpBody
        
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await refreshData(showLoadingState: false)
            } else {
                print("[CW] Failed to mark next episode as watched, status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
        } catch {
            print("[CW] Failed to mark next episode as watched: \(error)")
        }
    }

    private func fetchAllWatchedHistory(pmdbToken: String) async -> Data? {
        var allItems: [Any] = []
        var page = 1
        var totalPages = 1
        
        while page <= totalPages {
            guard let url = URL(string: "https://publicmetadb.com/api/external/watched?perPage=500&page=\(page)") else { break }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(pmdbToken)", forHTTPHeaderField: "Authorization")
            
            guard let (data, _) = try? await URLSession.shared.data(for: req),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                break
            }
            
            if let items = json["items"] as? [Any] {
                allItems.append(contentsOf: items)
            } else if let dataItems = json["data"] as? [Any] {
                allItems.append(contentsOf: dataItems)
            }
            
            if let tp = json["totalPages"] as? Int {
                totalPages = tp
            } else {
                break
            }
            page += 1
        }
        
        let combined = ["items": allItems]
        return try? JSONSerialization.data(withJSONObject: combined)
    }

    func fetchTVMazeAirtimeDate(showId: Int, season: Int, episode: Int, airDateStr: String) async -> (airtimeDate: Date?, absoluteEpisode: Int?, networkName: String?) {
        struct ExternalIDs: Codable { let tvdbId: Int?; let imdbId: String? }
        let tmdbKey = Config.tmdbAPIKey
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let extUrl = URL(string: "https://api.themoviedb.org/3/tv/\(showId)/external_ids?api_key=\(tmdbKey)"),
              let (extData, _) = try? await URLSession.shared.data(from: extUrl),
              let extIds = try? d.decode(ExternalIDs.self, from: extData) else { return (nil, nil, nil) }
        
        var tvmazeLookupUrl: URL?
        if let tvdbId = extIds.tvdbId {
            tvmazeLookupUrl = URL(string: "https://api.tvmaze.com/lookup/shows?thetvdb=\(tvdbId)")
        } else if let imdbId = extIds.imdbId {
            tvmazeLookupUrl = URL(string: "https://api.tvmaze.com/lookup/shows?imdb=\(imdbId)")
        }
        
        guard let tvmazeLookupUrl = tvmazeLookupUrl,
              let (tvmazeShowData, _) = try? await URLSession.shared.data(from: tvmazeLookupUrl) else { return (nil, nil, nil) }
        
        struct TVMazeNetwork: Codable { let name: String? }
        struct TVMazeShow: Codable {
            let id: Int?
            let network: TVMazeNetwork?
            let webChannel: TVMazeNetwork?
        }
        
        let tvmazeD = JSONDecoder()
        guard let tvmazeShow = try? tvmazeD.decode(TVMazeShow.self, from: tvmazeShowData) else { return (nil, nil, nil) }
        
        let networkName = tvmazeShow.network?.name ?? tvmazeShow.webChannel?.name
        
        guard let tvmazeShowId = tvmazeShow.id,
              let epUrl = URL(string: "https://api.tvmaze.com/shows/\(tvmazeShowId)/episodesbydate?date=\(airDateStr)"),
              let (tvmazeEpData, _) = try? await URLSession.shared.data(from: epUrl),
              let episodesJson = try? JSONSerialization.jsonObject(with: tvmazeEpData) as? [[String: Any]] else { return (nil, nil, networkName) }
        
        // Match exact season/episode first (for double episodes that air on the same day)
        var matchedEp = episodesJson.first { ($0["season"] as? Int) == season && ($0["number"] as? Int) == episode }
        
        // Fallback: If not found, it might be an anime where TMDB/TVMaze season numbering differs. Just take the first one.
        if matchedEp == nil {
            matchedEp = episodesJson.first
        }
        
        var airtimeDate: Date?
        var absEp: Int?
        if let ep = matchedEp {
            absEp = ep["number"] as? Int
            if let airstamp = ep["airstamp"] as? String {
                let isoFormatter = ISO8601DateFormatter()
                airtimeDate = isoFormatter.date(from: airstamp)
            }
        }
        
        return (airtimeDate, absEp, networkName)
    }
    
    func enrichHistoryImages(entries: [WatchEntry]) async {
        let movieEntries = entries.filter { $0.mediaType == .movie }.prefix(50)
        let tmdbKey = Config.tmdbAPIKey
        
        await withTaskGroup(of: (Int, URL?, URL?)?.self) { group in
            for entry in movieEntries {
                let id = entry.tmdbId
                group.addTask {
                    guard let url = URL(string: "https://api.themoviedb.org/3/movie/\(id)/images?api_key=\(tmdbKey)&include_image_language=en,null") else { return nil }
                    guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
                    struct TMDBImage: Codable { let filePath: String?; let iso6391: String? }
                    struct TMDBImages: Codable { let logos: [TMDBImage]?; let backdrops: [TMDBImage]? }
                    let dec = JSONDecoder()
                    dec.keyDecodingStrategy = .convertFromSnakeCase
                    guard let images = try? dec.decode(TMDBImages.self, from: data) else { return nil }
                    
                    let enLogos = images.logos?.filter { $0.iso6391 == "en" && ($0.filePath?.hasSuffix(".svg") == false) } ?? []
                    let anyLogos = images.logos?.filter { $0.filePath?.hasSuffix(".svg") == false } ?? []
                    let logoPath = enLogos.first?.filePath ?? anyLogos.first?.filePath
                    
                    let cleanBackdrops = images.backdrops?.filter { $0.iso6391 == nil || $0.iso6391 == "" } ?? []
                    let cleanBackdropPath = cleanBackdrops.first?.filePath
                    
                    let logoURL = logoPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") }
                    let cleanURL = cleanBackdropPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") }
                    
                    return (id, logoURL, cleanURL)
                }
            }
            
            for await result in group {
                if let (id, logoURL, cleanURL) = result {
                    await MainActor.run {
                        if let l = logoURL { self.historyLogos[id] = l }
                        if let c = cleanURL { self.historyCleanBackdrops[id] = c }
                    }
                }
            }
        }
    }
}

// MARK: - Recent Updates Models

struct RecentUpdatesResponse: Codable {
    let skips: [RecentSkip]
    let ratings: [RecentRating]
    let highlights: [RecentHighlight]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Safely decode arrays, defaulting to empty if the array itself is missing/invalid.
        // Even better, we could decode unkeyed containers to filter bad items, but using try? for the whole array 
        // at least prevents the entire page from breaking if one property is wrong.
        skips = (try? container.decodeIfPresent([RecentSkip].self, forKey: .skips)) ?? []
        ratings = (try? container.decodeIfPresent([RecentRating].self, forKey: .ratings)) ?? []
        highlights = (try? container.decodeIfPresent([RecentHighlight].self, forKey: .highlights)) ?? []
    }
}

struct RecentSkip: Codable, Identifiable, Hashable {
    let id: String
    let tmdbId: Int
    let mediaType: String // "movie" or "tv"
    let season: Int?
    let episode: Int?
    let source: String?
    let title: String?
    let posterPath: String?
    let year: String?
    let updated: String
    let user: String?
    
    var mediaTypeEnum: MediaType {
        MediaType(rawValue: mediaType) ?? .movie
    }
    
    var posterURL: URL? {
        guard let p = posterPath, !p.isEmpty else { return nil }
        return URL(string: Config.tmdbImageBase + p)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case season
        case episode
        case source
        case title
        case posterPath = "poster_path"
        case year
        case updated
        case user
    }
}

struct RecentRating: Codable, Identifiable, Hashable {
    let id: String
    let tmdbId: Int
    let mediaType: String
    let score: Double
    let label: String?
    let title: String?
    let posterPath: String?
    let year: String?
    let updated: String
    let user: String?
    
    var mediaTypeEnum: MediaType {
        MediaType(rawValue: mediaType) ?? .movie
    }
    
    var posterURL: URL? {
        guard let p = posterPath, !p.isEmpty else { return nil }
        return URL(string: Config.tmdbImageBase + p)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case score
        case label
        case title
        case posterPath = "poster_path"
        case year
        case updated
        case user
    }
}

struct RecentHighlight: Codable, Identifiable, Hashable {
    let id: String
    let tmdbId: Int
    let mediaType: String
    let season: Int?
    let episode: Int?
    let description: String?
    let title: String?
    let posterPath: String?
    let year: String?
    let updated: String
    let user: String?
    
    var mediaTypeEnum: MediaType {
        MediaType(rawValue: mediaType) ?? .movie
    }
    
    var posterURL: URL? {
        guard let p = posterPath, !p.isEmpty else { return nil }
        return URL(string: Config.tmdbImageBase + p)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case season
        case episode
        case description
        case title
        case posterPath = "poster_path"
        case year
        case updated
        case user
    }
}

private extension ResumeQuery {
    init(perPage: Int) {
        self.init()
        self.perPage = perPage
    }
}

private extension APIService {
    func fetchResumePoints(perPage: Int) async throws -> PaginatedResponse<ResumePoint> {
        try await fetchResumePoints(query: ResumeQuery(perPage: perPage))
    }

    func fetchWatchHistory(perPage: Int) async throws -> PaginatedResponse<WatchEntry> {
        try await fetchWatchHistory(page: 1, perPage: perPage)
    }
}

struct TMDBShowDetail: Codable {
    let name: String?
    let backdropPath: String?
    let nextEpisodeToAir: TMDBNextEpisodeToAir?

    enum CodingKeys: String, CodingKey {
        case name
        case backdropPath = "backdrop_path"
        case nextEpisodeToAir = "next_episode_to_air"
    }
}

import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    // Use a serial queue to prevent iOS UNUserNotificationCenter race conditions
    private let queue = DispatchQueue(label: "com.pmdb.notifications")
    
    private init() {}
    
    func scheduleEpisodeNotification(
        showId: Int,
        showTitle: String,
        season: Int,
        episode: Int,
        absoluteEpisode: Int?,
        episodeTitle: String,
        network: String?,
        airDate: Date,
        isExactTime: Bool = true
    ) {
        @AppStorage("pushNotificationsEnabled") var pushNotificationsEnabled = false
        guard pushNotificationsEnabled else { return }
        
        let identifier = "upcoming_show_\(showId)"
        
        // If exact time, schedule 15 minutes before. Otherwise, it's already set to 9:00 AM.
        let timeInterval = isExactTime ? (airDate.timeIntervalSinceNow - (15 * 60)) : airDate.timeIntervalSinceNow
        guard timeInterval > 0 else { return }
        
        queue.async {
            let content = UNMutableNotificationContent()
            content.title = showTitle
            content.subtitle = "S\(season) • E\(episode) - \(episodeTitle)"
            
            if isExactTime {
                let netString = network ?? "TV"
                content.body = "Airing in 15 minutes on \(netString)!"
            } else {
                if let net = network, !net.isEmpty {
                    content.body = "Airing today on \(net)!"
                } else {
                    content.body = "Airing today!"
                }
            }
            
            content.sound = UNNotificationSound(named: UNNotificationSoundName("cinematicboom.caf"))
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            // `add` automatically replaces existing requests with the same identifier.
            // Explicitly calling removePendingNotificationRequests first is known to cause race conditions in iOS!
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification for \(showTitle): \(error)")
                }
            }
        }
    }
}
