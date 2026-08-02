import SwiftUI

struct MyStatsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MyStatsViewModel()
    
    // Background animation
    @State private var gradientOffset = false
    
    var body: some View {
        ZStack {
            // Liquid Glass animated background
            AppBackground()
            
            // Dynamic colorful blobs in the background
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.4))
                    .blur(radius: 120)
                    .frame(width: 300, height: 300)
                    .offset(x: gradientOffset ? -150 : 150, y: gradientOffset ? -200 : 0)
                
                Circle()
                    .fill(Color.purple.opacity(0.4))
                    .blur(radius: 120)
                    .frame(width: 300, height: 300)
                    .offset(x: gradientOffset ? 150 : -150, y: gradientOffset ? 200 : 0)
            }
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: gradientOffset)
            
            if viewModel.isLoading && viewModel.profile == nil {
                VStack(spacing: 20) {
                    OrbitLoader(color: .blue, size: 90)
                        .frame(width: 90, height: 90)
                    
                    Text("Checking Your Stats...")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .kerning(0.5)
                        .foregroundStyle(.blue)
                        .shadow(color: .blue.opacity(0.5), radius: 4, x: 0, y: 2)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        if let profile = viewModel.profile {
                            ProfileHeaderView(profile: profile)
                        }
                        
                        if let metrics = viewModel.metrics {
                            StatsSectionView(metrics: metrics)
                        }
                        
                        if let progress = viewModel.progress {
                            AchievementsSectionView(progress: progress)
                        }
                        
                        BadgesSectionView(badges: viewModel.badges)
                        
                        HistorySectionView(history: viewModel.history)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.vertical, 24)
                }
            }
        }
        .navigationTitle("My Stats")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            gradientOffset = true
        }
        .task {
            if viewModel.profile == nil {
                await viewModel.refresh(context: appState)
            }
        }
    }
}

// MARK: - Profile Header
struct ProfileHeaderView: View {
    let profile: StatProfile
    
    var body: some View {
        VStack(spacing: 20) {
            // Avatar & Name
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 80, height: 80)
                        .shadow(color: .purple.opacity(0.6), radius: 20, x: 0, y: 10)
                    
                    Text(profile.avatarInitials)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.username)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "star.circle.fill")
                            .foregroundStyle(Color(red: 174.0/255.0, green: 134.0/255.0, blue: 37.0/255.0))
                        Text("LEVEL \(profile.level)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            
            // Pills
            HStack(spacing: 12) {
                StatPill(icon: "chart.line.uptrend.xyaxis", value: profile.totalContributions.formatted(), title: "Contributions", color: .indigo)
                StatPill(icon: "flame.fill", value: profile.dayStreak.formatted(), title: "Day Streak", color: .orange)
                StatPill(icon: "calendar", value: profile.activeDays.formatted(), title: "Active Days", color: .green)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.85)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .background {
            Circle()
                .fill(color)
                .blur(radius: 40)
                .frame(width: 80, height: 80)
                .opacity(0.8)
        }
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Stats Section
struct StatsSectionView: View {
    let metrics: StatMetrics
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("STATISTICS")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 24)
            
            LazyVGrid(columns: columns, spacing: 16) {
                StatCard(icon: "star.fill", title: "Ratings", value: metrics.ratings, color: .yellow)
                StatCard(icon: "clock.arrow.circlepath", title: "Skips", value: metrics.skips, color: .purple)
                StatCard(icon: "flag.fill", title: "Highlights", value: metrics.highlights, color: .red)
                StatCard(icon: "link", title: "ID Mappings", value: metrics.idMappings, color: .blue)
            }
            .padding(.horizontal, 24)
            
            // Full width titles helped
            HStack(spacing: 16) {
                Image(systemName: "tv.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.mint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Titles Helped")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(metrics.titlesHelped.formatted())
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.ultraThinMaterial).opacity(0.85))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1))
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.mint)
                    .blur(radius: 50)
                    .opacity(0.6)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.5), radius: 8, x: 0, y: 4)
            
            Text(value.formatted())
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.85)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .clear, color.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .background {
            Circle()
                .fill(color)
                .blur(radius: 50)
                .frame(width: 130, height: 130)
                .opacity(0.8)
        }
    }
}

// MARK: - Achievements & Progress
struct AchievementsSectionView: View {
    let progress: StatProgress
    @State private var barWidth: CGFloat = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ACHIEVEMENTS & PROGRESS")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 24)
            
            VStack(spacing: 24) {
                // Progress Bar
                VStack(spacing: 12) {
                    HStack {
                        Text("PROGRESS TO LEVEL \(progress.nextLevel)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text(progress.hintText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.blue)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.black.opacity(0.4))
                                .frame(height: 12)
                            
                            Capsule()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                                .frame(width: barWidth, height: 12)
                                .shadow(color: .purple.opacity(0.6), radius: 8, x: 0, y: 0)
                        }
                        .onAppear {
                            withAnimation(.easeOut(duration: 1.5).delay(0.2)) {
                                barWidth = geo.size.width * CGFloat(progress.progressPercentage)
                            }
                        }
                    }
                    .frame(height: 12)
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Heatmap
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(0..<30, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(progress.activityHeatmap[i] ? Color.green : Color.white.opacity(0.1))
                                .frame(height: 30)
                                .shadow(color: progress.activityHeatmap[i] ? .green.opacity(0.4) : .clear, radius: 4, x: 0, y: 0)
                        }
                    }
                    
                    HStack {
                        Text("30 DAYS AGO")
                        Spacer()
                        Text("TODAY")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1))
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Badges
struct BadgesSectionView: View {
    let badges: [AchievementBadge]
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("BADGES COLLECTION")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 24)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(isExpanded ? badges : Array(badges.prefix(4))) { badge in
                    BadgeCard(badge: badge)
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isExpanded)
            .padding(.horizontal, 24)
            
            if badges.count > 4 {
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(isExpanded ? "SHOW LESS ACHIEVEMENTS" : "VIEW ALL ACHIEVEMENTS")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
            }
        }
    }
}

struct BadgeCard: View {
    let badge: AchievementBadge
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked ? Color.white : Color.white.opacity(0.05))
                    .frame(width: 60, height: 60)
                    .shadow(color: badge.isUnlocked ? .white.opacity(0.4) : .clear, radius: 10, x: 0, y: 0)
                
                Image(systemName: badge.iconName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(badge.isUnlocked ? .black : .white.opacity(0.2))
                
                if !badge.isUnlocked {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 20, height: 20)
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .frame(width: 60, height: 60)
                    .offset(x: 5, y: 5)
                }
            }
            
            VStack(spacing: 4) {
                Text(badge.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(badge.isUnlocked ? .white : .white.opacity(0.3))
                Text(badge.description)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(badge.isUnlocked ? Color.white.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - History
struct HistorySectionView: View {
    let history: [ContributionHistoryItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("HISTORY")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("\(history.count) ITEMS")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 24)
            
            if history.isEmpty {
                Text("No contributions yet.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.ultraThinMaterial))
                    .padding(.horizontal, 24)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(history) { item in
                        MediaDetailLink(route: MediaDetailRoute(tmdbId: item.tmdbId, mediaType: item.mediaType)) {
                            HistoryCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

struct HistoryCard: View {
    let item: ContributionHistoryItem
    
    @State private var title: String
    @State private var posterPath: String?
    
    init(item: ContributionHistoryItem) {
        self.item = item
        self._title = State(initialValue: item.title)
        self._posterPath = State(initialValue: item.posterPath)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Placeholder or Poster
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 70, height: 105)
                
                if let posterPath = posterPath {
                    CachedImage(url: URL(string: "https://image.tmdb.org/t/p/w200\(posterPath)")) {
                        ProgressView()
                    }
                    .frame(width: 70, height: 105)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image(systemName: item.mediaType == .movie ? "film.fill" : "tv.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: item.mediaType == .movie ? "film.fill" : "tv.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(item.mediaType.rawValue.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                }
                .foregroundStyle(.white.opacity(0.5))
                
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    if item.ratingCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.yellow)
                            if item.ratingCount > 1 {
                                Text("\(item.ratingCount)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        .shadow(color: .yellow.opacity(0.5), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.1)))
                    }
                    
                    if item.skipCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 12))
                                .foregroundStyle(.purple)
                            if item.skipCount > 1 {
                                Text("\(item.skipCount)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        .shadow(color: .purple.opacity(0.5), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.1)))
                    }
                    
                    if item.highlightCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                            if item.highlightCount > 1 {
                                Text("\(item.highlightCount)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        .shadow(color: .red.opacity(0.5), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.1)))
                    }
                    
                    if item.mappingCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 12))
                                .foregroundStyle(.blue)
                            if item.mappingCount > 1 {
                                Text("\(item.mappingCount)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        .shadow(color: .blue.opacity(0.5), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.1)))
                    }
                    
                    Spacer()
                    
                    let formatter: DateFormatter = {
                        let df = DateFormatter()
                        df.dateFormat = "dd MMM yyyy"
                        return df
                    }()
                    
                    Text(formatter.string(from: item.date).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .task {
            if title == "Loading..." {
                do {
                    let details = try await TMDBService.shared.fetchDetailInfo(tmdbId: item.tmdbId, mediaType: item.mediaType)
                    title = details.title
                    posterPath = details.posterPath
                } catch {
                    title = "Unknown"
                }
            }
        }
    }
}
