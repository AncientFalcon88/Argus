import SwiftUI
import Combine
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @Environment(\.modelContext) private var modelContext
    
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    if viewModel.isLoadingHero && viewModel.heroItems.isEmpty {
                        SkeletonHeroCarouselView()
                            .padding(.top, -50)
                            .padding(.bottom, -(UIScreen.main.bounds.width * 0.15))
                    } else if !viewModel.heroItems.isEmpty {
                        HomeHeroCarouselView(items: viewModel.heroItems)
                            .padding(.top, -50)
                            .padding(.bottom, -(UIScreen.main.bounds.width * 0.15))
                    } else if !viewModel.isLoadingHero && viewModel.heroItems.isEmpty {
                        HeroEmptyStateView()
                            .padding(.top, -50)
                    }
                    
                    if let error = viewModel.errorMessage, !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(.horizontal, 16)
                    }

                    if !Config.isAPIKeyConfigured {
                        settingsPrompt
                    }

                    if viewModel.isLoadingContinueWatching || !viewModel.continueWatching.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "Continue Watching", symbol: "play")
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(alignment: .top, spacing: 16) {
                                    if viewModel.isLoadingContinueWatching {
                                        ForEach(0..<4, id: \.self) { _ in
                                            SkeletonCardView(isLandscape: true, showProgressBar: true)
                                        }
                                    } else {
                                        ForEach(Array(viewModel.continueWatching.enumerated()), id: \.element.id) { index, item in
                                            VStack(spacing: 0) {
                                                ContinueWatchingCard(item: item, viewModel: viewModel)
                                            }
                                            .zIndex(Double(viewModel.continueWatching.count - index))
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.bottom, 24)
                        }
                    }
                    if viewModel.isLoadingUpcoming || (viewModel.upcomingLoaded && !viewModel.upcomingEpisodes.isEmpty) {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "Upcoming", symbol: "calendar")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(alignment: .top, spacing: 16) {
                                    if viewModel.isLoadingUpcoming {
                                        ForEach(0..<4, id: \.self) { _ in
                                            SkeletonCardView(isLandscape: true)
                                        }
                                    } else {
                                        ForEach(Array(viewModel.upcomingEpisodes.enumerated()), id: \.element.id) { index, ep in
                                            VStack(spacing: 0) {
                                                UpcomingEpisodeCard(ep: ep)
                                        }
                                        .zIndex(Double(viewModel.upcomingEpisodes.count - index))
                                    }
                                }
                            }
                                .padding(.horizontal, 16)
                            }
                            .padding(.bottom, 24)
                        }
                    }
                    
                    if viewModel.isLoadingWatchHistory || !viewModel.watchHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            NavigationLink(destination: WatchHistoryListView(viewModel: viewModel)) {
                                SectionHeader(title: "Watch History", symbol: "clock.arrow.circlepath", hasChevron: true)
                            }
                            .buttonStyle(.plain)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(alignment: .top, spacing: 16) {
                                    if viewModel.isLoadingWatchHistory {
                                        ForEach(0..<4, id: \.self) { _ in
                                            SkeletonCardView(isLandscape: true)
                                        }
                                    } else {
                                        ForEach(Array(viewModel.watchHistory.prefix(50).enumerated()), id: \.element.id) { index, entry in
                                            VStack(spacing: 0) {
                                                WatchHistoryCard(entry: entry, viewModel: viewModel)
                                            .buttonStyle(.plain)
                                            }
                                            .zIndex(Double(viewModel.watchHistory.prefix(50).count - index))
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.bottom, 24)
                        }
                    }

                    if viewModel.isLoadingTrending || (!viewModel.trendingMovies.isEmpty || !viewModel.trendingTVs.isEmpty) {
                        HomeTrendingSection(viewModel: viewModel)
                            .padding(.bottom, 24)
                    }

                    if viewModel.isLoadingRecentLists || !viewModel.recentLists.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "New Lists", symbol: "list.star")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    if viewModel.isLoadingRecentLists {
                                        ForEach(0..<3, id: \.self) { _ in
                                            SkeletonHomeListGlassCard()
                                        }
                                    } else {
                                        ForEach(viewModel.recentLists) { list in
                                            NavigationLink(destination: WatchlistDetailView(list: list)) {
                                                HomeListGlassCard(list: list)
                                            }
                                            .buttonStyle(SquishyLiquidCardButtonStyle())
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.viewAligned)
                        }
                        .padding(.bottom, 24)
                    }

                    if viewModel.isLoadingRecentSkips || !viewModel.recentSkips.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "Recently Updated Skips", symbol: "bolt")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    if viewModel.isLoadingRecentSkips {
                                        ForEach(0..<3, id: \.self) { _ in
                                            SkeletonRecentSkipGlassCard()
                                        }
                                    } else {
                                        ForEach(Array(viewModel.recentSkips.prefix(10))) { skip in
                                            MediaDetailLink(route: MediaDetailRoute(tmdbId: skip.tmdbId, mediaType: skip.mediaTypeEnum)) {
                                                RecentSkipGlassCard(skip: skip)
                                            }
                                            .buttonStyle(SquishyLiquidCardButtonStyle())
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.viewAligned)
                        }
                        .padding(.bottom, 24)
                    }

                    if viewModel.isLoadingRecentRatings || !viewModel.recentRatings.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "Recently Rated", symbol: "star")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    if viewModel.isLoadingRecentRatings {
                                        ForEach(0..<3, id: \.self) { _ in
                                            SkeletonRecentRatingGlassCard()
                                        }
                                    } else {
                                        ForEach(Array(viewModel.recentRatings.prefix(10))) { rating in
                                            MediaDetailLink(route: MediaDetailRoute(tmdbId: rating.tmdbId, mediaType: rating.mediaTypeEnum)) {
                                                RecentRatingGlassCard(rating: rating)
                                            }
                                            .buttonStyle(SquishyLiquidCardButtonStyle())
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.viewAligned)
                        }
                        .padding(.bottom, 24)
                    }

                    if viewModel.isLoadingRecentHighlights || !viewModel.recentHighlights.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "Recent Highlights", symbol: "flag")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    if viewModel.isLoadingRecentHighlights {
                                        ForEach(0..<3, id: \.self) { _ in
                                            SkeletonRecentHighlightGlassCard()
                                        }
                                    } else {
                                        ForEach(Array(viewModel.recentHighlights.prefix(10))) { highlight in
                                            MediaDetailLink(route: MediaDetailRoute(tmdbId: highlight.tmdbId, mediaType: highlight.mediaTypeEnum)) {
                                                RecentHighlightGlassCard(highlight: highlight)
                                            }
                                            .buttonStyle(SquishyLiquidCardButtonStyle())
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.viewAligned)
                        }
                        .padding(.bottom, 24)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .ignoresSafeArea(edges: .top)
            .mediaDetailDestination()
            .onAppear {
                viewModel.configure(context: modelContext)
                if !viewModel.hasLoadedData && !viewModel.isLoading {
                    Task {
                        await viewModel.enrichCachedIfNeeded()
                        await viewModel.refreshData()
                    }
                }
            }
            .onReceive(timer) { _ in
                viewModel.refreshCountdowns()
            }
        }
    }

    private var settingsPrompt: some View {
        NavigationLink {
            SettingsView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                Text("Configure API keys to load your library")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(GlassTheme.primaryText)
            .padding(14)
            .liquidGlass()
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func carouselSection<Item: Identifiable, Content: View>(
        title: String,
        symbol: String,
        items: [Item],
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        VStack(spacing: 0) {
            SectionHeader(title: title, symbol: symbol)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(items) { item in
                        content(item)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
    }
    
    private func formatWatchDate(_ isoString: String) -> String {
        isoString.formattedLocalTime()
    }
}

struct HomePosterTag: View {
    let text: String
    var isBold: Bool = false
    
    var body: some View {
        Text(text)
            .font(isBold ? .caption.weight(.bold) : .caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
    }
}

struct ContinueWatchingCard: View {
    let item: ContinueWatchingItem
    @ObservedObject var viewModel: HomeViewModel
    
    var body: some View {
        MediaDetailLink(route: item.resumeRoute()) {
            let titleString = Config.displayTitle(title: item.title, tmdbId: item.tmdbId)
            let subtitleString = item.mediaType == .movie ? titleString : (item.episodeName ?? "Episode \(item.episode ?? 1)")
            
            let imgUrl: URL? = {
                if let still = item.episodeStillPath, !still.isEmpty {
                    return URL(string: "https://image.tmdb.org/t/p/w500\(still)")
                } else if let backdrop = item.backdropPath, !backdrop.isEmpty {
                    return Config.backdropURL(path: backdrop)
                } else {
                    return Config.posterURL(path: item.posterPath)
                }
            }()
            
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottom) {
                    CachedImage(url: imgUrl) {
                        Rectangle().fill(Color.white.opacity(0.08))
                    }
                    .id(imgUrl)
                    .aspectRatio(3/2, contentMode: .fill)
                    .frame(width: 260, height: 174)
                    .clipped()
                    
                    // 1. Thick Glass Sheen (Base gradient)
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.4), location: 0.0),
                            .init(color: .white.opacity(0.0), location: 0.2),
                            .init(color: .clear, location: 0.5),
                            .init(color: .black.opacity(0.3), location: 0.8),
                            .init(color: .black.opacity(0.6), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    

                    
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    
                    if item.mediaType == .movie, let logo = item.logoURL {
                        CachedImage(url: logo, contentMode: .fit) { Color.clear }
                            .frame(maxWidth: 160, maxHeight: 80)
                            .shadow(color: .black.opacity(0.8), radius: 5, x: 0, y: 3)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    
                    VStack(spacing: 0) {
                        HStack {
                            HomePosterTag(text: item.episodeLabel)
                            Spacer()
                            if item.progress > 0 {
                                HomePosterTag(text: "\(Int(round(item.progress * 100)))%", isBold: true)
                            } else {
                                HomePosterTag(text: "NEXT", isBold: true)
                            }
                        }
                        .padding(12)
                        
                        Spacer()
                        
                        VStack(spacing: 8) {
                            HStack(alignment: .bottom) {
                                if !(item.mediaType == .movie && item.logoURL != nil) {
                                    Text(titleString)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .kerning(0.3)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.white, Color(white: 0.8)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                                }
                                Spacer()
                                if let runtime = item.runtime {
                                    let remaining = max(1, Int(Double(runtime) * (1.0 - item.progress)))
                                    Text(item.progress > 0 ? "\(remaining)m left" : "\(runtime)m")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.85))
                                }
                            }
                            
                            if item.progress > 0 {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.3)).frame(height: 4)
                                        Capsule().fill(Color.white).frame(width: geo.size.width * max(0.0, min(item.progress, 1.0)), height: 4)
                                    }
                                }
                                .frame(height: 4)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                    }
                }
                .frame(width: 260, height: 174)
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
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black)
                        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
                        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 10)
                )
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 16))
                .contextMenu {
                    Button {
                        Task { await viewModel.markNextEpisodeWatched(item: item) }
                    } label: {
                        Label("Mark Watched", systemImage: "checkmark.circle")
                    }
                    if item.mediaType == .tv {
                        Button(role: .destructive) {
                            Task { await viewModel.revertToPreviousEpisode(item: item) }
                        } label: {
                            Label("Revert to Previous Episode", systemImage: "arrow.uturn.backward.circle")
                        }
                        .tint(.red)
                        .foregroundStyle(.red)
                    }
                    
                    if item.progress > 0 {
                        Button(role: .destructive) {
                            Task { await viewModel.removeWatchProgress(item: item) }
                        } label: {
                            Label("Remove Watch Progress", systemImage: "xmark.circle")
                        }
                        .tint(.red)
                        .foregroundStyle(.red)
                    }
                }
                
                HStack(alignment: .center) {
                    Text(subtitleString)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 0) {
                        Text(item.timeAgo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(width: 260)
        }
    }
}

struct UpcomingEpisodeCard: View {
    let ep: UpcomingEpisode
    
    var body: some View {
        MediaDetailLink(route: MediaDetailRoute(tmdbId: ep.showId, mediaType: .tv)) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    CachedImage(url: ep.backdropURL) {
                        Rectangle().fill(Color.white.opacity(0.08))
                    }
                    .id(ep.backdropURL)
                    .aspectRatio(3/2, contentMode: .fill)
                    .frame(width: 260, height: 174)
                    .clipped()
                    
                    // 1. Thick Glass Sheen (Base gradient)
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.4), location: 0.0),
                            .init(color: .white.opacity(0.0), location: 0.2),
                            .init(color: .clear, location: 0.5),
                            .init(color: .black.opacity(0.3), location: 0.8),
                            .init(color: .black.opacity(0.6), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    

                    
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    
                    if let logo = ep.logoURL {
                        CachedImage(url: logo, contentMode: .fit) { Color.clear }
                            .frame(maxWidth: 160, maxHeight: 80)
                            .shadow(color: .black.opacity(0.8), radius: 5, x: 0, y: 3)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    
                    VStack {
                        HStack(alignment: .top) {
                            HomePosterTag(text: ep.episodeLabel)
                            Spacer()
                            HomePosterTag(text: ep.countdownLabel, isBold: true)
                        }
                        .padding(12)
                        Spacer()
                        if ep.logoURL == nil {
                            HStack {
                                Text(ep.showName)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .kerning(0.3)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white, Color(white: 0.8)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .lineLimit(1)
                                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                                Spacer()
                            }
                            .padding(8)
                        }
                    }
                }
                .frame(width: 260, height: 174)
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
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 10)
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 16))
                
                HStack(alignment: .center) {
                    Text(ep.episodeName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 0) {
                        Text(ep.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 260)
        }
    }
}

struct WatchHistoryCard: View {
    let entry: WatchEntry
    @ObservedObject var viewModel: HomeViewModel
    
    var body: some View {
        MediaDetailLink(route: MediaDetailRoute(entry: entry)) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    let tmdbId = entry.tmdbId
                    let isMovie = entry.mediaType == .movie
                    let logo = isMovie ? viewModel.historyLogos[tmdbId] : nil
                    
                    let imgUrl: URL? = {
                        if let still = entry.episodeStillPath, !still.isEmpty {
                            return URL(string: "https://image.tmdb.org/t/p/w500\(still)")
                        } else if let backdrop = entry.backdropPath, !backdrop.isEmpty {
                            return Config.backdropURL(path: backdrop)
                        } else {
                            return Config.posterURL(path: entry.posterPath)
                        }
                    }()
                    CachedImage(url: imgUrl) {
                        ZStack {
                            Rectangle().fill(Color.white.opacity(0.08))
                            Image(systemName: isMovie ? "film" : "tv")
                                .font(.system(size: 30))
                                .foregroundStyle(.white.opacity(0.2))
                        }
                    }
                    .id(imgUrl)
                    .aspectRatio(3/2, contentMode: .fill)
                    .frame(width: 260, height: 174)
                    .clipped()
                    
                    // 1. Thick Glass Sheen (Base gradient)
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.4), location: 0.0),
                            .init(color: .white.opacity(0.0), location: 0.2),
                            .init(color: .clear, location: 0.5),
                            .init(color: .black.opacity(0.3), location: 0.8),
                            .init(color: .black.opacity(0.6), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    
                    if let logoURL = logo {
                        CachedImage(url: logoURL, contentMode: .fit) { Color.clear }
                            .frame(maxWidth: 160, maxHeight: 80)
                            .shadow(color: .black.opacity(0.8), radius: 5, x: 0, y: 3)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    
                    VStack {
                        HStack(alignment: .top) {
                            let label = entry.episodeLabel
                            if !label.isEmpty {
                                HomePosterTag(text: label)
                            }
                            Spacer()
                        }
                        .padding(12)
                        
                        Spacer()
                        
                        VStack(spacing: 8) {
                            HStack(alignment: .bottom) {
                                if !(entry.mediaType == .movie && logo != nil) {
                                    Text(Config.displayTitle(title: entry.title, tmdbId: entry.tmdbId))
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .kerning(0.3)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.white, Color(white: 0.8)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                    }
                }
                .frame(width: 260, height: 174)
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
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 10)
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 16))
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
                
                HStack(alignment: .center) {
                    let subtitleString = entry.mediaType == .tv ? (entry.episodeName ?? "Episode \(entry.episode ?? 1)") : Config.displayTitle(title: entry.title, tmdbId: entry.tmdbId)
                    
                    Text(subtitleString)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    HStack(spacing: 0) {
                        Text(formatWatchDate(entry.watchedAt ?? ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 260)
        }
    }
    
    private func formatWatchDate(_ isoString: String) -> String {
        isoString.formattedLocalTime()
    }
}

// MARK: - Recent Update Rows

fileprivate func computeTimeAgo(dateString: String) -> String {
    let date = Date.parseRobustly(dateString)
    if date.timeIntervalSince1970 <= 0 { return "" }
    return date.relativeTime()
}

extension Date {
    fileprivate func relativeTime() -> String {
        let mins = Int(Date().timeIntervalSince(self) / 60)
        if mins < 1 { return "Just now" }
        if mins < 60 { return "\(mins)m ago" }
        let hrs = mins / 60
        if hrs < 24 { return "\(hrs)h ago" }
        return "\(hrs/24)d ago"
    }
}

extension RecentSkip {
    var timeAgo: String { computeTimeAgo(dateString: updated) }
}
extension RecentRating {
    var timeAgo: String { computeTimeAgo(dateString: updated) }
}
extension RecentHighlight {
    var timeAgo: String { computeTimeAgo(dateString: updated) }
}

struct SquishyLiquidCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct RecentSkipRowView: View {
    let skip: RecentSkip
    @State private var isPressed = false
    
    var body: some View {
        NavigationLink(value: MediaDetailRoute(tmdbId: skip.tmdbId, mediaType: skip.mediaTypeEnum)) {
            HStack(spacing: 16) {
                // Left: Glossy Poster
                CachedImage(url: skip.posterURL) {
                    ZStack {
                        Rectangle().fill(Color.gray.opacity(0.2))
                        Image(systemName: skip.mediaTypeEnum == .movie ? "film" : (skip.mediaTypeEnum == .tv ? "tv" : "person.fill"))
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .aspectRatio(2/3, contentMode: .fit)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Right: Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(skip.title ?? "Unknown")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        // Skip Pill
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill").font(.system(size: 10, weight: .black))
                            Text("SKIP").font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0, green: 0.9, blue: 0.55), Color(red: 0.66, green: 0.33, blue: 0.97)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        
                        if skip.mediaTypeEnum == .tv, let s = skip.season, let e = skip.episode {
                            Text("S\(s) • E\(e)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        } else if skip.mediaTypeEnum == .movie {
                            Text("MOVIE")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(skip.timeAgo)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.85)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1), .white.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(SquishyLiquidCardButtonStyle())
    }
}

struct RecentRatingRowView: View {
    let rating: RecentRating
    @State private var isPressed = false
    
    var body: some View {
        NavigationLink(value: MediaDetailRoute(tmdbId: rating.tmdbId, mediaType: rating.mediaTypeEnum)) {
            HStack(spacing: 16) {
                // Left: Glossy Poster
                CachedImage(url: rating.posterURL) {
                    ZStack {
                        Rectangle().fill(Color.gray.opacity(0.2))
                        Image(systemName: rating.mediaTypeEnum == .movie ? "film" : (rating.mediaTypeEnum == .tv ? "tv" : "person.fill"))
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .aspectRatio(2/3, contentMode: .fit)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Right: Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(rating.title ?? "Unknown")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        // Rating Pill
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill").font(.system(size: 10, weight: .black))
                            Text(String(format: "%.0f", rating.score)).font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.25))
                        .clipShape(Capsule())
                        
                        if let source = rating.label, !source.isEmpty {
                            Text(source.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(rating.timeAgo)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.85)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1), .white.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(SquishyLiquidCardButtonStyle())
    }
}

struct RecentHighlightRowView: View {
    let highlight: RecentHighlight
    @State private var userProfile: UserProfile?
    @State private var isPressed = false
    
    var body: some View {
        NavigationLink(value: MediaDetailRoute(tmdbId: highlight.tmdbId, mediaType: highlight.mediaTypeEnum)) {
            HStack(spacing: 16) {
                // Left: Glossy Poster
                CachedImage(url: highlight.posterURL) {
                    ZStack {
                        Rectangle().fill(Color.gray.opacity(0.2))
                        Image(systemName: highlight.mediaTypeEnum == .movie ? "film" : (highlight.mediaTypeEnum == .tv ? "tv" : "person.fill"))
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .aspectRatio(2/3, contentMode: .fit)
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Right: Info
                VStack(alignment: .leading, spacing: 6) {
                    if let profile = userProfile, !profile.name.isEmpty {
                        HStack(spacing: 6) {
                            if let avatarUrl = profile.avatarUrl {
                                CachedImage(url: avatarUrl) {
                                    Circle().fill(Color.white.opacity(0.1))
                                }
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                            } else {
                                Text(String(profile.name.prefix(1)).uppercased())
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .frame(width: 24, height: 24)
                                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .clipShape(Circle())
                                    .foregroundStyle(.white)
                            }
                            
                            Text(profile.name)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(.bottom, 2)
                    }
                    
                    Text(highlight.title ?? "Unknown")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        // Highlight Pill
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill").font(.system(size: 10, weight: .black))
                            Text("HIGHLIGHT").font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.red.opacity(0.25))
                        .clipShape(Capsule())
                        
                        if highlight.mediaTypeEnum == .tv, let s = highlight.season, let e = highlight.episode {
                            Text("S\(s) • E\(e)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                    
                    if let desc = highlight.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                    
                    Text(highlight.timeAgo)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.85)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1), .white.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(SquishyLiquidCardButtonStyle())
        .task {
            if let userId = highlight.user {
                userProfile = await UserService.shared.fetchUserProfile(id: userId)
            }
        }
    }
}

struct HomeListCardView: View {
    let list: MediaList
    @State private var userProfile: UserProfile?
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Info
            VStack(alignment: .leading, spacing: 8) {
                // Creator Badge
                if let profile = userProfile, !profile.name.isEmpty {
                    HStack(spacing: 6) {
                        if let avatarUrl = profile.avatarUrl {
                            CachedImage(url: avatarUrl) {
                                Circle().fill(Color.white.opacity(0.1))
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                        } else {
                            Text(String(profile.name.prefix(1)).uppercased())
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .frame(width: 24, height: 24)
                                .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .clipShape(Circle())
                                .foregroundStyle(.white)
                        }
                        
                        Text(profile.name)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.bottom, 4)
                }
                
                Text(list.name)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                if let desc = list.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }
                
                // Item Count Pill
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet.rectangle.portrait").font(.system(size: 11, weight: .black))
                    Text("\(list.itemCount ?? 0) ITEMS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.top, 4)
            }
            
            Spacer(minLength: 16)
            
            // Right: Cover Flow Posters
            if !list.previewPosters.isEmpty {
                let posters = Array(list.previewPosters.prefix(4))
                ZStack(alignment: .trailing) {
                    ForEach(Array(posters.enumerated().reversed()), id: \.offset) { index, url in
                        CachedImage(url: url) { Rectangle().fill(Color.gray.opacity(0.3)) }
                            .aspectRatio(2/3, contentMode: .fit)
                            .frame(height: 100 - CGFloat(index * 8))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.3), lineWidth: 1))
                            .shadow(color: .black.opacity(0.5), radius: 6, x: -4, y: 2)
                            .offset(x: CGFloat(index * -16))
                            .rotationEffect(.degrees(Double(index) * -4))
                            .zIndex(Double(-index))
                    }
                }
                .padding(.trailing, 8)
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.1), .white.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
        // Note: For NavigationLink destination rows, ButtonStyle is applied directly to the NavigationLink inside the parent view,
        // but since HomeListCardView is the content of the NavigationLink, we don't need the gesture here.
        .task {
            if let creatorName = list.creatorName {
                var avatarUrl: URL? = nil
                if let avatar = list.creatorAvatar, !avatar.isEmpty, let cId = list.creatorId {
                    avatarUrl = URL(string: "https://api.publicmetadb.com/api/files/users/\(cId)/\(avatar)")
                }
                userProfile = UserProfile(name: creatorName, avatarUrl: avatarUrl)
            } else if let userId = list.user {
                userProfile = await UserService.shared.fetchUserProfile(id: userId)
            }
        }
    }
}
import SwiftUI

struct HomeTrendingSection: View {
    @ObservedObject var viewModel: HomeViewModel
    @State private var selectedTab: MediaType = .movie
    
    enum MediaType { case movie, tv }
    @Namespace private var animation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header & Toggle
            SectionHeader(title: "Trending Today", symbol: "flame.fill") {
                // Pill Toggle
                HStack(spacing: 0) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = .movie
                        }
                    } label: {
                        Text("Movies")
                            .font(.system(size: 13, weight: selectedTab == .movie ? .bold : .semibold))
                            .foregroundStyle(selectedTab == .movie ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                ZStack {
                                    if selectedTab == .movie {
                                        Capsule().fill(Color.white.opacity(0.2))
                                            .matchedGeometryEffect(id: "tab", in: animation)
                                    }
                                }
                            )
                    }
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = .tv
                        }
                    } label: {
                        Text("Series")
                            .font(.system(size: 13, weight: selectedTab == .tv ? .bold : .semibold))
                            .foregroundStyle(selectedTab == .tv ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                ZStack {
                                    if selectedTab == .tv {
                                        Capsule().fill(Color.white.opacity(0.2))
                                            .matchedGeometryEffect(id: "tab", in: animation)
                                    }
                                }
                            )
                    }
                }
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
            }
            .padding(.bottom, 8)
            
            // Carousel
            let items = selectedTab == .movie ? viewModel.trendingMovies : viewModel.trendingTVs
            
            if items.isEmpty {
                // Skeleton state
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: -10) {
                        ForEach(0..<5, id: \.self) { _ in
                            SkeletonTrendingDeckCard()
                        }
                    }
                    .padding(.horizontal, 40) // Space for 3D expansion on edges
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: -10) { // Negative spacing so cards overlap slightly like a fan
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            TrendingDeckCard(viewModel: viewModel, item: item, rank: index + 1)
                        }
                    }
                    .padding(.horizontal, 40) // Space for 3D expansion on edges
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }
}

struct SkeletonTrendingDeckCard: View {
    @AppStorage("posterTitleEnabled") private var posterTitleEnabled = false
    
    var body: some View {
        GeometryReader { geo in
            let minX = geo.frame(in: .global).minX
            let midX = geo.frame(in: .global).midX
            let screenWidth = UIScreen.main.bounds.width
            
            // Calculate distance from center (-1 to 1)
            let distance = (midX - (screenWidth / 2)) / (screenWidth / 2)
            let absDistance = abs(distance)
            
            // Fan Arc Math
            let rotationAngle = distance * 15
            let yOffset = absDistance * 40
            let scale = 1.0 - (absDistance * 0.15)
            
            VStack {
                ShimmerView()
                    .frame(width: geo.size.width, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Spacer()
            }
            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 15)
            .scaleEffect(max(0.8, scale))
            .offset(y: yOffset)
            .rotationEffect(.degrees(rotationAngle))
            .rotation3DEffect(
                .degrees(-distance * 25),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .zIndex(1 - absDistance) // Center card on top
        }
        .frame(width: 180, height: posterTitleEnabled ? 330 : 280) // Expand when titles are enabled
    }
}

struct TrendingDeckCard: View {
    @ObservedObject var viewModel: HomeViewModel
    let item: TMDBMediaItem
    let rank: Int
    @AppStorage("posterTitleEnabled") private var posterTitleEnabled = false
    
    var body: some View {
        MediaDetailLink(route: MediaDetailRoute(tmdbId: item.tmdbId, mediaType: item.mediaType)) {
            GeometryReader { geo in
                let minX = geo.frame(in: .global).minX
                let midX = geo.frame(in: .global).midX
                let screenWidth = UIScreen.main.bounds.width
                
                // Calculate distance from center (-1 to 1)
                let distance = (midX - (screenWidth / 2)) / (screenWidth / 2)
                let absDistance = abs(distance)
                
                // Fan Arc Math
                let rotationAngle = distance * 15 // Tilt left/right depending on distance from center
                let yOffset = absDistance * 40    // Push side cards down slightly to form an arc
                let scale = 1.0 - (absDistance * 0.15) // Shrink side cards slightly
                
                ZStack(alignment: .topLeading) {
                    DiscoverPosterCell(
                        item: item,
                        pmdbRating: viewModel.pmdbRatings[item.tmdbId],
                        logoURL: viewModel.itemLogos[item.tmdbId],
                        cleanPosterURL: viewModel.cleanPosters[item.tmdbId],
                        customWidth: geo.size.width,
                        customHeight: 240,
                        hideTopBadge: true
                    )
                    
                    // Liquid Glass Number
                    Text("\(rank)")
                        .font(.system(size: 60, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            .linearGradient(
                                colors: [.white, .white.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 5)
                        .shadow(color: .white.opacity(0.6), radius: 2, x: -1, y: -1)
                        .blendMode(.plusLighter)
                        .padding(.leading, 12)
                        .padding(.top, 4)
                }
                .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 15)
                .scaleEffect(max(0.8, scale))
                .offset(y: yOffset)
                .rotationEffect(.degrees(rotationAngle))
                .rotation3DEffect(
                    .degrees(-distance * 25), // 3D tilt inwards
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .zIndex(1 - absDistance) // Center card on top
            }
            .frame(width: 180, height: posterTitleEnabled ? 330 : 280) // Expand when titles are enabled
        }
    }
}

// MARK: - List Glass Card
struct HomeListGlassCard: View {
    let list: MediaList
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Posters preview
            ZStack {
                Color.black.opacity(0.3)
                
                if list.previewPosters.isEmpty {
                    Image(systemName: "list.and.film")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    GeometryReader { geo in
                        HStack(spacing: -geo.size.width * 0.15) {
                            ForEach(Array(list.previewPosters.prefix(4).enumerated()), id: \.offset) { index, url in
                                CachedImage(url: url) {
                                    ZStack {
                                        Color.gray.opacity(0.2)
                                        Image(systemName: "film")
                                            .font(.title3)
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                }
                                    .aspectRatio(2/3, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                                    .rotationEffect(.degrees(Double(index) * 4 - 6))
                                    .zIndex(Double(4 - index))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                    }
                }
            }
            .frame(height: 160)
            .clipped()
            
            VStack(alignment: .leading, spacing: 6) {
                Text(list.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                Spacer(minLength: 0)
                
                HStack {
                    let count = list.itemCount ?? 0
                    Text("\(count) items")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.ultraThinMaterial))
                    
                    Spacer()
                    
                    if let creator = list.creatorName {
                        Text("By \(creator)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 260, height: 270)
        .background(
            ZStack {
                LinearGradient(colors: [Color.blue.opacity(0.2), Color.indigo.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Rectangle().fill(.ultraThinMaterial)
            }
        )
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
    }
}

// MARK: - Skip Glass Card
struct RecentSkipGlassCard: View {
    let skip: RecentSkip
    @State private var userProfile: UserProfile?
    
    var body: some View {
        ZStack(alignment: .center) {
            CachedImage(url: skip.posterURL) {
                ZStack {
                    Color.gray.opacity(0.2)
                    Image(systemName: skip.mediaTypeEnum == .movie ? "film" : (skip.mediaTypeEnum == .tv ? "tv" : "person.fill"))
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
                .aspectRatio(contentMode: .fill)
                .frame(width: 280, height: 160)
                .clipped()
                .overlay(.black.opacity(0.4))
                .overlay(.ultraThinMaterial)
            
            HStack(spacing: 12) {
                // Left: Info
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(skip.title ?? "Unknown")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        
                        if let s = skip.season, let e = skip.episode {
                            Text("S\(s) • E\(e)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    if let source = skip.source {
                        Text(source.uppercased())
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.orange.opacity(0.6)))
                            .overlay(Capsule().stroke(Color.orange, lineWidth: 1))
                    }
                    
                    if let profile = userProfile, !profile.name.isEmpty {
                        Text("\(profile.name) • \(skip.timeAgo)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    } else {
                        Text(skip.timeAgo)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 0)
                
                // Right: Clear Poster & Bolt
                VStack(alignment: .trailing, spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: .orange.opacity(0.6), radius: 6)
                    
                    Spacer(minLength: 0)
                    
                    CachedImage(url: skip.posterURL) {
                        ZStack {
                            Color.gray.opacity(0.2)
                            Image(systemName: skip.mediaTypeEnum == .movie ? "film" : (skip.mediaTypeEnum == .tv ? "tv" : "person.fill"))
                                .font(.title)
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                        .aspectRatio(2/3, contentMode: .fit)
                        .frame(height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                }
            }
            .padding(16)
        }
        .frame(width: 280, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .task {
            if let userId = skip.user {
                userProfile = await UserService.shared.fetchUserProfile(id: userId)
            }
        }
    }
}

// MARK: - Rating Glass Card
struct RecentRatingGlassCard: View {
    let rating: RecentRating
    @State private var userProfile: UserProfile?
    @AppStorage("convertRatings") private var convertRatings = false
    
    var body: some View {
        HStack(spacing: 0) {
            CachedImage(url: rating.posterURL) {
                ZStack {
                    Color.gray.opacity(0.2)
                    Image(systemName: rating.mediaTypeEnum == .movie ? "film" : (rating.mediaTypeEnum == .tv ? "tv" : "person.fill"))
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
                .aspectRatio(2/3, contentMode: .fit)
                .frame(width: 100, height: 150)
                .clipped()
                .mask(
                    LinearGradient(
                        colors: [.black, .black, .black.opacity(0.8), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(rating.title ?? "Unknown")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                Spacer(minLength: 0)
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(convertRatings ? convertedScoreTextFn(Int(rating.score), label: rating.label ?? "") : "\(Int(rating.score))")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(tintColors?.first ?? .white)
                        .shadow(color: (tintColors?.first ?? .white).opacity(0.5), radius: 5)
                    
                    if let label = rating.label {
                        Image("logo_hero_\(label)")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 14)
                    }
                }
                
                if let profile = userProfile, !profile.name.isEmpty {
                    Text("\(profile.name) • \(rating.timeAgo)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    Text(rating.timeAgo)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 280, height: 150)
        .background(.ultraThinMaterial)
        .background(
            ZStack {
                if let tints = tintColors {
                    let gradientOpacity = rating.label == "AN" ? 0.15 : 0.30
                    let gradientColors = tints.map { $0.opacity(gradientOpacity) } + [Color.clear]
                    LinearGradient(colors: gradientColors, startPoint: UnitPoint(x: 0.35, y: 0), endPoint: .bottomTrailing)
                } else {
                    LinearGradient(colors: [.white.opacity(0.15), .clear], startPoint: UnitPoint(x: 0.35, y: 0), endPoint: .bottomTrailing)
                }
            }
        )
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LinearGradient(colors: [(tintColors?.first ?? .white).opacity(0.6), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .task {
            if let userId = rating.user {
                userProfile = await UserService.shared.fetchUserProfile(id: userId)
            }
        }
    }
    
    private var tintColors: [Color]? {
        switch rating.label {
        case "IM": return [Color(red: 245/255, green: 197/255, blue: 24/255)]
        case "RE": return [Color(red: 0.83, green: 0.68, blue: 0.21)]
        case "TR": return [.purple]
        case "AN": return [Color(red: 0.0, green: 0.4, blue: 0.8)]
        case "LB": return [
            Color(red: 1.0, green: 0.5, blue: 0.0),
            Color(red: 1.0, green: 0.5, blue: 0.0),
            Color(red: 0.0, green: 0.88, blue: 0.33),
            Color(red: 0.0, green: 0.88, blue: 0.33),
            Color(red: 0.25, green: 0.74, blue: 0.96),
            Color(red: 0.25, green: 0.74, blue: 0.96)
        ]
        case "RT": return [Color(red: 250/255, green: 50/255, blue: 10/255)]
        case "PC": return [.red, .red, .yellow, .yellow]
        case "MC": return [.yellow, .black]
        case "TM": return [.teal]
        case "ML": return [Color(red: 0.2, green: 0.5, blue: 1.0)]
        default: return nil
        }
    }
}

// MARK: - Highlight Glass Card
struct RecentHighlightGlassCard: View {
    let highlight: RecentHighlight
    @State private var userProfile: UserProfile?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "quote.opening")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            
            Text(highlight.description ?? "")
                .font(.system(size: 18, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(4)
                .multilineTextAlignment(.leading)
            
            // Author and Time
            HStack(spacing: 6) {
                Text("—")
                    .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                    .fontWeight(.black)
                if let profile = userProfile, !profile.name.isEmpty {
                    Text("\(profile.name)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                Text("• \(highlight.timeAgo)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 4)
            
            Spacer(minLength: 0)
            
            // Citation Pill
            HStack(spacing: 10) {
                CachedImage(url: highlight.posterURL) {
                    ZStack {
                        Color.gray.opacity(0.2)
                        Image(systemName: highlight.mediaTypeEnum == .movie ? "film" : (highlight.mediaTypeEnum == .tv ? "tv" : "person.fill"))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(highlight.title ?? "Unknown")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    
                    if let s = highlight.season, let e = highlight.episode {
                        Text("S\(s) • E\(e)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial).opacity(0.8))
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .frame(width: 320, height: 240)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LinearGradient(colors: [.purple.opacity(0.6), .blue.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .purple.opacity(0.15), radius: 15, x: 0, y: 8)
        .task {
            if let userId = highlight.user {
                userProfile = await UserService.shared.fetchUserProfile(id: userId)
            }
        }
    }
}
