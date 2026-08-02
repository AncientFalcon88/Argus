import Foundation

/// Unified card for the Home "Continue Watching" row (resume + inferred next episodes).
struct ContinueWatchingItem: Identifiable, Hashable {
    var id: String
    let tmdbId: Int
    let mediaType: MediaType
    var season: Int?
    var episode: Int?
    let title: String?
    let posterPath: String?
    let progress: Double
    let sortDate: Date
    
    // New fields populated after initial build
    var episodeName: String?
    var episodeStillPath: String?
    var runtime: Int?
    var backdropPath: String?   // for display in wide landscape card
    var logoPath: String?
    var cleanBackdropPath: String?
    var watchedAt: String?      // raw ISO string — used for re-sorting after async enrichment
    var isNext: Bool = false    // true = "next episode" suggestion, false = in-progress resume
    var resumeUpdatedAt: String?
    var resumeId: String?

    var episodeLabel: String {
        switch mediaType {
        case .movie:
            return "MOVIE"
        case .person:
            return "PERSON"
        case .tv:
            if let season, let episode {
                return "S\(season) • E\(episode)"
            }
            return "TV Series"
        }
    }

    var latestInteractionDate: Date {
        let historyDate = Date.parseRobustly(watchedAt)
        let resumeDate = Date.parseRobustly(resumeUpdatedAt)
        if progress > 0 && progress < 1.0 {
            return resumeDate > Date(timeIntervalSince1970: 0) ? resumeDate : historyDate
        }
        return historyDate
    }

    var timeAgo: String {
        let finalDate = latestInteractionDate
        if finalDate <= Date(timeIntervalSince1970: 0) {
            return ""
        }
        
        let mins = Int(Date().timeIntervalSince(finalDate) / 60)
        if mins < 1 { return "Just now" }
        if mins < 60 { return "\(mins)m ago" }
        let hrs = mins / 60
        if hrs < 24 { return "\(hrs)h ago" }
        return "\(hrs/24)d ago"
    }

    init(
        id: String,
        tmdbId: Int,
        mediaType: MediaType,
        season: Int?,
        episode: Int?,
        title: String?,
        posterPath: String?,
        backdropPath: String? = nil,
        progress: Double,
        sortDate: Date
    ) {
        self.id = id
        self.tmdbId = tmdbId
        self.mediaType = mediaType
        self.season = season
        self.episode = episode
        self.title = title
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.progress = progress
        self.sortDate = sortDate
    }

    init(resume point: ResumePoint) {
        self.init(
            id: point.id,
            tmdbId: point.tmdbId,
            mediaType: point.mediaType,
            season: point.season,
            episode: point.episode,
            title: point.title,
            posterPath: point.posterPath,
            backdropPath: point.backdropPath,
            progress: point.progressFraction,
            sortDate: {
                let updated = Date.parseRobustly(point.updatedAt)
                if updated > .distantPast { return updated }
                let created = Date.parseRobustly(point.createdAt)
                if created > .distantPast { return created }
                return .now
            }()
        )
        // ResumePoint runtime comes in milliseconds if available
        if let rMs = point.runtimeMs, rMs > 0 {
            self.runtime = rMs / 60000
        }
    }

    var logoURL: URL? {
        logoPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") }
    }
    var textlessBackdropURL: URL? {
        cleanBackdropPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") }
    }
    
    func resumeRoute() -> MediaDetailRoute {
        MediaDetailRoute(
            tmdbId: tmdbId,
            mediaType: mediaType,
            season: season,
            episode: episode
        )
    }
}

enum ContinueWatchingBuilder {
    static let completionThreshold = 0.95
    static let maxItems = 5

    static func build(resumePoints: [ResumePoint], watchHistory: [WatchEntry]) async -> [ContinueWatchingItem] {
        var items: [ContinueWatchingItem] = []
        var seen = Set<String>()

        for point in resumePoints {
            let progress = point.progressFraction
            guard progress > 0.01, progress < completionThreshold else { continue }
            let item = ContinueWatchingItem(resume: point)
            let key = identityKey(for: item)
            guard seen.insert(key).inserted else { continue }
            items.append(item)
        }

        let tvByShow = Dictionary(grouping: watchHistory.filter { $0.mediaType == .tv && $0.tmdbId > 0 }) { $0.tmdbId }

        // Sort by tmdbId before iterating so dictionary's non-deterministic order doesn't matter
        for (tmdbId, entries) in tvByShow.sorted(by: { $0.key > $1.key }) {
            let sorted = entries.sorted {
                Date.parseRobustly($0.watchedAt) > Date.parseRobustly($1.watchedAt)
            }
            guard let latest = sorted.first else { continue }

            let season = latest.season ?? 1
            let watchedEpisode = latest.episode ?? 1

            let inProgressOnShow = resumePoints.contains { point in
                point.tmdbId == tmdbId
                    && point.mediaType == .tv
                    && point.progressFraction > 0.01
                    && point.progressFraction < completionThreshold
            }
            if inProgressOnShow { continue }

            let nextEpisode = watchedEpisode + 1
            let next = ContinueWatchingItem(
                id: "next-\(tmdbId)-\(season)-\(nextEpisode)",
                tmdbId: tmdbId,
                mediaType: .tv,
                season: season,
                episode: nextEpisode,
                title: latest.title,
                posterPath: latest.posterPath,
                progress: 0,
                sortDate: Date.parseRobustly(latest.watchedAt)
            )
            let key = identityKey(for: next)
            guard seen.insert(key).inserted else { continue }
            items.append(next)
        }

        items.sort { a, b -> Bool in
            if a.sortDate != b.sortDate { return a.sortDate > b.sortDate }
            // Stable tiebreaker: higher tmdbId first (arbitrary but consistent)
            return a.tmdbId > b.tmdbId
        }
        let baseItems = items
            
        // Fetch missing metadata (runtime/episodeTitle) and resolve season rollovers
        var enrichedItems: [ContinueWatchingItem?] = Array(repeating: nil, count: baseItems.count)
        let tmdbKey = Config.tmdbAPIKey
        
        await withTaskGroup(of: (Int, ContinueWatchingItem?).self) { group in
            for (index, item) in baseItems.enumerated() {
                group.addTask {
                    var mutableItem = item
                    do {
                        if item.mediaType == .tv, let season = item.season, let episode = item.episode {
                            var targetSeason = season
                            var targetEpisode = episode
                            
                            // 1. Resolve Rollover
                            let showUrl = URL(string: "https://api.themoviedb.org/3/tv/\(item.tmdbId)?api_key=\(tmdbKey)")!
                            let (showData, _) = try await URLSession.shared.data(from: showUrl)
                            
                            struct TMDBShowTemp: Codable {
                                struct SeasonTemp: Codable {
                                    let season_number: Int
                                    let episode_count: Int
                                }
                                let seasons: [SeasonTemp]?
                            }
                            let showInfo = try JSONDecoder().decode(TMDBShowTemp.self, from: showData)
                            
                            if let seasons = showInfo.seasons {
                                let watchedSeason = season
                                let watchedEpisode = episode - 1
                                
                                if let currentSeasonInfo = seasons.first(where: { $0.season_number == watchedSeason }) {
                                    if watchedEpisode >= currentSeasonInfo.episode_count {
                                        // rollover!
                                        targetSeason = watchedSeason + 1
                                        targetEpisode = 1
                                        
                                        // check if next season actually exists
                                        if !seasons.contains(where: { $0.season_number == targetSeason }) {
                                            // User finished the entire show!
                                            return (index, nil)
                                        }
                                    }
                                }
                            }
                            
                            mutableItem.season = targetSeason
                            mutableItem.episode = targetEpisode
                            mutableItem.id = "next-\(item.tmdbId)-\(targetSeason)-\(targetEpisode)"

                            // 2. Fetch Episode Metadata
                            let url = URL(string: "https://api.themoviedb.org/3/tv/\(item.tmdbId)/season/\(targetSeason)/episode/\(targetEpisode)?api_key=\(tmdbKey)")!
                            let (data, _) = try await URLSession.shared.data(from: url)
                            let detail = try JSONDecoder().decode(TMDBEpisodeBasicInfo.self, from: data)
                            mutableItem.episodeName = detail.name
                            mutableItem.episodeStillPath = detail.still_path
                            if let runtime = detail.runtime {
                                mutableItem.runtime = runtime
                            }
                        } else if item.mediaType == .movie {
                            let url = URL(string: "https://api.themoviedb.org/3/movie/\(item.tmdbId)?api_key=\(tmdbKey)")!
                            let (data, _) = try await URLSession.shared.data(from: url)
                            let detail = try JSONDecoder().decode(TMDBMovieBasicInfo.self, from: data)
                            if let runtime = detail.runtime {
                                mutableItem.runtime = runtime
                            }
                            if let backdrop = detail.backdrop_path, mutableItem.backdropPath == nil {
                                mutableItem.backdropPath = backdrop
                            }
                        }
                    } catch {
                        // silently fail and return existing item (or nil if it failed after realizing it was a finale)
                    }
                    return (index, mutableItem)
                }
            }
            
            for await (index, enriched) in group {
                enrichedItems[index] = enriched
            }
        }
        
        return enrichedItems.compactMap { $0 }
    }

    static func identityKey(for item: ContinueWatchingItem) -> String {
        "\(item.mediaType.rawValue)-\(item.tmdbId)-\(item.season ?? 0)-\(item.episode ?? 0)"
    }
}

struct TMDBEpisodeBasicInfo: Codable {
    let name: String?
    let runtime: Int?
    let still_path: String?
}

struct TMDBMovieBasicInfo: Codable {
    let runtime: Int?
    let backdrop_path: String?
}

