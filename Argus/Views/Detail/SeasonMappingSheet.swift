import SwiftUI

struct UISeasonMappingChunk: Identifiable {
    let id = UUID()
    var tmdbSeason: String = ""
    var tmdbEpisodeStart: String = ""
    var tmdbEpisodeEnd: String = ""
    var useDifferentShow: Bool = false
    var chunkTmdbId: Int? = nil
    var chunkTmdbTitle: String? = nil
    var chunkTmdbPosterPath: String? = nil
    var chunkTmdbYear: String? = nil
    // Seasons available for the chosen show (populated dynamically)
    var availableSeasons: [SeasonSummary] = []
    var isLoadingSeasons: Bool = false
}

struct SeasonMappingSheet: View {
    @ObservedObject var viewModel: MediaDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var seasonNumber: String = ""
    @State private var seasonName: String = ""
    @State private var chunks: [UISeasonMappingChunk] = [UISeasonMappingChunk()]

    @State private var isSubmitting = false
    @FocusState private var isInputActive: Bool
    
    var editingMapping: AnimeSeasonMapping? = nil

    // The seasons of the primary show (from detail)
    private var primarySeasons: [SeasonSummary] {
        viewModel.detail?.seasons ?? []
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("SEASON #")
                                        .font(.caption.bold())
                                        .foregroundStyle(.gray)
                                    TextField("1", text: $seasonNumber)
                                        .keyboardType(.numberPad)
                                        .focused($isInputActive)
                                        .padding()
                                        .liquidGlass(cornerRadius: 8)
                                }

                                VStack(alignment: .leading, spacing: 12) {
                                    Text("LABEL (optional)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.gray)
                                    TextField("e.g. Mugen Train Arc", text: $seasonName)
                                        .padding()
                                        .liquidGlass(cornerRadius: 8)
                                }
                            }
                            .padding()
                            .liquidGlass(cornerRadius: 12)
                            .padding(.horizontal)

                            // Chunks
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("MAPS TO TMDB")
                                        .font(.caption.bold())
                                        .foregroundStyle(.gray)
                                    Spacer()
                                    Button {
                                        withAnimation {
                                            var newChunk = UISeasonMappingChunk()
                                            newChunk.availableSeasons = primarySeasons
                                            chunks.append(newChunk)
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus")
                                            Text("ADD CHUNK")
                                        }
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Capsule())
                                    }
                                }

                                VStack(spacing: 16) {
                                    ForEach(Array(chunks.enumerated()), id: \.offset) { index, _ in
                                        chunkCard(index: index, chunk: $chunks[index])
                                    }
                                }
                            }
                            .padding()
                            .liquidGlass(cornerRadius: 12)
                            .padding(.horizontal)

                            // Error
                            if let error = viewModel.seasonMappingSubmitError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }

                            // Submit & Helper Text
                            VStack(spacing: 12) {
                                Button {
                                    submit()
                                } label: {
                                    HStack {
                                        if isSubmitting {
                                            ProgressView().controlSize(.small).tint(.white)
                                        } else {
                                            Image(systemName: "map.fill")
                                                .font(.system(size: 16, weight: .bold))
                                            Text(editingMapping == nil ? "Submit Mapping" : "Update Mapping")
                                                .font(.system(size: 14, weight: .black, design: .rounded))
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 16)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .disabled(isFormInvalid || isSubmitting)
                                .opacity(isFormInvalid || isSubmitting ? 0.5 : 1)

                                Text("Add another chunk if this anime season spans multiple seasons or shows.")
                                    .font(.caption2)
                                    .foregroundStyle(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
                            .padding(.bottom, 24)
                        }
                        .padding(.vertical)
                    }
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
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowBackground(Color.clear)
            .navigationTitle(editingMapping == nil ? "New Season Mapping" : "Edit Season Mapping")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let edit = editingMapping {
                seasonNumber = "\(edit.seasonNumber)"
                seasonName = edit.seasonName ?? ""
                chunks = edit.chunks.map { c in
                    var ch = UISeasonMappingChunk()
                    ch.tmdbSeason = "\(c.tmdbSeason)"
                    ch.tmdbEpisodeStart = c.tmdbEpisodeStart.map { "\($0)" } ?? ""
                    ch.tmdbEpisodeEnd = c.tmdbEpisodeEnd.map { "\($0)" } ?? ""
                    if let chunkId = c.chunkTmdbId {
                        ch.useDifferentShow = true
                        ch.chunkTmdbId = chunkId
                    } else {
                        ch.availableSeasons = primarySeasons
                    }
                    return ch
                }
                
                for (idx, c) in edit.chunks.enumerated() {
                    if let chunkId = c.chunkTmdbId {
                        Task {
                            await MainActor.run { chunks[idx].isLoadingSeasons = true }
                            if let detail = try? await TMDBService.shared.fetchDetailInfo(tmdbId: chunkId, mediaType: .tv) {
                                await MainActor.run {
                                    chunks[idx].chunkTmdbTitle = detail.title
                                    chunks[idx].availableSeasons = detail.seasons
                                    chunks[idx].isLoadingSeasons = false
                                }
                            } else {
                                await MainActor.run { chunks[idx].isLoadingSeasons = false }
                            }
                        }
                    }
                }
            } else if chunks[0].availableSeasons.isEmpty {
                chunks[0].availableSeasons = primarySeasons
            }
        }
        .onChange(of: viewModel.seasonMappingSubmitSuccess) { _, success in
            if success {
                dismiss()
            }
        }
    }

    // MARK: - Chunk Card

    private func chunkCard(index: Int, chunk: Binding<UISeasonMappingChunk>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("CHUNK \(index + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(.gray)
                
                if chunk.chunkTmdbId.wrappedValue != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 10, weight: .bold))
                        Text("Cross-show")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )
                }
                
                Spacer()
                if chunks.count > 1 {
                    Button {
                        let i = index
                        withAnimation { self.chunks.remove(at: i) }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
            }

            // TMDB Show Picker Toggle
            Button {
                withAnimation {
                    let wasUsing = chunk.useDifferentShow.wrappedValue
                    chunk.useDifferentShow.wrappedValue.toggle()
                    if wasUsing {
                        // Reverted to primary show — reset seasons
                        chunk.chunkTmdbId.wrappedValue = nil
                        chunk.chunkTmdbTitle.wrappedValue = nil
                        chunk.availableSeasons.wrappedValue = primarySeasons
                        chunk.tmdbSeason.wrappedValue = ""
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "link")
                    Text(chunk.useDifferentShow.wrappedValue ? "USE ORIGINAL SHOW" : "USE A DIFFERENT SHOW")
                    Spacer()
                    if !chunk.useDifferentShow.wrappedValue {
                        Text("Current show by default")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
                .font(.caption.bold())
                .foregroundStyle(chunk.useDifferentShow.wrappedValue ? .blue : .gray)
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(Color.white.opacity(0.1))
                )
            }

            if chunk.useDifferentShow.wrappedValue {
                ShowSearchField(
                    chunk: chunk,
                    onSelected: { item, seasons in
                        withAnimation {
                            chunk.chunkTmdbId.wrappedValue = item.tmdbId
                            chunk.chunkTmdbTitle.wrappedValue = item.title
                            chunk.chunkTmdbPosterPath.wrappedValue = item.posterPath
                            chunk.chunkTmdbYear.wrappedValue = item.year
                            chunk.availableSeasons.wrappedValue = seasons
                            chunk.tmdbSeason.wrappedValue = ""
                        }
                    }
                )
            }

            // TMDB Season Picker — populated from the chosen show's real seasons
            let seasons = chunk.availableSeasons.wrappedValue.isEmpty ? primarySeasons : chunk.availableSeasons.wrappedValue
            Menu {
                Picker("TMDB Season", selection: chunk.tmdbSeason) {
                    Text("Pick TMDB season...").tag("")
                    ForEach(seasons) { season in
                        Text(season.seasonNumber == 0
                             ? "Specials · \(season.episodeCount) eps"
                             : "S\(String(format: "%02d", season.seasonNumber)) · \(season.episodeCount) eps")
                            .tag("\(season.seasonNumber)")
                    }
                }
            } label: {
                HStack {
                    let val = chunk.tmdbSeason.wrappedValue
                    if val.isEmpty {
                        Text("Pick TMDB season...")
                            .foregroundStyle(.gray)
                    } else if val == "0" {
                        Text("Specials")
                            .foregroundStyle(.white)
                    } else {
                        Text("S\(String(format: "%02d", Int(val) ?? 0))")
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    if chunk.isLoadingSeasons.wrappedValue {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
            }
            .padding()
            .liquidGlass(cornerRadius: 8)

            HStack(spacing: 12) {
                TextField("Start Ep", text: chunk.tmdbEpisodeStart)
                    .keyboardType(.numberPad)
                    .focused($isInputActive)
                    .padding()
                    .liquidGlass(cornerRadius: 8)

                Image(systemName: "arrow.right")
                    .foregroundStyle(.gray)

                TextField("End Ep", text: chunk.tmdbEpisodeEnd)
                    .keyboardType(.numberPad)
                    .focused($isInputActive)
                    .padding()
                    .liquidGlass(cornerRadius: 8)
            }
        }
        .padding()
        .liquidGlass(cornerRadius: 12)
        .padding(.horizontal)
    }

    // MARK: - Validation

    private var isFormInvalid: Bool {
        guard let _ = Int(seasonNumber) else { return true }
        for chunk in chunks {
            if Int(chunk.tmdbSeason) == nil { return true }
        }
        return false
    }

    // MARK: - Submit

    private func submit() {
        guard let season = Int(seasonNumber) else { return }
        isSubmitting = true

        let chunkInputs = chunks.compactMap { chunk -> AnimeSeasonChunkInput? in
            guard let tmdbSeason = Int(chunk.tmdbSeason) else { return nil }
            return AnimeSeasonChunkInput(
                tmdbSeason: tmdbSeason,
                tmdbEpisodeStart: Int(chunk.tmdbEpisodeStart),
                tmdbEpisodeEnd: Int(chunk.tmdbEpisodeEnd),
                chunkTmdbId: chunk.chunkTmdbId
            )
        }

        Task {
            await viewModel.submitSeasonMapping(
                seasonNumber: season,
                seasonName: seasonName.isEmpty ? nil : seasonName,
                chunks: chunkInputs
            )
            await MainActor.run { isSubmitting = false }
        }
    }
}

// MARK: - Show Search Field

struct ShowSearchField: View {
    let chunk: Binding<UISeasonMappingChunk>
    let onSelected: (TMDBMediaItem, [SeasonSummary]) -> Void

    @State private var query: String = ""
    @State private var results: [TMDBMediaItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var showResults = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = chunk.chunkTmdbTitle.wrappedValue, let tmdbId = chunk.chunkTmdbId.wrappedValue {
                HStack(spacing: 12) {
                    if let poster = chunk.chunkTmdbPosterPath.wrappedValue {
                        AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w92\(poster)")) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color.white.opacity(0.1)
                        }
                        .frame(width: 40, height: 60)
                        .cornerRadius(6)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 40, height: 60)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Text("\(chunk.chunkTmdbYear.wrappedValue ?? "") · TMDB \(String(tmdbId))")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation {
                            chunk.chunkTmdbId.wrappedValue = nil
                            chunk.chunkTmdbTitle.wrappedValue = nil
                            chunk.chunkTmdbPosterPath.wrappedValue = nil
                            chunk.chunkTmdbYear.wrappedValue = nil
                            chunk.availableSeasons.wrappedValue = []
                            chunk.tmdbSeason.wrappedValue = ""
                            query = ""
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(.gray)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
            } else {
                HStack(spacing: 12) {
                    if isSearching {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.gray)
                    }
                    
                    TextField("Search TMDB for a show...", text: $query)
                        .onChange(of: query) { _, newValue in
                            scheduleSearch(newValue)
                        }
                }
                .padding()
                .liquidGlass(cornerRadius: 8)
            }

            if showResults && !results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(results) { item in
                        Button {
                            selectShow(item)
                        } label: {
                            HStack(spacing: 10) {
                                if let poster = item.posterPath {
                                    AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w92\(poster)")) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Color.white.opacity(0.1)
                                    }
                                    .frame(width: 32, height: 48)
                                    .cornerRadius(4)
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 32, height: 48)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text("\(item.year) · TMDB \(String(item.tmdbId))")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if item.id != results.last?.id {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }


        }
    }

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        guard text.count >= 2 else {
            results = []
            showResults = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms debounce
            guard !Task.isCancelled else { return }
            await MainActor.run { isSearching = true }
            do {
                let items = try await TMDBService.shared.search(text, mediaType: .tv)
                await MainActor.run {
                    results = Array(items.prefix(6))
                    showResults = true
                    isSearching = false
                }
            } catch {
                await MainActor.run { isSearching = false }
            }
        }
    }

    private func selectShow(_ item: TMDBMediaItem) {
        withAnimation {
            query = ""
            showResults = false
            chunk.isLoadingSeasons.wrappedValue = true
        }

        Task {
            // Fetch the show's seasons from TMDB
            do {
                let detail = try await TMDBService.shared.fetchDetailInfo(tmdbId: item.tmdbId, mediaType: .tv)
                await MainActor.run {
                    onSelected(item, detail.seasons)
                    chunk.isLoadingSeasons.wrappedValue = false
                }
            } catch {
                await MainActor.run {
                    onSelected(item, [])
                    chunk.isLoadingSeasons.wrappedValue = false
                }
            }
        }
    }
}
