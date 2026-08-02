import SwiftUI

struct PreviewPosterCard: View {
    let title: String
    let posterURL: URL?
    let cleanPosterURL: URL?
    let logoURL: URL?
    let mediaType: String // "movie" or "tv"
    let voteAverage: Double
    let genreName: String?
    let badgeText: String?
    let year: String
    
    // Toggles
    @AppStorage("posterBadgeEnabled") private var posterBadgeEnabled = true
    @AppStorage("posterRatingEnabled") private var posterRatingEnabled = true
    @AppStorage("posterGenreEnabled") private var posterGenreEnabled = true
    @AppStorage("posterTitleEnabled") private var posterTitleEnabled = false
    @AppStorage("posterGlassStyle") private var posterGlassStyle = "dark"
    @State private var dynamicBadgeColor: Color? = nil
    @State private var isDynamicColorReady = false
    
    private var textColor: Color {
        .white
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
    
    private var ratingValue: Int {
        Int(voteAverage * 10)
    }
    
    private var ratingColor: Color {
        if ratingValue >= 80 { return .green }
        if ratingValue >= 60 { return .yellow }
        if ratingValue >= 40 { return .orange }
        if ratingValue > 0 { return .red }
        return textColor.opacity(0.8)
    }
    
    private var hasBothCleanAssets: Bool {
        cleanPosterURL != nil && logoURL != nil
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Group {
                if posterGlassStyle == "dynamic" && !isDynamicColorReady {
                    ShimmerView()
                        .frame(width: 160, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onAppear { extractDynamicColor() }
                } else {
                    ZStack {
                        // Background Image
                        CachedImage(url: hasBothCleanAssets ? cleanPosterURL : posterURL) {
                            ZStack {
                                Rectangle().fill(Color.white.opacity(0.08))
                                Image(systemName: mediaType == "movie" ? "film" : "tv")
                                    .font(.system(size: 30 * (160.0 / 115.0)))
                                    .foregroundStyle(.white.opacity(0.2))
                            }
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 240)
                        .clipped()
                        .onAppear { extractDynamicColor() }
                
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
                            if posterBadgeEnabled {
                                HStack(spacing: 8) {
                                    Text(badgeText ?? (mediaType == "movie" ? "MOVIE" : "SERIES"))
                                        .font(.system(size: 9 * (160.0 / 115.0), weight: .black, design: .monospaced))
                                        .foregroundStyle(textColor)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background( // Shadow Layer
                                    UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8)
                                        .fill(Color.black.opacity(0.01))
                                        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                                )
                                .background( // Material Layer
                                    badgeBackground(shape: UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8))
                                )
                                .overlay( // Border Layer
                                    UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8)
                                        .strokeBorder(badgeBorderGradient, lineWidth: 0.5)
                                )
                            }
                            
                            Spacer()
                            
                            // BOTTOM CENTER: Logo or Person Name
                            if hasBothCleanAssets, let logo = logoURL {
                                CachedImage(url: logo, contentMode: .fit) {
                                    Color.clear // Use Color.clear to ensure it takes up space even while loading
                                }
                                .frame(maxWidth: 160 * 0.85, maxHeight: 50 * (160.0 / 115.0))
                                .shadow(color: .black.opacity(0.7), radius: 3, x: 0, y: 2)
                                .padding(.bottom, 16 * (160.0 / 115.0))
                            }
                            
                            if posterGenreEnabled, let genre = genreName, !genre.isEmpty {
                                Text(genre.replacingOccurrences(of: "/", with: " & ").uppercased())
                                    .font(.system(size: 8 * (160.0 / 115.0), weight: .black, design: .rounded))
                                    .kerning(1.0 * (160.0 / 115.0))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                                    .padding(.bottom, 14 * (160.0 / 115.0))
                            }
                            
                            if posterRatingEnabled {
                                HStack(alignment: .center, spacing: 6) {
                                    if !year.isEmpty {
                                        Text(year)
                                            .foregroundStyle(textColor.opacity(0.85))
                                    }
                                    
                                    if ratingValue > 0 {
                                        if !year.isEmpty {
                                            Text("•")
                                                .font(.system(size: 8 * (160.0 / 115.0), weight: .black))
                                                .foregroundStyle(textColor.opacity(0.4))
                                        }
                                        
                                        HStack(spacing: 3) {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 10 * (160.0 / 115.0)))
                                                .offset(y: -0.5)
                                            Text(String(ratingValue))
                                        }
                                        .foregroundStyle(ratingColor)
                                    }
                                }
                                .font(.system(size: 11 * (160.0 / 115.0), weight: .heavy, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background( // Shadow Layer
                                    Capsule()
                                        .fill(Color.black.opacity(0.01))
                                        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                                )
                                .background( // Style Layer
                                    badgeBackground(shape: Capsule())
                                )
                                .overlay( // Border Layer
                                    Capsule()
                                        .strokeBorder(badgeBorderGradient, lineWidth: 0.5)
                                )
                            }
                        }
                        .padding(.bottom, 12 * (160.0 / 115.0))
                    }
                    .frame(width: 160, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    // Liquid Glass border exactly like DiscoverPosterCell
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
                }
            }
            
            // Title UNDER the poster
            Text(title)
                .font(.system(size: 12 * (160.0 / 115.0), weight: .bold, design: .rounded))
                .kerning(0.3 * (160.0 / 115.0))
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
                .frame(width: 160, height: 40, alignment: .top)
                .opacity(posterTitleEnabled ? 1 : 0)
        }
    }
    
    private func extractDynamicColor() {
        guard posterGlassStyle == "dynamic" else {
            isDynamicColorReady = true
            return
        }
        let url: URL? = hasBothCleanAssets ? cleanPosterURL : posterURL
        guard let url else {
            isDynamicColorReady = true
            return
        }
        
        // Fast path: Color is already cached
        if let cachedColor = ColorCache.shared.object(forKey: url as NSURL) {
            dynamicBadgeColor = Color(cachedColor)
            isDynamicColorReady = true
            return
        }
        
        Task {
            await prefetchDynamicColors(for: [url])
            if let cachedColor = ColorCache.shared.object(forKey: url as NSURL) {
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.2)) {
                        self.dynamicBadgeColor = Color(cachedColor)
                        self.isDynamicColorReady = true
                    }
                }
            } else {
                await MainActor.run {
                    self.isDynamicColorReady = true
                }
            }
        }
    }

    @ViewBuilder
    private func badgeBackground<S: Shape>(shape: S) -> some View {
        switch posterGlassStyle {
        case "dark":
            shape.fill(Color(white: 0.15).opacity(0.85))
        case "dynamic":
            shape.fill((dynamicBadgeColor ?? .black).opacity(0.90))
        case "gray":
            shape.fill(Color(white: 0.4).opacity(0.85))
        default: // "glass"
            shape.fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
        }
    }
}
