import SwiftUI

// MARK: - List Glass Card
struct HomeListGlassCard: View {
    let list: MediaList
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Posters preview
            ZStack {
                if list.previewPosters.isEmpty {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(Image(systemName: "list.and.film").font(.largeTitle).foregroundStyle(.white.opacity(0.5)))
                } else {
                    GeometryReader { geo in
                        HStack(spacing: -geo.size.width * 0.15) {
                            ForEach(Array(list.previewPosters.prefix(4).enumerated()), id: \.offset) { index, url in
                                CachedImage(url: url)
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
            
            VStack(alignment: .leading, spacing: 6) {
                Text(list.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                HStack {
                    if let count = list.itemCount {
                        Text("\(count) items")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.ultraThinMaterial))
                    }
                    
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
        .frame(width: 260)
        .background(.ultraThinMaterial)
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
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedImage(url: skip.posterURL)
                .aspectRatio(contentMode: .fill)
                .frame(width: 260, height: 160)
                .clipped()
                .overlay(.black.opacity(0.4))
                .overlay(.ultraThinMaterial)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
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
                    
                    Spacer()
                    
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: .orange.opacity(0.6), radius: 6)
                }
                
                Spacer()
                
                HStack(alignment: .bottom) {
                    if let source = skip.source {
                        Text(source.uppercased())
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.orange.opacity(0.6)))
                            .overlay(Capsule().stroke(Color.orange, lineWidth: 1))
                    }
                    
                    Spacer()
                    
                    if let user = skip.user {
                        Text(user)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 260, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Rating Glass Card
struct RecentRatingGlassCard: View {
    let rating: RecentRating
    
    var body: some View {
        HStack(spacing: 0) {
            CachedImage(url: rating.posterURL)
                .aspectRatio(2/3, contentMode: .fit)
                .frame(width: 100)
                .clipped()
            
            VStack(alignment: .leading, spacing: 6) {
                Text(rating.title ?? "Unknown")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                Spacer(minLength: 0)
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", rating.score))
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(tintColor)
                        .shadow(color: tintColor.opacity(0.5), radius: 5)
                    
                    if let label = rating.label {
                        Image("logo_hero_\(label)")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 14)
                    }
                }
                
                if let user = rating.user {
                    Text("by \(user)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [tintColor.opacity(0.15), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .frame(width: 280, height: 130)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LinearGradient(colors: [tintColor.opacity(0.6), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    private var tintColor: Color {
        switch rating.label {
        case "IM": return Color(red: 245/255, green: 197/255, blue: 24/255)
        case "RT": return Color(red: 250/255, green: 50/255, blue: 10/255)
        case "MC": return .yellow
        case "LB": return Color(red: 0.0, green: 0.88, blue: 0.33)
        case "TM": return .teal
        case "TR": return .purple
        case "PC": return .red
        case "AN": return Color(red: 0.0, green: 0.4, blue: 0.8)
        case "ML": return Color(red: 0.2, green: 0.5, blue: 1.0)
        default: return .white
        }
    }
}

// MARK: - Highlight Glass Card
struct RecentHighlightGlassCard: View {
    let highlight: RecentHighlight
    
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
            
            Spacer(minLength: 0)
            
            HStack(spacing: 12) {
                CachedImage(url: highlight.posterURL)
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 40, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(highlight.title ?? "Unknown")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        if let s = highlight.season, let e = highlight.episode {
                            Text("S\(s) • E\(e)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        if let user = highlight.user {
                            Text("• \(user)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
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
    }
}
