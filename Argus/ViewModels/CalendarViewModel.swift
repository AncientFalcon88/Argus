import Foundation
import SwiftData
import SwiftUI

struct CalendarMonthGroup: Identifiable {
    let id: String
    let monthYearLabel: String
    let episodes: [CalendarEpisode]
}

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var episodes: [CalendarEpisode] = []

    // Grouped data for the new Apple-native UI
    @Published var upNext: [CalendarEpisode] = []
    @Published var thisWeek: [CalendarEpisode] = []
    
    @Published var groupedUpcoming: [CalendarMonthGroup] = []
    @Published var groupedRecentlyAired: [CalendarMonthGroup] = []

    private let tmdb = TMDBService.shared

    func loadCalendar(context: ModelContext) async {
        guard episodes.isEmpty else { return } // Already loaded
        isLoading = true
        defer { isLoading = false }

        var orderedTrackedIds = [Int]()
        var seenIds = Set<Int>()
        
        // Helper to add uniquely
        let addId = { (id: Int) in
            if !seenIds.contains(id) {
                seenIds.insert(id)
                orderedTrackedIds.append(id)
            }
        }
        
        // 1. Fetch tracked shows from API (full pagination)
        let pmdbToken = Config.apiKey
        if !pmdbToken.isEmpty {
            var page = 1
            var totalPages = 1
            while page <= totalPages {
                guard let url = URL(string: "https://publicmetadb.com/api/external/watched?perPage=500&page=\(page)") else { break }
                var req = URLRequest(url: url)
                req.setValue("Bearer \(pmdbToken)", forHTTPHeaderField: "Authorization")
                
                if let (data, _) = try? await URLSession.shared.data(for: req),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    let items = (json["items"] as? [[String: Any]]) ?? (json["data"] as? [[String: Any]]) ?? []
                    for item in items {
                        if let type = item["media_type"] as? String, type == "tv",
                           let tmdbId = item["tmdb_id"] as? Int {
                            addId(tmdbId)
                        }
                    }
                    if let tp = json["totalPages"] as? Int {
                        totalPages = tp
                    } else {
                        break
                    }
                    page += 1
                } else {
                    break
                }
            }
        }
        
        // 2. Fallback to local cache if API failed or offline
        if orderedTrackedIds.isEmpty {
            let watchedDescriptor = FetchDescriptor<CachedWatchEntry>()
            let watched = (try? context.fetch(watchedDescriptor)) ?? []
            let sortedWatched = watched.sorted { ($0.watchedAt ?? "") > ($1.watchedAt ?? "") }
            for w in sortedWatched where w.mediaType == "tv" {
                addId(w.tmdbId)
            }
        }
        
        // 3. Always include favorite shows
        let favDescriptor = FetchDescriptor<FavoriteItem>()
        let favs = (try? context.fetch(favDescriptor)) ?? []
        for f in favs {
            if f.category == .shows {
                addId(f.tmdbId)
            }
        }

        let idsToFetch = Array(orderedTrackedIds.prefix(250))
        
        var fetchedEpisodes: [CalendarEpisode] = []
        
        await withTaskGroup(of: [CalendarEpisode].self) { group in
            for tmdbId in idsToFetch {
                group.addTask {
                    return await self.fetchEpisodesForShow(tmdbId: tmdbId)
                }
            }
            
            for await showEpisodes in group {
                fetchedEpisodes.append(contentsOf: showEpisodes)
            }
        }
        
        self.episodes = fetchedEpisodes.sorted(by: { $0.airDate < $1.airDate })
        categorizeEpisodes()
        await fetchExactTimeForUpNext()
    }
    
    private func fetchExactTimeForUpNext() async {
        let tmdbKey = Config.tmdbAPIKey
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        
        var updatedUpNext = upNext
        
        for i in 0..<updatedUpNext.count {
            var ep = updatedUpNext[i]
            
            struct ExternalIDs: Codable { let tvdbId: Int?; let imdbId: String? }
            guard let extUrl = URL(string: "https://api.themoviedb.org/3/tv/\(ep.showId)/external_ids?api_key=\(tmdbKey)"),
                  let (extData, _) = try? await URLSession.shared.data(from: extUrl),
                  let extIds = try? d.decode(ExternalIDs.self, from: extData) else { continue }
            
            var tvmazeLookupUrl: URL?
            if let tvdbId = extIds.tvdbId {
                tvmazeLookupUrl = URL(string: "https://api.tvmaze.com/lookup/shows?thetvdb=\(tvdbId)")
            } else if let imdbId = extIds.imdbId {
                tvmazeLookupUrl = URL(string: "https://api.tvmaze.com/lookup/shows?imdb=\(imdbId)")
            }
            
            if let tvmazeLookupUrl = tvmazeLookupUrl {
                if let (tvmazeShowData, _) = try? await URLSession.shared.data(from: tvmazeLookupUrl) {
                    struct TVMazeNetwork: Codable { let name: String? }
                    struct TVMazeLinks: Codable { let nextepisode: TVMazeHref? }
                    struct TVMazeHref: Codable { let href: String? }
                    struct TVMazeShow: Codable {
                        let id: Int?
                        let network: TVMazeNetwork?
                        let webChannel: TVMazeNetwork?
                    }
                    
                    let tvmazeD = JSONDecoder()
                    if let tvmazeShow = try? tvmazeD.decode(TVMazeShow.self, from: tvmazeShowData) {
                        ep.networkName = tvmazeShow.network?.name ?? tvmazeShow.webChannel?.name
                        
                        if let showId = tvmazeShow.id {
                            let df = DateFormatter()
                            df.dateFormat = "yyyy-MM-dd"
                            let dateStr = df.string(from: ep.airDate)
                            
                            if let epUrl = URL(string: "https://api.tvmaze.com/shows/\(showId)/episodesbydate?date=\(dateStr)"),
                               let (tvmazeEpData, _) = try? await URLSession.shared.data(from: epUrl),
                               let episodesJson = try? JSONSerialization.jsonObject(with: tvmazeEpData) as? [[String: Any]] {
                                
                                // Match exact season/episode first (for double episodes that air on the same day)
                                var matchedEp = episodesJson.first { ($0["season"] as? Int) == ep.seasonNumber && ($0["number"] as? Int) == ep.episodeNumber }
                                
                                // Fallback: If not found, it might be an anime where TMDB/TVMaze season numbering differs.
                                if matchedEp == nil {
                                    matchedEp = episodesJson.first
                                }
                                
                                if let matched = matchedEp, let airstamp = matched["airstamp"] as? String {
                                    let isoFormatter = ISO8601DateFormatter()
                                    ep.exactAirtime = isoFormatter.date(from: airstamp)
                                }
                            }
                        }
                    }
                }
            }
            
            updatedUpNext[i] = ep
            
            // Also update in self.episodes
            if let idx = self.episodes.firstIndex(where: { $0.id == ep.id }) {
                self.episodes[idx] = ep
            }
        }
        
        let now = Date()
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)
        
        var validUpNext: [CalendarEpisode] = []
        for ep in updatedUpNext {
            if let exactDate = ep.exactAirtime {
                // If we have a precise airtime, only keep it if it hasn't aired yet
                if exactDate > now {
                    validUpNext.append(ep)
                }
                // else: exactAirtime passed → falls to Recently Aired
            } else {
                // No exact airtime: keep if air date is today or future
                let calendarDay = cal.startOfDay(for: ep.airDate)
                if calendarDay >= todayStart {
                    validUpNext.append(ep)
                }
            }
        }
        
        validUpNext.sort { ($0.exactAirtime ?? $0.airDate) < ($1.exactAirtime ?? $1.airDate) }
        
        if let firstFuture = validUpNext.first {
            let upNextDate = cal.startOfDay(for: firstFuture.exactAirtime ?? firstFuture.airDate)
            self.upNext = validUpNext.filter { cal.startOfDay(for: $0.exactAirtime ?? $0.airDate) == upNextDate }
        } else {
            self.upNext = []
        }
        
        // Re-categorize the lists now that exactAirtime is populated for upcoming items
        categorizeEpisodes(updateUpNext: false)
    }
    
    private func fetchEpisodesForShow(tmdbId: Int) async -> [CalendarEpisode] {
        do {
            let detail = try await tmdb.fetchDetailInfo(tmdbId: tmdbId, mediaType: .tv)
            let allSeasons = detail.seasons.map({ $0.seasonNumber }).sorted(by: >)
            guard !allSeasons.isEmpty else {
                return []
            }
            
            // Fetch the top two regular seasons + season 0 if it exists
            var seasonsToFetch = Array(allSeasons.filter { $0 > 0 }.prefix(2))
            if allSeasons.contains(0) {
                seasonsToFetch.append(0)
            }
            
            var calEpisodes: [CalendarEpisode] = []
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let now = Date()
            
            for seasonNum in seasonsToFetch {
                let seasonEpisodes = try await tmdb.fetchSeasonEpisodes(tmdbId: tmdbId, season: seasonNum)
                
                for ep in seasonEpisodes {
                    guard let airDateStr = ep.airDate, !airDateStr.isEmpty, let date = dateFormatter.date(from: airDateStr) else { continue }
                    
                    let daysDiff = Calendar.current.dateComponents([.day], from: now, to: date).day ?? 0
                    if daysDiff >= -365 && daysDiff <= 365 {
                        let isPremiere = ep.episodeNumber == 1
                        let isFinale = ep.episodeNumber == seasonEpisodes.count
                        
                        let logoPath = detail.logoPath
                        let textlessPoster = detail.textlessPosterPath
                        
                        calEpisodes.append(CalendarEpisode(
                            id: "\(tmdbId)-\(seasonNum)-\(ep.episodeNumber)",
                            showId: tmdbId,
                            showTitle: detail.title,
                            posterPath: detail.posterPath,
                            textlessPosterPath: textlessPoster,
                            logoPath: logoPath,
                            seasonNumber: seasonNum,
                            episodeNumber: ep.episodeNumber,
                            episodeTitle: ep.name,
                            overview: ep.overview ?? "",
                            airDate: date,
                            isPremiere: isPremiere,
                            isFinale: isFinale
                        ))
                    }
                }
            }
            
            return calEpisodes
        } catch {
            return []
        }
    }

    private func categorizeEpisodes(updateUpNext: Bool = true) {
        let now = Date()
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: todayStart) ?? todayStart
        
        // Use exactAirtime if available, otherwise fallback to start of airDate.
        // Include episodes from up to 2 days ago to account for TMDB timezone drift
        let futureOrToday = episodes.filter { ep in
            if let exact = ep.exactAirtime {
                return exact > now
            }
            // Fallback: If no exact time, check if it's today or later
            return cal.startOfDay(for: ep.airDate) >= todayStart
        }.sorted(by: { ($0.exactAirtime ?? cal.startOfDay(for: $0.airDate)) < ($1.exactAirtime ?? cal.startOfDay(for: $1.airDate)) })
        
        if updateUpNext {
            // Grab the next 50 upcoming/recent episodes. `fetchExactTimeForUpNext()` will correctly filter this!
            upNext = Array(futureOrToday.prefix(50))
        }
        
        // thisWeek / upcoming logic
        let oneWeekFromNow = cal.date(byAdding: .day, value: 7, to: todayStart) ?? now
        let allThisWeek = futureOrToday.filter { cal.startOfDay(for: $0.airDate) <= oneWeekFromNow }
        thisWeek = Array(allThisWeek.prefix(200))
        
        // Anything not in thisWeek (future items + anything over the 200 cap) flows into upcoming
        let upcomingList = Array(futureOrToday.filter { !thisWeek.contains($0) }.prefix(9999))
        
        let recentlyAiredList = Array(episodes.filter { ep in
            if let exact = ep.exactAirtime {
                return exact <= now
            }
            return cal.startOfDay(for: ep.airDate) < todayStart
        }.sorted(by: { ($0.exactAirtime ?? cal.startOfDay(for: $0.airDate)) > ($1.exactAirtime ?? cal.startOfDay(for: $1.airDate)) }).prefix(9999))
        
        groupedUpcoming = groupEpisodesByMonth(upcomingList)
        groupedRecentlyAired = groupEpisodesByMonth(recentlyAiredList, descending: true)
    }
    
    private func groupEpisodesByMonth(_ episodesToGroup: [CalendarEpisode], descending: Bool = false) -> [CalendarMonthGroup] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        var dict: [String: [CalendarEpisode]] = [:]
        for ep in episodesToGroup {
            // Create a standardized key for sorting purposes (YYYY-MM)
            let month = cal.component(.month, from: ep.airDate)
            let year = cal.component(.year, from: ep.airDate)
            let sortKey = String(format: "%04d-%02d", year, month)
            
            dict[sortKey, default: []].append(ep)
        }
        
        let sortedKeys = descending ? dict.keys.sorted(by: >) : dict.keys.sorted(by: <)
        return sortedKeys.map { sortKey in
            let eps = dict[sortKey]!
            let label = formatter.string(from: eps.first!.airDate)
            return CalendarMonthGroup(id: sortKey, monthYearLabel: label, episodes: eps)
        }
    }
    
    // MARK: - Consistent Formatters
    
    func formatSeasonEpisode(_ ep: CalendarEpisode) -> String {
        return String(format: "S%02d · E%02d", ep.seasonNumber, ep.episodeNumber)
    }
    
    func explicitDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    func countdownText(for date: Date, exactAirtime: Date? = nil) -> String {
        if let exactDate = exactAirtime {
            let timeInterval = exactDate.timeIntervalSinceNow
            if timeInterval < 0 {
                return "Aired"
            } else if timeInterval < 3600 {
                let minutes = Int(timeInterval / 60)
                return "Airing in \(minutes)m"
            } else if timeInterval < 86400 {
                let hours = Int(timeInterval / 3600)
                return "Airing in \(hours)h"
            }
        }
        
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let targetStart = cal.startOfDay(for: date)
        let components = cal.dateComponents([.day], from: todayStart, to: targetStart)
        let days = components.day ?? 0
        
        if days == 0 {
            return "Airing Today"
        } else if days == 1 {
            return "Airing Tomorrow"
        } else if days < 0 {
            return "Aired \(abs(days)) days ago"
        } else {
            return "Airing in \(days) days"
        }
    }
    
    func formattedDateString(for episode: CalendarEpisode) -> String {
        let countdown = countdownText(for: episode.airDate, exactAirtime: episode.exactAirtime)
        if countdown.starts(with: "Airing in") && countdown.hasSuffix("M") {
            return countdown
        }
        if countdown.starts(with: "Airing in") && countdown.hasSuffix("H") {
            return countdown
        }
        if countdown == "Airing Today" || countdown == "Aired" {
            return countdown
        }
        return "\(countdown) · \(explicitDateText(for: episode.airDate))"
    }
}
