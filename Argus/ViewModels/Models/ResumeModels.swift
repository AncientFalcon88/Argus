import Foundation

struct ResumePoint: Codable, Identifiable, Hashable {
    let id: String
    let tmdbId: Int
    let mediaType: MediaType
    let season: Int?
    let episode: Int?
    let positionMs: Int
    let runtimeMs: Int?
    let progress: Double?
    let title: String?
    let posterPath: String?
    let backdropPath: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case season, episode
        case positionMs = "position_ms"
        case runtimeMs = "runtime_ms"
        case progress, title
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var progressFraction: Double {
        if let progress {
            return progress > 1 ? min(progress / 100, 1) : min(max(progress, 0), 1)
        }
        guard let runtimeMs, runtimeMs > 0 else { return 0 }
        return min(max(Double(positionMs) / Double(runtimeMs), 0), 1)
    }

    var episodeLabel: String {
        mediaType == .tv ? "S\(season ?? 1) • E\(episode ?? 1)" : "Movie"
    }

    init(
        id: String,
        tmdbId: Int,
        mediaType: MediaType,
        season: Int?,
        episode: Int?,
        positionMs: Int,
        runtimeMs: Int?,
        progress: Double?,
        title: String?,
        posterPath: String?,
        backdropPath: String?,
        createdAt: String?,
        updatedAt: String?
    ) {
        self.id = id
        self.tmdbId = tmdbId
        self.mediaType = mediaType
        self.season = season
        self.episode = episode
        self.positionMs = positionMs
        self.runtimeMs = runtimeMs
        self.progress = progress
        self.title = title
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct SaveResumeRequest: Codable {
    let tmdbId: Int?
    let mediaType: MediaType
    let season: Int?
    let episode: Int?
    let positionMs: Int
    let runtimeMs: Int
    let idType: ExternalIDType?
    let idValue: String?

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case season, episode
        case positionMs = "position_ms"
        case runtimeMs = "runtime_ms"
        case idType = "id_type"
        case idValue = "id_value"
    }

    init(
        tmdbId: Int? = nil,
        mediaType: MediaType,
        season: Int? = nil,
        episode: Int? = nil,
        positionMs: Int,
        runtimeMs: Int,
        idType: ExternalIDType? = nil,
        idValue: String? = nil
    ) {
        self.tmdbId = tmdbId
        self.mediaType = mediaType
        self.season = season
        self.episode = episode
        self.positionMs = positionMs
        self.runtimeMs = runtimeMs
        self.idType = idType
        self.idValue = idValue
    }
}

struct BatchSaveResumeRequest: Codable {
    let items: [SaveResumeRequest]
}

struct BatchSaveResumeResponse: Codable {
    let results: [BatchItemResult]?
}

struct BatchItemResult: Codable {
    let index: Int?
    let success: Bool?
    let action: String?
    let error: String?
}

struct ResumeQuery {
    var tmdbId: Int?
    var mediaType: MediaType?
    var season: Int?
    var episode: Int?
    var idType: ExternalIDType?
    var idValue: String?
    var page: Int = 1
    var perPage: Int = Config.defaultPerPage

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perPage", value: "\(perPage)")
        ]
        if let tmdbId { items.append(URLQueryItem(name: "tmdb_id", value: "\(tmdbId)")) }
        if let mediaType { items.append(URLQueryItem(name: "media_type", value: mediaType.rawValue)) }
        if let season { items.append(URLQueryItem(name: "season", value: "\(season)")) }
        if let episode { items.append(URLQueryItem(name: "episode", value: "\(episode)")) }
        if let idType { items.append(URLQueryItem(name: "id_type", value: idType.rawValue)) }
        if let idValue { items.append(URLQueryItem(name: "id_value", value: idValue)) }
        return items
    }
}

