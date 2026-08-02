import Foundation
import SwiftData

enum FavoriteCategory: String, Codable {
    case films = "Films"
    case shows = "Shows"
    case lists = "Lists"
}

enum FavoriteTimePeriod: String, Codable {
    case allTime = "All-Time"
    case thisYear = "This Year"
    case thisMonth = "This Month"
}

@Model
final class FavoriteItem {
    var tmdbId: Int
    var listId: String?
    var remoteId: String?      // PocketBase record ID for server sync
    var category: FavoriteCategory
    var timePeriod: FavoriteTimePeriod
    var slotIndex: Int // 0, 1, 2, or 3
    
    var title: String
    var posterPath: String?
    var releaseYear: String?
    var reasonText: String
    
    init(tmdbId: Int, listId: String? = nil, remoteId: String? = nil, category: FavoriteCategory, timePeriod: FavoriteTimePeriod, slotIndex: Int, title: String, posterPath: String? = nil, releaseYear: String? = nil, reasonText: String = "") {
        self.tmdbId = tmdbId
        self.listId = listId
        self.remoteId = remoteId
        self.category = category
        self.timePeriod = timePeriod
        self.slotIndex = slotIndex
        self.title = title
        self.posterPath = posterPath
        self.releaseYear = releaseYear
        self.reasonText = reasonText
    }
}
