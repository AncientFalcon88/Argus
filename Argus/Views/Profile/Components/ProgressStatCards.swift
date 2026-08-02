import SwiftUI
import Charts

struct GlassCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = title {
                Text(title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)
            }
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.85)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
    }
}

struct WatchTimeHeroCard: View {
    let hours: Int
    let episodes: Int
    let movies: Int
    let shows: Int
    
    var body: some View {
        GlassCard(title: "All Time Watch Time") {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(hours)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("hours")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                let days = Double(hours) / 24.0
                Text(String(format: "%.1f full days of non-stop watching", days))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                HStack {
                    statItem(count: episodes, label: "Episodes")
                    Spacer()
                    statItem(count: movies, label: "Movies")
                    Spacer()
                    statItem(count: shows, label: "Shows")
                }
            }
        }
    }
    
    private func statItem(count: Int, label: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text("\(count)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1)
        }
    }
}

struct MetricMiniCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                }
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ActivityHeatmapCard: View {
    let activity: [ProgressActivityDay]
    
    var body: some View {
        GlassCard(title: "Activity (Last 30 Days)") {
            let recentActivity = Array(activity.prefix(30).reversed())
            
            Chart {
                ForEach(recentActivity) { day in
                    AreaMark(
                        x: .value("Date", day.date),
                        y: .value("Count", day.count)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green.opacity(0.6), .green.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    LineMark(
                        x: .value("Date", day.date),
                        y: .value("Count", day.count)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.1))
                    AxisValueLabel().foregroundStyle(.secondary).font(.caption2)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.month().day())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 160)
            .padding(.top, 10)
        }
    }
}

struct MonthlyChartCard: View {
    let stats: [ProgressMonthlyStat]
    
    var body: some View {
        GlassCard(title: "Monthly") {
            Chart {
                ForEach(stats) { stat in
                    AreaMark(
                        x: .value("Month", stat.month),
                        y: .value("Count", stat.count)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.teal.opacity(0.6), .blue.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    LineMark(
                        x: .value("Month", stat.month),
                        y: .value("Count", stat.count)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.teal, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    
                    PointMark(
                        x: .value("Month", stat.month),
                        y: .value("Count", stat.count)
                    )
                    .foregroundStyle(.white)
                    .symbolSize(40)
                    .annotation(position: .top, spacing: 6) {
                        Text("\(stat.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.1))
                    AxisValueLabel().foregroundStyle(.secondary).font(.caption2)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                        .font(.caption2.weight(.bold))
                }
            }
            .frame(height: 180)
            .padding(.top, 10)
        }
    }
}

struct TimeDistributionCard: View {
    let dist: ProgressTimeDistribution
    
    struct TimeSlice: Identifiable {
        let id = UUID()
        let name: String
        let count: Int
        let color: Color
    }
    
    private var slices: [TimeSlice] {
        [
            TimeSlice(name: "Morning", count: dist.morning, color: .orange),
            TimeSlice(name: "Afternoon", count: dist.afternoon, color: .red),
            TimeSlice(name: "Evening", count: dist.evening, color: .purple),
            TimeSlice(name: "Night", count: dist.night, color: .indigo)
        ].filter { $0.count > 0 }
    }
    
    var body: some View {
        GlassCard(title: "When You Watch") {
            HStack(spacing: 20) {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Count", slice.count > 0 ? log10(Double(slice.count) + 1.0) : 0.0),
                        innerRadius: .ratio(0.65),
                        angularInset: 2.0
                    )
                    .cornerRadius(4)
                    .foregroundStyle(slice.color.gradient)
                }
                .frame(width: 140, height: 140)
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(slices) { slice in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(slice.color.gradient)
                                .frame(width: 8, height: 8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(slice.name)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                
                                Text("\(slice.count) items")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
    }
}

struct BusiestDaysCard: View {
    let days: [ProgressDayStat]
    
    var body: some View {
        GlassCard(title: "Busiest Days") {
            HStack(spacing: 12) {
                let maxCount = days.map { $0.count }.max() ?? 1
                
                ForEach(days) { dayStat in
                    let fraction = (maxCount <= 0 || dayStat.count <= 0) ? 0.0 : (log10(Double(dayStat.count) + 1.0) / log10(Double(maxCount) + 1.0))
                    
                    VStack(spacing: 8) {
                        // Floating count
                        Text(formatCount(dayStat.count))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(fraction > 0.3 ? .white : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        // Glass Capsule
                        GeometryReader { geo in
                            ZStack(alignment: .bottom) {
                                // Background glass track
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                
                                // Liquid green fill
                                if dayStat.count > 0 {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                colors: [.green.opacity(0.9), .green.opacity(0.3)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(height: max(geo.size.height * CGFloat(fraction), 14)) // Minimum pill size
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                                        )
                                        .shadow(color: .green.opacity(0.3 * fraction), radius: 8, x: 0, y: 0)
                                }
                            }
                        }
                        .frame(height: 120)
                        
                        // Day Label
                        Text(dayStat.day)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(fraction > 0.5 ? .white : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 4)
        }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            let formatted = String(format: "%.1fK", Double(count) / 1000.0)
            return formatted.replacingOccurrences(of: ".0K", with: "K")
        }
        return "\(count)"
    }
}

struct TopGenresCard: View {
    let genres: [ProgressGenreStat]
    
    var body: some View {
        GlassCard(title: "Top Genres") {
            KeywordFlowLayout(spacing: 12) {
                ForEach(genres) { genre in
                    genrePill(genre)
                }
            }
            .padding(.vertical, 10)
        }
    }
    
    private func genrePill(_ genre: ProgressGenreStat) -> some View {
        let hash = abs(genre.name.hashValue)
        let sizes: [CGFloat] = [14, 16, 18, 15, 17]
        let size = sizes[hash % sizes.count]
        
        let rotations: [Double] = [-4, -2, 0, 2, 4, 3, -3]
        let rot = rotations[hash % rotations.count]
        
        return HStack(spacing: 8) {
            Text(genre.name.lowercased())
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(Double(hash % 40 + 60) / 100.0))
            
            Text("\(genre.count)")
                .font(.system(size: size * 0.75, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.3))
                .clipShape(Capsule())
        }
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

struct TopPeopleCard: View {
    let title: String
    let people: [ProgressPersonStat]
    
    var body: some View {
        GlassCard(title: title) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                        TopPersonCell(person: person, index: index)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
}

struct TopPersonCell: View {
    let person: ProgressPersonStat
    let index: Int
    
    var body: some View {
        NavigationLink(value: PersonDetailRoute(personId: person.tmdbId, name: person.name)) {
            Glass3DBox(width: 120, height: 200, depth: 8) {
                VStack(spacing: 0) {
                    personImage
                        .frame(height: 140)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .overlay(
                            // Numbering watermark
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .padding(6),
                            alignment: .topLeading
                        )
                    
                    // Text Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.name)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                        
                        Text("\(person.count) \(person.count == 1 ? "title" : "titles")")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.4))
                }
            } background: {
                personImage
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var personImage: some View {
        if let path = person.profilePath, let url = Config.tmdbImageURL(path: path, size: "w185") {
            CachedImage(url: url) {
                Color(white: 0.15)
            }
        } else {
            Color(white: 0.15)
                .overlay(
                    Text(String(person.name.prefix(1)))
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                )
        }
    }
}

// MARK: - Radical Taste Profile Components

struct TasteCoreView: View {
    let sample: Int
    let avgRating: Double?
    let avgRuntime: Int
    let avgPop: Int
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Background Glow
                Circle()
                    .fill(Color.teal.opacity(0.15))
                    .frame(width: 220, height: 220)
                    .blur(radius: 40)
                
                // Outer Ring: Avg Rating (out of 10)
                let ratingVal = (avgRating ?? 0) / 10.0
                RingView(
                    value: isAnimating ? ratingVal : 0,
                    color: .teal,
                    size: 200,
                    thickness: 16,
                    label: "RATING"
                )
                
                // Middle Ring: Avg Runtime (out of 180 min)
                let runtimeVal = min(Double(avgRuntime) / 180.0, 1.0)
                RingView(
                    value: isAnimating ? runtimeVal : 0,
                    color: .green,
                    size: 160,
                    thickness: 16,
                    label: "TIME"
                )
                
                // Inner Ring: Avg Popularity (out of 100)
                let popVal = min(Double(avgPop) / 100.0, 1.0)
                RingView(
                    value: isAnimating ? popVal : 0,
                    color: .mint,
                    size: 120,
                    thickness: 16,
                    label: "POP."
                )
                
                // Center Core
                VStack(spacing: 2) {
                    Text("\(sample)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("SAMPLE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 240)
            
            // Legend
            HStack(spacing: 20) {
                legendItem(color: .teal, value: avgRating != nil ? String(format: "%.1f", avgRating!) : "—", label: "AVG RATING")
                legendItem(color: .green, value: "\(avgRuntime)m", label: "AVG RUNTIME")
                legendItem(color: .mint, value: "\(avgPop)", label: "AVG POP.")
            }
        }
        .padding(.vertical, 20)
        .onAppear {
            withAnimation(.spring(response: 1.5, dampingFraction: 0.8).delay(0.1)) {
                isAnimating = true
            }
        }
    }
    
    private func legendItem(color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.secondary)
        }
    }
}

struct RingView: View {
    let value: Double
    let color: Color
    let size: CGFloat
    let thickness: CGFloat
    let label: String
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: thickness)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    color.gradient,
                    style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 0)
        }
    }
}

struct TasteOrbCloud<T: Identifiable>: View {
    let title: String
    let items: [T]
    let nameKeyPath: KeyPath<T, String>
    let percentKeyPath: KeyPath<T, Double>
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -10) { // Overlapping effect
                    ForEach(items.prefix(8)) { item in
                        let name = item[keyPath: nameKeyPath]
                        let percent = item[keyPath: percentKeyPath]
                        
                        // Calculate size between 60 and 140 based on percentage
                        let normalizedPercent = max(percent, 0.05)
                        let size = 60 + (normalizedPercent * 160)
                        
                        ZStack {
                            Circle()
                                .fill(color.gradient.opacity(0.2))
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 10)
                            
                            VStack(spacing: 2) {
                                Text("\(Int(round(percent * 100)))%")
                                    .font(.system(size: size * 0.2, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(name)
                                    .font(.system(size: size * 0.12, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                            }
                        }
                        .frame(width: size, height: size)
                        .offset(y: CGFloat.random(in: -20...20)) // Organic staggered look
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 30)
            }
        }
    }
}

struct TasteEraWave: View {
    let decades: [TasteDecadeStat]
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ERA WAVE")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            
            ZStack {
                Chart {
                    ForEach(decades) { decade in
                        AreaMark(
                            x: .value("Decade", decade.label),
                            y: .value("Count", isAnimating ? decade.count : 0)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.teal.opacity(0.6), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        LineMark(
                            x: .value("Decade", decade.label),
                            y: .value("Count", isAnimating ? decade.count : 0)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.caption2.weight(.bold))
                    }
                }
                .frame(height: 160)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                isAnimating = true
            }
        }
    }
}

struct FloatingRebuildButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("REBUILD TASTE PROFILE")
                    .font(.system(size: 13, weight: .black, design: .rounded))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .background(Color.green.opacity(0.3).clipShape(Capsule()))
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
            .foregroundStyle(.white)
            .shadow(color: .green.opacity(0.6), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

struct TasteVersionSubheader: View {
    let version: String
    let keywords: Int
    let people: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cpu")
                .foregroundStyle(.teal)
            
            Text(version.uppercased())
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            
            Divider()
                .frame(height: 12)
                .background(Color.white.opacity(0.3))
            
            Text("\(keywords) KEYWORDS • \(people) PEOPLE")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .background(Color.green.opacity(0.1).clipShape(Capsule()))
        )
        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .green.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct TasteAffinityFooter: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 10))
                Text("CREW & CAST AFFINITY")
                    .font(.system(size: 10, weight: .black, design: .rounded))
            }
            .foregroundStyle(.secondary)
            
            Text("Profile tracks 50 people. Directors, writers, and composers are weighted 3x, 2x, and 1.5x over cast in the ranker.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.gray)
                .lineSpacing(4)
        }
        .padding(.horizontal, 30)
        .padding(.top, 10)
    }
}

struct TasteInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundStyle(.green.gradient)
                            .padding(.bottom, 8)
                        
                        Text("Your Taste Profile")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("A distilled profile built from your watch history and ratings. The picks recommender ranks candidates against this vector. Auto-rebuilds when you cross 10 new watched items; manual rebuild invalidates all pick caches.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(6)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("HOW IT WORKS")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(.secondary)
                            
                            infoRow(icon: "star.fill", color: .teal, title: "Rating Weight", text: "Titles you rate highly have a much stronger influence on your Taste Profile than titles you just watched.")
                            infoRow(icon: "person.2.fill", color: .green, title: "Crew & Cast Affinity", text: "Profile tracks 50 people. Directors, writers, and composers are weighted 3x, 2x, and 1.5x over cast in the ranker.")
                            infoRow(icon: "calendar", color: .mint, title: "Decade Shift", text: "The Era Wave shows your temporal bias, helping the engine recommend older classics or modern hits.")
                        }
                        .padding(.top, 16)
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(.green)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func infoRow(icon: String, color: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color.gradient)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }
        }
    }
}
