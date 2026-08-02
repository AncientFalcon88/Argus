import Foundation

struct SkipTimestamp: Codable, Identifiable, Hashable {
    let id: String
    let tmdbId: Int
    let mediaType: MediaType
    let season: Int?
    let episode: Int?
    let source: SkipSource?
    let introStartMs: Int?
    let introEndMs: Int?
    let creditsStartMs: Int?
    let creditsEndMs: Int?
    let createdAt: String?
    let contributor: String?
    // Vote data (fetched separately and merged in)
    var voteCount: Int
    var userVote: Int  // -1, 0, or 1
    var isOwner: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case season, episode, source
        case introStartMs = "intro_start_ms"
        case introEndMs = "intro_end_ms"
        case creditsStartMs = "credits_start_ms"
        case creditsEndMs = "credits_end_ms"
        case createdAt = "created"
        case createdFallback = "created_at"
        case contributor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        tmdbId = try container.decode(Int.self, forKey: .tmdbId)
        mediaType = try container.decode(MediaType.self, forKey: .mediaType)
        season = try container.decodeIfPresent(Int.self, forKey: .season)
        episode = try container.decodeIfPresent(Int.self, forKey: .episode)
        source = try container.decodeIfPresent(SkipSource.self, forKey: .source)
        introStartMs = try container.decodeIfPresent(Int.self, forKey: .introStartMs)
        introEndMs = try container.decodeIfPresent(Int.self, forKey: .introEndMs)
        creditsStartMs = try container.decodeIfPresent(Int.self, forKey: .creditsStartMs)
        creditsEndMs = try container.decodeIfPresent(Int.self, forKey: .creditsEndMs)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? container.decodeIfPresent(String.self, forKey: .createdFallback)
        contributor = try container.decodeIfPresent(String.self, forKey: .contributor)
        voteCount = 0
        userVote = 0
        isOwner = false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tmdbId, forKey: .tmdbId)
        try container.encode(mediaType, forKey: .mediaType)
        try container.encodeIfPresent(season, forKey: .season)
        try container.encodeIfPresent(episode, forKey: .episode)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(introStartMs, forKey: .introStartMs)
        try container.encodeIfPresent(introEndMs, forKey: .introEndMs)
        try container.encodeIfPresent(creditsStartMs, forKey: .creditsStartMs)
        try container.encodeIfPresent(creditsEndMs, forKey: .creditsEndMs)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(contributor, forKey: .contributor)
    }

    /// Display string for intro: "mm:ss → mm:ss"
    var introDisplay: String? {
        guard let s = introStartMs, let e = introEndMs else { return nil }
        return "\(msToDisplay(s)) → \(msToDisplay(e))"
    }

    /// Display string for credits: "mm:ss → mm:ss"
    var creditsDisplay: String? {
        guard let s = creditsStartMs, let e = creditsEndMs else { return nil }
        return "\(msToDisplay(s)) → \(msToDisplay(e))"
    }

    var dateString: String? {
        guard let c = createdAt else { return nil }
        let prefix = String(c.prefix(10))
        let parts = prefix.split(separator: "-")
        if parts.count == 3 { return "\(parts[2])/\(parts[1])/\(parts[0])" }
        return prefix
    }
}

private func msToDisplay(_ ms: Int) -> String {
    let totalSec = ms / 1000
    let m = totalSec / 60
    let s = totalSec % 60
    return String(format: "%02d:%02d", m, s)
}

struct SkipsResponse: Codable {
    let skips: [SkipTimestamp]?
    let items: [SkipTimestamp]?

    var allSkips: [SkipTimestamp] { skips ?? items ?? [] }
}

struct CreateSkipRequest: Codable {
    let tmdbId: Int
    let mediaType: MediaType
    let season: Int?
    let episode: Int?
    let source: SkipSource?
    let introStartMs: Int?
    let introEndMs: Int?
    let creditsStartMs: Int?
    let creditsEndMs: Int?

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case season, episode, source
        case introStartMs = "intro_start_ms"
        case introEndMs = "intro_end_ms"
        case creditsStartMs = "credits_start_ms"
        case creditsEndMs = "credits_end_ms"
    }
}
