import Foundation

// MARK: - API Models

struct FavoriteAPIItem: Codable, Identifiable {
    let id: String
    let collectionName: String?
    let user: String?
    let mediaType: String?
    let period: String?
    let periodKey: String?
    let slot: Int?
    let tmdbId: Int?
    let listRef: String?
    let title: String?
    let posterPath: String?
    let year: String?
    let why: String?
    let created: String?
    let updated: String?

    enum CodingKeys: String, CodingKey {
        case id, user, slot, title, year, why, created, updated
        case collectionName = "collectionName"
        case mediaType = "media_type"
        case period
        case periodKey = "period_key"
        case tmdbId = "tmdb_id"
        case listRef = "list_ref"
        case posterPath = "poster_path"
    }
}

struct FavoriteAPIResponse: Codable {
    let items: [FavoriteAPIItem]
    let page: Int?
    let perPage: Int?
    let totalItems: Int?
    let totalPages: Int?
}

struct SaveFavoriteRequest: Codable {
    let user: String
    let mediaType: String
    let period: String
    let periodKey: String
    let slot: Int
    let tmdbId: Int
    let listRef: String
    let title: String
    let posterPath: String
    let year: String
    let why: String

    enum CodingKeys: String, CodingKey {
        case user, slot, title, year, why
        case mediaType = "media_type"
        case period
        case periodKey = "period_key"
        case tmdbId = "tmdb_id"
        case listRef = "list_ref"
        case posterPath = "poster_path"
    }
}

// MARK: - Service

final class FavoritesService {
    static let shared = FavoritesService()
    private let pbBase = URL(string: "https://api.publicmetadb.com")!
    private let session = URLSession.shared

    private init() {}

    private var pbToken: String {
        KeychainStore.load(account: SettingsKeychainAccount.pbToken.rawValue) ?? ""
    }

    private var userId: String {
        UserDefaults.standard.string(forKey: "publicmetadb.user.id") ?? ""
    }

    var isLoggedIn: Bool { !pbToken.isEmpty && !userId.isEmpty }

    // MARK: - Fetch

    func fetchMyFavorites() async throws -> [FavoriteAPIItem] {
        guard isLoggedIn else { return [] }

        // Check if token is expired to prevent PocketBase returning [] as a guest and wiping local DB
        if let exp = decodeJWTExp(token: pbToken), exp < Date() {
            throw URLError(.userAuthenticationRequired)
        }

        let filter = "user=\"\(userId)\""
        guard var components = URLComponents(url: pbBase.appendingPathComponent("/api/collections/favorites/records"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "filter", value: filter),
            URLQueryItem(name: "perPage", value: "9999")
        ]
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(pbToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        let msg = String(data: data, encoding: .utf8) ?? "No data"
        print("[Favorites] Fetch status: \(status), URL: \(url), Response: \(msg.prefix(500))")
        
        guard (200...299).contains(status) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(FavoriteAPIResponse.self, from: data)
        return decoded.items
    }

    // MARK: - Save (Create or Update)

    @discardableResult
    func saveFavorite(remoteId: String?, request: SaveFavoriteRequest) async throws -> String {
        guard isLoggedIn else { throw URLError(.userAuthenticationRequired) }

        // 1. Check if it already exists on the server to prevent unique constraint errors
        let filter = "user=\"\(request.user)\" && media_type=\"\(request.mediaType)\" && period=\"\(request.period)\" && period_key=\"\(request.periodKey)\" && slot=\(request.slot)"
        var checkComponents = URLComponents(url: pbBase.appendingPathComponent("/api/collections/favorites/records"), resolvingAgainstBaseURL: false)!
        checkComponents.queryItems = [
            URLQueryItem(name: "filter", value: filter),
            URLQueryItem(name: "perPage", value: "1")
        ]
        
        var existingId: String? = remoteId
        if let checkUrl = checkComponents.url {
            var checkReq = URLRequest(url: checkUrl)
            checkReq.setValue("Bearer \(pbToken)", forHTTPHeaderField: "Authorization")
            if let (data, resp) = try? await session.data(for: checkReq),
               let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let items = json["items"] as? [[String: Any]],
                   let firstItem = items.first,
                   let id = firstItem["id"] as? String {
                    existingId = id
                }
            }
        }

        let path: String
        let method: String
        if let targetId = existingId, !targetId.isEmpty {
            path = "/api/collections/favorites/records/\(targetId)"
            method = "PATCH"
        } else {
            path = "/api/collections/favorites/records"
            method = "POST"
        }

        guard let url = URL(string: "https://api.publicmetadb.com\(path)") else { throw URLError(.badURL) }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(pbToken)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(status) else {
            let msg = String(data: data, encoding: .utf8) ?? "Server error"
            print("[Favorites] Save error \(status): \(msg)")
            throw URLError(.badServerResponse)
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = json["id"] as? String {
            return id
        }
        return existingId ?? ""
    }

    // MARK: - Delete

    func deleteFavorite(remoteId: String) async throws {
        guard isLoggedIn, !remoteId.isEmpty else { return }
        guard let url = URL(string: "https://api.publicmetadb.com/api/collections/favorites/records/\(remoteId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(pbToken)", forHTTPHeaderField: "Authorization")
        let (_, _) = try await session.data(for: request)
    }

    // MARK: - Helpers
    private func decodeJWTExp(token: String) -> Date? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return nil }
        var base64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else { return nil }
        return Date(timeIntervalSince1970: exp)
    }
}

// MARK: - Mapping Helpers

extension FavoriteTimePeriod {
    /// Maps to the `period` field used in the PocketBase collection
    var apiPeriod: String {
        switch self {
        case .allTime:   return "all_time"
        case .thisYear:  return "year"
        case .thisMonth: return "month"
        }
    }

    /// Maps to the `period_key` field (e.g. "all", "2026", "2026-06")
    var apiPeriodKey: String {
        switch self {
        case .allTime:
            return "all"
        case .thisYear:
            let year = Calendar.current.component(.year, from: Date())
            return "\(year)"
        case .thisMonth:
            let cal = Calendar.current
            let year = cal.component(.year, from: Date())
            let month = cal.component(.month, from: Date())
            return String(format: "%04d-%02d", year, month)
        }
    }

    static func from(apiPeriod: String) -> FavoriteTimePeriod {
        switch apiPeriod {
        case "all_time": return .allTime
        case "year":     return .thisYear
        case "month":    return .thisMonth
        default:         return .allTime
        }
    }
}

extension FavoriteCategory {
    var apiMediaType: String {
        switch self {
        case .films: return "movie"
        case .shows: return "tv"
        case .lists: return "list"
        }
    }

    static func from(apiMediaType: String) -> FavoriteCategory {
        switch apiMediaType {
        case "movie": return .films
        case "tv":    return .shows
        case "list":  return .lists
        default:      return .films
        }
    }
}
