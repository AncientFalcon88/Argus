import SwiftUI

// MARK: - Shared Helpers

struct SectionHeaderLabel: View {
    let symbol: String
    let title: String
    var hasBackground: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            if hasBackground {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.gray)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text(title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

private struct DetailGlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    @ViewBuilder let content: () -> Content

    init(cornerRadius: CGFloat = 20, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .background(Color(white: 0.1).opacity(0.5))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
    }
}

// MARK: - 1. Watch Providers Section

// MARK: - 1. Where to Watch Section

// MARK: - 1. Where to Watch Section

struct LiquidGlassWatchProvidersSection: View {
    let providers: WatchProviderInfo
    let link: String?
    @Environment(\.openURL) private var openURL
    private let horizontalPadding: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionHeaderLabel(symbol: "play.tv.fill", title: "Where to Watch")
                }
                Spacer()
                if let linkStr = link, let url = URL(string: linkStr) {
                    Button {
                        openURL(url)
                    } label: {
                        HStack(spacing: 4) {
                            Text("JustWatch")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, horizontalPadding)

            // Horizontal Glowing Glass Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    if !providers.streaming.isEmpty {
                        LiquidGlassCategoryCard(title: "STREAM", icon: "play.fill", tint: .green, entries: providers.streaming)
                    }
                    if !providers.free.isEmpty {
                        LiquidGlassCategoryCard(title: "FREE", icon: "gift.fill", tint: .mint, entries: providers.free)
                    }
                    if !providers.rent.isEmpty {
                        LiquidGlassCategoryCard(title: "RENT", icon: "clock.fill", tint: .orange, entries: providers.rent)
                    }
                    if !providers.buy.isEmpty {
                        LiquidGlassCategoryCard(title: "BUY", icon: "bag.fill", tint: .blue, entries: providers.buy)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 24)
                .padding(.top, 8)
            }
        }
    }
}

private struct LiquidGlassCategoryCard: View {
    let title: String
    let icon: String
    let tint: Color
    let entries: [WatchProviderEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                Text(title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(tint)
            .shadow(color: tint.opacity(0.5), radius: 8, y: 2)

            // List of providers
            HStack(spacing: 16) {
                ForEach(entries) { provider in
                    providerIcon(provider)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(tint.opacity(0.08)) // Subtle tint bleed
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(LinearGradient(colors: [tint.opacity(0.5), tint.opacity(0.0)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        )
        .shadow(color: tint.opacity(0.15), radius: 15, y: 8)
    }

    @ViewBuilder
    private func providerIcon(_ provider: WatchProviderEntry) -> some View {
        Group {
            if let url = provider.logoURL {
                CachedImage(url: url) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                }
                .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        Text(String(provider.name.prefix(2)).uppercased())
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.0)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        .accessibilityLabel(provider.name)
    }
}

// MARK: - 2. Next Episode Card

struct NextEpisodeCard: View {
    let episode: NextEpisodeInfo
    private let horizontalPadding: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderLabel(symbol: "calendar.badge.clock", title: "Up Next")
                .padding(.horizontal, horizontalPadding)

            ZStack {
                // Ambient backing color bleed
                LinearGradient(
                    colors: [Color.indigo.opacity(0.4), Color.blue.opacity(0.2), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 40)
                
                // Deep Glass Background
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                
                // Luminous Edge Border
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .white.opacity(0.1), .white.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                HStack(spacing: 20) {
                    // Countdown Circle
                    if let days = episode.daysUntilAir {
                        ZStack {
                            Circle()
                                .fill(days <= 3 && days >= 0 ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                                .frame(width: 72, height: 72)
                            
                            Circle()
                                .stroke(days <= 3 && days >= 0 ? Color.green.opacity(0.6) : Color.white.opacity(0.25), lineWidth: 2)
                                .frame(width: 72, height: 72)
                                .shadow(color: days <= 3 && days >= 0 ? Color.green.opacity(0.4) : .clear, radius: 8)
                            
                            if days == 0 {
                                Text("TODAY")
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.green)
                            } else if days < 0 {
                                Image(systemName: "checkmark")
                                    .font(.title.weight(.heavy))
                                    .foregroundStyle(.green)
                            } else {
                                VStack(spacing: -2) {
                                    Text("\(days)")
                                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(days == 1 ? "DAY" : "DAYS")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Season/Episode Pill
                        Text("S\(String(format: "%02d", episode.seasonNumber)) E\(String(format: "%02d", episode.episodeNumber))")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white.opacity(0.15)))
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                        
                        Text(episode.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        
                        HStack(spacing: 5) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(episode.formattedAirDate)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(20)
            }
            .padding(.horizontal, horizontalPadding)
            .shadow(color: .black.opacity(0.25), radius: 15, y: 8)
        }
    }
}

// MARK: - 3. Filtered Credits Section

struct FilteredCreditsSection: View {
    let departmentGroups: [DepartmentGroup]
    @State private var selectedDepartment: String = "Cast"
    @Namespace private var tabNamespace

    init(departmentGroups: [DepartmentGroup]) {
        self.departmentGroups = departmentGroups
        if !departmentGroups.isEmpty {
            self._selectedDepartment = State(initialValue: departmentGroups[0].department)
        }
    }

    var currentGroup: DepartmentGroup? {
        departmentGroups.first(where: { $0.department == selectedDepartment })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Department Pills ScrollView
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(departmentGroups) { group in
                        let isSelected = selectedDepartment == group.department
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedDepartment = group.department
                            }
                        } label: {
                            Text(group.department)
                                .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                                .foregroundStyle(isSelected ? .black : .gray)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background {
                                    if isSelected {
                                        Capsule()
                                            .fill(.white)
                                            .matchedGeometryEffect(id: "DepartmentTab", in: tabNamespace)
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
                .compositingGroup()
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 16)
            }

            // Credits Horizontal ScrollView
            if let group = currentGroup {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) { // Spacing is smaller because the box includes padding for depth
                        ForEach(group.members) { member in
                            PersonDetailLink(route: PersonDetailRoute(personId: member.id, name: member.name)) {
                                Glass3DBox(width: 120, height: 200, depth: 8) {
                                    VStack(spacing: 0) {
                                        // Image
                                        Group {
                                            if let url = member.profileURL {
                                                CachedImage(url: url) { Color(white: 0.15) }
                                            } else {
                                                Color(white: 0.15)
                                                    .overlay(Image(systemName: "person.fill").font(.largeTitle).foregroundStyle(.gray.opacity(0.5)))
                                            }
                                        }
                                        .scaledToFill()
                                        .frame(width: 120, height: 148)
                                        .clipped()
                                        
                                        // Text Area
                                        ZStack(alignment: .leading) {
                                            Rectangle()
                                                .fill(Color(white: 0.1))
                                            
                                            Rectangle()
                                                .fill(.ultraThinMaterial)
                                                .environment(\.colorScheme, .dark)
                                            
                                            // Text Content
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(member.name)
                                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                                    .foregroundStyle(.white)
                                                    .lineLimit(2)
                                                    .minimumScaleFactor(0.8)

                                                Text(member.character.isEmpty ? "—" : member.character)
                                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                                    .foregroundStyle(.white.opacity(0.8))
                                                    .lineLimit(2)
                                                    .minimumScaleFactor(0.8)
                                            }
                                            .padding(.horizontal, 8)
                                        }
                                        .frame(height: 52)
                                        .frame(maxWidth: .infinity)
                                    }
                                    .overlay(
                                        // Sheen over everything
                                        LinearGradient(
                                            stops: [
                                                .init(color: .white.opacity(0.3), location: 0.0),
                                                .init(color: .clear, location: 0.4),
                                                .init(color: .black.opacity(0.3), location: 1.0)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                } background: {
                                    Group {
                                        if let url = member.profileURL {
                                            CachedImage(url: url) { Color(white: 0.15) }
                                        } else {
                                            Color(white: 0.15)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .id("\(group.department)-\(member.id)")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .padding(.top, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
    }
}

// MARK: - 5. Video Gallery Section

struct VideoGallerySection: View {
    let videos: [VideoItem]
    @Environment(\.openURL) private var openURL
    private let horizontalPadding: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderLabel(symbol: "film.stack", title: "Videos")
                .padding(.horizontal, horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(videos) { video in
                        VideoThumbCard(video: video) {
                            if let url = video.youtubeURL {
                                openURL(url)
                            }
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 4)
            }
        }
    }
}

private struct VideoThumbCard: View {
    let video: VideoItem
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                // Thumbnail
                Group {
                    if let url = video.thumbnailURL {
                        CachedImage(url: url) {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(white: 0.14))
                        }
                        .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(white: 0.14))
                    }
                }
                .frame(width: 200, height: 112)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Gradient overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Play button center
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Type badge + title
                VStack(alignment: .leading, spacing: 3) {
                    Text(video.typeBadge)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.15))
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 5))

                    Text(video.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
            }
            .frame(width: 200, height: 112)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - 6. Collection Carousel Section

struct CollectionCarouselSection: View {
    let collectionName: String
    let movies: [TMDBMediaItem]
    let pmdbRatings: [Int: Int]
    let itemLogos: [Int: URL]
    let cleanPosters: [Int: URL]
    private let horizontalPadding: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderLabel(symbol: "rectangle.stack.fill", title: collectionName)
                .padding(.horizontal, horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(movies) { item in
                        MediaDetailLink(route: MediaDetailRoute(item: item)) {
                            KnownForCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 4)
            }
        }
    }
}

// MARK: - Liquid Glass Details Section

struct LiquidGlassDetailsSection: View {
    let detail: MediaDetailInfo
    private let horizontalPadding: CGFloat = 16

    private func formatMoney(_ value: Int) -> String {
        let d = Double(value)
        if d >= 1_000_000_000 {
            return String(format: "$%.1fB", d / 1_000_000_000)
        } else if d >= 1_000_000 {
            return String(format: "$%.1fM", d / 1_000_000)
        } else if d >= 1_000 {
            return String(format: "$%.0fK", d / 1_000)
        }
        return "$\(value)"
    }
    
    private func flagEmoji(for code: String) -> String {
        code.unicodeScalars
            .compactMap { Unicode.Scalar(127397 + $0.value) }
            .reduce("") { String($0) + String($1) }
    }

    private var languageLabel: String? {
        guard let lang = detail.originalLanguage else { return nil }
        let locale = Locale(identifier: "en_US")
        return locale.localizedString(forLanguageCode: lang)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderLabel(symbol: "info.square.fill", title: detail.mediaType == .movie ? "Details & Finances" : "Details")
                .padding(.horizontal, horizontalPadding)

            // Main Liquid Glass Container
            ZStack {
                // Ambient backing color bleed
                LinearGradient(
                    colors: [Color.indigo.opacity(0.3), Color.blue.opacity(0.2), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 40)
                
                // Deep Glass Background
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                
                // Luminous Edge Border
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .white.opacity(0.1), .white.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                
                // Content Stack
                VStack(spacing: 20) {
                    
                    // 1. Info Tiles Grid (Status, Year, Runtime, Cert)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        infoTile(title: "STATUS", value: detail.status?.uppercased() ?? "—")
                        infoTile(title: "RELEASE", value: (!detail.year.isEmpty && detail.year != "—") ? detail.year : "—")
                        infoTile(title: "RUNTIME", value: {
                            guard let r = detail.runtimeLabel, !r.isEmpty else { return "—" }
                            return detail.mediaType == .tv ? "\(r) / ep" : r
                        }())
                        infoTile(title: "RATING", value: detail.certification?.uppercased() ?? "—")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    // 2. Financial Tiles Grid
                    if detail.mediaType == .movie {
                        VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            financialTile(
                                title: "BUDGET",
                                value: (detail.budget ?? 0) > 0 ? formatMoney(detail.budget ?? 0) : "—",
                                gradient: LinearGradient(colors: [.gray.opacity(0.8), .white], startPoint: .top, endPoint: .bottom)
                            )
                            financialTile(
                                title: "REVENUE",
                                value: (detail.revenue ?? 0) > 0 ? formatMoney(detail.revenue ?? 0) : "—",
                                gradient: LinearGradient(colors: [.green.opacity(0.8), .mint], startPoint: .top, endPoint: .bottom)
                            )
                        }
                        
                        let budget = detail.budget ?? 0
                        let revenue = detail.revenue ?? 0
                        if budget > 0 && revenue > 0 {
                            let profit = revenue - budget
                            let isProfit = profit >= 0
                            let roiPercent = Int((Double(profit) / Double(budget)) * 100)
                            
                            HStack(spacing: 12) {
                                    Image(systemName: isProfit ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(isProfit ? .green : .red)
                                    Text(isProfit ? "PROFIT" : "LOSS")
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .foregroundStyle(isProfit ? .green : .red)
                                        .tracking(1.0)
                                    Text(formatMoney(abs(profit)))
                                        .font(.system(size: 16, weight: .black, design: .rounded))
                                        .foregroundStyle(isProfit ? .green : .red)
                                    Spacer()
                                    Text("ROI \(roiPercent > 0 ? "+" : "")\(roiPercent)%")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(roiPercent >= 0 ? .green : .red)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background((roiPercent >= 0 ? Color.green : Color.red).opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(Color.black.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // 3. Recessed Plaque (Production & Origin)
                    let networks = detail.networkItems
                    let countries = detail.originCountry ?? []
                    
                    VStack(alignment: .leading, spacing: 12) {
                        if !networks.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(networks) { network in
                                        Group {
                                            if let url = network.logoURL {
                                                CachedImage(url: url) { Color.clear }
                                                    .scaledToFit()
                                                    .frame(height: 20)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 8)
                                                    .background(Color.white)
                                                    .clipShape(Capsule())
                                            } else {
                                                Text(network.name)
                                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 10)
                                                    .background(Color.black.opacity(0.3))
                                                    .clipShape(Capsule())
                                                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            originTile(
                                title: "COUNTRY",
                                value: !countries.isEmpty ? (Locale(identifier: "en_US").localizedString(forRegionCode: countries[0]) ?? countries[0]) : "—",
                                backgroundText: !countries.isEmpty ? flagEmoji(for: countries[0]) : nil
                            )
                            originTile(
                                title: "LANGUAGE",
                                value: languageLabel ?? "—",
                                backgroundText: nil
                            )
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.black.opacity(0.4), lineWidth: 2)
                    )
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .compositingGroup()
            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
        }
    }
    
    // Custom Small Glass Tile
    private func infoTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.0)
            
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
    }
    
    // Custom 3D Glass Tile
    private func financialTile(title: String, value: String, gradient: LinearGradient) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1.5)
            
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(gradient)
                .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.black.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        // Inner shadow effect
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LinearGradient(colors: [.black.opacity(0.6), .clear, .white.opacity(0.2)], startPoint: .top, endPoint: .bottom), lineWidth: 2)
        )
    }

    // Custom Box for origin and language
    private func originTile(title: String, value: String, backgroundText: String?) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)
            
            HStack(spacing: 6) {
                if let emoji = backgroundText {
                    Text(emoji)
                        .font(.system(size: 18))
                }
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}



// MARK: - 8. Plot Keywords Section

struct PlotKeywordsSection: View {
    let keywords: [String]
    private let horizontalPadding: CGFloat = 16

    var body: some View {
        FlowKeywordsView(keywords: keywords)
            .padding(.horizontal, horizontalPadding)
    }
}

private struct FlowKeywordsView: View {
    let keywords: [String]

    var body: some View {
        KeywordFlowLayout(spacing: 10) {
            ForEach(keywords, id: \.self) { keyword in
                keywordPill(keyword)
            }
        }
        .padding(.vertical, 20)
    }

    private func keywordPill(_ keyword: String) -> some View {
        // Deterministic styling based on string hash to create a cool "word cloud" effect
        let hash = abs(keyword.hashValue)
        let sizes: [CGFloat] = [13, 15, 17, 14, 16]
        let size = sizes[hash % sizes.count]
        
        let rotations: [Double] = [-4, -2, 0, 2, 4, 3, -3]
        let rot = rotations[hash % rotations.count]
        
        return Text(keyword.lowercased())
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.white.opacity(Double(hash % 40 + 60) / 100.0)) // Random opacity between 0.6 - 1.0
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.03))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .compositingGroup()
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .rotationEffect(.degrees(rot))
            .hoverEffect(.lift)
    }
}

struct KeywordFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            let point = result.points[index]
            subview.place(at: CGPoint(x: point.x + bounds.minX, y: point.y + bounds.minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var points: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Layout.Subviews, spacing: CGFloat) {
            var lines: [[(index: Int, rect: CGRect)]] = []
            var currentLine: [(index: Int, rect: CGRect)] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for (index, subview) in subviews.enumerated() {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > maxWidth && currentX > 0 {
                    lines.append(currentLine)
                    currentLine = []
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                currentLine.append((index, CGRect(x: currentX, y: currentY, width: size.width, height: size.height)))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            if !currentLine.isEmpty {
                lines.append(currentLine)
            }
            
            // Center align points
            points = Array(repeating: .zero, count: subviews.count)
            for line in lines {
                guard let last = line.last else { continue }
                let lineWidth = last.rect.maxX
                let offsetX = max(0, (maxWidth - lineWidth) / 2) // Shift line to center
                
                for item in line {
                    points[item.index] = CGPoint(x: item.rect.minX + offsetX, y: item.rect.minY)
                }
            }
            
            size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - 9. Reviews Section

struct ReviewsSection: View {
    let reviews: [ReviewItem]
    @State private var expandedReviewIds: Set<String> = []
    private let horizontalPadding: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderLabel(symbol: "quote.bubble.fill", title: "Reviews")
                .padding(.horizontal, horizontalPadding)

            VStack(spacing: 10) {
                ForEach(reviews) { review in
                    ReviewCard(
                        review: review,
                        isExpanded: expandedReviewIds.contains(review.id)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if expandedReviewIds.contains(review.id) {
                                expandedReviewIds.remove(review.id)
                            } else {
                                expandedReviewIds.insert(review.id)
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                }
            }
        }
    }
}

private struct ReviewCard: View {
    let review: ReviewItem
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        DetailGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 12) {
                    // Avatar
                    Group {
                        Circle()
                            .fill(Color(white: 0.22))
                            .overlay(
                                Text(String(review.author.prefix(1)).uppercased())
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(review.author)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)

                        HStack(spacing: 6) {
                            if let rating = review.rating {
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.yellow)
                                    Text(String(format: "%.1f", rating))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            if let date = review.formattedDate {
                                Text("·")
                                    .foregroundStyle(.white.opacity(0.3))
                                Text(date)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                        }
                    }

                    Spacer()
                }

                // Review body
                ZStack(alignment: .bottom) {
                    Text(review.content)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineSpacing(4)
                        .lineLimit(isExpanded ? nil : 5)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !isExpanded {
                        LinearGradient(
                            colors: [.clear, Color(white: 0.1).opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 40)
                    }
                }

                // Expand/collapse toggle
                Button(action: onToggle) {
                    Text(isExpanded ? "Show Less" : "Read More")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
    }
}

// MARK: - 3D Glass Box Components

struct Glass3DBox<Content: View, Background: View>: View {
    let width: CGFloat
    let height: CGFloat
    let depth: CGFloat
    @ViewBuilder let content: Content
    @ViewBuilder let background: Background
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Shadow
            ShadowShape(width: width, height: height, depth: depth)
                .fill(Color.black.opacity(0.4))
                .blur(radius: 8)
                .offset(y: 8)
            
            // Top Face
            TopFaceShape(depth: depth)
                .fill(Color(white: 0.1))
                .overlay(
                    ZStack {
                        background
                            .scaledToFill()
                            .frame(width: width, height: height)
                            .blur(radius: 20)
                            .overlay(Color.black.opacity(0.3))
                    }
                    .frame(width: width, height: depth)
                    .clipShape(TopFaceShape(depth: depth))
                )
                .overlay(TopFaceShape(depth: depth).fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
                .overlay(
                    TopFaceShape(depth: depth)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.8), .white.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 1, lineJoin: .round)
                        )
                )
                .frame(width: width, height: depth)
                .offset(y: -depth)
            
            // Right Face
            RightFaceShape(depth: depth)
                .fill(Color(white: 0.1))
                .overlay(
                    ZStack {
                        background
                            .scaledToFill()
                            .frame(width: width, height: height)
                            .blur(radius: 20)
                            .overlay(Color.black.opacity(0.6))
                    }
                    .frame(width: depth, height: height)
                    .clipShape(RightFaceShape(depth: depth))
                )
                .overlay(RightFaceShape(depth: depth).fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
                .overlay(
                    RightFaceShape(depth: depth)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 1, lineJoin: .round)
                        )
                )
                .frame(width: depth, height: height)
                .offset(x: width)
            
            // Front Face
            content
                .frame(width: width, height: height)
                .clipped()
                .overlay(
                    Rectangle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 1, lineJoin: .round)
                        )
                )
        }
        .padding(.top, depth)
        .padding(.trailing, depth)
    }
}

struct TopFaceShape: Shape {
    let depth: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width + depth, y: 0))
        path.addLine(to: CGPoint(x: depth, y: 0))
        path.closeSubpath()
        return path
    }
}

struct RightFaceShape: Shape {
    let depth: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: -depth))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - depth))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct ShadowShape: Shape {
    let width: CGFloat
    let height: CGFloat
    let depth: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: depth, y: -depth))
        path.addLine(to: CGPoint(x: width + depth, y: -depth))
        path.addLine(to: CGPoint(x: width + depth, y: height - depth))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        return path
    }
}
