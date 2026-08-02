import Foundation

struct MediaList: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let isPublic: Bool
    let type: ListType?
    var itemCount: Int?
    let createdAt: String?
    let updatedAt: String?
    var creatorName: String?
    var creatorAvatar: String?
    var creatorId: String?
    var user: String?
    var previewItems: [ListItem] = []
    var previewPosters: [URL?] = []
    
    struct EmptyPayload: Codable {}

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case isPublic = "is_public"
        case type
        case itemCount
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case user
        case expand
    }
    
    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }
    
    struct Expand: Codable, Hashable {
        struct User: Codable, Hashable {
            let id: String?
            let username: String?
            let name: String?
            let avatar: String?
            
            var displayName: String? {
                if let n = name, !n.isEmpty { return n }
                return username
            }
        }
        struct ListItemSummary: Codable, Hashable {
            let tmdb_id: Int
            let media_type: MediaType
        }
        let user: User?
        let list_items_via_list: [ListItemSummary]?
    }
    var expand: Expand?

    init(
        id: String,
        name: String,
        description: String?,
        isPublic: Bool,
        type: ListType?,
        itemCount: Int?,
        createdAt: String?,
        updatedAt: String?,
        creatorName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isPublic = isPublic
        self.type = type
        self.itemCount = itemCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.creatorName = creatorName
        self.creatorAvatar = nil
        self.creatorId = nil
        self.user = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? true
        type = try container.decodeIfPresent(ListType.self, forKey: .type)
        user = try container.decodeIfPresent(String.self, forKey: .user)
        itemCount = (try? container.decodeIfPresent(Int.self, forKey: .itemCount)) ??
                    (try? dynamicContainer.decodeIfPresent(Int.self, forKey: DynamicCodingKeys(stringValue: "item_count")!)) ??
                    (try? dynamicContainer.decodeIfPresent(Int.self, forKey: DynamicCodingKeys(stringValue: "total_results")!))
        createdAt = (try? container.decodeIfPresent(String.self, forKey: .createdAt)) ?? 
                    (try? dynamicContainer.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "created")!))
        updatedAt = (try? container.decodeIfPresent(String.self, forKey: .updatedAt)) ?? 
                    (try? dynamicContainer.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "updated")!))
        
        expand = try container.decodeIfPresent(Expand.self, forKey: .expand)
        if let expand = expand {
            creatorName = expand.user?.displayName
            creatorAvatar = expand.user?.avatar
            creatorId = expand.user?.id
            if let listItems = expand.list_items_via_list {
                if itemCount == nil || itemCount == 0 {
                    itemCount = listItems.count
                }
                previewItems = listItems.prefix(6).map { summary in
                    ListItem(
                        id: UUID().uuidString,
                        tmdbId: summary.tmdb_id,
                        mediaType: summary.media_type,
                        title: nil,
                        posterPath: nil,
                        addedAt: nil
                    )
                }
            }
        }
    }
}

struct CreateListRequest: Codable {
    let name: String
    let description: String?
    let isPublic: Bool?
    let type: ListType?

    enum CodingKeys: String, CodingKey {
        case name, description
        case isPublic = "is_public"
        case type
    }
}

struct ListItem: Codable, Identifiable, Hashable {
    let id: String
    let tmdbId: Int
    let mediaType: MediaType
    let title: String?
    let posterPath: String?
    let addedAt: String?
    var year: String?
    var voteAverage: Double?
    var genreIds: [Int]?

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: Config.tmdbImageBase + posterPath)
    }
    
    func toMediaItem() -> TMDBMediaItem {
        TMDBMediaItem(
            id: self.id,
            tmdbId: self.tmdbId,
            mediaType: self.mediaType,
            title: self.title ?? "Unknown",
            overview: "",
            year: self.year ?? "",
            posterPath: self.posterPath,
            backdropPath: nil,
            voteAverage: self.voteAverage ?? 0.0,
            voteCount: 0,
            genreIds: self.genreIds
        )
    }

    init(
        id: String,
        tmdbId: Int,
        mediaType: MediaType,
        title: String?,
        posterPath: String?,
        addedAt: String?,
        year: String? = nil,
        voteAverage: Double? = nil,
        genreIds: [Int]? = nil
    ) {
        self.id = id
        self.tmdbId = tmdbId
        self.mediaType = mediaType
        self.title = title
        self.posterPath = posterPath
        self.addedAt = addedAt
        self.year = year
        self.voteAverage = voteAverage
        self.genreIds = genreIds
    }

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case title
        case posterPath = "poster_path"
        case addedAt = "added_at"
        case year
        case voteAverage = "vote_average"
        case genreIds = "genre_ids"
    }
}

struct AddListItemRequest: Codable {
    let tmdbId: Int
    let mediaType: MediaType

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
    }
}

struct ListsResponse: Codable {
    let items: [MediaList]
    let total: Int?

    // Decode flexibly — the external API and PocketBase use different shapes.
    // Known shapes:
    //   External API: { "items": [...], "total": N }
    //   PocketBase:   { "items": [...], "totalItems": N, "page": N, "perPage": N }
    //   Possibly also: { "data": [...] } or { "results": [...] }
    //   Bare array:   [...]
    init(from decoder: Decoder) throws {
        // First try decoding as a bare array
        if let array = try? [MediaList](from: decoder) {
            self.items = array
            self.total = array.count
            return
        }

        let container = try decoder.container(keyedBy: AnyCodingKey.self)

        // Try all known array keys in priority order
        if let found = try? container.decodeIfPresent([MediaList].self, forKey: AnyCodingKey("items")), !found.isEmpty {
            items = found
        } else if let found = try? container.decodeIfPresent([MediaList].self, forKey: AnyCodingKey("data")), !found.isEmpty {
            items = found
        } else if let found = try? container.decodeIfPresent([MediaList].self, forKey: AnyCodingKey("results")), !found.isEmpty {
            items = found
        } else if let found = try? container.decodeIfPresent([MediaList].self, forKey: AnyCodingKey("lists")), !found.isEmpty {
            items = found
        } else {
            // Last resort: empty list
            items = []
        }

        total = (try? container.decodeIfPresent(Int.self, forKey: AnyCodingKey("total")))
             ?? (try? container.decodeIfPresent(Int.self, forKey: AnyCodingKey("totalItems")))
             ?? (try? container.decodeIfPresent(Int.self, forKey: AnyCodingKey("count")))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        try container.encode(items, forKey: AnyCodingKey("items"))
        try container.encodeIfPresent(total, forKey: AnyCodingKey("total"))
    }
}

// A generic CodingKey that can represent any string key
private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { self.stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}


struct ListItemsResponse: Codable {
    let items: [ListItem]
    let total: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([ListItem].self, forKey: .items) ?? []
        total = try container.decodeIfPresent(Int.self, forKey: .total)
    }

    enum CodingKeys: String, CodingKey {
        case items, total
    }
}

