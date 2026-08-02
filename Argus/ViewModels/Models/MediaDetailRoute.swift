import Foundation

struct MediaDetailRoute: Hashable {
    let tmdbId: Int
    let mediaType: MediaType
    var season: Int?
    var episode: Int?

    init(tmdbId: Int, mediaType: MediaType, season: Int? = nil, episode: Int? = nil) {
        self.tmdbId = TMDBIDResolver.resolve(numericId: tmdbId, displayTitle: nil) ?? tmdbId
        self.mediaType = mediaType
        self.season = season
        self.episode = episode
    }

    init(item: TMDBMediaItem) {
        self.init(tmdbId: item.tmdbId, mediaType: item.mediaType)
    }

    init(entry: WatchEntry) {
        let id = TMDBIDResolver.resolve(numericId: entry.tmdbId, displayTitle: entry.title) ?? entry.tmdbId
        self.init(tmdbId: id, mediaType: entry.mediaType, season: entry.season, episode: entry.episode)
    }

    init(point: ResumePoint) {
        let id = TMDBIDResolver.resolve(numericId: point.tmdbId, displayTitle: point.title) ?? point.tmdbId
        self.init(tmdbId: id, mediaType: point.mediaType, season: point.season, episode: point.episode)
    }

    init(item: CatalogItem) {
        let id = TMDBIDResolver.resolve(numericId: item.tmdbId, displayTitle: item.title) ?? item.tmdbId
        self.init(tmdbId: id, mediaType: item.mediaType)
    }

    init(item: ListItem) {
        let id = TMDBIDResolver.resolve(numericId: item.tmdbId, displayTitle: item.title) ?? item.tmdbId
        self.init(tmdbId: id, mediaType: item.mediaType)
    }
}

struct PersonDetailRoute: Hashable {
    let personId: Int
    let name: String
}
enum CommunityDataTab: String, CaseIterable, Identifiable {
    case ratings = "Ratings"
    case episodeRatings = "Episode Ratings"
    case skips = "Skips"
    case highlights = "Highlights"
    case seasonMappings = "Season Mappings"
    case externalIDs = "External IDs"

    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .ratings: return "star.fill"
        case .episodeRatings: return "star"
        case .skips: return "forward.end"
        case .seasonMappings: return "map"
        case .highlights: return "flag"
        case .externalIDs: return "link"
        }
    }
}

struct MediaDetailInfo: Equatable {
    let tmdbId: Int
    let mediaType: MediaType
    let title: String
    let tagline: String?
    let overview: String
    let year: String
    let posterPath: String?
    let textlessPosterPath: String?
    let backdropPath: String?
    let logoPath: String?
    let certification: String?
    let networkLabel: String?
    let runtimeLabel: String?
    let trailerYouTubeKey: String?
    let voteAverage: Double
    let voteCount: Int
    let genres: [String]
    let genreIds: [Int]
    let seasons: [SeasonSummary]
    let originalLanguage: String?
    let originCountry: [String]?
    let credits: [DepartmentGroup]
    // Rich metadata
    let watchProviders: WatchProviderInfo?
    let nextEpisodeToAir: NextEpisodeInfo?
    let budget: Int?
    let revenue: Int?
    let collectionId: Int?
    let collectionName: String?
    let allVideos: [VideoItem]
    let networkItems: [NetworkItem]
    let keywords: [String]
    let reviews: [ReviewItem]
    let status: String?

    var trailerURL: URL? {
        guard let trailerYouTubeKey else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(trailerYouTubeKey)")
    }
}

// MARK: - Watch Providers

struct WatchProviderInfo: Equatable {
    let link: String?
    let streaming: [WatchProviderEntry]
    let rent: [WatchProviderEntry]
    let buy: [WatchProviderEntry]
    let free: [WatchProviderEntry]

    var hasAny: Bool { !streaming.isEmpty || !rent.isEmpty || !buy.isEmpty || !free.isEmpty }
}

struct WatchProviderEntry: Equatable, Identifiable {
    let id: Int
    let name: String
    let logoPath: String?

    var logoURL: URL? {
        guard let logoPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w92" + logoPath)
    }
}

// MARK: - Next Episode

struct NextEpisodeInfo: Equatable {
    let seasonNumber: Int
    let episodeNumber: Int
    let name: String
    let airDate: String   // "2026-07-14"

    var daysUntilAir: Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: airDate) else { return nil }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return Calendar.current.dateComponents([.day], from: startOfToday, to: date).day
    }

    var formattedAirDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: airDate) else { return airDate }
        let out = DateFormatter()
        out.dateStyle = .long
        out.timeStyle = .none
        return out.string(from: date)
    }
}



// MARK: - Videos

struct VideoItem: Equatable, Identifiable {
    let id: String
    let key: String
    let name: String
    let type: String  // Trailer, Teaser, Clip, Behind the Scenes, Featurette, Bloopers
    let site: String  // YouTube

    var youtubeURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(key)")
    }
    var thumbnailURL: URL? {
        URL(string: "https://img.youtube.com/vi/\(key)/mqdefault.jpg")
    }
    var typeBadge: String {
        switch type.lowercased() {
        case "trailer": return "TRAILER"
        case "teaser": return "TEASER"
        case "clip": return "CLIP"
        case "behind the scenes": return "BTS"
        case "featurette": return "FEATURETTE"
        case "bloopers": return "BLOOPERS"
        default: return type.uppercased()
        }
    }
}

// MARK: - Network

struct NetworkItem: Equatable, Identifiable {
    let id: Int
    let name: String
    let logoPath: String?

    var logoURL: URL? {
        guard let logoPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w92" + logoPath)
    }
}

// MARK: - Reviews

struct ReviewItem: Equatable, Identifiable {
    let id: String
    let author: String
    let content: String
    let rating: Double?
    let avatarPath: String?
    let createdAt: String?

    var avatarURL: URL? {
        guard let avatarPath, !avatarPath.isEmpty else { return nil }
        // TMDB sometimes returns full URLs (gravatar), sometimes just paths
        if avatarPath.hasPrefix("/t/p/") {
            return URL(string: "https://image.tmdb.org" + avatarPath)
        } else if avatarPath.hasPrefix("/") {
            // Could be a gravatar path prepended by TMDB as "/https://..."
            let stripped = String(avatarPath.dropFirst())
            return URL(string: stripped)
        }
        return URL(string: avatarPath)
    }

    var formattedDate: String? {
        guard let createdAt else { return nil }
        let prefix = String(createdAt.prefix(10))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: prefix) else { return prefix }
        let out = DateFormatter()
        out.dateStyle = .medium
        return out.string(from: date)
    }
}

// MARK: - Credits

struct DepartmentGroup: Equatable, Identifiable {
    let id = UUID()
    let department: String
    let members: [CastMember]
}

struct CastMember: Identifiable, Hashable {
    let id: Int
    let name: String
    let character: String // or job role
    let profilePath: String?

    var profileURL: URL? {
        Config.tmdbImageURL(path: profilePath, size: "w185")
    }
}

struct SeasonSummary: Identifiable, Hashable {
    let seasonNumber: Int
    let name: String
    let episodeCount: Int

    var id: Int { seasonNumber }
    var shortLabel: String { seasonNumber == 0 ? "Specials" : "S\(seasonNumber)" }
}

struct EpisodeDisplay: Identifiable, Hashable {
    let episodeNumber: Int
    let name: String
    let overview: String?
    let stillPath: String?
    let runtimeMinutes: Int?
    let airDate: String?

    var id: Int { episodeNumber }

    var runtimeLabel: String {
        guard let runtimeMinutes, runtimeMinutes > 0 else { return "—" }
        return "\(runtimeMinutes)m"
    }
}

struct AggregatedScoreCard: Identifiable, Hashable {
    let id: String
    let abbreviation: String
    let title: String
    let scoreText: String
    let tint: String
}
