import SwiftUI

class PersonDetailViewModel: ObservableObject {
    let route: PersonDetailRoute
    @Published var isLoading = true
    @Published var person: TMDBPersonDetailResponse?
    @Published var error: Error?
    
    @Published var selectedMediaType: String = "All"
    @Published var selectedDepartment: String = "All Departments"
    
    @Published var availableDepartments: [String] = ["All Departments"]
    
    // Processed and filtered data
    private var allCredits: [PersonCreditItem] = []
    
    init(route: PersonDetailRoute) {
        self.route = route
    }
    
    var filteredGroupedCredits: [(year: String, items: [PersonCreditItem])] {
        let filtered = allCredits.filter { item in
            let matchesMedia = selectedMediaType == "All" ||
                (selectedMediaType == "Movies" && item.mediaItem.mediaType == .movie) ||
                (selectedMediaType == "Series" && item.mediaItem.mediaType == .tv)
                
            let matchesDept = selectedDepartment == "All Departments" || item.department.contains(selectedDepartment)
            
            return matchesMedia && matchesDept
        }
        
        let grouped = Dictionary(grouping: filtered, by: { $0.yearString })
        return grouped.map { (year: $0.key, items: $0.value) }
            .sorted { a, b in
                if a.year == "Upcoming" { return true }
                if b.year == "Upcoming" { return false }
                return a.year > b.year
            }
    }
    
    @MainActor
    func load() async {
        guard person == nil else { return }
        isLoading = true
        do {
            let response = try await TMDBService.shared.fetchPersonDetail(personId: route.personId)
            self.person = response
            self.processCredits(response)
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    private func processCredits(_ person: TMDBPersonDetailResponse) {
        var mergedItems: [String: PersonCreditItem] = [:]
        var depts: Set<String> = []
        
        let processItem = { (result: TMDBResult, isCast: Bool) in
            let media = result.mediaItem(defaultKind: .movie)
            let dateStr = result.releaseDate ?? result.firstAirDate ?? ""
            let year = String(dateStr.prefix(4))
            
            let dept = isCast ? "Acting" : (result.department ?? "Crew")
            let role = isCast ? (result.character ?? "Unknown Role") : (result.job ?? "Crew")
            let eps = result.episodeCount
            
            if let existing = mergedItems[media.id] {
                // Merge roles and departments
                var newRoles = existing.role
                if !newRoles.contains(role) && !role.isEmpty {
                    newRoles += " / " + role
                }
                
                var newDepts = existing.department
                if !newDepts.contains(dept) {
                    newDepts += ", " + dept
                }
                
                let maxEps = max(existing.episodeCount ?? 0, eps ?? 0)
                
                mergedItems[media.id] = PersonCreditItem(
                    mediaItem: media,
                    department: newDepts,
                    role: newRoles,
                    episodeCount: maxEps > 0 ? maxEps : nil,
                    rawDate: existing.rawDate,
                    yearString: existing.yearString
                )
            } else {
                mergedItems[media.id] = PersonCreditItem(
                    mediaItem: media,
                    department: dept,
                    role: role,
                    episodeCount: eps,
                    rawDate: dateStr,
                    yearString: year.isEmpty ? "Upcoming" : year
                )
            }
            depts.insert(dept)
        }
        
        if let cast = person.combinedCredits?.cast {
            for result in cast { processItem(result, true) }
        }
        
        if let crew = person.combinedCredits?.crew {
            for result in crew { processItem(result, false) }
        }
        
        var items = Array(mergedItems.values)
        
        // Sort items by raw date descending
        items.sort { a, b in
            if a.rawDate.isEmpty && !b.rawDate.isEmpty { return true } // Upcoming first
            if !a.rawDate.isEmpty && b.rawDate.isEmpty { return false }
            return a.rawDate > b.rawDate
        }
        
        self.allCredits = items
        self.availableDepartments = ["All Departments"] + depts.sorted()
    }
}

struct PersonDetailView: View {
    @StateObject private var viewModel: PersonDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isBioExpanded = false
    
    init(route: PersonDetailRoute) {
        _viewModel = StateObject(wrappedValue: PersonDetailViewModel(route: route))
    }
    
    var body: some View {
        ZStack {
            AppBackground()
            
            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
            } else if let person = viewModel.person {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection(person)
                        
                        personalInfoSection(person)
                        
                        if let bio = person.biography, !bio.isEmpty {
                            biographySection(bio)
                        }
                        
                        if let profiles = person.images?.profiles, !profiles.isEmpty {
                            gallerySection(profiles)
                        }
                        
                        if let credits = person.combinedCredits?.cast, !credits.isEmpty {
                            knownForSection(credits)
                        }
                        
                        if !viewModel.availableDepartments.isEmpty {
                            creditsFilterHeader
                            creditsSection
                        }
                    }
                    .padding(.bottom, 40)
                }
                .ignoresSafeArea(edges: .top)
            } else if viewModel.error != nil {
                Text("Failed to load details.")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle(viewModel.route.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private func headerSection(_ person: TMDBPersonDetailResponse) -> some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .global).minY
            let isScrollingDown = minY > 0
            let offset = isScrollingDown ? -minY : 0
            let height = 450 + (isScrollingDown ? minY : 0)
            
            ZStack(alignment: .bottomLeading) {
                // Full bleed background
                if let path = person.profilePath {
                    CachedImage(url: Config.tmdbImageURL(path: path, size: "w780")!) {
                        ZStack {
                            GlassTheme.background
                            Image(systemName: "person.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.1))
                        }
                    }
                    .scaledToFill()
                    .frame(width: geo.size.width, height: height)
                    .clipped()
                } else {
                    ZStack {
                        GlassTheme.background
                        Image(systemName: "person.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.1))
                    }
                    .frame(width: geo.size.width, height: height)
                }
                
                // Gradient fade to background
                LinearGradient(colors: [
                    GlassTheme.background,
                    GlassTheme.background.opacity(0.8),
                    GlassTheme.background.opacity(0.4),
                    .clear
                ], startPoint: .bottom, endPoint: .top)
                .frame(width: geo.size.width, height: height)
                .allowsHitTesting(false)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 4)
                    
                    if let department = person.knownForDepartment {
                        Text(department)
                            .font(.title3.bold())
                            .foregroundStyle(Color.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .frame(width: geo.size.width, height: height)
            .offset(y: offset)
        }
        .frame(height: 450)
    }
    
    private func formatDateString(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .long
            return formatter.string(from: date)
        }
        return dateString
    }
    
    private func personalInfoSection(_ person: TMDBPersonDetailResponse) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if let birthday = person.birthday {
                    infoTag(icon: "calendar", text: "Born \(formatDateString(birthday))")
                }
                if let placeOfBirth = person.placeOfBirth {
                    infoTag(icon: "mappin.and.ellipse", text: placeOfBirth)
                }
                if let deathday = person.deathday {
                    infoTag(icon: "cross.circle", text: "Died \(formatDateString(deathday))")
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func infoTag(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(Color.white.opacity(0.8))
            Text(text)
                .fontWeight(.medium)
        }
        .font(.subheadline)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.1))
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
    
    private func biographySection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderLabel(symbol: "doc.text.fill", title: "Biography", hasBackground: false)
            
            ZStack(alignment: .bottom) {
                Text(bio)
                    .font(.body)
                    .foregroundStyle(GlassTheme.secondaryText)
                    .lineSpacing(6)
                    .lineLimit(isBioExpanded ? nil : 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if !isBioExpanded {
                    LinearGradient(
                        colors: [.clear, Color(white: 0.1).opacity(0.8), Color(white: 0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)
                }
            }
            
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isBioExpanded.toggle()
                }
            }) {
                Text(isBioExpanded ? "Show Less" : "Read More")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.1).opacity(0.6))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    private func knownForSection(_ credits: [TMDBResult]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderLabel(symbol: "star.fill", title: "Known For")
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    let items = credits.prefix(20).map { $0.mediaItem(defaultKind: .movie) }
                    
                    ForEach(items) { item in
                        MediaDetailLink(route: MediaDetailRoute(item: item)) {
                            KnownForCard(item: item)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func gallerySection(_ profiles: [TMDBProfileImage]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderLabel(symbol: "photo.fill", title: "Photos")
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(profiles) { profile in
                        if let url = Config.tmdbImageURL(path: profile.filePath, size: "w185") {
                            CachedImage(url: url) {
                                Color(white: 0.15)
                            }
                            .frame(width: 140, height: 210)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Credits Section
    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            let grouped = viewModel.filteredGroupedCredits
            
            if grouped.isEmpty {
                Text("No credits found.")
                    .foregroundStyle(GlassTheme.secondaryText)
                    .padding()
            } else {
                LazyVStack(spacing: 32) {
                    ForEach(grouped, id: \.year) { group in
                        VStack(alignment: .leading, spacing: 16) {
                            // Year Timeline Node
                            HStack(alignment: .center, spacing: 16) {
                                Circle()
                                    .fill(Color.white.opacity(0.8))
                                    .frame(width: 8, height: 8)
                                    .shadow(color: .white, radius: 4, x: 0, y: 0)
                                
                                Text(group.year)
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal)
                            
                            // Cards for this year
                            VStack(spacing: 16) {
                                ForEach(group.items) { item in
                                    MediaDetailLink(route: MediaDetailRoute(item: item.mediaItem)) {
                                        CinematicCreditCardView(item: item)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.leading, 12) // indent under the timeline node
                            .overlay(
                                // Subtle timeline connecting line
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
                .padding(.top, 16)
            }
        }
    }
    
    private var creditsFilterHeader: some View {
        HStack {
            SectionHeaderLabel(symbol: "list.bullet.rectangle.fill", title: "Credits")
            
            Spacer()
            
            // Filters encapsulated in a glass pill
            HStack(spacing: 16) {
                Menu {
                    Button(action: { viewModel.selectedMediaType = "All" }) {
                        Label("All", systemImage: "square.stack.3d.up")
                    }
                    Button(action: { viewModel.selectedMediaType = "Movies" }) {
                        Label("Movies", systemImage: "film")
                    }
                    Button(action: { viewModel.selectedMediaType = "Series" }) {
                        Label("Series", systemImage: "tv")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.selectedMediaType)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .contentShape(Rectangle())
                }
                .id("mediaType_\(viewModel.selectedMediaType)")
                
                Divider()
                    .frame(height: 12)
                    .background(Color.white.opacity(0.5))
                
                Menu {
                    ForEach(viewModel.availableDepartments, id: \.self) { dept in
                        Button(action: { viewModel.selectedDepartment = dept }) {
                            Label(dept, systemImage: iconForDepartment(dept))
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.selectedDepartment)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .contentShape(Rectangle())
                }
                .id("department_\(viewModel.selectedDepartment)")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(white: 0.1).opacity(0.8))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal)
        .zIndex(1)
    }
}

// Global helper for icons
func iconForDepartment(_ dept: String) -> String {
    switch dept {
    case "All Departments": return "briefcase"
    case "Acting": return "theatermasks"
    case "Directing": return "megaphone"
    case "Writing": return "pencil.and.outline"
    case "Production": return "film.stack"
    case "Camera": return "camera"
    case "Art": return "paintpalette"
    case "Sound": return "waveform"
    case "Editing": return "scissors"
    case "Crew": return "person.3"
    default: return "star"
    }
}

struct CinematicCreditCardView: View {
    let item: PersonCreditItem
    
    var body: some View {
        HStack(spacing: 16) {
            // Poster
            if let url = item.mediaItem.posterURL {
                CachedImage(url: url) {
                    Color(white: 0.15)
                }
                .frame(width: 70, height: 105)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 3)
            } else {
                ZStack {
                    Color(white: 0.15)
                    Image(systemName: item.mediaItem.mediaType == .movie ? "film" : (item.mediaItem.mediaType == .tv ? "tv" : "person.fill"))
                        .font(.largeTitle)
                        .foregroundStyle(.gray.opacity(0.5))
                }
                .frame(width: 70, height: 105)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Details
            VStack(alignment: .leading, spacing: 8) {
                Text(item.mediaItem.title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    .lineLimit(2)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        // Department Badges (Dynamic split)
                        ForEach(item.department.components(separatedBy: ", "), id: \.self) { dept in
                            HStack(spacing: 4) {
                                Image(systemName: iconForDepartment(dept))
                                Text(dept)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                        }
                        
                        // Type Badge
                        if item.mediaItem.mediaType == .movie {
                            HStack(spacing: 4) {
                                Image(systemName: "film")
                                Text("Movie")
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.4))
                            .clipShape(Capsule())
                        } else if item.mediaItem.mediaType == .tv {
                            HStack(spacing: 4) {
                                Image(systemName: "tv")
                                Text("Series")
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.4))
                            .clipShape(Capsule())
                        }
                        
                        // Episode Badge
                        if let eps = item.episodeCount, eps > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "play.rectangle.on.rectangle")
                                Text("\(eps) eps")
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.indigo.opacity(0.4))
                            .clipShape(Capsule())
                        }
                        
                        // Score Badge
                        if item.mediaItem.voteAverage > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", item.mediaItem.voteAverage))
                                    .fontWeight(.bold)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.2))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 2) // Prevents clipping inside the ScrollView
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(item.role)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .padding(12)
        .background {
            // Cinematic Background
            ZStack {
                if let url = item.mediaItem.posterURL {
                    CachedImage(url: url) { Color.clear }
                        .scaledToFill()
                        .blur(radius: 40)
                        .opacity(1.0)
                }
                Color.black.opacity(0.2)
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}
struct KnownForCard: View {
    let item: TMDBMediaItem
    @State private var logoURL: URL? = nil
    
    var body: some View {
        ZStack {
            // Background Image
            if let url = item.backdropURL {
                CachedImage(url: url) {
                    Color(white: 0.15)
                }
            } else if let url = item.posterURL {
                // Fallback to poster if no backdrop exists
                CachedImage(url: url) {
                    Color(white: 0.15)
                }
            } else {
                Color(white: 0.15)
            }
            
            // Dim overlay to make logo/text readable
            Color.black.opacity(0.4)
            
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
            

            
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                startPoint: .center,
                endPoint: .bottom
            )
            
            // Logo (or title fallback)
            if let logoURL = logoURL {
                CachedImage(url: logoURL) {
                    Color.clear
                }
                .scaledToFit()
                .padding(24)
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            } else {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .kerning(0.5)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(white: 1.0), Color(white: 0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .multilineTextAlignment(.center)
                    .shadow(color: .black, radius: 1, x: 0, y: 1)
                    .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                    .padding()
            }
        }
        .frame(width: 240, height: 135)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        // Liquid Glass border
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.8), location: 0.0),
                            .init(color: .white.opacity(0.3), location: 0.2),
                            .init(color: .white.opacity(0.2), location: 0.5),
                            .init(color: .white.opacity(0.3), location: 0.8),
                            .init(color: .white.opacity(0.5), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        // Inner rim for 3D thickness
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                .padding(1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 10)
        )
        .task {
            // Lazy fetch logo from full detail payload
            do {
                let info = try await TMDBService.shared.fetchDetailInfo(tmdbId: item.tmdbId, mediaType: item.mediaType)
                if let path = info.logoPath {
                    self.logoURL = URL(string: "https://image.tmdb.org/t/p/w500" + path)
                }
            } catch {
                // Ignore errors and keep text fallback
            }
        }
    }
}
