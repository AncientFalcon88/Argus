import Foundation
import SwiftUI

enum DiscoverTab: String, CaseIterable, Identifiable {
    var id: String { self.rawValue }
    case top = "Top"
    case movie = "Movie"
    case tv = "Series"
    
    var mediaType: MediaType {
        self == .tv ? .tv : .movie
    }
}

@MainActor
final class DiscoverViewModel: ObservableObject {
    @Published var selectedTab: DiscoverTab = .movie
    @Published var searchText = ""
    @Published var items: [TMDBMediaItem] = []
    @Published var sortMode: DiscoverSort = .popular
    @Published var selectedGenres: Set<Int> = []
    @Published var startYear: Double = 1900
    @Published var endYear: Double = 2026
    
    // Custom Redesign Images & Tags
    @Published var trendingMovies: [TMDBMediaItem] = []
    @Published var trendingTVs: [TMDBMediaItem] = []
    @Published var itemLogos: [Int: URL] = [:]
    @Published var cleanPosters: [Int: URL] = [:]
    
    // Quick toggles
    @Published var postersOnly = false
    @Published var ratedOnly = false
    @Published var isMustSee = false
    @Published var isNoAnimation = false
    @Published var isEnglishOnly = false {
        didSet {
            if isEnglishOnly {
                isNonEnglish = false
            }
        }
    }
    @Published var isNonEnglish = false {
        didSet {
            if isNonEnglish {
                isEnglishOnly = false
            }
        }
    }
    
    // Advanced drops
    @Published var watchRegion: String = "Anywhere"
    @Published var watchProviders: Set<Int> = []
    @Published var selectedStudios: [TMDBStudio] = []
    @Published var selectedPeople: [TMDBPerson] = []
    @Published var minRuntime: Int?
    @Published var maxRuntime: Int?
    @Published var ageRating: String?
    
    // Search Sheets
    @Published var peopleSearchQuery = ""
    @Published var studioSearchQuery = ""
    @Published var peopleSearchResults: [TMDBPerson] = []
    @Published var studioSearchResults: [TMDBStudio] = []
    
    private var peopleSearchTask: Task<Void, Never>?
    private var studioSearchTask: Task<Void, Never>?
    
    // Filter configuration data
    let availableGenres: [TMDBGenre] = [
        TMDBGenre(id: 28, name: "Action"),
        TMDBGenre(id: 12, name: "Adventure"),
        TMDBGenre(id: 16, name: "Animation"),
        TMDBGenre(id: 35, name: "Comedy"),
        TMDBGenre(id: 80, name: "Crime"),
        TMDBGenre(id: 99, name: "Documentary"),
        TMDBGenre(id: 18, name: "Drama"),
        TMDBGenre(id: 10751, name: "Family"),
        TMDBGenre(id: 14, name: "Fantasy"),
        TMDBGenre(id: 36, name: "History"),
        TMDBGenre(id: 27, name: "Horror"),
        TMDBGenre(id: 10402, name: "Music"),
        TMDBGenre(id: 9648, name: "Mystery"),
        TMDBGenre(id: 10749, name: "Romance"),
        TMDBGenre(id: 878, name: "Science Fiction"),
        TMDBGenre(id: 10770, name: "TV Movie"),
        TMDBGenre(id: 53, name: "Thriller"),
        TMDBGenre(id: 10752, name: "War"),
        TMDBGenre(id: 37, name: "Western")
    ]
    @Published var availableCountries: [TMDBCountry] = []
    @Published var availableProviders: [TMDBProvider] = []
    
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var pmdbRatings: [Int: Int] = [:]

    private let tmdb = TMDBService.shared
    private let api = APIService.shared
    private var debounceTask: Task<Void, Never>?
    private var filterDebounceTask: Task<Void, Never>?
    private static let debounceInterval: Duration = .milliseconds(300)

    var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var wasSearchActive = false

    var hasMorePages: Bool {
        currentPage < totalPages
    }

    var headerSubtitle: String {
        if isSearchActive {
            return isSearching ? "Searching…" : "\(items.count) results"
        }
        return "Movies and TV from TMDB"
    }

    func onSearchTextChanged() {
        debounceTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isNowSearchActive = !query.isEmpty
        
        if isNowSearchActive && !wasSearchActive {
            selectedTab = .top
        } else if !isNowSearchActive && wasSearchActive {
            if selectedTab == .top {
                selectedTab = .movie
            }
        }
        wasSearchActive = isNowSearchActive

        if query.isEmpty {
            isSearching = false
            errorMessage = nil
            debounceTask = Task { await loadDiscover() }
            return
        }

        debounceTask = Task {
            do {
                try await Task.sleep(for: Self.debounceInterval)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await performSearch(query: query)
        }
    }

    func load() async {
        if trendingMovies.isEmpty && trendingTVs.isEmpty {
            await loadTrending()
        }
        if isSearchActive {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            await performSearch(query: query)
        } else {
            await loadDiscover()
        }
    }

    private func loadTrending() async {
        do {
            async let m1 = tmdb.fetchTrending(mediaType: "movie", timeWindow: "day", page: 1)
            async let m2 = tmdb.fetchTrending(mediaType: "movie", timeWindow: "day", page: 2)
            async let t1 = tmdb.fetchTrending(mediaType: "tv", timeWindow: "day", page: 1)
            async let t2 = tmdb.fetchTrending(mediaType: "tv", timeWindow: "day", page: 2)
            
            let (movies1, movies2, tvs1, tvs2) = try await (m1, m2, t1, t2)
            
            trendingMovies = Array((movies1 + movies2).prefix(30))
            trendingTVs = Array((tvs1 + tvs2).prefix(30))
        } catch {
            print("Failed to load trending: \(error)")
        }
    }

    func loadDiscover(page: Int? = nil) async {
        guard !isSearchActive else { return }
        isSearching = false
        isLoading = true
        errorMessage = nil
        let targetPage = page ?? 1
        currentPage = targetPage
        defer { isLoading = false }

        do {
            var fetchedItems: [TMDBMediaItem] = []
            var resultPage = targetPage
            var resultTotalPages = 1
            
            if selectedTab == .top {
                let response = try await tmdb.fetchTrending(mediaType: "all", timeWindow: "week", page: targetPage)
                fetchedItems = response
                resultPage = targetPage
                resultTotalPages = 100
            } else {
                let result = try await tmdb.discover(filters: makeFilters(page: targetPage))
                fetchedItems = result.items
                resultPage = result.page
                resultTotalPages = result.totalPages
            }
            
            if postersOnly {
                fetchedItems = fetchedItems.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
            }
            await fetchMetadata(for: fetchedItems)
            
            if ratedOnly {
                fetchedItems = fetchedItems.filter { item in 
                    let rating = pmdbRatings[item.tmdbId] ?? -1
                    return rating > 0
                }
            }
            items = fetchedItems
            currentPage = resultPage
            totalPages = resultTotalPages
        } catch {
            if error is CancellationError { return }
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            items = []
            errorMessage = error.localizedDescription
        }
    }

    func loadNextPageIfNeeded() async {
        guard !isSearchActive, !isLoading, !isLoadingMore, hasMorePages else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = currentPage + 1
        do {
            var newItems: [TMDBMediaItem] = []
            var resultPage = nextPage
            var resultTotalPages = 1
            
            if selectedTab == .top {
                let response = try await tmdb.fetchTrending(mediaType: "all", timeWindow: "week", page: nextPage)
                newItems = response
                resultPage = nextPage
                resultTotalPages = 100
            } else {
                let result = try await tmdb.discover(filters: makeFilters(page: nextPage))
                resultPage = result.page
                resultTotalPages = result.totalPages
                guard !Task.isCancelled else { return }
                newItems = result.items
            }
            
            guard !Task.isCancelled else { return }
            let existingIDs = Set(items.map(\.id))
            newItems = newItems.filter { !existingIDs.contains($0.id) }
            if postersOnly {
                newItems = newItems.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
            }
            await fetchMetadata(for: newItems)
            
            Task {
                await TrendingManager.shared.fetchTrendingIfNeeded()
            }
            
            if ratedOnly {
                newItems = newItems.filter { item in 
                    let rating = pmdbRatings[item.tmdbId] ?? -1
                    return rating > 0
                }
            }
            items.append(contentsOf: newItems)
            currentPage = resultPage
            totalPages = resultTotalPages
        } catch {
            if error is CancellationError { return }
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
        }
    }

    func applyDiscoverFilters() {
        guard !isSearchActive else { return }
        debounceTask?.cancel()
        filterDebounceTask?.cancel()
        filterDebounceTask = Task {
            do {
                try await Task.sleep(for: Self.debounceInterval)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await loadDiscover()
        }
    }

    private func performSearch(query: String) async {
        isSearching = true
        isLoading = true
        errorMessage = nil

        do {
            let results: [TMDBMediaItem]
            if selectedTab == .top {
                results = try await tmdb.searchMulti(query, year: nil)
            } else {
                results = try await tmdb.search(query, mediaType: selectedTab.mediaType)
            }
            
            guard !Task.isCancelled else { return }
            guard searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
            
            await fetchMetadata(for: results)
            
            items = results
            currentPage = 1
            totalPages = 1
            if results.isEmpty {
                errorMessage = nil
            }
        } catch {
            if error is CancellationError { return }
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            errorMessage = error.localizedDescription
            items = []
        }

        isLoading = false
        isSearching = false
    }

    func onMediaTypeChanged() {
        if isSearchActive {
            onSearchTextChanged()
        } else {
            Task { await loadDiscover() }
        }
    }

    func reroll() {
        let maxPage = min(totalPages, 500)
        let randomPage = Int.random(in: 1...max(1, maxPage))
        Task { await loadDiscover(page: randomPage) }
    }
    
    private let unsupportedCountries: Set<String> = [
        "Afghanistan", "American Samoa", "Anguilla", "Antarctica", "Armenia", "Aruba", "Bangladesh", "Benin", "Bhutan", "Botswana", "Bouvet Island", "British Indian Ocean Territory", "British Virgin Islands", "Brunei Darussalam", "Burma", "Burundi", "Cambodia", "Cayman Islands", "Central African Republic", "China", "Christmas Island", "Cocos Islands", "Comoros", "Congo", "Cook Islands", "Czechoslovakia", "Djibouti", "Dominica", "East Germany", "East Timor", "Eritrea", "Ethiopia", "Faeroe Islands", "Falkland Islands", "French Southern Territories", "Gabon", "Gambia", "Georgia", "Greenland", "Grenada", "Guadaloupe", "Guam", "Guinea", "Guinea-Bissau", "Haiti", "Heard and McDonald Islands", "Iran", "Kazakhstan", "Kiribati", "Kyrgyz Republic", "Lao People's Democratic Republic", "Lesotho", "Liberia", "Macao", "Maldives", "Marshall Islands", "Martinique", "Mauritania", "Mayotte", "Micronesia", "Mongolia", "Montserrat", "Myanmar", "Namibia", "Nauru", "Nepal", "Netherlands Antilles", "New Caledonia", "Niue", "Norfolk Island", "North Korea", "Northern Ireland", "Northern Mariana Islands", "Palau", "Pitcairn Island", "Puerto Rico", "Reunion", "Rwanda", "Samoa", "Sao Tome and Principe", "Serbia and Montenegro", "Sierra Leone", "Solomon Islands", "Somalia", "South Georgia and the South Sandwich Islands", "South Sudan", "Soviet Union", "Sri Lanka", "St. Helena", "St. Kitts and Nevis", "St. Pierre and Miquelon", "St. Vincent and the Grenadines", "Sudan", "Suriname", "Svalbard & Jan Mayen Islands", "Swaziland", "Syrian Arab Republic", "Tajikistan", "Timor-Leste", "Togo", "Tokelau", "Tonga", "Turkmenistan", "Tuvalu", "US Virgin Islands", "United States Minor Outlying Islands", "Uzbekistan", "Vanuatu", "Vietnam", "Wallis and Futuna Islands", "Western Sahara", "Yugoslavia"
    ]
    
    private let pinnedCountries: [String] = [
        "United States of America", "United Kingdom", "Canada", "Australia", 
        "India", "Germany", "France", "Japan", "South Korea", 
        "Brazil", "Mexico", "Spain"
    ]
    
    func fetchFilterData() async {
        do {
            let countries = try await tmdb.fetchCountries()
            let sortedCountries = countries
                .filter { !unsupportedCountries.contains($0.english_name) }
                .sorted { 
                    let index1 = pinnedCountries.firstIndex(of: $0.english_name) ?? Int.max
                    let index2 = pinnedCountries.firstIndex(of: $1.english_name) ?? Int.max
                    if index1 != index2 {
                        return index1 < index2
                    }
                    return $0.english_name < $1.english_name 
                }
            self.availableCountries = sortedCountries
            
            if watchRegion != "Anywhere" {
                if selectedTab != .top {
                    self.availableProviders = try await tmdb.fetchProviders(mediaType: selectedTab.mediaType, watchRegion: watchRegion)
                }
            } else {
                self.availableProviders = []
            }
        } catch {
            print("Failed to fetch filter data: \(error)")
        }
    }
    
    func onWatchRegionChanged() {
        watchProviders.removeAll()
        Task {
            if watchRegion != "Anywhere" {
                if selectedTab != .top {
                    do {
                        self.availableProviders = try await tmdb.fetchProviders(mediaType: selectedTab.mediaType, watchRegion: watchRegion)
                    } catch {
                        print("Failed to fetch providers: \(error)")
                    }
                }
            } else {
                self.availableProviders = []
            }
            await loadDiscover(page: 1)
        }
    }
    
    // MARK: - Dynamic Search Sheets
    
    func onPeopleSearchTextChanged() {
        peopleSearchTask?.cancel()
        guard !peopleSearchQuery.isEmpty else {
            peopleSearchResults = []
            return
        }
        peopleSearchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                let results = try await tmdb.searchPeople(query: peopleSearchQuery)
                await MainActor.run {
                    self.peopleSearchResults = results
                }
            } catch {
                print("People search error: \(error)")
            }
        }
    }
    
    func onStudioSearchTextChanged() {
        studioSearchTask?.cancel()
        guard !studioSearchQuery.isEmpty else {
            studioSearchResults = []
            return
        }
        studioSearchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                let results = try await tmdb.searchStudios(query: studioSearchQuery)
                await MainActor.run {
                    self.studioSearchResults = results
                }
            } catch {
                print("Studio search error: \(error)")
            }
        }
    }
    
    // MARK: - Watchlist

    @Published var watchlistedItemIds: Set<Int> = []

    func isInWatchlist(_ item: TMDBMediaItem) -> Bool {
        watchlistedItemIds.contains(item.tmdbId)
    }

    func fetchWatchlist() {
        Task {
            do {
                let response = try await APIService.shared.fetchLists(perPage: 50)
                guard let watchlist = response.items.first(where: { $0.type == .watchlist }) else { return }
                
                var allItems: [ListItem] = []
                var page = 1
                while true {
                    let items = try await APIService.shared.fetchListItems(listId: watchlist.id, page: page, perPage: 1000)
                    allItems.append(contentsOf: items.items)
                    if items.items.count < 1000 { break }
                    page += 1
                }
                
                await MainActor.run {
                    self.watchlistedItemIds = Set(allItems.compactMap { $0.tmdbId })
                }
            } catch {
                print("Failed to fetch watchlist: \(error)")
            }
        }
    }

    func addToWatchlist(_ item: TMDBMediaItem) {
        Task {
            do {
                let response = try await APIService.shared.fetchLists(perPage: 50)
                guard let watchlist = response.items.first(where: { $0.type == .watchlist }) else {
                    print("No watchlist found for user")
                    return
                }
                _ = try await APIService.shared.addListItem(
                    listId: watchlist.id,
                    request: AddListItemRequest(tmdbId: item.tmdbId, mediaType: item.mediaType)
                )
                watchlistedItemIds.insert(item.tmdbId)
                print("Successfully added \(item.title) to watchlist")
            } catch {
                print("Failed to add \(item.title) to watchlist: \(error)")
            }
        }
    }

    func removeFromWatchlist(_ item: TMDBMediaItem) {
        Task {
            do {
                let response = try await APIService.shared.fetchLists(perPage: 50)
                guard let watchlist = response.items.first(where: { $0.type == .watchlist }) else { return }
                
                var listItemIdToRemove: String? = nil
                var page = 1
                while true {
                    let items = try await APIService.shared.fetchListItems(listId: watchlist.id, page: page, perPage: 1000)
                    if let found = items.items.first(where: { $0.tmdbId == item.tmdbId }) {
                        listItemIdToRemove = found.id
                        break
                    }
                    if items.items.count < 1000 { break }
                    page += 1
                }
                
                guard let itemId = listItemIdToRemove else { return }
                try await APIService.shared.removeListItem(listId: watchlist.id, itemId: itemId)
                watchlistedItemIds.remove(item.tmdbId)
                print("Successfully removed \(item.title) from watchlist")
            } catch {
                print("Failed to remove \(item.title) from watchlist: \(error)")
            }
        }
    }

    private func makeFilters(page: Int) -> DiscoverFilters {
        var filters = DiscoverFilters()
        filters.mediaType = selectedTab.mediaType
        filters.sortBy = sortMode.queryValue(for: selectedTab.mediaType)
        filters.selectedGenres = selectedGenres
        filters.startYear = Int(startYear)
        filters.endYear = Int(endYear)
        filters.page = page
        
        filters.isMustSee = isMustSee
        filters.isNoAnimation = isNoAnimation
        filters.postersOnly = postersOnly
        filters.ratedOnly = ratedOnly
        filters.isEnglishOnly = isEnglishOnly
        filters.isNonEnglish = isNonEnglish
        filters.watchRegion = watchRegion
        filters.watchProviders = watchProviders
        filters.selectedStudios = selectedStudios
        filters.selectedPeople = selectedPeople
        filters.minRuntime = minRuntime
        filters.maxRuntime = maxRuntime
        filters.ageRating = ageRating
        
        return filters
    }

    private func fetchMetadata(for items: [TMDBMediaItem]) async {
        let (newRatings, newPosters, newLogos) = await MetadataEnrichmentService.shared.fetchRichMetadata(
            for: items,
            pmdbRatings: pmdbRatings,
            cleanPosters: cleanPosters,
            itemLogos: itemLogos
        )
        
        // Batch update on MainActor
        for (k, v) in newRatings { self.pmdbRatings[k] = v }
        for (k, v) in newPosters { self.cleanPosters[k] = v }
        for (k, v) in newLogos { self.itemLogos[k] = v }
        
        // PREFETCH DYNAMIC COLORS
        if UserDefaults.standard.string(forKey: "posterGlassStyle") == "dynamic" {
            let urlsToFetch = items.compactMap { item -> URL? in
                if let clean = newPosters[item.tmdbId] ?? cleanPosters[item.tmdbId] { return clean }
                return item.posterURL
            }
            await prefetchDynamicColors(for: urlsToFetch)
        }
    }
    func getTag(for item: TMDBMediaItem) -> String {
        if item.mediaType == .person {
            let job = (item.department ?? "Person").uppercased()
            if job == "ACTING" { return "ACTOR" }
            if job == "DIRECTING" { return "DIRECTOR" }
            if job == "WRITING" { return "WRITER" }
            return job
        }
        return BadgeEngine.getTag(for: item)
    }
}

enum DiscoverSort: String, CaseIterable, Identifiable {
    case popular = "Popular"
    case topRated = "Top Rated"
    case newest = "Newest"
    case oldest = "Oldest"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .popular: return "flame.fill"
        case .topRated: return "star.fill"
        case .newest: return "sparkles"
        case .oldest: return "clock"
        }
    }

    func queryValue(for mediaType: MediaType) -> String {
        switch self {
        case .popular: "popularity.desc"
        case .topRated: "vote_average.desc"
        case .newest:
            mediaType == .movie ? "primary_release_date.desc" : "first_air_date.desc"
        case .oldest:
            mediaType == .movie ? "primary_release_date.asc" : "first_air_date.asc"
        }
    }
}

struct TMDBGenre: Identifiable, Hashable {
    let id: Int
    let name: String
}
