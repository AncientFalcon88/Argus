import Foundation

/// Resolves TMDB numeric IDs from API fields or placeholder display strings like "TMDB 244786".
enum TMDBIDResolver {
    private static let placeholderPattern = #/(?i)^\s*TMDB\s*#?(\d+)\s*$/#

    static func resolve(numericId: Int, displayTitle: String?) -> Int? {
        if numericId > 0 { return numericId }
        return extractID(from: displayTitle)
    }

    static func extractID(from raw: String?) -> Int? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let match = trimmed.firstMatch(of: placeholderPattern) {
            return Int(match.1)
        }

        let upper = trimmed.uppercased()
        if let range = upper.range(of: "TMDB") {
            let suffix = trimmed[range.upperBound...]
            let digits = suffix.filter(\.isNumber)
            if let value = Int(String(digits)), value > 0 {
                return value
            }
        }

        if trimmed.allSatisfy(\.isNumber), let value = Int(trimmed) {
            return value
        }

        return nil
    }

    static func isPlaceholderTitle(_ title: String?) -> Bool {
        guard let title else { return true }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return trimmed.firstMatch(of: placeholderPattern) != nil
    }

    static func needsMetadata(title: String?, posterPath: String?, backdropPath: String? = "ignored", tmdbId: Int) -> Bool {
        let resolved = resolve(numericId: tmdbId, displayTitle: title) ?? 0
        guard resolved > 0 else { return false }
        
        if isPlaceholderTitle(title) { return true }
        if posterPath == nil || posterPath?.isEmpty == true { return true }
        if backdropPath != "ignored" && (backdropPath == nil || backdropPath?.isEmpty == true) { return true }
        
        return false
    }
}
