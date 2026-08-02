import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Query private var allFavorites: [FavoriteItem]
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedCategory: FavoriteCategory = .films
    
    var body: some View {
        ZStack {
            // Immersive background
            AppBackground()
            
            // Abstract floating orbs to make it liquid glass premium
            Circle()
                .fill(Color.yellow.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(Color(red: 0.7, green: 0.5, blue: 0.0).opacity(0.22)) // Dark Yellow / Gold
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: 150, y: 300)
            
            VStack(spacing: 0) {
                // Custom Animated Pill Picker
                HStack {
                    ForEach([FavoriteCategory.films, .shows, .lists], id: \.self) { category in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedCategory = category
                            }
                        } label: {
                            Text(category.rawValue)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .foregroundStyle(selectedCategory == category ? .white : .white.opacity(0.5))
                                .background {
                                    if selectedCategory == category {
                                        Capsule()
                                            .fill(.white.opacity(0.15))
                                            .matchedGeometryEffect(id: "CATEGORY_PILL", in: animationNamespace)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                // TabView for horizontal swiping between Categories
                TabView(selection: $selectedCategory) {
                    CategoryScrollView(category: .films, favorites: allFavorites)
                        .tag(FavoriteCategory.films)
                    
                    CategoryScrollView(category: .shows, favorites: allFavorites)
                        .tag(FavoriteCategory.shows)
                    
                    CategoryScrollView(category: .lists, favorites: allFavorites)
                        .tag(FavoriteCategory.lists)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @Namespace private var animationNamespace
}

struct CategoryScrollView: View {
    let category: FavoriteCategory
    let favorites: [FavoriteItem]
    
    @State private var cleanPosters: [Int: URL] = [:]
    @State private var itemLogos: [Int: URL] = [:]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 50) {
                FavoriteCarouselSection(
                    category: category,
                    timePeriod: .allTime,
                    favorites: favorites.filter { $0.category == category && $0.timePeriod == .allTime },
                    cleanPosters: cleanPosters,
                    itemLogos: itemLogos
                )
                
                FavoriteCarouselSection(
                    category: category,
                    timePeriod: .thisYear,
                    favorites: favorites.filter { $0.category == category && $0.timePeriod == .thisYear },
                    cleanPosters: cleanPosters,
                    itemLogos: itemLogos
                )
                
                FavoriteCarouselSection(
                    category: category,
                    timePeriod: .thisMonth,
                    favorites: favorites.filter { $0.category == category && $0.timePeriod == .thisMonth },
                    cleanPosters: cleanPosters,
                    itemLogos: itemLogos
                )
            }
            .padding(.bottom, 80)
        }
        .task(id: favorites) {
            if category == .lists { return }
            let itemsToFetch = favorites.filter { $0.category == category }
                .map { TMDBMediaItem(id: "\(category.rawValue)-\($0.tmdbId)", tmdbId: $0.tmdbId, mediaType: category == .films ? .movie : .tv, title: $0.title, overview: "", year: "", posterPath: $0.posterPath, backdropPath: nil, voteAverage: 0.0, voteCount: 0) }
            
            let metadata = await MetadataEnrichmentService.shared.fetchRichMetadata(
                for: itemsToFetch,
                pmdbRatings: [:],
                cleanPosters: cleanPosters,
                itemLogos: itemLogos
            )
            cleanPosters.merge(metadata.posters) { current, _ in current }
            itemLogos.merge(metadata.logos) { current, _ in current }
        }
    }
}
