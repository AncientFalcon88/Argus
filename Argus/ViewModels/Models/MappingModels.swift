import Foundation

struct ExternalMapping: Codable, Identifiable, Hashable {
    let id: String
    let tmdbId: Int
    let mediaType: MediaType
    let idType: ExternalIDType
    let idValue: String
    let contributor: String?
    var userVote: Int?
    var voteCount: Int?
    var isOwner: Bool?
    let created: String?
    let tmdbSeason: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case idType = "id_type"
        case idValue = "id_value"
        case contributor
        case userVote = "user_vote"
        case voteCount = "vote_count"
        case isOwner = "is_owner"
        case created
        case tmdbSeason = "tmdb_season"
    }
}

struct MappingsResponse: Codable {
    struct MappingItem: Codable {
        let id: String
        let value: String
        let contributor: String?
        let userVote: Int?
        let voteCount: Int?
        let isOwner: Bool?
        let created: String?
        let tmdbSeason: Int?

        enum CodingKeys: String, CodingKey {
            case id
            case value
            case contributor
            case userVote = "user_vote"
            case voteCount = "vote_count"
            case isOwner = "is_owner"
            case created
            case tmdbSeason = "tmdb_season"
        }
    }
    
    let tmdb_id: Int?
    let media_type: String?
    let mappings: [String: [MappingItem]]?
    let items: [ExternalMapping]?

    var all: [ExternalMapping] {
        if let mappingsDict = mappings {
            var result: [ExternalMapping] = []
            for (typeStr, mappingItems) in mappingsDict {
                if let idType = ExternalIDType(rawValue: typeStr) {
                    for item in mappingItems {
                        result.append(ExternalMapping(
                            id: item.id,
                            tmdbId: tmdb_id ?? 0,
                            mediaType: MediaType(rawValue: media_type ?? "tv") ?? .tv,
                            idType: idType,
                            idValue: item.value,
                            contributor: item.contributor,
                            userVote: item.userVote,
                            voteCount: item.voteCount,
                            isOwner: item.isOwner,
                            created: item.created,
                            tmdbSeason: item.tmdbSeason
                        ))
                    }
                }
            }
            return result
        }
        return items ?? []
    }
}

struct LookupTMDBResponse: Codable {
    let tmdbId: Int?
    let mediaType: MediaType?

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
    }
}

struct CreateMappingRequest: Codable {
    let tmdbId: Int
    let mediaType: MediaType
    let idType: ExternalIDType
    let idValue: String

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case idType = "id_type"
        case idValue = "id_value"
    }
}

struct PocketBaseMappingRequest: Codable {
    let tmdb_id: Int
    let media_type: String
    let id_type: String
    let id_value: String
    let user: String
    let contributor: String
    let votes: VotesDict
    let userVote: Int
    
    struct VotesDict: Codable {
        let up: [String]
        let down: [String]
    }
}

