import Foundation

enum Config {
    static let baseURL = URL(string: "https://publicmetadb.com")!
    static let tmdbAPIBase = URL(string: "https://api.themoviedb.org/3")!
    static let tmdbImageBase = "https://image.tmdb.org/t/p/w500"
    static let defaultPerPage = 100
    static let maxBatchSize = 50

    static var apiKey: String {
        let stored = KeychainStore.load(account: SettingsKeychainAccount.publicMetaDB.rawValue) ?? ""
        return SettingsStore.isPlaceholder(stored) ? "" : stored
    }

    static var pbToken: String {
        let stored = KeychainStore.load(account: SettingsKeychainAccount.pbToken.rawValue) ?? ""
        return SettingsStore.isPlaceholder(stored) ? "" : stored
    }

    static var tmdbAPIKey: String {
        let stored = KeychainStore.load(account: SettingsKeychainAccount.tmdb.rawValue) ?? ""
        return SettingsStore.isPlaceholder(stored) ? "" : stored
    }

    static var isAPIKeyConfigured: Bool {
        !apiKey.isEmpty
    }

    static func posterURL(path: String?) -> URL? {
        tmdbImageURL(path: path, size: "w500")
    }

    static func backdropURL(path: String?) -> URL? {
        tmdbImageURL(path: path, size: "w780")
    }

    static func tmdbImageURL(path: String?, size: String) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        let normalized = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(normalized)")
    }

    static func displayTitle(title: String?, tmdbId: Int) -> String {
        if let title, !TMDBIDResolver.isPlaceholderTitle(title) {
            return title
        }
        let resolved = TMDBIDResolver.resolve(numericId: tmdbId, displayTitle: title) ?? tmdbId
        return resolved > 0 ? "Loading…" : "Unknown title"
    }
}

enum SettingsKeychainAccount: String {
    case publicMetaDB = "publicmetadb.api.key"
    case tmdb = "tmdb.api.key"
    case pbToken = "publicmetadb.pb.token"
}
