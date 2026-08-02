import SwiftUI
import SwiftData

struct FavoriteSearchModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let category: FavoriteCategory
    let timePeriod: FavoriteTimePeriod
    let slotIndex: Int
    
    // Search State
    @State private var query: String = ""
    @State private var searchResults: [TMDBMediaItem] = []
    @State private var isSearching = false
    
    // Selection State
    @State private var selectedItem: TMDBMediaItem? = nil
    @State private var reasonText: String = ""
    @State private var hasLoadedInitialData = false
    
    // Existing item check
    @Query private var existingItems: [FavoriteItem]
    @Query private var userLists: [CachedMediaList]
    
    var body: some View {
        ZStack {
            // Stack without search bar (for Selected State)
            NavigationStack {
                mainView
                    .navigationTitle("\(timePeriod.rawValue) \(categoryNameSingular) #\(slotIndex + 1)")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") { saveFavorite() }
                                .disabled(selectedItem == nil)
                        }
                    }
            }
            .opacity(selectedItem != nil || category == .lists ? 1 : 0)
            .allowsHitTesting(selectedItem != nil || category == .lists)
            
            // Stack with search bar (for Search State)
            NavigationStack {
                mainView
                    .navigationTitle("\(timePeriod.rawValue) \(categoryNameSingular) #\(slotIndex + 1)")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") { saveFavorite() }
                                .disabled(selectedItem == nil)
                        }
                    }
                    .searchable(
                        text: $query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: Text(searchPrompt)
                    )
                    .onSubmit(of: .search) {
                        Task { await performSearch() }
                    }
                    .onChange(of: query) { _, newValue in
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            guard query == newValue else { return }
                            await performSearch()
                        }
                    }
            }
            .opacity(selectedItem == nil && category != .lists ? 1 : 0)
            .allowsHitTesting(selectedItem == nil && category != .lists)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if !hasLoadedInitialData {
                loadExistingData()
                hasLoadedInitialData = true
            }
        }
    }
    
    private var mainView: some View {
        contentZStack
    }
    
    private var contentZStack: some View {
        ZStack {
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .onTapGesture { }
            
            VStack(spacing: 0) {
                    if let selected = selectedItem {
                        // SELECTED STATE
                        ScrollView {
                            VStack(spacing: 24) {
                                // Selected Card
                                HStack(spacing: 16) {
                                    if let path = selected.posterPath, let url = path.hasPrefix("http") ? URL(string: path) : URL(string: "https://image.tmdb.org/t/p/w200\(path)") {
                                        AsyncImage(url: url) { image in
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Color.gray.opacity(0.3)
                                        }
                                        .frame(width: 80, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.black.opacity(0.3))
                                            .frame(width: 80, height: 120)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(selected.title)
                                            .font(.system(size: 28, weight: .black, design: .rounded))
                                            .foregroundStyle(.white)
                                            .lineLimit(2)
                                        
                                        if !selected.year.isEmpty {
                                            Text(selected.year)
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                        
                                        HStack(spacing: 12) {
                                            Button {
                                                withAnimation {
                                                    selectedItem = nil
                                                }
                                            } label: {
                                                Text("Change")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(.white)
                                                    .frame(width: 60)
                                                    .padding(.vertical, 6)
                                                    .background(Capsule().fill(.white.opacity(0.2)))
                                            }
                                            
                                            Button {
                                                deleteFavorite()
                                            } label: {
                                                Text("Delete")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(.red)
                                                    .frame(width: 60)
                                                    .padding(.vertical, 6)
                                                    .background(Capsule().fill(.red.opacity(0.2)))
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(24)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 32))
                                .overlay(RoundedRectangle(cornerRadius: 32).stroke(.white.opacity(0.2), lineWidth: 1))
                                
                                // Reason Text
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("WHY THIS ONE? (optional)")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(.gray)
                                            .tracking(1)
                                        Spacer()
                                        Text("\(reasonText.count)/300")
                                            .font(.system(size: 12))
                                            .foregroundStyle(reasonText.count > 300 ? .red : .gray)
                                    }
                                    
                                    TextEditor(text: $reasonText)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white)
                                        .scrollContentBackground(.hidden)
                                        .padding(8)
                                        .frame(height: 120)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))
                                        .onChange(of: reasonText) { _, newValue in
                                            if newValue.count > 300 {
                                                reasonText = String(newValue.prefix(300))
                                            }
                                        }
                                }
                            }
                            .padding()
                        }
                        
                    } else {
                        // SEARCH STATE
                        VStack(spacing: 0) {
                            if category == .lists {
                                ScrollView {
                                    LazyVStack(spacing: 12) {
                                        if userLists.isEmpty {
                                            Text("No lists found.")
                                                .font(.system(size: 16))
                                                .foregroundStyle(.gray)
                                                .padding(.top, 40)
                                        } else {
                                            ForEach(userLists) { list in
                                                Button {
                                                    withAnimation {
                                                        selectedItem = TMDBMediaItem(
                                                            id: list.remoteId,
                                                            tmdbId: 0,
                                                            mediaType: .movie,
                                                            title: list.name,
                                                            overview: list.listDescription ?? "",
                                                            year: "\(list.itemCount) items",
                                                            posterPath: list.posterURLs.first,
                                                            backdropPath: nil,
                                                            voteAverage: 0,
                                                            voteCount: 0
                                                        )
                                                    }
                                                } label: {
                                                    ListCardView(list: list.toMediaList())
                                                        .padding(.horizontal, 16)
                                                        .contentShape(Rectangle())
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                    .padding(.vertical)
                                }
                            } else {
                                // Results List
                                ScrollView {
                                    LazyVStack(spacing: 12) {
                                    ForEach(searchResults, id: \.id) { item in
                                        Button {
                                            withAnimation {
                                                selectedItem = item
                                            }
                                        } label: {
                                            HStack(spacing: 16) {
                                                if let path = item.posterPath, let url = path.hasPrefix("http") ? URL(string: path) : URL(string: "https://image.tmdb.org/t/p/w200\(path)") {
                                                    AsyncImage(url: url) { image in
                                                        image.resizable().aspectRatio(contentMode: .fill)
                                                    } placeholder: {
                                                        Color.gray.opacity(0.3)
                                                    }
                                                    .frame(width: 40, height: 60)
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                                } else {
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 40, height: 60)
                                                }
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(item.title)
                                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                                        .foregroundStyle(.white)
                                                        .multilineTextAlignment(.leading)
                                                    
                                                    if !item.year.isEmpty {
                                                        Text(item.year)
                                                            .font(.system(size: 14))
                                                            .foregroundStyle(.gray)
                                                    }
                                                }
                                                Spacer()
                                            }
                                            .padding(.horizontal)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Divider().background(.white.opacity(0.1)).padding(.horizontal, 24)
                                    }
                                }
                                .padding(.vertical)
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private var categoryNameSingular: String {
        switch category {
        case .films: return "Movie"
        case .shows: return "Show"
        case .lists: return "List"
        }
    }
    
    private var searchPrompt: String {
        switch category {
        case .films: return "Search movies..."
        case .shows: return "Search shows..."
        case .lists: return "Search lists..."
        }
    }
    
    private func loadExistingData() {
        if let existing = existingItems.first(where: { $0.category == category && $0.timePeriod == timePeriod && $0.slotIndex == slotIndex }) {
            // Reconstruct a dummy TMDBMediaItem for editing state
            // This is a bit hacky but works for the mock/local setup until we fetch full details
            self.selectedItem = TMDBMediaItem(
                id: existing.listId ?? "\(category == .films ? "movie" : "tv")-\(existing.tmdbId)",
                tmdbId: existing.tmdbId,
                mediaType: category == .films ? .movie : .tv,
                title: existing.title,
                overview: "",
                year: existing.releaseYear ?? "",
                posterPath: existing.posterPath,
                backdropPath: nil,
                voteAverage: 0,
                voteCount: 0,
                releaseDate: nil
            )
            self.reasonText = existing.reasonText
        }
    }
    
    private func performSearch() async {
        guard !query.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        
        do {
            let mediaType: MediaType = category == .films ? .movie : .tv
            if category == .lists {
                // Mock lists search since API is disabled for this feature currently
                searchResults = []
            } else {
                let results = try await TMDBService.shared.search(query, mediaType: mediaType)
                await MainActor.run {
                    self.searchResults = results
                }
            }
        } catch {
            print("Search error: \(error)")
        }
    }
    
    private func saveFavorite() {
        guard let selected = selectedItem else { return }
        
        // Find existing to overwrite, or create new
        let existing = existingItems.first(where: { $0.category == category && $0.timePeriod == timePeriod && $0.slotIndex == slotIndex })
        
        let favService = FavoritesService.shared
        let userId = UserDefaults.standard.string(forKey: "publicmetadb.user.id") ?? ""
        
        // Build the API request
        let request = SaveFavoriteRequest(
            user: userId,
            mediaType: category.apiMediaType,
            period: timePeriod.apiPeriod,
            periodKey: timePeriod.apiPeriodKey,
            slot: slotIndex + 1, // API is 1-based
            tmdbId: selected.tmdbId,
            listRef: category == .lists ? selected.id : "",
            title: selected.title,
            posterPath: selected.posterPath ?? "",
            year: category == .lists ? "" : (selected.year ?? ""),
            why: reasonText
        )
        
        if let existing {
            let remoteId = existing.remoteId
            existing.tmdbId = selected.tmdbId
            existing.listId = category == .lists ? selected.id : nil
            existing.title = selected.title
            existing.posterPath = selected.posterPath
            existing.releaseYear = selected.year
            existing.reasonText = reasonText
            // Push to API async (fire-and-forget, update remoteId if new)
            if favService.isLoggedIn {
                let ctx = modelContext
                Task {
                    do {
                        let returnedId = try await favService.saveFavorite(remoteId: remoteId, request: request)
                        await MainActor.run {
                            existing.remoteId = returnedId
                            try? ctx.save()
                        }
                    } catch {
                        print("[Favorites] API save error: \(error)")
                    }
                }
            }
        } else {
            let newFav = FavoriteItem(
                tmdbId: selected.tmdbId,
                listId: category == .lists ? selected.id : nil,
                category: category,
                timePeriod: timePeriod,
                slotIndex: slotIndex,
                title: selected.title,
                posterPath: selected.posterPath,
                releaseYear: selected.year,
                reasonText: reasonText
            )
            modelContext.insert(newFav)
            // Push to API async and store remoteId
            if favService.isLoggedIn {
                let ctx = modelContext
                Task {
                    do {
                        let returnedId = try await favService.saveFavorite(remoteId: nil, request: request)
                        await MainActor.run {
                            newFav.remoteId = returnedId
                            try? ctx.save()
                        }
                    } catch {
                        print("[Favorites] API save error: \(error)")
                    }
                }
            }
        }
        
        dismiss()
    }
    
    private func deleteFavorite() {
        if let existing = existingItems.first(where: { $0.category == category && $0.timePeriod == timePeriod && $0.slotIndex == slotIndex }) {
            let remoteId = existing.remoteId
            modelContext.delete(existing)
            // Delete from API async
            if let rid = remoteId, !rid.isEmpty, FavoritesService.shared.isLoggedIn {
                Task {
                    do {
                        try await FavoritesService.shared.deleteFavorite(remoteId: rid)
                    } catch {
                        print("[Favorites] API delete error: \(error)")
                    }
                }
            }
        }
        dismiss()
    }
}
