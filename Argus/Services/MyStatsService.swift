import Foundation

final class MyStatsService: Sendable {
    
    private struct PBListResponse: Decodable {
        let totalItems: Int
        let items: [PBItem]
    }
    
    private struct PBItem: Decodable {
        let tmdb_id: Int?
        let media_type: String?
        let updated: String
        
        // For skips
        let intro_start_ms: Int?
        let intro_end_ms: Int?
        let credits_start_ms: Int?
        let credits_end_ms: Int?
    }
    
    func fetchLogsStats() async throws -> LogsStatsResponse {
        guard let userId = UserDefaults.standard.string(forKey: "publicmetadb.user.id"),
              let token = KeychainStore.load(account: SettingsKeychainAccount.pbToken.rawValue),
              !token.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        
        async let ratingsTask = fetchAllItems(collection: "ratings", userId: userId, token: token)
        async let skipsTask = fetchAllItems(collection: "skips", userId: userId, token: token)
        async let highlightsTask = fetchAllItems(collection: "highlights", userId: userId, token: token)
        async let mappingsTask = fetchAllItems(collection: "media_id_mappings", userId: userId, token: token)
        
        let (ratings, skips, highlights, mappings) = try await (ratingsTask, skipsTask, highlightsTask, mappingsTask)
        
        // Convert PBItems to the models expected by the UI
        let mappedRatings = ratings.items.map { LogStatItem(updated: $0.updated, tmdb_id: $0.tmdb_id ?? 0, media_type: $0.media_type ?? "") }
        let mappedSkips = skips.items.map { LogStatSkipItem(
            updated: $0.updated,
            tmdb_id: $0.tmdb_id ?? 0,
            media_type: $0.media_type ?? "",
            intro_start_ms: $0.intro_start_ms,
            intro_end_ms: $0.intro_end_ms,
            credits_start_ms: $0.credits_start_ms,
            credits_end_ms: $0.credits_end_ms
        )}
        let mappedHighlights = highlights.items.map { LogStatItem(updated: $0.updated, tmdb_id: $0.tmdb_id ?? 0, media_type: $0.media_type ?? "") }
        let mappedMappings = mappings.items.map { LogStatItem(updated: $0.updated, tmdb_id: $0.tmdb_id ?? 0, media_type: $0.media_type ?? "") }
        
        // Compute unique items
        var uniqueKeys = Set<String>()
        for item in ratings.items { uniqueKeys.insert("\(item.tmdb_id ?? 0)_\(item.media_type ?? "")") }
        for item in skips.items { uniqueKeys.insert("\(item.tmdb_id ?? 0)_\(item.media_type ?? "")") }
        for item in highlights.items { uniqueKeys.insert("\(item.tmdb_id ?? 0)_\(item.media_type ?? "")") }
        for item in mappings.items { uniqueKeys.insert("\(item.tmdb_id ?? 0)_\(item.media_type ?? "")") }
        
        let summary = LogsStatsSummary(
            totalRatings: ratings.totalItems,
            totalSkips: skips.totalItems,
            totalHighlights: highlights.totalItems,
            totalMappings: mappings.totalItems,
            uniqueItems: uniqueKeys.count
        )
        
        return LogsStatsResponse(
            summary: summary,
            ratings: mappedRatings,
            skips: mappedSkips,
            highlights: mappedHighlights,
            mappings: mappedMappings
        )
    }
    
    private func fetchAllItems(collection: String, userId: String, token: String) async throws -> (totalItems: Int, items: [PBItem]) {
        let baseURL = "https://api.publicmetadb.com/api/collections/\(collection)/records"
        let filter = "user='\(userId)'"
        // We fetch up to 500 at a time, selecting only the necessary fields to keep payloads tiny.
        let fields = "tmdb_id,media_type,updated,intro_start_ms,intro_end_ms,credits_start_ms,credits_end_ms"
        
        var firstPageComponents = URLComponents(string: baseURL)!
        firstPageComponents.queryItems = [
            URLQueryItem(name: "filter", value: filter),
            URLQueryItem(name: "fields", value: fields),
            URLQueryItem(name: "perPage", value: "500"),
            URLQueryItem(name: "page", value: "1")
        ]
        
        var req = URLRequest(url: firstPageComponents.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: req)
        let firstPage = try JSONDecoder().decode(PBListResponse.self, from: data)
        
        var allItems = firstPage.items
        let totalItems = firstPage.totalItems
        
        // If there are more pages, fetch them concurrently
        if totalItems > 500 {
            let totalPages = Int(ceil(Double(totalItems) / 500.0))
            if totalPages > 1 {
                try await withThrowingTaskGroup(of: [PBItem].self) { group in
                    for page in 2...totalPages {
                        group.addTask {
                            var components = URLComponents(string: baseURL)!
                            components.queryItems = [
                                URLQueryItem(name: "filter", value: filter),
                                URLQueryItem(name: "fields", value: fields),
                                URLQueryItem(name: "perPage", value: "500"),
                                URLQueryItem(name: "page", value: "\(page)")
                            ]
                            var pageReq = URLRequest(url: components.url!)
                            pageReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                            let (pageData, _) = try await URLSession.shared.data(for: pageReq)
                            let pageResponse = try JSONDecoder().decode(PBListResponse.self, from: pageData)
                            return pageResponse.items
                        }
                    }
                    for try await pageItems in group {
                        allItems.append(contentsOf: pageItems)
                    }
                }
            }
        }
        
        return (totalItems, allItems)
    }
}
