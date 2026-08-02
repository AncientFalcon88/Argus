import SwiftUI

// 1. Enums for our interactive states
enum RefreshRate: String, CaseIterable {
    case threeHours = "Every 3 hours"
    case sixHours = "Every 6 hours"
    case twelveHours = "Every 12 hours"
    case twentyFourHours = "Every 24 hours"
}

enum LayoutStyle {
    case rails, compact
}

struct CommandButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(color)
                    .shadow(color: color.opacity(0.5), radius: 4, y: 2)
                
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(Color.white.opacity(0.04))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }
}

struct PicksView: View {
    // Inject the ViewModel
    @StateObject private var viewModel = PicksViewModel()
    

    @State private var layout: LayoutStyle = .rails
    @State private var isShowingNewPickSheet = false
    @State private var isShowingNewRecipeSheet = false
    @State private var itemForWhyThis: CatalogItem? = nil
    @State private var catalogToEdit: PickCatalog? = nil
    
    @State private var isShowingAddonSheet = false
    
    @State private var isShowingImportAlert = false
    @State private var importJsonString = ""
    
    // Grid configuration for Compact mode
    let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]
    
    var body: some View {
        ZStack {
            NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    

                    if !viewModel.isLoading {
                        // MARK: Command Center Dashboard
                        VStack(spacing: 16) {
                        // Top Row: Status & Auto-Refresh
                        HStack(spacing: 8) {
                            
                            // Addon Button
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isShowingAddonSheet = true
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "puzzlepiece.extension")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("Addon")
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.2))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                            
                            // Auto-Refresh Picker Menu
                            Menu {
                                Picker("Refresh Rate", selection: Binding(
                                    get: {
                                        switch viewModel.refreshRateHours {
                                        case 3: return RefreshRate.threeHours
                                        case 6: return RefreshRate.sixHours
                                        case 12: return RefreshRate.twelveHours
                                        case 24: return RefreshRate.twentyFourHours
                                        default: return RefreshRate.twentyFourHours
                                        }
                                    },
                                    set: { (newRate: RefreshRate) in
                                        Task {
                                            var hours = 24
                                            switch newRate {
                                            case .threeHours: hours = 3
                                            case .sixHours: hours = 6
                                            case .twelveHours: hours = 12
                                            case .twentyFourHours: hours = 24
                                            }
                                            await viewModel.updateRefreshRate(hours: hours)
                                        }
                                    }
                                )) {
                                    ForEach(RefreshRate.allCases, id: \.self) { rate in
                                        Text(rate.rawValue).tag(rate)
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 12, weight: .bold))
                                    Text(
                                        (viewModel.refreshRateHours == 3 ? RefreshRate.threeHours :
                                         viewModel.refreshRateHours == 6 ? RefreshRate.sixHours :
                                         viewModel.refreshRateHours == 12 ? RefreshRate.twelveHours : RefreshRate.twentyFourHours).rawValue.replacingOccurrences(of: "Every ", with: "")
                                    )
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                        .frame(width: 58, alignment: .leading)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.2))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                            
                            // 5/5 Quota Indicator
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 12))
                                Text("\(viewModel.quotaRemaining ?? 5)/5")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Left Today")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.2))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        // Bottom Row: Action Grid
                        HStack(spacing: 12) {
                            CommandButton(
                                title: "IMPORT",
                                icon: "square.and.arrow.down",
                                color: .green
                            ) {
                                importJsonString = ""
                                isShowingImportAlert = true
                            }
                            
                            CommandButton(
                                title: "NEW PICK",
                                icon: "plus",
                                color: .blue
                            ) {
                                isShowingNewPickSheet = true
                            }
                            
                            CommandButton(
                                title: "NEW RECIPE",
                                icon: "wand.and.stars",
                                color: Color(red: 0.45, green: 0.2, blue: 0.8)
                            ) {
                                isShowingNewRecipeSheet = true
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
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
                    .padding(.horizontal)
                    }
                    
                    if viewModel.isLoading {
                        VStack(spacing: 0) {
                            LottieWebView(data: NSDataAsset(name: "blackrainbowcat")?.data)
                                .frame(width: 200, height: 200)

                            Text("Crunching your taste profile...")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .kerning(0.5)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1, green: 0.2, blue: 0.3),
                                            Color(red: 1, green: 0.6, blue: 0),
                                            Color(red: 1, green: 0.9, blue: 0),
                                            Color(red: 0.2, green: 0.9, blue: 0.4),
                                            Color(red: 0.2, green: 0.6, blue: 1),
                                            Color(red: 0.6, green: 0.2, blue: 1)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                        }
                        .padding(.top, 150)
                        .padding(.bottom, 100)
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else if let error = viewModel.errorMessage {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        // 3. The Generated Picks Carousels
                        ForEach(viewModel.picks) { catalog in
                            if let items = viewModel.pickItems[catalog.id] {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Category Header
                                    NavigationLink(value: catalog) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 10) {
                                                if let recipeType = NewPickSheetView.RecipeType(rawValue: catalog.name) {
                                                    Image(systemName: recipeType.iconName)
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundStyle(.gray)
                                                        .frame(width: 32, height: 32)
                                                        .background(.ultraThinMaterial)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                } else if let template = NewRecipeSheet.allRecipes.first(where: { $0.name == catalog.name }) {
                                                    Image(systemName: template.icon)
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundStyle(.gray)
                                                        .frame(width: 32, height: 32)
                                                        .background(.ultraThinMaterial)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                }
                                                
                                                HStack(spacing: 4) {
                                                    Text(catalog.name).font(.system(size: 20, weight: .heavy, design: .rounded)).foregroundColor(.white)
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                                        .foregroundStyle(GlassTheme.secondaryText)
                                                }
                                            }
                                            if let desc = catalog.description, !desc.isEmpty {
                                                Text(desc)
                                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                                    .foregroundColor(.gray)
                                                    .multilineTextAlignment(.leading)
                                            }
                                        }
                                        .frame(minHeight: 32)
                                    }
                                    .padding(.trailing, 44) // Leave space for button
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .overlay(alignment: .topTrailing) {
                                        Menu {
                                            Button {
                                                Task {
                                                    try? await viewModel.refreshPick(catalogId: catalog.id)
                                                }
                                            } label: {
                                                Label("Refresh", systemImage: "arrow.clockwise")
                                            }

                                            Button {
                                                catalogToEdit = catalog
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }

                                            Button {
                                                // Serialize entire catalog config to JSON and copy to clipboard
                                                let encoder = JSONEncoder()
                                                encoder.outputFormatting = .prettyPrinted
                                                if let data = try? encoder.encode(catalog),
                                                   let jsonString = String(data: data, encoding: .utf8) {
                                                    UIPasteboard.general.string = jsonString
                                                }
                                            } label: {
                                                Label("Copy JSON", systemImage: "doc.on.doc")
                                            }

                                            Divider()

                                            Button(role: .destructive) {
                                                Task {
                                                    try? await viewModel.deletePick(catalogId: catalog.id)
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            .tint(.red)
                                            .foregroundStyle(.red)
                                        } label: {
                                            Image(systemName: "slider.horizontal.3")
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .frame(width: 32, height: 32)
                                                .background(.ultraThinMaterial)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.horizontal)
                                
                                // The Liquid Glass Media Cards
                                if viewModel.isRefreshingCatalog[catalog.id] == true {
                                    if layout == .rails {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            LazyHStack(spacing: 16) {
                                                ForEach(0..<5, id: \.self) { _ in
                                                    SkeletonDiscoverPosterCell(customWidth: 140)
                                                }
                                            }
                                            .padding(.horizontal)
                                            .scrollTargetLayout()
                                        }
                                        .scrollTargetBehavior(.viewAligned)
                                    } else {
                                        LazyVGrid(columns: columns, spacing: 16) {
                                            ForEach(0..<6, id: \.self) { _ in
                                                SkeletonDiscoverPosterCell()
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                } else if viewModel.pickItems[catalog.id] != nil && items.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "sparkles.rectangle.stack")
                                            .font(.system(size: 32, weight: .light, design: .rounded))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [Color.white, Color.white.opacity(0.4)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .padding(.bottom, 4)
                                        
                                        Text("No Matches Found")
                                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                                            .foregroundColor(.white)
                                        
                                        Text("Your recipe is a bit too strict. Let's tweak the ingredients to find some great titles.")
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.6))
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 16)
                                        
                                        Button(action: {
                                            catalogToEdit = catalog
                                        }) {
                                            Text("Adjust Recipe")
                                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 10)
                                                .background(Color.white)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain) // Prevents the whole List row from triggering if inside list
                                        .padding(.top, 8)
                                    }
                                    .padding(.vertical, 32)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.02))
                                    .liquidGlass(cornerRadius: 24)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 0.5
                                            )
                                    )
                                    .padding(.horizontal)
                                } else if layout == .rails {

                                    // Horizontal Rail
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        LazyHStack(spacing: 16) {
                                            ForEach(items) { item in
                                                NavigationLink(value: MediaDetailRoute(item: item)) {
                                                    let mediaItem = item.toMediaItem()
                                                    let badgeText = BadgeEngine.getTag(for: mediaItem)
                                                    DiscoverPosterCell(
                                                        item: mediaItem,
                                                        tmdbRating: item.voteAverage,
                                                        logoURL: viewModel.itemLogos[mediaItem.tmdbId],
                                                        cleanPosterURL: viewModel.cleanPosters[mediaItem.tmdbId],
                                                        badgeText: badgeText.isEmpty ? nil : badgeText,
                                                        percentageMatch: item.calculatedPercentage,
                                                        isInWatchlist: false,
                                                        hideDefaultContextMenu: true, hideGenre: true,
                                                        onAddToWatchlist: {},
                                                        onRemoveFromWatchlist: {},
                                                        onWhyThis: { itemForWhyThis = item },
                                                        onNoThanks: { viewModel.hideItem(catalogId: catalog.id, item: item) },
                                                        customWidth: 140
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                                .zIndex(0)
                                            }
                                            if viewModel.hasMorePages[catalog.id, default: true] {
                                                MorePickCard(
                                                    catalogId: catalog.id,
                                                    nextPage: viewModel.currentPage[catalog.id, default: 1] + 1,
                                                    viewModel: viewModel
                                                )
                                            }
                                        }
                                        .padding(.horizontal)
                                        .scrollTargetLayout()
                                    }
                                    .scrollTargetBehavior(.viewAligned)
                                } else {
                                    // Compact Grid Layout
                                    LazyVGrid(columns: columns, spacing: 16) {
                                        ForEach(items) { item in
                                            NavigationLink(value: MediaDetailRoute(item: item)) {
                                                let mediaItem = item.toMediaItem()
                                                let badgeText = BadgeEngine.getTag(for: mediaItem)
                                                DiscoverPosterCell(
                                                    item: mediaItem,
                                                    tmdbRating: item.voteAverage,
                                                    logoURL: viewModel.itemLogos[mediaItem.tmdbId],
                                                    cleanPosterURL: viewModel.cleanPosters[mediaItem.tmdbId],
                                                    badgeText: badgeText.isEmpty ? nil : badgeText,
                                                    percentageMatch: item.calculatedPercentage,
                                                    isInWatchlist: false,
                                                    hideDefaultContextMenu: true, hideGenre: true,
                                                    onAddToWatchlist: {},
                                                    onRemoveFromWatchlist: {},
                                                    onWhyThis: { itemForWhyThis = item },
                                                    onNoThanks: { viewModel.hideItem(catalogId: catalog.id, item: item) }
                                                )
                                            }
                                            .buttonStyle(.plain)
                                            .zIndex(0)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.bottom, 16)
                            } // Closes if let
                        }
                    }
                }
                .padding(.top, 16)
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationTitle("Picks")
            .navigationBarTitleDisplayMode(.large)
            .mediaDetailDestination()
            .navigationDestination(for: PickCatalog.self) { catalog in
                PicksGridView(catalog: catalog, viewModel: viewModel)
            }
            .sheet(isPresented: $isShowingImportAlert) {
                ImportRecipeSheetView(
                    isPresented: $isShowingImportAlert,
                    importJsonString: $importJsonString,
                    onImport: handleImportJSON
                )
                .presentationDetents([.large])
            }
        }
        .task {
            async let addonFetch: () = viewModel.fetchAddonData()
            if viewModel.picks.isEmpty {
                await viewModel.fetchPersonalizedPicks()
            }
            _ = await addonFetch
        }
        .sheet(isPresented: $isShowingNewPickSheet) {
            NewPickSheetView(isPresented: $isShowingNewPickSheet, viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingNewRecipeSheet) {
            NewRecipeSheet(viewModel: viewModel)
        }
        .sheet(item: $itemForWhyThis) { item in
            WhyThisSheetView(item: item)
                .presentationDetents([.height(410)])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $catalogToEdit) { catalog in
            NewPickSheetView(isPresented: .constant(true), viewModel: viewModel, editingCatalog: catalog)
                .presentationDetents([.medium, .large])
        }
        .blur(radius: isShowingAddonSheet ? 20 : 0)
            
            if isShowingAddonSheet {
                PicksAddonOverlay(isPresented: $isShowingAddonSheet, viewModel: viewModel)
                    .zIndex(100)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
    
    private struct FlexibleImport: Codable {
        let name: String?
        let description: String?
        let seed_type: String?
        let seed_params: PickSeedParams?
        let filters: PickFilters?
        let weights: PickWeights?
        let exclude_watched: Bool?
        let exclude_watchlist: Bool?
    }

    private func handleImportJSON() {
        guard let data = importJsonString.data(using: .utf8) else { return }
        do {
            let flex = try JSONDecoder().decode(FlexibleImport.self, from: data)
            let request = CreatePickRequest(
                name: flex.name ?? "Imported Pick",
                description: flex.description,
                seed_type: flex.seed_type ?? "taste_profile",
                seed_params: flex.seed_params,
                filters: flex.filters ?? PickFilters(),
                weights: flex.weights ?? PickWeights(genre: 1.0, keyword: 0, people: 0, quality: 0.4, popularity: 0.1, novelty: 0.2, recency: 0, era: 0, language: 0),
                exclude_watched: flex.exclude_watched ?? true,
                exclude_watchlist: flex.exclude_watchlist ?? false
            )
            
            Task {
                do {
                    try await viewModel.createPick(request: request)
                } catch {
                    print("Error importing pick: \(error)")
                }
            }
        } catch {
            print("Invalid JSON for import: \(error)")
        }
        importJsonString = ""
    }
}

// A reusable component for the top action buttons
struct ActionButton: View {
    let icon: String
    let title: String
    var isPrimary: Bool = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            action?()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isPrimary ? Color.white : Color.gray.opacity(0.2))
            .foregroundColor(isPrimary ? .black : .white)
            .cornerRadius(8)
        }
    }
}

// 4. The Toggle Button Component
struct LayoutButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .medium, design: .rounded))
                Text(title).font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.white.opacity(0.15) : Color.clear)
            .foregroundColor(isSelected ? .white : .gray)
            .clipShape(Capsule())
        }
    }
}

// Reusable Auto-Loading More Pick Card
struct MorePickCard: View {
    let catalogId: String
    let nextPage: Int
    @ObservedObject var viewModel: PicksViewModel
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.03))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
            
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
        }
        .frame(width: 140, height: 210)
        .onAppear {
            if viewModel.isFetchingMore[catalogId] != true {
                Task {
                    await viewModel.fetchNextPage(catalogId: catalogId)
                }
            }
        }
    }
}


struct PicksGridView: View {
    let catalog: PickCatalog
    @ObservedObject var viewModel: PicksViewModel
    
    @State private var itemForWhyThis: CatalogItem? = nil
    @State private var isReady = false
    
    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]
    
    var body: some View {
        ZStack {
            AppBackground()
            
            if isReady {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                        let items = viewModel.pickItems[catalog.id] ?? []
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            NavigationLink(value: MediaDetailRoute(item: item)) {
                                let mediaItem = item.toMediaItem()
                                let badgeText = BadgeEngine.getTag(for: mediaItem)
                                DiscoverPosterCell(
                                    item: mediaItem,
                                    tmdbRating: item.voteAverage,
                                    logoURL: viewModel.itemLogos[mediaItem.tmdbId],
                                    cleanPosterURL: viewModel.cleanPosters[mediaItem.tmdbId],
                                    badgeText: badgeText.isEmpty ? nil : badgeText,
                                    percentageMatch: item.calculatedPercentage,
                                    isInWatchlist: false,
                                    hideDefaultContextMenu: true, hideGenre: true,
                                    onAddToWatchlist: {},
                                    onRemoveFromWatchlist: {},
                                    onWhyThis: { itemForWhyThis = item },
                                    onNoThanks: { viewModel.hideItem(catalogId: catalog.id, item: item) }
                                )
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if index == items.count - 1 {
                                    Task {
                                        await viewModel.fetchNextPage(catalogId: catalog.id)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    
                    if viewModel.isFetchingMore[catalog.id] == true {
                        ProgressView()
                            .padding()
                    }
                }
                .transition(.opacity)
            } else {
                ProgressView()
                    .tint(GlassTheme.primaryText)
                    .scaleEffect(1.2)
            }
        }
        .navigationTitle(catalog.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !isReady {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isReady = true
                    }
                }
            }
        }
        .sheet(item: $itemForWhyThis) { item in
            WhyThisSheetView(item: item)
                .presentationDetents([.height(410)])
                .presentationDragIndicator(.visible)
        }
    }
}



// 5. New Pick Sheet
struct NewPickSheetView: View {
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PicksViewModel

    /// When set, the sheet is in "Edit" mode — title shows "Edit Pick", button shows "Update"
    var editingCatalog: PickCatalog? = nil
    /// When set, the sheet is in "Copy" mode — pre-populated with the source catalog's name
    var copyFromCatalog: PickCatalog? = nil

    private var isEditMode: Bool { editingCatalog != nil }
    private var navigationTitle: String { isEditMode ? "Edit Pick" : "New Pick" }
    private var actionButtonTitle: String { isEditMode ? "Update" : "Create" }

    @FocusState private var isInputActive: Bool

    // Snapshots for change detection in edit mode
    @State private var initialName = ""
    @State private var initialDescription = ""
    @State private var initialRecipeType = RecipeType.tasteProfile
    @State private var initialAudienceType = AudienceType.auto
    @State private var initialIncludeMovies = true
    @State private var initialIncludeTV = true
    @State private var initialHideWatched = true
    @State private var initialHideWatchlist = false
    @State private var initialIncludedGenres: Set<String> = []
    @State private var initialExcludedGenres: Set<String> = []
    @State private var initialIncludedLanguages: Set<String> = []
    @State private var initialExcludedLanguages: Set<String> = []
    @State private var initialIncludedKeywords: [String] = []
    @State private var initialExcludedKeywords: [String] = []
    @State private var initialWeightGenre: Double = 1.0
    @State private var initialWeightKeyword: Double = 0.0
    @State private var initialWeightPeople: Double = 0.0
    @State private var initialWeightQuality: Double = 0.4
    @State private var initialWeightPopularity: Double = 0.1
    @State private var initialWeightNovelty: Double = 0.2
    @State private var initialWeightRecency: Double = 0.0
    @State private var initialWeightEra: Double = 0.0
    @State private var initialWeightLanguage: Double = 0.0
    @State private var initialMinVoteCount = "50"
    @State private var initialMinVoteAverage = "0"
    @State private var initialYearFrom = ""
    @State private var initialYearTo = ""
    @State private var initialRuntimeMin = ""
    @State private var initialRuntimeMax = ""
    @State private var initialSelectedMoods: Set<String> = []
    @State private var initialSelectedSeedTitles: [TMDBMediaItem] = []
    @State private var initialSelectedCompanies: [TMDBStudio] = []
    @State private var initialSelectedRegion = "United States"
    @State private var initialSelectedRating: String? = nil
    @State private var initialSortOrder = "Default (taste-ranked)"
    @State private var initialIncludedProviders: Set<String> = []
    private var hasChanges: Bool {
        guard isEditMode else { return true } // always enabled for Create
        return pickName != initialName
            || pickDescription != initialDescription
            || selectedRecipeType != initialRecipeType
            || audienceType != initialAudienceType
            || includeMovies != initialIncludeMovies
            || includeTV != initialIncludeTV
            || includeHideWatched != initialHideWatched
            || includeHideWatchlist != initialHideWatchlist
            || includedGenres != initialIncludedGenres
            || excludedGenres != initialExcludedGenres
            || includedLanguages != initialIncludedLanguages
            || excludedLanguages != initialExcludedLanguages
            || includedKeywords != initialIncludedKeywords
            || excludedKeywords != initialExcludedKeywords
            || weightGenre != initialWeightGenre
            || weightKeyword != initialWeightKeyword
            || weightPeople != initialWeightPeople
            || weightQuality != initialWeightQuality
            || weightPopularity != initialWeightPopularity
            || weightNovelty != initialWeightNovelty
            || weightRecency != initialWeightRecency
            || weightEra != initialWeightEra
            || weightLanguage != initialWeightLanguage
            || minVoteCount != initialMinVoteCount
            || minVoteAverage != initialMinVoteAverage
            || yearFrom != initialYearFrom
            || yearTo != initialYearTo
            || runtimeMax != initialRuntimeMax
            || selectedMoods != initialSelectedMoods
            || selectedSeedTitles != initialSelectedSeedTitles
            || selectedCompanies != initialSelectedCompanies
            || selectedRegion != initialSelectedRegion
            || selectedRating != initialSelectedRating
            || sortOrder != initialSortOrder
            || includedProviders != initialIncludedProviders
    }
    
    // Form state
    @State private var hasInitialized = false
    @State private var pickName = ""
    @State private var pickDescription = ""
    @State private var selectedRecipeType = RecipeType.tasteProfile
    @State private var audienceType = AudienceType.auto
    
    // Include Flags
    @State private var includeMovies = true
    @State private var includeTV = true
    @State private var includeHideWatched = true
    @State private var includeHideWatchlist = false
    
    // Seed Titles
    @State private var seedTitlesInput = ""
    @State private var seedTitlesSuggestions: [TMDBMediaItem] = []
    @State private var selectedSeedTitles: [TMDBMediaItem] = []
    @State private var isSearchingSeed = false
    @State private var seedSearchTask: Task<Void, Never>? = nil
    
    // Production Company
    @State private var companyInput = ""
    @State private var companySuggestions: [TMDBStudio] = []
    @State private var selectedCompanies: [TMDBStudio] = []
    @State private var isSearchingCompany = false
    @State private var companySearchTask: Task<Void, Never>? = nil
    
    // Advanced / Filters
    @State private var isAdvancedExpanded = false
    
    // Weights
    @State private var weightGenre: Double = 1.0
    @State private var weightKeyword: Double = 0.0
    @State private var weightPeople: Double = 0.0
    @State private var weightQuality: Double = 0.4
    @State private var weightPopularity: Double = 0.1
    @State private var weightNovelty: Double = 0.2
    @State private var weightRecency: Double = 0.0
    @State private var weightEra: Double = 0.0
    @State private var weightLanguage: Double = 0.0
    
    // Eras / Runtime / Min Votes
    @State private var minVoteCount: String = "50"
    @State private var minVoteAverage: String = "0"
    @State private var yearFrom: String = ""
    @State private var yearTo: String = ""
    @State private var runtimeMin: String = ""
    @State private var runtimeMax: String = ""
    
    // Languages
    let languagesList = ["English", "Japanese", "Korean", "French", "Spanish", "German", "Italian", "Chinese", "Hindi", "Russian", "Portuguese", "Turkish", "Thai", "Swedish", "Arabic", "Polish", "Danish", "Norwegian", "Dutch", "Finnish", "Indonesian", "Filipino", "Romanian", "Hungarian", "Czech", "Greek", "Hebrew"]
    @State private var includedLanguages: Set<String> = []
    @State private var excludedLanguages: Set<String> = []
    
    // Genres
    let genresList = ["Action", "Adventure", "Animation", "Comedy", "Crime", "Documentary", "Drama", "Family", "Fantasy", "History", "Horror", "Music", "Mystery", "Romance", "Sci-Fi", "Thriller", "War", "Western"]
    let excludedGenresList = ["Action", "Adventure", "Animation", "Comedy", "Crime", "Documentary", "Drama", "Family", "Fantasy", "History", "Horror", "Music", "Mystery", "Romance", "Sci-Fi", "Thriller", "War", "Western", "Kids", "Reality", "Soap", "Talk", "TV Movie"]
    @State private var includedGenres: Set<String> = []
    @State private var excludedGenres: Set<String> = []
    
    // Keywords
    @State private var includedKeywordsInput = ""
    @State private var excludedKeywordsInput = ""
    @State private var includedKeywords: [String] = []
    @State private var excludedKeywords: [String] = []
    
    // Moods
    let moodsList = ["cozy", "cerebral", "bleak", "wholesome", "romantic", "gritty", "weird", "funny", "epic", "dumb-fun", "horny", "sad", "hopeful", "scary", "neon", "slowburn", "tense", "nostalgic", "trippy", "chill", "dark", "uplifting", "absurd", "dreamy", "chaotic", "meditative"]
    @State private var selectedMoods: Set<String> = []
    
    // Region
    let regionsList = ["United States", "United Kingdom", "Canada", "Australia", "Germany", "France", "Spain", "Italy", "Brazil", "India", "Japan", "South Korea", "Netherlands", "Sweden", "Mexico"]
    @State private var selectedRegion: String = "United States"
    
    // Providers
    let providersList = ["Netflix", "Amazon Prime", "Disney+", "Max", "Apple TV+", "Hulu", "Paramount+", "Peacock", "Crunchyroll", "AMC+", "Apple iTunes", "Google Play", "YouTube", "MUBI", "Curiosity Stream", "GuideDoc", "Criterion Channel", "Kanopy", "Tubi", "Pluto TV"]
    @State private var includedProviders: Set<String> = []
    
    // Content Rating
    let ratingsList = ["G", "PG", "PG-13", "R", "NC-17"]
    @State private var selectedRating: String? = nil
    
    // Sort Order
    let sortOptionsList = ["Default (taste-ranked)", "Most popular", "Least popular", "Highest rated", "Newest first", "Oldest first", "Highest revenue"]
    @State private var sortOrder: String = "Default (taste-ranked)"

    enum AudienceType: String, CaseIterable {
        case auto = "AUTO"
        case grownUp = "GROWN-UP"
        case kidSafe = "KID-SAFE"
    }

    enum RecipeType: String, CaseIterable {
        case tasteProfile = "Taste Profile"
        case usersLikeYou = "Users Like You"
        case lowPopularity = "Low Popularity"
        case undersampledGenres = "Undersampled Genres"
        case edgeOfTaste = "Edge of Taste"
        case byMood = "By Mood"
        case byEra = "By Era"
        case byDirectorCrew = "By Director / Crew"
        case recentStreak = "Recent Streak"
        case similarTo = "Similar To..."
        case outsideProfile = "Outside Profile"
        case rewatch = "Rewatch"
        
        var apiSeedType: String {
            switch self {
            case .tasteProfile: return "taste"
            case .usersLikeYou: return "twin"
            case .lowPopularity: return "obscurity"
            case .undersampledGenres: return "gap"
            case .edgeOfTaste: return "discovery"
            case .byMood: return "mood"
            case .byEra: return "era"
            case .byDirectorCrew: return "crew"
            case .recentStreak: return "streak"
            case .similarTo: return "similar_to"
            case .outsideProfile: return "anti_taste"
            case .rewatch: return "rewatch_risk"
            }
        }
        
        var iconName: String {
            switch self {
            case .tasteProfile: return "sparkles"
            case .usersLikeYou: return "person.2.fill"
            case .lowPopularity: return "chart.line.downtrend.xyaxis"
            case .undersampledGenres: return "chart.pie.fill"
            case .edgeOfTaste: return "mountain.2.fill"
            case .byMood: return "theatermasks.fill"
            case .byEra: return "clock.fill"
            case .byDirectorCrew: return "megaphone.fill"
            case .recentStreak: return "flame.fill"
            case .similarTo: return "link.circle.fill"
            case .outsideProfile: return "globe.americas.fill"
            case .rewatch: return "arrow.triangle.2.circlepath.circle.fill"
            }
        }
        
        var subtitle: String {
            switch self {
            case .tasteProfile: return "Ranked by your top genres, keywords, and people."
            case .usersLikeYou: return "High-rated picks from users with overlapping ratings."
            case .lowPopularity: return "Quality titles below a vote-count ceiling."
            case .undersampledGenres: return "Genres you have undersampled relative to your profile."
            case .edgeOfTaste: return "Pushes into genres at the edge of your profile."
            case .byMood: return "Weighted by one or more mood keyword palettes."
            case .byEra: return "Taste-ranked picks from a year or decade range."
            case .byDirectorCrew: return "Weighted by your top directors, writers, composers."
            case .recentStreak: return "Extends the streaks of your last few watches."
            case .similarTo: return "Neighbors of titles you pick, re-ranked by your taste."
            case .outsideProfile: return "Well-rated titles from genres you rarely watch."
            case .rewatch: return "Your own history, filtered to items old enough to feel fresh."
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // The black opacity ensures it behaves like a sheet and can be dismissed via dragging
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        basicInfoCard
                        recipeTypeCard
                        
                        if selectedRecipeType == .byMood {
                            moodsCard
                        } else if selectedRecipeType == .byEra {
                            eraCard
                        } else if selectedRecipeType == .similarTo {
                            seedTitlesSection
                        }
                        
                        includeCard
                        audienceCard
                        advancedCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                
                // Floating Glassmorphic Done Button
                if isInputActive {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                isInputActive = false
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }) {
                                HStack(spacing: 8) {
                                    Text("Done")
                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .tint(.blue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(actionButtonTitle) {
                        let request = buildCreateRequest()
                        isPresented = false
                        dismiss()
                        Task {
                            do {
                                if let catalog = editingCatalog {
                                    try await viewModel.updatePick(catalogId: catalog.id, request: request)
                                } else {
                                    try await viewModel.createPick(request: request)
                                }
                            } catch {
                                print("Error saving pick: \(error)")
                            }
                        }
                    }
                    .tint(.blue)
                    .disabled(!hasChanges || pickName.isEmpty || (selectedRecipeType == .byMood && selectedMoods.isEmpty) || (selectedRecipeType == .byEra && (yearFrom.isEmpty || yearTo.isEmpty)) || (selectedRecipeType == .similarTo && selectedSeedTitles.isEmpty))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .preferredColorScheme(.dark)
            .onChange(of: selectedRecipeType) { _, newValue in
                applyDefaultWeights(for: newValue)
            }
            .onAppear {
                if !hasInitialized {
                    if let catalog = editingCatalog ?? copyFromCatalog {
                        // Pre-populate name and description from the catalog
                        if pickName.isEmpty {
                            pickName = isEditMode ? catalog.name : "Copy of \(catalog.name)"
                            pickDescription = catalog.description ?? ""
                        }
                    // Map the seed_type back to a RecipeType so the correct form sections appear
                    if let seedType = catalog.seedType {
                        let mapped = NewPickSheetView.RecipeType.allCases.first { $0.apiSeedType == seedType }
                        if let matched = mapped { selectedRecipeType = matched }
                    }
                    
                    // Map filters
                    if let filters = catalog.filters {
                        if let mt = filters.media_types {
                            includeMovies = mt.contains("movie")
                            includeTV = mt.contains("tv")
                        }
                        if let mvc = filters.min_vote_count { minVoteCount = String(mvc) }
                        if let mva = filters.min_vote_average { minVoteAverage = String(mva) }
                        if let ymin = filters.year_min { yearFrom = String(ymin) }
                        if let ymax = filters.year_max { yearTo = String(ymax) }
                        
                        if let rmin = filters.runtime_min { runtimeMin = String(rmin) }
                        if let rmax = filters.runtime_max { runtimeMax = String(rmax) }
                        
                        if let wG = filters.with_genres {
                            let names = wG.compactMap { id in genreIDMap.first(where: { $0.value == id })?.key }
                            includedGenres = Set(names)
                        }
                        if let woG = filters.without_genres {
                            let names = woG.compactMap { id in genreIDMap.first(where: { $0.value == id })?.key }
                            excludedGenres = Set(names)
                        }
                        
                        if let wL = filters.languages {
                            let names = wL.compactMap { code in languageISOMap.first(where: { $0.value == code })?.key }
                            includedLanguages = Set(names)
                        }
                        if let woL = filters.exclude_languages {
                            let names = woL.compactMap { code in languageISOMap.first(where: { $0.value == code })?.key }
                            excludedLanguages = Set(names)
                        }
                        
                        if let wK = filters.with_keywords { includedKeywords = wK }
                        if let woK = filters.exclude_keywords { excludedKeywords = woK }
                        
                        if let wP = filters.with_watch_providers {
                            let names = wP.compactMap { id in providerIDMap.first(where: { $0.value == String(id) })?.key }
                            includedProviders = Set(names)
                        }
                        
                        if let region = filters.watch_region {
                            if let uiName = regionISOMap.first(where: { $0.value == region })?.key {
                                selectedRegion = uiName
                            }
                        }
                        
                        if let rating = filters.certification_lte {
                            selectedRating = rating
                        }
                        
                        if let sort = filters.sort_by {
                            if let uiName = sortOrderAPIMap.first(where: { $0.value == sort })?.key {
                                sortOrder = uiName
                            }
                        }
                        
                        if let aud = filters.audience {
                            if aud == "auto" { audienceType = .auto }
                            if aud == "adult" { audienceType = .grownUp }
                            if aud == "kids" { audienceType = .kidSafe }
                        }
                    }
                    
                    if let ew = catalog.excludeWatched { includeHideWatched = ew }
                    if let ewl = catalog.excludeWatchlist { includeHideWatchlist = ewl }
                    
                    // Map weights
                    if let weights = catalog.weights {
                        if let g = weights.genre { weightGenre = g }
                        if let k = weights.keyword { weightKeyword = k }
                        if let p = weights.people { weightPeople = p }
                        if let q = weights.quality { weightQuality = q }
                        if let pop = weights.popularity { weightPopularity = pop }
                        if let nov = weights.novelty { weightNovelty = nov }
                        if let rec = weights.recency { weightRecency = rec }
                        if let e = weights.era { weightEra = e }
                        if let l = weights.language { weightLanguage = l }
                    }
                    
                    // Map seed params
                    if let sp = catalog.seedParams {
                        if let moods = sp.moods { selectedMoods = Set(moods) }
                    }
                    
                    // Snapshot initial values for change detection
                    if isEditMode {
                        initialName = pickName
                        initialDescription = pickDescription
                        initialRecipeType = selectedRecipeType
                        initialAudienceType = audienceType
                        initialIncludeMovies = includeMovies
                        initialIncludeTV = includeTV
                        initialHideWatched = includeHideWatched
                        initialHideWatchlist = includeHideWatchlist
                        initialIncludedGenres = includedGenres
                        initialExcludedGenres = excludedGenres
                        initialIncludedLanguages = includedLanguages
                        initialExcludedLanguages = excludedLanguages
                        initialIncludedKeywords = includedKeywords
                        initialExcludedKeywords = excludedKeywords
                        initialWeightGenre = weightGenre
                        initialWeightKeyword = weightKeyword
                        initialWeightPeople = weightPeople
                        initialWeightQuality = weightQuality
                        initialWeightPopularity = weightPopularity
                        initialWeightNovelty = weightNovelty
                        initialWeightRecency = weightRecency
                        initialWeightEra = weightEra
                        initialWeightLanguage = weightLanguage
                        initialMinVoteCount = minVoteCount
                        initialMinVoteAverage = minVoteAverage
                        initialYearFrom = yearFrom
                        initialYearTo = yearTo
                        initialRuntimeMin = runtimeMin
                        initialRuntimeMax = runtimeMax
                        initialSelectedMoods = selectedMoods
                        initialSelectedRegion = selectedRegion
                        initialSelectedRating = selectedRating
                        initialSortOrder = sortOrder
                        initialIncludedProviders = includedProviders
                        
                        // Fetch Seed Titles and Companies dynamically
                        Task {
                            // 1. Fetch seed titles
                            var loadedTitles: [TMDBMediaItem] = []
                            if let sIds = catalog.seedParams?.similar_ids {
                                for item in sIds {
                                    let mt = item.media_type == "movie" ? MediaType.movie : MediaType.tv
                                    if let detail = try? await TMDBService.shared.fetchDetailInfo(tmdbId: item.tmdb_id, mediaType: mt) {
                                        let mediaItem = TMDBMediaItem(id: "\(mt.rawValue)-\(item.tmdb_id)", tmdbId: item.tmdb_id, mediaType: mt, title: detail.title ?? "", overview: detail.overview ?? "", year: detail.year ?? "", posterPath: detail.posterPath, backdropPath: detail.backdropPath, voteAverage: detail.voteAverage ?? 0.0, voteCount: detail.voteCount ?? 0)
                                        loadedTitles.append(mediaItem)
                                    }
                                }
                            }
                            
                            // 2. Fetch companies
                            var loadedCompanies: [TMDBStudio] = []
                            if let cIds = catalog.filters?.with_companies {
                                for idStr in cIds {
                                    if let idInt = Int(idStr) {
                                        if let studio = try? await TMDBService.shared.fetchStudio(id: idInt) {
                                            loadedCompanies.append(studio)
                                        }
                                    }
                                }
                            }
                            
                            await MainActor.run {
                                selectedSeedTitles = loadedTitles
                                initialSelectedSeedTitles = loadedTitles
                                selectedCompanies = loadedCompanies
                                initialSelectedCompanies = loadedCompanies
                            }
                        }
                    }
                } else if pickName.isEmpty {
                    pickName = selectedRecipeType.rawValue
                    pickDescription = selectedRecipeType.subtitle
                }
                hasInitialized = true
                }
            }
            .onChange(of: selectedRecipeType) { _, newValue in
                pickName = newValue.rawValue
                pickDescription = newValue.subtitle
                let currentYear = String(Calendar.current.component(.year, from: Date()))
                if newValue == .byEra {
                    if yearFrom.isEmpty { yearFrom = "2000" }
                    if yearTo.isEmpty { yearTo = currentYear }
                } else {
                    if yearFrom == "2000" && yearTo == currentYear {
                        yearFrom = ""
                        yearTo = ""
                    }
                }
            }
        }
    }
    
    // MARK: - Cards
    
    @ViewBuilder
    private var basicInfoCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("NAME")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                    .padding(.leading, 4)
                
                TextField("e.g. Hidden gems, weekend watchlist...", text: $pickName)
                    .padding(16)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("DESCRIPTION (optional)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                    .padding(.leading, 4)
                
                TextField("one-line summary", text: $pickDescription)
                    .padding(16)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .cardStyle()
    }
    
    @ViewBuilder
    private var recipeTypeCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("RECIPE TYPE")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            NavigationLink {
                RecipeTypeSelectionView(selectedRecipeType: $selectedRecipeType)
            } label: {
                HStack(spacing: 16) {
                    // Icon Container
                    ZStack {
                        LinearGradient(colors: [Color.blue.opacity(0.8), Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: selectedRecipeType.iconName)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.blue.opacity(0.5), radius: 8, x: 0, y: 4)
                    
                    // Text Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedRecipeType.rawValue)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(selectedRecipeType.subtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(16)
                .background(Color.blue.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .liquidGlass(cornerRadius: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.blue.opacity(0.8), lineWidth: 1.5)
                )
            }
        }
        .cardStyle()
        .onChange(of: selectedRecipeType) { _, newValue in
            if pickName.isEmpty || pickName == RecipeType.tasteProfile.rawValue {
                pickName = newValue.rawValue
            }
        }
    }
    
    @ViewBuilder
    private var moodsCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("MOODS (pick at least one mood)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(moodsList, id: \.self) { mood in
                    modernPillButton(title: mood, isSelected: selectedMoods.contains(mood), activeColor: .blue, isSmall: true) {
                        if selectedMoods.contains(mood) {
                            selectedMoods.remove(mood)
                        } else {
                            selectedMoods.insert(mood)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }
    
    @ViewBuilder
    private var eraCard: some View {
        yearRangeSection
            .cardStyle()
    }
    
    @ViewBuilder
    private var includeCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("INCLUDE")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    modernPillButton(title: "Movies", icon: "film", isSelected: includeMovies) { includeMovies.toggle() }
                    modernPillButton(title: "TV", icon: "tv", isSelected: includeTV) { includeTV.toggle() }
                }
                HStack(spacing: 12) {
                    modernPillButton(title: "Hide watched", icon: "eye.slash", isSelected: includeHideWatched) { includeHideWatched.toggle() }
                    modernPillButton(title: "Hide watchlist", icon: "bookmark.slash", isSelected: includeHideWatchlist) { includeHideWatchlist.toggle() }
                }
            }
        }
        .cardStyle()
    }
    
    @ViewBuilder
    private var audienceCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AUDIENCE")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            HStack(alignment: .top, spacing: 12) {
                ForEach(AudienceType.allCases, id: \.self) { type in
                    VStack(spacing: 8) {
                        modernPillButton(title: type.rawValue, isSelected: audienceType == type) {
                            audienceType = type
                        }
                        
                        if audienceType == type {
                            Text(type == .auto ? "Infer from taste" : (type == .grownUp ? "Block kids networks" : "Family-friendly only"))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }
    
    @ViewBuilder
    private var advancedCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header button — uses liquidGlass to sit above inner boxes
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    isAdvancedExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ADVANCED")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("weights, filters, languages")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .rotationEffect(.degrees(isAdvancedExpanded ? -180 : 0))
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: isAdvancedExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .liquidGlass()
            }
            .buttonStyle(.plain)

            if isAdvancedExpanded {
                VStack(alignment: .leading, spacing: 20) {
                    innerBox { weightsSection }
                    innerBox { languagesSection }
                    innerBox { minVotesSection }
                    if selectedRecipeType != .byEra {
                        innerBox { yearRangeSection }
                    }
                    innerBox { genresSection }
                    innerBox { runtimeSection }
                    innerBox { keywordsSection }
                    innerBox { providersSection }
                    innerBox { contentRatingSection }
                    innerBox { productionCompanySection }
                    innerBox { sortOrderSection }
                }
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Advanced Sections
    
    @ViewBuilder
    private var weightsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RANKING WEIGHTS")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                    Text("Blank fields use the recipe preset")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.gray.opacity(0.7))
                }
                Spacer()
                Button(action: {
                    applyDefaultWeights(for: selectedRecipeType)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("RESET")
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            
            VStack(spacing: 16) {
                weightSlider(title: "GENRE",      value: $weightGenre,      range: -1.0...2.0)
                Divider().background(Color.white.opacity(0.1))
                weightSlider(title: "KEYWORD",    value: $weightKeyword,    range: 0.0...2.0)
                Divider().background(Color.white.opacity(0.1))
                weightSlider(title: "PEOPLE",     value: $weightPeople,     range: 0.0...2.0)
                Divider().background(Color.white.opacity(0.1))
                weightSlider(title: "QUALITY",    value: $weightQuality,    range: 0.0...1.5)
                Divider().background(Color.white.opacity(0.1))
                weightSlider(title: "POPULARITY", value: $weightPopularity, range: -1.0...1.0)
                Divider().background(Color.white.opacity(0.1))
                weightSlider(title: "NOVELTY",    value: $weightNovelty,    range: 0.0...1.5)
                Divider().background(Color.white.opacity(0.1))
                weightSlider(title: "RECENCY",    value: $weightRecency,    range: 0.0...1.0)
                Divider().background(Color.white.opacity(0.1))
                weightSlider(title: "ERA",        value: $weightEra,        range: 0.0...1.5)
                Divider().background(Color.white.opacity(0.1))
                weightSlider(title: "LANGUAGE",   value: $weightLanguage,   range: 0.0...1.0)
            }
        }
    }
    
    private func weightSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        let interactionBinding = Binding<Double>(
            get: { value.wrappedValue },
            set: { newValue in
                if newValue != value.wrappedValue {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
                value.wrappedValue = newValue
            }
        )
        
        return HStack {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            Slider(value: interactionBinding, in: range, step: 0.1)
                .tint(.white)
            Text(String(format: "%.1f", value.wrappedValue))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 30, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var languagesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Include
            VStack(alignment: .leading, spacing: 12) {
                Text("ONLY THESE LANGUAGES (leave empty for all)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(languagesList, id: \.self) { lang in
                        modernPillButton(title: lang, isSelected: includedLanguages.contains(lang), activeColor: .blue, isSmall: true) {
                            if includedLanguages.contains(lang) {
                                includedLanguages.remove(lang)
                            } else {
                                includedLanguages.insert(lang)
                                excludedLanguages.remove(lang)
                            }
                        }
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.15))
            
            // Exclude
            VStack(alignment: .leading, spacing: 12) {
                Text("EXCLUDE LANGUAGES (never recommend these)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(languagesList, id: \.self) { lang in
                        modernPillButton(title: lang, isSelected: excludedLanguages.contains(lang), activeColor: .red, isSmall: true) {
                            if excludedLanguages.contains(lang) {
                                excludedLanguages.remove(lang)
                            } else {
                                excludedLanguages.insert(lang)
                                includedLanguages.remove(lang)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var minVotesSection: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("MIN VOTE COUNT")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                    .padding(.leading, 4)
                TextField("50", text: $minVoteCount)
                    .padding(16)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .keyboardType(.numberPad)
                    .focused($isInputActive)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("MIN VOTE AVERAGE")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                    .padding(.leading, 4)
                TextField("0", text: $minVoteAverage)
                    .padding(16)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .keyboardType(.numberPad)
                    .focused($isInputActive)
            }
        }
    }
    
    @ViewBuilder
    private var yearRangeSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(selectedRecipeType == .byEra ? "YEAR RANGE" : "YEAR RANGE (optional)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .padding(.leading, 4)
            HStack(spacing: 16) {
                TextField("From", text: $yearFrom)
                    .padding(16)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .keyboardType(.numberPad)
                    .focused($isInputActive)
                TextField("To", text: $yearTo)
                    .padding(16)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .keyboardType(.numberPad)
                    .focused($isInputActive)
            }
        }
    }
    
    @ViewBuilder
    private var genresSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("ONLY THESE GENRES (leave empty for all)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(genresList, id: \.self) { genre in
                        modernPillButton(title: genre, isSelected: includedGenres.contains(genre), activeColor: .blue, isSmall: true) {
                            if includedGenres.contains(genre) {
                                includedGenres.remove(genre)
                            } else {
                                includedGenres.insert(genre)
                                excludedGenres.remove(genre)
                            }
                        }
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.15))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("EXCLUDE GENRES (never recommend these)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(excludedGenresList, id: \.self) { genre in
                        modernPillButton(title: genre, isSelected: excludedGenres.contains(genre), activeColor: .red, isSmall: true) {
                            if excludedGenres.contains(genre) {
                                excludedGenres.remove(genre)
                            } else {
                                excludedGenres.insert(genre)
                                includedGenres.remove(genre)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var runtimeSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("RUNTIME (MINUTES)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .padding(.leading, 4)
            HStack(spacing: 16) {
                TextField("Min", text: $runtimeMin)
                    .padding(16)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                    .keyboardType(.numberPad)
                    .focused($isInputActive)
                TextField("Max", text: $runtimeMax)
                    .padding(16)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                    .keyboardType(.numberPad)
                    .focused($isInputActive)
            }
        }
    }

    @ViewBuilder
    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("MUST INCLUDE KEYWORDS (e.g. alien, heist, spy)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                HStack {
                    TextField("Type a keyword", text: $includedKeywordsInput)
                        .padding(16)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onSubmit {
                            if !includedKeywordsInput.isEmpty && includedKeywords.count < 10 && !includedKeywords.contains(includedKeywordsInput) {
                                includedKeywords.append(includedKeywordsInput)
                                includedKeywordsInput = ""
                            }
                        }
                    Button(action: {
                        if !includedKeywordsInput.isEmpty && includedKeywords.count < 10 && !includedKeywords.contains(includedKeywordsInput) {
                            includedKeywords.append(includedKeywordsInput)
                            includedKeywordsInput = ""
                        }
                    }) {
                        Text("ADD")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .activeLiquidGlass(isActive: includedKeywords.count < 10)
                    }
                    .disabled(includedKeywords.count >= 10)
                }
                if !includedKeywords.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(includedKeywords, id: \.self) { kw in
                            HStack(spacing: 4) {
                                Text(kw)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                Button(action: { includedKeywords.removeAll(where: { $0 == kw }) }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.3))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Color.blue.opacity(0.8), lineWidth: 1))
                        }
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.15))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("EXCLUDE KEYWORDS (e.g. anime, sequel, remake)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                HStack {
                    TextField("Type a keyword", text: $excludedKeywordsInput)
                        .padding(16)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onSubmit {
                            if !excludedKeywordsInput.isEmpty && excludedKeywords.count < 10 && !excludedKeywords.contains(excludedKeywordsInput) {
                                excludedKeywords.append(excludedKeywordsInput)
                                excludedKeywordsInput = ""
                            }
                        }
                    Button(action: {
                        if !excludedKeywordsInput.isEmpty && excludedKeywords.count < 10 && !excludedKeywords.contains(excludedKeywordsInput) {
                            excludedKeywords.append(excludedKeywordsInput)
                            excludedKeywordsInput = ""
                        }
                    }) {
                        Text("ADD")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .activeLiquidGlass(isActive: excludedKeywords.count < 10, activeColor: Color.red.opacity(0.8))
                    }
                    .disabled(excludedKeywords.count >= 10)
                }
                if !excludedKeywords.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(excludedKeywords, id: \.self) { kw in
                            HStack(spacing: 4) {
                                Text(kw)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                Button(action: { excludedKeywords.removeAll(where: { $0 == kw }) }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.3))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Color.red.opacity(0.8), lineWidth: 1))
                        }
                    }
                }
            }
            
            Text("Matched against TMDB keywords. Up to 10.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.gray)
                .padding(.top, 4)
        }
    }
    
    @ViewBuilder
    private var providersSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("STREAMING PROVIDERS (leave empty for all)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                Spacer()
            }
            
            if !includedProviders.isEmpty {
                HStack {
                    Text("REGION")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                    Menu {
                        ForEach(regionsList, id: \.self) { region in
                            Button(region) { selectedRegion = region }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedRegion)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                        }
                        .frame(width: 160)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                    }
                }
                .padding(.bottom, 8)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(providersList, id: \.self) { provider in
                    providerPillButton(title: provider, isSelected: includedProviders.contains(provider)) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if includedProviders.contains(provider) {
                                includedProviders.remove(provider)
                            } else {
                                includedProviders.insert(provider)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var contentRatingSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("CONTENT RATING")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            HStack(spacing: 8) {
                Text("Up to")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
                
                ForEach(ratingsList, id: \.self) { rating in
                    modernPillButton(title: rating, isSelected: selectedRating == rating, activeColor: .blue) {
                        if selectedRating == rating {
                            selectedRating = nil
                        } else {
                            selectedRating = rating
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var productionCompanySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("PRODUCTION COMPANY")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            HStack(spacing: 12) {
                if isSearchingCompany {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                }
                
                TextField("Search companies (A24, Ghibli, Pixar)", text: $companyInput)
                    .onChange(of: companyInput) { _, newValue in
                        scheduleCompanySearch(newValue)
                    }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            if !companySuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(companySuggestions) { item in
                        Button {
                            if !selectedCompanies.contains(where: { $0.id == item.id }) {
                                selectedCompanies.append(item)
                            }
                            companyInput = ""
                            companySuggestions = []
                        } label: {
                            HStack(spacing: 10) {
                                if let logo = item.logo_path {
                                    AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w92\(logo)")) { img in
                                        img.resizable().scaledToFit()
                                    } placeholder: {
                                        Color.white.opacity(0.1)
                                    }
                                    .frame(width: 40, height: 24)
                                    .background(Color.white)
                                    .cornerRadius(4)
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 40, height: 24)
                                }
                                
                                Text(item.name)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if item.id != companySuggestions.last?.id {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            
            if !selectedCompanies.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(selectedCompanies) { company in
                        HStack(spacing: 4) {
                            Text(company.name)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                            Button(action: { selectedCompanies.removeAll(where: { $0.id == company.id }) }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.3))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.blue.opacity(0.8), lineWidth: 1))
                    }
                }
            }
        }
    }

    private func scheduleCompanySearch(_ text: String) {
        companySearchTask?.cancel()
        guard text.count >= 2 else {
            companySuggestions = []
            return
        }
        companySearchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { isSearchingCompany = true }
            do {
                let items = try await TMDBService.shared.searchStudios(query: text)
                await MainActor.run {
                    companySuggestions = Array(items.prefix(5))
                    isSearchingCompany = false
                }
            } catch {
                await MainActor.run { isSearchingCompany = false }
            }
        }
    }
    
    @ViewBuilder
    private var sortOrderSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("SORT ORDER")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            Menu {
                Picker("Sort Order", selection: $sortOrder) {
                    ForEach(sortOptionsList, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            } label: {
                HStack {
                    Text(sortOrder)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(.gray)
                }
                .padding(16)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    @ViewBuilder
    private var seedTitlesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("SEED TITLES (pick at least one seed title)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            HStack(spacing: 12) {
                if isSearchingSeed {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                }
                
                TextField("Search titles to seed from...", text: $seedTitlesInput)
                    .onChange(of: seedTitlesInput) { _, newValue in
                        scheduleSeedSearch(newValue)
                    }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            if !seedTitlesSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(seedTitlesSuggestions) { item in
                        Button {
                            if !selectedSeedTitles.contains(where: { $0.id == item.id }) {
                                selectedSeedTitles.append(item)
                            }
                            seedTitlesInput = ""
                            seedTitlesSuggestions = []
                        } label: {
                            HStack(spacing: 10) {
                                if let poster = item.posterPath {
                                    AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w92\(poster)")) { img in
                                        img.resizable().scaledToFit()
                                    } placeholder: {
                                        Color.white.opacity(0.1)
                                    }
                                    .frame(width: 30, height: 45)
                                    .background(Color.white)
                                    .cornerRadius(4)
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 30, height: 45)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    
                                    Text("\(item.mediaType == .movie ? "Movie" : "TV") • \(item.year)")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(.gray)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if item.id != seedTitlesSuggestions.last?.id {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            
            if !selectedSeedTitles.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(selectedSeedTitles) { title in
                        HStack(spacing: 4) {
                            Text(title.title)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                            Button(action: { selectedSeedTitles.removeAll(where: { $0.id == title.id }) }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.3))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.blue.opacity(0.8), lineWidth: 1))
                    }
                }
            }
        }
        .cardStyle()
    }

    private func scheduleSeedSearch(_ text: String) {
        seedSearchTask?.cancel()
        guard text.count >= 2 else {
            seedTitlesSuggestions = []
            return
        }
        seedSearchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { isSearchingSeed = true }
            do {
                async let movies = TMDBService.shared.search(text, mediaType: .movie)
                async let shows = TMDBService.shared.search(text, mediaType: .tv)
                let combined = try await movies + shows
                let sortedCombined = combined.sorted { $0.voteCount > $1.voteCount }
                await MainActor.run {
                    seedTitlesSuggestions = Array(sortedCombined.prefix(5))
                    isSearchingSeed = false
                }
            } catch {
                await MainActor.run { isSearchingSeed = false }
            }
        }
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private func innerBox<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func modernPillButton(title: String, icon: String? = nil, isSelected: Bool, activeColor: Color = .white, isSmall: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: isSmall ? 12 : 15, weight: .medium, design: .rounded))
                }
                Text(title)
                    .font(.system(size: isSmall ? 12 : 15, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, 6)
            .foregroundStyle(isSelected ? .white : GlassTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, isSmall ? 8 : 12)
            .background(isSelected ? activeColor.opacity(0.3) : .white.opacity(0.05))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? activeColor.opacity(0.8) : .white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private func providerPillButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? .white : GlassTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.blue.opacity(0.8) : Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }

    private func applyDefaultWeights(for recipe: RecipeType) {
        weightGenre = 0.0
        weightKeyword = 0.0
        weightPeople = 0.0
        weightQuality = 0.0
        weightPopularity = 0.0
        weightNovelty = 0.0
        weightRecency = 0.0
        weightEra = 0.0
        weightLanguage = 0.0
        
        switch recipe {
        case .tasteProfile:
            weightGenre = 1.0; weightQuality = 0.4; weightPopularity = 0.1; weightNovelty = 0.2
        case .similarTo:
            weightGenre = 0.8; weightQuality = 0.3; weightPopularity = 0.0; weightNovelty = 0.3
        case .byMood:
            weightGenre = 0.6; weightQuality = 0.4; weightPopularity = 0.1; weightNovelty = 0.3
        case .byEra:
            weightGenre = 0.8; weightEra = 1.2; weightQuality = 0.3; weightPopularity = 0.0
        case .lowPopularity:
            weightGenre = 1.0; weightQuality = 0.6; weightPopularity = -0.5; weightNovelty = 1.0
        case .edgeOfTaste:
            weightGenre = 0.4; weightQuality = 0.5; weightPopularity = -0.2; weightNovelty = 1.0
        case .usersLikeYou:
            weightGenre = 0.5; weightQuality = 0.6; weightPopularity = 0.0; weightNovelty = 0.4
        case .outsideProfile:
            weightGenre = -0.6; weightQuality = 1.0; weightPopularity = 0.2; weightNovelty = 0.1
        case .byDirectorCrew:
            weightGenre = 0.3; weightPeople = 1.5; weightQuality = 0.4; weightPopularity = 0.0
        case .recentStreak:
            weightGenre = 1.2; weightQuality = 0.3; weightPopularity = 0.0; weightNovelty = 0.2
        case .undersampledGenres:
            weightGenre = 0.6; weightQuality = 0.6; weightPopularity = 0.1; weightNovelty = 0.5
        case .rewatch:
            weightGenre = 0.8; weightQuality = 0.5; weightPopularity = 0.0
        }
    }

    // MARK: - Lookup Tables

    private let languageISOMap: [String: String] = [
        "English": "en", "Japanese": "ja", "Korean": "ko", "French": "fr",
        "Spanish": "es", "German": "de", "Italian": "it", "Chinese": "zh",
        "Hindi": "hi", "Russian": "ru", "Portuguese": "pt", "Turkish": "tr",
        "Thai": "th", "Swedish": "sv", "Arabic": "ar", "Polish": "pl",
        "Danish": "da", "Norwegian": "no", "Dutch": "nl", "Finnish": "fi",
        "Indonesian": "id", "Filipino": "tl", "Romanian": "ro", "Hungarian": "hu",
        "Czech": "cs", "Greek": "el", "Hebrew": "he"
    ]

    private let genreIDMap: [String: String] = [
        // Movie genres
        "Action": "28", "Adventure": "12", "Animation": "16", "Comedy": "35",
        "Crime": "80", "Documentary": "99", "Drama": "18", "Family": "10751",
        "Fantasy": "14", "History": "36", "Horror": "27", "Music": "10402",
        "Mystery": "9648", "Romance": "10749", "Sci-Fi": "878", "Thriller": "53",
        "War": "10752", "Western": "37",
        // TV-only genres
        "Kids": "10762", "Reality": "10764", "Soap": "10766", "Talk": "10767",
        "TV Movie": "10770"
    ]

    private let providerIDMap: [String: String] = [
        "Netflix": "8", "Amazon Prime": "9", "Disney+": "337", "Max": "1899",
        "Apple TV+": "350", "Hulu": "15", "Paramount+": "531", "Peacock": "386",
        "Crunchyroll": "283", "AMC+": "526", "Apple iTunes": "2",
        "Google Play": "3", "YouTube": "192", "MUBI": "11",
        "Curiosity Stream": "190", "GuideDoc": "100", "Criterion Channel": "258",
        "Kanopy": "212", "Tubi": "73", "Pluto TV": "300"
    ]

    private let regionISOMap: [String: String] = [
        "United States": "US", "United Kingdom": "GB", "Canada": "CA",
        "Australia": "AU", "Germany": "DE", "France": "FR", "Spain": "ES",
        "Italy": "IT", "Brazil": "BR", "India": "IN", "Japan": "JP",
        "South Korea": "KR", "Netherlands": "NL", "Sweden": "SE", "Mexico": "MX"
    ]

    private let sortOrderAPIMap: [String: String] = [
        "Most popular": "popularity.desc",
        "Least popular": "popularity.asc",
        "Highest rated": "vote_average.desc",
        "Newest first": "primary_release_date.desc",
        "Oldest first": "primary_release_date.asc",
        "Highest revenue": "revenue.desc"
    ]

    private let certificationOrderMap: [String: Int] = [
        "G": 0, "PG": 1, "PG-13": 2, "R": 3, "NC-17": 4
    ]

    // MARK: - Build Request

    private func buildCreateRequest() -> CreatePickRequest {
        let mediaTypes = (includeMovies && includeTV) ? ["movie", "tv"]
            : (includeMovies ? ["movie"] : (includeTV ? ["tv"] : []))

        // MARK: seed_params (recipe-specific)
        var seedParams = PickSeedParams()

        switch selectedRecipeType {
        case .byMood:
            if !selectedMoods.isEmpty { seedParams.moods = Array(selectedMoods) }
        case .similarTo:
            if !selectedSeedTitles.isEmpty {
                seedParams.similar_ids = selectedSeedTitles.map {
                    SimilarItem(tmdb_id: $0.tmdbId, media_type: $0.mediaType.rawValue)
                }
            }
        case .byEra:
            if let from = Int(yearFrom) { seedParams.year_min = from }
            if let to   = Int(yearTo)   { seedParams.year_max = to }
        default:
            break
        }

        // MARK: filters
        var filters = PickFilters()

        // Media types
        if !mediaTypes.isEmpty { filters.media_types = mediaTypes }

        // Vote thresholds
        if let count = Int(minVoteCount), count > 0    { filters.min_vote_count   = count }
        if let avg   = Double(minVoteAverage), avg > 0 { filters.min_vote_average = avg }

        // Year range (used in advanced section for all recipe types except byEra)
        if selectedRecipeType != .byEra {
            if let from = Int(yearFrom) { filters.year_min = from }
            if let to   = Int(yearTo)   { filters.year_max = to }
        }

        // Audience
        switch audienceType {
        case .grownUp:  filters.audience = "adult"
        case .kidSafe:  filters.audience = "kids"
        case .auto:     break  // omit — backend defaults to auto
        }

        // Include genres
        if !includedGenres.isEmpty {
            let ids = includedGenres.compactMap { genreIDMap[$0] }
            if !ids.isEmpty { filters.with_genres = ids }
        }

        // Exclude genres
        if !excludedGenres.isEmpty {
            let ids = excludedGenres.compactMap { genreIDMap[$0] }
            if !ids.isEmpty { filters.without_genres = ids }
        }

        // Languages (ISO codes)
        if !includedLanguages.isEmpty {
            let codes = includedLanguages.compactMap { languageISOMap[$0] }
            if !codes.isEmpty { filters.languages = codes }
        }
        if !excludedLanguages.isEmpty {
            let codes = excludedLanguages.compactMap { languageISOMap[$0] }
            if !codes.isEmpty { filters.exclude_languages = codes }
        }

        // Runtime (minutes)
        if let rMin = Int(runtimeMin), rMin > 0 { filters.runtime_min = rMin }
        if let rMax = Int(runtimeMax), rMax > 0 { filters.runtime_max = rMax }

        // Keywords
        if !includedKeywords.isEmpty { filters.with_keywords    = includedKeywords }
        if !excludedKeywords.isEmpty { filters.exclude_keywords = excludedKeywords }

        // Streaming providers + region
        if !includedProviders.isEmpty {
            let ids = includedProviders.compactMap { providerIDMap[$0] }.compactMap { Int($0) }
            if !ids.isEmpty {
                filters.with_watch_providers = ids
                filters.watch_region = regionISOMap[selectedRegion] ?? "US"
            }
        }

        // Content rating
        if let rating = selectedRating {
            filters.certification_country = "US"
            filters.certification_lte     = rating
        }

        // Production companies
        if !selectedCompanies.isEmpty {
            filters.with_companies = selectedCompanies.map { String($0.id) }
        }

        // Sort order (omit for default taste-ranked)
        if sortOrder != "Default (taste-ranked)" {
            filters.sort_by = sortOrderAPIMap[sortOrder]
        }

        // MARK: weights
        let weights = PickWeights(
            genre:      weightGenre,
            keyword:    weightKeyword,
            people:     weightPeople,
            quality:    weightQuality,
            popularity: weightPopularity,
            novelty:    weightNovelty,
            recency:    weightRecency,
            era:        weightEra,
            language:   weightLanguage
        )

        let hasSeedParams = seedParams.moods != nil
            || seedParams.similar_ids != nil
            || seedParams.year_min != nil

        return CreatePickRequest(
            name:             pickName,
            description:      pickDescription.isEmpty ? nil : pickDescription,
            seed_type:        selectedRecipeType.apiSeedType,
            seed_params:      hasSeedParams ? seedParams : nil,
            filters:          filters,
            weights:          weights,
            exclude_watched:  includeHideWatched,
            exclude_watchlist: includeHideWatchlist
        )
    }
}



// MARK: - Modifiers & Layouts

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

struct RecipeTypeSelectionView: View {
    @Binding var selectedRecipeType: NewPickSheetView.RecipeType
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.12).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(NewPickSheetView.RecipeType.allCases, id: \.self) { type in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                selectedRecipeType = type
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 16) {
                                // Icon Container
                                ZStack {
                                    if selectedRecipeType == type {
                                        LinearGradient(colors: [Color.blue.opacity(0.8), Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    } else {
                                        Color.white.opacity(0.08)
                                    }
                                    
                                    Image(systemName: type.iconName)
                                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                                        .foregroundColor(selectedRecipeType == type ? .white : .white.opacity(0.6))
                                }
                                .frame(width: 54, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: selectedRecipeType == type ? Color.blue.opacity(0.5) : .clear, radius: 8, x: 0, y: 4)
                                
                                // Text Content
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(type.rawValue)
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundColor(selectedRecipeType == type ? .white : .white.opacity(0.9))
                                    
                                    Text(type.subtitle)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(selectedRecipeType == type ? .white.opacity(0.8) : .gray)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                
                                // Active Checkmark placeholder to prevent layout shift
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundColor(.blue)
                                    .opacity(selectedRecipeType == type ? 1 : 0)
                            }
                            .padding(16)
                            .background(
                                ZStack {
                                    if selectedRecipeType == type {
                                        Color.blue.opacity(0.15)
                                    } else {
                                        Color.white.opacity(0.02)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            )
                            .liquidGlass(cornerRadius: 20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(selectedRecipeType == type ? Color.blue.opacity(0.8) : Color.white.opacity(0.1), lineWidth: selectedRecipeType == type ? 1.5 : 0.5)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Recipe Type")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Real New Recipe Sheet
struct RecipeTemplate: Identifiable {
    let id: String       // key
    let name: String
    let description: String
    let icon: String
    let seedType: String
    let seedParams: PickSeedParams?
    let filters: PickFilters
}

struct NewRecipeSheet: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: PicksViewModel
    
    @State private var selectedKey: String = "movies_for_you"
    @State private var errorMessage: String? = nil

    let darkPurple = Color(red: 0.45, green: 0.2, blue: 0.8)

    static var allRecipes: [RecipeTemplate] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return [
            RecipeTemplate(
                id: "movies_for_you",
                name: "Movies for you",
                description: "Your top genres, directors, and keywords. Movies only.",
                icon: "film",
                seedType: "taste",
                seedParams: nil,
                filters: PickFilters(media_types: ["movie"])
            ),
            RecipeTemplate(
                id: "series_for_you",
                name: "Series for you",
                description: "Your top genres, directors, and keywords. Series only.",
                icon: "tv",
                seedType: "taste",
                seedParams: nil,
                filters: PickFilters(media_types: ["tv"])
            ),
            RecipeTemplate(
                id: "next_obsession",
                name: "Your next obsession",
                description: "Tense, gripping picks tuned to your taste — the ones you won't want to pause.",
                icon: "bolt.fill",
                seedType: "mood",
                seedParams: PickSeedParams(moods: ["tense", "gritty", "chaotic"]),
                filters: PickFilters(min_vote_average: 7)
            ),
            RecipeTemplate(
                id: "critics_pick",
                name: "Critics love, you will too",
                description: "Highly rated titles that also match your taste profile.",
                icon: "star.fill",
                seedType: "taste",
                seedParams: nil,
                filters: PickFilters(min_vote_count: 500, min_vote_average: 7.5)
            ),
            RecipeTemplate(
                id: "international",
                name: "International cinema for you",
                description: "Non-English titles ranked by your taste.",
                icon: "globe",
                seedType: "taste",
                seedParams: nil,
                filters: PickFilters(exclude_languages: ["en"])
            ),
            RecipeTemplate(
                id: "stunning",
                name: "Visually stunning",
                description: "Epic, dreamy, and atmospheric picks matched to your taste.",
                icon: "sparkles",
                seedType: "mood",
                seedParams: PickSeedParams(moods: ["epic", "dreamy", "slowburn"]),
                filters: PickFilters()
            ),
            RecipeTemplate(
                id: "trending",
                name: "Everyone's talking about",
                description: "Recent popular titles ranked by your taste.",
                icon: "chart.line.uptrend.xyaxis",
                seedType: "taste",
                seedParams: nil,
                filters: PickFilters(year_min: currentYear - 1)
            ),
            RecipeTemplate(
                id: "binge",
                name: "Binge-worthy",
                description: "Series you won't be able to stop watching.",
                icon: "play.rectangle.on.rectangle.fill",
                seedType: "streak",
                seedParams: nil,
                filters: PickFilters(media_types: ["tv"])
            ),
            RecipeTemplate(
                id: "late_night",
                name: "Late night picks",
                description: "Dark, tense, and scary. For when the lights are off.",
                icon: "moon.stars.fill",
                seedType: "mood",
                seedParams: PickSeedParams(moods: ["dark", "tense", "scary"]),
                filters: PickFilters()
            ),
            RecipeTemplate(
                id: "award_winners",
                name: "Award winners you missed",
                description: "Universally acclaimed titles from outside your usual genres.",
                icon: "trophy.fill",
                seedType: "discovery",
                seedParams: nil,
                filters: PickFilters(min_vote_count: 1000, min_vote_average: 7.5)
            ),
            RecipeTemplate(
                id: "directors",
                name: "From directors you love",
                description: "Ranked by your top directors, writers, and composers.",
                icon: "megaphone.fill",
                seedType: "crew",
                seedParams: nil,
                filters: PickFilters()
            ),
            RecipeTemplate(
                id: "keep_going",
                name: "Keep the streak going",
                description: "More of what you've been watching lately.",
                icon: "flame.fill",
                seedType: "streak",
                seedParams: nil,
                filters: PickFilters()
            ),
            RecipeTemplate(
                id: "quick_watch",
                name: "Quick watch",
                description: "Movies under 100 minutes, taste-ranked.",
                icon: "timer",
                seedType: "taste",
                seedParams: nil,
                filters: PickFilters(media_types: ["movie"], runtime_max: 100)
            ),
            RecipeTemplate(
                id: "fresh_out",
                name: "Fresh out",
                description: "New releases from \(currentYear), ranked by your taste.",
                icon: "calendar.badge.plus",
                seedType: "taste",
                seedParams: nil,
                filters: PickFilters(year_min: currentYear)
            ),
        ]
    }

    var selectedRecipe: RecipeTemplate? {
        Self.allRecipes.first { $0.id == selectedKey }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.11, green: 0.11, blue: 0.12).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Self.allRecipes) { recipe in
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    selectedKey = recipe.id
                                }
                            } label: {
                                HStack(spacing: 16) {
                                    // Icon Container
                                    ZStack {
                                        if selectedKey == recipe.id {
                                            LinearGradient(
                                                colors: [darkPurple.opacity(0.8), darkPurple],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            )
                                        } else {
                                            Color.white.opacity(0.08)
                                        }
                                        Image(systemName: recipe.icon)
                                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                                            .foregroundColor(selectedKey == recipe.id ? .white : .white.opacity(0.6))
                                    }
                                    .frame(width: 54, height: 54)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .shadow(color: selectedKey == recipe.id ? darkPurple.opacity(0.5) : .clear, radius: 8, x: 0, y: 4)

                                    // Text
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(recipe.name)
                                            .font(.system(size: 17, weight: .bold, design: .rounded))
                                            .foregroundColor(selectedKey == recipe.id ? .white : .white.opacity(0.9))
                                        Text(recipe.description)
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(selectedKey == recipe.id ? .white.opacity(0.8) : .gray)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)

                                    // Checkmark
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                                        .foregroundColor(darkPurple)
                                        .opacity(selectedKey == recipe.id ? 1 : 0)
                                }
                                .padding(16)
                                .background(
                                    ZStack {
                                        if selectedKey == recipe.id {
                                            darkPurple.opacity(0.15)
                                        } else {
                                            Color.white.opacity(0.02)
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                )
                                .liquidGlass(cornerRadius: 20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(
                                            selectedKey == recipe.id ? darkPurple.opacity(0.8) : Color.white.opacity(0.1),
                                            lineWidth: selectedKey == recipe.id ? 1.5 : 0.5
                                        )
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }

                // Error toast
                if let err = errorMessage {
                    VStack {
                        Spacer()
                        Text(err)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.85))
                            .clipShape(Capsule())
                            .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(darkPurple)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") { createRecipe() }
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(darkPurple)
                }
            }
        }
    }

    private func createRecipe() {
        guard let recipe = selectedRecipe else { return }
        errorMessage = nil

        let request = CreatePickRequest(
            name: recipe.name,
            description: recipe.description,
            seed_type: recipe.seedType,
            seed_params: recipe.seedParams,
            filters: recipe.filters,
            weights: PickWeights(),
            exclude_watched: true,
            exclude_watchlist: false
        )

        dismiss()

        Task {
            do {
                try await viewModel.createPick(request: request)
            } catch {
                print("Error creating recipe: \(error)")
            }
        }
    }
}


struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let result = calculateLayout(in: width, subviews: subviews)
        return result.bounds
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = calculateLayout(in: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = result.frames[index].origin
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }
    
    private func calculateLayout(in maxWidth: CGFloat, subviews: Subviews) -> (bounds: CGSize, frames: [CGRect]) {
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        var frames: [CGRect] = []
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }
        return (CGSize(width: maxWidth == 0 ? maxX : maxWidth, height: currentY + lineHeight), frames)
    }
}

enum AddonState {
    case uninitialized
    case generated
    case active
}

struct PicksAddonOverlay: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: PicksViewModel
    @State private var state: AddonState = .uninitialized
    @State private var addonURL: String = "Generating..."
    @State private var isAnimatingFromButton = false
    
    // For 3D Flip effect
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Dark tinted background that dismisses when tapped
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }
            
            // The Floating Orb/Card
            ZStack {
                uninitializedCard
                    .opacity(state == .uninitialized ? 1 : 0)
                
                generatedCard
                    .opacity(state == .generated ? 1 : 0)
                
                activeCard
                    .opacity(state == .active ? 1 : 0)
            }
            .frame(width: 340)
            .background(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.15, blue: 0.2).opacity(0.98),
                                Color(red: 0.05, green: 0.05, blue: 0.08).opacity(0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .clear, .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 40, y: 30)
            .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
            .onAppear {
                if viewModel.isAddonActive {
                    self.state = .active
                    self.rotation = 0
                    self.addonURL = viewModel.addonStremioUrl ?? ""
                } else {
                    self.state = .uninitialized
                    self.rotation = 0
                    self.addonURL = "Generating..."
                }
            }
            .onChange(of: viewModel.isAddonActive) { isActive in
                guard !isAnimatingFromButton else { return }
                if isActive {
                    self.state = .active
                    self.rotation = 0
                    self.addonURL = viewModel.addonStremioUrl ?? ""
                } else {
                    self.state = .uninitialized
                    self.rotation = 0
                    self.addonURL = "Generating..."
                }
            }
        }
    }
    
    private var uninitializedCard: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 120, height: 120)
                    .blur(radius: 40)
                    .opacity(0.6)
                
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 50, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .red.opacity(0.8), radius: 15)
            }
            .padding(.top, 24)
            
            VStack(spacing: 12) {
                Text("INACTIVE")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.red)
                    .kerning(2.0)
                
                Text("Generates a read-only install URL that exposes your Picks as catalogs for any compatible client. The URL shows once, so copy it right away. Revoking or regenerating stops it working instantly.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }
            
            Button {
                Task {
                    do {
                        isAnimatingFromButton = true
                        try await viewModel.generateAddonUrl()
                        if let url = viewModel.addonStremioUrl {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                rotation += 180
                                addonURL = url
                                state = .generated
                            }
                        }
                        // Reset after animation completes
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        isAnimatingFromButton = false
                    } catch {
                        isAnimatingFromButton = false
                        print("[Addon Overlay] Failed to generate url: \(error)")
                    }
                }
            } label: {
                Text("GENERATE URL")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    private var generatedCard: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.5))
                        .frame(width: 80, height: 80)
                        .blur(radius: 20)
                    
                    Image(systemName: "link")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.5), radius: 10)
                }
                
                Text("URL GENERATED")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
                    .kerning(1.5)
            }
            .padding(.top, 24)
            
            // The URL Box
            Text(addonURL)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white)
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 24)
            
            HStack(spacing: 24) {
                Button {
                    UIPasteboard.general.string = addonURL
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        rotation += 180
                        state = .active
                    }
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 28))
                        Text("COPY")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 90, height: 90)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                
                Button {
                    if let url = URL(string: addonURL), url.scheme != nil {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 28, weight: .bold))
                        Text("OPEN")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .frame(width: 90, height: 90)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .white.opacity(0.4), radius: 15, y: 5)
                }
            }
            .padding(.bottom, 40)
        }
        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0)) // Counter-rotate the content so it reads left-to-right on the flip
    }
    
    private var activeCard: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 120, height: 120)
                    .blur(radius: 40)
                    .opacity(0.6)
                
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 50, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .green.opacity(0.8), radius: 15)
            }
            .padding(.top, 24)
            
            Text("ACTIVE")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.green)
                .kerning(2.0)
            
            HStack(spacing: 16) {
                Button {
                    Task {
                        do {
                            isAnimatingFromButton = true
                            try await viewModel.generateAddonUrl()
                            if let url = viewModel.addonStremioUrl {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    rotation -= 180
                                    addonURL = url
                                    state = .generated
                                }
                            }
                            try? await Task.sleep(nanoseconds: 600_000_000)
                            isAnimatingFromButton = false
                        } catch {
                            isAnimatingFromButton = false
                            print("[Addon Overlay] Failed to regenerate url: \(error)")
                        }
                    }
                } label: {
                    Text("REGENERATE")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                Button {
                    Task {
                        do {
                            isAnimatingFromButton = true
                            try await viewModel.revokeAddonUrl()
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                rotation -= 360
                                state = .uninitialized
                            }
                            try? await Task.sleep(nanoseconds: 600_000_000)
                            isAnimatingFromButton = false
                        } catch {
                            isAnimatingFromButton = false
                            print("[Addon Overlay] Failed to revoke url: \(error)")
                        }
                    }
                } label: {
                    Text("REVOKE")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 1, green: 0.3, blue: 0.3))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

struct ImportRecipeSheetView: View {
    @Binding var isPresented: Bool
    @Binding var importJsonString: String
    var onImport: () -> Void
    
    @FocusState private var isInputActive: Bool
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Deep dark background matching the app's aesthetic
                Color(red: 0.11, green: 0.11, blue: 0.12).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Icon
                        ZStack {
                            LinearGradient(
                                colors: [Color.green.opacity(0.8), Color.green],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 32, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.green.opacity(0.5), radius: 12, x: 0, y: 6)
                        .padding(.top, 32)
                        
                        // Title & Subtitle
                        VStack(spacing: 8) {
                            Text("Import Recipe")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Paste a recipe JSON from Discord, GitHub, or a friend. It will create a new pick with those settings.")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        
                        // Action: Paste from Clipboard
                        Button(action: {
                            if let string = UIPasteboard.general.string {
                                importJsonString = string
                            }
                        }) {
                            HStack {
                                Image(systemName: "doc.on.clipboard")
                                Text("Paste from Clipboard")
                            }
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                        }
                        .padding(.horizontal, 24)
                        
                        // Text Editor
                        VStack(alignment: .leading, spacing: 8) {
                            Text("JSON DATA")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.gray)
                                .padding(.leading, 4)
                            
                            TextEditor(text: $importJsonString)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(minHeight: 200, maxHeight: 300)
                                .padding(16)
                                .scrollContentBackground(.hidden)
                                .background(Color.black.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                                .focused($isInputActive)
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 40)
                }
                .onTapGesture {
                    isInputActive = false
                }
                
                // Floating Glassmorphic Done Button
                if isInputActive {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                isInputActive = false
                            }) {
                                HStack(spacing: 8) {
                                    Text("Done")
                                        .font(.subheadline.weight(.bold))
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 16)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isInputActive)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        importJsonString = ""
                        isPresented = false
                    }
                    .tint(.green)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        isPresented = false
                        onImport()
                    }
                    .tint(.green)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .disabled(importJsonString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
