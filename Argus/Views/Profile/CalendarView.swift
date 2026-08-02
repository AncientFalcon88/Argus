import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = CalendarViewModel()
    
    var body: some View {
        ZStack {
            AppBackground()
            
            if viewModel.isLoading {
                VStack(spacing: 20) {
                    OrbitLoader(color: .purple, size: 90)
                        .frame(width: 90, height: 90)
                    Text("Syncing Tracked Shows...")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .kerning(0.5)
                        .foregroundStyle(.purple)
                        .shadow(color: .purple.opacity(0.5), radius: 4, x: 0, y: 2)
                }
            } else if viewModel.episodes.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        
                        if !viewModel.upNext.isEmpty {
                            heroCarouselSection(episodes: viewModel.upNext)
                                .padding(.top, -50)
                        }
                        
                        if !viewModel.thisWeek.isEmpty {
                            horizontalCarouselSection(title: "This Week", episodes: viewModel.thisWeek)
                        }
                        
                        if !viewModel.groupedUpcoming.isEmpty || !viewModel.groupedRecentlyAired.isEmpty {
                            listSection
                        }
                        
                    }
                    .padding(.bottom, 60)
                }
                .ignoresSafeArea(edges: .top)
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadCalendar(context: modelContext)
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "tv.slash")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(GlassTheme.secondaryText)
            Text("No Shows Tracked")
                .font(.title2.bold())
                .foregroundStyle(GlassTheme.primaryText)
            Text("Watch or favorite some TV shows to track their upcoming episodes here.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(GlassTheme.secondaryText)
                .padding(.horizontal, 40)
        }
    }
    
    enum CalendarListTab: String, CaseIterable {
        case upcoming = "Upcoming"
        case recentlyAired = "Recently Aired"
    }
    
    @State private var heroScrolledIndex: Int? = 0
    @State private var selectedTab: CalendarListTab = .upcoming
    @State private var selectedMonthId: String = "ALL"
    @Namespace private var animationNamespace
    
    // MARK: - Hero Swiper
    private func heroCarouselSection(episodes: [CalendarEpisode]) -> some View {
        let items = episodes.map { ep in
            CalendarHeroDisplayItem(
                episode: ep,
                seasonEpisodeLabel: viewModel.formatSeasonEpisode(ep),
                countdownLabel: viewModel.countdownText(for: ep.airDate, exactAirtime: ep.exactAirtime)
            )
        }
        return CalendarHeroCarouselView(items: items)
    }
    
    // MARK: - Carousel Section
    private func horizontalCarouselSection(title: String, episodes: [CalendarEpisode]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.weight(.heavy))
                .fontDesign(.rounded)
                .foregroundStyle(GlassTheme.primaryText)
                .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(episodes) { ep in
                        NavigationLink(value: MediaDetailRoute(tmdbId: ep.showId, mediaType: .tv)) {
                            carouselCard(for: ep)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    private func carouselCard(for episode: CalendarEpisode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    if let url = episode.posterURL {
                        CachedImage(url: url) {
                            Rectangle().fill(Color.gray.opacity(0.2))
                        }
                    } else {
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                    
                    // Liquid Glass sheen over the poster
                    LinearGradient(
                        colors: [.white.opacity(0.25), .clear, .clear, .black.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Overlay Badges
                    HStack {
                        if episode.isPremiere {
                            badgePill(text: "PREMIERE", color: .green)
                        }
                        if episode.isFinale {
                            badgePill(text: "FINALE", color: .red)
                        }
                    }
                    .padding(8)
                }
                
                // Top Right Date Pill
                if viewModel.countdownText(for: episode.airDate, exactAirtime: episode.exactAirtime) != "Airing Today" {
                    badgePill(text: viewModel.explicitDateText(for: episode.airDate).uppercased(), color: .purple)
                        .padding(8)
                }
            }
            .frame(width: 140, height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            // Liquid Glass border
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .white.opacity(0.1), .clear, .white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 5)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.countdownText(for: episode.airDate, exactAirtime: episode.exactAirtime).uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.purple)
                    .lineLimit(1)
                
                Text(episode.showTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
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
                
                Text(viewModel.formatSeasonEpisode(episode))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(GlassTheme.secondaryText)
            }
            .frame(width: 140, alignment: .leading)
        }
    }
    
    // MARK: - List Section (Tabs + Picker + Content)
    @ViewBuilder
    private var listSection: some View {
        VStack(spacing: 24) {
            // 1. Determine active groups
            let activeGroups = selectedTab == .upcoming ? viewModel.groupedUpcoming : viewModel.groupedRecentlyAired
            
            // 2. Main Tabs (Large Hierarchy)
            HStack(spacing: 0) {
                ForEach(CalendarListTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.5))
                        .background {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(.white.opacity(0.15))
                                    .matchedGeometryEffect(id: "LIST_TAB_PILL", in: animationNamespace)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedTab = tab
                                selectedMonthId = "ALL"
                            }
                        }
                }
            }
            .padding(6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .zIndex(10)
            
            // 3. Render Content
            let filteredGroups = selectedMonthId == "ALL" ? activeGroups : activeGroups.filter { $0.id == selectedMonthId }
            
            if filteredGroups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundStyle(GlassTheme.secondaryText)
                    Text("No episodes found.")
                        .font(.headline)
                        .foregroundStyle(GlassTheme.secondaryText)
                }
                .padding(.top, 40)
            } else {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(Array(filteredGroups.enumerated()), id: \.element.id) { index, group in
                        Section(header: stickyHeader(title: group.monthYearLabel, activeGroups: activeGroups, showPicker: index == 0)) {
                            VStack(spacing: 12) {
                                ForEach(group.episodes) { ep in
                                    MediaDetailLink(route: MediaDetailRoute(tmdbId: ep.showId, mediaType: .tv)) {
                                        listRow(for: ep)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.trailing, 16)
                            .padding(.leading, 36)
                            .padding(.bottom, 24)
                            .overlay(
                                Rectangle()
                                    .fill(LinearGradient(
                                        stops: [
                                            .init(color: .white.opacity(0.25), location: 0.0),
                                            .init(color: .white.opacity(0.25), location: 0.5),
                                            .init(color: .clear, location: 1.0)
                                        ],
                                        startPoint: .top, endPoint: .bottom
                                    ))
                                    .frame(width: 2)
                                    .padding(.leading, 19)
                                    .padding(.top, 2),
                                alignment: .leading
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func stickyHeader(title: String, activeGroups: [CalendarMonthGroup], showPicker: Bool) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 8, height: 8)
                .shadow(color: .white, radius: 4, x: 0, y: 0)
            
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            
            Spacer()
            
            if showPicker && !activeGroups.isEmpty {
                Menu {
                    Button("All Months") { selectedMonthId = "ALL" }
                    ForEach(activeGroups) { group in
                        Button(group.monthYearLabel) { selectedMonthId = group.id }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedMonthId == "ALL" ? "All Months" : (activeGroups.first(where: { $0.id == selectedMonthId })?.monthYearLabel ?? "All Months"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AnyShapeStyle(.ultraThinMaterial))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
    }
    
    private func listRow(for episode: CalendarEpisode) -> some View {
        HStack(spacing: 16) {
            if let url = episode.posterURL {
                CachedImage(url: url) {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 64, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(episode.showTitle)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                
                Text(viewModel.formatSeasonEpisode(episode))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                
                Text(episode.episodeTitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if episode.isPremiere {
                            badgePill(text: "PREMIERE", color: .green)
                        }
                        if episode.isFinale {
                            badgePill(text: "FINALE", color: .red)
                        }
                        
                        Text(viewModel.countdownText(for: episode.airDate, exactAirtime: episode.exactAirtime).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AnyShapeStyle(.ultraThinMaterial)))
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Trailing Date Pill
            if viewModel.countdownText(for: episode.airDate, exactAirtime: episode.exactAirtime) != "Airing Today" {
                VStack {
                    badgePill(text: viewModel.explicitDateText(for: episode.airDate).uppercased(), color: .purple)
                    Spacer()
                }
            }
        }
        .padding(12)
        .background {
            ZStack {
                if let url = episode.posterURL {
                    CachedImage(url: url) {
                        Color.clear
                    }
                    .blur(radius: 40)
                    .opacity(1.0)
                }
                Color.black.opacity(0.2)
                Rectangle()
                    .fill(AnyShapeStyle(.ultraThinMaterial))
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Helpers
    private func badgePill(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.6))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(color.opacity(0.8), lineWidth: 1)
            )
    }
}




// MARK: - Calendar Hero Display Item
struct CalendarHeroDisplayItem: Identifiable, Equatable {
    let episode: CalendarEpisode
    let seasonEpisodeLabel: String
    let countdownLabel: String
    var id: String { "hero-\(episode.id)" }
}

// MARK: - Calendar Hero Carousel View
private struct CalendarHeroCarouselView: View {
    let items: [CalendarHeroDisplayItem]
    @State private var heroScrolledIndex: Int? = 0
    
    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            GeometryReader { geo in
                let minY = geo.frame(in: .global).minY
                let isScrollingDown = minY > 0
                let offset = isScrollingDown ? -minY : 0
                let height = UIScreen.main.bounds.width * 1.5 + (isScrollingDown ? minY : 0)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(items) { item in
                            let index = items.firstIndex(of: item) ?? 0
                            MediaDetailLink(route: MediaDetailRoute(tmdbId: item.episode.showId, mediaType: .tv)) {
                                CalendarHeroCardNew(item: item, isFirst: index == 0, isLast: index == items.count - 1)
                            }
                            .containerRelativeFrame(.horizontal)
                            .buttonStyle(.plain)
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $heroScrolledIndex)
                .frame(width: geo.size.width, height: height)
                .offset(y: offset)
                .overlay(alignment: .bottom) {
                    if items.count > 1 {
                        LiquidGlassPageIndicator(numberOfPages: items.count, currentIndex: heroScrolledIndex ?? 0)
                            .padding(.bottom, 8)
                            .offset(y: offset)
                    }
                }
            }
            .frame(height: UIScreen.main.bounds.width * 1.5)
        }
    }
}

// MARK: - Calendar Hero Card
private struct CalendarHeroCardNew: View {
    let item: CalendarHeroDisplayItem
    let isFirst: Bool
    let isLast: Bool
    
    var body: some View {
        GeometryReader { geo in
            let globalFrame = geo.frame(in: .global)
            let minX = globalFrame.minX
            let screenWidth = UIScreen.main.bounds.width
            
            let isStretchingLeft = isFirst && minX > 0
            let isStretchingRight = isLast && globalFrame.maxX < screenWidth
            
            let extraWidth = isStretchingLeft ? minX : (isStretchingRight ? screenWidth - globalFrame.maxX : 0)
            let xOffset = isStretchingLeft ? -minX / 2 : (isStretchingRight ? extraWidth / 2 : 0)
            
            ZStack(alignment: .bottom) {
                // Background Poster
                CachedImage(url: item.episode.textlessPosterURL ?? item.episode.posterURL) {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width + extraWidth, height: geo.size.height)
                .clipped()
                .offset(x: xOffset)
                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                    content
                        .scaleEffect(1.0 - abs(phase.value) * 0.15)
                        .rotation3DEffect(.degrees(phase.value * -20), axis: (x: 0, y: 1, z: 0))
                        .offset(x: phase.value * -50, y: abs(phase.value) * 15)
                        .blur(radius: abs(phase.value) * 2)
                }
                
                // Frosted Liquid Glass Blur behind the black gradient
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black, .black, .black]),
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: geo.size.width + extraWidth, height: geo.size.height)
                    .offset(x: xOffset, y: 30)
                    .allowsHitTesting(false)
                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                        content
                            .scaleEffect(1.0 - abs(phase.value) * 0.15)
                            .rotation3DEffect(.degrees(phase.value * -20), axis: (x: 0, y: 1, z: 0))
                            .offset(x: phase.value * -50, y: abs(phase.value) * 15)
                    }

                // Gradients for text legibility
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.3), .black.opacity(0.8), .black.opacity(1.0)]),
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width + extraWidth, height: geo.size.height)
                .offset(x: xOffset, y: 30)
                .allowsHitTesting(false)
                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                    content
                        .scaleEffect(1.0 - abs(phase.value) * 0.15)
                        .rotation3DEffect(.degrees(phase.value * -20), axis: (x: 0, y: 1, z: 0))
                        .offset(x: phase.value * -50, y: abs(phase.value) * 15)
                }
                
                VStack(spacing: 12) {
                    // Logo or Title
                    if let logoURL = item.episode.logoURL {
                        CachedImage(url: logoURL) {
                            Text(item.episode.showTitle)
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geo.size.width * 0.7, maxHeight: 100)
                        .padding(.bottom, 8)
                    } else {
                        Text(item.episode.showTitle)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.bottom, 8)
                    }
                    
                    // Info Pills
                    HStack(spacing: 10) {
                        Text(item.seasonEpisodeLabel.uppercased())
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.6))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.purple.opacity(0.8), lineWidth: 1.5))
                        
                        Text(item.episode.episodeTitle)
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .italic()
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
                }
                .frame(width: geo.size.width)
                .padding(.bottom, 40) // Space so indicator does not overlap text
                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                    content
                        .offset(x: phase.value * UIScreen.main.bounds.width * 0.8)
                        .opacity(1.0 - abs(phase.value) * 2)
                }
                
                // Top Right Date Pill & Badges
                VStack {
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) {
                            Text(item.countdownLabel)
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                            
                            if item.episode.isPremiere {
                                Text("PREMIERE")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.green.opacity(0.4).background(.ultraThinMaterial))
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                            }
                            if item.episode.isFinale {
                                Text("FINALE")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.4).background(.ultraThinMaterial))
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                            }
                        }
                        .padding(.top, 160)
                        .padding(.trailing, 16)
                    }
                    Spacer()
                }
                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                    content
                        .offset(x: phase.value * UIScreen.main.bounds.width * 0.5)
                        .opacity(1.0 - abs(phase.value) * 1.5)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
    
    private func badgePill(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.6))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(color.opacity(0.8), lineWidth: 1)
            )
    }
}
