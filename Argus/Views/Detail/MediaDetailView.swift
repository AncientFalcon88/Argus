import SwiftUI
import SwiftData
import AVKit

struct MediaDetailView: View {
    let route: MediaDetailRoute
    @StateObject private var viewModel: MediaDetailViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @State private var showMarkAllWatchedAlert = false
    @State private var showMarkAllUnwatchedAlert = false
    @State private var showMovieWatchOptions = false
    @State private var showMovieUnwatchOptions = false
    @State private var showMovieManagePlaysSheet = false
    @State private var isMarkingWatched = false
    @State private var selectedSynopsisEpisode: EpisodeDisplay?
    @State private var selectedRatingEpisode: Int?
    @State private var managePlaysEpisode: Int?
    @State private var isOverviewExpanded = false
    @State private var animatedTab: CommunityDataTab? = nil
    @Namespace private var tabNamespace
    @AppStorage("autoPlayTrailers") private var autoPlayTrailers = true
    @AppStorage("autoplayLocation") private var autoplayLocation: AutoplayLocation = .both
    @AppStorage("playbackStyle") private var playbackStyle: PlaybackStyle = .resume
    @AppStorage("trailersStartMuted") private var trailersStartMuted = true
    @AppStorage("convertRatings") private var convertRatings = false
    @State private var isHeroMuted = true
    @State private var isVideoReady = false
    @State private var heroMinY: CGFloat = 0
    
    private let horizontalPadding: CGFloat = 16
    private var screenWidth: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 390
    }
    
    private var safeAreaTop: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 50
    }

    init(route: MediaDetailRoute) {
        self.route = route
        _viewModel = StateObject(wrappedValue: MediaDetailViewModel(route: route))
        _isHeroMuted = State(initialValue: UserDefaults.standard.bool(forKey: "trailersStartMuted"))
    }
    
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var isGeneratingShareImage = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if let detail = viewModel.detail {
                    Group {
                        heroHeader(detail)
                        actionButtons(detail)
                        tagsRow(detail)
                        overviewSection(detail)

                        // Next Episode (TV only, actively airing shows)
                        if detail.mediaType == .tv, let nextEp = detail.nextEpisodeToAir,
                           detail.status == "Returning Series" || detail.status == "In Production" {
                            NextEpisodeCard(episode: nextEp)
                                .padding(.top, 32)
                        }






                        if detail.mediaType == .tv {
                            episodesSection(detail)
                                .padding(.top, 32)
                        }

                        communitySection
                            .padding(.top, 32)

                        // Video Gallery (beyond the hero trailer)
                        if !detail.allVideos.isEmpty {
                            VideoGallerySection(videos: detail.allVideos)
                                .padding(.top, 32)
                        }

                        if !detail.credits.isEmpty {
                            FilteredCreditsSection(departmentGroups: detail.credits)
                                .padding(.top, 32)
                        }
                        
                        LiquidGlassDetailsSection(detail: detail)
                            .padding(.top, 32)

                        // Watch Providers (US)
                        if let providers = detail.watchProviders, providers.hasAny {
                            LiquidGlassWatchProvidersSection(providers: providers, link: providers.link)
                                .padding(.top, 32)
                        }

                        // Belongs to Collection (movies only)
                        if detail.mediaType == .movie,
                           let collName = detail.collectionName,
                           !viewModel.collectionMovies.isEmpty {
                            CollectionCarouselSection(
                                collectionName: collName,
                                movies: viewModel.collectionMovies,
                                pmdbRatings: viewModel.pmdbRatings,
                                itemLogos: viewModel.itemLogos,
                                cleanPosters: viewModel.cleanPosters
                            )
                            .padding(.top, 32)
                        }

                        if !viewModel.recommendations.isEmpty {
                            recommendationsSection
                                .padding(.top, 32)
                        }

                        // Written Reviews
                        if !detail.reviews.isEmpty {
                            ReviewsSection(reviews: detail.reviews)
                                .padding(.top, 32)
                        }

                        // Plot Keywords
                        if !detail.keywords.isEmpty {
                            PlotKeywordsSection(keywords: detail.keywords)
                                .padding(.top, 32)
                        }
                    }
                    .transition(.opacity)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red.opacity(0.9))
                        .padding(horizontalPadding)
                        .padding(.top, 48)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: viewModel.detail != nil)
            .padding(.bottom, 40)
        }
        .background(Color.black)
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if autoPlayTrailers && (autoplayLocation == .both || autoplayLocation == .detail) && isVideoReady && heroMinY > -100 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isHeroMuted.toggle()
                        }
                    }) {
                        Image(systemName: isHeroMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showShareSheet) {
            if let image = shareImage {
                SharePreviewSheet(image: image)
            }
        }
        .task {
            viewModel.loadCachedState(context: modelContext)
            await viewModel.load()
        }
        .onChange(of: viewModel.selectedSeason) {
            if !viewModel.isLoading {
                Task { await viewModel.seasonDidChange() }
            }
        }
        .sheet(isPresented: $viewModel.showListPicker) { listPickerSheet }
        .sheet(isPresented: Binding(
            get: { selectedRatingEpisode != nil },
            set: { if !$0 { selectedRatingEpisode = nil } }
        )) {
            if let ep = selectedRatingEpisode {
                EpisodeRatingSheet(viewModel: viewModel, episodeNumber: ep)
                    .presentationDetents([.height(680), .large])
            }
        }
        .overlay(alignment: .bottom) { actionToast }
        .background(actionDialogs)
        .sheet(item: $selectedSynopsisEpisode) { episode in
            EpisodeSynopsisSheet(episode: episode, seasonNumber: viewModel.selectedSeason)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $viewModel.showSkipSheet) {
            SkipSubmissionSheet(viewModel: viewModel, episode: viewModel.selectedSkipEpisode)
                .presentationDetents([.height(720), .large])
        }
        .sheet(isPresented: $viewModel.showHighlightSheet) {
            HighlightSubmissionSheet(viewModel: viewModel, episode: viewModel.selectedHighlightEpisode)
                .presentationDetents([.height(620), .large])
        }
        .sheet(isPresented: $viewModel.showExternalIDSheet) {
            ExternalIDSubmissionSheet(viewModel: viewModel)
                .presentationDetents([.height(360), .large])
        }
        .sheet(isPresented: Binding(
            get: { managePlaysEpisode != nil },
            set: { if !$0 { managePlaysEpisode = nil } }
        )) {
            if let ep = managePlaysEpisode {
                ManagePlaysView(viewModel: viewModel, episodeNumber: ep)
            }
        }
        .sheet(isPresented: $showMovieManagePlaysSheet) {
            ManagePlaysView(viewModel: viewModel, episodeNumber: nil)
        }
        .sheet(isPresented: $viewModel.showCommunityRatingSheet) {
            CommunityRatingSheet(viewModel: viewModel)
                .presentationDetents([.height(viewModel.editingCommunityRating == nil ? 520 : 380), .large])
        }
        .sheet(isPresented: $viewModel.showSeasonMappingSheet) {
            SeasonMappingSheet(viewModel: viewModel, editingMapping: viewModel.editingSeasonMapping)
                .onDisappear {
                    viewModel.editingSeasonMapping = nil
                }
                .presentationDetents([.height(772), .large])
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ActivityViewController(activityItems: [image])
                    .presentationDetents([.medium, .large])
            }
        }
        .overlay {
            if isGeneratingShareImage {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        Text("Generating Poster...")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(30)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                }
            }
        }
    }

    // MARK: - Hero

    private func heroHeader(_ detail: MediaDetailInfo) -> some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .global).minY
            let isScrollingDown = minY > 0
            let offset = isScrollingDown ? -minY : 0
            let height = geo.size.width * 1.4 + (isScrollingDown ? minY : 0)

            ZStack(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    if let posterPath = detail.textlessPosterPath ?? detail.posterPath, let url = Config.tmdbImageURL(path: posterPath, size: "w780") {
                        CachedImage(url: url) {
                            ZStack {
                                Color(white: 0.12)
                                Image(systemName: viewModel.route.mediaType == .movie ? "film" : "tv")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.white.opacity(0.1))
                            }
                        }
                        .frame(width: geo.size.width, height: height)
                        .clipped()
                    } else {
                        ZStack {
                            Color(white: 0.12)
                            Image(systemName: viewModel.route.mediaType == .movie ? "film" : "tv")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.1))
                        }
                        .frame(width: geo.size.width, height: height)
                    }
                    
                    if autoPlayTrailers && (autoplayLocation == .both || autoplayLocation == .detail), let trailerURL = viewModel.trailerURL {
                        DetailHeroVideoLayer(
                            trailerURL: trailerURL,
                            isMuted: $isHeroMuted,
                            isVideoReady: $isVideoReady,
                            geoWidth: geo.size.width,
                            geoHeight: height,
                            minY: minY
                        )
                    }
                    

                }
                .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0.0),
                                .init(color: .black, location: 0.75),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Liquid Glass blur for text readability (instead of harsh black)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black.opacity(0.5), location: 0.5),
                                .init(color: .black, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 380)
                    .offset(y: 30)
                    .allowsHitTesting(false)
                
                // Final pure black fade only at the very bottom to merge seamlessly with the app background
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.1), location: 0.7),
                        .init(color: .black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 250)
                .offset(y: 30)
                .allowsHitTesting(false)

                VStack(alignment: .center, spacing: 8) {
                    if let logoPath = detail.logoPath, let url = Config.tmdbImageURL(path: logoPath, size: "w500") {
                        CachedImage(url: url, contentMode: .fit) {
                            Color.clear.frame(height: 100)
                        }
                        .frame(maxHeight: 100)
                        .padding(.bottom, 4)
                    } else {
                        Text(detail.title)
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }

                    if let tagline = detail.tagline, !tagline.isEmpty {
                        HStack(alignment: .top, spacing: 4) {
                            Text("\u{201C}\(tagline)\u{201D}")
                                .font(.system(size: 15, weight: .light, design: .serif))
                                .italic()
                                .foregroundStyle(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                        .padding(.horizontal, 12)
                    }
                    
                    metadataRow(detail)
                        .padding(.top, 4)
                }
                .shadow(color: .black.opacity(0.8), radius: 6, x: 0, y: 3)
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 24)
            }
            .frame(width: geo.size.width, height: height)
            .offset(y: offset)
            .onChange(of: minY) { newY in
                if heroMinY != newY {
                    heroMinY = newY
                }
            }
            .onAppear {
                heroMinY = minY
            }
        }
        .frame(height: screenWidth * 1.4)
    }

    private func metadataRow(_ detail: MediaDetailInfo) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                HeroMetadataCapsule(text: detail.mediaType == .tv ? "Series" : "Movie")
                
                if !detail.year.isEmpty {
                    HeroMetadataCapsule(text: detail.year)
                }
                
                if let runtime = detail.runtimeLabel, !runtime.isEmpty {
                    HeroMetadataCapsule(text: runtime)
                }
                
                if let cert = detail.certification, !cert.isEmpty {
                    HeroMetadataCapsule(text: cert)
                }
                
                if (viewModel.pmdbAverageRating ?? 0) > 0 || detail.voteAverage > 0 {
                    HeroMetadataRatingCapsule(voteAverage: detail.voteAverage, pmdbRating: viewModel.pmdbAverageRating)
                }
            }
            .frame(minWidth: screenWidth - (horizontalPadding * 2))
        }
    }

    private func tagsRow(_ detail: MediaDetailInfo) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Vote count
                if viewModel.totalCommunityVotes > 0 {
                    Text("\(viewModel.totalCommunityVotes.formatted()) VOTES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 8))
                }
                
                // Genres
                ForEach(detail.genres, id: \.self) { genre in
                    Text(genre.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(minWidth: screenWidth - (horizontalPadding * 2))
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 8)
        }
    }

    // MARK: - Actions

    private func actionButtons(_ detail: MediaDetailInfo) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    Task { @MainActor in
                        await generateShareImage(detail: detail)
                    }
                } label: {
                    DetailActionLabel(title: "SHARE", symbol: "square.and.arrow.up", style: .primary)
                }

                Button { viewModel.showListPicker = true } label: {
                    if viewModel.isInList {
                        DetailActionLabel(title: "IN A LIST", symbol: "heart.fill", style: .progress(fraction: 1.0))
                    } else {
                        DetailActionLabel(title: "ADD TO LIST", symbol: "heart", style: .dark)
                    }
                }
            }

            watchedButton(detail: detail)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    /// Movies: any watch entry present.
    /// TV shows: every non-special episode is watched
    ///   (watchedEpisodePairCount >= totalEpisodeCount, both > 0).
    private var isWatched: Bool {
        guard let detail = viewModel.detail else { return false }
        if detail.mediaType == .movie {
            return viewModel.watchedEpisodeKeys.contains("movie")
        } else {
            let total = viewModel.totalEpisodeCount
            guard total > 0 else { return false }
            return viewModel.watchedEpisodePairCount >= total
        }
    }

    private func watchedButton(detail: MediaDetailInfo) -> some View {
        Button {
            Task { await handleWatchedButtonTap(detail: detail) }
        } label: {
            Group {
                if isMarkingWatched {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if isWatched {
                    DetailActionLabel(title: "WATCHED", symbol: "eye.fill", style: .primary)
                } else if detail.mediaType == .movie, let resumePoint = viewModel.resumePoint, resumePoint.progressFraction > 0 {
                    let progress = resumePoint.progressFraction
                    DetailActionLabel(title: "MARK WATCHED (\(Int(round(progress * 100)))%)", symbol: "eye", style: .progress(fraction: progress))
                } else if detail.mediaType == .tv, !viewModel.watchedEpisodeKeys.isEmpty {
                    let totalEpisodes = detail.seasons.filter { $0.seasonNumber > 0 }.reduce(0) { $0 + $1.episodeCount }
                    let watchedEpisodes = viewModel.watchedEpisodeKeys.filter { !$0.hasPrefix("0-") && $0 != "movie" }.count
                    
                    if totalEpisodes > 0 && watchedEpisodes > 0 {
                        let progress = min(1.0, Double(watchedEpisodes) / Double(totalEpisodes))
                        DetailActionLabel(title: "MARK WATCHED (\(Int(round(progress * 100)))%)", symbol: "eye", style: .progress(fraction: progress))
                    } else {
                        DetailActionLabel(title: "MARK WATCHED", symbol: "eye", style: .dark)
                    }
                } else {
                    DetailActionLabel(title: "MARK WATCHED", symbol: "eye", style: .dark)
                }
            }
        }
        .disabled(isMarkingWatched)
    }

    private func handleWatchedButtonTap(detail: MediaDetailInfo) async {

        guard Config.isAPIKeyConfigured else {
            viewModel.errorMessage = "Please log in to continue"
            return
        }

        if isWatched {
            if detail.mediaType == .movie {
                showMovieUnwatchOptions = true
            } else {
                showMarkAllUnwatchedAlert = true
            }
            return
        }

        if detail.mediaType == .movie {
            showMovieWatchOptions = true
        } else {
            showMarkAllWatchedAlert = true
        }
    }

    private func confirmMarkAllTVWatched() async {
        guard Config.isAPIKeyConfigured else {
            viewModel.errorMessage = "Please log in to continue"
            return
        }

        isMarkingWatched = true
        defer { isMarkingWatched = false }

        do {
            try await viewModel.markAllTVEpisodesWatched()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func confirmMarkAllTVUnwatched() async {
        guard Config.isAPIKeyConfigured else {
            viewModel.errorMessage = "Please log in to continue"
            return
        }

        isMarkingWatched = true
        defer { isMarkingWatched = false }

        do {
            try await viewModel.unmarkShowWatched()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func confirmMarkMovieWatched() async {
        isMarkingWatched = true
        defer { isMarkingWatched = false }
        do {
            try await viewModel.markMovieWatched()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func confirmMarkMovieUnwatched() async {
        isMarkingWatched = true
        defer { isMarkingWatched = false }
        do {
            try await viewModel.unmarkShowWatched()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Overview

    private func overviewSection(_ detail: MediaDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderLabel(symbol: "doc.text.fill", title: "Overview", hasBackground: false)
                .padding(.horizontal, horizontalPadding)
                ZStack(alignment: .bottom) {
                    Text(detail.overview.isEmpty ? "No overview available." : detail.overview)
                        .font(.body)
                        .foregroundStyle(GlassTheme.secondaryText)
                        .lineSpacing(6)
                        .lineLimit(isOverviewExpanded ? nil : 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !isOverviewExpanded && !detail.overview.isEmpty {
                        LinearGradient(
                            colors: [.clear, Color(white: 0.1).opacity(0.8), Color(white: 0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)
                    }
                }
                
                if !detail.overview.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isOverviewExpanded.toggle()
                        }
                    }) {
                        Text(isOverviewExpanded ? "Show Less" : "Read More")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: 0.1).opacity(0.6))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 16)
    }

    private var communityRatingsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {

            if viewModel.dedupedCommunityRatings.isEmpty {
                Text("No community ratings yet.")
                    .font(.caption)
                    .foregroundStyle(GlassTheme.secondaryText)
                    .padding(.horizontal, horizontalPadding)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], alignment: .leading, spacing: 12) {
                    ForEach(viewModel.dedupedCommunityRatings, id: \.id) { rating in
                        communityRatingGridCard(rating)
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }

            // MARK: My Ratings
            if !viewModel.myRatings.isEmpty {
                myRatingsSection
            }

            // Add Rating Button
            Button {
                viewModel.editingCommunityRating = nil
                viewModel.showCommunityRatingSheet = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Submit New Rating")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var myRatingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            SectionHeaderLabel(symbol: "person.fill", title: "My Ratings")
                .opacity(0.85)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 8)

            VStack(spacing: 10) {
                ForEach(viewModel.myRatings) { rating in
                    myRatingRow(rating)
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
    }

    private func myRatingRow(_ rating: Rating) -> some View {
        let scoreColor: Color = rating.score >= 80 ? .green : (rating.score >= 60 ? .yellow : (rating.score >= 40 ? .orange : .red))
        let displayLabel = rating.label?.isEmpty == false ? rating.label! : "Overall"

        return HStack(spacing: 16) {
            // Score badge
            ZStack {
                Circle()
                    .fill(scoreColor.opacity(0.18))
                    .frame(width: 52, height: 52)
                Circle()
                    .strokeBorder(scoreColor.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 52, height: 52)
                VStack(spacing: 0) {
                    Text(convertedScoreText(rating.score, label: rating.label ?? ""))
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(scoreColor)
                    Text(denominatorText(rating.label ?? ""))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(scoreColor.opacity(0.7))
                }
            }

            // Label
            VStack(alignment: .leading, spacing: 2) {
                Text(displayLabel)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                if let date = rating.createdAt {
                    Text(friendlyDate(date))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            Spacer()

            // Edit + Delete buttons
            HStack(spacing: 4) {
                Button {
                    viewModel.editingCommunityRating = viewModel.dedupedCommunityRatings.first(where: {
                        $0.id.lowercased() == (rating.label ?? "overall").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    })
                    viewModel.showCommunityRatingSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    Task { await viewModel.deleteMyRating(id: rating.id) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.75))
                        .frame(width: 34, height: 34)
                        .background(.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [scoreColor.opacity(0.12), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(scoreColor.opacity(0.25), lineWidth: 1)
            }
        }
    }

    private func friendlyDate(_ dateStr: String) -> String {
        let prefix = String(dateStr.prefix(10))
        let parts = prefix.split(separator: "-")
        guard parts.count == 3,
              let year = parts.first.map(String.init),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return prefix }
        let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        let monthStr = month >= 1 && month <= 12 ? months[month-1] : "\(month)"
        return "\(day) \(monthStr) \(year)"
    }

    /// Converts a 0-100 score to the native scale of the given label if convertRatings is enabled.
    private func convertedScoreText(_ score: Int, label: String) -> String {
        convertedScoreTextFn(score, label: label)
    }

    private func denominatorText(_ label: String) -> String {
        denominatorTextFn(label)
    }

    private func communityRatingGridCard(_ rating: CommunityRatingSummary) -> some View {
        let scoreColor: Color = rating.averageScore >= 80 ? .green : (rating.averageScore >= 60 ? .yellow : (rating.averageScore >= 40 ? .orange : .red))
        let knownLogos = ["IM", "RT", "MC", "LB", "PC", "TM", "TR", "AN", "ML", "RE"]
        let hasLogo = knownLogos.contains(rating.shortLabel)
        
        let tintColors: [Color]? = {
            if !hasLogo { return nil }
            switch rating.shortLabel {
            case "IM": return [Color(red: 245/255, green: 197/255, blue: 24/255)] // Official IMDb Yellow
            case "RE": return [Color(red: 0.83, green: 0.68, blue: 0.21)] // Distinct deeper gold
            case "TR": return [.purple]
            case "AN": return [Color(red: 0.0, green: 0.4, blue: 0.8)] // Darker blue
            case "LB": return [
                Color(red: 1.0, green: 0.5, blue: 0.0),   // Official LB Orange
                Color(red: 1.0, green: 0.5, blue: 0.0),   // Orange block
                Color(red: 0.0, green: 0.88, blue: 0.33), // Official LB Green
                Color(red: 0.0, green: 0.88, blue: 0.33), // Green block
                Color(red: 0.25, green: 0.74, blue: 0.96),// Official LB Blue
                Color(red: 0.25, green: 0.74, blue: 0.96) // Blue block
            ]
            case "RT": return [Color(red: 250/255, green: 50/255, blue: 10/255)] // Official RT Tomato Red
            case "PC": return [.red, .red, .yellow, .yellow] // Balance to 50/50 mix
            case "MC": return [.yellow, .black] // Mix yellow and black
            case "TM": return [.teal]
            case "ML": return [Color(red: 0.2, green: 0.5, blue: 1.0)] // Brighter, saturated royal blue for glow
            default: return nil
            }
        }()
        
        return Button {
            viewModel.editingCommunityRating = rating
            viewModel.showCommunityRatingSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    if hasLogo {
                        let scale: CGFloat = {
                            switch rating.shortLabel {
                            case "TR": return 2.4
                            case "LB": return 1.8
                            case "MC": return 1.6
                            case "RE": return 1.5
                            case "AN": return 1.4
                            case "ML": return 1.2
                            default: return 1.0
                            }
                        }()
                        
                        let needsGlow = rating.shortLabel == "MC"
                        let glowOpacity = 0.25
                        
                        let xOffset: CGFloat = {
                            switch rating.shortLabel {
                            case "PC": return 10
                            case "LB": return -6
                            case "TR": return -10
                            default: return 0
                            }
                        }()
                        
                        let yOffset: CGFloat = {
                            switch rating.shortLabel {
                            case "PC": return -2
                            default: return 0
                            }
                        }()
                        
                        Image("logo_\(rating.shortLabel)")
                            .resizable()
                            .scaledToFit()
                            .shadow(color: needsGlow ? .white.opacity(glowOpacity) : .clear, radius: 1)
                            .scaleEffect(scale, anchor: .leading)
                            .offset(x: xOffset, y: yOffset)
                            .frame(maxWidth: 80, maxHeight: 28, alignment: .leading)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.gray)
                                .font(.caption2)
                            Text(rating.shortLabel)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer(minLength: 8)
                    
                    HStack(spacing: 2) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("\(rating.voteCount)")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.gray)
                    .padding(.top, 4)
                }
                .frame(height: 28) // Force all top rows to have the exact same height
                
                HStack(alignment: .lastTextBaseline) {
                    Text(convertedScoreText(rating.averageScore, label: rating.shortLabel))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(scoreColor)
                    Text(denominatorText(rating.shortLabel))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.gray)
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        let filledBars = min(5, max(1, Int(Double(rating.averageScore) / 20.0)))
                        ForEach(0..<5) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(i < filledBars ? scoreColor : Color.gray.opacity(0.3))
                                .frame(width: 3, height: CGFloat(6 + i * 2))
                        }
                    }
                    .offset(y: -4)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    if let tints = tintColors {
                        let gradientOpacity = rating.shortLabel == "AN" ? 0.15 : 0.30
                        let gradientColors = tints.map { $0.opacity(gradientOpacity) } + [Color.clear]
                        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(tintColors?.first?.opacity(0.3) ?? Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Episodes

    private func episodesSection(_ detail: MediaDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Picker("Season", selection: $viewModel.selectedSeason) {
                    ForEach(detail.seasons) { season in
                        Text(season.seasonNumber == 0 ? "Specials" : "Season \(season.seasonNumber)").tag(season.seasonNumber)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                
                Spacer()
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 34)

            if viewModel.isLoadingEpisodes {
                ProgressView("Loading Episodes...")
                    .tint(.white)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(Array(viewModel.episodes.enumerated()), id: \.element.id) { index, episode in
                                let episodeKey = "\(route.tmdbId)-s\(viewModel.selectedSeason)-e\(episode.episodeNumber)"
                                let progress: Double = {
                                    if let resumePoint = viewModel.resumePoint,
                                       resumePoint.season == viewModel.selectedSeason,
                                       resumePoint.episode == episode.episodeNumber {
                                        return resumePoint.progressFraction
                                    }
                                    return 0.0
                                }()
                                VStack(alignment: .leading, spacing: 6) {
                                    EpisodeThumbCard(
                                        episode: episode,
                                        isWatched: viewModel.watchedEpisodeKeys.contains(episodeKey),
                                        progress: progress,
                                        onToggle: {
                                            viewModel.toggleWatched(episode: episode.episodeNumber)
                                        }
                                    )
                                    .contextMenu {
                                        if !viewModel.watchedEpisodeKeys.contains(episodeKey) {
                                            Button {
                                                viewModel.toggleWatched(episode: episode.episodeNumber)
                                            } label: {
                                                Label("Mark Watched", systemImage: "checkmark.circle")
                                            }
                                        } else {
                                            Button {
                                                viewModel.markEpisodeRewatched(episode: episode.episodeNumber)
                                            } label: {
                                                Label("Mark Rewatched", systemImage: "checkmark.circle")
                                            }
                                        }
                                        
                                        if !viewModel.isCurrentSeasonFullyWatched() {
                                            Button {
                                                Task { await viewModel.markSeasonWatched() }
                                            } label: {
                                                Label("Mark Season Watched", systemImage: "checkmark.circle.fill")
                                            }
                                        }
                                        
                                        if (episode.episodeNumber > 1 || viewModel.selectedSeason > 1) && viewModel.hasUnwatchedPreviousEpisodes(upTo: episode.episodeNumber) {
                                            Button {
                                                Task { await viewModel.markPreviousWatched(upTo: episode.episodeNumber) }
                                            } label: {
                                                Label("Mark Previous Watched", systemImage: "backward.end.circle")
                                            }
                                        }
                                        
                                        if viewModel.watchedEpisodeKeys.contains(episodeKey) && progress == 0 {
                                            Button(role: .destructive) {
                                                viewModel.toggleWatched(episode: episode.episodeNumber)
                                            } label: {
                                                Label("Mark Unwatched", systemImage: "arrow.counterclockwise.circle")
                                            }
                                            .tint(.red)
                                            .foregroundStyle(.red)
                                        }
                                        
                                        if !viewModel.isCurrentSeasonFullyUnwatched() {
                                            Button(role: .destructive) {
                                                Task { await viewModel.markSeasonUnwatched() }
                                            } label: {
                                                Label("Mark Season Unwatched", systemImage: "arrow.counterclockwise.circle.fill")
                                            }
                                            .tint(.red)
                                            .foregroundStyle(.red)
                                        }
                                        
                                        if (episode.episodeNumber > 1 || viewModel.selectedSeason > 1) && viewModel.hasWatchedPreviousEpisodes(upTo: episode.episodeNumber) {
                                            Button(role: .destructive) {
                                                Task { await viewModel.markPreviousUnwatched(upTo: episode.episodeNumber) }
                                            } label: {
                                                Label("Mark Previous Unwatched", systemImage: "backward.end.circle.fill")
                                            }
                                            .tint(.red)
                                            .foregroundStyle(.red)
                                        }
                                        
                                        if progress > 0 {
                                            Button(role: .destructive) {
                                                Task { await viewModel.removeWatchProgress() }
                                            } label: {
                                                Label("Remove Watch Progress", systemImage: "xmark.circle")
                                            }
                                            .tint(.red)
                                            .foregroundStyle(.red)
                                        }
                                        
                                        Divider()
                                        
                                        Button {
                                            managePlaysEpisode = episode.episodeNumber
                                        } label: {
                                            Label("Manage Plays", systemImage: "calendar")
                                        }
                                    }
                                    
                                    ZStack(alignment: .topLeading) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(" \n ")
                                                .font(.caption)
                                                .lineLimit(2, reservesSpace: true)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            
                                            HStack(alignment: .top) {
                                                Text("Date")
                                                Spacer()
                                                Text("Time")
                                            }
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        }
                                        .opacity(0)
                                        .accessibilityHidden(true)
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            if let overview = episode.overview, !overview.isEmpty {
                                                Button(action: {
                                                    selectedSynopsisEpisode = episode
                                                }) {
                                                    Text(overview)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(2)
                                                        .multilineTextAlignment(.leading)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            
                                            HStack(alignment: .top) {
                                                if let airDate = episode.airDate {
                                                    Text(airDate)
                                                }
                                                Spacer()
                                                Text(episode.runtimeLabel)
                                            }
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .frame(width: 260)
                                .id(episode.episodeNumber)
                                .padding(.leading, index == 0 ? horizontalPadding : 12)
                                .padding(.trailing, index == viewModel.episodes.count - 1 ? horizontalPadding : 0)
                                .onAppear {
                                    if episode.episodeNumber == viewModel.targetScrollEpisode {
                                        Task {
                                            for delay in [100, 300, 600] {
                                                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000))
                                                await MainActor.run {
                                                    withAnimation(.easeInOut(duration: 0.5)) {
                                                        proxy.scrollTo(episode.episodeNumber, anchor: .leading)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: viewModel.targetScrollEpisode) {
                        if let target = viewModel.targetScrollEpisode {
                            Task {
                                try? await Task.sleep(nanoseconds: 100_000_000)
                                await MainActor.run {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        proxy.scrollTo(target, anchor: .leading)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }



    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("You Might Also Like", symbol: "sparkles")
                .padding(.top, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.recommendations) { item in
                        MediaDetailLink(route: MediaDetailRoute(item: item)) {
                                DiscoverPosterCell(
                                    item: item,
                                    pmdbRating: viewModel.pmdbRatings[item.tmdbId],
                                    logoURL: viewModel.itemLogos[item.tmdbId],
                                    cleanPosterURL: viewModel.cleanPosters[item.tmdbId],
                                    badgeText: BadgeEngine.getTag(for: item),
                                    hideDefaultContextMenu: true,
                                    customWidth: 140
                                )
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }
        }
    }

    // MARK: - Community

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(visibleTabs) { tab in
                        let currentTab = animatedTab ?? viewModel.selectedCommunityTab
                        let selected = currentTab == tab
                        Button {
                            // 1. Animate the tab pill instantly
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                animatedTab = tab
                            }
                            // 2. Swap the heavy grid on the next run loop to prevent dropping the first frame
                            DispatchQueue.main.async {
                                viewModel.selectedCommunityTab = tab
                                if tab == .seasonMappings {
                                    Task { await viewModel.loadSeasonMappings() }
                                }
                            }
                        } label: {
                            Label(tab.rawValue, systemImage: tab.icon)
                                .font(.subheadline.weight(selected ? .bold : .semibold))
                                .foregroundStyle(selected ? .black : .gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background {
                                    if selected {
                                        Capsule()
                                            .fill(.white)
                                            .matchedGeometryEffect(id: "CommunityTab", in: tabNamespace)
                                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(white: 0.1).opacity(0.6))
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 36)
            .padding(.bottom, 12)

            communityContent
                .animation(nil, value: viewModel.selectedCommunityTab)
        }
    }

    private var visibleTabs: [CommunityDataTab] {
        CommunityDataTab.allCases.filter { tab in
            if tab == .episodeRatings { return route.mediaType == .tv }
            if tab == .seasonMappings { return route.mediaType == .tv && viewModel.isAnime }
            return true
        }
    }

    @ViewBuilder
    private var communityContent: some View {
        switch viewModel.selectedCommunityTab {
        case .ratings:
            communityRatingsGrid
        case .episodeRatings:
            episodeRatingsList
        case .skips:
            skipsList
        case .seasonMappings:
            seasonMappingsList
        case .highlights:
            highlightsList
        case .externalIDs:
            externalIDsList
        }
    }

    private let episodeRatingColumns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)

    private var episodeRatingsList: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Floating Glass Pills Header
            let stats = episodeRatingsStats
            VStack(spacing: 12) {
                let avg = stats.averageScore
                let avgColor: Color = {
                    if avg == 0 { return .cyan }
                    if avg >= 80 { return .green }
                    if avg >= 60 { return .yellow }
                    if avg >= 40 { return .orange }
                    return .red
                }()
                
                HStack(spacing: 12) {
                    glassStatPill(title: "RATINGS", value: "\(stats.totalRatings)", symbol: "star.fill", color: avgColor)
                    glassStatPill(title: "LABELS", value: "\(stats.uniqueLabels)", symbol: "tag.fill", color: avgColor)
                }
                
                let total = max(1, viewModel.episodes.count)
                glassProgressBar(
                    title: "EPISODES RATED",
                    value: "\(stats.episodesRated) EPS",
                    color: avgColor,
                    progress: CGFloat(stats.episodesRated) / CGFloat(total)
                )
            }
            .padding(.horizontal, horizontalPadding)
            
            if episodeRatingEpisodeNumbers.isEmpty {
                communityEmptyRow("No episode ratings for this season.")
            } else {
                LazyVGrid(columns: episodeRatingColumns, spacing: 14) {
                    ForEach(episodeRatingEpisodeNumbers, id: \.self) { episodeNumber in
                        Button {
                            selectedRatingEpisode = episodeNumber
                        } label: {
                            EpisodeRatingCell(
                                episodeNumber: episodeNumber,
                                summary: viewModel.episodeRatingSummaries[episodeNumber]
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 4)
    }

    private var episodeRatingEpisodeNumbers: [Int] {
        let fromEpisodes = viewModel.episodes.map(\.episodeNumber)
        let validEpisodeNumbers = Set(fromEpisodes)
        
        if !validEpisodeNumbers.isEmpty {
            return fromEpisodes.sorted()
        }
        
        return Array(viewModel.episodeRatingSummaries.keys).sorted()
    }

    private var episodeRatingsStats: (totalRatings: Int, episodesRated: Int, uniqueLabels: Int, averageScore: Int) {
        let maxEpisodes = viewModel.detail?.seasons.first(where: { $0.seasonNumber == viewModel.selectedSeason })?.episodeCount ?? 10000
        
        var totalRatings = 0
        var episodesRated = 0
        var uniqueLabels = Set<String>()
        var totalScoreSum: Double = 0
        
        for (ep, epsRatings) in viewModel.seasonEpisodeRatings {
            if ep <= maxEpisodes && !epsRatings.isEmpty {
                episodesRated += 1
                totalRatings += epsRatings.count
                for r in epsRatings {
                    uniqueLabels.insert((r.label ?? "overall").lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
                    totalScoreSum += Double(r.score)
                }
            }
        }
        
        if totalRatings == 0 && !viewModel.episodeRatingSummaries.isEmpty {
            for (ep, summary) in viewModel.episodeRatingSummaries {
                if ep <= maxEpisodes {
                    episodesRated += 1
                    totalRatings += summary.total
                    totalScoreSum += summary.average * Double(summary.total)
                }
            }
            uniqueLabels.insert("overall")
        }
        
        let avgScore = totalRatings > 0 ? Int(round(totalScoreSum / Double(totalRatings))) : 0
        return (totalRatings, episodesRated, uniqueLabels.count, avgScore)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
    
    private func statBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.gray)
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private func glassStatPill(title: String, value: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color.gradient)
                    .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 0)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: value)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(title)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(color.opacity(0.9))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .background(
            LinearGradient(colors: [color.opacity(0.6), color.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: Capsule()
        )
        .overlay(Capsule().strokeBorder(color.opacity(0.6), lineWidth: 1))
        .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 0)
    }

    @ViewBuilder
    private var skipsList: some View {
        if viewModel.route.mediaType == .movie {
            movieSkipsList
        } else {
            tvSkipsList
        }
    }

    // MARK: - Season Mappings List

    private var seasonMappingsList: some View {
        VStack(spacing: 24) {
            if viewModel.seasonMappings.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "square.3.layers.3d")
                        .font(.system(size: 48))
                        .foregroundStyle(.gray.opacity(0.5))
                    
                    Text("No season mappings yet")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    
                    Text("Be the first to map this anime to TMDB!")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                .padding(.horizontal, horizontalPadding)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.seasonMappings) { mapping in
                        SeasonMappingCard(
                            mapping: mapping,
                            onVote: { vote in
                                Task { await viewModel.voteOnSeasonMapping(mapping: mapping, vote: vote) }
                            },
                            onEdit: {
                                viewModel.editingSeasonMapping = mapping
                                viewModel.showSeasonMappingSheet = true
                            },
                            onDelete: {
                                Task {
                                    // Make sure you have deleteAnimeSeasonMapping added to the viewModel
                                    await viewModel.deleteAnimeSeasonMapping(tmdbId: mapping.tmdbId ?? viewModel.route.tmdbId, seasonNumber: mapping.seasonNumber)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }
            
            Button {
                viewModel.showSeasonMappingSheet = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Add Mapping")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .padding(.horizontal, horizontalPadding)
        }
        .padding(.top, 4)
    }

    private func glassProgressBar(title: String, value: String, color: Color, progress: CGFloat) -> some View {
        let hasData = progress > 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.white.opacity(0.08))
                
                // Filled Track
                if hasData {
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: max(0, geo.size.width * progress))
                        .shadow(color: color.opacity(0.4), radius: 6, x: 0, y: 0)
                }
                
                // Text Overlay
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(hasData ? .white : color.opacity(0.8))
                        .shadow(color: hasData ? .black.opacity(0.3) : .clear, radius: 2, x: 0, y: 1)
                    Spacer()
                    if hasData {
                        Text(verbatim: value)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    } else {
                        Text(verbatim: value)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 18)
            }
            .clipShape(Capsule())
        }
        .frame(height: 48)
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
    }

    private var movieSkipsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            let hasIntro = viewModel.skips.contains(where: { $0.introStartMs != nil })
            let hasOutro = viewModel.skips.contains(where: { $0.creditsStartMs != nil })
            
            let introColor = Color(red: 0, green: 0.9, blue: 0.55)
            let outroColor = Color(red: 0.66, green: 0.33, blue: 0.97)
            
            HStack(spacing: 12) {
                glassProgressBar(
                    title: "INTRO",
                    value: "✓",
                    color: introColor,
                    progress: hasIntro ? 1.0 : 0.0
                )
                
                glassProgressBar(
                    title: "CREDITS",
                    value: "✓",
                    color: outroColor,
                    progress: hasOutro ? 1.0 : 0.0
                )
            }
            .padding(.horizontal, horizontalPadding)
            
            Button {
                viewModel.selectedSkipEpisode = nil
                viewModel.showSkipSheet = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text((hasIntro || hasOutro) ? "View / Submit Skip Times" : "Submit Skip Times")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .padding(.horizontal, horizontalPadding)
        }
        .padding(.top, 4)
    }

    private let skipsColumns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)

    private var tvSkipsList: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            let introEpisodes = Set(viewModel.skips.compactMap { $0.introStartMs != nil ? $0.episode : nil })
            let outroEpisodes = Set(viewModel.skips.compactMap { $0.creditsStartMs != nil ? $0.episode : nil })
            
            // Progress Bars
            HStack(spacing: 12) {
                let introCount = skipsEpisodeNumbers.filter { introEpisodes.contains($0) }.count
                let outroCount = skipsEpisodeNumbers.filter { outroEpisodes.contains($0) }.count
                let total = max(1, viewModel.episodes.count)
                
                let introColor = Color(red: 0, green: 0.9, blue: 0.55)
                let outroColor = Color(red: 0.66, green: 0.33, blue: 0.97)
                
                glassProgressBar(
                    title: "INTRO",
                    value: "\(introCount) EPS",
                    color: introColor,
                    progress: CGFloat(introCount) / CGFloat(total)
                )
                
                glassProgressBar(
                    title: "OUTRO",
                    value: "\(outroCount) EPS",
                    color: outroColor,
                    progress: CGFloat(outroCount) / CGFloat(total)
                )
            }
            .padding(.horizontal, horizontalPadding)
            
            if skipsEpisodeNumbers.isEmpty {
                communityEmptyRow("No skip data for this season.")
            } else {
                LazyVGrid(columns: skipsColumns, spacing: 14) {
                    ForEach(skipsEpisodeNumbers, id: \.self) { episodeNumber in
                        Button {
                            if let ep = viewModel.episodes.first(where: { $0.episodeNumber == episodeNumber }) {
                                viewModel.selectedSkipEpisode = ep
                            } else {
                                viewModel.selectedSkipEpisode = EpisodeDisplay(
                                    episodeNumber: episodeNumber, name: "Episode \(episodeNumber)",
                                    overview: nil, stillPath: nil, runtimeMinutes: nil, airDate: nil
                                )
                            }
                            viewModel.showSkipSheet = true
                        } label: {
                            SkipCell(
                                episodeNumber: episodeNumber,
                                hasIntro: introEpisodes.contains(episodeNumber),
                                hasOutro: outroEpisodes.contains(episodeNumber)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 4)
    }

    private var skipsEpisodeNumbers: [Int] {
        let fromEpisodes = viewModel.episodes.map(\.episodeNumber)
        let validEpisodeNumbers = Set(fromEpisodes)
        
        if !validEpisodeNumbers.isEmpty {
            return fromEpisodes.sorted()
        }
        
        return Array(Set(viewModel.skips.compactMap(\.episode))).sorted()
    }

    @ViewBuilder
    private var highlightsList: some View {
        if viewModel.route.mediaType == .movie {
            movieHighlightsList
        } else {
            tvHighlightsList
        }
    }

    private var movieHighlightsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                glassStatPill(title: "HIGHLIGHTS", value: "\(viewModel.highlights.count)", symbol: "flag.fill", color: Color(red: 0.85, green: 0.1, blue: 0.3))
            }
            .padding(.horizontal, horizontalPadding)
            
            Button {
                viewModel.selectedHighlightEpisode = nil
                viewModel.showHighlightSheet = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text(viewModel.highlights.isEmpty ? "Submit Highlight" : "View / Submit Highlights")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .padding(.horizontal, horizontalPadding)
        }
        .padding(.top, 4)
    }

    private var tvHighlightsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stats Header
            HStack(spacing: 12) {
                let total = max(1, viewModel.episodes.count)
                let highlightedCount = viewModel.seasonEpisodeHighlights.count
                
                glassStatPill(title: "HIGHLIGHTS", value: "\(viewModel.highlights.count)", symbol: "flag.fill", color: Color(red: 0.85, green: 0.1, blue: 0.3))
                
                glassProgressBar(
                    title: "EPISODES",
                    value: "\(highlightedCount) EPS",
                    color: Color(red: 0.85, green: 0.1, blue: 0.3),
                    progress: CGFloat(highlightedCount) / CGFloat(total)
                )
            }
            .padding(.horizontal, horizontalPadding)
            
            if highlightEpisodeNumbers.isEmpty {
                communityEmptyRow("No highlights for this season.")
            } else {
                let highlightsColumns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)
                LazyVGrid(columns: highlightsColumns, spacing: 14) {
                    ForEach(highlightEpisodeNumbers, id: \.self) { episodeNumber in
                        Button {
                            viewModel.selectedHighlightEpisode = episodeNumber
                            viewModel.showHighlightSheet = true
                        } label: {
                            HighlightCell(
                                episodeNumber: episodeNumber,
                                highlightCount: viewModel.seasonEpisodeHighlights[episodeNumber]?.count ?? 0
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 4)
    }

    private var highlightEpisodeNumbers: [Int] {
        let fromEpisodes = viewModel.episodes.map(\.episodeNumber)
        let validEpisodeNumbers = Set(fromEpisodes)
        
        if !validEpisodeNumbers.isEmpty {
            return fromEpisodes.sorted()
        }
        
        return Array(viewModel.seasonEpisodeHighlights.keys).sorted()
    }

    private var externalIDsList: some View {
        VStack(spacing: 16) {
            // TMDB Static Top Block
            ExternalIDPlatformGroup(
                title: "TMDB",
                items: [
                    ExternalMapping(id: "tmdb", tmdbId: route.tmdbId, mediaType: route.mediaType, idType: .tmdb, idValue: "\(route.tmdbId)", contributor: nil, userVote: nil, voteCount: nil, isOwner: nil, created: nil, tmdbSeason: nil)
                ],
                isTMDB: true,
                viewModel: viewModel
            )
            
            let dynamicMappings = viewModel.mappings.filter { 
                $0.idType != .tmdb && $0.idType != .anidb && $0.tmdbSeason == nil && $0.mediaType == route.mediaType
            }
            let orderedTypes = dynamicMappings.reduce(into: [ExternalIDType]()) { result, mapping in
                if !result.contains(mapping.idType) {
                    result.append(mapping.idType)
                }
            }.sorted { $0.displayLabel.uppercased() < $1.displayLabel.uppercased() }
            
            ForEach(orderedTypes, id: \.self) { type in
                let itemsForType = dynamicMappings.filter { $0.idType == type }.sorted {
                    let v1 = $0.voteCount ?? 0
                    let v2 = $1.voteCount ?? 0
                    if v1 != v2 {
                        return v1 > v2
                    }
                    let c1 = $0.created ?? ""
                    let c2 = $1.created ?? ""
                    if c1 != c2 {
                        return c1 > c2 // Newest First
                    }
                    return $0.id > $1.id // Fallback Newest First
                }
                if !itemsForType.isEmpty {
                    ExternalIDPlatformGroup(
                        title: type.displayLabel.uppercased(),
                        items: itemsForType,
                        isTMDB: false,
                        viewModel: viewModel
                    )
                }
            }
            
            // Add ID Button
            Button {
                viewModel.showExternalIDSheet = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Add External ID")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
        }
        .padding(.horizontal, horizontalPadding)
    }

    // MARK: - Chrome

    private func sectionTitle(_ text: String, symbol: String) -> some View {
        SectionHeaderLabel(symbol: symbol, title: text)
            .padding(.horizontal, horizontalPadding)
    }

    private func communityEmptyRow(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
    }

    @ViewBuilder
    private var actionToast: some View {
        if let message = viewModel.actionMessage {
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
                .padding(.bottom, 16)
                .onAppear {
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        viewModel.actionMessage = nil
                    }
                }
        }
    }

    private var listPickerSheet: some View {
        NavigationStack {
            List(viewModel.userLists) { list in
                HStack {
                    Text(list.name)
                        .foregroundStyle(.white)
                    Spacer()
                    
                    if let itemId = viewModel.containedListItems[list.id] {
                        Button {
                            Task { await viewModel.removeFromList(listId: list.id, itemId: itemId, listName: list.name) }
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .foregroundStyle(.red)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button("Add") {
                            Task { await viewModel.addToList(list) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.white.opacity(0.15))
                        .foregroundStyle(.white)
                        .font(.subheadline.bold())
                        .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Add to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { viewModel.showListPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var actionDialogs: some View {
        Color.clear
            .alert("Mark Entire Show as Watched?", isPresented: $showMarkAllWatchedAlert) {
                Button("Mark All Watched", role: .destructive) {
                    Task { await confirmMarkAllTVWatched() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will mark all episodes of every season as watched.")
            }
            .alert("Mark Entire Show as Unwatched?", isPresented: $showMarkAllUnwatchedAlert) {
                Button("Mark All Unwatched", role: .destructive) {
                    Task { await confirmMarkAllTVUnwatched() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all watched history for every episode of this show.")
            }
            .alert("Mark Movie Watched", isPresented: $showMovieWatchOptions) {
                Button {
                    Task { await confirmMarkMovieWatched() }
                } label: {
                    Text("Just Now").bold()
                }
                .keyboardShortcut(.defaultAction)
                Button("Log Custom Date") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showMovieManagePlaysSheet = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("How would you like to log this movie?")
            }
            .alert("Manage Movie", isPresented: $showMovieUnwatchOptions) {
                Button("Remove All Plays", role: .destructive) {
                    Task { await confirmMarkMovieUnwatched() }
                }
                Button("Manage Plays") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showMovieManagePlaysSheet = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have already watched this movie. What would you like to do?")
            }
    }
    private func fetchImage(url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    @MainActor
    private func generateShareImage(detail: MediaDetailInfo) async {
        isGeneratingShareImage = true
        defer { isGeneratingShareImage = false }
        
        // Calculate aired episodes (cap at totalEpisodeCount to avoid inflated numbers)
        let totalEps = viewModel.totalEpisodeCount
        let airedEpisodes: Int
        if detail.mediaType == .tv, let next = detail.nextEpisodeToAir {
            let priorSeasonsCount = detail.seasons
                .filter { $0.seasonNumber > 0 && $0.seasonNumber < next.seasonNumber }
                .reduce(0) { $0 + $1.episodeCount }
            let calculated = priorSeasonsCount + max(0, next.episodeNumber - 1)
            airedEpisodes = min(calculated, totalEps) // never exceed TMDB total
        } else {
            airedEpisodes = totalEps // show ended or no next ep info
        }
        let validWatched = min(viewModel.watchedEpisodePairCount, airedEpisodes)
        
        // Fetch images first to avoid black render
        var bgImage: UIImage?
        var logoImage: UIImage?
        var networkImage: UIImage?
        
        if let bgURL = Config.tmdbImageURL(path: detail.textlessPosterPath ?? detail.posterPath ?? detail.backdropPath, size: "original") {
            bgImage = await fetchImage(url: bgURL)
        }
        if let lURL = Config.tmdbImageURL(path: detail.logoPath, size: "w780") {
            logoImage = await fetchImage(url: lURL)
        }
        if let netURL = Config.tmdbImageURL(path: detail.networkItems.first?.logoPath, size: "w300") {
            networkImage = await fetchImage(url: netURL)
        }
        
        let data = ShareMediaData(
            title: detail.title,
            background: bgImage,
            logo: logoImage,
            network: networkImage,
            tagline: detail.tagline,
            displayRatingTitle: {
                if !viewModel.myRatings.isEmpty {
                    return "MY RATING"
                } else if !viewModel.dedupedCommunityRatings.isEmpty {
                    return "PMDB RATING"
                }
                return nil
            }(),
            displayRatingValue: {
                if !viewModel.myRatings.isEmpty {
                    let sum = viewModel.myRatings.reduce(0) { $0 + $1.score }
                    return Int(round(Double(sum) / Double(viewModel.myRatings.count)))
                }
                let scores = viewModel.dedupedCommunityRatings.map { $0.averageScore }
                if scores.isEmpty { return nil }
                let sum = scores.reduce(0, +)
                return Int(round(Double(sum) / Double(scores.count)))
            }(),
            mediaType: detail.mediaType,
            year: detail.year,
            runtime: detail.runtimeLabel,
            contentRating: detail.certification,
            genres: Array(detail.genres.prefix(3)),
            directorName: {
                if detail.mediaType == .movie {
                    return detail.credits
                        .first { $0.department == "Directing" }?
                        .members.first?.name
                } else {
                    return detail.credits
                        .first { $0.department == "Creator" || $0.department == "Writing" }?
                        .members.first?.name
                }
            }(),
            isDirector: detail.mediaType == .movie,
            showStatus: {
                let status = detail.status?.lowercased() ?? ""
                switch status {
                case "ended": return "ENDED"
                case "canceled", "cancelled": return "CANCELLED"
                case "returning series": return "RETURNING SERIES"
                case "in production": return "IN PRODUCTION"
                case "post production": return "POST PRODUCTION"
                case "rumored": return "RUMORED"
                case "planned": return "PLANNED"
                case "released": return "RELEASED"
                default: return nil
                }
            }(),
            appIconName: UIApplication.shared.alternateIconName,
            watchedCount: viewModel.watchHistoryItems.count,
            totalEpisodes: airedEpisodes,
            watchedEpisodes: validWatched,
            isEpisodeCountReliable: true
        )
        
        let renderer = ImageRenderer(content: ShareImageRenderView(data: data))
        renderer.scale = 1.0
        if let image = renderer.uiImage {
            self.shareImage = image
            self.showShareSheet = true
        }
    }
}

// MARK: - Components

private struct RecommendationPosterCard: View {
    let item: TMDBMediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let url = Config.tmdbImageURL(path: item.posterPath, size: "w342") {
                    CachedImage(url: url) {
                        ZStack {
                            Color(white: 0.15)
                            Image(systemName: item.mediaType == .movie ? "film" : (item.mediaType == .tv ? "tv" : "person.fill"))
                                .font(.system(size: 30))
                                .foregroundStyle(.gray.opacity(0.5))
                        }
                    }
                } else {
                    ZStack {
                        Color(white: 0.15)
                        Image(systemName: item.mediaType == .movie ? "film" : (item.mediaType == .tv ? "tv" : "person.fill"))
                            .font(.system(size: 30))
                            .foregroundStyle(.gray.opacity(0.5))
                    }
                }
            }
            .frame(width: 120)
            .aspectRatio(2 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(item.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(GlassTheme.primaryText)
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
        }
    }
}

struct HeroMetadataCapsule: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
    }
}

struct HeroMetadataRatingCapsule: View {
    let voteAverage: Double
    var pmdbRating: Int? = nil

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundStyle(.yellow)
            if let pmdb = pmdbRating, pmdb > 0 {
                Text("\(pmdb)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            } else {
                Text("\(Int(voteAverage * 10))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
    }
}

private enum DetailActionStyle: Equatable {
    case primary
    case glass
    case dark
    case progress(fraction: Double)
}

private struct DetailActionLabel: View {
    let title: String
    let symbol: String
    let style: DetailActionStyle
    
    @State private var animatedFraction: Double = 0.0

    var body: some View {
        Group {
            switch style {
            case .primary:
                labelContent
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.8), radius: 6, x: 0, y: 0)
                    .background {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.20))
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
                    .shadow(color: .white.opacity(0.15), radius: 8, x: 0, y: 0)
            case .dark:
                labelContent
                    .foregroundStyle(.white.opacity(0.8))
                    .background {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06))
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            case .glass:
                labelContent
                    .foregroundStyle(GlassTheme.primaryText)
                    .liquidGlass(cornerRadius: 12)
            case .progress(let _):
                ZStack {
                    labelContent
                        .foregroundStyle(.white.opacity(0.8))
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial)
                                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06))
                            }
                        }
                    
                    labelContent
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.8), radius: 6, x: 0, y: 0)
                        .background(
                            LinearGradient(
                                colors: [.white.opacity(0.15), .white.opacity(0.25)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .drawingGroup()
                        .mask(
                            Rectangle()
                                .scaleEffect(x: max(0, min(1, animatedFraction)), y: 1, anchor: .leading)
                        )
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .onAppear {
                    if case .progress(let targetFraction) = style {
                        if targetFraction >= 1.0 {
                            animatedFraction = targetFraction
                        } else {
                            animatedFraction = 0.0
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation(.spring(response: 1.2, dampingFraction: 0.85)) {
                                    animatedFraction = targetFraction
                                }
                            }
                        }
                    }
                }
                .onChange(of: style) { _, newStyle in
                    if case .progress(let targetFraction) = newStyle {
                        withAnimation(.spring(response: 1.2, dampingFraction: 0.85)) {
                            animatedFraction = targetFraction
                        }
                    }
                }
            }
        }
    }

    private var labelContent: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .frame(height: 24)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
    }
}

private struct EpisodeThumbCard: View {
    let episode: EpisodeDisplay
    let isWatched: Bool
    let progress: Double
    let onToggle: () -> Void
    
    @State private var animatedProgress: Double = 0.0

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let url = Config.posterURL(path: episode.stillPath) {
                    CachedImage(url: url) {
                        Rectangle().fill(Color.white.opacity(0.08))
                    }
                } else {
                    Rectangle().fill(Color.white.opacity(0.08))
                }
            }
            .aspectRatio(16/9, contentMode: .fill)
            .frame(width: 260, height: 146)
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
            
            VStack {
                HStack(alignment: .top) {
                    Text("E\(String(episode.episodeNumber))")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                    
                    Spacer()
                    
                    Button(action: onToggle) {
                        ZStack {
                            if isWatched {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Circle()
                                    .stroke(
                                        LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                                    )
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .frame(width: 30, height: 30)
                        .liquidGlass(cornerRadius: 15)
                        .shadow(radius: 2)
                        .frame(width: 44, height: 44) // Center visually in touch target
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .offset(x: 7, y: -10)
                }
                .padding(12)
                
                Spacer()
                
                VStack(spacing: 6) {
                    HStack {
                        Text(episode.name)
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
                            .lineLimit(2)
                        Spacer()
                    }
                    
                    if progress > 0 {
                        HStack(spacing: 6) {
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.3)).frame(height: 4)
                                Capsule().fill(Color.white).frame(height: 4)
                                    .mask(
                                        Rectangle()
                                            .scaleEffect(x: max(0.0, min(animatedProgress, 1.0)), y: 1, anchor: .leading)
                                    )
                            }
                            .frame(height: 4)
                            .onAppear {
                                animatedProgress = 0.0
                                withAnimation(.easeOut(duration: 0.8)) {
                                    animatedProgress = progress
                                }
                            }
                            .onChange(of: progress) { _, newProgress in
                                withAnimation(.easeOut(duration: 0.8)) {
                                    animatedProgress = newProgress
                                }
                            }
                            
                            Text("\(Int(round(progress * 100)))%")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(10)
            }
        }
        .frame(width: 260, height: 146)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        // Liquid Glass border
        .overlay(
            RoundedRectangle(cornerRadius: 14)
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
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                .padding(1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 10)
        )
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 14))
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct EpisodeRatingCell: View {
    let episodeNumber: Int
    let summary: EpisodeRatingSummary?
    @AppStorage("convertRatings") private var convertRatings = false

    var body: some View {
        let isRated = summary != nil
        let avg = summary?.average ?? 0
        let total = summary?.total ?? 0
        
        let glowColor: Color = {
            if !isRated { return .clear }
            if avg >= 80 { return Color.green }
            if avg >= 60 { return Color.yellow }
            if avg >= 40 { return Color.orange }
            return Color.red
        }()
        
        VStack(spacing: 8) {
            // Episode Number
            Text(String(episodeNumber))
                .font(.system(.title, design: .rounded, weight: .heavy))
                .foregroundStyle(isRated ? .white : GlassTheme.secondaryText)
            
            // Rating Badge or Placeholder
            if isRated {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                    let displayText = convertRatings ? String(format: "%.1f", avg / 10.0) : "\(Int(round(avg)))"
                    Text(displayText)
                        .font(.system(.caption, design: .rounded, weight: .black))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(glowColor, in: Capsule())
                
                Text("\(total) ratings")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                Capsule()
                    .fill(.white.opacity(0.05))
                    .frame(width: 30, height: 4)
                    .padding(.vertical, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    isRated 
                    ? AnyShapeStyle(LinearGradient(colors: [glowColor.opacity(0.6), glowColor.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.white.opacity(0.05))
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isRated ? glowColor.opacity(0.6) : .white.opacity(0.1), lineWidth: 1)
                .shadow(color: isRated ? glowColor.opacity(0.4) : .clear, radius: 4, x: 0, y: 0)
        )
    }
}

private struct SkipCell: View {
    let episodeNumber: Int
    let hasIntro: Bool
    let hasOutro: Bool

    var body: some View {
        let introColor = Color(red: 0, green: 0.9, blue: 0.55)
        let outroColor = Color(red: 0.66, green: 0.33, blue: 0.97)
        let hasData = hasIntro || hasOutro
        
        VStack(spacing: 8) {
            Text(String(episodeNumber))
                .font(.system(.title, design: .rounded, weight: .heavy))
                .foregroundStyle(hasData ? .white : GlassTheme.secondaryText)
            
            HStack(spacing: 4) {
                if hasIntro {
                    Text("INTRO")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(introColor)
                }
                if hasIntro && hasOutro {
                    Circle().fill(.white.opacity(0.3)).frame(width: 3, height: 3)
                }
                if hasOutro {
                    Text("OUTRO")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(outroColor)
                }
            }
            .frame(height: 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                
                if hasIntro {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [introColor.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                if hasOutro {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [.clear, outroColor.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            hasIntro ? introColor.opacity(0.6) : .white.opacity(0.15),
                            hasOutro ? outroColor.opacity(0.6) : .white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: hasData ? 1.5 : 0.5
                )
                .shadow(color: hasIntro ? introColor.opacity(0.3) : .clear, radius: 4, x: -2, y: -2)
                .shadow(color: hasOutro ? outroColor.opacity(0.3) : .clear, radius: 4, x: 2, y: 2)
        )
    }
}

private struct HighlightCell: View {
    let episodeNumber: Int
    let highlightCount: Int

    var body: some View {
        let hasHighlights = highlightCount > 0
        let highlightColor = Color.red
        
        VStack(spacing: 8) {
            Text(String(episodeNumber))
                .font(.system(.title, design: .rounded, weight: .heavy))
                .foregroundStyle(hasHighlights ? .white : GlassTheme.secondaryText)
            
            if hasHighlights {
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9))
                    Text("\(highlightCount)")
                        .font(.system(.caption, design: .rounded, weight: .black))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(highlightColor, in: Capsule())
            } else {
                Capsule()
                    .fill(.white.opacity(0.05))
                    .frame(width: 30, height: 4)
                    .padding(.vertical, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    hasHighlights 
                    ? AnyShapeStyle(LinearGradient(colors: [highlightColor.opacity(0.6), highlightColor.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.white.opacity(0.05))
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(hasHighlights ? highlightColor.opacity(0.6) : .white.opacity(0.1), lineWidth: 1)
                .shadow(color: hasHighlights ? highlightColor.opacity(0.4) : .clear, radius: 4, x: 0, y: 0)
        )
    }
}

struct EpisodeRatingSheet: View {
    @ObservedObject var viewModel: MediaDetailViewModel
    let episodeNumber: Int
    
    @State private var selectedTab = 0
    @State private var myRatingLabel: String = "overall"
    @State private var myRatingScore: Double = 50
    @State private var isSubmitting = false
    
    @Environment(\.dismiss) private var dismiss
    
    private var isAnime: Bool {
        guard let detail = viewModel.detail else { return false }
        let isAnimation = detail.genres.contains("Animation")
        let isEastAsian = detail.originCountry?.contains(where: { ["JP", "KR", "CN", "TW", "HK"].contains($0.uppercased()) }) ?? false
        return isAnimation && isEastAsian
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }
                
                VStack(spacing: 0) {
                    let total = viewModel.episodeRatingSummaries[episodeNumber]?.total ?? 0
                    GlassTabSelector(selection: $selectedTab, options: [0, 1]) { tab in
                        tab == 0 ? "All Ratings (\(total))" : "My Rating"
                    }
                    .padding()

                    if selectedTab == 0 {
                        allRatingsView
                    } else {
                        myRatingView
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowBackground(Color.clear)
            .navigationTitle("S\(viewModel.selectedSeason):E\(String(episodeNumber))")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
    
    private var allRatingsView: some View {
        ScrollView {
            let ratings = viewModel.seasonEpisodeRatings[episodeNumber] ?? []
            if ratings.isEmpty {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Image(systemName: "star")
                            .font(.system(size: 32))
                            .foregroundStyle(.gray)
                            .padding(.bottom, 8)
                        
                        Text("No ratings yet")
                            .font(.headline.bold())
                            .foregroundStyle(.gray)
                        
                        Text("Be the first to rate this episode!")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        
                        Button {
                            selectedTab = 1
                        } label: {
                            Text("+ Add Rating")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8]))
                            .foregroundStyle(Color.white.opacity(0.1))
                    )
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(ratings) { rating in
                        EpisodeRatingCard(viewModel: viewModel, rating: rating)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
    }
    
    private var myRatingView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RATING LABEL")
                        .font(.caption.bold())
                        .foregroundStyle(.gray)
                    TextField("e.g. overall, acting, writing", text: $myRatingLabel)
                        .padding()
                        .liquidGlass(cornerRadius: 8)
                        .foregroundStyle(.white)
                        .onChange(of: myRatingLabel) { oldValue, newValue in
                            if newValue.contains(" ") {
                                myRatingLabel = newValue.replacingOccurrences(of: " ", with: "")
                            }
                            let cleanOld = oldValue.replacingOccurrences(of: " ", with: "")
                            let cleanNew = newValue.replacingOccurrences(of: " ", with: "")
                            let oldConfig = RatingScaleConfig.get(for: cleanOld)
                            let newConfig = RatingScaleConfig.get(for: cleanNew)
                            if oldConfig != newConfig {
                                let percentage = oldConfig.toPercentage(myRatingScore)
                                myRatingScore = newConfig.fromPercentage(percentage)
                            }
                        }
                    Text("Common labels: overall, acting, writing, directing, cinematography")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    SourcePillShortcuts(text: $myRatingLabel, isAnime: isAnime, isEpisode: true)
                }
                .padding()
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)
                        if let tints = ratingTintColors(for: myRatingLabel) {
                            let gradientOpacity = myRatingLabel.uppercased().hasPrefix("AN") ? 0.15 : 0.25
                            let gradientColors = tints.map { $0.opacity(gradientOpacity) } + [Color.clear]
                            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                )
                
                VStack(alignment: .leading, spacing: 16) {
                    let config = RatingScaleConfig.get(for: myRatingLabel)
                    
                    HStack(spacing: 12) {
                        Text("SCORE")
                            .font(.caption.bold())
                            .foregroundStyle(.gray)
                        
                        let scoreText: String = {
                            if config.step == 1 {
                                return "\(Int(myRatingScore))"
                            } else {
                                return String(format: "%g", myRatingScore)
                            }
                        }()
                        
                        Text(scoreText)
                            .font(.headline.bold())
                            .frame(minWidth: 40, alignment: .center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .liquidGlass(cornerRadius: 8)
                            
                        Spacer()
                    }
                    
                    Slider(value: $myRatingScore, in: config.range, step: config.step)
                        .accentColor(.white)
                        .onChange(of: myRatingScore) { _ in
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
                    
                    HStack {
                        Text(config.step == 1 ? "\(Int(config.range.lowerBound))" : String(format: "%g", config.range.lowerBound)).font(.caption2).foregroundStyle(.gray)
                        Spacer()
                        Text(config.step == 1 ? "\(Int(config.range.upperBound))" : String(format: "%g", config.range.upperBound)).font(.caption2).foregroundStyle(.gray)
                    }
                }
                .padding()
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)
                        if let tints = ratingTintColors(for: myRatingLabel) {
                            let gradientOpacity = myRatingLabel.uppercased().hasPrefix("AN") ? 0.15 : 0.25
                            let gradientColors = tints.map { $0.opacity(gradientOpacity) } + [Color.clear]
                            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                )
                
                Button(action: submitRating) {
                    HStack {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "star.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Submit Rating")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            Capsule().fill(Color.white.opacity(0.1))
                            if let tints = ratingTintColors(for: myRatingLabel) {
                                let gradientOpacity = myRatingLabel.uppercased().hasPrefix("AN") ? 0.25 : 0.35
                                let gradientColors = tints.map { $0.opacity(gradientOpacity) } + [Color.clear]
                                LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                    .clipShape(Capsule())
                            }
                        }
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .opacity(isSubmitting || myRatingLabel.isEmpty ? 0.5 : 1)
                }
                .disabled(isSubmitting || myRatingLabel.isEmpty)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }
    
    private func submitRating() {
        isSubmitting = true
        Task {
            let finalScore = RatingScaleConfig.get(for: myRatingLabel).toPercentage(myRatingScore)
            await viewModel.submitEpisodeRating(
                episode: episodeNumber,
                score: finalScore,
                label: myRatingLabel
            )
            isSubmitting = false
            dismiss()
        }
    }
}

private struct EpisodeRatingCard: View {
    @ObservedObject var viewModel: MediaDetailViewModel
    let rating: MediaDetailViewModel.LocalEpisodeRating
    @State private var resolvedUsername: String?
    @State private var isDeleting = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Avatar, User, Trash
            HStack(spacing: 8) {
                    Group {
                        if let avatarUrl = rating.avatarUrl {
                            AsyncImage(url: avatarUrl) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                        } else {
                            Color.gray.opacity(0.3)
                                .overlay(Image(systemName: "person").font(.caption).foregroundColor(.gray))
                        }
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    Text(displayUsername)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    if rating.isOwner {
                        Text("YOU")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    if rating.isOwner {
                        Button {
                            isDeleting = true
                            Task {
                                await viewModel.deleteEpisodeRating(ratingId: rating.id)
                                isDeleting = false
                            }
                        } label: {
                            if isDeleting {
                                ProgressView().controlSize(.small)
                                    .frame(width: 34, height: 34)
                                    .background(.red.opacity(0.1))
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.red.opacity(0.75))
                                    .frame(width: 34, height: 34)
                                    .background(.red.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Body and Votes
                HStack(alignment: .bottom, spacing: 12) {
                    // Body: Score, Label, Date
                    HStack(spacing: 12) {
                        Text(convertedScoreTextFn(rating.score, label: rating.label ?? ""))
                        .font(.title2.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .liquidGlass(cornerRadius: 8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text((rating.label ?? "Overall").uppercased())
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(.white)
                        
                        if let dateString = rating.dateString {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.gray)
                                Text(dateString)
                                    .font(.caption2)
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                    }
                
                Spacer(minLength: 4)
                
                // Voting Controls centered on the right
                HStack(spacing: 16) {
                    Button {
                    Task { await viewModel.voteOnEpisodeRating(ratingId: rating.id, vote: rating.userVote == 1 ? .remove : .up) }
                } label: {
                    Image(systemName: rating.userVote == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.body.bold())
                        .foregroundStyle(rating.userVote == 1 ? .orange : .gray)
                }
                
                Text("\(rating.voteCount)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 24, alignment: .center)
                
                Button {
                    Task { await viewModel.voteOnEpisodeRating(ratingId: rating.id, vote: rating.userVote == -1 ? .remove : .down) }
                } label: {
                    Image(systemName: rating.userVote == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .font(.body.bold())
                        .foregroundStyle(rating.userVote == -1 ? .orange : .gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } // closes HStack(bottom)
        } // closes top-level VStack
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .task {
            if let name = rating.username, !name.isEmpty {
                resolvedUsername = name
            } else if let uId = rating.userId, !uId.isEmpty {
                resolvedUsername = await UserService.shared.fetchUsername(id: uId)
            }
        }
    }
    
    private var displayUsername: String {
        if let name = resolvedUsername, !name.isEmpty {
            return name
        }
        return "Anonymous"
    }
}

private struct SkipBar: View {
    let label: String
    let startMs: Int?
    let endMs: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(.white)
                Spacer()
                Text(durationText).font(.caption2).foregroundStyle(.gray)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.25))
                    Capsule().fill(Color.white.opacity(0.75))
                        .frame(width: max(8, geo.size.width * fraction))
                }
            }
            .frame(height: 6)
        }
    }

    private var fraction: CGFloat {
        guard let startMs, let endMs, endMs > startMs else { return 0.1 }
        return CGFloat(min(max(Double(endMs - startMs) / 120_000, 0.08), 1))
    }

    private var durationText: String {
        guard let startMs, let endMs else { return "—" }
        return "\((endMs - startMs) / 1000)s"
    }
}

private struct ExternalIDPlatformGroup: View {
    let title: String
    let items: [ExternalMapping]
    let isTMDB: Bool
    @ObservedObject var viewModel: MediaDetailViewModel
    
    @State private var isExpanded = false
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Row
            Button {
                if isTMDB {
                    if let first = items.first, let url = ExternalLinkBuilder.url(for: first, route: viewModel.route) {
                        openURL(url)
                    }
                } else if items.count > 1 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: 16) {
                    // Beautiful platform icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 48, height: 48)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                        
                        if isTMDB {
                            Image(systemName: "film.fill")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "link")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        
                        if isTMDB, let first = items.first {
                            Text(first.idValue)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.6))
                        } else if !isTMDB {
                            Text("\(items.count) ID\(items.count > 1 ? "s" : "") available")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                    
                    if isTMDB {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(10)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    } else if items.count > 1 {
                        // EXACT "more" button logic but slightly refined layout inside
                        HStack(spacing: 4) {
                            Text(isExpanded ? "Hide" : "+\(items.count - 1) more")
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if !isTMDB {
                let displayItems = isExpanded ? items : Array(items.prefix(1))
                ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                    if index > 0 || isExpanded {
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.horizontal, 16)
                    }
                    let isTopItem = (index == 0) && (items.count > 1)
                    ExternalIDDetailCard(item: item, isTop: isTopItem, viewModel: viewModel)
                }
            }
        }
        .liquidGlass(cornerRadius: 20)
    }
}

private struct ExternalIDDetailCard: View {
    let item: ExternalMapping
    let isTop: Bool
    @ObservedObject var viewModel: MediaDetailViewModel
    
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(spacing: 12) {
            let isActuallyOwner = item.isOwner == true || (item.contributor?.lowercased() == SettingsStore.shared.contributorName.lowercased() && !SettingsStore.shared.contributorName.isEmpty)
            
            // TOP ROW: User Info & Actions
            HStack(spacing: 6) {
                Text("ADDED BY \(item.contributor?.uppercased() ?? "COMMUNITY")")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.gray.opacity(0.8))
                
                if isActuallyOwner {
                    Text("YOU")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                }
                
                if isTop {
                    Text("TOP")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                
                Spacer(minLength: 8)
                
                if isActuallyOwner {
                    // EXACT edit/delete buttons from original
                    HStack(spacing: 4) {
                        Button {
                            viewModel.startEditingMapping(item)
                            viewModel.showExternalIDSheet = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 34, height: 34)
                                .background(.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            Task { await viewModel.deleteMapping(id: item.id) }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.red.opacity(0.75))
                                .frame(width: 34, height: 34)
                                .background(.red.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // BOTTOM ROW: Link Pill & Thumbs
            HStack(spacing: 12) {
                // Link Pill
                Button {
                    if let url = ExternalLinkBuilder.url(for: item, route: viewModel.route) {
                        openURL(url)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.blue)
                        Text(item.idValue)
                            .font(.headline.monospacedDigit().weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                
                Spacer(minLength: 8)
                
                // EXACT Voting UI from original
                HStack(spacing: 16) {
                    Button {
                        Task { await viewModel.voteOnMapping(mappingId: item.id, vote: item.userVote == 1 ? .remove : .up) }
                    } label: {
                        Image(systemName: item.userVote == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.body.bold())
                            .foregroundStyle(item.userVote == 1 ? .orange : .gray)
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(item.voteCount ?? 0)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 24, alignment: .center)
                    
                    Button {
                        Task { await viewModel.voteOnMapping(mappingId: item.id, vote: item.userVote == -1 ? .remove : .down) }
                    } label: {
                        Image(systemName: item.userVote == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            .font(.body.bold())
                            .foregroundStyle(item.userVote == -1 ? .orange : .gray)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
    }
}

struct ExternalIDSubmissionSheet: View {
    @ObservedObject var viewModel: MediaDetailViewModel
    @State private var idValue: String = ""
    @State private var isSubmitting = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ID TYPE").font(.caption.bold()).foregroundStyle(.gray)
                                Menu {
                                    Picker("Type", selection: $viewModel.selectedExternalIDType) {
                                        ForEach(ExternalIDType.allCases.filter { $0 != .tmdb && $0 != .anidb && $0 != .tmdbSeason && $0 != .tmdbEpisode }, id: \.self) { type in
                                            Text(type.displayLabel).tag(type)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(viewModel.selectedExternalIDType.displayLabel)
                                            .font(.body)
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ID VALUE").font(.caption.bold()).foregroundStyle(.gray)
                                TextField("e.g. tt1234567", text: $idValue)
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(.white)
                                    .padding(12)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                        
                        if let error = viewModel.externalIDSubmitError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    
                    Button {
                        submitExternalID()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView().controlSize(.small).tint(.white)
                            } else {
                                Image(systemName: "link")
                                    .font(.system(size: 16, weight: .bold))
                                Text(viewModel.editingMappingId != nil ? "Save Changes" : "Submit External ID")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                    }
                    .disabled(idValue.isEmpty || isSubmitting)
                    .opacity(idValue.isEmpty || isSubmitting ? 0.5 : 1)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle(viewModel.editingMappingId != nil ? "Edit Mapping ID" : "New Mapping ID")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let editId = viewModel.editingMappingId,
               let mapping = viewModel.mappings.first(where: { $0.id == editId }) {
                idValue = mapping.idValue
            }
        }
        .onChange(of: viewModel.externalIDSubmitSuccess) { _, success in
            if success {
                viewModel.externalIDSubmitSuccess = false
                idValue = ""
                viewModel.editingMappingId = nil
                dismiss()
            }
        }
    }
    
    private func submitExternalID() {
        isSubmitting = true
        Task {
            if let editId = viewModel.editingMappingId {
                await viewModel.updateExternalID(
                    id: editId,
                    idType: viewModel.selectedExternalIDType,
                    idValue: idValue.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } else {
                await viewModel.submitExternalID(
                    idType: viewModel.selectedExternalIDType,
                    idValue: idValue.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            isSubmitting = false
        }
    }
}

enum ExternalLinkBuilder {
    static func tmdb(route: MediaDetailRoute) -> URL? {
        let segment = route.mediaType == .movie ? "movie" : "tv"
        return URL(string: "https://www.themoviedb.org/\(segment)/\(route.tmdbId)")
    }

    static func url(for mapping: ExternalMapping, route: MediaDetailRoute) -> URL? {
        switch mapping.idType {
        case .imdb:
            let id = mapping.idValue.hasPrefix("tt") ? mapping.idValue : "tt\(mapping.idValue)"
            return URL(string: "https://www.imdb.com/title/\(id)/")
        case .tmdb:
            let segment = route.mediaType == .movie ? "movie" : "tv"
            return URL(string: "https://www.themoviedb.org/\(segment)/\(mapping.idValue)")
        case .trakt, .traktSlug:
            let segment = route.mediaType == .movie ? "movies" : "shows"
            return URL(string: "https://trakt.tv/\(segment)/\(mapping.idValue)")
        case .tvdb:
            return URL(string: "https://www.thetvdb.com/?tab=series&id=\(mapping.idValue)")
        case .mal:
            return URL(string: "https://myanimelist.net/anime/\(mapping.idValue)")
        case .anilist:
            return URL(string: "https://anilist.co/anime/\(mapping.idValue)")
        case .anidb:
            return URL(string: "https://anidb.net/anime/\(mapping.idValue)")
        case .justWatch, .rottenTomatoes, .metacritic, .letterboxd, .tmdbSeason, .tmdbEpisode:
            return nil
        }
    }
}

private struct EpisodeSynopsisSheet: View {
    let episode: EpisodeDisplay
    let seasonNumber: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }
                    
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("S\(seasonNumber) • E\(episode.episodeNumber) - \(episode.name)")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(episode.overview ?? "No synopsis available.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal)
                    .padding(.top, 32)
                    .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Skip Submission Sheet
struct SkipSubmissionSheet: View {
    @ObservedObject var viewModel: MediaDetailViewModel
    let episode: EpisodeDisplay?
    
    @State private var selectedTab: Int = 0
    @State private var sourceType: SkipSource = .streaming
    @State private var introStart: String = ""
    @State private var introEnd: String = ""
    @State private var creditsStart: String = ""
    @State private var creditsEnd: String = ""

    @State private var isSubmitting = false
    
    @Environment(\.dismiss) private var dismiss
    
    private var episodeNumber: Int? { episode?.episodeNumber }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }
                
                VStack(spacing: 0) {
                    GlassTabSelector(selection: $selectedTab, options: [0, 1]) { tab in
                        tab == 0 ? "All Submissions (\(viewModel.episodeSkips.count))" : "My Submission"
                    }
                    .padding()
                    
                    if selectedTab == 0 {
                        allSubmissionsView
                    } else {
                        mySubmissionView
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowBackground(Color.clear)
            .navigationTitle(episode != nil ? "S\(viewModel.selectedSeason):E\(String(episode!.episodeNumber))" : "Skip Times")
            .navigationBarTitleDisplayMode(.inline)

        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.loadSkipsForSheet(episodeNumber: episodeNumber)
            prefillFromExisting()
        }
        .onChange(of: viewModel.skipSubmitSuccess) { _, success in
            if success {
                selectedTab = 0
                viewModel.skipSubmitSuccess = false
            }
        }
    }
    
    private func prefillFromExisting() {
        guard let existing = viewModel.episodeSkips.first else { return }
        if let s = existing.introStartMs { introStart = msToString(s) }
        if let e = existing.introEndMs { introEnd = msToString(e) }
        if let s = existing.creditsStartMs { creditsStart = msToString(s) }
        if let e = existing.creditsEndMs { creditsEnd = msToString(e) }
        if let src = existing.source { sourceType = src }
    }
    
    // MARK: - All Submissions View
    private var allSubmissionsView: some View {
        ScrollView {
            if viewModel.isLoadingSkipSheet {
                VStack {
                    ProgressView()
                        .padding(.top, 60)
                }
                .frame(maxWidth: .infinity)
            } else if viewModel.episodeSkips.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Image(systemName: "person.3")
                            .font(.system(size: 32))
                            .foregroundStyle(.gray)
                            .padding(.bottom, 8)
                        
                        Text("No submissions yet")
                            .font(.headline.bold())
                            .foregroundStyle(.gray)
                        
                        Text("Be the first to submit skip times!")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        
                        Button {
                            selectedTab = 1
                        } label: {
                            Text("+ Add Submission")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8]))
                            .foregroundStyle(Color.white.opacity(0.1))
                    )
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.episodeSkips) { skip in
                        SkipCard(viewModel: viewModel, skip: skip, episodeNumber: episodeNumber)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - My Submission View
    private var mySubmissionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Source Type
                VStack(alignment: .leading, spacing: 12) {
                    Text("SOURCE TYPE")
                        .font(.caption.bold())
                        .foregroundStyle(.gray)
                    Text("Skip times may differ between streaming and physical releases.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    HStack(spacing: 12) {
                        sourceButton(title: "Streaming", icon: "tv", type: .streaming)
                        sourceButton(title: "Physical", icon: "record.circle", type: .physical)
                    }
                }
                .padding()
                .liquidGlass(cornerRadius: 12)
                
                // INTRO
                timeBox(title: "INTRO", color: Color(red: 0, green: 0.9, blue: 0.55), start: $introStart, end: $introEnd)
                
                // CREDITS
                timeBox(title: "CREDITS", color: Color(red: 0.66, green: 0.33, blue: 0.97), start: $creditsStart, end: $creditsEnd)
                
                if let error = viewModel.skipSubmitError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                Button {
                    submitSkip()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: "clock")
                                .font(.system(size: 16, weight: .bold))
                            Text("Submit Timestamps")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .disabled(isSubmitting || isSkipFormInvalid)
                .opacity(isSubmitting || isSkipFormInvalid ? 0.5 : 1)
                Text("Your submission will be combined with others to calculate the best skip times.")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }
    
    private var isSkipFormInvalid: Bool {
        let introPartiallyFilled = (introStart.isEmpty && !introEnd.isEmpty) || (!introStart.isEmpty && introEnd.isEmpty)
        let creditsPartiallyFilled = (creditsStart.isEmpty && !creditsEnd.isEmpty) || (!creditsStart.isEmpty && creditsEnd.isEmpty)
        let allEmpty = introStart.isEmpty && introEnd.isEmpty && creditsStart.isEmpty && creditsEnd.isEmpty
        
        return introPartiallyFilled || creditsPartiallyFilled || allEmpty
    }
    
    private func submitSkip() {
        isSubmitting = true
        Task {
            await viewModel.submitSkip(
                episodeNumber: episodeNumber,
                introStartMs: parseTime(introStart),
                introEndMs: parseTime(introEnd),
                creditsStartMs: parseTime(creditsStart),
                creditsEndMs: parseTime(creditsEnd),
                source: sourceType
            )
            isSubmitting = false
        }
    }
    
    private func sourceButton(title: String, icon: String, type: SkipSource) -> some View {
        let isSelected = sourceType == type
        return Button {
            sourceType = type
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.bold())
            .foregroundStyle(isSelected ? (type == .streaming ? .blue : .orange) : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? (type == .streaming ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1)) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? (type == .streaming ? Color.blue.opacity(0.3) : Color.orange.opacity(0.3)) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private func timeBox(title: String, color: Color, start: Binding<String>, end: Binding<String>) -> some View {
        let formatTime: (Binding<String>, String, String) -> Void = { binding, old, new in
            if old.count >= new.count { return } // user is deleting
            let digits = new.replacingOccurrences(of: ":", with: "")
            if digits.count == 2 && !new.contains(":") {
                binding.wrappedValue = new + ":"
            } else if digits.count > 2 && !new.contains(":") {
                var str = new
                str.insert(":", at: str.index(str.startIndex, offsetBy: 2))
                binding.wrappedValue = str
            }
        }
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                if title == "INTRO" {
                    Image(systemName: "play.fill").font(.system(size: 8))
                } else {
                    Image(systemName: "square.fill").font(.system(size: 8))
                }
                Text(title)
                    .font(.caption.bold())
            }
            .foregroundStyle(color)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start (mm:ss)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    TextField("00:00", text: start)
                        .keyboardType(.numbersAndPunctuation)
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.white)
                        .padding()
                        .liquidGlass(cornerRadius: 8)
                        .onChange(of: start.wrappedValue) { old, new in
                            formatTime(start, old, new)
                        }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("End (mm:ss)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    TextField("00:00", text: end)
                        .keyboardType(.numbersAndPunctuation)
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.white)
                        .padding()
                        .liquidGlass(cornerRadius: 8)
                        .onChange(of: end.wrappedValue) { old, new in
                            formatTime(end, old, new)
                        }
                }
            }
        }
        .padding()
        .liquidGlass(cornerRadius: 12)
    }
}

// MARK: - Time Helpers
func parseTime(_ str: String) -> Int? {
    let parts = str.split(separator: ":").map { Int($0) }
    guard parts.count == 2, let m = parts[0], let s = parts[1] else { return nil }
    return (m * 60 + s) * 1000
}

func msToString(_ ms: Int) -> String {
    let totalSec = ms / 1000
    let m = totalSec / 60
    let s = totalSec % 60
    return String(format: "%02d:%02d", m, s)
}

// MARK: - Skip Card
struct SkipCard: View {
    @ObservedObject var viewModel: MediaDetailViewModel
    let skip: SkipTimestamp
    let episodeNumber: Int?
    @State private var isDeleting = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(spacing: 8) {
                    // Placeholder avatar since we don't have avatarUrl on skip yet
                    Color.gray.opacity(0.3)
                        .overlay(Image(systemName: "person").font(.caption).foregroundColor(.gray))
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    if let contributor = skip.contributor, !contributor.isEmpty {
                        Text(contributor)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        Text("Unknown")
                            .font(.subheadline.bold())
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    
                    if skip.isOwner {
                        Text("YOU")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    if skip.isOwner {
                        Button {
                            isDeleting = true
                            Task {
                                await viewModel.deleteSkip(id: skip.id, episodeNumber: episodeNumber)
                                isDeleting = false
                            }
                        } label: {
                            if isDeleting {
                                ProgressView().controlSize(.small)
                                    .frame(width: 34, height: 34)
                                    .background(.red.opacity(0.1))
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.red.opacity(0.75))
                                    .frame(width: 34, height: 34)
                                    .background(.red.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Body and Votes
                HStack(alignment: .bottom, spacing: 12) {
                    // Body: Source, Times, Date
                    VStack(alignment: .leading, spacing: 10) {
                        // Source badge (optional)
                    if let source = skip.source {
                        HStack(spacing: 4) {
                            Image(systemName: source == .streaming ? "tv" : "record.circle")
                            Text(source.rawValue.uppercased())
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(source == .streaming ? .blue : .orange)
                        .padding(.bottom, 2)
                    }
                    
                    if let intro = skip.introDisplay {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color(red: 0, green: 0.9, blue: 0.55))
                            Text("INTRO")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(red: 0, green: 0.9, blue: 0.55))
                            Text(intro)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.white)
                        }
                    }
                    if let credits = skip.creditsDisplay {
                        HStack(spacing: 6) {
                            Image(systemName: "square.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color(red: 0.66, green: 0.33, blue: 0.97))
                            Text("CREDITS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(red: 0.66, green: 0.33, blue: 0.97))
                            Text(credits)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.white)
                        }
                    }
                    
                    if let dateStr = skip.dateString {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                                .foregroundStyle(.gray)
                            Text(dateStr)
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                        .padding(.top, 2)
                    }
                }
                
                Spacer(minLength: 4)
                
                // Voting Controls (centered on right)
                HStack(spacing: 16) {
                Button {
                    Task { await viewModel.voteOnSkip(skipId: skip.id, vote: skip.userVote == 1 ? .remove : .up) }
                } label: {
                    Image(systemName: skip.userVote == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.body.bold())
                        .foregroundStyle(skip.userVote == 1 ? .orange : .gray)
                }
                
                Text("\(skip.voteCount)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 24, alignment: .center)
                
                Button {
                    Task { await viewModel.voteOnSkip(skipId: skip.id, vote: skip.userVote == -1 ? .remove : .down) }
                } label: {
                    Image(systemName: skip.userVote == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .font(.body.bold())
                        .foregroundStyle(skip.userVote == -1 ? .orange : .gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } // closes HStack(bottom)
        } // closes top-level VStack
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct HighlightSubmissionSheet: View {
    @ObservedObject var viewModel: MediaDetailViewModel
    let episode: Int?
    
    @State private var selectedTab: Int = 0
    @State private var startText: String = ""
    @State private var endText: String = ""
    @State private var descriptionText: String = ""
    @State private var seasonText: String = ""
    @State private var episodeText: String = ""

    @State private var isSubmitting = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.001).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    GlassTabSelector(selection: $selectedTab, options: [0, 1]) { tab in
                        tab == 0 ? "All Highlights (\(viewModel.episodeHighlights.count))" : "My Highlight"
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    if selectedTab == 0 {
                        allHighlightsView
                    } else {
                        myHighlightView
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle(episode != nil ? "S\(viewModel.selectedSeason):E\(String(episode!))" : "Highlights")
            .navigationBarTitleDisplayMode(.inline)

        }
        .preferredColorScheme(.dark)
        .task {
            if let ep = episode {
                seasonText = "\(viewModel.selectedSeason)"
                episodeText = "\(ep)"
            }
            await viewModel.loadHighlightsForSheet(episodeNumber: episode)
            if let mine = viewModel.myEpisodeHighlight {
                startText = msToTimeString(mine.highlightStartMs)
                if mine.highlightEndMs > 0 { endText = msToTimeString(mine.highlightEndMs) }
                descriptionText = mine.description ?? ""
            }
        }
        .onChange(of: viewModel.highlightSubmitSuccess) { _, success in
            if success {
                selectedTab = 0
                viewModel.highlightSubmitSuccess = false
            }
        }
    }
    
    private var allHighlightsView: some View {
        ScrollView {
            if viewModel.isLoadingHighlightSheet {
                VStack {
                    ProgressView().padding(.top, 60)
                }
                .frame(maxWidth: .infinity)
            } else if viewModel.episodeHighlights.isEmpty {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Image(systemName: "flag")
                            .font(.system(size: 32))
                            .foregroundStyle(.gray)
                            .padding(.bottom, 8)
                        
                        Text("No highlights yet")
                            .font(.headline.bold())
                            .foregroundStyle(.gray)
                        
                        Text("Be the first to mark a scene!")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        
                        Button {
                            selectedTab = 1
                        } label: {
                            Text("+ Add Highlight")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8]))
                            .foregroundStyle(Color.white.opacity(0.1))
                    )
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.episodeHighlights) { highlight in
                        HighlightCard(viewModel: viewModel, highlight: highlight, episodeNumber: episode) {
                            if highlight.isOwner == true {
                                selectedTab = 1
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
    }
    
    private var myHighlightView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(viewModel.myEpisodeHighlight != nil ? "Edit Highlight" : "New Highlight")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                    
                    HStack(spacing: 16) {
                        timeBox(title: "START (MM:SS)", start: $startText)
                        timeBox(title: "END (MM:SS) optional", start: $endText)
                    }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DESCRIPTION").font(.caption.bold()).foregroundStyle(.gray)
                            TextField("e.g. Jump scare", text: $descriptionText)
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.white)
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                        }
                        
                        if viewModel.route.mediaType != .movie {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("SEASON").font(.caption.bold()).foregroundStyle(.gray)
                                    TextField("1", text: $seasonText)
                                        .keyboardType(.numberPad)
                                        .padding()
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(8)
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("EPISODE").font(.caption.bold()).foregroundStyle(.gray)
                                    TextField("1", text: $episodeText)
                                        .keyboardType(.numberPad)
                                        .padding()
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        
                        if let error = viewModel.highlightSubmitError {
                            Text(error).font(.caption).foregroundStyle(.red)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    
                    Button {
                        submitHighlight()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView().controlSize(.small).tint(.white)
                            } else {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text(viewModel.myEpisodeHighlight != nil ? "Update Highlight" : "Submit Highlight")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                    }
                    .disabled(isSubmitting || startText.isEmpty || descriptionText.isEmpty)
                    .opacity(isSubmitting || startText.isEmpty || descriptionText.isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }
    
    private func timeBox(title: String, start: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.bold()).foregroundStyle(.gray)
            TextField("00:00", text: start)
                .keyboardType(.numbersAndPunctuation)
                .font(.body.monospacedDigit())
                .foregroundStyle(.white)
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
        }
    }
    
    private func submitHighlight() {
        isSubmitting = true
        let startMs = stringToMs(startText) ?? 0
        let endMs = stringToMs(endText) ?? 0
        Task {
            if let mine = viewModel.myEpisodeHighlight {
                await viewModel.updateHighlight(id: mine.id, episodeNumber: episode, startMs: startMs, endMs: endMs, description: descriptionText)
            } else {
                await viewModel.submitHighlight(episodeNumber: episode, startMs: startMs, endMs: endMs, description: descriptionText)
            }
            isSubmitting = false
        }
    }
    
    private func stringToMs(_ str: String) -> Int? {
        if str.isEmpty { return nil }
        let parts = str.split(separator: ":")
        guard parts.count == 2,
              let m = Int(parts[0]), let s = Int(parts[1]) else { return nil }
        return (m * 60 + s) * 1000
    }
    
    private func msToTimeString(_ ms: Int) -> String {
        let totalSec = ms / 1000
        let m = totalSec / 60
        let s = totalSec % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct HighlightCard: View {
    @ObservedObject var viewModel: MediaDetailViewModel
    let highlight: Highlight
    let episodeNumber: Int?
    var onEdit: (() -> Void)? = nil
    
    @State private var isDeleting = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row (Full Width)
            HStack(alignment: .center, spacing: 8) {
                Color.gray.opacity(0.3)
                    .overlay(Image(systemName: "person").font(.caption).foregroundColor(.gray))
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                if let contributor = highlight.contributor, !contributor.isEmpty {
                    Text(contributor)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text("Unknown")
                        .font(.subheadline.bold())
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                
                if highlight.isOwner == true {
                        Text("YOU")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                }
                
                Spacer()
                
                if highlight.isOwner == true {
                    HStack(spacing: 4) {
                        Button {
                            onEdit?()
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 34, height: 34)
                                .background(.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            isDeleting = true
                            Task {
                                await viewModel.deleteHighlight(id: highlight.id, episodeNumber: episodeNumber)
                                isDeleting = false
                            }
                        } label: {
                            if isDeleting {
                                ProgressView().controlSize(.small)
                                    .frame(width: 34, height: 34)
                                    .background(.red.opacity(0.1))
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.red.opacity(0.75))
                                    .frame(width: 34, height: 34)
                                    .background(.red.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Body and Voting Row
            HStack(alignment: .bottom, spacing: 12) {
                // Body
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill").font(.system(size: 8)).foregroundStyle(.red)
                        Text("HIGHLIGHT").font(.system(size: 10, weight: .bold)).foregroundStyle(.red)
                        Text("\(highlight.displayStart) \((highlight.highlightEndMs > 0) ? "-> \(highlight.displayEnd)" : "")")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.white)
                    }
                    
                    if let desc = highlight.description {
                        Text(desc).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    }
                    
                    if let dateStr = highlight.dateString {
                        HStack(spacing: 4) {
                            Image(systemName: "clock").font(.system(size: 9)).foregroundStyle(.gray)
                            Text(dateStr).font(.caption2).foregroundStyle(.gray)
                        }
                    }
                }
                
                Spacer(minLength: 4)
                
                // Voting Controls
                HStack(spacing: 16) {
                    Button {
                        Task { await viewModel.voteOnHighlight(highlightId: highlight.id, vote: highlight.userVote == 1 ? .remove : .up) }
                    } label: {
                        Image(systemName: highlight.userVote == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.body.bold())
                            .foregroundStyle(highlight.userVote == 1 ? .orange : .gray)
                    }
                    
                    Text("\(highlight.voteCount ?? 0)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 24, alignment: .center)
                    
                    Button {
                        Task { await viewModel.voteOnHighlight(highlightId: highlight.id, vote: highlight.userVote == -1 ? .remove : .down) }
                    } label: {
                        Image(systemName: highlight.userVote == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            .font(.body.bold())
                            .foregroundStyle(highlight.userVote == -1 ? .orange : .gray)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
    }
}

private struct SourcePillShortcuts: View {
    @Binding var text: String
    var isAnime: Bool = false
    var isEpisode: Bool = false
    
    var labels: [String] {
        if isEpisode {
            return ["IM", "TM", "TR"]
        }
        var base: [String] = []
        base.append(contentsOf: ["IM", "LB", "TM", "TR", "RT", "PC"])
        if isAnime {
            base.append(contentsOf: ["AN", "ML"])
        }
        base.append(contentsOf: ["MC", "RE"])
        return base
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(labels, id: \.self) { label in
                    let isSelected = text.lowercased() == label.lowercased()
                    Button {
                        text = label
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image("logo_hero_\(label)")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 14)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                ZStack {
                                    Capsule().fill(.ultraThinMaterial)
                                    
                                    let tintColors: [Color]? = {
                                        switch label {
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
                                    }()
                                    
                                    if let tints = tintColors {
                                        let gradientOpacity = label == "AN" ? 0.25 : 0.4
                                        let gradientColors = tints.map { $0.opacity(gradientOpacity) } + [Color.clear]
                                        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                            .clipShape(Capsule())
                                    }
                                }
                            )
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(isSelected ? Color.white : Color.white.opacity(0.15), lineWidth: isSelected ? 1.5 : 0.5))
                    }
                }
            }
        }
        .padding(.top, 4)
    }
}

private struct RatingScaleConfig: Equatable {
    let range: ClosedRange<Double>
    let step: Double
    let mid: Double
    let toPercentage: (Double) -> Int
    let fromPercentage: (Int) -> Double
    
    static func get(for label: String) -> RatingScaleConfig {
        switch label.uppercased() {
        case "IM", "ML":
            return RatingScaleConfig(
                range: 1.0...10.0, 
                step: 0.1, 
                mid: 5.0,
                toPercentage: { Int(round($0 * 10)) }, 
                fromPercentage: { Double($0) / 10.0 }
            )
        case "TM":
            return RatingScaleConfig(
                range: 1.0...10.0, 
                step: 0.1, 
                mid: 5.0,
                toPercentage: { Int(round($0 * 10)) }, 
                fromPercentage: { Double($0) / 10.0 }
            )
        case "LB":
            return RatingScaleConfig(
                range: 0.5...5.0, 
                step: 0.1, 
                mid: 2.5,
                toPercentage: { Int(round($0 * 20)) }, 
                fromPercentage: { Double($0) / 20.0 }
            )
        case "RE":
            return RatingScaleConfig(
                range: 0...4.0, 
                step: 0.5, 
                mid: 2.0,
                toPercentage: { Int(round($0 * 25)) }, 
                fromPercentage: { Double($0) / 25.0 }
            )
        case "TR", "AN", "RT", "MC", "PC":
            return RatingScaleConfig(
                range: 0...100, 
                step: 1, 
                mid: 50.0,
                toPercentage: { Int(round($0)) }, 
                fromPercentage: { Double($0) }
            )
        default:
            return RatingScaleConfig(
                range: 0...100, 
                step: 1, 
                mid: 50.0,
                toPercentage: { Int(round($0)) }, 
                fromPercentage: { Double($0) }
            )
        }
    }
    
    static func == (lhs: RatingScaleConfig, rhs: RatingScaleConfig) -> Bool {
        lhs.range == rhs.range && lhs.step == rhs.step
    }
}

func convertedScoreTextFn(_ score: Int, label: String) -> String {
    guard UserDefaults.standard.bool(forKey: "convertRatings") else { return "\(score)" }
    let config = RatingScaleConfig.get(for: label)
    if config.range == 0.0...100.0 { return "\(score)" }
    let converted = config.fromPercentage(score)
    // Always show 1 decimal for 10-scale and similar
    if config.step < 1 || config.range.upperBound <= 10 {
        return String(format: "%.1f", converted)
    }
    return config.step == 1 ? "\(Int(converted))" : String(format: "%g", converted)
}

func denominatorTextFn(_ label: String) -> String {
    guard UserDefaults.standard.bool(forKey: "convertRatings") else { return "/ 100" }
    let config = RatingScaleConfig.get(for: label)
    if config.range == 0.0...100.0 { return "/ 100" }
    let max = config.range.upperBound
    return "/ \(config.step == 1 ? "\(Int(max))" : String(format: "%g", max))"
}

func ratingTintColors(for label: String) -> [Color]? {
    let cleanLabel = label.uppercased()
    let knownLabels = ["IM", "RE", "TR", "AN", "LB", "RT", "PC", "MC", "TM", "ML"]
    let matchedLabel = knownLabels.first(where: { cleanLabel.hasPrefix($0) }) ?? cleanLabel
    
    switch matchedLabel {
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

struct CommunityRatingSheet: View {
    @ObservedObject var viewModel: MediaDetailViewModel
    
    @State private var labelValue: String = ""
    @State private var scoreValue: Double = 50
    @State private var isSubmitting = false
    @State private var isReadyForHaptics = false
    
    @Environment(\.dismiss) private var dismiss
    
    private var isAnime: Bool {
        guard let detail = viewModel.detail else { return false }
        let isAnimation = detail.genres.contains("Animation")
        let isEastAsian = detail.originCountry?.contains(where: { ["JP", "KR", "CN", "TW", "HK"].contains($0.uppercased()) }) ?? false
        return isAnimation && isEastAsian
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.editingCommunityRating == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("RATING LABEL").font(.caption.bold()).foregroundStyle(.gray)
                            TextField("e.g. overall", text: $labelValue)
                                .padding()
                                .liquidGlass(cornerRadius: 8)
                                .foregroundStyle(.white)
                                .onChange(of: labelValue) { oldValue, newValue in
                                    if newValue.contains(" ") {
                                        labelValue = newValue.replacingOccurrences(of: " ", with: "")
                                    }
                                    let cleanOld = oldValue.replacingOccurrences(of: " ", with: "")
                                    let cleanNew = newValue.replacingOccurrences(of: " ", with: "")
                                    let oldConfig = RatingScaleConfig.get(for: cleanOld)
                                    let newConfig = RatingScaleConfig.get(for: cleanNew)
                                    if oldConfig != newConfig {
                                        let percentage = oldConfig.toPercentage(scoreValue)
                                        scoreValue = newConfig.fromPercentage(percentage)
                                    }
                                }
                            Text("Common labels: overall, acting, writing, directing, cinematography")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                            SourcePillShortcuts(text: $labelValue, isAnime: isAnime)
                        }
                        .padding()
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)
                                if let tints = ratingTintColors(for: labelValue) {
                                    let gradientOpacity = labelValue.uppercased().hasPrefix("AN") ? 0.15 : 0.25
                                    let gradientColors = tints.map { $0.opacity(gradientOpacity) } + [Color.clear]
                                    LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        let config = RatingScaleConfig.get(for: viewModel.editingCommunityRating?.label ?? labelValue)
                        
                        HStack(spacing: 12) {
                            Text(viewModel.editingCommunityRating == nil ? "SCORE" : "YOUR SCORE")
                                .font(.caption.bold())
                                .foregroundStyle(.gray)
                            
                            let scoreText: String = {
                                if config.step == 1 {
                                    return "\(Int(scoreValue))"
                                } else {
                                    return String(format: "%g", scoreValue)
                                }
                            }()
                            
                            Text(scoreText)
                                .font(.headline.bold())
                                .frame(minWidth: 40, alignment: .center)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .liquidGlass(cornerRadius: 8)
                                
                            Spacer()
                        }
                        
                        Slider(value: $scoreValue, in: config.range, step: config.step)
                            .accentColor(.white)
                            .onChange(of: scoreValue) { _ in
                                if isReadyForHaptics {
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                }
                            }
                        
                        HStack {
                            Text(config.step == 1 ? "\(Int(config.range.lowerBound))" : String(format: "%g", config.range.lowerBound)).font(.caption2).foregroundStyle(.gray)
                            Spacer()
                            Text(config.step == 1 ? "\(Int(config.range.upperBound))" : String(format: "%g", config.range.upperBound)).font(.caption2).foregroundStyle(.gray)
                        }
                    }
                    .padding()
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)
                            let currentLabel = viewModel.editingCommunityRating?.label ?? labelValue
                            if let tints = ratingTintColors(for: currentLabel) {
                                let gradientOpacity = currentLabel.uppercased().hasPrefix("AN") ? 0.15 : 0.25
                                let gradientColors = tints.map { $0.opacity(gradientOpacity) } + [Color.clear]
                                LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    )
                    
                    if let error = viewModel.communityRatingSubmitError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    Button(action: submitRating) {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text(viewModel.editingCommunityRating == nil ? "Publish Rating" : "Submit Rating")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                        .background(
                            ZStack {
                                Capsule().fill(Color.white.opacity(0.1))
                                let currentLabel = viewModel.editingCommunityRating?.label ?? labelValue
                                if let tints = ratingTintColors(for: currentLabel) {
                                    let gradientOpacity = currentLabel.uppercased().hasPrefix("AN") ? 0.25 : 0.35
                                    let gradientColors = tints.map { $0.opacity(gradientOpacity) } + [Color.clear]
                                    LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                        .clipShape(Capsule())
                                }
                            }
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .opacity(isSubmitting || (viewModel.editingCommunityRating == nil && labelValue.isEmpty) ? 0.5 : 1)
                    }
                    .disabled(isSubmitting || (viewModel.editingCommunityRating == nil && labelValue.isEmpty))
                }
                .padding(.horizontal)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle(viewModel.editingCommunityRating != nil ? viewModel.editingCommunityRating!.shortLabel : "New Rating")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let editRating = viewModel.editingCommunityRating {
                let config = RatingScaleConfig.get(for: editRating.label)
                scoreValue = config.fromPercentage(editRating.averageScore)
                labelValue = editRating.label
            } else {
                scoreValue = 50
                labelValue = ""
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isReadyForHaptics = true
            }
        }
        .onChange(of: viewModel.communityRatingSubmitSuccess) { _, success in
            if success {
                viewModel.communityRatingSubmitSuccess = false
                isSubmitting = false
                dismiss()
            }
        }
    }
    
    private func submitRating() {
        guard !isSubmitting else { return }
        isSubmitting = true
        // When editing use the stored label; when new use what user typed (default "overall")
        let finalLabel: String
        if let editing = viewModel.editingCommunityRating {
            finalLabel = editing.label.isEmpty ? "overall" : editing.label
        } else {
            finalLabel = labelValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "overall" : labelValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        Task {
            let finalScore = RatingScaleConfig.get(for: finalLabel).toPercentage(scoreValue)
            await viewModel.submitCommunityRating(score: finalScore, label: finalLabel)
            await MainActor.run {
                if viewModel.communityRatingSubmitError != nil {
                    isSubmitting = false
                }
            }
        }
    }
}

struct DetailHeroVideoLayer: View {
    let trailerURL: URL?
    @Binding var isMuted: Bool
    @Binding var isVideoReady: Bool
    let geoWidth: CGFloat
    let geoHeight: CGFloat
    let minY: CGFloat    
    @State private var player: AVPlayer?
    @State private var playTask: Task<Void, Never>?
    @State private var isVisible = false
    @AppStorage("playbackStyle") private var playbackStyle: PlaybackStyle = .resume
    
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState
    @State private var parentTab: AppTab? = nil
    
    var body: some View {
        ZStack {
            if let player = player {
                HeroVideoPlayer(player: player)
                    .ignoresSafeArea()
                    .scaleEffect(1.35)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geoWidth, height: geoHeight)
                    .clipped()
                    .opacity(isVideoReady && isVisible ? 1.0 : 0.0)
                    .blur(radius: isVideoReady && isVisible ? 0 : 20)
                    .animation(.easeInOut(duration: 1.5), value: isVideoReady && isVisible)
            }
        }
        .frame(width: geoWidth, height: geoHeight)
        .onAppear {
            if parentTab == nil {
                parentTab = appState.selectedTab
            }
            isVisible = true
            handleVisibility()
        }
        .onDisappear {
            isVisible = false
            handleVisibility()
        }
        // When offset gets too high, we consider it invisible to save resources
        .onChange(of: minY) { newMinY in
            let currentlyVisible = newMinY > -geoHeight // Keep playing until completely off screen
            if currentlyVisible != isVisible {
                isVisible = currentlyVisible
                handleVisibility()
            }
        }
        .onChange(of: isMuted) { newMuted in
            player?.isMuted = newMuted
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                if isVisible && (parentTab == nil || appState.selectedTab == parentTab) {
                    player?.play()
                }
            } else {
                player?.pause()
            }
        }
        .onChange(of: appState.selectedTab) { newTab in
            guard let parentTab = parentTab else { return }
            if newTab == parentTab {
                if isVisible && scenePhase == .active {
                    player?.play()
                }
            } else {
                player?.pause()
            }
        }
    }
    
    private func handleVisibility() {
        if isVisible {
            if player == nil {
                setupPlayer()
            } else {
                if playbackStyle == .startOver {
                    player?.seek(to: .zero)
                }
                
                playTask?.cancel()
                playTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2.0 second delay
                    guard !Task.isCancelled, isVisible else { return }
                    
                    self.player?.play()
                    withAnimation {
                        self.isVideoReady = true
                    }
                }
            }
        } else {
            playTask?.cancel()
            playTask = nil
            player?.pause()
            withAnimation(.easeOut(duration: 0.5)) {
                isVideoReady = false
            }
        }
    }
    
    private func setupPlayer() {
        guard let url = trailerURL else { return }
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.isMuted = isMuted
        self.player = newPlayer
        
        playTask?.cancel()
        playTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2.0 second delay
            guard !Task.isCancelled, isVisible else { return }
            
            self.player?.play()
            self.isVideoReady = true
            
            // Loop video
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: newPlayer.currentItem,
                queue: .main
            ) { _ in
                newPlayer.seek(to: .zero)
                newPlayer.play()
            }
        }
    }
}
// Share Image Feature

struct ShareMediaData {
    let title: String
    let background: UIImage?
    let logo: UIImage?
    let network: UIImage?
    let tagline: String?
    
    let displayRatingTitle: String?
    let displayRatingValue: Int?
    
    let mediaType: MediaType
    let year: String?
    let runtime: String?
    let contentRating: String?
    let genres: [String]
    let directorName: String?
    let isDirector: Bool
    let showStatus: String?
    let appIconName: String?
    
    let watchedCount: Int
    let totalEpisodes: Int
    let watchedEpisodes: Int
    let isEpisodeCountReliable: Bool
    
    var appIconImageName: String {
        switch appIconName {
        case "Argus-3D-Black": return "Argus-3D-Black-Preview"
        case "Argus-100-eyes": return "Argus-100-eyes-Preview"
        case "pmdb-flat":      return "pmdb-flat-Preview"
        case "pmdb-3D":        return "pmdb-3D-Preview"
        default:               return "Argus-flat-Preview"
        }
    }
}

struct ShareImageRenderView: View {
    let data: ShareMediaData
    
    var body: some View {
        ZStack {
            // ── Background ──
            if let bg = data.background {
                Image(uiImage: bg)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 1080, height: 1920)
                    .clipped()
            } else {
                Color.black.frame(width: 1080, height: 1920)
            }
            
            // ── Gradient (bottom → top) ──
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.15), location: 0.15),
                        .init(color: .black.opacity(0.6), location: 0.4),
                        .init(color: .black.opacity(0.88), location: 0.65),
                        .init(color: .black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 1200)
            }
            
            // ── Top bar: Network (left) + Status (right) ──
            VStack {
                HStack(alignment: .center) {
                    if let network = data.network {
                        Image(uiImage: network.withRenderingMode(.alwaysTemplate))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 70)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                            .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    
                    Spacer()
                    
                    if let status = data.showStatus {
                        Text(status)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .tracking(3)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                            .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.top, 80)
                
                // Tagline at the very top (movie poster style)
                if let tagline = data.tagline, !tagline.isEmpty {
                    VStack(spacing: 16) {
                        // Top fading line
                        Rectangle()
                            .fill(LinearGradient(colors: [.clear, .white.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 400, height: 1)
                            .shadow(color: .black, radius: 4, x: 0, y: 0)
                            
                        Text(tagline.uppercased())
                            .font(.system(size: 26, weight: .semibold, design: .serif))
                            .foregroundStyle(.white.opacity(0.95))
                            .tracking(10)
                            .lineSpacing(12)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.8), radius: 20, x: 0, y: 5)
                            .shadow(color: .black, radius: 5, x: 0, y: 0)
                            
                        // Bottom fading line
                        Rectangle()
                            .fill(LinearGradient(colors: [.clear, .white.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 400, height: 1)
                            .shadow(color: .black, radius: 4, x: 0, y: 0)
                    }
                    .padding(.horizontal, 80)
                    .padding(.top, 50)
                }
                
                Spacer()
            }
            
            // ── Main content: pure cinematic typography (no card) ──
            VStack {
                Spacer()
                VStack(spacing: 36) {
                    // Title Logo or serif title
                    if let logo = data.logo {
                        Image(uiImage: logo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 820, height: 320)
                            .shadow(color: .black, radius: 40, x: 0, y: 15)
                    } else {
                        Text(data.title)
                            .font(.system(size: 100, weight: .heavy, design: .serif))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.4)
                            .shadow(color: .black, radius: 30, x: 0, y: 0)
                            .shadow(color: .black.opacity(0.8), radius: 60, x: 0, y: 0)
                    }
                    
                    // Metadata row
                    HStack(spacing: 20) {
                        let components = [
                            data.mediaType == .tv ? "SERIES" : "FILM",
                            data.year,
                            data.runtime,
                            data.contentRating
                        ].compactMap { $0 }.filter { !$0.isEmpty }
                        
                        Text(components.joined(separator: " • "))
                    }
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .tracking(3)
                    .shadow(color: .black, radius: 15, x: 0, y: 0)
                    .padding(.top, 40)
                    
                    // Genres
                    if !data.genres.isEmpty {
                        Text(data.genres.map { $0.uppercased() }.joined(separator: "  ·  "))
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .tracking(2)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black, radius: 12, x: 0, y: 0)
                    }
                    
                    // Rating
                    if let ratingValue = data.displayRatingValue, let ratingTitle = data.displayRatingTitle {
                        VStack(spacing: 10) {
                            Text(ratingTitle)
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .foregroundStyle(.white.opacity(0.85))
                                .tracking(3)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.black.opacity(0.35)))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                                .shadow(color: .black, radius: 10, x: 0, y: 0)
                            HStack(spacing: 10) {
                                Image(systemName: "star.fill").foregroundStyle(.yellow)
                                Text("\(ratingValue)")
                            }
                            .font(.system(size: 80, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black, radius: 20, x: 0, y: 5)
                        }
                    }
                    
                    // Director / Creator
                    if let director = data.directorName {
                        (Text(data.isDirector ? "DIRECTED BY  " : "CREATED BY  ")
                            .font(.system(size: 22, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                         + Text(director.uppercased())
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75)))
                        .tracking(2)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black, radius: 10, x: 0, y: 0)
                    }
                    
                    // Watch status
                    if data.mediaType == .movie {
                        if data.watchedCount > 0 {
                            Text(data.watchedCount == 1 ? "WATCHED" : "WATCHED \(String(data.watchedCount))×")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .tracking(4)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                                .padding(.top, 16)
                        }
                    } else if data.watchedEpisodes > 0 {
                        Text("WATCHED \(String(data.watchedEpisodes)) OF \(String(data.totalEpisodes)) EPISODES")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .tracking(4)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                            .padding(.top, 16)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
                .padding(.bottom, 200)
            }
            
            // ── via Argus — bottom right ──
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 14) {
                        Image(data.appIconImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 3)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("via")
                                .font(.system(size: 32, weight: .light, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                                .shadow(color: .black, radius: 8, x: 0, y: 0)
                            Text("Argus")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                                .shadow(color: .black, radius: 8, x: 0, y: 0)
                        }
                    }
                    .padding(.trailing, 60)
                    .padding(.bottom, 80)
                }
            }
        }
        .frame(width: 1080, height: 1920)
        .overlay(
            Rectangle()
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 3)
        )
        .environment(\.colorScheme, .dark)
    }
}

struct SharePreviewSheet: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var showActivityView = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background blur of the image itself for a cinematic feel
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .blur(radius: 60)
                    .overlay(Color.black.opacity(0.4))
                
                VStack(spacing: 32) {
                    Spacer().frame(height: 20)
                
                // Image Preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 20)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                // Share Button
                Button {
                    showActivityView = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .bold))
                        Text("Share Image")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        ZStack {
                            Capsule().fill(.ultraThinMaterial)
                            Capsule().fill(Color.white.opacity(0.1))
                        }
                    )
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1.5))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showActivityView) {
            ActivityViewController(activityItems: [image])
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}
