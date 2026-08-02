import SwiftUI

struct MyProgressView: View {
    @StateObject private var viewModel = MyProgressViewModel()
    @Namespace private var tabNamespace
    @Namespace private var yearNamespace
    @State private var showActivityDetail = false
    @State private var showTasteInfo = false
    
    var body: some View {
        ZStack {
            AppBackground()
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                VStack(spacing: 20) {
                    OrbitLoader(color: .green, size: 90)
                        .frame(width: 90, height: 90)
                    Text(viewModel.selectedTab == .taste ? "Rebuilding Taste Profile..." : "Calculating Your data...")
                        .font(.system(size: viewModel.selectedTab == .taste ? 16 : 20, weight: .black, design: .rounded))
                        .kerning(0.5)
                        .foregroundStyle(.green)
                        .shadow(color: .green.opacity(0.5), radius: 4, x: 0, y: 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Tab Picker
                        HStack(spacing: 0) {
                            ForEach(ProgressTab.allCases, id: \.self) { tab in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.selectedTab = tab
                                    }
                                } label: {
                                    Text(tab.rawValue)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(viewModel.selectedTab == tab ? .white : .secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .contentShape(Rectangle())
                                        .background(
                                            ZStack {
                                                if viewModel.selectedTab == tab {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.white.opacity(0.15))
                                                        .matchedGeometryEffect(id: "TabHighlight", in: tabNamespace)
                                                }
                                            }
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .padding(.horizontal, 20)
                        
                        if viewModel.selectedTab == .stats {
                            statsContent
                        } else {
                            tasteContent
                        }
                    }
                    .padding(.vertical, 20)
                }
                .transition(.opacity)
            }
        }
        .navigationTitle("My Progress")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showActivityDetail) {
            if let stats = viewModel.statsData {
                ActivityDetailView(activity: stats.allActivityMap, selectedYear: viewModel.selectedYear)
            }
        }
        .sheet(isPresented: $showTasteInfo) {
            TasteInfoSheet()
        }
    }
    
    @ViewBuilder
    private var statsContent: some View {
        VStack(spacing: 24) {
            // Liquid Glass Year Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(viewModel.availableYears, id: \.self) { year in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.selectedYear = year
                            }
                            viewModel.applyYearFilter()
                        } label: {
                            Text(year)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(viewModel.selectedYear == year ? .white : .secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                                .background(
                                    ZStack {
                                        if viewModel.selectedYear == year {
                                            Capsule()
                                                .fill(Color.white.opacity(0.15))
                                                .matchedGeometryEffect(id: "YearHighlight", in: yearNamespace)
                                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                        }
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 20)
            }
            
            if let stats = viewModel.statsData {
                VStack(spacing: 16) {
                    WatchTimeHeroCard(
                        hours: stats.watchTimeHours,
                        episodes: stats.episodesWatched,
                        movies: stats.moviesWatched,
                        shows: stats.showsWatched
                    )
                    
                    HStack(spacing: 16) {
                        MetricMiniCard(title: "Current Streak", value: "\(stats.currentStreak) d", subtitle: nil, icon: "flame.fill")
                        MetricMiniCard(title: "Best Streak", value: "\(stats.bestStreak) d", subtitle: nil, icon: "trophy.fill")
                    }
                    
                    HStack(spacing: 16) {
                        MetricMiniCard(title: "First Play", value: stats.firstPlayTitle, subtitle: formatDate(stats.firstPlayDate), icon: "play.circle.fill")
                        MetricMiniCard(title: "Last Play", value: stats.lastPlayTitle, subtitle: formatDate(stats.lastPlayDate), icon: "clock.fill")
                    }
                    
                    Button {
                        showActivityDetail = true
                    } label: {
                        ActivityHeatmapCard(activity: stats.activityMap)
                    }
                    .buttonStyle(.plain)
                    
                    MonthlyChartCard(stats: stats.monthlyStats)
                    
                    TimeDistributionCard(dist: stats.timeDistribution)
                    
                    BusiestDaysCard(days: stats.busiestDays)
                    
                    TopGenresCard(genres: stats.topGenres)
                    
                    TopPeopleCard(title: "Most Watched Actors", people: stats.mostWatchedActors)
                    
                    TopPeopleCard(title: "Most Watched Directors", people: stats.mostWatchedDirectors)
                }
                .padding(.horizontal, 20)
                .transition(.opacity)
            }
        }
    }
    
    @ViewBuilder
    private var tasteContent: some View {
        if let stats = viewModel.statsData {
            let taste = stats.tasteData
            
            ZStack(alignment: .bottom) {
                VStack(spacing: 16) { // Reduced from 32
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            showTasteInfo = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle.fill")
                                Text("What is this?")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .background(Color.green.opacity(0.2).clipShape(Capsule()))
                            )
                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                            .foregroundStyle(.white)
                            .shadow(color: .green.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 4) // Reduced padding
                    
                    TasteCoreView(
                        sample: taste.sampleSize,
                        avgRating: taste.avgRating,
                        avgRuntime: taste.avgRuntimeMinutes,
                        avgPop: taste.avgPopularity
                    )
                    // Reduced padding below the TasteCoreView
                    .padding(.bottom, -10)
                    
                    TasteVersionSubheader(version: taste.versionLabel, keywords: taste.keywordsCount, people: taste.peopleCount)
                    
                    TasteOrbCloud(
                        title: "Top Genres",
                        items: taste.topGenres,
                        nameKeyPath: \.name,
                        percentKeyPath: \.percentage,
                        color: .green
                    )
                    
                    TasteEraWave(decades: taste.decades)
                    
                    TasteOrbCloud(
                        title: "Languages",
                        items: taste.languages,
                        nameKeyPath: \.language,
                        percentKeyPath: \.percentage,
                        color: .mint
                    )
                    
                    // Extra padding for the floating button
                    Spacer().frame(height: 100)
                }
                .padding(.top, 16)
                
                FloatingRebuildButton {
                    viewModel.rebuildTaste()
                }
                .padding(.bottom, 30)
            }
            .transition(.opacity)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        return df.string(from: date)
    }
}
