import Foundation

struct CommunityRatingSummary: Identifiable, Hashable {
    let id: String
    let label: String
    let shortLabel: String
    let averageScore: Int
    let voteCount: Int

    static func dedupe(from ratings: [Rating]) -> [CommunityRatingSummary] {
        let grouped = Dictionary(grouping: ratings, by: { 
            ($0.label ?? "Overall")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        })
        
        return grouped.compactMap { normalizedLabel, entries in
            let count = entries.count
            guard count > 0 else { return nil }
            
            // Proper rounded average, clamped to valid range
            let total = entries.map(\.score).reduce(0, +)
            let avg = Int((Double(total) / Double(count)).rounded())
            let clampedAvg = max(0, min(100, avg))
            
            let displayLabel: String
            switch normalizedLabel {
            case "imdb", "im":             displayLabel = "IM"
            case "trakt", "tr":            displayLabel = "TR"
            case "tmdb", "tm":             displayLabel = "TM"
            case "metacritic", "mc":       displayLabel = "MC"
            case "letterboxd", "lb":       displayLabel = "LB"
            case "rotten tomatoes", "rt":  displayLabel = "RT"
            case "personal", "pc":         displayLabel = "PC"
            case "overall":                displayLabel = "Overall"
            default:                       displayLabel = (entries.first?.label ?? "Overall").uppercased()
            }
            
            return CommunityRatingSummary(
                id: normalizedLabel,
                label: entries.first?.label ?? "Overall",
                shortLabel: displayLabel,
                averageScore: clampedAvg,
                voteCount: count
            )
        }
        .sorted { $0.averageScore > $1.averageScore }
    }
}

struct Rating: Codable, Identifiable, Hashable {
    let id: String
    let tmdbId: Int
    let mediaType: MediaType
    let score: Int          // Stored as Int; API may send fractional Doubles (e.g. 74.9)
    let label: String?
    let createdAt: String?
    let isOwner: Bool?
    let userId: String?
    let username: String?
    let contributor: String?

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case score, label
        case createdAt = "created_at"
        case isOwner = "is_owner"
        case userId = "user_id"
        case username
        case contributor
    }

    init(id: String, tmdbId: Int, mediaType: MediaType, score: Int, label: String?, createdAt: String?, isOwner: Bool? = nil, userId: String? = nil, username: String? = nil, contributor: String? = nil) {
        self.id = id
        self.tmdbId = tmdbId
        self.mediaType = mediaType
        self.score = score
        self.label = label
        self.createdAt = createdAt
        self.isOwner = isOwner
        self.userId = userId
        self.username = username
        self.contributor = contributor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self, forKey: .id)
        tmdbId    = try c.decode(Int.self,    forKey: .tmdbId)
        mediaType = try c.decode(MediaType.self, forKey: .mediaType)
        // score can arrive as Double (e.g. 74.9) or Int — normalise to Int by rounding
        if let d = try? c.decode(Double.self, forKey: .score) {
            score = Int(d.rounded())
        } else {
            score = try c.decode(Int.self, forKey: .score)
        }
        label     = try c.decodeIfPresent(String.self, forKey: .label)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        isOwner   = try c.decodeIfPresent(Bool.self,   forKey: .isOwner)
        userId    = try c.decodeIfPresent(String.self, forKey: .userId)
        username  = try c.decodeIfPresent(String.self, forKey: .username)
        contributor = try c.decodeIfPresent(String.self, forKey: .contributor)
    }
}

struct RatingsResponse: Decodable {
    let items: [Rating]
    let average: Double?
    let total: Int?

    var ratings: [Rating] { items }
    var count: Int? { total }

    enum CodingKeys: String, CodingKey {
        case items
        case ratings
        case average
        case total
        case count
    }

    init(items: [Rating] = [], average: Double? = nil, total: Int? = nil) {
        self.items = items
        self.average = average
        self.total = total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let decodedItems = try container.decodeIfPresent([Rating].self, forKey: .items) {
            items = decodedItems
        } else {
            items = try container.decodeIfPresent([Rating].self, forKey: .ratings) ?? []
        }
        average = try container.decodeIfPresent(Double.self, forKey: .average)
        if let decodedTotal = try container.decodeIfPresent(Int.self, forKey: .total) {
            total = decodedTotal
        } else {
            total = try container.decodeIfPresent(Int.self, forKey: .count)
        }
    }
}

struct CreateRatingRequest: Codable {
    let tmdbId: Int
    let mediaType: MediaType
    let score: Int
    let label: String?

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case score, label
    }
}

struct EpisodeRating: Codable, Identifiable, Hashable {
    let id: String
    let tmdbId: Int
    let mediaType: MediaType
    let season: Int
    let episode: Int
    let score: Int
    let label: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case season, episode, score, label
        case createdAt = "created_at"
    }
}

struct EpisodeRatingsResponse: Codable {
    let ratings: [EpisodeRating]
    let average: Double?
    let count: Int?
}

struct CreateEpisodeRatingRequest: Codable {
    let tmdbId: Int
    let mediaType: MediaType
    let season: Int
    let episode: Int
    let score: Int
    let label: String?

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case season, episode, score, label
    }
}

struct EpisodeRatingInput: Codable {
    let episode: Int
    let score: Int
    let label: String?
}

struct BatchCreateEpisodeRatingsRequest: Codable {
    let tmdbId: Int
    let mediaType: MediaType
    let season: Int
    let label: String?
    let ratings: [EpisodeRatingInput]

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case season, label, ratings
    }
}

struct BatchDeleteEpisodeRatingsRequest: Codable {
    let ids: [String]
}

struct EpisodeRatingSummary: Hashable {
    let average: Double
    let total: Int
}

// MARK: - Multi-shape batch response parser

/// Tries every known response shape for GET /episode-ratings/batch and returns
/// a [episodeNumber: EpisodeRatingSummary] dictionary.
///
/// Supported shapes (tried in order):
///   1. { "episodes": { "1": { "average": 84.5, "total": 12 }, ... } }        ← keyed dict
///   2. { "items": [ { "episode": 1, "average": 84.5, "total": 12 }, ... ] }  ← items array
///   3. [ { "episode": 1, "average": 84.5, "total": 12 }, ... ]               ← root array of summaries
///   4. [ { "id": "...", "episode": 1, "score": 85, ... } ]                   ← flat individual records
enum EpisodeRatingsParser {

    static func parse(data: Data) -> [Int: EpisodeRatingSummary] {
        // Shape 1 — keyed dict under "episodes"
        if let result = tryKeyedDict(data) { return result }
        // Shape 2 — { "items": [...] }
        if let result = tryItemsArray(data) { return result }
        // Shape 3 — root array of summary objects  [ { episode, average, total } ]
        if let result = tryRootSummaryArray(data) { return result }
        // Shape 4 — flat individual rating records  [ { id, episode, score, ... } ]
        if let result = tryFlatRecords(data) { return result }
        return [:]
    }

    // MARK: Shape 1 — { "episodes": { "1": { "average": X, "total": N } } }
    private static func tryKeyedDict(_ data: Data) -> [Int: EpisodeRatingSummary]? {
        struct Root: Decodable {
            let episodes: [String: Entry]?
            struct Entry: Decodable {
                let average: Double?
                let total: Int?
                let count: Int?
                let ratings: [IndividualRecord]?
            }
        }
        guard let root = try? JSONDecoder().decode(Root.self, from: data),
              let episodes = root.episodes, !episodes.isEmpty else { return nil }
        var result: [Int: EpisodeRatingSummary] = [:]
        for (key, entry) in episodes {
            guard let ep = Int(key) else { continue }
            let avg: Double
            if let a = entry.average { avg = a }
            else if let recs = entry.ratings, !recs.isEmpty {
                avg = Double(recs.map { $0.score ?? 0 }.reduce(0, +)) / Double(recs.count)
            } else { continue }
            result[ep] = EpisodeRatingSummary(average: avg, total: entry.total ?? entry.count ?? entry.ratings?.count ?? 0)
        }
        return result.isEmpty ? nil : result
    }

    // MARK: Shape 2 — { "items": [ { "episode": 1, "average": X, "total": N } ] }
    private static func tryItemsArray(_ data: Data) -> [Int: EpisodeRatingSummary]? {
        struct Root: Decodable { let items: [SummaryRow] }
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else { return nil }
        return buildFromSummaryRows(root.items)
    }

    // MARK: Shape 3 — [ { "episode": 1, "average": X, "total": N } ]
    private static func tryRootSummaryArray(_ data: Data) -> [Int: EpisodeRatingSummary]? {
        guard let rows = try? JSONDecoder().decode([SummaryRow].self, from: data) else { return nil }
        return buildFromSummaryRows(rows)
    }

    private static func buildFromSummaryRows(_ rows: [SummaryRow]) -> [Int: EpisodeRatingSummary]? {
        guard !rows.isEmpty else { return nil }
        var result: [Int: EpisodeRatingSummary] = [:]
        for row in rows {
            guard let ep = row.episode, let avg = row.average else { continue }
            result[ep] = EpisodeRatingSummary(average: avg, total: row.total ?? row.count ?? 0)
        }
        return result.isEmpty ? nil : result
    }

    // MARK: Shape 4 — flat individual records [ { id, episode, score, ... } ]
    private static func tryFlatRecords(_ data: Data) -> [Int: EpisodeRatingSummary]? {
        guard let records = try? JSONDecoder().decode([IndividualRecord].self, from: data),
              !records.isEmpty else { return nil }
        let grouped = Dictionary(grouping: records) { $0.episode ?? 0 }
        var result: [Int: EpisodeRatingSummary] = [:]
        for (ep, recs) in grouped where ep > 0 {
            let scores = recs.compactMap { $0.score }
            guard !scores.isEmpty else { continue }
            let avg = Double(scores.reduce(0, +)) / Double(scores.count)
            result[ep] = EpisodeRatingSummary(average: avg, total: scores.count)
        }
        return result.isEmpty ? nil : result
    }

    // Shared intermediate models
    private struct SummaryRow: Decodable {
        let episode: Int?
        let average: Double?
        let total: Int?
        let count: Int?
    }

    struct IndividualRecord: Decodable {
        let episode: Int?
        let score: Int?
        enum CodingKeys: String, CodingKey { case episode, score }
    }
}

// MARK: - Legacy types (kept for backward compat with other callers)

struct EpisodeRatingBatchEntry: Decodable {
    let average: Double?
    let total: Int?
    let ratings: [EpisodeRating]?

    enum CodingKeys: String, CodingKey { case average, total, ratings, count }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        average = try c.decodeIfPresent(Double.self, forKey: .average)
        total   = try c.decodeIfPresent(Int.self,    forKey: .total) ??
                  c.decodeIfPresent(Int.self, forKey: .count)
        ratings = try c.decodeIfPresent([EpisodeRating].self, forKey: .ratings)
    }
}

struct BatchEpisodeRatingsResponse: Decodable {
    let episodesByNumber: [String: EpisodeRatingBatchEntry]

    enum CodingKeys: String, CodingKey { case episodes }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        episodesByNumber = (try? c.decodeIfPresent([String: EpisodeRatingBatchEntry].self, forKey: .episodes)) ?? [:]
    }
}

struct SeasonRatingSummary: Codable {
    let average: Double?
    let count: Int?
}

