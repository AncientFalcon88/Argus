import SwiftUI

struct ManagePlaysView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: MediaDetailViewModel
    let episodeNumber: Int?
    
    @State private var editingEntryId: String? = nil
    @State private var isDeletingId: String? = nil
    @State private var tempDate: Date = Date()
    @State private var newPlayDate: Date = Date()
    @State private var isSaving = false
    @State private var isAddingNewPlay = false
    
    var plays: [WatchEntry] {
        if let ep = episodeNumber {
            return viewModel.watchHistoryItems
                .filter { $0.season == viewModel.selectedSeason && $0.episode == ep }
                .sorted { ($0.watchedAt ?? "") > ($1.watchedAt ?? "") }
        } else {
            return viewModel.watchHistoryItems
                .sorted { ($0.watchedAt ?? "") > ($1.watchedAt ?? "") }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Liquid glass background
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Title Header
                        VStack(alignment: .leading, spacing: 4) {
                            let playCount = plays.count
                            let playText = playCount == 0 ? "No plays" : "\(playCount) play\(playCount == 1 ? "" : "s")"
                            
                            if let ep = episodeNumber {
                                Text("S\(viewModel.selectedSeason)•E\(ep) — \(playText)")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.white)
                            } else {
                                Text("\(viewModel.detail?.title ?? "Movie") — \(playText)")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal)
                        

                        
                        // List of Plays
                        if plays.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.gray)
                                    .padding(.bottom, 8)
                                
                                Text("No plays yet")
                                    .font(.headline.bold())
                                    .foregroundStyle(.gray)
                                
                                Text("Log your first play below!")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8]))
                                    .foregroundStyle(Color.white.opacity(0.1))
                            )
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(plays) { entry in
                                    playRow(for: entry)
                                    
                                    if entry.id != plays.last?.id {
                                        Divider().background(Color.white.opacity(0.1)).padding(.horizontal)
                                    }
                                }
                            }
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                        
                        if isAddingNewPlay {
                            VStack(spacing: 16) {
                                DatePicker("Date", selection: $newPlayDate, displayedComponents: [.date])
                                    .datePickerStyle(.graphical)
                                    .environment(\.colorScheme, .dark)
                                    
                                DatePicker("Time", selection: $newPlayDate, displayedComponents: [.hourAndMinute])
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .environment(\.colorScheme, .dark)
                                    .frame(height: 120)
                                    .clipped()
                                
                                HStack(spacing: 12) {
                                    Button("Cancel") {
                                        withAnimation(.spring()) {
                                            isAddingNewPlay = false
                                        }
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Capsule())
                                    
                                    Button {
                                        Task {
                                            isSaving = true
                                            await viewModel.markEpisodeRewatchedAsync(episode: episodeNumber, watchedAt: newPlayDate)
                                            withAnimation(.spring()) {
                                                isAddingNewPlay = false
                                            }
                                            isSaving = false
                                        }
                                    } label: {
                                        HStack {
                                            if isSaving {
                                                ProgressView().tint(.black)
                                            } else {
                                                Image(systemName: "calendar")
                                                    .font(.system(size: 16, weight: .bold))
                                                Text("Log Play")
                                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                            }
                                        }
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 16)
                                        .background(Color.white)
                                        .clipShape(Capsule())
                                    }
                                    .disabled(isSaving)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.05))
                        } else {
                            Button {
                                withAnimation(.spring()) {
                                    newPlayDate = Date()
                                    isAddingNewPlay = true
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Log Custom Play")
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                }
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
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 20)
                }
            }
            .background(Color.clear)
        }
        .presentationDetents([.height(isAddingNewPlay || editingEntryId != nil ? 700 : plays.isEmpty ? 336 : CGFloat(236 + max(1, plays.count) * 75)), .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
    
    @ViewBuilder
    private func playRow(for entry: WatchEntry) -> some View {
        let isEditing = editingEntryId == entry.id
        
        VStack(spacing: 0) {
            HStack {
                Text(formatDate(entry.watchedAt))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                
                Spacer()
                
                if !isEditing {
                    HStack(spacing: 4) {
                        Button {
                            withAnimation(.spring()) {
                                if let date = parseDate(entry.watchedAt) {
                                    tempDate = date
                                }
                                editingEntryId = entry.id
                            }
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 34, height: 34)
                                .background(.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            Task {
                                isDeletingId = entry.id
                                await viewModel.deleteWatchEntry(id: entry.id)
                                isDeletingId = nil
                            }
                        } label: {
                            if isDeletingId == entry.id {
                                ProgressView().controlSize(.small).tint(.red)
                                    .frame(width: 34, height: 34)
                                    .background(.red.opacity(0.1))
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.red.opacity(0.75))
                                    .frame(width: 34, height: 34)
                                    .background(.red.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button("Cancel") {
                        withAnimation(.spring()) {
                            editingEntryId = nil
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
            
            if isEditing {
                VStack(spacing: 16) {
                    DatePicker("Date", selection: $tempDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .environment(\.colorScheme, .dark)
                        
                    DatePicker("Time", selection: $tempDate, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.colorScheme, .dark)
                        .frame(height: 120)
                        .clipped()
                    
                    Button {
                        Task {
                            isSaving = true
                            await viewModel.editWatchDate(id: entry.id, newDate: tempDate)
                            withAnimation(.spring()) {
                                editingEntryId = nil
                            }
                            isSaving = false
                        }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Save Changes")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                            }
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .disabled(isSaving)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(isEditing ? Color.white.opacity(0.05) : Color.clear)
    }
    
    // MARK: - Helpers
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let ds = dateString else { return nil }
        let date = Date.parseRobustly(ds)
        if date == Date(timeIntervalSince1970: 0) {
            return nil
        }
        return date
    }
    
    private func formatDate(_ dateString: String?) -> String {
        guard let d = parseDate(dateString) else { return "Unknown Date" }
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy 'at' HH:mm"
        return f.string(from: d)
    }
}
