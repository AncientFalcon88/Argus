import SwiftUI

struct SeasonMappingCard: View {
    let mapping: AnimeSeasonMapping
    var onVote: ((VoteValue) -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    @ObservedObject private var settings = SettingsStore.shared
    
    private var isOwner: Bool {
        guard !settings.contributorName.isEmpty, let contrib = mapping.contributor else { return false }
        return contrib.lowercased() == settings.contributorName.lowercased()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Title and Voting
            HStack(alignment: .top) {
                // Titles
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        Text("S\(String(format: "%02d", mapping.seasonNumber))")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        
                        if let name = mapping.seasonName, !name.isEmpty {
                            Text("•")
                                .foregroundStyle(.gray)
                            Text(name)
                                .font(.headline)
                                .foregroundStyle(.gray)
                        }
                    }
                    
                    HStack(alignment: .center, spacing: 6) {
                        Text("ADDED BY \(mapping.contributor?.uppercased() ?? "COMMUNITY")")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(.gray.opacity(0.8))
                        
                        if isOwner {
                            Text("YOU")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.leading, 8)
                .padding(.top, 4)
                
                Spacer()
                
                if isOwner {
                    HStack(spacing: 8) {
                        Button {
                            onEdit?()
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption.bold())
                                .foregroundStyle(.gray)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.05))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            onDelete?()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption.bold())
                                .foregroundStyle(.red.opacity(0.8))
                                .frame(width: 32, height: 32)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.trailing, 8)
                }
            }
            
            HStack(alignment: .bottom) {
                // Chunks
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(mapping.chunks, id: \.id) { chunk in
                        chunkRow(chunk: chunk)
                    }
                }
                .padding(.top, 4)
                
                Spacer()
                
                // Voting Pill
                HStack(spacing: 16) {
                    Button {
                        let newVote: VoteValue = mapping.userVote == 1 ? .remove : .up
                        onVote?(newVote)
                    } label: {
                        Image(systemName: "hand.thumbsup\(mapping.userVote == 1 ? ".fill" : "")")
                            .font(.body.bold())
                            .foregroundStyle(mapping.userVote == 1 ? Color.orange : .gray)
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(mapping.voteCount ?? 0)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 24, alignment: .center)
                    
                    Button {
                        let newVote: VoteValue = mapping.userVote == -1 ? .remove : .down
                        onVote?(newVote)
                    } label: {
                        Image(systemName: "hand.thumbsdown\(mapping.userVote == -1 ? ".fill" : "")")
                            .font(.body.bold())
                            .foregroundStyle(mapping.userVote == -1 ? Color.red : .gray)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .liquidGlass(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 1))
                .foregroundStyle(Color.white.opacity(0.1))
        )
    }
    
    private func chunkRow(chunk: AnimeSeasonChunk) -> some View {
        HStack(spacing: 8) {
            if let chunkId = chunk.chunkTmdbId {
                Text(verbatim: "Show ID \(chunkId)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Text("•")
                    .foregroundStyle(.gray)
            }
            
            Text("S\(String(format: "%02d", chunk.tmdbSeason))")
                .font(.caption.bold())
                .foregroundStyle(.white)
            
            if let start = chunk.tmdbEpisodeStart, let end = chunk.tmdbEpisodeEnd {
                Text("·")
                    .foregroundStyle(.gray)
                
                Text("E\(String(format: "%02d", start)) - E\(String(format: "%02d", end))")
                    .font(.caption.bold())
                    .foregroundStyle(.gray)
            } else if let start = chunk.tmdbEpisodeStart {
                Text("·")
                    .foregroundStyle(.gray)
                
                Text("E\(String(format: "%02d", start))")
                    .font(.caption.bold())
                    .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
}
