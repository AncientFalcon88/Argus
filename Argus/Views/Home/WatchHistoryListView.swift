import SwiftUI

enum WatchHistoryFilter: String, CaseIterable {
    case any = "Any"
    case movies = "Movies"
    case tv = "Series"
    case timeline = "Timeline"
    
    var icon: String {
        switch self {
        case .any: return "square.grid.2x2"
        case .timeline: return "square.3.layers.3d"
        case .movies: return "film"
        case .tv: return "tv"
        }
    }
}

struct GroupedWatchEntry: Identifiable, Hashable {
    let id: String // tmdbId + mediaType
    let tmdbId: Int
    let mediaType: MediaType
    let title: String?
    let name: String?
    let posterPath: String?
    var backdropPath: String?
    var textlessBackdropPath: String?
    var logoPath: String?
    let latestWatchedAt: String?
    var episodesWatched: Int {
        if mediaType == .movie {
            return entries.count
        } else {
            let uniqueEpisodes = Set(entries.compactMap { entry -> String? in
                guard let s = entry.season, let e = entry.episode else { return nil }
                return "\(s)-\(e)"
            })
            return uniqueEpisodes.count
        }
    }
    let entries: [WatchEntry]
    
    var logoURL: URL? {
        logoPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") }
    }
    
    var cleanBackdropURL: URL? {
        textlessBackdropPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") }
    }
    
    var displayTitle: String {
        return title ?? name ?? "Unknown Item"
    }
}

struct WatchHistoryListView: View {
    @ObservedObject var viewModel: HomeViewModel
    @State private var selectedFilter: WatchHistoryFilter = .any
    
    var filteredHistory: [WatchEntry] {
        switch selectedFilter {
        case .timeline, .any: return viewModel.watchHistory
        case .movies: return viewModel.watchHistory.filter { $0.mediaType == .movie }
        case .tv: return viewModel.watchHistory.filter { $0.mediaType == .tv }
        }
    }
    
    var groupedHistory: [GroupedWatchEntry] {
        var groups: [String: GroupedWatchEntry] = [:]
        
        for entry in viewModel.watchHistory {
            let groupId = "\(entry.tmdbId)-\(entry.mediaType.rawValue)"
            
            if let existing = groups[groupId] {
                let currentLatest = existing.latestWatchedAt ?? ""
                let entryDate = entry.watchedAt ?? ""
                let isNewer = entryDate > currentLatest
                
                groups[groupId] = GroupedWatchEntry(
                    id: existing.id,
                    tmdbId: existing.tmdbId,
                    mediaType: existing.mediaType,
                    title: existing.title,
                    name: existing.name,
                    posterPath: existing.posterPath,
                    backdropPath: existing.backdropPath,
                    textlessBackdropPath: existing.textlessBackdropPath,
                    logoPath: existing.logoPath,
                    latestWatchedAt: isNewer ? entryDate : currentLatest,
                    entries: existing.entries + [entry]
                )
            } else {
                groups[groupId] = GroupedWatchEntry(
                    id: groupId,
                    tmdbId: entry.tmdbId,
                    mediaType: entry.mediaType,
                    title: entry.title,
                    name: entry.name,
                    posterPath: entry.posterPath,
                    backdropPath: entry.backdropPath,
                    textlessBackdropPath: entry.textlessBackdropPath,
                    logoPath: entry.logoPath,
                    latestWatchedAt: entry.watchedAt,
                    entries: [entry]
                )
            }
        }
        
        for item in viewModel.continueWatching where item.mediaType == .movie {
            let groupId = "\(item.tmdbId)-\(item.mediaType.rawValue)"
            
            let l = (item.runtime ?? 100) * 60000
            let d = Int(item.progress * Double(l))
            
            var entry = WatchEntry(
                id: item.id,
                tmdbId: item.tmdbId,
                mediaType: item.mediaType,
                season: item.season,
                episode: item.episode,
                watchedAt: item.resumeUpdatedAt ?? item.watchedAt,
                title: item.title,
                name: item.title,
                posterPath: item.posterPath,
                backdropPath: item.backdropPath,
                episodeName: item.episodeName,
                episodeStillPath: item.episodeStillPath,
                runtime: item.runtime,
                runtimeMs: nil,
                duration: d,
                length: l
            )
            entry.logoPath = item.logoPath
            entry.textlessBackdropPath = item.cleanBackdropPath
            
            if let existing = groups[groupId] {
                let currentLatest = existing.latestWatchedAt ?? ""
                let entryDate = entry.watchedAt ?? ""
                let isNewer = entryDate > currentLatest
                
                groups[groupId] = GroupedWatchEntry(
                    id: existing.id,
                    tmdbId: existing.tmdbId,
                    mediaType: existing.mediaType,
                    title: existing.title,
                    name: existing.name,
                    posterPath: existing.posterPath,
                    backdropPath: existing.backdropPath,
                    textlessBackdropPath: existing.textlessBackdropPath,
                    logoPath: existing.logoPath,
                    latestWatchedAt: isNewer ? entryDate : currentLatest,
                    entries: [entry] + existing.entries
                )
            } else {
                groups[groupId] = GroupedWatchEntry(
                    id: groupId,
                    tmdbId: entry.tmdbId,
                    mediaType: entry.mediaType,
                    title: entry.title,
                    name: entry.name,
                    posterPath: entry.posterPath,
                    backdropPath: entry.backdropPath,
                    textlessBackdropPath: entry.textlessBackdropPath,
                    logoPath: entry.logoPath,
                    latestWatchedAt: entry.watchedAt,
                    entries: [entry]
                )
            }
        }
        
        return groups.values.sorted {
            ($0.latestWatchedAt ?? "") > ($1.latestWatchedAt ?? "")
        }
    }
    
    var body: some View {
        ScrollView(showsIndicators: true) {
            LazyVStack(spacing: 20) {
                if selectedFilter != .timeline {
                    let displayGroups = groupedHistory.filter { group in
                        if selectedFilter == .movies { return group.mediaType == .movie }
                        if selectedFilter == .tv { return group.mediaType == .tv }
                        return true
                    }
                    ForEach(displayGroups) { group in
                        if group.mediaType == .movie, let firstEntry = group.entries.first {
                            NavigationLink(destination: MediaDetailView(route: MediaDetailRoute(entry: firstEntry))) {
                                GroupedHistoryCard(group: group)
                            }
                            .buttonStyle(SquishyHistoryCardButtonStyle())
                            .padding(.horizontal, 16)
                        } else {
                            NavigationLink(destination: ShowWatchHistoryView(viewModel: viewModel, tmdbId: group.tmdbId, showName: group.displayTitle, entries: group.entries)) {
                                GroupedHistoryCard(group: group)
                            }
                            .buttonStyle(SquishyHistoryCardButtonStyle())
                            .padding(.horizontal, 16)
                        }
                    }
                } else {
                    ForEach(filteredHistory) { entry in
                        NavigationLink(destination: MediaDetailView(route: MediaDetailRoute(entry: entry))) {
                            LiquidHistoryCard(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .contextMenu {
                            Button {
                                Task { await viewModel.markWatched(entry) }
                            } label: {
                                Label("Mark Watched Again", systemImage: "checkmark.circle")
                            }
                            Button(role: .destructive) {
                                Task { await viewModel.removeFromWatched(entry) }
                            } label: {
                                Label("Remove from Watched", systemImage: "xmark.circle")
                            }
                            .tint(.red)
                            .foregroundStyle(.red)
                        }
                        .onAppear {
                            if entry == filteredHistory.last {
                                Task { await viewModel.loadMoreWatchHistory() }
                            }
                        }
                    }
                }
                
                if viewModel.isLoadingMoreWatchHistory {
                    ProgressView()
                        .padding(.vertical, 20)
                }
            }
            .padding(.vertical, 16)
        }
        .background(AppBackground())
        .navigationTitle("Watch History")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Text("**Filter By**")
                        .foregroundStyle(.gray)
                    
                    Picker("Filter Options", selection: $selectedFilter) {
                        ForEach(WatchHistoryFilter.allCases, id: \.self) { option in
                            Label(option.rawValue, systemImage: option.icon).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private func formatWatchDate(_ isoString: String) -> String {
        isoString.formattedLocalTime(includeDay: true)
    }
}

struct SquishyHistoryCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct LiquidHistoryCard: View {
    let entry: WatchEntry
    var fallbackName: String? = nil
    var fallbackStillPath: String? = nil
    
    @State private var fetchedEpisodeName: String? = nil
    @State private var fetchedStillPath: String? = nil
    
    var imageUrl: URL? {
        let path = fetchedStillPath ?? fallbackStillPath ?? entry.episodeStillPath
        if let p = path, !p.isEmpty, p != "null" {
            return URL(string: "https://image.tmdb.org/t/p/w780\(p)")
        } else if let p = entry.backdropPath, !p.isEmpty, p != "null" {
            return URL(string: "https://image.tmdb.org/t/p/w780\(p)")
        } else {
            return Config.posterURL(path: entry.posterPath)
        }
    }
    
    var displayEpisodeName: String? {
        let epName = fallbackName ?? entry.episodeName
        if let n = epName, !n.isEmpty {
            return n
        }
        return fetchedEpisodeName
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Left Image (Small 16:9 or poster, we use the imageUrl which might be a still)
            CachedImage(url: imageUrl) {
                Color(white: 0.15)
            }
            .id(imageUrl) // Force update when still path is fetched
            .aspectRatio(contentMode: .fill)
            .frame(width: 112, height: 63)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 3)
            
            // Details
            VStack(alignment: .leading, spacing: 6) {
                Text(Config.displayTitle(title: entry.title, tmdbId: entry.tmdbId))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    .lineLimit(2)
                
                if let epName = displayEpisodeName, !epName.isEmpty, entry.mediaType == .tv {
                    Text(epName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                }
                
                HStack(spacing: 6) {
                    if entry.mediaType == .tv, let s = entry.season, let e = entry.episode {
                        HStack(spacing: 4) {
                            Image(systemName: "tv")
                            Text("S\(s) • E\(e)")
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))
                    } else if entry.mediaType == .movie {
                        HStack(spacing: 4) {
                            Image(systemName: "film")
                            Text("MOVIE")
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))
                    }
                    
                    Spacer()
                    
                    if let watchedAt = entry.watchedAt {
                        Text(watchedAt.formattedLocalTime(includeDay: true))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .padding(12)
        .background {
            // Cinematic Background
            ZStack {
                if let url = Config.posterURL(path: entry.posterPath) { // Use poster for background blur
                    CachedImage(url: url) { Color.clear }
                        .scaledToFill()
                        .blur(radius: 40)
                        .opacity(1.0)
                } else {
                    CachedImage(url: imageUrl) { Color.clear }
                        .scaledToFill()
                        .blur(radius: 40)
                        .opacity(1.0)
                }
                Color.black.opacity(0.2)
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .task {
            if entry.mediaType == .tv, let s = entry.season, let e = entry.episode {
                let missingName = entry.episodeName == nil || entry.episodeName!.isEmpty
                let missingStill = entry.episodeStillPath == nil || entry.episodeStillPath!.isEmpty || entry.episodeStillPath == "null"
                
                if missingName || missingStill {
                    do {
                        let episodes = try await TMDBService.shared.fetchSeasonEpisodes(tmdbId: entry.tmdbId, season: s)
                        if let ep = episodes.first(where: { $0.episodeNumber == e }) {
                            if missingName && !ep.name.isEmpty {
                                fetchedEpisodeName = ep.name
                            }
                            if missingStill, let still = ep.stillPath {
                                fetchedStillPath = still
                            }
                        }
                    } catch {
                        print("Failed to fetch episode details for history card: \(error)")
                    }
                }
            }
        }
    }
}


struct GroupedHistoryCard: View {
    let group: GroupedWatchEntry
    
    // TMDB details fetched asynchronously
    @State private var fetchedTotalEpisodes: Int?
    @State private var fetchedMovieRuntime: Int?
    @State private var lastAiredSeason: Int?
    @State private var lastAiredEpisode: Int?
    @State private var fetchedLogoURL: URL?
    @State private var hasFetched = false
    
    private var validEpisodesWatched: Int {
        if group.mediaType == .movie { return group.entries.count }
        let validEntries = group.entries.filter { entry in
            guard let s = entry.season, let e = entry.episode else { return false }
            if let las = lastAiredSeason, let lae = lastAiredEpisode {
                if s < las { return true }
                if s == las && e <= lae { return true }
                return false
            }
            return true
        }
        let unique = Set(validEntries.compactMap { "\($0.season ?? 0)-\($0.episode ?? 0)" })
        return unique.count
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.clear
                .aspectRatio(16/9, contentMode: .fit)
                .overlay(
                    CachedImage(url: group.cleanBackdropURL ?? URL(string: "https://image.tmdb.org/t/p/w780\(group.backdropPath ?? group.posterPath ?? "")")) {
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                    .aspectRatio(contentMode: .fill)
                )
                .clipped()
            
            // Gradients for text readability
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.8), location: 0.0),
                    .init(color: .clear, location: 0.3),
                    .init(color: .clear, location: 0.7),
                    .init(color: .black.opacity(0.9), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Center Logo
            if let logo = group.logoURL ?? fetchedLogoURL {
                CachedImage(url: logo, contentMode: .fit) { Color.clear }
                    .frame(maxWidth: 180, maxHeight: 90)
                    .shadow(color: .black.opacity(0.8), radius: 5, x: 0, y: 3)
            } else {
                Text(group.displayTitle)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
            }
            
            // Top Left Tags
            VStack {
                HStack {
                    if group.mediaType == .movie {
                        let progress = group.entries.first?.progressFraction ?? 1.0
                        if progress >= 0.95 {
                            Text("WATCHED")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.green.opacity(0.15))
                                .background(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Color.green.opacity(0.4), lineWidth: 0.5))
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                        }
                    } else {
                        if let total = fetchedTotalEpisodes, total > 0, validEpisodesWatched >= total {
                            Text("WATCHED")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.green.opacity(0.15))
                                .background(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Color.green.opacity(0.4), lineWidth: 0.5))
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                        }
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(12)
            
            // Bottom Info Bar
            VStack {
                Spacer()
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        if group.mediaType == .movie {
                            let first = group.entries.first
                            let progress = first?.progressFraction ?? 1.0
                            let totalMin = fetchedMovieRuntime ?? first?.runtime ?? (first?.length != nil ? first!.length! / 60000 : 100)
                            let currentMin = Int(progress * Double(totalMin))
                            
                            Text("\(currentMin) / \(totalMin) min")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.3)).frame(height: 4)
                                    Capsule().fill(Color.white).frame(width: geo.size.width * max(0.0, min(progress, 1.0)), height: 4)
                                }
                            }
                            .frame(height: 4)
                            .padding(.top, 2)
                        } else {
                            let total = fetchedTotalEpisodes ?? max(validEpisodesWatched, 1)
                            Text("\(validEpisodesWatched) / \(fetchedTotalEpisodes != nil ? "\(total)" : "?") Episodes")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.3)).frame(height: 4)
                                    Capsule().fill(Color.white).frame(width: geo.size.width * max(0.0, min(Double(validEpisodesWatched) / Double(total), 1.0)), height: 4)
                                }
                            }
                            .frame(height: 4)
                            .padding(.top, 2)
                        }
                    }
                    
                    Spacer()
                }
                .padding(16)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // Liquid Glass border
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.8), location: 0.0),
                            .init(color: .white.opacity(0.3), location: 0.2),
                            .init(color: .white.opacity(0.2), location: 0.5),
                            .init(color: .white.opacity(0.3), location: 0.8),
                            .init(color: .white.opacity(0.5), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        // Inner rim for 3D thickness
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                .padding(1.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
        .onAppear {
            if !hasFetched {
                loadDetails()
                hasFetched = true
            }
        }
    }
    
    private func loadDetails() {
        Task {
            let tmdbKey = Config.tmdbAPIKey
            let typeStr = group.mediaType == .movie ? "movie" : "tv"
            
            if group.mediaType == .movie {
                if let url = URL(string: "https://api.themoviedb.org/3/movie/\(group.tmdbId)?api_key=\(tmdbKey)") {
                    if let (data, _) = try? await URLSession.shared.data(from: url) {
                        struct TMDBMovieDetail: Codable { let runtime: Int? }
                        if let details = try? JSONDecoder().decode(TMDBMovieDetail.self, from: data) {
                            await MainActor.run {
                                fetchedMovieRuntime = details.runtime
                            }
                        }
                    }
                }
            }
            
            if group.mediaType == .tv {
                if let url = URL(string: "https://api.themoviedb.org/3/tv/\(group.tmdbId)?api_key=\(tmdbKey)") {
                    if let (data, _) = try? await URLSession.shared.data(from: url) {
                        struct TMDBTVDetail: Codable {
                            let number_of_episodes: Int?
                            let last_episode_to_air: LastEpisode?
                            let seasons: [Season]?
                            
                            struct LastEpisode: Codable {
                                let episode_number: Int
                                let season_number: Int
                            }
                            struct Season: Codable {
                                let episode_count: Int
                                let season_number: Int
                            }
                        }
                        if let details = try? JSONDecoder().decode(TMDBTVDetail.self, from: data) {
                            var airedCount = details.number_of_episodes
                            if let last = details.last_episode_to_air, let seasons = details.seasons {
                                var countPrevious = 0
                                var currentSeasonCount = 0
                                for season in seasons {
                                    if season.season_number > 0 && season.season_number < last.season_number {
                                        countPrevious += season.episode_count
                                    }
                                    if season.season_number == last.season_number {
                                        currentSeasonCount = season.episode_count
                                    }
                                }
                                
                                // TMDB anime quirk: sometimes last_episode_to_air.episode_number is the absolute episode number across all seasons
                                if last.episode_number > currentSeasonCount && last.episode_number > 100 {
                                    airedCount = last.episode_number
                                } else {
                                    airedCount = countPrevious + last.episode_number
                                }
                            }
                            await MainActor.run {
                                fetchedTotalEpisodes = airedCount
                                lastAiredSeason = details.last_episode_to_air?.season_number
                                lastAiredEpisode = details.last_episode_to_air?.episode_number
                            }
                        }
                    }
                }
            }
            
            if group.logoURL == nil {
                if let url = URL(string: "https://api.themoviedb.org/3/\(typeStr)/\(group.tmdbId)/images?api_key=\(tmdbKey)&include_image_language=en,null") {
                    if let (data, _) = try? await URLSession.shared.data(from: url) {
                        struct TMDBImage: Codable { let file_path: String?; let iso_639_1: String? }
                        struct TMDBImages: Codable { let logos: [TMDBImage]? }
                        if let images = try? JSONDecoder().decode(TMDBImages.self, from: data) {
                            let enLogos = images.logos?.filter { $0.iso_639_1 == "en" && !($0.file_path?.hasSuffix(".svg") ?? false) } ?? []
                            let anyLogos = images.logos?.filter { !($0.file_path?.hasSuffix(".svg") ?? false) } ?? []
                            let logoPath = enLogos.first?.file_path ?? anyLogos.first?.file_path
                            
                            if let lp = logoPath {
                                await MainActor.run {
                                    fetchedLogoURL = URL(string: "https://image.tmdb.org/t/p/w500\(lp)")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


struct ShowWatchHistoryView: View {
    @ObservedObject var viewModel: HomeViewModel
    let tmdbId: Int
    let showName: String
    let entries: [WatchEntry] // Passed from the grouped history
    
    struct EpData: Equatable {
        let name: String
        let stillPath: String
    }
    @State private var fetchedEpisodeData: [String: EpData] = [:]
    
    // We sort the entries chronologically (oldest to newest or newest to oldest? Usually newest to oldest for history).
    var sortedEntries: [WatchEntry] {
        entries.sorted {
            ($0.watchedAt ?? "") > ($1.watchedAt ?? "")
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(sortedEntries) { entry in
                    NavigationLink(destination: MediaDetailView(route: MediaDetailRoute(entry: entry))) {
                        let key = "\(entry.season ?? 0)-\(entry.episode ?? 0)"
                        let data = fetchedEpisodeData[key]
                        LiquidHistoryCard(entry: entry, fallbackName: data?.name, fallbackStillPath: data?.stillPath)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .contextMenu {
                        Button {
                            Task { await viewModel.markWatched(entry) }
                        } label: {
                            Label("Mark Watched Again", systemImage: "checkmark.circle")
                        }
                        Button(role: .destructive) {
                            Task { await viewModel.removeFromWatched(entry) }
                        } label: {
                            Label("Remove from Watched", systemImage: "xmark.circle")
                        }
                        .tint(.red)
                        .foregroundStyle(.red)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle(showName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
