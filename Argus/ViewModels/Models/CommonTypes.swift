import Foundation

// MARK: - Core Common Types

enum MediaType: String, Codable, CaseIterable, Identifiable {
    var id: String { self.rawValue }
    var title: String {
        switch self {
        case .movie: return "Movie"
        case .tv: return "Series"
        case .person: return "Person"
        }
    }
    case movie = "movie"
    case tv = "tv"
    case person = "person"
}

struct NamedItem: Identifiable, Hashable {
    let id: Int
    let name: String
    let code: String?
    
    init(id: Int, name: String, code: String? = nil) {
        self.id = id
        self.name = name
        self.code = code
    }
}

enum AudienceType: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case kids = "Kids"
    case family = "Family"
    case teens = "Teens"
    case adults = "Adults"
    
    var id: String { self.rawValue }
}

enum PickRecipeType: String, CaseIterable, Identifiable {
    case byMood = "By Mood"
    case similarTo = "Similar To..."
    case hiddenGems = "Hidden Gems"
    case criticallyAcclaimed = "Critically Acclaimed"
    case boxOfficeSmash = "Box Office Smash"
    case cultClassics = "Cult Classics"
    case customized = "Customized"
    case byEra = "By Era" // Added this

    var id: String { self.rawValue }

    var apiSeedType: String {
        switch self {
        case .byMood: return "mood"
        case .similarTo: return "similar"
        case .hiddenGems: return "hidden_gems"
        case .criticallyAcclaimed: return "critically_acclaimed"
        case .boxOfficeSmash: return "box_office"
        case .cultClassics: return "cult_classics"
        case .customized: return "custom"
        case .byEra: return "era" // Added this
        }
    }
    
    var icon: String {
        switch self {
        case .byMood: return "face.smiling"
        case .similarTo: return "sparkles.rectangle.stack"
        case .hiddenGems: return "diamond"
        case .criticallyAcclaimed: return "star.circle"
        case .boxOfficeSmash: return "ticket"
        case .cultClassics: return "film"
        case .customized: return "slider.horizontal.3"
        case .byEra: return "clock" // Added this
        }
    }
    
    var description: String {
        switch self {
        case .byMood: return "Pick the perfect title for how you're feeling right now."
        case .similarTo: return "Find movies or shows that match the vibe of your favorites."
        case .hiddenGems: return "Discover highly-rated but lesser-known titles you might have missed."
        case .criticallyAcclaimed: return "Explore the highest-rated masterpieces across genres."
        case .boxOfficeSmash: return "Enjoy the biggest hits and crowd-pleasing blockbusters."
        case .cultClassics: return "Dive into movies and shows with dedicated, passionate fanbases."
        case .customized: return "Create a completely custom pick using advanced filters and weights."
        case .byEra: return "Take a trip back in time to your favorite decade of entertainment." // Added this
        }
    }
}

enum ExternalIDType: String, Codable, CaseIterable {
    case imdb = "imdb"
    case tvdb = "tvdb"
    case tmdb = "tmdb"
    case trakt = "trakt"
    case traktSlug = "trakt_slug"
    case justWatch = "justwatch"
    case rottenTomatoes = "rottentomatoes"
    case metacritic = "metacritic"
    case letterboxd = "letterboxd"
    case mal = "mal"
    case anilist = "anilist"
    case anidb = "anidb"
    case tmdbSeason = "tmdb_season"
    case tmdbEpisode = "tmdb_episode"
    
    var displayLabel: String {
        switch self {
        case .imdb: return "IMDB"
        case .tvdb: return "TVDB"
        case .trakt: return "Trakt"
        case .traktSlug: return "Trakt Slug"
        case .justWatch: return "JustWatch"
        case .rottenTomatoes: return "Rotten Tomatoes"
        case .metacritic: return "Metacritic"
        case .letterboxd: return "Letterboxd"
        case .mal: return "MAL"
        case .anilist: return "AniList"
        case .anidb: return "AniDB"
        case .tmdb: return "TMDB"
        case .tmdbSeason: return "TMDB Season"
        case .tmdbEpisode: return "TMDB Episode"
        }
    }
}

enum SkipSource: String, Codable {
    case discover = "discover"
    case picks = "picks"
    case feed = "feed"
    case lists = "lists"
    case streaming = "streaming"
    case physical = "physical"
}

enum VoteValue: String, Codable {
    case up = "up"
    case down = "down"
    case remove = "remove"
}

struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let total: Int?
    let page: Int?
    let pages: Int?

    enum CodingKeys: String, CodingKey {
        case items
        case data
        case total
        case totalItems = "totalItems"
        case total_items = "total_items"
        case page
        case pages
        case totalPages = "totalPages"
        case total_pages = "total_pages"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        do {
            if let itemsArr = try container.decodeIfPresent([T].self, forKey: .items) {
                items = itemsArr
            } else if let dataArr = try container.decodeIfPresent([T].self, forKey: .data) {
                items = dataArr
            } else {
                items = []
            }
        } catch {
            print("[PaginatedResponse] Failed to decode items array: \(error)")
            items = []
        }
        
        total = (try? container.decodeIfPresent(Int.self, forKey: .total)) ?? 
                (try? container.decodeIfPresent(Int.self, forKey: .totalItems)) ?? 
                (try? container.decodeIfPresent(Int.self, forKey: .total_items))
                
        page = try? container.decodeIfPresent(Int.self, forKey: .page)
        
        pages = (try? container.decodeIfPresent(Int.self, forKey: .pages)) ?? 
                (try? container.decodeIfPresent(Int.self, forKey: .totalPages)) ?? 
                (try? container.decodeIfPresent(Int.self, forKey: .total_pages))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
        if let total { try container.encode(total, forKey: .total) }
        if let page { try container.encode(page, forKey: .page) }
        if let pages { try container.encode(pages, forKey: .pages) }
    }
}

enum ListType: String, Codable {
    case custom = "custom"
    case system = "system"
    case dynamic = "dynamic"
    case watchlist = "watchlist"
    case history = "history"
    case favorites = "favorites"
}

struct APIActionResponse: Codable {
    let success: Bool?
    let message: String?
    /// The ID of the created/affected item.
    /// Some endpoints return it as top-level "id", others nest it inside "item": {"id": ...}
    let id: String?
    
    private enum CodingKeys: String, CodingKey {
        case success, message, id, item
    }
    
    private struct NestedItem: Decodable {
        let id: String?
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try? c.decodeIfPresent(Bool.self, forKey: .success)
        message = try? c.decodeIfPresent(String.self, forKey: .message)
        // Try top-level "id" first, then fall back to nested "item.id"
        if let topId = try? c.decodeIfPresent(String.self, forKey: .id) {
            id = topId
        } else if let nested = try? c.decodeIfPresent(NestedItem.self, forKey: .item) {
            id = nested.id
        } else {
            id = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try? c.encodeIfPresent(success, forKey: .success)
        try? c.encodeIfPresent(message, forKey: .message)
        try? c.encodeIfPresent(id, forKey: .id)
    }
}
