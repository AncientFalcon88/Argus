import Foundation

struct WatchEntry: Codable, Identifiable, Hashable {
    let id: String
    let tmdbId: Int
    let mediaType: MediaType
    let season: Int?
    let episode: Int?
    let watchedAt: String?
    let title: String?
    let name: String? // TV Shows use name instead of title
    let posterPath: String?
    var backdropPath: String?
    var episodeName: String?
    var episodeStillPath: String?
    var runtime: Int?
    var runtimeMs: Int?
    var duration: Int?
    var length: Int?
    var logoPath: String?
    var textlessBackdropPath: String?
    
    var logoURL: URL? {
        logoPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") }
    }
    var cleanBackdropURL: URL? {
        textlessBackdropPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") }
    }
    
    var displayTitle: String {
        return title ?? name ?? episodeName ?? "Unknown Item"
    }

    var progressFraction: Double? {
        if let d = duration, let l = length, l > 0 {
            return Double(d) / Double(l)
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case season, episode
        case watchedAt = "watched_at"
        case title
        case name
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case episodeName = "episode_name"
        case episodeStillPath = "episode_still_path"
        case runtime
        case runtimeMs = "runtime_ms"
        case duration
        case length
    }

    var watchedDate: Date? {
        let date = Date.parseRobustly(watchedAt)
        return date > Date(timeIntervalSince1970: 0) ? date : nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        
        if let tInt = try? container.decodeIfPresent(Int.self, forKey: .tmdbId) {
            tmdbId = tInt
        } else if let tStr = try? container.decodeIfPresent(String.self, forKey: .tmdbId), let val = Int(tStr) {
            tmdbId = val
        } else {
            tmdbId = 0
        }
        
        if let mType = try? container.decodeIfPresent(MediaType.self, forKey: .mediaType) {
            mediaType = mType
        } else if let mStr = try? container.decodeIfPresent(String.self, forKey: .mediaType), let mType = MediaType(rawValue: mStr) {
            mediaType = mType
        } else {
            mediaType = .movie // Default fallback
        }
        
        watchedAt = try? container.decodeIfPresent(String.self, forKey: .watchedAt)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        posterPath = try? container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try? container.decodeIfPresent(String.self, forKey: .backdropPath)
        episodeName = try? container.decodeIfPresent(String.self, forKey: .episodeName)
        episodeStillPath = try? container.decodeIfPresent(String.self, forKey: .episodeStillPath)
        runtime = try? container.decodeIfPresent(Int.self, forKey: .runtime)
        runtimeMs = try? container.decodeIfPresent(Int.self, forKey: .runtimeMs)
        duration = try? container.decodeIfPresent(Int.self, forKey: .duration)
        length = try? container.decodeIfPresent(Int.self, forKey: .length)
        
        if let sInt = try? container.decodeIfPresent(Int.self, forKey: .season) {
            season = sInt
        } else if let sStr = try? container.decodeIfPresent(String.self, forKey: .season) {
            season = Int(sStr)
        } else {
            season = nil
        }
        
        if let eInt = try? container.decodeIfPresent(Int.self, forKey: .episode) {
            episode = eInt
        } else if let eStr = try? container.decodeIfPresent(String.self, forKey: .episode) {
            episode = Int(eStr)
        } else {
            episode = nil
        }
    }

    init(id: String, tmdbId: Int, mediaType: MediaType, season: Int?, episode: Int?, watchedAt: String?, title: String?, name: String?, posterPath: String?, backdropPath: String? = nil, episodeName: String? = nil, episodeStillPath: String? = nil, runtime: Int? = nil, runtimeMs: Int? = nil, duration: Int? = nil, length: Int? = nil) {
        self.id = id
        self.tmdbId = tmdbId
        self.mediaType = mediaType
        self.season = season
        self.episode = episode
        self.watchedAt = watchedAt
        self.title = title
        self.name = name
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.episodeName = episodeName
        self.episodeStillPath = episodeStillPath
        self.runtime = runtime
        self.runtimeMs = runtimeMs
        self.duration = duration
        self.length = length
    }

    var displayDate: String {
        let date = Date.parseRobustly(watchedAt)
        if date <= Date(timeIntervalSince1970: 0) {
            return watchedAt ?? "Unknown date"
        }
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: .now)
    }

    var episodeLabel: String {
        mediaType == .tv ? "S\(season ?? 1) • E\(episode ?? 1)" : "MOVIE"
    }

    init(
        id: String,
        tmdbId: Int,
        mediaType: MediaType,
        season: Int?,
        episode: Int?,
        watchedAt: String?,
        title: String?,
        name: String? = nil,
        posterPath: String?,
        backdropPath: String? = nil,
        episodeName: String? = nil,
        episodeStillPath: String? = nil
    ) {
        self.id = id
        self.tmdbId = tmdbId
        self.mediaType = mediaType
        self.season = season
        self.episode = episode
        self.watchedAt = watchedAt
        self.title = title
        self.name = name
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.episodeName = episodeName
        self.episodeStillPath = episodeStillPath
    }
}

struct MarkWatchedRequest: Codable {
    let tmdbId: Int
    let mediaType: MediaType
    let season: Int?
    let episode: Int?
    let watchedAt: String?

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case season, episode
        case watchedAt = "watched_at"
    }

    init(tmdbId: Int, mediaType: MediaType, season: Int? = nil, episode: Int? = nil, watchedAt: String? = nil) {
        self.tmdbId = tmdbId
        self.mediaType = mediaType
        self.season = season
        self.episode = episode
        self.watchedAt = watchedAt
    }
}

struct EditWatchDateRequest: Codable {
    let watchedAt: String?

    enum CodingKeys: String, CodingKey {
        case watchedAt = "watched_at"
    }
}

struct WatchedBulkDeleteQuery {
    let tmdbId: Int
    let mediaType: MediaType
    let season: Int?
    let episode: Int?

    var queryItems: [URLQueryItem] {
        var items = [
            URLQueryItem(name: "tmdb_id", value: "\(tmdbId)"),
            URLQueryItem(name: "media_type", value: mediaType.rawValue)
        ]
        if let season { items.append(URLQueryItem(name: "season", value: "\(season)")) }
        if let episode { items.append(URLQueryItem(name: "episode", value: "\(episode)")) }
        return items
    }
}

