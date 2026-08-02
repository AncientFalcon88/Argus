import Foundation

struct AnimeSeasonChunk: Codable, Identifiable, Hashable {
    let id: String
    let tmdbSeason: Int
    let tmdbEpisodeStart: Int?
    let tmdbEpisodeEnd: Int?
    let chunkTmdbId: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbSeason = "tmdb_season"
        case tmdbEpisodeStart = "tmdb_episode_start"
        case tmdbEpisodeEnd = "tmdb_episode_end"
        case chunkTmdbId = "chunk_tmdb_id"
    }
}

struct AnimeSeasonMapping: Codable, Identifiable, Hashable {
    let serverId: String?
    let tmdbId: Int?
    let seasonNumber: Int
    let seasonName: String?
    let contributor: String?
    var userVote: Int?
    var voteCount: Int?
    let chunks: [AnimeSeasonChunk]

    enum CodingKeys: String, CodingKey {
        case serverId = "id"
        case tmdbId = "tmdb_id"
        case seasonNumber = "season_number"
        case seasonName = "season_name"
        case contributor
        case userVote = "user_vote"
        case voteCount = "vote_count"
        case chunks
    }

    var id: String { serverId ?? "\(tmdbId ?? 0)-\(seasonNumber)" }
    var stableId: String { id }
}

struct AnimeSeasonChunkInput: Codable {
    let tmdbSeason: Int
    let tmdbEpisodeStart: Int?
    let tmdbEpisodeEnd: Int?
    let chunkTmdbId: Int?

    enum CodingKeys: String, CodingKey {
        case tmdbSeason = "tmdb_season"
        case tmdbEpisodeStart = "tmdb_episode_start"
        case tmdbEpisodeEnd = "tmdb_episode_end"
        case chunkTmdbId = "chunk_tmdb_id"
    }
}

struct SubmitAnimeSeasonRequest: Codable {
    let tmdbId: Int
    let seasonNumber: Int
    let seasonName: String?
    let chunks: [AnimeSeasonChunkInput]

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case seasonNumber = "season_number"
        case seasonName = "season_name"
        case chunks
    }
}

struct AnimeSeasonsResponse: Decodable {
    let seasons: [AnimeSeasonMapping]?
    let mappings: [AnimeSeasonMapping]?
    let items: [AnimeSeasonMapping]?

    var all: [AnimeSeasonMapping] { seasons ?? mappings ?? items ?? [] }

    // Custom decode: handle a direct top-level array OR an object wrapper
    init(from decoder: Decoder) throws {
        // Try object first
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            seasons  = try container.decodeIfPresent([AnimeSeasonMapping].self, forKey: .seasons)
            mappings = try container.decodeIfPresent([AnimeSeasonMapping].self, forKey: .mappings)
            items    = try container.decodeIfPresent([AnimeSeasonMapping].self, forKey: .items)
        } else {
            // Fallback: top-level array
            var unkeyedContainer = try decoder.unkeyedContainer()
            var result: [AnimeSeasonMapping] = []
            while !unkeyedContainer.isAtEnd {
                result.append(try unkeyedContainer.decode(AnimeSeasonMapping.self))
            }
            seasons = result
            mappings = nil
            items = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case seasons, mappings, items
    }
}

