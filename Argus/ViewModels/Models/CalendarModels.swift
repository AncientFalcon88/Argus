import Foundation

enum CalendarFilter: String, CaseIterable, Equatable {
    case all = "ALL"
    case premieres = "PREMIERES"
    case finales = "FINALES"
}

enum CalendarViewMode: String, CaseIterable, Equatable {
    case week = "WEEK"
    case month = "MONTH"
}

struct CalendarEpisode: Identifiable, Hashable {
    let id: String
    let showId: Int
    let showTitle: String
    let posterPath: String?
    let textlessPosterPath: String?
    let logoPath: String?
    var seasonNumber: Int
    var episodeNumber: Int
    var episodeTitle: String
    let overview: String
    let airDate: Date
    let isPremiere: Bool
    let isFinale: Bool
    var exactAirtime: Date?
    var networkName: String?

    var formattedAirDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: airDate)
    }

    var posterURL: URL? {
        guard let posterPath = posterPath else { return nil }
        return Config.tmdbImageURL(path: posterPath, size: "w780")
    }
    
    var textlessPosterURL: URL? {
        guard let textlessPosterPath = textlessPosterPath else { return nil }
        return Config.tmdbImageURL(path: textlessPosterPath, size: "w780")
    }
    
    var logoURL: URL? {
        guard let logoPath = logoPath else { return nil }
        return Config.tmdbImageURL(path: logoPath, size: "w500")
    }
}
