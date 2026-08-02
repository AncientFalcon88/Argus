import Foundation

final class APIService: Sendable {
    static let shared = APIService()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": "Argus/1.0 iOS"
        ]
        self.session = URLSession(configuration: configuration)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Resume

    func fetchResumePoints(query: ResumeQuery = ResumeQuery()) async throws -> PaginatedResponse<ResumePoint> {
        let data = try await getRawData("/api/external/resume", query: query.queryItems)
        print("[CW] Raw resume: \(String(data: data, encoding: .utf8) ?? "nil")")
        return try decoder.decode(PaginatedResponse<ResumePoint>.self, from: data)
    }

    func saveResumePoint(_ request: SaveResumeRequest) async throws -> APIActionResponse {
        try await post("/api/external/resume", body: request)
    }

    func batchSaveResumePoints(_ request: BatchSaveResumeRequest) async throws -> BatchSaveResumeResponse {
        try await post("/api/external/resume/batch", body: request)
    }

    func deleteResumePoint(id: String) async throws {
        try await delete("/api/external/resume/\(id)")
    }

    // MARK: - Watch History

    func fetchWatchHistory(
        page: Int = 1,
        perPage: Int = Config.defaultPerPage,
        tmdbId: Int? = nil,
        mediaType: MediaType? = nil
    ) async throws -> PaginatedResponse<WatchEntry> {
        var query = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perPage", value: "\(perPage)"),
            URLQueryItem(name: "sort", value: "-created")
        ]
        if let tmdbId { query.append(URLQueryItem(name: "tmdb_id", value: "\(tmdbId)")) }
        if let mediaType { query.append(URLQueryItem(name: "media_type", value: mediaType.rawValue)) }
        return try await get("/api/external/watched", query: query)
    }

    func markAsWatched(_ request: MarkWatchedRequest, dedupe: Bool = false, notify: Bool = true) async throws -> APIActionResponse {
        var query: [URLQueryItem] = []
        if dedupe {
            query.append(URLQueryItem(name: "dedupe", value: "true"))
        }
        
        let response: APIActionResponse = try await post("/api/external/watched", query: query, body: request)
        
        if notify {
            await MainActor.run {
                NotificationCenter.default.post(name: .watchStateDidChange, object: nil)
            }
        }
        
        return response
    }

    func editWatchDate(id: String, request: EditWatchDateRequest) async throws -> APIActionResponse {
        try await patch("/api/external/watched/\(id)", body: request)
    }

    func deleteWatchEntry(id: String) async throws {
        try await delete("/api/external/watched/\(id)")
        await MainActor.run {
            NotificationCenter.default.post(name: .watchStateDidChange, object: nil)
        }
    }

    func bulkDeleteWatchHistory(query: WatchedBulkDeleteQuery) async throws {
        try await delete("/api/external/watched", query: query.queryItems)
        await MainActor.run {
            NotificationCenter.default.post(name: .watchStateDidChange, object: nil)
        }
    }

    // MARK: - Skips

    func fetchSkips(tmdbId: Int, mediaType: MediaType, season: Int? = nil, episode: Int? = nil, source: SkipSource? = nil) async throws -> SkipsResponse {
        var query = [
            URLQueryItem(name: "tmdb_id", value: "\(tmdbId)"),
            URLQueryItem(name: "media_type", value: mediaType.rawValue)
        ]
        if let season { query.append(URLQueryItem(name: "season", value: "\(season)")) }
        if let episode { query.append(URLQueryItem(name: "episode", value: "\(episode)")) }
        if let source { query.append(URLQueryItem(name: "source", value: source.rawValue)) }
        let data = try await getRawData("/api/external/skips", query: query)
        return try decoder.decode(SkipsResponse.self, from: data)
    }

    func createSkip(_ request: CreateSkipRequest) async throws -> APIActionResponse {
        try await post("/api/external/skips", body: request)
    }

    func deleteSkip(id: String) async throws {
        try await delete("/api/external/skips/\(id)")
    }

    // MARK: - Ratings

    func fetchRatings(tmdbId: Int, mediaType: MediaType, label: String? = nil) async throws -> RatingsResponse {
        let token = Config.apiKey
        
        guard !token.isEmpty else {
            return RatingsResponse(items: [])
        }

        var query = [
            URLQueryItem(name: "tmdb_id", value: "\(tmdbId)"),
            URLQueryItem(name: "media_type", value: mediaType.rawValue)
        ]
        if let label { query.append(URLQueryItem(name: "label", value: label)) }
        
        do {
            let data = try await getRawData("/api/external/ratings", query: query)
            print("[Ratings DEBUG] Body: \(String(data: data, encoding: .utf8) ?? "nil")")
            return try decoder.decode(RatingsResponse.self, from: data)
        } catch let error as APIError {
            if case .serverError(let status, _) = error {
                print("[Ratings DEBUG] Status: \(status)")
            }
            throw error
        }
    }

    func createRating(_ request: CreateRatingRequest) async throws -> APIActionResponse {
        try await post("/api/external/ratings", body: request)
    }

    func deleteRating(id: String) async throws {
        try await delete("/api/external/ratings/\(id)")
    }

    // MARK: - Episode Ratings

    func fetchEpisodeRatings(tmdbId: Int, mediaType: MediaType, season: Int? = nil, episode: Int? = nil, label: String? = nil, perPage: Int = 30) async throws -> EpisodeRatingsResponse {
        var query = [
            URLQueryItem(name: "tmdb_id", value: "\(tmdbId)"),
            URLQueryItem(name: "media_type", value: mediaType.rawValue),
            URLQueryItem(name: "perPage", value: "\(perPage)")
        ]
        if let season { query.append(URLQueryItem(name: "season", value: "\(season)")) }
        if let episode { query.append(URLQueryItem(name: "episode", value: "\(episode)")) }
        if let label { query.append(URLQueryItem(name: "label", value: label)) }
        return try await get("/api/external/episode-ratings", query: query)
    }

    func createEpisodeRating(_ request: CreateEpisodeRatingRequest) async throws -> APIActionResponse {
        try await post("/api/external/episode-ratings", body: request)
    }

    func deleteEpisodeRating(id: String) async throws {
        try await delete("/api/external/episode-ratings/\(id)")
    }

    func batchGetEpisodeRatings(tmdbId: Int, mediaType: MediaType, season: Int, label: String? = nil) async throws -> BatchEpisodeRatingsResponse {
        var query = [
            URLQueryItem(name: "tmdb_id", value: "\(tmdbId)"),
            URLQueryItem(name: "media_type", value: mediaType.rawValue),
            URLQueryItem(name: "season", value: "\(season)")
        ]
        if let label { query.append(URLQueryItem(name: "label", value: label)) }
        return try await get("/api/external/episode-ratings/batch", query: query)
    }

    /// Returns the raw JSON bytes for the batch episode-ratings endpoint so callers
    /// can inspect the response shape and parse defensively.
    func batchGetEpisodeRatingsData(tmdbId: Int, mediaType: MediaType, season: Int) async throws -> Data {
        let query = [
            URLQueryItem(name: "tmdb_id", value: "\(tmdbId)"),
            URLQueryItem(name: "media_type", value: mediaType.rawValue),
            URLQueryItem(name: "season", value: "\(season)")
        ]
        return try await getRawData("/api/external/episode-ratings/batch", query: query)
    }

    func batchCreateEpisodeRatings(_ request: BatchCreateEpisodeRatingsRequest) async throws -> MultiStatusResponse {
        try await post("/api/external/episode-ratings/batch", body: request, acceptMultiStatus: true)
    }

    func batchDeleteEpisodeRatings(_ request: BatchDeleteEpisodeRatingsRequest) async throws -> MultiStatusResponse {
        try await deleteWithBody("/api/external/episode-ratings/batch", body: request, acceptMultiStatus: true)
    }

    // MARK: - Highlights

    func fetchHighlights(tmdbId: Int, mediaType: MediaType, season: Int? = nil, episode: Int? = nil, perPage: Int = 500) async throws -> HighlightsResponse {
        var query = [
            URLQueryItem(name: "tmdb_id", value: "\(tmdbId)"),
            URLQueryItem(name: "media_type", value: mediaType.rawValue),
            URLQueryItem(name: "perPage", value: "\(perPage)")
        ]
        if let season { query.append(URLQueryItem(name: "season", value: "\(season)")) }
        if let episode { query.append(URLQueryItem(name: "episode", value: "\(episode)")) }
        return try await get("/api/external/highlights", query: query)
    }

    func createHighlight(_ request: CreateHighlightRequest) async throws -> APIActionResponse {
        try await post("/api/external/highlights", body: request)
    }

    func deleteHighlight(id: String) async throws {
        try await delete("/api/external/highlights/\(id)")
    }

    // MARK: - Mappings

    func fetchMappings(tmdbId: Int, mediaType: MediaType, idType: ExternalIDType? = nil) async throws -> MappingsResponse {
        var query = [
            URLQueryItem(name: "tmdb_id", value: "\(tmdbId)"),
            URLQueryItem(name: "media_type", value: mediaType.rawValue)
        ]
        if let idType { query.append(URLQueryItem(name: "id_type", value: idType.rawValue)) }
        return try await get("/api/external/mappings", query: query)
    }

    func lookupTMDB(idType: ExternalIDType, idValue: String, mediaType: MediaType? = nil) async throws -> LookupTMDBResponse {
        var query = [
            URLQueryItem(name: "id_type", value: idType.rawValue),
            URLQueryItem(name: "id_value", value: idValue)
        ]
        if let mediaType { query.append(URLQueryItem(name: "media_type", value: mediaType.rawValue)) }
        return try await get("/api/external/mappings/lookup", query: query)
    }

    struct PocketBaseResponse: Codable {
        let id: String
    }

    func createMappingDirect(_ request: PocketBaseMappingRequest) async throws -> PocketBaseResponse {
        try await postPocketBase("/api/collections/media_id_mappings/records", body: request)
    }
    
    struct PocketBaseMappingUpdateRequest: Codable {
        let id_type: String
        let id_value: String
    }
    
    func updateMappingDirect(id: String, idType: String, idValue: String) async throws -> PocketBaseResponse {
        let req = PocketBaseMappingUpdateRequest(id_type: idType, id_value: idValue)
        return try await patchPocketBase("/api/collections/media_id_mappings/records/\(id)", body: req)
    }

    func deleteMapping(id: String) async throws {
        try await delete("/api/external/mappings/\(id)")
    }

    // MARK: - Anime Seasons

    func fetchAnimeSeasons(tmdbId: Int) async throws -> AnimeSeasonsResponse {
        try await get("/api/external/anime-seasons", query: [URLQueryItem(name: "tmdb_id", value: "\(tmdbId)")])
    }

    func submitAnimeSeason(_ request: SubmitAnimeSeasonRequest) async throws -> APIActionResponse {
        try await post("/api/external/anime-seasons", body: request)
    }

    func deleteAnimeSeasonMapping(tmdbId: Int, seasonNumber: Int) async throws {
        try await delete("/api/external/anime-seasons", query: [
            URLQueryItem(name: "tmdb_id", value: "\(tmdbId)"),
            URLQueryItem(name: "season_number", value: "\(seasonNumber)")
        ])
    }

    func deleteAnimeSeasonChunk(id: String) async throws {
        try await delete("/api/external/anime-seasons/\(id)")
    }

    func fetchAnimeSeasonVotes(itemId: String, all: Bool = false) async throws -> (voteCount: Int, userVote: Int) {
        let data = try await getRawData("/api/external/anime-seasons/\(itemId)/votes", query: all ? [URLQueryItem(name: "all", value: "true")] : [])
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var total = (dict["net_score"] as? Int) ?? (dict["score"] as? Int) ?? (dict["total"] as? Int) ?? (dict["vote_count"] as? Int) ?? 0
            if let upvotes = dict["upvotes"] as? Int, let downvotes = dict["downvotes"] as? Int {
                total = upvotes - downvotes
            }
            var uVote = (dict["userVote"] as? Int) ?? (dict["user_vote"] as? Int) ?? (dict["vote"] as? Int) ?? 0
            let arr = (dict["votes"] as? [[String: Any]]) ?? (dict["items"] as? [[String: Any]]) ?? (dict["records"] as? [[String: Any]]) ?? (dict["results"] as? [[String: Any]])
            if let votesArr = arr {
                total = votesArr.reduce(0) { 
                    let v = ($1["vote"] as? Int) ?? ($1["score"] as? Int) ?? 0
                    return $0 + (v == 1 ? 1 : v == -1 ? -1 : 0)
                }
                uVote = (dict["userVote"] as? Int) ?? (dict["user_vote"] as? Int) ?? ((dict["vote"] as? [String: Any])?["vote"] as? Int) ?? 0
            }
            return (total, uVote)
        }
        return (0, 0)
    }

    func voteOnAnimeSeason(itemId: String, vote: VoteValue) async throws -> APIActionResponse {
        try await post("/api/external/anime-seasons/\(itemId)/votes", body: SubmitVoteRequest(vote: vote))
    }

    func removeAnimeSeasonVote(itemId: String) async throws {
        try await delete("/api/external/anime-seasons/\(itemId)/votes")
    }

    // MARK: - Lists

    func fetchLists(page: Int = 1, perPage: Int = 30) async throws -> ListsResponse {
        let data = try await getRawData("/api/external/lists", query: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perPage", value: "\(perPage)"),
            URLQueryItem(name: "expand", value: "user,list_items_via_list")
        ])
        let raw = String(data: data, encoding: .utf8) ?? "nil"
        print("[Lists DEBUG] /api/external/lists raw: \(raw)")
        return try decoder.decode(ListsResponse.self, from: data)
    }
    
    func fetchRecentUpdates() async throws -> RecentUpdatesResponse {
        return try await get("/api/recent-updates", query: [])
    }
    
    func fetchDiscoverLists(page: Int = 1, perPage: Int = 30) async throws -> ListsResponse {
        try await getPocketBase("/api/collections/lists/records", query: [
            URLQueryItem(name: "filter", value: "is_public=true"),
            URLQueryItem(name: "sort", value: "-updated"),
            URLQueryItem(name: "expand", value: "user,list_items_via_list"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perPage", value: "\(perPage)")
        ])
    }
    
    func searchLists(query: String, page: Int = 1, perPage: Int = 30) async throws -> ListsResponse {
        let filterStr = "is_public=true && (name~\"\(query)\" || description~\"\(query)\")"
        return try await getPocketBase("/api/collections/lists/records", query: [
            URLQueryItem(name: "filter", value: filterStr),
            URLQueryItem(name: "sort", value: "-updated"),
            URLQueryItem(name: "expand", value: "user,list_items_via_list"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perPage", value: "\(perPage)")
        ])
    }

    func createList(_ request: CreateListRequest) async throws -> CreateListResponse {
        try await post("/api/external/lists", body: request)
    }

    func deleteList(id: String) async throws {
        try await delete("/api/external/lists/\(id)")
    }
    
    func saveList(listId: String) async throws -> APIActionResponse {
        print("[DEBUG] Attempting to save list. URL: POST /api/external/lists/\(listId)/save")
        return try await post("/api/external/lists/\(listId)/save", body: MediaList.EmptyPayload())
    }
    
    func unsaveList(listId: String) async throws {
        print("[DEBUG] Attempting to unsave list. URL: DELETE /api/external/lists/\(listId)/save")
        try await delete("/api/external/lists/\(listId)/save")
    }

    func fetchListItems(listId: String, page: Int = 1, perPage: Int = 1000) async throws -> ListItemsResponse {
        try await get("/api/external/lists/\(listId)/items", query: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perPage", value: "\(perPage)"),
            URLQueryItem(name: "sort", value: "-created")
        ])
    }

    func addListItem(listId: String, request: AddListItemRequest) async throws -> APIActionResponse {
        try await post("/api/external/lists/\(listId)/items", body: request)
    }

    func removeListItem(listId: String, itemId: String) async throws {
        try await delete("/api/external/lists/\(listId)/items/\(itemId)")
    }

    // MARK: - Catalogs (Picks)

    func fetchCatalogs() async throws -> CatalogsResponse {
        try await get("/api/external/catalogs")
    }

    func createCatalog(_ request: CreatePickRequest) async throws -> APIActionResponse {
        try await post("/api/external/catalogs", body: request)
    }

    func updateCatalog(catalogId: String, _ request: CreatePickRequest) async throws -> APIActionResponse {
        try await patch("/api/external/catalogs/\(catalogId)", body: request)
    }

    func deleteCatalog(catalogId: String) async throws {
        try await delete("/api/external/catalogs/\(catalogId)")
    }

    func refreshCatalog(catalogId: String) async throws -> APIActionResponse {
        try await post("/api/external/catalogs/\(catalogId)/refresh")
    }

    func fetchCatalogItems(catalogId: String, page: Int = 1, perPage: Int = 20) async throws -> CatalogItemsResponse {
        try await get("/api/external/catalogs/\(catalogId)/items", query: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perPage", value: "\(perPage)")
        ])
    }

    struct NotInterestedRequest: Codable {
        let tmdb_id: Int
        let media_type: String
    }
    
    func markNotInterested(tmdbId: Int, mediaType: String) async throws {
        let body = NotInterestedRequest(tmdb_id: tmdbId, media_type: mediaType)
        let _: APIActionResponse = try await post("/api/external/not-interested", body: body)
    }

    // MARK: - Addons & Quota
    
    struct QuotaResponse: Codable {
        let limit: Int?
        let used: Int?
        let remaining: Int?
        let next_refresh_in_seconds: Int?
    }
    
    struct AddonSettingsResponse: Codable {
        let refresh_interval_hours: Int?
    }
    
    struct AddonSettingsRequest: Codable {
        let refresh_interval_hours: Int
    }
    
    struct AddonStatusResponse: Codable {
        let installed: Bool?
        let manifestUrl: String?
        let stremioUrl: String?
    }
    
    func fetchRefreshQuota() async throws -> QuotaResponse {
        try await get("/api/external/catalogs/refresh-quota")
    }
    
    func fetchAddonSettings() async throws -> AddonSettingsResponse {
        try await get("/api/external/catalogs/settings")
    }
    
    func updateAddonSettings(hours: Int) async throws -> APIActionResponse {
        try await patch("/api/external/catalogs/settings", body: AddonSettingsRequest(refresh_interval_hours: hours))
    }
    
    func fetchAddonStatus() async throws -> AddonStatusResponse {
        try await get("/api/addon/status")
    }
    
    func generateAddonUrl() async throws -> AddonStatusResponse {
        try await post("/api/addon/install")
    }
    
    func revokeAddonUrl() async throws -> APIActionResponse {
        try await post("/api/addon/revoke")
    }

    // MARK: - Voting

    func fetchSkipVotes(itemId: String, all: Bool = false) async throws -> VotesResponse {
        try await get("/api/external/skips/\(itemId)/votes", query: all ? [URLQueryItem(name: "all", value: "true")] : [])
    }

    func fetchMappingVotes(itemId: String, all: Bool = false) async throws -> (voteCount: Int, userVote: Int) {
        let data = try await getRawData("/api/external/mappings/\(itemId)/votes", query: all ? [URLQueryItem(name: "all", value: "true")] : [])
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var total = (dict["net_score"] as? Int) ?? (dict["score"] as? Int) ?? (dict["total"] as? Int) ?? (dict["vote_count"] as? Int) ?? 0
            
            if let upvotes = dict["upvotes"] as? Int, let downvotes = dict["downvotes"] as? Int {
                total = upvotes - downvotes
            }
            
            var uVote = (dict["userVote"] as? Int) ?? (dict["user_vote"] as? Int) ?? (dict["vote"] as? Int) ?? 0
            
            let arr = (dict["votes"] as? [[String: Any]]) ?? (dict["items"] as? [[String: Any]]) ?? (dict["records"] as? [[String: Any]]) ?? (dict["results"] as? [[String: Any]])
            if let votesArr = arr {
                total = votesArr.reduce(0) { 
                    let v = ($1["vote"] as? Int) ?? ($1["score"] as? Int) ?? 0
                    return $0 + (v == 1 ? 1 : v == -1 ? -1 : 0)
                }
                uVote = (dict["userVote"] as? Int) ?? (dict["user_vote"] as? Int) ?? ((dict["vote"] as? [String: Any])?["vote"] as? Int) ?? 0
            }
            return (total, uVote)
        }
        return (0, 0)
    }

    func voteOnMapping(itemId: String, vote: VoteValue) async throws -> APIActionResponse {
        try await post("/api/external/mappings/\(itemId)/votes", body: SubmitVoteRequest(vote: vote))
    }

    func removeMappingVote(itemId: String) async throws {
        try await delete("/api/external/mappings/\(itemId)/votes")
    }

    func voteOnSkip(itemId: String, vote: VoteValue) async throws -> APIActionResponse {
        try await post("/api/external/skips/\(itemId)/votes", body: SubmitVoteRequest(vote: vote))
    }

    func removeSkipVote(itemId: String) async throws {
        try await delete("/api/external/skips/\(itemId)/votes")
    }

    func voteOnRating(itemId: String, vote: VoteValue) async throws -> APIActionResponse {
        try await post("/api/external/ratings/\(itemId)/votes", body: SubmitVoteRequest(vote: vote))
    }

    func voteOnEpisodeRating(itemId: String, vote: VoteValue) async throws -> APIActionResponse {
        try await post("/api/external/episode-ratings/\(itemId)/votes", body: SubmitVoteRequest(vote: vote))
    }

    func fetchHighlightVotes(itemId: String, all: Bool = false) async throws -> VotesResponse {
        try await get("/api/external/highlights/\(itemId)/votes", query: all ? [URLQueryItem(name: "all", value: "true")] : [])
    }

    func voteOnHighlight(itemId: String, vote: VoteValue) async throws -> APIActionResponse {
        try await post("/api/external/highlights/\(itemId)/votes", body: SubmitVoteRequest(vote: vote))
    }

    func removeHighlightVote(itemId: String) async throws {
        try await delete("/api/external/highlights/\(itemId)/votes")
    }

    func updateHighlight(id: String, _ request: CreateHighlightRequest) async throws -> APIActionResponse {
        print("[Highlights API] PUT /api/external/highlights/\(id)")
        return try await put("/api/external/highlights/\(id)", body: request)
    }

    // MARK: - HTTP Core

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await request(path: path, method: "GET", query: query)
    }

    private func getPocketBase<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        guard var components = URLComponents(string: "https://api.publicmetadb.com\(path)") else {
            throw APIError.invalidURL
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        
        if let jsonStr = String(data: data, encoding: .utf8) {
            print("[APIService] GET \(path) Response: \(jsonStr)")
        }
        
        if status == 401 { throw APIError.unauthorized }
        guard status >= 200 && status < 300 else {
            throw APIError.serverError(status: status, message: "PocketBase error")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private func performPocketBaseMethod<T: Decodable, B: Encodable>(method: String, path: String, body: B) async throws -> T {
        guard let url = URL(string: "https://api.publicmetadb.com\(path)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let token = KeychainStore.load(account: SettingsKeychainAccount.pbToken.rawValue) ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        if status == 401 { throw APIError.unauthorized }
        guard status >= 200 && status < 300 else {
            let msg = String(data: data, encoding: .utf8) ?? "PocketBase error"
            throw APIError.serverError(status: status, message: msg)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func postPocketBase<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await performPocketBaseMethod(method: "POST", path: path, body: body)
    }

    private func patchPocketBase<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await performPocketBaseMethod(method: "PATCH", path: path, body: body)
    }

    private func getRawData(_ path: String, query: [URLQueryItem] = []) async throws -> Data {
        guard var components = URLComponents(url: Config.baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(Config.apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performWithRateLimitRetry(urlRequest)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0

        if status == 401 { throw APIError.unauthorized }
        if status == 429 {
            let retryAfter = http?.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw APIError.rateLimited(retryAfter: retryAfter)
        }
        if status >= 500 {
            throw APIError.serverError(status: status, message: String(data: data, encoding: .utf8) ?? "Server error")
        }
        guard (200...299).contains(status) else {
            throw APIError.serverError(status: status, message: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    private func post<T: Decodable, B: Encodable>(
        _ path: String,
        query: [URLQueryItem] = [],
        body: B,
        acceptMultiStatus: Bool = false
    ) async throws -> T {
        try await request(path: path, method: "POST", query: query, body: try encoder.encode(body), acceptMultiStatus: acceptMultiStatus)
    }

    private func post<T: Decodable>(
        _ path: String,
        query: [URLQueryItem] = [],
        acceptMultiStatus: Bool = false
    ) async throws -> T {
        try await request(path: path, method: "POST", query: query, body: nil, acceptMultiStatus: acceptMultiStatus)
    }

    private func patch<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await request(path: path, method: "PATCH", body: try encoder.encode(body))
    }

    private func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await request(path: path, method: "PUT", body: try encoder.encode(body))
    }

    private func delete(_ path: String, query: [URLQueryItem] = []) async throws {
        let _: EmptyResponse? = try? await request(path: path, method: "DELETE", query: query) as EmptyResponse
    }

    private func deleteWithBody<T: Decodable, B: Encodable>(
        _ path: String,
        body: B,
        acceptMultiStatus: Bool = false
    ) async throws -> T {
        try await request(path: path, method: "DELETE", body: try encoder.encode(body), acceptMultiStatus: acceptMultiStatus)
    }

    private func request<T: Decodable>(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        acceptMultiStatus: Bool = false
    ) async throws -> T {
        guard var components = URLComponents(url: Config.baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.httpBody = body
        
        var token = Config.apiKey
        if path.contains("/api/addon/") {
            await AuthService.shared.refreshTokenIfNeeded()
            token = Config.pbToken
            print("[API Debug] Sending addon request to \(path). token prefix: \(token.prefix(15))... empty? \(token.isEmpty)")
        }
        
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Increase timeout for potentially long-running endpoints
        if path.contains("/api/recent-updates") {
            urlRequest.timeoutInterval = 300 // 5 minutes
        }

        let (data, response) = try await performWithRateLimitRetry(urlRequest)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0

        if status == 401 {
            throw APIError.unauthorized
        }
        if status == 429 {
            let retryAfter = http?.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw APIError.rateLimited(retryAfter: retryAfter)
        }
        if status >= 500 {
            let message = String(data: data, encoding: .utf8) ?? "Server error"
            throw APIError.serverError(status: status, message: message)
        }
        let successRange = acceptMultiStatus ? (200...299).contains(status) || status == 207 : (200...299).contains(status)
        if !successRange {
            let message = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: status)
            throw APIError.serverError(status: status, message: message)
        }

        if data.isEmpty, T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        guard !data.isEmpty else { throw APIError.emptyResponse }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("[API DECODE ERROR] Failed to decode \(T.self)")
            print("[API DECODE ERROR] Error: \(error)")
            print("[API DECODE ERROR] Raw JSON: \(String(data: data, encoding: .utf8) ?? "nil")")
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    private func performWithRateLimitRetry(_ request: URLRequest, attempt: Int = 0) async throws -> (Data, URLResponse) {
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 429, attempt < 1 {
            let wait = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init) ?? 2
            try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            return try await performWithRateLimitRetry(request, attempt: attempt + 1)
        }
        return (data, response)
    }
}

private struct EmptyResponse: Decodable {
    init() {}
}

private struct EmptyBody: Encodable {}

