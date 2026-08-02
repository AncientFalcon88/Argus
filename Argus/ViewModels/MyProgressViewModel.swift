import Foundation

enum ProgressTab: String, CaseIterable {
    case stats = "Stats"
    case taste = "Taste"
}

@MainActor
final class MyProgressViewModel: ObservableObject {
    @Published var selectedTab: ProgressTab = .stats
    @Published var selectedYear: String = "ALL TIME"
    @Published var isLoading: Bool = false
    @Published var statsData: MyProgressStatsData? = nil
    
    @Published var availableYears: [String] = ["ALL TIME"] {
        didSet {
            if !availableYears.contains(selectedYear) {
                selectedYear = "ALL TIME"
            }
        }
    }
    
    // Caching for fast filtering
    private var cachedAllWatched: [WatchEntry] = []
    private var cachedDetailCache: [String: TMDBDetailResponse] = [:]
    private var cachedEpisodeRuntimes: [String: Int] = [:]
    private var cachedTotalRatings: Int = 0
    private var cachedUserAvgRating: Double? = nil
    private var cachedTasteData: TasteProfileData? = nil
    
    init() {
        loadData()
    }
    
    func loadData() {
        isLoading = true
        Task {
            // Yield to main thread to allow SwiftUI to start the loading animation
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            do {
                let (liveTaste, raw, computedYears) = try await Task.detached {
                    let service = MyProgressService()
                    let liveTaste = try await service.fetchTasteProfile()
                    let raw = try await service.fetchRawStatsData()
                    
                    // Determine available years off the main thread
                    let calendar = Calendar.current
                    let validDates = raw.allWatched.compactMap { $0.watchedDate }.sorted()
                    
                    var years = ["ALL TIME"]
                    if let first = validDates.first, let last = validDates.last {
                        let firstYear = calendar.component(.year, from: first)
                        let lastYear = calendar.component(.year, from: last)
                        if firstYear <= lastYear && firstYear > 2000 {
                            for y in (firstYear...lastYear).reversed() {
                                years.append("\(y)")
                            }
                        }
                    }
                    
                    return (liveTaste, raw, years)
                }.value
                
                self.cachedTasteData = liveTaste
                self.cachedAllWatched = raw.allWatched
                self.cachedTotalRatings = raw.totalRatings
                self.cachedUserAvgRating = raw.userAvgRating
                self.availableYears = computedYears
                
                // Pre-warm the TMDB detail cache by computing exact hours for all data
                await computeStats(for: self.selectedYear)
                
                self.isLoading = false
            } catch {
                print("Failed to load progress data: \(error)")
                self.isLoading = false
            }
        }
    }
    
    func refresh() {
        loadData()
    }
    
    func rebuildTaste() {
        isLoading = true
        Task {
            do {
                let service = MyProgressService()
                try await service.rebuildTasteProfile()
                let newTaste = try await service.fetchTasteProfile()
                self.cachedTasteData = newTaste
                await computeStats(for: self.selectedYear)
                self.isLoading = false
            } catch {
                print("Failed to rebuild live taste profile: \(error)")
                self.isLoading = false
            }
        }
    }
    
    func applyYearFilter() {
        Task {
            await computeStats(for: self.selectedYear)
        }
    }
    
    // MARK: - Compute Stats Engine
    
    private func computeStats(for yearStr: String) async {
        guard let tasteData = cachedTasteData else { return }
        
        let allWatched = cachedAllWatched
        let calendar = Calendar.current
        
        // 1. Offload Heavy Processing off Main Thread
        let computed = await Task.detached {
            let filteredWatched: [WatchEntry]
            if yearStr == "ALL TIME" {
                filteredWatched = allWatched
            } else if let targetYear = Int(yearStr) {
                filteredWatched = allWatched.filter {
                    if let d = $0.watchedDate {
                        return calendar.component(.year, from: d) == targetYear
                    }
                    return false
                }
            } else {
                filteredWatched = allWatched
            }
            
            var moviesCount = 0
            var episodesCount = 0
            var showsSet = Set<Int>()
            var validDates: [Date] = []
            
            for item in filteredWatched {
                if item.mediaType == .movie {
                    moviesCount += 1
                } else if item.mediaType == .tv {
                    episodesCount += 1
                    showsSet.insert(item.tmdbId)
                }
                if let date = item.watchedDate {
                    validDates.append(date)
                }
            }
            
            let showsCount = showsSet.count
            validDates.sort()
            
            let firstPlayDate = validDates.first ?? Date()
            let lastPlayDate = validDates.last ?? Date()
            
            var morning = 0, afternoon = 0, evening = 0, night = 0
            var dayCounts: [Date: Int] = [:]
            var monthlyDict: [Int: Int] = [:]
            var weeklyDict: [String: Int] = [:]
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "E"
            
            for d in validDates {
                let hour = calendar.component(.hour, from: d)
                if hour >= 6 && hour < 12 { morning += 1 }
                else if hour >= 12 && hour < 18 { afternoon += 1 }
                else if hour >= 18 { evening += 1 }
                else { night += 1 }
                
                let startOfDay = calendar.startOfDay(for: d)
                dayCounts[startOfDay, default: 0] += 1
                
                let month = calendar.component(.month, from: d)
                monthlyDict[month, default: 0] += 1
                
                let dayKey = dayFormatter.string(from: d)
                weeklyDict[dayKey, default: 0] += 1
            }
            
            let timeDist = ProgressTimeDistribution(morning: morning, afternoon: afternoon, evening: evening, night: night)
            let monthSymbols = calendar.shortMonthSymbols
            let watchedByMonth = monthSymbols.enumerated().map { index, symbol in
                ProgressMonthlyStat(month: symbol, count: monthlyDict[index + 1] ?? 0)
            }
            let watchedByDay = calendar.shortWeekdaySymbols.map { day in 
                ProgressDayStat(day: day, count: weeklyDict[day] ?? 0) 
            }
            
            var longestStreak = 0
            var currentStreak = 0
            var previousDate: Date?
            
            let sortedDays = dayCounts.keys.sorted()
            for day in sortedDays {
                if let prev = previousDate {
                    if let daysBetween = calendar.dateComponents([.day], from: prev, to: day).day, daysBetween == 1 {
                        currentStreak += 1
                    } else {
                        longestStreak = max(longestStreak, currentStreak)
                        currentStreak = 1
                    }
                } else {
                    currentStreak = 1
                }
                previousDate = day
            }
            longestStreak = max(longestStreak, currentStreak)
            
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: lastPlayDate) ?? Date()
            let activity = dayCounts
                .filter { $0.key >= thirtyDaysAgo }
                .map { ProgressActivityDay(date: $0.key, count: $0.value) }
                .sorted { $0.date < $1.date }
                
            let allActivity = dayCounts
                .map { ProgressActivityDay(date: $0.key, count: $0.value) }
                .sorted { $0.date < $1.date }
                
            return (filteredWatched, moviesCount, episodesCount, showsCount, firstPlayDate, lastPlayDate, timeDist, watchedByMonth, watchedByDay, currentStreak, longestStreak, activity, allActivity)
        }.value
        
        let filteredWatched = computed.0
        
        var updatedTaste = tasteData
        updatedTaste.avgRating = cachedTotalRatings > 0 ? cachedUserAvgRating : nil
        
        // 4. Exact Watch Hours from TMDB Cache
        let exactStats = await fetchExactWatchHours(for: filteredWatched)
        let exactWatchHours = exactStats.totalMinutes / 60
        
        var firstPlayTitle = filteredWatched.last?.displayTitle ?? "Unknown Item"
        if firstPlayTitle == "Unknown Item", let first = filteredWatched.last {
            if let detail = try? await TMDBService.shared.fetchDetailInfo(tmdbId: first.tmdbId, mediaType: first.mediaType) {
                firstPlayTitle = detail.title
            }
        }
        
        var lastPlayTitle = filteredWatched.first?.displayTitle ?? "Unknown Item"
        if lastPlayTitle == "Unknown Item", let last = filteredWatched.first {
            if let detail = try? await TMDBService.shared.fetchDetailInfo(tmdbId: last.tmdbId, mediaType: last.mediaType) {
                lastPlayTitle = detail.title
            }
        }
        
        let newData = MyProgressStatsData(
            watchTimeHours: exactWatchHours,
            episodesWatched: computed.2,
            moviesWatched: computed.1,
            showsWatched: computed.3,
            currentStreak: computed.9,
            bestStreak: computed.10,
            firstPlayTitle: firstPlayTitle,
            firstPlayDate: computed.4,
            lastPlayTitle: lastPlayTitle,
            lastPlayDate: computed.5,
            activityMap: computed.11,
            allActivityMap: computed.12,
            monthlyStats: computed.7,
            timeDistribution: computed.6,
            busiestDays: computed.8,
            topGenres: exactStats.topGenres,
            mostWatchedActors: exactStats.mostWatchedActors,
            mostWatchedDirectors: exactStats.mostWatchedDirectors,
            tasteData: updatedTaste
        )
        
        self.statsData = newData
    }
    
    // MARK: - TMDB Exact Match Hours Engine
    struct ExactWatchStats {
        let totalMinutes: Int
        let topGenres: [ProgressGenreStat]
        let mostWatchedActors: [ProgressPersonStat]
        let mostWatchedDirectors: [ProgressPersonStat]
    }
    
    private func fetchExactWatchHours(for entries: [WatchEntry]) async -> ExactWatchStats {
        var totalMinutes = 0
        
        let uniqueMovies = Set(entries.filter { $0.mediaType == .movie }.map { $0.tmdbId })
        let uniqueShows = Set(entries.filter { $0.mediaType == .tv }.map { $0.tmdbId })
        
        // Find unique seasons for exact episode runtimes
        struct SeasonKey: Hashable { let tmdbId: Int; let season: Int }
        var uniqueSeasons = Set<SeasonKey>()
        for entry in entries where entry.mediaType == .tv {
            if let s = entry.season, let e = entry.episode {
                let cacheKey = "\(entry.tmdbId)-\(s)-\(e)"
                // Only fetch if we don't already have it cached
                if cachedEpisodeRuntimes[cacheKey] == nil {
                    uniqueSeasons.insert(SeasonKey(tmdbId: entry.tmdbId, season: s))
                }
            }
        }
        
        // Fetch exact episode runtimes concurrently
        await withTaskGroup(of: [(String, Int)].self) { group in
            var iterator = uniqueSeasons.makeIterator()
            for _ in 0..<5 {
                if let skey = iterator.next() {
                    group.addTask {
                        do {
                            let episodes = try await TMDBService.shared.fetchSeasonEpisodes(tmdbId: skey.tmdbId, season: skey.season)
                            var results: [(String, Int)] = []
                            for ep in episodes {
                                if let r = ep.runtimeMinutes, r > 0 {
                                    results.append(("\(skey.tmdbId)-\(skey.season)-\(ep.episodeNumber)", r))
                                }
                            }
                            return results
                        } catch { return [] }
                    }
                }
            }
            for await result in group {
                for (k, r) in result { self.cachedEpisodeRuntimes[k] = r }
                if let skey = iterator.next() {
                    group.addTask {
                        do {
                            let episodes = try await TMDBService.shared.fetchSeasonEpisodes(tmdbId: skey.tmdbId, season: skey.season)
                            var results: [(String, Int)] = []
                            for ep in episodes {
                                if let r = ep.runtimeMinutes, r > 0 {
                                    results.append(("\(skey.tmdbId)-\(skey.season)-\(ep.episodeNumber)", r))
                                }
                            }
                            return results
                        } catch { return [] }
                    }
                }
            }
        }
        
        // Fetch missing movies concurrently
        await withTaskGroup(of: (String, TMDBDetailResponse)?.self) { group in
            var iterator = uniqueMovies.makeIterator()
            for _ in 0..<5 {
                if let tmdbId = iterator.next() {
                    let key = "movie-\(tmdbId)"
                    if cachedDetailCache[key] == nil {
                        group.addTask {
                            do { return (key, try await TMDBService.shared.fetchDetailPayloadDirect(tmdbId: tmdbId, mediaType: .movie, appendVideos: true)) }
                            catch { return nil }
                        }
                    } else {
                        group.addTask { return nil }
                    }
                }
            }
            for await result in group {
                if let (key, detail) = result { cachedDetailCache[key] = detail }
                if let tmdbId = iterator.next() {
                    let key = "movie-\(tmdbId)"
                    if cachedDetailCache[key] == nil {
                        group.addTask {
                            do { return (key, try await TMDBService.shared.fetchDetailPayloadDirect(tmdbId: tmdbId, mediaType: .movie, appendVideos: true)) }
                            catch { return nil }
                        }
                    } else {
                        group.addTask { return nil }
                    }
                }
            }
        }
        
        // Fetch missing shows concurrently
        await withTaskGroup(of: (String, TMDBDetailResponse)?.self) { group in
            var iterator = uniqueShows.makeIterator()
            for _ in 0..<5 {
                if let tmdbId = iterator.next() {
                    let key = "tv-\(tmdbId)"
                    if cachedDetailCache[key] == nil {
                        group.addTask {
                            do { return (key, try await TMDBService.shared.fetchDetailPayloadDirect(tmdbId: tmdbId, mediaType: .tv, appendVideos: true)) }
                            catch { return nil }
                        }
                    } else {
                        group.addTask { return nil }
                    }
                }
            }
            for await result in group {
                if let (key, detail) = result { cachedDetailCache[key] = detail }
                if let tmdbId = iterator.next() {
                    let key = "tv-\(tmdbId)"
                    if cachedDetailCache[key] == nil {
                        group.addTask {
                            do { return (key, try await TMDBService.shared.fetchDetailPayloadDirect(tmdbId: tmdbId, mediaType: .tv, appendVideos: true)) }
                            catch { return nil }
                        }
                    } else {
                        group.addTask { return nil }
                    }
                }
            }
        }
        
        var genreCounts: [String: Int] = [:]
        var actorStats: [Int: (name: String, profilePath: String?, count: Int)] = [:]
        var directorStats: [Int: (name: String, profilePath: String?, count: Int)] = [:]
        
        for entry in entries {
            var exactRuntime = 0
            let jsonRuntime = entry.runtime ?? entry.duration ?? entry.length ?? ((entry.runtimeMs ?? 0) / 60000)
            
            if jsonRuntime > 0 {
                exactRuntime = jsonRuntime
            } else if entry.mediaType == .tv, let s = entry.season, let e = entry.episode, let exactEpRuntime = cachedEpisodeRuntimes["\(entry.tmdbId)-\(s)-\(e)"] {
                exactRuntime = exactEpRuntime
            } else {
                let key = "\(entry.mediaType.rawValue)-\(entry.tmdbId)"
                if let detail = cachedDetailCache[key] {
                    if entry.mediaType == .movie {
                        exactRuntime = detail.runtime ?? 100
                    } else {
                        exactRuntime = detail.episodeRunTime?.first ?? detail.runtime ?? 30
                    }
                } else {
                    exactRuntime = entry.mediaType == .movie ? 100 : 30
                }
            }
            totalMinutes += exactRuntime
        }
        
        // Compute Genres, Actors, Directors from details
        // For stats, we iterate over the requested unique entries, NOT the whole cache
        let uniqueRequestedEntries = Array(Set(entries.map { "\(String(describing: $0.mediaType.rawValue))-\($0.tmdbId)" }))
        for key in uniqueRequestedEntries {
            if let detail = cachedDetailCache[key] {
                // Genres
                if let genres = detail.genres {
                    for genre in genres {
                        if let name = genre.name {
                            genreCounts[name, default: 0] += 1
                        }
                    }
                }
                
                // Actors
                if let cast = detail.aggregateCredits?.cast ?? detail.credits?.cast {
                    for actor in cast.prefix(5) {
                        if let id = actor.id, let name = actor.name {
                            actorStats[id, default: (name: name, profilePath: actor.profilePath, count: 0)].count += 1
                        }
                    }
                }
                
                // Directors
                if let crew = detail.credits?.crew {
                    for member in crew where member.job == "Director" {
                        if let id = member.id, let name = member.name {
                            directorStats[id, default: (name: name, profilePath: member.profilePath, count: 0)].count += 1
                        }
                    }
                }
            }
        }
        
        let sortedGenres = genreCounts.map { ProgressGenreStat(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }.prefix(10)
            
        let allSortedActors = actorStats.map { 
            ProgressPersonStat(name: $0.value.name, count: $0.value.count, profilePath: $0.value.profilePath, tmdbId: $0.key) 
        }.sorted { 
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.name < $1.name
        }
        
        let allSortedDirectors = directorStats.map { 
            ProgressPersonStat(name: $0.value.name, count: $0.value.count, profilePath: $0.value.profilePath, tmdbId: $0.key) 
        }.sorted { 
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.name < $1.name
        }
        
        let totalAllowed = 50
        let requestedDirectors = min(allSortedDirectors.count, 25)
        let finalActorsCount = min(allSortedActors.count, totalAllowed - requestedDirectors)
        let finalDirectorsCount = min(allSortedDirectors.count, totalAllowed - finalActorsCount)
        
        let finalActors = Array(allSortedActors.prefix(finalActorsCount))
        let finalDirectors = Array(allSortedDirectors.prefix(finalDirectorsCount))
        
        return ExactWatchStats(
            totalMinutes: totalMinutes,
            topGenres: Array(sortedGenres),
            mostWatchedActors: Array(finalActors),
            mostWatchedDirectors: Array(finalDirectors)
        )
    }
}


// MARK: - My Progress Service
struct TastePayload: Codable {
    let vector: TasteVector
    let version: Int
    let sampleSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case vector
        case version
        case sampleSize = "sample_size"
    }
}

struct TasteVector: Codable {
    let avgPopularity: Double?
    let avgRuntime: Double?
    let avgVoteAverage: Double?
    let decades: [String: Double]?
    let genres: [String: Double]?
    let keywords: [String: Double]?
    let languages: [String: Double]?
    let people: [String: Double]?
    let sampleSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case avgPopularity = "avg_popularity"
        case avgRuntime = "avg_runtime"
        case avgVoteAverage = "avg_vote_average"
        case decades
        case genres
        case keywords
        case languages
        case people
        case sampleSize = "sample_size"
    }
}

final class MyProgressService {
    
    private let tmdbGenreMap: [String: String] = [
        "28": "Action", "12": "Adventure", "16": "Animation", "35": "Comedy",
        "80": "Crime", "99": "Documentary", "18": "Drama", "10751": "Family",
        "14": "Fantasy", "36": "History", "27": "Horror", "10402": "Music",
        "9648": "Mystery", "10749": "Romance", "878": "Sci-Fi", "10770": "TV Movie",
        "53": "Thriller", "10752": "War", "37": "Western",
        "10759": "Action & Adventure", "10762": "Kids", "10763": "News",
        "10764": "Reality", "10765": "Sci-Fi & Fantasy", "10766": "Soap",
        "10767": "Talk", "10768": "War & Politics"
    ]
    
    func fetchTasteProfile() async throws -> TasteProfileData {
        guard let url = URL(string: "https://publicmetadb.com/api/external/taste"),
              let token = KeychainStore.load(account: SettingsKeychainAccount.publicMetaDB.rawValue),
              !token.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try parseTasteProfile(from: data)
    }
    
    func rebuildTasteProfile() async throws {
        guard let url = URL(string: "https://publicmetadb.com/api/external/taste/rebuild"),
              let token = KeychainStore.load(account: SettingsKeychainAccount.publicMetaDB.rawValue),
              !token.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: req)
        
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // Ignore the response body as it might just be a success message
        return
    }
    
    private func parseTasteProfile(from data: Data) throws -> TasteProfileData {
        let payload = try JSONDecoder().decode(TastePayload.self, from: data)
        let vector = payload.vector
        
        let sampleSize = vector.sampleSize ?? payload.sampleSize ?? 1
        
        // Map Decades
        var decadesList: [TasteDecadeStat] = []
        if let decadesMap = vector.decades {
            let sortedKeys = decadesMap.keys.sorted()
            for key in sortedKeys {
                let prefix = String(key.dropFirst(2))
                let label = "\(prefix)s"
                let count = Int(round((decadesMap[key] ?? 0) * Double(sampleSize)))
                decadesList.append(TasteDecadeStat(label: label, count: max(1, count)))
            }
        }
        
        // Map Genres
        var genresList: [TasteGenreStat] = []
        if let genresMap = vector.genres {
            let sorted = genresMap.sorted { $0.value > $1.value }
            for (key, value) in sorted.prefix(8) {
                let name = tmdbGenreMap[key] ?? "Unknown"
                genresList.append(TasteGenreStat(name: name, percentage: value))
            }
        }
        
        // Map Languages
        var languagesList: [TasteLanguageStat] = []
        if let langMap = vector.languages {
            let sorted = langMap.sorted { $0.value > $1.value }
            for (key, value) in sorted.prefix(8) {
                let name = Locale.current.localizedString(forLanguageCode: key) ?? key.uppercased()
                languagesList.append(TasteLanguageStat(language: name, percentage: value))
            }
        }
        
        var topPeopleIds: [Int] = []
        if let peopleMap = vector.people {
            let sorted = peopleMap.sorted { $0.value > $1.value }
            for (key, _) in sorted.prefix(5) {
                if let id = Int(key) {
                    topPeopleIds.append(id)
                }
            }
        }
        
        return TasteProfileData(
            sampleSize: sampleSize,
            avgRating: nil, // Computed later from actual user ratings
            avgRuntimeMinutes: vector.avgRuntime.map { Int(round($0)) } ?? 0,
            avgPopularity: vector.avgPopularity.map { Int(round($0)) } ?? 0,
            versionLabel: "VERSION \(payload.version)",
            keywordsCount: vector.keywords?.count ?? 0,
            peopleCount: vector.people?.count ?? 0,
            topGenres: genresList,
            decades: decadesList,
            languages: languagesList,
            rawTopPeopleIds: topPeopleIds
        )
    }
    
    func fetchRawStatsData() async throws -> (allWatched: [WatchEntry], totalRatings: Int, userAvgRating: Double?) {
        guard let token = KeychainStore.load(account: SettingsKeychainAccount.publicMetaDB.rawValue), !token.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        
        // 1. Fetch total ratings and user's average rating
        var totalRatings = 0
        var userAvgRating: Double? = nil
        
        if let url = URL(string: "https://publicmetadb.com/api/external/ratings?perPage=1") {
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let (data, _) = try? await URLSession.shared.data(for: req),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                if let total = json["totalItems"] as? Int ?? json["total"] as? Int {
                    totalRatings = total
                }
                
                if let avg = json["average"] as? Double {
                    userAvgRating = avg / 10.0 // Convert from 100-scale to 10-scale
                } else if let avgStr = json["average"] as? String, let avgD = Double(avgStr) {
                    userAvgRating = avgD / 10.0
                }
            }
        }
        
        // 2. Fetch all watched history
        var allWatched: [WatchEntry] = []
        var page = 1
        var totalPages = 1
        
        struct WatchedPage: Codable {
            let items: [WatchEntry]?
            let data: [WatchEntry]?
            let totalPages: Int?
        }
        
        while page <= totalPages {
            guard let url = URL(string: "https://publicmetadb.com/api/external/watched?perPage=500&page=\(page)") else { break }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            guard let (data, _) = try? await URLSession.shared.data(for: req) else { break }
            
            if page == 1 {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("================ DEBUG HISTORY JSON ================")
                    print(String(jsonString.prefix(2000))) // Print first 2000 characters
                    print("====================================================")
                }
            }
            
            if let parsed = try? JSONDecoder().decode(WatchedPage.self, from: data) {
                allWatched.append(contentsOf: parsed.items ?? parsed.data ?? [])
                totalPages = parsed.totalPages ?? 1
            } else {
                break
            }
            page += 1
        }
        
        return (allWatched, totalRatings, userAvgRating)
    }
}
