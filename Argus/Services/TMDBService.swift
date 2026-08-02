import Foundation

/// TMDB metadata via PublicMetaDB proxy, with optional direct TMDB API fallback.
final class TMDBService: Sendable {
    static let shared = TMDBService()

    private let session: URLSession
    private let decoder = JSONDecoder()

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        self.session = URLSession(configuration: configuration)
    }

    func discover(filters: DiscoverFilters) async throws -> TMDBDiscoverResult {
        do {
            let path = "/api/tmdb/discover/\(filters.mediaType.rawValue)"
            let response: TMDBPageResponse = try await getProxy(path, query: filters.queryItems)
            return response.discoverResult(filters: filters)
        } catch {
            return try await discoverFromDirectAPI(filters: filters)
        }
    }

    private func discoverFromDirectAPI(filters: DiscoverFilters) async throws -> TMDBDiscoverResult {
        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else {
            throw APIError.serverError(status: 0, message: "TMDB API key not configured")
        }

        guard var components = URLComponents(
            url: Config.tmdbAPIBase.appending(path: "/discover/\(filters.mediaType.rawValue)"),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        var queryItems = filters.queryItems
        queryItems.append(URLQueryItem(name: "api_key", value: apiKey))
        components.queryItems = queryItems
        guard let url = components.url else { throw APIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError(
                status: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "TMDB discover error"
            )
        }
        let page = try decoder.decode(TMDBPageResponse.self, from: data)
        return page.discoverResult(filters: filters)
    }

    func search(_ query: String, mediaType: MediaType) async throws -> [TMDBMediaItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        do {
            return try await searchFromProxy(trimmed, mediaType: mediaType)
        } catch {
            return try await searchFromDirectAPI(trimmed, mediaType: mediaType)
        }
    }

    private func searchFromProxy(_ query: String, mediaType: MediaType) async throws -> [TMDBMediaItem] {
        let typedPath = "/api/tmdb/search/\(mediaType.rawValue)"
        do {
            let typed: TMDBPageResponse = try await getProxy(
                typedPath,
                query: [URLQueryItem(name: "query", value: query)]
            )
            let items = typed.mediaItems(defaultKind: mediaType)
            if !items.isEmpty { return items }
        } catch {
            // Fall through to multi search.
        }

        let multi: TMDBPageResponse = try await getProxy(
            "/api/tmdb/search/multi",
            query: [URLQueryItem(name: "query", value: query)]
        )
        return multi.mediaItems(defaultKind: mediaType)
            .filter { $0.mediaType == mediaType && $0.tmdbId > 0 }
    }

    private func searchFromDirectAPI(_ query: String, mediaType: MediaType) async throws -> [TMDBMediaItem] {
        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else { throw APIError.serverError(status: 0, message: "TMDB API key not configured") }

        guard var components = URLComponents(
            url: Config.tmdbAPIBase.appending(path: "/search/\(mediaType.rawValue)"),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query)
        ]
        guard let url = components.url else { throw APIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError(
                status: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "TMDB search error"
            )
        }
        let page = try decoder.decode(TMDBPageResponse.self, from: data)
        return page.mediaItems(defaultKind: mediaType).filter { $0.tmdbId > 0 }
    }
    func fetchTrending(mediaType: String = "all", timeWindow: String = "day", page: Int = 1) async throws -> [TMDBMediaItem] {
        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else { throw APIError.serverError(status: 0, message: "TMDB API key not configured") }

        guard var components = URLComponents(
            url: Config.tmdbAPIBase.appending(path: "/trending/\(mediaType)/\(timeWindow)"),
            resolvingAgainstBaseURL: false
        ) else { throw APIError.invalidURL }
        
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "page", value: String(page))
        ]
        guard let url = components.url else { throw APIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
        
        let page = try decoder.decode(TMDBPageResponse.self, from: data)
        return page.mediaItems(defaultKind: .movie).filter { $0.tmdbId > 0 }
    }

    func fetchImages(tmdbId: Int, mediaType: MediaType) async throws -> TMDBImagesResponse {
        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else { throw APIError.serverError(status: 0, message: "TMDB API key not configured") }
        
        let segment = mediaType == .movie ? "movie" : "tv"
        guard var components = URLComponents(
            url: Config.tmdbAPIBase.appending(path: "/\(segment)/\(tmdbId)/images"),
            resolvingAgainstBaseURL: false
        ) else { throw APIError.invalidURL }
        
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "include_image_language", value: "en,null")
        ]
        
        guard let url = components.url else { throw APIError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "Failed to fetch images")
        }
        
        return try decoder.decode(TMDBImagesResponse.self, from: data)
    }

    func searchMulti(_ query: String, year: String?) async throws -> [TMDBMediaItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else { throw APIError.serverError(status: 0, message: "TMDB API key not configured") }

        guard var components = URLComponents(
            url: Config.tmdbAPIBase.appending(path: "/search/multi"),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        
        var queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: trimmed)
        ]
        
        if let year = year, !year.isEmpty {
            queryItems.append(URLQueryItem(name: "year", value: year)) // Note: multi search might ignore year, but it's worth trying, or we filter manually.
        }
        
        components.queryItems = queryItems
        guard let url = components.url else { throw APIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return []
        }
        
        let page = try decoder.decode(TMDBPageResponse.self, from: data)
        
        var items = page.mediaItems(defaultKind: .movie).filter { $0.tmdbId > 0 && ($0.mediaType == .movie || $0.mediaType == .tv || $0.mediaType == .person) }
        
        if let year = year, !year.isEmpty {
            // Filter by year if possible
            let filtered = items.filter { $0.year == year }
            if !filtered.isEmpty {
                items = filtered
            }
        }
        
        return items
    }

    func find(externalId: String) async throws -> TMDBMediaItem? {
        let trimmed = externalId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else { throw APIError.serverError(status: 0, message: "TMDB API key not configured") }
        
        let externalSource = trimmed.lowercased().starts(with: "tt") ? "imdb_id" : (trimmed.lowercased().starts(with: "tmdb") ? "tvdb_id" : "imdb_id")
        let idToSearch = trimmed.lowercased().replacingOccurrences(of: "tmdb:", with: "")

        guard var components = URLComponents(
            url: Config.tmdbAPIBase.appending(path: "/find/\(idToSearch)"),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "external_source", value: externalSource)
        ]
        guard let url = components.url else { throw APIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }
        
        let findResponse = try decoder.decode(TMDBFindResponse.self, from: data)
        
        if let movies = findResponse.movieResults, let first = movies.first {
            return first.mediaItem(defaultKind: .movie)
        }
        if let tvs = findResponse.tvResults, let first = tvs.first {
            return first.mediaItem(defaultKind: .tv)
        }
        
        return nil
    }

    func details(tmdbId: Int, mediaType: MediaType) async throws -> TMDBMediaItem {
        let info = try await fetchDetailInfo(tmdbId: tmdbId, mediaType: mediaType)
        return TMDBMediaItem(
            id: "\(info.mediaType.rawValue)-\(info.tmdbId)",
            tmdbId: info.tmdbId,
            mediaType: info.mediaType,
            title: info.title,
            overview: info.overview,
            year: info.year,
            posterPath: info.posterPath,
            backdropPath: info.backdropPath,
            voteAverage: info.voteAverage,
            voteCount: 0,
            genreIds: info.genreIds
        )
    }

    func fetchDetailInfo(tmdbId: Int, mediaType: MediaType) async throws -> MediaDetailInfo {
        do {
            let detail: TMDBDetailResponse = try await fetchDetailPayload(
                tmdbId: tmdbId,
                mediaType: mediaType,
                appendVideos: true
            )
            return detail.detailInfo(mediaType: mediaType, tmdbId: tmdbId)
        } catch {
            return try await fetchDetailInfoDirect(tmdbId: tmdbId, mediaType: mediaType)
        }
    }

    func fetchRecommendations(tmdbId: Int, mediaType: MediaType) async throws -> [TMDBMediaItem] {
        do {
            let path = mediaType == .movie
                ? "/api/tmdb/movie/\(tmdbId)/recommendations"
                : "/api/tmdb/tv/\(tmdbId)/recommendations"
            let response: TMDBPageResponse = try await getProxy(path, query: [])
            return Array(response.mediaItems(defaultKind: mediaType).prefix(10))
        } catch {
            return try await fetchRecommendationsDirect(tmdbId: tmdbId, mediaType: mediaType)
        }
    }

    private func fetchRecommendationsDirect(tmdbId: Int, mediaType: MediaType) async throws -> [TMDBMediaItem] {
        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else {
            throw APIError.serverError(status: 0, message: "TMDB API key not configured")
        }

        let segment = mediaType == .movie ? "movie" : "tv"
        guard var components = URLComponents(
            url: Config.tmdbAPIBase.appending(path: "/\(segment)/\(tmdbId)/recommendations"),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components.url else { throw APIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError(
                status: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "TMDB recommendations error"
            )
        }
        let page = try decoder.decode(TMDBPageResponse.self, from: data)
        return Array(page.mediaItems(defaultKind: mediaType).prefix(10))
    }

    func fetchSeasonEpisodes(tmdbId: Int, season: Int) async throws -> [EpisodeDisplay] {
        do {
            let path = "/api/tmdb/tv/\(tmdbId)/season/\(season)"
            let response: TMDBSeasonDetailResponse = try await getProxy(path, query: [])
            return (response.episodes ?? []).map { $0.display() }
        } catch {
            return try await fetchSeasonEpisodesDirect(tmdbId: tmdbId, season: season)
        }
    }

    func fetchDetailPayload(
        tmdbId: Int,
        mediaType: MediaType,
        appendVideos: Bool
    ) async throws -> TMDBDetailResponse {
        let path = mediaType == .movie
            ? "/api/tmdb/movie/\(tmdbId)"
            : "/api/tmdb/tv/\(tmdbId)"
        var query: [URLQueryItem] = []
        if appendVideos {
            let appendStr = mediaType == .movie
                ? "videos,credits,images,keywords,reviews,watch/providers"
                : "videos,credits,aggregate_credits,images,keywords,reviews,watch/providers"
            query.append(URLQueryItem(name: "append_to_response", value: appendStr))
            query.append(URLQueryItem(name: "include_image_language", value: "en,null,xx"))
            query.append(URLQueryItem(name: "watch_region", value: "US"))
        }
        return try await getProxy(path, query: query)
    }

    func fetchDetailPayloadDirect(
        tmdbId: Int,
        mediaType: MediaType,
        appendVideos: Bool
    ) async throws -> TMDBDetailResponse {
        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else { throw APIError.serverError(status: 0, message: "TMDB API key not configured") }

        let segment = mediaType == .movie ? "movie" : "tv"
        guard var components = URLComponents(
            url: Config.tmdbAPIBase.appending(path: "/\(segment)/\(tmdbId)"),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        
        var queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        if appendVideos {
            let appendStr = mediaType == .movie
                ? "videos,credits,images,content_ratings,release_dates,keywords,reviews,watch/providers"
                : "videos,credits,aggregate_credits,images,content_ratings,release_dates,keywords,reviews,watch/providers"
            queryItems.append(URLQueryItem(name: "append_to_response", value: appendStr))
            queryItems.append(URLQueryItem(name: "include_image_language", value: "en,null,xx"))
            queryItems.append(URLQueryItem(name: "watch_region", value: "US"))
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw APIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError(
                status: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "TMDB API error"
            )
        }
        return try decoder.decode(TMDBDetailResponse.self, from: data)
    }

    private func fetchDetailInfoDirect(tmdbId: Int, mediaType: MediaType) async throws -> MediaDetailInfo {
        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else { throw APIError.serverError(status: 0, message: "TMDB API key not configured") }

        let segment = mediaType == .movie ? "movie" : "tv"
        guard var components = URLComponents(
            url: Config.tmdbAPIBase.appending(path: "/\(segment)/\(tmdbId)"),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        let appendStr = mediaType == .movie
            ? "videos,credits,images,content_ratings,release_dates,keywords,reviews,watch/providers"
            : "videos,credits,aggregate_credits,images,content_ratings,release_dates,keywords,reviews,watch/providers"
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "append_to_response", value: appendStr),
            URLQueryItem(name: "include_image_language", value: "en,null,xx"),
            URLQueryItem(name: "watch_region", value: "US")
        ]
        guard let url = components.url else { throw APIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError(
                status: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "TMDB API error"
            )
        }
        let detail = try decoder.decode(TMDBDetailResponse.self, from: data)
        return detail.detailInfo(mediaType: mediaType, tmdbId: tmdbId)
    }
    
    // MARK: - External IDs
    func fetchExternalIDs(tmdbId: Int, mediaType: MediaType) async throws -> TMDBExternalIDsResponse {
        do {
            let path = "/api/tmdb/\(mediaType.rawValue)/\(tmdbId)/external_ids"
            return try await getProxy(path, query: [])
        } catch {
            let apiKey = Config.tmdbAPIKey
            guard !apiKey.isEmpty else {
                throw APIError.serverError(status: 0, message: "TMDB API key not configured")
            }
            guard var components = URLComponents(
                url: Config.tmdbAPIBase.appending(path: "/\(mediaType.rawValue)/\(tmdbId)/external_ids"),
                resolvingAgainstBaseURL: false
            ) else {
                throw APIError.invalidURL
            }
            components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
            guard let url = components.url else { throw APIError.invalidURL }
            
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw APIError.serverError(
                    status: (response as? HTTPURLResponse)?.statusCode ?? 0,
                    message: "TMDB external ids error"
                )
            }
            return try decoder.decode(TMDBExternalIDsResponse.self, from: data)
        }
    }

    // MARK: - Collection
    func fetchCollection(id: Int) async throws -> TMDBCollectionResponse {
        do {
            return try await getProxy("/api/tmdb/collection/\(id)", query: [])
        } catch {
            return try await fetchCollectionDirect(id: id)
        }
    }

    private func fetchCollectionDirect(id: Int) async throws -> TMDBCollectionResponse {
        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else { throw APIError.serverError(status: 0, message: "TMDB API key not configured") }
        guard var components = URLComponents(url: Config.tmdbAPIBase.appending(path: "/collection/\(id)"), resolvingAgainstBaseURL: false) else { throw APIError.invalidURL }
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components.url else { throw APIError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "TMDB collection error")
        }
        return try decoder.decode(TMDBCollectionResponse.self, from: data)
    }

    private func fetchSeasonEpisodesDirect(tmdbId: Int, season: Int) async throws -> [EpisodeDisplay] {
        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else { throw APIError.serverError(status: 0, message: "TMDB API key not configured") }

        guard var components = URLComponents(
            url: Config.tmdbAPIBase.appending(path: "/tv/\(tmdbId)/season/\(season)"),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components.url else { throw APIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError(
                status: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "TMDB season error"
            )
        }
        let seasonResponse = try decoder.decode(TMDBSeasonDetailResponse.self, from: data)
        return (seasonResponse.episodes ?? []).map { $0.display() }
    }
    // MARK: - Configuration / Providers
    
    func fetchCountries() async throws -> [TMDBCountry] {
        do {
            return try await getProxy("/api/tmdb/configuration/countries", query: [])
        } catch {
            return try await fetchCountriesDirect()
        }
    }
    
    private func fetchCountriesDirect() async throws -> [TMDBCountry] {
        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else { throw APIError.serverError(status: 0, message: "TMDB API key not configured") }
        
        guard var components = URLComponents(url: Config.tmdbAPIBase.appending(path: "/configuration/countries"), resolvingAgainstBaseURL: false) else { throw APIError.invalidURL }
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components.url else { throw APIError.invalidURL }
        
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "TMDB configuration error")
        }
        return try decoder.decode([TMDBCountry].self, from: data)
    }
    
    func fetchProviders(mediaType: MediaType, watchRegion: String) async throws -> [TMDBProvider] {
        do {
            let path = "/api/tmdb/watch/providers/\(mediaType.rawValue)"
            let response: TMDBProviderResponse = try await getProxy(path, query: [URLQueryItem(name: "watch_region", value: watchRegion)])
            return response.results
        } catch {
            return try await fetchProvidersDirect(mediaType: mediaType, watchRegion: watchRegion)
        }
    }
    
    private func fetchProvidersDirect(mediaType: MediaType, watchRegion: String) async throws -> [TMDBProvider] {
        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else { throw APIError.serverError(status: 0, message: "TMDB API key not configured") }
        
        guard var components = URLComponents(url: Config.tmdbAPIBase.appending(path: "/watch/providers/\(mediaType.rawValue)"), resolvingAgainstBaseURL: false) else { throw APIError.invalidURL }
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "watch_region", value: watchRegion)
        ]
        guard let url = components.url else { throw APIError.invalidURL }
        
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "TMDB providers error")
        }
        let result = try decoder.decode(TMDBProviderResponse.self, from: data)
        return result.results
    }

    // MARK: - Search People & Studios
    
    func searchPeople(query: String) async throws -> [TMDBPerson] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        do {
            let response: TMDBPersonSearchResponse = try await getProxy("/api/tmdb/search/person", query: [URLQueryItem(name: "query", value: trimmed)])
            return response.results
        } catch {
            return try await searchPeopleDirect(trimmed)
        }
    }
    
    private func searchPeopleDirect(_ query: String) async throws -> [TMDBPerson] {
        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else { throw APIError.serverError(status: 0, message: "TMDB API key not configured") }
        guard var components = URLComponents(url: Config.tmdbAPIBase.appending(path: "/search/person"), resolvingAgainstBaseURL: false) else { throw APIError.invalidURL }
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query)
        ]
        guard let url = components.url else { throw APIError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "TMDB person search error")
        }
        let result = try decoder.decode(TMDBPersonSearchResponse.self, from: data)
        return result.results
    }
    
    func searchStudios(query: String) async throws -> [TMDBStudio] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        do {
            let response: TMDBStudioSearchResponse = try await getProxy("/api/tmdb/search/company", query: [URLQueryItem(name: "query", value: trimmed)])
            return response.results
        } catch {
            return try await searchStudiosDirect(trimmed)
        }
    }
    
    private func searchStudiosDirect(_ query: String) async throws -> [TMDBStudio] {
        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else { throw APIError.serverError(status: 0, message: "TMDB API key not configured") }
        guard var components = URLComponents(url: Config.tmdbAPIBase.appending(path: "/search/company"), resolvingAgainstBaseURL: false) else { throw APIError.invalidURL }
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query)
        ]
        guard let url = components.url else { throw APIError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "TMDB studio search error")
        }
        let result = try decoder.decode(TMDBStudioSearchResponse.self, from: data)
        return result.results
    }
    
    func fetchStudio(id: Int) async throws -> TMDBStudio {
        do {
            return try await getProxy("/api/tmdb/company/\(id)", query: [])
        } catch {
            return try await fetchStudioDirect(id: id)
        }
    }
    
    private func fetchStudioDirect(id: Int) async throws -> TMDBStudio {
        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else { throw APIError.serverError(status: 0, message: "TMDB API key not configured") }
        guard var components = URLComponents(url: Config.tmdbAPIBase.appending(path: "/company/\(id)"), resolvingAgainstBaseURL: false) else { throw APIError.invalidURL }
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components.url else { throw APIError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "TMDB company fetch error")
        }
        return try decoder.decode(TMDBStudio.self, from: data)
    }

    func fetchPersonDetail(personId: Int) async throws -> TMDBPersonDetailResponse {
        do {
            let path = "/api/tmdb/person/\(personId)"
            return try await getProxy(path, query: [
                URLQueryItem(name: "append_to_response", value: "combined_credits,images")
            ])
        } catch {
            return try await fetchPersonDetailDirect(personId: personId)
        }
    }
    
    private func fetchPersonDetailDirect(personId: Int) async throws -> TMDBPersonDetailResponse {
        let apiKey = Config.tmdbAPIKey
        guard !apiKey.isEmpty else { throw APIError.serverError(status: 0, message: "TMDB API key not configured") }
        guard var components = URLComponents(url: Config.tmdbAPIBase.appending(path: "/person/\(personId)"), resolvingAgainstBaseURL: false) else { throw APIError.invalidURL }
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "append_to_response", value: "combined_credits,images")
        ]
        guard let url = components.url else { throw APIError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "TMDB person detail error")
        }
        return try decoder.decode(TMDBPersonDetailResponse.self, from: data)
    }

    private func getProxy<T: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> T {
        guard var components = URLComponents(url: Config.baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        var queryItems = query
        let tmdbKey = Config.tmdbAPIKey
        if !tmdbKey.isEmpty, !queryItems.contains(where: { $0.name == "api_key" }) {
            queryItems.append(URLQueryItem(name: "api_key", value: tmdbKey))
        }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let publicMetaDBKey = Config.apiKey
        if !publicMetaDBKey.isEmpty {
            request.setValue("Bearer \(publicMetaDBKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let message = String(data: data, encoding: .utf8) ?? "TMDB proxy error"
            throw APIError.serverError(status: status, message: message)
        }
        return try decoder.decode(T.self, from: data)
    }
}

struct TMDBDetailResponse: Codable {
    let id: Int?
    let tmdbId: Int?
    let mediaType: String?
    let title: String?
    let name: String?
    let overview: String?
    let tagline: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let voteCount: Int?
    let runtime: Int?
    let episodeRunTime: [Int]?
    let status: String?
    let contentRatings: TMDBContentRatingsResponse?
    let releaseDates: TMDBReleaseDatesResponse?
    let networks: [TMDBNetworkWrapper]?
    let genres: [TMDBGenreStub]?
    let seasons: [TMDBSeasonStub]?
    let videos: TMDBVideosResponse?
    let credits: TMDBCreditsResponse?
    let aggregateCredits: TMDBAggregateCreditsResponse?
    let createdBy: [TMDBCrewMember]?
    let images: TMDBImagesResponse?
    let nextEpisodeToAir: TMDBNextEpisodeToAir?
    let originalLanguage: String?
    let originCountry: [String]?
    // New rich metadata fields
    let budget: Int?
    let revenue: Int?
    let belongsToCollection: TMDBCollectionStub?
    let productionCompanies: [TMDBProductionCompany]?
    let keywords: TMDBKeywordsWrapper?
    let reviews: TMDBReviewsResponse?
    let watchProviders: TMDBWatchProvidersResponse?

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case title, name, overview, tagline, status, runtime, genres, seasons, networks, videos, credits, images
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case episodeRunTime = "episode_run_time"
        case contentRatings = "content_ratings"
        case releaseDates = "release_dates"
        case aggregateCredits = "aggregate_credits"
        case createdBy = "created_by"
        case nextEpisodeToAir = "next_episode_to_air"
        case originalLanguage = "original_language"
        case originCountry = "origin_country"
        case budget, revenue
        case belongsToCollection = "belongs_to_collection"
        case productionCompanies = "production_companies"
        case keywords
        case reviews
        case watchProviders = "watch/providers"
    }

    func mediaItem(mediaType: MediaType, tmdbId: Int) -> TMDBMediaItem {
        let info = detailInfo(mediaType: mediaType, tmdbId: tmdbId)
        return TMDBMediaItem(
            id: "\(info.mediaType.rawValue)-\(info.tmdbId)",
            tmdbId: info.tmdbId,
            mediaType: info.mediaType,
            title: info.title,
            overview: info.overview,
            year: info.year,
            posterPath: info.posterPath,
            backdropPath: info.backdropPath,
            voteAverage: info.voteAverage,
            voteCount: 0
        )
    }

    func detailInfo(mediaType: MediaType, tmdbId: Int) -> MediaDetailInfo {
        let kind: MediaType = self.mediaType == "tv" ? .tv : (self.mediaType == "movie" ? .movie : mediaType)
        let resolvedId = self.tmdbId ?? id ?? tmdbId
        let resolvedTitle = title ?? name ?? "Untitled"
        let date = releaseDate ?? firstAirDate ?? ""
        let year = String(date.prefix(4))

        let runtimeMinutes = runtime ?? episodeRunTime?.first
        let runtimeLabel: String? = {
            guard let rm = runtimeMinutes, rm > 0 else { return nil }
            if kind == .movie {
                let h = rm / 60
                let m = rm % 60
                if h > 0 {
                    return m > 0 ? "\(h)h \(m)m" : "\(h)h"
                } else {
                    return "\(m)m"
                }
            } else {
                let h = rm / 60
                let m = rm % 60
                if h > 0 {
                    return m > 0 ? "\(h)h \(m)m" : "\(h)h"
                } else {
                    return "\(m)m"
                }
            }
        }()

        var cert: String? = nil
        if kind == .tv {
            if let results = contentRatings?.results {
                cert = results.first(where: { $0.iso_3166_1 == "US" })?.rating
                if cert == nil { cert = results.first?.rating }
            }
        } else {
            if let results = releaseDates?.results {
                let usRelease = results.first(where: { $0.iso_3166_1 == "US" })
                cert = usRelease?.release_dates?.first(where: { !($0.certification ?? "").isEmpty })?.certification
                if cert == nil {
                    cert = results.first?.release_dates?.first(where: { !($0.certification ?? "").isEmpty })?.certification
                }
            }
        }

        let seasonSummaries: [SeasonSummary] = (seasons ?? [])
            .compactMap { stub in
                guard let number = stub.seasonNumber else { return nil }
                return SeasonSummary(
                    seasonNumber: number,
                    name: stub.name ?? "Season \(number)",
                    episodeCount: stub.episodeCount ?? 0
                )
            }
            .filter { $0.seasonNumber >= 0 }
            .sorted { $0.seasonNumber < $1.seasonNumber }

        let trailerKey = videos?.results?
            .first(where: { ($0.site?.lowercased() == "youtube") && ($0.type?.lowercased() == "trailer") })?
            .key

        // MARK: - Credits Grouping
        var groupedDepartments: [String: [CastMember]] = [:]
        
        // 1. Cast
        var sourceCast = aggregateCredits?.cast ?? credits?.cast ?? []
        sourceCast.sort { ($0.order ?? 999) < ($1.order ?? 999) }
        var castMembers: [CastMember] = []
        var seenCastIds = Set<Int>()
        
        for member in sourceCast {
            guard let id = member.id, let name = member.name, !name.isEmpty, !seenCastIds.contains(id) else { continue }
            seenCastIds.insert(id)
            let char: String
            if let aggregateRoles = member.roles, let firstRole = aggregateRoles.first?.character {
                char = firstRole
            } else {
                char = member.character ?? ""
            }
            castMembers.append(CastMember(id: id, name: name, character: char, profilePath: member.profilePath))
            if castMembers.count >= 20 { break }
        }
        
        if !castMembers.isEmpty {
            groupedDepartments["Cast"] = castMembers
        }
        
        // 2. Creators (TV)
        var creators: [CastMember] = []
        var seenCreatorIds = Set<Int>()
        for c in (createdBy ?? []) {
            guard let id = c.id, let name = c.name, !name.isEmpty, !seenCreatorIds.contains(id) else { continue }
            seenCreatorIds.insert(id)
            creators.append(CastMember(id: id, name: name, character: "Creator", profilePath: c.profilePath))
            if creators.count >= 20 { break }
        }
        if !creators.isEmpty {
            groupedDepartments["Creator"] = creators
        }
        
        // 3. Crew
        let sourceCrew = aggregateCredits?.crew ?? credits?.crew ?? []
        var seenCrewKeys = Set<String>() // id + department
        for c in sourceCrew {
            guard let id = c.id, let name = c.name, !name.isEmpty else { continue }
            let dept = c.department ?? "Crew"
            
            let job: String
            if let aggregateJobs = c.jobs, let firstJob = aggregateJobs.first?.job {
                job = firstJob
            } else {
                job = c.job ?? dept
            }
            
            let key = "\(id)-\(dept)"
            guard !seenCrewKeys.contains(key) else { continue }
            
            var deptMembers = groupedDepartments[dept] ?? []
            if deptMembers.count < 20 {
                seenCrewKeys.insert(key)
                deptMembers.append(CastMember(id: id, name: name, character: job, profilePath: c.profilePath))
                groupedDepartments[dept] = deptMembers
            }
        }
        
        // 4. Sort Departments
        let priorityOrder = ["Cast": 0, "Creator": 1, "Directing": 2, "Writing": 3]
        let sortedKeys = groupedDepartments.keys.sorted {
            let p1 = priorityOrder[$0] ?? 99
            let p2 = priorityOrder[$1] ?? 99
            if p1 != p2 { return p1 < p2 }
            return $0 < $1
        }
        
        let groupedCredits = sortedKeys.map { DepartmentGroup(department: $0, members: groupedDepartments[$0]!) }
            
        let mappedGenres = (genres ?? []).compactMap { $0.name }
        let mappedGenreIds = (genres ?? []).compactMap { $0.id }

        var textlessPoster: String? = nil
        if let posters = images?.posters {
            if let textless = posters.first(where: { $0.iso639_1 == nil || $0.iso639_1 == "xx" }) {
                textlessPoster = textless.filePath
            }
        }

        var logoPath: String? = nil
        if let logos = images?.logos {
            if let firstPng = logos.first(where: { ($0.filePath ?? "").lowercased().hasSuffix(".png") }) {
                logoPath = firstPng.filePath
            } else if let fallback = logos.first(where: { !($0.filePath ?? "").lowercased().hasSuffix(".svg") }) {
                logoPath = fallback.filePath
            }
        }

        // MARK: Watch Providers (US only)
        let usProviders = watchProviders?.us
        let mappedWatchProviders: WatchProviderInfo? = usProviders.map { p in
            WatchProviderInfo(
                link: p.link,
                streaming: (p.flatrate ?? []).map { WatchProviderEntry(id: $0.providerId, name: $0.providerName ?? "", logoPath: $0.logoPath) },
                rent: (p.rent ?? []).map { WatchProviderEntry(id: $0.providerId, name: $0.providerName ?? "", logoPath: $0.logoPath) },
                buy: (p.buy ?? []).map { WatchProviderEntry(id: $0.providerId, name: $0.providerName ?? "", logoPath: $0.logoPath) },
                free: (p.free ?? []).map { WatchProviderEntry(id: $0.providerId, name: $0.providerName ?? "", logoPath: $0.logoPath) }
            )
        }

        // MARK: Next Episode
        let mappedNextEpisode: NextEpisodeInfo? = nextEpisodeToAir.flatMap { ep in
            guard let sn = ep.seasonNumber, let en = ep.episodeNumber, let ad = ep.airDate else { return nil }
            return NextEpisodeInfo(
                seasonNumber: sn,
                episodeNumber: en,
                name: ep.name ?? "Episode \(en)",
                airDate: ad
            )
        }

        // MARK: All Videos (YouTube only, unique keys, sorted by priority)
        let videoOrder: [String: Int] = ["Trailer": 0, "Teaser": 1, "Clip": 2,
                                          "Behind the Scenes": 3, "Featurette": 4, "Bloopers": 5]
        var seenVideoKeys = Set<String>()
        let allVideos: [VideoItem] = (videos?.results ?? [])
            .filter { ($0.site?.lowercased() == "youtube") && !($0.key ?? "").isEmpty }
            .sorted { (videoOrder[$0.type ?? ""] ?? 99) < (videoOrder[$1.type ?? ""] ?? 99) }
            .compactMap { v -> VideoItem? in
                guard let key = v.key, !seenVideoKeys.contains(key) else { return nil }
                seenVideoKeys.insert(key)
                return VideoItem(
                    id: v.id ?? key,
                    key: key,
                    name: v.name ?? "",
                    type: v.type ?? "Video",
                    site: v.site ?? "YouTube"
                )
            }

        // MARK: Network Items
        let networkItems: [NetworkItem]
        if let nets = networks, !nets.isEmpty {
            networkItems = nets.compactMap { wrapper in
                guard let id = wrapper.id, let name = wrapper.name else { return nil }
                return NetworkItem(id: id, name: name, logoPath: wrapper.logoPath)
            }
        } else if let companies = productionCompanies, !companies.isEmpty {
            networkItems = companies.compactMap { company in
                guard let name = company.name else { return nil }
                return NetworkItem(id: company.id, name: name, logoPath: company.logoPath)
            }
        } else {
            networkItems = []
        }

        // MARK: Keywords
        let mappedKeywords: [String] = (keywords?.all ?? []).prefix(20).map { $0.name }

        // MARK: Reviews
        let mappedReviews: [ReviewItem] = (reviews?.results ?? []).prefix(5).compactMap { r in
            guard let content = r.content, !content.isEmpty else { return nil }
            return ReviewItem(
                id: r.id,
                author: r.author ?? "Anonymous",
                content: content,
                rating: r.authorDetails?.rating,
                avatarPath: r.authorDetails?.avatarPath,
                createdAt: r.createdAt
            )
        }

        return MediaDetailInfo(
            tmdbId: resolvedId,
            mediaType: kind,
            title: resolvedTitle,
            tagline: tagline,
            overview: overview ?? "",
            year: year.isEmpty ? "—" : year,
            posterPath: posterPath,
            textlessPosterPath: textlessPoster,
            backdropPath: backdropPath,
            logoPath: logoPath,
            certification: cert,
            networkLabel: networks?.first?.name ?? status,
            runtimeLabel: runtimeLabel,
            trailerYouTubeKey: trailerKey,
            voteAverage: voteAverage ?? 0,
            voteCount: voteCount ?? 0,
            genres: mappedGenres,
            genreIds: mappedGenreIds,
            seasons: seasonSummaries,
            originalLanguage: originalLanguage,
            originCountry: originCountry,
            credits: groupedCredits,
            watchProviders: mappedWatchProviders,
            nextEpisodeToAir: mappedNextEpisode,
            budget: budget,
            revenue: revenue,
            collectionId: belongsToCollection?.id,
            collectionName: belongsToCollection?.name,
            allVideos: allVideos,
            networkItems: networkItems,
            keywords: mappedKeywords,
            reviews: mappedReviews,
            status: status
        )
    }
}

struct TMDBCreditsResponse: Codable {
    let cast: [TMDBCastMember]?
    let crew: [TMDBCrewMember]?
}

struct TMDBCrewMember: Codable {
    let id: Int?
    let name: String?
    let job: String?
    let department: String?
    let profilePath: String?
    let jobs: [TMDBJob]?

    enum CodingKeys: String, CodingKey {
        case id, name, job, department, jobs
        case profilePath = "profile_path"
    }
}

struct TMDBJob: Codable {
    let job: String?
}

struct TMDBCastMember: Codable {
    let id: Int?
    let name: String?
    let character: String?
    let roles: [TMDBRole]?
    let profilePath: String?
    let order: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, character, roles, order
        case profilePath = "profile_path"
    }
}

struct TMDBAggregateCreditsResponse: Codable {
    let cast: [TMDBCastMember]?
    let crew: [TMDBCrewMember]?
}

struct TMDBRole: Codable {
    let character: String?
}

struct TMDBImagesResponse: Codable {
    let posters: [TMDBImage]?
    let logos: [TMDBImage]?
    
    var bestLogoURL: URL? {
        guard let logos = logos else { return nil }
        let pngLogos = logos.filter { $0.filePath?.lowercased().hasSuffix(".png") == true }
        let match = pngLogos.first(where: { $0.iso639_1 == "en" }) ?? pngLogos.first
        guard let path = match?.filePath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500" + path)
    }
    
    var cleanPosterURL: URL? {
        guard let posters = posters else { return nil }
        guard let match = posters.first(where: { $0.iso639_1 == nil && !($0.filePath?.lowercased().hasSuffix(".svg") ?? false) }) else { return nil }
        guard let path = match.filePath else { return nil }
        return URL(string: Config.tmdbImageBase + path)
    }
}

struct TMDBImage: Codable {
    let filePath: String?
    let iso639_1: String?

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case iso639_1 = "iso_639_1"
    }
}

struct TMDBNextEpisodeToAir: Codable {
    let seasonNumber: Int?
    let episodeNumber: Int?
    let airDate: String?
    let name: String?
    let stillPath: String?

    enum CodingKeys: String, CodingKey {
        case name
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
        case airDate = "air_date"
        case stillPath = "still_path"
    }
}

struct TMDBContentRatingsResponse: Codable {
    let results: [TMDBContentRating]?
}

struct TMDBContentRating: Codable {
    let iso_3166_1: String?
    let rating: String?
}

struct TMDBReleaseDatesResponse: Codable {
    let results: [TMDBReleaseDateItem]?
}

struct TMDBReleaseDateItem: Codable {
    let iso_3166_1: String?
    let release_dates: [TMDBReleaseDateEntry]?
}

struct TMDBReleaseDateEntry: Codable {
    let certification: String?
}

// MARK: - Collection

struct TMDBCollectionStub: Codable {
    let id: Int?
    let name: String?
    let posterPath: String?
    let backdropPath: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }
}

struct TMDBCollectionResponse: Codable {
    let id: Int?
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let parts: [TMDBResult]?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, parts
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }
}

// MARK: - Keywords

struct TMDBKeywordsWrapper: Codable {
    // Movies use "keywords", TV shows use "results"
    let keywords: [TMDBKeyword]?
    let results: [TMDBKeyword]?

    var all: [TMDBKeyword] { keywords ?? results ?? [] }
}

struct TMDBKeyword: Codable, Identifiable {
    let id: Int
    let name: String
}

// MARK: - Reviews

struct TMDBReviewsResponse: Codable {
    let results: [TMDBReview]?
}

struct TMDBReview: Codable, Identifiable {
    let id: String
    let author: String?
    let content: String?
    let createdAt: String?
    let authorDetails: TMDBReviewAuthorDetails?

    enum CodingKeys: String, CodingKey {
        case id, author, content
        case createdAt = "created_at"
        case authorDetails = "author_details"
    }
}

struct TMDBReviewAuthorDetails: Codable {
    let rating: Double?
    let avatarPath: String?

    enum CodingKeys: String, CodingKey {
        case rating
        case avatarPath = "avatar_path"
    }
}

// MARK: - Watch Providers

struct TMDBWatchProvidersResponse: Codable {
    let results: [String: TMDBWatchProviderCountry]?

    var us: TMDBWatchProviderCountry? { results?["US"] }
}

struct TMDBWatchProviderCountry: Codable {
    let link: String?
    let flatrate: [TMDBWatchProviderItem]?  // streaming
    let rent: [TMDBWatchProviderItem]?
    let buy: [TMDBWatchProviderItem]?
    let free: [TMDBWatchProviderItem]?
}

struct TMDBWatchProviderItem: Codable, Identifiable {
    let providerId: Int
    let providerName: String?
    let logoPath: String?
    let displayPriority: Int?

    var id: Int { providerId }

    enum CodingKeys: String, CodingKey {
        case providerId = "provider_id"
        case providerName = "provider_name"
        case logoPath = "logo_path"
        case displayPriority = "display_priority"
    }
}

// MARK: - Production Company

struct TMDBProductionCompany: Codable, Identifiable {
    let id: Int
    let name: String?
    let logoPath: String?
    let originCountry: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case logoPath = "logo_path"
        case originCountry = "origin_country"
    }
}
