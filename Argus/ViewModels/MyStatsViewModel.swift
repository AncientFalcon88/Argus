import Foundation
import SwiftUI

@MainActor
final class MyStatsViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var profile: StatProfile?
    @Published var metrics: StatMetrics?
    @Published var progress: StatProgress?
    @Published var badges: [AchievementBadge] = []
    @Published var history: [ContributionHistoryItem] = []
    
    init() {
        // Will be fetched manually or via task
    }
    
    func refresh(context: AppState) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let statsService = MyStatsService()
            let progressService = MyProgressService()
            
            // Fetch raw stats to calculate things
            let logsStats = try await statsService.fetchLogsStats()
            
            let totalContribs = logsStats.summary.totalRatings + logsStats.summary.totalSkips + logsStats.summary.totalHighlights + logsStats.summary.totalMappings
            
            // Calculate skips details
            var introSkips = 0
            var outroSkips = 0
            for skip in logsStats.skips {
                if skip.intro_start_ms != nil && skip.intro_end_ms != nil {
                    introSkips += 1
                }
                if skip.credits_start_ms != nil && skip.credits_end_ms != nil {
                    outroSkips += 1
                }
            }
            
            // Calculate Streaks & XP
            let xp = (logsStats.summary.totalRatings * 10) + (logsStats.summary.totalSkips * 50) + (logsStats.summary.totalHighlights * 25) + (logsStats.summary.totalMappings * 15)
            let level = Int(floor(sqrt(Double(xp) / 100.0))) + 1
            let prevLevelBaseXp = Int(pow(Double(level - 1), 2.0) * 100.0)
            let nextLevelBaseXp = Int(pow(Double(level), 2.0) * 100.0)
            
            let xpProgress = xp - prevLevelBaseXp
            let xpTotal = nextLevelBaseXp - prevLevelBaseXp
            let progressPercent = min(1.0, max(0.0, Double(xpProgress) / Double(xpTotal)))
            
            // Calculate active days
            let df1 = DateFormatter()
            df1.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSZ"
            df1.locale = Locale(identifier: "en_US_POSIX")
            
            let df2 = DateFormatter()
            df2.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
            df2.locale = Locale(identifier: "en_US_POSIX")
            
            let df3 = ISO8601DateFormatter()
            df3.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let df4 = ISO8601DateFormatter()
            
            func parseDate(_ str: String) -> Date? {
                let sanitized = str.replacingOccurrences(of: "Z", with: "+0000")
                return df1.date(from: sanitized) ?? 
                       df2.date(from: sanitized) ?? 
                       df1.date(from: str) ?? 
                       df2.date(from: str) ?? 
                       df3.date(from: str) ?? 
                       df4.date(from: str)
            }
            
            var allDates: [Date] = []
            allDates.append(contentsOf: logsStats.ratings.compactMap { parseDate($0.updated) })
            allDates.append(contentsOf: logsStats.skips.compactMap { parseDate($0.updated) })
            allDates.append(contentsOf: logsStats.highlights.compactMap { parseDate($0.updated) })
            allDates.append(contentsOf: logsStats.mappings.compactMap { parseDate($0.updated) })
            
            let calendar = Calendar.current
            let midnightDates = allDates.map { calendar.startOfDay(for: $0) }
            let uniqueSortedDates = Array(Set(midnightDates)).sorted(by: >) // newest first
            
            var streak = 0
            let today = calendar.startOfDay(for: Date())
            if let firstDate = uniqueSortedDates.first, (firstDate == today || firstDate == calendar.date(byAdding: .day, value: -1, to: today)!) {
                streak = 1
                var currentDate = firstDate
                for i in 1..<uniqueSortedDates.count {
                    if let expectedNext = calendar.date(byAdding: .day, value: -1, to: currentDate),
                       uniqueSortedDates[i] == expectedNext {
                        streak += 1
                        currentDate = expectedNext
                    } else {
                        break
                    }
                }
            }
            
            // Build heatmap
            var heatmap = [Bool](repeating: false, count: 30)
            for i in 0..<30 {
                let targetDate = calendar.date(byAdding: .day, value: -29 + i, to: today)!
                if uniqueSortedDates.contains(targetDate) {
                    heatmap[i] = true
                }
            }
            
            // Extract unique items contributed to
            struct UniqueItem: Hashable {
                let tmdbId: Int
                let mediaType: String
            }
            var uniqueItems = Set<UniqueItem>()
            
            for item in logsStats.ratings {
                if let id = item.tmdb_id, let type = item.media_type { uniqueItems.insert(UniqueItem(tmdbId: id, mediaType: type)) }
            }
            for item in logsStats.skips {
                if let id = item.tmdb_id, let type = item.media_type { uniqueItems.insert(UniqueItem(tmdbId: id, mediaType: type)) }
            }
            for item in logsStats.highlights {
                if let id = item.tmdb_id, let type = item.media_type { uniqueItems.insert(UniqueItem(tmdbId: id, mediaType: type)) }
            }
            for item in logsStats.mappings {
                if let id = item.tmdb_id, let type = item.media_type { uniqueItems.insert(UniqueItem(tmdbId: id, mediaType: type)) }
            }
            
            let movieCount = uniqueItems.filter { $0.mediaType == "movie" }.count
            let tvCount = uniqueItems.filter { $0.mediaType == "tv" }.count
            
            let username = SettingsStore.shared.contributorName
            self.profile = StatProfile(
                username: username,
                avatarInitials: String(username.prefix(2)).uppercased(),
                level: level,
                totalContributions: totalContribs,
                dayStreak: streak,
                activeDays: uniqueSortedDates.count
            )
            
            self.metrics = StatMetrics(
                ratings: logsStats.summary.totalRatings,
                skips: logsStats.summary.totalSkips,
                highlights: logsStats.summary.totalHighlights,
                idMappings: logsStats.summary.totalMappings,
                titlesHelped: uniqueItems.count
            )
            
            let xpRemaining = xpTotal - xpProgress
            let skipsLeft = Int(ceil(Double(xpRemaining) / 50.0))
            let ratingsLeft = Int(ceil(Double(xpRemaining) / 10.0))
            
            let hintText: String
            if skipsLeft <= 2 {
                hintText = "~\(skipsLeft) skip\(skipsLeft > 1 ? "s" : "") to go"
            } else if ratingsLeft <= 5 {
                hintText = "~\(ratingsLeft) rating\(ratingsLeft > 1 ? "s" : "") to go"
            } else {
                hintText = "~\(skipsLeft) skips or ~\(ratingsLeft) ratings to go"
            }
            
            self.progress = StatProgress(
                currentLevel: level,
                nextLevel: level + 1,
                progressPercentage: progressPercent,
                hintText: hintText,
                activityHeatmap: heatmap
            )
            
            // Calculate Badges
            let totalRatings = logsStats.summary.totalRatings
            let totalSkips = logsStats.summary.totalSkips
            let totalHighlights = logsStats.summary.totalHighlights
            let totalMappings = logsStats.summary.totalMappings
            
            self.badges = [
                AchievementBadge(title: "First Step", description: "Made your first contribution", iconName: "target", isUnlocked: totalContribs >= 1),
                AchievementBadge(title: "Critic", description: "Rated 10+ items", iconName: "star.circle", isUnlocked: totalRatings >= 10),
                AchievementBadge(title: "Lead Critic", description: "Rated 50+ items", iconName: "star.circle.fill", isUnlocked: totalRatings >= 50),
                AchievementBadge(title: "Film Buff", description: "Contributed to 10+ Movies", iconName: "film", isUnlocked: movieCount >= 10),
                AchievementBadge(title: "Binge Watcher", description: "Contributed to 10+ TV Shows", iconName: "tv", isUnlocked: tvCount >= 10),
                AchievementBadge(title: "Time Traveler", description: "Submitted 5+ skip segments", iconName: "clock.arrow.circlepath", isUnlocked: totalSkips >= 5),
                AchievementBadge(title: "Time Lord", description: "Submitted 25+ skip segments", iconName: "clock.fill", isUnlocked: totalSkips >= 25),
                AchievementBadge(title: "Intro Expert", description: "Submitted 10+ Intro skips", iconName: "play.circle", isUnlocked: introSkips >= 10),
                AchievementBadge(title: "Spotter", description: "Added 5+ content highlights", iconName: "flag", isUnlocked: totalHighlights >= 5),
                AchievementBadge(title: "Sentinel", description: "Added 25+ content highlights", iconName: "flag.fill", isUnlocked: totalHighlights >= 25),
                AchievementBadge(title: "Linker", description: "Added 5+ ID mappings", iconName: "link", isUnlocked: totalMappings >= 5),
                AchievementBadge(title: "Bridge Builder", description: "Added 25+ ID mappings", iconName: "link.badge.plus", isUnlocked: totalMappings >= 25),
                AchievementBadge(title: "Completionist", description: "Contributed all 4 types", iconName: "checkmark.seal.fill", isUnlocked: totalRatings > 0 && totalSkips > 0 && totalHighlights > 0 && totalMappings > 0),
                AchievementBadge(title: "Dedicated", description: "Active for 3 days in a row", iconName: "flame", isUnlocked: streak >= 3),
                AchievementBadge(title: "Marathoner", description: "7 Day Streak", iconName: "flame.fill", isUnlocked: streak >= 7),
                AchievementBadge(title: "Centurion", description: "100 Total Contributions", iconName: "rosette", isUnlocked: totalContribs >= 100),
                AchievementBadge(title: "Showstopper", description: "100+ Skip Contributions", iconName: "clock.badge.exclamationmark", isUnlocked: totalSkips >= 100),
                AchievementBadge(title: "Veteran", description: "Active for 30+ Days", iconName: "calendar.badge.clock", isUnlocked: uniqueSortedDates.count >= 30),
                AchievementBadge(title: "Elite", description: "Reached Level 10", iconName: "crown.fill", isUnlocked: level >= 10),
                AchievementBadge(title: "Explorer", description: "Help 50+ Unique Shows", iconName: "tv.badge.wifi", isUnlocked: tvCount >= 50)
            ]
            // Build recent history natively from contributions!
            // First, find all unique contributions sorted by most recent date.
            var uniqueHistoryMap: [String: ContributionHistoryItem] = [:]
            
            func processItems(_ items: [LogStatItem], type: String) {
                for item in items {
                    guard let tmdbId = item.tmdb_id, tmdbId > 0, let mTypeStr = item.media_type, let mType = MediaType(rawValue: mTypeStr) else { continue }
                    let date = parseDate(item.updated) ?? Date.distantPast
                    let key = "\(tmdbId)_\(mType.rawValue)"
                    
                    if uniqueHistoryMap[key] == nil {
                        uniqueHistoryMap[key] = ContributionHistoryItem(
                            tmdbId: tmdbId,
                            mediaType: mType,
                            title: "Loading...",
                            posterPath: nil,
                            date: date
                        )
                    }
                    
                    if date > uniqueHistoryMap[key]!.date {
                        uniqueHistoryMap[key]!.date = date
                    }
                    
                    switch type {
                    case "rating": uniqueHistoryMap[key]!.ratingCount += 1
                    case "skip": uniqueHistoryMap[key]!.skipCount += 1
                    case "highlight": uniqueHistoryMap[key]!.highlightCount += 1
                    case "mapping": uniqueHistoryMap[key]!.mappingCount += 1
                    default: break
                    }
                }
            }
            
            processItems(logsStats.ratings, type: "rating")
            processItems(logsStats.skips.map { LogStatItem(updated: $0.updated, tmdb_id: $0.tmdb_id, media_type: $0.media_type) }, type: "skip")
            processItems(logsStats.highlights, type: "highlight")
            processItems(logsStats.mappings, type: "mapping")
            
            // Sort by date descending and take ALL contributions
            let allSortedContributions = uniqueHistoryMap.values.sorted { $0.date > $1.date }
            
            self.history = allSortedContributions
        } catch {
            print("Failed to load My Stats: \(error)")
        }
    }
}
