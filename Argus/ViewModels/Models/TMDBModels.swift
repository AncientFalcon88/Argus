import Foundation

struct TMDBMediaItem: Identifiable, Hashable {
    let id: String
    let tmdbId: Int
    let mediaType: MediaType
    let title: String
    let overview: String
    let year: String
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let voteCount: Int
    var releaseDate: String? = nil
    var genreIds: [Int]? = nil
    var originalLanguage: String? = nil
    var originCountry: [String]? = nil
    var department: String? = nil

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: Config.tmdbImageBase + posterPath)
    }

    var backdropURL: URL? {
        guard let backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w780" + backdropPath)
    }
}

struct TMDBPageResponse: Codable {
    let page: Int?
    let totalPages: Int?
    let results: [TMDBResult]?
    let items: [TMDBResult]?

    enum CodingKeys: String, CodingKey {
        case page
        case totalPages = "total_pages"
        case results
        case items
    }

    func mediaItems(defaultKind: MediaType) -> [TMDBMediaItem] {
        (results ?? items ?? []).map { $0.mediaItem(defaultKind: defaultKind) }
    }

    func discoverResult(filters: DiscoverFilters) -> TMDBDiscoverResult {
        TMDBDiscoverResult(
            items: mediaItems(defaultKind: filters.mediaType),
            page: page ?? filters.page,
            totalPages: max(totalPages ?? 1, 1)
        )
    }
}

struct TMDBDiscoverResult {
    let items: [TMDBMediaItem]
    let page: Int
    let totalPages: Int
}

struct TMDBResult: Codable {
    let id: Int?
    let tmdbId: Int?
    let mediaType: String?
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let voteCount: Int?
    
    // Credit specific fields
    let character: String?
    let job: String?
    let department: String?
    let episodeCount: Int?
    
    // Person fields
    let profilePath: String?
    let knownForDepartment: String?
    
    // Additional Metadata
    let genreIds: [Int]?
    let originalLanguage: String?
    let originCountry: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case title, name, overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        
        case character, job, department
        case episodeCount = "episode_count"
        
        case profilePath = "profile_path"
        case knownForDepartment = "known_for_department"
        
        case genreIds = "genre_ids"
        case originalLanguage = "original_language"
        case originCountry = "origin_country"
    }

    func mediaItem(defaultKind: MediaType) -> TMDBMediaItem {
        let kind: MediaType = mediaType == "tv" ? .tv : (mediaType == "movie" ? .movie : (mediaType == "person" ? .person : defaultKind))
        let resolvedId = tmdbId ?? id ?? 0
        let resolvedTitle = title ?? name ?? "Untitled"
        let date = releaseDate ?? firstAirDate ?? ""
        let year = String(date.prefix(4))
        
        let finalPosterPath = kind == .person ? (profilePath ?? posterPath) : posterPath
        let finalDepartment = kind == .person ? knownForDepartment : (department ?? job)
        
        return TMDBMediaItem(
            id: "\(kind.rawValue)-\(resolvedId)",
            tmdbId: resolvedId,
            mediaType: kind,
            title: resolvedTitle,
            overview: overview ?? "",
            year: year,
            posterPath: finalPosterPath,
            backdropPath: backdropPath,
            voteAverage: voteAverage ?? 0,
            voteCount: voteCount ?? 0,
            releaseDate: date.isEmpty ? nil : date,
            genreIds: genreIds,
            originalLanguage: originalLanguage,
            originCountry: originCountry,
            department: finalDepartment
        )
    }
}

struct DiscoverFilters: Equatable {
    var mediaType: MediaType = .movie
    var sortBy: String = "popularity.desc"
    var selectedGenres: Set<Int> = []
    var startYear: Int = 1980
    var endYear: Int = 2026
    var page: Int = 1
    
    // Quick Toggles
    var postersOnly: Bool = false
    var ratedOnly: Bool = false
    var isMustSee: Bool = false
    var isNoAnimation: Bool = false
    var isEnglishOnly: Bool = false
    var isNonEnglish: Bool = false
    
    // Advanced Drops
    var watchRegion: String = "Anywhere"
    var watchProviders: Set<Int> = []
    var selectedStudios: [TMDBStudio] = []
    var selectedPeople: [TMDBPerson] = []
    var minRuntime: Int?
    var maxRuntime: Int?
    var ageRating: String?

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "sort_by", value: sortBy)
        ]
        
        if !selectedGenres.isEmpty {
            let ids = selectedGenres.map(String.init).joined(separator: ",")
            items.append(URLQueryItem(name: "with_genres", value: ids))
        }
        
        if isMustSee {
            items.append(URLQueryItem(name: "vote_average.gte", value: "7.5"))
            items.append(URLQueryItem(name: "vote_count.gte", value: "1000"))
        }
        
        if isNoAnimation {
            items.append(URLQueryItem(name: "without_genres", value: "16"))
        }
        if isEnglishOnly {
            items.append(URLQueryItem(name: "with_original_language", value: "en"))
        }
        if isNonEnglish {
            items.append(URLQueryItem(name: "without_original_language", value: "en"))
        }
        
        if watchRegion != "Anywhere" {
            items.append(URLQueryItem(name: "watch_region", value: watchRegion))
            if !watchProviders.isEmpty {
                let ids = watchProviders.map(String.init).joined(separator: "|")
                items.append(URLQueryItem(name: "with_watch_providers", value: ids))
            }
        }
        
        if !selectedStudios.isEmpty {
            let ids = selectedStudios.map { String($0.id) }.joined(separator: ",")
            items.append(URLQueryItem(name: "with_companies", value: ids))
        }
        if !selectedPeople.isEmpty {
            let ids = selectedPeople.map { String($0.id) }.joined(separator: ",")
            items.append(URLQueryItem(name: "with_people", value: ids))
        }
        if let minRt = minRuntime {
            items.append(URLQueryItem(name: "with_runtime.gte", value: "\(minRt)"))
        }
        if let maxRt = maxRuntime {
            items.append(URLQueryItem(name: "with_runtime.lte", value: "\(maxRt)"))
        }
        
        if let rating = ageRating, rating != "Any" {
            items.append(URLQueryItem(name: "certification_country", value: "US"))
            items.append(URLQueryItem(name: "certification", value: rating))
        }
        
        if mediaType == .movie {
            items.append(URLQueryItem(name: "primary_release_date.gte", value: "\(startYear)-01-01"))
            items.append(URLQueryItem(name: "primary_release_date.lte", value: "\(endYear)-12-31"))
        } else {
            items.append(URLQueryItem(name: "first_air_date.gte", value: "\(startYear)-01-01"))
            items.append(URLQueryItem(name: "first_air_date.lte", value: "\(endYear)-12-31"))
        }
        return items
    }
}

// MARK: - Filter Models

struct TMDBCountry: Codable, Identifiable, Hashable {
    let iso_3166_1: String
    let english_name: String
    var id: String { iso_3166_1 }
}

struct TMDBProvider: Codable, Identifiable, Hashable {
    let provider_id: Int
    let provider_name: String
    let logo_path: String?
    var id: Int { provider_id }
}

struct TMDBProviderResponse: Codable {
    let results: [TMDBProvider]
}

struct TMDBPerson: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let profile_path: String?
    let known_for_department: String?
}

struct TMDBPersonSearchResponse: Codable {
    let results: [TMDBPerson]
}

// MARK: - Person Details

struct TMDBPersonDetailResponse: Codable {
    let id: Int
    let name: String
    let biography: String?
    let birthday: String?
    let deathday: String?
    let placeOfBirth: String?
    let profilePath: String?
    let knownForDepartment: String?
    
    let combinedCredits: TMDBPersonCredits?
    let images: TMDBPersonImages?
    
    enum CodingKeys: String, CodingKey {
        case id, name, biography, birthday, deathday
        case placeOfBirth = "place_of_birth"
        case profilePath = "profile_path"
        case knownForDepartment = "known_for_department"
        case combinedCredits = "combined_credits"
        case images
    }
}

struct TMDBPersonCredits: Codable {
    let cast: [TMDBResult]?
    let crew: [TMDBResult]?
}

struct TMDBPersonImages: Codable {
    let profiles: [TMDBProfileImage]?
}

struct TMDBProfileImage: Codable, Identifiable {
    let filePath: String
    var id: String { filePath }
    
    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
    }
}

struct TMDBStudio: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let logo_path: String?
}

struct TMDBStudioSearchResponse: Codable {
    let results: [TMDBStudio]
}

struct TMDBFindResponse: Codable {
    let movieResults: [TMDBResult]?
    let tvResults: [TMDBResult]?
    
    enum CodingKeys: String, CodingKey {
        case movieResults = "movie_results"
        case tvResults = "tv_results"
    }
}

struct TMDBExternalIDsResponse: Codable {
    let id: Int
    let imdb_id: String?
    let tvdb_id: Int?
}

// MARK: - Processed Credits
struct PersonCreditItem: Identifiable {
    let id = UUID()
    let mediaItem: TMDBMediaItem
    
    let department: String
    let role: String // character or job
    let episodeCount: Int?
    
    var sortDate: Date {
        // Since year in TMDBMediaItem is just "YYYY", we can sort by that as a string/integer, or we can use the full releaseDate from TMDBResult.
        // Actually, let's just keep a raw releaseDate string for robust sorting.
        return Date() // will be populated correctly
    }
    
    let rawDate: String
    let yearString: String
}
