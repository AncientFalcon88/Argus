import SwiftUI
import SwiftData

struct FavoriteCarouselSection: View {
    let category: FavoriteCategory
    let timePeriod: FavoriteTimePeriod
    let favorites: [FavoriteItem]
    var cleanPosters: [Int: URL] = [:]
    var itemLogos: [Int: URL] = [:]
    
    @Query private var userLists: [CachedMediaList]
    @State private var activeSlotForSearch: Int?
    
    // We only want to display 4 slots for each time period
    let maxSlots = 4
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text(timePeriod.rawValue)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
            
            // 3D Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(0..<maxSlots, id: \.self) { index in
                        let item = favorites.first(where: { $0.slotIndex == index })
                        
                        HeroFavoriteCard(
                            item: item,
                            posters: getPosters(for: item),
                            cleanPosterURL: item != nil ? cleanPosters[item!.tmdbId] : nil,
                            logoURL: item != nil ? itemLogos[item!.tmdbId] : nil,
                            slotIndex: index,
                            isEmpty: item == nil,
                            action: { activeSlotForSearch = index }
                        )
                        // Dynamic 3D Scroll Transition (iOS 17+)
                        .scrollTransition(topLeading: .interactive, bottomTrailing: .interactive) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.6)
                                .scaleEffect(phase.isIdentity ? 1 : 0.85)
                                .rotation3DEffect(.degrees(phase.value * 15), axis: (x: 0, y: 1, z: 0))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .scrollTargetBehavior(.viewAligned)
            .frame(height: 480) // Massive immersive height
        }
        .sheet(item: Binding<IdentifiableInt?>(
            get: { activeSlotForSearch.map { IdentifiableInt(value: $0) } },
            set: { activeSlotForSearch = $0?.value }
        )) { ident in
            FavoriteSearchModal(category: category, timePeriod: timePeriod, slotIndex: ident.value)
        }
    }
    
    private func getPosters(for item: FavoriteItem?) -> [String] {
        guard let item = item else { return [] }
        if item.category == .lists, let listId = item.listId, let foundList = userLists.first(where: { $0.remoteId == listId }) {
            return foundList.posterURLs
        } else if let posterPath = item.posterPath {
            return [posterPath]
        }
        return []
    }
}

struct HeroFavoriteCard: View {
    let item: FavoriteItem?
    let posters: [String]
    var cleanPosterURL: URL? = nil
    var logoURL: URL? = nil
    let slotIndex: Int
    let isEmpty: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isEmpty {
                    // Shimmering Frosted Glass Empty State
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
                        )
                    
                    VStack(spacing: 16) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(.white.opacity(0.5))
                            .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 0)
                        
                        Text("Add to Favorites")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                } else if let item = item {
                    // Filled State with Poster
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color.black)
                    
                    if item.category == .lists && !posters.isEmpty {
                        // --- LISTS MULTI-POSTER DESIGN ---
                        if let firstPath = posters.first {
                            let url: URL? = firstPath.hasPrefix("http") ? URL(string: firstPath) : URL(string: "https://image.tmdb.org/t/p/w780\(firstPath)")
                            if let url {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Color.black
                                    }
                                }
                                .blur(radius: 25)
                                .overlay(Color.black.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                            }
                        }
                        
                        // Fanned Out Cards
                        ZStack {
                            let displayPosters = Array(posters.prefix(4).enumerated())
                            let count = displayPosters.count
                            ForEach(displayPosters, id: \.offset) { i, path in
                                let url: URL? = path.hasPrefix("http") ? URL(string: path) : URL(string: "https://image.tmdb.org/t/p/w342\(path)")
                                
                                let centerOffset = Double(i) - Double(count - 1) / 2.0
                                let rotation = centerOffset * 15.0 // Tilted progressively
                                let offsetX = centerOffset * 50.0 // Wide horizontal spread
                                let offsetY = centerOffset * 30.0 // Deep vertical diagonal spread
                                
                                if let url {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            Color.gray.opacity(0.3)
                                        }
                                    }
                                    .frame(width: 200, height: 300) // HUGE cards
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .rotationEffect(.degrees(rotation))
                                    .offset(x: offsetX, y: offsetY - 10)
                                }
                            }
                        }
                        .frame(width: 280, height: 420) // Match the exact parent container size
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous)) // HARD CROP overflown edges
                    } else {
                        // --- SINGLE POSTER DESIGN ---
                        let hasBothCleanAssets = cleanPosterURL != nil && logoURL != nil
                        let url = (hasBothCleanAssets ? cleanPosterURL : nil) ?? (item.posterPath.flatMap { $0.hasPrefix("http") ? URL(string: $0) : URL(string: "https://image.tmdb.org/t/p/w780\($0)") })
                        if let url {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    ProgressView().tint(.white)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        }
                    }
                    
                    // Dark Gradient at the bottom to make text pop
                    VStack {
                        Spacer()
                        LinearGradient(colors: [.black.opacity(0.9), .clear], startPoint: .bottom, endPoint: .top)
                            .frame(height: item.category == .lists ? 150 : 200)
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    }
                    
                    // Title and Why This One Glass Capsule
                    VStack {
                        Spacer()
                        
                        let hasBothCleanAssets = cleanPosterURL != nil && logoURL != nil
                        if item.category != .lists, hasBothCleanAssets, let logo = logoURL {
                            CachedImage(url: logo, contentMode: .fit) { Color.clear }
                                .frame(maxHeight: 60)
                                .shadow(color: .black.opacity(0.8), radius: 5, x: 0, y: 3)
                                .padding(.horizontal, 16)
                                .padding(.bottom, -4)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            if item.category == .lists {
                                Text(item.title)
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text(item.title)
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                                
                                if !item.reasonText.isEmpty {
                                    Text(item.reasonText)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .lineLimit(3)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(12)
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                // Massive Number Overlay
                Text("\(slotIndex + 1)")
                    .font(.system(size: 100, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(isEmpty ? 0.3 : 0.9))
                    .shadow(color: .black.opacity(0.6), radius: 15, x: 0, y: 10)
                    .padding(.top, -10)
                    .padding(.leading, 10)
            }
            .compositingGroup()
        }
        .buttonStyle(.plain)
        .frame(width: 280, height: 420) // The massive hero card size
        .shadow(color: .black.opacity(isEmpty ? 0.2 : 0.6), radius: 20, x: 0, y: 15)
    }
}

struct IdentifiableInt: Identifiable {
    let value: Int
    var id: Int { value }
}
