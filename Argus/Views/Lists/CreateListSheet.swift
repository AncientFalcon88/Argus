import SwiftUI

struct CreateListSheet: View {
    @Binding var isPresented: Bool
    var onListCreated: (() -> Void)? = nil
    
    @StateObject private var viewModel = CreateListViewModel()
    @State private var isBulkImportExpanded: Bool = false
    
    enum CreateListField {
        case name, description, bulkImportTitleYear, bulkImportExternalIds
    }
    @FocusState private var focusedField: CreateListField?
    
    private var pasteInstructionText: String {
        viewModel.bulkImportMode == 0 ? "PASTE TITLES WITH YEAR (ONE PER LINE)" : "PASTE EXTERNAL IDS (ONE PER LINE)"
    }
    
    private var placeholderText: String {
        viewModel.bulkImportMode == 0 ? "Interstellar (2014)\nBreaking Bad (2008)\nOne Piece (1999)" : "tt0816692\ntt0903747\ntt0388629"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background matching genres popup
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        hideKeyboard()
                    }
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Basic Info
                        VStack(spacing: 16) {
                            textFieldBackground {
                                TextField("List Name", text: $viewModel.listName)
                                    .focused($focusedField, equals: .name)
                                    .foregroundStyle(.white)
                            }
                            
                            textFieldBackground {
                                TextField("Description (optional)", text: $viewModel.listDescription)
                                    .focused($focusedField, equals: .description)
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        bulkImportSection
                        
                        
                        textFieldBackground {
                            Toggle(isOn: $viewModel.isPublic) {
                                Text("MAKE THIS LIST PUBLIC")
                                    .font(.subheadline.weight(.bold))
                            }
                            .tint(.blue)
                            .foregroundStyle(.white)
                        }
                        
                        if let errorMsg = viewModel.errorMessage {
                            Text(errorMsg)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        if let successMsg = viewModel.successMessage {
                            Text(successMsg)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.green)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        Color.black.opacity(0.001)
                            .contentShape(Rectangle())
                            .onTapGesture { hideKeyboard() }
                    )
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Floating Glassmorphic Done Button
                if focusedField != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                focusedField = nil
                                hideKeyboard()
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
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: focusedField)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Create New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        isPresented = false
                        let vm = viewModel
                        let callback = onListCreated
                        Task {
                            await vm.createList {
                                DispatchQueue.main.async {
                                    callback?()
                                }
                            }
                        }
                    }
                    .disabled(viewModel.listName.isEmpty || viewModel.isCreatingList || (viewModel.hasSearched && viewModel.foundItems.isEmpty))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var bulkImportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isBulkImportExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Bulk Import")
                    Spacer()
                    Image(systemName: isBulkImportExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.headline)
                .foregroundStyle(.white)
            }
            
            if isBulkImportExpanded {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        PillTab(title: "TITLE + YEAR", isSelected: viewModel.bulkImportMode == 0) { viewModel.bulkImportMode = 0 }
                        PillTab(title: "EXTERNAL IDS", isSelected: viewModel.bulkImportMode == 1) { viewModel.bulkImportMode = 1 }
                    }
                    
                    Text(pasteInstructionText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GlassTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                    
                    bulkImportTextArea
                    
                    findItemsButton
                    
                    if viewModel.hasSearched {
                        foundItemsPreview
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var findItemsButton: some View {
        Button(action: {
            Task {
                await viewModel.findItems()
            }
        }) {
            HStack {
                if viewModel.isFindingItems {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "magnifyingglass")
                    Text("FIND ITEMS")
                }
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .disabled((viewModel.bulkImportTitleYearText.isEmpty && viewModel.bulkImportExternalIdsText.isEmpty) || viewModel.isFindingItems)
    }
    
    private var bulkImportTextArea: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.bulkImportMode == 0 {
                if viewModel.bulkImportTitleYearText.isEmpty {
                    Text(placeholderText)
                        .foregroundStyle(Color.white.opacity(0.3))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                }
                TextEditor(text: $viewModel.bulkImportTitleYearText)
                    .focused($focusedField, equals: .bulkImportTitleYear)
                    .frame(height: 120)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.clear)
                    .foregroundStyle(.white)
            } else {
                if viewModel.bulkImportExternalIdsText.isEmpty {
                    Text(placeholderText)
                        .foregroundStyle(Color.white.opacity(0.3))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                }
                TextEditor(text: $viewModel.bulkImportExternalIdsText)
                    .focused($focusedField, equals: .bulkImportExternalIds)
                    .frame(height: 120)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.clear)
                    .foregroundStyle(.white)
            }
        }
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // Placeholder view for found items
    private var foundItemsPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark")
                Text("FOUND \(viewModel.foundItems.count) ITEMS")
                
                if !viewModel.notFoundLines.isEmpty {
                    Text("(\(viewModel.notFoundLines.count) failed)")
                        .foregroundStyle(.red)
                }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.green)
            
            if !viewModel.foundItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.foundItems.prefix(20)) { item in
                            VStack(alignment: .leading) {
                                if let url = item.posterURL {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            Color.gray.opacity(0.3)
                                        }
                                    }
                                    .frame(width: 60, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 60, height: 90)
                                        .overlay(
                                            Image(systemName: "film")
                                                .foregroundStyle(.white.opacity(0.5))
                                        )
                                }
                                
                                Text(item.title)
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .frame(width: 60, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func textFieldBackground<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

fileprivate struct PillTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : GlassTheme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(isSelected ? 0.8 : 0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
import Foundation
import Combine

@MainActor
final class CreateListViewModel: ObservableObject {
    @Published var listName: String = ""
    @Published var listDescription: String = ""
    @Published var isPublic: Bool = false
    
    @Published var bulkImportMode: Int = 0 // 0 = TITLE + YEAR, 1 = EXTERNAL IDS
    @Published var bulkImportTitleYearText: String = ""
    @Published var bulkImportExternalIdsText: String = ""
    
    @Published var isFindingItems: Bool = false
    @Published var hasSearched: Bool = false
    @Published var foundItems: [TMDBMediaItem] = []
    @Published var notFoundLines: [String] = []
    
    @Published var isCreatingList: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // Parses the text and looks up each line
    func findItems() async {
        let hasTitles = !bulkImportTitleYearText.isEmpty
        let hasIds = !bulkImportExternalIdsText.isEmpty
        guard hasTitles || hasIds else { return }
        
        isFindingItems = true
        hasSearched = true
        errorMessage = nil
        foundItems = []
        notFoundLines = []
        
        var allTasks: [(String, Int)] = []
        
        if hasTitles {
            let lines = bulkImportTitleYearText.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            allTasks.append(contentsOf: lines.map { ($0, 0) })
        }
        
        if hasIds {
            let lines = bulkImportExternalIdsText.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            allTasks.append(contentsOf: lines.map { ($0, 1) })
        }
        
        guard !allTasks.isEmpty else {
            isFindingItems = false
            return
        }
        
        // Process in parallel using a TaskGroup
        await withTaskGroup(of: (String, TMDBMediaItem?).self) { group in
            for taskData in allTasks {
                group.addTask {
                    let item = await self.resolveLine(taskData.0, mode: taskData.1)
                    return (taskData.0, item)
                }
            }
            
            for await (line, item) in group {
                if let validItem = item {
                    foundItems.append(validItem)
                } else {
                    notFoundLines.append(line)
                }
            }
        }
        
        isFindingItems = false
    }
    
    private func resolveLine(_ line: String, mode: Int) async -> TMDBMediaItem? {
        if mode == 1 {
            // Mode 1: External IDs (tt1234567 or tmdb:1234)
            return try? await TMDBService.shared.find(externalId: line)
        } else {
            let pattern = #/^(.*?)\s*(?:\((\d{4})\))?$/#
            if let match = try? pattern.wholeMatch(in: line) {
                let title = String(match.1).trimmingCharacters(in: .whitespaces)
                let year = match.2 != nil ? String(match.2!) : nil
                return (try? await TMDBService.shared.searchMulti(title, year: year))?.first
            }
            return (try? await TMDBService.shared.searchMulti(line, year: nil))?.first
        }
    }
    
    func createList(onSuccess: @escaping () -> Void) async {
        guard !listName.isEmpty else { return }
        isCreatingList = true
        errorMessage = nil
        successMessage = nil
        
        do {
            // 1. Create the List
            let createReq = CreateListRequest(
                name: listName.trimmingCharacters(in: .whitespaces),
                description: listDescription.isEmpty ? nil : listDescription.trimmingCharacters(in: .whitespaces),
                isPublic: isPublic,
                type: .custom
            )
            
            let response = try await APIService.shared.createList(createReq)
            
            let resolvedListId: String
            if let idStr = response.listId, !idStr.isEmpty {
                resolvedListId = idStr
            } else if let idStr = response.list?.id, !idStr.isEmpty {
                resolvedListId = idStr
            } else if let idStr = response.item?.id, !idStr.isEmpty {
                resolvedListId = idStr
            } else {
                throw APIError.serverError(status: 0, message: "Invalid list ID returned")
            }
            
            // 2. Add Items to the List in Parallel
            if !foundItems.isEmpty {
                var successCount = 0
                var failCount = 0
                
                await withTaskGroup(of: Bool.self) { group in
                    for item in foundItems {
                        group.addTask {
                            let req = AddListItemRequest(tmdbId: item.tmdbId, mediaType: item.mediaType)
                            do {
                                _ = try await APIService.shared.addListItem(listId: resolvedListId, request: req)
                                return true
                            } catch {
                                return false
                            }
                        }
                    }
                    
                    for await success in group {
                        if success { successCount += 1 } else { failCount += 1 }
                    }
                }
                
                if failCount > 0 {
                    successMessage = "List created with \(successCount) items (\(failCount) failed)."
                } else {
                    successMessage = "List created with \(successCount) items!"
                }
            } else {
                successMessage = "Empty list created successfully!"
            }
            
            isCreatingList = false
            onSuccess()
            
        } catch {
            isCreatingList = false
            print("[DEBUG] ERROR creating list: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func resetSearch() {
        bulkImportTitleYearText = ""
        bulkImportExternalIdsText = ""
        hasSearched = false
        foundItems = []
        notFoundLines = []
        errorMessage = nil
    }
}
