import SwiftUI

struct LiquidGlassPickCard: View {
    let item: CatalogItem
    let catalogId: String
    @ObservedObject var viewModel: PicksViewModel
    var onWhyThis: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                // Poster
                if let posterPath = item.posterPath, !posterPath.isEmpty {
                    CachedImage(url: URL(string: "https://image.tmdb.org/t/p/w342\(posterPath)")) {
                        ZStack {
                            Rectangle().fill(Color.white.opacity(0.05))
                            Image(systemName: item.mediaType == .movie ? "film" : (item.mediaType == .tv ? "tv" : "person.fill"))
                                .font(.system(size: 30))
                                .foregroundStyle(.white.opacity(0.2))
                        }
                    }
                        .frame(width: 140, height: 210)
                        .background(Color.white.opacity(0.05))
                        .clipped()
                } else {
                    ZStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                        Image(systemName: item.mediaType == .movie ? "film" : (item.mediaType == .tv ? "tv" : "person.fill"))
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                    .frame(width: 140, height: 210)
                }
                
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
                

                
                // PILLS OVERLAY LAYER
                VStack {
                    HStack(alignment: .top) {
                        GlassPill(text: item.calculatedPercentage, isCompact: false)
                        
                        Spacer()
                        
                        if let rating = item.voteAverage, rating > 0 {
                            GlassPill(icon: "star.fill", text: String(format: "%.1f", rating), isCompact: false)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        if let year = item.year, !year.isEmpty {
                            GlassPill(text: year, isCompact: false)
                        }
                        Spacer()
                        GlassPill(text: item.mediaType == .movie ? "Movie" : "TV", isCompact: false)
                    }
                }
                .padding(10)
            }
            .frame(width: 140, height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.9), location: 0.0),
                                .init(color: .white.opacity(0.2), location: 0.2),
                                .init(color: .white.opacity(0.0), location: 0.5),
                                .init(color: .white.opacity(0.1), location: 0.8),
                                .init(color: .white.opacity(0.5), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                    .padding(1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
                    .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 10)
            )
            .contextMenu {
                Button {
                    onWhyThis?()
                } label: {
                    Label("Why This?", systemImage: "info.circle")
                }
                
                Button(role: .destructive) {
                    viewModel.hideItem(catalogId: catalogId, item: item)
                } label: {
                    Label("No Thanks :(", systemImage: "eye.slash")
                }
                .tint(.red)
                .foregroundStyle(.red)
            }
            
            Text(item.title ?? "Unknown")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .kerning(0.3)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(white: 0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                .frame(width: 140, height: 36, alignment: .topLeading)
        }
        .frame(width: 140)
    }
}

struct WhyThisSheetView: View {
    let item: CatalogItem
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                // Background exactly like "genres" pop up
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // "WHY THIS?" text
                        Text("WHY THIS?")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .kerning(4)
                            .foregroundColor(.gray)
                        
                        // Match and score
                        if let score = item.matchScore {
                            Text("\(item.calculatedPercentage) match • score \(String(format: "%.2f", score))")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                        } else {
                            Text("\(item.calculatedPercentage) match")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        // Reasons List
                        if let reasons = item.matchReasons, !reasons.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(reasons, id: \.self) { reason in
                                    HStack(alignment: .center, spacing: 12) {
                                        Image(systemName: iconForReason(reason))
                                            .font(.system(size: 18, weight: .regular, design: .rounded))
                                            .foregroundColor(.gray)
                                            .frame(width: 24)
                                        Text(reason)
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        } else {
                            Text("No specific reasons available.")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer(minLength: 24)
                        
                        Divider().background(Color.white.opacity(0.2))
                        
                        // Footer details
                        let footerParts: [String] = [
                            item.voteCount.map { "\($0) votes" },
                            item.popularityScore.map { "Popularity \(Int($0))" },
                            item.originalLanguage
                        ].compactMap { $0 }
                        
                        Text(footerParts.joined(separator: " • "))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                            .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.dark)
        }
    }
    
    private func iconForReason(_ reason: String) -> String {
        let lowercased = reason.lowercased()
        if lowercased.contains("genre") { return "chart.pie.fill" }
        if lowercased.contains("language") { return "globe" }
        if lowercased.contains("decade") || lowercased.contains("year") { return "calendar" }
        if lowercased.contains("director") || lowercased.contains("actor") || lowercased.contains("crew") { return "person.fill" }
        if lowercased.contains("cut") || lowercased.contains("underseen") || lowercased.contains("gem") { return "sparkles" }
        if lowercased.contains("tmdb") { return "star.fill" }
        return "info.circle.fill"
    }
}
