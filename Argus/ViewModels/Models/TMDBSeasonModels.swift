import Foundation

struct TMDBSeasonListResponse: Codable {
    let seasons: [TMDBSeasonStub]?
}

struct TMDBSeasonStub: Codable {
    let seasonNumber: Int?
    let name: String?
    let episodeCount: Int?

    enum CodingKeys: String, CodingKey {
        case seasonNumber = "season_number"
        case name
        case episodeCount = "episode_count"
    }
}

struct TMDBSeasonDetailResponse: Codable {
    let seasonNumber: Int?
    let name: String?
    let episodes: [TMDBEpisodeStub]?

    enum CodingKeys: String, CodingKey {
        case seasonNumber = "season_number"
        case name, episodes
    }
}

struct TMDBEpisodeStub: Codable {
    let episodeNumber: Int?
    let name: String?
    let overview: String?
    let stillPath: String?
    let runtime: Int?
    let airDate: String?

    enum CodingKeys: String, CodingKey {
        case episodeNumber = "episode_number"
        case name, overview
        case stillPath = "still_path"
        case runtime
        case airDate = "air_date"
    }

    func display() -> EpisodeDisplay {
        EpisodeDisplay(
            episodeNumber: episodeNumber ?? 0,
            name: name ?? "Episode \(episodeNumber ?? 0)",
            overview: overview,
            stillPath: stillPath,
            runtimeMinutes: runtime,
            airDate: airDate
        )
    }
}

struct TMDBVideosResponse: Codable {
    let results: [TMDBVideo]?
}

struct TMDBVideo: Codable {
    let id: String?
    let key: String?
    let name: String?
    let site: String?
    let type: String?
}

struct TMDBNetworkWrapper: Codable {
    let id: Int?
    let name: String?
    let logoPath: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case logoPath = "logo_path"
    }
}

struct TMDBGenreStub: Codable {
    let id: Int
    let name: String?
}
