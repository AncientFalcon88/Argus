import Foundation
import SwiftUI

struct HeroCarouselItem: Identifiable, Equatable {
    let id: String
    let tmdbId: Int
    let mediaType: MediaType
    
    let title: String
    let overview: String
    let posterPath: String?
    let textlessPosterPath: String?
    let backdropPath: String?
    let logoPath: String?
    
    // Info pills
    let year: String?
    let runtime: Int?
    let voteAverage: Double?
    let pmdbAverageRating: Int?
    let contentRating: String? // e.g. "TV-MA" or "R"
    let communityRatings: [CommunityRatingSummary]?
    
    // Video background
    var imdbId: String?
    var trailerURL: URL?
    
    var posterURL: URL? {
        guard let path = textlessPosterPath ?? posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w780\(path)")
    }
    
    var logoURL: URL? {
        guard let path = logoPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }
    
    var displayYear: String? {
        guard let y = year, !y.isEmpty else { return nil }
        return String(y.prefix(4))
    }
    
    var displayRuntime: String? {
        guard let r = runtime, r > 0 else { return nil }
        let hours = r / 60
        let minutes = r % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var displayRating: String? {
        guard let v = voteAverage, v > 0 else { return nil }
        return String(format: "%.1f", v)
    }
}
