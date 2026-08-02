import Foundation

// MARK: - Core Profile Info
struct StatProfile: Equatable {
    var username: String
    var avatarInitials: String
    var level: Int
    var totalContributions: Int
    var dayStreak: Int
    var activeDays: Int
}

// MARK: - Core Metrics
struct StatMetrics: Equatable {
    var ratings: Int
    var skips: Int
    var highlights: Int
    var idMappings: Int
    var titlesHelped: Int
}

// MARK: - Progress & Heatmap
struct StatProgress: Equatable {
    var currentLevel: Int
    var nextLevel: Int
    var progressPercentage: Double
    var hintText: String
    
    /// True means contribution made on that day (last 30 days)
    var activityHeatmap: [Bool]
}

// MARK: - Badges
struct AchievementBadge: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var description: String
    var iconName: String
    var isUnlocked: Bool
}

// MARK: - History
struct ContributionHistoryItem: Identifiable, Equatable {
    let id = UUID()
    var tmdbId: Int
    var mediaType: MediaType
    var title: String
    var posterPath: String?
    
    // What the user did
    var ratingCount: Int = 0
    var skipCount: Int = 0
    var highlightCount: Int = 0
    var mappingCount: Int = 0
    
    var date: Date
}

// MARK: - API Response Models

struct LogsStatsResponse: Codable {
    let summary: LogsStatsSummary
    let ratings: [LogStatItem]
    let skips: [LogStatSkipItem]
    let highlights: [LogStatItem]
    let mappings: [LogStatItem]
}

struct LogsStatsSummary: Codable {
    let totalRatings: Int
    let totalSkips: Int
    let totalHighlights: Int
    let totalMappings: Int
    let uniqueItems: Int?
}

struct LogStatItem: Codable {
    let updated: String
    let tmdb_id: Int?
    let media_type: String?
}

struct LogStatSkipItem: Codable {
    let updated: String
    let tmdb_id: Int?
    let media_type: String?
    let intro_start_ms: Int?
    let intro_end_ms: Int?
    let credits_start_ms: Int?
    let credits_end_ms: Int?
}
