import Foundation

struct PickCatalog: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let seedType: String?
    let updatedAt: String?
    
    let filters: PickFilters?
    let weights: PickWeights?
    let seedParams: PickSeedParams?
    let excludeWatched: Bool?
    let excludeWatchlist: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case seedType = "seed_type"
        case updatedAt = "updated_at"
        case filters, weights
        case seedParams = "seed_params"
        case excludeWatched = "exclude_watched"
        case excludeWatchlist = "exclude_watchlist"
    }
}

struct CatalogsResponse: Codable {
    let items: [PickCatalog]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([PickCatalog].self, forKey: .items) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case items
    }
}

struct CatalogItem: Codable, Identifiable, Hashable {
    let _id: String?
    var id: String { _id ?? "\(mediaType.rawValue)-\(tmdbId)" }
    let tmdbId: Int
    let mediaType: MediaType
    let title: String?
    let posterPath: String?
    let backdropPath: String?
    let matchScore: Double?
    let voteAverage: Double?
    let year: String?
    
    let matchReasons: [String]?
    let voteCount: Int?
    let popularityScore: Double?
    let originalLanguage: String?

    var calculatedPercentage: String {
        let score = matchScore ?? 0.0
        let percentage = min(Int(round(score * 25)), 100)
        return "\(percentage)%"
    }

    init(
        id: String? = nil,
        tmdbId: Int,
        mediaType: MediaType,
        title: String?,
        posterPath: String?,
        backdropPath: String?,
        matchScore: Double?,
        voteAverage: Double? = nil,
        year: String? = nil,
        matchReasons: [String]? = nil,
        voteCount: Int? = nil,
        popularityScore: Double? = nil,
        originalLanguage: String? = nil
    ) {
        self._id = id
        self.tmdbId = tmdbId
        self.mediaType = mediaType
        self.title = title
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.matchScore = matchScore
        self.voteAverage = voteAverage
        self.year = year
        self.matchReasons = matchReasons
        self.voteCount = voteCount
        self.popularityScore = popularityScore
        self.originalLanguage = originalLanguage
    }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case title
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case matchScore = "score"
        case voteAverage = "vote_average"
        case year
        case matchReasons = "reasons"
        case voteCount = "vote_count"
        case popularityScore = "popularity"
        case originalLanguage = "original_language"
    }

    func toMediaItem() -> TMDBMediaItem {
        return TMDBMediaItem(
            id: self.id,
            tmdbId: self.tmdbId,
            mediaType: self.mediaType,
            title: self.title ?? "",
            overview: "", // Not available in CatalogItem
            year: self.year ?? "",
            posterPath: self.posterPath,
            backdropPath: self.backdropPath,
            voteAverage: self.voteAverage ?? 0.0,
            voteCount: self.voteCount ?? 0
        )
    }
}

struct CatalogItemsResponse: Codable {
    let items: [CatalogItem]
    let page: Int?
    let totalPages: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([CatalogItem].self, forKey: .items) ?? []
        page = try container.decodeIfPresent(Int.self, forKey: .page)
        totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages)
    }

    enum CodingKeys: String, CodingKey {
        case items, page, totalPages
    }
}

// MARK: - Create Pick API Models

struct CreatePickRequest: Codable {
    let name: String
    let description: String?
    let seed_type: String
    let seed_params: PickSeedParams?
    let filters: PickFilters
    let weights: PickWeights
    let exclude_watched: Bool
    let exclude_watchlist: Bool
}

/// Parameters that vary per recipe type — sent as `seed_params` in the request body
struct PickSeedParams: Codable, Hashable, Equatable {
    var moods: [String]?           // byMood
    var similar_ids: [SimilarItem]?  // similarTo
    var year_min: Int?             // byEra (seed-level)
    var year_max: Int?

    init(moods: [String]? = nil, similar_ids: [SimilarItem]? = nil, year_min: Int? = nil, year_max: Int? = nil) {
        self.moods = moods
        self.similar_ids = similar_ids
        self.year_min = year_min
        self.year_max = year_max
    }
}

struct SimilarItem: Codable, Hashable, Equatable {
    let tmdb_id: Int
    let media_type: String
}

struct PickFilters: Codable, Hashable, Equatable {
    var media_types: [String]?
    var min_vote_count: Int?
    var min_vote_average: Double?
    var year_min: Int?
    var year_max: Int?
    var with_genres: [String]?
    var without_genres: [String]?
    var with_keywords: [String]?
    var exclude_keywords: [String]?
    var languages: [String]?
    var exclude_languages: [String]?
    var with_watch_providers: [Int]?
    var watch_region: String?
    var certification_country: String?
    var certification_lte: String?
    var with_companies: [String]?
    var runtime_min: Int?
    var runtime_max: Int?
    var sort_by: String?
    var audience: String?           // "auto" | "adult" | "kids"

    init(
        media_types: [String]? = nil,
        min_vote_count: Int? = nil,
        min_vote_average: Double? = nil,
        year_min: Int? = nil,
        year_max: Int? = nil,
        with_genres: [String]? = nil,
        without_genres: [String]? = nil,
        with_keywords: [String]? = nil,
        exclude_keywords: [String]? = nil,
        languages: [String]? = nil,
        exclude_languages: [String]? = nil,
        with_watch_providers: [Int]? = nil,
        watch_region: String? = nil,
        certification_country: String? = nil,
        certification_lte: String? = nil,
        with_companies: [String]? = nil,
        runtime_min: Int? = nil,
        runtime_max: Int? = nil,
        sort_by: String? = nil,
        audience: String? = nil
    ) {
        self.media_types = media_types
        self.min_vote_count = min_vote_count
        self.min_vote_average = min_vote_average
        self.year_min = year_min
        self.year_max = year_max
        self.with_genres = with_genres
        self.without_genres = without_genres
        self.with_keywords = with_keywords
        self.exclude_keywords = exclude_keywords
        self.languages = languages
        self.exclude_languages = exclude_languages
        self.with_watch_providers = with_watch_providers
        self.watch_region = watch_region
        self.certification_country = certification_country
        self.certification_lte = certification_lte
        self.with_companies = with_companies
        self.runtime_min = runtime_min
        self.runtime_max = runtime_max
        self.sort_by = sort_by
        self.audience = audience
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.media_types = try container.decodeIfPresent([String].self, forKey: .media_types)
        self.min_vote_count = try container.decodeIfPresent(Int.self, forKey: .min_vote_count)
        self.min_vote_average = try container.decodeIfPresent(Double.self, forKey: .min_vote_average)
        self.year_min = try container.decodeIfPresent(Int.self, forKey: .year_min)
        self.year_max = try container.decodeIfPresent(Int.self, forKey: .year_max)
        
        // Flexible decoding for with_genres
        if let strings = try? container.decodeIfPresent([String].self, forKey: .with_genres) {
            self.with_genres = strings
        } else if let ints = try? container.decodeIfPresent([Int].self, forKey: .with_genres) {
            self.with_genres = ints.map { String($0) }
        }
        
        // Flexible decoding for without_genres
        if let strings = try? container.decodeIfPresent([String].self, forKey: .without_genres) {
            self.without_genres = strings
        } else if let ints = try? container.decodeIfPresent([Int].self, forKey: .without_genres) {
            self.without_genres = ints.map { String($0) }
        }
        
        self.with_keywords = try container.decodeIfPresent([String].self, forKey: .with_keywords)
        self.exclude_keywords = try container.decodeIfPresent([String].self, forKey: .exclude_keywords)
        self.languages = try container.decodeIfPresent([String].self, forKey: .languages)
        self.exclude_languages = try container.decodeIfPresent([String].self, forKey: .exclude_languages)
        self.with_watch_providers = try container.decodeIfPresent([Int].self, forKey: .with_watch_providers)
        self.watch_region = try container.decodeIfPresent(String.self, forKey: .watch_region)
        self.certification_country = try container.decodeIfPresent(String.self, forKey: .certification_country)
        self.certification_lte = try container.decodeIfPresent(String.self, forKey: .certification_lte)
        
        // Flexible decoding for with_companies
        if let strings = try? container.decodeIfPresent([String].self, forKey: .with_companies) {
            self.with_companies = strings
        } else if let ints = try? container.decodeIfPresent([Int].self, forKey: .with_companies) {
            self.with_companies = ints.map { String($0) }
        }
        
        self.runtime_min = try container.decodeIfPresent(Int.self, forKey: .runtime_min)
        self.runtime_max = try container.decodeIfPresent(Int.self, forKey: .runtime_max)
        self.sort_by = try container.decodeIfPresent(String.self, forKey: .sort_by)
        self.audience = try container.decodeIfPresent(String.self, forKey: .audience)
    }
}

struct PickWeights: Codable, Hashable, Equatable {
    var genre: Double?
    var keyword: Double?
    var people: Double?
    var quality: Double?
    var popularity: Double?
    var novelty: Double?
    var recency: Double?
    var era: Double?
    var language: Double?
}
