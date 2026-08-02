import SwiftUI
import Foundation
import SwiftData

@MainActor
class PicksViewModel: ObservableObject {
    @Published var picks: [PickCatalog] = []
    @Published var pickItems: [String: [CatalogItem]] = [:]
    
    // Rich Metadata
    @Published var cleanPosters: [Int: URL] = [:]
    @Published var itemLogos: [Int: URL] = [:]
    
    // Pagination State
    @Published var currentPage: [String: Int] = [:]
    @Published var hasMorePages: [String: Bool] = [:]
    @Published var isFetchingMore: [String: Bool] = [:]
    @Published var isRefreshingCatalog: [String: Bool] = [:]
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // Addon & Quota State
    @Published var quotaRemaining: Int? = nil
    @Published var isAddonActive: Bool = false
    @Published var addonManifestUrl: String? = nil
    @Published var addonStremioUrl: String? = nil
    @Published var refreshRateHours: Int = 24
    
    let apiService = APIService.shared
    let enrichment = MetadataEnrichmentService.shared
    
    func fetchPersonalizedPicks() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let catalogData = try await apiService.fetchCatalogs()
            
            var newPickItems: [String: [CatalogItem]] = [:]
            var initialPages: [String: Int] = [:]
            var initialHasMore: [String: Bool] = [:]
            var initialIsFetching: [String: Bool] = [:]
            
            let api = self.apiService
            let enrich = self.enrichment
            
            await withTaskGroup(of: (String, [CatalogItem], Int, Bool, Bool).self) { group in
                for catalog in catalogData.items {
                    group.addTask {
                        do {
                            let itemsResponse = try await api.fetchCatalogItems(catalogId: catalog.id, page: 1)
                            let items = itemsResponse.items
                            let enriched = await enrich.enrichCatalogItems(items)
                            return (catalog.id, enriched, 1, !items.isEmpty, false)
                        } catch {
                            return (catalog.id, [], 1, false, false)
                        }
                    }
                }
                
                for await result in group {
                    newPickItems[result.0] = result.1
                    initialPages[result.0] = result.2
                    initialHasMore[result.0] = result.3
                    initialIsFetching[result.0] = result.4
                }
            }
            
            let allItems = newPickItems.values.flatMap { $0 }.map { $0.toMediaItem() }
            let metadata = await enrich.fetchRichMetadata(
                for: allItems,
                pmdbRatings: [:], // Ratings are already inside CatalogItem as voteAverage
                cleanPosters: cleanPosters,
                itemLogos: itemLogos
            )
            
            self.picks = catalogData.items
            self.pickItems = newPickItems
            self.currentPage = initialPages
            self.hasMorePages = initialHasMore
            self.isFetchingMore = initialIsFetching
            self.cleanPosters.merge(metadata.posters) { current, _ in current }
            self.itemLogos.merge(metadata.logos) { current, _ in current }
            
            if UserDefaults.standard.string(forKey: "posterGlassStyle") == "dynamic" {
                let urlsToFetch = allItems.compactMap { item -> URL? in
                    return self.cleanPosters[item.tmdbId] ?? item.posterURL
                }
                await prefetchDynamicColors(for: urlsToFetch)
            }
        } catch {
            if error is CancellationError || (error as NSError).code == NSURLErrorCancelled {
                print("Fetch cancelled because user switched tabs. Ignoring.")
                return 
            }
            self.errorMessage = error.localizedDescription
        }
    }
    
    func fetchNextPage(catalogId: String) async {
        guard let current = currentPage[catalogId],
              let hasMore = hasMorePages[catalogId],
              let isFetching = isFetchingMore[catalogId],
              hasMore && !isFetching else { return }
        
        isFetchingMore[catalogId] = true
        defer { isFetchingMore[catalogId] = false }
        
        let nextPage = current + 1
        
        do {
            let itemsResponse = try await apiService.fetchCatalogItems(catalogId: catalogId, page: nextPage)
            let items = itemsResponse.items
            
            if items.isEmpty {
                hasMorePages[catalogId] = false
                return
            }
            
            let enrichedItems = await enrichment.enrichCatalogItems(items)
            let metadata = await enrichment.fetchRichMetadata(
                for: enrichedItems.map { $0.toMediaItem() },
                pmdbRatings: [:],
                cleanPosters: cleanPosters,
                itemLogos: itemLogos
            )
            
            pickItems[catalogId]?.append(contentsOf: enrichedItems)
            currentPage[catalogId] = nextPage
            cleanPosters.merge(metadata.posters) { current, _ in current }
            itemLogos.merge(metadata.logos) { current, _ in current }
            
            if UserDefaults.standard.string(forKey: "posterGlassStyle") == "dynamic" {
                let urlsToFetch = enrichedItems.compactMap { item -> URL? in
                    return self.cleanPosters[item.tmdbId] ?? item.toMediaItem().posterURL
                }
                await prefetchDynamicColors(for: urlsToFetch)
            }
        } catch {
            print("Error fetching next page for catalog \(catalogId): \(error)")
        }
    }
    
    func hideItem(catalogId: String, item: CatalogItem) {
        // Optimistically remove it locally
        if var items = pickItems[catalogId] {
            items.removeAll { $0.id == item.id }
            pickItems[catalogId] = items
        }
        
        // Send hide request to the API
        Task {
            do {
                try await apiService.markNotInterested(tmdbId: item.tmdbId, mediaType: item.mediaType.rawValue)
                print("Successfully marked item \(item.tmdbId) as not interested")
            } catch {
                print("Failed to hide item: \(error)")
            }
        }
    }
    
    func createPick(request: CreatePickRequest) async throws {
        _ = try await apiService.createCatalog(request)
        // Refresh picks after creating a new one
        await fetchPersonalizedPicks()
    }
    
    // MARK: - Addon & Quota
    
    func fetchAddonData() async {
        do {
            let quota = try await apiService.fetchRefreshQuota()
            self.quotaRemaining = quota.remaining
            print("[Addon Debug] Quota: \(quota)")
        } catch {
            print("[Addon Debug] Fetch Quota Error: \(error)")
        }
        
        do {
            let settings = try await apiService.fetchAddonSettings()
            if let hours = settings.refresh_interval_hours {
                self.refreshRateHours = hours
            }
            print("[Addon Debug] Settings: \(settings)")
        } catch {
            print("[Addon Debug] Fetch Settings Error: \(error)")
        }
        
        do {
            let addon = try await apiService.fetchAddonStatus()
            self.isAddonActive = addon.installed == true
            self.addonManifestUrl = addon.manifestUrl
            self.addonStremioUrl = addon.stremioUrl
            print("[Addon Debug] Addon Status: \(addon)")
        } catch {
            print("[Addon Debug] Fetch Addon Status Error: \(error)")
        }
    }
    
    func updateRefreshRate(hours: Int) async {
        do {
            _ = try await apiService.updateAddonSettings(hours: hours)
            self.refreshRateHours = hours
        } catch {
            print("Failed to update refresh rate: \(error)")
        }
    }
    
    func generateAddonUrl() async throws {
        let status = try await apiService.generateAddonUrl()
        self.isAddonActive = true
        self.addonManifestUrl = status.manifestUrl
        self.addonStremioUrl = status.stremioUrl
    }
    
    func revokeAddonUrl() async throws {
        _ = try await apiService.revokeAddonUrl()
        self.isAddonActive = false
        self.addonManifestUrl = nil
        self.addonStremioUrl = nil
    }

    func updatePick(catalogId: String, request: CreatePickRequest) async throws {
        _ = try await apiService.updateCatalog(catalogId: catalogId, request)
        await fetchPersonalizedPicks()
    }

    func deletePick(catalogId: String) async throws {
        try await apiService.deleteCatalog(catalogId: catalogId)
        await MainActor.run {
            picks.removeAll { $0.id == catalogId }
            pickItems.removeValue(forKey: catalogId)
        }
    }

    func refreshPick(catalogId: String) async throws {
        await MainActor.run { isRefreshingCatalog[catalogId] = true }
        defer {
            Task { @MainActor in isRefreshingCatalog[catalogId] = false }
        }
        
        _ = try await apiService.refreshCatalog(catalogId: catalogId)
        
        // Refresh quota immediately so the counter updates in real time
        if let quota = try? await apiService.fetchRefreshQuota() {
            await MainActor.run { self.quotaRemaining = quota.remaining }
        }
        
        // Reload items for this catalog
        if let newItems = try? await apiService.fetchCatalogItems(catalogId: catalogId) {
            let enriched = await enrichment.enrichCatalogItems(newItems.items)
            let metadata = await enrichment.fetchRichMetadata(
                for: enriched.map { $0.toMediaItem() },
                pmdbRatings: [:],
                cleanPosters: cleanPosters,
                itemLogos: itemLogos
            )
            
            await MainActor.run {
                self.cleanPosters.merge(metadata.posters) { current, _ in current }
                self.itemLogos.merge(metadata.logos) { current, _ in current }
                pickItems[catalogId] = enriched
            }
        }
    }
    
    func buildFilters(
        mediaTypes: Set<String>,
        audienceType: AudienceType,
        minVoteCount: Double,
        minVoteAverage: Double,
        yearFrom: Double,
        yearTo: Double,
        selectedCompanies: [String],
        runtimeMin: String,
        runtimeMax: String,
        selectedMoods: Set<String>,
        selectedSeedTitles: [CatalogItem],
        includedProviders: Set<String>,
        providerMap: [NamedItem],
        selectedRegion: String,
        regionMap: [NamedItem],
        genreIdsInclude: Set<String>,
        genreIdsExclude: Set<String>,
        genreMap: [NamedItem],
        kwInclude: [String],
        kwExclude: [String],
        keywordMap: [NamedItem],
        langCodesInclude: Set<String>,
        langCodesExclude: Set<String>,
        languageMap: [NamedItem],
        apiSortBy: String,
        selectedRating: String?
    ) -> PickFilters {
        let mappedMediaTypes: [String]? = mediaTypes.isEmpty ? nil : Array(mediaTypes)
        let minVC: Int? = Int(minVoteCount)
        let minVA: Double? = Double(minVoteAverage)
        let yFrom: Int? = Int(yearFrom)
        let yTo: Int? = Int(yearTo)
        
        let mappedCompanies: [String]? = selectedCompanies.isEmpty ? nil : selectedCompanies
        let mappedRuntimeMin: Int? = runtimeMin.isEmpty ? nil : Int(runtimeMin)
        let mappedRuntimeMax: Int? = runtimeMax.isEmpty ? nil : Int(runtimeMax)
        
        var mappedProviderIds: [Int]? = nil
        if !includedProviders.isEmpty {
            var tempIds: [Int] = []
            for name in includedProviders {
                for item in providerMap {
                    if item.name == name {
                        if let code = item.code, let intId = Int(code) { tempIds.append(intId) }
                        break
                    }
                }
            }
            if !tempIds.isEmpty { mappedProviderIds = tempIds }
        }
        
        var regionCode = "US"
        for item in regionMap {
            if item.name == selectedRegion {
                if let code = item.code { regionCode = code }
                break
            }
        }
        let mappedRegionCode: String? = mappedProviderIds == nil ? nil : regionCode
        
        var tempGenreIdsInclude: [String] = []
        for name in genreIdsInclude {
            for item in genreMap {
                if item.name == name {
                    tempGenreIdsInclude.append("\(item.id)")
                    break
                }
            }
        }
        let mappedGenreIdsInclude: [String]? = tempGenreIdsInclude.isEmpty ? nil : tempGenreIdsInclude
        
        var tempGenreIdsExclude: [String] = []
        for name in genreIdsExclude {
            for item in genreMap {
                if item.name == name {
                    tempGenreIdsExclude.append("\(item.id)")
                    break
                }
            }
        }
        let mappedGenreIdsExclude: [String]? = tempGenreIdsExclude.isEmpty ? nil : tempGenreIdsExclude
        
        var tempKwInclude: [String] = []
        for kw in kwInclude {
            for item in keywordMap {
                if item.name == kw {
                    tempKwInclude.append("\(item.id)")
                    break
                }
            }
        }
        let mappedKwInclude: [String]? = tempKwInclude.isEmpty ? nil : tempKwInclude
        
        var tempKwExclude: [String] = []
        for kw in kwExclude {
            for item in keywordMap {
                if item.name == kw {
                    tempKwExclude.append("\(item.id)")
                    break
                }
            }
        }
        let mappedKwExclude: [String]? = tempKwExclude.isEmpty ? nil : tempKwExclude
        
        var tempLangCodesInclude: [String] = []
        for name in langCodesInclude {
            for item in languageMap {
                if item.name == name {
                    if let code = item.code { tempLangCodesInclude.append(code) }
                    break
                }
            }
        }
        let mappedLangCodesInclude: [String]? = tempLangCodesInclude.isEmpty ? nil : tempLangCodesInclude
        
        return PickFilters(
            media_types: mappedMediaTypes,
            min_vote_count: minVC,
            min_vote_average: minVA,
            year_min: yFrom,
            year_max: yTo,
            with_genres: mappedGenreIdsInclude,
            without_genres: mappedGenreIdsExclude,
            with_keywords: mappedKwInclude,
            exclude_keywords: mappedKwExclude,
            languages: mappedLangCodesInclude,
            with_watch_providers: mappedProviderIds,
            watch_region: mappedRegionCode,
            certification_country: mappedRegionCode,
            certification_lte: selectedRating.flatMap { $0.isEmpty ? nil : $0 },
            with_companies: mappedCompanies,
            runtime_min: mappedRuntimeMin,
            runtime_max: mappedRuntimeMax,
            sort_by: apiSortBy,
            audience: {
                switch audienceType {
                case .adults: return "adult"
                case .kids:   return "kids"
                default:      return nil
                }
            }()
        )
    }

    func createPickFromView(
        includeMovies: Bool,
        includeTV: Bool,
        sortOrder: String,
        audienceType: AudienceType,
        minVoteCount: Double,
        minVoteAverage: Double,
        yearFrom: String,
        yearTo: String,
        selectedCompanies: [String],
        runtimeMin: String,
        runtimeMax: String,
        selectedMoods: Set<String>,
        selectedSeedTitles: [CatalogItem],
        includedProviders: Set<String>,
        providerMap: [NamedItem],
        selectedRegion: String,
        regionMap: [NamedItem],
        includedGenres: Set<String>,
        excludedGenres: Set<String>,
        genreMap: [NamedItem],
        includedKeywords: [String],
        excludedKeywords: [String],
        keywordMap: [NamedItem],
        includedLanguages: Set<String>,
        excludedLanguages: Set<String>,
        languageMap: [NamedItem],
        selectedRating: String,
        weightGenre: Double,
        weightKeyword: Double,
        weightPeople: Double,
        weightQuality: Double,
        weightPopularity: Double,
        weightNovelty: Double,
        weightRecency: Double,
        weightEra: Double,
        weightLanguage: Double,
        pickName: String,
        pickDescription: String,
        selectedRecipeType: PickRecipeType,
        includeHideWatched: Bool,
        includeHideWatchlist: Bool
    ) {
        var tempMediaTypes: Set<String> = []
        if includeMovies { tempMediaTypes.insert("movie") }
        if includeTV { tempMediaTypes.insert("tv") }
        
        var apiSortByStr: String? = nil
        if sortOrder == "Release Date (Newest)" { apiSortByStr = "primary_release_date.desc" }
        else if sortOrder == "Release Date (Oldest)" { apiSortByStr = "primary_release_date.asc" }
        else if sortOrder == "Highest Rated" { apiSortByStr = "vote_average.desc" }
        else if sortOrder == "Lowest Rated" { apiSortByStr = "vote_average.asc" }
        else if sortOrder == "Most Popular" { apiSortByStr = "popularity.desc" }
        else if sortOrder == "Least Popular" { apiSortByStr = "popularity.asc" }
        
        let requestFilters = buildFilters(
            mediaTypes: tempMediaTypes,
            audienceType: audienceType,
            minVoteCount: minVoteCount,
            minVoteAverage: minVoteAverage,
            yearFrom: Double(yearFrom) ?? 1990.0,
            yearTo: Double(yearTo) ?? 2024.0,
            selectedCompanies: selectedCompanies,
            runtimeMin: runtimeMin,
            runtimeMax: runtimeMax,
            selectedMoods: selectedMoods,
            selectedSeedTitles: selectedSeedTitles,
            includedProviders: includedProviders,
            providerMap: providerMap,
            selectedRegion: selectedRegion,
            regionMap: regionMap,
            genreIdsInclude: includedGenres,
            genreIdsExclude: excludedGenres,
            genreMap: genreMap,
            kwInclude: includedKeywords,
            kwExclude: excludedKeywords,
            keywordMap: keywordMap,
            langCodesInclude: includedLanguages,
            langCodesExclude: excludedLanguages,
            languageMap: languageMap,
            apiSortBy: apiSortByStr ?? "popularity.desc",
            selectedRating: selectedRating == "Any" ? nil : selectedRating
        )
        
        let weights = PickWeights(
            genre: weightGenre == 0 ? nil : weightGenre,
            keyword: weightKeyword == 0 ? nil : weightKeyword,
            people: weightPeople == 0 ? nil : weightPeople,
            quality: weightQuality == 0 ? nil : weightQuality,
            popularity: weightPopularity == 0 ? nil : weightPopularity,
            novelty: weightNovelty == 0 ? nil : weightNovelty,
            recency: weightRecency == 0 ? nil : weightRecency,
            era: weightEra == 0 ? nil : weightEra,
            language: weightLanguage == 0 ? nil : weightLanguage
        )
        
        let request = CreatePickRequest(
            name: pickName,
            description: pickDescription.isEmpty ? nil : pickDescription,
            seed_type: selectedRecipeType.apiSeedType,
            seed_params: nil,
            filters: requestFilters,
            weights: weights,
            exclude_watched: includeHideWatched,
            exclude_watchlist: includeHideWatchlist
        )
        
        Task {
            do {
                try await self.createPick(request: request)
            } catch {
                print("Failed to create pick: \(error)")
            }
        }
    }
}
