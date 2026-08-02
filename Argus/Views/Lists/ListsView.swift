import SwiftUI
import SwiftData
import WebKit

enum ListTab: String, CaseIterable {
    case myLists = "My Lists"
    case discover = "Discover"
}

struct ListsView: View {
    @StateObject private var viewModel = ListsViewModel()
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedTab: ListTab = .myLists
    @State private var showCreateSheet = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    pickerView
                    errorView
                    
                    ZStack(alignment: .top) {
                        // Attach searchable independently so it doesn't break the content transitions
                        Color.clear
                            .frame(width: 0, height: 0)
                            .searchable(
                                text: $viewModel.searchText,
                                placement: .navigationBarDrawer(displayMode: .always),
                                prompt: selectedTab == .discover ? "Search public lists..." : "Search my lists..."
                            )
                        
                        discoverTab
                            .id("discoverGrid")
                            .opacity(selectedTab == .discover ? 1 : 0)
                            .allowsHitTesting(selectedTab == .discover)
                            
                        myListsTab
                            .id("myListsGrid")
                            .opacity(selectedTab == .myLists ? 1 : 0)
                            .allowsHitTesting(selectedTab == .myLists)
                    }
                    .animation(.easeInOut(duration: 0.25), value: selectedTab)
                }
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("Lists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if selectedTab == .myLists {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateListSheet(isPresented: $showCreateSheet) {
                    Task {
                        await viewModel.refresh(showLoading: true)
                    }
                }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .mediaDetailDestination()
            .navigationDestination(for: MediaList.self) { list in
                WatchlistDetailView(list: list)
            }
            .task {
                viewModel.configure(context: modelContext)
                await viewModel.refresh()
            }
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.performSearch()
            }
        }
    }
    
    @ViewBuilder
    private var pickerView: some View {
        VStack(spacing: 12) {
            GlassTabSelector(selection: $selectedTab, options: ListTab.allCases) { tab in
                tab.rawValue
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 10)
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var errorView: some View {
        if let error = viewModel.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red.opacity(0.85))
                .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Discover Tab
    private var discoverTab: some View {
        VStack(spacing: 16) {
            if viewModel.isSearching {
                ProgressView("Searching...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding(.top, 50)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isDiscoverLoading {
                VStack {
                    LottieWebView(data: NSDataAsset(name: "listsloader_lottie")?.data)
                        .frame(width: 180, height: 180)
                    Text("Discovering public lists...")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .kerning(0.5)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color(red: 0.8, green: 0.95, blue: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                        .padding(.top, -12)
                }
                .padding(.top, 50)
                .frame(maxWidth: .infinity)
            } else if viewModel.discoverLists.isEmpty {
                Text("No public lists found.")
                    .font(.subheadline)
                    .foregroundStyle(GlassTheme.secondaryText)
                    .padding(.top, 40)
            } else {
                ForEach(viewModel.discoverLists, id: \.id) { list in
                    NavigationLink(value: list) {
                        DiscoverListCard(list: list)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if viewModel.lists.contains(where: { $0.id == list.id }) {
                            if viewModel.isListSaved(listId: list.id) {
                                Button(role: .destructive) {
                                    viewModel.removeList(listId: list.id)
                                } label: {
                                    Label {
                                        Text("Remove from My Lists")
                                    } icon: {
                                        Image(systemName: "xmark.circle")
                                            .renderingMode(.template)
                                    }
                                }
                                .tint(.red)
                                .foregroundStyle(.red)
                            } else {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteList(list) }
                                } label: {
                                    Label {
                                        Text("Delete List")
                                    } icon: {
                                        Image(systemName: "trash")
                                            .renderingMode(.template)
                                    }
                                }
                                .tint(.red)
                                .foregroundStyle(.red)
                            }
                        } else {
                            Button {
                                viewModel.addList(list: list)
                            } label: {
                                Label("Add to My Lists", systemImage: "plus.circle")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    // MARK: - My Lists Tab
    private var myListsTab: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonListCard()
                        .padding(.horizontal, 16)
                }
            } else if viewModel.filteredMyLists.isEmpty {
                Text(viewModel.searchText.isEmpty ? "No lists found." : "No lists match '\(viewModel.searchText)'.")
                    .font(.subheadline)
                    .foregroundStyle(GlassTheme.secondaryText)
                    .padding(.top, 40)
            } else {
                ForEach(viewModel.filteredMyLists) { list in
                    NavigationLink(value: list) {
                        ListCardView(list: list)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .contextMenu {
                        if list.name != "My Watchlist" {
                            if viewModel.isListSaved(listId: list.id) {
                                Button(role: .destructive) {
                                    viewModel.removeList(listId: list.id)
                                } label: {
                                    Label {
                                        Text("Remove from My Lists")
                                    } icon: {
                                        Image(systemName: "xmark.circle")
                                            .renderingMode(.template) 
                                    }
                                }
                                .tint(.red)
                                .foregroundStyle(.red)
                            } else {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteList(list) }
                                } label: {
                                    Label {
                                        Text("Delete List")
                                    } icon: {
                                        Image(systemName: "trash")
                                            .renderingMode(.template) 
                                    }
                                }
                                .tint(.red)
                                .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - DiscoverListCard
struct DiscoverListCard: View {
    let list: MediaList
    @State private var userProfile: UserProfile?
    
    var body: some View {
        VStack(spacing: 0) {
            // Top 75%: Poster Collage
            ZStack(alignment: .bottomTrailing) {
                // Background for the top part
                Color(white: 0.12)
                
                GeometryReader { geo in
                    let posterHeight = geo.size.height
                    let posterWidth = posterHeight * (2.0 / 3.0)
                    
                    let availableWidth = geo.size.width
                    let maxPosters = 6
                    let count = maxPosters
                    
                    let spacing: CGFloat = {
                        let s = (availableWidth - (CGFloat(count) * posterWidth)) / CGFloat(count - 1)
                        return min(s, -10)
                    }()
                    
                    HStack(spacing: spacing) {
                        ForEach(0..<count, id: \.self) { index in
                            Group {
                                if index < list.previewPosters.count {
                                    CachedImage(url: list.previewPosters[index]) {
                                        Color.gray.opacity(0.3)
                                    }
                                } else {
                                    Color.white.opacity(0.05)
                                }
                            }
                            .frame(width: posterWidth, height: posterHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 4, x: -2, y: 0)
                            .zIndex(Double(index))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                GlassPill(text: "\(list.itemCount ?? 0) items")
                    .padding(12)
            }
            .frame(height: 180 * 0.75) // 75% of card height
            
            // Bottom 25%: Metadata
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(list.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Description
                if let desc = list.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // User info
                if let profile = userProfile, !profile.name.isEmpty {
                    HStack(spacing: 6) {
                        if let avatarUrl = profile.avatarUrl {
                            CachedImage(url: avatarUrl) {
                                Circle().fill(Color.white.opacity(0.1))
                            }
                            .frame(width: 20, height: 20)
                            .clipShape(Circle())
                        } else {
                            Text(String(profile.name.prefix(1)).uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 20, height: 20)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                                .foregroundColor(.secondary)
                        }
                        
                        Text(profile.name)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            ZStack {
                Rectangle().fill(.thinMaterial)
                
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
                

            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // Liquid Glass border
        .overlay(
            RoundedRectangle(cornerRadius: 16)
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
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                .padding(1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 10)
        )
        .task {
            if let creatorName = list.creatorName {
                var avatarUrl: URL? = nil
                if let avatar = list.creatorAvatar, !avatar.isEmpty, let cId = list.creatorId {
                    avatarUrl = URL(string: "https://api.publicmetadb.com/api/files/users/\(cId)/\(avatar)")
                }
                userProfile = UserProfile(name: creatorName, avatarUrl: avatarUrl)
            } else if let userId = list.user {
                userProfile = await UserService.shared.fetchUserProfile(id: userId)
            }
        }
    }
}

// MARK: - WatchlistDetailView
struct WatchlistDetailView: View {
    let list: MediaList
    @StateObject private var viewModel = ListsViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSort: SortOption = .defaultSort
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 40)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding()
            } else if viewModel.listItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 40))
                        .foregroundStyle(GlassTheme.secondaryText)
                    Text("No items in this list yet.")
                        .font(.subheadline)
                        .foregroundStyle(GlassTheme.secondaryText)
                }
                .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.listItems) { item in
                        MediaDetailLink(route: MediaDetailRoute(item: item)) {
                            let mediaItem = item.toMediaItem()
                            DiscoverPosterCell(
                                item: mediaItem,
                                pmdbRating: viewModel.pmdbRatings[mediaItem.tmdbId],
                                logoURL: viewModel.itemLogos[mediaItem.tmdbId],
                                cleanPosterURL: viewModel.cleanPosters[mediaItem.tmdbId],
                                badgeText: BadgeEngine.getTag(for: mediaItem),
                                isInWatchlist: viewModel.isInWatchlist(item),
                                onAddToWatchlist: {
                                    viewModel.addToWatchlist(item)
                                },
                                onRemoveFromWatchlist: {
                                    viewModel.removeFromWatchlist(item)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .background(AppBackground())
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.configure(context: modelContext)
            await viewModel.loadItems(for: list)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Text("**Sort By**")
                        .foregroundStyle(.gray)
                    
                    Picker("Sort Options", selection: $selectedSort) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Label(option.rawValue, systemImage: option.icon).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
        }
        .onChange(of: selectedSort) { _, newValue in
            viewModel.sortListItems(by: newValue)
        }
    }
}

// MARK: - ListCardView
struct ListCardView: View {
    let list: MediaList
    @State private var userProfile: UserProfile?
    
    var body: some View {
        VStack(spacing: 0) {
            // Top 75%: Poster Collage
            ZStack(alignment: .bottomTrailing) {
                GeometryReader { geo in
                    let posterHeight = geo.size.height
                    let posterWidth = posterHeight * (2.0 / 3.0)
                    
                    let availableWidth = geo.size.width
                    let maxPosters = 6
                    let count = list.previewPosters.isEmpty ? maxPosters : min(maxPosters, list.previewPosters.count)
                    
                    let spacing: CGFloat = {
                        if count <= 1 { return 0 }
                        let s = (availableWidth - (CGFloat(count) * posterWidth)) / CGFloat(count - 1)
                        return min(s, -10)
                    }()
                    
                    HStack(spacing: spacing) {
                        ForEach(0..<count, id: \.self) { index in
                            Group {
                                if index < list.previewPosters.count {
                                    CachedImage(url: list.previewPosters[index]) {
                                        Color.gray.opacity(0.3)
                                    }
                                } else {
                                    Color.white.opacity(0.05)
                                }
                            }
                            .frame(width: posterWidth, height: posterHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 4, x: -2, y: 0)
                            .zIndex(Double(index))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                GlassPill(text: "\(list.itemCount ?? 0) items")
                    .padding(12)
            }
            .frame(height: 180 * 0.75) // 75% of card height
            
            // Bottom 25%: Metadata
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(list.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Description
                if let desc = list.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // User info
                if let profile = userProfile, !profile.name.isEmpty {
                    HStack(spacing: 6) {
                        if let avatarUrl = profile.avatarUrl {
                            CachedImage(url: avatarUrl) {
                                Circle().fill(Color.white.opacity(0.1))
                            }
                            .frame(width: 20, height: 20)
                            .clipShape(Circle())
                        } else {
                            Text(String(profile.name.prefix(1)).uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 20, height: 20)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                                .foregroundColor(.secondary)
                        }
                        
                        Text(profile.name)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            ZStack {
                Rectangle().fill(.thinMaterial)
                
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
                

            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // Liquid Glass border
        .overlay(
            RoundedRectangle(cornerRadius: 16)
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
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                .padding(1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 10)
        )
        .task {
            if let creatorName = list.creatorName {
                var avatarUrl: URL? = nil
                if let avatar = list.creatorAvatar, !avatar.isEmpty, let cId = list.creatorId {
                    avatarUrl = URL(string: "https://api.publicmetadb.com/api/files/users/\(cId)/\(avatar)")
                }
                userProfile = UserProfile(name: creatorName, avatarUrl: avatarUrl)
            } else if let userId = list.user {
                userProfile = await UserService.shared.fetchUserProfile(id: userId)
            }
        }
    }
}

// MARK: - SkeletonListCard
struct SkeletonListCard: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 150, height: 20)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 16)
                
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 70, height: 24)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .redacted(reason: .placeholder)
    }
}


