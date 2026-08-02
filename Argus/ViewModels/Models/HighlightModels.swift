import Foundation

struct Highlight: Codable, Identifiable, Hashable {
    let id: String
    let tmdbId: Int
    let mediaType: MediaType
    let season: Int?
    let episode: Int?
    let highlightStartMs: Int
    let highlightEndMs: Int
    let description: String?
    
    var contributor: String?
    var created: String?
    var voteCount: Int?
    var userVote: Int?
    var isOwner: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case season, episode
        case highlightStartMs = "highlight_start_ms"
        case highlightEndMs = "highlight_end_ms"
        case description
        case contributor, created
        case voteCount = "vote_count"
        case userVote = "user_vote"
        case isOwner = "is_owner"
    }
}

extension Highlight {
    var displayStart: String {
        formatMs(highlightStartMs)
    }
    
    var displayEnd: String {
        formatMs(highlightEndMs)
    }
    
    var dateString: String? {
        guard let created = created else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: created) {
            let outFormatter = DateFormatter()
            outFormatter.dateStyle = .short
            return outFormatter.string(from: date)
        }
        
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        if let date = simpleFormatter.date(from: String(created.prefix(10))) {
            let outFormatter = DateFormatter()
            outFormatter.dateStyle = .short
            return outFormatter.string(from: date)
        }
        return created
    }
    
    private func formatMs(_ ms: Int) -> String {
        guard ms > 0 else { return "00:00" }
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct HighlightsResponse: Codable {
    let highlights: [Highlight]?
    let items: [Highlight]?
    let page: Int?
    let perPage: Int?
    let totalPages: Int?
    let totalItems: Int?
    let total: Int?

    var all: [Highlight] { highlights ?? items ?? [] }
}

struct CreateHighlightRequest: Codable {
    let tmdbId: Int
    let mediaType: MediaType
    let season: Int?
    let episode: Int?
    let highlightStartMs: Int
    let highlightEndMs: Int
    let description: String?

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case season, episode
        case highlightStartMs = "highlight_start_ms"
        case highlightEndMs = "highlight_end_ms"
        case description
    }
}

