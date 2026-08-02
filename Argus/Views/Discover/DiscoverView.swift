import SwiftUI

struct DiscoverView: View {
    @StateObject private var viewModel = DiscoverViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private let skeletonCount = 9
    @State private var showYearLengthSheet = false
    @State private var showWhereSheet = false
    @State private var showGenresSheet = false
    @State private var showPeopleSheet = false
    @State private var showStudioSheet = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {

                    HStack {
                        GlassTabSelector(
                            selection: $viewModel.selectedTab,
                            options: viewModel.isSearchActive ? DiscoverTab.allCases : [.movie, .tv]
                        ) { type in
                            type.rawValue
                        }
                        .onChange(of: viewModel.selectedTab) { _, _ in
                            viewModel.onMediaTypeChanged()
                        }
                        
                        if !viewModel.isSearchActive {
                            Button(action: { viewModel.reroll() }) {
                                Label("Reroll", systemImage: "dice")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .activeLiquidGlass(isActive: false)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    if !viewModel.isSearchActive {
                        filtersPanel
                    }

                    if let error = viewModel.errorMessage, !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(.horizontal, 16)
                    }
                    
                    contentGrid
                }
                .padding(.bottom, 24)
            }
            .background(Color.black.ignoresSafeArea())
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search Movies & Series"
            )
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showYearLengthSheet) {
                yearLengthSheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showWhereSheet) {
                whereSheet
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showGenresSheet) {
                genresSheet
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showPeopleSheet) {
                PeopleSearchSheet(viewModel: viewModel, isPresented: $showPeopleSheet)
                    .presentationDetents([.large])
                    .presentationBackgroundInteraction(.enabled(upThrough: .large))
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showStudioSheet) {
                StudioSearchSheet(viewModel: viewModel, isPresented: $showStudioSheet)
                    .presentationDetents([.large])
                    .presentationBackgroundInteraction(.enabled(upThrough: .large))
                    .presentationDragIndicator(.visible)
            }
            .mediaDetailDestination()
            .onChange(of: viewModel.searchText) { _, _ in viewModel.onSearchTextChanged() }
            .onChange(of: viewModel.watchProviders) { _, _ in viewModel.applyDiscoverFilters() }
            .onChange(of: viewModel.selectedStudios) { _, _ in viewModel.applyDiscoverFilters() }
            .onChange(of: viewModel.selectedPeople) { _, _ in viewModel.applyDiscoverFilters() }
            .onChange(of: viewModel.startYear) { _, _ in viewModel.applyDiscoverFilters() }
            .onChange(of: viewModel.endYear) { _, _ in viewModel.applyDiscoverFilters() }
            .onChange(of: viewModel.minRuntime) { _, _ in viewModel.applyDiscoverFilters() }
            .onChange(of: viewModel.maxRuntime) { _, _ in viewModel.applyDiscoverFilters() }
            .onChange(of: viewModel.ageRating) { _, _ in viewModel.applyDiscoverFilters() }
        }
        .task { 
            await viewModel.load() 
            await viewModel.fetchFilterData()
            viewModel.fetchWatchlist()
        }
        .onChange(of: viewModel.sortMode) { _, _ in viewModel.applyDiscoverFilters() }
        .onChange(of: viewModel.selectedGenres) { _, _ in viewModel.applyDiscoverFilters() }
        .onChange(of: viewModel.postersOnly) { _, _ in viewModel.applyDiscoverFilters() }
        .onChange(of: viewModel.ratedOnly) { _, _ in viewModel.applyDiscoverFilters() }
        .onChange(of: viewModel.isMustSee) { _, _ in viewModel.applyDiscoverFilters() }
        .onChange(of: viewModel.isNoAnimation) { _, _ in viewModel.applyDiscoverFilters() }
        .onChange(of: viewModel.isEnglishOnly) { _, _ in viewModel.applyDiscoverFilters() }
        .onChange(of: viewModel.isNonEnglish) { _, _ in viewModel.applyDiscoverFilters() }
        .onChange(of: viewModel.watchRegion) { _, _ in viewModel.onWatchRegionChanged() }
    }

    @ViewBuilder
    private var contentGrid: some View {
        if viewModel.isLoading {
            loadingGrid
        } else if viewModel.items.isEmpty {
            emptyState
        } else {
            resultsGrid
        }
    }

    private var loadingGrid: some View {
        VStack(spacing: 14) {
            if viewModel.isSearchActive {
                ProgressView()
                    .tint(.white)
                    .controlSize(.regular)
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<skeletonCount, id: \.self) { _ in
                    DiscoverSkeletonCell()
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private var resultsGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.items, id: \.id) { item in
                Group {
                    if item.mediaType == .person {
                        PersonDetailLink(route: PersonDetailRoute(personId: item.tmdbId, name: item.title)) {
                            DiscoverPosterCell(
                                item: item,
                                pmdbRating: viewModel.pmdbRatings[item.tmdbId],
                                logoURL: viewModel.itemLogos[item.tmdbId],
                                cleanPosterURL: viewModel.cleanPosters[item.tmdbId],
                                badgeText: viewModel.getTag(for: item),
                                isInWatchlist: viewModel.isInWatchlist(item),
                                onAddToWatchlist: { viewModel.addToWatchlist(item) },
                                onRemoveFromWatchlist: { viewModel.removeFromWatchlist(item) }
                            )
                        }
                    } else {
                        MediaDetailLink(route: MediaDetailRoute(item: item)) {
                            DiscoverPosterCell(
                                item: item,
                                pmdbRating: viewModel.pmdbRatings[item.tmdbId],
                                logoURL: viewModel.itemLogos[item.tmdbId],
                                cleanPosterURL: viewModel.cleanPosters[item.tmdbId],
                                badgeText: viewModel.getTag(for: item),
                                isInWatchlist: viewModel.isInWatchlist(item),
                                onAddToWatchlist: { viewModel.addToWatchlist(item) },
                                onRemoveFromWatchlist: { viewModel.removeFromWatchlist(item) }
                            )
                        }
                    }
                }
                .onAppear {
                    if item.id == viewModel.items.last?.id {
                        Task { await viewModel.loadNextPageIfNeeded() }
                    }
                }
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .tint(.white)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.isSearchActive {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(GlassTheme.secondaryText)
                Text("No results for \"\(viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                    .font(.subheadline)
                    .foregroundStyle(GlassTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 24)
        }
    }

    private var filtersPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. Quick Filters
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    quickToggle("Posters Only", isOn: $viewModel.postersOnly)
                    quickToggle("Rated Only", isOn: $viewModel.ratedOnly)
                    quickToggle("Must-see", isOn: $viewModel.isMustSee)
                    quickToggle("No animation", isOn: $viewModel.isNoAnimation)
                    quickToggle("English only", isOn: $viewModel.isEnglishOnly)
                    quickToggle("Non-English", isOn: $viewModel.isNonEnglish)
                }
                .padding(.horizontal, 16)
            }
            
            // 2. Advanced Dropdowns
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    Menu {
                        Picker("Sort", selection: Binding(
                            get: { viewModel.sortMode },
                            set: { newValue in
                                viewModel.sortMode = newValue
                                viewModel.applyDiscoverFilters()
                            }
                        )) {
                            ForEach(DiscoverSort.allCases) { sort in
                                Label(sort.rawValue, systemImage: sort.icon).tag(sort)
                            }
                        }
                    } label: { filterLabel("Sort", isActive: viewModel.sortMode != .popular) }

                    Button(action: { showGenresSheet = true }) {
                        filterLabel(viewModel.selectedGenres.isEmpty ? "Genres: Any" : "Genres: \(viewModel.selectedGenres.count)", isActive: !viewModel.selectedGenres.isEmpty)
                    }

                    Button(action: { showWhereSheet = true }) {
                        filterLabel("Where: \(viewModel.watchRegion == "Anywhere" ? "Any" : viewModel.watchRegion)", isActive: viewModel.watchRegion != "Anywhere")
                    }

                    Button(action: { showYearLengthSheet = true }) {
                        filterLabel("Year & Length", isActive: viewModel.startYear > 1900 || viewModel.endYear < 2026 || viewModel.minRuntime != nil || viewModel.maxRuntime != nil || (viewModel.ageRating != nil && viewModel.ageRating != "Any"))
                    }

                    Button(action: { showPeopleSheet = true }) {
                        filterLabel(viewModel.selectedPeople.isEmpty ? "People" : "People: \(viewModel.selectedPeople.count)", isActive: !viewModel.selectedPeople.isEmpty)
                    }

                    Button(action: { showStudioSheet = true }) {
                        filterLabel(viewModel.selectedStudios.isEmpty ? "Studio" : "Studio: \(viewModel.selectedStudios.count)", isActive: !viewModel.selectedStudios.isEmpty)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var yearLengthSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }
                    
                List {
                Section(header: Text("Release Year").foregroundColor(.secondary)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(formattedYear(viewModel.startYear)) - \(formattedYear(viewModel.endYear))")
                            .font(.subheadline)
                        let startBinding = Binding(
                            get: { viewModel.startYear },
                            set: { newValue in
                                if Int(newValue) != Int(viewModel.startYear) {
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                }
                                viewModel.startYear = newValue
                            }
                        )
                        Slider(value: startBinding, in: 1900...2026) { Text("Start") }
                        
                        let endBinding = Binding(
                            get: { viewModel.endYear },
                            set: { newValue in
                                if Int(newValue) != Int(viewModel.endYear) {
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                }
                                viewModel.endYear = newValue
                            }
                        )
                        Slider(value: endBinding, in: 1900...2026) { Text("End") }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                        PillButton(title: "Any", isSelected: viewModel.startYear == 1900 && viewModel.endYear == 2026) {
                            viewModel.startYear = 1900
                            viewModel.endYear = 2026
                        }
                        PillButton(title: "2020s", isSelected: viewModel.startYear == 2020 && viewModel.endYear == 2026) {
                            viewModel.startYear = 2020
                            viewModel.endYear = 2026
                        }
                        PillButton(title: "2010s", isSelected: viewModel.startYear == 2010 && viewModel.endYear == 2019) {
                            viewModel.startYear = 2010
                            viewModel.endYear = 2019
                        }
                        PillButton(title: "2000s", isSelected: viewModel.startYear == 2000 && viewModel.endYear == 2009) {
                            viewModel.startYear = 2000
                            viewModel.endYear = 2009
                        }
                        PillButton(title: "1990s", isSelected: viewModel.startYear == 1990 && viewModel.endYear == 1999) {
                            viewModel.startYear = 1990
                            viewModel.endYear = 1999
                        }
                        PillButton(title: "1980s", isSelected: viewModel.startYear == 1980 && viewModel.endYear == 1989) {
                            viewModel.startYear = 1980
                            viewModel.endYear = 1989
                        }
                        PillButton(title: "1970s", isSelected: viewModel.startYear == 1970 && viewModel.endYear == 1979) {
                            viewModel.startYear = 1970
                            viewModel.endYear = 1979
                        }
                        PillButton(title: "<1970", isSelected: viewModel.startYear == 1900 && viewModel.endYear == 1969) {
                            viewModel.startYear = 1900
                            viewModel.endYear = 1969
                        }
                    }
                    .padding(.top, 4)
                }
                .listRowBackground(Color.white.opacity(0.08))
                .listRowSeparator(.hidden)
                
                Section(header: Text("Runtime (Minutes)").foregroundColor(.secondary)) {
                    HStack {
                        Text("Min:")
                        TextField("e.g. 90", value: $viewModel.minRuntime, format: .number)
                            .keyboardType(.numberPad)
                    }
                    HStack {
                        Text("Max:")
                        TextField("e.g. 150", value: $viewModel.maxRuntime, format: .number)
                            .keyboardType(.numberPad)
                    }
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                        PillButton(title: "Any length", isSelected: viewModel.minRuntime == nil && viewModel.maxRuntime == nil) {
                            viewModel.minRuntime = nil
                            viewModel.maxRuntime = nil
                        }
                        PillButton(title: "< 90 min", isSelected: viewModel.minRuntime == nil && viewModel.maxRuntime == 90) {
                            viewModel.minRuntime = nil
                            viewModel.maxRuntime = 90
                        }
                        PillButton(title: "< 2 hrs", isSelected: viewModel.minRuntime == nil && viewModel.maxRuntime == 120) {
                            viewModel.minRuntime = nil
                            viewModel.maxRuntime = 120
                        }
                        PillButton(title: "< 2.5 hrs", isSelected: viewModel.minRuntime == nil && viewModel.maxRuntime == 150) {
                            viewModel.minRuntime = nil
                            viewModel.maxRuntime = 150
                        }
                    }
                    .padding(.top, 4)
                }
                .listRowBackground(Color.white.opacity(0.08))
                .listRowSeparatorTint(Color.white.opacity(0.15))
                
                Section(header: Text("Age Rating").foregroundColor(.secondary)) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50), spacing: 8)], spacing: 8) {
                        PillButton(title: "Any", isSelected: viewModel.ageRating == nil || viewModel.ageRating == "Any") {
                            viewModel.ageRating = "Any"
                        }
                        ForEach(["G", "PG", "PG-13", "R", "NC-17"], id: \.self) { rating in
                            PillButton(title: rating, isSelected: viewModel.ageRating == rating) {
                                viewModel.ageRating = rating
                            }
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.08))
                .listRowSeparatorTint(Color.white.opacity(0.15))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            }
            .navigationTitle("Year & Length")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        viewModel.startYear = 1900
                        viewModel.endYear = 2026
                        viewModel.minRuntime = nil
                        viewModel.maxRuntime = nil
                        viewModel.ageRating = nil
                    }
                    .disabled(viewModel.startYear == 1900 && viewModel.endYear == 2026 && viewModel.minRuntime == nil && viewModel.maxRuntime == nil && (viewModel.ageRating == nil || viewModel.ageRating == "Any"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showYearLengthSheet = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var genresSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }
                    
                ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                    ForEach(viewModel.availableGenres) { genre in
                        Button {
                            if viewModel.selectedGenres.contains(genre.id) {
                                viewModel.selectedGenres.remove(genre.id)
                            } else {
                                viewModel.selectedGenres.insert(genre.id)
                            }
                        } label: {
                            Text(genre.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(viewModel.selectedGenres.contains(genre.id) ? .white : GlassTheme.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(viewModel.selectedGenres.contains(genre.id) ? .white.opacity(0.2) : .white.opacity(0.05))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(.white.opacity(viewModel.selectedGenres.contains(genre.id) ? 0.8 : 0.1), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowBackground(Color.clear)
            }
            .navigationTitle("Genres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear All") {
                        viewModel.selectedGenres.removeAll()
                    }
                    .disabled(viewModel.selectedGenres.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showGenresSheet = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var whereSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }
                    
                VStack(spacing: 0) {
                // Top Picker
                Picker("Country", selection: $viewModel.watchRegion) {
                    Text("Anywhere").tag("Anywhere")
                    ForEach(viewModel.availableCountries) { country in
                        Text(country.english_name == "United States of America" ? "United States" : country.english_name).tag(country.iso_3166_1)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
                .padding()
                
                Divider().background(Color.white.opacity(0.1))
                
                // Providers Grid
                if viewModel.watchRegion == "Anywhere" {
                    VStack {
                        Spacer()
                        Text("Select a country to view streaming providers.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    }
                } else {
                    ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 16)], spacing: 16) {
                        ForEach(viewModel.availableProviders) { provider in
                            Button {
                                if viewModel.watchProviders.contains(provider.id) {
                                    viewModel.watchProviders.remove(provider.id)
                                } else {
                                    viewModel.watchProviders.insert(provider.id)
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    if let path = provider.logo_path {
                                        CachedImage(url: URL(string: "https://image.tmdb.org/t/p/w200\(path)"), contentMode: .fit) {
                                            Color.gray.opacity(0.3)
                                        }
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .opacity(viewModel.watchProviders.contains(provider.id) ? 1.0 : 0.4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(.white, lineWidth: viewModel.watchProviders.contains(provider.id) ? 2 : 0)
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                } // End of if-else
            }
            .background(Color.clear)
            }
            .navigationTitle("Streaming On")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear All") {
                        viewModel.watchProviders.removeAll()
                    }
                    .disabled(viewModel.watchProviders.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showWhereSheet = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func formattedYear(_ value: Double) -> String {
        Int(value).formatted(.number.grouping(.never))
    }

    private func quickToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Button(action: { isOn.wrappedValue.toggle() }) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .activeLiquidGlass(isActive: isOn.wrappedValue)
        }
    }

    private func filterLabel(_ text: String, isActive: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(text)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .activeLiquidGlass(isActive: isActive)
    }
    
    // MARK: - Search Sheets (moved to dedicated structs below DiscoverView)
    
}

// MARK: - People Search Sheet

struct PeopleSearchSheet: View {
    @ObservedObject var viewModel: DiscoverViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 3. Move Selected Items Below Search
                if !viewModel.selectedPeople.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.selectedPeople, id: \.id) { person in
                                Button(action: {
                                    withAnimation { viewModel.selectedPeople.removeAll(where: { $0.id == person.id }) }
                                }) {
                                    HStack {
                                        Text(person.name)
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color(white: 0.3, opacity: 0.75))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    Divider().background(Color.white.opacity(0.1))
                }

            
            // 2. The Results List
            ScrollView {
                LazyVStack {
                    ForEach(viewModel.peopleSearchResults, id: \.id) { person in
                        Button(action: {
                            withAnimation {
                                if !viewModel.selectedPeople.contains(where: { $0.id == person.id }) {
                                    viewModel.selectedPeople.append(person)
                                }
                                viewModel.peopleSearchQuery = ""
                                viewModel.peopleSearchResults = []
                            }
                        }) {
                            HStack(spacing: 12) {
                                if let path = person.profile_path, let url = URL(string: "https://image.tmdb.org/t/p/w200\(path)") {
                                    CachedImage(url: url) {
                                        Color.gray.opacity(0.3)
                                    }
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 50, height: 50)
                                        .overlay(Image(systemName: "person.fill").foregroundStyle(.white.opacity(0.5)))
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(person.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    if let dept = person.known_for_department {
                                        Text(dept)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            
            
            Spacer(minLength: 0)
        }
        .background(Color.clear)
        .scrollContentBackground(.hidden)
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $viewModel.peopleSearchQuery,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search People..."
        )
        .onChange(of: viewModel.peopleSearchQuery) { _, _ in
            viewModel.onPeopleSearchTextChanged()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Reset") {
                    withAnimation { viewModel.selectedPeople.removeAll() }
                }
                .disabled(viewModel.selectedPeople.isEmpty)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    isPresented = false
                }
            }
        }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Studio Search Sheet

struct StudioSearchSheet: View {
    @ObservedObject var viewModel: DiscoverViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 3. Move Selected Items Below Search
                if !viewModel.selectedStudios.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.selectedStudios, id: \.id) { studio in
                                Button(action: {
                                    withAnimation { viewModel.selectedStudios.removeAll(where: { $0.id == studio.id }) }
                                }) {
                                    HStack {
                                        Text(studio.name)
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color(white: 0.3, opacity: 0.75))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    Divider().background(Color.white.opacity(0.1))
                }
            
            // 2. The Results List
            ScrollView {
                LazyVStack {
                    ForEach(viewModel.studioSearchResults, id: \.id) { studio in
                        Button(action: {
                            withAnimation {
                                if !viewModel.selectedStudios.contains(where: { $0.id == studio.id }) {
                                    viewModel.selectedStudios.append(studio)
                                }
                                viewModel.studioSearchQuery = ""
                                viewModel.studioSearchResults = []
                            }
                        }) {
                            HStack(spacing: 12) {
                                if let path = studio.logo_path, let url = URL(string: "https://image.tmdb.org/t/p/w200\(path)") {
                                    CachedImage(url: url, contentMode: .fit) {
                                        Color.gray.opacity(0.3)
                                    }
                                    .frame(width: 50, height: 50)
                                    .padding(4)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 50, height: 50)
                                        .overlay(Image(systemName: "building.2.fill").foregroundStyle(.white.opacity(0.5)))
                                }
                                Text(studio.name)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            
            Spacer(minLength: 0)
        }
        .background(Color.clear)
        .scrollContentBackground(.hidden)
        .navigationTitle("Studios")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $viewModel.studioSearchQuery,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search Studios..."
        )
        .onChange(of: viewModel.studioSearchQuery) { _, _ in
            viewModel.onStudioSearchTextChanged()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Reset") {
                    withAnimation { viewModel.selectedStudios.removeAll() }
                }
                .disabled(viewModel.selectedStudios.isEmpty)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    isPresented = false
                }
            }
        }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - PillButton
struct PillButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(isSelected ? .white : GlassTheme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? .white.opacity(0.2) : .white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(.white.opacity(isSelected ? 0.8 : 0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
