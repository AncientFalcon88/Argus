import SwiftUI
import WebKit
import CoreImage

// MARK: - Orbit Loader
struct OrbitLoader: View {
    let color: Color
    var size: CGFloat = 80
    
    @State private var rotation: Double = 0
    @State private var innerRotation: Double = 0
    @State private var pulse: Bool = false

    private let orbitCount = 8

    var body: some View {
        ZStack {
            // Outer pulsing ring
            Circle()
                .stroke(color.opacity(0.12), lineWidth: 1.5)
                .frame(width: size, height: size)
                .scaleEffect(pulse ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

            // Inner pulsing ring
            Circle()
                .stroke(color.opacity(0.22), lineWidth: 1)
                .frame(width: size * 0.6, height: size * 0.6)
                .scaleEffect(pulse ? 0.88 : 1.0)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.3), value: pulse)

            // Center glowing dot
            Circle()
                .fill(color.opacity(0.7))
                .frame(width: size * 0.13, height: size * 0.13)
                .shadow(color: color, radius: 6)
                .scaleEffect(pulse ? 1.3 : 0.8)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)

            // Orbiting dots
            ForEach(0..<orbitCount, id: \.self) { i in
                let angle = Double(i) / Double(orbitCount) * 360.0
                let delay = Double(i) / Double(orbitCount) * 0.6
                let dotSize = size * 0.095
                let orbitRadius = size * 0.42

                OrbitDot(
                    color: color,
                    dotSize: dotSize,
                    orbitRadius: orbitRadius,
                    baseAngle: angle,
                    opacity: 1.0 - (Double(i) / Double(orbitCount)) * 0.75
                )
            }
            .rotationEffect(.degrees(rotation))
            
            // Inner counter-rotating small dots
            ForEach(0..<4, id: \.self) { i in
                let angle = Double(i) / 4.0 * 360.0
                let dotSize = size * 0.06
                let orbitRadius = size * 0.24

                OrbitDot(
                    color: color,
                    dotSize: dotSize,
                    orbitRadius: orbitRadius,
                    baseAngle: angle,
                    opacity: 1.0 - (Double(i) / 4.0) * 0.6
                )
            }
            .rotationEffect(.degrees(-innerRotation))
        }
        .onAppear {
            pulse = true
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                innerRotation = 360
            }
        }
    }
}

private struct OrbitDot: View {
    let color: Color
    let dotSize: CGFloat
    let orbitRadius: CGFloat
    let baseAngle: Double
    let opacity: Double

    var body: some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: dotSize, height: dotSize)
            .shadow(color: color.opacity(opacity * 0.8), radius: dotSize * 0.8)
            .offset(x: orbitRadius)
            .rotationEffect(.degrees(baseAngle))
    }
}

struct ScreenHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(GlassTheme.primaryText)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(GlassTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

struct SectionHeader<TrailingContent: View>: View {
    let title: String
    let symbol: String
    var hasChevron: Bool = false
    let trailingContent: TrailingContent

    init(title: String, symbol: String, hasChevron: Bool = false, @ViewBuilder trailingContent: () -> TrailingContent) {
        self.title = title
        self.symbol = symbol
        self.hasChevron = hasChevron
        self.trailingContent = trailingContent()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.gray)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
            Text(title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(GlassTheme.primaryText)
                
            if hasChevron {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            
            trailingContent
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

extension SectionHeader where TrailingContent == EmptyView {
    init(title: String, symbol: String, hasChevron: Bool = false) {
        self.title = title
        self.symbol = symbol
        self.hasChevron = hasChevron
        self.trailingContent = EmptyView()
    }
}

struct GlassPill: View {
    var icon: String? = nil
    var text: String
    var isCompact: Bool = false // Defaults to the larger Picks size
    /// If true, uses ultraThinMaterial (blurred). If false, uses a flat fill (better scroll perf).
    var useMaterial: Bool? = nil // nil = auto: material when non-compact, flat when compact

    private var shouldUseMaterial: Bool {
        useMaterial ?? !isCompact
    }

    var body: some View {
        // Dynamic sizing based on the flag
        let fontSize: CGFloat = isCompact ? 9 : 11
        let pillHeight: CGFloat = isCompact ? 20 : 24
        let hPadding: CGFloat = isCompact ? 4 : 5

        HStack(spacing: 3) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: fontSize, weight: .heavy))
            }
            Text(text)
                .font(.system(size: fontSize, weight: .heavy))
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, hPadding)
        .frame(height: pillHeight)
        .background(
            Group {
                if shouldUseMaterial {
                    Capsule().fill(.ultraThinMaterial)
                } else {
                    Capsule().fill(Color(white: 0.3, opacity: 0.75))
                }
            }
        )
        .overlay(
            shouldUseMaterial ? nil : Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .foregroundColor(.white)
    }
}

struct PosterThumbnail: View {
    let url: URL?
    let title: String

    var body: some View {
        ZStack {
            if let url {
                CachedImage(url: url) {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityLabel(title)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .overlay {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(GlassTheme.secondaryText)
            }
    }
}

struct MediaPosterCard: View {
    let title: String
    let subtitle: String
    let posterURL: URL?
    var progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterThumbnail(url: posterURL, title: title)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .bottom) {
                    if let progress, progress > 0 {
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: geo.size.width * progress, height: 3)
                        }
                        .frame(height: 3)
                    }
                }

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(GlassTheme.primaryText)
                .lineLimit(2)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(GlassTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(width: 120)
        .padding(10)
        .glassCard(cornerRadius: 14)
    }
}

struct HistoryRowCard: View {
    let title: String
    let detail: String
    let date: String
    let posterURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            PosterThumbnail(url: posterURL, title: title)
                .frame(width: 52, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GlassTheme.primaryText)
                if !detail.isEmpty {
                    Text(detail.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                        .padding(.vertical, 2)
                }
                Text(date)
                    .font(.caption2)
                    .foregroundStyle(GlassTheme.secondaryText)
            }
            Spacer()
        }
        .padding(12)
        .richLiquidGlass(cornerRadius: 12)
        .contentShape(Rectangle())
    }
}

struct DiscoverPosterCell: View {
    let item: TMDBMediaItem
    var pmdbRating: Int? = nil
    var tmdbRating: Double? = nil
    var logoURL: URL? = nil
    var cleanPosterURL: URL? = nil
    var badgeText: String? = nil
    var percentageMatch: String? = nil
    var isInWatchlist: Bool = false
    var hideDefaultContextMenu: Bool = false
    var hideGenre: Bool = false
    var onAddToWatchlist: (() -> Void)? = nil
    var onRemoveFromWatchlist: (() -> Void)? = nil

    var onWhyThis: (() -> Void)? = nil
    var onNoThanks: (() -> Void)? = nil
    var customWidth: CGFloat? = nil
    var customHeight: CGFloat? = nil
    var hideTopBadge: Bool = false

    @AppStorage("posterBadgeEnabled") private var posterBadgeEnabled = true
    @AppStorage("posterRatingEnabled") private var posterRatingEnabled = true
    @AppStorage("posterGenreEnabled") private var posterGenreEnabled = true
    @AppStorage("posterTitleEnabled") private var posterTitleEnabled = false
    @AppStorage("posterGlassStyle") private var posterGlassStyle = "dark"
    @State private var dynamicBadgeColor: Color = .black
    
    private var textColor: Color {
        posterGlassStyle == "dynamic" ? .white : .white
    }

    private var mainGenre: String? {
        guard let id = item.genreIds?.first else { return nil }
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

    private let totalPadding: CGFloat = 24
    private let totalSpacing: CGFloat = 24
    private var posterWidth: CGFloat {
        customWidth ?? ((UIScreen.main.bounds.width - totalPadding - totalSpacing) / 3)
    }
    private var posterHeight: CGFloat {
        customHeight ?? (posterWidth * 1.5) // 2:3 aspect ratio by default
    }
    
    private var scale: CGFloat {
        posterWidth / 115.0 // 115 is standard poster width
    }
    
    private var badgeBorderGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.5), location: 0.0),
                .init(color: .white.opacity(0.1), location: 0.2),
                .init(color: .clear, location: 0.5),
                .init(color: .white.opacity(0.15), location: 0.8),
                .init(color: .white.opacity(0.3), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var ratingColor: Color {
        let rating = pmdbRating ?? (tmdbRating != nil ? Int(tmdbRating! * 10) : Int(item.voteAverage * 10))
        if rating >= 80 { return .green }
        if rating >= 60 { return .yellow }
        if rating >= 40 { return .orange }
        if rating > 0 { return .red }
        return .white.opacity(0.8)
    }

    private var displayRating: String {
        if let rating = tmdbRating, rating > 0 {
            return String(format: "%.1f", rating)
        } else if let rating = pmdbRating {
            if rating > 0 {
                return String(rating)
            } else if rating == -1 {
                return String(Int(item.voteAverage * 10))
            }
        }
        return ""
    }
    
    private var matchColor: Color {
        guard let matchStr = percentageMatch else { return .white }
        let numbers = matchStr.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let val = Int(numbers) {
            if val >= 80 { return .green }
            if val >= 60 { return .yellow }
            if val >= 40 { return .orange }
            return .red
        }
        return .white
    }

    var body: some View {
        VStack(spacing: 8) {
            if hideDefaultContextMenu && onWhyThis == nil && onNoThanks == nil {
                posterContent
            } else {
                posterContent
                    .contextMenu {
                        if let onWhyThis = onWhyThis {
                            Button {
                                onWhyThis()
                            } label: {
                                Label("Why This?", systemImage: "info.circle")
                            }
                        }
                        
                        if let onNoThanks = onNoThanks {
                            Button(role: .destructive) {
                                onNoThanks()
                            } label: {
                                Label("No Thanks :(", systemImage: "eye.slash")
                            }
                            .tint(.red)
                            .foregroundStyle(.red)
                        }
                        
                        if !hideDefaultContextMenu {
                            if isInWatchlist {
                                Button(role: .destructive) {
                                    onRemoveFromWatchlist?()
                                } label: {
                                    Label("Remove from Watchlist", systemImage: "bookmark.slash")
                                }
                                .tint(.red)
                                .foregroundStyle(.red)
                            } else {
                                Button {
                                    onAddToWatchlist?()
                                } label: {
                                    Label("Add to Watchlist", systemImage: "bookmark")
                                }
                            }
                        }
                    }
            }
            
            if posterTitleEnabled {
                Text(item.title)
                    .font(.system(size: 12 * scale, weight: .bold, design: .rounded))
                    .kerning(0.3 * scale)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(white: 0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.8), radius: 2 * scale, x: 0, y: 1 * scale)
                    .frame(width: posterWidth, height: 40 * scale, alignment: .top)
            }
        }
    }
    private var hasBothCleanAssets: Bool {
        cleanPosterURL != nil && logoURL != nil
    }
    
    @ViewBuilder
    private func badgeBackground<S: Shape>(shape: S) -> some View {
        switch posterGlassStyle {
        case "dark":
            shape.fill(Color(white: 0.15).opacity(0.85))
        case "dynamic":
            shape.fill(dynamicBadgeColor.opacity(0.90))
        case "gray":
            shape.fill(Color(white: 0.4).opacity(0.85))
        default: // "glass"
            shape.fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
        }
    }
    
    @ViewBuilder
    private var posterContent: some View {
        ZStack {
            // Background Image (Clean poster or fallback)
            CachedImage(url: hasBothCleanAssets ? cleanPosterURL : item.posterURL) {
                ZStack {
                    Rectangle().fill(Color.white.opacity(0.08))
                    Image(systemName: item.mediaType == .movie ? "film" : (item.mediaType == .tv ? "tv" : "person.fill"))
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            .frame(width: posterWidth, height: posterHeight)
            .clipped()
            .clipped()
            .onAppear { applyDynamicColor() }
            
            // Subtle dark glass gradient at the bottom for readability
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.4),
                    .init(color: .black.opacity(0.4), location: 0.7),
                    .init(color: .black.opacity(0.8), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Content Layer
            VStack(spacing: 0) {
                // TOP CENTER: Creative Hero Badge (Floating Tab)
                if !hideTopBadge && ((posterBadgeEnabled && badgeText != nil) || percentageMatch != nil) {
                    HStack(spacing: 6) {
                        if posterBadgeEnabled, let badge = badgeText {
                            Text(badge)
                                .font(.system(size: 9 * scale, weight: .black, design: .monospaced))
                                .foregroundStyle(textColor)
                        }
                        
                        if posterBadgeEnabled && badgeText != nil && percentageMatch != nil {
                            Rectangle()
                                .fill(textColor.opacity(0.3))
                                .frame(width: 1, height: 10 * scale)
                        }
                        
                        if let match = percentageMatch {
                            Text(match)
                                .font(.system(size: 9 * scale, weight: .bold, design: .monospaced))
                                .foregroundStyle(matchColor)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background( // Shadow Layer
                        UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6)
                            .fill(Color.black.opacity(0.01))
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    )
                    .background( // Material Layer
                        badgeBackground(shape: UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6))
                    )
                    .overlay( // Border Layer
                        UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6)
                            .strokeBorder(badgeBorderGradient, lineWidth: 0.5)
                    )
                }
                
                Spacer()
                
                // BOTTOM CENTER: Logo or Person Name
                if hasBothCleanAssets, let logo = logoURL {
                    CachedImage(url: logo, contentMode: .fit) {
                        Color.clear // Use Color.clear to ensure it takes up space even while loading
                    }
                    .frame(maxWidth: posterWidth * 0.85, maxHeight: 50 * scale) // Allow square logos to grow taller while wide logos hit maxWidth
                    .shadow(color: .black.opacity(0.7), radius: 3 * scale, x: 0, y: 2 * scale)
                    .padding(.bottom, 16 * scale)
                } else if item.mediaType == .person {
                    Text(item.title)
                        .font(.system(size: 14 * scale, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(white: 0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 12)
                }
                
                // GENRE
                if posterGenreEnabled && !hideGenre, let genre = mainGenre, !genre.isEmpty {
                    Text(genre.replacingOccurrences(of: "/", with: " & ").uppercased())
                        .font(.system(size: 8 * scale, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .tracking(1.0 * scale)
                        .shadow(color: .black.opacity(0.8), radius: 2 * scale, x: 0, y: 1 * scale)
                        .padding(.bottom, 14 * scale)
                }
                
                // BOTTOM ROW: Metadata (Year • Rating)
                if item.mediaType != .person && posterRatingEnabled {
                    HStack(alignment: .center, spacing: 6) {
                        if !item.year.isEmpty {
                            Text(item.year)
                                .foregroundStyle(textColor.opacity(0.85))
                        }
                        
                        let ratingStr = displayRating
                        if !ratingStr.isEmpty && ratingStr != "0" {
                            if !item.year.isEmpty {
                                Text("•")
                                    .font(.system(size: 8 * scale, weight: .black))
                                    .foregroundStyle(textColor.opacity(0.4))
                            }
                            
                            HStack(spacing: 3 * scale) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8 * scale))
                                    .offset(y: -0.5 * scale)
                                Text(ratingStr)
                            }
                            .foregroundStyle(ratingColor)
                        }
                    }
                    .font(.system(size: 10 * scale, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 10 * scale)
                    .padding(.vertical, 4 * scale)
                    .background( // Shadow Layer
                        Capsule()
                            .fill(Color.black.opacity(0.01))
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    )
                    .background( // Material Layer
                        badgeBackground(shape: Capsule())
                    )
                    .overlay( // Border Layer
                        Capsule()
                            .strokeBorder(badgeBorderGradient, lineWidth: 0.5)
                    )
                    .padding(.bottom, 12 * scale)
                }
            }
        }
        .frame(width: posterWidth, height: posterHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // Liquid Glass border
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.6), location: 0.0),
                            .init(color: .white.opacity(0.1), location: 0.2),
                            .init(color: .clear, location: 0.5),
                            .init(color: .white.opacity(0.2), location: 0.8),
                            .init(color: .white.opacity(0.4), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        // Inner rim for 3D thickness
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                .padding(1)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
        )
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 16))
    }
    
    private func applyDynamicColor() {
        guard posterGlassStyle == "dynamic" else { return }
        let url: URL? = hasBothCleanAssets ? cleanPosterURL : item.posterURL
        guard let url else { return }
        
        // Fast path: Color is already cached
        if let cachedColor = ColorCache.shared.object(forKey: url as NSURL) {
            dynamicBadgeColor = Color(cachedColor)
            return
        }
        
        Task {
            // Wait for image to load (poll every 50ms up to 20 times = 1 second max)
            for _ in 0..<20 {
                if let cachedImage = ImageCache.shared.object(forKey: url as NSURL) {
                    // Extract color in background to avoid scrolling stutter
                    let extracted = await Task.detached(priority: .userInitiated) {
                        cachedImage.vibrantDominantColor()
                    }.value
                    
                    if let extracted {
                        ColorCache.shared.setObject(extracted, forKey: url as NSURL)
                        await MainActor.run {
                            withAnimation(.easeIn(duration: 0.2)) {
                                self.dynamicBadgeColor = Color(extracted)
                            }
                        }
                    }
                    return
                }
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
    }
}

struct DiscoverSkeletonCell: View {
    @State private var pulse = false

    private let totalPadding: CGFloat = 24
    private let totalSpacing: CGFloat = 24
    private var posterWidth: CGFloat {
        (UIScreen.main.bounds.width - totalPadding - totalSpacing) / 3
    }
    private var posterHeight: CGFloat {
        posterWidth * 1.5
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(pulse ? 0.14 : 0.07))
            .frame(width: posterWidth, height: posterHeight)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}


struct WideLandscapePoster: View {
    let title: String
    let imageURL: URL?
    let topLeftTag: String?
    let topRightTag: String?
    let topRightTagTint: Color?
    
    init(
        title: String,
        imageURL: URL?,
        topLeftTag: String? = nil,
        topRightTag: String? = nil,
        topRightTagTint: Color? = nil
    ) {
        self.title = title
        self.imageURL = imageURL
        self.topLeftTag = topLeftTag
        self.topRightTag = topRightTag
        self.topRightTagTint = topRightTagTint
    }

    var body: some View {
        ZStack {
            PosterThumbnail(url: imageURL, title: title)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Gradient overlay for contrast
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                startPoint: .center,
                endPoint: .bottom
            )
            
            // PILLS OVERLAY LAYER
            VStack {
                HStack(alignment: .top) {
                    if let topLeftTag {
                        GlassPill(text: topLeftTag)
                    }
                    Spacer()
                    if let topRightTag {
                        GlassPill(text: topRightTag)
                    }
                }
                Spacer()
            }
            .padding(12)
            
            // Bottom-leading title
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .shadow(radius: 4)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 12, style: .continuous))
        .zIndex(0)
    }
}

struct WideLandscapeCard: View {
    let title: String
    let subtitle: String
    let detail: String
    let imageURL: URL?
    let topLeftTag: String?
    let topRightTag: String?
    let topRightTagTint: Color?
    
    init(
        title: String,
        subtitle: String,
        detail: String,
        imageURL: URL?,
        topLeftTag: String? = nil,
        topRightTag: String? = nil,
        topRightTagTint: Color? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.imageURL = imageURL
        self.topLeftTag = topLeftTag
        self.topRightTag = topRightTag
        self.topRightTagTint = topRightTagTint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WideLandscapePoster(
                title: title,
                imageURL: imageURL,
                topLeftTag: topLeftTag,
                topRightTag: topRightTag,
                topRightTagTint: topRightTagTint
            )
            
            HStack(spacing: 6) {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(GlassTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(width: 260)
    }
}

// MARK: - Cached Image Loader
class ImageCache {
    static let shared = NSCache<NSURL, UIImage>()
    
    // Configure cache size limits
    static func configure() {
        shared.countLimit = 100 // maximum 100 images
        shared.totalCostLimit = 1024 * 1024 * 100 // 100 MB max
    }
}

class ColorCache {
    static let shared = NSCache<NSURL, UIColor>()
}

/// Pre-fetches images and extracts their dynamic colors in the background.
/// This allows ViewModels to hold their main loading spinners until all dynamic colors are ready.
func prefetchDynamicColors(for urls: [URL]) async {
    await withTaskGroup(of: Void.self) { group in
        for url in urls {
            if ColorCache.shared.object(forKey: url as NSURL) != nil {
                continue
            }
            group.addTask {
                if let cachedImage = ImageCache.shared.object(forKey: url as NSURL) {
                    if let extracted = cachedImage.vibrantDominantColor() {
                        ColorCache.shared.setObject(extracted, forKey: url as NSURL)
                    }
                    return
                }
                do {
                    let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
                    let (data, _) = try await URLSession.shared.data(for: request)
                    if let uiImage = UIImage(data: data) {
                        ImageCache.shared.setObject(uiImage, forKey: url as NSURL, cost: data.count)
                        if let extracted = uiImage.vibrantDominantColor() {
                            ColorCache.shared.setObject(extracted, forKey: url as NSURL)
                        }
                    }
                } catch {}
            }
        }
    }
}

// MARK: - Dominant Color Extraction
extension UIImage {
    /// Average color sampled from a downscaled thumbnail via CIAreaAverage (fast, no deps).
    func dominantColor() -> UIColor? {
        let targetSize = CGSize(width: 40, height: 60)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: targetSize))
        let thumb = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cgImage = (thumb ?? self).cgImage else { return nil }
        let ciInput = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: "CIAreaAverage",
                              parameters: [kCIInputImageKey: ciInput,
                                           kCIInputExtentKey: CIVector(cgRect: ciInput.extent)])
        guard let output = filter?.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        let ctx = CIContext(options: [.workingColorSpace: NSNull()])
        ctx.render(output, toBitmap: &bitmap, rowBytes: 4,
                   bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                   format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return UIColor(red: CGFloat(bitmap[0]) / 255,
                       green: CGFloat(bitmap[1]) / 255,
                       blue: CGFloat(bitmap[2]) / 255,
                       alpha: 1.0)
    }

    /// Saturation- and brightness-boosted version — makes the color pop on badge backgrounds.
    func vibrantDominantColor() -> UIColor? {
        guard let base = dominantColor() else { return nil }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        base.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let boostedS = min(s * 1.5 + 0.2, 1.0)
        let boostedB = max(min(b * 1.1, 0.75), 0.35)
        return UIColor(hue: h, saturation: boostedS, brightness: boostedB, alpha: a)
    }
}

@MainActor
class ImageLoader: ObservableObject {
    @Published var image: Image?
    @Published var isLoading = false
    
    private var url: URL?
    private var task: Task<Void, Never>?
    
    init(url: URL?) {
        self.url = url
    }
    
    func load() {
        guard let url = url else { return }
        
        if let cached = ImageCache.shared.object(forKey: url as NSURL) {
            self.image = Image(uiImage: cached)
            return
        }
        
        guard !isLoading && image == nil else { return }
        isLoading = true
        
        task = Task {
            do {
                let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
                let (data, _) = try await URLSession.shared.data(for: request)
                
                if let uiImage = UIImage(data: data) {
                    ImageCache.shared.setObject(uiImage, forKey: url as NSURL, cost: data.count)
                    if !Task.isCancelled {
                        self.image = Image(uiImage: uiImage)
                    }
                }
            } catch {
                // Ignore errors like cancellation
            }
            if !Task.isCancelled {
                self.isLoading = false
            }
        }
    }
    
    func cancel() {
        task?.cancel()
    }
}

struct CachedImage<Placeholder: View>: View {
    @StateObject private var loader: ImageLoader
    private let contentMode: ContentMode
    private let placeholder: () -> Placeholder
    
    init(url: URL?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        _loader = StateObject(wrappedValue: ImageLoader(url: url))
        self.contentMode = contentMode
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = loader.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.load()
        }
        .onDisappear {
            // We do not cancel the task aggressively here.
            // If they scroll quickly, we still want the image to fetch and enter the NSCache
            // so that when they scroll back, it's instantly ready.
        }
    }
}

struct GlassTabSelector<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let titleForOption: (T) -> String
    @Namespace private var namespace
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selection = option
                    }
                } label: {
                    Text(titleForOption(option))
                        .font(.subheadline.weight(isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            .matchedGeometryEffect(id: "tab", in: namespace)
                    }
                }
            }
        }
        .padding(4)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(Capsule().fill(Color.black.opacity(0.3)))
        }
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }
}

// MARK: - LottieWebView
struct LottieWebView: UIViewRepresentable {
    private let animationData: Data?

    init(data: Data?) {
        self.animationData = data
    }
    
    class Coordinator {
        var didLoad = false
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard !context.coordinator.didLoad else { return }
        context.coordinator.didLoad = true
        
        guard let data = animationData,
              let jsonString = String(data: data, encoding: .utf8),
              let jsAsset = NSDataAsset(name: "lottie_js"),
              let jsString = String(data: jsAsset.data, encoding: .utf8) else { return }
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body, html {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    height: 100%;
                    background-color: transparent;
                    overflow: hidden;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                }
                #lottie {
                    width: 100%;
                    height: 100%;
                }
            </style>
            <script>\(jsString)</script>
        </head>
        <body>
            <div id="lottie"></div>
            <script>
                var animationData = \(jsonString);
                lottie.loadAnimation({
                    container: document.getElementById('lottie'),
                    renderer: 'svg',
                    loop: true,
                    autoplay: true,
                    animationData: animationData
                });
            </script>
        </body>
        </html>
        """
        uiView.loadHTMLString(html, baseURL: nil)
    }
}
