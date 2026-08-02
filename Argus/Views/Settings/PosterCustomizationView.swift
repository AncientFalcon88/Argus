import SwiftUI

struct PosterCustomizationView: View {
    @State private var items: [PreviewItem] = []
    @State private var isLoading = true
    @State private var showPerformanceAlert = false
    
    // Toggles
    @AppStorage("posterBadgeEnabled") private var posterBadgeEnabled = true
    @AppStorage("posterRatingEnabled") private var posterRatingEnabled = true
    @AppStorage("posterGenreEnabled") private var posterGenreEnabled = true
    @AppStorage("posterTitleEnabled") private var posterTitleEnabled = false
    @AppStorage("posterGlassStyle") private var posterGlassStyle = "dark"
    
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    var body: some View {
        ZStack {
            // Background
            GlassTheme.background.ignoresSafeArea()
            
            // Blurred glowing aura
            Circle()
                .fill(Color(hex: "00C9FF").opacity(0.15))
                .blur(radius: 100)
                .frame(width: 300, height: 300)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(Color(hex: "92FE9D").opacity(0.15))
                .blur(radius: 100)
                .frame(width: 300, height: 300)
                .offset(x: 100, y: 200)
                
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {

                    
                    // 2x2 Preview Grid
                    if isLoading {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(0..<4, id: \.self) { _ in
                                VStack(spacing: 8) {
                                    ShimmerView()
                                        .frame(width: 160, height: 240)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                        )
                                    ShimmerView()
                                        .frame(width: 120, height: 16)
                                        .cornerRadius(4)
                                        .frame(width: 160, height: 40, alignment: .top)
                                        .opacity(posterTitleEnabled ? 1 : 0)
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                        .padding(.horizontal, 20)
                    } else {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(items) { item in
                                PreviewPosterCard(
                                    title: item.title,
                                    posterURL: item.posterURL,
                                    cleanPosterURL: item.cleanPosterURL,
                                    logoURL: item.logoURL,
                                    mediaType: item.mediaType,
                                    voteAverage: item.voteAverage,
                                    genreName: item.genreName,
                                    badgeText: item.badgeText,
                                    year: item.year
                                )
                                .transition(.scale(scale: 0.95).combined(with: .opacity))
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Premium Control Panel
                    VStack(spacing: 0) {
                        Text("POSTER UI")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .kerning(1.5)
                            .foregroundStyle(Color.white.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                            .padding(.top, 24)
                        
                        VStack(spacing: 0) {
                            GlassToggleRow(icon: "tag.fill", title: "Top Badge (Movie/Series)", isOn: $posterBadgeEnabled)
                            Divider().background(Color.white.opacity(0.1)).padding(.leading, 52)
                            GlassToggleRow(icon: "star.fill", title: "Rating Pill", isOn: $posterRatingEnabled)
                            Divider().background(Color.white.opacity(0.1)).padding(.leading, 52)
                            GlassToggleRow(icon: "theatermasks.fill", title: "Main Genre", isOn: $posterGenreEnabled)
                            Divider().background(Color.white.opacity(0.1)).padding(.leading, 52)
                            GlassToggleRow(icon: "text.aligncenter", title: "Title Name", isOn: $posterTitleEnabled)
                        }
                        .tint(.blue)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                        .padding(.horizontal, 20)
                        
                        // Style Picker
                        Text("BADGE & PILL STYLE")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .kerning(1.5)
                            .foregroundStyle(Color.white.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                            .padding(.top, 24)
                        
                        VStack(spacing: 0) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    styleButton(title: "Dark", value: "dark", color: .black)
                                    styleButton(title: "Gray", value: "gray", color: .gray)
                                    styleButton(title: "Dynamic", value: "dynamic", color: .clear, isGradient: true)
                                    styleButton(title: "Glass", value: "glass", color: .clear)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                        .padding(.horizontal, 20)
                        
                        // Restore Defaults Button
                        Button(action: restoreDefaults) {
                            Text("Restore Defaults")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.red.opacity(0.8))
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationTitle("Poster Style")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Performance Warning", isPresented: $showPerformanceAlert) {
            Button("I Understand", role: .cancel) { }
        } message: {
            Text("The Glass style uses real-time dynamic blurs. Applying this to dozens of posters in a grid requires a powerful GPU and may cause scrolling to drop frames. If you experience lag, please switch to Dark, Gray, or Dynamic.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { isLoading = true }
                    Task { await fetchRandomPosters() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .bold))
                }
            }
        }
        .task {
            if items.isEmpty {
                await fetchRandomPosters()
            }
        }
    }
    
    private func styleButton(title: String, value: String, color: Color, isGradient: Bool = false) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            let previousValue = posterGlassStyle
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                posterGlassStyle = value
            }
            if value == "glass" && previousValue != "glass" {
                showPerformanceAlert = true
            }
        } label: {
            HStack(spacing: 8) {
                if isGradient {
                    Circle()
                        .fill(LinearGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))
                } else {
                    Circle()
                        .fill(value == "accent" ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "00C9FF"), Color(hex: "92FE9D")], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(color))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(posterGlassStyle == value ? .white : .white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(posterGlassStyle == value ? Color.white.opacity(0.1) : Color.black.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(posterGlassStyle == value ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
    }
    
    private func restoreDefaults() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation {
            posterBadgeEnabled = true
            posterRatingEnabled = true
            posterGenreEnabled = true
            posterTitleEnabled = false
            posterGlassStyle = "dark"
        }
    }
    
    private func fetchRandomPosters() async {
        isLoading = true
        let tmdbKey = Config.tmdbAPIKey
        guard let url = URL(string: "https://api.themoviedb.org/3/trending/all/day?api_key=\(tmdbKey)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder().decode(PreviewTrendingResult.self, from: data)
            
            // Shuffle results to get random ones
            let shuffled = result.results.shuffled()
            
            // Filter to ones with a rating and poster
            let validItems = shuffled.filter { ($0.vote_average ?? 0) > 0 && $0.poster_path != nil }
            let pickedItems = Array(validItems.prefix(4))
            
            // Convert to TMDBMediaItem for metadata fetching
            let tmdbItems = pickedItems.map { item in
                let releaseDate = item.release_date ?? item.first_air_date ?? ""
                let year = String(releaseDate.prefix(4))
                return TMDBMediaItem(
                    id: String(item.id ?? 0),
                    tmdbId: item.id ?? 0,
                    mediaType: item.media_type == "tv" ? .tv : .movie,
                    title: item.title ?? item.name ?? "Unknown",
                    overview: "",
                    year: year,
                    posterPath: item.poster_path,
                    backdropPath: nil, // Don't need for posters
                    voteAverage: item.vote_average ?? 0,
                    voteCount: 0,
                    releaseDate: releaseDate,
                    genreIds: item.genre_ids
                )
            }
            
            let (newRatings, newPosters, newLogos) = await MetadataEnrichmentService.shared.fetchRichMetadata(
                for: tmdbItems,
                pmdbRatings: [:],
                cleanPosters: [:],
                itemLogos: [:]
            )
            
            // Convert to PreviewItem
            var newItems: [PreviewItem] = []
            for tmdbItem in tmdbItems {
                let cleanPoster = newPosters[tmdbItem.tmdbId]
                let logoUrl = newLogos[tmdbItem.tmdbId]
                
                var genreName: String? = nil
                if let firstGenreId = tmdbItem.genreIds?.first {
                    genreName = getGenreName(for: firstGenreId)
                }
                
                let badgeText = await BadgeEngine.getTag(for: tmdbItem)
                let year = String((tmdbItem.releaseDate ?? "").prefix(4))
                
                newItems.append(PreviewItem(
                    id: tmdbItem.tmdbId,
                    title: tmdbItem.title,
                    posterURL: tmdbItem.posterURL,
                    cleanPosterURL: cleanPoster,
                    logoURL: logoUrl,
                    mediaType: tmdbItem.mediaType == .movie ? "movie" : "tv",
                    voteAverage: tmdbItem.voteAverage,
                    genreName: genreName,
                    badgeText: badgeText,
                    year: year
                ))
            }
            
            await MainActor.run {
                self.items = newItems
                self.isLoading = false
            }
        } catch {
            print("Preview fetch error: \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }
    
    private func getGenreName(for id: Int) -> String? {
        let genres: [Int: String] = [
            28: "Action", 12: "Adventure", 16: "Animation", 35: "Comedy",
            80: "Crime", 99: "Documentary", 18: "Drama", 10751: "Family",
            14: "Fantasy", 36: "History", 27: "Horror", 10402: "Music",
            9648: "Mystery", 10749: "Romance", 878: "Sci-Fi", 10770: "TV Movie",
            53: "Thriller", 10752: "War", 37: "Western",
            10759: "Action & Adv", 10762: "Kids", 10763: "News",
            10764: "Reality", 10765: "Sci-Fi & Fantasy", 10766: "Soap",
            10767: "Talk", 10768: "Politics"
        ]
        return genres[id]
    }
}

// MARK: - Custom Glass Toggle Row
struct GlassToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Models
struct PreviewItem: Identifiable {
    let id: Int
    let title: String
    let posterURL: URL?
    let cleanPosterURL: URL?
    let logoURL: URL?
    let mediaType: String
    let voteAverage: Double
    let genreName: String?
    let badgeText: String?
    let year: String
}

private struct PreviewTrendingResult: Codable {
    let results: [PreviewTrendingItem]
}

private struct PreviewTrendingItem: Codable {
    let id: Int?
    let title: String?
    let name: String?
    let poster_path: String?
    let media_type: String?
    let vote_average: Double?
    let release_date: String?
    let first_air_date: String?
    let genre_ids: [Int]?
}
