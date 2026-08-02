import Foundation

actor MetadataEnrichmentService {
    static let shared = MetadataEnrichmentService()

    private var cache: [String: TMDBMediaItem] = [:]
    private let tmdb = TMDBService.shared
    private let maxConcurrent = 6

    private func cacheKey(tmdbId: Int, mediaType: MediaType) -> String {
        "\(mediaType.rawValue)-\(tmdbId)"
    }

    func enrichWatchEntries(_ entries: [WatchEntry]) async -> [WatchEntry] {
        await enrich(entries) { entry in
            let id = TMDBIDResolver.resolve(numericId: entry.tmdbId, displayTitle: entry.title) ?? entry.tmdbId
            guard id > 0,
                  TMDBIDResolver.needsMetadata(title: entry.title, posterPath: entry.posterPath, backdropPath: entry.backdropPath, tmdbId: entry.tmdbId) else {
                return entry
            }
            guard let meta = await self.metadata(tmdbId: id, mediaType: entry.mediaType) else {
                return entry
            }
            return WatchEntry(
                id: entry.id,
                tmdbId: id,
                mediaType: entry.mediaType,
                season: entry.season,
                episode: entry.episode,
                watchedAt: entry.watchedAt,
                title: meta.title,
                posterPath: meta.posterPath ?? entry.posterPath,
                backdropPath: meta.backdropPath ?? entry.backdropPath
            )
        }
    }

    func enrichResumePoints(_ points: [ResumePoint]) async -> [ResumePoint] {
        await enrich(points) { point in
            let id = TMDBIDResolver.resolve(numericId: point.tmdbId, displayTitle: point.title) ?? point.tmdbId
            guard id > 0,
                  TMDBIDResolver.needsMetadata(title: point.title, posterPath: point.posterPath, backdropPath: point.backdropPath, tmdbId: point.tmdbId) else {
                return point
            }
            guard let meta = await self.metadata(tmdbId: id, mediaType: point.mediaType) else {
                return point
            }
            return ResumePoint(
                id: point.id,
                tmdbId: id,
                mediaType: point.mediaType,
                season: point.season,
                episode: point.episode,
                positionMs: point.positionMs,
                runtimeMs: point.runtimeMs,
                progress: point.progress,
                title: meta.title,
                posterPath: meta.posterPath ?? point.posterPath,
                backdropPath: meta.backdropPath ?? point.backdropPath,
                createdAt: point.createdAt,
                updatedAt: point.updatedAt
            )
        }
    }

    func enrichLists(_ lists: [MediaList]) async -> [MediaList] {
        var enrichedLists = lists
        await withTaskGroup(of: (Int, Int, [URL?])?.self) { group in
            for i in 0..<enrichedLists.count {
                let previewItems = enrichedLists[i].previewItems
                let itemCount = enrichedLists[i].itemCount ?? previewItems.count
                if !previewItems.isEmpty {
                    group.addTask {
                        let enrichedItems = await self.enrichListItems(previewItems)
                        return (i, itemCount, enrichedItems.map { $0.posterURL })
                    }
                } else {
                    let listId = enrichedLists[i].id
                    group.addTask {
                        do {
                            let response = try await APIService.shared.fetchListItems(listId: listId)
                            let count = response.items.count
                            let items = Array(response.items.prefix(6))
                            let enrichedItems = await self.enrichListItems(items)
                            return (i, count, enrichedItems.map { $0.posterURL })
                        } catch {
                            return (i, 0, [])
                        }
                    }
                }
            }
            for await result in group {
                if let (index, count, posters) = result {
                    enrichedLists[index].itemCount = count
                    enrichedLists[index].previewPosters = posters
                }
            }
        }
        return enrichedLists
    }

    func enrichListItems(_ items: [ListItem]) async -> [ListItem] {
        await enrich(items) { item in
            let id = TMDBIDResolver.resolve(numericId: item.tmdbId, displayTitle: item.title) ?? item.tmdbId
            guard id > 0,
                  TMDBIDResolver.needsMetadata(title: item.title, posterPath: item.posterPath, tmdbId: item.tmdbId) else {
                return item
            }
            guard let meta = await self.metadata(tmdbId: id, mediaType: item.mediaType) else {
                return item
            }
            return ListItem(
                id: item.id,
                tmdbId: id,
                mediaType: item.mediaType,
                title: meta.title,
                posterPath: meta.posterPath ?? item.posterPath,
                addedAt: item.addedAt,
                year: meta.year,
                voteAverage: meta.voteAverage,
                genreIds: meta.genreIds ?? item.genreIds
            )
        }
    }

    func enrichCatalogItems(_ items: [CatalogItem]) async -> [CatalogItem] {
        await enrich(items) { item in
            let id = TMDBIDResolver.resolve(numericId: item.tmdbId, displayTitle: item.title) ?? item.tmdbId
            guard id > 0,
                  TMDBIDResolver.needsMetadata(title: item.title, posterPath: item.posterPath, tmdbId: item.tmdbId) else {
                return item
            }
            guard let meta = await self.metadata(tmdbId: id, mediaType: item.mediaType) else {
                return item
            }
            return CatalogItem(
                tmdbId: id,
                mediaType: item.mediaType,
                title: meta.title,
                posterPath: meta.posterPath ?? item.posterPath,
                backdropPath: meta.backdropPath ?? item.backdropPath,
                matchScore: item.matchScore,
                voteAverage: meta.voteAverage,
                year: meta.year,
                matchReasons: item.matchReasons,
                voteCount: item.voteCount,
                popularityScore: item.popularityScore,
                originalLanguage: item.originalLanguage
            )
        }
    }

    private func metadata(tmdbId: Int, mediaType: MediaType) async -> TMDBMediaItem? {
        let key = cacheKey(tmdbId: tmdbId, mediaType: mediaType)
        if let cached = cache[key] { return cached }
        guard let item = try? await tmdb.details(tmdbId: tmdbId, mediaType: mediaType) else {
            return nil
        }
        cache[key] = item
        return item
    }

    private func enrich<T>(
        _ items: [T],
        transform: @escaping (T) async -> T
    ) async -> [T] {
        guard !items.isEmpty else { return items }
        var result = Array(items)
        var index = 0

        await withTaskGroup(of: (Int, T).self) { group in
            func scheduleNext() {
                guard index < items.count else { return }
                let current = index
                index += 1
                group.addTask {
                    let enriched = await transform(items[current])
                    return (current, enriched)
                }
            }

            for _ in 0..<min(maxConcurrent, items.count) {
                scheduleNext()
            }

            for await (position, enriched) in group {
                result[position] = enriched
                scheduleNext()
            }
        }

        return result
    }

    
    func fetchRichMetadata(for items: [TMDBMediaItem], pmdbRatings: [Int: Int], cleanPosters: [Int: URL], itemLogos: [Int: URL]) async -> (ratings: [Int: Int], posters: [Int: URL], logos: [Int: URL]) {
        enum FetchResult {
            case rating(Int, Int)
            case images(Int, URL, URL)
        }
        
        var newRatings = [Int: Int]()
        var newPosters = [Int: URL]()
        var newLogos = [Int: URL]()
        
        // Ensure we only fetch for items we haven't fetched yet
        let itemsToFetchRatings = items.filter { pmdbRatings[$0.tmdbId] == nil }
        let itemsToFetchImages = items.filter { cleanPosters[$0.tmdbId] == nil && itemLogos[$0.tmdbId] == nil }
        
        await withTaskGroup(of: FetchResult?.self) { group in
            for item in itemsToFetchRatings {
                group.addTask {
                    do {
                        let response = try await APIService.shared.fetchRatings(tmdbId: item.tmdbId, mediaType: item.mediaType)
                        if let avg = response.average {
                            return .rating(item.tmdbId, Int(avg.rounded()))
                        } else {
                            return .rating(item.tmdbId, -1)
                        }
                    } catch {
                        return .rating(item.tmdbId, -1)
                    }
                }
            }
            
            for item in itemsToFetchImages {
                group.addTask {
                    do {
                        let images = try await TMDBService.shared.fetchImages(tmdbId: item.tmdbId, mediaType: item.mediaType)
                        if let poster = images.cleanPosterURL, let logo = images.bestLogoURL {
                            return .images(item.tmdbId, poster, logo)
                        } else {
                            return nil
                        }
                    } catch {
                        return nil
                    }
                }
            }
            
            for await result in group {
                if let res = result {
                    switch res {
                    case .rating(let id, let r): newRatings[id] = r
                    case .images(let id, let p, let l): newPosters[id] = p; newLogos[id] = l
                    }
                }
            }
        }
        
        return (newRatings, newPosters, newLogos)
    }
}

@MainActor
final class TrendingManager {
    static let shared = TrendingManager()
    
    private let tmdb = TMDBService.shared
    
    private(set) var trendingMovies: [TMDBMediaItem] = []
    private(set) var trendingTVs: [TMDBMediaItem] = []
    
    private var lastFetchTime: Date?
    private let cacheValidDuration: TimeInterval = 60 * 60 * 4 // 4 hours
    
    private var fetchTask: Task<Void, Never>?
    
    func fetchTrendingIfNeeded() async {
        if let lastFetch = lastFetchTime, Date().timeIntervalSince(lastFetch) < cacheValidDuration {
            return // Cache is still valid
        }
        
        if let task = fetchTask {
            await task.value // Wait if already fetching
            return
        }
        
        let task = Task {
            do {
                async let moviesTask = tmdb.fetchTrending(mediaType: "movie", timeWindow: "day", page: 1)
                async let tvsTask = tmdb.fetchTrending(mediaType: "tv", timeWindow: "day", page: 1)
                
                async let moviesTask2 = tmdb.fetchTrending(mediaType: "movie", timeWindow: "day", page: 2)
                async let tvsTask2 = tmdb.fetchTrending(mediaType: "tv", timeWindow: "day", page: 2)
                
                let (movies1, tvs1, movies2, tvs2) = try await (moviesTask, tvsTask, moviesTask2, tvsTask2)
                
                self.trendingMovies = Array((movies1 + movies2).prefix(30))
                self.trendingTVs = Array((tvs1 + tvs2).prefix(30))
                self.lastFetchTime = Date()
            } catch {
                print("Failed to fetch global trending items: \(error)")
            }
            self.fetchTask = nil
        }
        self.fetchTask = task
        await task.value
    }
}

struct BadgeEngine {
    
    @MainActor
    static func getTag(for item: TMDBMediaItem) -> String {
        // 1. Trending Priority
        if item.mediaType == .movie {
            if let index = TrendingManager.shared.trendingMovies.firstIndex(where: { $0.tmdbId == item.tmdbId }) {
                return "#\(index + 1) TRENDING"
            }
        } else {
            if let index = TrendingManager.shared.trendingTVs.firstIndex(where: { $0.tmdbId == item.tmdbId }) {
                return "#\(index + 1) TRENDING"
            }
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate] // YYYY-MM-DD
        
        var daysSinceRelease: Int? = nil
        let currentYear = String(Calendar.current.component(.year, from: Date()))
        let currentYearInt = Int(currentYear) ?? 2026
        
        if let dateString = item.releaseDate, let releaseDate = formatter.date(from: dateString) {
            daysSinceRelease = Calendar.current.dateComponents([.day], from: releaseDate, to: Date()).day
            
            if let days = daysSinceRelease {
                if days >= 0 && days <= 45 {
                    return item.mediaType == .tv ? "NEW SERIES" : "NEW RELEASE"
                }
                if days < 0 { return "UPCOMING" }
            }
        } else {
            if let itemYearInt = Int(item.year), itemYearInt > currentYearInt {
                return "UPCOMING"
            }
        }
        
        // Exceptional Ratings
        if item.voteAverage >= 8.5 && item.voteCount >= 3000 {
            return "MASTERPIECE"
        }
        
        if item.voteAverage >= 7.5 && item.voteCount >= 100 {
            if let days = daysSinceRelease, days > (25 * 365) {
                return "CLASSIC"
            } else if let itemYearInt = Int(item.year), itemYearInt <= (currentYearInt - 25) {
                return "CLASSIC"
            }
        }

        // Low Vote / Hidden
        if item.voteAverage >= 7.5 && item.voteCount >= 50 && item.voteCount <= 500 {
            return "HIDDEN GEM"
        }
        
        if item.voteAverage >= 7.0 && item.voteCount >= 10 && item.voteCount <= 50 {
            return "INDIE"
        }
        
        if item.voteAverage >= 8.0 && item.voteCount >= 100 {
            return "TOP RATED"
        }
        
        if item.voteCount >= 10000 {
            return "BLOCKBUSTER"
        }
        
        if item.voteAverage >= 6.5 && item.voteAverage <= 7.4 && item.voteCount >= 3000 {
            if let days = daysSinceRelease, days > (15 * 365) {
                return "CULT CLASSIC"
            } else if let itemYearInt = Int(item.year), itemYearInt <= (currentYearInt - 15) {
                return "CULT CLASSIC"
            }
        }
        
        if item.voteCount >= 1500 {
            return "POPULAR"
        }
        
        // Specific Genres / Categories
        if item.genreIds?.contains(99) == true {
            return "DOCUMENTARY"
        }
        
        let isAnime = item.genreIds?.contains(16) == true && (item.originalLanguage == "ja" || item.originCountry?.contains("JP") == true)
        if isAnime {
            return "ANIME"
        }
        
        if item.mediaType == .tv && (item.originCountry?.contains("KR") == true || item.originalLanguage == "ko") {
            return "K-DRAMA"
        }
        
        return item.mediaType == .movie ? "MOVIE" : "SERIES"
    }
}
